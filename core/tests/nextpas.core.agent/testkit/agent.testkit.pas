{**
 * agent.testkit - W1 测试替身（测试树，不进 src/；TESTING.md §3）。
 *
 * TScriptedTransport：按脚本返回 TWireResponse 或逐块投喂流式事件，
 * 保持 chunk 边界（真增量时序断言依赖）；TCapturingLogger：记录全部
 * 日志行供脱敏断言。
 *}

unit agent.testkit;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.log.intf,
  nextpas.core.atomic.core,
  nextpas.core.agent.base,
  nextpas.core.agent.errors,
  nextpas.core.agent.intf,
  nextpas.core.agent.sse;

type
  { 单个脚本响应：非流式取 BodyText；流式按 Chunks 序列投喂。
    RaiseUpstream=True 时按生产 transport 同款算法把非 2xx 归约为
    EAgentError 抛出（含 Provider 归因与 retry-after 解析）——非流式在
    RoundTrip 即抛，流式与生产一致延迟到首个 NextEvent 才抛 }
  TScriptResponse = record
    Status: Integer;
    Headers: TWireHeaderArray;
    BodyText: string;                { 非流式路径全量响应体 }
    Chunks: TStringArray;            { 流式路径：原始 SSE 字节序列 }
    RaiseUpstream: Boolean;
  end;
  TScriptResponseArray = array of TScriptResponse;

  TScriptedTransport = class(TInterfacedObject, IAgentTransport)
  private
    FResponses: TScriptResponseArray;
    FNext: Integer;
    FServed: Integer;
    FLastRequest: TWireRequest;
    FProviderName: string;           { 上游错误归因名（生产为适配器传入）}
    function PopNext: TScriptResponse;
  public
    constructor Create;
    procedure Add(const AResp: TScriptResponse);
    { 最近一次请求快照（URL/头/体断言用）}
    function LastRequest: TWireRequest;
    { 已发出的 wire 请求数（拒绝路径"未发请求"断言用）}
    function ServedCount: Integer;
    property ProviderName: string read FProviderName write FProviderName;
    { IAgentTransport }
    procedure RoundTrip(const AReq: TWireRequest; out AResp: TWireResponse);
    function OpenStream(const AReq: TWireRequest): IAgentWireStream;
  end;

  { 流式回放：NextEvent 拉动式喂块——消费方每取尽解析器队列才喂下一块，
    chunk 边界即事件产出边界（真增量时序可断言）}
  TScriptedWireStream = class(TInterfacedObject, IAgentWireStream)
  private
    FChunks: TStringArray;
    FChunkIdx: Integer;
    FParser: TSSEParser;
    FCancelled: Boolean;
    FFinished: Boolean;
    procedure FeedChunk(const S: string);
  public
    constructor Create(const AChunks: TStringArray);
    destructor Destroy; override;
    function NextEvent(out AEvent: TWireSSEEvent): Boolean;
    procedure Cancel;
    function GetCancelled: Boolean;
  end;

  { 上游错误流：首个 NextEvent 抛脚本指定的 EAgentError，此后终态幂等重抛
    （生产 TWireStream 的 wmkError 行为镜像；WithRetry 首 delta 门测试用）}
  TScriptedFailStream = class(TInterfacedObject, IAgentWireStream)
  private
    FErrCode: TAgentErrorCode;
    FErrMsg: string;
    FDone: Boolean;
    procedure NextEventRaise;
  public
    constructor Create(const AErr: EAgentError);
    function NextEvent(out AEvent: TWireSSEEvent): Boolean;
    procedure Cancel;
    function GetCancelled: Boolean;
  end;

  { 捕获型 ILogger：记录 "级别|消息" 行 }
  TCapturingLogger = class(TInterfacedObject, ILogger)
  private
    FLines: TStringArray;
  public
    procedure Log(const ALevel: TLogLevel; const AMessage: string);
    procedure Trace(const AMessage: string);
    procedure Debug(const AMessage: string);
    procedure Info(const AMessage: string);
    procedure Warn(const AMessage: string);
    procedure Error(const AMessage: string);
    procedure Fatal(const AMessage: string);
    function Lines: TStringArray;    { 副本 }
    function Count: Integer;
    procedure Clear;
  end;

  { 并发峰值探针：原子在飞计数与峰值的真 CAS 提升。
    供 loop 分组调度（W13）、限流、网关扇出等"是否真并行"断言复用。
    Max=观测到的最大并发；Dbg* 暴露 Enter 路径用于精确定位退化 }
  TAgentConcurrencyMeter = class
  private
    FCur: Int32;
    FMax: Int32;
  public
    DbgCalls: Int32;
    DbgBrk: Int32;
    DbgCasFail: Int32;
    DbgLastLNow: Int32;
    DbgLastLOld: Int32;
    function Enter: Int32;
    procedure Leave;
    property Max: Int32 read FMax;
  end;

{ F-M13 WithTools 第二形态便利（base 不依赖 intf 的分层约束，落位 testkit 转发 + src/tools 自由函数） }
function KitWithTools(const ATools: array of IAgentTool): TToolSpecArray;

implementation

uses
  nextpas.core.json,
  nextpas.core.text.conv; // 独立预言机零依赖 provider.common（F-M19）

{ ---- 独立预言机（F-M19）：与生产 BuildUpstreamError 零共享算法的快照 oracle ----
  测试替身自带最小分类器，与 src/provider.common 双实现对照；
  若生产分类器回归，两侧快照不一致即红（test_provider_common 快照对比亦覆盖）。 }

function ScriptedWireHeaderValue(const AHeaders: TWireHeaderArray;
  const AName: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(AHeaders) do
    if SameText(AHeaders[I].Name, AName) then
      Exit(AHeaders[I].Value);
end;

function ScriptedParsePlainInt64(const S: string; out V: Int64): Boolean;
var
  C: Integer;
begin
  Val(S, V, C);
  Result := (C = 0) and (Length(S) > 0);
end;

function ScriptedParseRetryAfterMs(const AHeaders: TWireHeaderArray): Int64;
var
  LRaw: string;
  LSecs: Int64;
  LTmp: Int64;
begin
  LRaw := Trim(ScriptedWireHeaderValue(AHeaders, 'retry-after-ms'));
  if ScriptedParsePlainInt64(LRaw, LTmp) and (LTmp >= 0) then
    Exit(LTmp);
  LRaw := Trim(ScriptedWireHeaderValue(AHeaders, 'retry-after'));
  if ScriptedParsePlainInt64(LRaw, LSecs) and (LSecs >= 0) then
  begin
    // 秒级 ×1000 带溢出钳制（与生产侧同帽不同实现路径）
    if LSecs > High(Int64) div 1000 then
      Exit(High(Int64));
    Exit(LSecs * 1000);
  end;
  Result := CRetryAfterUnknown;
end;

function ScriptedMatchesOverflow(const AMsg: string): Boolean;
const
  PH: array[0..5] of string = (
    'context length','maximum context','token limit',
    'too many tokens','context_length_exceeded','prompt is too long');
var
  L: string;
  I: Integer;
begin
  L := LowerCase(AMsg);
  for I := Low(PH) to High(PH) do
    if Pos(PH[I], L) > 0 then Exit(True);
  Result := False;
end;

function ScriptedExtractErrorMessage(const ABody: string): string;
var
  Doc: IJsonDocument;
  LE, LM: TJsonValue;
begin
  Result := '';
  if ABody = '' then Exit;
  Doc := JsonParse(ABody);
  if Doc.HasError then Exit;
  LE := Doc.Root.Get('error');
  if LE.IsObject then
  begin
    LM := LE.Get('message');
    if LM.IsStr then Exit(LM.AsStr.ToString);
    Exit('');
  end;
  if LE.IsStr then Exit(LE.AsStr.ToString);
end;

function ScriptedProbeRequestId(const AHeaders: TWireHeaderArray): string;
begin
  Result := ScriptedWireHeaderValue(AHeaders, 'x-request-id');
  if Result <> '' then Exit;
  Result := ScriptedWireHeaderValue(AHeaders, 'request-id');
  if Result <> '' then Exit;
  Result := ScriptedWireHeaderValue(AHeaders, 'anthropic-request-id');
end;

function ScriptedBuildUpstreamError(const AProvider, ABody: string;
  AStatus: Integer; const AHeaders: TWireHeaderArray): EAgentError;
var
  LSnippet, LMsg, LRId: string;
  LC: TAgentErrorCode;
  LRA: Int64;
begin
  // RawBodySnippet 独立截断（不复用生产 Utf8SafeTruncate 的共享路径）
  if Length(ABody) > 8192 then
    LSnippet := Copy(ABody, 1, 8192)
  else
    LSnippet := ABody;
  LMsg := ScriptedExtractErrorMessage(ABody);
  if LMsg = '' then
    LMsg := 'upstream status ' + IntToStr(AStatus);
  LC := ErrorCodeForStatus(AStatus);
  if (LC = aecInvalidRequest) and ScriptedMatchesOverflow(LMsg) then
    LC := aecContextOverflow;
  if AStatus = 429 then
    LRA := ScriptedParseRetryAfterMs(AHeaders)
  else
    LRA := CRetryAfterUnknown;
  LRId := ScriptedProbeRequestId(AHeaders);
  Result := EAgentError.CreateUpstream(LC, AProvider, LMsg, LRId, LSnippet, LRA);
end;

{ ---- TScriptedTransport ---- }

constructor TScriptedTransport.Create;
begin
  inherited Create;
  FNext := 0;
end;

function TScriptedTransport.LastRequest: TWireRequest;
begin
  Result := FLastRequest;
end;

function TScriptedTransport.ServedCount: Integer;
begin
  Result := FServed;
end;

procedure TScriptedTransport.Add(const AResp: TScriptResponse);
var
  LN: Integer;
begin
  LN := Length(FResponses);
  SetLength(FResponses, LN + 1);
  FResponses[LN] := AResp;
end;

function TScriptedTransport.PopNext: TScriptResponse;
begin
  if FNext >= Length(FResponses) then
    raise EAgentError.CreateLocal(aecProtocol,
      'scripted transport: script exhausted');
  Result := FResponses[FNext];
  Inc(FNext);
end;

procedure TScriptedTransport.RoundTrip(const AReq: TWireRequest;
  out AResp: TWireResponse);
var
  LScript: TScriptResponse;
begin
  Inc(FServed);
  FLastRequest := AReq;
  LScript := PopNext;
  if LScript.RaiseUpstream and (LScript.Status <> 200) then
    raise ScriptedBuildUpstreamError(FProviderName, LScript.BodyText,
      LScript.Status, LScript.Headers);
  AResp.StatusCode := LScript.Status;
  AResp.Headers := Copy(LScript.Headers, 0, Length(LScript.Headers));
  AResp.RequestId := ScriptedWireHeaderValue(LScript.Headers, 'x-request-id');
  AResp.BodyText := LScript.BodyText;
end;

function TScriptedTransport.OpenStream(
  const AReq: TWireRequest): IAgentWireStream;
var
  LScript: TScriptResponse;
begin
  Inc(FServed);
  FLastRequest := AReq;
  LScript := PopNext;
  if LScript.RaiseUpstream and (LScript.Status <> 200) then
    Exit(TScriptedFailStream.Create(ScriptedBuildUpstreamError(FProviderName,
      LScript.BodyText, LScript.Status, LScript.Headers)));
  Result := TScriptedWireStream.Create(LScript.Chunks);
end;

{ ---- TScriptedFailStream ---- }

constructor TScriptedFailStream.Create(const AErr: EAgentError);
begin
  inherited Create;
  FErrCode := AErr.ErrorCode;
  FErrMsg := AErr.Message;
  FDone := False;
  AErr.Free;
end;

procedure TScriptedFailStream.NextEventRaise;
begin
  raise EAgentError.CreateLocal(FErrCode, FErrMsg);
end;

function TScriptedFailStream.NextEvent(out AEvent: TWireSSEEvent): Boolean;
begin
  { 生产 TWireStream 同款终态幂等：错误后重复调用重抛同一错误 }
  if FDone then
    NextEventRaise;
  FDone := True;
  NextEventRaise;
  Result := False;                   { 不可达 }
end;

procedure TScriptedFailStream.Cancel;
begin
  FDone := True;
end;

function TScriptedFailStream.GetCancelled: Boolean;
begin
  Result := False;
end;

{ ---- TScriptedWireStream ---- }

constructor TScriptedWireStream.Create(const AChunks: TStringArray);
begin
  inherited Create;
  FChunks := Copy(AChunks, 0, Length(AChunks));
  FParser := TSSEParser.Create;
end;

destructor TScriptedWireStream.Destroy;
begin
  FParser.Free;
  inherited Destroy;
end;

procedure TScriptedWireStream.FeedChunk(const S: string);
begin
  if S <> '' then
    FParser.Feed(TByteSpan.Create(@S[1], Length(S)));
end;

function TScriptedWireStream.NextEvent(out AEvent: TWireSSEEvent): Boolean;
label
  Again;
begin
Again:
  if FParser.PopEvent(AEvent) then
    Exit(True);
  if FCancelled then
    Exit(False);
  if FChunkIdx < Length(FChunks) then
  begin
    FeedChunk(FChunks[FChunkIdx]);
    Inc(FChunkIdx);
    goto Again;
  end;
  if not FFinished then
  begin
    FParser.Finish;                  { Q-O4 宽容收口：挂起帧产出 }
    FFinished := True;
    goto Again;
  end;
  Result := False;
end;

procedure TScriptedWireStream.Cancel;
begin
  FCancelled := True;
end;

function TScriptedWireStream.GetCancelled: Boolean;
begin
  Result := FCancelled;
end;

{ ---- TCapturingLogger ---- }

procedure TCapturingLogger.Log(const ALevel: TLogLevel;
  const AMessage: string);
var
  LN: Integer;
begin
  LN := Length(FLines);
  SetLength(FLines, LN + 1);
  FLines[LN] := IntToStr(Ord(ALevel)) + '|' + AMessage;
end;

procedure TCapturingLogger.Trace(const AMessage: string);
begin
  Log(llTrace, AMessage);
end;

procedure TCapturingLogger.Debug(const AMessage: string);
begin
  Log(llDebug, AMessage);
end;

procedure TCapturingLogger.Info(const AMessage: string);
begin
  Log(llInfo, AMessage);
end;

procedure TCapturingLogger.Warn(const AMessage: string);
begin
  Log(llWarn, AMessage);
end;

procedure TCapturingLogger.Error(const AMessage: string);
begin
  Log(llError, AMessage);
end;

procedure TCapturingLogger.Fatal(const AMessage: string);
begin
  Log(llFatal, AMessage);
end;

function TCapturingLogger.Lines: TStringArray;
begin
  Result := Copy(FLines, 0, Length(FLines));
end;

function TCapturingLogger.Count: Integer;
begin
  Result := Length(FLines);
end;

procedure TCapturingLogger.Clear;
begin
  FLines := nil;
end;

{ ---- TAgentConcurrencyMeter ---- }

function TAgentConcurrencyMeter.Enter: Int32;
var
  LNow, LOld, LPrev: Int32;
begin
  Inc(DbgCalls);
  LNow := _backend_xadd_i32(FCur, 1) + 1;
  DbgLastLNow := LNow;
  repeat
    LOld := _backend_xadd_i32(FMax, 0);
    DbgLastLOld := LOld;
    if LNow <= LOld then
    begin
      Inc(DbgBrk);
      Break;
    end;
    LPrev := _backend_cmpxchg_i32(FMax, LNow, LOld);
    if LPrev = LOld then
      Break;
    Inc(DbgCasFail);
  until False;
  Result := LNow;
end;

procedure TAgentConcurrencyMeter.Leave;
begin
  _backend_xadd_i32(FCur, -1);
end;

function KitWithTools(const ATools: array of IAgentTool): TToolSpecArray;
var
  I: Integer;
begin
  SetLength(Result, Length(ATools));
  for I := 0 to High(ATools) do
    Result[I] := ATools[I].Spec;
end;

end.
