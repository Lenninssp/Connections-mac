import Foundation
import NaturalLanguage

struct KeywordExtractor {
    static func extract(from text: String, count: Int) -> [String] {
        let tokens = tokenize(text)
        let filtered = tokens.filter { !stopWords.contains($0) && $0.count >= 3 }

        var freq: [String: Double] = [:]
        for token in filtered {
            freq[token, default: 0] += 1
        }

        // Bonus for words in first and last sentence
        let sentences = text.components(separatedBy: .init(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let topicWords = Set(
            (sentences.first.map(tokenize) ?? []) +
            (sentences.last.map(tokenize) ?? [])
        )
        for word in topicWords {
            if freq[word] != nil { freq[word]! *= 1.5 }
        }

        return freq.sorted { $0.value > $1.value }
            .prefix(count)
            .map { $0.key }
    }

    private static func tokenize(_ text: String) -> [String] {
        var tokens: [String] = []
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let word = text[range].lowercased()
            tokens.append(word)
            return true
        }
        return tokens
    }

    private static let stopWords: Set<String> = [
        "a","about","above","after","again","against","all","am","an","and","any","are","aren't",
        "as","at","be","because","been","before","being","below","between","both","but","by",
        "can't","cannot","could","couldn't","did","didn't","do","does","doesn't","doing","don't",
        "down","during","each","few","for","from","further","get","got","had","hadn't","has",
        "hasn't","have","haven't","having","he","he'd","he'll","he's","her","here","here's",
        "hers","herself","him","himself","his","how","how's","i","i'd","i'll","i'm","i've",
        "if","in","into","is","isn't","it","it's","its","itself","let's","me","more","most",
        "mustn't","my","myself","no","nor","not","of","off","on","once","only","or","other",
        "ought","our","ours","ourselves","out","over","own","same","shan't","she","she'd",
        "she'll","she's","should","shouldn't","so","some","such","than","that","that's","the",
        "their","theirs","them","themselves","then","there","there's","these","they","they'd",
        "they'll","they're","they've","this","those","through","to","too","under","until","up",
        "very","was","wasn't","we","we'd","we'll","we're","we've","were","weren't","what",
        "what's","when","when's","where","where's","which","while","who","who's","whom","why",
        "why's","will","with","won't","would","wouldn't","you","you'd","you'll","you're",
        "you've","your","yours","yourself","yourselves","also","just","may","might","much",
        "now","shall","use","used","using","via","well","yet","one","two","three","four","five",
        "six","seven","eight","nine","ten","new","old","good","great","many","can","like","make",
        "way","even","back","still","around","another","however","therefore","thus","hence",
        "its","our","their","has","had","have","been","will","would","could","should"
    ]
}
