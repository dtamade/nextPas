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
  nextpas.core.time.deadline,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.impl.h2.client.pool,
  nextpas.core.http.impl.h2.client.body,
  nextpas.core.http.impl.h2.client.helpers,
  nextpas.core.http.impl.h2.client.streams,
  nextpas.core.http.impl.cancel.adapter,
  nextpas.core.http.impl.h2.frame,
  nextpas.core.http.impl.h2.wire,
  nextpas.core.http.impl.h2.hpack,
  nextpas.core.http.impl.h2.types,
  nextpas.core.tls.base;

type
  { Response body reader lives in impl.h2.client.body (mechanical extract). }
  TH2ClientResponseBodyReader =
    nextpas.core.http.impl.h2.client.body.TH2ClientResponseBodyReader;

  TH2ClientConnectionState = (
    h2ccsConnecting,
    h2ccsActive,
    h2ccsGoaway,
    h2ccsClosed
  );

  TH2ClientConnection = class(TH2PooledClientConnection)
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
  private
    FConn: ITcpStream;
    FOptions: TH2ClientTransportOptions;
    FState: TH2ClientConnectionState;
    { Shared read/write wire buffers (impl.h2.wire). }
    FWire: TH2WireBuffers;
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
    FActiveStreams: TH2ClientActiveStreams;
    FLastPingData: UInt64;
    procedure ApplyDeadline;
    procedure EnsureActive;
    procedure EnsureOpen;
    procedure TransitionClosed;
    function FillReadBuffer: Boolean;
    function DecodeNextFrame(out AFrame: TH2Frame; out AConsumed: SizeUInt): Boolean;
    function ReadFrame(out AFrame: TH2Frame): Boolean;
    procedure DiscardConsumed(const AConsumed: SizeUInt);
    procedure FlushWriteBuffer;
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
    function AllocateStreamID: UInt32;
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
    function IsReusable: Boolean; override;
    { Active liveness probe for pool borrow: PING/ACK when PingTimeout > 0.
      Must not be called while holding the transport pool lock. }
    function ProbeHealth: Boolean; override;
    { Wire/clear IHttpCancelToken for mid-read/write cancel slices on FConn. }
    procedure ApplyCancelToken(const AToken: IHttpCancelToken);
    procedure ClearCancelToken;
    procedure Close; override;
    property State: TH2ClientConnectionState read FState;
    property NextStreamID: UInt32 read FNextStreamID;
  end;

  TH2ClientTransport = class(TInterfacedObject, IHttpTransport,
    IHttpTransportMultiplex, IHttpTransportIdleConnections)
  private
    FOptions: TH2ClientTransportOptions;
    FDefaultTLSContext: ISSLContext;
    FPool: TH2IdleConnectionPool;
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

function DefaultH2ClientDial(const AHost: string; const APort: UInt16;
  const ADialTimeoutMs: Int64): ITcpStream;
begin
  if ADialTimeoutMs > 0 then
    Result := TcpConnect(AHost, APort, ADialTimeoutMs)
  else
    Result := TcpConnect(AHost, APort);
  { HTTP/2 multiplex is latency-sensitive; Nagle delays kill small-frame RTT. }
  if Result <> nil then
    Result.SetNoDelay(True);
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
  H2WireInit(FWire);
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
  H2ClientStreamsInit(FActiveStreams);
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
  LBuf: array[0..65535] of Byte;
  LRead: SizeUInt;
begin
  Result := False;
  H2WirePrepareAppendRead(FWire);
  LRead := FConn.Read(LBuf[0], SizeOf(LBuf));
  if LRead = 0 then
    Exit;
  H2WireAppendReadBytes(FWire, LBuf[0], SizeInt(LRead));
  Result := True;
end;

function TH2ClientConnection.DecodeNextFrame(out AFrame: TH2Frame;
  out AConsumed: SizeUInt): Boolean;
begin
  Result := H2WireTryDecodeFrame(FWire, AFrame, AConsumed);
end;

function TH2ClientConnection.ReadFrame(out AFrame: TH2Frame): Boolean;
var
  LConsumed: SizeUInt;
  LErrorCode: UInt32;
begin
  AFrame := Default(TH2Frame);
  { Deliver any coalesced writes before blocking on the peer. }
  FlushWriteBuffer;
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
begin
  H2WireDiscardConsumed(FWire, AConsumed);
end;

procedure TH2ClientConnection.FlushWriteBuffer;
var
  LWritten: SizeUInt;
begin
  while H2WireHasWriteData(FWire) do
  begin
    LWritten := FConn.Write(FWire.WriteBuf[1], SizeUInt(Length(FWire.WriteBuf)));
    if LWritten = 0 then
    begin
      H2WireClearWrite(FWire);
      TransitionClosed;
      raise EHttpError.Create(hekProtocol,
        'HTTP/2 client write failed: connection closed');
    end;
    H2WireConsumeWriteFront(FWire, LWritten);
  end;
end;

procedure TH2ClientConnection.SendBytes(const ABytes: AnsiString);
begin
  H2WireAppendWrite(FWire, ABytes);
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
    begin
      SendGoaway(FLastPeerStreamID, AErrorCode, ADebugData);
      try
        FlushWriteBuffer;
      except
      end;
    end;
  finally
    if FConn <> nil then
    begin
      try
        FConn.Close;
      except
      end;
      FConn := nil;
    end;
    H2WireClear(FWire);
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
  LHeaderList[2].Value := H2ClientRequestAuthority(LUrl);
  LHeaderList[3].Name := ':path';
  LHeaderList[3].Value := H2ClientRequestPath(LUrl);
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
begin
  Result := H2ClientStreamsFindIndex(FActiveStreams, AStreamID);
end;

function TH2ClientConnection.AddActiveStream(const AStreamID: UInt32): SizeInt;
begin
  Result := H2ClientStreamsAdd(FActiveStreams, AStreamID,
    FRemoteSettings.InitialWindowSize, FLocalSettings.InitialWindowSize);
end;

procedure TH2ClientConnection.RemoveActiveStream(const AStreamID: UInt32);
begin
  H2ClientStreamsRemove(FActiveStreams, AStreamID);
end;

procedure TH2ClientConnection.ApplyRemoteInitialWindowSizeToActiveStreams(
  const ANewInitialWindowSize: UInt32);
begin
  H2ClientStreamsApplyPeerInitialWindow(FActiveStreams, ANewInitialWindowSize);
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
    LChunkSize := H2MinUInt32(FRemoteSettings.MaxFrameSize, LCapacity);
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
  if not H2ParseSettingsPayload(FRemoteSettings, AFrame.Payload, LSettings) then
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
  if not H2ExtractHeadersFragment(AFrame.Header.Flags, AFrame.Payload, LFragment) then
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
  if not H2ExtractDataPayload(AFrame.Header.Flags, AFrame.Payload, LData) then
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
  LFrame := Default(TH2Frame);
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
  { SETTINGS ACK (and any control frames) from HandleSettings must hit the wire
    before Handshake returns — tests and peers observe WrittenData / peer state. }
  FlushWriteBuffer;
  FState := h2ccsActive;
  Result := True;
end;

procedure TH2ClientConnection.ApplyCancelToken(const AToken: IHttpCancelToken);
begin
  ApplyHttpCancelToken(FConn, AToken);
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
      SendRequestBody(LStreamID, AReq, FActiveStreams.Items[LStreamIndex].Flow,
        LResponse);
    while not LResponse.EndStream do
    begin
      if not ReadFrame(LFrame) then
        raise EHttpError.Create(hekProtocol, 'HTTP/2 response incomplete: connection closed');
      DispatchFrame(LFrame, LStreamID, FActiveStreams.Items[LStreamIndex].Flow,
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
    DrainBufferedFrames(LStreamID, FActiveStreams.Items[LStreamIndex].Flow,
      LResponse);
    FlushWriteBuffer;
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
          FActiveStreams.Items[LStreamIndex].Flow, LResponses[LI]);
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
        { Connection-level frames (SETTINGS/PING/GOAWAY/conn WINDOW_UPDATE).
          Stream flow control rejects StreamID=0; use a dummy ID=1 like the
          idle PING probe path. HandleWindowUpdate routes stream-0 updates to
          FConnectionFlow via the frame header, not this dummy. }
        LDummyFlow.Init(1, FRemoteSettings.InitialWindowSize,
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
          FActiveStreams.Items[LStreamIndex].Flow, LResponses[LRespIndex]);
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

    FlushWriteBuffer;
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
  if H2WireHasReadData(FWire) then
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
      FlushWriteBuffer;
    except
    end;
  end;
  try
    FConn.Close;
  except
  end;
  FConn := nil;
  H2WireClear(FWire);
  TransitionClosed;
end;

{ TH2ClientTransport }

constructor TH2ClientTransport.Create(const AOptions: TH2ClientTransportOptions);
begin
  inherited Create;
  AOptions.Validate;
  FOptions := AOptions;
  FDefaultTLSContext := nil;
  FPool := TH2IdleConnectionPool.Create(FOptions.MaxPoolSize, FOptions.IdleTTL);
end;

destructor TH2ClientTransport.Destroy;
begin
  FreeAndNil(FPool);
  FDefaultTLSContext := nil;
  inherited Destroy;
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
  LWrapped: Exception;
begin
  LWrapped := nil;
  LHostKey := CanonicalPoolHostKey(AHost);
  Result := TH2ClientConnection(FPool.Get(LHostKey, APort, ASecure));
  APooled := Result <> nil;
  if APooled then
    Exit;
  { 拨号阶段（DNS/connect/TLS/ALPN）与写读阶段同一传输异常契约：
    ENetworkError/ETimeoutError 经 HttpWrapTransportException 包装为
    EHttpError，裸网络异常不穿透 AcquireConnection。 }
  try
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
  except
    on E: Exception do
    begin
      LWrapped := HttpWrapTransportException(E);
      if LWrapped <> nil then
        raise LWrapped;
      raise;
    end;
  end;
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
    FPool.Put(LHostKey, APort, ASecure, AConn);
end;

function TH2ClientTransport.RoundTrip(const AReq: IHttpRequest): IHttpResponse;
var
  LUrl: TUrl;
  LHost: string;
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
  if FPool <> nil then
    FPool.Clear;
end;

function NewH2ClientTransport(
  const AOptions: TH2ClientTransportOptions): IHttpTransport;
begin
  Result := TH2ClientTransport.Create(AOptions);
end;

initialization
  GH2ClientDialFunc := nil;

end.
