import Foundation
import Combine
import AppKit

@MainActor
final class TrafficStore: ObservableObject {
    enum Status: Equatable {
        case unknown
        case loading
        case ok
        case notLoggedIn(String)
        case offline(String)
    }

    @Published var status: Status = .unknown
    @Published var info: TrafficInfo?
    @Published var lastUpdated: Date?
    @Published var isRefreshing = false

    private var timer: Timer?
    private var wakeObserver: NSObjectProtocol?

    init() {
        // ponytail: 自举，开机即查，不依赖 MenuBarExtra 弹窗是否点开过。
        Task { @MainActor [weak self] in self?.start() }
    }

    var menuTitle: String {
        switch status {
        case .ok:
            if let info { return ByteFormat.menu(info.remainBytes) }
            return "…"
        case .notLoggedIn: return "未登录"
        case .offline: return "离线"
        case .loading: return info != nil ? ByteFormat.menu(info!.remainBytes) : "查询中"
        case .unknown: return "…"
        }
    }

    var menuIcon: String {
        switch status {
        case .ok: return "wifi"
        case .notLoggedIn: return "person.crop.circle.badge.questionmark"
        case .offline: return "wifi.slash"
        case .loading, .unknown: return "wifi"
        }
    }

    func start() {
        // ponytail: init 自举 + delegate + content.task 都会调，防重入，只建一次。
        guard timer == nil else { return }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            guard let store = self else { return }
            Task { @MainActor in store.refresh() }
        }
        if wakeObserver == nil {
            wakeObserver = NotificationCenter.default.addObserver(
                forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
            ) { [weak self] _ in
                guard let store = self else { return }
                Task { @MainActor in store.refresh() }
            }
        }
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        if info == nil, status == .unknown { status = .loading }
        Task { @MainActor in
            do {
                let r = try await SRunClient.fetch()
                info = r
                lastUpdated = r.fetchedAt
                status = .ok
                #if DEBUG
                print("[NCUT] ok remain=\(r.remainBytes) used=\(r.usedBytes)")
                #endif
            } catch let e as SRunError {
                switch e {
                case .notOnline(let msg):
                    status = .notLoggedIn(msg.isEmpty ? "未登录" : msg)
                case .badResponse, .network:
                    status = .offline(e.localizedDescription)
                }
                #if DEBUG
                print("[NCUT] fail: \(e.localizedDescription)")
                #endif
            } catch {
                status = info != nil ? .offline(error.localizedDescription) : .offline(error.localizedDescription)
                #if DEBUG
                print("[NCUT] fail: \(error.localizedDescription)")
                #endif
            }
            isRefreshing = false
        }
    }
}
