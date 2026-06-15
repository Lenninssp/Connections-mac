import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        Form {
            Section("Appearance") {
                ColorPicker("Accent Color", selection: $state.accentColor)
                    .onChange(of: state.accentColor) { _ in state.saveAccentColor() }

                HStack {
                    Text("Presets")
                    Spacer()
                    ForEach(presets, id: \.self) { color in
                        Circle()
                            .fill(color)
                            .frame(width: 20, height: 20)
                            .overlay(Circle().stroke(Color.black.opacity(0.15), lineWidth: 1))
                            .onTapGesture {
                                state.accentColor = color
                                state.saveAccentColor()
                            }
                    }
                }
            }

            Section("Generation") {
                Toggle("Use AI (DeepSeek)", isOn: $state.useAI)
                    .help("When off, uses a local keyword extraction algorithm")

                HStack {
                    Text("Default word count")
                    Spacer()
                    Stepper("\(state.wordCount)", value: $state.wordCount, in: 2...7)
                        .labelsHidden()
                    Text("\(state.wordCount)")
                        .font(.system(size: 13, design: .monospaced))
                        .frame(width: 20)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 360)
        .padding()
    }

    private var presets: [Color] = [
        Color(red: 0.2, green: 0.4, blue: 1.0),  // blue
        Color(red: 0.1, green: 0.7, blue: 0.4),  // green
        Color(red: 0.8, green: 0.2, blue: 0.2),  // red
        Color(red: 0.6, green: 0.2, blue: 0.8),  // purple
        Color(red: 0.9, green: 0.5, blue: 0.1),  // orange
        Color(red: 0.0, green: 0.0, blue: 0.0),  // black
    ]
}
