import SwiftUI

@main
struct NCUT_Network_TrafficApp: App {
    @StateObject private var store = TrafficStore()

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(store)
        } label: {
            Label(store.menuTitle, systemImage: store.menuIcon)
        }
        .menuBarExtraStyle(.window)
    }
}
