Storage 包负责剪贴板条目持久化。

- `Sources/ICopyStorage/ClipboardStore.swift` — 剪贴板存储协议。
- `Sources/ICopyStorage/JSONClipboardStore.swift` — JSON 文件存储实现。
- `Sources/ICopyStorage/StickyCardStore.swift` — 桌面卡片存储协议。
- `Sources/ICopyStorage/JSONStickyCardStore.swift` — 桌面卡片 JSON 存储(desktop-cards.json;空/截断文件降级为空)。
- `Tests/ICopyStorageTests/` — Storage 持久化测试。

## Cross-refs
- **intra** — `Packages/Core/README.md`
- **intra** — `Features/ClipboardPanel/README.md`
