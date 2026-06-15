import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var state: AppState
    @State private var editingId: UUID?
    @State private var editingName: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Sessions")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 6)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(state.sessions) { session in
                        SessionRow(
                            session: session,
                            isSelected: session.id == state.currentSessionId,
                            isEditing: editingId == session.id,
                            editingName: $editingName,
                            accent: state.accentColor,
                            onSelect: { state.selectSession(session.id) },
                            onDelete: { state.deleteSession(id: session.id) },
                            onRename: {
                                editingId = session.id
                                editingName = session.name
                            },
                            onCommitRename: {
                                if !editingName.isEmpty {
                                    state.renameCurrentSession(to: editingName)
                                }
                                editingId = nil
                            }
                        )
                    }
                }
                .padding(.horizontal, 8)
            }

            Divider()

            Button(action: { state.newSession() }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 11))
                    Text("New Session")
                        .font(.system(size: 12))
                }
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("n", modifiers: .command)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct SessionRow: View {
    let session: Session
    let isSelected: Bool
    let isEditing: Bool
    @Binding var editingName: String
    let accent: Color
    let onSelect: () -> Void
    let onDelete: () -> Void
    let onRename: () -> Void
    let onCommitRename: () -> Void

    var body: some View {
        Group {
            if isEditing {
                TextField("Name", text: $editingName, onCommit: onCommitRename)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(accent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            } else {
                HStack {
                    Text(session.name)
                        .font(.system(size: 13))
                        .foregroundColor(isSelected ? accent : .primary)
                        .lineLimit(1)
                    Spacer()
                    Text("\(session.nodes.count)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(isSelected ? accent.opacity(0.12) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .contentShape(Rectangle())
                .onTapGesture(count: 2) { onRename() }
                .onTapGesture { onSelect() }
                .contextMenu {
                    Button("Rename") { onRename() }
                    Divider()
                    Button("Delete", role: .destructive) { onDelete() }
                }
            }
        }
    }
}
