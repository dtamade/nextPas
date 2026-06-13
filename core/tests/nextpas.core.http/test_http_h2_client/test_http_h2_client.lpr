program test_http_h2_client;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.io.base,
  nextpas.core.io.memory,
  nextpas.core.net.base,
  nextpas.core.net.intf,
  nextpas.core.time.deadline,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.headers,
  nextpas.core.http.message,
  nextpas.core.http.impl.h2.frame,
  nextpas.core.http.impl.h2.hpack,
  nextpas.core.http.impl.h2.types,
  nextpas.core.http.impl.h2.client,
  nextpas.core.http.impl.registry,
  nextpas.core.testing;

type
  TFakeTcpStream = class(TInterfacedObject, ITcpStream)
  private
    FReadData: AnsiString;
    FReadPos: SizeInt;
    FWrittenData: AnsiString;
    FClosed: Boolean;
    FLocalAddr: TNetAddress;
    FRemoteAddr: TNetAddress;
    FReadDeadline: TDeadline;
    FWriteDeadline: TDeadline;
    FMaxWriteChunk: SizeUInt;
  public
    constructor Create(const AReadData: AnsiString);
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
    procedure AppendReadData(const AData: AnsiString);
    function WrittenData: AnsiString;
    property MaxWriteChunk: SizeUInt read FMaxWriteChunk write FMaxWriteChunk;
  end;

var
  T: TTestRunner;
  GDialQueue: array of ITcpStream;
  GDialCount: SizeInt;
  GDialIndex: SizeInt;

function TestDial(const AHost: string; const APort: UInt16): ITcpStream;
begin
  Check(GDialIndex < GDialCount, 'dial queue has connection');
  Result := GDialQueue[GDialIndex];
  Inc(GDialIndex);
end;

procedure ResetDialQueue;
var
  LI: SizeInt;
begin
  for LI := 0 to GDialCount - 1 do
    GDialQueue[LI] := nil;
  GDialQueue := nil;
  GDialCount := 0;
  GDialIndex := 0;
end;

procedure QueueDialConn(const AConn: ITcpStream);
begin
  if GDialCount >= Length(GDialQueue) then
    SetLength(GDialQueue, GDialCount + 4);
  GDialQueue[GDialCount] := AConn;
  Inc(GDialCount);
end;

function HexNibble(const ACh: Char): Byte;
begin
  case ACh of
    '0'..'9':
      Result := Ord(ACh) - Ord('0');
    'a'..'f':
      Result := Ord(ACh) - Ord('a') + 10;
    'A'..'F':
      Result := Ord(ACh) - Ord('A') + 10;
  else
    Result := 0;
  end;
end;

function HexToBytes(const AHex: string): AnsiString;
var
  LI: SizeInt;
  LOut: SizeInt;
begin
  SetLength(Result, Length(AHex) div 2);
  LOut := 1;
  LI := 1;
  while LI < Length(AHex) do
  begin
    Result[LOut] := AnsiChar((HexNibble(AHex[LI]) shl 4) or
      HexNibble(AHex[LI + 1]));
    Inc(LOut);
    Inc(LI, 2);
  end;
end;

function EncodeHeaders(const AHeaders: array of THPackHeader): AnsiString;
var
  LEncoder: THPackEncoder;
begin
  LEncoder.Init;
  Result := LEncoder.Encode(AHeaders);
end;

function ComposeServerHandshake(const ASettingsPayload: AnsiString = ''): AnsiString;
begin
  Result := H2EncodeFrame(H2_FRAME_SETTINGS, 0, 0, ASettingsPayload);
end;

function ComposeResponseHeaders(const AStatus: string;
  const AExtraHeaders: array of THPackHeader): AnsiString;
var
  LHeaders: array of THPackHeader;
  LI: SizeInt;
begin
  SetLength(LHeaders, Length(AExtraHeaders) + 1);
  LHeaders[0].Name := ':status';
  LHeaders[0].Value := AnsiString(AStatus);
  for LI := 0 to High(AExtraHeaders) do
    LHeaders[LI + 1] := AExtraHeaders[LI];
  Result := EncodeHeaders(LHeaders);
end;

function ComposeResponse(const AStreamID: UInt32; const AStatus: string;
  const ABody: AnsiString; const AExtraHeaders: array of THPackHeader): AnsiString;
var
  LHeaderFlags: Byte;
begin
  LHeaderFlags := H2_FLAG_HEADERS_END_HEADERS;
  if ABody = '' then
    LHeaderFlags := LHeaderFlags or H2_FLAG_HEADERS_END_STREAM;
  Result := H2EncodeFrame(H2_FRAME_HEADERS, LHeaderFlags, AStreamID,
    ComposeResponseHeaders(AStatus, AExtraHeaders));
  if ABody <> '' then
    Result := Result + H2EncodeFrame(H2_FRAME_DATA, H2_FLAG_DATA_END_STREAM,
      AStreamID, ABody);
end;

function ComposePushPromisePayload(const APromisedStreamID: UInt32): AnsiString;
begin
  SetLength(Result, 4);
  Result[1] := AnsiChar(Byte((APromisedStreamID shr 24) and $7F));
  Result[2] := AnsiChar(Byte(APromisedStreamID shr 16));
  Result[3] := AnsiChar(Byte(APromisedStreamID shr 8));
  Result[4] := AnsiChar(Byte(APromisedStreamID));
end;

function ReadAllBody(const ABody: IReader): string;
var
  LBuf: array[0..255] of Byte;
  LRead: SizeUInt;
  LOldLen: SizeInt;
begin
  Result := '';
  if ABody = nil then
    Exit;
  repeat
    LRead := ABody.Read(LBuf[0], SizeOf(LBuf));
    if LRead = 0 then
      Break;
    LOldLen := Length(Result);
    SetLength(Result, LOldLen + SizeInt(LRead));
    Move(LBuf[0], Result[LOldLen + 1], LRead);
  until False;
end;

procedure DecodeFrames(const AWire: AnsiString; out AFrames: array of TH2Frame;
  out ACount: SizeInt);
var
  LOffset: SizeInt;
  LConsumed: SizeUInt;
  LFrame: TH2Frame;
begin
  ACount := 0;
  LOffset := 1;
  while LOffset <= Length(AWire) do
  begin
    Check(H2DecodeFrame(@AWire[LOffset], Length(AWire) - LOffset + 1,
      LFrame, LConsumed), 'frame decodes from wire');
    Check(ACount < Length(AFrames), 'frame output capacity sufficient');
    AFrames[ACount] := LFrame;
    Inc(ACount);
    Inc(LOffset, SizeInt(LConsumed));
  end;
end;

function FindSettingsValue(const APayload: AnsiString;
  const AIdentifier: UInt16; out AValue: UInt32): Boolean;
var
  LEntries: TH2SettingEntries;
  LI: SizeInt;
begin
  AValue := 0;
  Check(H2DecodeSettingsPayload(APayload, LEntries),
    'settings payload decodes');
  for LI := 0 to High(LEntries) do
    if LEntries[LI].Identifier = AIdentifier then
    begin
      AValue := LEntries[LI].Value;
      Exit(True);
    end;
  Result := False;
end;

function FindGoawayError(const AFrames: array of TH2Frame;
  const ACount: SizeInt; out AErrorCode: UInt32): Boolean;
var
  LI: SizeInt;
  LLastStreamID: UInt32;
  LDebugData: AnsiString;
begin
  AErrorCode := H2_ERR_NO_ERROR;
  for LI := 0 to ACount - 1 do
    if AFrames[LI].Header.FrameType = H2_FRAME_GOAWAY then
    begin
      Check(H2DecodeGoaway(AFrames[LI].Payload, LLastStreamID, AErrorCode,
        LDebugData), 'GOAWAY payload decodes');
      Exit(True);
    end;
  Result := False;
end;

function HeaderValue(const AHeaders: array of THPackHeader;
  const AName: AnsiString): string;
var
  LI: SizeInt;
begin
  Result := '';
  for LI := 0 to High(AHeaders) do
  begin
    if AHeaders[LI].Name = '' then
      Break;
    if AHeaders[LI].Name = AName then
      Exit(string(AHeaders[LI].Value));
  end;
end;

procedure DecodeRequestHeaders(const APayload: AnsiString;
  out AHeaders: array of THPackHeader);
var
  LDecoder: THPackDecoder;
begin
  LDecoder.Init;
  Check(LDecoder.Decode(APayload, AHeaders), 'request header block decodes');
end;

{ TFakeTcpStream }

constructor TFakeTcpStream.Create(const AReadData: AnsiString);
begin
  inherited Create;
  FReadData := AReadData;
  FReadPos := 1;
  FWrittenData := '';
  FClosed := False;
  FLocalAddr := TNetAddress.Loopback(8080);
  FRemoteAddr := TNetAddress.IPv4('127.0.0.2', 9000);
  FReadDeadline := TDeadline.Infinite;
  FWriteDeadline := TDeadline.Infinite;
  FMaxWriteChunk := 0;
end;

function TFakeTcpStream.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
var
  LAvailable: SizeUInt;
begin
  if FClosed or (FReadPos > Length(FReadData)) then
    Exit(0);
  LAvailable := SizeUInt(Length(FReadData) - FReadPos + 1);
  if ACount < LAvailable then
    Result := ACount
  else
    Result := LAvailable;
  Move(FReadData[FReadPos], ABuf, Result);
  Inc(FReadPos, SizeInt(Result));
end;

function TFakeTcpStream.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
var
  LWriteCount: SizeUInt;
  LOldLen: SizeInt;
begin
  if FClosed then
    Exit(0);
  LWriteCount := ACount;
  if (FMaxWriteChunk > 0) and (LWriteCount > FMaxWriteChunk) then
    LWriteCount := FMaxWriteChunk;
  if LWriteCount = 0 then
    Exit(0);
  LOldLen := Length(FWrittenData);
  SetLength(FWrittenData, LOldLen + SizeInt(LWriteCount));
  Move(ABuf, FWrittenData[LOldLen + 1], LWriteCount);
  Result := LWriteCount;
end;

function TFakeTcpStream.Seek(const AOffset: Int64; const AOrigin: TSeekOrigin): Int64;
begin
  Result := 0;
end;

procedure TFakeTcpStream.Close;
begin
  FClosed := True;
end;

function TFakeTcpStream.GetSize: Int64;
begin
  Result := 0;
end;

function TFakeTcpStream.GetPosition: Int64;
begin
  Result := 0;
end;

procedure TFakeTcpStream.SetPosition(const AValue: Int64);
begin
end;

function TFakeTcpStream.LocalAddr: TNetAddress;
begin
  Result := FLocalAddr;
end;

function TFakeTcpStream.RemoteAddr: TNetAddress;
begin
  Result := FRemoteAddr;
end;

procedure TFakeTcpStream.Shutdown;
begin
  FClosed := True;
end;

procedure TFakeTcpStream.SetNoDelay(const AValue: Boolean);
begin
end;

procedure TFakeTcpStream.SetKeepAlive(const AValue: Boolean);
begin
end;

procedure TFakeTcpStream.SetReadDeadline(const ADeadline: TDeadline);
begin
  FReadDeadline := ADeadline;
end;

procedure TFakeTcpStream.SetWriteDeadline(const ADeadline: TDeadline);
begin
  FWriteDeadline := ADeadline;
end;

procedure TFakeTcpStream.AppendReadData(const AData: AnsiString);
var
  LOldLen: SizeInt;
begin
  LOldLen := Length(FReadData);
  SetLength(FReadData, LOldLen + Length(AData));
  Move(AData[1], FReadData[LOldLen + 1], Length(AData));
end;

function TFakeTcpStream.WrittenData: AnsiString;
begin
  Result := FWrittenData;
end;

procedure TestHandshakeWritesClientPrefaceAndSettings;
var
  LConn: TH2ClientConnection;
  LStream: TFakeTcpStream;
  LFrames: array[0..7] of TH2Frame;
  LCount: SizeInt;
  LEnablePushValue: UInt32;
begin
  LStream := TFakeTcpStream.Create(ComposeServerHandshake);
  LConn := TH2ClientConnection.Create(LStream as ITcpStream,
    TH2ClientTransportOptions.Default);
  try
    Check(LConn.Handshake, 'handshake succeeds');
    CheckEqual(Int64(Ord(h2ccsActive)), Int64(Ord(LConn.State)),
      'connection becomes active');
    Check(Pos(H2_CLIENT_PREFACE, LStream.WrittenData) = 1,
      'client preface written first');
    DecodeFrames(Copy(LStream.WrittenData, Length(H2_CLIENT_PREFACE) + 1,
      MaxInt), LFrames, LCount);
    Check(LCount >= 2, 'client wrote settings and ack/window delta');
    CheckEqual(Int64(H2_FRAME_SETTINGS), Int64(LFrames[0].Header.FrameType),
      'first frame is settings');
    Check(FindSettingsValue(LFrames[0].Payload, H2_SETTINGS_ENABLE_PUSH,
      LEnablePushValue), 'client sends SETTINGS_ENABLE_PUSH');
    CheckEqual(Int64(0), Int64(LEnablePushValue),
      'client disables server push');
    CheckEqual(Int64(H2_FRAME_SETTINGS), Int64(LFrames[1].Header.FrameType),
      'second frame is settings ack');
    CheckEqual(Int64(H2_FLAG_SETTINGS_ACK), Int64(LFrames[1].Header.Flags),
      'settings ack flag');
  finally
    LConn.Free;
    LStream := nil;
  end;
end;

procedure TestRoundTripGetReadsResponse;
var
  LConn: TH2ClientConnection;
  LStream: TFakeTcpStream;
  LResp: IHttpResponse;
  LFrames: array[0..7] of TH2Frame;
  LDecodedHeaders: array of THPackHeader;
  LCount: SizeInt;
  LRequestIndex: SizeInt;
begin
  LStream := TFakeTcpStream.Create(
    ComposeServerHandshake +
    ComposeResponse(1, '200', 'pong', []));
  LConn := TH2ClientConnection.Create(LStream as ITcpStream,
    TH2ClientTransportOptions.Default);
  try
    LResp := LConn.RoundTrip(NewRequest(hmGet, 'http://example.com/ping'));
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'response status');
    CheckEqual('pong', ReadAllBody(LResp.Body), 'response body');
    DecodeFrames(Copy(LStream.WrittenData, Length(H2_CLIENT_PREFACE) + 1,
      MaxInt), LFrames, LCount);
    Check(LCount >= 3, 'settings, ack, request headers sent');
    LRequestIndex := 2;
    if (LCount > 3) and (LFrames[2].Header.FrameType <> H2_FRAME_HEADERS) then
      LRequestIndex := LCount - 1;
    CheckEqual(Int64(H2_FRAME_HEADERS), Int64(LFrames[LRequestIndex].Header.FrameType),
      'request uses headers frame');
    CheckEqual(Int64(1), Int64(LFrames[LRequestIndex].Header.StreamID),
      'first request uses stream 1');
    SetLength(LDecodedHeaders, Length(LFrames[LRequestIndex].Payload) + 4);
    DecodeRequestHeaders(LFrames[LRequestIndex].Payload, LDecodedHeaders);
    CheckEqual('GET', HeaderValue(LDecodedHeaders, ':method'), 'pseudo method');
    CheckEqual('/ping', HeaderValue(LDecodedHeaders, ':path'), 'pseudo path');
    CheckEqual('example.com', HeaderValue(LDecodedHeaders, ':authority'),
      'pseudo authority');
  finally
    LResp := nil;
    LConn.Free;
    LConn := nil;
    LStream := nil;
  end;
end;

procedure TestRoundTripPostWritesDataFrame;
var
  LConn: TH2ClientConnection;
  LStream: TFakeTcpStream;
  LResp: IHttpResponse;
  LBody: IStream;
  LFrames: array[0..15] of TH2Frame;
  LCount: SizeInt;
begin
  LBody := CreateBytesStreamFrom([Byte('a'), Byte('b'), Byte('c')]);
  LStream := TFakeTcpStream.Create(
    ComposeServerHandshake +
    ComposeResponse(1, '201', '', []));
  LConn := TH2ClientConnection.Create(LStream as ITcpStream,
    TH2ClientTransportOptions.Default);
  try
    LResp := LConn.RoundTrip(NewRequest(hmPost, 'http://example.com/post',
      NewHttpHeaders, LBody as IReader, 3));
    CheckEqual(Int64(201), Int64(LResp.StatusCode), 'post response status');
    DecodeFrames(Copy(LStream.WrittenData, Length(H2_CLIENT_PREFACE) + 1,
      MaxInt), LFrames, LCount);
    Check(LCount >= 4, 'settings, ack, headers, data');
    CheckEqual(Int64(H2_FRAME_DATA), Int64(LFrames[LCount - 1].Header.FrameType),
      'post writes data frame');
    CheckEqual('abc', string(LFrames[LCount - 1].Payload), 'data payload');
    Check((LFrames[LCount - 1].Header.Flags and H2_FLAG_DATA_END_STREAM) <> 0,
      'data ends stream');
  finally
    LResp := nil;
    LConn.Free;
    LConn := nil;
    LStream := nil;
    LBody := nil;
  end;
end;

procedure TestStreamIdIncrementsAcrossRequests;
var
  LConn: TH2ClientConnection;
  LStream: TFakeTcpStream;
  LResp: IHttpResponse;
begin
  LStream := TFakeTcpStream.Create(
    ComposeServerHandshake +
    ComposeResponse(1, '200', '', []) +
    ComposeResponse(3, '200', '', []));
  LConn := TH2ClientConnection.Create(LStream as ITcpStream,
    TH2ClientTransportOptions.Default);
  try
    LResp := LConn.RoundTrip(NewRequest(hmGet, 'http://example.com/one'));
    LResp := nil;
    CheckEqual(Int64(3), Int64(LConn.NextStreamID), 'next stream after first request');
    LResp := LConn.RoundTrip(NewRequest(hmGet, 'http://example.com/two'));
    LResp := nil;
    CheckEqual(Int64(5), Int64(LConn.NextStreamID), 'next stream after second request');
  finally
    LConn.Free;
    LConn := nil;
    LStream := nil;
  end;
end;

procedure TestGoawayMarksConnectionNotReusable;
var
  LConn: TH2ClientConnection;
  LStream: TFakeTcpStream;
  LResp: IHttpResponse;
begin
  LStream := TFakeTcpStream.Create(
    ComposeServerHandshake +
    ComposeResponse(1, '200', '', []) +
    H2EncodeFrame(H2_FRAME_GOAWAY, 0, 0, H2EncodeGoaway(1, H2_ERR_NO_ERROR, '')));
  LConn := TH2ClientConnection.Create(LStream as ITcpStream,
    TH2ClientTransportOptions.Default);
  try
    LResp := LConn.RoundTrip(NewRequest(hmGet, 'http://example.com/goaway'));
    LResp := nil;
    CheckEqual(False, LConn.IsReusable, 'goaway makes connection non-reusable');
  finally
    LConn.Free;
    LConn := nil;
    LStream := nil;
  end;
end;

procedure TestPushPromiseTriggersProtocolGoaway;
var
  LConn: TH2ClientConnection;
  LStream: TFakeTcpStream;
  LResp: IHttpResponse;
  LFrames: array[0..15] of TH2Frame;
  LCount: SizeInt;
  LErrorCode: UInt32;
  LErrorRaised: Boolean;
begin
  LResp := nil;
  LStream := TFakeTcpStream.Create(
    ComposeServerHandshake +
    H2EncodeFrame(H2_FRAME_PUSH_PROMISE, H2_FLAG_PUSH_PROMISE_END_HEADERS, 1,
      ComposePushPromisePayload(2)) +
    ComposeResponse(1, '200', '', []));
  LConn := TH2ClientConnection.Create(LStream as ITcpStream,
    TH2ClientTransportOptions.Default);
  try
    LErrorRaised := False;
    try
      LResp := LConn.RoundTrip(NewRequest(hmGet, 'http://example.com/push'));
      LResp := nil;
    except
      on E: Exception do
        LErrorRaised := True;
    end;
    Check(LErrorRaised, 'PUSH_PROMISE aborts client round trip');
    CheckEqual(Int64(Ord(h2ccsClosed)), Int64(Ord(LConn.State)),
      'PUSH_PROMISE closes client connection');
    CheckEqual(True, LStream.FClosed, 'PUSH_PROMISE closes TCP stream');

    DecodeFrames(Copy(LStream.WrittenData, Length(H2_CLIENT_PREFACE) + 1,
      MaxInt), LFrames, LCount);
    Check(FindGoawayError(LFrames, LCount, LErrorCode),
      'client writes GOAWAY for PUSH_PROMISE');
    CheckEqual(Int64(H2_ERR_PROTOCOL_ERROR), Int64(LErrorCode),
      'PUSH_PROMISE GOAWAY uses PROTOCOL_ERROR');
  finally
    LResp := nil;
    LConn.Free;
    LConn := nil;
    LStream := nil;
  end;
end;

procedure TestPingGetsAcked;
var
  LConn: TH2ClientConnection;
  LStream: TFakeTcpStream;
  LResp: IHttpResponse;
  LFrames: array[0..15] of TH2Frame;
  LCount: SizeInt;
  LFoundAck: Boolean;
  LI: SizeInt;
begin
  LStream := TFakeTcpStream.Create(
    ComposeServerHandshake +
    H2EncodeFrame(H2_FRAME_PING, 0, 0, H2EncodePing($0102030405060708)) +
    ComposeResponse(1, '200', '', []));
  LConn := TH2ClientConnection.Create(LStream as ITcpStream,
    TH2ClientTransportOptions.Default);
  try
    LResp := LConn.RoundTrip(NewRequest(hmGet, 'http://example.com/ping-ack'));
    LResp := nil;
    DecodeFrames(Copy(LStream.WrittenData, Length(H2_CLIENT_PREFACE) + 1,
      MaxInt), LFrames, LCount);
    LFoundAck := False;
    for LI := 0 to LCount - 1 do
      if (LFrames[LI].Header.FrameType = H2_FRAME_PING) and
         ((LFrames[LI].Header.Flags and H2_FLAG_PING_ACK) <> 0) then
        LFoundAck := True;
    Check(LFoundAck, 'client writes ping ack');
  finally
    LConn.Free;
    LConn := nil;
    LStream := nil;
  end;
end;

procedure TestTransportReusesPooledConnection;
var
  LTransport: IHttpTransport;
  LIdle: IHttpTransportIdleConnections;
  LStream: TFakeTcpStream;
  LResp: IHttpResponse;
  LFrames: array[0..31] of TH2Frame;
  LCount: SizeInt;
  LRequestFrameCount: Int32;
  LI: SizeInt;
begin
  ResetDialQueue;
  LStream := TFakeTcpStream.Create(
    ComposeServerHandshake +
    ComposeResponse(1, '200', '', []) +
    ComposeResponse(3, '200', '', []));
  QueueDialConn(LStream as ITcpStream);
  SetH2ClientDialFuncForTests(@TestDial);
  try
    LTransport := NewH2ClientTransport(TH2ClientTransportOptions.Default);
    Check(Supports(LTransport, IHttpTransportIdleConnections, LIdle),
      'h2 client transport supports idle close');
    LResp := LTransport.RoundTrip(NewRequest(hmGet, 'http://example.com/one'));
    LResp := nil;
    LResp := LTransport.RoundTrip(NewRequest(hmGet, 'http://example.com/two'));
    LResp := nil;
    CheckEqual(Int64(1), Int64(GDialIndex), 'pooled transport dialed once');
    DecodeFrames(Copy(LStream.WrittenData, Length(H2_CLIENT_PREFACE) + 1,
      MaxInt), LFrames, LCount);
    LRequestFrameCount := 0;
    for LI := 0 to LCount - 1 do
      if LFrames[LI].Header.FrameType = H2_FRAME_HEADERS then
        Inc(LRequestFrameCount);
    Check(LRequestFrameCount >= 2, 'two request header frames sent on one conn');
  finally
    ResetH2ClientDialFuncForTests;
    ResetDialQueue;
    LTransport := nil;
    LIdle := nil;
    LStream := nil;
  end;
end;

procedure TestTransportCloseIdleConnectionsClosesPooledConn;
var
  LTransport: IHttpTransport;
  LIdle: IHttpTransportIdleConnections;
  LStream: TFakeTcpStream;
  LResp: IHttpResponse;
begin
  ResetDialQueue;
  LStream := TFakeTcpStream.Create(
    ComposeServerHandshake +
    ComposeResponse(1, '200', '', []));
  QueueDialConn(LStream as ITcpStream);
  SetH2ClientDialFuncForTests(@TestDial);
  try
    LTransport := NewH2ClientTransport(TH2ClientTransportOptions.Default);
    Check(Supports(LTransport, IHttpTransportIdleConnections, LIdle),
      'transport supports idle close');
    LResp := LTransport.RoundTrip(NewRequest(hmGet, 'http://example.com/idle'));
    LResp := nil;
    LIdle.CloseIdleConnections;
    CheckEqual(True, LStream.FClosed, 'idle connection closed');
  finally
    ResetH2ClientDialFuncForTests;
    ResetDialQueue;
    LTransport := nil;
    LIdle := nil;
    LStream := nil;
  end;
end;

procedure TestBuiltinHttp2ClientTransportIsRegistered;
var
  LTransport: IHttpTransport;
begin
  LTransport := ResolveClientTransport(hvHttp2, THttpClientOptions.Default);
  Check(LTransport <> nil, 'built-in HTTP/2 client transport resolves');
end;

begin
  T := TTestRunner.Create('test_http_h2_client');
  T.Run('Handshake writes client preface and settings',
    @TestHandshakeWritesClientPrefaceAndSettings);
  T.Run('RoundTrip GET reads response',
    @TestRoundTripGetReadsResponse);
  T.Run('RoundTrip POST writes data frame',
    @TestRoundTripPostWritesDataFrame);
  T.Run('Stream ID increments across requests',
    @TestStreamIdIncrementsAcrossRequests);
  T.Run('GOAWAY marks connection not reusable',
    @TestGoawayMarksConnectionNotReusable);
  T.Run('PUSH_PROMISE triggers PROTOCOL_ERROR GOAWAY',
    @TestPushPromiseTriggersProtocolGoaway);
  T.Run('PING gets acked',
    @TestPingGetsAcked);
  T.Run('Transport reuses pooled connection',
    @TestTransportReusesPooledConnection);
  T.Run('Transport CloseIdleConnections closes pooled conn',
    @TestTransportCloseIdleConnectionsClosesPooledConn);
  T.Run('Built-in HTTP/2 client transport is registered',
    @TestBuiltinHttp2ClientTransportIsRegistered);
  T.Summary;
end.
