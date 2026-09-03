import Foundation
import AppKit
import SwiftUI

@MainActor
final class NotesPanelController {
    private var panel: NSPanel?
    private weak var model: FocoDSModel?
    private weak var pillWindow: NSWindow?

    init(model: FocoDSModel, pillWindow: NSWindow?) {
        self.model = model
        self.pillWindow = pillWindow
        setupPanel()
    }

    private func setupPanel() {
        guard let model = model else { return }

        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 210),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        p.isFloatingPanel = true
        p.level = .floating
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false // Clean, no heavy black shadow!
        p.isMovableByWindowBackground = true

        let contentView = NSHostingView(rootView: FloatingNoteContentView(model: model, onClose: { [weak self] in
            self?.hide()
        }))
        p.contentView = contentView

        self.panel = p
    }

    func toggle() {
        if let p = panel, p.isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        guard let p = panel, let model = model else { return }

        // Position right below or to the side of the pill window
        if let pill = pillWindow {
            let pillFrame = pill.frame
            let x = pillFrame.origin.x + (pillFrame.width - p.frame.width) / 2
            let y = pillFrame.origin.y - p.frame.height - 8
            p.setFrameOrigin(NSPoint(x: x, y: y))
        }

        p.orderFrontRegardless()
        model.isSideNotesOpen = true
    }

    func hide() {
        panel?.orderOut(nil)
        model?.isSideNotesOpen = false
    }
}

struct FloatingNoteContentView: View {
    @ObservedObject var model: FocoDSModel
    var onClose: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 6) {
                Text("📝")
                    .font(.system(size: 12))

                VStack(alignment: .leading, spacing: 1) {
                    Text("Notas da Tarefa")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.95))

                    Text(model.taskTitle)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Color(red: 16/255, green: 185/255, blue: 129/255))
                        .lineLimit(1)
                }

                Spacer()

                // Close Button
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(5)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            // Text Editor (Bidirectional Sync)
            TextEditor(text: Binding(
                get: { model.notesText },
                set: { model.userEditedNotes($0) }
            ))
            .font(.system(size: 12, design: .default))
            .focused($isFocused)
            .scrollContentBackground(.hidden)
            .background(Color.black.opacity(0.3))
            .cornerRadius(8)
            .frame(minHeight: 110)

            // Footer
            HStack {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(red: 16/255, green: 185/255, blue: 129/255))
                        .frame(width: 5, height: 5)
                    Text("Salva no Super Productivity")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer()

                Button("Copiar") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(model.notesText, forType: .string)
                }
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color(red: 16/255, green: 185/255, blue: 129/255))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 16/255, green: 20/255, blue: 30/255).opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                )
        )
        .onAppear {
            isFocused = true
        }
    }
}
