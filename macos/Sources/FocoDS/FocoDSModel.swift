import Foundation
import SwiftUI
import Combine

struct HabitItem: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let emoji: String
    let count: Int?
    let isOn: Bool?
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

    // Visual Flash Pulse on Pill
    @Published var isPillFlashing: Bool = false

    // Callbacks to send commands to Super Productivity
    var onNotesSaved: ((_ taskId: String, _ notes: String) -> Void)?
    var onToggleNotesPanel: (() -> Void)?
    var onHabitClicked: ((_ habitId: String) -> Void)?
    var onTaskClicked: ((_ taskId: String?) -> Void)?
    var onUpdateEstimate: ((_ taskId: String, _ estimateMs: Int64) -> Void)?

    private var timerCancellable: AnyCancellable?
    private var previousIsTracking: Bool = false
    private var previousIsBreak: Bool = false
    private var previousRemaining: Int64 = 0
    private var hasAlertedOvertimeTaskId: String? = nil
    private var saveDebounceWorkItem: DispatchWorkItem?

    init() {
        self.notesText = UserDefaults.standard.string(forKey: "foco_ds_side_notes") ?? ""

        // Local clock ticking smoothly every second
        timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, self.isTracking else { return }
                self.timeSpentMs += 1000

                // Check if estimate was just exceeded
                if self.hasEstimate && self.isOvertime && self.hasAlertedOvertimeTaskId != self.taskId {
                    self.hasAlertedOvertimeTaskId = self.taskId
                    self.triggerOvertimeAlert()
                }

                if self.remainingSeconds > 0 {
                    self.remainingSeconds -= 1
                    if self.remainingSeconds == 0 {
                        self.triggerOvertimeAlert()
                    }
                }
            }
    }

    var hasEstimate: Bool {
        return timeEstimateMs > 0
    }

    var isOvertime: Bool {
        return hasEstimate && timeSpentMs >= timeEstimateMs
    }

    func update(
        isTracking: Bool,
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

        if taskChanged {
            self.hasAlertedOvertimeTaskId = nil
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

        // 1. Trigger Green Screen Flash when user hits PLAY
        if triggerPlayFlash || (!wasTracking && newlyTracking) {
            ScreenFlashController.triggerPlayFlash()
        }

        // 2. Trigger Red Screen Flash when estimate is exceeded or focus finished
        if triggerOvertimeFlash || forceFinishedAlert || (!previousIsBreak && isBreak) {
            triggerOvertimeAlert()
        } else if self.hasEstimate && self.isOvertime && self.hasAlertedOvertimeTaskId != self.taskId {
            self.hasAlertedOvertimeTaskId = self.taskId
            triggerOvertimeAlert()
        }

        self.previousIsTracking = newlyTracking
        self.previousIsBreak = isBreak
        self.previousRemaining = remainingSeconds
    }

    func triggerOvertimeAlert() {
        ScreenFlashController.triggerOvertimeFlash()

        // Flash pill border with warning pulse
        withAnimation(.easeInOut(duration: 0.15).repeatCount(4, autoreverses: true)) {
            self.isPillFlashing = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            self.isPillFlashing = false
        }
    }

    func triggerFinishedAlert() {
        triggerOvertimeAlert()
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

    // Displays both spent and estimate if present, e.g. "33:03 / 15m"
    var formattedTime: String {
        if hasEstimate {
            return "\(formattedTimeSpent) / \(formattedEstimate)"
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

