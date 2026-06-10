import AppKit
import ICopyCore
import SwiftUI

/// 翻译卡片内容:上方原文输入,下方只读译文;锁定态上报译文复制区域。
struct TranslationCardView: View {
    @ObservedObject var viewModel: DesktopCardViewModel
    let appearance: StickyCardAppearance
    let onCopied: () -> Void
    @StateObject private var speechPlayer = TranslationSpeechPlayer()

    var body: some View {
        VStack(spacing: 0) {
            sourcePane
                .frame(maxHeight: .infinity, alignment: .top)

            Divider().opacity(0.45)

            directionRow

            Divider().opacity(0.25)

            translationPane
                .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    @ViewBuilder
    private var sourcePane: some View {
        ScrollView {
            SectionTextView(
                text: Binding(
                    get: { sourceText },
                    set: { viewModel.setSourceText($0) }
                ),
                font: nsFont,
                textColor: nsTextColor,
                onFocus: {},
                onCaret: { _ in }
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
        }
        .scrollContentBackground(.hidden)
    }

    private var directionRow: some View {
        HStack {
            Text(directionLabel)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(appearance.swiftUITextColor.opacity(0.7))
            Button {
                speechPlayer.toggle(text: sourceText, language: sourceLanguage)
            } label: {
                Image(systemName: speechPlayer.isSpeaking ? "speaker.slash" : "speaker.wave.2")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(appearance.swiftUITextColor.opacity(sourceTextIsEmpty ? 0.3 : 0.7))
            .disabled(sourceTextIsEmpty)
            .help("朗读原文")
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private var translationPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                statusContent
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(10)
            .contentShape(Rectangle())
            .reportCopyRegion(.translation)
            .onTapGesture {
                if viewModel.copyTranslation() { onCopied() }
            }
        }
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private var statusContent: some View {
        switch viewModel.translation?.status ?? .idle {
        case .idle:
            Text("译文会在原文停止输入后自动显示")
                .font(.system(size: max(11, appearance.fontSize - 2)))
                .foregroundStyle(appearance.swiftUITextColor.opacity(0.55))
        case .translating:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("正在翻译...")
                    .font(.system(size: max(11, appearance.fontSize - 2)))
            }
            .foregroundStyle(appearance.swiftUITextColor.opacity(0.7))
        case .done:
            Text(translatedText.isEmpty ? " " : translatedText)
                .font(appearance.swiftUIFont)
                .foregroundStyle(appearance.swiftUITextColor)
        case .failed(let message):
            Text(message)
                .font(.system(size: max(11, appearance.fontSize - 2)))
                .foregroundStyle(.red.opacity(0.85))
        }
    }

    private var sourceText: String {
        viewModel.translation?.sourceText ?? ""
    }

    private var translatedText: String {
        viewModel.translation?.translatedText ?? ""
    }

    private var directionLabel: String {
        StickyCardItem.detectTarget(for: sourceText) == .english ? "中 -> EN" : "EN -> 中"
    }

    private var sourceLanguage: TranslationLanguage {
        StickyCardItem.detectTarget(for: sourceText) == .english ? .chinese : .english
    }

    private var sourceTextIsEmpty: Bool {
        sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var nsFont: NSFont {
        let weight: NSFont.Weight
        switch appearance.fontWeight {
        case .regular: weight = .regular
        case .medium: weight = .medium
        case .semibold: weight = .semibold
        case .bold: weight = .bold
        }
        if let family = appearance.fontFamily, !family.isEmpty,
           let font = NSFont(name: family, size: appearance.fontSize) {
            return font
        }
        return NSFont.systemFont(ofSize: appearance.fontSize, weight: weight)
    }

    private var nsTextColor: NSColor {
        let color = appearance.textColor
        return NSColor(
            srgbRed: color.red,
            green: color.green,
            blue: color.blue,
            alpha: color.alpha * appearance.textIntensity
        )
    }
}
