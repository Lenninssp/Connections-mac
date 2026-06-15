import SwiftUI

struct MainGraphView: View {
    @EnvironmentObject var state: AppState
    @State private var showInput: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            GraphCanvas()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if showInput {
                InputPanelView()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                if let session = state.currentSession {
                    Text(session.name)
                        .font(.system(size: 13, weight: .medium))
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showInput.toggle() }
                } label: {
                    Image(systemName: showInput ? "chevron.down.circle.fill" : "chevron.up.circle")
                        .foregroundColor(state.accentColor)
                }
                .help("Toggle input panel (⌘I)")
                .keyboardShortcut("i", modifiers: .command)
            }
        }
    }
}
