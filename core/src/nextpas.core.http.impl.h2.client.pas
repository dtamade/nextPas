unit nextpas.core.http.impl.h2.client;
{**
 * @desc HTTP/2 cleartext client transport and per-connection RoundTrip path.
 *       Implements client preface/SETTINGS handshake, synchronous request/
 *       response exchange, pooled connection reuse, flow-control bookkeeping,
 *       PING/GOAWAY handling, and registry-facing transport construction.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.net.intf,
  nextpas.core.sync,
  nextpas.core.time.deadline,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.impl.h2.frame,
  nextpas.core.http.impl.h2.hpack,
  nextpas.core.http.impl.h2.types,
  nextpas.core.tls.base;

type
  TH2ClientResponseBodyReader = class(TInterfacedObject, IReader)
  private
    FData: nextpas.core.base.TBytes;
    FPosition: SizeInt;
  public
    constructor Create(const AData: nextpas.core.base.TBytes);
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
  end;

  TH2ClientConnectionState = (
    h2ccsConnecting,
    h2ccsActive,
    h2ccsGoaway,
    h2ccsClosed
  );

  TH2ClientConnection = class(TInterfacedObject)
  private type
    TH2ResponseState = record
      StreamID: UInt32;
      StatusCode: THttpStatus;
      HeaderFragments: array of AnsiString;
      HeadersComplete: Boolean;
      HeadersDecoded: Boolean;
      HeadersStore: TObject;
      Headers: IHttpHeaders;
      Body: TBytes;
      BodyLen: SizeInt;
      EndStream: Boolean;
      Reset: Boolean;
      ResetCode: UInt32;
      PendingWindowUpdate: UInt32;
      class procedure Init(out AState: TH2ResponseState); static;
    end;
    TH2ActiveStreamState = record
      StreamID: UInt32;
      Flow: TH2StreamFlowControl;
    end;
  private
    FConn: ITcpStream;
    FOptions: TH2ClientTransportOptions;
    FState: TH2ClientConnectionState;
    FReadBuffer: AnsiString;
    FRemoteSettings: TH2Settings;
    FLocalSettings: TH2Settings;
    FConnectionFlow: TH2ConnectionFlowControl;
    FDecoder: THPackDecoder;
    FEncoder: THPackEncoder;
    FNextStreamID: UInt32;
    FPeerSettingsAcked: Boolean;
    FGoawayReceived: Boolean;
    FGoawaySent: Boolean;
    FLastPeerStreamID: UInt32;
    FPendingContinuationStreamID: UInt32;
    FPendingConnectionWindowUpdate: UInt32;
    FActiveStreams: array of TH2ActiveStreamState;
    FActiveStreamCount: SizeInt;
    FLastPingData: UInt64;
    procedure ApplyDeadline;
    procedure EnsureActive;
    procedure EnsureOpen;
    procedure TransitionClosed;
    function FillReadBuffer: Boolean;
    function DecodeNextFrame(out AFrame: TH2Frame; out AConsumed: SizeUInt): Boolean;
    function ReadFrame(out AFrame: TH2Frame): Boolean;
    procedure DiscardConsumed(const AConsumed: SizeUInt);
    procedure SendBytes(const ABytes: AnsiString);
    procedure SendFrame(const AFrameType: Byte; const AFlags: Byte;
      const AStreamID: UInt32; const APayload: AnsiString);
    procedure SendSettings;
    procedure SendSettingsAck;
    procedure SendPingAck(const AData: UInt64);
    procedure SendWindowUpdate(const AStreamID: UInt32; const AIncrement: UInt32);
    procedure SendGoaway(const ALastStreamID: UInt32; const AErrorCode: UInt32;
      const ADebugData: AnsiString = '');
    procedure FailConnection(const AErrorCode: UInt32; const ADebugData: AnsiString;
      const AMessage: string);
    procedure SendConnectionWindowDelta;
    function ParseSettingsPayload(const APayload: AnsiString;
      out ASettings: TH2Settings): Boolean;
    function AllocateStreamID: UInt32;
    function RequestPath(const AUrl: TUrl): AnsiString;
    function RequestAuthority(const AUrl: TUrl): AnsiString;
    function EncodeRequestHeaders(const AReq: IHttpRequest): AnsiString;
    procedure SendRequestHeaders(const AStreamID: UInt32; const AReq: IHttpRequest;
      const AEndStream: Boolean);
    function AddActiveStream(const AStreamID: UInt32): SizeInt;
    function FindActiveStreamIndex(const AStreamID: UInt32): SizeInt;
    procedure RemoveActiveStream(const AStreamID: UInt32);
    procedure ApplyRemoteInitialWindowSizeToActiveStreams(
      const ANewInitialWindowSize: UInt32);
    function RequestBodySendCapacity(
      const AStreamFlow: TH2StreamFlowControl): UInt32;
    procedure ReadRequestBodyFlowControlFrame(const AStreamID: UInt32;
      var AStreamFlow: TH2StreamFlowControl; var AResponse: TH2ResponseState);
    procedure SendRequestBody(const AStreamID: UInt32; const AReq: IHttpRequest;
      var AStreamFlow: TH2StreamFlowControl; var AResponse: TH2ResponseState);
    class function ExtractHeadersFragment(const AFlags: Byte;
      const APayload: AnsiString; out AFragment: AnsiString): Boolean; static;
    class function ExtractDataPayload(const AFlags: Byte;
      const APayload: AnsiString; out AData: AnsiString): Boolean; static;
    procedure AppendResponseHeaderFragment(var AResponse: TH2ResponseState;
      const AFragment: AnsiString);
    procedure DecodeResponseHeaders(var AResponse: TH2ResponseState);
    procedure AppendResponseBody(var AResponse: TH2ResponseState;
      const APayload: AnsiString);
    procedure ConsumeResponseBody(var AResponse: TH2ResponseState;
      const ABytes: UInt32);
    procedure FlushPendingConnectionWindowUpdate;
    procedure HandleSettings(const AFrame: TH2Frame);
    procedure HandleWindowUpdate(const AFrame: TH2Frame;
      const AStreamID: UInt32; var AStreamFlow: TH2StreamFlowControl);
    procedure HandlePing(const AFrame: TH2Frame);
    procedure HandleGoaway(const AFrame: TH2Frame);
    procedure HandleRstStream(const AFrame: TH2Frame;
      const AStreamID: UInt32; var AResponse: TH2ResponseState);
    procedure HandleHeaders(const AFrame: TH2Frame;
      const AStreamID: UInt32; var AResponse: TH2ResponseState);
    procedure HandleContinuation(const AFrame: TH2Frame;
      const AStreamID: UInt32; var AResponse: TH2ResponseState);
    procedure HandleData(const AFrame: TH2Frame; const AStreamID: UInt32;
      var AStreamFlow: TH2StreamFlowControl; var AResponse: TH2ResponseState);
    procedure DispatchFrame(const AFrame: TH2Frame; const AStreamID: UInt32;
      var AStreamFlow: TH2StreamFlowControl; var AResponse: TH2ResponseState);
    procedure DrainBufferedFrames(const AStreamID: UInt32;
      var AStreamFlow: TH2StreamFlowControl; var AResponse: TH2ResponseState);
    function BuildResponse(const AResponse: TH2ResponseState): IHttpResponse;
  public
    constructor Create(const AConn: ITcpStream;
      const AOptions: TH2ClientTransportOptions);
    destructor Destroy; override;
    function Handshake: Boolean;
    function RoundTrip(const AReq: IHttpRequest): IHttpResponse;
    { Same-connection multiplex: open concurrent streams, demux responses
      in request order. Does not change serial RoundTrip semantics. }
    function RoundTripMany(const AReqs: array of IHttpRequest): THttpResponseArray;
    function IsReusable: Boolean;
    { Active liveness probe for pool borrow: PING/ACK when PingTimeout > 0.
      Must not be called while holding the transport pool lock. }
    function ProbeHealth: Boolean;
    { Wire/clear IHttpCancelToken for mid-read/write cancel slices on FConn. }
    procedure ApplyCancelToken(const AToken: IHttpCancelToken);
    procedure ClearCancelToken;
    procedure Close;
    property State: TH2ClientConnectionState read FState;
    property NextStreamID: UInt32 read FNextStreamID;
  end;

  TH2ClientTransport = class(TInterfacedObject, IHttpTransport,
    IHttpTransportMultiplex, IHttpTransportIdleConnections)
  private type
    TH2PoolEntry = record
      Host: string;
      Port: UInt16;
      Secure: Boolean;
      Conn: TH2ClientConnection;
      IdleAtMs: UInt64;
    end;
  private
    FOptions: TH2ClientTransportOptions;
    FDefaultTLSContext: ISSLContext;
    FPoolLock: IMutex;
    FPool: array of TH2PoolEntry;
    FPoolCount: Int32;
    function PoolEntryExpired(const AEntry: TH2PoolEntry): Boolean;
    procedure PoolRemoveAt(const AIndex: Int32);
    function PoolGet(const AHost: string; const APort: UInt16;
      const ASecure: Boolean): TH2ClientConnection;
    procedure PoolPut(const AHost: string; const APort: UInt16;
      const ASecure: Boolean;
      const AConn: TH2ClientConnection);
    procedure PoolClear;
    function SecureClientContext: ISSLContext;
    function AcquireConnection(const AHost: string; const APort: UInt16;
      const ASecure: Boolean; out APooled: Boolean): TH2ClientConnection;
    procedure ReleaseConnection(const AHost: string; const APort: UInt16;
      const ASecure: Boolean; const AConn: TH2ClientConnection;
      const AReqHeaders: IHttpHeaders);
  public
    constructor Create(const AOptions: TH2ClientTransportOptions);
    destructor Destroy; override;
    function RoundTrip(const AReq: IHttpRequest): IHttpResponse;
    function RoundTripMany(const AReqs: array of IHttpRequest): THttpResponseArray;
    procedure CloseIdleConnections;
  end;

function NewH2ClientTransport(
  const AOptions: TH2ClientTransportOptions): IHttpTransport;

type
  { ADialTimeoutMs is the effective OS dial budget (ConnectTimeout or Timeout). }
  TH2ClientDialFunc = function(const AHost: string;
    const APort: UInt16; const ADialTimeoutMs: Int64): ITcpStream;

procedure SetH2ClientDialFuncForTests(const ADial: TH2ClientDialFunc);
procedure ResetH2ClientDialFuncForTests;

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.text.conv,
  nextpas.core.errors,
  nextpas.core.net,
  nextpas.core.time.base,
  nextpas.core.time,
  nextpas.core.http.headers,
  nextpas.core.http.message,
  nextpas.core.http.impl.tls.stream,
  nextpas.core.tls.http2.alpn,
  nextpas.core.tls.quick;

type
  TH2OwnedHeaders = class(THttpHeaders)
  end;

var
  GH2ClientDialFunc: TH2ClientDialFunc = nil;

{ TH2ClientResponseBodyReader }

constructor TH2ClientResponseBodyReader.Create(
  const AData: nextpas.core.base.TBytes);
begin
  inherited Create;
  FData := AData;
  FPosition := 0;
end;

function TH2ClientResponseBodyReader.Read(var ABuf;
  const ACount: SizeUInt): SizeUInt;
var
  LAvailable: SizeUInt;
begin
  Result := 0;
  if (ACount = 0) or (FPosition >= Length(FData)) then
    Exit;
  LAvailable := SizeUInt(Length(FData) - FPosition);
  if ACount < LAvailable then
    Result := ACount
  else
    Result := LAvailable;
  if Result = 0 then
    Exit;
  Move(FData[FPosition], ABuf, Result);
  Inc(FPosition, SizeInt(Result));
end;

function MinUInt32(const ALeft, ARight: UInt32): UInt32; inline;
begin
  if ALeft < ARight then
    Result := ALeft
  else
    Result := ARight;
end;

function CanonicalPoolHostKey(const AHost: string): string; inline;
begin
  Result := LowerCase(AHost);
end;

procedure ValidateH2ClientUrlScheme(const AUrl: TUrl);
var
  LScheme: string;
begin
  LScheme := LowerCase(AUrl.Scheme);
  if (LScheme <> '') and (LScheme <> 'http') and (LScheme <> 'https') then
    raise EHttpError.Create(hekParse, 'unsupported HTTP client URL scheme: ' +
      AUrl.Scheme);
end;

function HeadersHaveConnectionCloseToken(const AHeaders: IHttpHeaders): Boolean;
var
  LValues: TStringArray;
  LI: SizeInt;
begin
  Result := False;
  if AHeaders = nil then
    Exit;
  LValues := AHeaders.GetAll('connection');
  for LI := Low(LValues) to High(LValues) do
    if Pos('close', LowerCase(LValues[LI])) > 0 then
      Exit(True);
end;

function IsH2ForbiddenRequestHeader(const AName: string): Boolean; inline;
begin
  Result :=
    (AName = 'connection') or
    (AName = 'upgrade') or
    (AName = 'keep-alive') or
    (AName = 'proxy-connection') or
    (AName = 'transfer-encoding');
end;

function IsRetryableMethod(const AMethod: THttpMethod): Boolean; inline;
begin
  Result := HttpIsRetryableMethod(AMethod);
end;

function HasRetryIdempotencyKey(const AReq: IHttpRequest): Boolean; inline;
begin
  Result := HttpHasRetryIdempotencyKey(AReq);
end;

function IsRetrySafeRequest(const AReq: IHttpRequest): Boolean; inline;
begin
  Result := HttpIsRetrySafeRequest(AReq);
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
    raise EHttpError.Create(hekBody, 'pooled retry request body is not replayable');
  ABodyStream.Position := AStartPosition;
end;

function ClientRequestDeadline(const ATimeoutMs: Int64): TDeadline;
begin
  if ATimeoutMs > 0 then
    Result := TDeadline.After(TDuration.FromMilliseconds(ATimeoutMs))
  else
    Result := TDeadline.Infinite;
end;

procedure ApplyClientDeadline(const AConn: ITcpStream; const ADeadline: TDeadline);
begin
  { Always set, including Infinite, so Timeout=0 can clear a prior ConnectTimeout. }
  AConn.SetReadDeadline(ADeadline);
  AConn.SetWriteDeadline(ADeadline);
end;

type
  { Bridge IHttpCancelToken → INetCancelToken; forward waitable when present. }
  THttpNetCancelAdapter = class(TInterfacedObject, INetCancelToken, INetCancelWaitable)
  private
    FToken: IHttpCancelToken;
    FWaitable: INetCancelWaitable;
  public
    constructor Create(const AToken: IHttpCancelToken);
    function IsCanceled: Boolean;
    function WakeHandle: PtrUInt;
    procedure DrainWake;
  end;

constructor THttpNetCancelAdapter.Create(const AToken: IHttpCancelToken);
begin
  inherited Create;
  FToken := AToken;
  FWaitable := nil;
  if (AToken <> nil) and
     (AToken.QueryInterface(INetCancelWaitable, FWaitable) <> 0) then
    FWaitable := nil;
end;

function THttpNetCancelAdapter.IsCanceled: Boolean;
begin
  Result := (FToken <> nil) and FToken.IsCanceled;
end;

function THttpNetCancelAdapter.WakeHandle: PtrUInt;
begin
  if FWaitable <> nil then
    Result := FWaitable.WakeHandle
  else
    Result := 0;
end;

procedure THttpNetCancelAdapter.DrainWake;
begin
  if FWaitable <> nil then
    FWaitable.DrainWake;
end;

function DefaultH2ClientDial(const AHost: string; const APort: UInt16;
  const ADialTimeoutMs: Int64): ITcpStream;
begin
  if ADialTimeoutMs > 0 then
    Result := TcpConnect(AHost, APort, ADialTimeoutMs)
  else
    Result := TcpConnect(AHost, APort);
end;

procedure SetH2ClientDialFuncForTests(const ADial: TH2ClientDialFunc);
begin
  GH2ClientDialFunc := ADial;
end;

procedure ResetH2ClientDialFuncForTests;
begin
  GH2ClientDialFunc := nil;
end;

{ H1-compatible dial budget: ConnectTimeout>0 wins, else Timeout (0=unbounded). }
function H2ClientDial(const AHost: string; const APort: UInt16;
  const AConnectTimeoutMs, ATimeoutMs: Int64): ITcpStream;
var
  LDialMs: Int64;
begin
  if AConnectTimeoutMs > 0 then
    LDialMs := AConnectTimeoutMs
  else
    LDialMs := ATimeoutMs;
  if Assigned(GH2ClientDialFunc) then
    Result := GH2ClientDialFunc(AHost, APort, LDialMs)
  else
    Result := DefaultH2ClientDial(AHost, APort, LDialMs);
end;

{ TH2ClientConnection.TH2ResponseState }

class procedure TH2ClientConnection.TH2ResponseState.Init(
  out AState: TH2ResponseState);
begin
  AState.StreamID := 0;
  AState.StatusCode := 0;
  AState.HeaderFragments := nil;
  AState.HeadersComplete := False;
  AState.HeadersDecoded := False;
  AState.HeadersStore := nil;
  AState.Headers := nil;
  AState.Body := nil;
  AState.BodyLen := 0;
  AState.EndStream := False;
  AState.Reset := False;
  AState.ResetCode := H2_ERR_NO_ERROR;
  AState.PendingWindowUpdate := 0;
end;

{ TH2ClientConnection }

constructor TH2ClientConnection.Create(const AConn: ITcpStream;
  const AOptions: TH2ClientTransportOptions);
begin
  inherited Create;
  if AConn = nil then
    raise EHttpError.Create(hekArgument, 'h2 client connection requires connection');
  AOptions.Validate;
  FConn := AConn;
  FOptions := AOptions;
  FState := h2ccsConnecting;
  FReadBuffer := '';
  FRemoteSettings := TH2Settings.Default;
  FLocalSettings := FOptions.ToSettings;
  FConnectionFlow.Init(FRemoteSettings.InitialWindowSize,
    FOptions.InitialConnectionWindowSize);
  FDecoder.Init(FLocalSettings.HeaderTableSize);
  FEncoder.Init(FLocalSettings.HeaderTableSize);
  FNextStreamID := H2_MIN_STREAM_ID;
  FPeerSettingsAcked := False;
  FGoawayReceived := False;
  FGoawaySent := False;
  FLastPeerStreamID := 0;
  FPendingContinuationStreamID := 0;
  FPendingConnectionWindowUpdate := 0;
  FActiveStreams := nil;
  FActiveStreamCount := 0;
  FLastPingData := 0;
end;

destructor TH2ClientConnection.Destroy;
begin
  Close;
  inherited Destroy;
end;

procedure TH2ClientConnection.ApplyDeadline;
begin
  ApplyClientDeadline(FConn, ClientRequestDeadline(FOptions.Timeout));
end;

procedure TH2ClientConnection.EnsureActive;
begin
  if FState <> h2ccsActive then
    raise EHttpError.Create(hekProtocol, 'h2 client connection is not active');
end;

procedure TH2ClientConnection.EnsureOpen;
begin
  if FState = h2ccsClosed then
    raise EHttpError.Create(hekProtocol, 'h2 client connection is closed');
end;

procedure TH2ClientConnection.TransitionClosed;
begin
  FState := h2ccsClosed;
end;

function TH2ClientConnection.FillReadBuffer: Boolean;
var
  LBuf: array[0..4095] of Byte;
  LRead: SizeUInt;
  LOldLen: SizeInt;
begin
  Result := False;
  LRead := FConn.Read(LBuf[0], SizeOf(LBuf));
  if LRead = 0 then
    Exit;
  LOldLen := Length(FReadBuffer);
  SetLength(FReadBuffer, LOldLen + SizeInt(LRead));
  Move(LBuf[0], FReadBuffer[LOldLen + 1], LRead);
  Result := True;
end;

function TH2ClientConnection.DecodeNextFrame(out AFrame: TH2Frame;
  out AConsumed: SizeUInt): Boolean;
begin
  if FReadBuffer = '' then
  begin
    AFrame := Default(TH2Frame);
    AConsumed := 0;
    Exit(False);
  end;
  Result := H2DecodeFrame(@FReadBuffer[1], Length(FReadBuffer), AFrame,
    AConsumed);
end;

function TH2ClientConnection.ReadFrame(out AFrame: TH2Frame): Boolean;
var
  LConsumed: SizeUInt;
  LErrorCode: UInt32;
begin
  while not DecodeNextFrame(AFrame, LConsumed) do
  begin
    if not FillReadBuffer then
    begin
      TransitionClosed;
      Exit(False);
    end;
  end;
  if not H2ValidateFrame(AFrame, FRemoteSettings.MaxFrameSize, LErrorCode) then
    FailConnection(LErrorCode, AnsiString(H2FrameTypeName(
      AFrame.Header.FrameType)), 'HTTP/2 frame validation failed: ' +
      H2ErrorCodeName(LErrorCode));
  DiscardConsumed(LConsumed);
  Result := True;
end;

procedure TH2ClientConnection.DiscardConsumed(const AConsumed: SizeUInt);
var
  LRemain: SizeInt;
begin
  if AConsumed = 0 then
    Exit;
  if AConsumed >= SizeUInt(Length(FReadBuffer)) then
  begin
    FReadBuffer := '';
    Exit;
  end;
  LRemain := Length(FReadBuffer) - SizeInt(AConsumed);
  FReadBuffer := Copy(FReadBuffer, SizeInt(AConsumed) + 1, LRemain);
end;

procedure TH2ClientConnection.SendBytes(const ABytes: AnsiString);
var
  LOffset: SizeInt;
  LWritten: SizeUInt;
  LLen: SizeUInt;
begin
  if ABytes = '' then
    Exit;
  LOffset := 1;
  LLen := Length(ABytes);
  while SizeUInt(LOffset) <= LLen do
  begin
    LWritten := FConn.Write(ABytes[LOffset], LLen - SizeUInt(LOffset) + 1);
    if LWritten = 0 then
    begin
      TransitionClosed;
      raise EHttpError.Create(hekProtocol, 'HTTP/2 client write failed: connection closed');
    end;
    Inc(LOffset, SizeInt(LWritten));
  end;
end;

procedure TH2ClientConnection.SendFrame(const AFrameType: Byte; const AFlags: Byte;
  const AStreamID: UInt32; const APayload: AnsiString);
begin
  SendBytes(H2EncodeFrame(AFrameType, AFlags, AStreamID, APayload));
end;

procedure TH2ClientConnection.SendSettings;
var
  LEntries: TH2SettingEntries;
begin
  SetLength(LEntries, 5);
  LEntries[0].Identifier := H2_SETTINGS_HEADER_TABLE_SIZE;
  LEntries[0].Value := FLocalSettings.HeaderTableSize;
  LEntries[1].Identifier := H2_SETTINGS_ENABLE_PUSH;
  if FLocalSettings.EnablePush then
    LEntries[1].Value := 1
  else
    LEntries[1].Value := 0;
  LEntries[2].Identifier := H2_SETTINGS_MAX_CONCURRENT_STREAMS;
  LEntries[2].Value := FLocalSettings.MaxConcurrentStreams;
  LEntries[3].Identifier := H2_SETTINGS_INITIAL_WINDOW_SIZE;
  LEntries[3].Value := FLocalSettings.InitialWindowSize;
  LEntries[4].Identifier := H2_SETTINGS_MAX_FRAME_SIZE;
  LEntries[4].Value := FLocalSettings.MaxFrameSize;
  SendFrame(H2_FRAME_SETTINGS, 0, 0, H2EncodeSettingsPayload(LEntries));
end;

procedure TH2ClientConnection.SendSettingsAck;
begin
  SendFrame(H2_FRAME_SETTINGS, H2_FLAG_SETTINGS_ACK, 0, '');
end;

procedure TH2ClientConnection.SendPingAck(const AData: UInt64);
begin
  SendFrame(H2_FRAME_PING, H2_FLAG_PING_ACK, 0, H2EncodePing(AData));
end;

procedure TH2ClientConnection.SendWindowUpdate(const AStreamID: UInt32;
  const AIncrement: UInt32);
begin
  if AIncrement = 0 then
    Exit;
  SendFrame(H2_FRAME_WINDOW_UPDATE, 0, AStreamID,
    H2EncodeWindowUpdate(AIncrement));
end;

procedure TH2ClientConnection.SendGoaway(const ALastStreamID: UInt32;
  const AErrorCode: UInt32; const ADebugData: AnsiString);
begin
  if FGoawaySent then
    Exit;
  SendFrame(H2_FRAME_GOAWAY, 0, 0,
    H2EncodeGoaway(ALastStreamID, AErrorCode, ADebugData));
  FGoawaySent := True;
  if FState <> h2ccsClosed then
    FState := h2ccsGoaway;
end;

procedure TH2ClientConnection.FailConnection(const AErrorCode: UInt32;
  const ADebugData: AnsiString; const AMessage: string);
begin
  try
    if FConn <> nil then
      SendGoaway(FLastPeerStreamID, AErrorCode, ADebugData);
  finally
    if FConn <> nil then
    begin
      try
        FConn.Close;
      except
      end;
      FConn := nil;
    end;
    TransitionClosed;
  end;
  raise EHttpError.Create(hekProtocol, AMessage);
end;

procedure TH2ClientConnection.SendConnectionWindowDelta;
var
  LDelta: UInt32;
begin
  if FOptions.InitialConnectionWindowSize <= H2_DEFAULT_INITIAL_WINDOW_SIZE then
    Exit;
  LDelta := FOptions.InitialConnectionWindowSize -
    H2_DEFAULT_INITIAL_WINDOW_SIZE;
  SendWindowUpdate(0, LDelta);
end;

function TH2ClientConnection.ParseSettingsPayload(const APayload: AnsiString;
  out ASettings: TH2Settings): Boolean;
var
  LEntries: TH2SettingEntries;
  LI: SizeInt;
begin
  ASettings := FRemoteSettings;
  if not H2DecodeSettingsPayload(APayload, LEntries) then
    Exit(False);
  for LI := 0 to High(LEntries) do
  begin
    case LEntries[LI].Identifier of
      H2_SETTINGS_HEADER_TABLE_SIZE:
        ASettings.HeaderTableSize := LEntries[LI].Value;
      H2_SETTINGS_ENABLE_PUSH:
        begin
          if LEntries[LI].Value > 1 then
            Exit(False);
          ASettings.EnablePush := LEntries[LI].Value <> 0;
        end;
      H2_SETTINGS_MAX_CONCURRENT_STREAMS:
        ASettings.MaxConcurrentStreams := LEntries[LI].Value;
      H2_SETTINGS_INITIAL_WINDOW_SIZE:
        ASettings.InitialWindowSize := LEntries[LI].Value;
      H2_SETTINGS_MAX_FRAME_SIZE:
        ASettings.MaxFrameSize := LEntries[LI].Value;
      H2_SETTINGS_MAX_HEADER_LIST_SIZE:
        ASettings.MaxHeaderListSize := LEntries[LI].Value;
    end;
  end;
  try
    ASettings.Validate;
  except
    Exit(False);
  end;
  Result := True;
end;

function TH2ClientConnection.AllocateStreamID: UInt32;
begin
  if FNextStreamID = 0 then
    raise EHttpError.Create(hekProtocol, 'HTTP/2 client stream ID overflow');
  Result := FNextStreamID;
  if Result > H2_MAX_STREAM_ID - 2 then
    FNextStreamID := 0
  else
    Inc(FNextStreamID, 2);
end;

function TH2ClientConnection.RequestPath(const AUrl: TUrl): AnsiString;
begin
  Result := AnsiString(AUrl.Path);
  if Result = '' then
    Result := '/';
  if AUrl.RawQuery <> '' then
    Result := Result + '?' + AnsiString(AUrl.RawQuery);
end;

function TH2ClientConnection.RequestAuthority(const AUrl: TUrl): AnsiString;
begin
  Result := AnsiString(AUrl.HostPort);
end;

function TH2ClientConnection.EncodeRequestHeaders(const AReq: IHttpRequest): AnsiString;
var
  LHeaderList: array of THPackHeader;
  LHeaderCount: SizeInt;
  LUrl: TUrl;
begin
  LUrl := AReq.Url;
  LHeaderCount := 4;
  if AReq.Headers <> nil then
    LHeaderCount := LHeaderCount + AReq.Headers.Count;
  SetLength(LHeaderList, LHeaderCount);
  LHeaderList[0].Name := ':method';
  LHeaderList[0].Value := AnsiString(HttpMethodToStr(AReq.Method));
  LHeaderList[1].Name := ':scheme';
  if LUrl.Scheme <> '' then
    LHeaderList[1].Value := AnsiString(LUrl.Scheme)
  else
    LHeaderList[1].Value := 'http';
  LHeaderList[2].Name := ':authority';
  LHeaderList[2].Value := RequestAuthority(LUrl);
  LHeaderList[3].Name := ':path';
  LHeaderList[3].Value := RequestPath(LUrl);
  LHeaderCount := 4;
  if AReq.Headers <> nil then
    AReq.Headers.ForEach(
      procedure(const AName, AValue: string)
      begin
        if AName = '' then
          Exit;
        if AName[1] = ':' then
          Exit;
        if AName = 'host' then
          Exit;
        if IsH2ForbiddenRequestHeader(AName) then
          Exit;
        if (AName = 'te') and (AValue <> 'trailers') then
          Exit;
        LHeaderList[LHeaderCount].Name := AnsiString(AName);
        LHeaderList[LHeaderCount].Value := AnsiString(AValue);
        Inc(LHeaderCount);
      end);
  SetLength(LHeaderList, LHeaderCount);
  Result := FEncoder.Encode(LHeaderList);
end;

procedure TH2ClientConnection.SendRequestHeaders(const AStreamID: UInt32;
  const AReq: IHttpRequest; const AEndStream: Boolean);
var
  LFlags: Byte;
begin
  LFlags := H2_FLAG_HEADERS_END_HEADERS;
  if AEndStream then
    LFlags := LFlags or H2_FLAG_HEADERS_END_STREAM;
  SendFrame(H2_FRAME_HEADERS, LFlags, AStreamID, EncodeRequestHeaders(AReq));
end;

function TH2ClientConnection.FindActiveStreamIndex(
  const AStreamID: UInt32): SizeInt;
var
  LI: SizeInt;
begin
  for LI := 0 to FActiveStreamCount - 1 do
    if FActiveStreams[LI].StreamID = AStreamID then
      Exit(LI);
  Result := -1;
end;

function TH2ClientConnection.AddActiveStream(const AStreamID: UInt32): SizeInt;
begin
  if FindActiveStreamIndex(AStreamID) >= 0 then
    raise EHttpError.Create(hekProtocol, 'HTTP/2 client stream is already active');
  if FActiveStreamCount >= Length(FActiveStreams) then
    SetLength(FActiveStreams, FActiveStreamCount + 4);
  Result := FActiveStreamCount;
  FActiveStreams[Result].StreamID := AStreamID;
  FActiveStreams[Result].Flow.Init(AStreamID, FRemoteSettings.InitialWindowSize,
    FLocalSettings.InitialWindowSize);
  Inc(FActiveStreamCount);
end;

procedure TH2ClientConnection.RemoveActiveStream(const AStreamID: UInt32);
var
  LIndex: SizeInt;
begin
  LIndex := FindActiveStreamIndex(AStreamID);
  if LIndex < 0 then
    Exit;
  Dec(FActiveStreamCount);
  if LIndex <> FActiveStreamCount then
    FActiveStreams[LIndex] := FActiveStreams[FActiveStreamCount];
  FActiveStreams[FActiveStreamCount] := Default(TH2ActiveStreamState);
end;

procedure TH2ClientConnection.ApplyRemoteInitialWindowSizeToActiveStreams(
  const ANewInitialWindowSize: UInt32);
var
  LI: SizeInt;
begin
  for LI := 0 to FActiveStreamCount - 1 do
    FActiveStreams[LI].Flow.ApplyPeerInitialWindowSize(ANewInitialWindowSize);
end;

function TH2ClientConnection.RequestBodySendCapacity(
  const AStreamFlow: TH2StreamFlowControl): UInt32;
var
  LCapacity: Int64;
  LStreamCapacity: Int64;
begin
  LCapacity := FConnectionFlow.SendWindow.AvailableCapacity;
  LStreamCapacity := AStreamFlow.SendWindow.AvailableCapacity;
  if LStreamCapacity < LCapacity then
    LCapacity := LStreamCapacity;
  if LCapacity <= 0 then
    Exit(0);
  if LCapacity > High(UInt32) then
    Exit(High(UInt32));
  Result := UInt32(LCapacity);
end;

procedure TH2ClientConnection.ReadRequestBodyFlowControlFrame(
  const AStreamID: UInt32; var AStreamFlow: TH2StreamFlowControl;
  var AResponse: TH2ResponseState);
var
  LFrame: TH2Frame;
begin
  if not ReadFrame(LFrame) then
    raise EHttpError.Create(hekProtocol,
      'HTTP/2 client request body stalled: connection closed');
  DispatchFrame(LFrame, AStreamID, AStreamFlow, AResponse);
  if AResponse.PendingWindowUpdate > 0 then
  begin
    SendWindowUpdate(AStreamID, AResponse.PendingWindowUpdate);
    AResponse.PendingWindowUpdate := 0;
  end;
  FlushPendingConnectionWindowUpdate;
  if AResponse.Reset then
    raise EHttpError.Create(hekProtocol, 'HTTP/2 stream ' + IntToStr(AStreamID) + ' reset while sending request body: ' +
      H2ErrorCodeName(AResponse.ResetCode));
end;

procedure TH2ClientConnection.SendRequestBody(const AStreamID: UInt32;
  const AReq: IHttpRequest; var AStreamFlow: TH2StreamFlowControl;
  var AResponse: TH2ResponseState);
var
  LRemaining: Int64;
  LRead: SizeUInt;
  LChunkSize: UInt32;
  LCapacity: UInt32;
  LBuffer: array of Byte;
  LPayload: AnsiString;
  LFlags: Byte;
begin
  if (AReq.Body = nil) or (AReq.ContentLength <= 0) then
    Exit;

  LRemaining := AReq.ContentLength;
  while LRemaining > 0 do
  begin
    LCapacity := RequestBodySendCapacity(AStreamFlow);
    while LCapacity = 0 do
    begin
      ReadRequestBodyFlowControlFrame(AStreamID, AStreamFlow, AResponse);
      LCapacity := RequestBodySendCapacity(AStreamFlow);
    end;
    LChunkSize := MinUInt32(FRemoteSettings.MaxFrameSize, LCapacity);
    if Int64(LChunkSize) > LRemaining then
      LChunkSize := UInt32(LRemaining);
    SetLength(LBuffer, LChunkSize);
    LRead := AReq.Body.Read(LBuffer[0], LChunkSize);
    if LRead = 0 then
      raise EHttpError.Create(hekBody, 'HTTP/2 client request body ended before content-length');
    if not FConnectionFlow.SendWindow.TryReserve(UInt32(LRead)) then
      raise EHttpError.Create(hekProtocol, 'HTTP/2 client connection send window reserve failed');
    if not AStreamFlow.SendWindow.TryReserve(UInt32(LRead)) then
    begin
      FConnectionFlow.SendWindow.ReleaseReserved(UInt32(LRead));
      raise EHttpError.Create(hekProtocol, 'HTTP/2 client stream send window reserve failed');
    end;
    SetLength(LPayload, LRead);
    Move(LBuffer[0], LPayload[1], LRead);
    FConnectionFlow.SendWindow.CommitSend(UInt32(LRead));
    AStreamFlow.SendWindow.CommitSend(UInt32(LRead));
    Dec(LRemaining, UInt32(LRead));
    if LRemaining = 0 then
      LFlags := H2_FLAG_DATA_END_STREAM
    else
      LFlags := 0;
    SendFrame(H2_FRAME_DATA, LFlags, AStreamID, LPayload);
  end;
end;

class function TH2ClientConnection.ExtractHeadersFragment(const AFlags: Byte;
  const APayload: AnsiString; out AFragment: AnsiString): Boolean;
var
  LPadLength: SizeInt;
  LStart: SizeInt;
  LFragmentLen: SizeInt;
begin
  Result := False;
  AFragment := '';
  LStart := 1;
  LPadLength := 0;
  if (AFlags and H2_FLAG_HEADERS_PADDED) <> 0 then
  begin
    if Length(APayload) < 1 then
      Exit;
    LPadLength := Byte(APayload[1]);
    Inc(LStart);
  end;
  if (AFlags and H2_FLAG_HEADERS_PRIORITY) <> 0 then
  begin
    if Length(APayload) < LStart + 4 then
      Exit;
    Inc(LStart, 5);
  end;
  LFragmentLen := Length(APayload) - LStart + 1 - LPadLength;
  if LFragmentLen < 0 then
    Exit;
  if LFragmentLen > 0 then
    AFragment := Copy(APayload, LStart, LFragmentLen);
  Result := True;
end;

class function TH2ClientConnection.ExtractDataPayload(const AFlags: Byte;
  const APayload: AnsiString; out AData: AnsiString): Boolean;
var
  LPadLength: SizeInt;
begin
  Result := False;
  AData := '';
  if (AFlags and H2_FLAG_DATA_PADDED) = 0 then
  begin
    AData := APayload;
    Exit(True);
  end;
  if Length(APayload) < 1 then
    Exit;
  LPadLength := Byte(APayload[1]);
  if Length(APayload) < 1 + LPadLength then
    Exit;
  if Length(APayload) > 1 + LPadLength then
    AData := Copy(APayload, 2, Length(APayload) - 1 - LPadLength);
  Result := True;
end;

procedure TH2ClientConnection.AppendResponseHeaderFragment(
  var AResponse: TH2ResponseState; const AFragment: AnsiString);
const
  { Hard cap to prevent unlimited memory growth when MaxHeaderListSize = 0 }
  H2_HEADER_HARD_CAP = 64 * 1024;
var
  LLen: SizeInt;
  LTotalBytes: SizeInt;
  LI: SizeInt;
begin
  LLen := Length(AResponse.HeaderFragments);
  { Calculate total header bytes to prevent memory DoS }
  LTotalBytes := Length(AFragment);
  for LI := 0 to LLen - 1 do
    Inc(LTotalBytes, Length(AResponse.HeaderFragments[LI]));
  if (FOptions.MaxHeaderListSize > 0) and (LTotalBytes > FOptions.MaxHeaderListSize) then
    raise EHttpError.Create(hekProtocol, 'HTTP/2 response headers too large');
  if LTotalBytes > H2_HEADER_HARD_CAP then
    raise EHttpError.Create(hekProtocol, 'HTTP/2 response headers exceed hard cap');
  SetLength(AResponse.HeaderFragments, LLen + 1);
  AResponse.HeaderFragments[LLen] := AFragment;
end;

procedure TH2ClientConnection.DecodeResponseHeaders(var AResponse: TH2ResponseState);
var
  LHeaders: array of THPackHeaderView;
  LBlock: AnsiString;
  LNameStr: AnsiString;
  LTotalLen: SizeInt;
  LWritePos: SizeInt;
  LI: SizeInt;
  LStatusText: string;
  LStatusValue: Int64;
  LValueStr: AnsiString;
  LStatusSeen: Boolean;
  LRegularSeen: Boolean;
  LNameLower: AnsiString;
  LJ: SizeInt;
begin
  if AResponse.HeadersDecoded then
    Exit;
  LTotalLen := 0;
  for LI := 0 to High(AResponse.HeaderFragments) do
    Inc(LTotalLen, Length(AResponse.HeaderFragments[LI]));
  SetLength(LBlock, LTotalLen);
  LWritePos := 1;
  for LI := 0 to High(AResponse.HeaderFragments) do
  begin
    if AResponse.HeaderFragments[LI] = '' then
      Continue;
    Move(AResponse.HeaderFragments[LI][1], LBlock[LWritePos],
      Length(AResponse.HeaderFragments[LI]));
    Inc(LWritePos, Length(AResponse.HeaderFragments[LI]));
  end;
  SetLength(LHeaders, Length(LBlock));
  if not FDecoder.DecodeView(LBlock, LHeaders) then
    raise EHttpError.Create(hekProtocol, 'HTTP/2 client HPACK decode failed');
  if AResponse.HeadersStore = nil then
  begin
    AResponse.HeadersStore := TH2OwnedHeaders.Create;
    AResponse.Headers := TH2OwnedHeaders(AResponse.HeadersStore);
  end;
  LStatusText := '';
  LStatusSeen := False;
  LRegularSeen := False;
  for LI := 0 to High(LHeaders) do
  begin
    if LHeaders[LI].Name.Ptr = nil then
      Break;
    SetString(LNameStr, LHeaders[LI].Name.Ptr, LHeaders[LI].Name.Len);
    SetString(LValueStr, LHeaders[LI].Value.Ptr, LHeaders[LI].Value.Len);
    if LNameStr = ':status' then
    begin
      { RFC 9113 §8.1: only :status pseudo-header allowed in response }
      if LStatusSeen or LRegularSeen then
        raise EHttpError.Create(hekProtocol, 'HTTP/2 invalid response pseudo-header order');
      LStatusText := string(LValueStr);
      LStatusSeen := True;
    end
    else if (Length(LNameStr) > 0) and (LNameStr[1] = ':') then
    begin
      { No other pseudo-headers allowed in response }
      raise EHttpError.Create(hekProtocol, 'HTTP/2 invalid response pseudo-header: ' + string(LNameStr));
    end
    else
    begin
      LRegularSeen := True;
      { RFC 9113 §8.2: field names MUST be lowercase }
      for LJ := 1 to Length(LNameStr) do
        if (LNameStr[LJ] >= 'A') and (LNameStr[LJ] <= 'Z') then
          raise EHttpError.Create(hekProtocol, 'HTTP/2 response header not lowercase: ' + string(LNameStr));
      { Reject connection-specific headers }
      if (LNameStr = 'connection') or (LNameStr = 'upgrade') or
         (LNameStr = 'keep-alive') or (LNameStr = 'proxy-connection') or
         (LNameStr = 'transfer-encoding') then
        raise EHttpError.Create(hekProtocol, 'HTTP/2 forbidden response header: ' + string(LNameStr));
      if (LNameStr = 'te') and (LValueStr <> 'trailers') then
        raise EHttpError.Create(hekProtocol, 'HTTP/2 invalid TE header value');
      TH2OwnedHeaders(AResponse.HeadersStore).Add(string(LNameStr),
        string(LValueStr));
    end;
  end;
  if (LStatusText = '') or (not TryStrToInt64(LStatusText, LStatusValue)) then
    raise EHttpError.Create(hekProtocol, 'HTTP/2 response missing valid :status');
  if (LStatusValue < 100) or (LStatusValue > 599) then
    raise EHttpError.Create(hekProtocol, 'HTTP/2 :status out of range: ' + LStatusText);
  AResponse.StatusCode := THttpStatus(LStatusValue);
  AResponse.HeadersDecoded := True;
end;

procedure TH2ClientConnection.AppendResponseBody(var AResponse: TH2ResponseState;
  const APayload: AnsiString);
var
  LOldLen: SizeInt;
  LPayloadLen: SizeInt;
begin
  LPayloadLen := Length(APayload);
  if LPayloadLen = 0 then
    Exit;
  { Prevent memory DoS from unbounded body accumulation }
  if (FOptions.MaxResponseBodySize > 0) and
     (AResponse.BodyLen + LPayloadLen > SizeInt(FOptions.MaxResponseBodySize)) then
    raise EHttpError.Create(hekProtocol, 'HTTP/2 response body too large');
  LOldLen := Length(AResponse.Body);
  SetLength(AResponse.Body, LOldLen + LPayloadLen);
  Move(APayload[1], AResponse.Body[LOldLen], LPayloadLen);
  AResponse.BodyLen := Length(AResponse.Body);
end;

procedure TH2ClientConnection.ConsumeResponseBody(var AResponse: TH2ResponseState;
  const ABytes: UInt32);
begin
  if ABytes = 0 then
    Exit;
  FConnectionFlow.RecvWindow.OnDataConsumed(ABytes);
  if FPendingConnectionWindowUpdate <= High(UInt32) - ABytes then
    Inc(FPendingConnectionWindowUpdate, ABytes)
  else
    FPendingConnectionWindowUpdate := High(UInt32);
  if AResponse.PendingWindowUpdate <= High(UInt32) - ABytes then
    Inc(AResponse.PendingWindowUpdate, ABytes)
  else
    AResponse.PendingWindowUpdate := High(UInt32);
end;

procedure TH2ClientConnection.FlushPendingConnectionWindowUpdate;
begin
  if FPendingConnectionWindowUpdate > 0 then
  begin
    SendWindowUpdate(0, FPendingConnectionWindowUpdate);
    FPendingConnectionWindowUpdate := 0;
  end;
end;

procedure TH2ClientConnection.HandleSettings(const AFrame: TH2Frame);
var
  LSettings: TH2Settings;
  LOldInitialWindowSize: UInt32;
begin
  if (AFrame.Header.Flags and H2_FLAG_SETTINGS_ACK) <> 0 then
  begin
    FPeerSettingsAcked := True;
    Exit;
  end;
  if not ParseSettingsPayload(AFrame.Payload, LSettings) then
    raise EHttpError.Create(hekProtocol, 'HTTP/2 invalid SETTINGS payload');
  LOldInitialWindowSize := FRemoteSettings.InitialWindowSize;
  FRemoteSettings := LSettings;
  if FRemoteSettings.InitialWindowSize <> LOldInitialWindowSize then
    ApplyRemoteInitialWindowSizeToActiveStreams(
      FRemoteSettings.InitialWindowSize);
  FEncoder.SetDynamicTableSize(FRemoteSettings.HeaderTableSize);
  SendSettingsAck;
end;

procedure TH2ClientConnection.HandleWindowUpdate(const AFrame: TH2Frame;
  const AStreamID: UInt32; var AStreamFlow: TH2StreamFlowControl);
var
  LIncrement: UInt32;
begin
  if not H2DecodeWindowUpdate(AFrame.Payload, LIncrement) then
    raise EHttpError.Create(hekProtocol, 'HTTP/2 invalid WINDOW_UPDATE payload');
  if AFrame.Header.StreamID = 0 then
    FConnectionFlow.SendWindow.OnWindowUpdate(LIncrement)
  else if AFrame.Header.StreamID = AStreamID then
    AStreamFlow.SendWindow.OnWindowUpdate(LIncrement);
end;

procedure TH2ClientConnection.HandlePing(const AFrame: TH2Frame);
var
  LData: UInt64;
begin
  if not H2DecodePing(AFrame.Payload, LData) then
    raise EHttpError.Create(hekProtocol, 'HTTP/2 invalid PING payload');
  if (AFrame.Header.Flags and H2_FLAG_PING_ACK) = 0 then
    SendPingAck(LData)
  else
    FLastPingData := LData;
end;

procedure TH2ClientConnection.HandleGoaway(const AFrame: TH2Frame);
var
  LErrorCode: UInt32;
  LDebugData: AnsiString;
  LLastStreamID: UInt32;
begin
  if not H2DecodeGoaway(AFrame.Payload, LLastStreamID, LErrorCode, LDebugData) then
    raise EHttpError.Create(hekProtocol, 'HTTP/2 invalid GOAWAY payload');
  FGoawayReceived := True;
  FLastPeerStreamID := LLastStreamID;
  if FState <> h2ccsClosed then
    FState := h2ccsGoaway;
end;

procedure TH2ClientConnection.HandleRstStream(const AFrame: TH2Frame;
  const AStreamID: UInt32; var AResponse: TH2ResponseState);
var
  LErrorCode: UInt32;
begin
  if not H2DecodeRstStream(AFrame.Payload, LErrorCode) then
    raise EHttpError.Create(hekProtocol, 'HTTP/2 invalid RST_STREAM payload');
  if AFrame.Header.StreamID = AStreamID then
  begin
    AResponse.Reset := True;
    AResponse.ResetCode := LErrorCode;
    AResponse.EndStream := True;
  end;
end;

procedure TH2ClientConnection.HandleHeaders(const AFrame: TH2Frame;
  const AStreamID: UInt32; var AResponse: TH2ResponseState);
var
  LFragment: AnsiString;
begin
  if AFrame.Header.StreamID = 0 then
    FailConnection(H2_ERR_PROTOCOL_ERROR, 'HEADERS',
      'HTTP/2 HEADERS received on connection stream');
  if AFrame.Header.StreamID <> AStreamID then
    Exit;
  if not ExtractHeadersFragment(AFrame.Header.Flags, AFrame.Payload, LFragment) then
    raise EHttpError.Create(hekProtocol, 'HTTP/2 invalid HEADERS payload');
  AResponse.HeaderFragments := nil;
  AppendResponseHeaderFragment(AResponse, LFragment);
  AResponse.HeadersComplete := False;
  AResponse.HeadersDecoded := False;
  if (AFrame.Header.Flags and H2_FLAG_HEADERS_END_HEADERS) <> 0 then
  begin
    AResponse.HeadersComplete := True;
    DecodeResponseHeaders(AResponse);
  end
  else
    FPendingContinuationStreamID := AStreamID;
  if (AFrame.Header.Flags and H2_FLAG_HEADERS_END_STREAM) <> 0 then
    AResponse.EndStream := True;
end;

procedure TH2ClientConnection.HandleContinuation(const AFrame: TH2Frame;
  const AStreamID: UInt32; var AResponse: TH2ResponseState);
begin
  if (FPendingContinuationStreamID = 0) or
     (FPendingContinuationStreamID <> AFrame.Header.StreamID) or
     (AFrame.Header.StreamID <> AStreamID) then
  begin
    FPendingContinuationStreamID := 0;
    FailConnection(H2_ERR_PROTOCOL_ERROR, 'CONTINUATION',
      'HTTP/2 unexpected CONTINUATION');
  end;

  AppendResponseHeaderFragment(AResponse, AFrame.Payload);
  if (AFrame.Header.Flags and H2_FLAG_CONTINUATION_END_HEADERS) <> 0 then
  begin
    FPendingContinuationStreamID := 0;
    AResponse.HeadersComplete := True;
    DecodeResponseHeaders(AResponse);
  end;
end;

procedure TH2ClientConnection.HandleData(const AFrame: TH2Frame;
  const AStreamID: UInt32; var AStreamFlow: TH2StreamFlowControl;
  var AResponse: TH2ResponseState);
var
  LData: AnsiString;
  LDataLen: UInt32;
  LFrameLen: UInt32;
begin
  if AFrame.Header.StreamID = 0 then
    FailConnection(H2_ERR_PROTOCOL_ERROR, 'DATA',
      'HTTP/2 DATA received on connection stream');
  if AFrame.Header.StreamID <> AStreamID then
    Exit;
  if not ExtractDataPayload(AFrame.Header.Flags, AFrame.Payload, LData) then
    raise EHttpError.Create(hekProtocol, 'HTTP/2 invalid DATA payload');
  { Flow control accounts for entire frame payload including padding }
  LFrameLen := UInt32(Length(AFrame.Payload));
  if LFrameLen > 0 then
  begin
    AStreamFlow.RecvWindow.OnDataReceived(LFrameLen);
    FConnectionFlow.RecvWindow.OnDataReceived(LFrameLen);
    LDataLen := UInt32(Length(LData));
    if LDataLen > 0 then
    begin
      AppendResponseBody(AResponse, LData);
      AStreamFlow.RecvWindow.OnDataConsumed(LDataLen);
      ConsumeResponseBody(AResponse, LDataLen);
    end;
  end;
  if (AFrame.Header.Flags and H2_FLAG_DATA_END_STREAM) <> 0 then
    AResponse.EndStream := True;
end;

procedure TH2ClientConnection.DispatchFrame(const AFrame: TH2Frame;
  const AStreamID: UInt32; var AStreamFlow: TH2StreamFlowControl;
  var AResponse: TH2ResponseState);
begin
  case AFrame.Header.FrameType of
    H2_FRAME_SETTINGS:
      HandleSettings(AFrame);
    H2_FRAME_WINDOW_UPDATE:
      HandleWindowUpdate(AFrame, AStreamID, AStreamFlow);
    H2_FRAME_PING:
      HandlePing(AFrame);
    H2_FRAME_GOAWAY:
      HandleGoaway(AFrame);
    H2_FRAME_PUSH_PROMISE:
      FailConnection(H2_ERR_PROTOCOL_ERROR, 'PUSH_PROMISE',
        'HTTP/2 PUSH_PROMISE received while server push is disabled');
    H2_FRAME_RST_STREAM:
      HandleRstStream(AFrame, AStreamID, AResponse);
    H2_FRAME_HEADERS:
      HandleHeaders(AFrame, AStreamID, AResponse);
    H2_FRAME_CONTINUATION:
      HandleContinuation(AFrame, AStreamID, AResponse);
    H2_FRAME_DATA:
      HandleData(AFrame, AStreamID, AStreamFlow, AResponse);
  end;
end;

procedure TH2ClientConnection.DrainBufferedFrames(const AStreamID: UInt32;
  var AStreamFlow: TH2StreamFlowControl; var AResponse: TH2ResponseState);
var
  LFrame: TH2Frame;
  LConsumed: SizeUInt;
begin
  while DecodeNextFrame(LFrame, LConsumed) do
  begin
    if (LFrame.Header.StreamID <> 0) and (LFrame.Header.StreamID <> AStreamID) then
      Exit;
    DiscardConsumed(LConsumed);
    DispatchFrame(LFrame, AStreamID, AStreamFlow, AResponse);
    if AResponse.PendingWindowUpdate > 0 then
    begin
      SendWindowUpdate(AStreamID, AResponse.PendingWindowUpdate);
      AResponse.PendingWindowUpdate := 0;
    end;
    FlushPendingConnectionWindowUpdate;
  end;
end;

function TH2ClientConnection.BuildResponse(
  const AResponse: TH2ResponseState): IHttpResponse;
var
  LBody: IReader;
begin
  if AResponse.Reset then
    raise EHttpError.Create(hekProtocol, 'HTTP/2 stream ' + IntToStr(AResponse.StreamID) + ' reset: ' +
      H2ErrorCodeName(AResponse.ResetCode));
  if AResponse.StatusCode = 0 then
    raise EHttpError.Create(hekProtocol, 'HTTP/2 response missing status');
  if Length(AResponse.Body) > 0 then
    LBody := TH2ClientResponseBodyReader.Create(AResponse.Body)
  else
    LBody := nil;
  Result := THttpResponse.Create(AResponse.StatusCode, AResponse.Headers, LBody,
    hvHttp2);
end;

function TH2ClientConnection.Handshake: Boolean;
var
  LFrame: TH2Frame;
  LSettingsReceived: Boolean;
begin
  if FState = h2ccsActive then
    Exit(True);
  EnsureOpen;
  { Deadline is set by transport: connect budget on new dial, full Timeout after. }
  SendBytes(H2_CLIENT_PREFACE);
  SendSettings;
  SendConnectionWindowDelta;
  LSettingsReceived := False;
  while not LSettingsReceived do
  begin
    if not ReadFrame(LFrame) then
      Exit(False);
    case LFrame.Header.FrameType of
      H2_FRAME_SETTINGS:
        begin
          HandleSettings(LFrame);
          if (LFrame.Header.Flags and H2_FLAG_SETTINGS_ACK) = 0 then
            LSettingsReceived := True;
        end;
      H2_FRAME_PING:
        HandlePing(LFrame);
      H2_FRAME_GOAWAY:
        begin
          HandleGoaway(LFrame);
          Exit(False);
        end;
    else
      raise EHttpError.Create(hekProtocol, 'HTTP/2 handshake expected SETTINGS first');
    end;
  end;
  FState := h2ccsActive;
  Result := True;
end;

procedure TH2ClientConnection.ApplyCancelToken(const AToken: IHttpCancelToken);
var
  LNet: INetCancelToken;
begin
  if FConn = nil then
    Exit;
  if AToken = nil then
    FConn.SetCancelToken(nil)
  else if AToken.QueryInterface(INetCancelToken, LNet) = 0 then
    FConn.SetCancelToken(LNet)
  else
    FConn.SetCancelToken(THttpNetCancelAdapter.Create(AToken));
end;

procedure TH2ClientConnection.ClearCancelToken;
begin
  if FConn <> nil then
    FConn.SetCancelToken(nil);
end;

function TH2ClientConnection.RoundTrip(const AReq: IHttpRequest): IHttpResponse;
var
  LStreamID: UInt32;
  LStreamIndex: SizeInt;
  LHasBody: Boolean;
  LFrame: TH2Frame;
  LResponse: TH2ResponseState;
  LWasActive: Boolean;
begin
  if AReq = nil then
    raise EHttpError.Create(hekArgument, 'h2 client transport requires request');
  if AReq.Headers = nil then
    raise EHttpError.Create(hekArgument, 'h2 client transport requires request headers');
  LWasActive := FState = h2ccsActive;
  if LWasActive then
    ApplyDeadline;
  if not Handshake then
    raise EHttpError.Create(hekProtocol, 'HTTP/2 client handshake failed');
  { After handshake first-write (connect budget), re-arm full request Timeout. }
  if not LWasActive then
    ApplyDeadline;
  EnsureActive;
  LStreamID := AllocateStreamID;
  TH2ResponseState.Init(LResponse);
  LResponse.StreamID := LStreamID;
  LStreamIndex := AddActiveStream(LStreamID);
  try
    if (AReq.Body <> nil) and (AReq.ContentLength < 0) then
      raise EHttpError.Create(hekArgument,
        'HTTP/2 client does not support chunked/unknown-length request bodies');
    LHasBody := (AReq.Body <> nil) and (AReq.ContentLength > 0);
    SendRequestHeaders(LStreamID, AReq, not LHasBody);
    if LHasBody then
      SendRequestBody(LStreamID, AReq, FActiveStreams[LStreamIndex].Flow,
        LResponse);
    while not LResponse.EndStream do
    begin
      if not ReadFrame(LFrame) then
        raise EHttpError.Create(hekProtocol, 'HTTP/2 response incomplete: connection closed');
      DispatchFrame(LFrame, LStreamID, FActiveStreams[LStreamIndex].Flow,
        LResponse);
      { RFC 9113 §6.8: GOAWAY indicates the server is shutting down.
        If we receive GOAWAY while waiting for a response, abort immediately. }
      if FGoawayReceived and (not LResponse.EndStream) then
        raise EHttpError.Create(hekProtocol, 'HTTP/2 GOAWAY received during response');
      if LResponse.PendingWindowUpdate > 0 then
      begin
        SendWindowUpdate(LStreamID, LResponse.PendingWindowUpdate);
        LResponse.PendingWindowUpdate := 0;
      end;
      FlushPendingConnectionWindowUpdate;
    end;
    DrainBufferedFrames(LStreamID, FActiveStreams[LStreamIndex].Flow,
      LResponse);
    Result := BuildResponse(LResponse);
  finally
    RemoveActiveStream(LStreamID);
    LResponse.Headers := nil;
    LResponse.HeadersStore := nil;
  end;
end;

function TH2ClientConnection.RoundTripMany(
  const AReqs: array of IHttpRequest): THttpResponseArray;
var
  LCount: SizeInt;
  LI: SizeInt;
  LStreamIDs: array of UInt32;
  LResponses: array of TH2ResponseState;
  LFinished: array of Boolean;
  LStreamIndex: SizeInt;
  LRespIndex: SizeInt;
  LHasBody: Boolean;
  LFrame: TH2Frame;
  LWasActive: Boolean;
  LDone: SizeInt;
  LDummyFlow: TH2StreamFlowControl;
  LDummyResp: TH2ResponseState;
  LMaxConc: UInt32;
begin
  Result := nil;
  LCount := Length(AReqs);
  SetLength(Result, LCount);
  if LCount = 0 then
    Exit;

  for LI := 0 to LCount - 1 do
  begin
    if AReqs[LI] = nil then
      raise EHttpError.Create(hekArgument, 'h2 RoundTripMany requires request');
    if AReqs[LI].Headers = nil then
      raise EHttpError.Create(hekArgument,
        'h2 RoundTripMany requires request headers');
    if (AReqs[LI].Body <> nil) and (AReqs[LI].ContentLength < 0) then
      raise EHttpError.Create(hekArgument,
        'HTTP/2 client does not support chunked/unknown-length request bodies');
  end;

  LWasActive := FState = h2ccsActive;
  if LWasActive then
    ApplyDeadline;
  if not Handshake then
    raise EHttpError.Create(hekProtocol, 'HTTP/2 client handshake failed');
  if not LWasActive then
    ApplyDeadline;
  EnsureActive;

  LMaxConc := FRemoteSettings.MaxConcurrentStreams;
  if (LMaxConc > 0) and (UInt32(LCount) > LMaxConc) then
    raise EHttpError.Create(hekArgument,
      'HTTP/2 RoundTripMany exceeds peer MaxConcurrentStreams');

  SetLength(LStreamIDs, LCount);
  SetLength(LResponses, LCount);
  SetLength(LFinished, LCount);
  for LI := 0 to LCount - 1 do
  begin
    LStreamIDs[LI] := AllocateStreamID;
    TH2ResponseState.Init(LResponses[LI]);
    LResponses[LI].StreamID := LStreamIDs[LI];
    AddActiveStream(LStreamIDs[LI]);
    LFinished[LI] := False;
  end;

  try
    { Open all streams: HEADERS (and bodies) before demux loop. }
    for LI := 0 to LCount - 1 do
    begin
      LHasBody := (AReqs[LI].Body <> nil) and (AReqs[LI].ContentLength > 0);
      SendRequestHeaders(LStreamIDs[LI], AReqs[LI], not LHasBody);
      if LHasBody then
      begin
        LStreamIndex := FindActiveStreamIndex(LStreamIDs[LI]);
        SendRequestBody(LStreamIDs[LI], AReqs[LI],
          FActiveStreams[LStreamIndex].Flow, LResponses[LI]);
        if LResponses[LI].EndStream then
        begin
          { RST while sending body — count as finished. }
          LFinished[LI] := True;
        end;
      end;
    end;

    LDone := 0;
    for LI := 0 to LCount - 1 do
      if LFinished[LI] then
        Inc(LDone);

    while LDone < LCount do
    begin
      if not ReadFrame(LFrame) then
        raise EHttpError.Create(hekProtocol,
          'HTTP/2 multiplex response incomplete: connection closed');

      if LFrame.Header.StreamID = 0 then
      begin
        LDummyFlow.Init(0, FRemoteSettings.InitialWindowSize,
          FLocalSettings.InitialWindowSize);
        TH2ResponseState.Init(LDummyResp);
        DispatchFrame(LFrame, 0, LDummyFlow, LDummyResp);
      end
      else
      begin
        LRespIndex := -1;
        for LI := 0 to LCount - 1 do
          if LStreamIDs[LI] = LFrame.Header.StreamID then
          begin
            LRespIndex := LI;
            Break;
          end;
        if LRespIndex < 0 then
          raise EHttpError.Create(hekProtocol,
            'HTTP/2 frame for unknown stream ' +
            IntToStr(LFrame.Header.StreamID));
        LStreamIndex := FindActiveStreamIndex(LStreamIDs[LRespIndex]);
        if LStreamIndex < 0 then
          raise EHttpError.Create(hekProtocol,
            'HTTP/2 active stream missing for ' +
            IntToStr(LStreamIDs[LRespIndex]));
        DispatchFrame(LFrame, LStreamIDs[LRespIndex],
          FActiveStreams[LStreamIndex].Flow, LResponses[LRespIndex]);
        if LResponses[LRespIndex].PendingWindowUpdate > 0 then
        begin
          SendWindowUpdate(LStreamIDs[LRespIndex],
            LResponses[LRespIndex].PendingWindowUpdate);
          LResponses[LRespIndex].PendingWindowUpdate := 0;
        end;
        if LResponses[LRespIndex].EndStream and (not LFinished[LRespIndex]) then
        begin
          LFinished[LRespIndex] := True;
          Inc(LDone);
        end;
      end;

      if FGoawayReceived then
      begin
        for LI := 0 to LCount - 1 do
          if (not LFinished[LI]) and
             (LStreamIDs[LI] > FLastPeerStreamID) then
            raise EHttpError.Create(hekProtocol,
              'HTTP/2 GOAWAY received during multiplex response');
        { Streams with ID <= last-stream-id may still complete. }
        if LDone < LCount then
        begin
          { If all remaining are already finished or within last stream id,
            keep reading; if GOAWAY and no unfinished streams that can complete
            (all remaining > last), raised above. }
        end;
      end;
      FlushPendingConnectionWindowUpdate;
    end;

    for LI := 0 to LCount - 1 do
      Result[LI] := BuildResponse(LResponses[LI]);
  finally
    for LI := 0 to LCount - 1 do
    begin
      RemoveActiveStream(LStreamIDs[LI]);
      LResponses[LI].Headers := nil;
      LResponses[LI].HeadersStore := nil;
    end;
  end;
end;

function TH2ClientConnection.IsReusable: Boolean;
begin
  Result := (FConn <> nil) and (FState = h2ccsActive) and
    (not FGoawayReceived) and (not FGoawaySent);
end;

function TH2ClientConnection.ProbeHealth: Boolean;
var
  LOpaque: UInt64;
  LFrame: TH2Frame;
  LStreamFlow: TH2StreamFlowControl;
begin
  { Borrow-time active probe (Wave I1). PingTimeout=0 disables wire PING. }
  Result := False;
  if not IsReusable then
    Exit;
  if FOptions.PingTimeout <= 0 then
    Exit(True);
  { Residual buffered frames mean the peer has already written on this
    connection (live). Serial RoundTrip fixtures may also pre-queue the next
    response; do not fail the probe on that data. }
  if FReadBuffer <> '' then
    Exit(True);

  try
    ApplyClientDeadline(FConn, ClientRequestDeadline(FOptions.PingTimeout));
    try
      LOpaque := GetTickCount64;
      if LOpaque = 0 then
        LOpaque := 1;
      FLastPingData := not LOpaque;
      SendFrame(H2_FRAME_PING, 0, 0, H2EncodePing(LOpaque));
      { Dummy stream flow only for connection-level WINDOW_UPDATE dispatch. }
      LStreamFlow.Init(1, FRemoteSettings.InitialWindowSize);
      while True do
      begin
        if not IsReusable then
          Exit(False);
        if not ReadFrame(LFrame) then
          Exit(False);
        case LFrame.Header.FrameType of
          H2_FRAME_PING:
            begin
              HandlePing(LFrame);
              if ((LFrame.Header.Flags and H2_FLAG_PING_ACK) <> 0) and
                 (FLastPingData = LOpaque) then
                Exit(IsReusable);
            end;
          H2_FRAME_GOAWAY:
            begin
              HandleGoaway(LFrame);
              Exit(False);
            end;
          H2_FRAME_SETTINGS:
            HandleSettings(LFrame);
          H2_FRAME_WINDOW_UPDATE:
            begin
              if LFrame.Header.StreamID <> 0 then
                Exit(False);
              HandleWindowUpdate(LFrame, 0, LStreamFlow);
            end;
          H2_FRAME_PUSH_PROMISE:
            begin
              FailConnection(H2_ERR_PROTOCOL_ERROR, 'PUSH_PROMISE',
                'HTTP/2 PUSH_PROMISE received while server push is disabled');
              Exit(False);
            end;
        else
          { Unexpected stream-level traffic while idle → not healthy for reuse. }
          Exit(False);
        end;
      end;
    finally
      ApplyClientDeadline(FConn, TDeadline.Infinite);
    end;
  except
    Result := False;
  end;
end;

procedure TH2ClientConnection.Close;
begin
  if FConn = nil then
    Exit;
  if FState in [h2ccsConnecting, h2ccsActive] then
  begin
    try
      SendGoaway(FLastPeerStreamID, H2_ERR_NO_ERROR);
    except
    end;
  end;
  try
    FConn.Close;
  except
  end;
  FConn := nil;
  TransitionClosed;
end;

{ TH2ClientTransport }

constructor TH2ClientTransport.Create(const AOptions: TH2ClientTransportOptions);
begin
  inherited Create;
  AOptions.Validate;
  FOptions := AOptions;
  FDefaultTLSContext := nil;
  FPoolLock := Mutex;
  FPool := nil;
  FPoolCount := 0;
end;

destructor TH2ClientTransport.Destroy;
begin
  PoolClear;
  FPoolLock := nil;
  FDefaultTLSContext := nil;
  inherited Destroy;
end;

function TH2ClientTransport.PoolEntryExpired(const AEntry: TH2PoolEntry): Boolean;
var
  LNow: UInt64;
  LAge: UInt64;
begin
  Result := False;
  if FOptions.IdleTTL <= 0 then
    Exit;
  LNow := GetTickCount64;
  if LNow >= AEntry.IdleAtMs then
    LAge := LNow - AEntry.IdleAtMs
  else
    LAge := 0;
  Result := LAge >= UInt64(FOptions.IdleTTL);
end;

procedure TH2ClientTransport.PoolRemoveAt(const AIndex: Int32);
begin
  if (AIndex < 0) or (AIndex >= FPoolCount) then
    Exit;
  FPool[AIndex] := FPool[FPoolCount - 1];
  Dec(FPoolCount);
end;

function TH2ClientTransport.PoolGet(const AHost: string;
  const APort: UInt16; const ASecure: Boolean): TH2ClientConnection;
var
  LI: Int32;
  LCandidate: TH2ClientConnection;
  LToClose: array of TH2ClientConnection;
  LCloseCount: Int32;
begin
  { Never Close/Free while holding FPoolLock — same hang class as H1 pool. }
  Result := nil;
  LCloseCount := 0;
  SetLength(LToClose, 0);
  while True do
  begin
    LCandidate := nil;
    FPoolLock.Acquire;
    try
      LI := 0;
      while LI < FPoolCount do
      begin
        if (FPool[LI].Host = AHost) and (FPool[LI].Port = APort) and
           (FPool[LI].Secure = ASecure) then
        begin
          if PoolEntryExpired(FPool[LI]) then
          begin
            if FPool[LI].Conn <> nil then
            begin
              if LCloseCount >= Length(LToClose) then
                SetLength(LToClose, LCloseCount + 4);
              LToClose[LCloseCount] := FPool[LI].Conn;
              Inc(LCloseCount);
            end;
            PoolRemoveAt(LI);
            Continue;
          end;
          LCandidate := FPool[LI].Conn;
          PoolRemoveAt(LI);
          Break;
        end;
        Inc(LI);
      end;
    finally
      FPoolLock.Release;
    end;

    if LCandidate = nil then
      Break;

    { Probe outside the pool lock: PING/Read can block (same hang class as Close). }
    if LCandidate.IsReusable and LCandidate.ProbeHealth then
    begin
      Result := LCandidate;
      Break;
    end;

    if LCloseCount >= Length(LToClose) then
      SetLength(LToClose, LCloseCount + 4);
    LToClose[LCloseCount] := LCandidate;
    Inc(LCloseCount);
  end;

  for LI := 0 to LCloseCount - 1 do
    if LToClose[LI] <> nil then
    try
      LToClose[LI].Close;
      LToClose[LI].Free;
    except
    end;
end;

procedure TH2ClientTransport.PoolPut(const AHost: string; const APort: UInt16;
  const ASecure: Boolean; const AConn: TH2ClientConnection);
var
  LI: Int32;
  LAuthorityIdle: Int32;
  LToClose: array of TH2ClientConnection;
  LCloseCount: Int32;
  LReject: Boolean;
begin
  LCloseCount := 0;
  SetLength(LToClose, 0);
  LReject := False;
  FPoolLock.Acquire;
  try
    if (AConn = nil) or (not AConn.IsReusable) then
    begin
      LReject := AConn <> nil;
      Exit;
    end;
    LI := 0;
    while LI < FPoolCount do
    begin
      if (FPool[LI].Host = AHost) and (FPool[LI].Port = APort) and
         (FPool[LI].Secure = ASecure) and PoolEntryExpired(FPool[LI]) then
      begin
        if FPool[LI].Conn <> nil then
        begin
          if LCloseCount >= Length(LToClose) then
            SetLength(LToClose, LCloseCount + 4);
          LToClose[LCloseCount] := FPool[LI].Conn;
          Inc(LCloseCount);
        end;
        PoolRemoveAt(LI);
      end
      else
        Inc(LI);
    end;
    if FOptions.MaxPoolSize > 0 then
    begin
      LAuthorityIdle := 0;
      for LI := 0 to FPoolCount - 1 do
        if (FPool[LI].Host = AHost) and (FPool[LI].Port = APort) and
           (FPool[LI].Secure = ASecure) then
          Inc(LAuthorityIdle);
      if LAuthorityIdle >= FOptions.MaxPoolSize then
      begin
        LReject := True;
        Exit;
      end;
    end;
    if FPoolCount >= Length(FPool) then
      SetLength(FPool, FPoolCount + 4);
    FPool[FPoolCount].Host := AHost;
    FPool[FPoolCount].Port := APort;
    FPool[FPoolCount].Secure := ASecure;
    FPool[FPoolCount].Conn := AConn;
    FPool[FPoolCount].IdleAtMs := GetTickCount64;
    Inc(FPoolCount);
  finally
    FPoolLock.Release;
  end;

  if LReject and (AConn <> nil) then
  begin
    if LCloseCount >= Length(LToClose) then
      SetLength(LToClose, LCloseCount + 4);
    LToClose[LCloseCount] := AConn;
    Inc(LCloseCount);
  end;
  for LI := 0 to LCloseCount - 1 do
    if LToClose[LI] <> nil then
    try
      LToClose[LI].Close;
      LToClose[LI].Free;
    except
    end;
end;

procedure TH2ClientTransport.PoolClear;
var
  LI: Int32;
  LToClose: array of TH2ClientConnection;
  LCloseCount: Int32;
begin
  LCloseCount := 0;
  SetLength(LToClose, 0);
  FPoolLock.Acquire;
  try
    for LI := 0 to FPoolCount - 1 do
      if FPool[LI].Conn <> nil then
      begin
        if LCloseCount >= Length(LToClose) then
          SetLength(LToClose, LCloseCount + 4);
        LToClose[LCloseCount] := FPool[LI].Conn;
        Inc(LCloseCount);
      end;
    FPool := nil;
    FPoolCount := 0;
  finally
    FPoolLock.Release;
  end;
  for LI := 0 to LCloseCount - 1 do
    if LToClose[LI] <> nil then
    try
      LToClose[LI].Close;
      LToClose[LI].Free;
    except
    end;
end;

function TH2ClientTransport.SecureClientContext: ISSLContext;
begin
  if FOptions.TLSContext <> nil then
    Exit(FOptions.TLSContext);
  if FDefaultTLSContext = nil then
    FDefaultTLSContext := TSSLQuick.SecureClient;
  Result := FDefaultTLSContext;
end;

procedure H2ApplyPostDialDeadline(const AConn: ITcpStream;
  const AOptions: TH2ClientTransportOptions);
begin
  if AConn = nil then
    Exit;
  { Match H1: ConnectTimeout>0 bounds post-dial first write; else Timeout. }
  if AOptions.ConnectTimeout > 0 then
    ApplyClientDeadline(AConn, ClientRequestDeadline(AOptions.ConnectTimeout))
  else
    ApplyClientDeadline(AConn, ClientRequestDeadline(AOptions.Timeout));
end;

function H2RequestCancelToken(const AReq: IHttpRequest): IHttpCancelToken;
var
  LReqOpts: IHttpRequestWithOptions;
begin
  Result := nil;
  if (AReq <> nil) and Supports(AReq, IHttpRequestWithOptions, LReqOpts) then
    Result := LReqOpts.RequestOptions.EffectiveCancelToken;
end;

function TH2ClientTransport.AcquireConnection(const AHost: string;
  const APort: UInt16; const ASecure: Boolean;
  out APooled: Boolean): TH2ClientConnection;
var
  LRawConn: ITcpStream;
  LSelectedALPN: string;
  LHostKey: string;
begin
  LHostKey := CanonicalPoolHostKey(AHost);
  Result := PoolGet(LHostKey, APort, ASecure);
  APooled := Result <> nil;
  if APooled then
    Exit;
  LRawConn := H2ClientDial(AHost, APort, FOptions.ConnectTimeout,
    FOptions.Timeout);
  if ASecure then
  begin
    H2ApplyPostDialDeadline(LRawConn, FOptions);
    LRawConn := NewTlsClientTcpStream(LRawConn, SecureClientContext, AHost,
      HTTP2_ALPN_PROTOCOL);
    LSelectedALPN := LowerCase(Trim(TlsTcpStreamSelectedALPN(LRawConn)));
    if LSelectedALPN <> HTTP2_ALPN_PROTOCOL then
      raise EHttpError.Create(hekProtocol,
        'HTTPS HTTP/2 client requires negotiated ALPN "h2"');
    H2ApplyPostDialDeadline(LRawConn, FOptions);
  end
  else
    H2ApplyPostDialDeadline(LRawConn, FOptions);
  Result := TH2ClientConnection.Create(LRawConn, FOptions);
end;

procedure TH2ClientTransport.ReleaseConnection(const AHost: string;
  const APort: UInt16; const ASecure: Boolean;
  const AConn: TH2ClientConnection; const AReqHeaders: IHttpHeaders);
var
  LHostKey: string;
begin
  if AConn = nil then
    Exit;
  AConn.ClearCancelToken;
  LHostKey := CanonicalPoolHostKey(AHost);
  if HeadersHaveConnectionCloseToken(AReqHeaders) or (not AConn.IsReusable) then
  begin
    AConn.Close;
    AConn.Free;
  end
  else
    PoolPut(LHostKey, APort, ASecure, AConn);
end;

function TH2ClientTransport.RoundTrip(const AReq: IHttpRequest): IHttpResponse;
var
  LUrl: TUrl;
  LHost: string;
  LHostKey: string;
  LPort: UInt16;
  LSecure: Boolean;
  LRawConn: ITcpStream;
  LSelectedALPN: string;
  LConn: TH2ClientConnection;
  LPooled: Boolean;
  LBodyStream: IStream;
  LBodyStartPosition: Int64;
  LRequestWriteComplete: Boolean;
  LWrapped: Exception;
  LCancel: IHttpCancelToken;
begin
  if AReq = nil then
    raise EHttpError.Create(hekArgument, 'h2 client transport requires request');
  if AReq.Headers = nil then
    raise EHttpError.Create(hekArgument, 'h2 client transport requires request headers');
  LUrl := AReq.Url;
  ValidateH2ClientUrlScheme(LUrl);
  LHost := LUrl.Host;
  if LHost = '' then
    raise EHttpError.Create(hekParse, 'HTTP/2 client request requires host');
  LSecure := LowerCase(LUrl.Scheme) = 'https';
  LPort := LUrl.Port;
  if LPort = 0 then
  begin
    if LSecure then
      LPort := 443
    else
      LPort := 80;
  end;
  LHostKey := CanonicalPoolHostKey(LHost);
  CaptureRetryBodyPosition(AReq, LBodyStream, LBodyStartPosition);
  LCancel := H2RequestCancelToken(AReq);
  HttpThrowIfCanceled(LCancel);
  LConn := AcquireConnection(LHost, LPort, LSecure, LPooled);
  LRequestWriteComplete := False;
  try
    LConn.ApplyCancelToken(LCancel);
    try
      Result := LConn.RoundTrip(AReq);
      LRequestWriteComplete := True;
    finally
      LConn.ClearCancelToken;
    end;
  except
    on E: Exception do
    begin
      if LPooled then
      begin
        LConn.ClearCancelToken;
        LConn.Close;
        LConn.Free;
        if ((not LRequestWriteComplete) and (not IsRetrySafeRequest(AReq))) or
           ((AReq.Body <> nil) and (AReq.ContentLength > 0) and (LBodyStream = nil)) then
        begin
          LWrapped := HttpWrapTransportException(E);
          if LWrapped <> nil then
            raise LWrapped;
          raise;
        end;
        RewindRetryBody(AReq, LBodyStream, LBodyStartPosition);
        HttpThrowIfCanceled(LCancel);
        LRawConn := H2ClientDial(LHost, LPort, FOptions.ConnectTimeout,
          FOptions.Timeout);
        if LSecure then
        begin
          H2ApplyPostDialDeadline(LRawConn, FOptions);
          LRawConn := NewTlsClientTcpStream(LRawConn, SecureClientContext, LHost,
            HTTP2_ALPN_PROTOCOL);
          LSelectedALPN := LowerCase(Trim(TlsTcpStreamSelectedALPN(LRawConn)));
          if LSelectedALPN <> HTTP2_ALPN_PROTOCOL then
            raise EHttpError.Create(hekProtocol,
              'HTTPS HTTP/2 client requires negotiated ALPN "h2"');
          H2ApplyPostDialDeadline(LRawConn, FOptions);
        end
        else
          H2ApplyPostDialDeadline(LRawConn, FOptions);
        LConn := TH2ClientConnection.Create(LRawConn, FOptions);
        try
          LConn.ApplyCancelToken(LCancel);
          try
            Result := LConn.RoundTrip(AReq);
          finally
            LConn.ClearCancelToken;
          end;
        except
          on E2: Exception do
          begin
            LConn.ClearCancelToken;
            LConn.Close;
            LConn.Free;
            LWrapped := HttpWrapTransportException(E2);
            if LWrapped <> nil then
              raise LWrapped;
            raise;
          end;
        end;
      end
      else
      begin
        LConn.ClearCancelToken;
        LConn.Close;
        LConn.Free;
        LWrapped := HttpWrapTransportException(E);
        if LWrapped <> nil then
          raise LWrapped;
        raise;
      end;
    end;
  end;
  ReleaseConnection(LHost, LPort, LSecure, LConn, AReq.Headers);
end;

function TH2ClientTransport.RoundTripMany(
  const AReqs: array of IHttpRequest): THttpResponseArray;
var
  LCount: SizeInt;
  LI: SizeInt;
  LUrl: TUrl;
  LHost: string;
  LPort: UInt16;
  LSecure: Boolean;
  LConn: TH2ClientConnection;
  LPooled: Boolean;
  LCancel: IHttpCancelToken;
  LWrapped: Exception;
  LOtherUrl: TUrl;
  LOtherSecure: Boolean;
  LOtherPort: UInt16;
begin
  Result := nil;
  LCount := Length(AReqs);
  SetLength(Result, LCount);
  if LCount = 0 then
    Exit;

  if AReqs[0] = nil then
    raise EHttpError.Create(hekArgument, 'h2 RoundTripMany requires request');
  if AReqs[0].Headers = nil then
    raise EHttpError.Create(hekArgument,
      'h2 RoundTripMany requires request headers');
  LUrl := AReqs[0].Url;
  ValidateH2ClientUrlScheme(LUrl);
  LHost := LUrl.Host;
  if LHost = '' then
    raise EHttpError.Create(hekParse, 'HTTP/2 client request requires host');
  LSecure := LowerCase(LUrl.Scheme) = 'https';
  LPort := LUrl.Port;
  if LPort = 0 then
  begin
    if LSecure then
      LPort := 443
    else
      LPort := 80;
  end;

  for LI := 1 to LCount - 1 do
  begin
    if AReqs[LI] = nil then
      raise EHttpError.Create(hekArgument, 'h2 RoundTripMany requires request');
    LOtherUrl := AReqs[LI].Url;
    ValidateH2ClientUrlScheme(LOtherUrl);
    LOtherSecure := LowerCase(LOtherUrl.Scheme) = 'https';
    LOtherPort := LOtherUrl.Port;
    if LOtherPort = 0 then
    begin
      if LOtherSecure then
        LOtherPort := 443
      else
        LOtherPort := 80;
    end;
    if (CanonicalPoolHostKey(LOtherUrl.Host) <> CanonicalPoolHostKey(LHost)) or
       (LOtherPort <> LPort) or (LOtherSecure <> LSecure) then
      raise EHttpError.Create(hekArgument,
        'HTTP/2 RoundTripMany requires same authority for all requests');
  end;

  LCancel := H2RequestCancelToken(AReqs[0]);
  HttpThrowIfCanceled(LCancel);
  LConn := AcquireConnection(LHost, LPort, LSecure, LPooled);
  try
    LConn.ApplyCancelToken(LCancel);
    try
      Result := LConn.RoundTripMany(AReqs);
    finally
      LConn.ClearCancelToken;
    end;
  except
    on E: Exception do
    begin
      LConn.ClearCancelToken;
      LConn.Close;
      LConn.Free;
      LWrapped := HttpWrapTransportException(E);
      if LWrapped <> nil then
        raise LWrapped;
      raise;
    end;
  end;
  ReleaseConnection(LHost, LPort, LSecure, LConn, AReqs[0].Headers);
end;

procedure TH2ClientTransport.CloseIdleConnections;
begin
  PoolClear;
end;

function NewH2ClientTransport(
  const AOptions: TH2ClientTransportOptions): IHttpTransport;
begin
  Result := TH2ClientTransport.Create(AOptions);
end;

initialization
  GH2ClientDialFunc := nil;

end.
