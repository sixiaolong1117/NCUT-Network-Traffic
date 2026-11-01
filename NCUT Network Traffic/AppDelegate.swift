import AppKit
import SwiftUI
import Combine

// ponytail: MenuBarExtra 的标题在部分系统上只显示图标不跟文字，
// 改用 NSStatusItem 直接写 button.title + button.image，所见即所得。
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    let store = TrafficStore()
    private var statusItem: NSStatusItem!
    private var popover = NSPopover()
    private var bag = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ note: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(toggle(_:))
        statusItem.button?.imagePosition = .imageLeading

        popover.contentViewController = NSHostingController(rootView: ContentView().environmentObject(store))
        popover.behavior = .transient

        // objectWillChange 在变化前触发，defer 一拍再读就是新值。
        store.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.syncButton() }
        }.store(in: &bag)
        syncButton()
        store.start()
    }

    private func syncButton() {
        guard let button = statusItem?.button else { return }
        button.title = store.menuTitle
        button.image = NSImage(systemSymbolName: store.menuIcon, accessibilityDescription: nil)
    }

    @objc private func toggle(_ sender: Any?) {
        guard let button = statusItem?.button else { return }
        if popover.isShown { popover.performClose(sender) } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
