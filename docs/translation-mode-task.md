# 任务:为桌面卡片新增「翻译模式」(Translation Mode)

> 本文件是一份**可独立执行的实现规格**。执行者无需上下文对话即可据此完成。
> 仓库根目录:`/Users/iu/Desktop/icopy`。这是一个 SwiftPM monorepo(`App/` 外壳 + `Packages/*` 本地包 + `Features/*` 功能模块)。
> **执行前必读** `CLAUDE.md`(尤其是架构基线、模块化原则、README 逐目录同步、改码后重新打包重启 App 这四节)——本任务的所有产物都必须满足那些强制约束。

---

## 1. 目标(用户故事)

为桌面便签卡片新增第三种内容模式「翻译」:

1. **设置入口**:在卡片设置面板(齿轮按钮)里,内容模式分段选择器从「手动 / 剪贴板」扩展为「手动 / 剪贴板 / 翻译」。
2. **核心功能**:
   - 翻译卡片中输入或粘贴的任意内容,被自动翻译为目标语言。
   - 支持**中英双向**:中 → 英、英 → 中。
   - 翻译由**本地 LLM(LM Studio)**完成,走其 OpenAI 兼容接口 `POST {baseURL}/v1/chat/completions`。
3. **触发方式**:**不**重映射 Enter 键。改为**内容稳定后自动触发**——用户停止输入/完成粘贴后去抖(~700ms)自动发起翻译。

### 已确认的设计决策(不要重新讨论,直接照做)

| 决策点 | 采用方案 |
|---|---|
| 模式建模 | 作为**第三种 `StickyCardContentMode`**(`.translation`),与 `.manual`/`.clipboard` 互斥,复用既有分段选择器 |
| 译文呈现 | **上下分栏**:上方可编辑「原文」,下方只读「译文」(自动更新);锁定态译文区单击复制 |
| 翻译方向 | **自动检测**:按 Unicode 区间(CJK 占比)判断——以中文为主 → 译为英文,否则 → 译为中文 |
| LM Studio 连接配置 | **全局 App 设置**(Settings 窗口),所有翻译卡片共享一个 endpoint + 模型名 |
| 触发 | 原文去抖 ~700ms 后自动翻译;粘贴作为单次大编辑被同一去抖捕获 |

---

## 2. 架构落点(强制遵守基线)

LM Studio 调用是**网络/平台依赖**,而 `Packages/Core` 禁止平台依赖,故必须**新建一个包**承载它。各层落点如下:

| 关注点 | 落点 | 理由 |
|---|---|---|
| `.translation` 模式、原文/译文/状态模型、方向检测(纯函数) | `Packages/Core/Sources/ICopyCore`(改) | 纯领域逻辑,无 UI 无网络 |
| LM Studio HTTP 客户端 + `TranslationService` 协议 | **新建 `Packages/Translation/Sources/ICopyTranslation`** | 网络=平台依赖,做成可注入/可 mock,形态对齐 `Clipboard` 包的 `PasteboardWriting` |
| 自动触发编排、上下分栏视图、设置里的模式分段 | `Features/DesktopCard/Sources/DesktopCard`(改) | 视图编排 |
| 全局 endpoint/模型配置 UI + 持久化 | `App/Sources/iCopyApp`(改) | App 级设置,对齐 `ClipboardAppearancePreferences` |

> 新增包属于「偏离基线 = 一次架构决策」:需在 `CLAUDE.md` 与 `AGENTS.md` 的「架构基线」目录树注释中**同一次改动内**补一行说明该包职责(见 §9)。

---

## 3. 详细实现

### 3.1 新建包 `Packages/Translation`(target 名 `ICopyTranslation`)

复制现有包形态(`Sources/<Target>/` + `Tests/<Target>Tests/` + 包内不放独立 `Package.swift`,本仓库用根 `Package.swift` 统一声明 target;参照 `ICopyClipboard`)。

**目录结构:**
```
Packages/Translation/
├── README.md
├── Sources/ICopyTranslation/
│   ├── README.md
│   ├── TranslationService.swift
│   ├── LMStudioTranslationService.swift
│   └── LMStudioConfig.swift
└── Tests/ICopyTranslationTests/
    ├── README.md
    └── LMStudioTranslationServiceTests.swift
```

**`LMStudioConfig.swift`** —— 纯值类型,不引入 `URLSession`,以便 UI/Core 也能持有:
```swift
import Foundation

public struct LMStudioConfig: Equatable, Sendable {
    public var baseURL: URL          // 默认 http://localhost:1234
    public var modelName: String     // 例如 "local-model" / 用户在 LM Studio 加载的模型 id

    public init(baseURL: URL, modelName: String) {
        self.baseURL = baseURL
        self.modelName = modelName
    }

    public static let `default` = LMStudioConfig(
        baseURL: URL(string: "http://localhost:1234")!,
        modelName: "local-model"
    )
}
```

**`TranslationService.swift`** —— 可注入协议(对齐 `PasteboardWriting` 的做法),依赖 `ICopyCore` 的 `TranslationLanguage`:
```swift
import ICopyCore

public protocol TranslationService: Sendable {
    /// 把 text 翻译为 target 语言,只返回译文文本(不含解释/前后缀)。
    func translate(_ text: String, to target: TranslationLanguage) async throws -> String
}

public enum TranslationError: Error, Equatable {
    case emptyInput
    case server(status: Int, body: String)
    case malformedResponse
    case transport(String)
}
```

**`LMStudioTranslationService.swift`** —— OpenAI 兼容实现:
```swift
import Foundation
import ICopyCore

public struct LMStudioTranslationService: TranslationService {
    private let config: LMStudioConfig
    private let session: URLSession

    public init(config: LMStudioConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    public func translate(_ text: String, to target: TranslationLanguage) async throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw TranslationError.emptyInput }

        let targetName = (target == .english) ? "English" : "Simplified Chinese"
        let system = "You are a translation engine. Translate the user's text into \(targetName). "
            + "Output ONLY the translation, with no explanations, quotes, or extra text."

        let url = config.baseURL.appendingPathComponent("v1/chat/completions")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload: [String: Any] = [
            "model": config.modelName,
            "temperature": 0.2,
            "stream": false,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": trimmed]
            ]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let data: Data, response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            throw TranslationError.transport(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else { throw TranslationError.malformedResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw TranslationError.server(status: http.statusCode, body: String(data: data, encoding: .utf8) ?? "")
        }
        // 解析 choices[0].message.content
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let message = choices.first?["message"] as? [String: Any],
            let content = message["content"] as? String
        else { throw TranslationError.malformedResponse }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
```

**测试用 mock**(放测试 target,不放产物):`MockTranslationService`,可配置返回固定串/抛错/记录调用次数,供 ViewModel 测试用。

**`Package.swift`(根)新增**:
- `products` 增 `.library(name: "ICopyTranslation", targets: ["ICopyTranslation"])`。
- `targets` 增:
  ```swift
  .target(
      name: "ICopyTranslation",
      dependencies: ["ICopyCore"],
      path: "Packages/Translation/Sources/ICopyTranslation",
      exclude: ["README.md"]
  ),
  .testTarget(
      name: "ICopyTranslationTests",
      dependencies: ["ICopyTranslation"],
      path: "Packages/Translation/Tests/ICopyTranslationTests",
      exclude: ["README.md"]
  ),
  ```
- 把 `"ICopyTranslation"` 加进 `DesktopCard` target 的 `dependencies`。
- 若 `iCopyApp` executable target 直接构造该服务(见 §3.5),也把 `"ICopyTranslation"` 加进它的 `dependencies`。

---

### 3.2 Core 模型改动 `Packages/Core/Sources/ICopyCore/StickyCardItem.swift`

1. 给 `StickyCardContentMode` 增加 case:
   ```swift
   public enum StickyCardContentMode: String, Codable, Equatable, Hashable, Sendable, CaseIterable {
       case manual
       case clipboard
       case translation   // 原文→译文的自动翻译卡片
   }
   ```

2. 新增纯类型(放在本文件或新建 `Packages/Core/Sources/ICopyCore/StickyCardTranslation.swift`;若新建文件,务必在 Core 的 README 增一行):
   ```swift
   public enum TranslationLanguage: String, Codable, Equatable, Sendable {
       case english
       case chinese
   }

   public enum TranslationStatus: Codable, Equatable, Sendable {
       case idle
       case translating
       case done
       case failed(String)
   }

   public struct StickyCardTranslation: Codable, Equatable, Hashable, Sendable {
       public var sourceText: String
       public var translatedText: String
       public var status: TranslationStatus
       public init(sourceText: String = "", translatedText: String = "", status: TranslationStatus = .idle) {
           self.sourceText = sourceText
           self.translatedText = translatedText
           self.status = status
       }
   }
   ```
   > `TranslationStatus` 含关联值,需手写或确认 `Codable`/`Hashable` 可合成。`Hashable` 对含 `String` 关联值的 enum 可自动合成;`StickyCardItem` 整体是 `Hashable`,故 `StickyCardTranslation` 也需 `Hashable`——逐字段满足即可。

3. `StickyCardItem` 新增字段(与 `clipboardSource` 对称):
   ```swift
   public var translation: StickyCardTranslation?   // 仅 .translation 非 nil
   ```
   - 加进 `init`(默认 `nil`)、`Codable`(自动合成,但**注意向后兼容**:旧持久化 JSON 无此字段,设为 optional 即可安全解码)。
   - 增便捷属性:`public var isTranslation: Bool { contentMode == .translation }`。

4. **方向检测纯函数**(放 Core,易单测):
   ```swift
   public static func detectTarget(for text: String) -> TranslationLanguage {
       // 统计 CJK 统一表意文字(U+4E00...U+9FFF 等)字符数占「字母/表意文字」总数的比例。
       // 中文为主(比例 >= 阈值,如 0.3)→ 译为英文;否则 → 译为中文。
       let cjk = text.unicodeScalars.filter { (0x4E00...0x9FFF).contains($0.value) }.count
       let letters = text.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count
       let total = max(letters, 1)
       return Double(cjk) / Double(total) >= 0.3 ? .english : .chinese
   }
   ```

5. **模式不变量**:翻译模式下 `sections` 为空、`clipboardSource` 为 nil、`translation` 非 nil。该不变量在 `DesktopCardViewModel.setMode`(§3.3)里维护——与现有 manual/clipboard 切换逻辑同处。Core 侧可不强制,但若 `setMode` 等价逻辑在 Core 有镜像,需一并覆盖。

> Core 保持**零网络**:只建模「翻译什么」,绝不涉及「如何翻译」。

---

### 3.3 ViewModel 改动 `Features/DesktopCard/Sources/DesktopCard/DesktopCardViewModel.swift`

注入可选 `TranslationService`(nil 表示非翻译卡片,做法对齐现有可选 `clipboard`):

```swift
import ICopyTranslation
// ...
private let translator: TranslationService?
private var translateTask: Task<Void, Never>?
private var lastTranslatedSource: String = ""
```

- `init` 增参数 `translator: TranslationService? = nil`,存入。
- `setMode(_:)` 扩展不变量:
  ```swift
  case .translation:
      card.sections = []
      card.clipboardSource = nil
      if card.translation == nil { card.translation = StickyCardTranslation() }
  ```
  (并在切到 manual/clipboard 时把 `card.translation = nil`。)
- 新增原文写入入口(供视图绑定):
  ```swift
  public func setSourceText(_ text: String) {
      guard card.translation != nil else { return }
      card.translation?.sourceText = text
      persistSoon()
      scheduleTranslate()
  }
  ```
- **去抖触发**(~700ms,与持久化的 300ms 去抖相互独立):
  ```swift
  private func scheduleTranslate() {
      translateTask?.cancel()
      guard let translator, let t = card.translation else { return }
      let source = t.sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !source.isEmpty, source != lastTranslatedSource else { return }
      translateTask = Task { @MainActor in
          try? await Task.sleep(for: .milliseconds(700))
          guard !Task.isCancelled else { return }
          await self.runTranslation(source: source, translator: translator)
      }
  }

  private func runTranslation(source: String, translator: TranslationService) async {
      let target = StickyCardItem.detectTarget(for: source)
      card.translation?.status = .translating
      objectWillChange.send()
      do {
          let result = try await translator.translate(source, to: target)
          guard !Task.isCancelled else { return }
          card.translation?.translatedText = result
          card.translation?.status = .done
          lastTranslatedSource = source
      } catch {
          guard !Task.isCancelled else { return }
          card.translation?.status = .failed(Self.message(for: error))
      }
      persistNow()
  }
  ```
  - 关键:新编辑会 `cancel()` 在途任务,避免竞态与陈旧译文覆盖。
  - 暴露读取属性给视图:`var translation: StickyCardTranslation? { card.translation }`。
  - 锁定态:原文只读,不触发;译文区由视图上报可复制区域。

---

### 3.4 视图改动 `Features/DesktopCard/Sources/DesktopCard/`

1. **新建 `TranslationCardView.swift`**:上下分栏。
   - 顶部:可编辑原文,复用 `SectionTextView`(已在 `ManualSectionsView.swift`),`text` 绑定到 `viewModel.setSourceText`。
   - 中部:细分隔 + 方向小标签(由 `detectTarget` 推出,如「中 → EN」/「EN → 中」)。
   - 底部:只读译文区,按 `status` 渲染:`.idle` 占位提示、`.translating` 小转圈、`.done` 显示 `translatedText`、`.failed(msg)` 显示错误小字。锁定态对译文区加 `.reportCopyRegion(...)`(见 `CardCopyableRegions.swift`)以支持单击复制。
   - 字体/颜色沿用 `appearance`(参照 `ManualSectionsView` 的 `nsFont`/`nsTextColor`)。
2. **`DesktopCardView.swift`**:内容区按 `contentMode` 分发处,增加 `.translation` 分支渲染 `TranslationCardView`。
3. **`CardSettingsView.swift`** 的 `modeRow` 选择器加第三段:
   ```swift
   Text("翻译").tag(StickyCardContentMode.translation)
   ```
   并把 `.frame(width: 150)` 视情况放宽以容纳三段。

---

### 3.5 全局设置 `App/Sources/iCopyApp/`

1. **新增 `TranslationPreferences`**(UserDefaults 持久化,形态对齐 `ClipboardAppearancePreferences`):字段 `baseURL: String`、`modelName: String`,提供 `config: LMStudioConfig` 计算属性与 `reset()`。建议放新文件 `App/Sources/iCopyApp/TranslationPreferences.swift`(并在 `App/Sources/iCopyApp/README.md` 增一行)。
2. **`SettingsWindowController.swift`** 的 `SettingsView`:
   - `SettingsSection` 增 `case translation`。
   - 侧栏增一项「翻译」(`sidebarItem(.translation, title: "翻译", icon: "character.bubble")`)。
   - 新增 `TranslationSettingsView`:两个文本框(服务器地址、模型名)+「测试连接」按钮(对 `{baseURL}/v1/models` 发 GET,展示成功/失败)。
   - `SettingsWindowController.init` 与 `SettingsView` 注入 `TranslationPreferences`。
3. **`AppDelegate.swift`**:创建并持有 `TranslationPreferences`,传给 `SettingsWindowController`,并传给 `DesktopCardManager`。
4. **`DesktopCard/DesktopCardManager.swift`** 的 `makeController`:当 `card.contentMode == .translation` 时,用 `prefs.config` 构造 `LMStudioTranslationService` 注入 ViewModel:
   ```swift
   let translator: TranslationService? = card.isTranslation
       ? LMStudioTranslationService(config: translationPrefs.config)
       : nil
   let viewModel = DesktopCardViewModel(
       card: card,
       clipboard: card.isClipboard ? clipboard : nil,
       translator: translator,
       onPersist: { [weak self] updated in self?.persist(updated) }
   )
   ```
   `DesktopCardManager.init` 增 `translationPrefs: TranslationPreferences` 参数;`App` target 的 `Package.swift` deps 增 `ICopyTranslation`。

---

## 4. 测试

- **Core**(`ICopyCoreTests`):
  - `detectTarget`:纯中文 → `.english`;纯英文 → `.chinese`;中英混合(过/不过阈值各一例);纯符号/数字/空串 → 默认 `.chinese`。
  - `StickyCardItem` 解码旧 JSON(无 `translation` 字段)成功且 `translation == nil`(向后兼容)。
- **Translation**(`ICopyTranslationTests`):
  - 用 `URLProtocol` stub 或注入自定义 `URLSession`,验证:正常响应解析出 `content`;非 2xx → `.server`;畸形 JSON → `.malformedResponse`;空输入 → `.emptyInput`。
- **DesktopCard**(`DesktopCardTests`,用 `MockTranslationService`):
  - 输入原文 → 去抖后调用一次翻译,`translatedText`/`status==.done` 正确写入。
  - 去抖窗口内连续编辑 → 仅最终一次发起翻译(在途被取消)。
  - 服务抛错 → `status == .failed(...)`。
  - 相同原文不重复翻译(`lastTranslatedSource` 守卫)。

> 涉及行为风险,提交前运行 `swift test`。

---

## 5. 构建与验证(强制,见 CLAUDE.md「改码后重新打包重启 App」)

1. 先退出正在运行的 `iCopy`/`icopy` 进程。
2. `swift test`(全绿)。
3. `./package.sh` 生成 `build/iCopy.app`。
4. `open build/iCopy.app`,确认新进程来自 `build/iCopy.app/Contents/MacOS/iCopy`。
5. 任一步失败 → 在最终回复中说明失败命令与阻塞原因。

**手动验收**(需本机 LM Studio 已启动并加载模型,默认 `http://localhost:1234`):
- 新建卡片 → 设置里切到「翻译」→ 卡片变为上下分栏。
- 在原文区粘贴一段中文 → 约 0.7s 后下方出现英文译文;方向标签显示「中 → EN」。
- 粘贴英文 → 下方出现中文译文。
- LM Studio 未启动时:译文区显示失败提示而非崩溃/静默。
- 锁定卡片后单击译文区 → 复制译文,弹出「已复制」提示。
- Settings →「翻译」可改地址/模型并「测试连接」。

---

## 6. 文档同步义务(强制,见 CLAUDE.md「逐目录 README 同步」与「风格约束」)

同一次改动内完成,缺一即视为未完成:

- 新建 `Packages/Translation/README.md`(首行职责声明)与 `Packages/Translation/Sources/ICopyTranslation/README.md`(逐文件一行)、测试目录粗粒度一行。
- 更新 `INDEX.md`:在「核心业务」或新增分组下加「翻译服务(LM Studio 本地 LLM):`Packages/Translation/README.md`」。
- 更新 `Features/DesktopCard/Sources/DesktopCard/README.md`:新增 `TranslationCardView.swift` 一行;`DesktopCardViewModel.swift`、`CardSettingsView.swift`、`DesktopCardView.swift` 描述若变则改;在 `Cross-refs` 增对 `Packages/Translation/README.md` 的 intra 引用(两侧 README 都要写)。
- 更新 `Packages/Core/README.md`:若新建 `StickyCardTranslation.swift` 则加一行;否则 `StickyCardItem.swift` 描述按需微调。
- 更新 `App/Sources/iCopyApp/README.md`:新增 `TranslationPreferences.swift` 一行;`SettingsWindowController.swift`、`DesktopCard/DesktopCardManager.swift` 描述按需微调。
- 更新 **`CLAUDE.md` 与 `AGENTS.md`(镜像,逐字一致仅头部不同)** 的「架构基线」目录树:在 `Packages/` 下补一行 `Translation/` 包职责(翻译服务:LM Studio 本地 LLM 调用,可注入协议)。
- 风格:README/INDEX 只写**当前状态**——不写日期、不写「从前/迁移/已删除」叙事;每文件一行 ≤120 字符(中日韩字符按双倍计)。

---

## 7. 执行顺序建议

1. Core 模型(`.translation` + 类型 + `detectTarget`)+ 其单测。
2. 新建 `Packages/Translation` 包 + `Package.swift` 接线 + 其单测。
3. `DesktopCardViewModel` 注入与去抖触发 + 其单测(mock)。
4. 视图:`TranslationCardView` + `DesktopCardView` 分发 + `CardSettingsView` 第三段。
5. App:`TranslationPreferences` + Settings「翻译」面板 + `DesktopCardManager`/`AppDelegate` 接线。
6. 全量 README/INDEX/CLAUDE.md/AGENTS.md 同步。
7. `swift test` → `./package.sh` → 重启 App → 手动验收。

## 8. 已知约束 / 注意

- **LM Studio 必须运行**且已加载模型;失败以 `.failed` 状态 +「测试连接」暴露,不静默。
- **v1 不做流式**:单次请求取完整响应(短文本足够;后续可加 stream)。
- 译文区只读,**无反馈回路**;重译仅由**原文**变化触发,并由 `lastTranslatedSource` 守卫防重复。
- 持久化向后兼容:`translation` 为 optional,旧卡片 JSON 正常解码为 `nil`。
- `StickyCardItem` 现为 `Hashable`/`Equatable`/`Codable`/`Sendable`,新增字段与类型必须同样满足。
