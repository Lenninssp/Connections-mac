import Foundation
import CoreGraphics

final class ForceDirectedLayout {
    private let repulsionK: Double = 9000
    private let springK: Double = 0.04
    private let restLength: Double = 160
    private let damping: Double = 0.82
    private let gravityK: Double = 0.008
    private let minDistance: Double = 60
    private let stabilityThreshold: Double = 0.5

    var onUpdate: (([WordNode]) -> Void)?

    private var nodes: [WordNode] = []
    private var edges: [Edge] = []
    private var timer: Timer?
    private var center: CGPoint = .zero

    func start(nodes: [WordNode], edges: [Edge], center: CGPoint) {
        self.nodes = nodes
        self.edges = edges
        self.center = center
        stopTimer()
        guard !nodes.isEmpty else { return }
        startTimer()
    }

    func update(nodes: [WordNode], edges: [Edge]) {
        self.nodes = nodes
        self.edges = edges
        if timer == nil && !nodes.isEmpty { startTimer() }
    }

    func updateCenter(_ center: CGPoint) {
        self.center = center
    }

    func pinNode(id: UUID, at position: CGPoint) {
        if let i = nodes.firstIndex(where: { $0.id == id }) {
            nodes[i].isPinned = true
            nodes[i].position = position
            nodes[i].velocity = .zero
            if timer == nil { startTimer() }
        }
    }

    func moveNode(id: UUID, to position: CGPoint) {
        if let i = nodes.firstIndex(where: { $0.id == id }) {
            nodes[i].position = position
            nodes[i].velocity = .zero
        }
    }

    func unpinNode(id: UUID) {
        if let i = nodes.firstIndex(where: { $0.id == id }) {
            nodes[i].isPinned = false
        }
    }

    func stop() { stopTimer() }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard !nodes.isEmpty else { stopTimer(); return }

        var forces = Array(repeating: CGPoint.zero, count: nodes.count)

        // Repulsion
        for i in 0..<nodes.count {
            for j in (i + 1)..<nodes.count {
                let dx = nodes[i].position.x - nodes[j].position.x
                let dy = nodes[i].position.y - nodes[j].position.y
                let distSq = max(dx * dx + dy * dy, minDistance * minDistance)
                let dist = sqrt(distSq)
                let f = repulsionK / distSq
                let fx = f * dx / dist
                let fy = f * dy / dist
                forces[i].x += fx
                forces[i].y += fy
                forces[j].x -= fx
                forces[j].y -= fy
            }
        }

        // Spring attraction for connected pairs
        let nodeIndex = Dictionary(uniqueKeysWithValues: nodes.enumerated().map { ($0.element.id, $0.offset) })
        for edge in edges {
            guard let i = nodeIndex[edge.fromId], let j = nodeIndex[edge.toId] else { continue }
            let dx = nodes[j].position.x - nodes[i].position.x
            let dy = nodes[j].position.y - nodes[i].position.y
            let dist = max(sqrt(dx * dx + dy * dy), 1)
            let f = springK * (dist - restLength)
            let fx = f * dx / dist
            let fy = f * dy / dist
            forces[i].x += fx
            forces[i].y += fy
            forces[j].x -= fx
            forces[j].y -= fy
        }

        // Gravity toward center
        for i in 0..<nodes.count {
            forces[i].x += gravityK * (center.x - nodes[i].position.x)
            forces[i].y += gravityK * (center.y - nodes[i].position.y)
        }

        // Integrate
        var maxV: Double = 0
        for i in 0..<nodes.count {
            guard !nodes[i].isPinned else { continue }
            nodes[i].velocity.x = (nodes[i].velocity.x + forces[i].x) * damping
            nodes[i].velocity.y = (nodes[i].velocity.y + forces[i].y) * damping
            nodes[i].position.x += nodes[i].velocity.x
            nodes[i].position.y += nodes[i].velocity.y
            let speed = sqrt(nodes[i].velocity.x * nodes[i].velocity.x + nodes[i].velocity.y * nodes[i].velocity.y)
            maxV = max(maxV, speed)
        }

        onUpdate?(nodes)

        if maxV < stabilityThreshold { stopTimer() }
    }
}
