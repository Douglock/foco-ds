import SwiftUI
import AppKit

struct FocoDSPillView: View {
    @ObservedObject var model: FocoDSModel
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 10) {
            // Status Dot
            statusDot

            // Task Title
            Text(model.taskTitle)
                .font(.system(size: 13, weight: .medium, design: .default))
                .foregroundColor(.white.opacity(0.92))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: 220, alignment: .leading)

            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 1, height: 14)

            // Time Spent Display
            Text(model.formattedTime)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(timerColor)

            // Minimal Arrow indicator on hover
            if isHovering {
                Image(systemName: "arrow.up.forward.app")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            ZStack(alignment: .bottom) {
                // Blur Glass background
                Capsule()
                    .fill(Color(red: 14/255, green: 18/255, blue: 28/255).opacity(0.88))
                    .overlay(
                        Capsule()
                            .stroke(borderColor, lineWidth: 1)
                    )

                // Optional Bottom Progress Bar
                if model.timeEstimateMs > 0 {
                    GeometryReader { geo in
                        Capsule()
                            .fill(Color(red: 16/255, green: 185/255, blue: 129/255).opacity(0.65))
                            .frame(width: geo.size.width * CGFloat(model.progress), height: 2)
                    }
                    .frame(height: 2)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 1)
                }
            }
        )
        .shadow(color: Color.black.opacity(0.45), radius: 12, x: 0, y: 4)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                self.isHovering = hovering
            }
        }
        .overlay(
            // Native Window Drag & Click Handler
            NativeDragAndClickHandler(onClick: {
                SuperProductivityLauncher.activateSuperProductivity()
            })
        )
        .help("Foco DS • Clique para abrir Super Productivity")
    }

    private var statusDot: some View {
        ZStack {
            if model.isTracking && !model.isBreak {
                Circle()
                    .fill(Color(red: 16/255, green: 185/255, blue: 129/255).opacity(0.35))
                    .frame(width: 14, height: 14)
            }

            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
        }
    }

    private var statusColor: Color {
        if !model.isConnected {
            return Color.gray.opacity(0.6)
        }
        if model.isBreak {
            return Color(red: 34/255, green: 211/255, blue: 238/255) // Cyan
        }
        if model.isTracking {
            return Color(red: 16/255, green: 185/255, blue: 129/255) // Emerald
        }
        return Color.white.opacity(0.4)
    }

    private var timerColor: Color {
        if model.isBreak {
            return Color(red: 34/255, green: 211/255, blue: 238/255)
        }
        if model.isTracking {
            return Color(red: 52/255, green: 211/255, blue: 153/255)
        }
        return Color.white.opacity(0.65)
    }

    private var borderColor: Color {
        if isHovering {
            return Color(red: 16/255, green: 185/255, blue: 129/255).opacity(0.45)
        }
        if model.isTracking && !model.isBreak {
            return Color(red: 16/255, green: 185/255, blue: 129/255).opacity(0.25)
        }
        return Color.white.opacity(0.12)
    }
}

/// Native zero-lag macOS Window Drag & Single Click NSView
struct NativeDragAndClickHandler: NSViewRepresentable {
    let onClick: () -> Void

    func makeNSView(context: Context) -> DragClickNSView {
        let view = DragClickNSView()
        view.onClick = onClick
        return view
    }

    func updateNSView(_ nsView: DragClickNSView, context: Context) {
        nsView.onClick = onClick
    }
}

final class DragClickNSView: NSView {
    var onClick: (() -> Void)?
    private var initialMouseDownLocation: NSPoint?
    private var hasMoved = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func mouseDown(with event: NSEvent) {
        initialMouseDownLocation = event.locationInWindow
        hasMoved = false
    }

    override func mouseDragged(with event: NSEvent) {
        hasMoved = true
        window?.performDrag(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        if !hasMoved {
            // Click without dragging: activate Super Productivity!
            onClick?()
        }
        initialMouseDownLocation = nil
        hasMoved = false
    }
}
