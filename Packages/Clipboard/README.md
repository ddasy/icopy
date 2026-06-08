Clipboard 包负责系统剪贴板读写与变更采集。

- `Sources/ICopyClipboard/PasteboardClient.swift` — NSPasteboard 读写适配器。
- `Sources/ICopyClipboard/ClipboardMonitor.swift` — 剪贴板文本事件唤醒和低频 changeCount 采集器。
- `Tests/ICopyClipboardTests/` — Clipboard 剪贴板采集测试。

## Cross-refs
- **intra** — `Packages/Core/README.md`
- **intra** — `Features/ClipboardPanel/README.md`
