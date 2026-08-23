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
    FLastRequest: TWireRequest;
    FProviderName: string;           { 上游错误归因名（生产为适配器传入）}
    function PopNext: TScriptResponse;
  public
    constructor Create;
    procedure Add(const AResp: TScriptResponse);
    { 最近一次请求快照（URL/头/体断言用）}
    function LastRequest: TWireRequest;
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

implementation

uses
  nextpas.core.agent.provider.common;

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
  FLastRequest := AReq;
  LScript := PopNext;
  if LScript.RaiseUpstream and (LScript.Status <> 200) then
    raise BuildUpstreamError(FProviderName, LScript.BodyText,
      LScript.Status, LScript.Headers);
  AResp.StatusCode := LScript.Status;
  AResp.Headers := Copy(LScript.Headers, 0, Length(LScript.Headers));
  AResp.RequestId := WireHeaderValue(LScript.Headers, 'x-request-id');
  AResp.BodyText := LScript.BodyText;
end;

function TScriptedTransport.OpenStream(
  const AReq: TWireRequest): IAgentWireStream;
var
  LScript: TScriptResponse;
begin
  FLastRequest := AReq;
  LScript := PopNext;
  if LScript.RaiseUpstream and (LScript.Status <> 200) then
    Exit(TScriptedFailStream.Create(BuildUpstreamError(FProviderName,
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

end.
