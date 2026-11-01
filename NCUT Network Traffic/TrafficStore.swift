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

    var menuTitle: String {
        switch status {
        case .ok:
            if let info { return ByteFormat.menu(info.remainBytes) }
            return "…"
        case .notLoggedIn: return "未登录"
        case .offline: return "离线"
        case .loading: return info != nil ? ByteFormat.menu(info!.remainBytes) : "…"
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
        refresh()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            guard let store = self else { return }
            Task { @MainActor in store.refresh() }
        }
        wakeObserver = NotificationCenter.default.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            guard let store = self else { return }
            Task { @MainActor in store.refresh() }
        }
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        if info == nil, status == .unknown { status = .loading }
        Task {
            do {
                let r = try await SRunClient.fetch()
                info = r
                lastUpdated = r.fetchedAt
                status = .ok
            } catch let e as SRunError {
                switch e {
                case .notOnline(let msg):
                    status = .notLoggedIn(msg.isEmpty ? "未登录" : msg)
                case .badResponse, .network:
                    status = .offline(e.localizedDescription)
                }
            } catch {
                status = info != nil ? .offline(error.localizedDescription) : .offline(error.localizedDescription)
            }
            isRefreshing = false
        }
    }
}
