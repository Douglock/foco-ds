import Foundation
import SwiftUI
import Combine

@MainActor
final class FocoDSModel: ObservableObject {
    @Published var isConnected: Bool = false
    @Published var isTracking: Bool = false
    @Published var isBreak: Bool = false
    @Published var taskTitle: String = "Foco DS"
    @Published var timeSpentMs: Int64 = 0
    @Published var timeEstimateMs: Int64 = 0
    @Published var remainingSeconds: Int64 = 0
    @Published var focusDurationSeconds: Int64 = 0
    @Published var taskId: String? = nil
    @Published var lastUpdated: Date = Date()

    // Notes Sync State
    @Published var isSideNotesOpen: Bool = false
    @Published var notesText: String = ""
    @Published var isEditingNotes: Bool = false

    // Visual Flash Pulse on Pill
    @Published var isPillFlashing: Bool = false

    // Callback when notes change to send to Super Productivity
    var onNotesSaved: ((_ taskId: String, _ notes: String) -> Void)?
    var onToggleNotesPanel: (() -> Void)?

    private var timerCancellable: AnyCancellable?
    private var previousIsBreak: Bool = false
    private var previousRemaining: Int64 = 0
    private var saveDebounceWorkItem: DispatchWorkItem?

    init() {
        self.notesText = UserDefaults.standard.string(forKey: "foco_ds_side_notes") ?? ""

        // Keep local clock ticking smoothly every second
        timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, self.isTracking else { return }
                self.timeSpentMs += 1000
                if self.remainingSeconds > 0 {
                    self.remainingSeconds -= 1
                    if self.remainingSeconds == 0 {
                        self.triggerFinishedAlert()
                    }
                }
            }
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
        forceFinishedAlert: Bool = false
    ) {
        let cleanTitle = taskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        self.isConnected = true
        self.isTracking = isTracking
        self.taskTitle = cleanTitle.isEmpty ? "Foco DS" : cleanTitle
        self.timeSpentMs = max(0, timeSpentMs)
        self.timeEstimateMs = max(0, timeEstimateMs)
        self.remainingSeconds = max(0, remainingSeconds)
        if focusDurationSeconds > 0 {
            self.focusDurationSeconds = focusDurationSeconds
        }
        self.isBreak = isBreak
        self.taskId = taskId
        self.lastUpdated = Date()

        // Sync notes from Super Productivity if not actively editing
        if let incomingNotes = taskNotes, !self.isEditingNotes {
            if incomingNotes != self.notesText {
                self.notesText = incomingNotes
            }
        }

        // Trigger finish alert if transition happened
        if forceFinishedAlert || (!previousIsBreak && isBreak) || (previousRemaining > 0 && remainingSeconds == 0 && isTracking) {
            triggerFinishedAlert()
        }

        self.previousIsBreak = isBreak
        self.previousRemaining = remainingSeconds
    }

    func triggerFinishedAlert() {
        ScreenFlashController.triggerFocusFinishedAlert()

        // Flash pill border
        withAnimation(.easeInOut(duration: 0.15).repeatCount(4, autoreverses: true)) {
            self.isPillFlashing = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            self.isPillFlashing = false
        }
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

    var formattedTime: String {
        if remainingSeconds > 0 {
            let m = remainingSeconds / 60
            let s = remainingSeconds % 60
            return String(format: "%02d:%02d", m, s)
        }

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

    var progress: Double {
        if timeEstimateMs > 0 {
            return min(1.0, max(0.0, Double(timeSpentMs) / Double(timeEstimateMs)))
        }
        if focusDurationSeconds > 0 && remainingSeconds >= 0 {
            return min(1.0, max(0.0, 1.0 - (Double(remainingSeconds) / Double(focusDurationSeconds))))
        }
        let defaultCycleMs: Double = 25 * 60 * 1000
        let cycleProgress = Double(timeSpentMs % Int64(defaultCycleMs)) / defaultCycleMs
        return isTracking ? cycleProgress : 0.0
    }
}
