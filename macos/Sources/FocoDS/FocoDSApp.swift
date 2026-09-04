import SwiftUI
import AppKit

final class FocoDSPillPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override var isMovable: Bool {
        get { true }
        set { }
    }
}

final class FocoDSPillHostingView: NSHostingView<FocoDSPillView> {
    weak var appDelegate: AppDelegate?

    override func menu(for event: NSEvent) -> NSMenu? {
        return appDelegate?.buildPillMenu()
    }
}

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
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    static var openMenuCount: Int = 0
    static var isMenuOpen: Bool { openMenuCount > 0 }

    func menuWillOpen(_ menu: NSMenu) {
        AppDelegate.openMenuCount += 1
    }

    func menuDidClose(_ menu: NSMenu) {
        AppDelegate.openMenuCount = max(0, AppDelegate.openMenuCount - 1)
    }

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

        // 6. Setup Task Creation
        model.onCreateTask = { [weak b] title, estimateMs in
            b?.queueCommand([
                "type": "create_task",
                "title": title,
                "timeEstimateMs": estimateMs
            ])
        }

        // 7. Setup Floating Pill Window
        setupFloatingPill()

        // 8. Setup Floating Notes Panel Controller
        notesController = NotesPanelController(model: model, pillWindow: window)
        model.onToggleNotesPanel = { [weak self] in
            self?.notesController?.toggle()
        }

        // 9. Setup Window Reposition Listener with Async Debounce
        model.onWindowRepositionRequested = { [weak self] in
            self?.scheduleWindowReposition()
        }

        // 10. Register Global Hotkey ⌥ + F (Toggle Notes / Focus HUD)
        GlobalHotkeyManager.shared.onHotKeyTriggered = { [weak self] in
            guard let self = self else { return }
            self.notesController?.toggle()
            self.scheduleWindowReposition()
        }
        GlobalHotkeyManager.shared.registerDefaultHotKey()

        // 11. Setup Menu Bar Status Item
        setupStatusItem()
    }

    private var repositionWorkItem: DispatchWorkItem?

    private func scheduleWindowReposition() {
        repositionWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.applyWindowPosition()
            if self.model.showTaskCreateCard {
                self.window?.makeKeyAndOrderFront(nil)
            }
        }
        repositionWorkItem = item
        DispatchQueue.main.async(execute: item)
    }

    private func setupFloatingPill() {
        let panel = FocoDSPillPanel(
            contentRect: NSRect(x: 0, y: 0, width: 56, height: 340),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovableByWindowBackground = true

        let hostingView = FocoDSPillHostingView(rootView: FocoDSPillView(model: model))
        hostingView.appDelegate = self
        panel.contentView = hostingView

        self.window = panel
        applyWindowPosition()
        panel.orderFrontRegardless()
    }

    private func applyWindowPosition() {
        guard let panel = window, let screen = NSScreen.main else { return }

        // CRITICAL: If user is actively dragging, clicking, or navigating a menu, never interrupt frame!
        if NSEvent.pressedMouseButtons != 0 || AppDelegate.isMenuOpen {
            return
        }

        if model.visualStyle == "lateral" {
            let targetWidth: CGFloat = model.showTaskCreateCard ? 336 : 56
            let targetHeight: CGFloat = 340
            let y = screen.frame.midY - targetHeight / 2 + 20
            let x: CGFloat = (model.dockSide == "right") ? (screen.frame.maxX - targetWidth) : screen.frame.minX
            let targetRect = NSRect(x: x, y: y, width: targetWidth, height: targetHeight)
            if panel.frame != targetRect {
                panel.setFrame(targetRect, display: true, animate: false)
            }
        } else {
            let targetWidth: CGFloat = model.isCompactCircle ? 44 : max(260, min(800, model.pillWidth))
            let targetHeight: CGFloat = model.isCompactCircle ? 42 : 40

            let targetRect: NSRect
            if model.isNotchSnapped {
                let screenFrame = screen.frame
                let x = screenFrame.origin.x + (screenFrame.width - targetWidth) / 2
                let y = screenFrame.maxY - targetHeight
                targetRect = NSRect(x: x, y: y, width: targetWidth, height: targetHeight)
            } else {
                let currentFrame = panel.frame
                // Preserve user-dragged position if already placed on screen
                if currentFrame.origin.x > 10 || currentFrame.origin.y > 10 {
                    let newX = currentFrame.midX - targetWidth / 2
                    targetRect = NSRect(x: newX, y: currentFrame.origin.y, width: targetWidth, height: targetHeight)
                } else {
                    let screenRect = screen.visibleFrame
                    let x = screenRect.origin.x + (screenRect.width - targetWidth) / 2
                    let y = screenRect.origin.y + screenRect.height - targetHeight - 10
                    targetRect = NSRect(x: x, y: y, width: targetWidth, height: targetHeight)
                }
            }

            if panel.frame != targetRect {
                panel.setFrame(targetRect, display: true, animate: false)
            }
        }
        panel.orderFrontRegardless()
    }

    func buildPillMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false

        let createItem = NSMenuItem(title: "➕ Criar Nova Tarefa de Foco...", action: #selector(menuCreateTask), keyEquivalent: "")
        createItem.target = self
        menu.addItem(createItem)

        if model.isPaused {
            let resumeItem = NSMenuItem(title: "▶️ Retomar Foco na Tarefa Atual", action: #selector(menuResumeTask), keyEquivalent: "")
            resumeItem.target = self
            menu.addItem(resumeItem)
        }

        menu.addItem(NSMenuItem.separator())

        let circleToggleTitle = model.isCompactCircle ? "↔️ Expandir para Pílula Completa" : "⭕ Diminuir até Apenas o Círculo"
        let circleItem = NSMenuItem(title: circleToggleTitle, action: #selector(menuToggleCircle), keyEquivalent: "")
        circleItem.target = self
        menu.addItem(circleItem)

        // Submenu: Largura da Pílula
        let widthMenu = NSMenu()
        widthMenu.delegate = self
        let autoFitItem = NSMenuItem(title: "🎯 Ajustar ao Título Automaticamente", action: #selector(menuAutoFitWidth), keyEquivalent: "")
        autoFitItem.target = self
        widthMenu.addItem(autoFitItem)
        widthMenu.addItem(NSMenuItem.separator())

        let circleWidthItem = NSMenuItem(title: "⭕ Bolinha / Círculo Compacto (42px)", action: #selector(menuSetCircle), keyEquivalent: "")
        circleWidthItem.target = self
        if model.isCompactCircle { circleWidthItem.state = .on }
        widthMenu.addItem(circleWidthItem)

        let w360 = NSMenuItem(title: "Compacto (360px)", action: #selector(menuSetWidth360), keyEquivalent: "")
        w360.target = self
        if model.pillWidth == 360 && !model.isCompactCircle { w360.state = .on }
        widthMenu.addItem(w360)

        let w480 = NSMenuItem(title: "Padrão (480px)", action: #selector(menuSetWidth480), keyEquivalent: "")
        w480.target = self
        if model.pillWidth == 480 && !model.isCompactCircle { w480.state = .on }
        widthMenu.addItem(w480)

        let w620 = NSMenuItem(title: "Amplo - Ver Todo Título e Estimativa (620px)", action: #selector(menuSetWidth620), keyEquivalent: "")
        w620.target = self
        if model.pillWidth == 620 && !model.isCompactCircle { w620.state = .on }
        widthMenu.addItem(w620)

        let w740 = NSMenuItem(title: "Máximo (740px)", action: #selector(menuSetWidth740), keyEquivalent: "")
        w740.target = self
        if model.pillWidth == 740 && !model.isCompactCircle { w740.state = .on }
        widthMenu.addItem(w740)

        let widthParentItem = NSMenuItem(title: "📏 Largura da Pílula", action: nil, keyEquivalent: "")
        widthParentItem.submenu = widthMenu
        menu.addItem(widthParentItem)

        // Submenu: Aviso de Inatividade
        let idleMenu = NSMenu()
        idleMenu.delegate = self
        let idle10 = NSMenuItem(title: "10 minutos sem foco", action: #selector(menuSetIdle10), keyEquivalent: "")
        idle10.target = self
        if model.idleReminderThresholdMinutes == 10 { idle10.state = .on }
        idleMenu.addItem(idle10)

        let idle15 = NSMenuItem(title: "15 minutos sem foco (Padrão)", action: #selector(menuSetIdle15), keyEquivalent: "")
        idle15.target = self
        if model.idleReminderThresholdMinutes == 15 { idle15.state = .on }
        idleMenu.addItem(idle15)

        let idle30 = NSMenuItem(title: "30 minutos sem foco", action: #selector(menuSetIdle30), keyEquivalent: "")
        idle30.target = self
        if model.idleReminderThresholdMinutes == 30 { idle30.state = .on }
        idleMenu.addItem(idle30)

        let idle0 = NSMenuItem(title: "Desativado", action: #selector(menuSetIdle0), keyEquivalent: "")
        idle0.target = self
        if model.idleReminderThresholdMinutes == 0 { idle0.state = .on }
        idleMenu.addItem(idle0)

        let idleParentItem = NSMenuItem(title: "⏰ Aviso de Inatividade", action: nil, keyEquivalent: "")
        idleParentItem.submenu = idleMenu
        menu.addItem(idleParentItem)

        menu.addItem(NSMenuItem.separator())

        // Submenu: Estilo Visual
        let styleMenu = NSMenu()
        styleMenu.delegate = self
        let styleClassic = NSMenuItem(title: "Pílula HUD Superior (Notch)", action: #selector(menuSetStyleClassic), keyEquivalent: "")
        styleClassic.target = self
        if model.visualStyle == "classic" { styleClassic.state = .on }
        styleMenu.addItem(styleClassic)

        let styleLateral = NSMenuItem(title: "Dock Lateral com Anéis (Colado na Lateral)", action: #selector(menuSetStyleLateral), keyEquivalent: "")
        styleLateral.target = self
        if model.visualStyle == "lateral" { styleLateral.state = .on }
        styleMenu.addItem(styleLateral)

        let styleCircular = NSMenuItem(title: "Anéis Horizontais", action: #selector(menuSetStyleCircular), keyEquivalent: "")
        styleCircular.target = self
        if model.visualStyle == "circular" { styleCircular.state = .on }
        styleMenu.addItem(styleCircular)

        let styleParentItem = NSMenuItem(title: "🎨 Estilo Visual", action: nil, keyEquivalent: "")
        styleParentItem.submenu = styleMenu
        menu.addItem(styleParentItem)

        // Submenu: Encaixe no Topo / Lateral
        if model.visualStyle == "lateral" {
            let sideMenu = NSMenu()
            sideMenu.delegate = self
            let rightSide = NSMenuItem(title: "Lateral Direita", action: #selector(menuSetSideRight), keyEquivalent: "")
            rightSide.target = self
            if model.dockSide == "right" { rightSide.state = .on }
            sideMenu.addItem(rightSide)

            let leftSide = NSMenuItem(title: "Lateral Esquerda", action: #selector(menuSetSideLeft), keyEquivalent: "")
            leftSide.target = self
            if model.dockSide == "left" { leftSide.state = .on }
            sideMenu.addItem(leftSide)

            let sideParentItem = NSMenuItem(title: "📱 Lado da Tela", action: nil, keyEquivalent: "")
            sideParentItem.submenu = sideMenu
            menu.addItem(sideParentItem)
        } else {
            let snapMenu = NSMenu()
            snapMenu.delegate = self
            let snapNotch = NSMenuItem(title: "Encaixe Magnético no Notch", action: #selector(menuSetSnapNotch), keyEquivalent: "")
            snapNotch.target = self
            if model.isNotchSnapped { snapNotch.state = .on }
            snapMenu.addItem(snapNotch)

            let snapFree = NSMenuItem(title: "Flutuação Livre (Arrastável)", action: #selector(menuSetSnapFree), keyEquivalent: "")
            snapFree.target = self
            if !model.isNotchSnapped { snapFree.state = .on }
            snapMenu.addItem(snapFree)

            let snapParentItem = NSMenuItem(title: "🧲 Encaixe no Topo", action: nil, keyEquivalent: "")
            snapParentItem.submenu = snapMenu
            menu.addItem(snapParentItem)
        }

        // Submenu: Opacidade
        let opacityMenu = NSMenu()
        opacityMenu.delegate = self
        let op100 = NSMenuItem(title: "100% (Sólido Preto)", action: #selector(menuSetOpacity100), keyEquivalent: "")
        op100.target = self
        if model.pillOpacity >= 0.95 { op100.state = .on }
        opacityMenu.addItem(op100)

        let op85 = NSMenuItem(title: "85% (Padrão Vidro)", action: #selector(menuSetOpacity85), keyEquivalent: "")
        op85.target = self
        if model.pillOpacity >= 0.80 && model.pillOpacity < 0.95 { op85.state = .on }
        opacityMenu.addItem(op85)

        let op70 = NSMenuItem(title: "70% (Translúcido)", action: #selector(menuSetOpacity70), keyEquivalent: "")
        op70.target = self
        if model.pillOpacity >= 0.65 && model.pillOpacity < 0.80 { op70.state = .on }
        opacityMenu.addItem(op70)

        let op50 = NSMenuItem(title: "50% (Vidro Leve)", action: #selector(menuSetOpacity50), keyEquivalent: "")
        op50.target = self
        if model.pillOpacity < 0.65 { op50.state = .on }
        opacityMenu.addItem(op50)

        let opacityParentItem = NSMenuItem(title: "🎛️ Opacidade do Fundo", action: nil, keyEquivalent: "")
        opacityParentItem.submenu = opacityMenu
        menu.addItem(opacityParentItem)

        // Submenu: Estimativa da Tarefa
        let estMenu = NSMenu()
        estMenu.delegate = self
        let est15 = NSMenuItem(title: "15 minutos", action: #selector(menuSetEst15), keyEquivalent: "")
        est15.target = self
        estMenu.addItem(est15)
        let est25 = NSMenuItem(title: "25 minutos", action: #selector(menuSetEst25), keyEquivalent: "")
        est25.target = self
        estMenu.addItem(est25)
        let est30 = NSMenuItem(title: "30 minutos", action: #selector(menuSetEst30), keyEquivalent: "")
        est30.target = self
        estMenu.addItem(est30)
        let est45 = NSMenuItem(title: "45 minutos", action: #selector(menuSetEst45), keyEquivalent: "")
        est45.target = self
        estMenu.addItem(est45)
        let est60 = NSMenuItem(title: "60 minutos (1h)", action: #selector(menuSetEst60), keyEquivalent: "")
        est60.target = self
        estMenu.addItem(est60)
        estMenu.addItem(NSMenuItem.separator())
        let est0 = NSMenuItem(title: "Sem estimativa", action: #selector(menuSetEst0), keyEquivalent: "")
        est0.target = self
        estMenu.addItem(est0)

        let estParentItem = NSMenuItem(title: "⏱️ Definir Estimativa", action: nil, keyEquivalent: "")
        estParentItem.submenu = estMenu
        menu.addItem(estParentItem)

        // Submenu: Sons e Efeitos
        let soundMenu = NSMenu()
        soundMenu.delegate = self
        let soundAudioItem = NSMenuItem(title: "Tocar Som ao Iniciar Foco (Play)", action: #selector(menuTogglePlayAudio), keyEquivalent: "")
        soundAudioItem.target = self
        if model.playAudioOnStart { soundAudioItem.state = .on }
        soundMenu.addItem(soundAudioItem)
        soundMenu.addItem(NSMenuItem.separator())

        let soundSubmarine = NSMenuItem(title: "Testar Som de Play (Submarine)", action: #selector(testPlaySound), keyEquivalent: "")
        soundSubmarine.target = self
        soundMenu.addItem(soundSubmarine)

        let soundFlashGreen = NSMenuItem(title: "Testar Flash de Borda Verde (1s)", action: #selector(testPlayFlash), keyEquivalent: "")
        soundFlashGreen.target = self
        soundMenu.addItem(soundFlashGreen)

        let soundFlashRed = NSMenuItem(title: "Testar Flash de Borda Vermelho (1s)", action: #selector(testAlert), keyEquivalent: "")
        soundFlashRed.target = self
        soundMenu.addItem(soundFlashRed)

        let soundParentItem = NSMenuItem(title: "🔊 Sons e Efeitos", action: nil, keyEquivalent: "")
        soundParentItem.submenu = soundMenu
        menu.addItem(soundParentItem)

        menu.addItem(NSMenuItem.separator())

        let hotkeyItem = NSMenuItem(title: "⌨️ Atalho Global: ⌥ + F", action: nil, keyEquivalent: "")
        hotkeyItem.isEnabled = false
        menu.addItem(hotkeyItem)

        let notesItem = NSMenuItem(title: "📝 Abrir/Fechar Anotações", action: #selector(toggleNotes), keyEquivalent: "")
        notesItem.target = self
        menu.addItem(notesItem)

        let spItem = NSMenuItem(title: "🎯 Abrir no Super Productivity", action: #selector(openSuperProductivity), keyEquivalent: "")
        spItem.target = self
        menu.addItem(spItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Encerrar Foco DS", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.title = "🎯 Foco DS"
        }
        statusItem?.menu = buildPillMenu()
    }

    // MARK: - Menu Actions
    @objc private func menuCreateTask() { model.toggleTaskCreateCard() }
    @objc private func menuResumeTask() { model.resumeCurrentTask() }
    @objc private func menuToggleCircle() { model.toggleCompactCircle() }
    @objc private func menuSetCircle() { model.isCompactCircle = true }
    @objc private func menuAutoFitWidth() { model.autoFitTitleWidth() }
    @objc private func menuSetWidth360() { model.setPillWidth(360) }
    @objc private func menuSetWidth480() { model.setPillWidth(480) }
    @objc private func menuSetWidth620() { model.setPillWidth(620) }
    @objc private func menuSetWidth740() { model.setPillWidth(740) }

    @objc private func menuSetIdle10() { model.setIdleReminderMinutes(10) }
    @objc private func menuSetIdle15() { model.setIdleReminderMinutes(15) }
    @objc private func menuSetIdle30() { model.setIdleReminderMinutes(30) }
    @objc private func menuSetIdle0() { model.setIdleReminderMinutes(0) }

    @objc private func menuSetStyleClassic() { model.setVisualStyle("classic") }
    @objc private func menuSetStyleLateral() { model.setVisualStyle("lateral") }
    @objc private func menuSetStyleCircular() { model.setVisualStyle("circular") }

    @objc private func menuSetSideRight() { model.setDockSide("right") }
    @objc private func menuSetSideLeft() { model.setDockSide("left") }

    @objc private func menuSetSnapNotch() { if !model.isNotchSnapped { model.toggleNotchSnap() } }
    @objc private func menuSetSnapFree() { if model.isNotchSnapped { model.toggleNotchSnap() } }

    @objc private func menuSetOpacity100() { model.setPillOpacity(1.0) }
    @objc private func menuSetOpacity85() { model.setPillOpacity(0.85) }
    @objc private func menuSetOpacity70() { model.setPillOpacity(0.70) }
    @objc private func menuSetOpacity50() { model.setPillOpacity(0.50) }

    @objc private func menuSetEst15() { model.setTaskEstimate(minutes: 15) }
    @objc private func menuSetEst25() { model.setTaskEstimate(minutes: 25) }
    @objc private func menuSetEst30() { model.setTaskEstimate(minutes: 30) }
    @objc private func menuSetEst45() { model.setTaskEstimate(minutes: 45) }
    @objc private func menuSetEst60() { model.setTaskEstimate(minutes: 60) }
    @objc private func menuSetEst0() { model.setTaskEstimate(minutes: 0) }

    @objc private func menuTogglePlayAudio() { model.togglePlayAudio() }

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
        if model.visualStyle == "lateral" {
            model.setVisualStyle("classic")
        } else {
            model.setVisualStyle("lateral")
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

