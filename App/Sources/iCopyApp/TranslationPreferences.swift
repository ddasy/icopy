import Combine
import Foundation
import ICopyTranslation

@MainActor
final class TranslationPreferences: ObservableObject {
    static let defaultBaseURL = "http://localhost:1234"
    static let defaultModelName = "local-model"

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
        LMStudioConfig(
            baseURL: normalizedBaseURL ?? LMStudioConfig.default.baseURL,
            modelName: trimmedModelName.isEmpty ? Self.defaultModelName : trimmedModelName
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

    private static let baseURLKey = "translation.baseURL"
    private static let modelNameKey = "translation.modelName"
}
