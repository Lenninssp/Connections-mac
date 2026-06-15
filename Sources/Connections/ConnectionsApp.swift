import SwiftUI

@main
struct ConnectionsApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 700, minHeight: 500)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Session") { appState.newSession() }
                    .keyboardShortcut("n", modifiers: .command)
            }
            CommandGroup(after: .undoRedo) {
                Button("Undo") { appState.undo() }
                    .keyboardShortcut("z", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}
