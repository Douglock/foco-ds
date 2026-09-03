import SwiftUI
import AppKit

@main
struct FocoDSApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSPanel?
    var statusItem: NSStatusItem?
    let model = FocoDSModel()
    var bridge: FocoDSBridge?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Start local bridge server
        bridge = FocoDSBridge(model: model)
        bridge?.start()

        // Setup Floating Window
        setupFloatingPanel()

        // Setup Menu Bar Status Item
        setupStatusItem()
    }

    private func setupFloatingPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 44),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovableByWindowBackground = false // We handle dragging cleanly in SwiftUI

        let hostingView = NSHostingView(rootView: FocoDSPillView(model: model))
        panel.contentView = hostingView

        // Center on main screen near top (below notch / menu bar)
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let x = screenRect.origin.x + (screenRect.width - 340) / 2
            let y = screenRect.origin.y + screenRect.height - 52
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.orderFrontRegardless()
        self.window = panel
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.title = "🎯 Foco DS"
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Foco DS • HUD Ativo", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Abrir Super Productivity", action: #selector(openSuperProductivity), keyEquivalent: "o"))
        menu.addItem(NSMenuItem(title: "Centralizar no Topo", action: #selector(recenterPanel), keyEquivalent: "c"))
        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Encerrar Foco DS", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    @objc private func openSuperProductivity() {
        SuperProductivityLauncher.activateSuperProductivity()
    }

    @objc private func recenterPanel() {
        guard let panel = window, let screen = NSScreen.main else { return }
        let screenRect = screen.visibleFrame
        let x = screenRect.origin.x + (screenRect.width - panel.frame.width) / 2
        let y = screenRect.origin.y + screenRect.height - 52
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    @objc private func quitApp() {
        bridge?.stop()
        NSApplication.shared.terminate(nil)
    }
}
