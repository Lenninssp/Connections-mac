import Foundation
import CoreGraphics

struct WordNode: Identifiable, Equatable {
    let id: UUID
    var word: String
    var number: Int
    var position: CGPoint
    var velocity: CGPoint
    var isPinned: Bool
    var colorIndex: Int?   // 1–9, nil = default accent

    init(id: UUID = UUID(), word: String, number: Int, position: CGPoint = .zero, colorIndex: Int? = nil) {
        self.id = id
        self.word = word
        self.number = number
        self.position = position
        self.velocity = .zero
        self.isPinned = false
        self.colorIndex = colorIndex
    }
}
