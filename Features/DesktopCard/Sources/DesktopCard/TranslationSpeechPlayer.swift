import AVFoundation
import ICopyCore

@MainActor
final class TranslationSpeechPlayer: ObservableObject {
    @Published private(set) var isSpeaking = false

    private let synthesizer = AVSpeechSynthesizer()
    private let piperConfig = LocalPiperConfig.default
    private var piperTask: Task<Void, Never>?
    private var audioPlayer: AVAudioPlayer?
    private var audioFileURL: URL?
    private var playbackToken = UUID()
    private var pollTimer: Timer?
    private let playbackRate: Float = 0.42

    func toggle(text: String, language: TranslationLanguage) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if isPlaybackActive {
            stopPlayback()
            return
        }

        if language == .english, piperConfig.isAvailable {
            speakWithPiper(text: trimmed)
            return
        }

        speakWithSystemVoice(text: trimmed, language: language)
    }

    private var isPlaybackActive: Bool {
        synthesizer.isSpeaking
        || piperTask != nil
        || (audioPlayer?.isPlaying == true)
    }

    private func stopPlayback() {
        playbackToken = UUID()
        synthesizer.stopSpeaking(at: .immediate)
        piperTask?.cancel()
        piperTask = nil
        audioPlayer?.stop()
        audioPlayer = nil
        removeAudioFile()
        isSpeaking = false
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func speakWithSystemVoice(text: String, language: TranslationLanguage) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = Self.bestVoice(for: language)
        utterance.rate = playbackRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        synthesizer.speak(utterance)
        isSpeaking = true
        startPolling()
    }

    private func speakWithPiper(text: String) {
        stopPlayback()
        isSpeaking = true
        let config = piperConfig
        let token = UUID()
        playbackToken = token
        piperTask = Task { @MainActor in
            let outputURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("icopy-piper-\(UUID().uuidString).wav")
            let generated = await Self.generatePiperAudio(
                text: text,
                outputURL: outputURL,
                config: config
            )
            guard !Task.isCancelled, self.playbackToken == token, generated else {
                try? FileManager.default.removeItem(at: outputURL)
                if self.playbackToken == token {
                    self.piperTask = nil
                    self.isSpeaking = false
                }
                return
            }
            do {
                let player = try AVAudioPlayer(contentsOf: outputURL)
                self.audioPlayer = player
                self.audioFileURL = outputURL
                player.prepareToPlay()
                player.play()
                self.startPolling()
            } catch {
                try? FileManager.default.removeItem(at: outputURL)
                self.audioPlayer = nil
                self.isSpeaking = false
            }
            self.piperTask = nil
        }
    }

    private nonisolated static func generatePiperAudio(
        text: String,
        outputURL: URL,
        config: LocalPiperConfig
    ) async -> Bool {
        await Task.detached {
            let process = Process()
            process.executableURL = config.executableURL
            process.currentDirectoryURL = config.runtimeDirectory
            process.arguments = [
                "--model", config.modelURL.path,
                "--config", config.modelConfigURL.path,
                "--espeak-data", config.espeakDataURL.path,
                "--length-scale", String(config.lengthScale),
                "--noise-scale", String(config.noiseScale),
                "--noise-w-scale", String(config.noiseWScale),
                "--output", outputURL.path,
                "--",
                text
            ]
            process.standardOutput = Pipe()
            process.standardError = Pipe()
            do {
                try process.run()
                process.waitUntilExit()
                return process.terminationStatus == 0
            } catch {
                return false
            }
        }.value
    }

    private static func bestVoice(for language: TranslationLanguage) -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == language.voiceCode }
            .sorted { lhs, rhs in
                qualityRank(lhs.quality) > qualityRank(rhs.quality)
            }
        return voices.first ?? AVSpeechSynthesisVoice(language: language.voiceCode)
    }

    private static func qualityRank(_ quality: AVSpeechSynthesisVoiceQuality) -> Int {
        switch quality {
        case .premium: 3
        case .enhanced: 2
        case .default: 1
        @unknown default: 0
        }
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
        guard !synthesizer.isSpeaking, audioPlayer?.isPlaying != true else { return }
        isSpeaking = false
        audioPlayer = nil
        removeAudioFile()
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func removeAudioFile() {
        if let audioFileURL {
            try? FileManager.default.removeItem(at: audioFileURL)
        }
        audioFileURL = nil
    }
}

private struct LocalPiperConfig: Sendable {
    let runtimeDirectory: URL
    let executableURL: URL
    let modelURL: URL
    let modelConfigURL: URL
    let espeakDataURL: URL
    let lengthScale: Double
    let noiseScale: Double
    let noiseWScale: Double

    var isAvailable: Bool {
        let fileManager = FileManager.default
        return fileManager.isExecutableFile(atPath: executableURL.path)
            && fileManager.fileExists(atPath: modelURL.path)
            && fileManager.fileExists(atPath: modelConfigURL.path)
            && fileManager.fileExists(atPath: espeakDataURL.path)
    }

    static var `default`: LocalPiperConfig {
        let runtimeDirectory = bundledRuntimeDirectory()
        return LocalPiperConfig(
            runtimeDirectory: runtimeDirectory,
            executableURL: runtimeDirectory.appendingPathComponent("bin/icopy-piper"),
            modelURL: runtimeDirectory.appendingPathComponent("voices/en_US-lessac-medium.onnx"),
            modelConfigURL: runtimeDirectory.appendingPathComponent("voices/en_US-lessac-medium.onnx.json"),
            espeakDataURL: runtimeDirectory.appendingPathComponent("espeak-ng-data"),
            lengthScale: 1.25,
            noiseScale: 0.55,
            noiseWScale: 0.8
        )
    }

    private static func bundledRuntimeDirectory() -> URL {
        if let resourceURL = Bundle.main.resourceURL {
            let bundledURL = resourceURL.appendingPathComponent("TTS")
            if FileManager.default.fileExists(atPath: bundledURL.path) {
                return bundledURL
            }
        }

        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Resources/TTS")
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
