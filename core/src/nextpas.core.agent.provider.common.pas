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
  nextpas.core.async.cancellation,
  nextpas.core.text.conv,
  nextpas.core.json,
  nextpas.core.json.builder,
  nextpas.core.text.builder,
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

type
  { 工具槽：跨 chunk 的 index 分桶缓冲。真实世界（sub2api 生产经验）存在
    id+args 先到、name 后到甚至缺失的流。两适配器共用同一分桶机制
    （WIRE-MAPPINGS Q-A6：provider.common 单一实现）}
  TWireToolSlot = record
    Index: Integer;
    Id: string;
    Name: string;
    Args: IStringBuilder;
    Announced: Boolean;
  end;

  { 槽池：单角色独占，不跨消息复用 }
  TWireToolSlotPool = class(TInterfacedObject)
  private
    FSlots: array of TWireToolSlot;
    function GetAnnounced(ASlot: Integer): Boolean;
    function GetHasName(ASlot: Integer): Boolean;
  public
    function Find(AIdx: Integer; out ACreated: Boolean): Integer;
    function Count: Integer;
    { 首个非空 id 生效；宣告前 name 持续更新，宣告后宽容忽略重复元数据 }
    procedure UpdateIdentity(ASlot: Integer; const AId, AName: string);
    procedure AppendArgs(ASlot: Integer; const AFrag: string);
    property Announced[ASlot: Integer]: Boolean read GetAnnounced;
    property HasName[ASlot: Integer]: Boolean read GetHasName;
    { 发 sdkToolCallStart 并冲刷既有缓冲 args——不含调用方随后直出的本片 }
    procedure Announce(ASlot: Integer; var ADeltas: TStreamDeltaArray);
    { Finalize 兜底：未宣告且带任一已知信息的槽全部冲刷并 warn
      （id 可能也缺——词表允许空串，绝不让已收参数片段无声丢失）}
    procedure FlushUnannounced(const ALog: ILogger; const ASrc: string;
      var ADeltas: TStreamDeltaArray);
    destructor Destroy; override;
  end;

  { 线背完成对象（两适配器共用）：wire 流事件→decoder 归约→词表增量
    逐个交付；EOF 收口唯一 fold（DESIGN D1）；sdkError 缓存至 GetMessage
    抛出（ERRORS §6）；弃置未读完即析构 → Cancel 上游流（W2 取消贯通）}
  TWireBackedCompletion = class(TInterfacedObject, IAgentCompletion)
  private
    FStream: IAgentWireStream;
    FDecoder: IAgentWireDecoder;
    FToken: IAsyncCancellationToken;
    FProviderName: string;
    FPending: TStreamDeltaArray;
    FIdx: Integer;
    FAccum: TStreamDeltaArray;
    FSourceDone: Boolean;
    FFolded: Boolean;
    FCancelled: Boolean;
    FMsg: TMessage;
    FErrMsg: string;
    FErrCode: TAgentErrorCode;
    FErrAfterMs: Int64;
    procedure AppendDeltas(const AArr: TStreamDeltaArray);
    procedure CloseOnce;
  public
    constructor Create(const AStream: IAgentWireStream;
      const ADecoder: IAgentWireDecoder;
      const AToken: IAsyncCancellationToken;
      const AProviderName: string);
    destructor Destroy; override;
    function NextDelta(out ADelta: TStreamDelta): Boolean;
    procedure Cancel;
    function GetCancelled: Boolean;
    function GetMessage: TMessage;
    function GetUsage: TTokenUsage;
  end;

{ 词表增量追加（容量倍增由 SetLength 摊还；两适配器与槽池共用）}
procedure AddStreamDelta(var AArr: TStreamDeltaArray;
  const AD: TStreamDelta);

{ UTF-8 安全截断：最多回退 3 字节到序列边界，绝不产出半字符 }
function Utf8SafeTruncate(const S: string; AMaxBytes: Integer): string;

{ 超窗措辞识别（不区分大小写；WIRE-MAPPINGS §0 全集）}
function MatchesOverflowPhrases(const AMsg: string): Boolean;

{ retry-after-ms 头优先，其次秒级 retry-after；负值与 HTTP-date 形态
  一律不信任 → CRetryAfterUnknown（不臆造，防恶意头绕过重试总预算）}
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

uses
  nextpas.core.agent.fold;

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
  if ParsePlainInt64(Trim(LRaw), Result) and (Result >= 0) then
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

{ ---- 共享 wire 流资产 ---- }

procedure AddStreamDelta(var AArr: TStreamDeltaArray;
  const AD: TStreamDelta);
var
  N: Integer;
begin
  N := Length(AArr);
  SetLength(AArr, N + 1);
  AArr[N] := AD;
end;

function TWireToolSlotPool.GetAnnounced(ASlot: Integer): Boolean;
begin
  Result := FSlots[ASlot].Announced;
end;

function TWireToolSlotPool.GetHasName(ASlot: Integer): Boolean;
begin
  Result := FSlots[ASlot].Name <> '';
end;

{ 记录含 string/接口字段：置空触发数组级终结，槽位资产不泄漏 }
destructor TWireToolSlotPool.Destroy;
begin
  SetLength(FSlots, 0);
  inherited Destroy;
end;

function TWireToolSlotPool.Find(AIdx: Integer;
  out ACreated: Boolean): Integer;
var
  I: Integer;
begin
  for I := 0 to High(FSlots) do
    if FSlots[I].Index = AIdx then
    begin
      ACreated := False;
      Exit(I);
    end;
  SetLength(FSlots, Length(FSlots) + 1);
  Result := High(FSlots);
  FSlots[Result] := Default(TWireToolSlot);
  FSlots[Result].Index := AIdx;
  FSlots[Result].Args := MakeStringBuilder;
  ACreated := True;
end;

function TWireToolSlotPool.Count: Integer;
begin
  Result := Length(FSlots);
end;

procedure TWireToolSlotPool.UpdateIdentity(ASlot: Integer;
  const AId, AName: string);
begin
  if (AId <> '') and (FSlots[ASlot].Id = '') then
    FSlots[ASlot].Id := AId;
  if (not FSlots[ASlot].Announced) and (AName <> '') then
    FSlots[ASlot].Name := AName;
end;

procedure TWireToolSlotPool.AppendArgs(ASlot: Integer; const AFrag: string);
begin
  if AFrag <> '' then
    FSlots[ASlot].Args.AppendStr(AFrag);
end;

procedure TWireToolSlotPool.Announce(ASlot: Integer;
  var ADeltas: TStreamDeltaArray);
var
  LD: TStreamDelta;
begin
  LD := Default(TStreamDelta);
  LD.Kind := sdkToolCallStart;
  LD.ToolIndex := FSlots[ASlot].Index;
  LD.ToolCallId := FSlots[ASlot].Id;
  LD.ToolName := FSlots[ASlot].Name;
  AddStreamDelta(ADeltas, LD);
  if FSlots[ASlot].Args.Len > 0 then
  begin
    LD := Default(TStreamDelta);
    LD.Kind := sdkToolCallDelta;
    LD.ToolIndex := FSlots[ASlot].Index;
    LD.ArgumentsDelta := FSlots[ASlot].Args.ToString;
    AddStreamDelta(ADeltas, LD);
  end;
  FSlots[ASlot].Announced := True;
end;

procedure TWireToolSlotPool.FlushUnannounced(const ALog: ILogger;
  const ASrc: string; var ADeltas: TStreamDeltaArray);
var
  I: Integer;
begin
  for I := 0 to High(FSlots) do
    if (not FSlots[I].Announced) and
       ((FSlots[I].Id <> '') or (FSlots[I].Name <> '') or
        (FSlots[I].Args.Len > 0)) then
    begin
      if ALog <> nil then
        ALog.Warn(ASrc + ': flushing tool call slot ' +
          IntToStr(FSlots[I].Index) + ' whose name never arrived');
      Announce(I, ADeltas);
    end;
end;

{ ---- TWireBackedCompletion ---- }

constructor TWireBackedCompletion.Create(const AStream: IAgentWireStream;
  const ADecoder: IAgentWireDecoder;
  const AToken: IAsyncCancellationToken;
  const AProviderName: string);
begin
  inherited Create;
  FStream := AStream;
  FDecoder := ADecoder;
  FToken := AToken;
  FProviderName := AProviderName;
  FIdx := 0;
end;

destructor TWireBackedCompletion.Destroy;
begin
  { 弃置未读完的流：硬取消上游在途请求（transport 联动），不拖到超时 }
  if not FSourceDone then
    Cancel;
  inherited Destroy;
end;

procedure TWireBackedCompletion.AppendDeltas(const AArr: TStreamDeltaArray);
var
  I: Integer;
begin
  for I := 0 to High(AArr) do
  begin
    if AArr[I].Kind = sdkError then
    begin
      { 首个中途错误缓存（ERRORS §6）：GetMessage 时抛出 }
      if FErrMsg = '' then
      begin
        FErrMsg := AArr[I].Error.Message;
        FErrCode := AArr[I].Error.Code;
        FErrAfterMs := AArr[I].Error.RetryAfterMs;
      end;
      Continue;
    end;
    AddStreamDelta(FAccum, AArr[I]);
    AddStreamDelta(FPending, AArr[I]);
  end;
end;

procedure TWireBackedCompletion.CloseOnce;
begin
  if FFolded then
    Exit;
  FFolded := True;
  FoldDeltas(FAccum, FMsg);            { 唯一 fold，EOF 收口一次 }
end;

function TWireBackedCompletion.NextDelta(out ADelta: TStreamDelta): Boolean;
var
  LEv: TWireSSEEvent;
  LArr: TStreamDeltaArray;
begin
  if FCancelled then
    Exit(False);
  if Assigned(FToken) and FToken.IsCancelled then
  begin
    Cancel;
    Exit(False);
  end;
  while FIdx >= Length(FPending) do
  begin
    if FSourceDone then
    begin
      CloseOnce;
      Exit(False);
    end;
    if FStream.NextEvent(LEv) then
    begin
      FDecoder.DecodeEvent(LEv, LArr);
      AppendDeltas(LArr);
    end
    else
    begin
      FSourceDone := True;             { 断连即 EOF，Finalize 收口 }
      FDecoder.Finalize(LArr);
      AppendDeltas(LArr);
    end;
  end;
  ADelta := FPending[FIdx];
  Inc(FIdx);
  Result := True;
end;

procedure TWireBackedCompletion.Cancel;
begin
  FCancelled := True;
  FStream.Cancel;
end;

function TWireBackedCompletion.GetCancelled: Boolean;
begin
  Result := FCancelled or FStream.GetCancelled;
end;

function TWireBackedCompletion.GetMessage: TMessage;
var
  E: EAgentError;
begin
  if not FFolded then
    raise EAgentMisuse.Create('GetMessage before EOF');
  if FErrMsg <> '' then
  begin
    E := EAgentError.CreateUpstream(FErrCode, FProviderName, FErrMsg,
      '', '', FErrAfterMs);
    raise E;
  end;
  Result := FMsg;
end;

function TWireBackedCompletion.GetUsage: TTokenUsage;
begin
  if not FFolded then
    raise EAgentMisuse.Create('GetUsage before EOF');
  Result := FMsg.Usage;
end;

end.
