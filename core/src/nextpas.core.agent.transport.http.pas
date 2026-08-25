{**
 * nextpas.core.agent.transport.http - 生产 IAgentTransport。
 *
 * 契约权威：core/docs/agent/API.md §3、ARCHITECTURE §3.2（真增量数据流）、
 * ERRORS.md §1（非 2xx 在此归约为错误码，adapter 见不到裸状态码）。
 *
 * 流式真增量：h1 client 的 Send 会读完整响应才返回，因此 OpenStream 把
 * Send 放到专属 worker 线程执行；ResponseBodyChunk 回调把字节喂给
 * agent.sse 解析器并经通道交付消费方。NextEvent 以 100ms 切片等待，
 * 取消延迟上界一个切片。硬中断（W2）：流持有 IHttpCancelToken 并注入
 * 请求——Cancel 联动在途 Send 的 mid-IO 轮询随即抛 hekCanceled；
 * 消费方主动取消的回声按 D2 以 EOF 形态呈现。
 *}

unit nextpas.core.agent.transport.http;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.sync.intf,
  nextpas.core.sync.mutex,
  nextpas.core.stopwatch,
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
      FHttpCancel: IHttpCancelToken;  { 硬中断：Cancel 联动在途 Send（W2）}
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
      { ---- 终态幂等（仅消费方线程触碰）---- }
      FDone: Boolean;
      FLastErrCode: TAgentErrorCode; { aecNone=自然 EOF；否则重复抛 }
      FLastErrMsg: string;
      { ---- 流式空闲卫生（W7，WIRE-MAPPINGS §0）----
        FSw Create 后仅读；FLastProgressMs worker 写/消费方读，
        8 字节对齐读写两平台均原子；FReadIdleMs Start 冻结后只读 }
      FSw: TStopwatch;
      FLastProgressMs: Int64;
      FReadIdleMs: Int64;
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
  { builder 方法返回修改副本：必须链式接住返回值，语句式调用会把
    标量设置丢在临时副本上（Header 例外——共享 IHttpHeaders 可变）}
  B := THttpRequestBuilder.Create(hmPost, AReq.Url)
    .ContentType('application/json');
  for I := 0 to High(AReq.Headers) do
    B := B.Header(AReq.Headers[I].Name, AReq.Headers[I].Value);
  if AReq.TotalTimeoutMs <> CTimeoutDefault then
    B := B.Timeout(AReq.TotalTimeoutMs);
  if Assigned(AChunkProc) then
    B := B.ResponseBodyChunk(AChunkProc).SkipBodyBuffer;
  if Assigned(AStatusProc) then
    B := B.ResponseStatus(AStatusProc);
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
  { worker 可能仍在 Send 中：先硬取消在途请求再等收尾——等待上界从
    "请求超时（至多 TotalTimeout 300s）"缩到 IO 切片级；消费方仍应优先
    显式 Cancel。W2 复核结论：每流专属 worker 保留（长生命周期流的正确
    形态），Destroy 确定性由硬取消保证 }
  if FWorker <> nil then
  begin
    if FHttpCancel <> nil then
      FHttpCancel.Cancel;
    FWorker.WaitFor;
    FWorker.Free;
    FWorker := nil;
  end;
  FParser.Free;
  { 通道是裸类引用（非接口持有），必须显式释放：对象 + 内部环形缓冲
    （256×40B）每流约 10.3KB，漏 Free 即每流泄漏一对块 }
  FChannel.Free;
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
  FHttpCancel := NewHttpCancelToken;
  { W7 空闲卫生：计时起点=Start（覆盖连接与首响应头等待期）}
  FReadIdleMs := AReq.ReadIdleTimeoutMs;
  FLastProgressMs := 0;
  FSw := TStopwatch.StartNew;
  { builder 方法返回修改副本：链式接住返回值（同 BuildPostRequest 注释）}
  B := THttpRequestBuilder.Create(hmPost, AReq.Url)
    .ContentType('application/json');
  for I := 0 to High(AReq.Headers) do
    B := B.Header(AReq.Headers[I].Name, AReq.Headers[I].Value);
  if AReq.TotalTimeoutMs <> CTimeoutDefault then
    B := B.Timeout(AReq.TotalTimeoutMs);
  { 硬中断贯通：worker 的在途 Send 在 mid-IO 切片轮询此令牌 }
  { SSE 路径：体不缓冲，逐块直投回调（h1 client 设计意图）}
  B := B.CancelToken(FHttpCancel)
    .ResponseBodyChunk(@OnBodyChunk)
    .ResponseStatus(@OnResponseStatus)
    .SkipBodyBuffer;
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
  FLastProgressMs := FSw.ElapsedMs;   { W7：响应头到达即进展 }
  FStatus := Integer(AStatus);
  FIsErrorResp := (FStatus < 200) or (FStatus > 299);
  PushMsg(MsgStatus(FStatus));
end;

procedure TWireStream.OnBodyChunk(const AData: PByte; ASize: SizeUInt);
begin
  FLastProgressMs := FSw.ElapsedMs;   { W7：任何字节到达即进展（含错误体）}
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
  { 终态幂等：EOF 后再调返回 False，错误后再调重抛同一错误——
    消费方误用不挂起。终态仅消费方线程写，无需加锁 }
  if FDone then
  begin
    if FLastErrCode <> aecNone then
      raise EAgentError.CreateLocal(FLastErrCode, FLastErrMsg);
    Exit(False);
  end;
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
          begin
            FDone := True;
            Exit(False);
          end;
        wmkError:
          begin
            { 消费方主动取消引发的 hekCanceled 回声：按 D2 以 EOF 形态
              呈现，不抛——判定取消永远看 GetCancelled }
            if (LMsg.ErrCode = aecCancelled) and GetCancelled then
            begin
              FDone := True;
              Exit(False);
            end;
            FDone := True;
            FLastErrCode := LMsg.ErrCode;
            FLastErrMsg := LMsg.ErrMsg;
            raise EAgentError.CreateLocal(LMsg.ErrCode, LMsg.ErrMsg);
          end;
      end;
    end;
    if GetCancelled then
    begin
      FDone := True;                 { 取消即终态：后续调用直接 False }
      Exit(False);                   { 取消优先于一切后续事件 }
    end;
    { W7 空闲卫生：取消判定之后——对端僵死不冒充消费方取消。
      硬中断在途 IO 回收 worker，但不置 FCancelled，GetCancelled 保持
      False 供消费方区分"我取消"与"对端僵死" }
    if (FReadIdleMs > CTimeoutDefault) and
       ((FSw.ElapsedMs - FLastProgressMs) > FReadIdleMs) then
    begin
      FDone := True;
      FLastErrCode := aecTimeout;
      FLastErrMsg := 'http transport: no stream data for ' +
        IntToStr(FReadIdleMs) + 'ms (read idle timeout)';
      if FHttpCancel <> nil then
        FHttpCancel.Cancel;
      FChannel.Close;                { 唤醒阻塞中的 ReceiveTimeout }
      raise EAgentError.CreateLocal(FLastErrCode, FLastErrMsg);
    end;
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
  { 硬中断：worker 在途 Send 的 mid-IO 轮询随即抛 hekCanceled（W2）}
  if FHttpCancel <> nil then
    FHttpCancel.Cancel;
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
