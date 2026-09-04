import SwiftUI
import AppKit

struct FocoDSPillView: View {
    @ObservedObject var model: FocoDSModel
    @State private var isHovering = false
    @State private var showTooltipCard = false

    var body: some View {
        Group {
            if model.visualStyle == "circular" {
                circularGaugeContainer
            } else {
                classicPillContainer
            }
        }
        .contextMenu {
            focoDSContextMenu
        }
    }

    // MARK: - Estilo 1: Pílula Clássica HUD
    private var classicPillContainer: some View {
        Group {
            if model.isTracking && !model.taskTitle.isEmpty {
                classicActiveTaskView
            } else {
                classicHabitsView
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            ZStack(alignment: .leading) {
                // Fundo Escuro com Opacidade Regulável
                Capsule()
                    .fill(Color(red: 16/255, green: 22/255, blue: 34/255).opacity(model.pillOpacity))

                // Barra de Progresso Suave
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
            Capsule()
                .stroke(borderStrokeColor, lineWidth: model.isPillFlashing ? 2.0 : 1.0)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                self.isHovering = hovering
            }
        }
    }

    // MARK: - Estilo 2: Anéis Circulares (Inspirado no anexo)
    private var circularGaugeContainer: some View {
        HStack(spacing: 11) {
            if model.isTracking && !model.taskTitle.isEmpty {
                // Active Task Gauge with ring & percentage
                CircularItemGauge(
                    icon: "🎯",
                    progress: model.progress,
                    color: statusColor,
                    percentageText: "\(Int(model.progress * 100))%",
                    tooltipTitle: model.taskTitle,
                    tooltipSubtitle: model.formattedTime
                ) {
                    model.clickTask()
                    SuperProductivityLauncher.activateSuperProductivity()
                }

                // Compact Title and Countdown Time
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.taskTitle)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.95))
                        .lineLimit(1)
                        .frame(maxWidth: 140, alignment: .leading)

                    Text(model.formattedTime)
                        .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                        .foregroundColor(timerColor)
                }

                Rectangle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 1, height: 16)

                // Notes Button
                Button(action: { model.toggleSideNotes() }) {
                    ZStack(alignment: .topTrailing) {
                        Text("📝")
                            .font(.system(size: 12))
                            .padding(4)
                            .background(model.isSideNotesOpen ? Color.white.opacity(0.24) : Color.white.opacity(0.08))
                            .clipShape(Circle())

                        if !model.notesText.isEmpty {
                            Circle()
                                .fill(Color(red: 16/255, green: 185/255, blue: 129/255))
                                .frame(width: 5, height: 5)
                                .offset(x: 2, y: -2)
                        }
                    }
                }
                .buttonStyle(.plain)

            } else {
                // Circular Habits Gauges (with circular ring and percentage)
                ForEach(model.habits) { habit in
                    let count = habit.count ?? 0
                    let target = 5.0
                    let pct = min(1.0, Double(count) / target)
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
        .overlay(
            NativeDragAndClickHandler(onClick: {
                if model.isTracking {
                    model.clickTask()
                }
                SuperProductivityLauncher.activateSuperProductivity()
            })
        )
    }

    // MARK: - Classic Active Task View
    private var classicActiveTaskView: some View {
        HStack(spacing: 9) {
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

            // Minimalist Note Button
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
            Circle()
                .fill(Color.white.opacity(0.35))
                .frame(width: 6, height: 6)

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

    // MARK: - Right Click Context Menu (Todas as Configurações)
    @ViewBuilder
    private var focoDSContextMenu: some View {
        // Encaixe Magnético no Notch
        Menu("🧲 Encaixe na Tela") {
            Button(model.isNotchSnapped ? "✓ Encaixe Magnético no Notch" : "Encaixe Magnético no Notch") {
                if !model.isNotchSnapped { model.toggleNotchSnap() }
            }
            Button(!model.isNotchSnapped ? "✓ Flutuação Livre (Arrastável)" : "Flutuação Livre (Arrastável)") {
                if model.isNotchSnapped { model.toggleNotchSnap() }
            }
        }

        // Estilo Visual (Pílula vs Anéis Circulares)
        Menu("🎨 Estilo Visual") {
            Button(model.visualStyle == "classic" ? "✓ Pílula HUD Moderna" : "Pílula HUD Moderna") {
                model.setVisualStyle("classic")
            }
            Button(model.visualStyle == "circular" ? "✓ Anéis Circulares (Estilo Anexo)" : "Anéis Circulares (Estilo Anexo)") {
                model.setVisualStyle("circular")
            }
        }

        // Opacidade Regulável
        Menu("🎛️ Opacidade do Fundo") {
            Button(model.pillOpacity >= 0.95 ? "✓ 100% (Sólido Preto)" : "100% (Sólido Preto)") {
                model.setPillOpacity(1.0)
            }
            Button(model.pillOpacity >= 0.80 && model.pillOpacity < 0.95 ? "✓ 85% (Padrão Vidro)" : "85% (Padrão Vidro)") {
                model.setPillOpacity(0.85)
            }
            Button(model.pillOpacity >= 0.65 && model.pillOpacity < 0.80 ? "✓ 70% (Translúcido)" : "70% (Translúcido)") {
                model.setPillOpacity(0.70)
            }
            Button(model.pillOpacity >= 0.45 && model.pillOpacity < 0.65 ? "✓ 50% (Vidro Leve)" : "50% (Vidro Leve)") {
                model.setPillOpacity(0.50)
            }
            Button(model.pillOpacity < 0.45 ? "✓ 30% (Ultra Transparente)" : "30% (Ultra Transparente)") {
                model.setPillOpacity(0.30)
            }
        }

        // Estimativa da Tarefa
        Menu("⏱️ Definir Estimativa") {
            Button("15 minutos") { model.setTaskEstimate(minutes: 15) }
            Button("25 minutos") { model.setTaskEstimate(minutes: 25) }
            Button("30 minutos") { model.setTaskEstimate(minutes: 30) }
            Button("45 minutos") { model.setTaskEstimate(minutes: 45) }
            Button("60 minutos (1h)") { model.setTaskEstimate(minutes: 60) }
            Divider()
            Button("Sem estimativa") { model.setTaskEstimate(minutes: 0) }
        }

        // Sons e Efeitos
        Menu("🔊 Sons e Efeitos") {
            Button(model.playAudioOnStart ? "✓ Tocar Som ao Iniciar Foco (Play)" : "Tocar Som ao Iniciar Foco (Play)") {
                model.togglePlayAudio()
            }
            Divider()
            Button("Testar Som de Play (Submarine)") {
                ScreenFlashController.playStartFocusSound()
            }
            Button("Testar Flash de Borda Verde (1s)") {
                ScreenFlashController.triggerPlayFlash(playSound: false)
            }
            Button("Testar Flash de Borda Vermelho (1s)") {
                ScreenFlashController.triggerOvertimeFlash(playSound: false)
            }
        }

        Divider()

        Button("⌨️ Atalho Global: ⌥ + F") {}
            .disabled(true)

        Button("📝 Abrir/Fechar Anotações") {
            model.toggleSideNotes()
        }

        Button("🎯 Abrir no Super Productivity") {
            model.clickTask()
            SuperProductivityLauncher.activateSuperProductivity()
        }
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
                    // Outer background ring
                    Circle()
                        .stroke(Color.white.opacity(0.10), lineWidth: 2.6)
                        .frame(width: 28, height: 28)

                    // Active progress ring
                    Circle()
                        .trim(from: 0, to: max(0.02, min(1.0, progress)))
                        .stroke(
                            color,
                            style: StrokeStyle(lineWidth: 2.6, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 28, height: 28)
                        .animation(.easeInOut(duration: 0.3), value: progress)

                    // Inner circle
                    Circle()
                        .fill(isHovered ? Color.white.opacity(0.20) : Color.white.opacity(0.08))
                        .frame(width: 22, height: 22)

                    // Centered Icon
                    Text(icon)
                        .font(.system(size: 11))
                }
                .scaleEffect(isHovered ? 1.12 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: isHovered)

                // Percentage below icon (estilo anexo: 73%, 21%, etc)
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
