import Foundation
import Combine

/// 按日统计：只存官网 remain 快照，用「前一日末次 - 当日末次」算用量。
/// 不碰本机网卡计数，多设备共享账号算的是账号总量。
struct DaySnapshot: Codable {
    var lastRemain: Int64
}

struct DayUsage: Identifiable {
    let dayID: String // yyyy-MM-dd
    let date: Date
    /// nil = 当天无快照或无前一天基线，算不出
    let usedBytes: Int64?
    /// 中间缺天（关机/离线），用量含多天，需标记估算
    let isEstimate: Bool
    /// remain 变大：充值/套餐重置，当天用量记 0
    let isReset: Bool
    let resetGainBytes: Int64

    var id: String { dayID }
}

@MainActor
final class DailyUsageStore: ObservableObject {
    @Published private(set) var snapshots: [String: DaySnapshot] = [:]

    // ponytail: 不缓存 Calendar，改系统时区后下次调用即按新时区切天。
    private var calendar: Calendar { .current }

    init() {
        snapshots = Self.load()
        #if DEBUG
        Self.selfCheck()
        #endif
    }

    // MARK: - record

    func record(remainBytes: Int64, at date: Date = Date()) {
        // remain<=0 只可能是 portal 字段改名导致 i64 兜底成 0，记了就是一笔巨额假用量，且历史删不掉。
        guard remainBytes > 0 else { return }
        let id = Self.dayID(date, calendar: calendar)
        // 值没变就不写盘不刷 UI，5 分钟一次轮询里大多数时候走这里。
        guard snapshots[id]?.lastRemain != remainBytes else { return }
        snapshots[id] = DaySnapshot(lastRemain: remainBytes)
        Self.save(snapshots)
    }

    // MARK: - query

    /// 某日用量 = 前一个有快照日的末次 - 当日末次
    func usage(for dayID: String) -> DayUsage? {
        guard let cur = snapshots[dayID] else { return nil }
        let prevID = snapshots.keys.filter { $0 < dayID }.max()
        return Self.makeUsage(dayID: dayID, curRemain: cur.lastRemain,
                             prevID: prevID, prevRemain: prevID.flatMap { snapshots[$0]?.lastRemain },
                             calendar: calendar)
    }

    /// 纯函数，方便单测/人肉验算。算例（remain 单位 GB）：
    /// 1. 正常：prev=50, cur=48 → 用量 2，非估算；
    /// 2. 缺 3 天：prev=50（3 天前）, cur=44 → 用量 6，isEstimate=true；
    /// 3. 充值：prev=10, cur=60 → 用量 0，isReset=true，resetGain=50；
    /// 4. 首日：prev=nil → 用量 nil（无基线）。
    static func makeUsage(dayID: String, curRemain: Int64, prevID: String?, prevRemain: Int64?, calendar: Calendar = .current) -> DayUsage? {
        guard let date = Self.date(dayID, calendar: calendar) else { return nil }
        guard let prevID, let prev = prevRemain,
              let prevDate = Self.date(prevID, calendar: calendar)
        else {
            return DayUsage(dayID: dayID, date: date, usedBytes: nil, isEstimate: false, isReset: false, resetGainBytes: 0)
        }
        let diff = prev - curRemain
        if diff < 0 {
            return DayUsage(dayID: dayID, date: date, usedBytes: 0, isEstimate: false, isReset: true, resetGainBytes: -diff)
        }
        let gap = calendar.dateComponents([.day], from: calendar.startOfDay(for: prevDate), to: calendar.startOfDay(for: date)).day ?? 1
        return DayUsage(dayID: dayID, date: date, usedBytes: diff, isEstimate: gap > 1, isReset: false, resetGainBytes: 0)
    }

    /// 含今天在内的最近 n 天（左老右新），无快照的天用量为 nil
    func recentDays(_ n: Int = 7, endingAt date: Date = Date()) -> [DayUsage] {
        let start = calendar.startOfDay(for: date)
        return (0..<n).compactMap { offset in
            let d = calendar.date(byAdding: .day, value: -(n - 1 - offset), to: start)
            guard let d else { return nil }
            let id = Self.dayID(d, calendar: calendar)
            // 有快照就走 usage()，无快照占位（图表断档）
            if snapshots[id] != nil { return usage(for: id) }
            return DayUsage(dayID: id, date: d, usedBytes: nil, isEstimate: false, isReset: false, resetGainBytes: 0)
        }
    }

    /// 按月倒序分组，只含 有快照 的天。一次排序顺序走，O(n)。
    func monthlyGroups() -> [(monthID: String, days: [DayUsage])] {
        let ids = snapshots.keys.sorted()
        var usages: [DayUsage] = []
        usages.reserveCapacity(ids.count)
        var prevID: String?
        var prevRemain: Int64?
        for id in ids {
            guard let cur = snapshots[id] else { continue }
            // 只有当天 id 合法才推进 prev：坏 key 不配当别人的基线，否则连带毒死后一天。
            if let u = Self.makeUsage(dayID: id, curRemain: cur.lastRemain, prevID: prevID, prevRemain: prevRemain, calendar: calendar) {
                usages.append(u)
                prevID = id
                prevRemain = cur.lastRemain
            }
        }
        // 倒序按月分组，字典收拢 O(n)
        var byMonth: [String: [DayUsage]] = [:]
        for u in usages.reversed() {
            byMonth[String(u.dayID.prefix(7)), default: []].append(u) // yyyy-MM
        }
        return byMonth.keys.sorted(by: >).map { (monthID: $0, days: byMonth[$0] ?? []) }
    }

    // MARK: - dayID

    #if DEBUG
    /// 四条分支启动即验算，release 零成本。
    static func selfCheck() {
        let G: Int64 = 1024 * 1024 * 1024
        let ok = makeUsage(dayID: "2026-11-02", curRemain: 48 * G, prevID: "2026-11-01", prevRemain: 50 * G)
        assert(ok?.usedBytes == 2 * G && ok?.isEstimate == false && ok?.isReset == false)
        let gap = makeUsage(dayID: "2026-11-04", curRemain: 44 * G, prevID: "2026-11-01", prevRemain: 50 * G)
        assert(gap?.usedBytes == 6 * G && gap?.isEstimate == true)
        let reset = makeUsage(dayID: "2026-11-02", curRemain: 60 * G, prevID: "2026-11-01", prevRemain: 10 * G)
        assert(reset?.usedBytes == 0 && reset?.isReset == true && reset?.resetGainBytes == 50 * G)
        let first = makeUsage(dayID: "2026-11-01", curRemain: 50 * G, prevID: nil, prevRemain: nil)
        assert(first?.usedBytes == nil)
    }
    #endif

    static func dayID(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func date(_ dayID: String, calendar: Calendar = .current) -> Date? {
        let p = dayID.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: p[0], month: p[1], day: p[2]))
    }

    // MARK: - persistence

    static var fileURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("NCUT Network Traffic/daily.json")
    }

    private static func load() -> [String: DaySnapshot] {
        // 旧文件含 firstRemain/samples/updatedAt 等多余键：Codable 默认忽略未知键，直接兼容。
        guard let url = fileURL,
              let data = try? Data(contentsOf: url),
              let d = try? JSONDecoder().decode([String: DaySnapshot].self, from: data)
        else { return [:] }
        return d
    }

    private static func save(_ snapshots: [String: DaySnapshot]) {
        guard let url = fileURL else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(snapshots) else { return }
        try? data.write(to: url, options: .atomic)
        // shortcut: 文件损坏直接丢弃重建，最多丢历史不影响主功能；数据量小（一天一条）无需限流/压缩。
    }
}
