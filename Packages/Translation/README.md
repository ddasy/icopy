Translation 包负责 LM Studio 本地 LLM 翻译服务协议与 OpenAI 兼容 HTTP 客户端。

- `Sources/ICopyTranslation/LMStudioConfig.swift` — LM Studio endpoint 与模型名配置值。
- `Sources/ICopyTranslation/TranslationService.swift` — 翻译服务协议(整段+流式,流式带默认退化实现)与错误类型。
- `Sources/ICopyTranslation/LMStudioTranslationService.swift` — OpenAI 兼容 chat completions 客户端:整段请求 + SSE 流式增量。
- `Tests/ICopyTranslationTests/` — Translation HTTP 客户端测试。

## Cross-refs
- **intra** — `Packages/Core/README.md` —— 使用 `TranslationLanguage` 领域类型。
- **intra** — `Features/DesktopCard/Sources/DesktopCard/README.md` —— 翻译卡片注入并调用服务。
