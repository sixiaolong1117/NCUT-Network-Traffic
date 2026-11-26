import AppKit
import SwiftUI
import Combine

// ponytail: MenuBarExtra 的标题在部分系统上只显示图标不跟文字，
// 改用 NSStatusItem 直接写 button.title + button.image，所见即所得。
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, ObservableObject {
    let store = TrafficStore()
    private var statusItem: NSStatusItem!
    private let panel = TrafficPanel(
        contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
        backing: .buffered, defer: false
    )
    private var bag = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ note: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(toggle(_:))
        statusItem.button?.imagePosition = .imageLeading

        panel.contentView = NSHostingView(rootView:
            ContentView(onContentSizeChange: { [weak self] in self?.resizePanelToFitContent() })
                .environmentObject(store)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        )
        panel.backgroundColor = .clear
        panel.title = "校园网流量"
        panel.isOpaque = false
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.transient, .moveToActiveSpace, .fullScreenAuxiliary]
        panel.animationBehavior = .utilityWindow
        panel.delegate = self

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

    private func resizePanelToFitContent() {
        guard panel.isVisible, let contentView = panel.contentView else { return }
        contentView.layoutSubtreeIfNeeded()
        let size = contentView.fittingSize
        guard size.width > 0, size.height > 0, contentView.frame.size != size else { return }
        panel.setContentSize(size)
        positionPanel()
    }

    @objc private func toggle(_ sender: Any?) {
        if panel.isVisible {
            panel.orderOut(sender)
        } else {
            panel.contentView?.layoutSubtreeIfNeeded()
            if let size = panel.contentView?.fittingSize { panel.setContentSize(size) }
            positionPanel()
            panel.makeKeyAndOrderFront(sender)
        }
    }

    private func positionPanel() {
        guard let button = statusItem?.button, let window = button.window,
              let screen = window.screen else { return }
        let anchor = window.convertToScreen(button.convert(button.bounds, to: nil))
        let bounds = screen.visibleFrame.insetBy(dx: 8, dy: 8)
        panel.setFrameOrigin(NSPoint(
            x: min(max(anchor.midX - panel.frame.width / 2, bounds.minX), bounds.maxX - panel.frame.width),
            y: max(bounds.minY, anchor.minY - panel.frame.height - 6)
        ))
    }

    func windowDidResize(_ notification: Notification) {
        if panel.isVisible { positionPanel() }
    }

    func windowDidResignKey(_ notification: Notification) {
        panel.orderOut(nil)
    }
}

private final class TrafficPanel: NSPanel {
    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        orderOut(sender)
    }
}
