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
    var notesController: NotesPanelController?
    var statusItem: NSStatusItem?
    let model = FocoDSModel()
    var bridge: FocoDSBridge?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. Setup local bridge server
        let b = FocoDSBridge(model: model)
        self.bridge = b
        b.start()

        // 2. Setup bidirectional notes saving
        model.onNotesSaved = { [weak b] taskId, notes in
            b?.queueCommand([
                "type": "update_notes",
                "taskId": taskId,
                "notes": notes
            ])
        }

        // 3. Setup Task Click Handler (opens and focuses task in Super Productivity)
        model.onTaskClicked = { [weak b] taskId in
            if let id = taskId, !id.isEmpty {
                b?.queueCommand([
                    "type": "focus_task",
                    "taskId": id
                ])
            }
        }

        // 4. Setup Habit Click Handler (increments habit counter in Super Productivity)
        model.onHabitClicked = { [weak b] habitId in
            b?.queueCommand([
                "type": "increment_habit",
                "habitId": habitId
            ])
        }

        // 5. Setup Estimate Updating
        model.onUpdateEstimate = { [weak b] taskId, estimateMs in
            b?.queueCommand([
                "type": "update_task_estimate",
                "taskId": taskId,
                "timeEstimateMs": estimateMs
            ])
        }

        // 6. Setup Floating Pill Window
        setupFloatingPill()

        // 6. Setup Floating Notes Panel Controller
        notesController = NotesPanelController(model: model, pillWindow: window)
        model.onToggleNotesPanel = { [weak self] in
            self?.notesController?.toggle()
        }

        // 7. Setup Menu Bar Status Item
        setupStatusItem()
    }

    private func setupFloatingPill() {
        let pillWidth: CGFloat = 330
        let pillHeight: CGFloat = 38

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: pillWidth, height: pillHeight),
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
        panel.isMovableByWindowBackground = false

        let hostingView = NSHostingView(rootView: FocoDSPillView(model: model))
        panel.contentView = hostingView

        // Center on main screen near top (right under notch / menu bar)
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let x = screenRect.origin.x + (screenRect.width - pillWidth) / 2
            let y = screenRect.origin.y + screenRect.height - pillHeight - 6
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
        menu.addItem(NSMenuItem(title: "Abrir/Fechar Nota Flutuante", action: #selector(toggleNotes), keyEquivalent: "n"))
        menu.addItem(NSMenuItem(title: "Testar Flash Play (Verde)", action: #selector(testPlayFlash), keyEquivalent: "p"))
        menu.addItem(NSMenuItem(title: "Testar Alerta/Estimativa (Vermelho)", action: #selector(testAlert), keyEquivalent: "t"))
        menu.addItem(NSMenuItem(title: "Centralizar no Topo", action: #selector(recenterPanel), keyEquivalent: "c"))
        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Encerrar Foco DS", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    @objc private func openSuperProductivity() {
        SuperProductivityLauncher.activateSuperProductivity()
    }

    @objc private func toggleNotes() {
        notesController?.toggle()
    }

    @objc private func testPlayFlash() {
        ScreenFlashController.triggerPlayFlash()
    }

    @objc private func testAlert() {
        model.triggerOvertimeAlert()
    }

    @objc private func recenterPanel() {
        guard let panel = window, let screen = NSScreen.main else { return }
        let screenRect = screen.visibleFrame
        let x = screenRect.origin.x + (screenRect.width - panel.frame.width) / 2
        let y = screenRect.origin.y + screenRect.height - panel.frame.height - 6
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    @objc private func quitApp() {
        bridge?.stop()
        NSApplication.shared.terminate(nil)
    }
}
