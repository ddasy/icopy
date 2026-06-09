DesktopCard 功能模块:桌面便签卡片的视图编排(手动/剪贴板/翻译内容、分区分割、锁定态可复制区域上报)。

- `DesktopCardViewModel.swift` — 单卡片编排:外观、分区/复制、翻译去抖与原文复制、剪贴板投影和持久化。
- `DesktopCardView.swift` — 卡片顶层视图:头部工具栏(锁定/分割/设置/关闭)+ 内容模式分发。
- `ManualSectionsView.swift` — 手动内容:可编辑分区(SectionTextView 上报焦点+光标)/ 锁定态只读分区上报可复制区域。
- `DesktopClipboardListView.swift` — 剪贴板卡片的桌面历史只读列表(紧凑行,上报可复制区域)。
- `TranslationCardView.swift` — 翻译卡片上下分栏:原文输入、方向提示、译文状态和锁定态译文复制区域。
- `TranslationSpeechPlayer.swift` — 翻译卡片原文朗读:用系统语音按检测语言播放输入框内容。
- `CardSettingsView.swift` — 单卡片设置面板:内容模式、透明度、字体、颜色预设盘+强度。
- `DesktopCardAppearance.swift` — StickyCardAppearance → SwiftUI Font/Color 映射 + 颜色预设盘。
- `CardCopyableRegions.swift` — 视图↔覆盖层契约:可复制区域 + PreferenceKey + 上报修饰符。
- `Tests/DesktopCardTests/` — 视图模型业务行为测试。

## Cross-refs
- **intra** — `Features/ClipboardPanel/README.md` —— 复用共享的 `ClipboardViewModel`(剪贴板模式数据源)。
- **intra** — `Packages/Translation/README.md` —— 翻译模式的 LM Studio 服务协议与客户端。
- **intra** — `App/Sources/iCopyApp/README.md` —— App 层窗口/锁定覆盖层消费可复制区域并触发复制。
