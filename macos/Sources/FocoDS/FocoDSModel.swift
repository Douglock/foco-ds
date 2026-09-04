import Foundation
import SwiftUI
import Combine

struct HabitItem: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let emoji: String
    let count: Int?
    let isOn: Bool?
    var counterType: String? = nil

    var displayCount: String {
        guard let c = count, c > 0 else { return "" }

        // Se for contador de tempo (StopWatch) ou se o valor for em milissegundos (>= 60.000 ms)
        let isTimeBased = (counterType == "StopWatch" || c >= 60000)
        if isTimeBased {
            if c >= 3600000 {
                let hours = Double(c) / 3600000.0
                if hours.truncatingRemainder(dividingBy: 1.0) == 0 {
                    return "\(Int(hours))h"
                } else {
                    return String(format: "%.1fh", hours)
                }
            } else if c >= 60000 {
                let mins = c / 60000
                return "\(mins)m"
            } else {
                let secs = c / 1000
                return "\(secs)s"
            }
        }

        if c > 999 {
            return "999+"
        }
        return "\(c)"
    }
}

@MainActor
final class FocoDSModel: ObservableObject {
    @Published var isConnected: Bool = false
    @Published var isTracking: Bool = false
    @Published var isBreak: Bool = false
    @Published var taskTitle: String = ""
    @Published var timeSpentMs: Int64 = 0
    @Published var timeEstimateMs: Int64 = 0
    @Published var remainingSeconds: Int64 = 0
    @Published var focusDurationSeconds: Int64 = 0
    @Published var taskId: String? = nil
    @Published var lastUpdated: Date = Date()

    // Habits List from Super Productivity
    @Published var habits: [HabitItem] = [
        HabitItem(id: "coffee", title: "Coffee Counter", emoji: "☕", count: 0, isOn: false),
        HabitItem(id: "treino", title: "Treino", emoji: "🏋️", count: 0, isOn: false),
        HabitItem(id: "agua", title: "Água 500ml", emoji: "🥤", count: 0, isOn: false),
        HabitItem(id: "ler", title: "Ler por 30 min", emoji: "📚", count: 0, isOn: false),
        HabitItem(id: "alongar", title: "Desaquecimento", emoji: "🧎", count: 0, isOn: false)
    ]

    // Notes Sync State
    @Published var isSideNotesOpen: Bool = false
    @Published var notesText: String = ""
    @Published var isEditingNotes: Bool = false

    @Published var isPaused: Bool = false
    @Published var isPillFlashing: Bool = false

    // Resizing & Compact Circle State
    @Published var pillWidth: CGFloat = 480 {
        didSet {
            UserDefaults.standard.set(Double(pillWidth), forKey: "foco_ds_pill_width")
            onWindowRepositionRequested?()
        }
    }
    @Published var isCompactCircle: Bool = false {
        didSet {
            UserDefaults.standard.set(isCompactCircle, forKey: "foco_ds_compact_circle")
            onWindowRepositionRequested?()
        }
    }

    // Inactivity / Idle Reminder (Aviso sutil na Island quando muito tempo sem focar)
    @Published var isIdleReminderActive: Bool = false
    @Published var idleReminderThresholdMinutes: Int = 15
    @Published var idleMinutesWithoutFocus: Int = 0
    private var secondsSinceLastFocus: Int = 0

    // User Preferences (Persisted)
    @Published var pillOpacity: Double = 0.88
    @Published var isNotchSnapped: Bool = true
    @Published var visualStyle: String = "lateral" // "lateral" (Side Dock com Anéis) or "classic" (HUD Topo)
    @Published var dockSide: String = "right" // "right" or "left"
    @Published var playAudioOnStart: Bool = true

    // Task Creation Card State
    @Published var showTaskCreateCard: Bool = false {
        didSet {
            onWindowRepositionRequested?()
        }
    }

    // Callbacks to send commands to Super Productivity & Window Manager
    var onNotesSaved: ((_ taskId: String, _ notes: String) -> Void)?
    var onToggleNotesPanel: (() -> Void)?
    var onHabitClicked: ((_ habitId: String) -> Void)?
    var onTaskClicked: ((_ taskId: String?) -> Void)?
    var onUpdateEstimate: ((_ taskId: String, _ estimateMs: Int64) -> Void)?
    var onCreateTask: ((_ title: String, _ estimateMs: Int64) -> Void)?
    var onWindowRepositionRequested: (() -> Void)?

    private var timerCancellable: AnyCancellable?
    private var previousIsTracking: Bool = false
    private var previousIsBreak: Bool = false
    private var previousRemaining: Int64 = 0
    private var hasAlertedOvertimeTaskId: String? = nil
    private var alertedOvertimeTaskKeys = Set<String>()
    private var saveDebounceWorkItem: DispatchWorkItem?

    init() {
        self.notesText = UserDefaults.standard.string(forKey: "foco_ds_side_notes") ?? ""

        // Load persisted settings
        let savedOpacity = UserDefaults.standard.double(forKey: "foco_ds_opacity")
        self.pillOpacity = savedOpacity > 0.1 ? savedOpacity : 0.88

        let savedWidth = UserDefaults.standard.double(forKey: "foco_ds_pill_width")
        self.pillWidth = savedWidth >= 200 ? CGFloat(savedWidth) : 480

        if let savedCompact = UserDefaults.standard.object(forKey: "foco_ds_compact_circle") as? Bool {
            self.isCompactCircle = savedCompact
        }

        let savedIdle = UserDefaults.standard.integer(forKey: "foco_ds_idle_threshold")
        self.idleReminderThresholdMinutes = savedIdle > 0 ? savedIdle : 15

        if let savedNotch = UserDefaults.standard.object(forKey: "foco_ds_notch_snapped") as? Bool {
            self.isNotchSnapped = savedNotch
        }

        self.visualStyle = UserDefaults.standard.string(forKey: "foco_ds_visual_style") ?? "classic"
        self.dockSide = UserDefaults.standard.string(forKey: "foco_ds_dock_side") ?? "right"

        if let savedAudio = UserDefaults.standard.object(forKey: "foco_ds_play_audio") as? Bool {
            self.playAudioOnStart = savedAudio
        }

        // Local clock ticking smoothly every second
        timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }

                if self.isTracking {
                    self.timeSpentMs += 1000
                    self.secondsSinceLastFocus = 0
                    if self.isIdleReminderActive {
                        self.isIdleReminderActive = false
                    }

                    // Check if estimate was just exceeded (ONLY ONCE per task)
                    let taskKey = "\(self.taskId ?? self.taskTitle)_\(self.timeEstimateMs)"
                    if self.hasEstimate && self.isOvertime && !self.alertedOvertimeTaskKeys.contains(taskKey) {
                        self.alertedOvertimeTaskKeys.insert(taskKey)
                        self.hasAlertedOvertimeTaskId = self.taskId
                        self.triggerOvertimeAlert()
                    }

                    if self.remainingSeconds > 0 {
                        self.remainingSeconds -= 1
                    }
                } else if !self.isBreak {
                    self.secondsSinceLastFocus += 1
                    let idleMins = self.secondsSinceLastFocus / 60
                    self.idleMinutesWithoutFocus = idleMins
                    if self.idleReminderThresholdMinutes > 0 && idleMins >= self.idleReminderThresholdMinutes {
                        if !self.isIdleReminderActive {
                            self.isIdleReminderActive = true
                        }
                    }
                }
            }
    }

    func setPillOpacity(_ value: Double) {
        let clamped = min(1.0, max(0.20, value))
        self.pillOpacity = clamped
        UserDefaults.standard.set(clamped, forKey: "foco_ds_opacity")
    }

    func toggleNotchSnap() {
        self.isNotchSnapped.toggle()
        UserDefaults.standard.set(self.isNotchSnapped, forKey: "foco_ds_notch_snapped")
        onWindowRepositionRequested?()
    }

    func setVisualStyle(_ style: String) {
        self.visualStyle = style
        UserDefaults.standard.set(style, forKey: "foco_ds_visual_style")
        onWindowRepositionRequested?()
    }

    func setDockSide(_ side: String) {
        self.dockSide = side
        UserDefaults.standard.set(side, forKey: "foco_ds_dock_side")
        onWindowRepositionRequested?()
    }

    func toggleTaskCreateCard() {
        self.showTaskCreateCard.toggle()
        onWindowRepositionRequested?()
    }

    func createNewTask(title: String, estimateMinutes: Int) {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }

        let estimateMs = Int64(estimateMinutes * 60 * 1000)
        self.taskTitle = cleanTitle
        self.timeSpentMs = 0
        self.timeEstimateMs = estimateMs
        self.isTracking = true
        self.showTaskCreateCard = false

        // Flash and audio feedback
        ScreenFlashController.triggerPlayFlash(playSound: playAudioOnStart)

        // Dispatch command to Super Productivity
        onCreateTask?(cleanTitle, estimateMs)
        onWindowRepositionRequested?()
    }

    func togglePlayAudio() {
        self.playAudioOnStart.toggle()
        UserDefaults.standard.set(self.playAudioOnStart, forKey: "foco_ds_play_audio")
    }

    var hasEstimate: Bool {
        return timeEstimateMs > 0
    }

    func toggleCompactCircle() {
        self.isCompactCircle.toggle()
    }

    func setPillWidth(_ width: CGFloat) {
        let clamped = max(260, min(800, width))
        self.pillWidth = clamped
        if self.isCompactCircle {
            self.isCompactCircle = false
        }
    }

    func setIdleReminderMinutes(_ minutes: Int) {
        self.idleReminderThresholdMinutes = minutes
        UserDefaults.standard.set(minutes, forKey: "foco_ds_idle_threshold")
    }

    var isOvertime: Bool {
        return hasEstimate && timeSpentMs >= timeEstimateMs
    }

    func resumeCurrentTask() {
        if let tid = taskId, !tid.isEmpty {
            onTaskClicked?(tid)
        }
    }

    func update(
        isTracking: Bool,
        isPaused: Bool = false,
        taskTitle: String,
        timeSpentMs: Int64,
        timeEstimateMs: Int64 = 0,
        remainingSeconds: Int64 = 0,
        focusDurationSeconds: Int64 = 0,
        isBreak: Bool = false,
        taskId: String? = nil,
        taskNotes: String? = nil,
        habits: [HabitItem]? = nil,
        triggerPlayFlash: Bool = false,
        triggerOvertimeFlash: Bool = false,
        forceFinishedAlert: Bool = false
    ) {
        let cleanTitle = taskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let newlyTracking = isTracking && !cleanTitle.isEmpty
        let wasTracking = self.isTracking
        let taskChanged = (self.taskId != taskId)

        self.isConnected = true
        self.isTracking = newlyTracking
        self.isPaused = isPaused
        if newlyTracking {
            self.secondsSinceLastFocus = 0
            self.isIdleReminderActive = false
        }
        self.taskTitle = cleanTitle
        self.timeSpentMs = max(0, timeSpentMs)
        self.timeEstimateMs = max(0, timeEstimateMs)
        self.remainingSeconds = max(0, remainingSeconds)
        if focusDurationSeconds > 0 {
            self.focusDurationSeconds = focusDurationSeconds
        }
        self.isBreak = isBreak
        self.taskId = taskId
        self.lastUpdated = Date()

        let taskKey = "\(taskId ?? cleanTitle)_\(timeEstimateMs)"
        if taskChanged {
            self.hasAlertedOvertimeTaskId = nil
            self.alertedOvertimeTaskKeys.removeAll()
        }

        if let incomingHabits = habits, !incomingHabits.isEmpty {
            self.habits = incomingHabits
        }

        // Sync notes from Super Productivity if not actively editing
        if let incomingNotes = taskNotes, !self.isEditingNotes {
            if incomingNotes != self.notesText {
                self.notesText = incomingNotes
            }
        }

        // 1. Trigger Green Screen Edge Flash when user hits PLAY
        if triggerPlayFlash || (!wasTracking && newlyTracking) {
            ScreenFlashController.triggerPlayFlash(playSound: playAudioOnStart)
        }

        // 2. Trigger Red Screen Flash when estimate is exceeded or focus finished (ONLY ONCE per task!)
        if !alertedOvertimeTaskKeys.contains(taskKey) {
            if triggerOvertimeFlash || forceFinishedAlert || (!previousIsBreak && isBreak) {
                alertedOvertimeTaskKeys.insert(taskKey)
                triggerOvertimeAlert()
            } else if self.hasEstimate && self.isOvertime {
                alertedOvertimeTaskKeys.insert(taskKey)
                self.hasAlertedOvertimeTaskId = self.taskId
                triggerOvertimeAlert()
            }
        }

        self.previousIsTracking = newlyTracking
        self.previousIsBreak = isBreak
        self.previousRemaining = remainingSeconds
    }

    func triggerOvertimeAlert() {
        ScreenFlashController.triggerOvertimeFlash()

        // Flash pill border with gentle warning pulse ONCE
        withAnimation(.easeInOut(duration: 0.2).repeatCount(2, autoreverses: true)) {
            self.isPillFlashing = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.isPillFlashing = false
        }
    }

    func triggerFinishedAlert() {
        triggerOvertimeAlert()
    }

    func autoFitTitleWidth() {
        guard !taskTitle.isEmpty else { return }
        if isCompactCircle {
            isCompactCircle = false
        }
        let titleLen = CGFloat(taskTitle.count)
        let needed = max(420, min(800, titleLen * 8.5 + 290))
        setPillWidth(needed)
        UserDefaults.standard.set(Double(needed), forKey: "foco_ds_pill_width")
    }

    func toggleSideNotes() {
        isSideNotesOpen.toggle()
        onToggleNotesPanel?()
    }

    func userEditedNotes(_ newText: String) {
        self.isEditingNotes = true
        self.notesText = newText
        UserDefaults.standard.set(newText, forKey: "foco_ds_side_notes")

        // Debounced sync to Super Productivity (400ms after typing stops)
        saveDebounceWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.isEditingNotes = false
            if let currentTaskId = self.taskId, !currentTaskId.isEmpty {
                self.onNotesSaved?(currentTaskId, newText)
            }
        }
        saveDebounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: workItem)
    }

    func setTaskEstimate(minutes: Int) {
        guard let tid = taskId, !tid.isEmpty else { return }
        let ms = Int64(minutes * 60 * 1000)
        self.timeEstimateMs = ms
        onUpdateEstimate?(tid, ms)
    }

    func clickHabit(_ habit: HabitItem) {
        onHabitClicked?(habit.id)
    }

    func clickTask() {
        onTaskClicked?(taskId)
    }

    // Formatted time spent (MM:SS or HH:MM:SS)
    var formattedTimeSpent: String {
        let totalSeconds = Int(timeSpentMs / 1000)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    // Formatted estimate duration (e.g. "15m", "1h", "1h15m")
    var formattedEstimate: String {
        guard timeEstimateMs > 0 else { return "" }
        let totalMinutes = Int(timeEstimateMs / (60 * 1000))
        let hours = totalMinutes / 60
        let mins = totalMinutes % 60

        if hours > 0 && mins > 0 {
            return "\(hours)h\(mins)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(mins)m"
        }
    }

    var remainingEstimateSeconds: Int64 {
        let remainingMs = timeEstimateMs - timeSpentMs
        return remainingMs / 1000
    }

    // Formatted remaining time when estimate exists (counts down: 15:00 -> 14:59... e quando excede mostra o tempo total decorrido: +16:33)
    var formattedCountdown: String {
        let remainingMs = timeEstimateMs - timeSpentMs
        if remainingMs >= 0 {
            let totalSeconds = Int(remainingMs / 1000)
            let hours = totalSeconds / 3600
            let minutes = (totalSeconds % 3600) / 60
            let seconds = totalSeconds % 60
            if hours > 0 {
                return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
            } else {
                return String(format: "%02d:%02d", minutes, seconds)
            }
        } else {
            // Tempo total que está rodando com indicador de tempo excedido (+)
            // Exemplo: Tarefa de 15m rodando há 16m33s exibe "+16:33"
            let totalSpentSec = Int(timeSpentMs / 1000)
            let hours = totalSpentSec / 3600
            let minutes = (totalSpentSec % 3600) / 60
            let seconds = totalSpentSec % 60
            if hours > 0 {
                return String(format: "+%02d:%02d:%02d", hours, minutes, seconds)
            } else {
                return String(format: "+%02d:%02d", minutes, seconds)
            }
        }
    }

    var overtimeSeconds: Int {
        guard timeSpentMs > timeEstimateMs && timeEstimateMs > 0 else { return 0 }
        return Int((timeSpentMs - timeEstimateMs) / 1000)
    }

    var formattedOvertimeOnly: String {
        let sec = overtimeSeconds
        guard sec > 0 else { return "" }
        let h = sec / 3600
        let m = (sec % 3600) / 60
        let s = sec % 60
        if h > 0 {
            return String(format: "+%dh %02dm", h, m)
        } else if m > 0 {
            return String(format: "+%dm %02ds", m, s)
        } else {
            return "+\(s)s"
        }
    }

    // Displays countdown if estimate is present, e.g. "14:50 / 15m" (counts down)
    var formattedTime: String {
        if hasEstimate {
            return "\(formattedCountdown) / \(formattedEstimate)"
        }

        if remainingSeconds > 0 {
            let m = remainingSeconds / 60
            let s = remainingSeconds % 60
            return String(format: "%02d:%02d", m, s)
        }

        return formattedTimeSpent
    }

    /// Progresso da barra:
    /// - Quando tem estimativa (`timeEstimateMs > 0`): a barra DECAI (1.0 -> 0.0).
    /// - Quando NÃO tem estimativa (`timeEstimateMs == 0`): a barra AUMENTA (0.0 -> 1.0 progressivo).
    var progress: Double {
        if timeEstimateMs > 0 {
            let remainingMs = max(0, timeEstimateMs - timeSpentMs)
            return min(1.0, max(0.0, Double(remainingMs) / Double(timeEstimateMs)))
        }

        if focusDurationSeconds > 0 && remainingSeconds >= 0 {
            return min(1.0, max(0.0, 1.0 - (Double(remainingSeconds) / Double(focusDurationSeconds))))
        }

        // Sem estimativa: fluxo progressivo que aumenta
        let defaultCycleMs: Double = 25 * 60 * 1000
        let cycleProgress = Double(timeSpentMs % Int64(defaultCycleMs)) / defaultCycleMs
        return isTracking ? cycleProgress : 0.0
    }
}

