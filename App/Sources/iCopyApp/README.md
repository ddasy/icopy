iCopyApp 可执行目标入口目录。

- `main.swift` — AppKit 应用主循环入口。
- `AppDelegate.swift` — 创建菜单栏入口并编排快捷键、登录项、主面板、设置窗口和桌面卡片。
- `DesktopCard/` — 桌面卡片的 AppKit 桥接(窗口/锁定覆盖层/复制提示/多卡片拥有者),见其 README。
- `TranslationPreferences.swift` — LM Studio 翻译 endpoint 与模型名偏好存储。
- `KeyboardShortcut.swift` — 定义全局呼出快捷键和偏好存储。
- `LoginItemSettings.swift` — 管理 macOS 登录项开机自启状态。
- `GlobalHotKeyRegistrar.swift` — 注册 Carbon 全局快捷键。
- `DoubleCommandMonitor.swift` — 监听双击 Command 默认呼出方式。
- `ClipboardPanelWindowController.swift` — 管理快捷键呼出的 SwiftUI 主面板窗口。
- `SettingsWindowController.swift` — 管理独立设置窗口和外观/翻译/呼出设置页视图。

## Cross-refs
- **intra** — `Features/ClipboardPanel/Sources/ClipboardPanel/README.md`
- **intra** — `Features/DesktopCard/Sources/DesktopCard/README.md`
- **intra** — `Packages/Translation/README.md`
