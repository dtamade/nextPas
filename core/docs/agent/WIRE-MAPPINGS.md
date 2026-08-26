# WIRE-MAPPINGS：厂商线级协议映射真相源

> 各适配器把厂商协议归约为 `API.md` 词表的**唯一权威映射表**。
> 实现与本文档冲突时先改文档再改代码。怪癖（quirk）条目均来自 token888 /
> code888 的生产教训或官方文档行为，实现必须逐条落测试。

## 0. 公共规则（两适配器共用，实现在 provider.common）

| 规则 | 内容 |
|------|------|
| Extra 无损 | 编码/解码时对已知字段做 key 黑名单遍历，未知字段原值捕获进 `ExtraJson`，编码时回注原位。未知字段绝不静默丢弃 |
| RequestId 回显 | 依次探测 `x-request-id` / `request-id` / `anthropic-request-id` 响应头，填入 EAgentError.RequestId |
| 超窗识别 | 状态 400 + 消息匹配（不区分大小写）：`context length` / `maximum context` / `token limit` / `too many tokens` / `context_length_exceeded` / `prompt is too long` → `aecContextOverflow` |
| 错误体摘要 | 上游非 2xx 时截取响应体前 8KB 进 RawBodySnippet；JSON error 信封优先提取 message 字段 |
| 流中途错误 | HTTP 200 且流已开始后到达的错误帧：产出 `sdkError` delta 后终止流（消费方可见），不吞进日志（token888 反例） |
| 未映射枚举值 | 厂商新增/未知枚举值（finish_reason、delta 类型等）：取词表零值（frNone 等），原始文本写入消息级 `ExtraJson` 保留键 `agent.unmapped.<field>`，记 warn。**绝不臆造近似映射** |
| 多字节边界 | SSE 解析按**字节缓冲**工作：UTF-8 序列可跨 Feed() 调用断裂，帧未完整前不得按字符解码（test_sse 有专项断言） |
| SSE 帧文法 | `:` 开头行=注释/keep-alive，忽略；`event:` 无 `data:` 的帧跳过；`id:`/`retry:` 字段 v1 忽略（debug 日志）；未知 event 名 warn+跳过（帧级"未映射"规则）；`data:` 多行以 `\n` 连接 |
| 系统消息确定性 | 顶层 system = 按数组顺序首个 mrSystem 文本；多个 system 段以 `\n\n` 连接；历史中后续 mrSystem 消息按各厂商规则保留原位——算法固定，保障前缀字节稳定（PERFORMANCE §6）|
| BaseUrl 拼接 | 去尾部 `/` 后拼接端点路径；BaseUrl 已含 `/v1` 结尾则只追加 `/chat/completions` 或 `/messages`，否则追加完整默认路径（支持反代前缀部署）|
| Extra 冲突 | 编码时 ExtraJson 键与已知字段同名：已知字段胜出（Extra 让位）；解码侧黑名单已排除，不产生冲突 |
| 时间语义 | 一切毫秒时长 Int64；ms→ns 换算前做溢出防护 |
| 流式空闲卫生 | `ReadIdleTimeoutMs`（TProviderOptions/TWireRequest，CTimeoutDefault=0 即禁用）：流式期间距最近一次到达字节（含响应头）超过该时长即合成 `aecTimeout` 终止流并硬中断在途 IO——上游僵死时消费方不必挂满 TotalTimeout。**不污染取消标志**：GetCancelled 保持 False，消费方可区分"我取消"与"对端僵死"。默认值取舍：o1 系 reasoning 阶段可长时间无增量输出，缺省禁用由消费方按模型族显式设置（推荐 60_000 起）。仅流路径；非流式由 http client TotalTimeout 覆盖 |

## 1. OpenAI Chat Completions 兼容适配器

端点：`POST {BaseUrl|https://api.openai.com}/v1/chat/completions`
鉴权：`Authorization: Bearer {ApiKey}`；可选 `OpenAI-Organization`。

### 1.1 请求映射

| 词表 | wire |
|------|------|
| `Model` | `model`（必填） |
| `System` | `messages[0] = {role:"system", content}`（与历史 System 消息合并去重） |
| `Messages[mrUser].pkText` | `{role:"user", content:"..."}` |
| `Messages[mrUser].pkImage` | content parts 数组形态：`{role:"user", content:[{type:"text"...},{type:"image_url", image_url:{url}}]}`（URL/data URI 均直传）|
| `Messages[mrAssistant].pkThinking` | 非流式：`message.reasoning_content` → pkThinking；流式见 Q-O2。无该字段的模型自然缺省 |
| `Messages[mrAssistant].pkText` | `{role:"assistant", content:"..."}` |
| `Messages[mrAssistant].pkToolCall` | `{role:"assistant", content:null|文本, tool_calls:[{id,type:"function",function:{name,arguments}}]}`（arguments 为折叠后全文） |
| `Messages[mrTool].pkToolResult` | 每部分一条 `{role:"tool", tool_call_id, content}` |
| `MaxTokens` >0 | `max_tokens`；模型族要求 `max_completion_tokens` 时自动改名（quirk Q-O1）|
| `Temperature` ≥0 | `temperature`；unset 不上送 |
| `TopP` ≥0 | `top_p`；unset 不上送 |
| `Seed` ≠ CSeedUnset | `seed` |
| `StopSequences` 非空 | `stop` |
| `ParallelToolCalls` ≠ tsUnset | `parallel_tool_calls` |
| `Tools` 非空（AReq.Tools） | `tools:[{type:"function", function:{name, description, parameters}}]`（parameters 为 JSON Schema 对象）；**空数组不上送字段** |
| `ResponseSchemaJson` 非空 | `response_format:{type:"json_schema", json_schema:{name:"response", strict:true, schema:<原文透传>}}`（§1.7；schema 须可解析为 JSON object，违者本地 aecConfig） |
| `ToolChoice` | tcmUnset 不上送；tcmAuto→`"auto"`；tcmNone→`"none"`；tcmRequired→`"required"`；tcmNamed→`{type:"function",function:{name:ToolChoiceName}}`（缺名或 Tools 空，本地 aecConfig） |
| `ReasoningEffort` ≠ reUnset | `reasoning_effort:"minimal"\|"low"\|"medium"\|"high"`（W7）；仅推理族模型接受，其余上游 400 自然归因（Q-O1 同哲学，不做模型名预判）；Grok 同族适用 |
| 流式调用 | 追加 `"stream":true, "stream_options":{"include_usage":true}`（quirk Q-O3） |
| `ExtraJson` | 浅合并进请求根对象 |

### 1.2 非流式响应映射

```
choices[0].message.content        → pkText
choices[0].message.tool_calls[i]  → pkToolCall{ToolCallId=id, ToolName=function.name,
                                     ArgumentsJson=function.arguments}
choices[0].finish_reason          → frStop|frLength|frToolCalls|frContentFilter
                                       ("stop"|"length"|"tool_calls"|"content_filter")
usage.prompt_tokens               → InputTokens
usage.completion_tokens           → OutputTokens
usage.completion_tokens_details.reasoning_tokens → ReasoningTokens
usage.prompt_tokens_details.cached_tokens → CacheReadInputTokens
id/model                          → TMessage.Id/.Model
```

### 1.3 流式 chunk 映射（SSE）

帧序（含容错）：

```
data: {"id":..,"model":..,"choices":[{"delta":{"role":"assistant",...}}]}（首 chunk）
                                      → sdkEnvelope(MessageId,Model)
data: {"choices":[{"delta":{"role":"assistant","content":"片段"},...}]}   → sdkTextDelta
data: {"choices":[{"delta":{"tool_calls":[{"index":N,"id":..,"function":{"name":..,"arguments":""}}]}}]}
                                      → sdkToolCallStart(index=N)
data: {"choices":[{"delta":{"tool_calls":[{"index":N,"function":{"arguments":"frag"}}]}}]}
                                      → sdkToolCallDelta(index=N)
data: {"choices":[{"delta":{},"finish_reason":"tool_calls"}]}            → sdkFinish
data: {"choices":[],"usage":{...}}                                       → sdkUsage   (Q-O3)
data: [DONE]                                                             → 终止符
连接关闭且未见 [DONE]                                                     → 视为 EOF（Q-O4）
```

### 1.4 错误信封

嵌套形态（OpenAI 官方）与扁平形态（xAI）并存，提取器两者都认：

```json
{"error": {"message": "...", "type": "invalid_request_error", "code": "..."}}
{"code": "invalid-argument", "error": "Could not decrypt ..."}
```

状态→错误码走公共分类器；429 附带 `retry-after` 头按公共规则解析。

### 1.5 OpenAI 怪癖清单

| # | 怪癖 | 处置 |
|---|------|------|
| Q-O1 | 推理族模型拒绝 `max_tokens`，要求 `max_completion_tokens` | 按模型名前缀判定（`o1`/`o3`/`gpt-5` 等，常量表可扩展）；判定失败由上游 400 自然暴露并归因 |
| Q-O2 | `reasoning_content` 增量字段（兼容系厂商普遍支持） | 映射为 `sdkThinkingDelta`；缺省无此字段即无思考输出。**别名**：xAI Grok 系用 `reasoning`，两者并存时 `reasoning_content` 优先（sub2api issue#5302 生产确认）|
| Q-O3 | usage 仅当 `stream_options.include_usage=true` 才随末 chunk 到达，且 `choices:[]` | 必发该选项；兼容端不支持则 usage 保持 CUsageUnknown（Known=False），绝不臆造 |
| Q-O4 | 部分兼容网关不发 `[DONE]` 直接断连 | 连接关闭=EOF；fold 正常收口 |
| Q-O5 | tool_calls 首片携带 id+name、后续片仅 index+args 片段 | Start 只在 **name 就绪时** 发一次；name 未到先缓冲 id/args（延迟命名——部分上游 id+args 先到、name 后到甚至缺失，Finalize 兜底冲刷）。条目缺 `index` **容忍按 0**（单工具流的省略形态，sub2api 生产确认）；负数仍违例。OpenAI 不产 End 事件，封槽由 fold 对 sdkFinish 隐式完成（API §4）|
| Q-O6 | 空 `choices` 数组的中间 chunk 存在 | 跳过，不算协议错误 |
| Q-O7 | `choices` 可能多于一条（n>1 场景） | v1 固定单选择：index>0 的 choice 丢弃并 warn（对"绝不静默丢弃"的显式豁免——多选择语义超出 v1 词表，记录在案）|
| Q-O8 | 上游发 `"stop"` 却带了 tool_calls | 归约为本流已开槽即 frToolCalls（流式看槽表；非流式看 pkToolCall 部件）——保住消费方循环判据（sub2api 同款纠正）|
| Q-O9 | 订阅网关注入 `event: ping` 计费心跳帧，数据非 JSON | 解码器按 event 名跳过该帧；其余 event 名不拦截（方言载荷在 data 行）|

### 1.6 Grok（xAI）家族

- 官方 API：`POST {BaseUrl\|https://api.x.ai}/v1/chat/completions`，Bearer 鉴权；
  wire 与 Chat Completions 同族（订阅上游亦为同方言，sub2api 确认）。
- 编解码器/provider 复用 OpenAI 族实现：差异仅默认端点、归因名 `'grok'`、
  env 前缀 `NEXTPAS_AGENT_GROK_*`。
- 适用怪癖全集 = §1.5（含 Q-O2 别名与 Q-O9 心跳帧）；structured output 与
  tool_choice 编码同族适用（§1.7、§1.1）；`reasoning_effort` 已随 W7 入词表。
- v1 inbox（未入词表）：`x_search` 服务端工具、
  Responses 族 encrypted_reasoning 重试语义。

### 1.7 Structured Output（json_schema strict 模式，W6/v1.1 第一批）

词表 `ResponseSchemaJson` 携带 **JSON Schema 对象文本**（draft 版本由上游
解释，建议 2020-12）。编码形态固定 `strict:true`——输出约束由上游执行，
响应侧仍是普通 content/tool_calls 词表，SDK 不做输出二次校验（消费方自行
解析；frStop 语义不变）。

- `json_schema.name` 固定 `"response"`：OpenAI 必填标识符但无语义载荷，
  词表不为它设字段；上游对 name/schema 的合法性裁决以 400 形态自然归因
  （Q-O1 同哲学：SDK 不做模型/网关能力预判）。
- schema 文本在编码入口经 json 解析器校验为 JSON object，违者本地
  aecConfig 不发网（防呆与 MaxTokens 缺失同纪律）；通过后原文透传
  （不重序列化，与 tools.parameters 同规则）。
- 兼容网关仅支持 `{"type":"json_object"}` 时 strict 形态被上游拒绝并按
  公共分类器归因。
- 流式/非流式共用同一请求编码（Encode 单一实现），无第二形态。

## 2. Anthropic Messages 适配器

端点：`POST {BaseUrl|https://api.anthropic.com}/v1/messages`
鉴权：`x-api-key: {ApiKey}`；`anthropic-version: 2023-06-01`。

### 2.1 请求映射

| 词表 | wire |
|------|------|
| `Model` | `model`（必填） |
| **`MaxTokens`** | **`max_tokens` 厂商强制必填**。unset → 本地抛 `aecConfig`（绝不静默填默认——code888 的 4096 隐式行为被明确否决） |
| `System` / 历史 mrSystem | 顶层 `system`（字符串；多段拼接） |
| `Messages[mrUser].pkText` | `{role:"user", content:[{type:"text", text}]}` |
| `pkImage` | data URI → `{type:"image", source:{type:"base64", media_type, data}}`；http(s) URL → `source:{type:"url", url}`（mime 白名单 png/jpeg/gif/webp，违者 aecConfig） |
| `Messages[mrAssistant].pkText` | `{type:"text"}` 块 |
| `pkThinking` | `{type:"thinking", thinking, signature}`（signature 原样透传，见 Q-A3） |
| `pkToolCall` | `{type:"tool_use", id, name, input:<折叠后的 JSON 对象>}` |
| `Messages[mrTool].pkToolResult` | 归并为**一条** `{role:"user", content:[{type:"tool_result", tool_use_id, content}]}`（Q-A4 分组规则）；`is_error` 遵循哨兵纪律仅失败时上送 true |
| `Tools` 非空（AReq.Tools） | `tools:[{name, description, input_schema}]`；空数组不上送字段 |
| `Temperature` ≥0 | `temperature` |
| `TopP` ≥0 | `top_p` |
| `Seed` ≠ CSeedUnset | 无对应参数：忽略 + debug 日志（与 ParallelToolCalls 同规则）|
| `ReasoningEffort` ≠ reUnset | 无对应参数：忽略 + warn 日志（Q-A5 同规则；推理力度表达走本侧 Thinking/Budget 词表，W7 待遇对齐）|
| `StopSequences` | `stop_sequences` |
| `Thinking` 三态 / Budget | `thinking:{"type":"enabled","budget_tokens":N}`；tsFalse 显式 `{"type":"disabled"}`；tsUnset 不上送；**tsTrue 而 Budget unset → aecConfig**（anthropic 强制 budget_tokens）|
| `ToolChoice` tcmAuto/tcmRequired/tcmNamed | `tool_choice:{"type":"auto"}` / `{"type":"any"}` / `{"type":"tool","name":ToolChoiceName}`（缺名或 Tools 空本地 aecConfig）；仅 Tools 非空时上送 |
| `ToolChoice` tcmNone | 无 none wire 形态：**省略 `tools` 字段**转译等价禁用（Q-A9 备注）；provider 层 debug 日志记一条转译说明 |
| `ResponseSchemaJson` 非空 | **本地 aecConfig**：厂商 API 无结构化输出参数——fail-fast 而非静默降级为 prompt 注入（tool-based 转译为后续候选，见 §3） |
| 流式调用 | `"stream":true` |

注意：anthropic 无 `parallel_tool_calls` 开关（Q-A5）；该词表字段被忽略并在
debug 日志记一条 warning，不算错误。

### 2.2 非流式响应映射

```
content[].type="text"      → pkText
content[].type="thinking"  → pkThinking{Text, Signature}
content[].type="tool_use"  → pkToolCall{ToolCallId=id, ToolName=name, ArgumentsJson=input}
stop_reason: end_turn|stop_sequence → frStop
             max_tokens          → frLength
             tool_use            → frToolCalls
             refusal             → frContentFilter
usage.input_tokens                    → InputTokens
usage.output_tokens                   → OutputTokens
usage.cache_read_input_tokens         → CacheReadInputTokens
usage.cache_creation_input_tokens     → CacheWriteInputTokens
id / model                            → Id / Model
```

### 2.3 流式事件映射（SSE，event: 名为主键）

| event | data 关键载荷 | 产物 |
|-------|--------------|------|
| `message_start` | `message{id,model,usage{input_tokens,...}}` | `sdkEnvelope{MessageId,Model}`；InputTokens 暂存至流末合成 |
| `content_block_start` | `index, content_block{type:text\|thinking\|tool_use{id,name}}` | text/thinking 开 part；tool_use → `sdkToolCallStart` |
| `content_block_delta` | `delta{type: text_delta{text}\| input_json_delta{partial_json}\| thinking_delta{thinking}\| signature_delta{signature}}` | 对应 `sdkTextDelta` / `sdkToolCallDelta` / `sdkThinkingDelta`；signature 经 `sdkThinkingDelta.Signature` 透传 |
| `content_block_stop` | `index` | 工具槽 → `sdkToolCallEnd`；其余收 part |
| `message_delta` | `delta{stop_reason}, usage{output_tokens(累计)}` | OutputTokens 暂存（累计值取最后一次） |
| `message_stop` | — | 触发 FinalizeStream 合成 `sdkFinish`+`sdkUsage` |
| `ping` | — | 忽略 |
| `error` | `error{type,message}` | `sdkError` 后终止流 |

### 2.4 错误信封

```json
{"type":"error", "error":{"type":"invalid_request_error", "message":"..."}}
```
`rate_limit_error` → aecRateLimited；`overloaded_error`(529) → aecServer 可重试；
其余按状态码公共分类器。

### 2.5 Anthropic 怪癖清单

| # | 怪癖 | 处置 |
|---|------|------|
| Q-A1 | `message_start` 是 SDK 解析的强制首信封；缺失即整流报废 | 适配器保证任何合成/回放路径都先产 message_start 等价物（token888 教训） |
| Q-A2 | usage 拆两处：message_start 给 input、message_delta 给累计 output | FinalizeStream 在流末统一合成 usage（到达顺序差异在 fold 层抹平） |
| Q-A3 | thinking 块签名服务端签发，不可伪造；跨轮回传必须原样带 signature | Signature 字段透传；丢失/篡改的回放会遭上游拒绝并归因为请求错误 |
| Q-A4 | tool_result 必须放在紧随 tool_use 的 **user 角色**消息里，且多个 result 应分组在同一条消息 | 循环层每轮工具结果合成一条 mrTool 消息（ARCHITECTURE §3.3），适配器展开为单条 user 消息多 tool_result 块 |
| Q-A5 | 无 parallel_tool_calls 参数 | 见 §2.1 注意事项 |
| Q-A6 | `input_json_delta` 的 partial_json 是纯片段，可能跨块断裂 | 与 openai 同一 index 分桶 + StringBuilder 累积机制（provider.common 单一实现） |
| Q-A7 | 429/5xx 响应可能带 `retry-after` 秒级头 | 公共规则解析；HTTP-date 形态不解析返回 unknown |
| Q-A8 | 连接在 `message_stop` 之前死亡（截断流） | **fail-closed**：decoder.Finalize 无 message_start→stop 完整轨迹即抛 aecProtocol，绝不把截断答案合成完整消息（与 Q-A1 同精神；对照 OpenAI Q-O4 的宽容是各自协议现实）|
| Q-A9 | thinking enabled 时官方仅允许 `tool_choice:{"type":"auto"}`；any/tool 组合遭上游 400 | SDK 不做本地预判（组合约束随上游演化），400 经公共分类器自然归因；tcmNone 的 tools 省略转译不受此约束影响 |

### 2.6 Prompt caching 断点策略（W10/v1.1 第五批）

词表 `CacheControl: TCacheControlMode = (ccmUnset, ccmAuto)`；ccmUnset 不上送
（v1 既有请求字节零变化）。anthropic 是显式打点协议：`cache_control` 附着在
content block 对象上，命中按断点前缀判定，厂商预算 ≤4 个/请求。

**ccmAuto 放置算法**（编码器内固定，确定性保障跨轮稳定）：

| 载体 | 发射形态 | 标记位 |
|------|---------|--------|
| tools | 末个 tool 对象尾附 `cache_control` | 有 Tools 时恒定 |
| system | 从 string 形态切换为单 text block 数组形态并附标记 | 有 system 时恒定 |
| messages | 最后一条消息的最后一个 content block 尾附标记 | 随轮次尾部移动 |

三处合计 ≤3 ≤4 预算；空载体（无 tools/无 system/末条消息无 parts）跳过不打。

**跨家族语义**：openai/grok/responses 三面对象无显式缓存字段——厂商对足长
前缀自动缓存，`ccmAuto` 在这些适配器为零差异意图声明（编码器不产任何字节）。

**与前缀稳定不变量的关系**（PERFORMANCE §6）：cache_control 是请求元数据而
非内容——历史块的文本/id/签名等内容字节跨轮不变，仅末条消息标记附着位随轮
移动；tools/system 段序列化字节跨轮恒定。自定义断点位形仍走 ExtraJson 逃生舱。

## 3. OpenAI Responses 适配器（W9/v1.1 第四批）

> 第三协议支柱。端点 `POST {base}/responses`；与 Chat Completions 共享
> 公共规则（§0）但请求/响应/SSE 三面形态均不同——本节为唯一权威。
> 实现单元 `nextpas.core.agent.provider.openai.responses.pas`（D13 公开
> 编解码器同款三件：Encode/Decode/WireDecoder）。

### 3.1 请求映射

| TCompletionRequest | Responses 字段 | 备注 |
|---|---|---|
| Model | `model` | 必填 |
| System | `instructions` | 顶层全局前缀；Messages 中不再重复注入 system |
| Messages(user text) | `input[]{role:"user",content:[{type:"input_text"}]}` | assistant 回填 `{type:"output_text"}` |
| Messages(tool result) | `input[]{type:"function_call_output", call_id, output}` | 对应上游 function_call 项的 call_id |
| Messages(assistant tool calls) | `input[]{type:"function_call", call_id, name, arguments}` | 回放历史轮的调用项 |
| MaxTokens | `max_output_tokens` | CMaxTokensUnset 省略 |
| Temperature / TopP / Seed | `temperature` / `top_p` / `seed` | sentinel 缺省省略 |
| StopSequences | —（**不支持**） | Q-R1：忽略+warn |
| ResponseSchemaJson | `text.format={type:"json_schema",…strict}` | Q-R6：structured output 在此走 text.format 而非 chat 的 response_format |
| Tools | `tools[]{type:"function", name, description, parameters, strict}` | Q-R3：function 定义平铺（无 chat 版嵌套 function 包装）|
| ToolChoice | `"auto"/"none"/"required"/{"type":"function","name":…}` | 四形态直映 |
| ParallelToolCalls | `parallel_tool_calls` | tsUnset 省略 |
| ReasoningEffort | `reasoning:{effort}` | reMinimal 映射 "minimal"；reUnset 整字段省略 |

### 3.2 非流式响应映射

根对象 `object:"response"`；`status="completed"` 正常解码：

- `output[]` 逐项展开：`type:"message"` → content 内 `output_text` 拼
  assistant 文本；`type:"function_call"` → 工具调用槽（name/call_id/
  arguments）；`type:"reasoning"` → thinking part（summary 文本拼接，
  词表落点 pkThinking）。
- `usage`: `input_tokens/output_tokens` + `output_tokens_details.
  reasoning_tokens`（Q-R4 字段名差异集中在此层吸收）。
- `status="failed"` 或根级 `error` → 公共错误分类器归因（§0/§1.4 同款信封
   解析；`error.code/message` 直取）。

### 3.3 流式事件映射（SSE，`event:` 名为主键，Q-R2）

| event | 词表增量 |
|---|---|
| `response.created` | 首 envelope delta（response.id → MessageId；Q-A1 同精神的强制首信封） |
| `response.output_text.delta` | sdkTextDelta(`delta`) |
| `response.reasoning_summary_text.delta` | sdkThinkingDelta(`delta`) |
| `response.output_item.added`(function_call) | sdkToolCallStart(item_id→call_id, name) |
| `response.function_call_arguments.delta` | sdkToolCallDelta（按 item_id 分桶累积） |
| `response.output_item.done`(function_call) | arguments 兜底校验（分桶缺失时以完整串补齐） |
| `response.completed` | usage delta（response.usage）+ 终态收口 |
| `response.incomplete` | finish=sdkFinishLength 截断语义 |
| `response.failed` / `response.error` | sdkError（流中失败上浮，fold 收口） |

`ping`、`response.in_progress`、`response.content_part.added/done`、
`response.output_text.done`、`response.reasoning_summary_*` 其余变体：
零增量合法帧，静默吞（Extra 证据照录）。

### 3.4 OpenAI Responses 怪癖清单

| # | 怪癖 | 处置 |
|---|------|------|
| Q-R1 | 无 stop sequences 参数（chat completions 有） | 编码侧忽略+warn（ReasoningEffort·anthropic 待遇先例）；调用方显式设置即日志可见 |
| Q-R2 | SSE 以 `event:` 名为主键（同 anthropic，异于 chat completions data-only） | 解码按 event 分派；data JSON 只做载荷提取 |
| Q-R3 | function tools 与 function_call 输出全部平铺（无嵌套 function 包装、id 叫 call_id） | 编码/解码两侧集中映射；词表不变 |
| Q-R4 | usage 字段名与 reasoning 明细位置不同于 chat completions | FillUsage responses 变体一次吸收 |
| Q-R5 | 连接在 `response.completed/failed` 之前死亡（截断流） | **fail-closed**：无 created→completed/failed 完整轨迹 Finalize 即抛 aecProtocol（Q-A8 同精神） |
| Q-R6 | structured output 走 `text.format` 而非 `response_format` | W6 schema 词表直映；strict 语义一致 |
| Q-R7 | opencode 代理等兼容实现的事件子集可能有缺 | 以官方规范为准编码；实测差异记入本表不阻塞（E2E 门兜底核实） |

## 4. 明确不做（v1 边界）

OpenAI 侧：`logprobs`、audio/modality 参数、legacy `functions` 字段。
Anthropic 侧：`metadata.user_id`、citations、server-side tools（web_search 等）、
`container`/code-execution、structured output
tool-based 转译（合成工具+强制 tool_choice 的完整方案为后续候选；当前
ResponseSchemaJson 在 anthropic 保持 fail-fast aecConfig，见 §2.1）。

response_format/JSON mode 与 `tool_choice` 已随 W6（v1.1 第一批）落地：
openai 族 §1.1/§1.7，anthropic §2.1。`reasoning_effort` 已随 W7（v1.1 第二批）
入词表：openai 族 §1.1 编码、anthropic 忽略+warn。prompt caching 显式打点已随
W10（v1.1 第五批）入词表：anthropic 显式 `cache_control` §2.6，openai/grok/
responses 族自动缓存零差异。

以上任一项进入实施范围时：先在本文件立节，再动代码。
