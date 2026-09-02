unit nextpas.core.http.impl.h1.conn;
{**
 * @desc H1 server connection state + shared request helpers (poll/serve drivers).
 *       Progress models live in impl.h1.serve (blocking) and impl.h1.poll (epoll).
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.io.intf, nextpas.core.net.intf, nextpas.core.net.server.intf,
  nextpas.core.net.server.base, nextpas.core.platform.io.base,
  nextpas.core.http.base, nextpas.core.http.intf,
  nextpas.core.http.impl.h1.outbound,
  nextpas.core.http.impl.h1.parser,
  nextpas.core.time.deadline,
  nextpas.core.mem.arena.intf,
  nextpas.core.errors;

type
  TH1ServerTransportOptions = record
    ReadTimeout: Int64;
    WriteTimeout: Int64;
    IdleTimeout: Int64;
    MaxHeaderSize: Int32;
    MaxBodySize: Int64;
    MaxRequestsPerConnection: Int32;
    { Connection-scoped LocalArena: Reset per request, attach for handlers. }
    RequestArena: Boolean;
    RequestArenaCapacity: SizeUInt;
    { PreferPollWorkerHandoff: when True, poll-owned path submits each completed
      request to WorkerHandoff (legacy isolation). Default False = reactor-inline
      handler execution for short-request scale (S1-1). Tests that assert handoff
      must set True. }
    PreferPollWorkerHandoff: Boolean;
    { R11: read-abort observation sink (may be nil). Fired when a request
      read deadline expires mid-request; never for idle keep-alive waits. }
    ReadAbortSink: IHttpServerReadAbortSink;
  end;


  TH1ServerConnectionState = class(TInterfacedObject, ITcpServerSession,
    ITcpServerPollDrivenSession, ITcpServerPollDrivenSessionWithDeadline)
  public
    { driver-visible fields/methods for serve/poll units }
    FOptions: TH1ServerTransportOptions;
    FConn: ITcpStream;
    FHandler: IHttpHandler;
    FSessionContext: ITcpServerSessionContext;
    FSocketRuntime: ITcpSocketRuntime;
    FStreamRuntime: ITcpStreamRuntime;
    FWorkerHandoff: ITcpServerWorkerHandoff;
    FParser: IH1Parser;
    FPending: string;
    FKeepAlive: Boolean;
    FReadMs: Int64;
    FIdleMs: Int64;
    FBuf: array[0..16383] of Byte;
    FPollSubmitted: Boolean;
    FPollWorkerPending: Boolean;
    FPollCompletionReady: Boolean;
    FPollCompletionOwnership: TTcpServerConnOwnership;
    FPollNeedRequestReset: Boolean;
    FParseTotalRead: SizeUInt;
    FParseHeadersDone: Boolean;
    FContinueSent: Boolean;
    FPollOutbound: IH1OutboundBuffer;
    FPollResponsePending: Boolean;
    FPollCloseAfterDrain: Boolean;
    FPollQueuedOutbound: IH1OutboundBuffer;
    FPollQueuedResponsePending: Boolean;
    FPollQueuedCloseAfterDrain: Boolean;
    { S2-1: connection-scoped outbound buffer free-list (depth matches poll
      active+queued responses). Avoids NewH1OutboundBuffer per keep-alive
      request on the hot path. }
    FSpareOutbound0: IH1OutboundBuffer;
    FSpareOutbound1: IH1OutboundBuffer;
    FPollReadDeadline: TDeadline;
    FPollReadDeadlineIsIdle: Boolean;
    FPollWriteDeadline: TDeadline;
    FParserIsSnapshot: Boolean;
    FRequestCount: Int32;
    FRequestArena: IArena;
    procedure InvokeHandler(const AReq: IHttpRequest;
      const AW: IHttpResponseWriter);
    procedure ArmPollReadDeadline(const ATimeoutMs: Int64;
      const AIsIdle: Boolean);
    procedure ArmPollRequestReadDeadline;
    procedure ClearPollReadDeadline;
    procedure ResetRequestParser;
    function TryUseFastRequestParser(const ABuf: PAnsiChar; const ALen: SizeUInt;
      out AConsumed: SizeUInt): Boolean;
    procedure ResetPollRequestStateWithDeadline(const ATimeoutMs: Int64;
      const AIsIdle: Boolean);
    procedure ResetPollRequestState;
    procedure PreparePollRequestParse;
    procedure PreparePollKeepAliveRequestParse;
    procedure ResetPollResponseState;
    procedure PromoteQueuedPollResponse;
    function AcquireOutboundBuffer: IH1OutboundBuffer;
    procedure ReleaseOutboundBuffer(var AOutbound: IH1OutboundBuffer);
    function EnqueuePollResponse(const AOutbound: IH1OutboundBuffer;
      const ACloseAfterDrain: Boolean): Boolean;
    function CanParseBufferedPollRequestWhileDraining: Boolean;
    function ShouldWaitForWritableInsteadOfEagerDrain(
      const AEvents: TPlatformPollEvents): Boolean;
    function QueuePollErrorResponse(const AStatus: THttpStatus): Boolean;
    procedure ApplyPollRequestResult(const AOutbound: IH1OutboundBuffer;
      const ACloseAfterDrain: Boolean);
    procedure ArmPollWriteDeadline;
    procedure ArmDirectWriteDeadline;
    { R11: fire the read-abort sink (best-effort, never raises). }
    procedure NotifyReadAbort;
    function UsePollOwnedResponseDrain: Boolean;
    function ExecuteCurrentRequest: TTcpServerConnOwnership;
    function ExecuteCurrentPollRequest(out AOutbound: IH1OutboundBuffer;
      out ACloseAfterDrain: Boolean): TTcpServerConnOwnership;
    constructor Create(const AConn: ITcpStream; const AHandler: IHttpHandler;
      const AOptions: TH1ServerTransportOptions); overload;
    constructor Create(const AConn: ITcpStream; const AHandler: IHttpHandler;
      const AOptions: TH1ServerTransportOptions;
      const AContext: ITcpServerSessionContext); overload;
    function Run: TTcpServerConnOwnership;
    function PollEvents: TPlatformPollEvents;
    function Advance(const AEvents: TPlatformPollEvents;
      out ANextEvents: TPlatformPollEvents;
      out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
    function WakeDeadline: TDeadline;
  end;

function ShouldKeepAlive(const AParser: IH1Parser): Boolean;
function ParserErrorStatus(const AParser: IH1Parser): THttpStatus;
function RequestMetadata(const AParser: IH1Parser): TH1RequestMetadata;
function HasHttp11HostPolicyError(const AParser: IH1Parser): Boolean;
function ShouldSendContinueResponse(const AParser: IH1Parser;
  const AHeadersDone, AContinueSent: Boolean): Boolean;
function HeaderPolicyErrorStatus(const AParser: IH1Parser;
  const AOptions: TH1ServerTransportOptions;
  const ATotalRead: SizeUInt; const AFastSnapshot: Boolean): THttpStatus;
function IsRequestReadFailure(const E: Exception): Boolean;

implementation

uses
  nextpas.core.base, nextpas.core.base.utils,
  nextpas.core.io.base, nextpas.core.io.buffer, nextpas.core.net,
  nextpas.core.time.base, nextpas.core.time,
  nextpas.core.text.conv,
  nextpas.core.http.headers, nextpas.core.http.message,
  nextpas.core.http.static,
  nextpas.core.http.impl.h1.wire,
  nextpas.core.http.impl.h1.prepend,
  nextpas.core.http.impl.h1.fast,
  nextpas.core.http.impl.h1.writer,
  nextpas.core.http.mem,
  nextpas.core.http.middleware.requestarena,
  nextpas.core.http.impl.h1.serve,
  nextpas.core.http.impl.h1.poll,
  nextpas.core.net.async.tlspas;

function ShouldKeepAlive(const AParser: IH1Parser): Boolean; inline;
var
  LMetadata: TH1RequestMetadata;
begin
  LMetadata := AParser.GetRequestMetadata;
  if AParser.GetHttpVersion = hvHttp10 then
    Result := LMetadata.ConnectionKeepAlive
  else
    Result := not LMetadata.ConnectionClose;
end;

function ParserErrorStatus(const AParser: IH1Parser): THttpStatus; inline;
begin
  case AParser.ErrorKind of
    pekNone:
      Result := HTTP_STATUS_BAD_REQUEST;
    pekUnsupportedTransferCoding:
      Result := HTTP_STATUS_NOT_IMPLEMENTED;
  else
    Result := HTTP_STATUS_BAD_REQUEST;
  end;
end;

function RequestMetadata(const AParser: IH1Parser): TH1RequestMetadata; inline;
begin
  if AParser = nil then
    Exit(Default(TH1RequestMetadata));
  Result := AParser.GetRequestMetadata;
end;

function HasHttp11HostPolicyError(const AParser: IH1Parser): Boolean; inline;
var
  LMetadata: TH1RequestMetadata;
begin
  Result := False;
  if (AParser = nil) or (AParser.GetHttpVersion <> hvHttp11) then
    Exit;
  LMetadata := RequestMetadata(AParser);
  Result := (not LMetadata.HasHost) or LMetadata.HasDuplicateHost;
end;

function ShouldSendContinueResponse(const AParser: IH1Parser;
  const AHeadersDone, AContinueSent: Boolean): Boolean; inline;
var
  LMetadata: TH1RequestMetadata;
begin
  LMetadata := RequestMetadata(AParser);
  Result := AHeadersDone and (not AContinueSent) and (AParser <> nil) and
    (not AParser.IsComplete) and LMetadata.ExpectsContinue and
    LMetadata.RequestDeclaresBody;
end;

function HeaderPolicyErrorStatus(const AParser: IH1Parser;
  const AOptions: TH1ServerTransportOptions;
  const ATotalRead: SizeUInt; const AFastSnapshot: Boolean): THttpStatus;
var
  LMetadata: TH1RequestMetadata;
begin
  Result := 0;
  if AParser = nil then
    Exit;

  LMetadata := RequestMetadata(AParser);

  if (AOptions.MaxHeaderSize > 0) and
     (Int64(ATotalRead) - AParser.GetBodySize >
      Int64(AOptions.MaxHeaderSize)) then
    Exit(HTTP_STATUS_HEADER_TOO_LARGE);

  if AParser.HasError then
    Exit(ParserErrorStatus(AParser));

  if HasHttp11HostPolicyError(AParser) then
    Exit(HTTP_STATUS_BAD_REQUEST);

  if AFastSnapshot then
    Exit(0);

  if LMetadata.HasUnsupportedExpect then
    Exit(HTTP_STATUS_EXPECTATION_FAILED);

  if LMetadata.HasInvalidContentLength then
    Exit(HTTP_STATUS_BAD_REQUEST);

  if (AOptions.MaxBodySize > 0) and LMetadata.HasContentLength and
     (LMetadata.DeclaredContentLength > AOptions.MaxBodySize) then
    Exit(HTTP_STATUS_PAYLOAD_TOO_LARGE);
end;

function IsRequestReadFailure(const E: Exception): Boolean;
begin
  Result := False;
  if E = nil then
    Exit(False);
  Result := HttpErrorIsTimeout(E) or (E is ENetworkError) or
    ((E is EHttpError) and (EHttpError(E).Kind = hekConnect));
end;

constructor TH1ServerConnectionState.Create(const AConn: ITcpStream;
  const AHandler: IHttpHandler; const AOptions: TH1ServerTransportOptions);
begin
  Create(AConn, AHandler, AOptions, nil);
end;

constructor TH1ServerConnectionState.Create(const AConn: ITcpStream;
  const AHandler: IHttpHandler; const AOptions: TH1ServerTransportOptions;
  const AContext: ITcpServerSessionContext);
begin
  inherited Create;
  FOptions := AOptions;
  FConn := AConn;
  FHandler := AHandler;
  FSessionContext := AContext;
  Supports(AConn, ITcpSocketRuntime, FSocketRuntime);
  Supports(AConn, ITcpStreamRuntime, FStreamRuntime);
  if AContext <> nil then
    FWorkerHandoff := AContext.WorkerHandoff
  else
    FWorkerHandoff := nil;
  FParser := NewH1RequestParser;
  FPending := '';
  FKeepAlive := True;
  { Connection-scoped request arena: one LocalArena, Reset per request. }
  if AOptions.RequestArena then
    FRequestArena := HttpCreateRequestArena(AOptions.RequestArenaCapacity)
  else
    FRequestArena := nil;
  if FOptions.IdleTimeout > 0 then
    FIdleMs := FOptions.IdleTimeout
  else
    FIdleMs := 30000;
  if FOptions.ReadTimeout > 0 then
    FReadMs := FOptions.ReadTimeout
  else
    FReadMs := FIdleMs;
  FPollSubmitted := False;
  FPollWorkerPending := False;
  FPollCompletionReady := False;
  FPollCompletionOwnership := tscoServer;
  FPollNeedRequestReset := False;
  FParseTotalRead := 0;
  FParseHeadersDone := False;
  FContinueSent := False;
  FPollOutbound := nil;
  FPollResponsePending := False;
  FPollCloseAfterDrain := False;
  FPollQueuedOutbound := nil;
  FPollQueuedResponsePending := False;
  FPollQueuedCloseAfterDrain := False;
  FSpareOutbound0 := nil;
  FSpareOutbound1 := nil;
  FPollReadDeadline := TDeadline.Infinite;
  FPollReadDeadlineIsIdle := False;
  FPollWriteDeadline := TDeadline.Infinite;
  FParserIsSnapshot := False;
  FRequestCount := 0;
  if FStreamRuntime <> nil then
    ArmPollRequestReadDeadline;
end;

function TH1ServerConnectionState.AcquireOutboundBuffer: IH1OutboundBuffer;
begin
  if FSpareOutbound0 <> nil then
  begin
    Result := FSpareOutbound0;
    FSpareOutbound0 := nil;
    Result.Reset;
    Exit;
  end;
  if FSpareOutbound1 <> nil then
  begin
    Result := FSpareOutbound1;
    FSpareOutbound1 := nil;
    Result.Reset;
    Exit;
  end;
  Result := NewH1OutboundBuffer;
end;

procedure TH1ServerConnectionState.ReleaseOutboundBuffer(
  var AOutbound: IH1OutboundBuffer);
begin
  if AOutbound = nil then
    Exit;
  AOutbound.Reset;
  if FSpareOutbound0 = nil then
    FSpareOutbound0 := AOutbound
  else if FSpareOutbound1 = nil then
    FSpareOutbound1 := AOutbound;
  { If both spares are full, drop — refcount frees the buffer. }
  AOutbound := nil;
end;

procedure TH1ServerConnectionState.InvokeHandler(const AReq: IHttpRequest;
  const AW: IHttpResponseWriter);
begin
  if FRequestArena = nil then
  begin
    FHandler.ServeHTTP(AReq, AW);
    Exit;
  end;
  { Connection-scoped LocalArena: Reset → attach → ServeHTTP → detach → Reset. }
  FRequestArena.Reset;
  HttpAttachRequestArena(AReq, FRequestArena);
  try
    FHandler.ServeHTTP(AReq, AW);
  finally
    HttpDetachRequestArena(AReq);
    FRequestArena.Reset;
  end;
end;

procedure TH1ServerConnectionState.ArmPollReadDeadline(const ATimeoutMs: Int64;
  const AIsIdle: Boolean);
begin
  if FStreamRuntime = nil then
    Exit;
  FPollReadDeadline := TDeadline.After(TDuration.FromMilliseconds(ATimeoutMs));
  FPollReadDeadlineIsIdle := AIsIdle;
  FConn.SetReadDeadline(FPollReadDeadline);
end;

procedure TH1ServerConnectionState.ArmPollRequestReadDeadline;
begin
  ArmPollReadDeadline(FReadMs, False);
end;

procedure TH1ServerConnectionState.ClearPollReadDeadline;
begin
  FPollReadDeadline := TDeadline.Infinite;
  FPollReadDeadlineIsIdle := False;
  if FStreamRuntime <> nil then
    FConn.SetReadDeadline(TDeadline.Infinite);
end;

procedure TH1ServerConnectionState.ResetRequestParser;
begin
  if (FParser = nil) or FParserIsSnapshot then
  begin
    FParser := NewH1RequestParser;
    FParserIsSnapshot := False;
  end
  else
    FParser.Reset;
end;

function TH1ServerConnectionState.TryUseFastRequestParser(const ABuf: PAnsiChar;
  const ALen: SizeUInt; out AConsumed: SizeUInt): Boolean;
const
  { Cap body copy into snapshot; larger/streamed bodies stay on llhttp. }
  FAST_PATH_MAX_BODY = 65536;
var
  LFast: TFastParseResult;
begin
  Result := False;
  AConsumed := 0;
  try
    LFast := FastParseRequest(ABuf, ALen);
  except
    { Fast path is optional; any parse fault falls back to llhttp. }
    Exit(False);
  end;

  if (not LFast.Success) or (LFast.Consumed = 0) or
     (LFast.Consumed > ALen) then
    Exit(False);

  { S2-2: fixed-length body allowed when fully buffered and within cap.
    Still reject Expect / Transfer-Encoding / host policy / connection close. }
  if (LFast.Version <> hvHttp11) or
     (LFast.ContentLength < 0) or
     (LFast.ContentLength > FAST_PATH_MAX_BODY) or
     (not LFast.HasHost) or
     LFast.HostRepeated or
     LFast.HasExpect or
     LFast.HasTransferEncoding then
    Exit(False);

  if LFast.HasConnection and
     ((not LFast.ConnectionKeepAlive) or
      LFast.ConnectionClose or
      LFast.ConnectionUnsupported) then
    Exit(False);

  FParser := NewH1FastRequestSnapshot(LFast, ABuf);
  FParserIsSnapshot := True;
  AConsumed := LFast.Consumed;
  Result := True;
end;

procedure TH1ServerConnectionState.ResetPollRequestStateWithDeadline(
  const ATimeoutMs: Int64; const AIsIdle: Boolean);
begin
  ResetRequestParser;
  FParseTotalRead := 0;
  FParseHeadersDone := False;
  FContinueSent := False;
  FPollNeedRequestReset := False;
  ArmPollReadDeadline(ATimeoutMs, AIsIdle);
end;

procedure TH1ServerConnectionState.ResetPollRequestState;
begin
  ResetPollRequestStateWithDeadline(FReadMs, False);
end;

procedure TH1ServerConnectionState.PreparePollRequestParse;
begin
  if FPollNeedRequestReset then
    ResetPollRequestState;
end;

procedure TH1ServerConnectionState.PreparePollKeepAliveRequestParse;
begin
  if not FPollNeedRequestReset then
    Exit;
  if FPending = '' then
    ResetPollRequestStateWithDeadline(FIdleMs, True)
  else
    ResetPollRequestState;
end;

procedure TH1ServerConnectionState.ResetPollResponseState;
begin
  ReleaseOutboundBuffer(FPollOutbound);
  FPollResponsePending := False;
  FPollCloseAfterDrain := False;
  ReleaseOutboundBuffer(FPollQueuedOutbound);
  FPollQueuedResponsePending := False;
  FPollQueuedCloseAfterDrain := False;
  FPollWriteDeadline := TDeadline.Infinite;
end;

procedure TH1ServerConnectionState.PromoteQueuedPollResponse;
begin
  if not FPollQueuedResponsePending then
    Exit;

  FPollOutbound := FPollQueuedOutbound;
  FPollResponsePending := (FPollOutbound <> nil) and (not FPollOutbound.IsEmpty);
  FPollCloseAfterDrain := FPollQueuedCloseAfterDrain;
  FPollQueuedOutbound := nil;
  FPollQueuedResponsePending := False;
  FPollQueuedCloseAfterDrain := False;
  FPollWriteDeadline := TDeadline.Infinite;
end;

function TH1ServerConnectionState.EnqueuePollResponse(
  const AOutbound: IH1OutboundBuffer; const ACloseAfterDrain: Boolean): Boolean;
begin
  if (AOutbound = nil) or AOutbound.IsEmpty then
    Exit(True);

  if not FPollResponsePending then
  begin
    FPollOutbound := AOutbound;
    FPollResponsePending := True;
    FPollCloseAfterDrain := ACloseAfterDrain;
    Exit(True);
  end;

  if not FPollQueuedResponsePending then
  begin
    FPollQueuedOutbound := AOutbound;
    FPollQueuedResponsePending := True;
    FPollQueuedCloseAfterDrain := ACloseAfterDrain;
    Exit(True);
  end;

  Result := False;
end;

function TH1ServerConnectionState.CanParseBufferedPollRequestWhileDraining: Boolean;
begin
  Result := (FOptions.WriteTimeout <= 0) and FKeepAlive and (FPending <> '') and
    FPollResponsePending and
    (not FPollCloseAfterDrain) and (not FPollQueuedResponsePending);
end;

function TH1ServerConnectionState.ShouldWaitForWritableInsteadOfEagerDrain(
  const AEvents: TPlatformPollEvents): Boolean;
begin
  Result := (FPending <> '') and FPollResponsePending and
    FPollQueuedResponsePending and (not (peWritable in AEvents));
end;

function TH1ServerConnectionState.QueuePollErrorResponse(
  const AStatus: THttpStatus): Boolean;
var
  LOutbound: IH1OutboundBuffer;
begin
  LOutbound := AcquireOutboundBuffer;
  WriteErrorResponseToWriter(LOutbound as IWriter, AStatus);
  Result := EnqueuePollResponse(LOutbound, True);
  if not Result then
    ReleaseOutboundBuffer(LOutbound);
end;

procedure TH1ServerConnectionState.ApplyPollRequestResult(
  const AOutbound: IH1OutboundBuffer; const ACloseAfterDrain: Boolean);
begin
  if not EnqueuePollResponse(AOutbound, ACloseAfterDrain) then
  begin
    { Caller still holds the buffer; drop via its refcount. Keep-alive off. }
    FKeepAlive := False;
  end;
end;

procedure TH1ServerConnectionState.ArmPollWriteDeadline;
begin
  if FOptions.WriteTimeout > 0 then
  begin
    FPollWriteDeadline := TDeadline.After(
      TDuration.FromMilliseconds(FOptions.WriteTimeout));
    FConn.SetWriteDeadline(FPollWriteDeadline);
  end
  else
    FPollWriteDeadline := TDeadline.Infinite;
end;

procedure TH1ServerConnectionState.ArmDirectWriteDeadline;
begin
  if FOptions.WriteTimeout > 0 then
    FConn.SetWriteDeadline(TDeadline.After(
      TDuration.FromMilliseconds(FOptions.WriteTimeout)));
end;

procedure TH1ServerConnectionState.NotifyReadAbort;
begin
  { Observation must never break the close path: sink faults are swallowed. }
  if FOptions.ReadAbortSink = nil then
    Exit;
  try
    FOptions.ReadAbortSink.OnReadAbort(FConn.RemoteAddr.ToString);
  except
  end;
end;

function TH1ServerConnectionState.UsePollOwnedResponseDrain: Boolean;
begin
  Result := FStreamRuntime <> nil;
end;

function TH1ServerConnectionState.ExecuteCurrentRequest: TTcpServerConnOwnership;
var
  LReq: IHttpRequest;
  LW: IHttpResponseWriter;
  LBodyReader: IReader;
  LContentLen: Int64;
  LHijackConn: ITcpStream;
  LOutbound: IH1OutboundBuffer;
  LResponseWriter: IWriter;
  LDrainStarted: Boolean;
  LKeepAlive: Boolean;
  LEarly: ITlsPasEarlyDataInfo;
  LEarlyReq: IHttpRequestWithEarlyData;
begin
  Result := tscoServer;
  LW := nil;
  LOutbound := nil;
  LResponseWriter := nil;
  LDrainStarted := False;
  try
    if FParserIsSnapshot then
      LKeepAlive := True
    else
      LKeepAlive := ShouldKeepAlive(FParser);

    { Enforce MaxRequestsPerConnection before writing response headers }
    Inc(FRequestCount);
    if (FOptions.MaxRequestsPerConnection > 0) and
       (FRequestCount >= FOptions.MaxRequestsPerConnection) then
      LKeepAlive := False;
    FKeepAlive := LKeepAlive;

    if HasHttp11HostPolicyError(FParser) then
    begin
      WriteErrorResponse(FConn, HTTP_STATUS_BAD_REQUEST, FOptions.WriteTimeout);
      FKeepAlive := False;
      Exit(tscoServer);
    end;

    LContentLen := FParser.GetBodySize;
    LBodyReader := FParser.NewBodyReader;
    if LBodyReader <> nil then
    begin
      LReq := THttpRequest.CreateFromRequestTarget(FParser.GetMethod,
        FParser.GetUrl, FParser.GetHttpVersion, FParser.GetHeaders,
        LBodyReader, LContentLen);
    end
    else
    begin
      LContentLen := 0;
      LReq := THttpRequest.CreateFromRequestTarget(FParser.GetMethod,
        FParser.GetUrl, FParser.GetHttpVersion, FParser.GetHeaders, nil,
        LContentLen);
    end;

    (LReq as THttpRequest).SetRemoteNetAddr(FConn.RemoteAddr);
    // 0-RTT: propagate TLS early-data flag to request for EarlyDataMiddleware
    if Supports(FConn, ITlsPasEarlyDataInfo, LEarly) then
      if Supports(LReq, IHttpRequestWithEarlyData, LEarlyReq) then
        LEarlyReq.SetWasEarlyData(LEarly.GetWasEarlyDataAccepted);

    if FPending <> '' then
      LHijackConn := TReadPrependTcpStream.Create(FConn, FPending)
    else
      LHijackConn := FConn;
    LOutbound := AcquireOutboundBuffer;
    LResponseWriter := LOutbound as IWriter;
    LW := TH1ResponseWriter.Create(LResponseWriter, LHijackConn,
      LReq.Method = hmHead, FOptions.WriteTimeout);
    (LW as TH1ResponseWriter).AttachSessionContext(FSessionContext);
    { RFC 7231 §7.1.1.2: responses SHOULD carry a Date header. Inject before
      the handler runs; a handler-set date wins (SetHeader replaces). }
    HttpEnsureDateHeader(LW.GetHeaders);
    if LKeepAlive and (FParser.GetHttpVersion = hvHttp10) then
      LW.GetHeaders.SetHeader('connection', 'keep-alive');
    if not LKeepAlive then
      LW.GetHeaders.SetHeader('connection', 'close');

    InvokeHandler(LReq, LW);

    if (LW as TH1ResponseWriter).IsHijacked then
    begin
      Result := tscoHandler;
      FKeepAlive := False;
      FConn.SetReadDeadline(TDeadline.Infinite);
      { Hijack owns the connection; outbound buffer is not reused. }
      LOutbound := nil;
      Exit;
    end;

    (LW as TH1ResponseWriter).FinalizeResponse;
    LDrainStarted := True;
    ArmDirectWriteDeadline;
    LOutbound.DrainAllTo(FConn as IWriter);
    ReleaseOutboundBuffer(LOutbound);

  except
    on E: Exception do
    begin
      if (LW <> nil) and (LW as TH1ResponseWriter).IsHijacked then
        Result := tscoHandler
      else if (LW = nil) or (not (LW as TH1ResponseWriter).HasCommitted) then
        WriteErrorResponse(FConn, HTTP_STATUS_INTERNAL_SERVER_ERROR,
          FOptions.WriteTimeout);
      if (LW <> nil) and (not (LW as TH1ResponseWriter).IsHijacked) and
         (LW as TH1ResponseWriter).HasCommitted and (not LDrainStarted) then
      begin
        try
          if (LOutbound <> nil) and (not LOutbound.IsEmpty) then
          begin
            ArmDirectWriteDeadline;
            LOutbound.DrainAllTo(FConn as IWriter);
          end;
        except
          { Best-effort drain after a committed error response; keep-alive ends. }
        end;
      end;
      ReleaseOutboundBuffer(LOutbound);
      FKeepAlive := False;
    end;
  end;
end;

function TH1ServerConnectionState.ExecuteCurrentPollRequest(
  out AOutbound: IH1OutboundBuffer; out ACloseAfterDrain: Boolean): TTcpServerConnOwnership;
var
  LReq: IHttpRequest;
  LW: IHttpResponseWriter;
  LBodyReader: IReader;
  LContentLen: Int64;
  LHijackConn: ITcpStream;
  LOutbound: IH1OutboundBuffer;
  LResponseWriter: IWriter;
  LKeepAlive: Boolean;
  LEarly: ITlsPasEarlyDataInfo;
  LEarlyReq: IHttpRequestWithEarlyData;
begin
  Result := tscoServer;
  AOutbound := nil;
  ACloseAfterDrain := False;
  LW := nil;
  LOutbound := nil;
  LResponseWriter := nil;
  try
    if FParserIsSnapshot then
      LKeepAlive := True
    else
      LKeepAlive := ShouldKeepAlive(FParser);

    { Enforce MaxRequestsPerConnection before writing response headers }
    Inc(FRequestCount);
    if (FOptions.MaxRequestsPerConnection > 0) and
       (FRequestCount >= FOptions.MaxRequestsPerConnection) then
      LKeepAlive := False;
    FKeepAlive := LKeepAlive;

    if HasHttp11HostPolicyError(FParser) then
    begin
      LOutbound := AcquireOutboundBuffer;
      WriteErrorResponseToWriter(LOutbound as IWriter, HTTP_STATUS_BAD_REQUEST);
      AOutbound := LOutbound;
      ACloseAfterDrain := True;
      Exit(tscoServer);
    end;

    LContentLen := FParser.GetBodySize;
    LBodyReader := FParser.NewBodyReader;
    if LBodyReader <> nil then
    begin
      LReq := THttpRequest.CreateFromRequestTarget(FParser.GetMethod,
        FParser.GetUrl, FParser.GetHttpVersion, FParser.GetHeaders,
        LBodyReader, LContentLen);
    end
    else
    begin
      LContentLen := 0;
      LReq := THttpRequest.CreateFromRequestTarget(FParser.GetMethod,
        FParser.GetUrl, FParser.GetHttpVersion, FParser.GetHeaders, nil,
        LContentLen);
    end;

    (LReq as THttpRequest).SetRemoteNetAddr(FConn.RemoteAddr);
    // 0-RTT: propagate TLS early-data flag to request for EarlyDataMiddleware
    if Supports(FConn, ITlsPasEarlyDataInfo, LEarly) then
      if Supports(LReq, IHttpRequestWithEarlyData, LEarlyReq) then
        LEarlyReq.SetWasEarlyData(LEarly.GetWasEarlyDataAccepted);

    if FPending <> '' then
      LHijackConn := TReadPrependTcpStream.Create(FConn, FPending)
    else
      LHijackConn := FConn;
    LOutbound := AcquireOutboundBuffer;
    LResponseWriter := LOutbound as IWriter;
    LW := TH1ResponseWriter.Create(LResponseWriter, LHijackConn,
      LReq.Method = hmHead, FOptions.WriteTimeout);
    (LW as TH1ResponseWriter).AttachSessionContext(FSessionContext);
    { RFC 7231 §7.1.1.2: responses SHOULD carry a Date header. Inject before
      the handler runs; a handler-set date wins (SetHeader replaces). }
    HttpEnsureDateHeader(LW.GetHeaders);
    if LKeepAlive and (FParser.GetHttpVersion = hvHttp10) then
      LW.GetHeaders.SetHeader('connection', 'keep-alive');
    if not LKeepAlive then
      LW.GetHeaders.SetHeader('connection', 'close');

    InvokeHandler(LReq, LW);

    if (LW as TH1ResponseWriter).IsHijacked then
    begin
      Result := tscoHandler;
      FKeepAlive := False;
      { Hijack owns the connection; do not recycle this outbound buffer. }
      LOutbound := nil;
      AOutbound := nil;
      Exit;
    end;

    (LW as TH1ResponseWriter).FinalizeResponse;

    ACloseAfterDrain := not LKeepAlive;
    AOutbound := LOutbound;
  except
    on E: Exception do
    begin
      if (LW <> nil) and (LW as TH1ResponseWriter).IsHijacked then
      begin
        Result := tscoHandler;
        LOutbound := nil;
        AOutbound := nil;
      end
      else if (LW = nil) or (not (LW as TH1ResponseWriter).HasCommitted) then
      begin
        if LOutbound = nil then
        begin
          LOutbound := AcquireOutboundBuffer;
          LResponseWriter := LOutbound as IWriter;
        end;
        try
          WriteErrorResponseToWriter(LOutbound as IWriter,
            HTTP_STATUS_INTERNAL_SERVER_ERROR);
          AOutbound := LOutbound;
          ACloseAfterDrain := True;
        except
          { Secondary failure while writing 500 — drop buffer; peer sees close. }
          ReleaseOutboundBuffer(LOutbound);
          AOutbound := nil;
          ACloseAfterDrain := False;
        end;
      end
      else
      begin
        if (LOutbound <> nil) and (not LOutbound.IsEmpty) then
        begin
          AOutbound := LOutbound;
          ACloseAfterDrain := True;
        end
      end;
    end;
  end;
end;

function TH1ServerConnectionState.Run: TTcpServerConnOwnership;
begin
  Result := H1ServeRun(Self);
end;

function TH1ServerConnectionState.PollEvents: TPlatformPollEvents;
begin
  Result := H1PollEvents(Self);
end;

function TH1ServerConnectionState.Advance(const AEvents: TPlatformPollEvents;
  out ANextEvents: TPlatformPollEvents;
  out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
begin
  Result := H1PollAdvance(Self, AEvents, ANextEvents, AOwnership);
end;

function TH1ServerConnectionState.WakeDeadline: TDeadline;
begin
  Result := H1PollWakeDeadline(Self);
end;

end.
