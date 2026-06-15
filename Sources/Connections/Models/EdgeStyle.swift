import Foundation

enum EdgeStyle: Int, CaseIterable, Codable {
    case line = 0
    case arrow = 1
    case dashed = 2
    case dashedArrow = 3

    var label: String {
        switch self {
        case .line: return "Line"
        case .arrow: return "Arrow"
        case .dashed: return "Dashed"
        case .dashedArrow: return "Dashed Arrow"
        }
    }

    var keyHint: String {
        switch self {
        case .line: return "1"
        case .arrow: return "2"
        case .dashed: return "3"
        case .dashedArrow: return "4"
        }
    }
}
