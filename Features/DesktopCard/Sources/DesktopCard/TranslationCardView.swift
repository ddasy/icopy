import AppKit
import ICopyCore
import SwiftUI

/// 翻译卡片内容:上方原文输入(本地持有文本),下方方向行 + 流式译文。三区状态隔离——
/// 方向行/译文区各自观察 TranslationController,其更新绝不重渲染输入区;锁定态上报译文复制区域。
struct TranslationCardView: View {
    let viewModel: DesktopCardViewModel
    let appearance: StickyCardAppearance
    let onCopied: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            sourcePane
                .frame(maxHeight: .infinity, alignment: .top)

            Divider().opacity(0.45)

            if let controller = viewModel.translationController {
                TranslationDirectionRow(controller: controller, appearance: appearance)

                Divider().opacity(0.25)

                TranslationResultPane(controller: controller, appearance: appearance) {
                    if viewModel.copyTranslation() { onCopied() }
                }
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
    }

    private var sourcePane: some View {
        ScrollView {
            TranslationSourceTextView(
                initialText: viewModel.translation?.sourceText ?? "",
                font: nsFont,
                textColor: nsTextColor,
                onCommit: { viewModel.setSourceText($0) }
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
        }
        .scrollContentBackground(.hidden)
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

/// 方向提示 + 原文朗读;只随提交的原文(词级频率)更新。
private struct TranslationDirectionRow: View {
    @ObservedObject var controller: TranslationController
    let appearance: StickyCardAppearance
    @StateObject private var speechPlayer = TranslationSpeechPlayer()

    var body: some View {
        HStack {
            Text(directionLabel)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(appearance.swiftUITextColor.opacity(0.7))
            Button {
                speechPlayer.toggle(text: controller.committedSource, language: sourceLanguage)
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

    private var directionLabel: String {
        StickyCardItem.detectTarget(for: controller.committedSource) == .english ? "中 -> EN" : "EN -> 中"
    }

    private var sourceLanguage: TranslationLanguage {
        StickyCardItem.detectTarget(for: controller.committedSource) == .english ? .chinese : .english
    }

    private var sourceTextIsEmpty: Bool {
        controller.committedSource.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// 译文区:流式增量渲染,点击复制;只有本区随每个译文片段重渲染。
private struct TranslationResultPane: View {
    @ObservedObject var controller: TranslationController
    let appearance: StickyCardAppearance
    let onCopy: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                statusContent
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(10)
            .contentShape(Rectangle())
            .reportCopyRegion(.translation)
            .onTapGesture { onCopy() }
        }
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private var statusContent: some View {
        switch controller.status {
        case .idle:
            Text("译文会在原文停止输入后自动显示")
                .font(.system(size: max(11, appearance.fontSize - 2)))
                .foregroundStyle(appearance.swiftUITextColor.opacity(0.55))
        case .translating:
            if controller.translatedText.isEmpty {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在翻译...")
                        .font(.system(size: max(11, appearance.fontSize - 2)))
                }
                .foregroundStyle(appearance.swiftUITextColor.opacity(0.7))
            } else {
                translatedTextView.opacity(0.85)
            }
        case .done:
            translatedTextView
        case .failed(let message):
            Text(message)
                .font(.system(size: max(11, appearance.fontSize - 2)))
                .foregroundStyle(.red.opacity(0.85))
        }
    }

    private var translatedTextView: some View {
        Text(controller.translatedText.isEmpty ? " " : controller.translatedText)
            .font(appearance.swiftUIFont)
            .foregroundStyle(appearance.swiftUITextColor)
    }
}
