桌面卡片的 AppKit 桥接:窗口/锁定嵌入桌面/覆盖层/复制提示,以及多卡片的拥有者。

- `DesktopCardManager.swift` — 卡片拥有者:持集合与存储,创建/关闭/恢复卡片窗口,共享剪贴板视图模型与提示。
- `DesktopCardWindowController.swift` — 单卡片窗口控制器:托管卡片视图,按锁定态切层级,持久化几何,转交可复制区域。
- `DesktopCardPanel.swift` — 无边框可成 key 的面板 + 边缘拖拽缩放 + FirstMouseHostingView;teardown 移除监视器。
- `LockOverlayController.swift` — 锁定覆盖层:快捷条(解锁/设置/关闭)、单击复制热区、滚轮转发;监视器全量 teardown。
- `CopiedToastController.swift` — 全应用共享的"已复制"点击穿透提示窗口。

## Cross-refs
- **intra** — `Features/DesktopCard/Sources/DesktopCard/README.md` —— 视图/视图模型/可复制区域契约来源。
- **intra** — `Features/ClipboardPanel/Sources/ClipboardPanel/README.md` —— 共享 `ClipboardViewModel`。
