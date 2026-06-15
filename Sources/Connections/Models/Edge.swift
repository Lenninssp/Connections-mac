import Foundation

struct Edge: Identifiable, Equatable {
    let id: UUID
    var fromId: UUID
    var toId: UUID
    var style: EdgeStyle

    init(id: UUID = UUID(), fromId: UUID, toId: UUID, style: EdgeStyle = .arrow) {
        self.id = id
        self.fromId = fromId
        self.toId = toId
        self.style = style
    }
}
