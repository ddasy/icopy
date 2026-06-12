import ICopyCore

public protocol TranslationService: Sendable {
    func translate(_ text: String, to target: TranslationLanguage) async throws -> String
    /// 以增量片段流式返回译文;终止流(中断迭代)即取消底层请求。
    func translateStream(_ text: String, to target: TranslationLanguage) -> AsyncThrowingStream<String, Error>
}

public extension TranslationService {
    /// 默认实现:退化为一次性返回完整译文的单元素流。
    func translateStream(_ text: String, to target: TranslationLanguage) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    continuation.yield(try await translate(text, to: target))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

public enum TranslationError: Error, Equatable, Sendable {
    case emptyInput
    case server(status: Int, body: String)
    case malformedResponse
    case transport(String)
}
