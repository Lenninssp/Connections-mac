import SwiftUI
import Combine

enum KeyboardMode: Equatable {
    case idle
    case addingNode
    case nodeSelected(Int)
    case connectingFrom(Int)
    case choosingEdgeStyle(from: Int, to: Int)
    case choosingNodeColor(Int)
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
    @Published var viewScale: CGFloat = 1.0
    @Published var viewOffset: CGPoint = .zero

    private let db = DatabaseManager.shared
    private let physics = ForceDirectedLayout()
    private var undoStack: [Session] = []
    private var keyMonitor: Any?
    private var scrollMonitor: Any?
    private var magnifyMonitor: Any?
    private var magnifyBaseScale: CGFloat = 1.0
    private(set) var canvasCenter: CGPoint = CGPoint(x: 400, y: 300)

    var worldCenter: CGPoint {
        CGPoint(x: (canvasCenter.x - viewOffset.x) / viewScale,
                y: (canvasCenter.y - viewOffset.y) / viewScale)
    }

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
        setupTrackpadMonitors()
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

    func duplicateSession(id: UUID) {
        guard let original = sessions.first(where: { $0.id == id }) else { return }
        // Deep copy with fresh UUIDs so nodes and edges are independent
        let newId = UUID()
        var copy = Session(id: newId, name: "\(original.name) (copy)",
                           paragraph: original.paragraph, createdAt: Date())
        var nodeIdMap: [UUID: UUID] = [:]
        copy.nodes = original.nodes.map { node in
            let newNodeId = UUID()
            nodeIdMap[node.id] = newNodeId
            return WordNode(id: newNodeId, word: node.word, number: node.number, position: node.position)
        }
        copy.edges = original.edges.compactMap { edge in
            guard let newFrom = nodeIdMap[edge.fromId],
                  let newTo = nodeIdMap[edge.toId] else { return nil }
            return Edge(id: UUID(), fromId: newFrom, toId: newTo, style: edge.style)
        }
        sessions.insert(copy, at: 0)
        db.saveSession(copy)
        selectSession(newId)
    }

    // MARK: - Graph Operations

    func generateKeywords(from paragraph: String) async {
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
            let wc = worldCenter
            var newNodes: [WordNode] = []
            for (i, word) in words.enumerated() {
                let angle = (Double(i) / Double(nodeCount)) * 2 * .pi
                let x = wc.x + spread * cos(angle)
                let y = wc.y + spread * sin(angle)
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
        let spread: Double = 80
        let wc = worldCenter
        let pos = CGPoint(x: wc.x + spread * cos(angle),
                          y: wc.y + spread * sin(angle))
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

        pushUndo()
        if let existingIdx = sessions[idx].edges.firstIndex(where: {
            ($0.fromId == fromNode.id && $0.toId == toNode.id) ||
            ($0.fromId == toNode.id && $0.toId == fromNode.id)
        }) {
            sessions[idx].edges[existingIdx].style = style
        } else {
            sessions[idx].edges.append(Edge(fromId: fromNode.id, toId: toNode.id, style: style))
        }
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

    func setNodeColor(number: Int, colorIndex: Int?) {
        guard let id = currentSessionId,
              let sIdx = sessions.firstIndex(where: { $0.id == id }),
              let nIdx = sessions[sIdx].nodes.firstIndex(where: { $0.number == number }) else { return }
        pushUndo()
        sessions[sIdx].nodes[nIdx].colorIndex = colorIndex
        saveCurrentSession()
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

    // MARK: - Viewport

    func zoomIn() {
        setScale(min(5.0, viewScale * 1.25), anchor: canvasCenter)
    }

    func zoomOut() {
        setScale(max(0.15, viewScale / 1.25), anchor: canvasCenter)
    }

    func resetView() {
        viewScale = 1.0
        viewOffset = .zero
    }

    func pan(dx: CGFloat, dy: CGFloat) {
        viewOffset.x += dx
        viewOffset.y += dy
    }

    func setScale(_ newScale: CGFloat, anchor: CGPoint) {
        let factor = newScale / viewScale
        viewOffset.x = anchor.x - (anchor.x - viewOffset.x) * factor
        viewOffset.y = anchor.y - (anchor.y - viewOffset.y) * factor
        viewScale = newScale
    }

    // MARK: - Keyboard

    private func setupKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return self.handleKey(event)
        }
    }

    private func setupTrackpadMonitors() {
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self else { return event }
            guard !(NSApp.keyWindow?.firstResponder is NSText) else { return event }
            let dx = event.hasPreciseScrollingDeltas ? event.scrollingDeltaX : event.scrollingDeltaX * 12
            let dy = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY : event.scrollingDeltaY * 12
            self.pan(dx: dx, dy: dy)
            return event
        }

        magnifyMonitor = NSEvent.addLocalMonitorForEvents(matching: .magnify) { [weak self] event in
            guard let self else { return event }
            guard !(NSApp.keyWindow?.firstResponder is NSText) else { return event }
            if event.phase.contains(.began) { self.magnifyBaseScale = self.viewScale }
            let newScale = min(5.0, max(0.15, self.magnifyBaseScale * (1 + event.magnification)))
            // Zoom toward the cursor position
            let mouseInWindow = event.locationInWindow
            let winH = NSApp.keyWindow?.contentView?.frame.height ?? self.canvasCenter.y * 2
            let anchor = CGPoint(x: mouseInWindow.x, y: winH - mouseInWindow.y)
            self.setScale(newScale, anchor: anchor)
            return event
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

        // Pass through all keys when any other text field/editor has focus
        if NSApp.keyWindow?.firstResponder is NSText {
            return event
        }

        // Global shortcuts
        if mods.contains(.command) {
            switch chars {
            case "z": undo(); return nil
            case "n": newSession(); return nil
            case "=", "+": zoomIn(); return nil
            case "-", "_": zoomOut(); return nil
            case "0": resetView(); return nil
            default: break
            }
            // Cmd+Arrow: pan
            let panStep: CGFloat = 60
            switch event.keyCode {
            case 123: pan(dx:  panStep, dy: 0); return nil  // ←
            case 124: pan(dx: -panStep, dy: 0); return nil  // →
            case 126: pan(dx: 0, dy:  panStep); return nil  // ↑
            case 125: pan(dx: 0, dy: -panStep); return nil  // ↓
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
            if let n = NodeLabel.number(forKey: chars) {
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
            if chars == "p" {
                keyboardMode = .choosingNodeColor(n)
                return nil
            }
            if let m = NodeLabel.number(forKey: chars), m != n {
                if currentSession?.nodes.first(where: { $0.number == m }) != nil {
                    keyboardMode = .nodeSelected(m)
                    return nil
                }
            }

        case .choosingNodeColor(let n):
            if event.keyCode == 53 { // Esc
                keyboardMode = .nodeSelected(n)
                return nil
            }
            if chars == "0" {
                setNodeColor(number: n, colorIndex: nil)
                keyboardMode = .nodeSelected(n)
                return nil
            }
            if let i = Int(chars), (1...9).contains(i) {
                setNodeColor(number: n, colorIndex: i)
                keyboardMode = .nodeSelected(n)
                return nil
            }

        case .connectingFrom(let from):
            if event.keyCode == 53 {
                keyboardMode = .idle
                return nil
            }
            if let to = NodeLabel.number(forKey: chars), to != from {
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
