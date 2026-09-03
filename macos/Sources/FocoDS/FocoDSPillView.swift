import SwiftUI
import AppKit

struct FocoDSPillView: View {
    @ObservedObject var model: FocoDSModel
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 9) {
            // Main Action Area: Drag window & Click to open Super Productivity
            HStack(spacing: 9) {
                // 1. Single Refined Status Dot
                statusIndicator

                // 2. Tarefa em Foco
                VStack(alignment: .leading, spacing: 1) {
                    Text(model.taskTitle)
                        .font(.system(size: 12.5, weight: .semibold, design: .default))
                        .foregroundColor(.white.opacity(0.95))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: 200, alignment: .leading)

                    Text(statusSubtitle)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(statusColor.opacity(0.85))
                }

                // 3. Subtle Divider
                Rectangle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 1, height: 14)

                // 4. Digital Time Clock
                Text(model.formattedTime)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(timerColor)
            }
            .contentShape(Rectangle())
            .overlay(
                // Native Window Drag & Click to open Super Productivity
                NativeDragAndClickHandler(onClick: {
                    SuperProductivityLauncher.activateSuperProductivity()
                })
            )

            // 5. Minimalist Note Button (ISOLATED - NOT COVERED BY DRAG/CLICK HANDLER)
            Button(action: {
                model.toggleSideNotes()
            }) {
                ZStack(alignment: .topTrailing) {
                    Text("📝")
                        .font(.system(size: 12))
                        .padding(5)
                        .background(model.isSideNotesOpen ? Color.white.opacity(0.24) : Color.white.opacity(0.08))
                        .cornerRadius(6)

                    if !model.notesText.isEmpty {
                        Circle()
                            .fill(Color(red: 16/255, green: 185/255, blue: 129/255))
                            .frame(width: 5, height: 5)
                            .offset(x: 2, y: -2)
                    }
                }
            }
            .buttonStyle(.plain)
            .help("Anotações da Tarefa (Clique para abrir/fechar)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            ZStack(alignment: .leading) {
                // Frosted Dark Glass Base (Zero black murky shadow)
                Capsule()
                    .fill(Color(red: 16/255, green: 22/255, blue: 34/255).opacity(0.86))

                // Barra de Progresso Suave no Fundo
                GeometryReader { geo in
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 16/255, green: 185/255, blue: 129/255).opacity(0.32),
                                    Color(red: 5/255, green: 150/255, blue: 105/255).opacity(0.14)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geo.size.width * CGFloat(model.progress)))
                        .animation(.easeInOut(duration: 0.3), value: model.progress)
                }

                // Linha de Progresso Fina na Base
                VStack {
                    Spacer()
                    GeometryReader { geo in
                        Capsule()
                            .fill(Color(red: 16/255, green: 185/255, blue: 129/255))
                            .frame(width: max(0, geo.size.width * CGFloat(model.progress)), height: 2)
                            .animation(.easeInOut(duration: 0.3), value: model.progress)
                    }
                    .frame(height: 2)
                }
            }
            .clipShape(Capsule())
        )
        .overlay(
            // Crisp 1px border stroke (pisca se finalizou foco)
            Capsule()
                .stroke(borderStrokeColor, lineWidth: model.isPillFlashing ? 2.0 : 1.0)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                self.isHovering = hovering
            }
        }
    }

    private var statusIndicator: some View {
        ZStack {
            if model.isTracking && !model.isBreak {
                Circle()
                    .fill(Color(red: 16/255, green: 185/255, blue: 129/255).opacity(0.35))
                    .frame(width: 14, height: 14)
            }

            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)
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
            return Color(red: 16/255, green: 185/255, blue: 129/255).opacity(0.28)
        }
        return Color.white.opacity(0.14)
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
