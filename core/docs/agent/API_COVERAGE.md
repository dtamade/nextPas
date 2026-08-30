# API_COVERAGE：契约面 × 落地单元 × 测试证据

> 契约权威是 `API.md`；本文件回答"每条契约在哪实现、被哪个 gate 证明"。
> 状态词：**落地**（实现+gate 双全）/ **接口先行**（接口冻结，实现后置）。

## §1 base 词表 → `nextpas.core.agent.base` — 落地

| 词表 | 证据 |
|------|------|
| TMessage/TPart/TTokenUsage/TCompletionRequest 及 builder | 全部 gates 消费；编码侧细节见 test_provider_openai/anthropic 快照 |
| TStreamDelta 全枚举 | test_protocol（fold 矩阵）+ 两 provider gate 流 FSM |
| helpers 一站式：`MessageText` / `WireHeaderValue` / `MergeExtraJson`（后者胜，空/坏值跳过）/ `AgentUtf8SafeTruncate`（UTF-8 字节安全回退）/ `AgentTruncateLines` / `AgentTruncateEnvelope`（行+字节双阈值，零拷贝单遍）/ `AgentInitUsageUnknown` / `AgentJoinWireUrl`（去尾 `/` + `/v1` 归一）/ `AgentBuildSystemText`（顶层 System 先行+历史去重，以 `#10#10` 连接） | `test_tools` 截断信封（行/字节/双阈值，Truncated 标记）+ `test_security` UTF-8 边界（`AgentUtf8SafeTruncate`）+ `test_provider_*` Extra 合并回注/回放 + `test_compile_skeleton` 门面一站式透出（编译即通过，不触网）；`WireHeaderValue` 贯穿 retry-after / request-id 探测 |
| 常量（单一真源 `base`，`provider.common` 为兼容 alias；门面 `nextpas.core.agent` 一站式 `inline` 透出）：`CAgentMaxSlotMap=256` / `CAgentMaxWireHeaderValueBytes=8 KiB` / `CAgentMaxWireTotalHeaderBytes=64 KiB` / `CAgentMaxSuccessBodyBytes=8 MiB` / `CAgentMaxRawBodySnippetBytes=8 KiB` / `CAgentMaxExtraKeys=64` | `test_transport_stream` 5×3 矩阵（单头 8 KiB / 总头 64 KiB）+ `test_security` Extra 64 键截断 + `test_tools` 256 KiB 参数预检协同 + `test_compile_skeleton` 常量透出（`CAgentMax*`） |

## §2 错误分类 → `nextpas.core.agent.errors` — 落地

| 词表 | 证据 |
|------|------|
| EAgentError 族 + aec* 分类 | test_retry（白名单/归因）、两 provider gate（上游状态归约）、test_security（fail-closed 路径）|
| EAgentMisuse | test_security（GetMessage before EOF）；decoder 复用守卫见 test_codecs |

## §3 接缝接口 → `nextpas.core.agent.intf` — 落地

| 接口 | 实现 | 证据 |
|------|------|------|
| IAgentProvider / IAgentCompletion | openai/anthropic/fake + retry 装饰 | 各 provider gate、test_retry、test_assembly |
| IAgentTransport | transport.http | test_transport_stream（真增量+硬取消回环）|
| IAgentWireDecoder（D13 公开） | 两适配器解码器 | test_codecs |
| IToolContext / IAgentTool | tools 单元 + 消费方注入 | test_tools / test_loop |
| IAgentClock | agent.clock（真实+fake） | test_retry / test_tools（超时确定性）|
| IAgentTranscriptStore | agent.session（W5：JSONL 落地，SESSION.md） | test_session |

## §4 协议域纯函数 fold → `nextpas.core.agent.fold` — 落地

D1 唯一折叠实现。test_protocol 全词表矩阵；复杂度主张由 bench_fold
背书（≈127 ns/delta，BENCHMARKS §2）。

## §5 重试策略 → `nextpas.core.agent.retry` — 落地

Retry-After/退避曲线/MaxAttempts/白名单外直通/取消打断——test_retry
13 测（fake clock 零真实睡眠）。首 delta 门语义同门覆盖。

## §6 循环 → `nextpas.core.agent.loop` + `.tools` — 落地

| 面 | 证据 |
|----|------|
| 校验/截断信封/批执行器（超时·取消·异常兜底·迟到写仲裁） | test_tools 7 测 |
| 编排/预算/事件/防打转/引导收尾/钩子三态 | test_loop 14 测（含 prompt cache 前缀稳定断言，PERFORMANCE §6）|
| 执行设施复杂度 | bench_loop_overhead ≈16.6 µs/轮 |

## §7 Fake / scripted provider → `nextpas.core.agent.provider.fake` — 落地

自身语义 test_fake_provider；作为基建被 test_assembly /
bench_loop_overhead 与全部示例消费（离线纪律的合法替代面）。

## §8 纯编解码器（D13）→ `provider.common` 公开表面 — 落地

| 契约 | 落地 | 证据 |
|------|------|------|
| wire↔词表往返、双角色并行隔离、违例 fail-closed | `provider.common` + 两适配器 | test_codecs 11 测（两角色并行、未知字段 Extra 回注、违例 `aecProtocol`） |
| Extra 保真：`CaptureExtraJson` 未知键无损捕获 / `WriteExtraFields` 已知键让位 / `MergeExtraJson` 后者胜（空/坏值跳过、几何预留 `LCap 8→*2`）/ `WithExtraJson` 链式多次调用按后者胜合并 | `base.MergeExtraJson` 单一真源；`provider.common` 编码侧回注、解码侧捕获、fold 旁路 | test_codecs 往返 + `test_tools` builder 链 + `test_security` Extra 64 键上限（超限丢弃并 warn）；W4 修复：openai 根级已知表补 `model` |
| Extra 64 键上限 `CAgentMaxExtraKeys=64` | 单一真源 `base`，`provider.common` 限流 | test_security `extra keys capped at 64` 7 passed 内；API Defaults 总表 1:1 |
| Truncate：`AgentTruncateLines`（单遍计数）+ `AgentTruncateEnvelope`（行+字节双阈值融合、UTF-8 安全、零中间分配）+ `AgentUtf8SafeTruncate`（最多回退 3 字节到合法边界） | `base` 唯一实现，门面 inline 透出 | test_tools 截断信封 3 用例（行切/字节切/双阈值）+ test_security UTF-8 边界 + bench_loop_overhead 时序锚定；`test_compile_skeleton` 透出 |

## §9 wire 头部消毒 → `base` 单一真源（`provider.common`/`transport.http` 兼容 alias 收口） — 落地

| 契约 | 落地 | 证据 |
|------|------|------|
| `AgentValidateWireHeaders` 单遍 O(totalHeaderBytes) 内联 CR/LF 扫描；单头 8 KiB / 总头 64 KiB、空名/CR-LF 注入 fail-closed `aecProtocol` 协议无关报文（`wire header: ...` 前缀）| `provider.common` 唯一实现+常量 `CAgentMaxWireHeaderValueBytes`/`CAgentMaxWireTotalHeaderBytes`（单一真源：nextpas.core.agent.base，`provider.common` 为兼容 alias）；`transport.http` 复用不自立；三提供者编码期前置早失败（`AgentWireAddOpenAIHeaders`/`AgentWireAddAnthropicHeaders`/`AgentWireAppendExtraHeaders` 末尾各调一次），transport `RoundTrip`/`OpenStream` 为兜底防线；`nextpas.core.agent` 门面 `agent` 一站式透出（`CAgentMaxWireHeaderValueBytes` 8 KiB / `CAgentMaxWireTotalHeaderBytes` 64 KiB / `CAgentMaxSuccessBodyBytes` 8 MiB / `CAgentMaxRawBodySnippetBytes` 8 KiB / `CAgentMaxExtraKeys` 64 / `CAgentMaxSlotMap` 256，单一真源：nextpas.core.agent.base） | `test_transport_stream` 头部守卫矩阵 5 用例（空名 / CRLF-名 / CRLF-值 / 单头 8 KiB / 总头 64 KiB）× 3 路径（`RoundTrip` / `OpenStream` / 直调 `AgentValidateWireHeaders`）=15 守卫断言，套件 8 passed HEAPTRC OK；`bench_wire_headers` 锚定 p50 ~203 ns（5 头）/ 754 ns（10 头），空头 17.1 ns（BENCHMARKS §2.2 2026-08-29 冻结） |

## 门面 `nextpas.core.agent` — 落地

| 透出 | 真源 | 证据 |
|------|------|------|
| DoS 六常量 `CAgentMaxSlotMap` / `CAgentMaxWireHeaderValueBytes` / `CAgentMaxWireTotalHeaderBytes` / `CAgentMaxSuccessBodyBytes` / `CAgentMaxRawBodySnippetBytes` / `CAgentMaxExtraKeys` | 单一真源 `base`（`provider.common` 为兼容 alias） | `test_compile_skeleton` 编译期常量透出（`Check(CAgentMax* = base.CAgentMax*)`） |
| 词表 helpers 一站式 `MessageText` / `WireHeaderValue` / `MergeExtraJson` / `AgentUtf8SafeTruncate` / `AgentTruncateLines` / `AgentTruncateEnvelope` / `AgentInitUsageUnknown` / `AgentJoinWireUrl` / `AgentBuildSystemText` / `AgentValidateWireHeaders` | `base` 单入口（`AgentValidateWireHeaders` 唯一实现在 `provider.common`，门面 inline 指向真源，免破层 `uses`） | `test_compile_skeleton` 9 passed（`TestFacadeForwarding` 含 `AgentValidateWireHeaders` / `CAgentMaxRawBodySnippetBytes` 等新增透出，编译即通过，不触网）；与 `API.md` §1/§10 及 `base` 单一真源 1:1 |
| 工厂/装饰器/工具转发/TAgentLoop 可用性 | 分层透出 | test_assembly 经门面装配点跑通完整链（scripted transport 注入 → retry 叠加 → loop 工具两轮） |

> W16.1 闭环判定：门面与 `API_COVERAGE` 行数 1:1，`test_compile_skeleton` 覆盖全部新增透出，`make hygiene` pass。

## 安全验收（SECURITY.md）

集中防线 test_security 7 测（密钥不入日志、FromEnv nil、mime 白名单零
wire、256KiB 预检、UTF-8 截断边界、误用守卫、Extra 上限）；深度覆盖在
归属门（sse 行上限→test_sse；编码细节→provider gates）。

## 已知缺口

- ~~session 域（IAgentTranscriptStore 实现）~~ 已清偿：W5 立项落地
  （2026-08-25），`nextpas.core.agent.session` + `test_session`。
- http.sse 同口径参照基准：两引擎输入域不同（bytes/text）不合基准；如需对照由 http lane 自立。

## W18.2 TODO — test_codecs 怪癖快照缺口（WIRE-MAPPINGS.md §1.5/2.5/3.4，不改映射，仅标记）— 0 剩余（25 已消项于 2026-08-29 37 passed）— 已收口

> 核验方式：`grep -R "Q-A\|unknown event\|thinking delta" core/tests/nextpas.core.agent/test_codecs`（2026-08-28）。
> 判定口径：仅统计 `test_codecs` 内的 `Q-O* / Q-A* / Q-R*` 字面与 `unknown event` / `thinking_delta` 语义用例；其余 `test_provider_*` / `test_sse` 内的同怪癖覆盖**不**计入本门的 `test_codecs` 网关式回放门（ROADMAP-FINAL W18.2）。
> 状态：2026-08-29 37 passed 已消 25 项（+ Q-A7/A8/R5/R6/R7/tool val），0 剩余，已收口。

- ✅ `Q-O1` 推理族 `max_completion_tokens` 改名 — `test_codecs` 25 passed `TestQuirkO1MaxCompletionTokensRenameTolerance` 已消项
- ✅ `Q-O2` `reasoning_content`/`reasoning` 映射 `sdkThinkingDelta` — `test_codecs` 25 passed `TestQuirkO2ReasoningContentThinkingDelta` 已消项
- ✅ `Q-O3` `stream_options.include_usage` — `test_codecs` 25 passed `TestQuirkO3IncludeUsageHarmless` 已消项
- ✅ `Q-O4` 无 `[DONE]` 直接断连宽容 — `test_codecs` 18 passed `TestQuirkO4NoDoneEOFGraceful` 已消项
- ✅ `Q-O5` 工具 slot 延迟命名/缺 index 容忍 — `test_codecs` 25 passed `TestQuirkO5ToolSlotDelayedNamingMissingIndex` 已消项
- ✅ `Q-O6` 空 `choices` 跳过 — `test_codecs` 18 passed `TestQuirkO6EmptyChoicesSkipped` 已消项
- ✅ `Q-O7` 多 choice 丢弃 warn — `test_codecs` 25 passed `TestQuirkO7MultiChoiceDiscardWarn` 已消项
- ✅ `Q-O8` `stop` 带 `tool_calls` 纠正 `frToolCalls` — `test_codecs` 31 passed `TestQuirkO8StopToolCallsCorrected` 已消项
- ✅ `Q-O9` `event: ping` 心跳跳过 — `test_codecs` 31 passed `TestQuirkO9PingSkipped` 已消项
- ✅ `Q-A1` `message_start` 强制首信封 — `test_codecs` 18 passed `TestQuirkA1MessageStartRequired` 已消项
- ✅ `Q-A3` thinking `signature` 透传 — `test_codecs` 25 passed `TestQuirkA3ThinkingSignaturePassthrough` 已消项
- ✅ `Q-A4` `tool_result` 分组 `user` 角色 — `test_codecs` 31 passed `TestQuirkA4ToolResultGrouped` 已消项
- ✅ `Q-A5` 无 `parallel_tool_calls` 忽略 warn — `test_codecs` 31 passed `TestQuirkA5ParallelToolCallsIgnored` 已消项
- ✅ `Q-A6` `input_json_delta` 分片累积 — `test_codecs` 18 passed `TestQuirkA6InputJsonDeltaAccumulated` 已消项
- ✅ `Q-A7` `retry-after` 解析 — `test_codecs` 37 passed `TestQuirkA7RetryAfterParsed` 已消项
- ✅ `Q-A8` 截断流 fail-closed — `test_codecs` 37 passed `TestQuirkA8TruncatedStreamFailClosed` 已消项（字面 `Q-A8`）
- ✅ `Q-A*` unknown event 跳过 — `test_codecs` 18 passed `TestQuirkUnknownEventSkipped` (含 openai/responses/anthropic 3 路) 已消项
- ✅ `Q-R1` 无 `stop_sequences` 忽略 warn — `test_codecs` 25 passed `TestQuirkR1StopSequencesIgnoredWarn` 已消项
- ✅ `Q-R2` `event:` 主键分派 — `test_codecs` 18 passed `TestQuirkR2EventDispatch` 已消项
- ✅ `Q-R3` function 平铺 — `test_codecs` 31 passed `TestQuirkR3FunctionFlatten` 已消项
- ✅ `Q-R4` usage 字段差异 — `test_codecs` 31 passed `TestQuirkR4UsageDiff` 已消项
- ✅ `Q-R5` 截断流 fail-closed — `test_codecs` 37 passed `TestQuirkR5TruncatedStreamFailClosed` 已消项
- ✅ `Q-R6` `text.format` structured output — `test_codecs` 37 passed `TestQuirkR6TextFormatStructuredOutput` 已消项
- ✅ `Q-R7` 子集缺失容忍 — `test_codecs` 37 passed `TestQuirkR7SubsetMissingTolerance` 已消项
- ✅ `Q-O tool validation` 具名缺名/空 Tools 抛 `aecConfig` — `test_codecs` 37 passed `TestQuirkOToolValidation` 已消项

> 以上 TODO 均不改 `WIRE-MAPPINGS.md`（怪癖表为真源），仅在 `test_codecs` 补网关式 `Decode → Fold → Encode` 回放快照后逐条消项。—— 0 剩余已收口。
