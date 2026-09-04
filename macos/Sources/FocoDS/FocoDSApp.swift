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

        // 7. Setup Floating Notes Panel Controller
        notesController = NotesPanelController(model: model, pillWindow: window)
        model.onToggleNotesPanel = { [weak self] in
            self?.notesController?.toggle()
        }

        // 8. Setup Window Reposition Listener
        model.onWindowRepositionRequested = { [weak self] in
            self?.applyWindowPosition()
        }

        // 9. Register Global Hotkey ⌥ + F (Toggle Notes / Focus HUD)
        GlobalHotkeyManager.shared.onHotKeyTriggered = { [weak self] in
            guard let self = self else { return }
            self.notesController?.toggle()
            if self.model.isNotchSnapped {
                self.applyWindowPosition()
            }
        }
        GlobalHotkeyManager.shared.registerDefaultHotKey()

        // 10. Setup Menu Bar Status Item
        setupStatusItem()
    }

    private func setupFloatingPill() {
        let pillWidth: CGFloat = 340
        let pillHeight: CGFloat = 40

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

        self.window = panel
        applyWindowPosition()
        panel.orderFrontRegardless()
    }

    private func applyWindowPosition() {
        guard let panel = window, let screen = NSScreen.main else { return }
        let pillWidth = panel.frame.width
        let pillHeight = panel.frame.height

        if model.isNotchSnapped {
            // Snapped directly flush under top edge (MacBook notch)
            let screenFrame = screen.frame
            let x = screenFrame.origin.x + (screenFrame.width - pillWidth) / 2
            let y = screenFrame.maxY - pillHeight
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        } else {
            // Free floating default near top with safe padding
            let screenRect = screen.visibleFrame
            let x = screenRect.origin.x + (screenRect.width - pillWidth) / 2
            let y = screenRect.origin.y + screenRect.height - pillHeight - 10
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.title = "🎯 Foco DS"
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Foco DS • HUD Ativo (⌥ + F)", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Abrir Super Productivity", action: #selector(openSuperProductivity), keyEquivalent: "o"))
        menu.addItem(NSMenuItem(title: "Abrir/Fechar Nota Flutuante", action: #selector(toggleNotes), keyEquivalent: "n"))
        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Alternar Encaixe no Notch", action: #selector(toggleNotch), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Alternar Estilo Visual", action: #selector(toggleStyle), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Testar Som de Play (Submarine)", action: #selector(testPlaySound), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Testar Flash Borda Verde (1s)", action: #selector(testPlayFlash), keyEquivalent: "p"))
        menu.addItem(NSMenuItem(title: "Testar Flash Borda Vermelho (1s)", action: #selector(testAlert), keyEquivalent: "t"))
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

    @objc private func toggleNotch() {
        model.toggleNotchSnap()
    }

    @objc private func toggleStyle() {
        if model.visualStyle == "classic" {
            model.setVisualStyle("circular")
        } else {
            model.setVisualStyle("classic")
        }
    }

    @objc private func testPlaySound() {
        ScreenFlashController.playStartFocusSound()
    }

    @objc private func testPlayFlash() {
        ScreenFlashController.triggerPlayFlash()
    }

    @objc private func testAlert() {
        model.triggerOvertimeAlert()
    }

    @objc private func recenterPanel() {
        applyWindowPosition()
    }

    @objc private func quitApp() {
        GlobalHotkeyManager.shared.unregisterHotKey()
        bridge?.stop()
        NSApplication.shared.terminate(nil)
    }
}

