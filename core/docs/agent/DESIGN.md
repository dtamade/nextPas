# DESIGN：对标分析与设计决策记录

> 回答"为什么是这个形状"。对标同类顶级产品，逐条记录采纳/拒绝及理由。
> 实施者不需要重读外部产品——本文档即结论。

## 1. 对标对象

| 产品 | 借鉴什么 | 定位差异 |
|------|---------|---------|
| **Vercel AI SDK Provider Spec**（`@ai-sdk/provider`） | 统一模型词表（stream part 枚举：text-delta/reasoning/tool-call/finish/error）+ 每厂商一个 spec 适配器 + 中间件包装（wrapLanguageModel ≈ 我们的 WithRetry 装饰器）。这是"stdlib 级 provider 抽象"的最成熟公开范本 | 它绑定 TS 迭代器/WebStream；我们用 pull 式接口 + Pascal record 词表 |
| **Anthropic Messages API** | 流式事件词汇（message_start / content_block_start·delta·stop / message_delta·stop）与 tool_use/tool_result 块模型；thinking+signature 的透传纪律 | 我们把它的分块生命周期归约进统一 delta 词表，而不是暴露厂商事件 |
| **OpenAI Agents SDK** | Agent=配置、Runner=循环的分离；max_turns 上限；工具循环终止语义；guardrails→我们的 hook 位 | 它自带 handoffs/tracing 生态；v1 不做，loop 保持薄 |
| **Claude Agent SDK / Claude Code** | 权限/hook 判定三值（proceed/block/stop）、工具结果截断上限、"步骤耗尽后引导模型总结收尾"的 UX | 那些是应用层策略；本模块只留 hook 点与默认参数 |
| **LangGraph** | 持久化检查点思想 → IAgentTranscriptStore 接口先行 | **拒绝**图引擎抽象：stdlib 不该强制状态机框架；线性轮次循环 + 钩子覆盖 v1 全部场景 |
| **LiteLLM / token888 网关** | IR 中枢（N 协议=2N 适配器）、Extra 无损回注、FinalizeStream、故障归因分离、整数用量数学 | 网关做协议翻译；我们是客户端侧，方向相反但词表同源 |
| **codex / opencode / grok-build**（经 code888 三方对比沉淀） | pull 式流、transport 接缝+可注入时钟、idle-guard 装饰器位、sentinel 选项、CI 全离线纪律 | code888 是应用 runtime；我们把其中**库性资产**下沉成可复用模块 |

## 2. 决策记录

### D1 单一规范词表 + 唯一纯折叠函数
- **决定**：`base` 定义 TMessage/TPart/TStreamDelta 词表；`fold.pas` 是唯一 delta→消息实现。
- **备选**：各适配器直接产出消息（token888 前身式两两翻译）；每适配器自带累积器。
- **理由**：code888 用"三方共用同一 fold"消灭了一整类"测试过但运行时分叉"bug；
  Vercel AI SDK 同构（specification 包独立于 provider）。测试禁止重写折叠逻辑。

### D2 pull 式流原语 `NextDelta(out Δ): Boolean`
- **决定**：消费方拉取；Cancel 正交；取消以 EOF 形态呈现并用 GetCancelled 区分。
- **备选**：push 回调（onDelta/onFinish/onError 三回调）；协程通道。
- **理由**：pull 对 mock/断言最友好（fake 直接喂数组即可），消费循环是直线代码；
  push 回调在异常传播与背压上复杂。Vercel 用 async iterator、codex 系用 reader——
  业界收敛于拉取形态。全量式 API（Complete/Run）保持异常通道，符合 core 错误策略。

### D3 真增量传输，从第一天起
- **决定**：transport.OpenStream 基于 http client `IHttpResponse.Body: IReader`
  逐块读取 + 自有 feed 式 SSE 解析器（`agent.sse`），socket 到帧即上抛。
- **备选**：复用 `http.sse.ParseSSE` 整包解析（code888 现状）。
- **理由**：首 token 延迟是 agent 体验的一级指标，整包缓冲使其不可能达标。
  已核实缺口只在解析器（IReader 本身支持增量读）。`agent.sse` 行为稳定后提请
  反哺晋升进 http.sse（跨模块 slice，需总控批准）——先例：code888 曾把 SSE
  parser 下沉进 core。

### D4 无全局注册表，构造函数装配
- **决定**：`NewXxxProvider()` 工厂函数；消费方持有实例；loop 内置实例作用域工具表。
- **备选**：code888 式 file-level 全局 RegisterProvider/RegisterTool。
- **理由**：库会被多 agent 宿主同进程加载；全局可变注册表带来初始化顺序与
  隔离问题（Go stdlib 形态：构造器+显式依赖）。

### D5 Sentinel 选项："未设置绝不上送"
- **决定**：CTemperatureUnset=-2.0 等 sentinel + TTriState 三态布尔；序列化跳过 unset。
- **理由**：Pascal 无 nullable；code888 已验证该模式并留下教训"勿臆造 auto"——
  anthropic max_tokens 被静默填 4096 属反面教材，本模块改为显式 aecConfig 快速失败。

### D6 重试是装饰器，provider 层零自动重试
- **决定**：`WithRetry(inner, policy, clock)` 包装任意 provider；睡在注入时钟上；
  仅对 RetryOn 白名单错误码重试；Retry-After 优先。
- **备选**：provider 内建重试开关（多数 SDK 做法）；完全不重试（token888 现状，
  单请求瞬态失败直通给终端用户）。
- **理由**：装饰器可与 fake/scripted 组合测试（零睡眠）；策略可按宿主调参；
  token888 证明"无请求内重试"在生产不可接受，code888 证明"runtime 里散落重试"
  不可测。故障归因分离沿用 token888：上游 4xx 语义错误永不重试。

### D7 取消复用 async.cancellation
- **决定**：全链路传 `IAsyncCancellationToken`；退避睡眠走 WaitForCancel；
  传输层 Cancel 使 NextEvent 立即 False；磁盘收尾由拥有线程独占。
- **理由**：底座已有原语（含子令牌树），不重复造；code888 的 ns 溢出防护与
  M8"取消只翻令牌"规则一并吸收为固定语义。

### D8 工具 = record spec + 接口执行器，能力标志驱动并行
- **决定**：TToolSpec（schema 文本+能力集）与 IAgentTool 执行解耦；批内全部声明
  tcParallel 才并行；调用侧务实级 schema 校验失败合成 error result 回喂模型。
- **备选**：硬编码并行白名单；完整 JSON-Schema 校验器。
- **理由**：code888 验证了能力标志比白名单健壮；完整 schema 校验是一个独立模块
  级工程（validation/json 域），v1 明确降级为结构校验并在 TESTING 记录边界。
  工具失败双防线：实现方返回 IsError，异常由 loop 兜底转 aecToolFailed。

### D9 用量 Int64 + 计价外置
- **决定**：TTokenUsage 六字段 Int64，未知=-1；不内置价格表。
- **理由**：token888 整数货币数学证明估算/浮点进入约束路径必出事；价格易变，
  标准库内置必然腐烂。缓存命中/推理 token 字段齐备，计价函数由消费方注入。

### D10 会话持久化接口先行、实现后置
- **决定**：IAgentTranscriptStore 进 intf 冻结讨论；内存实现随 W4；JSONL event-sourced
  实现（code888 形态）列独立后续 wave。
- **理由**：持久化语义（fork/crash 恢复/fsync 节奏）体量大且应用相关性强；
  先冻结最小接口避免上层返工，实现按需求追加。

### D11 测试全离线 + 可注入时钟
- **决定**：fake/scripted provider、scripted transport、fake clock 三件套为一级公民；
  仓库内任何 gate 禁触公网 LLM。
- **理由**：code888 AGENTS 明文纪律；其"env 装配漏注 transport 而门测仍绿"事故
  （刀 56）催生附加要求：至少一条 gate 走真实装配点组装链。

### D12 循环保持薄：编排而非框架
- **决定**：TAgentLoop 只做轮次编排/预算/钩子/防打转；无插件系统、无子代理、
  无自动 compaction。
- **备选**：LangGraph 图引擎；OpenAI Agents SDK 的 handoff/guardrail 全家桶。
- **理由**：标准库模块的价值在稳定词表与可靠原语；工作流编排是应用域。
  compaction 留扩展点（消费方裁剪 history 后重跑），子代理=再实例化一个 loop。

### D13 编解码器是公开表面，不是 provider 私有细节
- **决定**：每适配器公开 `EncodeXxxRequest / DecodeXxxResponse /
  NewXxxWireDecoder`，与工厂内部共用同一实现；流解码器为每角色一实例的
  引用计数对象（替代裸指针状态配对）。
- **备选**：codec 藏在 implementation 区（多数 SDK 的做法）。
- **理由**：首发客户推演（CONSUMERS.md）表明网关型客户 token888 消费的是
  协议翻译本身——它自维护的双向 adapter 与本模块实现逐条同构。公开 codec 后
  词表成为"客户端 SDK"与"协议翻译库"的共同底座，厂商怪癖修正单点生效。
  这是"让既有重户成为客户"的关键一步；对纯客户端用户零成本（默认路径不变）。

### D14 并行工具经 L1 线程池执行
- **决定**：并行批次 = `IThreadPool.SubmitBatch` + 轮线程汇合；池可注入；
  子令牌隔离批内失败；不做全局并发上限（v1，inbox 记录）。
- **备选**：async.taskgroup——已核实绑定 `TAsyncLoop`，同步场景属设施错配
  （SELECTION C9）；自研线程池；串行 only。
- **理由**：复用底座原语避免第二套并发设施；SubmitBatch 单锁广播省 per-task
  锁开销；子令牌树精确表达"单工具失败不连坐兄弟"；loop 保持单线程编排心智。
  详见 LIFECYCLE §5。

## 3. 性能姿态

| 主张 | 支撑 |
|------|------|
| 首 token 即时 | D3 增量链路；bench_sse_feed 以 MB/s 计并设回归阈值 |
| 折叠近零开销 | fold 用容量倍增缓冲，禁 per-delta SetLength；bench_fold 以 ns/op 计 |
| 抽象零税 | 词表 record 值传递、热路径无 RTTI/接口查询；bench_loop_overhead 用 fake provider 测整轮开销 µs 级 |
| 无分配风暴 | ArgumentsJson 片段 StringBuilder 累积；transcript 数组整体重建 |

全部主张由 nextpas.core.bench 强制（TESTING.md），不允许无数据的性能叙事。

## 4. 与底座的关系（反哺清单）

1. `agent.sse` → 候选晋升 `http.sse` 增量解析器（D3，跨模块需报批）。
2. 若 H2 路径响应体 IReader 增量读存在缺口 → 凭证据提 Needs Review，不在本 lane 私改 http。
3. 务实级 JSON-Schema 校验若长出完整能力 → 评估上移 validation/json 域。
