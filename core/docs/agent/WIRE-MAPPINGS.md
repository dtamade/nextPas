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
| 时间语义 | 一切毫秒时长 Int64；ms→ns 换算前做溢出防护 |

## 1. OpenAI Chat Completions 兼容适配器

端点：`POST {BaseUrl|https://api.openai.com}/v1/chat/completions`
鉴权：`Authorization: Bearer {ApiKey}`；可选 `OpenAI-Organization`。

### 1.1 请求映射

| 词表 | wire |
|------|------|
| `Model` | `model`（必填） |
| `System` | `messages[0] = {role:"system", content}`（与历史 System 消息合并去重） |
| `Messages[mrUser].pkText` | `{role:"user", content:"..."}` |
| `Messages[mrAssistant].pkText` | `{role:"assistant", content:"..."}` |
| `Messages[mrAssistant].pkToolCall` | `{role:"assistant", content:null|文本, tool_calls:[{id,type:"function",function:{name,arguments}}]}`（arguments 为折叠后全文） |
| `Messages[mrTool].pkToolResult` | 每部分一条 `{role:"tool", tool_call_id, content}` |
| `MaxTokens` >0 | `max_tokens`；模型族要求 `max_completion_tokens` 时自动改名（quirk Q-O1）|
| `Temperature` ≥0 | `temperature`；unset 不上送 |
| `TopP` ≥0 | `top_p`；unset 不上送 |
| `Seed` ≠ CSeedUnset | `seed` |
| `StopSequences` 非空 | `stop` |
| `ParallelToolCalls` ≠ tsUnset | `parallel_tool_calls` |
| `Tools[]` | `tools:[{type:"function", function:{name, description, parameters}}]`（parameters 为 JSON Schema 对象） |
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

```json
{"error": {"message": "...", "type": "invalid_request_error", "code": "..."}}
```
状态→错误码走公共分类器；429 附带 `retry-after` 头按公共规则解析。

### 1.5 OpenAI 怪癖清单

| # | 怪癖 | 处置 |
|---|------|------|
| Q-O1 | 推理族模型拒绝 `max_tokens`，要求 `max_completion_tokens` | 按模型名前缀判定（`o1`/`o3`/`gpt-5` 等，常量表可扩展）；判定失败由上游 400 自然暴露并归因 |
| Q-O2 | `reasoning_content` 增量字段（兼容系厂商普遍支持） | 映射为 `sdkThinkingDelta`；缺省无此字段即无思考输出 |
| Q-O3 | usage 仅当 `stream_options.include_usage=true` 才随末 chunk 到达，且 `choices:[]` | 必发该选项；兼容端不支持则 usage 保持 CUsageUnknown（Known=False），绝不臆造 |
| Q-O4 | 部分兼容网关不发 `[DONE]` 直接断连 | 连接关闭=EOF；fold 正常收口 |
| Q-O5 | tool_calls 首片携带 id+name、后续片仅 index+args 片段 | Start 只在首片发一次；adapter 按 index 分桶累积（禁止下游自行维护桶——词表已抽象掉） |
| Q-O6 | 空 `choices` 数组的中间 chunk 存在 | 跳过，不算协议错误 |

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
| `pkImage` | `{type:"image", source:{type:"base64", media_type, data}}`（data URI 解析；mime 白名单 png/jpeg/gif/webp，违者 aecConfig） |
| `Messages[mrAssistant].pkText` | `{type:"text"}` 块 |
| `pkThinking` | `{type:"thinking", thinking, signature}`（signature 原样透传，见 Q-A3） |
| `pkToolCall` | `{type:"tool_use", id, name, input:<折叠后的 JSON 对象>}` |
| `Messages[mrTool].pkToolResult` | 归并为**一条** `{role:"user", content:[{type:"tool_result", tool_use_id, content, is_error}]}`（Q-A4 分组规则） |
| `Tools[]` | `tools:[{name, description, input_schema}]` |
| `Temperature` ≥0 | `temperature` |
| `StopSequences` | `stop_sequences` |
| `Thinking` 三态 / Budget | `thinking:{"type":"enabled","budget_tokens":N}`；tsFalse 显式 `{"type":"disabled"}`；tsUnset 不上送 |
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
| `message_start` | `message{id,model,usage{input_tokens,...}}` | 记录 id/model；InputTokens 暂存 |
| `content_block_start` | `index, content_block{type:text\|thinking\|tool_use{id,name}}` | text/thinking 开 part；tool_use → `sdkToolCallStart` |
| `content_block_delta` | `delta{type: text_delta{text}\| input_json_delta{partial_json}\| thinking_delta{thinking}\| signature_delta{signature}}` | 对应 `sdkTextDelta` / `sdkToolCallDelta` / `sdkThinkingDelta`；signature 并入 part.Signature |
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

## 3. 明确不做（v1 边界）

OpenAI 侧：`logprobs`、`response_format`/JSON mode、audio/modality 参数、
legacy `functions` 字段、`tool_choice` 细粒度枚举（v1 固定 auto）。
Anthropic 侧：`metadata.user_id`、citations、server-side tools（web_search 等）、
`container`/code-execution、prompt caching 显式 `cache_control` 打点（缓存命中
用量照常记录，但主动打点策略留给消费方经 ExtraJson 注入）。

以上任一项进入实施范围时：先在本文件立节，再动代码。
