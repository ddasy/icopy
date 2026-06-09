import Foundation

public struct LMStudioConfig: Equatable, Sendable {
    public var baseURL: URL
    public var modelName: String

    public init(baseURL: URL, modelName: String) {
        self.baseURL = baseURL
        self.modelName = modelName
    }

    public static let `default` = LMStudioConfig(
        baseURL: URL(string: "http://localhost:1234")!,
        modelName: "local-model"
    )
}
