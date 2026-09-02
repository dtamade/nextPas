# nextpas.core.agent 架构

> 稳定架构事实。修改分层、单元职责或所有权规则前先改本文档。

## 1. 分层与依赖方向

```
                    ┌─────────────────────────────┐
        消费方  →   │   nextpas.core.agent (门面)   │  纯 re-export
                    └──────────────┬──────────────┘
                                   │ uses 全部子单元
       ┌────────────┬──────────────┼──────────────────┬────────────┐
       │            │              │                  │            │
   loop 域      session 域     provider 域         fold 域      tools 域
 nextpas.core.  nextpas.core.  nextpas.core.      nextpas.core. nextpas.core.
 agent.loop     agent.session  agent.provider.*   agent.fold    agent.tools
       │            │              │                  │            │
       │            │    ┌─────────┼─────────┐        │            │
       │            │    │         │         │        │            │
       │            │  retry    clock   provider.{openai,anthropic,fake,common}
       │            │    │         │         │
       │            │    └────┬────┘         │
       │            │         │        ┌─────┴──────┐
       │            │         │        │ transport.http ── sse(增量解析)
       │            │         │        └─────┬──────┘
       └────────────┴─────────┴──────────────┴────────────────────────┐
                                                                      │
                        base ← errors ← intf（词表与接缝，被所有域依赖）
                                                                      │
底座（全部向下合法）：json(+writer/parser/scanner), http(client/sse), async.cancellation,
                     thread(IThreadPool), io.intf, log.intf, time, id, encoding,
                     collections, base, errors
```

> 注：session 域已立项落地（W5，2026-08-25）——`nextpas.core.agent.session`
> 提供 `IAgentTranscriptStore` 的 JSONL 实现，设计权威见 [`SESSION.md`](SESSION.md)。

铁律：

1. `base`/`errors`/`intf` 不依赖本模块任何其他实现单元（errors 只依赖 base）；
   错误码枚举属纯词表，物理落位在 base。
2. 协议域（base/fold/sse）**零 IO**：不 uses http/net/fs，纯数据+纯函数，可独立单测。
3. provider 域是唯一知道线级协议细节的地方，且**编解码器是公开表面**
   （D13：网关型客户直接复用）；loop/session/tools 域只消费
   `IAgentProvider` 词表，永远看不到 wire 类型。
4. 只向下依赖 L0-L2 底座；禁止使用 FPC RTL 应用类型（TStream/SysUtils 函数等），
   遵循 core 双编译器纪律。

## 2. 单元清单

| 单元 | 层 | 职责 | 允许依赖 |
|------|---|------|---------|
| `nextpas.core.agent` | 门面 | 纯 re-export 公共词表与入口函数 | 全部子单元 |
| `nextpas.core.agent.textutil.pas` | 复用 | UTF-8 安全截断转发薄壳（单一真源在 `nextpas.core.text.utf8`，`AgentUtf8SafeCutLen/Truncate` 为公共 API 冻结名转发；`AgentEstimateTokens` 估算）| nextpas.core.text |
| `nextpas.core.agent.base.slotmap.pas` | 词表 | 槽位注册表 `TAgentSlotRegistry`/`TAgentSlotMap`/`AgentSlotMapEnsureSize`（O(1) 直映+稀疏回退，fold/provider 共享单一真源，2026-08-31 自 helpers 拆出）| agent.base.constants |
| `nextpas.core.agent.base.deltabuilder.pas` | 词表 | 增量构建器 `TAgentDeltaBuilder`/`PStreamDelta`（Count/Cap 几何增长，三路解码器高频路径共享，2026-08-31 自 helpers 拆出）| agent.base.types |
| `nextpas.core.agent.base.pas` | 词表 | TMessage/TPart/TStreamDelta/TTokenUsage/TCompletionRequest/TToolSpec/TAgentErrorCode、枚举、sentinel 常量、TTriState、TJsonText、TWire* wire 词表（纯词表零 IO，只依赖底座；`Utf8Cut` 透传 textutil）| core.base, agent.textutil |
| `nextpas.core.agent.errors.pas` | 错误 | EAgentError/EAgentCancelled 异常类、HTTP status→错误码分类器（枚举在 base）| agent.base, core.base |
| `nextpas.core.agent.intf.pas` | 接缝 | IAgentProvider/IAgentCompletion/IAgentTransport/IAgentWireStream/IAgentWireDecoder/IAgentTool/IToolExecutor/IAgentClock/IAgentTranscriptStore | base, errors, async.cancellation |
| `nextpas.core.agent.fold.pas` | 协议 | TAssistantBuild 增量累积器 + FoldDelta/FoldDeltas 纯折叠（唯一实现，禁止重写） | base, errors |
| `nextpas.core.agent.sse.pas` | 协议 | **feed 式增量 SSE 解析器**（Feed(buf)→PopEvent；内部单元，http.sse 晋升候选）；DoS 上限触发抛 aecProtocol（SECURITY §3）| base, errors, text.builder |
| `nextpas.core.agent.clock.pas` | 支撑 | IAgentClock 实现：真实时钟（可取消睡眠）+ fake 时钟（测试注入） | intf, async.cancellation, stopwatch, time.sleep |
| `nextpas.core.agent.retry.pas` | 策略 | TRetryPolicy 记录 + `WithRetry(inner, policy, clock)` 装饰器（纯策略无 IO，睡在 clock 上；流式只重试到首 delta——首 delta 门回放） | intf, base, errors, async.cancellation, platform.random |
| `nextpas.core.agent.fallback.pas` | 策略 | `NewFallbackProvider(chain, policy)` 容灾链装饰器（白名单内逐家切换、流式首 delta 门、全链耗尽透传最后原始错误、取消即止；OnSwitch 观测） | intf, base, errors |
| `nextpas.core.agent.throttle.pas` | 策略 | IAgentRateGate 细接口 + `NewThrottledProvider(inner, gate, clock, policy)` 客户端限流（拒绝→clock 取消感知等待重取，超窗本地 aecRateLimited）；`NewTokenBucketGate` 适配 core.lockfree.ratelimit 标准库 | intf, base, errors, clock, lockfree.ratelimit |
| `nextpas.core.agent.hedge.pas` | 策略 | `NewHedgedProvider(inner, clock, policy)` 对冲装饰器（DelayMs 无响应即并发第二路取先达、输路取消令牌合并必 Cancel、流式首 delta 先达者胜投递不重复、双倍 token 成本工厂级 opt-in；OnHedged 观测；DelayMs→ns 溢出钳制 High(Int64)） | intf, base, errors, async.cancellation, sync.event, clock |
| `nextpas.core.agent.resilience.pas` | 韧性 | 消费方侧纯函数四件（自 code888 韧弧 K69-K75 提炼反哺）：`StreamHasError` 断流指纹判定、`WaitCancelMs`/`WaitCancelSlice` 取消感知毫秒退避（ms→ns 溢出守卫+nil 吸收、Slice 版 200µs 切片轮询）、`ClampHintMs` 重试提示同帽钳制（负哨兵透传） | base, thread, agent.base |
| `nextpas.core.agent.transport.http.pas` | 传输 | 薄门面：组装 `http.core` + `http.stream` 为 `IAgentTransport`（73 行门面，消费方零改动） | transport.http.core/stream, http.client, intf |
| `nextpas.core.agent.transport.http.core.pas` | 传输子域 | HTTP wire core：非流式 `RoundTrip`/头部/体辅助与 POST 构造（197 行） | base, io.intf, http.intf/client, intf |
| `nextpas.core.agent.transport.http.stream.pas` | 传输子域 | HTTP wire streaming：`TWireStream` + `IReader` 逐块喂 `agent.sse` + 通道状态（464 行） | base, sync.mutex, stopwatch, thread.channel, http.intf/client, intf |
| `nextpas.core.agent.provider.common.pas` | 适配支撑（薄壳 291 行） | 适配器门面，inline 转发至三子域；**T1.5** `AgentWireApplyIdempotency` 单一真源透传 `Idempotency-Key` | common.wire/extra/slots, base, errors, intf |
| `nextpas.core.agent.provider.common.wire.pas` | 适配支撑子域 | wire JSON 组装/读取、SSE data 帧→delta 公共骨架、帧序 FSM 骨架（565 行） | base, errors, json, intf |
| `nextpas.core.agent.provider.common.extra.pas` | 适配支撑子域 | Extra 无损捕获与 64 键上限（109 行） | base, json |
| `nextpas.core.agent.provider.common.slots.pas` | 适配支撑子域 | `TWireToolSlotPool` 直映表 + `CAgentMaxSlotMap` 256 上限（519 行） | base, errors |
| `nextpas.core.agent.provider.openai.pas` | 适配（薄壳 326 行） | OpenAI Chat Completions 门面，inline 转发至三子域；公开编解码器三件（D13）；Q-O1..O7 全部落码+gate | openai.encode/decode/decoder, base, errors, intf, common, transport, fold |
| `nextpas.core.agent.provider.openai.encode.pas` | 适配子域 | Chat 编码子域（348 行纯函数） | base, intf, errors, common, json, json.builder, text.builder |
| `nextpas.core.agent.provider.openai.decode.pas` | 适配子域 | Chat 解码子域（232 行纯函数） | base, intf, errors, common, json |
| `nextpas.core.agent.provider.openai.decoder.pas` | 适配子域 | Chat WireDecoder 状态机（359 行，Q-O 流式） | base, intf, errors, common, json, log |
| `nextpas.core.agent.provider.openai.responses.pas` | 适配（薄壳 256 行） | Responses 门面，inline 转发至三子域；同款公开编解码器三件（WIRE-MAPPINGS §3，Q-R1..R7） | responses.encode/decode/decoder, base, errors, intf, common, transport, fold |
| `nextpas.core.agent.provider.openai.responses.encode.pas` | 适配子域 | Responses 编码子域（307 行纯函数，input/instructions/tool_choice/text.format） | base, intf, errors, common, json, json.builder, text.builder |
| `nextpas.core.agent.provider.openai.responses.decode.pas` | 适配子域 | Responses 解码子域（245 行纯函数，output 项+usage details） | base, intf, errors, common, json |
| `nextpas.core.agent.provider.openai.responses.decoder.pas` | 适配子域 | Responses WireDecoder 状态机（441 行，`response.*` 事件全集） | base, intf, errors, common, json, log |
| `nextpas.core.agent.provider.anthropic.pas` | 适配（薄壳 397 行） | Anthropic 适配器门面（inline 转发至子域，调用方零改动） | anthropic.encode/decode/decoder, base, errors, intf, common, transport, fold |
| `nextpas.core.agent.provider.anthropic.encode.pas` | 适配子域 | Anthropic 编码子域（449 行纯函数，Messages/count_tokens 同构） | base, intf, errors, common, json, json.builder, text.builder |
| `nextpas.core.agent.provider.anthropic.decode.pas` | 适配子域 | Anthropic 解码子域（196 行纯函数，非流式 §2.2） | base, intf, errors, common, json |
| `nextpas.core.agent.provider.anthropic.decoder.pas` | 适配子域 | Anthropic 状态机子域（332 行，WireDecoder Q-A1/A2/A6/A8） | base, intf, errors, common, json, log |
| `nextpas.core.agent.provider.fake.pas` | 测试 | scripted/fake provider：脚本化增量回放，离线走通全部上层代码路径；`NewFakeProvider`/`NewEchoProvider` 经门面 re-export（W7，406 行） | intf, fold, json |
| `nextpas.core.agent.tools.pas` | 工具 | 名称/schema 注册校验（aecConfig）、§1.5 参数校验失败→error result、结果截断信封（UTF-8 安全切）、RunToolBatch 批执行器（时钟感知超时/取消合成/异常兜底 aecToolFailed/WriteGuard 迟到写仲裁）；`WithTools(array of IAgentTool)` 自由函数（G6 补齐 F-M13） | base, intf, clock, errors, atomic, json, text, cancellation |
| `nextpas.core.agent.loop.pas` | 循环 | TAgentLoop 多轮工具循环：编排/预算/事件/防打转/引导收尾；**T1.4** 每轮 `AccumulateUsage` 后经 `pricing.EstimateCost` + `AgentEstimateTokens` 估 cost 透传 `IAgentUsageSink.RecordUsage`（nil 退化/吞异常不 raise）；全部工具经 IThreadPool（LIFECYCLE §5，D14/C9） | base, intf, clock, errors, tools, thread(pool), json, log, cancellation, pricing |
| `nextpas.core.agent.session.pas` | 会话 | **已落地（W5 2026-08-25）**：`TJsonlTranscriptStore` JSONL 实现 `IAgentTranscriptStore`（Append/Load/Delete/Fork），经门面 `NewJsonlTranscriptStore` 暴露；Fork 需经接口可达（F-H10 已修） | intf, fs, json, text.builder, base |
| `nextpas.core.agent.quota.pas` | 配额 | **Phase1 T1.2（2026-08-30）**：平台配额标量滚动窗口纯函数（`TPlatformQuotaWindowKind=pqDay/pqWeek/pqMonth` + `PlatformQuotaWindowSeconds` 86400/604800/2592000 + `PlatformQuotaWindowExpired`/`PlatformQuotaExpired`/`PlatformQuotaUsage`/`PlatformQuotaExceeded`/`SerializePlatformQuotaItem`），复刻 `token888::PlatformQuota*`（无 TConcurrentHashMap，O(1) 纯标量零IO） | json.builder |
| `nextpas.core.agent.pricing.pas` | 策略 | **Phase1 T1.1（2026-08-30）**：纯策略计费：`TModelPricing`/`EstimateCost`（`(prompt*per1k+500) div 1000 + (completion*per1k*rate+5000) div 10000` 整数μUSD，四舍五入同源 `tk888.billing.pas:22,212`）+ `TPassthroughPricing`/`ImageTierOf`（max-edge ≤1024→1000 ≤2048→2000 else 4000，含 `2048x2048→2000` 特判 `billing:470`）零IO纯函数，无堆分配 | agent.base |
| `nextpas.core.agent.snapshot.pas` | 复用 | **Phase4 有界快照管线（2026-09-01）**：`BuildBoundedSnapshot` 一站式合并去重+簇安全截断（6000 B 预算，`AgentUtf8SafeCutLen/Truncate` 单一真源）+ `BoundedSnapshotTokens/Cost` 成本联动；零直接依赖 FPC RTL（StringOfChar 等收至 nextpas.core 数值域），供 `PROMPT-BUDGET.md` 消费方直接复用（84 行，含首簇溢出空串分支） | agent.base, agent.pricing, text.utf8 |
| `nextpas.core.agent.streambox.pas` | 复用 | **Phase4 流式盒（2026-09-01）**：`TAgentStreamBox` Lock+Done+id 迟到丢弃封装（`TPlatformMutex` 经 `platform.sync`，零直接依赖 SyncObjs），对应 `PERFORMANCE.md §7.2` TAiStreamBox 的可复用落点 | agent.base, platform.sync |

体积指引：单文件 >800 行必须拆分（provider.* 各子域预期 ~500-700 行，含 wire 映射注释；超出即拆 `provider.<name>.<aspect>` 子模块）。
现状（2026-09-03 json 显式依赖收口 + 有界快照/流式盒）：`provider.common` 291+565+110+520 / `provider.openai` 326+351+233+360 / `provider.openai.responses` 256+308+246+442 / `provider.anthropic` 398+451+197+333 —— provider 域 14/14 <800 全达标（含 fake 407）；`base` 250+587+414 + `slotmap` 145 + `deltabuilder` 128 + `snapshot` 84 + `streambox` 131（托管逐项赋值）/ `loop` 57+97+122+187+681 / `transport.http` 73+197+464=734 / `hedge` 570 / `session` 552；总量 13687。

## 3. 数据流

### 3.1 非流式

```
Complete(req, tools)
  → adapter: TCompletionRequest + TToolSpec[] --编码--> wire JSON 文本
  → transport.RoundTrip(TWireRequest)                [HTTP POST]
  → adapter: 响应体 --解码--> TMessage（含 usage/finish/Extra 回注）
  → 返回 TMessage
```

### 3.2 流式（真增量）

```
Stream(req, tools)
  → adapter 编码请求 → transport.OpenStream()
      http client 发出 POST（响应头到达即返回）
      循环：IReader.Read(32KB chunk，PERFORMANCE §2)
            → agent.sse.Feed(chunk) → 完整 SSE 帧
            → adapter.DecodeFrame(frame) → 0..N 个 TStreamDelta
            → 立即经 IAgentWireStream.NextEvent 上抛   ← 首 token 无整包缓冲
  → IAgentCompletion.NextDelta() 逐个交付给消费方
  → EOF：FinalizeStream 合成终帧（usage/finish 到达顺序差异在此抹平）
       → GetMessage()/GetUsage() 可用
```

关键点：`agent.sse` 是 feed 式**字节域**解析器（TByteSpan 进；UTF-8 序列
跨块边界与 BOM 在内；DoS 上限触发抛 aecProtocol）。`http.sse` 已由 http lane
以 K61 独立完成 feed 式改造——TSSEFeeder 单一引擎、ParseSSE 委托之（WHATWG
规格对齐，text 行域）。两引擎输入域不同（bytes vs text），合并不立项；
本单元原"http.sse 晋升候选"主张就此关闭。

### 3.3 工具循环

```
TAgentLoop.Run(userText)
  └─ round = 1..MaxRounds:
       provider.Stream(req = RequestBase + transcript 追加为 Messages)
                                                  ← 每轮全量重发历史（v1 语义）；
                                                    前缀字节稳定不变量 PERFORMANCE §6
       drain deltas: OnEvent(lev*) 透传 + FoldDelta 累积
       assistant := build.Finish
       if 无 pkToolCall part → 终止路径（§5 引导语义或 roCompleted）
       收集本轮 tool calls（按 ToolIndex 排序）
       并行判定：批内全部 spec ∈ tcParallel 才并行；串/并行都经线程池执行
       for each call:
         PreToolCall hook → proceed / block(合成 error result) / stop turn
         ValidateToolArguments（§API 1.5 规范，失败合成 error result 回喂模型）
         Execute(args, 子令牌)                    [线程池 + TimeoutMs 汇合，弃置策略 LIFECYCLE §5]
         截断信封化（UTF-8 安全切 + 合法 JSON 包裹 + Truncated 标记）
         PostToolResult hook（只见截断后载荷——DoS 时序）
       history += assistant msg + 一条 mrTool 消息（每 call 一个 pkToolResult part）
       预算结算（usage 增量累计）；终止检查走统一引导收尾（LIFECYCLE §4）
```

## 4. 并发与取消模型

| 对象 | 线程契约 |
|------|---------|
| `IAgentProvider` | 不可变配置；并发调用 `Complete`/`Stream` 安全（每次调用独立状态） |
| `IAgentCompletion` | `NextDelta` 仅允许创建线程调用（pull 所有权）；`Cancel` 任意线程、幂等 |
| `IAgentTransport` | 同 provider；每个流独享连接与解析状态（token888 双状态教训：decode/encode 状态绝不共享） |
| `IAsyncCancellationToken` | 复用 `async.cancellation`；loop 在轮界/tool 界检查；传输层 Cancel 使 `NextEvent` 立即返回 False |

取消语义统一规则：

- pull 式（NextDelta/NextEvent）：Cancel 后返回 False（EOF 形态），消费方用
  `GetCancelled` 区分取消与正常结束——**不靠异常打断拉取循环**。
- 全量式（Complete / Loop.Run）：抛 `EAgentCancelled`。
- 退避睡眠一律走 `IAgentClock.SleepMs(ms, token)`，令牌触发立即返回
  （真实时钟底层 `WaitForCancel`；ns 换算带溢出防护）。
- 取消后磁盘/资源收尾由拥有线程独占执行（code888 M8 规则）。

## 5. 预算与失败语义

- 用量一律 Int64 token 数，未知字段 sentinel `-1`；估算值永不进入约束性判断。
- loop 预算：`MaxOutputTokens`（跨轮累计 usage 输出）/ `MaxToolCalls`；
  达限不是异常：追加一条 system 引导消息（"停止调用工具并用纯文本总结"）+
  最后一轮禁用工具的推理（code888 UX 教训），随后正常返回并置
  `RunOutcome = roBudgetExhausted`。
- 故障归因分离（token888 教训）：网络/5xx/429/超时 → 可重试类错误码；
  上游 400 类语义错误原样抛出（保留 RawBody 摘要 ≤8KB），重试装饰器不碰它们。
- `aecContextOverflow` 单列错误码：检测多家措辞（context_length / token limit /
  too many tokens），是否压缩由消费方决定——loop v1 不做自动 compaction
  （扩展点：消费方可在轮外自行裁剪 history 后重跑）。

## 6. 内存与字符串所有权

- `TJsonText = type string`：所有承载 JSON 的字段用它标注"owned 全量文本"
  （core 的 TJsonValue 是 borrow 视图，生命周期不可跨作用域假设；文本无损且
  天然携带未知字段——与 token888 Extra 纪律一致）。
- record 数组只整体重建（SetLength），绝不原地改共享数组元素（动态数组 COW 歧义，
  code888 G2 教训）；热路径避免 per-delta SetLength（fold 用容量倍增缓冲）。
- 析构/Close 不允许抛异常（best-effort 吞掉并记录 log.intf 警告）。
- 所有 Close/Free 幂等；stream 关闭即释放连接回池。

## 7. 门面 re-export 政策

> 单一消费点：`nextpas.core.agent` 是唯一对外门面，纯 re-export；新增条目需同步本文档与 `API.md §3`，禁止私下扩展（F-H09 审计后冻结）。

门面按域白名单分组（G6 2026-08-29 完整清单，F-H09/F-H19 合规）：

| 域 | 白名单（全部经门面 `inline` 转发） | 说明 |
|---|---|---|
| **词表与常量** | 公共 record/enum/常量：`TMessage/TPart/TStreamDelta/TTokenUsage/TCompletionRequest/TToolSpec/TAgentErrorCode/...`；DoS 单一真源常量 `CAgentMaxSlotMap/CAgentMaxWireHeaderValueBytes/CAgentMaxWireTotalHeaderBytes/CAgentMaxSuccessBodyBytes/CAgentMaxRawBodySnippetBytes/CAgentMaxExtraKeys/CAgentMaxToolArgsBytes` 等；helpers `MessageText/WireHeaderValue/MergeExtraJson/AgentUtf8SafeTruncate/AgentValidateWireHeaders/AgentInitUsageUnknown/AgentTruncateEnvelope/AgentJoinWireUrl/AgentBuildSystemText/AgentBuildBatchSignature` | 来自 `base`，权威表 `API.md §10` |
| **Provider 工厂与编解码器（D13 公开表面）** | `NewOpenAIProvider/NewOpenAIProviderFromEnv/EncodeOpenAIRequest/DecodeOpenAIResponse/NewOpenAIWireDecoder/BuildOpenAIUrl`；`NewGrokProvider/NewGrokProviderFromEnv/BuildGrokUrl`；`NewAnthropicProvider/NewAnthropicProviderFromEnv/EncodeAnthropicRequest/DecodeAnthropicResponse/NewAnthropicWireDecoder/BuildAnthropicUrl/EncodeAnthropicCountTokensRequest/BuildAnthropicCountTokensUrl`；`NewOpenAIResponsesProvider/NewOpenAIResponsesProviderFromEnv/EncodeResponsesRequest/DecodeResponsesResponse/NewResponsesWireDecoder/BuildResponsesUrl`；测试设施 `NewFakeProvider/NewEchoProvider` | 网关型客户直接复用编解码器（CONSUMERS §2） |
| **时钟** | `NewSystemClock/TFakeClock/IAgentClock` | `clock` 域 |
| **工具** | `ValidateToolSpec/ValidateToolArguments/EnvelopeTruncation/NewToolContext`；自由函数 `WithTools(array of IAgentTool): TToolSpecArray`（`tools` 单元，门面转发，F-M13） | `API.md §1.5/§6` |
| **循环** | `TAgentLoop/TAgentLoopOptions/TLoopEvent/TLoopOutcome` + `SetEventHook/SetPreToolCall/SetPostToolResult` 三形态；`WithRetry/TRetryPolicy` | `loop/retry` 域 |
| **会话（W5 已落地）** | `NewJsonlTranscriptStore/TJsonlTranscriptStore/ETranscriptCorrupt/IAgentTranscriptStore`（含 `Fork`）+ `IAgentTranscriptFork` 独立能力接口 | `session` 域，`SESSION.md` |
| **韧性与可靠性装饰器（W8-W11）** | `WithRetry`；`NewFallbackProvider/TFallbackPolicy/TFallbackSwitchHook`；`NewThrottledProvider/NewTokenBucketGate/IAgentRateGate/TThrottlePolicy`；`NewHedgedProvider/THedgePolicy/THedgeFireHook`；纯函数 `StreamHasError/WaitCancelMs/WaitCancelSlice/ClampHintMs`；追踪 `NewTracedTransport/IAgentTraceSink`；能力 `IAgentTokenCounter` | 策略域与 `resilience` 提炼 |
| **配额标量滚动（Phase1 T1.2）** | `TPlatformQuotaWindowKind/TPlatformQuotaItem/TPlatformQuotaArray`；`PlatformQuotaWindowSeconds/PlatformQuotaWindowExpired/PlatformQuotaExpired/PlatformQuotaUsage/PlatformQuotaExceeded/SerializePlatformQuotaItem/PlatformQuotaSerialize` 纯标量滚动（86400/604800/2592000，无 TConcurrentHashMap，O(1) 可单测） | `quota` 域，零IO纯函数 |
| **定价（Phase1 T1.1）** | `TModelPricing/TPassthroughPricing/EstimateCost/ImageTierOf/AgentEstimateTokens/AgentEstimateTokensFromMessage` 纯策略（`EstimateCost` 整数μUSD `(prompt*per1k+500) div 1000 + (completion*per1k*rate+5000) div 10000` 四舍五入同源 `billing:22,212`；`ImageTierOf` max-edge ≤1024→1000 ≤2048→2000 else 4000 含 `2048x2048→2000` 特判；`AgentEstimateTokens` 单一真源粗估） | `pricing` 域 + `textutil` 转发，零IO纯函数 |
| **有界快照/流式盒（Phase4 复用面）** | `CBoundedSnapshotBudget/BuildBoundedSnapshot/BoundedSnapshotTokens/BoundedSnapshotCost` + `TAgentStreamBox`（一站式有界快照管线/流式盒 Lock+Done+id，零直接依赖 FPC RTL） | `snapshot/streambox` 域，`PROMPT-BUDGET.md §2/§5` + `PERFORMANCE.md §7.2` |
| **不进门面** | `TWireRequest/TWireResponse/TWireSSEEvent/IAgentTransport/IAgentWireStream/TSSEParser` 等 wire/传输细节 | 自定义 transport 需显式 `uses nextpas.core.agent.intf`，保持门面最小化 |

体积与分层校验：`make hygiene` 拦截未登记导出；`test_compile_skeleton` 断言白名单与实现一致。
