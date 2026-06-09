import Foundation
import ICopyCore

public struct LMStudioTranslationService: TranslationService {
    private let config: LMStudioConfig
    private let session: URLSession

    public init(config: LMStudioConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    public func translate(_ text: String, to target: TranslationLanguage) async throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw TranslationError.emptyInput }

        var request = URLRequest(url: config.baseURL.appendingPathComponent("v1/chat/completions"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(CompletionRequest(
            model: config.modelName,
            temperature: 0.2,
            stream: false,
            messages: [
                CompletionMessage(
                    role: "system",
                    content: "You are a translation engine. Translate the user's text into \(target.displayName). Output ONLY the translation, with no explanations, quotes, or extra text."
                ),
                CompletionMessage(role: "user", content: trimmed)
            ]
        ))

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw TranslationError.transport(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else { throw TranslationError.malformedResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw TranslationError.server(status: http.statusCode, body: String(data: data, encoding: .utf8) ?? "")
        }
        do {
            let decoded = try JSONDecoder().decode(CompletionResponse.self, from: data)
            guard let content = decoded.choices.first?.message.content else {
                throw TranslationError.malformedResponse
            }
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch let error as TranslationError {
            throw error
        } catch {
            throw TranslationError.malformedResponse
        }
    }
}

private extension TranslationLanguage {
    var displayName: String {
        switch self {
        case .english: "English"
        case .chinese: "Simplified Chinese"
        }
    }
}

private struct CompletionRequest: Encodable {
    let model: String
    let temperature: Double
    let stream: Bool
    let messages: [CompletionMessage]
}

private struct CompletionMessage: Codable {
    let role: String
    let content: String
}

private struct CompletionResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: CompletionMessage
    }
}
