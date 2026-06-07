unit nextpas.core.http.impl.h1;
{**
 * @desc Default HTTP/1.x transport implementations for client and server.
 *       Owns single-request round trips, connection reuse, and per-connection
 *       request/response handling for the shared HTTP facade layer.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.io.intf,
  nextpas.core.net.intf,
  nextpas.core.net.server.intf,
  nextpas.core.net.server.base,
  nextpas.core.platform.io.base,
  nextpas.core.http.base,
  nextpas.core.http.intf;

type
  TH1ClientTransportOptions = record
    Timeout: Int64;
  end;

  TH1ServerTransportOptions = record
    ReadTimeout: Int64;
    WriteTimeout: Int64;
    IdleTimeout: Int64;
    MaxHeaderSize: Int32;
    MaxBodySize: Int64;
  end;

function NewH1ClientTransport(const AOptions: TH1ClientTransportOptions): IHttpTransport;
function NewH1ServerTransport(const AOptions: TH1ServerTransportOptions): IHttpServerTransport;

implementation

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.base.utils,
  nextpas.core.errors,
  nextpas.core.io.base,
  nextpas.core.io.buffer,
  nextpas.core.net,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.text.conv,
  nextpas.core.http.headers,
  nextpas.core.http.message,
  nextpas.core.http.impl.h1.outbound,
  nextpas.core.http.impl.h1.fast,
  nextpas.core.http.impl.h1.parser,
  nextpas.core.http.impl.h1.writer;

type
  TPoolEntry = record
    Host: string;
    Port: UInt16;
    Conn: ITcpStream;
  end;

  TPrefixedTcpStream = class(TInterfacedObject, IReader, IWriter, IStream, ITcpStream)
  private
    FInner: ITcpStream;
    FPrefix: string;
    FPrefixPos: SizeInt;
  public
    constructor Create(const AInner: ITcpStream; const APrefix: string);
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    function Seek(const AOffset: Int64; const AOrigin: TSeekOrigin): Int64;
    procedure Close;
    function GetSize: Int64;
    function GetPosition: Int64;
    procedure SetPosition(const AValue: Int64);
    function LocalAddr: TNetAddress;
    function RemoteAddr: TNetAddress;
    procedure Shutdown;
    procedure SetNoDelay(const AValue: Boolean);
    procedure SetKeepAlive(const AValue: Boolean);
    procedure SetReadDeadline(const ADeadline: TDeadline);
    procedure SetWriteDeadline(const ADeadline: TDeadline);
  end;

  TH1FastRequestSnapshot = class(TInterfacedObject, IH1Parser)
  private
    FMethod: THttpMethod;
    FUrl: string;
    FVersion: THttpVersion;
    FHeaders: IHttpHeaders;
    FBodySize: Int64;
    FComplete: Boolean;
    FRequestMetadata: TH1RequestMetadata;
  public
    constructor Create(const AResult: TFastParseResult);
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

  TH1ClientTransport = class(TInterfacedObject, IHttpTransport,
    IHttpTransportIdleConnections)
  private
    FOptions: TH1ClientTransportOptions;
    FPool: array of TPoolEntry;
    FPoolCount: Int32;
    function PoolGet(const AHost: string; const APort: UInt16): ITcpStream;
    procedure PoolPut(const AHost: string; const APort: UInt16; const AConn: ITcpStream);
    procedure PoolClear;
    function WriteRequest(const AWriter: IWriter; const AReq: IHttpRequest): Boolean;
    function ReadResponse(const AReader: IReader;
      const ARequestMethod: THttpMethod; out AKeepAlive: Boolean): IHttpResponse;
  public
    constructor Create(const AOptions: TH1ClientTransportOptions);
    function RoundTrip(const AReq: IHttpRequest): IHttpResponse;
    procedure CloseIdleConnections;
  end;

  TH1ServerTransport = class(TInterfacedObject, IHttpServerTransport,
    IHttpServerSessionFactory, IHttpServerSessionFactoryWithContext)
  private
    FOptions: TH1ServerTransportOptions;
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
    FIdleMs: Int64;
    FBuf: array[0..4095] of Byte;
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
    FPollReadDeadline: TDeadline;
    FPollWriteDeadline: TDeadline;
    FParserIsSnapshot: Boolean;
    procedure ArmPollReadDeadline;
    procedure ClearPollReadDeadline;
    procedure ResetRequestParser;
    function TryUseFastRequestParser(const ABuf: PAnsiChar; const ALen: SizeUInt;
      out AConsumed: SizeUInt): Boolean;
    procedure ResetPollRequestState;
    procedure PreparePollRequestParse;
    procedure ResetPollResponseState;
    procedure PromoteQueuedPollResponse;
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
    pekUnsupportedTransferCoding:
      Result := HTTP_STATUS_NOT_IMPLEMENTED;
  else
    Result := HTTP_STATUS_BAD_REQUEST;
  end;
end;

function IsRetryableMethod(const AMethod: THttpMethod): Boolean; inline;
begin
  Result := AMethod in [hmGet, hmHead, hmOptions, hmTrace];
end;

function HasRetryIdempotencyKey(const AReq: IHttpRequest): Boolean; inline;
begin
  Result := (AReq <> nil) and (AReq.Headers <> nil) and
    (AReq.Headers.Has('idempotency-key') or AReq.Headers.Has('x-idempotency-key'));
end;

function IsRetrySafeRequest(const AReq: IHttpRequest): Boolean; inline;
begin
  if AReq = nil then
    Exit(False);
  Result := IsRetryableMethod(AReq.Method) or HasRetryIdempotencyKey(AReq);
end;

function CaptureRetryBodyPosition(const AReq: IHttpRequest;
  out ABodyStream: IStream; out AStartPosition: Int64): Boolean;
begin
  ABodyStream := nil;
  AStartPosition := 0;
  if (AReq = nil) or (AReq.Body = nil) or (AReq.ContentLength = 0) then
    Exit(True);
  Result := Supports(AReq.Body, IStream, ABodyStream);
  if Result then
    AStartPosition := ABodyStream.Position;
end;

procedure RewindRetryBody(const AReq: IHttpRequest; const ABodyStream: IStream;
  const AStartPosition: Int64);
begin
  if (AReq = nil) or (AReq.Body = nil) or (AReq.ContentLength = 0) then
    Exit;
  if ABodyStream = nil then
    raise EHttpError.Create('pooled retry request body is not replayable');
  ABodyStream.Position := AStartPosition;
end;

function RequestMetadata(const AParser: IH1Parser): TH1RequestMetadata; inline;
begin
  if AParser = nil then
    Exit(Default(TH1RequestMetadata));
  Result := AParser.GetRequestMetadata;
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

  if AFastSnapshot then
    Exit(0);

  if (AParser.GetHttpVersion = hvHttp11) and
     (not LMetadata.HasHost) then
    Exit(HTTP_STATUS_BAD_REQUEST);

  if LMetadata.HasUnsupportedExpect then
    Exit(HTTP_STATUS_EXPECTATION_FAILED);

  if (AOptions.MaxBodySize > 0) and LMetadata.HasContentLength and
     (LMetadata.DeclaredContentLength > AOptions.MaxBodySize) then
    Exit(HTTP_STATUS_PAYLOAD_TOO_LARGE);
end;

function IsRequestReadFailure(const E: Exception): Boolean;
begin
  Result := False;
  if E = nil then
    Exit(False);
  Result := (E is ETimeoutError) or (E is ENetworkError);
end;

{ TPrefixedTcpStream }

constructor TPrefixedTcpStream.Create(const AInner: ITcpStream; const APrefix: string);
begin
  inherited Create;
  FInner := AInner;
  FPrefix := APrefix;
  FPrefixPos := 1;
end;

function TPrefixedTcpStream.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
var
  LPtr: PByte;
  LCopy: SizeUInt;
begin
  Result := 0;
  if ACount = 0 then
    Exit(0);

  LPtr := @ABuf;
  if (FPrefixPos > 0) and (FPrefixPos <= Length(FPrefix)) then
  begin
    LCopy := SizeUInt(Length(FPrefix) - FPrefixPos + 1);
    if LCopy > ACount then
      LCopy := ACount;
    Move(FPrefix[FPrefixPos], LPtr^, LCopy);
    Inc(FPrefixPos, SizeInt(LCopy));
    Inc(Result, LCopy);
    Inc(LPtr, LCopy);
    if FPrefixPos > Length(FPrefix) then
      FPrefix := '';
  end;

  if Result < ACount then
    Inc(Result, FInner.Read(LPtr^, ACount - Result));
end;

function TPrefixedTcpStream.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  Result := FInner.Write(ABuf, ACount);
end;

function TPrefixedTcpStream.Seek(const AOffset: Int64; const AOrigin: TSeekOrigin): Int64;
begin
  Result := FInner.Seek(AOffset, AOrigin);
end;

procedure TPrefixedTcpStream.Close;
begin
  FInner.Close;
end;

function TPrefixedTcpStream.GetSize: Int64;
begin
  Result := FInner.Size;
end;

function TPrefixedTcpStream.GetPosition: Int64;
begin
  Result := FInner.Position;
end;

procedure TPrefixedTcpStream.SetPosition(const AValue: Int64);
begin
  FInner.Position := AValue;
end;

function TPrefixedTcpStream.LocalAddr: TNetAddress;
begin
  Result := FInner.LocalAddr;
end;

function TPrefixedTcpStream.RemoteAddr: TNetAddress;
begin
  Result := FInner.RemoteAddr;
end;

procedure TPrefixedTcpStream.Shutdown;
begin
  FInner.Shutdown;
end;

procedure TPrefixedTcpStream.SetNoDelay(const AValue: Boolean);
begin
  FInner.SetNoDelay(AValue);
end;

procedure TPrefixedTcpStream.SetKeepAlive(const AValue: Boolean);
begin
  FInner.SetKeepAlive(AValue);
end;

procedure TPrefixedTcpStream.SetReadDeadline(const ADeadline: TDeadline);
begin
  FInner.SetReadDeadline(ADeadline);
end;

procedure TPrefixedTcpStream.SetWriteDeadline(const ADeadline: TDeadline);
begin
  FInner.SetWriteDeadline(ADeadline);
end;

{ TH1FastRequestSnapshot }

constructor TH1FastRequestSnapshot.Create(const AResult: TFastParseResult);
begin
  inherited Create;
  FMethod := AResult.Method;
  FUrl := AResult.Path;
  FVersion := AResult.Version;
  FHeaders := AResult.Headers;
  FBodySize := AResult.ContentLength;
  FComplete := True;
  FRequestMetadata := Default(TH1RequestMetadata);
  FRequestMetadata.HasHost := AResult.HasHost;
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
  Result := '';
end;

function TH1FastRequestSnapshot.GetBodySize: Int64;
begin
  Result := FBodySize;
end;

function TH1FastRequestSnapshot.NewBodyReader: IReader;
begin
  Result := nil;
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

procedure WriteErrorResponse(const AConn: ITcpStream; const AStatus: THttpStatus;
  const AWriteTimeoutMs: Int64 = 0);
var
  LW: IHttpResponseWriter;
  LBody: string;
begin
  try
    if AWriteTimeoutMs > 0 then
      AConn.SetWriteDeadline(TDeadline.After(
        TDuration.FromMilliseconds(AWriteTimeoutMs)));
    LW := TH1ResponseWriter.Create(AConn as IWriter);
    LBody := HttpStatusText(AStatus);
    LW.GetHeaders.SetHeader('content-length', IntToStr(Int64(Length(LBody))));
    LW.GetHeaders.SetHeader('connection', 'close');
    LW.WriteHeader(AStatus);
    if Length(LBody) > 0 then
      LW.Write(LBody[1], SizeUInt(Length(LBody)));
  except
    { Ignore secondary write failures while sending an error response. }
  end;
end;

procedure WriteErrorResponseToWriter(const AWriter: IWriter;
  const AStatus: THttpStatus);
var
  LW: IHttpResponseWriter;
  LBody: string;
begin
  LW := TH1ResponseWriter.Create(AWriter);
  LBody := HttpStatusText(AStatus);
  LW.GetHeaders.SetHeader('content-length', IntToStr(Int64(Length(LBody))));
  LW.GetHeaders.SetHeader('connection', 'close');
  LW.WriteHeader(AStatus);
  if Length(LBody) > 0 then
    LW.Write(LBody[1], SizeUInt(Length(LBody)));
end;

function TryWriteContinueResponse(const AConn: ITcpStream;
  const AWriteTimeoutMs: Int64 = 0): Boolean;
var
  LW: IHttpResponseWriter;
begin
  Result := False;
  try
    if AWriteTimeoutMs > 0 then
      AConn.SetWriteDeadline(TDeadline.After(
        TDuration.FromMilliseconds(AWriteTimeoutMs)));
    LW := TH1ResponseWriter.Create(AConn as IWriter);
    LW.WriteHeader(HTTP_STATUS_CONTINUE);
    Result := True;
  except
    Result := False;
  end;
end;

procedure WriteContinueResponseToWriter(const AWriter: IWriter);
var
  LW: IHttpResponseWriter;
begin
  LW := TH1ResponseWriter.Create(AWriter);
  LW.WriteHeader(HTTP_STATUS_CONTINUE);
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
  if FOptions.IdleTimeout > 0 then
    FIdleMs := FOptions.IdleTimeout
  else
    FIdleMs := 30000;
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
  FPollReadDeadline := TDeadline.Infinite;
  FPollWriteDeadline := TDeadline.Infinite;
  FParserIsSnapshot := False;
  if FStreamRuntime <> nil then
    ArmPollReadDeadline;
end;

procedure TH1ServerConnectionState.ArmPollReadDeadline;
begin
  if FStreamRuntime = nil then
    Exit;
  FPollReadDeadline := TDeadline.After(TDuration.FromMilliseconds(FIdleMs));
  FConn.SetReadDeadline(FPollReadDeadline);
end;

procedure TH1ServerConnectionState.ClearPollReadDeadline;
begin
  FPollReadDeadline := TDeadline.Infinite;
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

  if (LFast.Version <> hvHttp11) or
     (LFast.ContentLength <> 0) or
     (not LFast.HasHost) or
     LFast.HasExpect or
     LFast.HasTransferEncoding then
    Exit(False);

  if LFast.HasConnection and
     ((not LFast.ConnectionKeepAlive) or
      LFast.ConnectionClose or
      LFast.ConnectionUnsupported) then
    Exit(False);

  FParser := TH1FastRequestSnapshot.Create(LFast);
  FParserIsSnapshot := True;
  AConsumed := LFast.Consumed;
  Result := True;
end;

procedure TH1ServerConnectionState.ResetPollRequestState;
begin
  ResetRequestParser;
  FParseTotalRead := 0;
  FParseHeadersDone := False;
  FContinueSent := False;
  FPollNeedRequestReset := False;
  ArmPollReadDeadline;
end;

procedure TH1ServerConnectionState.PreparePollRequestParse;
begin
  if FPollNeedRequestReset then
    ResetPollRequestState;
end;

procedure TH1ServerConnectionState.ResetPollResponseState;
begin
  FPollOutbound := nil;
  FPollResponsePending := False;
  FPollCloseAfterDrain := False;
  FPollQueuedOutbound := nil;
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
  LOutbound := NewH1OutboundBuffer;
  WriteErrorResponseToWriter(LOutbound as IWriter, AStatus);
  Result := EnqueuePollResponse(LOutbound, True);
end;

procedure TH1ServerConnectionState.ApplyPollRequestResult(
  const AWork: TH1PollRequestWork);
begin
  if (AWork = nil) then
    Exit;

  if not EnqueuePollResponse(AWork.Outbound, AWork.CloseAfterDrain) then
    FKeepAlive := False;
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
begin
  Result := tscoServer;
  LW := nil;
  LOutbound := nil;
  LResponseWriter := nil;
  LDrainStarted := False;
  try
    if FParserIsSnapshot then
      FKeepAlive := True
    else
      FKeepAlive := ShouldKeepAlive(FParser);

    if (not FParserIsSnapshot) and (FParser.GetHttpVersion = hvHttp11) and
       (not RequestMetadata(FParser).HasHost) then
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
      LHijackConn := TPrefixedTcpStream.Create(FConn, FPending)
    else
      LHijackConn := FConn;
    LOutbound := NewH1OutboundBuffer;
    LResponseWriter := LOutbound as IWriter;
    LW := TH1ResponseWriter.Create(LResponseWriter, LHijackConn,
      LReq.Method = hmHead);
    if FKeepAlive and (FParser.GetHttpVersion = hvHttp10) then
      LW.GetHeaders.SetHeader('connection', 'keep-alive');
    if not FKeepAlive then
      LW.GetHeaders.SetHeader('connection', 'close');

    FHandler.ServeHTTP(LReq, LW);

    if (LW as TH1ResponseWriter).IsHijacked then
    begin
      Result := tscoHandler;
      FKeepAlive := False;
      Exit;
    end;

    LW.Flush;
    LDrainStarted := True;
    ArmDirectWriteDeadline;
    LOutbound.DrainAllTo(FConn as IWriter);

    if LW.GetHeaders.Get('connection') = 'close' then
      FKeepAlive := False;
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

    if (not FParserIsSnapshot) and (FParser.GetHttpVersion = hvHttp11) and
       (not RequestMetadata(FParser).HasHost) then
    begin
      LOutbound := NewH1OutboundBuffer;
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
      LHijackConn := TPrefixedTcpStream.Create(FConn, FPending)
    else
      LHijackConn := FConn;
    LOutbound := NewH1OutboundBuffer;
    LResponseWriter := LOutbound as IWriter;
    LW := TH1ResponseWriter.Create(LResponseWriter, LHijackConn,
      LReq.Method = hmHead);
    if LKeepAlive and (FParser.GetHttpVersion = hvHttp10) then
      LW.GetHeaders.SetHeader('connection', 'keep-alive');
    if not LKeepAlive then
      LW.GetHeaders.SetHeader('connection', 'close');

    FHandler.ServeHTTP(LReq, LW);

    if (LW as TH1ResponseWriter).IsHijacked then
    begin
      Result := tscoHandler;
      FKeepAlive := False;
      Exit;
    end;

    LW.Flush;

    if LW.GetHeaders.Get('connection') = 'close' then
      LKeepAlive := False;
    AOutbound := LOutbound;
    ACloseAfterDrain := not LKeepAlive;
  except
    on E: Exception do
    begin
      if (LW <> nil) and (LW as TH1ResponseWriter).IsHijacked then
        Result := tscoHandler
      else if (LW = nil) or (not (LW as TH1ResponseWriter).HasCommitted) then
      begin
        if LOutbound = nil then
        begin
          LOutbound := NewH1OutboundBuffer;
          LResponseWriter := LOutbound as IWriter;
        end;
        try
          WriteErrorResponseToWriter(LOutbound as IWriter,
            HTTP_STATUS_INTERNAL_SERVER_ERROR);
          AOutbound := LOutbound;
          ACloseAfterDrain := True;
        except
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
begin
  Result := tscoServer;
  while FKeepAlive do
  begin
    try
      FConn.SetReadDeadline(TDeadline.After(TDuration.FromMilliseconds(FIdleMs)));

      ResetRequestParser;
      LTotalRead := 0;
      LHeadersDone := False;
      FContinueSent := False;
      LRejected := False;
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
          LN := FConn.Read(FBuf[0], 4096);
          if LN = 0 then
          begin
            FKeepAlive := False;
            if (LTotalRead > 0) and (not FParser.IsComplete) and
               (not FParser.HasError) then
              FParser.Finish;
            Break;
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
      if not FKeepAlive then
        FKeepAlive := False;
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
begin
  AOwnership := tscoServer;
  ClearPollReadDeadline;

  if FWorkerHandoff = nil then
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
    PreparePollRequestParse;
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
  PreparePollRequestParse;
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
    PreparePollRequestParse;
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
          FPollOutbound := nil;
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
          PreparePollRequestParse;
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

{ TH1ClientTransport }

constructor TH1ClientTransport.Create(const AOptions: TH1ClientTransportOptions);
begin
  inherited Create;
  FOptions := AOptions;
  FPoolCount := 0;
end;

function TH1ClientTransport.PoolGet(const AHost: string; const APort: UInt16): ITcpStream;
var
  LI: Int32;
begin
  Result := nil;
  for LI := 0 to FPoolCount - 1 do
    if (FPool[LI].Host = AHost) and (FPool[LI].Port = APort) then
    begin
      Result := FPool[LI].Conn;
      FPool[LI] := FPool[FPoolCount - 1];
      Dec(FPoolCount);
      Exit;
    end;
end;

procedure TH1ClientTransport.PoolPut(const AHost: string; const APort: UInt16;
  const AConn: ITcpStream);
begin
  if FPoolCount >= Length(FPool) then
    SetLength(FPool, FPoolCount + 4);
  FPool[FPoolCount].Host := AHost;
  FPool[FPoolCount].Port := APort;
  FPool[FPoolCount].Conn := AConn;
  Inc(FPoolCount);
end;

procedure TH1ClientTransport.PoolClear;
var
  LI: Int32;
begin
  for LI := 0 to FPoolCount - 1 do
    if FPool[LI].Conn <> nil then
      FPool[LI].Conn.Close;
  FPoolCount := 0;
  SetLength(FPool, 0);
end;

function TH1ClientTransport.WriteRequest(const AWriter: IWriter;
  const AReq: IHttpRequest): Boolean;
const
  CRLF: AnsiString = #13#10;
var
  LPath: string;
  LBuf: IWriter;
  LFlusher: IFlusher;
  LN: SizeUInt;
  LRemaining: Int64;
  LReadSize: SizeUInt;
  LTmp: array[0..4095] of Byte;
  LStr: string;
begin
  Result := True;
  if not (AReq.Version in [hvHttp10, hvHttp11]) then
    raise EHttpError.Create('h1 transport only supports HTTP/1.x requests');

  LBuf := CreateBufferedWriter(AWriter, 4096);

  LStr := HttpMethodToStr(AReq.Method);
  LBuf.Write(LStr[1], SizeUInt(Length(LStr)));
  LBuf.Write(PAnsiChar(' ')^, 1);

  LPath := AReq.Path;
  if LPath = '' then
    LPath := '/';
  if AReq.RawQuery <> '' then
    LPath := LPath + '?' + AReq.RawQuery;
  LBuf.Write(LPath[1], SizeUInt(Length(LPath)));

  LStr := ' ' + HttpVersionToStr(AReq.Version);
  LBuf.Write(LStr[1], SizeUInt(Length(LStr)));
  LBuf.Write(CRLF[1], 2);

  AReq.Headers.ForEach(procedure(const AName, AValue: string)
  var
    LHeader: string;
  begin
    LHeader := AName + ': ' + AValue;
    LBuf.Write(LHeader[1], SizeUInt(Length(LHeader)));
    LBuf.Write(CRLF[1], 2);
  end);

  LBuf.Write(CRLF[1], 2);

  if (AReq.Body <> nil) and (AReq.ContentLength > 0) then
  begin
    LRemaining := AReq.ContentLength;
    while LRemaining > 0 do
    begin
      LReadSize := SizeUInt(SizeOf(LTmp));
      if LRemaining < Int64(LReadSize) then
        LReadSize := SizeUInt(LRemaining);
      LN := AReq.Body.Read(LTmp[0], LReadSize);
      if LN > 0 then
      begin
        if Int64(LN) > LRemaining then
          LN := SizeUInt(LRemaining);
        LBuf.Write(LTmp[0], LN);
        Dec(LRemaining, Int64(LN));
      end;
      if LN = 0 then
        raise EHttpError.Create(
          'HTTP request body shorter than declared content-length');
    end;
  end;

  if Supports(LBuf, IFlusher, LFlusher) then
    LFlusher.Flush;
end;

function TH1ClientTransport.ReadResponse(const AReader: IReader;
  const ARequestMethod: THttpMethod; out AKeepAlive: Boolean): IHttpResponse;
var
  LParser: IH1Parser;
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LBodyReader: IReader;
begin
  LParser := NewH1ResponseParser(ARequestMethod = hmHead);
  repeat
    LN := AReader.Read(LBuf[0], 4096);
    if LN = 0 then
      Break;
    LParser.Execute(@LBuf[0], LN);
  until LParser.IsComplete or LParser.HasError;

  if (not LParser.IsComplete) and (not LParser.HasError) then
    LParser.Finish;

  if LParser.HasError then
    raise EHttpError.Create('HTTP parse error: ' + LParser.ErrorMessage);
  if not LParser.IsComplete then
    raise EHttpError.Create('HTTP response incomplete: connection closed');

  AKeepAlive := LParser.ShouldKeepAlive;

  LBodyReader := LParser.NewBodyReader;
  if LBodyReader <> nil then
  begin
    Result := THttpResponse.Create(LParser.GetStatusCode, LParser.GetHeaders,
      LBodyReader);
  end
  else
    Result := THttpResponse.Create(LParser.GetStatusCode, LParser.GetHeaders, nil);
end;

function TH1ClientTransport.RoundTrip(const AReq: IHttpRequest): IHttpResponse;
var
  LUrl: TUrl;
  LHost: string;
  LPort: UInt16;
  LConn: ITcpStream;
  LResp: IHttpResponse;
  LPooled: Boolean;
  LKeepAlive: Boolean;
  LBodyStream: IStream;
  LBodyStartPosition: Int64;
begin
  LUrl := AReq.Url;
  LHost := LUrl.Host;
  LPort := LUrl.Port;
  if LPort = 0 then
  begin
    if LUrl.Scheme = 'https' then
      LPort := 443
    else
      LPort := 80;
  end;

  CaptureRetryBodyPosition(AReq, LBodyStream, LBodyStartPosition);
  LConn := PoolGet(LHost, LPort);
  LPooled := LConn <> nil;
  if not LPooled then
    LConn := TcpConnect(LHost, LPort);

  if FOptions.Timeout > 0 then
  begin
    LConn.SetReadDeadline(TDeadline.After(TDuration.FromMilliseconds(FOptions.Timeout)));
    LConn.SetWriteDeadline(TDeadline.After(TDuration.FromMilliseconds(FOptions.Timeout)));
  end;

  if not AReq.Headers.Has('host') then
    AReq.Headers.SetHeader('host', LUrl.HostPort);

  try
    WriteRequest(LConn as IWriter, AReq);
    LResp := ReadResponse(LConn as IReader, AReq.Method, LKeepAlive);
  except
    if LPooled then
    begin
      LConn.Close;
      if not IsRetrySafeRequest(AReq) then
        raise;
      RewindRetryBody(AReq, LBodyStream, LBodyStartPosition);
      LConn := TcpConnect(LHost, LPort);
      if FOptions.Timeout > 0 then
      begin
        LConn.SetReadDeadline(TDeadline.After(TDuration.FromMilliseconds(FOptions.Timeout)));
        LConn.SetWriteDeadline(TDeadline.After(TDuration.FromMilliseconds(FOptions.Timeout)));
      end;
      WriteRequest(LConn as IWriter, AReq);
      LResp := ReadResponse(LConn as IReader, AReq.Method, LKeepAlive);
    end
    else
    begin
      LConn.Close;
      raise;
    end;
  end;

  if LKeepAlive then
    PoolPut(LHost, LPort, LConn)
  else
    LConn.Close;

  Result := LResp;
end;

procedure TH1ClientTransport.CloseIdleConnections;
begin
  PoolClear;
end;

{ TH1ServerTransport }

constructor TH1ServerTransport.Create(const AOptions: TH1ServerTransportOptions);
begin
  inherited Create;
  FOptions := AOptions;
end;

function TH1ServerTransport.HandleConnection(const AConn: ITcpStream;
  const AHandler: IHttpHandler): Boolean;
var
  LState: TH1ServerConnectionState;
begin
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
  Result := TH1ServerConnectionState.Create(AConn, AHandler, FOptions);
end;

function TH1ServerTransport.NewSession(const AConn: ITcpStream;
  const AHandler: IHttpHandler;
  const AContext: ITcpServerSessionContext): ITcpServerSession;
begin
  Result := TH1ServerConnectionState.Create(AConn, AHandler, FOptions, AContext);
end;

function NewH1ClientTransport(const AOptions: TH1ClientTransportOptions): IHttpTransport;
begin
  Result := TH1ClientTransport.Create(AOptions);
end;

function NewH1ServerTransport(const AOptions: TH1ServerTransportOptions): IHttpServerTransport;
begin
  Result := TH1ServerTransport.Create(AOptions);
end;

end.
