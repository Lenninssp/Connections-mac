import SwiftUI

struct ContentView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .frame(minWidth: 180, idealWidth: 200, maxWidth: 240)
                .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            if state.currentSession != nil {
                MainGraphView()
            } else {
                emptyState
            }
        }
        .navigationTitle("")
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No sessions yet")
                .font(.title3)
                .foregroundColor(.secondary)
            Button("New Session") { state.newSession() }
                .buttonStyle(PrimaryButtonStyle(accent: state.accentColor))
                .keyboardShortcut("n", modifiers: .command)
        }
    }
}
