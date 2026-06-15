import Foundation

enum NodeLabel {
    // Sequence of keys used to identify/select nodes.
    // Skips 'c', 'd', 'n' — reserved as commands in nodeSelected/idle modes.
    static let sequence: [String] = {
        var labels: [String] = []
        for i in 1...9 { labels.append("\(i)") }
        let skipLetters: Set<Character> = ["c", "d", "n"]
        for scalar in UnicodeScalar("a").value...UnicodeScalar("z").value {
            let ch = Character(UnicodeScalar(scalar)!)
            if !skipLetters.contains(ch) { labels.append(String(ch)) }
        }
        let symbols = ["!", "@", "#", "$", "%", "^", "&", "*", "-", "=", "[", "]", ";", "'", ",", ".", "/", "`"]
        labels.append(contentsOf: symbols)
        return labels
    }()

    // node.number is 1-based internal index
    static func label(for number: Int) -> String {
        let idx = number - 1
        guard idx >= 0, idx < sequence.count else { return "?" }
        return sequence[idx]
    }

    static func number(forKey key: String) -> Int? {
        guard let idx = sequence.firstIndex(of: key) else { return nil }
        return idx + 1
    }
}
