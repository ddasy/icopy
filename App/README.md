应用入口与生命周期;AppKit 桥接和菜单栏常驻由这里编排。

- `Sources/iCopyApp/main.swift` — AppKit 应用主循环入口。
- `Sources/iCopyApp/AppDelegate.swift` — 创建菜单栏入口并编排快捷键、登录项、主面板和设置窗口。
- `Sources/iCopyApp/KeyboardShortcut.swift` — 定义全局呼出快捷键和偏好存储。
- `Sources/iCopyApp/LoginItemSettings.swift` — 管理 macOS 登录项开机自启状态。
- `Sources/iCopyApp/GlobalHotKeyRegistrar.swift` — 注册 Carbon 全局快捷键。
- `Sources/iCopyApp/DoubleCommandMonitor.swift` — 监听双击 Command 默认呼出方式并过滤极短回弹。
- `Sources/iCopyApp/ClipboardPanelWindowController.swift` — 管理快捷键呼出的 SwiftUI 主面板窗口。
- `Sources/iCopyApp/SettingsWindowController.swift` — 管理独立设置窗口和设置页视图。

## Cross-refs
- **intra** — `Features/ClipboardPanel/README.md`
