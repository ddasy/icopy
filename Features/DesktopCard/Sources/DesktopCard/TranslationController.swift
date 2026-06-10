import Combine
import Foundation
import ICopyCore
import ICopyTranslation

/// 翻译卡片的请求管线与活跃状态:短合并窗吸收击键、最新提交优先(取消过期请求/流)、
/// 流式增量更新译文。状态与输入视图隔离——发布只驱动方向行与译文区。
@MainActor
public final class TranslationController: ObservableObject {
    @Published public private(set) var committedSource: String = ""
    @Published public private(set) var translatedText: String = ""
    @Published public private(set) var status: TranslationStatus = .idle

    /// 一次翻译尘埃落定(成功/失败)时回调,供持有者持久化与后续动作。
    public var onSettled: ((_ source: String, _ translatedText: String, _ target: TranslationLanguage, _ status: TranslationStatus) -> Void)?

    private let translator: TranslationService
    private let coalesceWindow: Duration
    private var task: Task<Void, Never>?
    private var lastTranslatedSource = ""

    public init(translator: TranslationService, coalesceWindow: Duration = .milliseconds(250)) {
        self.translator = translator
        self.coalesceWindow = coalesceWindow
    }

    /// 恢复持久化状态;原文尚无对应完成译文时立即补译。
    public func restore(_ translation: StickyCardTranslation) {
        task?.cancel()
        task = nil
        committedSource = translation.sourceText
        translatedText = translation.translatedText
        status = translation.status
        let trimmed = translation.sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        if translation.status == .done,
           !translation.translatedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lastTranslatedSource = trimmed
        } else {
            lastTranslatedSource = ""
        }
        if !trimmed.isEmpty, trimmed != lastTranslatedSource {
            scheduleTranslation(of: trimmed)
        }
    }

    /// 输入视图每次提交(已确认、非 IME 组合中)文本时调用。
    public func setSource(_ text: String) {
        committedSource = text
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            reset()
            return
        }
        guard trimmed != lastTranslatedSource else {
            // 文本改回已译内容:丢弃待发请求,保留现有译文。
            task?.cancel()
            task = nil
            return
        }
        scheduleTranslation(of: trimmed)
    }

    public func reset() {
        task?.cancel()
        task = nil
        translatedText = ""
        status = .idle
        lastTranslatedSource = ""
    }

    private func scheduleTranslation(of source: String) {
        task?.cancel()
        task = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: self.coalesceWindow)
            guard !Task.isCancelled else { return }
            await self.runTranslation(source: source)
        }
    }

    private func runTranslation(source: String) async {
        status = .translating
        translatedText = ""
        let target = StickyCardItem.detectTarget(for: source)
        var accumulated = ""
        do {
            for try await delta in translator.translateStream(source, to: target) {
                guard !Task.isCancelled else { return }
                accumulated += delta
                translatedText = accumulated
            }
            guard !Task.isCancelled else { return }
            translatedText = accumulated.trimmingCharacters(in: .whitespacesAndNewlines)
            status = .done
            lastTranslatedSource = source
            onSettled?(source, translatedText, target, .done)
        } catch {
            guard !Task.isCancelled else { return }
            let message = Self.message(for: error)
            status = .failed(message)
            onSettled?(source, translatedText, target, .failed(message))
        }
    }

    private static func message(for error: Error) -> String {
        if let translationError = error as? TranslationError {
            switch translationError {
            case .emptyInput: return "请输入要翻译的内容"
            case .server(let status, let body): return "LM Studio 返回 \(status): \(body)"
            case .malformedResponse: return "LM Studio 响应格式不正确"
            case .transport(let message): return "连接失败: \(message)"
            }
        }
        return error.localizedDescription
    }
}
