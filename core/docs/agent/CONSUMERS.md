# CONSUMERS：首发客户剧本（token888 / code888 / 新项目）

> 设计检验标准：想象未来 token888 与 code888 都是本模块的客户。
> 本文档回答三个问题——他们各消费什么、迁移路径长什么样、拿到什么收益。
> 客户场景驱动的 API 变更必须回写 API.md 后才可实施。

## 0. 客户画像与消费面

| 客户 | 形态 | 消费面 | 不消费 |
|------|------|--------|--------|
| **token888** | AI API 网关（服务端） | **词表 + 纯编解码器**（上游侧协议翻译）；错误分类器；usage 词表 | loop / tools / session / transport（它有自己的 channel 池与冷却体系）|
| **code888** | coding agent 应用 | **provider 全栈**：transport + 适配器 + fold + retry/clock；可选 loop | session（自有 event-sourced 实现）、tools/权限（应用域）|
| **新项目** | 任意 LLM 应用 | 门面全家桶，五分钟接入 | — |

关键架构结论（决策 D13）：**编解码器是公开表面，不是 provider 私有细节。**
没有这一条，token888 这种"不打电话、只翻译协议"的客户根本无法成为客户；
有了它，模块的价值面从"客户端 SDK"扩展到"协议词表的单一实现源"。

## 1. 场景一：token888 —— 用 codecs 替换自维护适配器

### 现状痛点

token888 为每个上游协议维护一套 `IProtocolAdapter`（decode 请求/encode 请求/
双向流帧翻译），外加按角色拆分的流状态指针和 `FinalizeStream` 终帧逻辑——
这正是它踩过坑后手工沉淀的逻辑（跨角色状态污染、usage 到达顺序差异）。
这些与本模块 provider.common + 各 provider 单元内的实现**逐条同构**。

### 迁移后的形状

```
现状:  入站协议 ──自研adapter──→ TIR ──自研adapter──→ 上游协议
之后:  入站协议 ──自研入站侧──→ TMessage/Δ词表 ──nextpas.core.agent codec──→ 上游协议
                              （词表成为两套系统的边界契约）
```

- 上游 OpenAI-compat / Anthropic Messages 两族的 encode/decode/stream-decode
  直接删除自研实现，改调 `EncodeOpenAIRequest / DecodeOpenAIResponse /
  NewOpenAIWireDecoder` 与 anthropic 对应三件（API.md §8）。
- 流状态所有权模型不变：每角色一个 decoder 实例（接口引用计数管理，
  替代裸 Pointer+FreeState，消除一类释放 bug 面）。
- `Finalize` 语义等价替换其 FinalizeStream。
- Gemini / Responses 协议暂留自研（v1 未覆盖，见 §5 反哺通道）。

### 收益

| 项 | 现状 | 之后 |
|----|------|------|
| 协议代码维护面 | 每协议 ~千行自研 + 快照测试自建 | 删除；共享 core 的怪癖回归集（WIRE-MAPPINGS 怪癖表） |
| 流状态安全 | 手工 Pointer 配对释放 | 引用计数 decoder，编译期生命周期 |
| 协议知识同步 | 厂商怪癖修两遍 | 修一遍（怪癖清单单点维护） |

## 2. 场景二：code888 —— provider 栈整体换装

### 兼容性底子

本模块词表刻意与 code888 对齐（pull 式 NextDelta、sdk*/pk* 枚举命名同源、
sentinel 选项、唯一 fold、transport 接缝、注入时钟）。迁移是**平移不是重写**。

### 符号映射表

| code888 | nextpas.core.agent |
|---------|--------------------|
| `TLLMProvider` | `IAgentProvider` |
| `ChatCompletion(...)` | `Complete(...)` / `Stream(...)` |
| `ILLMCompletion.NextDelta` | `IAgentCompletion.NextDelta`（同名同义）|
| `TStreamDelta/sdkTextDelta...` | 同名枚举；工具调用细化为 Start/Delta/End 三事件 |
| `FoldStreamDeltas` | `FoldDeltas` / `TAssistantBuild` |
| `ILLMTransport.RoundTrip` | `IAgentTransport.RoundTrip`（新增 `OpenStream` 真增量）|
| `TBufferedCompletion`/fake | `NewFakeProvider` + ScriptedTransport（TESTING.md §3）|
| `TLLMErrorCode lec*` | `TAgentErrorCode aec*`（lecContextOverflow→aecContextOverflow 等）|
| `CTempUnset/CPenaltyUnset/CSeedUnset` | `CTemperatureUnset/CSeedUnset` |
| `TOwnedJson` | `TJsonText` |
| retry 配置键散落 | `TRetryPolicy` 记录 + `WithRetry` 装饰器 |
| `CODE888_<VENDOR>_API_KEY` | `NEXTPAS_AGENT_<VENDOR>_API_KEY`（新契约，见 §3）|

### 分阶段采用

1. **Phase 1（薄垫片，~200 行）**：code888 的 `TLLMProvider` 门面内部改指
   `IAgentProvider`，runtime/loop/session/tools 一律不动——立刻获得真增量流式
   （首 token 延迟从"不可能"变为真实可达）与 O(n) 折叠。
2. **Phase 2**：删除其 provider.{openai,anthropic,sse,retry} 自研单元与对应测试，
   改依赖 core 的怪癖回归集。
3. **Phase 3（可选）**：评估 `TAgentLoop` 替换其 runtime 中轮询编排部分；
   权限/hook/预算语义保留在应用侧经 loop hook 位接入。

### 收益

| 项 | code888 现状（已核实） | 换装后 |
|----|----------------------|--------|
| 首 token | 整包缓冲后才解析 SSE，不可能达标 | socket 到帧即上抛（bench_sse_feed 佐证）|
| 折叠路径 | per-delta SetLength，O(n²) 尾巴 | 容量倍增缓冲（bench_fold 佐证）|
| 重试/退避 | 自研于 runtime 内，难独立测 | 独立装饰器 + 注入时钟零睡眠测试 |
| 取消 | 自管令牌+睡眠打断 | 底座 async.cancellation 全链路统一 |
| 协议怪癖回归 | 自建快照 | 共享 core gate（Q-O*/Q-A* 清单）|

## 3. 环境变量装配契约（新项目五分钟接入）

统一前缀，杜绝漂移（code888 env 命名漂移教训）：

| 变量 | 含义 |
|------|------|
| `NEXTPAS_AGENT_OPENAI_API_KEY` / `_MODEL` / `_BASE_URL` | OpenAI-compat 族 |
| `NEXTPAS_AGENT_ANTHROPIC_API_KEY` / `_MODEL` / `_BASE_URL` | Anthropic 族 |

规则：

- 必填缺失（key/model 无值）→ `NewXxxProviderFromEnv` 返回 **nil**，绝不静默回退到
  其他端点或 fake——token888 曾因"空库静默回退真实端点"泄漏真实请求（生产事故）。
- `_BASE_URL` 缺省用厂商官方端点常量，属文档化默认而非臆造。
- 显式 options 路径永远优先；FromEnv 只是样板削减。

## 4. 新项目接入检查单（README 同步）

```pascal
// 1) 装配（显式 或 env）
LProvider := NewOpenAIProviderFromEnv;
if LProvider = nil then
  raise EAgentError.Create(aecConfig, 0, 'NEXTPAS_AGENT_OPENAI_* 未配置');
  { 演示代码才允许降级 fake；生产路径绝不静默回退（§3）}

// 2) 可靠性（一行装饰）
LProvider := WithRetry(LProvider, TRetryPolicy.Default, NewSystemClock);

// 3) 调用：一行全量 或 pull 式流式（工具随请求携带）
LReply := LProvider.Complete(
  TCompletionRequest.New('gpt-4o').WithUserText('hi'));

// 3.5) 可选：会话转录持久化（W5 JSONL store；权限边界见 SECURITY §6）
LStore := NewJsonlTranscriptStore('/var/lib/myapp/transcripts');

// 3.6) 可选：结构化输出 / 工具强制（W6；openai 族 json_schema strict，
//      anthropic 侧 schema fail-fast、tool_choice 映射见 WIRE-MAPPINGS §2.1）
// LReply := LProvider.Complete(TCompletionRequest.New('gpt-4o')
//   .WithUserText('extract: ...')
//   .WithResponseSchema('{"type":"object","properties":{...}}'));

// 4) 测试离线：NewFakeProvider 脚本回放，CI 零网络零睡眠
```

## 5. 反哺通道

- 客户发现的协议缺口（如 token888 需要 Gemini/Responses codec）→ ROADMAP inbox
  立项，进 WIRE-MAPPINGS 立节后实施——客户需求是适配器扩张的唯一合法入口。
- 客户暴露的底座缺口 → 按 AGENTS.md 受控跨模块流程报批（先例：agent.sse → http.sse）。
- 本文档随客户接入实测持续修订；"客户收益表"中的每条性能主张最终以
  BENCHMARKS.md 数据兑现，未兑现前保持 draft 措辞。
