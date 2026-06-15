import SwiftUI

struct GraphCanvas: View {
    @EnvironmentObject var state: AppState
    @State private var draggingNodeId: UUID?
    @State private var lastDragPosition: CGPoint = .zero
    @State private var newNodeText: String = ""
    @FocusState private var nodeInputFocused: Bool

    private let nodeRadius: CGFloat = 28

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.white

                Canvas { ctx, size in
                    let nodes = state.currentSession?.nodes ?? []
                    let edges = state.currentSession?.edges ?? []
                    let accent = NSColor(state.accentColor)

                    drawEdges(ctx: ctx, nodes: nodes, edges: edges, accent: accent)
                    drawNodes(ctx: ctx, nodes: nodes, accent: accent, size: size)
                }
                .gesture(dragGesture)

                hudOverlay

                if state.keyboardMode == .addingNode {
                    nodeInputOverlay
                }
            }
            .onAppear { state.updateCanvasCenter(CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)) }
            .onChange(of: geo.size) { size in
                state.updateCanvasCenter(CGPoint(x: size.width / 2, y: size.height / 2))
            }
        }
    }

    // MARK: - Node Input Overlay

    private var nodeInputOverlay: some View {
        VStack(spacing: 8) {
            Text("New node")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            TextField("Type a word…", text: $newNodeText)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .multilineTextAlignment(.center)
                .focused($nodeInputFocused)
                .onSubmit {
                    state.addNode(word: newNodeText)
                    newNodeText = ""
                }
                .frame(width: 200)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThickMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(state.accentColor, lineWidth: 1.5))
        .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 4)
        .onAppear {
            newNodeText = ""
            nodeInputFocused = true
        }
        .onChange(of: state.keyboardMode) { mode in
            if mode != .addingNode {
                newNodeText = ""
                nodeInputFocused = false
            }
        }
    }

    // MARK: - Drawing

    private func drawEdges(ctx: GraphicsContext, nodes: [WordNode], edges: [Edge], accent: NSColor) {
        let nodeMap = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        for edge in edges {
            guard let from = nodeMap[edge.fromId], let to = nodeMap[edge.toId] else { continue }
            drawEdge(ctx: ctx, from: from.position, to: to.position, style: edge.style)
        }
    }

    private func drawEdge(ctx: GraphicsContext, from: CGPoint, to: CGPoint, style: EdgeStyle) {
        let dx = to.x - from.x
        let dy = to.y - from.y
        let dist = sqrt(dx * dx + dy * dy)
        guard dist > 1 else { return }

        let nx = dx / dist
        let ny = dy / dist
        let startPt = CGPoint(x: from.x + nx * nodeRadius, y: from.y + ny * nodeRadius)
        let endPt = CGPoint(x: to.x - nx * nodeRadius, y: to.y - ny * nodeRadius)

        var path = Path()
        path.move(to: startPt)
        path.addLine(to: endPt)

        let isDashed = style == .dashed || style == .dashedArrow
        let hasArrow = style == .arrow || style == .dashedArrow

        ctx.stroke(path, with: .color(.black), style: StrokeStyle(lineWidth: 1.5, dash: isDashed ? [7, 4] : []))

        if hasArrow {
            let arrowLen: CGFloat = 10
            let arrowAngle: CGFloat = .pi / 6
            let p1 = CGPoint(
                x: endPt.x - arrowLen * cos(atan2(ny, nx) - arrowAngle),
                y: endPt.y - arrowLen * sin(atan2(ny, nx) - arrowAngle)
            )
            let p2 = CGPoint(
                x: endPt.x - arrowLen * cos(atan2(ny, nx) + arrowAngle),
                y: endPt.y - arrowLen * sin(atan2(ny, nx) + arrowAngle)
            )
            var arrow = Path()
            arrow.move(to: endPt)
            arrow.addLine(to: p1)
            arrow.move(to: endPt)
            arrow.addLine(to: p2)
            ctx.stroke(arrow, with: .color(.black), lineWidth: 1.5)
        }
    }

    private func drawNodes(ctx: GraphicsContext, nodes: [WordNode], accent: NSColor, size: CGSize) {
        let selectedNumber: Int? = {
            switch state.keyboardMode {
            case .nodeSelected(let n): return n
            case .connectingFrom(let n): return n
            case .choosingEdgeStyle(let f, _): return f
            default: return nil
            }
        }()
        let targetNumber: Int? = {
            if case .choosingEdgeStyle(_, let t) = state.keyboardMode { return t }
            return nil
        }()

        for node in nodes {
            let pos = node.position
            let rect = CGRect(x: pos.x - nodeRadius, y: pos.y - nodeRadius,
                              width: nodeRadius * 2, height: nodeRadius * 2)

            let isSelected = node.number == selectedNumber
            let isTarget = node.number == targetNumber

            // Shadow for selected
            if isSelected || isTarget {
                let glow = CGRect(x: rect.minX - 4, y: rect.minY - 4,
                                  width: rect.width + 8, height: rect.height + 8)
                ctx.fill(Path(ellipseIn: glow), with: .color(Color(accent).opacity(0.25)))
            }

            // Fill
            ctx.fill(Path(ellipseIn: rect), with: .color(.white))

            // Border
            let borderColor: Color = (isSelected || isTarget) ? Color(accent) : Color.black.opacity(0.8)
            let borderWidth: CGFloat = (isSelected || isTarget) ? 2.5 : 1.5
            ctx.stroke(Path(ellipseIn: rect), with: .color(borderColor), lineWidth: borderWidth)

            // Number label inside
            ctx.draw(
                Text(NodeLabel.label(for: node.number))
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(isSelected || isTarget ? Color(accent) : .black),
                at: pos
            )

            // Word label below
            ctx.draw(
                Text(node.word)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.black),
                at: CGPoint(x: pos.x, y: pos.y + nodeRadius + 10)
            )
        }
    }

    // MARK: - Drag

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                let loc = value.location
                if draggingNodeId == nil {
                    let nodes = state.currentSession?.nodes ?? []
                    if let nearest = nodes.min(by: {
                        distance($0.position, loc) < distance($1.position, loc)
                    }), distance(nearest.position, loc) < nodeRadius * 1.5 {
                        draggingNodeId = nearest.id
                        state.pinNode(id: nearest.id, at: loc)
                    }
                } else if let id = draggingNodeId {
                    state.moveNode(id: id, to: loc)
                }
                lastDragPosition = loc
            }
            .onEnded { _ in
                if let id = draggingNodeId { state.unpinNode(id: id) }
                draggingNodeId = nil
            }
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2))
    }

    // MARK: - HUD

    @ViewBuilder
    private var hudOverlay: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                hudText
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(16)
            }
        }
    }

    @ViewBuilder
    private var hudText: some View {
        switch state.keyboardMode {
        case .idle:
            Text("n add node  ·  1–9 select")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
        case .addingNode:
            Text("Type word · Enter to confirm · Esc to cancel")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(state.accentColor)
        case .nodeSelected(let n):
            Text("[\(NodeLabel.label(for: n))] selected  ·  c connect  ·  d delete  ·  Esc cancel")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.primary)
        case .connectingFrom(let n):
            Text("From [\(NodeLabel.label(for: n))] → press key to connect to  ·  Esc cancel")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(state.accentColor)
        case .choosingEdgeStyle(let f, let t):
            Text("[\(NodeLabel.label(for: f))]→[\(NodeLabel.label(for: t))]  1 line  2 arrow  3 dashed  4 dashed arrow  ·  Esc cancel")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(state.accentColor)
        }
    }
}
