# ROADMAP：实施波次

> 前提：本目录设计文档套件（README/ARCHITECTURE/API/WIRE-MAPPINGS/DESIGN/TESTING）
> 已获总控批准。每 wave 出口证据齐备才可 landing；wave 之间 lane 保持可编译。

## Wave 概览

| Wave | 内容 | 出口证据 |
|------|------|---------|
| **W0 骨架** | registry 登记 `agent` family（draft）；空门面+base+errors 编译 gate；本文档转正 | `test_compile_skeleton` 绿；hygiene 绿 |
| **W1 协议与传输** | base/errors/intf 全量词表；fold.pas；agent.sse 增量解析器；transport.http；provider.common + provider.openai（含公开编解码器）+ provider.fake；clock | test_protocol / test_errors / test_sse / test_transport_stream / test_provider_openai / test_codecs(openai) / test_fake_provider 绿 |
| **W2 可靠性** | retry 装饰器（含 fake clock 生产单元）；anthropic 适配器（含公开编解码器）；取消贯穿 transport/provider；usage 全字段映射 | test_retry / test_provider_anthropic / test_codecs(anthropic) 绿 |
| **W3 循环** | tools 校验/截断/超时包装；TAgentLoop（预算/钩子/事件/防打转/引导收尾）| test_tools / test_loop 绿 |
| **W4 收口** | examples（01_quickstart / 02_streaming / 03_tool_loop / 04_offline_test_pattern）；benchmarks 三件套；docs/agent/BENCHMARKS.md + API_COVERAGE.md 建立；README 状态 draft→stable(draft truth) | 全 gates + benches；`git diff --check`；`make hygiene`；Ready 报告 |
| **W5（后置，按需立项）** | JSONL event-sourced transcript store（fork/crash 恢复语义先出独立设计）；agent.sse 反哺晋升 http.sse 的跨模块 slice | 各自独立 Ready 报告 |

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
- 已知未清（后续独立 slice）：test_retry / test_transport_stream 功能全绿但
  HEAPTRC_GATE 报少量未释放块（retry 约 37 小块；transport_stream 5 块、含
  回环线程读缓冲 10KB×2），疑与流 worker/线程生命周期相关，修复需独立验证，
  不并入 anthropic 提交。
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

## Inbox（活动输入池，非承诺）

提升候选按"架构已预留扩展位 / 需新立项"分两组；每项标注触发条件。
立项 = 先改对应规格文档，再动代码。

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
- **tool_choice 控制**【v1.1 候选 #2】——auto/none/required/具名强制是 agent
  工作流基础控制（冷读评审判定）；词表加 `ToolChoice` 字段成本极低。
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
