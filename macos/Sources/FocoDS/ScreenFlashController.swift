import Foundation
import AppKit

@MainActor
final class ScreenFlashController {
    private static var lastAlertTime: Date = .distantPast
    private static var lastPlayFlashTime: Date = .distantPast

    /// Flash screen in Green when Play is pressed on a task
    static func triggerPlayFlash() {
        guard Date().timeIntervalSince(lastPlayFlashTime) > 0.8 else { return }
        lastPlayFlashTime = Date()

        let greenColor = NSColor(red: 16/255, green: 185/255, blue: 129/255, alpha: 0.38)
        flashScreen(color: greenColor, duration: 0.45)
    }

    /// Flash screen in Red when time estimate is reached / exceeded or focus finished
    static func triggerOvertimeFlash() {
        guard Date().timeIntervalSince(lastAlertTime) > 2.0 else { return }
        lastAlertTime = Date()

        playAlertSound()

        let redColor = NSColor(red: 239/255, green: 68/255, blue: 68/255, alpha: 0.48)
        flashScreen(color: redColor, duration: 0.6)
    }

    /// Legacy / General Focus Finished Alert
    static func triggerFocusFinishedAlert() {
        triggerOvertimeFlash()
    }

    static func playAlertSound() {
        if let sound = NSSound(named: "Hero") ?? NSSound(named: "Glass") {
            sound.play()
        } else {
            NSSound.beep()
        }
    }

    static func flashScreen(color: NSColor, duration: TimeInterval = 0.5) {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }

        for screen in screens {
            let flashWindow = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )

            flashWindow.level = .screenSaver
            flashWindow.isOpaque = false
            flashWindow.backgroundColor = color
            flashWindow.ignoresMouseEvents = true
            flashWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            flashWindow.alphaValue = 1.0

            flashWindow.orderFrontRegardless()

            NSAnimationContext.runAnimationGroup { context in
                context.duration = duration
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                flashWindow.animator().alphaValue = 0.0
            } completionHandler: {
                flashWindow.orderOut(nil)
            }
        }
    }
}

