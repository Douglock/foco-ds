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
    @Published var taskId: String? = nil
    @Published var lastUpdated: Date = Date()
    
    // Auto increment timer when tracking is active
    private var timerCancellable: AnyCancellable?

    init() {
        // Increment timeSpentMs every second locally when tracking to keep clock smooth
        timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, self.isTracking else { return }
                self.timeSpentMs += 1000
            }
    }

    func update(
        isTracking: Bool,
        taskTitle: String,
        timeSpentMs: Int64,
        timeEstimateMs: Int64 = 0,
        isBreak: Bool = false,
        taskId: String? = nil
    ) {
        self.isConnected = true
        self.isTracking = isTracking
        self.taskTitle = taskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Foco DS" : taskTitle
        self.timeSpentMs = max(0, timeSpentMs)
        self.timeEstimateMs = max(0, timeEstimateMs)
        self.isBreak = isBreak
        self.taskId = taskId
        self.lastUpdated = Date()
    }

    var formattedTime: String {
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
        guard timeEstimateMs > 0 else { return 0.0 }
        return min(1.0, max(0.0, Double(timeSpentMs) / Double(timeEstimateMs)))
    }
}
