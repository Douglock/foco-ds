import SwiftUI
import AppKit

struct FocoDSPillView: View {
    @ObservedObject var model: FocoDSModel
    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Main Pill HUD
            mainPill

            // Minimalist Side Notes Drawer
            if model.isSideNotesOpen {
                SideNotesView(model: model)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .trailing)),
                        removal: .opacity.combined(with: .scale(scale: 0.95))
                    ))
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.8), value: model.isSideNotesOpen)
    }

    private var mainPill: some View {
        HStack(spacing: 10) {
            // Status Dot / Target Icon
            statusIndicator

            // Active Task Title (Tarefa em foco aparecendo)
            VStack(alignment: .leading, spacing: 1) {
                Text(model.taskTitle)
                    .font(.system(size: 13, weight: .semibold, design: .default))
                    .foregroundColor(.white.opacity(0.95))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 220, alignment: .leading)

                // Subtitle: Status / Mode
                Text(statusSubtitle)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(statusColor.opacity(0.85))
            }

            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 1, height: 16)

            // Time Clock Display
            Text(model.formattedTime)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(timerColor)

            // Side Notes Toggle Button
            Button(action: {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                    model.toggleSideNotes()
                }
            }) {
                HStack(spacing: 3) {
                    Text("📝")
                        .font(.system(size: 11))
                    if !model.notesText.isEmpty {
                        Circle()
                            .fill(Color(red: 16/255, green: 185/255, blue: 129/255))
                            .frame(width: 5, height: 5)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(model.isSideNotesOpen ? Color.white.opacity(0.18) : Color.white.opacity(0.06))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .help("Anotações minimalistas na lateral")

            // Minimal Arrow indicator on hover
            if isHovering {
                Image(systemName: "arrow.up.forward.app")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            ZStack(alignment: .leading) {
                // 1. Base dark blur glass
                Capsule()
                    .fill(Color(red: 14/255, green: 18/255, blue: 28/255).opacity(0.88))

                // 2. Barra de Progresso no Fundo (Background Fill)
                GeometryReader { geo in
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 16/255, green: 185/255, blue: 129/255).opacity(0.35),
                                    Color(red: 5/255, green: 150/255, blue: 105/255).opacity(0.15)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(model.progress))
                        .animation(.easeInOut(duration: 0.3), value: model.progress)
                }

                // 3. Border Stroke (com piscar visual quando finaliza foco)
                Capsule()
                    .stroke(borderStrokeColor, lineWidth: model.isPillFlashing ? 2.5 : 1)
            }
        )
        .overlay(
            // 4. Barra de Progresso Fina Inferior
            VStack {
                Spacer()
                GeometryReader { geo in
                    Capsule()
                        .fill(Color(red: 16/255, green: 185/255, blue: 129/255))
                        .frame(width: max(0, geo.size.width * CGFloat(model.progress)), height: 2)
                        .animation(.easeInOut(duration: 0.3), value: model.progress)
                }
                .frame(height: 2)
                .padding(.horizontal, 10)
                .padding(.bottom, 1)
            }
        )
        .shadow(color: shadowColor, radius: 14, x: 0, y: 5)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                self.isHovering = hovering
            }
        }
        .overlay(
            // Native Window Drag & Click Handler (except over notes button)
            NativeDragAndClickHandler(onClick: {
                SuperProductivityLauncher.activateSuperProductivity()
            })
            .allowsHitTesting(!model.isSideNotesOpen)
        )
        .help("Foco DS • Clique para abrir Super Productivity")
    }

    private var statusIndicator: some View {
        ZStack {
            if model.isTracking && !model.isBreak {
                Circle()
                    .fill(Color(red: 16/255, green: 185/255, blue: 129/255).opacity(0.35))
                    .frame(width: 16, height: 16)
                    .scaleEffect(model.isTracking ? 1.15 : 1.0)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: model.isTracking)
            }

            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
        }
    }

    private var statusSubtitle: String {
        if !model.isConnected {
            return "Ocioso"
        }
        if model.isBreak {
            return "Em Pausa"
        }
        if model.isTracking {
            let pct = Int(model.progress * 100)
            return "Foco Ativo • \(pct)%"
        }
        return "Pronto"
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
        return Color.white.opacity(0.7)
    }

    private var borderStrokeColor: Color {
        if model.isPillFlashing {
            return Color(red: 251/255, green: 191/255, blue: 36/255) // Flash amber/gold
        }
        if isHovering {
            return Color(red: 16/255, green: 185/255, blue: 129/255).opacity(0.55)
        }
        if model.isTracking && !model.isBreak {
            return Color(red: 16/255, green: 185/255, blue: 129/255).opacity(0.3)
        }
        return Color.white.opacity(0.12)
    }

    private var shadowColor: Color {
        if model.isPillFlashing {
            return Color(red: 251/255, green: 191/255, blue: 36/255).opacity(0.6)
        }
        return Color.black.opacity(0.45)
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
