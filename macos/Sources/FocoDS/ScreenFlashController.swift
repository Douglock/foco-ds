import Foundation
import AppKit
import SwiftUI

@MainActor
final class ScreenFlashController {
    private static var lastAlertTime: Date = .distantPast
    private static var lastPlayFlashTime: Date = .distantPast

    /// Flash screen edges in Green when Play is pressed on a task
    static func triggerPlayFlash(playSound: Bool = true) {
        guard !AppDelegate.isMenuOpen else { return }
        guard Date().timeIntervalSince(lastPlayFlashTime) > 0.8 else { return }
        lastPlayFlashTime = Date()

        if playSound {
            playStartFocusSound()
        }

        let greenColor = NSColor(red: 16/255, green: 185/255, blue: 129/255, alpha: 0.95)
        flashScreenEdges(color: greenColor, duration: 1.0)
    }

    /// Flash screen edges in Red when time estimate is reached / exceeded or focus finished
    static func triggerOvertimeFlash(playSound: Bool = true) {
        guard !AppDelegate.isMenuOpen else { return }
        guard Date().timeIntervalSince(lastAlertTime) > 15.0 else { return }
        lastAlertTime = Date()

        if playSound {
            playAlertSound()
        }

        let redColor = NSColor(red: 239/255, green: 68/255, blue: 68/255, alpha: 0.95)
        flashScreenEdges(color: redColor, duration: 1.0)
    }

    /// Focus Start Sound (Submarine chime symbolizing entering deep focus)
    static func playStartFocusSound() {
        if let sound = NSSound(named: "Submarine") ?? NSSound(named: "Blow") {
            sound.play()
        } else {
            NSSound(named: "Ping")?.play()
        }
    }

    /// Alert sound for overtime / finished
    static func playAlertSound() {
        if let sound = NSSound(named: "Hero") ?? NSSound(named: "Glass") {
            sound.play()
        } else {
            NSSound.beep()
        }
    }

    /// Edge Glow: Glows only along the 4 borders of the screen with smooth fade out
    static func flashScreenEdges(color: NSColor, duration: TimeInterval = 1.0) {
        guard !AppDelegate.isMenuOpen else { return }
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }

        let swiftColor = Color(color)

        for screen in screens {
            let flashWindow = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )

            flashWindow.level = .screenSaver
            flashWindow.isOpaque = false
            flashWindow.backgroundColor = .clear
            flashWindow.ignoresMouseEvents = true
            flashWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            flashWindow.alphaValue = 1.0

            let glowView = EdgeGlowOverlayView(color: swiftColor)
            flashWindow.contentView = NSHostingView(rootView: glowView)

            flashWindow.orderFrontRegardless()

            NSAnimationContext.runAnimationGroup { context in
                context.duration = duration
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                flashWindow.animator().alphaValue = 0.0
            } completionHandler: {
                flashWindow.orderOut(nil)
            }
        }
    }
}

/// SwiftUI View rendering glowing ambient borders
struct EdgeGlowOverlayView: View {
    let color: Color

    var body: some View {
        GeometryReader { _ in
            ZStack {
                Color.clear

                // Outer soft blur glow (ambient light emanating inward)
                RoundedRectangle(cornerRadius: 16)
                    .stroke(color.opacity(0.75), lineWidth: 28)
                    .blur(radius: 20)

                // Middle intense aura
                RoundedRectangle(cornerRadius: 16)
                    .stroke(color.opacity(0.9), lineWidth: 10)
                    .blur(radius: 8)

                // Crisp neon perimeter edge
                RoundedRectangle(cornerRadius: 16)
                    .stroke(color, lineWidth: 3.5)
            }
            .padding(1)
        }
        .edgesIgnoringSafeArea(.all)
    }
}


