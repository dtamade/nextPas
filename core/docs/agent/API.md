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
  无损携带；禁止用 borrow 视图跨作用域）。

## 1. base 词表（nextpas.core.agent.base）

### 1.1 枚举

```pascal
TMessageRole = (mrSystem, mrUser, mrAssistant, mrTool);

TPartKind = (pkText, pkThinking, pkToolCall, pkToolResult, pkImage);

TFinishReason = (frNone, frStop, frLength, frToolCalls, frContentFilter);

TTriState = (tsUnset, tsFalse, tsTrue);   { 三态布尔：unset 即不上送 }

TStreamDeltaKind = (
  sdkTextDelta,        { TextDelta 追加正文 }
  sdkThinkingDelta,    { TextDelta 追加思考内容 }
  sdkToolCallStart,    { ToolIndex/ToolCallId/ToolName 就位 }
  sdkToolCallDelta,    { ArgumentsDelta 追加参数 JSON 片段 }
  sdkToolCallEnd,      { 该槽位参数流结束 }
  sdkFinish,           { FinishReason 就位，正文/工具流结束 }
  sdkUsage,            { Usage 就位（可与 sdkFinish 异序到达，fold 抹平）}
  sdkError             { Error 就位（中途可恢复上报或终止）}
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
  Id: string;                      { 厂商消息 id 或本地生成 }
  Role: TMessageRole;
  Parts: TPartArray;
  Model: string;                   { assistant：实际服务模型 id }
  FinishReason: TFinishReason;
  Usage: TTokenUsage;
  ExtraJson: TJsonText;            { 消息级未知字段无损捕获 }
end;
TMessageArray = array of TMessage;

{ ---- 流增量 ---- }

TAgentErrorInfo = record          { sdkError 携带的中途错误信息 }
  Code: TAgentErrorCode;          { 枚举物理落位在 base（词表同源），见 §2 }
  Message: string;
  Retryable: Boolean;
  RetryAfterMs: Int64;            { CUsageUnknown=未提供 }
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
end;
TStreamDeltaArray = array of TStreamDelta;

function MessageText(const AMsg: TMessage): string;  { 拼 pkText 便利函数 }

{ ---- 补全请求 ---- }

TCompletionRequest = record
  Model: string;                   { 必填：无默认值，调用方显式决定 }
  System: string;                  { 顶层 system 便利字段 }
  Messages: TMessageArray;         { 对话历史（不含本轮待发 user 时自行前置）}
  MaxTokens: Int64;                { CMaxTokensUnset；anthropic 强制必填→见 §6 }
  Temperature: Double;             { CTemperatureUnset }
  TopP: Double;                    { CTopPUnset }
  Seed: Int64;                     { CSeedUnset }
  StopSequences: TStringArray;
  ParallelToolCalls: TTriState;    { tsUnset 不上送 }
  Thinking: TTriState;             { 扩展思考开关；tsUnset 不上送 }
  ThinkingBudgetTokens: Int64;     { CMaxTokensUnset；Thinking=tsTrue 时语义生效 }
  ExtraJson: TJsonText;            { 逃生舱：合并进请求根对象（厂商私有参数）}

  class function New(const AModel: string): TCompletionRequest; static;
end;

{ builder 便利：TCompletionRequest 的 advancedrecords 方法，返回修改后的副本
  （record 值语义，支持链式书写，见 README 用例）：
    function WithSystem(const AText: string): TCompletionRequest;
    function WithUserText(const AText: string): TCompletionRequest;
    function WithMaxTokens(AN: Int64): TCompletionRequest;
    function WithTemperature(AValue: Double): TCompletionRequest;
    function WithStop(const ASeq: TStringArray): TCompletionRequest;
  需 {$modeswitch advancedrecords}（design-conventions §11 允许追加）。}
```

### 1.4 工具词表

```pascal
TToolCapability = (tcParallel, tcIdempotent, tcReadOnly, tcNeedsConfirm);
TToolCapabilities = set of TToolCapability;

TToolSpec = record
  Name: string;                    { ^[a-zA-Z0-9_-]{1,64}$，注册时校验 }
  Description: string;
  ParametersJson: TJsonText;       { JSON Schema 文本 }
  Capabilities: TToolCapabilities;
  TimeoutMs: Int64;                { CTimeoutDefault=不限；loop 用它包 executor }
end;
TToolSpecArray = array of TToolSpec;

TToolResult = record
  ContentJson: TJsonText;          { 回喂模型的 JSON 文本 }
  IsError: Boolean;                { true → 以 error 形态回喂，循环继续 }
  Truncated: Boolean;
end;
```

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
  RetryAfterMs: Int64;          { CUsageUnknown=未提供；仅 RateLimited 有意义 }
  Provider: string;             { 'openai' | 'anthropic' | ''=本地 }
  RequestId: string;            { 上游 x-request-id 回显（有则填）}
  RawBodySnippet: string;       { 上游错误体摘要 ≤8KB；本地错误为空 }
end;

EAgentCancelled = class(EAgentError);   { ErrorCode 固定 aecCancelled }

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

{ ---- wire 层（自定义 transport / 测试装饰器的落点；不进门面）---- }

TWireHeader = record
  Name: string;
  Value: string;
end;
TWireHeaderArray = array of TWireHeader;

TWireRequest = record
  Url: string;                      { 本模块仅 POST（chat/messages 端点），方法由 transport 固定 }
  BodyJson: TJsonText;              { 已序列化请求体 }
  Headers: TWireHeaderArray;        { 含 auth/content-type/accept }
  ConnectTimeoutMs: Int64;          { CTimeoutDefault }
  TotalTimeoutMs: Int64;            { CTimeoutDefault }
end;

TWireResponse = record
  StatusCode: Integer;
  Headers: TWireHeaderArray;
  BodyText: string;                 { 非流式路径全量响应体 }
  RequestId: string;
end;

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
  function GetCancelled: Boolean;      { EOF 后读取区分取消 }
  function GetMessage: TMessage;       { EOF 后有效：内部 fold 的最终消息 }
  function GetUsage: TTokenUsage;      { EOF 后有效；未知字段=CUsageUnknown }
end;

IAgentProvider = interface
  function GetName: string;                       { 'openai'|'anthropic'|'fake' }
  function Complete(const AReq: TCompletionRequest;
    const ATools: TToolSpecArray): TMessage;      { 取消→EAgentCancelled }
  function Stream(const AReq: TCompletionRequest;
    const ATools: TToolSpecArray): IAgentCompletion;
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
function WithRetry(const AInner: IAgentProvider; const APolicy: TRetryPolicy;
  const AClock: IAgentClock): IAgentProvider;

{ 环境装配（契约见 CONSUMERS.md §3）：必填 env 缺失返回 nil，绝不静默回退。
  NEXTPAS_AGENT_OPENAI_API_KEY / _MODEL / _BASE_URL
  NEXTPAS_AGENT_ANTHROPIC_API_KEY / _MODEL / _BASE_URL }
function NewOpenAIProviderFromEnv: IAgentProvider;
function NewAnthropicProviderFromEnv: IAgentProvider;
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
  Transport: IAgentTransport;      { 注入点：测试/装饰器；nil → 生产 http transport }
  Logger: ILogger;                 { log.intf 接缝（SELECTION C15）；nil → NullLogger 零开销 }
  ExtraHeaders: TWireHeaderArray;
end;

TOpenAIOptions = record
  Common: TProviderOptions;
  Organization: string;            { 可选 header }
  class function New(const AModel: string): TOpenAIOptions; static;
end;

TAnthropicOptions = record
  Common: TProviderOptions;
  AnthropicVersion: string;        { 默认取常量 CANTHROPIC_VERSION_DEFAULT }
  class function New(const AModel: string): TAnthropicOptions; static;
end;
```

## 4. 协议域纯函数（nextpas.core.agent.fold）

```pascal
TAssistantBuild = class     { 增量累积器；Create 后连续 FoldDelta，Finish 收口 }
  procedure FoldDelta(const ADelta: TStreamDelta);
  function Finish: TMessage;          { 合成终帧：usage/finish 异序抹平 }
  function PartialText: string;       { 中途观测用 }
end;

{ 一次性折叠：deltas 数组 → 消息。唯一权威实现：
  loop、IAgentCompletion.GetMessage、测试三方共用，禁止任何地方重写折叠逻辑 }
function FoldDeltas(const ADeltas: array of TStreamDelta;
  out AMsg: TMessage): TTokenUsage;
```

折叠规则（协议域铁律，违例抛 `EAgentError[aecProtocol]`）：

- `sdkToolCallStart` 开槽（ToolIndex 分桶）；`sdkToolCallDelta` 按 index 追加
  ArgumentsDelta（IStringBuilder 累积防 O(n²)）；`sdkToolCallEnd` 封槽；
  未 Start 先 Delta = 协议违例。
- `sdkUsage`/`sdkFinish` 到达顺序任意，`Finish` 统一合成（FinalizeStream 语义）。
- `sdkTextDelta`/`sdkThinkingDelta` 依序生成对应 part；thinking part 保留
  Signature 字段透传。
- fold 只认词表，不知道任何厂商名——厂商差异必须在 adapter 内归约为词表。

## 5. 重试策略（nextpas.core.agent.retry）

```pascal
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
  class function Default: TRetryPolicy; static;
end;

{ 装饰器：包装任意 IAgentProvider（含 fake）；睡在 AClock 上（测试零睡眠）；
  每次重试前检查 ACancel（intf 侧可选令牌版本另列）；每次尝试经 OnRetry 上报 }
function WithRetry(const AInner: IAgentProvider; const APolicy: TRetryPolicy;
  const AClock: IAgentClock): IAgentProvider; overload;
function WithRetry(const AInner: IAgentProvider; const APolicy: TRetryPolicy;
  const AClock: IAgentClock; const AToken: IAsyncCancellationToken): IAgentProvider; overload;
```

语义：仅对 `RetryOn` 且 `IsRetryable` 的错误重试；`RetryAfterMs` 有效且
`RespectRetryAfter` 时直接采用；指数退避 `min(prev*Multiplier, MaxDelayMs)` ± jitter；
超过 `MaxAttempts-1` 次后抛最后一次原始错误。

## 6. 循环（nextpas.core.agent.loop）

```pascal
TLoopEventKind = (levRunStart, levRoundStart, levRoundEnd,
  levToolCallStart, levToolCallEnd, levRetry, levBudgetWarning, levRunEnd);

TLoopEvent = record
  Kind: TLoopEventKind;
  Round: Integer;
  ToolName: string;
  ElapsedMs: Int64;
  DetailJson: TJsonText;           { 结构化细节，事件类型自解释 }
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
  MaxRounds: Integer;              { 默认 10 }
  MaxOutputTokens: Int64;          { 跨轮累计输出预算；CMaxTokensUnset=不限 }
  MaxToolCalls: Integer;           { 整次 run 工具调用总数；0=不限 }
  DoomLoopThreshold: Integer;      { 连续相同 call 判定阈值，默认 3；0=关闭检测 }
  TruncateLines: Integer;          { 工具结果截断行数上限，默认 2000；0=关 }
  TruncateBytes: Integer;          { 截断字节上限，默认 65536；0=关 }
  OnEvent: TLoopEventHandler;      { 内部统一存储；三形态 SetEventHook 重载注入 }
  PreToolCall: TLoopHook;          { 三形态 SetPreToolCall 重载注入 }
  PostToolResult: TLoopHook;       { 三形态 SetPostToolResult 重载注入 }
  Clock: IAgentClock;              { 注入；默认真实时钟 }
  Logger: ILogger;                 { 同 C15：nil → NullLogger }
  Cancel: IAsyncCancellationToken; { 可选运行令牌 }
end;

TAgentLoop = class
  constructor Create(const AProvider: IAgentProvider);
  procedure AddTool(const ATool: IAgentTool);          { 实例作用域容器 }
  property Options: TAgentLoopOptions read FOptions write FOptions;

  { 直线入口：内部维护 transcript；取消/预算按 §ARCHITECTURE 语义收尾 }
  function Run(const AUserText: string): IAgentLoopRun; overload;
  function Run(const AMessages: TMessageArray): IAgentLoopRun; overload;
end;

IAgentLoopRun = interface
  function FinalMessage: TMessage;        { 最终 assistant 文本消息 }
  function Transcript: TMessageArray;     { 全程消息（含 tool 往返）}
  function Outcome: TLoopOutcome;         { roCompleted | roCancelled |
                                            roBudgetExhausted | roDoomLoop | roFailed }
  function TotalUsage: TTokenUsage;
  function LastError: EAgentError;        { roFailed 时非 nil }
end;
```

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
  const ATools: TToolSpecArray; AStream: Boolean): TJsonText;

procedure DecodeOpenAIResponse(const ABody: TJsonText;
  out AMsg: TMessage);                       { 违反协议抛 aecProtocol }

function NewOpenAIWireDecoder: IAgentWireDecoder;

{ ---- Anthropic Messages 族（nextpas.core.agent.provider.anthropic）---- }

function EncodeAnthropicRequest(const AReq: TCompletionRequest;
  const ATools: TToolSpecArray; AStream: Boolean): TJsonText;

procedure DecodeAnthropicResponse(const ABody: TJsonText;
  out AMsg: TMessage);

function NewAnthropicWireDecoder: IAgentWireDecoder;
```

```pascal
{ 流帧解码器（intf 定义）：把厂商 SSE 帧归约为词表增量。
  provider 工厂内部与 Stream() 路径共用；Finalize 抹平 usage/finish 到达顺序 }
IAgentWireDecoder = interface
  procedure DecodeEvent(const AEvent: TWireSSEEvent;
    out ADeltas: TStreamDeltaArray);   { ping 等 0 增量帧合法 }
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

## 10. 默认值总表（单一事实源）

| 项 | 默认值 | 定义处 |
|----|--------|--------|
| OpenAI BaseUrl | `https://api.openai.com`（拼 `/v1/chat/completions`）| provider 常量 |
| Anthropic BaseUrl | `https://api.anthropic.com`（拼 `/v1/messages`）| provider 常量 |
| Anthropic-Version | `2023-06-01`（CANTHROPIC_VERSION_DEFAULT）| provider 常量 |
| ConnectTimeoutMs | 10_000 | TProviderOptions |
| TotalTimeoutMs | 300_000 | TProviderOptions |
| TRetryPolicy.Default | attempts=3, initial=1000ms, max=30_000ms, ×2.0, jitter=0.1, 白名单四码, RespectRetryAfter=True, 总上限 120_000ms | retry 单元 |
| TAgentLoopOptions.MaxRounds | 10 | loop |
| DoomLoopThreshold | 3 | loop |
| TruncateLines / TruncateBytes | 2000 / 65536 | loop |
| 读 chunk / 行缓冲上限 | 32 KiB / 1 MiB | PERFORMANCE §2 |
| SSE 单事件 data 上限 | 8 MiB | SECURITY §3 |
| 工具参数预检上限 | 256 KiB（超限合成 error result） | SECURITY §3 |
| RawBodySnippet 上限 | 8 KiB | ERRORS §6 |
| Logger 缺省 | nil → NullLogger（log.intf，零开销） | SELECTION C15 |
| env 前缀 | `NEXTPAS_AGENT_<VENDOR>_` | CONSUMERS §3 |

修改任何默认值必须同步本表并跑受影响 gate。
