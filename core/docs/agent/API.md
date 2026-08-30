# nextpas.core.agent 公开 API 契约

> 本文档是公开 API 的**权威契约**。实现与文档不一致时，以本文档为准修代码；
> 改 API 必须先改本文档。签名用 ObjFPC 语法书写，落地时遵循 design-conventions
> 风格（const 参数、L/A/F 前缀、2 空格缩进、`{$mode objfpc}{$H+}`）。

## 0. 通用约定

- **Sentinel 规则**：所有可选字段带 sentinel；未设置的字段**绝不上送 wire、
  绝不臆造默认值**。sentinel 常量一律 `C<X>Unset` 命名。
- **错误通道**：异常为默认通道；`TryXxx` 仅在消费方需要分支时提供；
  "无值"返回空记录/nil，不引入 Result<T,E>。
- **回调三形态**：对外回调一律提供 method pointer / anonymous / plain proc 三种
  重载，内部统一存 `reference to`，参数用命名过程类型。
- 所有 JSON 载荷字段类型为 `TJsonText = type string`（owned 全量 JSON 文本，
  无损携带；禁止用 borrow 视图跨作用域）。类型别名定义在 nextpas.core.agent.base：
  `TJsonText = type string;`

## 1. base 词表（nextpas.core.agent.base）

### 1.1 枚举

```pascal
TMessageRole = (mrSystem, mrUser, mrAssistant, mrTool);

TPartKind = (pkText, pkThinking, pkToolCall, pkToolResult, pkImage);

TFinishReason = (frNone, frStop, frLength, frToolCalls, frContentFilter);

TTriState = (tsUnset, tsFalse, tsTrue);   { 三态布尔：unset 即不上送 }

{ 工具选择模式（W6）：tcmUnset 不上送；tcmNamed 需配 ToolChoiceName。
  wire 映射：openai §1.1 / anthropic §2.1（required→any、none→省略 tools）}
TToolChoiceMode = (tcmUnset, tcmAuto, tcmNone, tcmRequired, tcmNamed);

{ 推理力度旋钮（W7/W7b）：reUnset 不上送。openai → reasoning_effort；
  anthropic 无对应参数 → 忽略 + warn（Q-A5 同规则），推理力度走本侧
  Thinking/Budget。部分高阶模型支持 max/xhigh 档（WIRE-MAPPINGS §1.1b）：
  reXHigh→"xhigh"、reMax→"max" 为最大档（reMax 封顶，reXHigh 次之）}
TReasoningEffort = (reUnset, reMinimal, reLow, reMedium, reHigh, reXHigh, reMax);

{ 提示缓存断点策略（W10）：ccmUnset 不上送。ccmAuto=anthropic 显式
  cache_control 自动打点（WIRE-MAPPINGS §2.6：tools 尾/system/末条消息
  尾块三处，≤4 厂商预算）；openai/grok/responses 族自动缓存零 wire 差异 }
TCacheControlMode = (ccmUnset, ccmAuto);

TStreamDeltaKind = (
  sdkTextDelta,        { TextDelta 追加正文 }
  sdkThinkingDelta,    { TextDelta 追加思考内容 }
  sdkToolCallStart,    { ToolIndex/ToolCallId/ToolName 就位 }
  sdkToolCallDelta,    { ArgumentsDelta 追加参数 JSON 片段 }
  sdkToolCallEnd,      { 该槽位参数流结束 }
  sdkFinish,           { FinishReason 就位，正文/工具流结束 }
  sdkUsage,            { Usage 就位（可与 sdkFinish 异序到达，fold 抹平）}
  sdkError,            { Error 就位（流中途错误上报；fold 跳过）}
  sdkEnvelope          { MessageId/Model 就位（流首信封事件；fold 记入消息）}
);
```

### 1.2 Sentinel 常量

```pascal
const
  CTemperatureUnset   = -2.0;          { 合法域 [0.0, 2.0]，负值即 unset }
  CTopPUnset          = -2.0;
  CMaxTokensUnset     = 0;             { >0 有效 }
  CSeedUnset          = Low(Int64);
  CTimeoutDefault     = 0;             { 0=用 transport 默认；<0=无限 }
  CUsageUnknown       = -1;            { TTokenUsage 各字段未知值 }
  CRetryAfterUnknown  = -1;            { RetryAfterMs 未提供/不适用 }
```

### 1.3 记录

```pascal
TTokenUsage = record
  InputTokens: Int64;              { CUsageUnknown = 未知 }
  OutputTokens: Int64;
  CacheReadInputTokens: Int64;
  CacheWriteInputTokens: Int64;
  ReasoningTokens: Int64;
  function Known: Boolean;         { 任一字段 ≠ CUsageUnknown }
  function TotalKnownTokens: Int64;
end;

TPart = record
  Kind: TPartKind;
  Text: string;                    { pkText/pkThinking 内容 }
  ToolCallId: string;              { pkToolCall / pkToolResult 配对键 }
  ToolName: string;                { pkToolCall }
  ArgumentsJson: TJsonText;        { pkToolCall 参数全文（start+delta 折叠结果）}
  ResultJson: TJsonText;           { pkToolResult 回喂内容 }
  IsError: Boolean;                { pkToolResult 失败标记 }
  ImageUrl: string;                { pkImage：URL 或 data URI }
  Signature: string;               { pkThinking 厂商签名（anthropic），不透明透传 }
  ExtraJson: TJsonText;            { 未知字段无损捕获，编码时回注原位 }
end;
TPartArray = array of TPart;

TMessage = record
  Id: string;                      { 厂商消息 id；厂商未给则空串（SELECTION C14，不本地伪造）}
  Role: TMessageRole;
  Parts: TPartArray;
  Model: string;                   { assistant：实际服务模型 id }
  FinishReason: TFinishReason;
  Usage: TTokenUsage;
  ExtraJson: TJsonText;            { 消息级未知字段无损捕获 }
  function IsEmpty: Boolean;       { 区分"空记录=无产出"与合法消息（取消路径语义）；
                                     usage 以 TotalKnownTokens=0 判定，
                                     覆盖全 CUsageUnknown 与全零两种形态 }
end;
TMessageArray = array of TMessage;

{ ---- 流增量 ---- }

TAgentErrorInfo = record          { sdkError 携带的中途错误信息 }
  Code: TAgentErrorCode;          { 枚举物理落位在 base（词表同源），见 §2 }
  Message: string;
  Retryable: Boolean;
  RetryAfterMs: Int64;            { CRetryAfterUnknown=未提供 }
end;

TStreamDelta = record
  Kind: TStreamDeltaKind;
  TextDelta: string;              { sdkTextDelta / sdkThinkingDelta 载荷 }
  ToolIndex: Integer;             { 并行工具槽位；非工具事件为 -1 }
  ToolCallId: string;             { sdkToolCallStart 携带厂商调用 id }
  ToolName: string;               { sdkToolCallStart 携带 }
  ArgumentsDelta: string;         { sdkToolCallDelta 的参数 JSON 片段 }
  FinishReason: TFinishReason;    { sdkFinish 携带 }
  Usage: TTokenUsage;             { sdkUsage 携带 }
  Error: TAgentErrorInfo;         { sdkError 携带 }
  MessageId: string;              { sdkEnvelope 携带厂商消息 id }
  Model: string;                  { sdkEnvelope 携带实际服务模型 id }
  Signature: string;              { sdkThinkingDelta 携带 thinking 签名透传 }
  UnmappedJson: TJsonText;        { 旁路：未映射枚举/未知块级键的 JSON object
                                    文本；fold 收口时并入消息 ExtraJson
                                    （WIRE-MAPPINGS §0 未映射枚举值规则）}
end;
TStreamDeltaArray = array of TStreamDelta;

{ 合并多个 ExtraJson object 文本；无效条目跳过，重名后者胜 }
function MergeExtraJson(const ATexts: array of TJsonText): TJsonText;

function MessageText(const AMsg: TMessage): string;
{ 拼 pkText：顺序直连无分隔符。不变量：MessageText(fold 结果) == 正文
  sdkTextDelta 的依序连接——流式已打印内容与非流式取文本完全一致 }

{ ---- 补全请求 ---- }

TCompletionRequest = record
  Model: string;                   { 必填：无默认值，调用方显式决定 }
  System: string;                  { 顶层 system 便利字段 }
  Messages: TMessageArray;         { 对话历史（不含本轮待发 user 时自行前置）}
  Tools: TToolSpecArray;           { 随请求携带（WithTools builder），接口单参数化 }
  ResponseSchemaJson: TJsonText;   { 非空即请求结构化输出：openai 族 json_schema
                                     strict 编码（WIRE-MAPPINGS §1.7），须为合法
                                     JSON object 否则 aecConfig；anthropic 无厂商
                                     参数 → 本地 aecConfig fail-fast（§2.1）}
  MaxTokens: Int64;                { CMaxTokensUnset；anthropic 强制必填→WIRE-MAPPINGS §2.1 }
  Temperature: Double;             { CTemperatureUnset }
  TopP: Double;                    { CTopPUnset }
  Seed: Int64;                     { CSeedUnset }
  StopSequences: TStringArray;
  ParallelToolCalls: TTriState;    { tsUnset 不上送 }
  ToolChoice: TToolChoiceMode;     { tcmUnset 不上送；映射见 WIRE-MAPPINGS §1.1/§2.1 }
  ToolChoiceName: string;          { 仅 tcmNamed 有效；缺名 aecConfig }
  ReasoningEffort: TReasoningEffort; { reUnset 不上送；openai reasoning_effort（W7）}
  CacheControl: TCacheControlMode; { ccmUnset 不上送；anthropic §2.6 自动打点（W10）}
  Thinking: TTriState;             { 扩展思考开关；tsUnset 不上送 }
  ThinkingBudgetTokens: Int64;     { CMaxTokensUnset；Thinking=tsTrue 时语义生效 }
  IdempotencyKey: string;          { T1.5：空=不启用，非空透传 Idempotency-Key 头 }
  ExtraJson: TJsonText;            { 逃生舱：合并进请求根对象（厂商私有参数）；
                                     非空须为合法 JSON object 否则编码期 aecConfig }

  class function New(const AModel: string): TCompletionRequest; static;
end;

{ builder 便利：TCompletionRequest 的 advancedrecords 方法，返回修改后的副本
  （record 值语义，支持链式书写，见 README 用例）：
    function WithSystem(const AText: string): TCompletionRequest;
    function WithUserText(const AText: string): TCompletionRequest;
    function WithMaxTokens(AN: Int64): TCompletionRequest;
    function WithTemperature(AValue: Double): TCompletionRequest;
    function WithTopP(AValue: Double): TCompletionRequest;
    function WithSeed(AValue: Int64): TCompletionRequest;
    function WithStop(const ASeq: TStringArray): TCompletionRequest;
    function WithTools(const ASpecs: TToolSpecArray): TCompletionRequest;
    function WithResponseSchema(const ASchemaJson: string): TCompletionRequest;
    function WithToolChoice(AMode: TToolChoiceMode;
      const AName: string): TCompletionRequest;
    function WithReasoningEffort(AEffort: TReasoningEffort): TCompletionRequest;
    function WithCacheControl(AMode: TCacheControlMode): TCompletionRequest;
    function WithParallelToolCalls(AVal: TTriState): TCompletionRequest;
    function WithThinking(AThinking: TTriState; ABudget: Int64 = CMaxTokensUnset): TCompletionRequest;
    function WithModel(const AModel: string): TCompletionRequest;
      { 克隆/回退场景改模型不断链 }
    function WithMessages(const AMsgs: TMessageArray): TCompletionRequest;
      { 批量覆盖 Messages（Copy 语义）；与 WithUserText/WithMessage 附加语义互补 }
    function WithMessage(const AMsg: TMessage): TCompletionRequest;
    function WithExtraJson(const AJson: TJsonText): TCompletionRequest;
      { 逃生舱：多次调用按 MergeExtraJson 后者胜合并，便于 gateway 侧 service_tier/user 等厂商私有键的渐进注入；空串跳过，非 object 编码期 aecConfig }
    { WithTools(array of IAgentTool) 第二形态落位在 tools 层自由函数
      （base 不依赖 intf 的分层约束，ARCHITECTURE §1），提取各工具的 Spec——
      builder 链经其不断裂；随 W3 tools 落地 }
  需 {$modeswitch advancedrecords}（design-conventions §11 允许追加）。}
```

### 1.4 工具词表

```pascal
{ v1 仅保留有明确消费语义的标志。tcParallel = W13 分组调度声明：
  相邻 tcParallel 调用段整段并行，非 tcParallel 调用独占执行——工具的
  并发声明永不被违反（LIFECYCLE §5）。Idempotent/ReadOnly/NeedsConfirm
  经评估不设词表位：NeedsConfirm 的确认门由 PreHook 同步回调表达
  （提交前运行、可阻塞等外部批准）；前两者在模块内无消费者（loop 重试
  哲学 = 模型驱动，不做工具级自动重试）——防死词表，触发条件见 ROADMAP
  Inbox}
TToolCapability = (tcParallel);
TToolCapabilities = set of TToolCapability;

TToolSpec = record
  Name: string;                    { ^[a-zA-Z0-9_-]{1,64}$，AddTool 时校验 }
  Description: string;
  ParametersJson: TJsonText;       { JSON Schema 文本；AddTool 时做务实级校验（§1.5）}
  Capabilities: TToolCapabilities;
  TimeoutMs: Int64;                { CTimeoutDefault（0=缺省即不限，全局 timeout 方言一致）}
end;
TToolSpecArray = array of TToolSpec;

TToolResult = record
  ContentJson: TJsonText;          { 回喂模型的 JSON 文本 }
  IsError: Boolean;                { true → 以 error 形态回喂，循环继续 }
  Truncated: Boolean;
end;
```

### 1.5 务实级工具参数校验（ValidateToolArguments 规范）

v1 校验的构造全集（超出即属完整 JSON-Schema 校验器范畴，明确不做）：

1. 预检：`Length(ArgumentsJson) ≤ 256 KiB`（SECURITY §3），超限直接 error result。
2. 根必须是合法 JSON **object**（解析失败/非 object → error result）。
3. `ParametersJson` 本身非法或根非 object → `AddTool` 时即抛 `aecConfig`
   （注册期快速失败；运行期不再重复校验 spec 本身）。
4. `required[]` 中的键必须出现在参数顶层。
5. 顶层 `properties` 声明了 string/number/boolean 类型的键做类型核对
   （number 接受 int/float）；array/object/null 类型不深查。
6. 嵌套深度 ≤ 8 层（防深嵌套 DoS）。

校验失败一律**合成 error result 回喂模型**（循环继续），不是异常——
参数错误是模型的错误，不是调用方的。

## 2. 错误分类（nextpas.core.agent.errors）

```pascal
TAgentErrorCode = (
  aecNone,
  aecInvalidRequest,     { 上游 400 类语义错误；不可重试，RawBody 保真 }
  aecAuthentication,     { 401/403 }
  aecNotFound,           { 404：模型/端点不存在 }
  aecRateLimited,        { 429；可重试，RetryAfterMs 生效 }
  aecTransport,          { 连接/读/写失败、连接重置；可重试 }
  aecTimeout,            { 连接/整体超时；可重试 }
  aecServer,             { 上游 5xx；可重试 }
  aecContextOverflow,    { 提示超窗（多措辞识别）；不可自动重试 }
  aecProtocol,           { 厂商响应/SSE 帧违反协议；不可重试 }
  aecCancelled,          { 经令牌取消 }
  aecConfig,             { 本地配置缺失/非法（缺 key、缺 MaxTokens 等）}
  aecToolFailed,         { loop 层：工具执行抛异常 }
  aecBudgetExhausted     { loop 层：预算达限（正常收尾态，见 ARCHITECTURE §5）}
);
{ 落位说明：TAgentErrorCode 是纯词表，物理定义在 nextpas.core.agent.base；
  本单元只拥有异常类与分类函数，依赖 base。 }

EAgentError = class(Exception)
public
  ErrorCode: TAgentErrorCode;   { 缺省 aecNone }
  Retryable: Boolean;           { 由错误码推导，构造时算好 }
  RetryAfterMs: Int64;          { CRetryAfterUnknown=未提供；仅 RateLimited 有意义 }
  Provider: string;             { 'openai' | 'anthropic' | ''=本地 }
  RequestId: string;            { 上游 x-request-id 回显（有则填）}
  RawBodySnippet: string;       { 上游错误体摘要 ≤8KB；本地错误为空 }
end;

EAgentCancelled = class(EAgentError);   { ErrorCode 固定 aecCancelled }

{ 消费方时序/用法违规（如 Active 期 GetMessage）：不占厂商协议错误码位，
  让 catch 边界能区分"我的 bug"与"上游的错" }
EAgentMisuse = class(EAgentError);      { ErrorCode 固定 aecConfig }

TAgentErrorCodes = set of TAgentErrorCode;

{ HTTP status → 错误码分类器（transport 与适配器共用，单一事实源）}
function ErrorCodeForStatus(AStatus: Integer): TAgentErrorCode;
function IsRetryable(ACode: TAgentErrorCode): Boolean;
```

规则：

- provider 层**从不**因任何错误自动睡眠或自动重试；策略全部在 `WithRetry`
  装饰器 / loop 层（token888 反例已吸收）。
- `RetryAfterMs` 解析 `retry-after-ms` 优先，其次秒级 `retry-after`；
  HTTP-date 形式不解析（返回 unknown，不臆造）。

## 3. 接缝接口（nextpas.core.agent.intf）

```pascal
IAgentClock = interface
  function NowMs: Int64;
  { 睡眠可被令牌打断；返回 True=自然睡满，False=被取消 }
  function SleepMs(AMs: Int64; const AToken: IAsyncCancellationToken): Boolean;
end;

{ ---- wire 层（自定义 transport / 测试装饰器的落点；不进门面）----
  落位说明：TWire* 记录与 WireHeaderValue 是纯词表，物理定义在
  nextpas.core.agent.base（sse/transport/intf 共用，ARCHITECTURE §2）；
  本节接口在 nextpas.core.agent.intf。}

TWireHeader = record
  Name: string;
  Value: string;
end;
TWireHeaderArray = array of TWireHeader;

TWireRequest = record
  Url: string;                      { 本模块仅 POST（chat/messages 端点），方法由 transport 固定 }
  BodyJson: TJsonText;              { 已序列化请求体 }
  Headers: TWireHeaderArray;        { 仅鉴权与语义头；Host/Content-Length 等
                                      物理头由 transport/http client 补全 }
  ConnectTimeoutMs: Int64;          { CTimeoutDefault }
  TotalTimeoutMs: Int64;            { CTimeoutDefault }
end;

TWireResponse = record
  StatusCode: Integer;
  Headers: TWireHeaderArray;
  BodyText: string;                 { 非流式路径全量响应体 }
  RequestId: string;
end;

{ wire 头查找（大小写不敏感，首个命中返回；未命中空串）。
  RequestId 探测 / retry-after 解析 / 消费方自定义头检查共用 }
function WireHeaderValue(const AHeaders: TWireHeaderArray;
  const AName: string): string;

{ SSE 帧（增量解析产物）}
TWireSSEEvent = record
  Event: string;                    { event: 字段；无则空串 }
  Data: string;                     { 多行 data: 拼接（\n 连接）}
end;

IAgentWireStream = interface
  { 真增量：socket 到一帧返一帧；False=EOF 或已取消（用 GetCancelled 区分）}
  function NextEvent(out AEvent: TWireSSEEvent): Boolean;
  procedure Cancel;                 { 幂等，任意线程 }
  function GetCancelled: Boolean;
end;

IAgentTransport = interface
  { 失败一律抛 EAgentError（aecTransport/aecTimeout/上游状态经公共分类器归约的码）；
    无布尔返回值——成功即 out 参数有效，失败即异常 }
  procedure RoundTrip(const AReq: TWireRequest; out AResp: TWireResponse);
  function OpenStream(const AReq: TWireRequest): IAgentWireStream;
end;

{ ---- 词表层（loop/session/消费方只见这些）---- }

IAgentCompletion = interface
  function NextDelta(out ADelta: TStreamDelta): Boolean;  { False=EOF }
  procedure Cancel;                    { 幂等，任意线程；使 NextDelta 返回 False }
  function GetCancelled: Boolean;      { EOF 后读取区分取消 }
  function GetMessage: TMessage;       { EOF 后有效：内部 fold 的最终消息 }
  function GetUsage: TTokenUsage;      { EOF 后有效；未知字段=CUsageUnknown }
end;

IAgentProvider = interface
  function GetName: string;                       { 'openai'|'anthropic'|'fake' }
  { 工具经 AReq.Tools 随请求携带（builder 链不断裂）；可选令牌重载用于
    全程取消（Stream 的令牌触发时自动 Cancel 返回的 completion）}
  function Complete(const AReq: TCompletionRequest): TMessage; overload;
  function Complete(const AReq: TCompletionRequest;
    const AToken: IAsyncCancellationToken): TMessage; overload;
  function Stream(const AReq: TCompletionRequest): IAgentCompletion; overload;
  function Stream(const AReq: TCompletionRequest;
    const AToken: IAsyncCancellationToken): IAgentCompletion; overload;
end;

{ ---- 工具 ---- }

IToolContext = interface
  function Token: IAsyncCancellationToken;         { 取消传播进工具实现 }
  function CallIndex: Integer;                    { 本轮批内序号 }
end;

IAgentTool = interface
  function Spec: TToolSpec;
  { 实现方约定：不抛异常，失败走 TToolResult.IsError=True（异常由 loop 兜底
    转 aecToolFailed 合成 error result——两道防线）}
  function Execute(const AArgumentsJson: TJsonText;
    const ACtx: IToolContext): TToolResult;
end;

{ ---- 会话（W4 起；接口先行冻结讨论）---- }
{ ThreadId 所有权：由消费方生成并持有（建议 core.id 的 ulid/v7）；
  loop 不感知会话身份，store 的 Append/Load 顺序即 transcript 数组序 }

IAgentTranscriptStore = interface
  procedure Append(const AThreadId: string; const AMsg: TMessage);
  function Load(const AThreadId: string): TMessageArray;
  procedure Delete(const AThreadId: string);
end;
```

构造入口（门面 re-export）：

```pascal
function NewOpenAIProvider(const AOpts: TOpenAIOptions): IAgentProvider;
function NewAnthropicProvider(const AOpts: TAnthropicOptions): IAgentProvider;
function NewFakeProvider(const AScriptJson: TJsonText): IAgentProvider;
{ W8 可靠性装饰器（语义权威=本文件 §装饰器组合）}
function NewFallbackProvider(const AChain: array of IAgentProvider;
  const APolicy: TFallbackPolicy): IAgentProvider;
function NewThrottledProvider(const AInner: IAgentProvider;
  const AGate: IAgentRateGate; const AClock: IAgentClock;
  const APolicy: TThrottlePolicy): IAgentProvider;

{ W9 对冲装饰器 + OpenAI Responses 协议支柱 }
function NewHedgedProvider(const AInner: IAgentProvider;
  const AClock: IAgentClock; const APolicy: THedgePolicy): IAgentProvider;
function NewOpenAIResponsesProvider(
  const AOpts: TOpenAIOptions): IAgentProvider;
function NewOpenAIResponsesProviderFromEnv: IAgentProvider;
function NewTokenBucketGate(ARatePerSecond, ABurst: Double): IAgentRateGate;
function WithRetry(const AInner: IAgentProvider; const APolicy: TRetryPolicy;
  const AClock: IAgentClock): IAgentProvider;

{ Grok（xAI）家族：wire 与 OpenAI Chat Completions 同族（WIRE-MAPPINGS
  §1.6），编解码器复用；差异仅默认端点 api.x.ai、归因名 'grok'、env 前缀 }
function BuildGrokUrl(const ABaseUrl: string): string;
function NewGrokProvider(const AOpts: TGrokOptions): IAgentProvider;

{ 环境装配（契约见 CONSUMERS.md §3）：必填 env 缺失返回 nil，绝不静默回退。
  NEXTPAS_AGENT_OPENAI_API_KEY / _MODEL / _BASE_URL
  NEXTPAS_AGENT_GROK_API_KEY / _MODEL / _BASE_URL
  NEXTPAS_AGENT_ANTHROPIC_API_KEY / _MODEL / _BASE_URL }
function NewOpenAIProviderFromEnv: IAgentProvider;
function NewGrokProviderFromEnv: IAgentProvider;
function NewAnthropicProviderFromEnv: IAgentProvider;

{ 时钟构造（nextpas.core.agent.clock；选型见 SELECTION C8）}
function NewSystemClock: IAgentClock;   { 真实时钟；SleepMs 底层 WaitForCancel }

type
  { 测试时钟：SleepMs 记录请睡时长并立即返回；由测试驱动 Advance 推进虚拟时间，
    配合 WithRetry 实现零睡眠退避断言（TESTING §3）}
  TFakeClock = class(TInterfacedObject, IAgentClock)
  public
    procedure Advance(AMs: Int64);              { 推进虚拟时钟并放行挂起的 SleepMs }
    function VirtualNowMs: Int64;
    function LastSleepRequestMs: Int64;         { 最近一次被请求的睡眠时长 }
  end;

{ 会话存储构造（nextpas.core.agent.session；W5 立项，设计权威 SESSION.md）}
function NewJsonlTranscriptStore(const ARootDir: string;
  ASyncEachAppend: Boolean = True): IAgentTranscriptStore;

type
  { JSONL 落地 store：一线程一文件 <RootDir>/<ThreadId>.jsonl；torn-tail
    崩溃恢复、SyncEachAppend fsync 节奏选项（默认每追加落盘）。
    Fork 为实例方法——接口 Append/Load/Delete 三方法面保持冻结不变。
    ETranscriptCorrupt（aecProtocol 固定码，消息含行号）为损坏 fail-closed
    异常；ThreadId 非法抛 EAgentMisuse }
  TJsonlTranscriptStore = class(TInterfacedObject, IAgentTranscriptStore)
  public
    procedure Fork(const ASrcThreadId, ADstThreadId: string);
    property RootDir: string read FRootDir;
    property SyncEachAppend: Boolean read FSyncEachAppend;
  end;
```

无全局注册表、无可变单例（决策 D4）：实例由消费方持有，库形态多 agent 宿主安全。

### 3.1 Provider 选项

```pascal
TProviderOptions = record          { 公共段，两厂商选项 record 内嵌 }
  ApiKey: string;                  { 空 → Complete 时抛 aecConfig }
  BaseUrl: string;                 { 空 → 厂商官方默认（常量表）}
  Model: string;                   { 回退默认；生效序 request.Model > 本值，皆空 → aecConfig }
  ConnectTimeoutMs: Int64;         { 默认 10_000 }
  TotalTimeoutMs: Int64;           { 默认 300_000（LLM 长尾合理值）}
  ReadIdleTimeoutMs: Int64;        { CTimeoutDefault=0 禁用；流式块间空闲超时
                                     （W7，WIRE-MAPPINGS §0）：超时合成 aecTimeout
                                     且不污染取消标志。推荐 60_000 起——o1 系
                                     reasoning 沉默期需按模型族放宽 }
  Transport: IAgentTransport;      { 注入点：测试/装饰器；nil → 生产 http transport }
  Logger: ILogger;                 { log.intf 接缝（SELECTION C15）；nil → NullLogger 零开销 }
  ExtraHeaders: TWireHeaderArray;
end;

TOpenAIOptions = record
  Common: TProviderOptions;
  Organization: string;            { 可选 header }
  { New 填入全部默认值（BaseUrl/超时/版本常量）；调用方按需覆盖字段 }
  class function New(const AModel: string): TOpenAIOptions; static;
end;

TGrokOptions = record
  Common: TProviderOptions;
  class function New(const AModel: string): TGrokOptions; static;
end;

TAnthropicOptions = record
  Common: TProviderOptions;
  AnthropicVersion: string;        { 默认取常量 CANTHROPIC_VERSION_DEFAULT }
  class function New(const AModel: string): TAnthropicOptions; static;
end;
```

### 3.2 请求级追踪（nextpas.core.agent.transport.trace，W11）

```pascal
TTraceRequestInfo = record
  Provider: string;                { 构造注入的适配器名（'anthropic' 等）}
  Url: string;
  Stream: Boolean;
  BodyBytes: Int64;                { 上送载荷体积 }
end;

TTraceResponseInfo = record
  Provider: string;
  Url: string;
  Stream: Boolean;
  Status: Integer;                 { -1 = 不可得（流式 wire 层不暴露/异常路径）}
  Failed: Boolean;                 { True = transport 异常路径（配对保证）}
  DurationMs: Int64;               { RoundTrip 全程 / OpenStream 建流耗时 }
  ResponseBytes: Int64;            { 非流式响应体；流式 -1（事件级归 fold/loop 层）}
  RequestId: string;               { 响应头透传；异常路径空串 }
end;

IAgentTraceSink = interface
  procedure OnRequest(const AInfo: TTraceRequestInfo);
  procedure OnResponse(const AInfo: TTraceResponseInfo);
end;

function NewTracedTransport(const AName: string;
  const ASink: IAgentTraceSink;
  const AInner: IAgentTransport;
  const AClock: IAgentClock = nil): IAgentTransport;
```

语义：

- 包装任意 `IAgentTransport`，一处接线三适配器全覆盖；与 WithRetry 叠装
  （traced 在内层）时每次尝试各产一对事件——重试可见性无需专用 onRetry 钩子
- OnRequest 在派发前、OnResponse 在落定后；transport 异常路径先发
  `Failed=True` 配对事件再原样上抛——不改写失败语义
- **sink 契约：回调内不得抛出**。失败路径的 sink 异常会顶替传输错误上抛；
  成功路径 sink 异常直接冒泡可见
- 字节口径为 UTF-8 精确计数；时钟经 IAgentClock 注入，测试零睡眠；
  流式 `Status=-1`/`ResponseBytes=-1`：SSE 事件级观测归 fold/loop 层

### 3.3 能力接口 IAgentTokenCounter（nextpas.core.agent.provider.anthropic，W12）

```pascal
IAgentTokenCounter = interface
  ['{A1B2C3D4-E5F6-7890-ABCD-111111000012}']
  function CountTokens(const AReq: TCompletionRequest): Int64;
end;
```

- **能力探测式接口**：仅实现于 anthropic provider（厂商 count_tokens 端点，
  映射权威=WIRE-MAPPINGS §2.7）；openai/grok/responses 族无厂商端点，
  不实现。
- 消费方用 `Supports(Prov, IAgentTokenCounter, LCounter)` 探测；未支持即走
  自有估算或降级路径——本模块不做本地近似估算冒充厂商口径（诚实边界）。
- 语义：同步阻塞调用，复用 Complete 同一套 transport/鉴权/超时配置；
  错误分类一致——本地装配错 aecConfig、上游错误按 §2.4 分类透传；
  响应缺 `input_tokens` 即 aecProtocol。

纯编解码器同批公开（D13）：`EncodeAnthropicCountTokensRequest(AReq)` 与
`BuildAnthropicCountTokensUrl(ABaseUrl)`，见 §8 Anthropic 段。

### 3.4 用量汇 IAgentUsageSink（nextpas.core.agent.intf，T1.4）

```pascal
IAgentUsageSink = interface
  ['{C3D4E5F6-A7B8-90AB-CDEF-555555000015}']
  procedure RecordUsage(const AProvider: string; const AReq: TCompletionRequest;
    const AUsage: TTokenUsage; ACostUsd6: Int64);
end;
```

- **nil 退化/线程安全不 raise**（tk888 `IUsageSink` 同契约，contracts:609）：loop 侧 `Assigned` 守卫 + `try..except` 吞掉；实现方须线程安全且不抛异常（数据面热路径直调）。
- **cost 口径**：loop 每轮 `AccumulateUsage` 后以 `pricing.EstimateCost` 估算（未知 token 按 `AgentEstimateTokens(MessageText) ~4字符/token` 粗估，F-M16 同口径；已知按实际 usage），`ACostUsd6` 为 μUSD 整数。

### 3.5 幂等键（nextpas.core.agent.base，T1.5）

```pascal
TCompletionRequest = record
  IdempotencyKey: string;  // 空=不启用，非空透传 wire 头 Idempotency-Key
  function WithIdempotencyKey(const AKey: string): TCompletionRequest;
end;
```

- 非空时 provider `BuildWireRequest` 透传 `Idempotency-Key: <key>`（`X-Request-Id` 语义，contracts:554）；空值不上送。
- 透传经 `AgentWireApplyIdempotency` 单一真源，三适配器（openai/anthropic/responses）共用；`WithRetry`/`NewFallbackProvider` 按值转发不改语义（重试/降级可见性由外层 trace 自然产生）。

## 4. 协议域纯函数（nextpas.core.agent.fold）

```pascal
TAssistantBuild = class     { 增量累积器；Create 后连续 FoldDelta，Finish 收口 }
  procedure FoldDelta(const ADelta: TStreamDelta);
  function Finish: TMessage;          { 合成终帧：usage/finish 异序抹平 }
  function PartialText: string;       { 中途观测用 }
end;

{ 一次性折叠：deltas 数组 → 消息。唯一权威实现：
  loop、IAgentCompletion.GetMessage、测试三方共用，禁止任何地方重写折叠逻辑。
  usage 随 AMsg.Usage 携带（单一来源，不另设返回值）}
procedure FoldDeltas(const ADeltas: array of TStreamDelta; out AMsg: TMessage);
```

折叠规则（协议域铁律，违例抛 `EAgentError[aecProtocol]`）：

- `sdkToolCallStart` 开槽（ToolIndex 分桶）；`sdkToolCallDelta` 按 index 追加
  ArgumentsDelta（IStringBuilder 累积防 O(n²)）；`sdkToolCallEnd` 封槽。
  **`sdkFinish` 隐式封全部未闭槽**——End 是建议性事件，OpenAI 协议天然不产
  它（WIRE-MAPPINGS Q-O5），缺 End 不是违例；未 Start 先 Delta 才是。
- 连续 `sdkTextDelta`/`sdkThinkingDelta` 追加进同一 part，直到 part 类别切换
  才开新 part（正文与思考交错时各自成段）；thinking part 保留
  Signature 字段透传。
- `sdkError` 不进入消息：fold 跳过它；错误缓存是 IAgentCompletion 实现的职责
  （ERRORS §6），fold 保持纯词表变换。
- `sdkUsage`/`sdkFinish` 到达顺序任意，`Finish` 统一合成（FinalizeStream 语义）。
- 空输入 → 空 mrAssistant 消息、frNone、Usage 全未知——合法结果不抛错。
- 未映射的厂商枚举值处理见 WIRE-MAPPINGS §0 公共规则（零值+Extra 保留键+warn）。
- fold 只认词表，不知道任何厂商名——厂商差异必须在 adapter 内归约为词表。

## 5. 重试策略（nextpas.core.agent.retry）

```pascal
TRetryAttemptHook = reference to procedure(const AAttempt: Integer;
  const ADelayMs: Int64; const ALastError: EAgentError);

TRetryPolicy = record
  MaxAttempts: Integer;            { ≥1；1=不重试 }
  InitialDelayMs: Int64;           { 默认 1000 }
  MaxDelayMs: Int64;               { 默认 30_000 }
  Multiplier: Double;              { 默认 2.0 }
  Jitter: Double;                  { [0..1) 比例抖动，默认 0.1 }
  RetryOn: TAgentErrorCodes;       { set of TAgentErrorCode；默认
                                     [aecRateLimited, aecTransport, aecTimeout, aecServer] }
  RespectRetryAfter: Boolean;      { 默认 True：服务器指示优先于退避曲线 }
  MaxTotalRetryMs: Int64;          { 总退避上限，默认 120_000 }
  OnAttempt: TRetryAttemptHook;    { 每次重试前上报（nil=静默）；副本方法 WithOnAttempt 注入 }
  class function Default: TRetryPolicy; static;
end;

{ 装饰器：包装任意 IAgentProvider（含 fake）；睡在 AClock 上（测试零睡眠）；
  每次尝试经 TRetryPolicy.OnAttempt 上报 }
function WithRetry(const AInner: IAgentProvider; const APolicy: TRetryPolicy;
  const AClock: IAgentClock): IAgentProvider; overload;
function WithRetry(const AInner: IAgentProvider; const APolicy: TRetryPolicy;
  const AClock: IAgentClock; const AToken: IAsyncCancellationToken): IAgentProvider; overload;
```

语义（可断言的精确定义）：

- 仅对 `RetryOn` ∩ `IsRetryable` 的错误重试。
- 第 n 次重试前延迟：`base_n = min(InitialDelayMs × Multiplier^(n-1), MaxDelayMs)`；
  实际延迟 = `base_n × f`，`f ∈ [1-Jitter, 1+Jitter]` 均匀分布。
- `RetryAfterMs ≠ CRetryAfterUnknown` 且 `RespectRetryAfter` 时直接采用服务器值
  （不经曲线）。
- 累计退避超过 `MaxTotalRetryMs` → 停止重试，抛最后一次原始错误。
- `OnAttempt(AAttempt=即将开始的尝试序号从 1 起, ADelayMs=本次尝试前的睡眠时长,
  首次尝试为 0, ALastError=上一次失败)`。ALastError 实例仅在钩子调用期内
  有效，不得留存（实现按失败快照重建等价异常）。
- 取消优先于一切：令牌在睡眠/尝试边界触发 → 抛 `EAgentCancelled`
  （不吞为成功、不还原成原始错误）。
- 流式作用域：装饰器只重试到**拿到流且收到首个 delta** 为止；流中途失败原样
  上抛（重放意味着向消费方重复投递 delta——禁止）。

{ ---- W8 可靠性装饰器（与 WithRetry 同层纯组合；语义可断言）---- }

TFallbackSwitchHook = reference to procedure(AIndex: Integer;
  const AProviderName: string; AErrCode: TAgentErrorCode;
  const AErrMsg: string);
  { 切换发生时上报：AIndex=即将尝试的链内序号（0 起）；实例仅调用期有效 }

TFallbackPolicy = record
  FailOn: TAgentErrorCodes;        { 触发降级的错误码集；默认同 retry 四码 }
  OnSwitch: TFallbackSwitchHook;   { nil=静默 }
  class function Default: TFallbackPolicy; static;
end;

IAgentRateGate = interface
  { TryAcquire：True=放行；False=拒绝并给出建议等待毫秒（0=未指明）。
    细接口——core.lockfree.ratelimit 经 NewTokenBucketGate 接入，
    测试用 fake gate 自由编排拒绝序列 }
  function TryAcquire(out ARetryAfterMs: Int64): Boolean;
end;

TThrottlePolicy = record
  MaxWaitMs: Int64;                { 单次调用累计等待上限；超限→本地 aecRateLimited
                                     （RetryAfterMs=gate 最近建议值），默认 30_000 }
  MaxAcquires: Integer;            { 等待-重取循环上限，防御性封顶，默认 64 }
  OnWait: TThrottleWaitHook;       { nil=静默；(ANextRetryAfterMs)每次等待前上报 }
  class function Default: TThrottlePolicy; static;
end;

TThrottleWaitHook = reference to procedure(AWaitNo: Integer;
  ANextRetryAfterMs: Int64);

NewFallbackProvider 语义：
- 链内单尝试逐家切换：AChain[0] 抛出且 ErrorCode ∈ FailOn ∩ IsRetryable →
  试 AChain[1]……全链耗尽 → **透传最后一次原始错误**（不包装不改码，
  对齐 WithRetry 哲学）；白名单外首错立即上抛不切换。
- 流式：仅**拿到流且收到首个 delta 前**允许降级（对齐 retry 首 delta 门）。
- 取消优先于一切：令牌已触发 → 不再切换，原样上抛。
- Complete/Stream 的请求对象按值传给每一家——各 provider 自行编码互不干扰。

NewThrottledProvider 语义：
- 每次 Complete / Stream 先 `gate.TryAcquire`；拒绝 → 在 `AClock.SleepMs` 上
  取消感知等待 `RetryAfterMs` 后重取；累计等待 > `MaxWaitMs` 或重取次数 >
  `MaxAcquires` → 本地抛 `aecRateLimited`（`RetryAfterMs` = 最近 gate 建议值）。
  归因分离：本地整形与上游 429 都落 `aecRateLimited`，但本地路径 `Message`
  带 `'throttled: '` 前缀 — 从未触网、零计费，文案为
  `'throttled: local rate gate — wait budget exceeded (client-side, no upstream request)'`。
  取消打断等待立即以 `EAgentCancelled` 上抛。

{ ---- W9 对冲装饰器（可靠性四象限收官：retry 败后重试/fallback 败后
  换家/throttle 事前整形/hedge 慢时对冲）---- }

THedgePolicy = record
  DelayMs: Int64;                  { 主路无响应 T 毫秒后起对冲路；必填 >0，
                                     工厂校验否则 aecConfig——显式 opt-in }
  OnHedged: THedgeFireHook;        { nil=静默；对冲路发起时上报（观测用） }
  class function Default(ADelayMs: Int64): THedgePolicy; static;
end;

THedgeFireHook = reference to procedure(ADelayMs: Int64);
  { 对冲路发起时回调：参数即本次生效的 DelayMs（实例仅调用期有效）}

NewHedgedProvider(inner, clock, policy) 语义：
- Complete：主路先行；DelayMs 内完成则对冲路从未存在（零额外成本）；到点未
  完成即并发第二路，**任一路先返回者胜出**，输路经取消令牌合并被 Cancel。
  两路皆败：透传**主路**原始错误（不包装；对齐 retry/fallback 哲学）。
- Stream：两流各取首 delta，先达者胜出并包装投递；输流 Cancel 且其增量
  永不外泄（首 delta 门同门——投递不重复）。首 delta 已投递后不再对冲。
- 成本明示：对冲路是完整第二次请求，双倍 token 成本由调用方 opt-in 承担；
  输路可能已被上游计费（客户端只能保证不采用其结果，不能撤回服务端计费）。
- 取消优先：外部令牌触发时两路一并取消，立即 EAgentCancelled。

## 6. 循环（nextpas.core.agent.loop）

```pascal
TLoopOutcome = (roCompleted, roCancelled, roBudgetExhausted, roDoomLoop,
  roRoundsExhausted, roFailed);

TLoopEventKind = (levRunStart, levRoundStart, levRoundEnd,
  levToolCallStart, levToolCallEnd, levBudgetWarning, levRunEnd);
{ 注意：无 levRetry——重试发生在 WithRetry 装饰器层，loop 不可见；
  重试观测走 TRetryPolicy.OnAttempt。levBudgetWarning 在剩余输出预算
  首次低于 20% 时触发一次 }

TLoopEvent = record
  Kind: TLoopEventKind;
  Round: Integer;
  ToolName: string;
  ToolCallId: string;              { 工具事件关联键；非工具事件为空 }
  ElapsedMs: Int64;
  DetailJson: TJsonText;           { 自由结构细节；快照断言只看 Kind/Round/ToolCallId }
end;

TLoopEventHandler = reference to procedure(const AEvent: TLoopEvent);
TLoopEventHandlerMethod = procedure(const AEvent: TLoopEvent) of object;
TLoopEventHandlerProc = procedure(const AEvent: TLoopEvent);

THookVerdict = (hvProceed, hvBlock, hvStop);   { block=合成 error result 继续；stop=结束轮转 }

TLoopHook = reference to function(const ASpec: TToolSpec;
  const AArgsJson: TJsonText): THookVerdict;
TLoopHookMethod = function(const ASpec: TToolSpec;
  const AArgsJson: TJsonText): THookVerdict of object;
TLoopHookProc = function(const ASpec: TToolSpec;
  const AArgsJson: TJsonText): THookVerdict;

TAgentLoopOptions = record
  RequestBase: TCompletionRequest; { 请求模板：Model/System/MaxTokens/Temperature 等
                                     由这里取；loop 每轮以其为底、追加 transcript 为
                                     Messages、注入注册的工具。Model 必填（同请求规则）}
  MaxRounds: Integer;              { 默认 10 }
  MaxOutputTokens: Int64;          { 跨轮累计输出预算；CMaxTokensUnset=不限 }
  MaxToolCalls: Integer;           { 整次 run 工具调用总数；0=不限 }
  DoomLoopThreshold: Integer;      { 连续相同 call 判定阈值，默认 3；0=关闭检测 }
  TruncateLines: Integer;          { 工具结果截断行数上限，默认 2000；0=关 }
  TruncateBytes: Integer;          { 截断字节上限，默认 65536；0=关 }
  Clock: IAgentClock;              { 注入；默认真实时钟 }
  Logger: ILogger;                 { 同 C15：nil → NullLogger }
  Cancel: IAsyncCancellationToken; { 可选运行令牌 }
  UsageSink: IAgentUsageSink;      { T1.4：可选用量汇，nil 退化，线程安全不 raise }
end;
{ 回调不在 Options 里：SetXxx 是唯一注入通道，避免双通道绕过归一化 }

TAgentLoop = class
  constructor Create(const AProvider: IAgentProvider); overload;
  constructor Create(const AProvider: IAgentProvider;
    const APool: IThreadPool); overload;   { 并行工具池；nil → 共享进程池 }
  procedure AddTool(const ATool: IAgentTool);    { 注册即校验 spec/schema → aecConfig }
  procedure SetEventHook(AHandler: TLoopEventHandler); overload;
  procedure SetEventHook(AHandler: TLoopEventHandlerMethod); overload;
  procedure SetEventHook(AHandler: TLoopEventHandlerProc); overload;
  procedure SetPreToolCall(AHook: TLoopHook); overload;
  procedure SetPreToolCall(AHook: TLoopHookMethod); overload;
  procedure SetPreToolCall(AHook: TLoopHookProc); overload;
  procedure SetPostToolResult(AHook: TLoopHook); overload;
  procedure SetPostToolResult(AHook: TLoopHookMethod); overload;
  procedure SetPostToolResult(AHook: TLoopHookProc); overload;

  Options: TAgentLoopOptions;      { 公开字段：Run 前配置（record 直赋合法）}

  { 直线入口：内部维护 transcript；取消/预算按 ARCHITECTURE §5 语义收尾 }
  function Run(const AUserText: string): IAgentLoopRun; overload;
  function Run(const AMessages: TMessageArray): IAgentLoopRun; overload;
end;

IAgentLoopRun = interface
  function FinalMessage: TMessage;        { 最终 assistant 文本消息；无产出时空记录
                                            （用 TMessage.IsEmpty 区分）}
  function TryGetFinalMessage(out AMsg: TMessage): Boolean;  { False=无产出 }
  function Transcript: TMessageArray;     { 全程消息（含 tool 往返）}
  function Outcome: TLoopOutcome;
  function TotalUsage: TTokenUsage;
  function LastError: EAgentError;        { roFailed 时非 nil }
end;
```

收尾语义（三种终止统一路径，normative）：预算耗尽 / 防打转 / MaxRounds 用尽
都执行"追加 system 引导消息 → 禁工具推理一次"；该轮成功则 `FinalMessage`=引导回复、
`Outcome`=触发原因（roBudgetExhausted/roDoomLoop/roRoundsExhausted）；该轮失败则
`Outcome=roFailed` 且 `LastError` 就位。hook/OnEvent 回调抛异常**不吞**：直接冒泡，
Run 以 roFailed 终止（编程错误必须响亮）。

工具结果截断信封（normative）：截断作用于结果的 UTF-8 安全切文本投影，
产出**合法 JSON 包裹** `{"truncated":true,"content":"<切后文本>"}`
（键名为 tools 单元公开常量）；顺序固定 `Execute → 截断信封化 →
PostToolResult hook → 回喂`——hook 只见截断后载荷，超大结果到不了 hook
（DoS 时序保证），`Truncated=True` 随 pkToolResult 记录。

hook 与事件回调的注入统一走 `SetXxx` 三形态重载（anonymous / method / proc），
内部按 design-conventions 回调范式存 `reference to`。

## 7. Fake / scripted provider（nextpas.core.agent.provider.fake）

```pascal
{ 脚本格式（JSON 数组，每项一个"虚拟响应"）：
  [ { "deltas": [
        {"kind":"text_delta","text":"你好"},
        {"kind":"tool_call_start","index":0,"id":"call_1","name":"weather"},
        {"kind":"tool_call_delta","index":0,"args":"{\"city\":\"上海\"}"},
        {"kind":"tool_call_end","index":0},
        {"kind":"finish","reason":"tool_calls"},
        {"kind":"usage","in":12,"out":34} ] } ]
  多项脚本 = 多轮响应按序回放；耗尽后再调用 → 抛 aecProtocol（测试立即暴露）}
function NewFakeProvider(const AScriptJson: TJsonText): IAgentProvider;
function NewEchoProvider: IAgentProvider;   { 单 delta 回显 user 输入的极简桩 }
```

CI 纪律：仓库内任何 test/example/benchmark 禁止触公网 LLM API；
需要"接近真实"时用 scripted transport + 快照 wire 体（TESTING.md）。

## 8. 纯编解码器（决策 D13：公开表面，客户复用）

> 动机见 CONSUMERS.md：网关型客户（token888）不消费"客户端调用"，
> 消费的是协议翻译本身。编解码器与 provider 工厂共用同一实现——
> 单一事实源，公开即免费。编码器为纯函数；流解码器为有状态对象
> （每角色一实例，引用计数管理，替代裸指针状态配对）。

```pascal
{ ---- OpenAI Chat Completions 族（nextpas.core.agent.provider.openai）---- }

function EncodeOpenAIRequest(const AReq: TCompletionRequest;
  AStream: Boolean): TJsonText;

procedure DecodeOpenAIResponse(const ABody: TJsonText;
  out AMsg: TMessage;
  const ALog: ILogger = nil);                { 违反协议抛 aecProtocol }

function NewOpenAIWireDecoder(
  const ALog: ILogger = nil): IAgentWireDecoder;

{ ---- Anthropic Messages 族（nextpas.core.agent.provider.anthropic）---- }

function EncodeAnthropicRequest(const AReq: TCompletionRequest;
  AStream: Boolean): TJsonText;

procedure DecodeAnthropicResponse(const ABody: TJsonText;
  out AMsg: TMessage;
  const ALog: ILogger = nil);                { 违反协议抛 aecProtocol }

function NewAnthropicWireDecoder(
  const ALog: ILogger = nil): IAgentWireDecoder;

function EncodeAnthropicCountTokensRequest(
  const AReq: TCompletionRequest): TJsonText;  { W12：§2.7 同构减
                                                  max_tokens/stream 两键 }

function BuildAnthropicUrl(const ABaseUrl: string): string;
function BuildAnthropicCountTokensUrl(
  const ABaseUrl: string): string;             { W12：…/v1/messages/count_tokens }

{ ---- OpenAI Responses 族（nextpas.core.agent.provider.openai.responses，
  W9/v1.1 第四批；映射权威=WIRE-MAPPINGS §3）---- }

function EncodeResponsesRequest(const AReq: TCompletionRequest;
  AStream: Boolean): TJsonText;

procedure DecodeResponsesResponse(const ABody: TJsonText;
  out AMsg: TMessage;
  const ALog: ILogger = nil);                { 违反协议抛 aecProtocol }

function NewResponsesWireDecoder(
  const ALog: ILogger = nil): IAgentWireDecoder;

function BuildResponsesUrl(const ABaseUrl: string): string;
```

可选 `ALog`：未映射枚举值（零值+`agent.unmapped.*` 捕获之外）与 Q-O7
多 choice 丢弃在此 warn；nil 时仅保留 Extra 证据不告警。

```pascal
{ 流帧解码器（intf 定义）：把厂商 SSE 帧归约为词表增量。
  provider 工厂内部与 Stream() 路径共用；Finalize 抹平 usage/finish 到达顺序 }
IAgentWireDecoder = interface
  procedure DecodeEvent(const AEvent: TWireSSEEvent;
    out ADeltas: TStreamDeltaArray);   { ping 等 0 增量帧合法 }
  { 流终止后调用一次（usage/finish 异序抹平）；重复调用返回空数组 }
  procedure Finalize(out ADeltas: TStreamDeltaArray);
end;
```

规则：

- 编解码器**只认 WIRE-MAPPINGS.md**；怪癖修正落在实现+快照测试，不落调用方。
- `Decode*Response`/`DecodeEvent` 对未知字段执行 Extra 无损回注；对违反协议的
  输入一律抛 `EAgentError[aecProtocol]`（带 RawBodySnippet），绝不静默跳过。
- 解码器实例不跨消息复用、非线程安全（单角色独占）；编码函数无状态可并发。
- 网关型客户的入站侧解析（server 方向）不属于本模块范围（README 非目标），
  词表可直接复用。

## 9. 版本与稳定性

- v1 全部公共表面标注 draft；首个 landing 后进入 registry truth-level 演进流程。
- 语义版本化随 core 模块纪律；破坏性词表变更必须先改本文档并更新 ROADMAP inbox。

## 10. 默认值总表（单一事实源 — 与 `nextpas.core.agent.base` 常量表对齐）

| 项 | 默认值 | 定义处 |
|----|--------|--------|
| OpenAI BaseUrl | `https://api.openai.com`（拼 `/v1/chat/completions`） | provider 常量 |
| Anthropic BaseUrl | `https://api.anthropic.com`（拼 `/v1/messages`） | provider 常量 |
| Anthropic-Version | `2023-06-01`（`CANTHROPIC_VERSION_DEFAULT`） | provider 常量 |
| ConnectTimeoutMs | 10_000 | `TProviderOptions` |
| TotalTimeoutMs | 300_000 | `TProviderOptions` |
| ReadIdleTimeoutMs | `CTimeoutDefault = 0` 禁用；> 0 生效（W7） | `TProviderOptions` / transport |
| TRetryPolicy.Default | attempts=3 · initial=1_000 ms · max=30_000 ms · ×2.0 · jitter=0.1 · 白名单四码 · RespectRetryAfter=True · 总上限 120_000 ms | retry 单元 |
| TAgentLoopOptions.MaxRounds | 10 | loop |
| DoomLoopThreshold | 3 | loop |
| TruncateLines / TruncateBytes | 2_000 / 65_536 | loop |
| 读 chunk | 32 KiB（IReader 单次 Read 步长） | transport.http `CReadChunkBytes` |
| SSE 行缓冲上限 | 1 MiB（单行，`sse.CSSEMaxLineBytes`） | sse 单元 |
| SSE 单事件 data 上限 | 8 MiB（`sse.CSSEMaxEventDataByte`） | sse 单元 |
| 成功体累积上限 | 8 MiB（超限 `aecProtocol`，`base.CAgentMaxSuccessBodyBytes` — 单一真源） | `nextpas.core.agent.base` |
| wire 单头上限 | 8 KiB（名+值，`base.CAgentMaxWireHeaderValueBytes` — 单一真源） | `nextpas.core.agent.base` |
| wire 总头上限 | 64 KiB（累计，`base.CAgentMaxWireTotalHeaderBytes` — 单一真源） | `nextpas.core.agent.base` |
| 槽位总数 / 索引上限 | 256（`base.CAgentMaxSlotMap` — 单一真源，稀疏大索引回退） | `nextpas.core.agent.base` |
| 工具参数预检上限 | 256 KiB（超限合成 error result，`base.CAgentMaxToolArgsBytes`） | `nextpas.core.agent.base` |
| Extra 未知键捕获上限 | 单消息 / part 64 个（`base.CAgentMaxExtraKeys` — 单一真源），超出丢弃并 `warn` | `nextpas.core.agent.base` |
| ExtraJson 合法性 | 非空必为 JSON object，否则编码期 `aecConfig` | provider.common `AgentValidateExtraJson` |
| RawBodySnippet 上限 | 8 KiB（`base.CAgentMaxRawBodySnippetBytes` — 单一真源） | `nextpas.core.agent.base` |
| 初始容量 · 工具参数 builder | 1_024（`base.CAgentToolArgsInitialCap`） | `nextpas.core.agent.base` |
| 初始容量 · System 去重拼接 | 512（`base.CAgentSystemTextInitialCap`） | `nextpas.core.agent.base` |
| 初始容量 · Session Fork | 1_024（`base.CAgentSessionForkInitialCap`） | `nextpas.core.agent.base` |
| Logger 缺省 | `nil` → `NullLogger`（`log.intf`，零开销） | SELECTION C15 |
| env 前缀 | `NEXTPAS_AGENT_<VENDOR>_` | CONSUMERS §3 |
| 定价 · RateDenominator / ARateMultiplier 默认 | 10_000（1.0x；`TModelPricing.RateDenominator` 缺省，`EstimateCost` 的 `ARateMultiplier` 默认 10_000，`<=0` 按 1.0x） | pricing 单元 |
| 定价 · EstimateCost 舍入 | `(prompt*per1kPrompt+500) div 1000 + (completion*per1kCompletion*rate+5000) div 10000` μUSD（整数微元，四舍五入同源 `tk888.billing.pas:22,212`） | pricing 单元 |
| 定价 · ImageTier 档位 | max-edge ≤1024→1000 · ≤2048→2000 · else 4000（含 `2048x2048→2000` 特判 `billing:470`） | pricing 单元 |
| 定价 · TPassthroughPricing.FlatCostUsd6 缺省 | 0（未定价不计费） | pricing 单元 |

> 修改任何默认值必须同步本表与 `nextpas.core.agent.base` 常量定义，并跑受影响 gate。
