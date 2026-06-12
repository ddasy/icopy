ICopyTranslation 源码封装 LM Studio 本地 LLM 翻译服务接口。

- `LMStudioConfig.swift` — LM Studio endpoint 与模型名配置值。
- `TranslationService.swift` — 翻译服务协议与错误类型。
- `LMStudioTranslationService.swift` — OpenAI 兼容 chat completions 翻译客户端;含按方向分流的 `TranslationProfile`(EN→ZH 严格忠实+贪婪采样;ZH→EN 允许润色并把枚举排成换行列表)。

## Cross-refs
- **intra** — `Packages/Core/Sources/ICopyCore/README.md`
- **intra** — `Features/DesktopCard/Sources/DesktopCard/README.md`
