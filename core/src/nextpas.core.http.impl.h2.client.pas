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
  nextpas.core.http.impl.h2.frame,
  nextpas.core.http.impl.h2.hpack,
  nextpas.core.http.impl.h2.types;

type
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
    function IsReusable: Boolean;
    procedure Close;
    property State: TH2ClientConnectionState read FState;
    property NextStreamID: UInt32 read FNextStreamID;
  end;

  TH2ClientTransport = class(TInterfacedObject, IHttpTransport,
    IHttpTransportIdleConnections)
  private type
    TH2PoolEntry = record
      Host: string;
      Port: UInt16;
      Conn: TH2ClientConnection;
    end;
  private
    FOptions: TH2ClientTransportOptions;
    FPool: array of TH2PoolEntry;
    FPoolCount: Int32;
    function PoolGet(const AHost: string; const APort: UInt16): TH2ClientConnection;
    procedure PoolPut(const AHost: string; const APort: UInt16;
      const AConn: TH2ClientConnection);
    procedure PoolClear;
  public
    constructor Create(const AOptions: TH2ClientTransportOptions);
    destructor Destroy; override;
    function RoundTrip(const AReq: IHttpRequest): IHttpResponse;
    procedure CloseIdleConnections;
  end;

function NewH2ClientTransport(
  const AOptions: TH2ClientTransportOptions): IHttpTransport;

type
  TH2ClientDialFunc = function(const AHost: string;
    const APort: UInt16): ITcpStream;

procedure SetH2ClientDialFuncForTests(const ADial: TH2ClientDialFunc);
procedure ResetH2ClientDialFuncForTests;

implementation

uses
  SysUtils,
  nextpas.core.errors,
  nextpas.core.io.memory,
  nextpas.core.net,
  nextpas.core.time.base,
  nextpas.core.http.headers,
  nextpas.core.http.message;

type
  TH2OwnedHeaders = class(THttpHeaders)
  end;

var
  GH2ClientDialFunc: TH2ClientDialFunc = nil;

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

procedure ValidatePlainHttpClientUrlScheme(const AUrl: TUrl);
var
  LScheme: string;
begin
  LScheme := LowerCase(AUrl.Scheme);
  if (LScheme <> '') and (LScheme <> 'http') then
    raise EHttpError.Create('unsupported HTTP client URL scheme: ' +
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

function ClientRequestDeadline(const ATimeoutMs: Int64): TDeadline;
begin
  if ATimeoutMs > 0 then
    Result := TDeadline.After(TDuration.FromMilliseconds(ATimeoutMs))
  else
    Result := TDeadline.Infinite;
end;

procedure ApplyClientDeadline(const AConn: ITcpStream; const ADeadline: TDeadline);
begin
  if ADeadline.IsInfinite then
    Exit;
  AConn.SetReadDeadline(ADeadline);
  AConn.SetWriteDeadline(ADeadline);
end;

function DefaultH2ClientDial(const AHost: string; const APort: UInt16): ITcpStream;
begin
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

function H2ClientDial(const AHost: string; const APort: UInt16): ITcpStream;
begin
  if Assigned(GH2ClientDialFunc) then
    Result := GH2ClientDialFunc(AHost, APort)
  else
    Result := DefaultH2ClientDial(AHost, APort);
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
    raise EArgumentError.Create('h2 client connection requires connection');
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
    raise EHttpError.Create('h2 client connection is not active');
end;

procedure TH2ClientConnection.EnsureOpen;
begin
  if FState = h2ccsClosed then
    raise EHttpError.Create('h2 client connection is closed');
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
    raise EHttpError.Create('HTTP/2 frame validation failed: ' +
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
      raise EHttpError.Create('HTTP/2 client write failed: connection closed');
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
  raise EHttpError.Create(AMessage);
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
    raise EHttpError.Create('HTTP/2 client stream ID overflow');
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
    raise EHttpError.Create('HTTP/2 client stream is already active');
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
    raise EHttpError.Create(
      'HTTP/2 client request body stalled: connection closed');
  DispatchFrame(LFrame, AStreamID, AStreamFlow, AResponse);
  if AResponse.PendingWindowUpdate > 0 then
  begin
    SendWindowUpdate(AStreamID, AResponse.PendingWindowUpdate);
    AResponse.PendingWindowUpdate := 0;
  end;
  FlushPendingConnectionWindowUpdate;
  if AResponse.Reset then
    raise EHttpError.Create('HTTP/2 stream reset while sending request body: ' +
      H2ErrorCodeName(AResponse.ResetCode));
end;

procedure TH2ClientConnection.SendRequestBody(const AStreamID: UInt32;
  const AReq: IHttpRequest; var AStreamFlow: TH2StreamFlowControl;
  var AResponse: TH2ResponseState);
var
  LRemaining: UInt32;
  LRead: SizeUInt;
  LChunkSize: UInt32;
  LCapacity: UInt32;
  LBuffer: array of Byte;
  LPayload: AnsiString;
  LFlags: Byte;
begin
  if (AReq.Body = nil) or (AReq.ContentLength <= 0) then
    Exit;

  LRemaining := UInt32(AReq.ContentLength);
  while LRemaining > 0 do
  begin
    LCapacity := RequestBodySendCapacity(AStreamFlow);
    while LCapacity = 0 do
    begin
      ReadRequestBodyFlowControlFrame(AStreamID, AStreamFlow, AResponse);
      LCapacity := RequestBodySendCapacity(AStreamFlow);
    end;
    LChunkSize := MinUInt32(FRemoteSettings.MaxFrameSize, LCapacity);
    LChunkSize := MinUInt32(LChunkSize, LRemaining);
    SetLength(LBuffer, LChunkSize);
    LRead := AReq.Body.Read(LBuffer[0], LChunkSize);
    if LRead = 0 then
      raise EHttpError.Create('HTTP/2 client request body ended before content-length');
    if not FConnectionFlow.SendWindow.TryReserve(UInt32(LRead)) then
      raise EHttpError.Create('HTTP/2 client connection send window reserve failed');
    if not AStreamFlow.SendWindow.TryReserve(UInt32(LRead)) then
    begin
      FConnectionFlow.SendWindow.ReleaseReserved(UInt32(LRead));
      raise EHttpError.Create('HTTP/2 client stream send window reserve failed');
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
var
  LLen: SizeInt;
begin
  LLen := Length(AResponse.HeaderFragments);
  SetLength(AResponse.HeaderFragments, LLen + 1);
  AResponse.HeaderFragments[LLen] := AFragment;
end;

procedure TH2ClientConnection.DecodeResponseHeaders(var AResponse: TH2ResponseState);
var
  LHeaders: array of THPackHeader;
  LBlock: AnsiString;
  LTotalLen: SizeInt;
  LWritePos: SizeInt;
  LI: SizeInt;
  LStatusText: string;
  LStatusValue: Int64;
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
  if not FDecoder.Decode(LBlock, LHeaders) then
    raise EHttpError.Create('HTTP/2 client HPACK decode failed');
  if AResponse.HeadersStore = nil then
  begin
    AResponse.HeadersStore := TH2OwnedHeaders.Create;
    AResponse.Headers := TH2OwnedHeaders(AResponse.HeadersStore);
  end;
  LStatusText := '';
  for LI := 0 to High(LHeaders) do
  begin
    if LHeaders[LI].Name = '' then
      Break;
    if LHeaders[LI].Name = ':status' then
      LStatusText := string(LHeaders[LI].Value)
    else
      TH2OwnedHeaders(AResponse.HeadersStore).Add(string(LHeaders[LI].Name),
        string(LHeaders[LI].Value));
  end;
  if (LStatusText = '') or (not TryStrToInt64(LStatusText, LStatusValue)) then
    raise EHttpError.Create('HTTP/2 response missing valid :status');
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
    raise EHttpError.Create('HTTP/2 invalid SETTINGS payload');
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
    raise EHttpError.Create('HTTP/2 invalid WINDOW_UPDATE payload');
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
    raise EHttpError.Create('HTTP/2 invalid PING payload');
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
    raise EHttpError.Create('HTTP/2 invalid GOAWAY payload');
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
    raise EHttpError.Create('HTTP/2 invalid RST_STREAM payload');
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
  if AFrame.Header.StreamID <> AStreamID then
    Exit;
  if not ExtractHeadersFragment(AFrame.Header.Flags, AFrame.Payload, LFragment) then
    raise EHttpError.Create('HTTP/2 invalid HEADERS payload');
  AResponse.HeaderFragments := nil;
  AppendResponseHeaderFragment(AResponse, LFragment);
  AResponse.HeadersComplete := False;
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
  if FPendingContinuationStreamID <> AFrame.Header.StreamID then
    raise EHttpError.Create('HTTP/2 unexpected CONTINUATION');
  if AFrame.Header.StreamID = AStreamID then
    AppendResponseHeaderFragment(AResponse, AFrame.Payload);
  if (AFrame.Header.Flags and H2_FLAG_CONTINUATION_END_HEADERS) <> 0 then
  begin
    FPendingContinuationStreamID := 0;
    if AFrame.Header.StreamID = AStreamID then
    begin
      AResponse.HeadersComplete := True;
      DecodeResponseHeaders(AResponse);
    end;
  end;
end;

procedure TH2ClientConnection.HandleData(const AFrame: TH2Frame;
  const AStreamID: UInt32; var AStreamFlow: TH2StreamFlowControl;
  var AResponse: TH2ResponseState);
var
  LData: AnsiString;
  LDataLen: UInt32;
begin
  if AFrame.Header.StreamID <> AStreamID then
    Exit;
  if not ExtractDataPayload(AFrame.Header.Flags, AFrame.Payload, LData) then
    raise EHttpError.Create('HTTP/2 invalid DATA payload');
  LDataLen := UInt32(Length(LData));
  if LDataLen > 0 then
  begin
    AStreamFlow.RecvWindow.OnDataReceived(LDataLen);
    FConnectionFlow.RecvWindow.OnDataReceived(LDataLen);
    AppendResponseBody(AResponse, LData);
    AStreamFlow.RecvWindow.OnDataConsumed(LDataLen);
    ConsumeResponseBody(AResponse, LDataLen);
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
    raise EHttpError.Create('HTTP/2 stream reset: ' +
      H2ErrorCodeName(AResponse.ResetCode));
  if AResponse.StatusCode = 0 then
    raise EHttpError.Create('HTTP/2 response missing status');
  if Length(AResponse.Body) > 0 then
    LBody := CreateBytesStreamFrom(AResponse.Body) as IReader
  else
    LBody := nil;
  Result := THttpResponse.Create(AResponse.StatusCode, AResponse.Headers, LBody);
end;

function TH2ClientConnection.Handshake: Boolean;
var
  LFrame: TH2Frame;
  LSettingsReceived: Boolean;
begin
  if FState = h2ccsActive then
    Exit(True);
  EnsureOpen;
  ApplyDeadline;
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
      raise EHttpError.Create('HTTP/2 handshake expected SETTINGS first');
    end;
  end;
  FState := h2ccsActive;
  Result := True;
end;

function TH2ClientConnection.RoundTrip(const AReq: IHttpRequest): IHttpResponse;
var
  LStreamID: UInt32;
  LStreamIndex: SizeInt;
  LHasBody: Boolean;
  LFrame: TH2Frame;
  LResponse: TH2ResponseState;
begin
  if AReq = nil then
    raise EArgumentError.Create('h2 client transport requires request');
  if AReq.Headers = nil then
    raise EArgumentError.Create('h2 client transport requires request headers');
  if not Handshake then
    raise EHttpError.Create('HTTP/2 client handshake failed');
  EnsureActive;
  LStreamID := AllocateStreamID;
  TH2ResponseState.Init(LResponse);
  LResponse.StreamID := LStreamID;
  LStreamIndex := AddActiveStream(LStreamID);
  try
    LHasBody := (AReq.Body <> nil) and (AReq.ContentLength > 0);
    SendRequestHeaders(LStreamID, AReq, not LHasBody);
    if LHasBody then
      SendRequestBody(LStreamID, AReq, FActiveStreams[LStreamIndex].Flow,
        LResponse);
    while not LResponse.EndStream do
    begin
      if not ReadFrame(LFrame) then
        raise EHttpError.Create('HTTP/2 response incomplete: connection closed');
      DispatchFrame(LFrame, LStreamID, FActiveStreams[LStreamIndex].Flow,
        LResponse);
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

function TH2ClientConnection.IsReusable: Boolean;
begin
  Result := (FConn <> nil) and (FState = h2ccsActive) and
    (not FGoawayReceived) and (not FGoawaySent);
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
  FPoolCount := 0;
end;

destructor TH2ClientTransport.Destroy;
begin
  PoolClear;
  inherited Destroy;
end;

function TH2ClientTransport.PoolGet(const AHost: string;
  const APort: UInt16): TH2ClientConnection;
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
      if (Result <> nil) and Result.IsReusable then
        Exit;
      if Result <> nil then
      begin
        Result.Close;
        Result.Free;
      end;
      Result := nil;
      Exit;
    end;
end;

procedure TH2ClientTransport.PoolPut(const AHost: string; const APort: UInt16;
  const AConn: TH2ClientConnection);
begin
  if (AConn = nil) or (not AConn.IsReusable) then
  begin
    if AConn <> nil then
    begin
      AConn.Close;
      AConn.Free;
    end;
    Exit;
  end;
  if (FOptions.MaxPoolSize > 0) and (FPoolCount >= FOptions.MaxPoolSize) then
  begin
    AConn.Close;
    AConn.Free;
    Exit;
  end;
  if FPoolCount >= Length(FPool) then
    SetLength(FPool, FPoolCount + 4);
  FPool[FPoolCount].Host := AHost;
  FPool[FPoolCount].Port := APort;
  FPool[FPoolCount].Conn := AConn;
  Inc(FPoolCount);
end;

procedure TH2ClientTransport.PoolClear;
var
  LI: Int32;
begin
  for LI := 0 to FPoolCount - 1 do
    if FPool[LI].Conn <> nil then
    begin
      FPool[LI].Conn.Close;
      FPool[LI].Conn.Free;
    end;
  FPool := nil;
  FPoolCount := 0;
end;

function TH2ClientTransport.RoundTrip(const AReq: IHttpRequest): IHttpResponse;
var
  LUrl: TUrl;
  LHost: string;
  LHostKey: string;
  LPort: UInt16;
  LConn: TH2ClientConnection;
  LPooled: Boolean;
  LBodyStream: IStream;
  LBodyStartPosition: Int64;
  LRequestWriteComplete: Boolean;
begin
  if AReq = nil then
    raise EArgumentError.Create('h2 client transport requires request');
  if AReq.Headers = nil then
    raise EArgumentError.Create('h2 client transport requires request headers');
  LUrl := AReq.Url;
  ValidatePlainHttpClientUrlScheme(LUrl);
  LHost := LUrl.Host;
  if LHost = '' then
    raise EHttpError.Create('HTTP/2 client request requires host');
  LPort := LUrl.Port;
  if LPort = 0 then
    LPort := 80;
  LHostKey := CanonicalPoolHostKey(LHost);
  CaptureRetryBodyPosition(AReq, LBodyStream, LBodyStartPosition);
  LConn := PoolGet(LHostKey, LPort);
  LPooled := LConn <> nil;
  if not LPooled then
    LConn := TH2ClientConnection.Create(H2ClientDial(LHost, LPort), FOptions);
  LRequestWriteComplete := False;
  try
    Result := LConn.RoundTrip(AReq);
    LRequestWriteComplete := True;
  except
    if LPooled then
    begin
      LConn.Close;
      LConn.Free;
      if (not LRequestWriteComplete) and (not IsRetrySafeRequest(AReq)) then
        raise;
      if (AReq.Body <> nil) and (AReq.ContentLength > 0) and (LBodyStream = nil) then
        raise;
      RewindRetryBody(AReq, LBodyStream, LBodyStartPosition);
      LConn := TH2ClientConnection.Create(H2ClientDial(LHost, LPort), FOptions);
      Result := LConn.RoundTrip(AReq);
    end
    else
    begin
      LConn.Close;
      LConn.Free;
      raise;
    end;
  end;
  if HeadersHaveConnectionCloseToken(AReq.Headers) or (not LConn.IsReusable) then
  begin
    LConn.Close;
    LConn.Free;
  end
  else
    PoolPut(LHostKey, LPort, LConn);
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
