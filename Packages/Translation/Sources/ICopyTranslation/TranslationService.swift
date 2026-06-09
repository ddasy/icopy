import ICopyCore

public protocol TranslationService: Sendable {
    func translate(_ text: String, to target: TranslationLanguage) async throws -> String
}

public enum TranslationError: Error, Equatable, Sendable {
    case emptyInput
    case server(status: Int, body: String)
    case malformedResponse
    case transport(String)
}
