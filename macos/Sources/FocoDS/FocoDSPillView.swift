import SwiftUI
import AppKit

struct FocoDSPillView: View {
    @ObservedObject var model: FocoDSModel
    @State private var isHovering = false

    var body: some View {
        Group {
            if model.isTracking && !model.taskTitle.isEmpty {
                activeTaskView
            } else {
                habitsView
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            ZStack(alignment: .leading) {
                // Frosted Dark Glass Base (Zero black murky shadow)
                Capsule()
                    .fill(Color(red: 16/255, green: 22/255, blue: 34/255).opacity(0.86))

                // Barra de Progresso Suave (apenas se estiver em tracking)
                if model.isTracking {
                    GeometryReader { geo in
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: progressGradientColors,
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(0, geo.size.width * CGFloat(model.progress)))
                            .animation(.easeInOut(duration: 0.3), value: model.progress)
                    }
                }
            }
            .clipShape(Capsule())
        )
        .overlay(
            // Crisp 1px border stroke (pisca se finalizou foco ou alerta)
            Capsule()
                .stroke(borderStrokeColor, lineWidth: model.isPillFlashing ? 2.0 : 1.0)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                self.isHovering = hovering
            }
        }
    }

    // MARK: - Active Task View
    private var activeTaskView: some View {
        HStack(spacing: 9) {
            // Main Action Area: Drag window & Click to open Task in Super Productivity
            HStack(spacing: 9) {
                statusIndicator

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

                Rectangle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 1, height: 14)

                Text(model.formattedTime)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(timerColor)
            }
            .contentShape(Rectangle())
            .overlay(
                NativeDragAndClickHandler(onClick: {
                    model.clickTask()
                    SuperProductivityLauncher.activateSuperProductivity()
                })
            )
            .contextMenu {
                Button("Abrir no Super Productivity") {
                    model.clickTask()
                    SuperProductivityLauncher.activateSuperProductivity()
                }
                Divider()
                Menu("Definir Estimativa") {
                    Button("15 minutos") { model.setTaskEstimate(minutes: 15) }
                    Button("25 minutos") { model.setTaskEstimate(minutes: 25) }
                    Button("30 minutos") { model.setTaskEstimate(minutes: 30) }
                    Button("45 minutos") { model.setTaskEstimate(minutes: 45) }
                    Button("60 minutos (1h)") { model.setTaskEstimate(minutes: 60) }
                    Divider()
                    Button("Sem estimativa") { model.setTaskEstimate(minutes: 0) }
                }
                Divider()
                Button("Anotações da Tarefa") {
                    model.toggleSideNotes()
                }
            }

            // Minimalist Note Button (Isolated from drag handler)
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
    }

    // MARK: - Habits View (Quando não há tarefa em foco)
    private var habitsView: some View {
        HStack(spacing: 12) {
            // Subtle indicator
            Circle()
                .fill(Color.white.opacity(0.35))
                .frame(width: 6, height: 6)

            // Habit Icons from Super Productivity
            ForEach(model.habits) { habit in
                HabitButton(habit: habit) {
                    NSSound(named: "Tink")?.play()
                    model.clickHabit(habit)
                }
            }
        }
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .overlay(
            NativeDragAndClickHandler(onClick: {
                SuperProductivityLauncher.activateSuperProductivity()
            })
        )
    }

    private var statusIndicator: some View {
        ZStack {
            if model.isTracking && !model.isBreak {
                Circle()
                    .fill(statusColor.opacity(0.35))
                    .frame(width: 14, height: 14)
            }

            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)
        }
    }

    private var statusSubtitle: String {
        if model.isBreak {
            return "Em Pausa"
        }
        if model.isTracking {
            if model.hasEstimate {
                if model.isOvertime {
                    let overtimeSec = max(0, Int((model.timeSpentMs - model.timeEstimateMs) / 1000))
                    let m = overtimeSec / 60
                    let s = overtimeSec % 60
                    let overtimeStr = m > 0 ? "+\(m)m" : "+\(s)s"
                    return "Tempo Excedido • \(overtimeStr)"
                } else {
                    let pct = Int(model.progress * 100)
                    return "Estimativa • \(pct)% restante"
                }
            }
            let pct = Int(model.progress * 100)
            return "Foco Ativo • \(pct)%"
        }
        return "Hábitos"
    }

    private var progressGradientColors: [Color] {
        if model.isOvertime {
            return [
                Color(red: 239/255, green: 68/255, blue: 68/255).opacity(0.35),
                Color(red: 220/255, green: 38/255, blue: 38/255).opacity(0.18)
            ]
        }
        return [
            Color(red: 16/255, green: 185/255, blue: 129/255).opacity(0.32),
            Color(red: 5/255, green: 150/255, blue: 105/255).opacity(0.14)
        ]
    }

    private var statusColor: Color {
        if model.isBreak {
            return Color(red: 34/255, green: 211/255, blue: 238/255) // Cyan
        }
        if model.isOvertime {
            return Color(red: 239/255, green: 68/255, blue: 68/255) // Red/Coral
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
        if model.isOvertime {
            return Color(red: 248/255, green: 113/255, blue: 113/255) // Red/Coral
        }
        if model.isTracking {
            return Color(red: 52/255, green: 211/255, blue: 153/255)
        }
        return Color.white.opacity(0.7)
    }

    private var borderStrokeColor: Color {
        if model.isPillFlashing {
            return Color(red: 251/255, green: 191/255, blue: 36/255)
        }
        if model.isOvertime {
            return Color(red: 239/255, green: 68/255, blue: 68/255).opacity(0.45)
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


// Single Habit Icon Button with count badge
struct HabitButton: View {
    let habit: HabitItem
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Text(habit.emoji)
                    .font(.system(size: 15))
                    .padding(5)
                    .background(isHovered ? Color.white.opacity(0.18) : Color.white.opacity(0.06))
                    .clipShape(Circle())
                    .scaleEffect(isHovered ? 1.15 : 1.0)
                    .animation(.easeInOut(duration: 0.12), value: isHovered)

                if let count = habit.count, count > 0 {
                    Text("\(count)")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(Color(red: 16/255, green: 185/255, blue: 129/255))
                        .clipShape(Capsule())
                        .offset(x: 4, y: -3)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("\(habit.title) • Clique para registrar")
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
            onClick?()
        }
        initialMouseDownLocation = nil
        hasMoved = false
    }
}
