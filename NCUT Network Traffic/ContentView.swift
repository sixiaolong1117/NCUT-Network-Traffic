import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var store: TrafficStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            Divider()
            details
            Divider()
            dailySection
            Divider()
            buttons
        }
        .padding(14)
        .frame(width: 270)
        .task { store.start() }
    }

    @ViewBuilder
    private var header: some View {
        switch store.status {
        case .ok:
            if let info = store.info {
                VStack(alignment: .leading, spacing: 2) {
                    Text("剩余流量").font(.caption).foregroundStyle(.secondary)
                    Text(ByteFormat.detail(info.remainBytes))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text("已用约 \(ByteFormat.detail(info.usedBytes)) · \(info.productName)")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        case .loading, .unknown:
            HStack { ProgressView().scaleEffect(0.8); Text(store.info == nil ? "查询中…" : "刷新中…").font(.callout) }
        case .notLoggedIn(let msg):
            Label(msg == "未登录" ? "未登录校园网" : msg, systemImage: "person.crop.circle.badge.exclamationmark")
                .font(.callout)
            Text("请先在浏览器完成 NCUT 登录认证。").font(.caption).foregroundStyle(.secondary)
        case .offline(let msg):
            Label("离线 / 非校园网", systemImage: "wifi.slash").font(.callout)
            Text(msg).font(.caption).foregroundStyle(.secondary).lineLimit(3)
            if let info = store.info {
                Text("上次：\(ByteFormat.detail(info.remainBytes))").font(.caption).foregroundStyle(.secondary)
            }
        }
        if let t = store.lastUpdated {
            Text("更新于 \(t.formatted(date: .omitted, time: .shortened))")
                .font(.caption2).foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private var details: some View {
        if let info = store.info {
            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 4) {
                GridRow { Text("账号").foregroundStyle(.secondary); Text(ByteFormat.masked(info.userName)) }
                GridRow { Text("IP").foregroundStyle(.secondary); Text(info.onlineIP) }
                GridRow { Text("在线设备").foregroundStyle(.secondary); Text("\(info.deviceCount) 台") }
            }
            .font(.caption)
        }
    }

    @ViewBuilder
    private var dailySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("按日用量 · 官网余量差值").font(.caption).foregroundStyle(.secondary)
            let days = store.daily.recentDays(7)
            HStack(spacing: 12) {
                Text("今日 \(shortUsage(days.last))").font(.caption)
                Text("昨日 \(shortUsage(days.count >= 2 ? days[days.count - 2] : nil))").font(.caption).foregroundStyle(.secondary)
            }
            if store.daily.snapshots.isEmpty {
                Text("联网成功查询后自动记录").font(.caption2).foregroundStyle(.tertiary)
            } else {
                HStack(alignment: .bottom, spacing: 6) {
                    let maxV = max(days.compactMap { $0.usedBytes }.max() ?? 1, 1)
                    ForEach(days) { d in
                        VStack(spacing: 2) {
                            Text(topLabel(d)).font(.system(size: 8)).foregroundStyle(.secondary)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(d.isReset ? Color.orange.opacity(0.5) : Color.accentColor.opacity(d.usedBytes == nil ? 0.15 : 1))
                                .frame(height: barHeight(d.usedBytes, maxBytes: maxV))
                            Text(dayLabel(d.date)).font(.system(size: 8)).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 84)
                // ponytail: 历史不限制天数，必须封在滚动区里，否则几年后弹窗被撑出屏幕。
                ScrollView {
                    ForEach(store.daily.monthlyGroups(), id: \.monthID) { g in
                        DisclosureGroup("\(monthTitle(g.monthID)) · 共用 \(ByteFormat.detail(g.days.compactMap(\.usedBytes).reduce(0, +)))") {
                            ForEach(g.days) { d in
                                HStack {
                                    Text(rowLabel(d)).font(.caption).foregroundStyle(.secondary)
                                    Spacer()
                                    Text(rowUsage(d)).font(.caption)
                                }
                            }
                        }
                        .font(.caption)
                    }
                }
                .frame(maxHeight: 220)
            }
        }
    }

    private func shortUsage(_ d: DayUsage?) -> String {
        guard let d, let v = d.usedBytes else { return "—" }
        if d.isReset { return "充值" }
        return shortBytes(v) + (d.isEstimate ? "*" : "")
    }

    private func topLabel(_ d: DayUsage) -> String {
        guard let v = d.usedBytes else { return "—" }
        if d.isReset { return "充" }
        if v == 0 { return "0" }
        return shortBytes(v)
    }

    private func shortBytes(_ bytes: Int64) -> String {
        let g = Double(bytes) / 1024 / 1024 / 1024
        if g >= 1 { return ByteFormat.menu(bytes) }
        return String(format: "%.0fM", Double(bytes) / 1024 / 1024)
    }

    private func barHeight(_ bytes: Int64?, maxBytes: Int64) -> CGFloat {
        guard let bytes, bytes > 0 else { return 3 }
        return Swift.max(3, 56 * CGFloat(Double(bytes) / Double(maxBytes)))
    }

    private func dayLabel(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.month, .day], from: date)
        return "\(c.month ?? 0)/\(c.day ?? 0)"
    }

    private func monthTitle(_ monthID: String) -> String {
        let p = monthID.split(separator: "-").compactMap { Int($0) }
        guard p.count == 2 else { return monthID }
        return "\(p[0])年\(p[1])月"
    }

    private func rowLabel(_ d: DayUsage) -> String {
        var s = dayLabel(d.date)
        if d.isEstimate { s += " *估算" }
        if d.isReset { s += " 充值+\(shortBytes(d.resetGainBytes))" }
        return s
    }

    private func rowUsage(_ d: DayUsage) -> String {
        guard let v = d.usedBytes else { return "—" }
        if d.isReset { return "0" }
        return ByteFormat.detail(v)
    }

    private var buttons: some View {
        VStack(spacing: 6) {
            Button(store.isRefreshing ? "刷新中…" : "立即刷新") { store.refresh() }
                .disabled(store.isRefreshing)
                .buttonStyle(.link)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("打开校园网登录页") {
                if let url = URL(string: "http://10.0.31.130/srun_portal_pc?ac_id=1&theme=pro") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.link)
            .frame(maxWidth: .infinity, alignment: .leading)
            Button("退出") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.link)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.callout)
    }
}
