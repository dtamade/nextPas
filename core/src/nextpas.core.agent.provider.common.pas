{**
 * nextpas.core.agent.provider.common - 两厂商适配器共享 helper。
 *
 * 契约权威：core/docs/agent/WIRE-MAPPINGS §0（公共规则）、ERRORS.md §3/§6、
 * SECURITY.md §3。实现与文档冲突时先改文档。
 *}

unit nextpas.core.agent.provider.common;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.log.intf,
  nextpas.core.text.conv,
  nextpas.core.json,
  nextpas.core.json.builder,
  nextpas.core.agent.base,
  nextpas.core.agent.errors,
  nextpas.core.agent.intf;

type
  { provider 选项公共段（API.md §3.1）：两厂商选项 record 内嵌。
    Transport 注入点供测试/装饰器替换；nil → 生产 http transport }
  TProviderOptions = record
    ApiKey: string;                  { 空 → Complete 时抛 aecConfig }
    BaseUrl: string;                 { 空 → 厂商官方默认（各适配器常量）}
    Model: string;                   { 回退默认；生效序 request.Model > 本值 }
    ConnectTimeoutMs: Int64;         { 默认 10_000 }
    TotalTimeoutMs: Int64;           { 默认 300_000（LLM 长尾合理值）}
    Transport: IAgentTransport;
    Logger: ILogger;                 { nil → NullLogger 零开销 }
    ExtraHeaders: TWireHeaderArray;
  end;

const
  CMaxRawBodySnippetBytes = 8 * 1024;   { ERRORS §6：RawBodySnippet 上限 }
  CMaxExtraKeys = 64;                   { SECURITY §3：未知键捕获上限 }

{ UTF-8 安全截断：最多回退 3 字节到序列边界，绝不产出半字符 }
function Utf8SafeTruncate(const S: string; AMaxBytes: Integer): string;

{ 超窗措辞识别（不区分大小写；WIRE-MAPPINGS §0 全集）}
function MatchesOverflowPhrases(const AMsg: string): Boolean;

{ retry-after-ms 头优先，其次秒级 retry-after；HTTP-date 形态不解析
  → CRetryAfterUnknown（不臆造）}
function ParseRetryAfterMs(const AHeaders: TWireHeaderArray): Int64;

{ x-request-id / request-id / anthropic-request-id 依次探测，未命中空串 }
function ProbeRequestId(const AHeaders: TWireHeaderArray): string;

{ 上游错误体提取 error.message（两厂商信封同形；无则空串）}
function ExtractErrorMessage(const ABody: string): string;

{ 上游非 2xx 错误信封分类（ERRORS.md §3 算法）：返回待 raise 的异常实例。
  400 + 超窗措辞覆盖为 aecContextOverflow；429 解析 Retry-After }
function BuildUpstreamError(const AProvider, ABody: string;
  AStatus: Integer; const AHeaders: TWireHeaderArray): EAgentError;

{ 解码侧 Extra 无损捕获：AValue 对象中不在 AKnownKeys 内的键原值捕获为
  JSON object 文本；超过 ALimit 键丢弃并 warn。无捕获返回空串 }
function CaptureExtraJson(const AValue: TJsonValue;
  const AKnownKeys: array of string; ALimit: Integer;
  const ALog: ILogger): TJsonText;

{ 编码侧 Extra 回注：把 AExtraJson 的键写入已打开的 builder 对象；
  与 AKnownNames 冲突的键让位跳过（WIRE-MAPPINGS §0 Extra 冲突规则）}
procedure WriteExtraFields(const ABld: IJsonBuilder;
  const AExtraJson: TJsonText; const AKnownNames: array of string);

implementation

function Utf8SafeTruncate(const S: string; AMaxBytes: Integer): string;
var
  LCut, LBack: Integer;
begin
  if AMaxBytes <= 0 then
    Exit('');
  if Length(S) <= AMaxBytes then
    Exit(S);
  LCut := AMaxBytes;
  { 回退连续字节（continuation bytes），上限 3——防畸形序列死循环 }
  LBack := 0;
  while (LCut > 0) and (LBack < 3) and
    ((Ord(S[LCut]) and $C0) = $80) do
  begin
    Dec(LCut);
    Inc(LBack);
  end;
  Result := Copy(S, 1, LCut);
end;

function MatchesOverflowPhrases(const AMsg: string): Boolean;
const
  PHRASES: array[0..5] of string = (
    'context length',
    'maximum context',
    'token limit',
    'too many tokens',
    'context_length_exceeded',
    'prompt is too long'
  );
var
  LLower: string;
  I: Integer;
begin
  LLower := LowerCase(AMsg);
  Result := False;
  for I := Low(PHRASES) to High(PHRASES) do
    if Pos(PHRASES[I], LLower) > 0 then
      Exit(True);
end;

function ParsePlainInt64(const S: string; out AValue: Int64): Boolean;
var
  LCode: Integer;
begin
  Val(S, AValue, LCode);
  Result := (LCode = 0) and (Length(S) > 0);
end;

function ParseRetryAfterMs(const AHeaders: TWireHeaderArray): Int64;
var
  LRaw: string;
  LSecs: Int64;
begin
  LRaw := WireHeaderValue(AHeaders, 'retry-after-ms');
  if ParsePlainInt64(Trim(LRaw), Result) then
    Exit;
  LRaw := Trim(WireHeaderValue(AHeaders, 'retry-after'));
  if ParsePlainInt64(LRaw, LSecs) and (LSecs >= 0) then
    Exit(LSecs * 1000);              { 秒级头 ×1000 }
  Result := CRetryAfterUnknown;      { HTTP-date / 缺失：不臆造 }
end;

function ProbeRequestId(const AHeaders: TWireHeaderArray): string;
begin
  Result := WireHeaderValue(AHeaders, 'x-request-id');
  if Result <> '' then
    Exit;
  Result := WireHeaderValue(AHeaders, 'request-id');
  if Result <> '' then
    Exit;
  Result := WireHeaderValue(AHeaders, 'anthropic-request-id');
end;

function ExtractErrorMessage(const ABody: string): string;
var
  Doc: IJsonDocument;
  LErr, LMsg: TJsonValue;
begin
  Result := '';
  if ABody = '' then
    Exit;
  Doc := JsonParse(ABody);
  if Doc.HasError then
    Exit;
  LErr := Doc.Root.Get('error');
  if LErr.IsObject then
  begin
    LMsg := LErr.Get('message');
    if LMsg.IsStr then
      Exit(LMsg.AsStr.ToString);
    Exit('');
  end;
  { xAI 扁平信封（error 是字符串而非对象，sub2api 生产确认两种形态并存）：
    code 为 "invalid-argument" 之类、error 直接承载消息文本 }
  if LErr.IsStr then
    Exit(LErr.AsStr.ToString);
end;

function BuildUpstreamError(const AProvider, ABody: string;
  AStatus: Integer; const AHeaders: TWireHeaderArray): EAgentError;
var
  LSnippet, LMsg, LRequestId: string;
  LCode: TAgentErrorCode;
  LRetryAfterMs: Int64;
begin
  LSnippet := Utf8SafeTruncate(ABody, CMaxRawBodySnippetBytes);
  LMsg := ExtractErrorMessage(ABody);
  if LMsg = '' then
    LMsg := 'upstream status ' + IntToStr(AStatus);
  LCode := ErrorCodeForStatus(AStatus);
  if (LCode = aecInvalidRequest) and MatchesOverflowPhrases(LMsg) then
    LCode := aecContextOverflow;     { 覆盖 400 归因 }
  if AStatus = 429 then
    LRetryAfterMs := ParseRetryAfterMs(AHeaders)
  else
    LRetryAfterMs := CRetryAfterUnknown;
  LRequestId := ProbeRequestId(AHeaders);
  Result := EAgentError.CreateUpstream(LCode, AProvider, LMsg,
    LRequestId, LSnippet, LRetryAfterMs);
end;

function CaptureExtraJson(const AValue: TJsonValue;
  const AKnownKeys: array of string; ALimit: Integer;
  const ALog: ILogger): TJsonText;
var
  LBld: IJsonBuilder;
  I, J: Integer;
  LKey: string;
  LKnown: Boolean;
  LCaptured: Integer;
begin
  Result := '';
  if not AValue.IsObject then
    Exit;
  LBld := JsonBuilder;
  LBld.BeginObject;
  LCaptured := 0;
  for I := 0 to Integer(AValue.ObjectLen) - 1 do
  begin
    LKey := AValue.ObjectKeyAt(UInt32(I)).ToString;
    LKnown := False;
    for J := Low(AKnownKeys) to High(AKnownKeys) do
      if AKnownKeys[J] = LKey then
      begin
        LKnown := True;
        Break;
      end;
    if LKnown then
      Continue;
    if LCaptured >= ALimit then
    begin
      if ALog <> nil then
        ALog.Warn('agent.extra: capture limit reached, dropping key '
          + LKey);
      Break;
    end;
    LBld.Key(LKey);
    LBld.RawJson(JsonStringify(AValue.ObjectGet(LKey)));
    Inc(LCaptured);
  end;
  if LCaptured > 0 then
  begin
    LBld.EndObject;
    Result := LBld.ToString;
  end;
end;

procedure WriteExtraFields(const ABld: IJsonBuilder;
  const AExtraJson: TJsonText; const AKnownNames: array of string);
var
  Doc: IJsonDocument;
  Root: TJsonValue;
  I, J: Integer;
  LKey: string;
  LKnown: Boolean;
begin
  if AExtraJson = '' then
    Exit;
  Doc := JsonParse(AExtraJson);
  if Doc.HasError or (not Doc.Root.IsObject) then
    Exit;                            { 词表保证 owned JSON 文本；防御坏输入 }
  Root := Doc.Root;
  for I := 0 to Integer(Root.ObjectLen) - 1 do
  begin
    LKey := Root.ObjectKeyAt(UInt32(I)).ToString;
    LKnown := False;
    for J := Low(AKnownNames) to High(AKnownNames) do
      if AKnownNames[J] = LKey then
      begin
        LKnown := True;
        Break;
      end;
    if LKnown then
      Continue;                      { 已知字段胜出，Extra 让位 }
    ABld.Key(LKey);
    ABld.RawJson(JsonStringify(Root.ObjectGet(LKey)));
  end;
end;

end.
