# ROADMAP：实施波次

> 前提：本目录设计文档套件（README/ARCHITECTURE/API/WIRE-MAPPINGS/DESIGN/TESTING）
> 已获总控批准。每 wave 出口证据齐备才可 landing；wave 之间 lane 保持可编译。

## Wave 概览

| Wave | 内容 | 出口证据 |
|------|------|---------|
| **W0 骨架** | registry 登记 `agent` family（draft）；空门面+base+errors 编译 gate；本文档转正 | `test_compile_skeleton` 绿；hygiene 绿 |
| **W1 协议与传输** | base/errors/intf 全量词表；fold.pas；agent.sse 增量解析器；transport.http；provider.common + provider.openai（含公开编解码器）+ provider.fake；clock | test_protocol / test_compile_skeleton（含错误分类器断言）/ test_clock / test_sse / test_transport_stream / test_provider_openai / test_codecs(openai) / test_fake_provider 绿 |
| **W2 可靠性** | retry 装饰器（含 fake clock 生产单元）；anthropic 适配器（含公开编解码器）；取消贯穿 transport/provider；usage 全字段映射 | test_retry / test_provider_anthropic / test_codecs(anthropic) 绿 |
| **W3 循环** | tools 校验/截断/超时包装；TAgentLoop（预算/钩子/事件/防打转/引导收尾）| test_tools / test_loop 绿 |
| **W4 收口** | examples（01_quickstart / 02_streaming / 03_tool_loop / 04_offline_test_pattern）；benchmarks 三件套；docs/agent/BENCHMARKS.md + API_COVERAGE.md 建立；README 状态 draft→stable(draft truth) | 全 gates + benches；`git diff --check`；`make hygiene`；Ready 报告 |
| **W5 session 域（2026-08-25 总控立项）** | JSONL event-sourced transcript store——独立设计见 [`SESSION.md`](SESSION.md)（fork/crash 恢复语义、fsync 节奏、行格式 schema v1）；实现 `nextpas.core.agent.session` + `test_session` 门 | SESSION.md §10 测试计划全绿 + Ready 报告。子项"agent.sse 反哺晋升 http.sse"**已关闭**：http lane 以 K61 自落
TSSEFeeder feed 式引擎（ParseSSE 委托单一引擎，WHATWG 对齐），目标达成无需
跨模块 slice；两引擎输入域不同（agent.sse 字节域含 UTF-8 跨块/BOM/DoS 上限，
http.sse 文本行域），合并经审计判定不立项 |
| **W6 结构化输出与工具选择（v1.1 第一批，2026-08-25 立项）** | 词表 `TToolChoiceMode`/`ToolChoiceName` + `ResponseSchemaJson` 启用；openai 族 json_schema strict 编码 + tool_choice 四形态；anthropic tool_choice 映射（required→any、none→省略 tools 转译）+ schema fail-fast；WIRE-MAPPINGS §1.7 立 strict 节 | test_provider_openai / test_provider_anthropic / test_codecs / test_fake_provider 扩测全绿（含 HEAPTRC 泄漏门）+ 三基准无回归 + Ready 报告 |
| **W7 推理力度与流式空闲卫生（v1.1 第二批，2026-08-25 立项）** | 词表 `TReasoningEffort`（openai reasoning_effort 编码，anthropic 忽略+warn 待遇对齐）；传输层 `ReadIdleTimeoutMs` 流式块间空闲超时（回环时序验证，aecTimeout 合成不污染取消标志）；新增 `test_e2e_live` 真实端点 opt-in 门 | test_provider_openai / test_provider_anthropic / test_transport_stream / test_e2e_live 扩测全绿（含 HEAPTRC 泄漏门）+ 三基准 A/B 无回归 + Ready 报告 |
| **W8 可靠性装饰器套件（v1.1 第三批，2026-08-25 立项）** | `WithFallback` 多供应商容灾链（白名单切换、首 delta 门、最后原始错误透传、取消即止、OnSwitch 观测）+ `WithThrottle` 客户端限流（`IAgentRateGate` 细接口对接 core.lockfree.ratelimit 标准库，clock 注入零睡眠等待，超窗本地 aecRateLimited 带 RetryAfterMs） | test_fallback / test_throttle 全绿（含 HEAPTRC 泄漏门）+ 三基准 A/B 零回归 + Ready 报告 |
| **W9 Responses 协议与对冲（v1.1 第四批，2026-08-25 立项）** | OpenAI Responses API 编解码器（独立单元 `provider.openai.responses`：input 数组/instructions/reasoning.effort/tool_choice/text.format 编码，output 项+usage details 解码，SSE `response.*` 事件全集→词表增量；E2E 真网三协议支柱补齐）+ `WithHedge` 对冲装饰器（DelayMs 无响应即并发第二路取先达、输路必 Cancel、双倍 token 成本工厂级 opt-in；可靠性装饰器四象限收官：retry 败后重试/fallback 败后换家/throttle 事前整形/hedge 慢时对冲） | test_provider_responses / test_hedge 全绿（含 HEAPTRC 泄漏门）/ test_e2e_live 扩 responses 三测真网全绿 + 三基准 A/B 零回归 + Ready 报告 |
| **W10 提示缓存断点（v1.1 第五批，2026-08-26 立项）** | 词表 `TCacheControlMode` + `WithCacheControl`；anthropic 编码器 ccmAuto 三断点放置（tools 尾/system 数组形态/末条消息尾块，≤4 厂商预算，空载体跳过）；openai/grok/responses 族自动缓存零差异声明；PERFORMANCE §6 标记元数据条款；loop 以请求模板透传零改动消费 | test_provider_anthropic / test_provider_openai / test_provider_responses 扩测全绿（含 HEAPTRC 泄漏门）/ test_loop 跨轮标记移动+内容字节稳定断言 / test_e2e_live 扩 anthropic 缓存往返真网测（二级 opt-in `NEXTPAS_AGENT_ANTHROPIC_CACHE=1`，端点需缓存权限）+ 三基准 A/B 无回归 + Ready 报告 |
| **W11 请求级追踪（v1.1 第六批，2026-08-26 立项）** | 词表 `TTraceRequestInfo`/`TTraceResponseInfo`/`IAgentTraceSink`；`NewTracedTransport` 装饰器——IAgentTransport 一处包装三适配器全覆盖，RoundTrip/OpenStream 前后事件对、异常路径 Status=-1 配对后原样上抛、与 WithRetry 叠装自然 N 对事件可见、IAgentClock 注入零睡眠 | 新门 `test_transport_trace` 全绿（含 HEAPTRC 泄漏门）+ 三基准无回归 + Ready 报告 |
| **W12 Token 预估能力接口（v1.1 第七批，2026-08-26 立项）** | 接缝接口 `IAgentTokenCounter`（`CountTokens`，Supports 探测，仅 anthropic 实现）；anthropic count_tokens 端点映射——POST {base}/v1/messages/count_tokens，请求体与 §2.1 同构但减 max_tokens/stream 两键，响应 `{"input_tokens":N}` 缺键即 aecProtocol；纯编解码器 `EncodeAnthropicCountTokensRequest`/`BuildAnthropicCountTokensUrl` 公开直测（D13）；openai/grok/responses 族无厂商端点诚实不实现该接口 | test_provider_anthropic 扩测全绿（含 HEAPTRC 泄漏门）+ 四基准 A/B 无回归 + Ready 报告 |
| **W13 批内混合调度精化（v1.1 第八批，2026-08-26 立项）** | `tcParallel` 分组调度——按调用序贪心分组：相邻 tcParallel 段整段并行（RunToolBatch 一次提交），非 tcParallel 调用独占执行（单元素批）；修复旧"全有全无"规则下一个非并行调用把整批拖成全串行的并行度塌缩；声明语义严格保持（任一时刻要么恰好一个非并行任务独占，要么只有 tcParallel 任务在跑）；全并行/全串行特例与旧行为一致，超时/取消/合成管线不变；同波诚实评估能力标志词表回归——NeedsConfirm 经 PreHook 已可表达不设标志防死词表，Idempotent/ReadOnly 无模块内消费者维持裁撤 | test_loop 扩混合批测全绿（P,P,N 会合证组内并发+独占探针 / P,N,P 孤立完成不饿死 / N,N 保序回归）含 HEAPTRC 泄漏门 + 四基准 A/B 无回归 + Ready 报告 |

## Wave 内顺序约束

- W1：fold 与 sse 先行并各自带 gate 落地，再接 transport（消费二者），最后 openai
  适配器——依赖方向即施工顺序。
- W2：retry 不依赖 anthropic；两者并行可行但 landing 分开提交（可回滚逻辑单元）。
- W3：loop 只准消费 intf 词表；发现需要 wire 信息即为分层违规，回 W1/W2 修词表。

### 实现期整改记录（W0-W1 施工沉淀）

- sse 多行 data 累积改 `IStringBuilder`（摊还 O(1) 追加，原字符串拼接 O(n²)）——已落地。
- ReadAllBody 倍增预分配（原逐 chunk SetLength 重拷）；错误体累积 64KB 封顶
  （信封摘要只需 8KB）防恶意大 4xx 体——已落地。
- 流式线程模型决策：每流专属 worker 为长生命周期流的正确形态（池化 worker 同样
  被流期钉死；Destroy 确定性由硬取消保证，回环实测收合 ~100ms），非技术债——
  W2 取消贯通复核完毕。
- **W2 取消贯通发现并修复 W1 潜伏缺陷**：transport.http 的 builder 以语句式调用
  fluent 链（返回值被丢弃），标量设置（Timeout/ResponseBodyChunk/ResponseStatus/
  SkipBodyBuffer/CancelToken）全部落在临时副本上——非流式碰巧能跑（直接读响应
  对象），**流式真增量从未生效**；gate 全走 scripted transport 故 W1 未暴露。
  已改链式赋值修复；test_transport_stream 新增回环硬取消两测作为真装配证据。
- **W2 anthropic 波次发现并修复 W1/W2 内存缺陷**：两 wire 解码器持有的
  TWireToolSlotPool 无析构（FSlots 数组含 string/IStringBuilder 托管字段，
  对象释放不会自动终结数组），每次流式补全泄漏整池；测试侧 TCapturingLogger
  以类变量承接 TInterfacedObject 实例（引用计数永不归零）。均由 HEAPTRC_GATE=1
  暴露；补池析构 + 测试改接口持有后 provider 两 gate 泄漏门双绿。
- **W4 后独立 slice 清零两处存量 HEAPTRC 泄漏**（此前"已知未清"项）：
  test_retry 根因有二——①GateAttempt 每次 OnAttempt 通知经 `APrior.Rebuild`
  新建 EAgentError 无人释放（37 小块主体），已改调用方 try/finally Free 并在
  TRetryAttemptHook 注释固化借用契约；②测试侧三守卫用例以类变量持有
  TFakeClock，构造器在 FClock 赋值前抛出即孤儿，改接口持有。
  test_transport_stream 根因：TWireStream 以裸类引用持有 TWireMsgChannel
  （TInterfacedObject 后代，引用计数永不生效），Destroy 只收 worker/parser
  不 Free 通道——每流泄漏通道对象+256×40B 环形缓冲（观测的 10256B+280B 对），
  已补 FChannel.Free（对齐 log 域 sink 析构顺序）。定位路径留档：BISECT3
  （仅起停回环+裸连接喂 Accept）证明 net/线程设施零泄漏；http client 大套件
  166 测同款回环路径 HEAPTRC OK 排除底座；块尺寸 256×40B+16B 头与环形缓冲
  严丝合缝定根因。两 gate 现功能绿且泄漏门双清零。
- **W3 loop 波次发现并修复一参构造漏建池**：TAgentLoop.Create(AProvider) 未
  创建自有 IThreadPool，FPool=nil；首次工具执行 SubmitDirect 即 AV。既有 gate
  要么显式传池要么直连 RunToolBatch，故 W2 未暴露；test_loop 全部走一参构造，
  首跑即抓出。已改构造即建池（随实例 Shutdown）。
- **W3 loop 波次发现并修复异常所有权缺陷**：轮失败路径 `R.WLastError := Ex`
  存储了 RTL 在 except 块结束时自动释放的异常对象——悬挂指针（读 Message 即
  AV、析构二次释放、HEAPTRC 连带假阳性）。两处失败路径（轮内 + 引导轮）均补
  AcquireExceptionObject 移交所有权给 TLoopRun（析构 Free）。
- LIFECYCLE §5 措辞已按实现修订：SubmitDirect 直提 + WaitAllTimeout 200µs
  切片轮询 + 逐项时钟感知截止合成（原 SubmitBatch + 批级一次汇合措辞不符）。
- **W4 收口发现并修复 openai 根级已知键漏 'model'**：CKNOWN_ROOT 未含
  model，已知字段（AMsg.Model 已映射）被二次捕获进 ExtraJson——挤占
  64 键捕获预算且污染回注。test_security 的 Extra 上限断言暴露；已补。
  anthropic 根级表核对无此缺口。
- **W4 装配门教训**：loop 恒走流路径——scripted transport 喂非流式体时
  流路径折叠为空消息（不报错）。test_assembly 以 SSE 块脚本供给并在注释
  记录该形态约定；provider 级非流式 e2e 仍归 test_provider_* 门。

## Inbox（活动输入池，非承诺）

提升候选按"架构已预留扩展位 / 需新立项"分两组；每项标注触发条件。
立项 = 先改对应规格文档，再动代码。

### 审计记录（2026-08-25 交接审计）

- **错误分类器两子项缺直接用例**【测试债】——TESTING.md 曾以从未存在的
  `test_errors` 门声称覆盖"RetryAfterMs 解析（秒级头/date 拒绝→unknown）"与
  "超窗措辞全集识别"；实际仅 retry-after-ms 整数头经 test_retry 真链路覆盖
  （7500ms 用例），秒级头/HTTP-date 形态与 MatchesOverflowPhrases 措辞全集均
  无用例。文档口径已同轮修正为事实。
  【已清偿 2026-08-25】新门 `test_provider_common`（9 测，含 HEAPTRC 泄漏门）
  补齐全部直接用例；写测时发现 ParseRetryAfterMs 的 ms 路径缺负值守卫
  （秒级路径有 `>=0` 而 ms 路径没有），恶意负值 retry-after-ms 头可绕过
  WithRetry 总预算上限检查（`LDelay > 0` 才检查）——已补守卫，TDD 红→绿留痕。
- 同轮文档修正：TESTING.md gate 表删除重复 anthropic 行并补登记真实存在的
  `test_clock`（5 测）；ARCHITECTURE.md 撤除从未落地的
  `agent.session.pas`"内存实现（W4 起）"表述，改为 intf 词表接口先行的如实记载。

### 组 A：装饰器/接口扩展位已预留，落地即插即用

- **IdleGuard 装饰器**（code888 空闲超时 408 语义）——待 code888 Phase 1 接入时
  评估上移为通用 transport 装饰器。

### 组 B：能力面扩张（待触发）

- **增量 JSON 参数校验**（工具参数片段边到边校验，坏参数流中即败而非执行时败）
  ——底座已核实：json.parser/scanner 为整输入 token 化，无 feed 式增量；
  立项前置条件是先向 json 域提出 feed 式解析反哺 slice。
- **Gemini 协议编解码器**——不押注单一客户需求；任一多模态/兼容系
  客户接入即可立项（D13 公开 codec 使追加成本低）。
  【Responses 半边已立项 2026-08-25 → W9 落地；本项仅 Gemini 半边待触发】
- **工具能力标志回归**：tcIdempotent/tcReadOnly/tcNeedsConfirm 消费语义立项后
  回归 TToolCapability 词表（v1 已裁撤至仅 tcParallel——冷读评审指认死词表）。
  【评估结论 2026-08-26（W13 同波）：NeedsConfirm 确认门语义 PreHook 已完备
  表达——同步回调在提交前运行、可阻塞等外部批准，设标志属重复表达面；
  Idempotent/ReadOnly 无模块内消费者（loop 重试哲学=模型驱动，不做工具级
  自动重试）维持裁撤。重新触发条件=出现真实消费者（审计分类/会话级确认
  状态机），届时先立消费语义节再回归词表】
- **loop 全局工具并发上限**（D14 明确 v1 不做）——出现跨批资源争用证据时立项。

### 已归档（Inbox→Wave 已落地，不再占待触发池）

> 契约时效：下表项已于对应 Wave 落地并经 gate 验收，移出 Inbox 待触发池以保
> 持输入池纯净；Wave 表为落地权威。

| 能力项 | Wave | 立项→落地 | 备注 |
|--------|------|-----------|------|
| ReadIdleTimeoutMs（流式块间空闲超时） | W7 | 2026-08-25 → W7 | 传输卫生，aecTimeout 合成不污染取消标志 |
| WithFallback 装饰器 | W8 | 2026-08-25 → W8 | 多 provider 容灾链，白名单切换/首 delta 门 |
| WithThrottle 装饰器 | W8 | 2026-08-25 → W8 | 客户端限流，core.lockfree.ratelimit 细接口 |
| WithHedge 对冲装饰器 | W9 | 2026-08-25 → W9 | p95 对冲，双倍 token 成本显式 opt-in |
| Provider 级 tracing 钩子 | W11 | 2026-08-26 → W11 | NewTracedTransport 一处接线三适配器全覆盖 |
| Structured Output | W6 | 2026-08-25 → W6 | ResponseSchemaJson strict 模式 |
| tool_choice 控制 | W6 | 2026-08-25 → W6 | auto/none/required/具名四形态 |
| ReasoningEffort 旋钮 | W7 | 2026-08-25 → W7 | openai reasoning_effort，anthropic 忽略+warn |
| Prompt-cache 断点策略 | W10 | 2026-08-26 → W10 | anthropic cache_control 三断点 ≤4 预算 |
| Responses 协议编解码器 | W9 | 2026-08-25 → W9 | OpenAI Responses 独立单元 provider.openai.responses |
| CountTokens API | W12 | 2026-08-26 → W12 | anthropic /count_tokens，IAgentTokenCounter |

## 明确不做（v1 冻结）

MCP / embeddings / 图像生成 / WebSocket realtime / 自动 compaction / 子代理编排 /
定价表 —— 见 README「非目标」与 DESIGN §4。（JSON mode 已转为 v1.1 承诺位，
见组 B#1；变更须先改文档再动代码。）
