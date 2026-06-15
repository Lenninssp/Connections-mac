import SwiftUI

struct InputPanelView: View {
    @EnvironmentObject var state: AppState
    @State private var paragraph: String = ""
    @FocusState private var textFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextEditor(text: $paragraph)
                .font(.system(size: 13))
                .frame(height: 80)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.black.opacity(0.15), lineWidth: 1)
                )
                .focused($textFocused)
                .overlay(alignment: .topLeading) {
                    if paragraph.isEmpty {
                        Text("Paste a paragraph to extract keywords…")
                            .foregroundColor(.secondary)
                            .font(.system(size: 13))
                            .padding(6)
                            .allowsHitTesting(false)
                    }
                }

            HStack(spacing: 14) {
                // Word count picker
                HStack(spacing: 6) {
                    Text("Words:")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    ForEach(2...7, id: \.self) { n in
                        Button("\(n)") {
                            state.wordCount = n
                        }
                        .buttonStyle(CountButtonStyle(isSelected: state.wordCount == n, accent: state.accentColor))
                    }
                }

                Divider().frame(height: 20)

                // AI / Local toggle
                HStack(spacing: 6) {
                    Toggle("AI", isOn: $state.useAI)
                        .toggleStyle(.button)
                        .font(.system(size: 12))
                }

                Spacer()

                if let err = state.generationError {
                    Text(err)
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                        .lineLimit(1)
                }

                Button(action: generate) {
                    HStack(spacing: 6) {
                        if state.isGenerating {
                            ProgressView().scaleEffect(0.7).frame(width: 14, height: 14)
                        }
                        Text(state.isGenerating ? "Generating…" : "Generate")
                            .font(.system(size: 13, weight: .medium))
                    }
                }
                .buttonStyle(PrimaryButtonStyle(accent: state.accentColor))
                .disabled(state.isGenerating || paragraph.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(12)
        .background(Color(NSColor.windowBackgroundColor))
        .overlay(alignment: .top) {
            Divider()
        }
        .onAppear {
            if let session = state.currentSession {
                paragraph = session.paragraph
            }
        }
        .onChange(of: state.currentSessionId) { _ in
            paragraph = state.currentSession?.paragraph ?? ""
        }
    }

    private func generate() {
        let text = paragraph
        Task { await state.generateKeywords(from: text, canvasCenter: CGPoint(x: 400, y: 300)) }
    }
}

struct CountButtonStyle: ButtonStyle {
    let isSelected: Bool
    let accent: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: isSelected ? .semibold : .regular, design: .monospaced))
            .frame(width: 22, height: 22)
            .background(isSelected ? accent.opacity(0.15) : Color.clear)
            .foregroundColor(isSelected ? accent : .primary)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(isSelected ? accent : Color.black.opacity(0.2), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    let accent: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(accent)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
