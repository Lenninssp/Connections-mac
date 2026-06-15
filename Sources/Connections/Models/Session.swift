import Foundation

struct Session: Identifiable, Equatable {
    let id: UUID
    var name: String
    var paragraph: String
    var createdAt: Date
    var nodes: [WordNode]
    var edges: [Edge]

    init(id: UUID = UUID(), name: String, paragraph: String = "", createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.paragraph = paragraph
        self.createdAt = createdAt
        self.nodes = []
        self.edges = []
    }
}
