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

- **ReadIdleTimeoutMs（流式块间空闲超时）**【v1.1 承诺位】——冷读评审判定这是
  传输卫生而非策略题：上游僵死时消费方挂满 TotalTimeout 300s 不可接受。
- **WithFallback 装饰器**（多 provider 容灾链：主路错误码命中白名单→次路重放）——
  纯组合 `IAgentProvider` 即可实现，~百行级。触发：任一客户表达多供应商容灾需求。
- **WithThrottle 装饰器**（客户端限流防 429，消费 core.ratelimit 令牌桶）——
  与 ratelimit 模块的标准库协同故事。触发：客户出现持续 429 场景。
- **IdleGuard 装饰器**（code888 空闲超时 408 语义）——待 code888 Phase 1 接入时
  评估上移为通用 transport 装饰器。
- **WithHedge 对冲装饰器**（延迟敏感场景 T 毫秒后并发第二请求取先达）——
  双倍 token 成本必须显式 opt-in。触发：交互式 agent 产品提出 p95 延迟诉求。
- **Provider 级 tracing 钩子**（onRequest/onResponse/onRetry 观测事件，
  loop OnEvent 的 provider 层对位）——触发：首个生产接入方要求请求级追踪。

### 组 B：能力面扩张（含 v1.1 承诺位）

v1.1 第一批立项顺序：**Structured Output → tool_choice**（余项按触发评估）。

- **Structured Output**【v1.1 承诺位 #1】——词表保留位 `ResponseSchemaJson`
  已立（v1 置非空即 aecConfig，防破坏性变更）；立项 = WIRE-MAPPINGS 立 strict
  模式节 + 三方编码实现。行业已把它当核心能力而非可选件。
  【已立项 2026-08-25 → W6 落地】
- **tool_choice 控制**【v1.1 候选 #2】——auto/none/required/具名强制是 agent
  工作流基础控制（冷读评审判定）；词表加 `ToolChoice` 字段成本极低。
  【已立项 2026-08-25 → W6 落地】
- **ReasoningEffort 旋钮**【v1.1 候选 #3】——OpenAI 系 reasoning_effort 无落点、
  与 anthropic Thinking 待遇失衡（冷读评审指认）；anthropic 侧忽略+warn 有
  ParallelToolCalls 先例。
- **CountTokens API**（Anthropic /count_tokens 先例；精确计数不入约束路径，
  仅观测）——计费精度诉求出现时立项。
- **Prompt-cache 断点策略**（loop 自动放置 cache_control 断点；agent 循环每轮全量
  重发历史，缓存命中可省 ~90% 输入费用）——与 §W3 前缀稳定不变量配套。
  触发：W3 落地后按真实账单数据评估。
- **增量 JSON 参数校验**（工具参数片段边到边校验，坏参数流中即败而非执行时败）
  ——底座已核实：json.parser/scanner 为整输入 token 化，无 feed 式增量；
  立项前置条件是先向 json 域提出 feed 式解析反哺 slice。
- **Gemini / Responses 协议编解码器**——不押注单一客户需求；任一多模态/兼容系
  客户接入即可立项（D13 公开 codec 使追加成本低）。
- **工具能力标志回归**：tcIdempotent/tcReadOnly/tcNeedsConfirm 消费语义立项后
  回归 TToolCapability 词表（v1 已裁撤至仅 tcParallel——冷读评审指认死词表）。
- **loop 全局工具并发上限**（D14 明确 v1 不做）——出现跨批资源争用证据时立项。

## 明确不做（v1 冻结）

MCP / embeddings / 图像生成 / WebSocket realtime / 自动 compaction / 子代理编排 /
定价表 —— 见 README「非目标」与 DESIGN §4。（JSON mode 已转为 v1.1 承诺位，
见组 B#1；变更须先改文档再动代码。）
