import SwiftUI
import Combine

enum KeyboardMode: Equatable {
    case idle
    case addingNode
    case nodeSelected(Int)
    case connectingFrom(Int)
    case choosingEdgeStyle(from: Int, to: Int)
}

@MainActor
final class AppState: ObservableObject {
    @Published var sessions: [Session] = []
    @Published var currentSessionId: UUID?
    @Published var keyboardMode: KeyboardMode = .idle
    @Published var isGenerating: Bool = false
    @Published var generationError: String?
    @Published var useAI: Bool = true
    @Published var wordCount: Int = 4
    @Published var accentColor: Color = Color(red: 0.2, green: 0.4, blue: 1.0)

    private let db = DatabaseManager.shared
    private let physics = ForceDirectedLayout()
    private var undoStack: [Session] = []
    private var keyMonitor: Any?
    private(set) var canvasCenter: CGPoint = CGPoint(x: 400, y: 300)

    var currentSession: Session? {
        get { sessions.first { $0.id == currentSessionId } }
    }

    init() {
        loadAccentColor()
        sessions = db.loadAllSessions()
        if let first = sessions.first { currentSessionId = first.id }
        physics.onUpdate = { [weak self] updatedNodes in
            guard let self, let id = self.currentSessionId,
                  let idx = self.sessions.firstIndex(where: { $0.id == id }) else { return }
            self.sessions[idx].nodes = updatedNodes
        }
        setupKeyMonitor()
    }

    // MARK: - Sessions

    func newSession(name: String? = nil) {
        let name = name ?? "Session \(sessions.count + 1)"
        let session = Session(name: name)
        sessions.insert(session, at: 0)
        currentSessionId = session.id
        db.saveSession(session)
        keyboardMode = .idle
    }

    func selectSession(_ id: UUID) {
        saveCurrentSession()
        currentSessionId = id
        keyboardMode = .idle
        restartPhysics()
    }

    func deleteSession(id: UUID) {
        db.deleteSession(id: id)
        sessions.removeAll { $0.id == id }
        if currentSessionId == id {
            currentSessionId = sessions.first?.id
            restartPhysics()
        }
    }

    func renameCurrentSession(to name: String) {
        guard let id = currentSessionId,
              let idx = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions[idx].name = name
        db.renameSession(id: id, name: name)
    }

    // MARK: - Graph Operations

    func generateKeywords(from paragraph: String, canvasCenter: CGPoint) async {
        guard !paragraph.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard let id = currentSessionId,
              let idx = sessions.firstIndex(where: { $0.id == id }) else { return }

        isGenerating = true
        generationError = nil
        pushUndo()

        do {
            let words: [String]
            if useAI {
                words = try await DeepSeekService.extractKeywords(from: paragraph, count: wordCount)
            } else {
                words = KeywordExtractor.extract(from: paragraph, count: wordCount)
            }

            let spread: Double = 120
            let nodeCount = words.count
            var newNodes: [WordNode] = []
            for (i, word) in words.enumerated() {
                let angle = (Double(i) / Double(nodeCount)) * 2 * .pi
                let x = canvasCenter.x + spread * cos(angle)
                let y = canvasCenter.y + spread * sin(angle)
                let node = WordNode(word: word, number: i + 1, position: CGPoint(x: x, y: y))
                newNodes.append(node)
            }

            sessions[idx].paragraph = paragraph
            sessions[idx].nodes = newNodes
            sessions[idx].edges = []
            saveCurrentSession()
            restartPhysics()
        } catch {
            generationError = error.localizedDescription
        }

        isGenerating = false
    }

    func addNode(word: String) {
        let word = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !word.isEmpty,
              let id = currentSessionId,
              let idx = sessions.firstIndex(where: { $0.id == id }) else { return }
        pushUndo()
        let nextNumber = (sessions[idx].nodes.map(\.number).max() ?? 0) + 1
        let angle = Double.random(in: 0..<(2 * .pi))
        let offset: Double = 80
        let pos = CGPoint(x: canvasCenter.x + offset * cos(angle),
                          y: canvasCenter.y + offset * sin(angle))
        let node = WordNode(word: word, number: nextNumber, position: pos)
        sessions[idx].nodes.append(node)
        saveCurrentSession()
        physics.update(nodes: sessions[idx].nodes, edges: sessions[idx].edges)
        keyboardMode = .idle
    }

    func addEdge(from fromNumber: Int, to toNumber: Int, style: EdgeStyle) {
        guard let id = currentSessionId,
              let idx = sessions.firstIndex(where: { $0.id == id }),
              let fromNode = sessions[idx].nodes.first(where: { $0.number == fromNumber }),
              let toNode = sessions[idx].nodes.first(where: { $0.number == toNumber }),
              fromNode.id != toNode.id else { return }

        let alreadyExists = sessions[idx].edges.contains {
            ($0.fromId == fromNode.id && $0.toId == toNode.id) ||
            ($0.fromId == toNode.id && $0.toId == fromNode.id)
        }
        guard !alreadyExists else { return }

        pushUndo()
        let edge = Edge(fromId: fromNode.id, toId: toNode.id, style: style)
        sessions[idx].edges.append(edge)
        saveCurrentSession()
        physics.update(nodes: sessions[idx].nodes, edges: sessions[idx].edges)
    }

    func deleteNode(number: Int) {
        guard let id = currentSessionId,
              let idx = sessions.firstIndex(where: { $0.id == id }),
              let node = sessions[idx].nodes.first(where: { $0.number == number }) else { return }
        pushUndo()
        sessions[idx].edges.removeAll { $0.fromId == node.id || $0.toId == node.id }
        sessions[idx].nodes.removeAll { $0.id == node.id }
        // Renumber
        for i in sessions[idx].nodes.indices {
            sessions[idx].nodes[i].number = i + 1
        }
        saveCurrentSession()
        physics.update(nodes: sessions[idx].nodes, edges: sessions[idx].edges)
    }

    func undo() {
        guard let saved = undoStack.popLast(),
              let idx = sessions.firstIndex(where: { $0.id == saved.id }) else { return }
        sessions[idx] = saved
        db.saveSession(saved)
        restartPhysics()
    }

    // MARK: - Node dragging

    func pinNode(id: UUID, at position: CGPoint) {
        physics.pinNode(id: id, at: position)
    }

    func moveNode(id: UUID, to position: CGPoint) {
        physics.moveNode(id: id, to: position)
    }

    func unpinNode(id: UUID) {
        physics.unpinNode(id: id)
        saveCurrentSession()
    }

    func updateCanvasCenter(_ center: CGPoint) {
        canvasCenter = center
        physics.updateCenter(center)
    }

    // MARK: - Keyboard

    private func setupKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return self.handleKey(event)
        }
    }

    private func handleKey(_ event: NSEvent) -> NSEvent? {
        let chars = event.charactersIgnoringModifiers ?? ""
        let mods = event.modifierFlags

        // While adding a node, pass everything through except Esc
        if keyboardMode == .addingNode {
            if event.keyCode == 53 {
                keyboardMode = .idle
                return nil
            }
            return event
        }

        // Global shortcuts
        if mods.contains(.command) {
            switch chars {
            case "z": undo(); return nil
            case "n": newSession(); return nil
            default: break
            }
            return event
        }

        switch keyboardMode {
        case .addingNode:
            return event // unreachable, handled above

        case .idle:
            if chars == "n" {
                keyboardMode = .addingNode
                return nil
            }
            if let n = Int(chars), (1...9).contains(n) {
                if currentSession?.nodes.first(where: { $0.number == n }) != nil {
                    keyboardMode = .nodeSelected(n)
                    return nil
                }
            }

        case .nodeSelected(let n):
            if event.keyCode == 53 { // Esc
                keyboardMode = .idle
                return nil
            }
            if chars == "c" {
                keyboardMode = .connectingFrom(n)
                return nil
            }
            if chars == "d" {
                deleteNode(number: n)
                keyboardMode = .idle
                return nil
            }
            if let m = Int(chars), (1...9).contains(m), m != n {
                if currentSession?.nodes.first(where: { $0.number == m }) != nil {
                    keyboardMode = .nodeSelected(m)
                    return nil
                }
            }

        case .connectingFrom(let from):
            if event.keyCode == 53 {
                keyboardMode = .idle
                return nil
            }
            if let to = Int(chars), (1...9).contains(to), to != from {
                if currentSession?.nodes.first(where: { $0.number == to }) != nil {
                    keyboardMode = .choosingEdgeStyle(from: from, to: to)
                    return nil
                }
            }

        case .choosingEdgeStyle(let from, let to):
            if event.keyCode == 53 {
                keyboardMode = .idle
                return nil
            }
            if let styleNum = Int(chars), let style = EdgeStyle(rawValue: styleNum - 1) {
                addEdge(from: from, to: to, style: style)
                keyboardMode = .idle
                return nil
            }
        }

        return event
    }

    // MARK: - Helpers

    private func pushUndo() {
        guard let session = currentSession else { return }
        undoStack.append(session)
        if undoStack.count > 20 { undoStack.removeFirst() }
    }

    private func saveCurrentSession() {
        guard let session = currentSession else { return }
        db.saveSession(session)
    }

    private func restartPhysics() {
        guard let session = currentSession else { return }
        physics.start(nodes: session.nodes, edges: session.edges, center: canvasCenter)
    }

    // MARK: - Accent color persistence

    private func loadAccentColor() {
        if let data = UserDefaults.standard.data(forKey: "accentColor"),
           let decoded = try? JSONDecoder().decode([Double].self, from: data),
           decoded.count == 3 {
            accentColor = Color(red: decoded[0], green: decoded[1], blue: decoded[2])
        }
    }

    func saveAccentColor() {
        guard let components = NSColor(accentColor).usingColorSpace(.deviceRGB) else { return }
        let data = try? JSONEncoder().encode([
            components.redComponent, components.greenComponent, components.blueComponent
        ])
        UserDefaults.standard.set(data, forKey: "accentColor")
    }
}
