# icopy 功能索引

模块定位清单:功能 → 目录(README)。每个目录 README 是该目录的文件级索引。
本项目为 SwiftPM monorepo:`App/` 为应用外壳,`Packages/*` 为本地包单元,`Features/*` 为 SwiftUI 功能模块。

## 核心业务
- 剪贴板采集与监听:`Packages/Clipboard/README.md`
- 领域模型与业务规则:`Packages/Core/README.md`
- 历史记录持久化与检索:`Packages/Storage/README.md`
- 功能视图(历史面板、收藏面板):`Features/ClipboardPanel/README.md`
- 桌面便签卡片(手动/剪贴板、分区、锁定嵌入桌面):`Features/DesktopCard/README.md`

## 基础设施
- 应用入口与 AppKit 桥接(菜单栏):`App/README.md`
- 可复用 SwiftUI 组件:`Packages/UIComponents/README.md`
- 资源(Assets / Info.plist / entitlements / 本地化):`Resources/` —— 非代码目录,不建 README
- 测试套件与 fixtures:`Tests/README.md`

## 维护
新增模块/目录 → 在所属分组下加一行;目录重命名/移除 → 同步本清单。
单一目录子节点超出"一跳定位"承载力时,在该节点插入 `INDEX.md` 分层(见 CLAUDE.md 的层级弹性规则)。
