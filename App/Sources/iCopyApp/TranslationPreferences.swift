import Combine
import Foundation
import ICopyTranslation

@MainActor
final class TranslationPreferences: ObservableObject {
    nonisolated static let defaultBaseURL = "http://localhost:1234"
    nonisolated static let defaultModelName = "local-model"

    @Published var baseURL: String {
        didSet { UserDefaults.standard.set(baseURL, forKey: Self.baseURLKey) }
    }

    @Published var modelName: String {
        didSet { UserDefaults.standard.set(modelName, forKey: Self.modelNameKey) }
    }

    init() {
        let defaults = UserDefaults.standard
        baseURL = defaults.string(forKey: Self.baseURLKey) ?? Self.defaultBaseURL
        modelName = defaults.string(forKey: Self.modelNameKey) ?? Self.defaultModelName
    }

    var config: LMStudioConfig {
        Self.makeConfig(baseURL: baseURL, modelName: modelName)
    }

    /// Reads the persisted endpoint/model straight from UserDefaults. Thread-safe and
    /// nonisolated so the translation service can pull the current config on each request
    /// (no observers, no main-actor hop) and pick up settings changes without a restart.
    nonisolated static func currentConfig() -> LMStudioConfig {
        let defaults = UserDefaults.standard
        return makeConfig(
            baseURL: defaults.string(forKey: baseURLKey) ?? defaultBaseURL,
            modelName: defaults.string(forKey: modelNameKey) ?? defaultModelName
        )
    }

    nonisolated static func makeConfig(baseURL: String, modelName: String) -> LMStudioConfig {
        let trimmedModel = modelName.trimmingCharacters(in: .whitespacesAndNewlines)
        let parsedURL = URL(string: baseURL.trimmingCharacters(in: .whitespacesAndNewlines))
        return LMStudioConfig(
            baseURL: parsedURL ?? LMStudioConfig.default.baseURL,
            modelName: trimmedModel.isEmpty ? defaultModelName : trimmedModel
        )
    }

    var normalizedBaseURL: URL? {
        URL(string: baseURL.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    var trimmedModelName: String {
        modelName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func reset() {
        baseURL = Self.defaultBaseURL
        modelName = Self.defaultModelName
    }

    nonisolated private static let baseURLKey = "translation.baseURL"
    nonisolated private static let modelNameKey = "translation.modelName"
}
