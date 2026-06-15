import Foundation

struct DeepSeekService {
    private static let endpoint = URL(string: "https://api.deepseek.com/chat/completions")!
    private static var apiKey: String {
        ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"] ?? ""
    }

    static func extractKeywords(from paragraph: String, count: Int) async throws -> [String] {
        let prompt = """
        Extract exactly \(count) keywords that capture the core ideas of this paragraph. \
        Return ONLY a comma-separated list of single words, no punctuation, no numbering, no explanation:

        \(paragraph)
        """

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": "deepseek-chat",
            "messages": [["role": "user", "content": prompt]],
            "max_tokens": 60,
            "temperature": 0.3
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw APIError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let content = (json?["choices"] as? [[String: Any]])?.first
            .flatMap { $0["message"] as? [String: Any] }
            .flatMap { $0["content"] as? String } ?? ""

        return content
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
            .prefix(count)
            .map { String($0) }
    }

    enum APIError: LocalizedError {
        case httpError(Int)
        var errorDescription: String? {
            if case .httpError(let code) = self { return "DeepSeek API returned HTTP \(code)" }
            return nil
        }
    }
}
