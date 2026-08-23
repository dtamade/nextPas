{**
 * nextpas.core.agent.transport.http - 生产 IAgentTransport。
 *
 * 契约权威：core/docs/agent/API.md §3、ARCHITECTURE §3.2（真增量数据流）、
 * ERRORS.md §1（非 2xx 在此归约为错误码，adapter 见不到裸状态码）。
 *
 * 流式真增量：h1 client 的 Send 会读完整响应才返回，因此 OpenStream 把
 * Send 放到专属 worker 线程执行；ResponseBodyChunk 回调把字节喂给
 * agent.sse 解析器并经通道交付消费方。NextEvent 以 100ms 切片等待，
 * 取消延迟上界一个切片。W1 为协作式取消；硬中断（IHttpCancelToken 贯通）
 * 属 ROADMAP W2。
 *}

unit nextpas.core.agent.transport.http;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.sync.intf,
  nextpas.core.sync.mutex,
  nextpas.core.io.intf,
  nextpas.core.thread.base,
  nextpas.core.thread.channel,
  nextpas.core.http.intf,
  nextpas.core.http.client,
  nextpas.core.agent.base,
  nextpas.core.agent.errors,
  nextpas.core.agent.intf;

{ AProviderName 用于传输层错误的 Provider 归因（'openai'/'anthropic'；
  空串=本地无前缀）。适配器工厂构造默认 transport 时传入各自名字 }
function NewHttpTransport(const AProviderName: string): IAgentTransport;

{ 注入既有 http client（超时/连接池由构造方定制）}
function NewHttpTransportWithClient(const AProviderName: string;
  const AClient: IHttpClient): IAgentTransport;

implementation

uses
  nextpas.core.http.base,
  nextpas.core.exception,
  nextpas.core.http.message,
  nextpas.core.agent.provider.common,
  nextpas.core.agent.sse;

const
  CReadChunkBytes = 32 * 1024;      { PERFORMANCE §2 读块尺寸 }
  CWaitSliceNs = 100 * 1000 * 1000; { NextEvent 等待切片：100ms }
  CMaxErrorBodyBytes = 64 * 1024;   { 错误体累积封顶：信封摘要只需 8KB
                                      （CMaxRawBodySnippetBytes），留 8 倍裕度 }

type
  { ---- wire 消息通道载荷 ---- }

  TWireMsgKind = (wmkSSE, wmkStatus, wmkEOF, wmkError);

  TTWireMsg = record
    Kind: TWireMsgKind;
    Event: TWireSSEEvent;
    Status: Integer;
    ErrCode: TAgentErrorCode;
    ErrMsg: string;
  end;

  TWireMsgChannel = specialize TChannel<TTWireMsg>;

function MsgSSE(const AEvent: TWireSSEEvent): TTWireMsg;
begin
  Result := Default(TTWireMsg);
  Result.Kind := wmkSSE;
  Result.Event := AEvent;
end;

function MsgStatus(AStatus: Integer): TTWireMsg;
begin
  Result := Default(TTWireMsg);
  Result.Kind := wmkStatus;
  Result.Status := AStatus;
end;

function MsgEOF: TTWireMsg;
begin
  Result := Default(TTWireMsg);
  Result.Kind := wmkEOF;
end;

function MsgError(ACode: TAgentErrorCode; const AText: string): TTWireMsg;
begin
  Result := Default(TTWireMsg);
  Result.Kind := wmkError;
  Result.ErrCode := ACode;
  Result.ErrMsg := AText;
end;

{ ---- 公共 helper ---- }
type
  { ---- 流式会话 ----
    worker 线程跑阻塞 Send；消费方线程经通道拉事件。
    线程模型决策：每流专属 worker（非 IThreadPool）是刻意选择——
    流生命周期以秒~分钟计，池化 worker 同样会被钉死整个流期，
    且 Destroy 依赖 WaitFor 获得确定性收尾；W2 取消贯通时复核此结论。
    一实例一次流，不复用（intf 契约：流不跨消息复用）}
    TWireStream = class(TInterfacedObject, IAgentWireStream)
    private type
      TWorker = class(TWorkerThread)
      private
        FStream: TObject;            { 裸回引；Destroy 时序保证存活 }
      public
        constructor Create(const AStream: TObject);
        procedure Execute; override;
      end;
    private
      FProvider: string;
      FClient: IHttpClient;
      FRequest: IHttpRequest;
      FChannel: TWireMsgChannel;
      FLock: IMutex;                 { 仅护 FCancelled 标志 }
      FCancelled: Boolean;
      FWorker: TWorker;
      { ---- 以下仅 worker 线程触碰 ---- }
      FParser: TSSEParser;
      FStatus: Integer;
      FIsErrorResp: Boolean;         { HTTP 层非 2xx：体走错误累积 }
      FDead: Boolean;                { 流已失败：后续 chunk 弃置 }
      FErrBody: string;
      procedure PushMsg(const AMsg: TTWireMsg);
      procedure DrainParser;
      procedure PushErrorObj(const AErr: EAgentError);
      procedure MapAndPushHttpException(const AErr: EHttpError);
      procedure OnResponseStatus(const AStatus: THttpStatus);
      procedure OnBodyChunk(const AData: PByte; ASize: SizeUInt);
      procedure ExecuteStream;
    public
      constructor Create(const AProviderName: string;
        const AClient: IHttpClient);
      destructor Destroy; override;
      procedure Start(const AReq: TWireRequest);
      { IAgentWireStream }
      function NextEvent(out AEvent: TWireSSEEvent): Boolean;
      procedure Cancel;
      function GetCancelled: Boolean;
    end;

  { ---- 生产传输 ---- }
  THttpTransport = class(TInterfacedObject, IAgentTransport)
  private
    FProvider: string;
    FClient: IHttpClient;
  public
    constructor Create(const AProviderName: string;
      const AClient: IHttpClient);
    procedure RoundTrip(const AReq: TWireRequest; out AResp: TWireResponse);
    function OpenStream(const AReq: TWireRequest): IAgentWireStream;
  end;

function NewHttpTransportWithClient(const AProviderName: string;
  const AClient: IHttpClient): IAgentTransport;
begin
  Result := THttpTransport.Create(AProviderName, AClient);
end;

function NewHttpTransport(const AProviderName: string): IAgentTransport;
begin
  Result := NewHttpTransportWithClient(AProviderName, NewHttpClient);
end;

function HeadersToArray(const AHeaders: IHttpHeaders): TWireHeaderArray;
var
  LN, LIdx: Integer;
  LArr: TWireHeaderArray;
begin
  LN := AHeaders.Count;
  SetLength(LArr, LN);
  LIdx := 0;
  AHeaders.ForEach(
    procedure(const AName, AValue: string)
    begin
      if LIdx < LN then
      begin
        LArr[LIdx].Name := AName;
        LArr[LIdx].Value := AValue;
        Inc(LIdx);
      end;
    end);
  Result := LArr;
end;

function ReadAllBody(const AReader: IReader): string;
const
  CInitialCapBytes = 64 * 1024;
var
  LBuf: array of Byte;
  LAcc: string;
  LCap: SizeInt;
  LN: SizeUInt;
  LTotal: SizeInt;
begin
  SetLength(LBuf, CReadChunkBytes);
  { 倍增预分配：避免逐 chunk SetLength 的 O(n²) 重拷 }
  LCap := CInitialCapBytes;
  SetLength(LAcc, LCap);
  LTotal := 0;
  repeat
    LN := AReader.Read(LBuf[0], CReadChunkBytes);
    if LN = 0 then
      Break;
    while LTotal + SizeInt(LN) > LCap do
    begin
      LCap := LCap * 2;
      SetLength(LAcc, LCap);
    end;
    Move(LBuf[0], PAnsiChar(@LAcc[LTotal + 1])^, LN);
    Inc(LTotal, SizeInt(LN));
  until False;
  Result := Copy(LAcc, 1, LTotal);   { 收口到实际长度，一次分配 }
end;

function BuildPostRequest(const AReq: TWireRequest;
  const AStatusProc: THttpResponseStatusProc = nil;
  const AChunkProc: THttpResponseBodyChunkProc = nil): IHttpRequest;
var
  B: THttpRequestBuilder;
  I: Integer;
begin
  B := THttpRequestBuilder.Create(hmPost, AReq.Url);
  B.ContentType('application/json');
  for I := 0 to High(AReq.Headers) do
    B.Header(AReq.Headers[I].Name, AReq.Headers[I].Value);
  if AReq.TotalTimeoutMs <> CTimeoutDefault then
    B.Timeout(AReq.TotalTimeoutMs);
  if Assigned(AChunkProc) then
  begin
    { SSE 路径：体不缓冲，逐块直投回调（h1 client 设计意图）}
    B.ResponseBodyChunk(AChunkProc);
    B.SkipBodyBuffer;
  end;
  if Assigned(AStatusProc) then
    B.ResponseStatus(AStatusProc);
  Result := B.Body(AReq.BodyJson).Build;
end;

{ ---- THttpTransport（非流式路径）---- }

constructor THttpTransport.Create(const AProviderName: string;
  const AClient: IHttpClient);
begin
  inherited Create;
  FProvider := AProviderName;
  FClient := AClient;
end;

procedure THttpTransport.RoundTrip(const AReq: TWireRequest;
  out AResp: TWireResponse);
var
  LResp: IHttpResponse;
  LHdrs: TWireHeaderArray;
  LBody: string;
  LStatus: Integer;
begin
  try
    LResp := FClient.Send(BuildPostRequest(AReq));
  except
    on HE: EHttpError do
    begin
      case HE.Kind of
        hekTimeout:  raise EAgentError.CreateLocal(aecTimeout,
                       'http transport: ' + HE.Message);
        hekCanceled: raise EAgentCancelled.Create;
        hekProtocol,
        hekParse:    raise EAgentError.CreateLocal(aecProtocol,
                       'http transport: ' + HE.Message);
      else
        raise EAgentError.CreateLocal(aecTransport,
          'http transport: ' + HE.Message);
      end;
    end;
  end;
  try
    LHdrs := HeadersToArray(LResp.Headers);
    LBody := ReadAllBody(LResp.Body);
    LStatus := Integer(LResp.StatusCode);
    AResp.StatusCode := LStatus;
    AResp.Headers := LHdrs;
    AResp.RequestId := ProbeRequestId(LHdrs);
    AResp.BodyText := LBody;
  finally
    LResp.Close;                     { 归还/排空连接体所有权 }
    LResp := nil;
  end;
  if (LStatus < 200) or (LStatus > 299) then
    raise BuildUpstreamError(FProvider, LBody, LStatus, LHdrs);
end;

function THttpTransport.OpenStream(
  const AReq: TWireRequest): IAgentWireStream;
var
  LStream: TWireStream;
begin
  LStream := TWireStream.Create(FProvider, FClient);
  LStream.Start(AReq);
  Result := LStream;
end;

{ ---- TWireStream.TWorker ---- }

constructor TWireStream.TWorker.Create(const AStream: TObject);
begin
  inherited Create;
  FStream := AStream;
end;

procedure TWireStream.TWorker.Execute;
begin
  TWireStream(FStream).ExecuteStream;
end;

{ ---- TWireStream ---- }

constructor TWireStream.Create(const AProviderName: string;
  const AClient: IHttpClient);
begin
  inherited Create;
  FProvider := AProviderName;
  FClient := AClient;
end;

destructor TWireStream.Destroy;
begin
  { worker 可能仍在 Send 中：等其收尾再拆状态（上界为请求超时；
    消费方应先 Cancel 再释放以缩短等待）}
  if FWorker <> nil then
  begin
    FWorker.WaitFor;
    FWorker.Free;
    FWorker := nil;
  end;
  FParser.Free;
  inherited Destroy;
end;

procedure TWireStream.Start(const AReq: TWireRequest);
var
  B: THttpRequestBuilder;
  I: Integer;
begin
  FLock := TMutex.Create;
  FChannel := TWireMsgChannel.Create(256);
  FParser := TSSEParser.Create;
  B := THttpRequestBuilder.Create(hmPost, AReq.Url);
  B.ContentType('application/json');
  for I := 0 to High(AReq.Headers) do
    B.Header(AReq.Headers[I].Name, AReq.Headers[I].Value);
  if AReq.TotalTimeoutMs <> CTimeoutDefault then
    B.Timeout(AReq.TotalTimeoutMs);
  { SSE 路径：体不缓冲，逐块直投回调（h1 client 设计意图）}
  B.ResponseBodyChunk(@OnBodyChunk);
  B.ResponseStatus(@OnResponseStatus);
  B.SkipBodyBuffer;
  FRequest := B.Body(AReq.BodyJson).Build;
  FWorker := TWorker.Create(Self);
  FWorker.Start;
end;

procedure TWireStream.PushMsg(const AMsg: TTWireMsg);
begin
  FChannel.Send(AMsg);
end;

procedure TWireStream.DrainParser;
var
  Ev: TWireSSEEvent;
begin
  while FParser.PopEvent(Ev) do
    PushMsg(MsgSSE(Ev));
end;

procedure TWireStream.PushErrorObj(const AErr: EAgentError);
begin
  try
    PushMsg(MsgError(AErr.ErrorCode, AErr.Message));
  finally
    AErr.Free;
  end;
end;

procedure TWireStream.MapAndPushHttpException(const AErr: EHttpError);
var
  LCode: TAgentErrorCode;
begin
  case AErr.Kind of
    hekTimeout:   LCode := aecTimeout;
    hekCanceled:  LCode := aecCancelled;
    hekProtocol,
    hekParse:     LCode := aecProtocol;
  else
    LCode := aecTransport;
  end;
  PushErrorObj(EAgentError.CreateLocal(LCode,
    'http transport: ' + AErr.Message));
end;

procedure TWireStream.OnResponseStatus(const AStatus: THttpStatus);
begin
  FStatus := Integer(AStatus);
  FIsErrorResp := (FStatus < 200) or (FStatus > 299);
  PushMsg(MsgStatus(FStatus));
end;

procedure TWireStream.OnBodyChunk(const AData: PByte; ASize: SizeUInt);
begin
  if FDead then
    Exit;                            { 失败后到尾的 chunk 一律弃置 }
  if FIsErrorResp then
  begin
    { 非 2xx：累积原始体供错误信封分类（headers 于 Send 返回后统一取）；
      超出封顶即弃置——恶意大 4xx 体不占内存 }
    if Length(FErrBody) < CMaxErrorBodyBytes then
    begin
      SetLength(FErrBody, Length(FErrBody) + SizeInt(ASize));
      Move(AData^, PAnsiChar(@FErrBody[Length(FErrBody) - SizeInt(ASize) + 1])^,
        ASize);
    end;
    Exit;
  end;
  try
    FParser.Feed(TByteSpan.Create(AData, ASize));
    DrainParser;
  except
    on E: EAgentError do
    begin
      { 回调不得跨 cdecl 边界抛出：转经通道交付（ERRORS §6）}
      FDead := True;
      PushErrorObj(EAgentError.CreateLocal(aecProtocol, E.Message));
    end;
  end;
end;

procedure TWireStream.ExecuteStream;
var
  LResp: IHttpResponse;
  LHdrs: TWireHeaderArray;
begin
  LHdrs := nil;
  try
    LResp := FClient.Send(FRequest);
    try
      if FIsErrorResp then
      begin
        LHdrs := HeadersToArray(LResp.Headers);
        PushErrorObj(BuildUpstreamError(FProvider, FErrBody, FStatus, LHdrs));
      end
      else
      begin
        FParser.Finish;              { Q-O4 宽容收口：挂起帧产出 }
        DrainParser;
        PushMsg(MsgEOF);
      end;
    finally
      LResp.Close;
      LResp := nil;
    end;
  except
    on HE: EHttpError do
      MapAndPushHttpException(HE);
    on E: Exception do
      PushErrorObj(EAgentError.CreateLocal(aecTransport,
        'http transport: ' + E.Message));
  end;
end;

function TWireStream.NextEvent(out AEvent: TWireSSEEvent): Boolean;
var
  LMsg: TTWireMsg;
begin
  while True do
  begin
    if FChannel.ReceiveTimeout(LMsg, CWaitSliceNs) then
    begin
      case LMsg.Kind of
        wmkSSE:
          begin
            AEvent := LMsg.Event;
            Exit(True);
          end;
        wmkStatus:
          Continue;                  { 状态仅供内部时序，词表层不可见 }
        wmkEOF:
          Exit(False);
        wmkError:
          raise EAgentError.CreateLocal(LMsg.ErrCode, LMsg.ErrMsg);
      end;
    end;
    if GetCancelled then
      Exit(False);                   { 取消优先于一切后续事件 }
  end;
end;

procedure TWireStream.Cancel;
begin
  FLock.Acquire;
  try
    FCancelled := True;
  finally
    FLock.Release;
  end;
  FChannel.Close;                    { 唤醒阻塞中的 ReceiveTimeout }
end;

function TWireStream.GetCancelled: Boolean;
begin
  FLock.Acquire;
  try
    Result := FCancelled;
  finally
    FLock.Release;
  end;
end;

end.
