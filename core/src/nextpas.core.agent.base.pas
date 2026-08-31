{**
 * nextpas.core.agent.base - agent 模块词表：纯数据与纯枚举，零 IO。
 *
 * 契约权威：core/docs/agent/API.md §1。实现与文档冲突时先改文档。
 *}

unit nextpas.core.agent.base;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

const
  { ---- Sentinel 常量（API.md §1.2）：未设置的字段绝不上送 wire ---- }
  CTemperatureUnset   = -2.0;          { 合法域 [0.0, 2.0]，负值即 unset }
  CTopPUnset          = -2.0;
  CMaxTokensUnset     = 0;             { >0 有效 }
  CSeedUnset          = Low(Int64);
  CTimeoutDefault     = 0;             { 0=用 transport 默认；<0=无限 }
  CUsageUnknown       = -1;            { TTokenUsage 各字段未知值 }
  CRetryAfterUnknown  = -1;            { RetryAfterMs 未提供/不适用 }

type
  { owned 全量 JSON 文本：core 的 TJsonValue 是 borrow 视图，词表只存文本 }
  TJsonText = type string;

  { ---- 对话角色与部件 ---- }

  TMessageRole = (mrSystem, mrUser, mrAssistant, mrTool);

  TPartKind = (pkText, pkThinking, pkToolCall, pkToolResult, pkImage);

  TFinishReason = (frNone, frStop, frLength, frToolCalls, frContentFilter);

  { 三态布尔：tsUnset 即不上送（Pascal 无 nullable 的诚实替代）}
  TTriState = (tsUnset, tsFalse, tsTrue);

  { 工具选择模式（W6）：tcmUnset 不上送；tcmNamed 需配 ToolChoiceName。
    wire 映射：openai §1.1 / anthropic §2.1（required→any、none→省略 tools）}
  TToolChoiceMode = (tcmUnset, tcmAuto, tcmNone, tcmRequired, tcmNamed);

  { 推理力度旋钮（W7）：reUnset 不上送。openai → reasoning_effort；
    anthropic 无对应参数 → 忽略 + warn（Q-A5 同规则），力度走 Thinking/Budget }
  TReasoningEffort = (reUnset, reMinimal, reLow, reMedium, reHigh);

  { 提示缓存断点策略（W10）：ccmUnset 不上送（v1 请求字节零变化）。
    ccmAuto=anthropic 显式 cache_control 自动打点（WIRE-MAPPINGS §2.6：
    tools 尾/system/末条消息尾块三处）；openai/grok/responses 族自动
    缓存，编码零差异 }
  TCacheControlMode = (ccmUnset, ccmAuto);

  TStreamDeltaKind = (
    sdkTextDelta,        { TextDelta 追加正文 }
    sdkThinkingDelta,    { TextDelta 追加思考内容；Signature 携带签名透传 }
    sdkToolCallStart,    { ToolIndex/ToolCallId/ToolName 就位 }
    sdkToolCallDelta,    { ArgumentsDelta 追加参数 JSON 片段 }
    sdkToolCallEnd,      { 该槽位参数流结束 }
    sdkFinish,           { FinishReason 就位，正文/工具流结束 }
    sdkUsage,            { Usage 就位（可与 sdkFinish 异序到达，fold 抹平）}
    sdkError,            { Error 就位（流中途错误上报；fold 跳过）}
    sdkEnvelope          { MessageId/Model 就位（流首信封事件；fold 记入消息）}
  );

  { 错误码词表（物理落位本单元；异常类在 nextpas.core.agent.errors）}
  TAgentErrorCode = (
    aecNone,
    aecInvalidRequest,     { 上游 400 类语义错误；不可重试，RawBody 保真 }
    aecAuthentication,     { 401/403 }
    aecNotFound,           { 404：模型/端点不存在 }
    aecRateLimited,        { 429；可重试，RetryAfterMs 生效 }
    aecTransport,          { 连接/读/写失败、连接重置；可重试 }
    aecTimeout,            { 连接/整体超时；可重试 }
    aecServer,             { 上游 5xx；可重试 }
    aecContextOverflow,    { 提示超窗；不可自动重试，需消费方裁剪历史 }
    aecProtocol,           { 厂商响应/SSE 帧违反协议；不可重试 }
    aecCancelled,          { 经令牌取消 }
    aecConfig,             { 本地配置缺失/非法（缺 key、缺 MaxTokens 等）}
    aecToolFailed,         { loop 层：工具执行抛异常 }
    aecBudgetExhausted     { loop 层：预算达限（正常收尾态）}
  );

  { ---- 用量 ---- }

  TTokenUsage = record
    InputTokens: Int64;              { CUsageUnknown = 未知 }
    OutputTokens: Int64;
    CacheReadInputTokens: Int64;
    CacheWriteInputTokens: Int64;
    ReasoningTokens: Int64;
    function Known: Boolean;         { 至少一个字段有真实值 }
    function TotalKnownTokens: Int64;{ 已知字段之和 }
  end;

  { ---- 消息部件 ---- }

  TPart = record
    Kind: TPartKind;
    Text: string;                    { pkText/pkThinking 内容 }
    ToolCallId: string;              { pkToolCall / pkToolResult 配对键 }
    ToolName: string;                { pkToolCall }
    ArgumentsJson: TJsonText;        { pkToolCall 参数全文（start+delta 折叠）}
    ResultJson: TJsonText;           { pkToolResult 回喂内容 }
    IsError: Boolean;                { pkToolResult 失败标记 }
    ImageUrl: string;                { pkImage：URL 或 data URI }
    Signature: string;               { pkThinking 厂商签名，不透明透传 }
    ExtraJson: TJsonText;            { 未知字段无损捕获，编码时回注原位 }
  end;
  TPartArray = array of TPart;

  TMessage = record
    Id: string;                      { 厂商消息 id；厂商未给则空串 }
    Role: TMessageRole;
    Parts: TPartArray;
    Model: string;                   { assistant：实际服务模型 id }
    FinishReason: TFinishReason;
    Usage: TTokenUsage;
    ExtraJson: TJsonText;            { 消息级未知字段无损捕获 }
    function IsEmpty: Boolean;       { 无 id/model/parts/usage 的零值消息 }
  end;
  TMessageArray = array of TMessage;

  { ---- 流增量 ---- }

  TAgentErrorInfo = record          { sdkError 携带的中途错误信息 }
    Code: TAgentErrorCode;
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

  { ---- 工具词表 ---- }

  { v1 仅保留有明确消费语义的标志；其余候选进 inbox 等语义立项 }
  TToolCapability = (tcParallel);
  TToolCapabilities = set of TToolCapability;

  TToolSpec = record
    Name: string;                    { 限字母数字下划线连字符，1..64 字符，AddTool 时校验 }
    Description: string;
    ParametersJson: TJsonText;       { JSON Schema 文本；AddTool 时务实级校验 }
    Capabilities: TToolCapabilities;
    TimeoutMs: Int64;                { CTimeoutDefault（0=缺省即不限）}
  end;
  TToolSpecArray = array of TToolSpec;

  TToolResult = record
    ContentJson: TJsonText;          { 回喂模型的 JSON 文本 }
    IsError: Boolean;                { true → 以 error 形态回喂，循环继续 }
    Truncated: Boolean;
  end;

  { ---- wire 词表（sse/transport/intf 共用；API.md §3）---- }

  TWireHeader = record
    Name: string;
    Value: string;
  end;
  TWireHeaderArray = array of TWireHeader;

  TWireRequest = record
    Url: string;                     { 本模块仅 POST（chat/messages 端点），方法由 transport 固定 }
    BodyJson: TJsonText;             { 已序列化请求体 }
    Headers: TWireHeaderArray;       { 仅鉴权与语义头；Host/Content-Length 等
                                       物理头由 transport/http client 补全 }
    ConnectTimeoutMs: Int64;         { CTimeoutDefault }
    TotalTimeoutMs: Int64;           { CTimeoutDefault }
    ReadIdleTimeoutMs: Int64;        { CTimeoutDefault=0 禁用；流式块间空闲
                                       超时（W7，WIRE-MAPPINGS §0）}
  end;

  TWireResponse = record
    StatusCode: Integer;
    Headers: TWireHeaderArray;
    BodyText: string;                { 非流式路径全量响应体 }
    RequestId: string;
  end;

  { W11 请求级追踪观测事件（API.md §3.2；transport.trace 装饰器产出）}
  TTraceRequestInfo = record
    Provider: string;                { 构造注入的适配器名（'anthropic' 等）}
    Url: string;
    Stream: Boolean;
    BodyBytes: Int64;                { 上送载荷 UTF-8 字节数 }
  end;

  TTraceResponseInfo = record
    Provider: string;
    Url: string;
    Stream: Boolean;
    Status: Integer;                 { -1 = 不可得（流式 wire 层不暴露 / 异常路径）}
    Failed: Boolean;                 { True=transport 异常路径（配对保证）}
    DurationMs: Int64;               { RoundTrip 全程 / OpenStream 建流耗时 }
    ResponseBytes: Int64;            { 非流式响应体；流式 -1（事件级归 fold/loop 层）}
    RequestId: string;               { 响应头透传；异常路径空串 }
  end;

  { SSE 帧（增量解析产物）}
  TWireSSEEvent = record
    Event: string;                   { event: 字段；无则空串 }
    Data: string;                    { 多行 data: 拼接（\n 连接）}
  end;
  TWireSSEEventArray = array of TWireSSEEvent;

  { ---- 补全请求 ---- }

  TCompletionRequest = record
    Model: string;                   { 必填：无默认值，调用方显式决定 }
    System: string;                  { 顶层 system 便利字段 }
    Messages: TMessageArray;         { 对话历史（不含本轮待发 user 时自行前置）}
    Tools: TToolSpecArray;           { 随请求携带（WithTools builder）}
    ResponseSchemaJson: TJsonText;   { 非空即结构化输出（W6）：openai 族 json_schema
                                       strict（§1.7，须合法 JSON object 否则
                                       aecConfig）；anthropic fail-fast aecConfig }
    MaxTokens: Int64;                { CMaxTokensUnset；anthropic 强制必填 }
    Temperature: Double;             { CTemperatureUnset }
    TopP: Double;                    { CTopPUnset }
    Seed: Int64;                     { CSeedUnset }
    StopSequences: TStringArray;
    ParallelToolCalls: TTriState;    { tsUnset 不上送 }
    ToolChoice: TToolChoiceMode;     { tcmUnset 不上送；§1.1/§2.1 映射 }
    ToolChoiceName: string;          { 仅 tcmNamed 有效；缺名 aecConfig }
    ReasoningEffort: TReasoningEffort; { reUnset 不上送；openai reasoning_effort }
    CacheControl: TCacheControlMode; { ccmUnset 不上送；anthropic §2.6 自动打点 }
    Thinking: TTriState;             { 扩展思考开关；tsUnset 不上送 }
    ThinkingBudgetTokens: Int64;     { CMaxTokensUnset；Thinking=tsTrue 时生效 }
    ExtraJson: TJsonText;            { 逃生舱：浅合并进请求根对象 }
    class function New(const AModel: string): TCompletionRequest; static;
      { 工厂：其余字段全部为 sentinel 缺省 }
    function WithSystem(const AText: string): TCompletionRequest;
    function WithUserText(const AText: string): TCompletionRequest;
    function WithMaxTokens(AN: Int64): TCompletionRequest;
    function WithTemperature(AValue: Double): TCompletionRequest;
    function WithStop(const ASeq: TStringArray): TCompletionRequest;
    function WithTools(const ASpecs: TToolSpecArray): TCompletionRequest;
    function WithResponseSchema(const ASchemaJson: string): TCompletionRequest;
    function WithToolChoice(AMode: TToolChoiceMode;
      const AName: string = ''): TCompletionRequest;
    function WithReasoningEffort(AEffort: TReasoningEffort): TCompletionRequest;
    function WithCacheControl(AMode: TCacheControlMode): TCompletionRequest;
      { W10：anthropic 显式打点；其余适配器零差异接受（§2.6）}
      { builder 全部返回修改后的副本（record 值语义链式书写）}
  end;

  { 拼 pkText：顺序直连无分隔符。不变量：MessageText(fold 结果) ==
    正文 sdkTextDelta 的依序连接 }
  function MessageText(const AMsg: TMessage): string;

  { wire 头查找（大小写不敏感，首个命中返回；未命中空串）。
    RequestId 探测 / retry-after 解析 / 消费方自定义头检查共用 }
  function WireHeaderValue(const AHeaders: TWireHeaderArray;
    const AName: string): string;

  { 合并多个 ExtraJson object 文本为一个；无效/空条目跳过，重名后者胜。
    解码侧多来源捕获（根/choice/message 级）与 fold 旁路通道共用 }
  function MergeExtraJson(const ATexts: array of TJsonText): TJsonText;

implementation

uses
  nextpas.core.json,
  nextpas.core.json.builder,
  nextpas.core.text.builder,
  nextpas.core.text.compare;

function TTokenUsage.Known: Boolean;
begin
  Result := (InputTokens <> CUsageUnknown)
    or (OutputTokens <> CUsageUnknown)
    or (CacheReadInputTokens <> CUsageUnknown)
    or (CacheWriteInputTokens <> CUsageUnknown)
    or (ReasoningTokens <> CUsageUnknown);
end;

function TTokenUsage.TotalKnownTokens: Int64;
begin
  Result := 0;
  if InputTokens > 0 then
    Result := Result + InputTokens;
  if OutputTokens > 0 then
    Result := Result + OutputTokens;
end;

function TMessage.IsEmpty: Boolean;
begin
  { usage 以 TotalKnownTokens=0 判定：同时覆盖全 CUsageUnknown 与全零，
    保证 Default(TMessage)（取消路径空记录）判 IsEmpty 为真 }
  Result := (Id = '') and (Model = '') and (Length(Parts) = 0)
    and (FinishReason = frNone) and (Usage.TotalKnownTokens = 0)
    and (ExtraJson = '');
end;

function MessageText(const AMsg: TMessage): string;
var
  I: Integer;
  SB: IStringBuilder;
begin
  SB := MakeStringBuilder;
  for I := 0 to High(AMsg.Parts) do
    if AMsg.Parts[I].Kind = pkText then
      SB.AppendStr(AMsg.Parts[I].Text);
  Result := SB.ToString;
end;

function WireHeaderValue(const AHeaders: TWireHeaderArray;
  const AName: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(AHeaders) do
    if SameText(AHeaders[I].Name, AName) then
    begin
      Result := AHeaders[I].Value;
      Break;
    end;
end;

class function TCompletionRequest.New(const AModel: string): TCompletionRequest; static;
begin
  Result := Default(TCompletionRequest);
  Result.Model := AModel;
  Result.Temperature := CTemperatureUnset;
  Result.TopP := CTopPUnset;
  Result.Seed := CSeedUnset;
  { MaxTokens/ThinkingBudgetTokens 零位即 CMaxTokensUnset；TriState 零位即 tsUnset }
end;

function TCompletionRequest.WithSystem(const AText: string): TCompletionRequest;
begin
  Result := Self;
  Result.System := AText;
end;

function TCompletionRequest.WithUserText(const AText: string): TCompletionRequest;
var
  LPart: TPart;
  LMsg: TMessage;
begin
  Result := Self;
  LPart := Default(TPart);
  LPart.Kind := pkText;
  LPart.Text := AText;
  LMsg := Default(TMessage);
  LMsg.Role := mrUser;
  SetLength(LMsg.Parts, 1);
  LMsg.Parts[0] := LPart;
  Insert(LMsg, Result.Messages, Length(Result.Messages));
end;

function TCompletionRequest.WithMaxTokens(AN: Int64): TCompletionRequest;
begin
  Result := Self;
  Result.MaxTokens := AN;
end;

function TCompletionRequest.WithTemperature(AValue: Double): TCompletionRequest;
begin
  Result := Self;
  Result.Temperature := AValue;
end;

function TCompletionRequest.WithStop(const ASeq: TStringArray): TCompletionRequest;
begin
  Result := Self;
  Result.StopSequences := Copy(ASeq, 0, Length(ASeq));
end;

function TCompletionRequest.WithTools(const ASpecs: TToolSpecArray): TCompletionRequest;
begin
  Result := Self;
  Result.Tools := Copy(ASpecs, 0, Length(ASpecs));
end;

function TCompletionRequest.WithResponseSchema(
  const ASchemaJson: string): TCompletionRequest;
begin
  Result := Self;
  Result.ResponseSchemaJson := ASchemaJson;
end;

function TCompletionRequest.WithToolChoice(AMode: TToolChoiceMode;
  const AName: string): TCompletionRequest;
begin
  Result := Self;
  Result.ToolChoice := AMode;
  Result.ToolChoiceName := AName;
end;

function TCompletionRequest.WithReasoningEffort(
  AEffort: TReasoningEffort): TCompletionRequest;
begin
  Result := Self;
  Result.ReasoningEffort := AEffort;
end;

function TCompletionRequest.WithCacheControl(
  AMode: TCacheControlMode): TCompletionRequest;
begin
  Result := Self;
  Result.CacheControl := AMode;
end;

function MergeExtraJson(const ATexts: array of TJsonText): TJsonText;
var
  B: IJsonBuilder;
  I, J, K: Integer;
  Doc: IJsonDocument;
  LKey: string;
  LSeen: array of string;
  LSeenAlready: Boolean;
begin
  Result := '';
  B := nil;
  LSeen := nil;
  for I := 0 to High(ATexts) do
  begin
    if ATexts[I] = '' then
      Continue;
    Doc := JsonParse(ATexts[I]);
    if Doc.HasError or (not Doc.Root.IsObject) then
      Continue;                        { 防御：捕获产物恒为合法 object，坏值跳过 }
    if B = nil then
    begin
      B := JsonBuilder;
      B.BeginObject;
    end;
    for J := 0 to Integer(Doc.Root.ObjectLen) - 1 do
    begin
      LKey := Doc.Root.ObjectKeyAt(UInt32(J)).ToString;
      LSeenAlready := False;
      for K := 0 to High(LSeen) do     { 重名后者胜：跳过已写键 }
        if LSeen[K] = LKey then
        begin
          LSeenAlready := True;
          Break;
        end;
      if LSeenAlready then
        Continue;
      SetLength(LSeen, Length(LSeen) + 1);
      LSeen[High(LSeen)] := LKey;
      B.Key(LKey);
      B.RawJson(JsonStringify(Doc.Root.ObjectValueAt(UInt32(J))));
    end;
  end;
  if B <> nil then
  begin
    B.EndObject;
    Result := B.ToString;
  end;
end;

end.
