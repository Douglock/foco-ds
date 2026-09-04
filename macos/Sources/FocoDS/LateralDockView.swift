import SwiftUI
import AppKit

// MARK: - Dedicated Shapes matching reference images

/// Anthropic Claude 8-Ray Starburst Icon (Cardinais longos, diagonais curtos)
struct ClaudeStarburst: View {
    var size: CGFloat = 14
    var color: Color = .white

    var body: some View {
        ZStack {
            // 4 Cardinal rays
            Capsule()
                .fill(color)
                .frame(width: 2.2, height: size)
            Capsule()
                .fill(color)
                .frame(width: size, height: 2.2)

            // 4 Diagonal rays
            Capsule()
                .fill(color)
                .frame(width: 1.8, height: size * 0.72)
                .rotationEffect(.degrees(45))
            Capsule()
                .fill(color)
                .frame(width: 1.8, height: size * 0.72)
                .rotationEffect(.degrees(-45))

            // Center core
            Circle()
                .fill(color)
                .frame(width: 3.2, height: 3.2)
        }
        .frame(width: size, height: size)
    }
}

/// 3D Isometric Wireframe Cube Shape (3 faces em diamante que se encontram no centro)
struct IsometricCubeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cx = rect.midX
        let cy = rect.midY
        let r = min(rect.width, rect.height) / 2

        let pTop = CGPoint(x: cx, y: cy - r)
        let pTopRight = CGPoint(x: cx + r * cos(.pi / 6), y: cy - r * sin(.pi / 6))
        let pBottomRight = CGPoint(x: cx + r * cos(.pi / 6), y: cy + r * sin(.pi / 6))
        let pBottom = CGPoint(x: cx, y: cy + r)
        let pBottomLeft = CGPoint(x: cx - r * cos(.pi / 6), y: cy + r * sin(.pi / 6))
        let pTopLeft = CGPoint(x: cx - r * cos(.pi / 6), y: cy - r * sin(.pi / 6))
        let pCenter = CGPoint(x: cx, y: cy)

        // Outer Hexagon
        path.move(to: pTop)
        path.addLine(to: pTopRight)
        path.addLine(to: pBottomRight)
        path.addLine(to: pBottom)
        path.addLine(to: pBottomLeft)
        path.addLine(to: pTopLeft)
        path.closeSubpath()

        // Inner 3 Lines to Center
        path.move(to: pCenter)
        path.addLine(to: pTop)
        path.move(to: pCenter)
        path.addLine(to: pBottomLeft)
        path.move(to: pCenter)
        path.addLine(to: pBottomRight)

        return path
    }
}

struct IsometricCubeIcon: View {
    var size: CGFloat = 15
    var color: Color = .white.opacity(0.85)

    var body: some View {
        IsometricCubeShape()
            .stroke(color, style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
    }
}

/// OpenAI Flower / Swirl Icon (6 rounded loops dispostos radialmente)
struct OpenAISwirlIcon: View {
    var size: CGFloat = 16
    var color: Color = .white.opacity(0.85)

    var body: some View {
        ZStack {
            ForEach(0..<6) { i in
                Capsule()
                    .stroke(color, lineWidth: 1.3)
                    .frame(width: size * 0.40, height: size * 0.85)
                    .offset(y: -size * 0.18)
                    .rotationEffect(.degrees(Double(i) * 60))
            }
            Circle()
                .fill(Color(red: 14/255, green: 16/255, blue: 22/255))
                .frame(width: size * 0.38, height: size * 0.38)
        }
        .frame(width: size, height: size)
    }
}

/// Speech Bubble Pointer Arrow conectando o card ao anel da lateral
struct SpeechBubbleArrow: View {
    let pointingRight: Bool

    var body: some View {
        Path { path in
            if pointingRight {
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: 9, y: 7))
                path.addLine(to: CGPoint(x: 0, y: 14))
                path.closeSubpath()
            } else {
                path.move(to: CGPoint(x: 9, y: 0))
                path.addLine(to: CGPoint(x: 0, y: 7))
                path.addLine(to: CGPoint(x: 9, y: 14))
                path.closeSubpath()
            }
        }
        .fill(Color(red: 18/255, green: 22/255, blue: 30/255).opacity(0.96))
        .frame(width: 9, height: 14)
    }
}

// MARK: - Anel Superior com Halo Iridescente (Referência Imagem 1)
struct IridescentHaloRing: View {
    var isTracking: Bool
    var progress: Double
    var isOvertime: Bool

    var body: some View {
        ZStack {
            // 1. Disco Texturizado Iridescente / Fogo Circular (Estilo Anexo 1)
            AngularGradient(
                gradient: Gradient(colors: [
                    Color(red: 255/255, green: 65/255, blue: 45/255),   // Red-Orange
                    Color(red: 255/255, green: 155/255, blue: 0/255),  // Amber
                    Color(red: 255/255, green: 220/255, blue: 20/255), // Bright Yellow
                    Color(red: 200/255, green: 60/255, blue: 140/255), // Magenta
                    Color(red: 90/255, green: 80/255, blue: 220/255),  // Violet
                    Color(red: 255/255, green: 50/255, blue: 70/255),  // Crimson
                    Color(red: 255/255, green: 65/255, blue: 45/255)   // Red-Orange
                ]),
                center: .center
            )
            .frame(width: 44, height: 44)
            .clipShape(Circle())
            .overlay(
                RadialGradient(
                    colors: [Color.clear, Color.black.opacity(0.42)],
                    center: .center,
                    startRadius: 9,
                    endRadius: 22
                )
                .clipShape(Circle())
            )
            .opacity(isTracking ? 1.0 : 0.78)

            // 2. Trilho do anel escuro
            Circle()
                .stroke(Color.black.opacity(0.55), lineWidth: 3.4)
                .frame(width: 32, height: 32)

            // 3. Arco de progresso brilhante amarelo / overtime vermelho
            Circle()
                .trim(from: 0, to: max(0.04, min(1.0, progress)))
                .stroke(
                    isOvertime
                        ? Color(red: 255/255, green: 69/255, blue: 58/255)
                        : Color(red: 255/255, green: 228/255, blue: 24/255),
                    style: StrokeStyle(lineWidth: 3.0, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 32, height: 32)
                .shadow(
                    color: isOvertime ? Color.red.opacity(0.7) : Color.yellow.opacity(0.55),
                    radius: 3
                )
                .animation(.easeInOut(duration: 0.3), value: progress)

            // 4. Disco central preto profundo
            Circle()
                .fill(Color(red: 12/255, green: 14/255, blue: 18/255))
                .frame(width: 24, height: 24)

            // 5. Ícone Anthropic Starburst em branco
            ClaudeStarburst(size: 13, color: .white)
        }
        .frame(width: 44, height: 44)
    }
}

// MARK: - LateralDockView Principal
struct LateralDockView: View {
    @ObservedObject var model: FocoDSModel

    @State private var newTaskTitle: String = ""
    @State private var selectedEstimateMinutes: Int = 25
    @State private var isHoveringDock = false
    @FocusState private var isInputFocused: Bool

    private let estimateOptions = [15, 25, 30, 45, 60]

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if model.dockSide == "right" {
                Spacer(minLength: 0)

                if model.showTaskCreateCard {
                    HStack(alignment: .top, spacing: 0) {
                        taskCardView
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.94, anchor: .trailing).combined(with: .opacity),
                                removal: .scale(scale: 0.96, anchor: .trailing).combined(with: .opacity)
                            ))

                        SpeechBubbleArrow(pointingRight: true)
                            .padding(.top, 25)
                            .transition(.opacity)
                    }
                    .padding(.trailing, 2)
                }

                dockPillView
            } else {
                dockPillView

                if model.showTaskCreateCard {
                    HStack(alignment: .top, spacing: 0) {
                        SpeechBubbleArrow(pointingRight: false)
                            .padding(.top, 25)
                            .transition(.opacity)

                        taskCardView
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.94, anchor: .leading).combined(with: .opacity),
                                removal: .scale(scale: 0.96, anchor: .leading).combined(with: .opacity)
                            ))
                    }
                    .padding(.leading, 2)
                }

                Spacer(minLength: 0)
            }
        }
        .frame(width: model.showTaskCreateCard ? 336 : 56, height: 340, alignment: model.dockSide == "right" ? .trailing : .leading)
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: model.showTaskCreateCard)
        .onChange(of: model.showTaskCreateCard) { isOpen in
            if isOpen {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.isInputFocused = true
                }
            }
        }
    }

    // MARK: - Dock Vertical Colado na Lateral (Estilo Anexos 1 e 2)
    private var dockPillView: some View {
        VStack(spacing: 12) {
            // 1. Active Task or Main Focus Indicator (Top Ring)
            VStack(spacing: 3) {
                IridescentHaloRing(
                    isTracking: model.isTracking,
                    progress: model.progress,
                    isOvertime: model.isOvertime
                )
                .contentShape(Circle())
                .onTapGesture {
                    model.toggleTaskCreateCard()
                }

                // Texto de porcentagem ou contagem regressiva abaixo do anel (73%, 21% ou 14m)
                Text(displayTopPercentageOrCountdown)
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundColor(topTimerTextColor)
            }
            .padding(.top, 4)

            // 2. Ring 2: Mint Green / Orange (Aparece com ícone OpenAI ou primeiro hábito)
            VStack(spacing: 3) {
                let habit = model.habits.first
                let count = habit?.count ?? 0
                let pct = habit != nil ? min(1.0, Double(count) / 5.0) : 0.21

                Button(action: {
                    if let h = habit {
                        NSSound(named: "Tink")?.play()
                        model.clickHabit(h)
                    } else {
                        model.toggleTaskCreateCard()
                    }
                }) {
                    ZStack {
                        // Track ring
                        Circle()
                            .stroke(Color.white.opacity(0.10), lineWidth: 2.5)
                            .frame(width: 32, height: 32)

                        // Mint Green Arc (Estilo Anexo 2: 21% verde)
                        Circle()
                            .trim(from: 0, to: max(0.05, min(1.0, pct)))
                            .stroke(
                                Color(red: 0/255, green: 230/255, blue: 153/255), // Neon Mint
                                style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: 32, height: 32)

                        // Center Disc & Icon
                        Circle()
                            .fill(Color(red: 16/255, green: 19/255, blue: 26/255))
                            .frame(width: 24, height: 24)

                        OpenAISwirlIcon(size: 14, color: .white.opacity(0.92))
                    }
                }
                .buttonStyle(.plain)
                .help(habit != nil ? "\(habit!.title) • Clique para registrar" : "OpenAI Focus")

                // Porcentagem abaixo do anel 2 (ex: 21%)
                Text(habit != nil && count > 0 ? "\(Int(pct * 100))%" : "21%")
                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 0/255, green: 230/255, blue: 153/255).opacity(0.95))
            }

            // 3. Ring 3: Yellow / Amber (Aparece com 3D Cube ou segundo hábito)
            VStack(spacing: 3) {
                let habit = model.habits.count > 1 ? model.habits[1] : nil
                let count = habit?.count ?? 0
                let pct = habit != nil ? min(1.0, Double(count) / 5.0) : 0.52

                Button(action: {
                    if let h = habit {
                        NSSound(named: "Tink")?.play()
                        model.clickHabit(h)
                    } else {
                        model.toggleTaskCreateCard()
                    }
                }) {
                    ZStack {
                        // Track ring
                        Circle()
                            .stroke(Color.white.opacity(0.10), lineWidth: 2.5)
                            .frame(width: 32, height: 32)

                        // Lemon Yellow Arc (Estilo Anexo 2: 52% amarelo)
                        Circle()
                            .trim(from: 0, to: max(0.05, min(1.0, pct)))
                            .stroke(
                                Color(red: 255/255, green: 204/255, blue: 0/255), // Bright Yellow
                                style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: 32, height: 32)

                        // Center Disc & Icon
                        Circle()
                            .fill(Color(red: 16/255, green: 19/255, blue: 26/255))
                            .frame(width: 24, height: 24)

                        IsometricCubeIcon(size: 13, color: .white.opacity(0.92))
                    }
                }
                .buttonStyle(.plain)
                .help(habit != nil ? "\(habit!.title) • Clique para registrar" : "Workspace 3D Focus")

                // Porcentagem abaixo do anel 3 (ex: 52%)
                Text(habit != nil && count > 0 ? "\(Int(pct * 100))%" : "52%")
                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 255/255, green: 204/255, blue: 0/255).opacity(0.95))
            }

            Spacer(minLength: 2)

            // 4. Action Buttons (+ Nova Tarefa / 📝 Anotações)
            VStack(spacing: 8) {
                // Botão + (Abrir criação de tarefa)
                Button(action: {
                    model.toggleTaskCreateCard()
                }) {
                    ZStack {
                        Circle()
                            .fill(model.showTaskCreateCard ? Color(red: 16/255, green: 185/255, blue: 129/255) : Color.white.opacity(0.10))
                            .frame(width: 28, height: 28)

                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(model.showTaskCreateCard ? .black : .white.opacity(0.9))
                    }
                }
                .buttonStyle(.plain)
                .help("Criar Nova Tarefa de Foco (+)")

                // Botão 📝 (Anotações flutuantes minimalistas)
                Button(action: {
                    model.toggleSideNotes()
                }) {
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
                .help("Anotações da Tarefa (Sincronizadas)")

                // 3 Pontinhos ••• (Estilo Anexo 1)
                HStack(spacing: 3) {
                    Circle().fill(Color.white.opacity(0.45)).frame(width: 3.5, height: 3.5)
                    Circle().fill(Color.white.opacity(0.45)).frame(width: 3.5, height: 3.5)
                    Circle().fill(Color.white.opacity(0.45)).frame(width: 3.5, height: 3.5)
                }
                .padding(.vertical, 2)
            }
            .padding(.bottom, 6)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .frame(width: 52, height: 320)
        .background(
            ZStack {
                // Cápsula escura colada na lateral
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 22/255, green: 26/255, blue: 34/255).opacity(model.pillOpacity),
                                Color(red: 12/255, green: 14/255, blue: 20/255).opacity(model.pillOpacity)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                Capsule()
                    .stroke(borderStrokeColor, lineWidth: 1.0)
            }
            .shadow(color: Color.black.opacity(0.55), radius: 10, x: model.dockSide == "right" ? -3 : 3, y: 0)
        )
        .onHover { hovering in
            self.isHoveringDock = hovering
        }
    }

    // MARK: - Floating Popover Card (Inspirado exatamente nos Anexos 1 e 2)
    private var taskCardView: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: 8-ray Starburst + Title + Close Button
            HStack(spacing: 8) {
                ClaudeStarburst(size: 15, color: .white)

                VStack(alignment: .leading, spacing: 1) {
                    Text(model.isTracking ? model.taskTitle : "Criar Tarefa de Foco")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    if model.isTracking {
                        Text(model.formattedTime)
                            .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                            .foregroundColor(topTimerTextColor)
                    } else {
                        Text("Sincronizado com Super Productivity")
                            .font(.system(size: 9.5))
                            .foregroundColor(.white.opacity(0.55))
                    }
                }

                Spacer()

                Button(action: { model.showTaskCreateCard = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white.opacity(0.65))
                        .padding(5)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            // Se estiver rastreando: Barra de Progresso da Sessão (Estilo Anexo 2: Claude Usage)
            if model.isTracking {
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("Sessão Atual")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                        if model.hasEstimate {
                            Text(model.isOvertime ? "Tempo excedido!" : "Resta \(max(0, model.remainingEstimateSeconds / 60)) min")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(model.isOvertime ? Color(red: 255/255, green: 69/255, blue: 58/255) : Color(red: 255/255, green: 155/255, blue: 0/255))
                        } else {
                            Text("\(Int(model.progress * 100))% decorrido")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(Color(red: 0/255, green: 230/255, blue: 153/255))
                        }
                    }

                    // Track Bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.12))
                                .frame(height: 5)

                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(red: 255/255, green: 100/255, blue: 30/255), Color(red: 255/255, green: 180/255, blue: 0/255)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(4, geo.size.width * CGFloat(model.progress)), height: 5)
                                .animation(.easeInOut(duration: 0.3), value: model.progress)
                        }
                    }
                    .frame(height: 5)
                }
                .padding(.vertical, 2)
            }

            // Linha de Criação: Text Field "Type here..." + Botão 3D "Submit" (Estilo Anexo 1)
            HStack(spacing: 6) {
                TextField(model.isTracking ? "Nova tarefa ou subtarefa..." : "Type here...", text: $newTaskTitle, onCommit: {
                    submitTask()
                })
                .focused($isInputFocused)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundColor(.white)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.40))
                .cornerRadius(7)
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )

                // Botão "Submit" com efeito 3D (Estilo Anexo 1)
                Button(action: {
                    submitTask()
                }) {
                    Text("Submit")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 45/255, green: 52/255, blue: 68/255),
                                    Color(red: 22/255, green: 26/255, blue: 36/255)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .cornerRadius(7)
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(Color.white.opacity(0.24), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }

            // Quick Estimate Pills: 15m, 25m, 30m, 45m, 60m
            HStack(spacing: 5) {
                Text("Estimativa:")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))

                ForEach(estimateOptions, id: \.self) { mins in
                    Button(action: {
                        selectedEstimateMinutes = mins
                    }) {
                        Text("\(mins)m")
                            .font(.system(size: 9, weight: selectedEstimateMinutes == mins ? .bold : .medium))
                            .foregroundColor(selectedEstimateMinutes == mins ? .black : .white.opacity(0.8))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2.5)
                            .background(selectedEstimateMinutes == mins ? Color(red: 16/255, green: 185/255, blue: 129/255) : Color.white.opacity(0.10))
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Footer (Estilo Anexo 1: ▶▶ bypass permissions on  (shift+tab to cycle))
            HStack {
                Text("▶▶ foco imediato")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundColor(Color(red: 255/255, green: 120/255, blue: 40/255))

                Spacer()

                Text("(enter para iniciar)")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.45))

                Button("Abrir Super") {
                    model.clickTask()
                    SuperProductivityLauncher.activateSuperProductivity()
                }
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.7))
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(width: 256)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(red: 18/255, green: 22/255, blue: 30/255).opacity(0.96))

                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.50), radius: 16, x: 0, y: 6)
        )
    }

    private func submitTask() {
        let title = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        model.createNewTask(title: title, estimateMinutes: selectedEstimateMinutes)
        newTaskTitle = ""
    }

    private var displayTopPercentageOrCountdown: String {
        if model.isTracking {
            if model.hasEstimate {
                let remSec = model.remainingEstimateSeconds
                if remSec >= 0 {
                    let m = remSec / 60
                    return "\(m)m"
                } else {
                    let over = abs(remSec) / 60
                    return "+\(over)m"
                }
            }
            return "\(Int(model.progress * 100))%"
        }
        return "73%" // Estilo Anexo 2 quando idle
    }

    private var topTimerTextColor: Color {
        if model.isOvertime {
            return Color(red: 255/255, green: 69/255, blue: 58/255)
        }
        if model.isTracking {
            return Color(red: 255/255, green: 225/255, blue: 20/255)
        }
        return Color(red: 255/255, green: 130/255, blue: 40/255)
    }

    private var borderStrokeColor: Color {
        if model.isOvertime {
            return Color(red: 255/255, green: 69/255, blue: 58/255).opacity(0.6)
        }
        if isHoveringDock {
            return Color(red: 255/255, green: 204/255, blue: 0/255).opacity(0.55)
        }
        return Color.white.opacity(0.16)
    }
}
