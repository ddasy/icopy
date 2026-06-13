DesktopCard 功能模块:桌面便签卡片的视图编排(手动/剪贴板/翻译内容、分区分割、锁定态可复制区域上报)。

- `DesktopCardViewModel.swift` — 单卡片编排:外观、分区/复制、翻译管线接线与落定回写、窗口锁、剪贴板投影和持久化;持卡片级 `undoManager`(结构编辑经快照注册撤销,打字撤销共用同栈)。
- `DesktopCardView.swift` — 卡片顶层视图:头部工具栏(锁定/横分割/竖分割/设置/关闭)+ 内容模式分发。
- `ManualSectionsView.swift` — 手动内容:按行渲染(列按 columnWeight 绝对占比分宽/分隔占独立间隔列;✕ 删右列或删整行,不合并、右侧列左移补位;竖向分隔 ⇔ 按住拖动调列宽);可编辑分区上报焦点+光标+横向占比,锁定态只读点击复制并上报区域;分区右键菜单(覆写屏蔽系统默认项)单项切换自定义标题/显示原文,有标题折叠为单行、复制仍写原文。
- `DesktopClipboardListView.swift` — 剪贴板卡片的桌面历史只读列表(紧凑行,上报可复制区域)。
- `TranslationCardView.swift` — 翻译卡片三区:原文输入、方向行、流式译文;子区各自观察,译文更新不重渲染输入区。
- `TranslationController.swift` — 翻译请求管线:短合并窗+最新提交优先取消+流式增量结果;状态与输入视图隔离。
- `TranslationSourceTextView.swift` — 原文输入 NSTextView:本地持有文本,仅提交非 IME 组合态,组合期间跳过属性写入。
- `TranslationSpeechPlayer.swift` — 翻译卡片原文朗读:Piper 英文原文播放 + 系统语音回退。
- `CardSettingsView.swift` — 单卡片设置面板:内容模式、透明度、字体、颜色预设盘+强度。
- `DesktopCardAppearance.swift` — StickyCardAppearance → SwiftUI Font/Color 映射 + 颜色预设盘。
- `CardCopyableRegions.swift` — 视图↔覆盖层契约:可复制区域 + PreferenceKey + 上报修饰符。
- `Tests/DesktopCardTests/` — 视图模型业务行为测试。

## Cross-refs
- **intra** — `Features/ClipboardPanel/README.md` —— 复用共享的 `ClipboardViewModel`(剪贴板模式数据源)。
- **intra** — `Packages/Translation/README.md` —— 翻译模式的 LM Studio 服务协议与客户端。
- **intra** — `App/Sources/iCopyApp/README.md` —— App 层窗口/锁定覆盖层消费可复制区域并触发复制。
