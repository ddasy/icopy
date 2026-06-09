Core 包提供剪贴板领域模型与业务规则。

- `Sources/ICopyCore/ClipboardItem.swift` — 剪贴板条目模型。
- `Sources/ICopyCore/ClipboardCollection.swift` — 历史和收藏集合规则。
- `Sources/ICopyCore/StickyCardItem.swift` — 桌面卡片模型:内容模式/锁定态/分区/分隔符切分合并规则。
- `Sources/ICopyCore/StickyCardAppearance.swift` — 桌面卡片外观值类型(透明度/字体/颜色/强度),纯数据。
- `Sources/ICopyCore/StickyCardCollection.swift` — 桌面卡片集合聚合:增删改、查找、z-order 重排。
- `Tests/ICopyCoreTests/` — Core 业务规则测试。

## Cross-refs
- **intra** — `Packages/Storage/README.md`
- **intra** — `Packages/UIComponents/README.md`
