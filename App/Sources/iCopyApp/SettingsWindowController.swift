import AppKit
import ClipboardPanel
import SwiftUI

@MainActor
final class SettingsWindowController {
    private let appearance: ClipboardAppearancePreferences
    private let shortcutSettings: ShortcutSettingsModel
    private let loginItemSettings: LoginItemSettings
    private var window: NSWindow?

    init(
        appearance: ClipboardAppearancePreferences,
        shortcutSettings: ShortcutSettingsModel,
        loginItemSettings: LoginItemSettings
    ) {
        self.appearance = appearance
        self.shortcutSettings = shortcutSettings
        self.loginItemSettings = loginItemSettings
    }

    func show() {
        let window = window ?? makeWindow()
        self.window = window
        window.level = .floating + 1
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makeWindow() -> NSWindow {
        let view = SettingsView(
            appearance: appearance,
            shortcutSettings: shortcutSettings,
            loginItemSettings: loginItemSettings
        )
        let controller = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: controller)
        window.title = "iCopy 设置"
        window.setContentSize(NSSize(width: 680, height: 420))
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.level = .floating + 1
        return window
    }
}

@MainActor
final class ShortcutSettingsModel: ObservableObject {
    @Published private(set) var title: String
    @Published private(set) var usesDefaultShortcut: Bool

    var customize: () -> Void = {}
    var useDefault: () -> Void = {}

    init(preference: ShortcutPreference) {
        title = preference.title
        usesDefaultShortcut = preference == .doubleCommand
    }

    func refresh(preference: ShortcutPreference) {
        title = preference.title
        usesDefaultShortcut = preference == .doubleCommand
    }
}

private enum SettingsSection: Hashable {
    case general
    case appearance
    case shortcut
}

private struct SettingsView: View {
    @ObservedObject var appearance: ClipboardAppearancePreferences
    @ObservedObject var shortcutSettings: ShortcutSettingsModel
    @ObservedObject var loginItemSettings: LoginItemSettings
    @State private var section: SettingsSection = .general

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            Group {
                switch section {
                case .general:
                    GeneralSettingsView(settings: loginItemSettings)
                case .appearance:
                    AppearanceSettingsView(appearance: appearance)
                case .shortcut:
                    ShortcutSettingsView(settings: shortcutSettings)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: 680, height: 420)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            sidebarItem(.general, title: "通用", icon: "gearshape")
            sidebarItem(.appearance, title: "外观", icon: "paintbrush")
            sidebarItem(.shortcut, title: "呼出", icon: "keyboard")
            Spacer()
        }
        .padding(10)
        .frame(width: 150)
        .background(.thinMaterial)
    }

    private func sidebarItem(_ target: SettingsSection, title: String, icon: String) -> some View {
        Button {
            section = target
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .frame(width: 18)
                Text(title)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
            .background(
                section == target ? Color.accentColor.opacity(0.18) : .clear,
                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
            )
            .foregroundStyle(section == target ? Color.accentColor : .primary)
        }
        .buttonStyle(.plain)
    }
}

private struct GeneralSettingsView: View {
    @ObservedObject var settings: LoginItemSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("通用")
                .font(.headline)

            Toggle(isOn: Binding(
                get: { settings.isEnabled },
                set: { settings.setEnabled($0) }
            )) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("开机自启")
                    Text("登录 macOS 后自动启动 iCopy。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
            .disabled(!settings.isAvailable)

            if !settings.isAvailable {
                Text("当前为开发运行模式，打包为 App 后可设置开机自启。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage = settings.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Spacer()
        }
        .padding(18)
        .onAppear {
            settings.refresh()
        }
    }
}

private struct AppearanceSettingsView: View {
    @ObservedObject var appearance: ClipboardAppearancePreferences

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("外观")
                .font(.headline)

            settingRow(label: "面板透明度", value: $appearance.panelOpacity)
            settingRow(label: "字体亮度", value: $appearance.textIntensity)

            panelPreview

            Button {
                appearance.reset()
            } label: {
                Label("恢复默认", systemImage: "arrow.counterclockwise")
            }
            .disabled(
                appearance.panelOpacity == ClipboardAppearancePreferences.defaultPanelOpacity
                && appearance.textIntensity == ClipboardAppearancePreferences.defaultTextIntensity
            )

            Spacer()
        }
        .padding(18)
    }

    private func settingRow(label: String, value: Binding<Double>) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .frame(width: 86, alignment: .leading)
            Slider(value: value, in: 0.1...1.0)
                .frame(maxWidth: 280)
            Text(value.wrappedValue.formatted(.percent.precision(.fractionLength(0))))
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 46, alignment: .trailing)
        }
    }

    private var panelPreview: some View {
        let fade = min(
            appearance.textIntensity / ClipboardAppearancePreferences.defaultTextIntensity,
            1
        )
        let deepen = max(
            0,
            (appearance.textIntensity - ClipboardAppearancePreferences.defaultTextIntensity)
            / (1 - ClipboardAppearancePreferences.defaultTextIntensity)
        )

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("iCopy")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Image(systemName: "gearshape")
            }
            Text("预览剪切板条目的标题")
                .font(.system(size: 13, weight: .medium))
            Text("最近复制")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .opacity(fade)
        .overlay(
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("iCopy")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Image(systemName: "gearshape")
                }
                Text("预览剪切板条目的标题")
                    .font(.system(size: 13, weight: .medium))
                Text("最近复制")
                    .font(.caption)
            }
            .foregroundStyle(Color(nsColor: .labelColor))
            .padding(12)
            .opacity(deepen)
            .allowsHitTesting(false)
        )
        .frame(width: 300)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(appearance.panelOpacity)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14))
                .opacity(appearance.panelOpacity)
        )
    }
}

private struct ShortcutSettingsView: View {
    @ObservedObject var settings: ShortcutSettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("呼出")
                .font(.headline)

            HStack(spacing: 12) {
                Text("当前快捷键")
                    .frame(width: 86, alignment: .leading)
                Text(settings.title)
                    .font(.system(.body, design: .monospaced))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
            }

            HStack(spacing: 10) {
                Button {
                    settings.customize()
                } label: {
                    Label("自定义快捷键", systemImage: "record.circle")
                }

                Button {
                    settings.useDefault()
                } label: {
                    Label("恢复双击 Command", systemImage: "command")
                }
                .disabled(settings.usesDefaultShortcut)
            }

            Spacer()
        }
        .padding(18)
    }
}
