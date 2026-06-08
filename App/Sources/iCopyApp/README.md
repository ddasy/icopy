iCopyApp 可执行目标入口目录。

- `main.swift` — AppKit 应用主循环入口。
- `AppDelegate.swift` — 创建菜单栏入口并编排快捷键、主面板和设置窗口。
- `KeyboardShortcut.swift` — 定义全局呼出快捷键和偏好存储。
- `LoginItemSettings.swift` — 管理 macOS 登录项开机自启状态。
- `GlobalHotKeyRegistrar.swift` — 注册 Carbon 全局快捷键。
- `DoubleCommandMonitor.swift` — 监听双击 Command 默认呼出方式。
- `ClipboardPanelWindowController.swift` — 管理快捷键呼出的 SwiftUI 主面板窗口。
- `SettingsWindowController.swift` — 管理独立设置窗口和设置页视图。

## Cross-refs
- **intra** — `Features/ClipboardPanel/Sources/ClipboardPanel/README.md`
