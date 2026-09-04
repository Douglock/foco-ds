import SwiftUI
import AppKit

struct FocoDSPillView: View {
    @ObservedObject var model: FocoDSModel
    @State private var isHovering = false
    @State private var showTooltipCard = false
    @State private var dragInitialWidth: CGFloat? = nil

    var body: some View {
        Group {
            if model.visualStyle == "lateral" {
                LateralDockView(model: model)
            } else if model.isCompactCircle {
                compactCircleView
            } else if model.visualStyle == "circular" {
                circularGaugeContainer
            } else {
                classicPillContainer
            }
        }
    }

    // MARK: - Modo 1: Círculo Compacto ("Diminuir até o ponto de ver apenas o círculo")
    private var compactCircleView: some View {
        ZStack {
            // Background dark disc
            Circle()
                .fill(Color(red: 16/255, green: 22/255, blue: 34/255).opacity(model.pillOpacity))
                .frame(width: 38, height: 38)

            // Idle Reminder Breathing Glow
            if model.isIdleReminderActive {
                Circle()
                    .stroke(Color(red: 255/255, green: 180/255, blue: 0/255).opacity(0.7), lineWidth: 2)
                    .scaleEffect(1.12)
            }

            // Tracking Active: Glowing circular ring around icon
            if model.isTracking {
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 2.8)
                    .frame(width: 32, height: 32)

                Circle()
                    .trim(from: 0, to: max(0.04, min(1.0, model.progress)))
                    .stroke(
                        statusColor,
                        style: StrokeStyle(lineWidth: 2.8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 32, height: 32)
                    .animation(.easeInOut(duration: 0.3), value: model.progress)

                ClaudeStarburst(size: 13, color: .white)
            } else if model.isPaused {
                // Paused State: Amber pause ring
                Circle()
                    .stroke(Color(red: 255/255, green: 180/255, blue: 0/255), lineWidth: 2.2)
                    .frame(width: 32, height: 32)

                Image(systemName: "pause.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(red: 255/255, green: 180/255, blue: 0/255))
            } else {
                // Idle / Habits State
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 2.0)
                    .frame(width: 30, height: 30)

                Text(model.isIdleReminderActive ? "⚡" : "🎯")
                    .font(.system(size: 13))
            }
        }
        .frame(width: 42, height: 40)
        .contentShape(Circle())
        .overlay(
            Circle()
                .stroke(borderStrokeColor, lineWidth: 1.0)
        )
        .overlay(
            NativeDragAndClickHandler(onClick: {
                if model.isPaused {
                    model.resumeCurrentTask()
                } else {
                    model.toggleCompactCircle()
                }
            })
        )
        .help(compactTooltipText)
    }

    private var compactTooltipText: String {
        if model.isTracking {
            return "\(model.taskTitle) (\(model.formattedTime)) • Clique para expandir"
        }
        if model.isPaused {
            return "Pausado: \(model.taskTitle) (\(model.formattedTime)) • Clique para retomar"
        }
        if model.isIdleReminderActive {
            return "⚡ \(model.idleMinutesWithoutFocus)m sem foco • Clique para expandir"
        }
        return "Foco DS • Clique para expandir"
    }

    // MARK: - Modo 2: Pílula Clássica HUD (Largura Ajustável)
    // MARK: - Modo 2: Pílula Clássica HUD (Largura Ajustável)
    private var classicPillContainer: some View {
        HStack(spacing: 0) {
            Group {
                if (model.isTracking || model.isPaused) && !model.taskTitle.isEmpty {
                    classicActiveTaskView
                } else {
                    classicHabitsView
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
        }
        .background(
            ZStack(alignment: .leading) {
                // Fundo Escuro com Opacidade Regulável
                Capsule()
                    .fill(Color(red: 16/255, green: 22/255, blue: 34/255).opacity(model.pillOpacity))

                // Barra de Progresso Suave (Tracking verde / Pausado âmbar / Overtime vermelho)
                if model.isTracking || model.isPaused {
                    GeometryReader { geo in
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: progressGradientColors,
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(0, geo.size.width * CGFloat(model.isOvertime ? 1.0 : model.progress)))
                            .animation(.easeInOut(duration: 0.3), value: model.progress)
                    }
                }
            }
            .clipShape(Capsule())
        )
        .overlay(
            Capsule()
                .stroke(borderStrokeColor, lineWidth: model.isPillFlashing ? 2.0 : 1.0)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                self.isHovering = hovering
            }
        }
        .onTapGesture(count: 2) {
            autoFitTitleWidth()
        }
    }

    // MARK: - Classic Active Task View (Suporta todo título e tempo estimado sem cortes)
    private var classicActiveTaskView: some View {
        HStack(spacing: 9) {
            HStack(spacing: 9) {
                statusIndicator

                // Título e Subtítulo (Espaço flexível para ver todo o título)
                VStack(alignment: .leading, spacing: 1) {
                    Text(model.taskTitle)
                        .font(.system(size: 12.5, weight: .semibold, design: .default))
                        .foregroundColor(.white.opacity(0.95))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(minWidth: 80, maxWidth: .infinity, alignment: .leading)
                        .help("\(model.taskTitle) • Clique duplo para ajustar largura automaticamente")

                    Text(statusSubtitle)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(statusColor.opacity(0.92))
                }

                Rectangle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 1, height: 14)

                // Tempo e Estimativa formatados (fixedSize garante que NUNCA será cortado!)
                Text(model.formattedTime)
                    .font(.system(size: 12.5, weight: .bold, design: .monospaced))
                    .foregroundColor(timerColor)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .contentShape(Rectangle())
            .overlay(
                NativeDragAndClickHandler(onClick: {
                    if model.isPaused {
                        model.resumeCurrentTask()
                    } else {
                        model.clickTask()
                        SuperProductivityLauncher.activateSuperProductivity()
                    }
                })
            )

            // Botão de Ajuste Rápido de Largura (↔️) - SÓ APARECE NO HOVER!
            if isHovering {
                Button(action: {
                    cyclePillWidth()
                }) {
                    Image(systemName: "arrow.left.and.right")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(5)
                        .background(Color.white.opacity(0.12))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
                .help("Ajustar tamanho (\(Int(model.pillWidth))px) • Clique para alternar ou diminuir até a Bolinha")
            }

            // Minimalist Note Button (📝)
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

    // MARK: - Classic Habits View
    private var classicHabitsView: some View {
        HStack(spacing: 12) {
            Button(action: {
                model.toggleCompactCircle()
            }) {
                Circle()
                    .fill(model.isIdleReminderActive ? Color(red: 255/255, green: 180/255, blue: 0/255) : Color.white.opacity(0.35))
                    .frame(width: 8, height: 8)
            }
            .buttonStyle(.plain)
            .help("Clique para diminuir para Bolinha / Círculo")

            if model.isIdleReminderActive {
                Text("⚡ \(model.idleMinutesWithoutFocus)m sem foco • Clique para iniciar")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(red: 255/255, green: 195/255, blue: 70/255))
                    .onTapGesture {
                        model.toggleTaskCreateCard()
                    }
            } else {
                ForEach(model.habits) { habit in
                    HabitButton(habit: habit) {
                        NSSound(named: "Tink")?.play()
                        model.clickHabit(habit)
                    }
                }
            }

            // Botão de Ajuste Rápido de Largura - SÓ APARECE NO HOVER também nos hábitos!
            if isHovering {
                Button(action: {
                    cyclePillWidth()
                }) {
                    Image(systemName: "arrow.left.and.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white.opacity(0.75))
                        .padding(4)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(5)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
                .help("Ajustar tamanho (\(Int(model.pillWidth))px) • Clique para alternar ou diminuir até a Bolinha")
            }
        }
        .padding(.horizontal, 4)
    }

    private func cyclePillWidth() {
        if model.isCompactCircle {
            // Se já for a bolinha, expande para a pílula padrão
            model.isCompactCircle = false
            model.setPillWidth(480)
        } else if model.pillWidth < 400 {
            // De compacto (360px) -> diminui até a BOLINHA!
            model.isCompactCircle = true
        } else if model.pillWidth < 520 {
            // De padrão (480px) -> vai para Amplo (620px - cabe todo o título e tempo)
            model.setPillWidth(620)
        } else if model.pillWidth < 680 {
            // De amplo (620px) -> vai para Máximo (740px)
            model.setPillWidth(740)
        } else {
            // De máximo (740px) -> vai para Compacto (360px)
            model.setPillWidth(360)
        }
        UserDefaults.standard.set(Double(model.pillWidth), forKey: "foco_ds_pill_width")
        UserDefaults.standard.set(model.isCompactCircle, forKey: "foco_ds_compact_circle")
    }

    private func autoFitTitleWidth() {
        guard !model.taskTitle.isEmpty else { return }
        if model.isCompactCircle {
            model.isCompactCircle = false
        }
        let titleLen = CGFloat(model.taskTitle.count)
        let needed = max(420, min(800, titleLen * 8.5 + 290))
        model.setPillWidth(needed)
        UserDefaults.standard.set(Double(needed), forKey: "foco_ds_pill_width")
    }

    // MARK: - Estilo 2: Anéis Horizontais
    private var circularGaugeContainer: some View {
        HStack(spacing: 11) {
            if (model.isTracking || model.isPaused) && !model.taskTitle.isEmpty {
                CircularItemGauge(
                    icon: model.isPaused ? "⏸" : "🎯",
                    progress: model.progress,
                    color: statusColor,
                    percentageText: "\(Int(model.progress * 100))%",
                    tooltipTitle: model.taskTitle,
                    tooltipSubtitle: model.formattedTime
                ) {
                    if model.isPaused {
                        model.resumeCurrentTask()
                    } else {
                        model.clickTask()
                        SuperProductivityLauncher.activateSuperProductivity()
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(model.taskTitle)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.95))
                        .lineLimit(1)
                        .frame(minWidth: 100, maxWidth: .infinity, alignment: .leading)

                    Text(model.formattedTime)
                        .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                        .foregroundColor(timerColor)
                        .fixedSize(horizontal: true, vertical: false)
                }

                Rectangle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 1, height: 16)

                Button(action: { model.toggleSideNotes() }) {
                    ZStack(alignment: .topTrailing) {
                        Text("📝")
                            .font(.system(size: 12))
                            .padding(4)
                            .background(model.isSideNotesOpen ? Color.white.opacity(0.24) : Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                }
                .buttonStyle(.plain)
            } else {
                ForEach(model.habits) { habit in
                    let count = habit.count ?? 0
                    let pct = min(1.0, Double(count) / 5.0)
                    let pctInt = Int(pct * 100)

                    CircularItemGauge(
                        icon: habit.emoji,
                        progress: pct,
                        color: habitColor(for: habit.id),
                        percentageText: "\(pctInt)%",
                        tooltipTitle: habit.title,
                        tooltipSubtitle: "\(count) registrados hoje"
                    ) {
                        NSSound(named: "Tink")?.play()
                        model.clickHabit(habit)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            ZStack {
                Capsule()
                    .fill(Color.black.opacity(model.pillOpacity))

                Capsule()
                    .stroke(borderStrokeColor, lineWidth: 1.0)
            }
        )
    }

    // MARK: - Status Helpers

    // MARK: - Status Helpers
    private var statusIndicator: some View {
        Button(action: {
            if model.isPaused {
                model.resumeCurrentTask()
            } else {
                model.toggleCompactCircle()
            }
        }) {
            ZStack {
                if model.isPaused {
                    Circle()
                        .fill(Color(red: 255/255, green: 180/255, blue: 0/255).opacity(0.22))
                        .frame(width: 18, height: 18)

                    Circle()
                        .stroke(Color(red: 255/255, green: 180/255, blue: 0/255), lineWidth: 1.8)
                        .frame(width: 15, height: 15)

                    Image(systemName: "pause.fill")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(Color(red: 255/255, green: 180/255, blue: 0/255))
                } else {
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
        }
        .buttonStyle(.plain)
        .help(model.isPaused ? "Pausado • Clique para retomar" : "Clique para diminuir para Círculo")
    }

    private var statusSubtitle: String {
        if model.isPaused {
            return "Pausado • Clique para retomar"
        }
        if model.isBreak {
            return "Em Pausa"
        }
        if model.isTracking {
            if model.hasEstimate {
                if model.isOvertime {
                    let overtimeStr = model.formattedOvertimeOnly.isEmpty ? "+1s" : model.formattedOvertimeOnly
                    return "Tempo Excedido • \(overtimeStr)"
                } else {
                    let pct = Int(model.progress * 100)
                    return "Estimativa • \(pct)% restante"
                }
            }
            let pct = Int(model.progress * 100)
            return "Foco Ativo • \(pct)%"
        }
        if model.isIdleReminderActive {
            return "⚡ \(model.idleMinutesWithoutFocus)m sem foco • Retomar?"
        }
        return "Hábitos"
    }

    private var progressGradientColors: [Color] {
        if model.isPaused {
            return [
                Color(red: 255/255, green: 180/255, blue: 0/255).opacity(0.35),
                Color(red: 245/255, green: 158/255, blue: 11/255).opacity(0.18)
            ]
        }
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
        if model.isPaused {
            return Color(red: 255/255, green: 180/255, blue: 0/255) // Amber
        }
        if model.isBreak {
            return Color(red: 34/255, green: 211/255, blue: 238/255) // Cyan
        }
        if model.isOvertime {
            return Color(red: 239/255, green: 68/255, blue: 68/255) // Red/Coral
        }
        if model.isTracking {
            return Color(red: 16/255, green: 185/255, blue: 129/255) // Emerald
        }
        if model.isIdleReminderActive {
            return Color(red: 255/255, green: 180/255, blue: 0/255)
        }
        return Color.white.opacity(0.4)
    }

    private var timerColor: Color {
        if model.isPaused {
            return Color(red: 255/255, green: 195/255, blue: 70/255) // Warm Amber
        }
        if model.isBreak {
            return Color(red: 34/255, green: 211/255, blue: 238/255)
        }
        if model.isOvertime {
            return Color(red: 248/255, green: 113/255, blue: 113/255) // Red/Coral
        }
        if model.isTracking {
            return Color(red: 52/255, green: 211/255, blue: 153/255) // Emerald Light
        }
        return Color.white.opacity(0.7)
    }

    private var borderStrokeColor: Color {
        if model.isPillFlashing {
            return Color(red: 251/255, green: 191/255, blue: 36/255)
        }
        if model.isPaused {
            return Color(red: 255/255, green: 180/255, blue: 0/255).opacity(0.45)
        }
        if model.isIdleReminderActive {
            return Color(red: 255/255, green: 180/255, blue: 0/255).opacity(0.55)
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

    private func habitColor(for id: String) -> Color {
        switch id {
        case "coffee": return Color(red: 249/255, green: 115/255, blue: 22/255) // Orange
        case "treino": return Color(red: 239/255, green: 68/255, blue: 68/255)  // Red
        case "agua": return Color(red: 6/255, green: 182/255, blue: 212/255)    // Cyan
        case "ler": return Color(red: 234/255, green: 179/255, blue: 8/255)     // Yellow
        default: return Color(red: 16/255, green: 185/255, blue: 129/255)       // Emerald
        }
    }
}

// MARK: - Circular Gauge Component (Anel Circular + Porcentagem abaixo)
struct CircularItemGauge: View {
    let icon: String
    let progress: Double
    let color: Color
    let percentageText: String
    let tooltipTitle: String
    let tooltipSubtitle: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                // Circular Ring with Icon inside
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.10), lineWidth: 2.6)
                        .frame(width: 28, height: 28)

                    Circle()
                        .trim(from: 0, to: max(0.04, min(1.0, progress)))
                        .stroke(
                            color,
                            style: StrokeStyle(lineWidth: 2.6, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 28, height: 28)
                        .animation(.easeInOut(duration: 0.25), value: progress)

                    Text(icon)
                        .font(.system(size: 13))
                }
                .scaleEffect(isHovered ? 1.08 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: isHovered)

                Text(percentageText)
                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                    .foregroundColor(color.opacity(0.95))
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("\(tooltipTitle) • \(tooltipSubtitle)")
    }
}

// Single Habit Icon Button with smart count / duration badge
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

                let badgeText = habit.displayCount
                if !badgeText.isEmpty {
                    Text(badgeText)
                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4.5)
                        .padding(.vertical, 1.5)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 16/255, green: 185/255, blue: 129/255),
                                    Color(red: 5/255, green: 150/255, blue: 105/255)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color(red: 16/255, green: 22/255, blue: 34/255), lineWidth: 1.2)
                        )
                        .shadow(color: Color.black.opacity(0.35), radius: 2, x: 0, y: 1)
                        .offset(x: 6, y: -4)
                        .fixedSize(horizontal: true, vertical: true)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("\(habit.title) • \(habitTooltipText)")
    }

    private var habitTooltipText: String {
        let badge = habit.displayCount
        if badge.isEmpty {
            return "Clique para registrar"
        }
        return "\(badge) registrado hoje • Clique para registrar"
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

    override func menu(for event: NSEvent) -> NSMenu? {
        if let hosting = window?.contentView as? FocoDSPillHostingView {
            return hosting.menu(for: event)
        }
        return super.menu(for: event)
    }
}
