unit nextpas.core.http.impl.h1;
{**
 * @desc HTTP/1.x server transport owner (poll/serve connection state).
 *       Client RoundTrip lives in impl.h1.client; shared prepend stream in
 *       impl.h1.prepend. This unit re-exports client options/factory.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.io.intf, nextpas.core.net.intf, nextpas.core.net.server.intf,
  nextpas.core.net.server.base, nextpas.core.platform.io.base,
  nextpas.core.tls.base, nextpas.core.http.base, nextpas.core.http.intf,
  nextpas.core.http.impl.h1.client;

type
  { Re-export client options/factory owner: impl.h1.client }
  TH1ClientTransportOptions = nextpas.core.http.impl.h1.client.TH1ClientTransportOptions;

function NewH1ClientTransport(const AOptions: TH1ClientTransportOptions): IHttpTransport;

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
  end;

function NewH1ServerTransport(const AOptions: TH1ServerTransportOptions): IHttpServerTransport;

implementation

uses
  nextpas.core.base, nextpas.core.base.utils, nextpas.core.errors,
  nextpas.core.io.base, nextpas.core.io.buffer, nextpas.core.net,
  nextpas.core.time.base, nextpas.core.time.deadline, nextpas.core.time,
  nextpas.core.text.conv,
  nextpas.core.encoding,
  nextpas.core.http.headers, nextpas.core.http.message,
  nextpas.core.http.impl.h1.outbound,
  nextpas.core.http.impl.h1.wire,
  nextpas.core.http.impl.h1.prepend,
  nextpas.core.http.impl.h1.fast,
  nextpas.core.http.impl.h1.parser, nextpas.core.http.impl.h1.writer,
  nextpas.core.http.impl.h1.chunked,
  nextpas.core.http.impl.tls.stream,
  nextpas.core.tls.quick,
  nextpas.core.mem.arena.intf,
  nextpas.core.http.mem,
  nextpas.core.http.middleware.requestarena;

type
  TH1FastSnapshotBodyReader = class(TInterfacedObject, IReader)
  private
    FData: TBytes;
    FPosition: SizeUInt;
    FSize: SizeUInt;
  public
    constructor Create(const AData: TBytes);
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
  end;

  TH1FastRequestSnapshot = class(TInterfacedObject, IH1Parser)
  private
    FMethod: THttpMethod;
    FUrl: string;
    FVersion: THttpVersion;
    FHeaders: IHttpHeaders;
    FBody: TBytes;
    FBodySize: Int64;
    FComplete: Boolean;
    FRequestMetadata: TH1RequestMetadata;
  public
    { ABuf is the same buffer FastParseRequest scanned; used to copy a complete
      fixed-length body into the snapshot when ContentLength > 0. }
    constructor Create(const AResult: TFastParseResult; const ABuf: PAnsiChar);
    function Execute(const ABuf: PAnsiChar; const ALen: SizeUInt): SizeUInt;
    procedure Finish;
    function GetMethod: THttpMethod;
    function GetStatusCode: THttpStatus;
    function GetHttpVersion: THttpVersion;
    function GetUrl: string;
    function GetHeaders: IHttpHeaders;
    function GetBody: string;
    function GetBodySize: Int64;
    function NewBodyReader: IReader;
    function HeadersComplete: Boolean;
    function IsComplete: Boolean;
    function ShouldKeepAlive: Boolean;
    function GetTrailerBytes: Int64;
    function GetRequestMetadata: TH1RequestMetadata;
    function HasError: Boolean;
    function ErrorMessage: string;
    function ErrorKind: TH1ParserErrorKind;
    procedure Reset;
  end;

  TH1ServerTransport = class(TInterfacedObject, IHttpServerTransport,
    IHttpServerSessionFactory, IHttpServerSessionFactoryWithContext)
  private
    FOptions: TH1ServerTransportOptions;
    procedure ValidateInputs(const AConn: ITcpStream; const AHandler: IHttpHandler);
    function HandleConnection(const AConn: ITcpStream; const AHandler: IHttpHandler): Boolean;
  public
    constructor Create(const AOptions: TH1ServerTransportOptions);
    function ServeConn(const AConn: ITcpStream;
      const AHandler: IHttpHandler): TTcpServerConnOwnership;
    function NewSession(const AConn: ITcpStream;
      const AHandler: IHttpHandler): ITcpServerSession; overload;
    function NewSession(const AConn: ITcpStream; const AHandler: IHttpHandler;
      const AContext: ITcpServerSessionContext): ITcpServerSession; overload;
  end;

  TH1ServerConnectionState = class;

  TH1PollRunWork = class(TInterfacedObject, ITcpServerWork)
  private
    FState: TH1ServerConnectionState;
  public
    constructor Create(const AState: TH1ServerConnectionState);
    function Execute: TTcpServerConnOwnership;
  end;

  TH1PollRequestWork = class(TInterfacedObject, ITcpServerWork)
  private
    FState: TH1ServerConnectionState;
    FOutbound: IH1OutboundBuffer;
    FCloseAfterDrain: Boolean;
  public
    constructor Create(const AState: TH1ServerConnectionState);
    function Execute: TTcpServerConnOwnership;
    property Outbound: IH1OutboundBuffer read FOutbound;
    property CloseAfterDrain: Boolean read FCloseAfterDrain;
  end;

  TH1PollRunCompletion = class(TInterfacedObject, ITcpServerWorkCompletion)
  private
    FState: TH1ServerConnectionState;
  public
    constructor Create(const AState: TH1ServerConnectionState);
    procedure Complete(const AOutcome: TTcpServerWorkOutcome;
      const AOwnership: TTcpServerConnOwnership);
  end;

  TH1PollRequestCompletion = class(TInterfacedObject, ITcpServerWorkCompletion)
  private
    FState: TH1ServerConnectionState;
    FWorkRef: ITcpServerWork;
    FWork: TH1PollRequestWork;
  public
    constructor Create(const AState: TH1ServerConnectionState;
      const AWork: TH1PollRequestWork);
    procedure Complete(const AOutcome: TTcpServerWorkOutcome;
      const AOwnership: TTcpServerConnOwnership);
  end;

  // Connection state stays protocol-owned so future runtimes can drive
  // the same H1 logic without keeping it welded to a thread entrypoint.
  TH1ServerConnectionState = class(TInterfacedObject, ITcpServerSession,
    ITcpServerPollDrivenSession, ITcpServerPollDrivenSessionWithDeadline)
  private
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
    procedure ApplyPollRequestResult(const AWork: TH1PollRequestWork);
    procedure ArmPollWriteDeadline;
    procedure ArmDirectWriteDeadline;
    function UsePollOwnedResponseDrain: Boolean;
    function ExecuteCurrentRequest: TTcpServerConnOwnership;
    function ExecuteCurrentPollRequest(out AOutbound: IH1OutboundBuffer;
      out ACloseAfterDrain: Boolean): TTcpServerConnOwnership;
    function AdvanceWholeRunBridge(const AEvents: TPlatformPollEvents;
      out ANextEvents: TPlatformPollEvents;
      out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
    function SubmitCurrentPollRequest(out ANextEvents: TPlatformPollEvents;
      out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
    function ContinueAfterPollCompletion(const AEvents: TPlatformPollEvents;
      out ANextEvents: TPlatformPollEvents;
      out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
    function AdvancePollResponseDrain(const AEvents: TPlatformPollEvents;
      out ANextEvents: TPlatformPollEvents;
      out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
    function AdvancePollRequestParse(const AEvents: TPlatformPollEvents;
      out ANextEvents: TPlatformPollEvents;
      out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
  public
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

{ TH1FastSnapshotBodyReader }

constructor TH1FastSnapshotBodyReader.Create(const AData: TBytes);
begin
  inherited Create;
  FData := AData;
  FPosition := 0;
  FSize := SizeUInt(Length(AData));
end;

function TH1FastSnapshotBodyReader.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
var
  LAvailable: SizeUInt;
begin
  if (ACount = 0) or (FPosition >= FSize) then
    Exit(0);
  LAvailable := FSize - FPosition;
  if ACount < LAvailable then
    Result := ACount
  else
    Result := LAvailable;
  Move(FData[FPosition], ABuf, Result);
  Inc(FPosition, Result);
end;

{ TH1FastRequestSnapshot }

constructor TH1FastRequestSnapshot.Create(const AResult: TFastParseResult;
  const ABuf: PAnsiChar);
begin
  inherited Create;
  FMethod := AResult.Method;
  FUrl := AResult.Path;
  FVersion := AResult.Version;
  FHeaders := AResult.Headers;
  FBodySize := AResult.ContentLength;
  SetLength(FBody, 0);
  if (AResult.ContentLength > 0) and (ABuf <> nil) then
  begin
    SetLength(FBody, AResult.ContentLength);
    Move(ABuf[AResult.BodyStart], FBody[0], AResult.ContentLength);
  end;
  FComplete := True;
  FRequestMetadata := Default(TH1RequestMetadata);
  FRequestMetadata.HasHost := AResult.HasHost;
  FRequestMetadata.HasDuplicateHost := AResult.HostRepeated;
  FRequestMetadata.HasTransferEncoding := AResult.HasTransferEncoding;
  FRequestMetadata.HasContentLength := AResult.HasContentLength;
  FRequestMetadata.DeclaredContentLength := AResult.ContentLength;
  FRequestMetadata.RequestDeclaresBody := AResult.ContentLength > 0;
  FRequestMetadata.ExpectsContinue := False;
  FRequestMetadata.HasUnsupportedExpect := False;
  FRequestMetadata.ConnectionClose := AResult.ConnectionClose;
  FRequestMetadata.ConnectionKeepAlive := AResult.ConnectionKeepAlive;
end;

function TH1FastRequestSnapshot.Execute(const ABuf: PAnsiChar;
  const ALen: SizeUInt): SizeUInt;
begin
  Result := 0;
end;

procedure TH1FastRequestSnapshot.Finish;
begin
end;

function TH1FastRequestSnapshot.GetMethod: THttpMethod;
begin
  Result := FMethod;
end;

function TH1FastRequestSnapshot.GetStatusCode: THttpStatus;
begin
  Result := 0;
end;

function TH1FastRequestSnapshot.GetHttpVersion: THttpVersion;
begin
  Result := FVersion;
end;

function TH1FastRequestSnapshot.GetUrl: string;
begin
  Result := FUrl;
end;

function TH1FastRequestSnapshot.GetHeaders: IHttpHeaders;
begin
  Result := FHeaders;
end;

function TH1FastRequestSnapshot.GetBody: string;
begin
  if Length(FBody) = 0 then
    Exit('');
  SetString(Result, PAnsiChar(@FBody[0]), Length(FBody));
end;

function TH1FastRequestSnapshot.GetBodySize: Int64;
begin
  Result := FBodySize;
end;

function TH1FastRequestSnapshot.NewBodyReader: IReader;
begin
  if Length(FBody) = 0 then
    Exit(nil);
  Result := TH1FastSnapshotBodyReader.Create(FBody);
end;

function TH1FastRequestSnapshot.HeadersComplete: Boolean;
begin
  Result := FComplete;
end;

function TH1FastRequestSnapshot.IsComplete: Boolean;
begin
  Result := FComplete;
end;

function TH1FastRequestSnapshot.ShouldKeepAlive: Boolean;
begin
  if FVersion = hvHttp10 then
    Result := FRequestMetadata.ConnectionKeepAlive
  else
    Result := not FRequestMetadata.ConnectionClose;
end;

function TH1FastRequestSnapshot.GetTrailerBytes: Int64;
begin
  Result := 0;
end;

function TH1FastRequestSnapshot.GetRequestMetadata: TH1RequestMetadata;
begin
  Result := FRequestMetadata;
end;

function TH1FastRequestSnapshot.HasError: Boolean;
begin
  Result := False;
end;

function TH1FastRequestSnapshot.ErrorMessage: string;
begin
  Result := '';
end;

function TH1FastRequestSnapshot.ErrorKind: TH1ParserErrorKind;
begin
  Result := pekNone;
end;

procedure TH1FastRequestSnapshot.Reset;
begin
  FComplete := False;
  FHeaders := NewHttpHeaders;
  FUrl := '';
  FBodySize := 0;
  FRequestMetadata := Default(TH1RequestMetadata);
end;

{ TH1PollRunWork }

constructor TH1PollRunWork.Create(const AState: TH1ServerConnectionState);
begin
  inherited Create;
  FState := AState;
end;

function TH1PollRunWork.Execute: TTcpServerConnOwnership;
begin
  Result := FState.Run;
end;

{ TH1PollRequestWork }

constructor TH1PollRequestWork.Create(const AState: TH1ServerConnectionState);
begin
  inherited Create;
  FState := AState;
end;

function TH1PollRequestWork.Execute: TTcpServerConnOwnership;
begin
  if FState.UsePollOwnedResponseDrain then
    Result := FState.ExecuteCurrentPollRequest(FOutbound, FCloseAfterDrain)
  else
    Result := FState.ExecuteCurrentRequest;
end;

{ TH1PollRunCompletion }

constructor TH1PollRunCompletion.Create(const AState: TH1ServerConnectionState);
begin
  inherited Create;
  FState := AState;
end;

procedure TH1PollRunCompletion.Complete(const AOutcome: TTcpServerWorkOutcome;
  const AOwnership: TTcpServerConnOwnership);
begin
  if FState <> nil then
  begin
    if AOutcome = tswoCompleted then
      FState.FPollCompletionOwnership := AOwnership
    else
    begin
      FState.FPollCompletionOwnership := tscoServer;
      FState.FKeepAlive := False;
    end;
    FState.FPollCompletionReady := True;
  end;
  FState := nil;
end;

{ TH1PollRequestCompletion }

constructor TH1PollRequestCompletion.Create(const AState: TH1ServerConnectionState;
  const AWork: TH1PollRequestWork);
begin
  inherited Create;
  FState := AState;
  FWorkRef := AWork as ITcpServerWork;
  FWork := AWork;
end;

procedure TH1PollRequestCompletion.Complete(
  const AOutcome: TTcpServerWorkOutcome;
  const AOwnership: TTcpServerConnOwnership);
begin
  if FState <> nil then
  begin
    if AOutcome = tswoCompleted then
    begin
      if AOwnership = tscoServer then
        FState.ApplyPollRequestResult(FWork);
      FState.FPollCompletionOwnership := AOwnership;
    end
    else
    begin
      FState.FPollCompletionOwnership := tscoServer;
      FState.FKeepAlive := False;
    end;
    FState.FPollCompletionReady := True;
  end;
  FWorkRef := nil;
  FWork := nil;
  FState := nil;
end;

{ TH1ServerConnectionState }

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

  FParser := TH1FastRequestSnapshot.Create(LFast, ABuf);
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
  const AWork: TH1PollRequestWork);
begin
  if (AWork = nil) then
    Exit;

  if not EnqueuePollResponse(AWork.Outbound, AWork.CloseAfterDrain) then
  begin
    { Work object still holds the buffer; drop via work refcount. Keep-alive off. }
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

    if FPending <> '' then
      LHijackConn := TReadPrependTcpStream.Create(FConn, FPending)
    else
      LHijackConn := FConn;
    LOutbound := AcquireOutboundBuffer;
    LResponseWriter := LOutbound as IWriter;
    LW := TH1ResponseWriter.Create(LResponseWriter, LHijackConn,
      LReq.Method = hmHead);
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

    LW.Flush;
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

    if FPending <> '' then
      LHijackConn := TReadPrependTcpStream.Create(FConn, FPending)
    else
      LHijackConn := FConn;
    LOutbound := AcquireOutboundBuffer;
    LResponseWriter := LOutbound as IWriter;
    LW := TH1ResponseWriter.Create(LResponseWriter, LHijackConn,
      LReq.Method = hmHead);
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

    LW.Flush;

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
var
  LN: SizeUInt;
  LConsumed: SizeUInt;
  LTotalRead: SizeUInt;
  LHeadersDone: Boolean;
  LRejected: Boolean;
  LHeaderStatus: THttpStatus;
  LIdleBeforeNextRequest: Boolean;
  LUsingIdleDeadline: Boolean;
begin
  Result := tscoServer;
  LIdleBeforeNextRequest := False;
  while FKeepAlive do
  begin
    try
      LUsingIdleDeadline := LIdleBeforeNextRequest and (FPending = '');
      if LUsingIdleDeadline then
        FConn.SetReadDeadline(TDeadline.After(TDuration.FromMilliseconds(FIdleMs)))
      else
        FConn.SetReadDeadline(TDeadline.After(TDuration.FromMilliseconds(FReadMs)));
      LIdleBeforeNextRequest := False;

      ResetRequestParser;
      LTotalRead := 0;
      LHeadersDone := False;
      FContinueSent := False;
      LRejected := False;
      { INV-12 keep-alive request-tail:
        parser only consumes the current framed request; any remainder stays in
        FPending for the next loop. Partial follow-up bytes are not rejected
        early; conclusively malformed / EOF-truncated follow-ups become the
        next request's 400 after the prior response. }
      repeat
        if FPending <> '' then
        begin
          LN := SizeUInt(Length(FPending));
          if not ((LTotalRead = 0) and
             TryUseFastRequestParser(PAnsiChar(FPending), LN, LConsumed)) then
            LConsumed := FParser.Execute(PAnsiChar(FPending), LN);
          if LConsumed < LN then
            FPending := Copy(FPending, Int32(LConsumed) + 1, Int32(LN - LConsumed))
          else
            FPending := '';
        end
        else
        begin
          LN := FConn.Read(FBuf[0], 16384);
          if LN = 0 then
          begin
            FKeepAlive := False;
            if (LTotalRead > 0) and (not FParser.IsComplete) and
               (not FParser.HasError) then
              FParser.Finish;
            Break;
          end;
          if LUsingIdleDeadline then
          begin
            FConn.SetReadDeadline(TDeadline.After(TDuration.FromMilliseconds(FReadMs)));
            LUsingIdleDeadline := False;
          end;
          if not ((LTotalRead = 0) and
             TryUseFastRequestParser(@FBuf[0], LN, LConsumed)) then
            LConsumed := FParser.Execute(@FBuf[0], LN);
          if LConsumed < LN then
          begin
            SetLength(FPending, Int32(LN - LConsumed));
            Move(FBuf[LConsumed], FPending[1], LN - LConsumed);
          end;
        end;
        Inc(LTotalRead, LConsumed);
        if (not LHeadersDone) and FParser.HeadersComplete then
        begin
          LHeadersDone := True;
          LHeaderStatus := HeaderPolicyErrorStatus(FParser, FOptions,
            LTotalRead, FParserIsSnapshot);
          if LHeaderStatus <> 0 then
          begin
            WriteErrorResponse(FConn, LHeaderStatus, FOptions.WriteTimeout);
            LRejected := True;
            FKeepAlive := False;
            Break;
          end;
          if ShouldSendContinueResponse(FParser, LHeadersDone, FContinueSent) then
          begin
            if not TryWriteContinueResponse(FConn, FOptions.WriteTimeout) then
            begin
              FKeepAlive := False;
              Break;
            end;
            FContinueSent := True;
          end;
        end;
        if LHeadersDone and (FOptions.MaxHeaderSize > 0) and
           (FParser.GetTrailerBytes > Int64(FOptions.MaxHeaderSize)) then
        begin
          WriteErrorResponse(FConn, HTTP_STATUS_HEADER_TOO_LARGE,
            FOptions.WriteTimeout);
          LRejected := True;
          FKeepAlive := False;
          Break;
        end;
        if (FOptions.MaxBodySize > 0) and
           (FParser.GetBodySize > FOptions.MaxBodySize) then
        begin
          WriteErrorResponse(FConn, HTTP_STATUS_PAYLOAD_TOO_LARGE,
            FOptions.WriteTimeout);
          LRejected := True;
          FKeepAlive := False;
          Break;
        end;
        if FParser.HasError then
        begin
          WriteErrorResponse(FConn, ParserErrorStatus(FParser),
            FOptions.WriteTimeout);
          LRejected := True;
          FKeepAlive := False;
          Break;
        end;
      until FParser.IsComplete or FParser.HasError;

      if LRejected then
        Break;

      if FParser.HasError then
      begin
        WriteErrorResponse(FConn, ParserErrorStatus(FParser),
          FOptions.WriteTimeout);
        Break;
      end;

      if not FParser.IsComplete then
        Break;

      if FOptions.MaxBodySize > 0 then
      begin
        if FParser.GetBodySize > FOptions.MaxBodySize then
        begin
          WriteErrorResponse(FConn, HTTP_STATUS_PAYLOAD_TOO_LARGE,
            FOptions.WriteTimeout);
          FKeepAlive := False;
          Continue;
        end;
      end;

      Result := ExecuteCurrentRequest;
      if Result <> tscoServer then
        Continue;
      LIdleBeforeNextRequest := FKeepAlive and (FPending = '');
    except
      on E: Exception do
      begin
        if not IsRequestReadFailure(E) then
          WriteErrorResponse(FConn, HTTP_STATUS_INTERNAL_SERVER_ERROR,
            FOptions.WriteTimeout);
        FKeepAlive := False;
      end;
    end;
  end;
end;

function TH1ServerConnectionState.AdvanceWholeRunBridge(
  const AEvents: TPlatformPollEvents; out ANextEvents: TPlatformPollEvents;
  out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
var
  LWork: ITcpServerWork;
  LCompletion: ITcpServerWorkCompletion;
  LHandoffResult: TTcpServerHandoffResult;
begin
  AOwnership := tscoServer;

  if not FPollSubmitted then
  begin
    if not (peReadable in AEvents) then
    begin
      ANextEvents := [peReadable];
      Exit(tsprWait);
    end;

    if FWorkerHandoff = nil then
    begin
      ANextEvents := [];
      AOwnership := Run;
      Exit(tsprDone);
    end;

    if FSocketRuntime <> nil then
      FSocketRuntime.SetBlocking(True);

    LWork := TH1PollRunWork.Create(Self);
    LCompletion := TH1PollRunCompletion.Create(Self);
    LHandoffResult := FWorkerHandoff.Submit(LWork, LCompletion);
    if LHandoffResult <> tshrAccepted then
    begin
      ANextEvents := [];
      Exit(tsprDone);
    end;

    FPollSubmitted := True;
    ANextEvents := [];
    Exit(tsprWait);
  end;

  if not FPollCompletionReady then
  begin
    ANextEvents := [];
    Exit(tsprWait);
  end;

  ANextEvents := [];
  AOwnership := FPollCompletionOwnership;
  Result := tsprDone;
end;

function TH1ServerConnectionState.SubmitCurrentPollRequest(
  out ANextEvents: TPlatformPollEvents;
  out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
var
  LWorkRef: TH1PollRequestWork;
  LWork: ITcpServerWork;
  LCompletion: ITcpServerWorkCompletion;
  LHandoffResult: TTcpServerHandoffResult;
  LOutbound: IH1OutboundBuffer;
  LCloseAfterDrain: Boolean;
  LInlineOnReactor: Boolean;
begin
  AOwnership := tscoServer;
  ClearPollReadDeadline;

  { S1-1: Prefer reactor-inline handler execution when poll owns response drain
    and PreferPollWorkerHandoff is False (production default).
    Multi-conn keep-alive on epoll was ~0.59x Go while threaded was ~3.3x Go —
    per-request WorkerHandoff (pool submit + completion wake) dominated short
    request cost. Inline removes that tax.

    Tradeoff: a blocking handler stalls the readiness reactor. PreferPollWorkerHandoff
    restores legacy isolation for tests / long-handler deployments. }
  LInlineOnReactor := (FWorkerHandoff = nil) or
    (UsePollOwnedResponseDrain and (not FOptions.PreferPollWorkerHandoff));
  if LInlineOnReactor then
  begin
    if FSocketRuntime <> nil then
      FSocketRuntime.SetBlocking(True);
    FPollNeedRequestReset := True;
    if UsePollOwnedResponseDrain then
      AOwnership := ExecuteCurrentPollRequest(LOutbound, LCloseAfterDrain)
    else
      AOwnership := ExecuteCurrentRequest;
    if AOwnership <> tscoServer then
    begin
      ANextEvents := [];
      Exit(tsprDone);
    end;
    if UsePollOwnedResponseDrain then
      EnqueuePollResponse(LOutbound, LCloseAfterDrain);
    if FSocketRuntime <> nil then
      FSocketRuntime.SetBlocking(False);
    if CanParseBufferedPollRequestWhileDraining then
    begin
      PreparePollRequestParse;
      Exit(AdvancePollRequestParse([], ANextEvents, AOwnership));
    end;
    if FPollResponsePending then
    begin
      if ShouldWaitForWritableInsteadOfEagerDrain([]) then
      begin
        ANextEvents := [peWritable];
        Exit(tsprWait);
      end;
      Exit(AdvancePollResponseDrain([], ANextEvents, AOwnership));
    end;
    if not FKeepAlive then
    begin
      ANextEvents := [];
      Exit(tsprDone);
    end;
    PreparePollKeepAliveRequestParse;
    Exit(AdvancePollRequestParse([], ANextEvents, AOwnership));
  end;

  if FSocketRuntime <> nil then
    FSocketRuntime.SetBlocking(True);

  FPollNeedRequestReset := True;
  FPollWorkerPending := True;
  FPollCompletionReady := False;
  LWorkRef := TH1PollRequestWork.Create(Self);
  LWork := LWorkRef;
  LCompletion := TH1PollRequestCompletion.Create(Self, LWorkRef);
  LHandoffResult := FWorkerHandoff.Submit(LWork, LCompletion);
  if LHandoffResult <> tshrAccepted then
  begin
    FPollWorkerPending := False;
    ANextEvents := [];
    Exit(tsprDone);
  end;

  ANextEvents := [];
  Result := tsprWait;
end;

function TH1ServerConnectionState.ContinueAfterPollCompletion(
  const AEvents: TPlatformPollEvents;
  out ANextEvents: TPlatformPollEvents;
  out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
begin
  FPollWorkerPending := False;
  FPollCompletionReady := False;
  AOwnership := FPollCompletionOwnership;

  if AOwnership <> tscoServer then
  begin
    ANextEvents := [];
    Exit(tsprDone);
  end;

  if FSocketRuntime <> nil then
    FSocketRuntime.SetBlocking(False);
  if CanParseBufferedPollRequestWhileDraining then
  begin
    PreparePollRequestParse;
    Exit(AdvancePollRequestParse([], ANextEvents, AOwnership));
  end;
  if FPollResponsePending then
  begin
    if ShouldWaitForWritableInsteadOfEagerDrain(AEvents) then
    begin
      ANextEvents := [peWritable];
      Exit(tsprWait);
    end;
    Exit(AdvancePollResponseDrain(AEvents, ANextEvents, AOwnership));
  end;
  if not FKeepAlive then
  begin
    ANextEvents := [];
    Exit(tsprDone);
  end;
  PreparePollKeepAliveRequestParse;
  Result := AdvancePollRequestParse([], ANextEvents, AOwnership);
end;

function TH1ServerConnectionState.AdvancePollResponseDrain(
  const AEvents: TPlatformPollEvents; out ANextEvents: TPlatformPollEvents;
  out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
var
  LWritten: SizeUInt;
  LWriteResult: TTcpStreamIOResult;
  LCloseAfterDrain: Boolean;
begin
  AOwnership := tscoServer;

  if (not FPollResponsePending) or (FPollOutbound = nil) or FPollOutbound.IsEmpty then
  begin
    PromoteQueuedPollResponse;
    if (not FPollResponsePending) or (FPollOutbound = nil) or FPollOutbound.IsEmpty then
      ResetPollResponseState;
    if not FKeepAlive then
    begin
      ANextEvents := [];
      Exit(tsprDone);
    end;
    PreparePollKeepAliveRequestParse;
    Exit(AdvancePollRequestParse(AEvents, ANextEvents, AOwnership));
  end;

  if (not FPollWriteDeadline.IsInfinite) and FPollWriteDeadline.IsExpired then
  begin
    ResetPollResponseState;
    FKeepAlive := False;
    ANextEvents := [];
    Exit(tsprDone);
  end;

  if FPollWriteDeadline.IsInfinite then
    ArmPollWriteDeadline;

  LWriteResult := FPollOutbound.TryDrainTo(FStreamRuntime, LWritten);
  case LWriteResult of
    tsiorOk:
      begin
        if FPollOutbound.IsEmpty then
        begin
          LCloseAfterDrain := FPollCloseAfterDrain;
          ReleaseOutboundBuffer(FPollOutbound);
          FPollResponsePending := False;
          FPollCloseAfterDrain := False;
          FPollWriteDeadline := TDeadline.Infinite;
          if LCloseAfterDrain then
          begin
            ANextEvents := [];
            Exit(tsprDone);
          end;
          if FPollQueuedResponsePending then
          begin
            PromoteQueuedPollResponse;
            if (FPending <> '') and (not FPollCloseAfterDrain) then
            begin
              ANextEvents := [peWritable];
              Exit(tsprWait);
            end;
            Exit(AdvancePollResponseDrain(AEvents, ANextEvents, AOwnership));
          end;
          if not FKeepAlive then
          begin
            ANextEvents := [];
            Exit(tsprDone);
          end;
          PreparePollKeepAliveRequestParse;
          Exit(AdvancePollRequestParse([], ANextEvents, AOwnership));
        end;
        if LWritten > 0 then
          ArmPollWriteDeadline;
        ANextEvents := [peWritable];
        Exit(tsprWait);
      end;
    tsiorWouldBlock:
      begin
        ANextEvents := [peWritable];
        Exit(tsprWait);
      end;
  else
    begin
      ResetPollResponseState;
      FKeepAlive := False;
      ANextEvents := [];
      Exit(tsprDone);
    end;
  end;
end;

function TH1ServerConnectionState.AdvancePollRequestParse(
  const AEvents: TPlatformPollEvents; out ANextEvents: TPlatformPollEvents;
  out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
var
  LN: SizeUInt;
  LConsumed: SizeUInt;
  LReadResult: TTcpStreamIOResult;
  LContinueOutbound: IH1OutboundBuffer;
  LHeaderStatus: THttpStatus;
  function FinishPollParseError(const AStatus: THttpStatus): TTcpServerPollResult;
  begin
    ClearPollReadDeadline;
    if QueuePollErrorResponse(AStatus) then
    begin
      FKeepAlive := False;
      Exit(AdvancePollResponseDrain(AEvents, ANextEvents, AOwnership));
    end;

    WriteErrorResponse(FConn, AStatus, FOptions.WriteTimeout);
    FKeepAlive := False;
    ANextEvents := [];
    Result := tsprDone;
  end;
begin
  AOwnership := tscoServer;

  while True do
  begin
    if FPending <> '' then
    begin
      LN := SizeUInt(Length(FPending));
      if not ((FParseTotalRead = 0) and
         TryUseFastRequestParser(PAnsiChar(FPending), LN, LConsumed)) then
        LConsumed := FParser.Execute(PAnsiChar(FPending), LN);
      if LConsumed < LN then
        FPending := Copy(FPending, Int32(LConsumed) + 1, Int32(LN - LConsumed))
      else
        FPending := '';
    end
    else
    begin
      if FStreamRuntime = nil then
        Exit(AdvanceWholeRunBridge(AEvents, ANextEvents, AOwnership));
      if not (peReadable in AEvents) then
      begin
        if FPollReadDeadline.IsExpired then
        begin
          ClearPollReadDeadline;
          FKeepAlive := False;
          ANextEvents := [];
          Exit(tsprDone);
        end;
        if FPollResponsePending then
          Exit(AdvancePollResponseDrain(AEvents, ANextEvents, AOwnership));
        ANextEvents := [peReadable];
        Exit(tsprWait);
      end;

      LReadResult := FStreamRuntime.TryRead(FBuf[0], SizeUInt(SizeOf(FBuf)), LN);
      case LReadResult of
        tsiorWouldBlock:
          begin
            if FPollReadDeadline.IsExpired then
            begin
              ClearPollReadDeadline;
              FKeepAlive := False;
              ANextEvents := [];
              Exit(tsprDone);
            end;
            ANextEvents := [peReadable];
            Exit(tsprWait);
          end;
        tsiorClosed:
          begin
            ClearPollReadDeadline;
            FKeepAlive := False;
            if (FParseTotalRead > 0) and (not FParser.IsComplete) and
               (not FParser.HasError) then
              FParser.Finish;
            if FParser.HasError then
              Exit(FinishPollParseError(ParserErrorStatus(FParser)));
            ANextEvents := [];
            Exit(tsprDone);
          end;
      else
      begin
        if FPollReadDeadlineIsIdle then
          ArmPollRequestReadDeadline;
        if not ((FParseTotalRead = 0) and
           TryUseFastRequestParser(@FBuf[0], LN, LConsumed)) then
          LConsumed := FParser.Execute(@FBuf[0], LN);
        if LConsumed < LN then
        begin
          SetLength(FPending, Int32(LN - LConsumed));
          Move(FBuf[LConsumed], FPending[1], LN - LConsumed);
        end;
      end;
      end;
    end;

    Inc(FParseTotalRead, LConsumed);
    if (not FParseHeadersDone) and FParser.HeadersComplete then
    begin
      FParseHeadersDone := True;
      LHeaderStatus := HeaderPolicyErrorStatus(FParser, FOptions,
        FParseTotalRead, FParserIsSnapshot);
      if LHeaderStatus <> 0 then
        Exit(FinishPollParseError(LHeaderStatus));
      if ShouldSendContinueResponse(FParser, FParseHeadersDone, FContinueSent) then
      begin
        LContinueOutbound := NewH1OutboundBuffer;
        WriteContinueResponseToWriter(LContinueOutbound as IWriter);
        if not EnqueuePollResponse(LContinueOutbound, False) then
        begin
          FKeepAlive := False;
          ANextEvents := [];
          Exit(tsprDone);
        end;
        FContinueSent := True;
        Exit(AdvancePollResponseDrain(AEvents, ANextEvents, AOwnership));
      end;
    end;

    if FParseHeadersDone and (FOptions.MaxHeaderSize > 0) and
       (FParser.GetTrailerBytes > Int64(FOptions.MaxHeaderSize)) then
      Exit(FinishPollParseError(HTTP_STATUS_HEADER_TOO_LARGE));

    if (FOptions.MaxBodySize > 0) and
       (FParser.GetBodySize > FOptions.MaxBodySize) then
      Exit(FinishPollParseError(HTTP_STATUS_PAYLOAD_TOO_LARGE));

    if FParser.HasError then
      Exit(FinishPollParseError(ParserErrorStatus(FParser)));

    if FParser.IsComplete then
      Exit(SubmitCurrentPollRequest(ANextEvents, AOwnership));
  end;
end;

function TH1ServerConnectionState.PollEvents: TPlatformPollEvents;
begin
  Result := [peReadable];
end;

function TH1ServerConnectionState.Advance(const AEvents: TPlatformPollEvents;
  out ANextEvents: TPlatformPollEvents;
  out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
begin
  AOwnership := tscoServer;

  if FStreamRuntime = nil then
    Exit(AdvanceWholeRunBridge(AEvents, ANextEvents, AOwnership));

  if FPollWorkerPending then
  begin
    if not FPollCompletionReady then
    begin
      ANextEvents := [];
      Exit(tsprWait);
    end;
    Exit(ContinueAfterPollCompletion(AEvents, ANextEvents, AOwnership));
  end;

  if CanParseBufferedPollRequestWhileDraining then
  begin
    PreparePollRequestParse;
    Exit(AdvancePollRequestParse([], ANextEvents, AOwnership));
  end;
  if FPollResponsePending then
  begin
    if ShouldWaitForWritableInsteadOfEagerDrain(AEvents) then
    begin
      ANextEvents := [peWritable];
      Exit(tsprWait);
    end;
    Exit(AdvancePollResponseDrain(AEvents, ANextEvents, AOwnership));
  end;

  Result := AdvancePollRequestParse(AEvents, ANextEvents, AOwnership);
end;

function TH1ServerConnectionState.WakeDeadline: TDeadline;
begin
  Result := TDeadline.Min(FPollReadDeadline, FPollWriteDeadline);
end;

{ TH1ServerTransport }

constructor TH1ServerTransport.Create(const AOptions: TH1ServerTransportOptions);
begin
  inherited Create;
  FOptions := AOptions;
end;

procedure TH1ServerTransport.ValidateInputs(const AConn: ITcpStream;
  const AHandler: IHttpHandler);
begin
  if AConn = nil then
    raise EHttpError.Create(hekArgument, 'h1 server transport requires connection');
  if AHandler = nil then
    raise EHttpError.Create(hekArgument, 'h1 server transport requires handler');
end;

function TH1ServerTransport.HandleConnection(const AConn: ITcpStream;
  const AHandler: IHttpHandler): Boolean;
var
  LState: TH1ServerConnectionState;
begin
  ValidateInputs(AConn, AHandler);
  LState := TH1ServerConnectionState.Create(AConn, AHandler, FOptions);
  try
    Result := LState.Run = tscoServer;
  finally
    LState.Free;
  end;
end;

function TH1ServerTransport.ServeConn(const AConn: ITcpStream;
  const AHandler: IHttpHandler): TTcpServerConnOwnership;
begin
  if HandleConnection(AConn, AHandler) then
    Result := tscoServer
  else
    Result := tscoHandler;
end;

function TH1ServerTransport.NewSession(const AConn: ITcpStream;
  const AHandler: IHttpHandler): ITcpServerSession;
begin
  ValidateInputs(AConn, AHandler);
  Result := TH1ServerConnectionState.Create(AConn, AHandler, FOptions);
end;

function TH1ServerTransport.NewSession(const AConn: ITcpStream;
  const AHandler: IHttpHandler;
  const AContext: ITcpServerSessionContext): ITcpServerSession;
begin
  ValidateInputs(AConn, AHandler);
  Result := TH1ServerConnectionState.Create(AConn, AHandler, FOptions, AContext);
end;



function NewH1ClientTransport(const AOptions: TH1ClientTransportOptions): IHttpTransport;
begin
  Result := nextpas.core.http.impl.h1.client.NewH1ClientTransport(AOptions);
end;

function NewH1ServerTransport(const AOptions: TH1ServerTransportOptions): IHttpServerTransport;
begin
  Result := TH1ServerTransport.Create(AOptions);
end;

end.
