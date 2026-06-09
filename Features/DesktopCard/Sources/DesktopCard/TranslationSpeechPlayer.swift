import AVFoundation
import ICopyCore

@MainActor
final class TranslationSpeechPlayer: ObservableObject {
    @Published private(set) var isSpeaking = false

    private let synthesizer = AVSpeechSynthesizer()
    private var pollTimer: Timer?

    func toggle(text: String, language: TranslationLanguage) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
            isSpeaking = false
            pollTimer?.invalidate()
            pollTimer = nil
            return
        }

        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = AVSpeechSynthesisVoice(language: language.voiceCode)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)
        isSpeaking = true
        startPolling()
    }

    private func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshSpeakingState()
            }
        }
    }

    private func refreshSpeakingState() {
        guard !synthesizer.isSpeaking else { return }
        isSpeaking = false
        pollTimer?.invalidate()
        pollTimer = nil
    }
}

private extension TranslationLanguage {
    var voiceCode: String {
        switch self {
        case .english: "en-US"
        case .chinese: "zh-CN"
        }
    }
}
