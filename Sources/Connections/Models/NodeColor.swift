import SwiftUI

enum NodeColor {
    // Apple's adaptive system colors — vibrant in both light and dark modes
    static let palette: [(color: Color, name: String)] = [
        (Color(red: 1.00, green: 0.27, blue: 0.27), "Red"),      // 1
        (Color(red: 1.00, green: 0.58, blue: 0.00), "Orange"),   // 2
        (Color(red: 0.95, green: 0.77, blue: 0.06), "Yellow"),   // 3
        (Color(red: 0.20, green: 0.78, blue: 0.35), "Green"),    // 4
        (Color(red: 0.00, green: 0.72, blue: 0.82), "Cyan"),     // 5
        (Color(red: 0.20, green: 0.47, blue: 1.00), "Blue"),     // 6
        (Color(red: 0.45, green: 0.30, blue: 1.00), "Indigo"),   // 7
        (Color(red: 0.69, green: 0.22, blue: 0.95), "Purple"),   // 8
        (Color(red: 1.00, green: 0.22, blue: 0.56), "Pink"),     // 9
    ]

    static func color(for index: Int?) -> Color? {
        guard let index, index >= 1, index <= palette.count else { return nil }
        return palette[index - 1].color
    }

    static func name(for index: Int?) -> String? {
        guard let index, index >= 1, index <= palette.count else { return nil }
        return palette[index - 1].name
    }
}
