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
