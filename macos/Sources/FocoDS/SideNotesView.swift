import SwiftUI
import AppKit

struct SideNotesView: View {
    @ObservedObject var model: FocoDSModel
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Text("📝")
                        .font(.system(size: 12))
                    Text("Notas Minimalistas")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                }

                Spacer()

                // Close Button
                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        model.isSideNotesOpen = false
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(4)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 2)

            // Current task context hint
            if !model.taskTitle.isEmpty && model.taskTitle != "Foco DS" {
                Text("Tarefa: \(model.taskTitle)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color(red: 16/255, green: 185/255, blue: 129/255))
                    .lineLimit(1)
            }

            // Distraction-free Text Editor
            TextEditor(text: Binding(
                get: { model.notesText },
                set: { model.updateNotes($0) }
            ))
            .font(.system(size: 12, design: .default))
            .focused($isFocused)
            .scrollContentBackground(.hidden)
            .background(Color.black.opacity(0.25))
            .cornerRadius(8)
            .frame(height: 140)

            // Footer Actions
            HStack {
                Text("\(model.notesText.split(separator: " ").count) palavras")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))

                Spacer()

                Button("Copiar") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(model.notesText, forType: .string)
                }
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color(red: 16/255, green: 185/255, blue: 129/255))

                Text("•")
                    .foregroundColor(.white.opacity(0.2))

                Button("Limpar") {
                    model.updateNotes("")
                }
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.red.opacity(0.7))
            }
        }
        .padding(14)
        .frame(width: 250)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 14/255, green: 18/255, blue: 28/255).opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.5), radius: 14, x: 0, y: 6)
        .onAppear {
            isFocused = true
        }
    }
}
