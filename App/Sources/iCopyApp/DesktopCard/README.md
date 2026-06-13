桌面卡片的 AppKit 桥接:窗口/锁定嵌入桌面/覆盖层/复制提示,以及多卡片的拥有者。

- `DesktopCardManager.swift` — 卡片拥有者:持集合与存储,创建/关闭/恢复窗口,注入剪贴板与翻译服务。
- `DesktopCardWindowController.swift` — 单卡片窗口控制器:托管卡片视图,切换设置面板,恢复锁定覆盖层。
- `DesktopCardPanel.swift` — 无边框可成 key 的面板 + 边缘拖拽缩放 + FirstMouseHostingView;teardown 移除监视器;performKeyEquivalent 把 Cmd+Z/Cmd+Shift+Z 路由到卡片撤销栈(无主菜单 Undo 项)。
- `LockOverlayController.swift` — 锁定覆盖层:镜像头部快捷条、单击复制热区、滚轮转发;监视器全量 teardown。
- `CopiedToastController.swift` — 全应用共享的"已复制"点击穿透提示窗口。

## Cross-refs
- **intra** — `Features/DesktopCard/Sources/DesktopCard/README.md` —— 视图/视图模型/可复制区域契约来源。
- **intra** — `Features/ClipboardPanel/Sources/ClipboardPanel/README.md` —— 共享 `ClipboardViewModel`。
- **intra** — `Packages/Translation/README.md` —— 翻译服务注入来源。
