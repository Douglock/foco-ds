import Foundation
import AppKit

@MainActor
final class ScreenFlashController {
    private static var lastAlertTime: Date = .distantPast

    static func triggerFocusFinishedAlert() {
        // Debounce alert to avoid repetitive firing
        guard Date().timeIntervalSince(lastAlertTime) > 3.0 else { return }
        lastAlertTime = Date()

        // 1. Play completion sound
        playCompletionSound()

        // 2. Flash screen
        flashScreen()
    }

    static func playCompletionSound() {
        if let sound = NSSound(named: "Hero") ?? NSSound(named: "Glass") {
            sound.play()
        } else {
            NSSound.beep()
        }
    }

    static func flashScreen() {
        guard let screen = NSScreen.main else { return }

        let flashWindow = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        flashWindow.level = .screenSaver
        flashWindow.isOpaque = false
        flashWindow.backgroundColor = NSColor.white.withAlphaComponent(0.38)
        flashWindow.ignoresMouseEvents = true
        flashWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        flashWindow.alphaValue = 1.0

        flashWindow.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.55
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            flashWindow.animator().alphaValue = 0.0
        } completionHandler: {
            flashWindow.orderOut(nil)
        }
    }
}
