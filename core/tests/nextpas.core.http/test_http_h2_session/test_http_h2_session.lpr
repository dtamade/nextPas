program test_http_h2_session;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.io.intf,
  nextpas.core.io.base,
  nextpas.core.io.memory,
  nextpas.core.net.base,
  nextpas.core.net.intf,
  nextpas.core.net.server.intf,
  nextpas.core.platform.io.base,
  nextpas.core.time.deadline,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.impl.h2.frame,
  nextpas.core.http.impl.h2.hpack,
  nextpas.core.http.impl.h2.session,
  nextpas.core.http.impl.h2.stream,
  nextpas.core.http.impl.h2.types,
  nextpas.core.testing;

const
  H2_SESSION_SOURCE_PATH_FROM_TEST =
    '../../../src/nextpas.core.http.impl.h2.session.pas';
  H2_SESSION_SOURCE_PATH_FROM_ROOT =
    'core/src/nextpas.core.http.impl.h2.session.pas';

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

  TCollectingHandler = class(TInterfacedObject, IHttpHandler)
  private
    FSeenMethod: THttpMethod;
    FSeenPath: string;
    FSeenBody: string;
    FSeenHeaders: IHttpHeaders;
    FSeenTrailers: IHttpHeaders;
    FCallCount: Int32;
    FResponseStatus: THttpStatus;
    FResponseHeaders: array of record
      Name: string;
      Value: string;
    end;
    FResponseBody: string;
  public
    constructor Create;
    procedure SetResponse(const AStatus: THttpStatus; const ABody: string);
    procedure AddResponseHeader(const AName, AValue: string);
    procedure ServeHTTP(const AReq: IHttpRequest; const AW: IHttpResponseWriter);
    property SeenMethod: THttpMethod read FSeenMethod;
    property SeenPath: string read FSeenPath;
    property SeenBody: string read FSeenBody;
    property SeenHeaders: IHttpHeaders read FSeenHeaders;
    property SeenTrailers: IHttpHeaders read FSeenTrailers;
    property CallCount: Int32 read FCallCount;
  end;

  TFailingHandler = class(TInterfacedObject, IHttpHandler)
  public
    procedure ServeHTTP(const AReq: IHttpRequest; const AW: IHttpResponseWriter);
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

function ReadSourceFile(const APath: string): string;
var
  LFile: Text;
  LLine: string;
begin
  Result := '';
  Assign(LFile, APath);
  Reset(LFile);
  try
    while not Eof(LFile) do
    begin
      ReadLn(LFile, LLine);
      Result := Result + LLine + #10;
    end;
  finally
    Close(LFile);
  end;
end;

function ResolveSourcePath(const APathFromTest, APathFromRoot: string): string;
begin
  if FileExists(APathFromTest) then
    Exit(APathFromTest);
  if FileExists(APathFromRoot) then
    Exit(APathFromRoot);
  Result := APathFromTest;
end;

function ComposePushPromisePayload(const APromisedStreamID: UInt32): AnsiString;
begin
  SetLength(Result, 4);
  Result[1] := AnsiChar(Byte((APromisedStreamID shr 24) and $7F));
  Result[2] := AnsiChar(Byte(APromisedStreamID shr 16));
  Result[3] := AnsiChar(Byte(APromisedStreamID shr 8));
  Result[4] := AnsiChar(Byte(APromisedStreamID));
end;

function EncodeHeaders(const AHeaders: array of THPackHeader): AnsiString;
var
  LEncoder: THPackEncoder;
begin
  LEncoder.Init;
  Result := LEncoder.Encode(AHeaders);
end;

function ComposeRequestHeadersWithExtras(const AMethod, APath: AnsiString;
  const AExtraHeaders: array of THPackHeader): AnsiString;
var
  LHeaders: array of THPackHeader;
  LI: SizeInt;
begin
  SetLength(LHeaders, 4 + Length(AExtraHeaders));
  LHeaders[0].Name := ':method';
  LHeaders[0].Value := AMethod;
  LHeaders[1].Name := ':path';
  LHeaders[1].Value := APath;
  LHeaders[2].Name := ':scheme';
  LHeaders[2].Value := 'https';
  LHeaders[3].Name := ':authority';
  LHeaders[3].Value := 'example.com';
  for LI := 0 to High(AExtraHeaders) do
    LHeaders[LI + 4] := AExtraHeaders[LI];
  Result := EncodeHeaders(LHeaders);
end;

function ComposeRequestHeaders(const AMethod, APath: AnsiString): AnsiString;
begin
  Result := ComposeRequestHeadersWithExtras(AMethod, APath, []);
end;

function ComposePrefaceHandshake(const ASettingsPayload: AnsiString = ''): AnsiString;
begin
  Result := H2_CLIENT_PREFACE +
    H2EncodeFrame(H2_FRAME_SETTINGS, 0, 0, ASettingsPayload);
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
    Check(LOffset + H2_FRAME_HEADER_SIZE - 1 <= Length(AWire),
      'wire contains full frame header');
    Check(H2DecodeFrame(@AWire[LOffset], Length(AWire) - LOffset + 1,
      LFrame, LConsumed), 'frame decodes from wire');
    Check(ACount < Length(AFrames), 'frame output capacity sufficient');
    AFrames[ACount] := LFrame;
    Inc(ACount);
    Inc(LOffset, SizeInt(LConsumed));
  end;
end;

function FindGoawayDetails(const AFrames: array of TH2Frame;
  const ACount: SizeInt; out ALastStreamID: UInt32;
  out AErrorCode: UInt32): Boolean;
var
  LI: SizeInt;
  LDebugData: AnsiString;
begin
  ALastStreamID := 0;
  AErrorCode := H2_ERR_NO_ERROR;
  for LI := 0 to ACount - 1 do
    if AFrames[LI].Header.FrameType = H2_FRAME_GOAWAY then
    begin
      Check(H2DecodeGoaway(AFrames[LI].Payload, ALastStreamID, AErrorCode,
        LDebugData), 'GOAWAY payload decodes');
      Exit(True);
    end;
  Result := False;
end;

function FindGoawayError(const AFrames: array of TH2Frame;
  const ACount: SizeInt; out AErrorCode: UInt32): Boolean;
var
  LLastStreamID: UInt32;
begin
  Result := FindGoawayDetails(AFrames, ACount, LLastStreamID, AErrorCode);
end;

function FindRstStreamError(const AFrames: array of TH2Frame;
  const ACount: SizeInt; const AStreamID: UInt32;
  out AErrorCode: UInt32): Boolean;
var
  LI: SizeInt;
begin
  AErrorCode := H2_ERR_NO_ERROR;
  for LI := 0 to ACount - 1 do
    if (AFrames[LI].Header.FrameType = H2_FRAME_RST_STREAM) and
       (AFrames[LI].Header.StreamID = AStreamID) then
    begin
      Check(H2DecodeRstStream(AFrames[LI].Payload, AErrorCode),
        'RST_STREAM payload decodes');
      Exit(True);
    end;
  Result := False;
end;

function FindSettingsValue(const APayload: AnsiString; const AIdentifier: UInt16;
  out AValue: UInt32): Boolean;
var
  LEntries: TH2SettingEntries;
  LI: SizeInt;
begin
  AValue := 0;
  Check(H2DecodeSettingsPayload(APayload, LEntries), 'SETTINGS payload decodes');
  for LI := 0 to High(LEntries) do
    if LEntries[LI].Identifier = AIdentifier then
    begin
      AValue := LEntries[LI].Value;
      Exit(True);
    end;
  Result := False;
end;

function HasFrameType(const AFrames: array of TH2Frame; const ACount: SizeInt;
  const AFrameType: Byte): Boolean;
var
  LI: SizeInt;
begin
  for LI := 0 to ACount - 1 do
    if AFrames[LI].Header.FrameType = AFrameType then
      Exit(True);
  Result := False;
end;

function ExtractStatusHeader(const ABlock: AnsiString): string;
var
  LDecoder: THPackDecoder;
  LHeaders: array of THPackHeader;
  LI: SizeInt;
begin
  LDecoder.Init;
  SetLength(LHeaders, Length(ABlock) + 4);
  Check(LDecoder.Decode(ABlock, LHeaders), 'response header block decodes');
  for LI := 0 to High(LHeaders) do
  begin
    if LHeaders[LI].Name = ':status' then
      Exit(string(LHeaders[LI].Value));
    if LHeaders[LI].Name = '' then
      Break;
  end;
  Result := '';
end;

procedure CheckPrefaceStatus(const AWire: AnsiString;
  const AExpectedStatus: TH2PrefaceStatus; const AExpectedConsumed: SizeUInt;
  const AExpectedError: UInt32; const AMessage: string);
var
  LConsumed: SizeUInt;
  LErrorCode: UInt32;
  LStatus: TH2PrefaceStatus;
begin
  LConsumed := 12345;
  LErrorCode := $FFFFFFFF;
  if Length(AWire) = 0 then
    LStatus := H2ValidateServerPreface(nil, 0, LConsumed, LErrorCode)
  else
    LStatus := H2ValidateServerPreface(@AWire[1], Length(AWire), LConsumed,
      LErrorCode);
  CheckEqual(Int64(Ord(AExpectedStatus)), Int64(Ord(LStatus)),
    AMessage + ' status');
  CheckEqual(Int64(AExpectedConsumed), Int64(LConsumed),
    AMessage + ' consumed');
  CheckEqual(Int64(AExpectedError), Int64(LErrorCode), AMessage + ' error');
end;

{ TFakeTcpStream }

constructor TFakeTcpStream.Create(const AReadData: AnsiString);
begin
  inherited Create;
  FReadData := AReadData;
  FReadPos := 1;
  FWrittenData := '';
  FClosed := False;
  FLocalAddr := TNetAddress.Loopback(8443);
  FRemoteAddr := TNetAddress.IPv4('127.0.0.2', 5050);
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
  raise EIOError.Create('fake tcp stream does not support seek');
end;

procedure TFakeTcpStream.Close;
begin
  FClosed := True;
end;

function TFakeTcpStream.GetSize: Int64;
begin
  Result := Length(FReadData);
end;

function TFakeTcpStream.GetPosition: Int64;
begin
  Result := FReadPos - 1;
end;

procedure TFakeTcpStream.SetPosition(const AValue: Int64);
begin
  if (AValue < 0) or (AValue > Length(FReadData)) then
    raise EArgumentError.Create('fake tcp stream position out of range');
  FReadPos := SizeInt(AValue) + 1;
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
  if AData <> '' then
    Move(AData[1], FReadData[LOldLen + 1], Length(AData));
end;

function TFakeTcpStream.WrittenData: AnsiString;
begin
  Result := FWrittenData;
end;

{ TCollectingHandler }

constructor TCollectingHandler.Create;
begin
  inherited Create;
  FSeenMethod := hmGet;
  FSeenPath := '';
  FSeenBody := '';
  FSeenHeaders := nil;
  FSeenTrailers := nil;
  FCallCount := 0;
  FResponseStatus := HTTP_STATUS_OK;
  FResponseBody := '';
  SetLength(FResponseHeaders, 0);
end;

procedure TCollectingHandler.SetResponse(const AStatus: THttpStatus;
  const ABody: string);
begin
  FResponseStatus := AStatus;
  FResponseBody := ABody;
end;

procedure TCollectingHandler.AddResponseHeader(const AName, AValue: string);
var
  LLen: SizeInt;
begin
  LLen := Length(FResponseHeaders);
  SetLength(FResponseHeaders, LLen + 1);
  FResponseHeaders[LLen].Name := AName;
  FResponseHeaders[LLen].Value := AValue;
end;

procedure TCollectingHandler.ServeHTTP(const AReq: IHttpRequest;
  const AW: IHttpResponseWriter);
var
  LI: SizeInt;
begin
  Inc(FCallCount);
  FSeenMethod := AReq.Method;
  FSeenPath := AReq.Path;
  FSeenBody := ReadAllBody(AReq.Body);
  if AReq.Headers <> nil then
    FSeenHeaders := AReq.Headers.Clone
  else
    FSeenHeaders := nil;
  if AReq.Trailers <> nil then
    FSeenTrailers := AReq.Trailers.Clone
  else
    FSeenTrailers := nil;
  for LI := 0 to High(FResponseHeaders) do
    AW.GetHeaders.SetHeader(FResponseHeaders[LI].Name,
      FResponseHeaders[LI].Value);
  if FResponseBody <> '' then
    AW.GetHeaders.SetHeader('content-length', IntToStr(Length(FResponseBody)));
  AW.WriteHeader(FResponseStatus);
  if FResponseBody <> '' then
    CheckEqual(Int64(Length(FResponseBody)),
      Int64(AW.Write(FResponseBody[1], Length(FResponseBody))),
      'response writer writes full body');
end;

procedure TFailingHandler.ServeHTTP(const AReq: IHttpRequest;
  const AW: IHttpResponseWriter);
begin
  raise EHttpError.Create('boom');
end;

procedure TestPartialPrefaceWaits;
begin
  CheckPrefaceStatus(Copy(H2_CLIENT_PREFACE, 1, 7), h2psNeedMore, 0,
    H2_ERR_NO_ERROR, 'partial preface');
end;

procedure TestWrongPrefaceIsConnectionError;
var
  LWire: AnsiString;
begin
  LWire := H2_CLIENT_PREFACE;
  LWire[1] := 'X';
  CheckPrefaceStatus(LWire, h2psConnectionError, 0, H2_ERR_PROTOCOL_ERROR,
    'wrong preface');
end;

procedure TestPrefaceWithoutFirstFrameWaits;
begin
  CheckPrefaceStatus(H2_CLIENT_PREFACE, h2psNeedMore, 0, H2_ERR_NO_ERROR,
    'preface only');
end;

procedure TestPartialFirstFrameWaits;
var
  LSettings: AnsiString;
begin
  LSettings := H2EncodeFrame(H2_FRAME_SETTINGS, 0, 0, '');
  CheckPrefaceStatus(H2_CLIENT_PREFACE + Copy(LSettings, 1, 4),
    h2psNeedMore, 0, H2_ERR_NO_ERROR, 'partial first frame');
end;

procedure TestInitialSettingsAccepted;
var
  LSettings: AnsiString;
begin
  LSettings := H2EncodeFrame(H2_FRAME_SETTINGS, 0, 0, '');
  CheckPrefaceStatus(H2_CLIENT_PREFACE + LSettings, h2psOk,
    Length(H2_CLIENT_PREFACE) + Length(LSettings), H2_ERR_NO_ERROR,
    'initial SETTINGS');
end;

procedure TestInitialSettingsWithPayloadAccepted;
var
  LEntries: TH2SettingEntries;
  LSettings: AnsiString;
begin
  SetLength(LEntries, 2);
  LEntries[0].Identifier := H2_SETTINGS_HEADER_TABLE_SIZE;
  LEntries[0].Value := 4096;
  LEntries[1].Identifier := H2_SETTINGS_MAX_FRAME_SIZE;
  LEntries[1].Value := 16384;
  LSettings := H2EncodeFrame(H2_FRAME_SETTINGS, 0, 0,
    H2EncodeSettingsPayload(LEntries));
  CheckPrefaceStatus(H2_CLIENT_PREFACE + LSettings, h2psOk,
    Length(H2_CLIENT_PREFACE) + Length(LSettings), H2_ERR_NO_ERROR,
    'initial SETTINGS payload');
end;

procedure TestFirstFrameMustBeSettings;
var
  LPing: AnsiString;
begin
  LPing := H2EncodeFrame(H2_FRAME_PING, 0, 0,
    HexToBytes('0102030405060708'));
  CheckPrefaceStatus(H2_CLIENT_PREFACE + LPing, h2psConnectionError, 0,
    H2_ERR_PROTOCOL_ERROR, 'first frame PING');
end;

procedure TestInitialSettingsMustNotAck;
var
  LSettings: AnsiString;
begin
  LSettings := H2EncodeFrame(H2_FRAME_SETTINGS, H2_FLAG_SETTINGS_ACK, 0, '');
  CheckPrefaceStatus(H2_CLIENT_PREFACE + LSettings, h2psConnectionError, 0,
    H2_ERR_PROTOCOL_ERROR, 'initial SETTINGS ACK');
end;

procedure TestInitialSettingsUsesConnectionStream;
var
  LSettings: AnsiString;
begin
  LSettings := H2EncodeFrame(H2_FRAME_SETTINGS, 0, 1, '');
  CheckPrefaceStatus(H2_CLIENT_PREFACE + LSettings, h2psConnectionError, 0,
    H2_ERR_PROTOCOL_ERROR, 'initial SETTINGS stream id');
end;

procedure TestRunHandshakeAndSimpleRequestResponse;
var
  LHandler: TCollectingHandler;
  LHandlerRef: IHttpHandler;
  LStream: TFakeTcpStream;
  LConnRef: ITcpStream;
  LSession: TH2ServerSession;
  LWire: AnsiString;
  LFrames: array[0..7] of TH2Frame;
  LFrameCount: SizeInt;
begin
  LHandler := TCollectingHandler.Create;
  LHandlerRef := LHandler as IHttpHandler;
  try
    LHandler.SetResponse(HTTP_STATUS_OK, 'world');
    LHandler.AddResponseHeader('content-type', 'text/plain');
    LWire := ComposePrefaceHandshake +
      H2EncodeFrame(H2_FRAME_HEADERS,
        H2_FLAG_HEADERS_END_HEADERS or H2_FLAG_HEADERS_END_STREAM, 1,
        ComposeRequestHeaders('GET', '/hello'));
    LStream := TFakeTcpStream.Create(LWire);
    LConnRef := LStream as ITcpStream;
    try
      LSession := TH2ServerSession.Create(LStream, LHandler,
        TH2ServerTransportOptions.Default);
      try
        CheckEqual(Int64(TCP_SERVER_CONN_OWNERSHIP_SERVER), Int64(LSession.Run),
          'Run returns server ownership');
      finally
        LSession.Free;
      end;
      CheckEqual(Int64(1), Int64(LHandler.CallCount), 'handler called once');
      CheckEqual(Int64(Ord(hmGet)), Int64(Ord(LHandler.SeenMethod)),
        'handler sees method');
      CheckEqual('/hello', LHandler.SeenPath, 'handler sees path');
      CheckEqual('', LHandler.SeenBody, 'handler sees empty body');

      DecodeFrames(LStream.WrittenData, LFrames, LFrameCount);
      CheckEqual(Int64(4), Int64(LFrameCount), 'server writes handshake + response frames');
      CheckEqual(Int64(H2_FRAME_SETTINGS), Int64(LFrames[0].Header.FrameType),
        'first frame is server SETTINGS');
      CheckEqual(Int64(H2_FRAME_SETTINGS), Int64(LFrames[1].Header.FrameType),
        'second frame is SETTINGS ACK');
      CheckEqual(Int64(H2_FRAME_HEADERS), Int64(LFrames[2].Header.FrameType),
        'third frame is response HEADERS');
      CheckEqual('200', ExtractStatusHeader(LFrames[2].Payload),
        'response status encoded');
      CheckEqual(Int64(H2_FRAME_DATA), Int64(LFrames[3].Header.FrameType),
        'fourth frame is DATA');
      CheckEqual('world', string(LFrames[3].Payload), 'response body encoded');
      Check((LFrames[3].Header.Flags and H2_FLAG_DATA_END_STREAM) <> 0,
        'response DATA ends stream');
    finally
      LConnRef := nil;
      LStream := nil;
    end;
  finally
    LHandlerRef := nil;
    LHandler := nil;
  end;
end;

procedure TestRunHandshakeAdvertisesMaxHeaderListSizeSetting;
var
  LHandler: TCollectingHandler;
  LHandlerRef: IHttpHandler;
  LOptions: TH2ServerTransportOptions;
  LStream: TFakeTcpStream;
  LConnRef: ITcpStream;
  LSession: TH2ServerSession;
  LWire: AnsiString;
  LFrames: array[0..7] of TH2Frame;
  LFrameCount: SizeInt;
  LSettingValue: UInt32;
begin
  LHandler := TCollectingHandler.Create;
  LHandlerRef := LHandler as IHttpHandler;
  try
    LHandler.SetResponse(HTTP_STATUS_OK, '');
    LOptions := TH2ServerTransportOptions.Default;
    LOptions.MaxHeaderListSize := 512;
    LWire := ComposePrefaceHandshake +
      H2EncodeFrame(H2_FRAME_HEADERS,
        H2_FLAG_HEADERS_END_HEADERS or H2_FLAG_HEADERS_END_STREAM, 1,
        ComposeRequestHeaders('GET', '/settings'));
    LStream := TFakeTcpStream.Create(LWire);
    LConnRef := LStream as ITcpStream;
    try
      LSession := TH2ServerSession.Create(LStream, LHandler, LOptions);
      try
        LSession.Run;
      finally
        LSession.Free;
      end;

      DecodeFrames(LStream.WrittenData, LFrames, LFrameCount);
      CheckEqual(Int64(H2_FRAME_SETTINGS), Int64(LFrames[0].Header.FrameType),
        'server handshake begins with SETTINGS');
      Check(FindSettingsValue(LFrames[0].Payload, H2_SETTINGS_MAX_HEADER_LIST_SIZE,
        LSettingValue), 'server SETTINGS advertises MAX_HEADER_LIST_SIZE');
      CheckEqual(Int64(512), Int64(LSettingValue),
        'server SETTINGS uses configured MAX_HEADER_LIST_SIZE');
    finally
      LConnRef := nil;
      LStream := nil;
    end;
  finally
    LHandlerRef := nil;
    LHandler := nil;
  end;
end;

procedure TestRunSettingsAckFromClientIsSilentlyAccepted;
var
  LHandler: TCollectingHandler;
  LHandlerRef: IHttpHandler;
  LStream: TFakeTcpStream;
  LConnRef: ITcpStream;
  LSession: TH2ServerSession;
  LWire: AnsiString;
  LFrames: array[0..7] of TH2Frame;
  LFrameCount: SizeInt;
  LErrorCode: UInt32;
begin
  LHandler := TCollectingHandler.Create;
  LHandlerRef := LHandler as IHttpHandler;
  try
    LHandler.SetResponse(HTTP_STATUS_OK, '');
    LWire := ComposePrefaceHandshake +
      H2EncodeFrame(H2_FRAME_SETTINGS, H2_FLAG_SETTINGS_ACK, 0, '') +
      H2EncodeFrame(H2_FRAME_HEADERS,
        H2_FLAG_HEADERS_END_HEADERS or H2_FLAG_HEADERS_END_STREAM, 1,
        ComposeRequestHeaders('GET', '/settings-ack'));
    LStream := TFakeTcpStream.Create(LWire);
    LConnRef := LStream as ITcpStream;
    try
      LSession := TH2ServerSession.Create(LStream, LHandler,
        TH2ServerTransportOptions.Default);
      try
        LSession.Run;
      finally
        LSession.Free;
      end;
      CheckEqual(Int64(1), Int64(LHandler.CallCount),
        'client SETTINGS ACK does not block request handling');
      DecodeFrames(LStream.WrittenData, LFrames, LFrameCount);
      CheckEqual(Int64(3), Int64(LFrameCount),
        'server writes handshake and header-only response');
      Check(not FindGoawayError(LFrames, LFrameCount, LErrorCode),
        'client SETTINGS ACK does not trigger GOAWAY');
    finally
      LConnRef := nil;
      LStream := nil;
    end;
  finally
    LHandlerRef := nil;
    LHandler := nil;
  end;
end;

procedure TestRunMaxConcurrentStreamsExceededSendsRefusedStream;
var
  LHandler: TCollectingHandler;
  LHandlerRef: IHttpHandler;
  LOptions: TH2ServerTransportOptions;
  LStream: TFakeTcpStream;
  LConnRef: ITcpStream;
  LSession: TH2ServerSession;
  LWire: AnsiString;
  LFrames: array[0..9] of TH2Frame;
  LFrameCount: SizeInt;
  LErrorCode: UInt32;
begin
  LHandler := TCollectingHandler.Create;
  LHandlerRef := LHandler as IHttpHandler;
  try
    LHandler.SetResponse(HTTP_STATUS_NO_CONTENT, '');
    LOptions := TH2ServerTransportOptions.Default;
    LOptions.MaxConcurrentStreams := 1;
    LWire := ComposePrefaceHandshake +
      H2EncodeFrame(H2_FRAME_HEADERS, H2_FLAG_HEADERS_END_HEADERS, 1,
        ComposeRequestHeaders('POST', '/stream-one')) +
      H2EncodeFrame(H2_FRAME_HEADERS,
        H2_FLAG_HEADERS_END_HEADERS or H2_FLAG_HEADERS_END_STREAM, 3,
        ComposeRequestHeaders('GET', '/stream-three')) +
      H2EncodeFrame(H2_FRAME_DATA, H2_FLAG_DATA_END_STREAM, 1, '');
    LStream := TFakeTcpStream.Create(LWire);
    LConnRef := LStream as ITcpStream;
    try
      LSession := TH2ServerSession.Create(LStream, LHandler, LOptions);
      try
        LSession.Run;
      finally
        LSession.Free;
      end;
      CheckEqual(Int64(1), Int64(LHandler.CallCount),
        'first stream still completes under MaxConcurrentStreams limit');
      CheckEqual('/stream-one', LHandler.SeenPath,
        'first stream reaches handler');

      DecodeFrames(LStream.WrittenData, LFrames, LFrameCount);
      Check(FindRstStreamError(LFrames, LFrameCount, 3, LErrorCode),
        'second concurrent stream receives RST_STREAM');
      CheckEqual(Int64(H2_ERR_REFUSED_STREAM), Int64(LErrorCode),
        'second concurrent stream uses REFUSED_STREAM');
      Check(not HasFrameType(LFrames, LFrameCount, H2_FRAME_GOAWAY),
        'concurrency refusal stays stream-scoped');
    finally
      LConnRef := nil;
      LStream := nil;
    end;
  finally
    LHandlerRef := nil;
    LHandler := nil;
  end;
end;

procedure TestRunPeerSettingsInitialWindowSizeUpdatesOpenStreams;
var
  LHandler: TCollectingHandler;
  LHandlerRef: IHttpHandler;
  LEntries: TH2SettingEntries;
  LStream: TFakeTcpStream;
  LConnRef: ITcpStream;
  LSession: TH2ServerSession;
  LWire: AnsiString;
  LFrames: array[0..11] of TH2Frame;
  LFrameCount: SizeInt;
begin
  LHandler := TCollectingHandler.Create;
  LHandlerRef := LHandler as IHttpHandler;
  try
    LHandler.SetResponse(HTTP_STATUS_OK, '0123456789AB');
    SetLength(LEntries, 1);
    LEntries[0].Identifier := H2_SETTINGS_INITIAL_WINDOW_SIZE;
    LEntries[0].Value := 10;
    LWire := ComposePrefaceHandshake +
      H2EncodeFrame(H2_FRAME_HEADERS, H2_FLAG_HEADERS_END_HEADERS, 1,
        ComposeRequestHeaders('POST', '/peer-window')) +
      H2EncodeFrame(H2_FRAME_SETTINGS, 0, 0, H2EncodeSettingsPayload(LEntries)) +
      H2EncodeFrame(H2_FRAME_DATA, H2_FLAG_DATA_END_STREAM, 1, 'x');
    LStream := TFakeTcpStream.Create(LWire);
    LConnRef := LStream as ITcpStream;
    try
      LSession := TH2ServerSession.Create(LStream, LHandler,
        TH2ServerTransportOptions.Default);
      try
        LSession.Run;
      finally
        LSession.Free;
      end;
      CheckEqual(Int64(1), Int64(LHandler.CallCount),
        'request with open stream still reaches handler after peer SETTINGS');
      CheckEqual('x', LHandler.SeenBody, 'handler sees request body');

      DecodeFrames(LStream.WrittenData, LFrames, LFrameCount);
      CheckEqual(Int64(H2_FRAME_SETTINGS), Int64(LFrames[2].Header.FrameType),
        'peer SETTINGS is acknowledged');
      Check((LFrames[2].Header.Flags and H2_FLAG_SETTINGS_ACK) <> 0,
        'peer SETTINGS emits ACK frame');
      CheckEqual(Int64(H2_FRAME_DATA), Int64(LFrames[4].Header.FrameType),
        'response body frame is emitted after peer SETTINGS');
      CheckEqual('0123456789', string(LFrames[4].Payload),
        'peer INITIAL_WINDOW_SIZE updates open stream send capacity');
      Check((LFrames[4].Header.Flags and H2_FLAG_DATA_END_STREAM) = 0,
        'reduced send window keeps remaining response bytes pending');
    finally
      LConnRef := nil;
      LStream := nil;
    end;
  finally
    LHandlerRef := nil;
    LHandler := nil;
  end;
end;

procedure TestRunInvalidSettingsIdentifierIsIgnored;
var
  LHandler: TCollectingHandler;
  LHandlerRef: IHttpHandler;
  LEntries: TH2SettingEntries;
  LStream: TFakeTcpStream;
  LConnRef: ITcpStream;
  LSession: TH2ServerSession;
  LWire: AnsiString;
  LFrames: array[0..7] of TH2Frame;
  LFrameCount: SizeInt;
  LErrorCode: UInt32;
begin
  LHandler := TCollectingHandler.Create;
  LHandlerRef := LHandler as IHttpHandler;
  try
    LHandler.SetResponse(HTTP_STATUS_OK, '');
    SetLength(LEntries, 1);
    LEntries[0].Identifier := $FFFF;
    LEntries[0].Value := 42;
    LWire := ComposePrefaceHandshake +
      H2EncodeFrame(H2_FRAME_SETTINGS, 0, 0, H2EncodeSettingsPayload(LEntries)) +
      H2EncodeFrame(H2_FRAME_HEADERS,
        H2_FLAG_HEADERS_END_HEADERS or H2_FLAG_HEADERS_END_STREAM, 1,
        ComposeRequestHeaders('GET', '/unknown-setting'));
    LStream := TFakeTcpStream.Create(LWire);
    LConnRef := LStream as ITcpStream;
    try
      LSession := TH2ServerSession.Create(LStream, LHandler,
        TH2ServerTransportOptions.Default);
      try
        LSession.Run;
      finally
        LSession.Free;
      end;
      CheckEqual(Int64(1), Int64(LHandler.CallCount),
        'unknown SETTINGS identifier does not block request handling');
      DecodeFrames(LStream.WrittenData, LFrames, LFrameCount);
      Check(not FindGoawayError(LFrames, LFrameCount, LErrorCode),
        'unknown SETTINGS identifier does not trigger GOAWAY');
      CheckEqual(Int64(H2_FRAME_SETTINGS), Int64(LFrames[2].Header.FrameType),
        'unknown SETTINGS still receives ACK');
      Check((LFrames[2].Header.Flags and H2_FLAG_SETTINGS_ACK) <> 0,
        'unknown SETTINGS ACK flag is set');
    finally
      LConnRef := nil;
      LStream := nil;
    end;
  finally
    LHandlerRef := nil;
    LHandler := nil;
  end;
end;

procedure TestRunSettingsEnablePushGreaterThanOneIsProtocolError;
var
  LHandler: TCollectingHandler;
  LHandlerRef: IHttpHandler;
  LEntries: TH2SettingEntries;
  LStream: TFakeTcpStream;
  LConnRef: ITcpStream;
  LSession: TH2ServerSession;
  LWire: AnsiString;
  LFrames: array[0..7] of TH2Frame;
  LFrameCount: SizeInt;
  LErrorCode: UInt32;
begin
  LHandler := TCollectingHandler.Create;
  LHandlerRef := LHandler as IHttpHandler;
  try
    SetLength(LEntries, 1);
    LEntries[0].Identifier := H2_SETTINGS_ENABLE_PUSH;
    LEntries[0].Value := 2;
    LWire := ComposePrefaceHandshake +
      H2EncodeFrame(H2_FRAME_SETTINGS, 0, 0, H2EncodeSettingsPayload(LEntries));
    LStream := TFakeTcpStream.Create(LWire);
    LConnRef := LStream as ITcpStream;
    try
      LSession := TH2ServerSession.Create(LStream, LHandler,
        TH2ServerTransportOptions.Default);
      try
        LSession.Run;
      finally
        LSession.Free;
      end;
      DecodeFrames(LStream.WrittenData, LFrames, LFrameCount);
      Check(FindGoawayError(LFrames, LFrameCount, LErrorCode),
        'invalid ENABLE_PUSH triggers GOAWAY');
      CheckEqual(Int64(H2_ERR_PROTOCOL_ERROR), Int64(LErrorCode),
        'invalid ENABLE_PUSH uses PROTOCOL_ERROR');
    finally
      LConnRef := nil;
      LStream := nil;
    end;
  finally
    LHandlerRef := nil;
    LHandler := nil;
  end;
end;

procedure CheckMalformedRequestResetsStream(
  const AHeaders: array of THPackHeader; const AMessage: string);
var
  LHandler: TCollectingHandler;
  LHandlerRef: IHttpHandler;
  LStream: TFakeTcpStream;
  LConnRef: ITcpStream;
  LSession: TH2ServerSession;
  LWire: AnsiString;
  LFrames: array[0..7] of TH2Frame;
  LFrameCount: SizeInt;
  LErrorCode: UInt32;
begin
  LHandler := TCollectingHandler.Create;
  LHandlerRef := LHandler as IHttpHandler;
  try
    LWire := ComposePrefaceHandshake +
      H2EncodeFrame(H2_FRAME_HEADERS,
        H2_FLAG_HEADERS_END_HEADERS or H2_FLAG_HEADERS_END_STREAM, 1,
        EncodeHeaders(AHeaders));
    LStream := TFakeTcpStream.Create(LWire);
    LConnRef := LStream as ITcpStream;
    try
      LSession := TH2ServerSession.Create(LStream, LHandler,
        TH2ServerTransportOptions.Default);
      try
        LSession.Run;
      finally
        LSession.Free;
      end;
      CheckEqual(Int64(0), Int64(LHandler.CallCount),
        AMessage + ' does not reach handler');
      DecodeFrames(LStream.WrittenData, LFrames, LFrameCount);
      Check(FindRstStreamError(LFrames, LFrameCount, 1, LErrorCode),
        AMessage + ' emits RST_STREAM');
      CheckEqual(Int64(H2_ERR_PROTOCOL_ERROR), Int64(LErrorCode),
        AMessage + ' uses PROTOCOL_ERROR');
      Check(not HasFrameType(LFrames, LFrameCount, H2_FRAME_GOAWAY),
        AMessage + ' stays stream scoped');
    finally
      LConnRef := nil;
      LStream := nil;
    end;
  finally
    LHandlerRef := nil;
    LHandler := nil;
  end;
end;

procedure TestRunMissingPathPseudoHeaderResetsStream;
var
  LHeaders: array[0..2] of THPackHeader;
begin
  LHeaders[0].Name := ':method';
  LHeaders[0].Value := 'GET';
  LHeaders[1].Name := ':scheme';
  LHeaders[1].Value := 'https';
  LHeaders[2].Name := ':authority';
  LHeaders[2].Value := 'example.com';
  CheckMalformedRequestResetsStream(LHeaders, 'missing :path');
end;

procedure TestRunMissingAuthorityAndHostResetsStream;
var
  LHeaders: array[0..2] of THPackHeader;
begin
  LHeaders[0].Name := ':method';
  LHeaders[0].Value := 'GET';
  LHeaders[1].Name := ':scheme';
  LHeaders[1].Value := 'https';
  LHeaders[2].Name := ':path';
  LHeaders[2].Value := '/no-authority';
  CheckMalformedRequestResetsStream(LHeaders, 'missing :authority and host');
end;

procedure TestRunPseudoHeaderAfterRegularHeaderResetsStream;
var
  LHeaders: array[0..4] of THPackHeader;
begin
  LHeaders[0].Name := ':method';
  LHeaders[0].Value := 'GET';
  LHeaders[1].Name := 'x-before-pseudo';
  LHeaders[1].Value := '1';
  LHeaders[2].Name := ':scheme';
  LHeaders[2].Value := 'https';
  LHeaders[3].Name := ':authority';
  LHeaders[3].Value := 'example.com';
  LHeaders[4].Name := ':path';
  LHeaders[4].Value := '/late-pseudo';
  CheckMalformedRequestResetsStream(LHeaders, 'pseudo header after regular header');
end;

procedure TestRunDuplicatePseudoHeaderResetsStream;
var
  LHeaders: array[0..4] of THPackHeader;
begin
  LHeaders[0].Name := ':method';
  LHeaders[0].Value := 'GET';
  LHeaders[1].Name := ':method';
  LHeaders[1].Value := 'POST';
  LHeaders[2].Name := ':scheme';
  LHeaders[2].Value := 'https';
  LHeaders[3].Name := ':authority';
  LHeaders[3].Value := 'example.com';
  LHeaders[4].Name := ':path';
  LHeaders[4].Value := '/duplicate-method';
  CheckMalformedRequestResetsStream(LHeaders, 'duplicate pseudo header');
end;

procedure TestRunConnectionSpecificHeaderResetsStream;
var
  LHeaders: array[0..4] of THPackHeader;
begin
  LHeaders[0].Name := ':method';
  LHeaders[0].Value := 'GET';
  LHeaders[1].Name := ':scheme';
  LHeaders[1].Value := 'https';
  LHeaders[2].Name := ':authority';
  LHeaders[2].Value := 'example.com';
  LHeaders[3].Name := ':path';
  LHeaders[3].Value := '/forbidden-connection';
  LHeaders[4].Name := 'connection';
  LHeaders[4].Value := 'close';
  CheckMalformedRequestResetsStream(LHeaders, 'connection header');
end;

procedure TestRunNonTrailersTeHeaderResetsStream;
var
  LHeaders: array[0..4] of THPackHeader;
begin
  LHeaders[0].Name := ':method';
  LHeaders[0].Value := 'GET';
  LHeaders[1].Name := ':scheme';
  LHeaders[1].Value := 'https';
  LHeaders[2].Name := ':authority';
  LHeaders[2].Value := 'example.com';
  LHeaders[3].Name := ':path';
  LHeaders[3].Value := '/forbidden-te';
  LHeaders[4].Name := 'te';
  LHeaders[4].Value := 'gzip';
  CheckMalformedRequestResetsStream(LHeaders, 'non-trailers TE header');
end;

procedure TestRunDataEndStreamTriggersHandlerAndFlowControlUpdate;
var
  LHandler: TCollectingHandler;
  LHandlerRef: IHttpHandler;
  LOptions: TH2ServerTransportOptions;
  LStream: TFakeTcpStream;
  LConnRef: ITcpStream;
  LSession: TH2ServerSession;
  LWire: AnsiString;
  LFrames: array[0..9] of TH2Frame;
  LFrameCount: SizeInt;
  LWindowUpdateCount: SizeInt;
  LI: SizeInt;
begin
  LHandler := TCollectingHandler.Create;
  LHandlerRef := LHandler as IHttpHandler;
  try
    LHandler.SetResponse(HTTP_STATUS_CREATED, '');
    LOptions := TH2ServerTransportOptions.Default;
    LOptions.InitialStreamWindowSize := 4;
    LOptions.InitialConnectionWindowSize := 4;
    LWire := ComposePrefaceHandshake +
      H2EncodeFrame(H2_FRAME_HEADERS, H2_FLAG_HEADERS_END_HEADERS, 1,
        ComposeRequestHeaders('POST', '/upload')) +
      H2EncodeFrame(H2_FRAME_DATA, H2_FLAG_DATA_END_STREAM, 1, 'ABCD');
    LStream := TFakeTcpStream.Create(LWire);
    LConnRef := LStream as ITcpStream;
    try
      LSession := TH2ServerSession.Create(LStream, LHandler, LOptions);
      try
        LSession.Run;
      finally
        LSession.Free;
      end;
      CheckEqual(Int64(1), Int64(LHandler.CallCount), 'handler called for POST');
      CheckEqual('ABCD', LHandler.SeenBody, 'handler sees full request body');

      DecodeFrames(LStream.WrittenData, LFrames, LFrameCount);
      CheckEqual(Int64(H2_FRAME_HEADERS), Int64(LFrames[2].Header.FrameType),
        'server responds after request completion');
      Check((LFrames[2].Header.Flags and H2_FLAG_HEADERS_END_STREAM) <> 0,
        'header-only response ends stream');
      LWindowUpdateCount := 0;
      for LI := 0 to LFrameCount - 1 do
        if LFrames[LI].Header.FrameType = H2_FRAME_WINDOW_UPDATE then
          Inc(LWindowUpdateCount);
      CheckEqual(Int64(2), Int64(LWindowUpdateCount),
        'server emits stream and connection WINDOW_UPDATE frames');
    finally
      LConnRef := nil;
      LStream := nil;
    end;
  finally
    LHandlerRef := nil;
    LHandler := nil;
  end;
end;

procedure TestRunDataOverMaxBodySizeReturns413WithoutHandler;
var
  LHandler: TCollectingHandler;
  LHandlerRef: IHttpHandler;
  LOptions: TH2ServerTransportOptions;
  LStream: TFakeTcpStream;
  LConnRef: ITcpStream;
  LSession: TH2ServerSession;
  LWire: AnsiString;
  LFrames: array[0..7] of TH2Frame;
  LFrameCount: SizeInt;
begin
  LHandler := TCollectingHandler.Create;
  LHandlerRef := LHandler as IHttpHandler;
  try
    LOptions := TH2ServerTransportOptions.Default;
    LOptions.MaxBodySize := 4;
    LWire := ComposePrefaceHandshake +
      H2EncodeFrame(H2_FRAME_HEADERS, H2_FLAG_HEADERS_END_HEADERS, 1,
        ComposeRequestHeaders('POST', '/too-large')) +
      H2EncodeFrame(H2_FRAME_DATA, H2_FLAG_DATA_END_STREAM, 1, 'ABCDE');
    LStream := TFakeTcpStream.Create(LWire);
    LConnRef := LStream as ITcpStream;
    try
      LSession := TH2ServerSession.Create(LStream, LHandler, LOptions);
      try
        LSession.Run;
      finally
        LSession.Free;
      end;

      CheckEqual(Int64(0), Int64(LHandler.CallCount),
        'oversize H2 request body does not reach handler');
      DecodeFrames(LStream.WrittenData, LFrames, LFrameCount);
      CheckEqual(Int64(5), Int64(LFrameCount),
        'oversize H2 request writes handshake, 413 response, and window updates');
      CheckEqual(Int64(H2_FRAME_HEADERS), Int64(LFrames[2].Header.FrameType),
        'oversize H2 request responds with HEADERS');
      CheckEqual('413', ExtractStatusHeader(LFrames[2].Payload),
        'oversize H2 request responds with 413 status');
      Check((LFrames[2].Header.Flags and H2_FLAG_HEADERS_END_STREAM) <> 0,
        'oversize H2 request ends stream in 413 response');
      CheckEqual(Int64(H2_FRAME_WINDOW_UPDATE), Int64(LFrames[3].Header.FrameType),
        'oversize H2 request restores stream receive window');
      CheckEqual(Int64(H2_FRAME_WINDOW_UPDATE), Int64(LFrames[4].Header.FrameType),
        'oversize H2 request restores connection receive window');
    finally
      LConnRef := nil;
      LStream := nil;
    end;
  finally
    LHandlerRef := nil;
    LHandler := nil;
  end;
end;

procedure TestRunHeadersOverMaxHeaderListSizeReturns431WithoutHandler;
var
  LHandler: TCollectingHandler;
  LHandlerRef: IHttpHandler;
  LOptions: TH2ServerTransportOptions;
  LStream: TFakeTcpStream;
  LConnRef: ITcpStream;
  LSession: TH2ServerSession;
  LWire: AnsiString;
  LFrames: array[0..7] of TH2Frame;
  LFrameCount: SizeInt;
  LErrorCode: UInt32;
begin
  LHandler := TCollectingHandler.Create;
  LHandlerRef := LHandler as IHttpHandler;
  try
    LOptions := TH2ServerTransportOptions.Default;
    LOptions.MaxHeaderListSize := 128;
    LWire := ComposePrefaceHandshake +
      H2EncodeFrame(H2_FRAME_HEADERS,
        H2_FLAG_HEADERS_END_HEADERS or H2_FLAG_HEADERS_END_STREAM, 1,
        ComposeRequestHeaders('GET', '/too-many-headers'));
    LStream := TFakeTcpStream.Create(LWire);
    LConnRef := LStream as ITcpStream;
    try
      LSession := TH2ServerSession.Create(LStream, LHandler, LOptions);
      try
        LSession.Run;
      finally
        LSession.Free;
      end;

      CheckEqual(Int64(0), Int64(LHandler.CallCount),
        'oversize H2 request headers do not reach handler');
      DecodeFrames(LStream.WrittenData, LFrames, LFrameCount);
      CheckEqual(Int64(H2_FRAME_HEADERS), Int64(LFrames[2].Header.FrameType),
        'oversize H2 request headers respond with HEADERS');
      CheckEqual('431', ExtractStatusHeader(LFrames[2].Payload),
        'oversize H2 request headers respond with 431 status');
      Check((LFrames[2].Header.Flags and H2_FLAG_HEADERS_END_STREAM) <> 0,
        'oversize H2 request headers end stream in 431 response');
      Check(not FindRstStreamError(LFrames, LFrameCount, 1, LErrorCode),
        'oversize H2 request headers do not emit RST_STREAM');
    finally
      LConnRef := nil;
      LStream := nil;
    end;
  finally
    LHandlerRef := nil;
    LHandler := nil;
  end;
end;

procedure TestRunPingGetsAcked;
var
  LHandler: TCollectingHandler;
  LHandlerRef: IHttpHandler;
  LStream: TFakeTcpStream;
  LConnRef: ITcpStream;
  LSession: TH2ServerSession;
  LWire: AnsiString;
  LFrames: array[0..3] of TH2Frame;
  LFrameCount: SizeInt;
  LPingData: UInt64;
begin
  LHandler := TCollectingHandler.Create;
  LHandlerRef := LHandler as IHttpHandler;
  try
    LWire := ComposePrefaceHandshake +
      H2EncodeFrame(H2_FRAME_PING, 0, 0, HexToBytes('0102030405060708'));
    LStream := TFakeTcpStream.Create(LWire);
    LConnRef := LStream as ITcpStream;
    try
      LSession := TH2ServerSession.Create(LStream, LHandler,
        TH2ServerTransportOptions.Default);
      try
        LSession.Run;
      finally
        LSession.Free;
      end;
      DecodeFrames(LStream.WrittenData, LFrames, LFrameCount);
      CheckEqual(Int64(3), Int64(LFrameCount), 'server writes handshake plus ping ack');
      CheckEqual(Int64(H2_FRAME_PING), Int64(LFrames[2].Header.FrameType),
        'server writes PING ack');
      Check((LFrames[2].Header.Flags and H2_FLAG_PING_ACK) <> 0,
        'ping ack flag set');
      Check(H2DecodePing(LFrames[2].Payload, LPingData), 'ack payload decodes');
      CheckEqual(Int64($0102030405060708), Int64(LPingData), 'ack echoes opaque data');
    finally
      LConnRef := nil;
      LStream := nil;
    end;
  finally
    LHandlerRef := nil;
    LHandler := nil;
  end;
end;

procedure TestRunRstStreamCancelsPendingRequest;
var
  LHandler: TCollectingHandler;
  LHandlerRef: IHttpHandler;
  LStream: TFakeTcpStream;
  LConnRef: ITcpStream;
  LSession: TH2ServerSession;
  LWire: AnsiString;
begin
  LHandler := TCollectingHandler.Create;
  LHandlerRef := LHandler as IHttpHandler;
  try
    LWire := ComposePrefaceHandshake +
      H2EncodeFrame(H2_FRAME_HEADERS, H2_FLAG_HEADERS_END_HEADERS, 1,
        ComposeRequestHeaders('POST', '/cancel')) +
      H2EncodeFrame(H2_FRAME_RST_STREAM, 0, 1, H2EncodeRstStream(H2_ERR_CANCEL));
    LStream := TFakeTcpStream.Create(LWire);
    LConnRef := LStream as ITcpStream;
    try
      LSession := TH2ServerSession.Create(LStream, LHandler,
        TH2ServerTransportOptions.Default);
      try
        LSession.Run;
      finally
        LSession.Free;
      end;
      CheckEqual(Int64(0), Int64(LHandler.CallCount),
        'RST_STREAM before END_STREAM prevents handler execution');
    finally
      LConnRef := nil;
      LStream := nil;
    end;
  finally
    LHandlerRef := nil;
    LHandler := nil;
  end;
end;

procedure TestRunGoawayStopsNewStreams;
var
  LHandler: TCollectingHandler;
  LHandlerRef: IHttpHandler;
  LStream: TFakeTcpStream;
  LConnRef: ITcpStream;
  LSession: TH2ServerSession;
  LWire: AnsiString;
begin
  LHandler := TCollectingHandler.Create;
  LHandlerRef := LHandler as IHttpHandler;
  try
    LWire := ComposePrefaceHandshake +
      H2EncodeFrame(H2_FRAME_GOAWAY, 0, 0,
        H2EncodeGoaway(0, H2_ERR_NO_ERROR, '')) +
      H2EncodeFrame(H2_FRAME_HEADERS,
        H2_FLAG_HEADERS_END_HEADERS or H2_FLAG_HEADERS_END_STREAM, 1,
        ComposeRequestHeaders('GET', '/late'));
    LStream := TFakeTcpStream.Create(LWire);
    LConnRef := LStream as ITcpStream;
    try
      LSession := TH2ServerSession.Create(LStream, LHandler,
        TH2ServerTransportOptions.Default);
      try
        LSession.Run;
      finally
        LSession.Free;
      end;
      CheckEqual(Int64(0), Int64(LHandler.CallCount),
        'GOAWAY stops accepting new requests');
    finally
      LConnRef := nil;
      LStream := nil;
    end;
  finally
    LHandlerRef := nil;
    LHandler := nil;
  end;
end;

procedure TestRunGoawayRejectsNonZeroLastStreamIDWithoutLocalStreams;
var
  LHandler: TCollectingHandler;
  LHandlerRef: IHttpHandler;
  LStream: TFakeTcpStream;
  LConnRef: ITcpStream;
  LSession: TH2ServerSession;
  LWire: AnsiString;
  LFrames: array[0..5] of TH2Frame;
  LFrameCount: SizeInt;
  LLastStreamID: UInt32;
  LErrorCode: UInt32;
begin
  LHandler := TCollectingHandler.Create;
  LHandlerRef := LHandler as IHttpHandler;
  try
    LWire := ComposePrefaceHandshake +
      H2EncodeFrame(H2_FRAME_GOAWAY, 0, 0,
        H2EncodeGoaway(2, H2_ERR_NO_ERROR, ''));
    LStream := TFakeTcpStream.Create(LWire);
    LConnRef := LStream as ITcpStream;
    try
      LSession := TH2ServerSession.Create(LStream, LHandler,
        TH2ServerTransportOptions.Default);
      try
        LSession.Run;
      finally
        LSession.Free;
      end;
      DecodeFrames(LStream.WrittenData, LFrames, LFrameCount);
      Check(FindGoawayDetails(LFrames, LFrameCount, LLastStreamID, LErrorCode),
        'server replies with GOAWAY for invalid peer GOAWAY');
      CheckEqual(Int64(0), Int64(LLastStreamID),
        'invalid peer GOAWAY preserves zero last seen peer stream id');
      CheckEqual(Int64(H2_ERR_PROTOCOL_ERROR), Int64(LErrorCode),
        'invalid peer GOAWAY maps to PROTOCOL_ERROR');
    finally
      LConnRef := nil;
      LStream := nil;
    end;
  finally
    LHandlerRef := nil;
    LHandler := nil;
  end;
end;

procedure TestRunPeerGoawayDoesNotOverwriteLastSeenPeerStreamID;
var
  LHandler: TCollectingHandler;
  LHandlerRef: IHttpHandler;
  LStream: TFakeTcpStream;
  LConnRef: ITcpStream;
  LSession: TH2ServerSession;
  LWire: AnsiString;
  LFrames: array[0..9] of TH2Frame;
  LFrameCount: SizeInt;
  LLastStreamID: UInt32;
  LErrorCode: UInt32;
begin
  LHandler := TCollectingHandler.Create;
  LHandlerRef := LHandler as IHttpHandler;
  try
    LHandler.SetResponse(HTTP_STATUS_OK, '');
    LWire := ComposePrefaceHandshake +
      H2EncodeFrame(H2_FRAME_HEADERS,
        H2_FLAG_HEADERS_END_HEADERS or H2_FLAG_HEADERS_END_STREAM, 1,
        ComposeRequestHeaders('GET', '/before-goaway')) +
      H2EncodeFrame(H2_FRAME_GOAWAY, 0, 0,
        H2EncodeGoaway(0, H2_ERR_NO_ERROR, '')) +
      H2EncodeFrame(H2_FRAME_PUSH_PROMISE, H2_FLAG_PUSH_PROMISE_END_HEADERS, 1,
        ComposePushPromisePayload(2));
    LStream := TFakeTcpStream.Create(LWire);
    LConnRef := LStream as ITcpStream;
    try
      LSession := TH2ServerSession.Create(LStream, LHandler,
        TH2ServerTransportOptions.Default);
      try
        LSession.Run;
      finally
        LSession.Free;
      end;
      DecodeFrames(LStream.WrittenData, LFrames, LFrameCount);
      Check(FindGoawayDetails(LFrames, LFrameCount, LLastStreamID, LErrorCode),
        'server emits GOAWAY after protocol error following peer GOAWAY');
      CheckEqual(Int64(1), Int64(LLastStreamID),
        'peer GOAWAY does not overwrite last seen peer stream id');
      CheckEqual(Int64(H2_ERR_PROTOCOL_ERROR), Int64(LErrorCode),
        'protocol error after peer GOAWAY still uses PROTOCOL_ERROR');
    finally
      LConnRef := nil;
      LStream := nil;
    end;
  finally
    LHandlerRef := nil;
    LHandler := nil;
  end;
end;

procedure TestAdvancePollsReadableThenWritable;
var
  LHandler: TCollectingHandler;
  LHandlerRef: IHttpHandler;
  LStream: TFakeTcpStream;
  LConnRef: ITcpStream;
  LSession: TH2ServerSession;
  LNextEvents: TPlatformPollEvents;
  LOwnership: TTcpServerConnOwnership;
  LResult: TTcpServerPollResult;
  LFrames: array[0..7] of TH2Frame;
  LFrameCount: SizeInt;
  LCurrentEvents: TPlatformPollEvents;
  LSteps: Int32;
  LReachedReadableIdle: Boolean;
begin
  LHandler := TCollectingHandler.Create;
  LHandlerRef := LHandler as IHttpHandler;
  try
    LHandler.SetResponse(HTTP_STATUS_OK, 'pong');
    LStream := TFakeTcpStream.Create(ComposePrefaceHandshake +
      H2EncodeFrame(H2_FRAME_HEADERS,
        H2_FLAG_HEADERS_END_HEADERS or H2_FLAG_HEADERS_END_STREAM, 1,
        ComposeRequestHeaders('GET', '/poll')));
    try
      LConnRef := LStream as ITcpStream;
      LStream.MaxWriteChunk := 5;
      LSession := TH2ServerSession.Create(LStream, LHandler,
        TH2ServerTransportOptions.Default);
      try
        CheckEqual(Int64(1), Int64(Ord(peReadable in LSession.PollEvents)),
          'poll starts readable');

        LResult := LSession.Advance([peReadable], LNextEvents, LOwnership);
        CheckEqual(Int64(Ord(tsprWait)), Int64(Ord(LResult)),
          'advance remains active after readable step');
        CheckEqual(Int64(TCP_SERVER_CONN_OWNERSHIP_SERVER), Int64(LOwnership),
          'advance preserves server ownership');
        Check(peWritable in LNextEvents, 'partial write moves poll to writable');

        LCurrentEvents := LNextEvents;
        LSteps := 0;
        LReachedReadableIdle := False;
        repeat
          LResult := LSession.Advance(LCurrentEvents, LNextEvents, LOwnership);
          Inc(LSteps);
          if (LResult = tsprWait) and (LNextEvents = [peReadable]) then
          begin
            LReachedReadableIdle := True;
            Break;
          end;
          if LResult = tsprDone then
            Break;
          LCurrentEvents := LNextEvents;
          Check(LCurrentEvents <> [], 'poll path keeps producing next events');
          Check(LSteps < 16, 'poll path converges');
        until False;
        Check(LReachedReadableIdle, 'poll path returns to readable idle after flush');
      finally
        LSession.Free;
      end;

      CheckEqual(Int64(1), Int64(LHandler.CallCount), 'poll path executes handler');
      DecodeFrames(LStream.WrittenData, LFrames, LFrameCount);
      CheckEqual(Int64(H2_FRAME_DATA), Int64(LFrames[LFrameCount - 1].Header.FrameType),
        'poll path eventually flushes DATA');
    finally
      LConnRef := nil;
      LStream := nil;
    end;
  finally
    LHandlerRef := nil;
    LHandler := nil;
  end;
end;

procedure TestRunUnknownExtensionFrameIsIgnored;
var
  LHandler: TCollectingHandler;
  LHandlerRef: IHttpHandler;
  LStream: TFakeTcpStream;
  LConnRef: ITcpStream;
  LSession: TH2ServerSession;
  LWire: AnsiString;
  LFrames: array[0..7] of TH2Frame;
  LFrameCount: SizeInt;
begin
  LHandler := TCollectingHandler.Create;
  LHandlerRef := LHandler as IHttpHandler;
  try
    LHandler.SetResponse(HTTP_STATUS_OK, '');
    LWire := ComposePrefaceHandshake +
      H2EncodeFrame($0A, 0, 0, 'ignored') +
      H2EncodeFrame(H2_FRAME_HEADERS,
        H2_FLAG_HEADERS_END_HEADERS or H2_FLAG_HEADERS_END_STREAM, 1,
        ComposeRequestHeaders('GET', '/ext'));
    LStream := TFakeTcpStream.Create(LWire);
    LConnRef := LStream as ITcpStream;
    try
      LSession := TH2ServerSession.Create(LStream, LHandler,
        TH2ServerTransportOptions.Default);
      try
        LSession.Run;
      finally
        LSession.Free;
      end;
      CheckEqual(Int64(1), Int64(LHandler.CallCount),
        'unknown extension frame does not stop request processing');
      DecodeFrames(LStream.WrittenData, LFrames, LFrameCount);
      CheckEqual(Int64(H2_FRAME_HEADERS), Int64(LFrames[LFrameCount - 1].Header.FrameType),
        'response still emitted after unknown frame');
      Check((LFrames[LFrameCount - 1].Header.Flags and H2_FLAG_HEADERS_END_STREAM) <> 0,
        'header-only response still ends stream');
    finally
      LConnRef := nil;
      LStream := nil;
    end;
  finally
    LHandlerRef := nil;
    LHandler := nil;
  end;
end;

procedure TestRunDataOnConnectionStreamSendsGoaway;
var
  LHandler: TCollectingHandler;
  LHandlerRef: IHttpHandler;
  LStream: TFakeTcpStream;
  LConnRef: ITcpStream;
  LSession: TH2ServerSession;
  LWire: AnsiString;
  LFrames: array[0..7] of TH2Frame;
  LFrameCount: SizeInt;
  LErrorCode: UInt32;
begin
  LHandler := TCollectingHandler.Create;
  LHandlerRef := LHandler as IHttpHandler;
  try
    LWire := ComposePrefaceHandshake +
      H2EncodeFrame(H2_FRAME_DATA, H2_FLAG_DATA_END_STREAM, 0, 'bad');
    LStream := TFakeTcpStream.Create(LWire);
    LConnRef := LStream as ITcpStream;
    try
      LSession := TH2ServerSession.Create(LStream, LHandler,
        TH2ServerTransportOptions.Default);
      try
        LSession.Run;
      finally
        LSession.Free;
      end;
      CheckEqual(Int64(0), Int64(LHandler.CallCount),
        'DATA on connection stream does not reach handler');
      DecodeFrames(LStream.WrittenData, LFrames, LFrameCount);
      Check(FindGoawayError(LFrames, LFrameCount, LErrorCode),
        'server writes GOAWAY for DATA on stream 0');
      CheckEqual(Int64(H2_ERR_PROTOCOL_ERROR), Int64(LErrorCode),
        'DATA stream 0 GOAWAY uses PROTOCOL_ERROR');
      Check(not HasFrameType(LFrames, LFrameCount, H2_FRAME_RST_STREAM),
        'DATA on stream 0 does not emit RST_STREAM');
    finally
      LConnRef := nil;
      LStream := nil;
    end;
  finally
    LHandlerRef := nil;
    LHandler := nil;
  end;
end;

procedure TestRunDataOnClosedStreamRestoresConnectionWindow;
var
  LHandler: TCollectingHandler;
  LHandlerRef: IHttpHandler;
  LStream: TFakeTcpStream;
  LConnRef: ITcpStream;
  LSession: TH2ServerSession;
  LWire: AnsiString;
  LFrames: array[0..9] of TH2Frame;
  LFrameCount: SizeInt;
  LRstCode: UInt32;
  LWindowIncrement: UInt32;
  LFoundRst: Boolean;
  LFoundConnectionWindowUpdateAfterRst: Boolean;
  LI: SizeInt;
begin
  LHandler := TCollectingHandler.Create;
  LHandlerRef := LHandler as IHttpHandler;
  try
    LHandler.SetResponse(HTTP_STATUS_OK, '');
    LWire := ComposePrefaceHandshake +
      H2EncodeFrame(H2_FRAME_HEADERS,
        H2_FLAG_HEADERS_END_HEADERS or H2_FLAG_HEADERS_END_STREAM, 1,
        ComposeRequestHeaders('GET', '/closed')) +
      H2EncodeFrame(H2_FRAME_DATA, H2_FLAG_DATA_END_STREAM, 1, 'xy');
    LStream := TFakeTcpStream.Create(LWire);
    LConnRef := LStream as ITcpStream;
    try
      LSession := TH2ServerSession.Create(LStream, LHandler,
        TH2ServerTransportOptions.Default);
      try
        LSession.Run;
      finally
        LSession.Free;
      end;
      CheckEqual(Int64(1), Int64(LHandler.CallCount),
        'initial request reaches handler before stream is closed');
      DecodeFrames(LStream.WrittenData, LFrames, LFrameCount);
      LFoundRst := False;
      LFoundConnectionWindowUpdateAfterRst := False;
      for LI := 0 to LFrameCount - 1 do
      begin
        if (LFrames[LI].Header.FrameType = H2_FRAME_RST_STREAM) and
           (LFrames[LI].Header.StreamID = 1) then
        begin
          Check(H2DecodeRstStream(LFrames[LI].Payload, LRstCode),
            'RST_STREAM payload decodes');
          CheckEqual(Int64(H2_ERR_STREAM_CLOSED), Int64(LRstCode),
            'closed stream DATA receives STREAM_CLOSED');
          LFoundRst := True;
        end
        else if LFoundRst and
          (LFrames[LI].Header.FrameType = H2_FRAME_WINDOW_UPDATE) and
          (LFrames[LI].Header.StreamID = 0) then
        begin
          Check(H2DecodeWindowUpdate(LFrames[LI].Payload, LWindowIncrement),
            'connection WINDOW_UPDATE payload decodes');
          CheckEqual(Int64(2), Int64(LWindowIncrement),
            'connection WINDOW_UPDATE restores closed-stream DATA bytes');
          LFoundConnectionWindowUpdateAfterRst := True;
        end;
      end;
      Check(LFoundRst, 'closed stream DATA emits RST_STREAM');
      Check(LFoundConnectionWindowUpdateAfterRst,
        'closed stream DATA still emits connection WINDOW_UPDATE');
    finally
      LConnRef := nil;
      LStream := nil;
    end;
  finally
    LHandlerRef := nil;
    LHandler := nil;
  end;
end;

procedure TestHandleDataConnectionStreamSourceContract;
var
  LSource: string;
  LHandleDataPos: SizeInt;
  LHandleDataBlock: string;
begin
  LSource := ReadSourceFile(ResolveSourcePath(H2_SESSION_SOURCE_PATH_FROM_TEST,
    H2_SESSION_SOURCE_PATH_FROM_ROOT));
  LHandleDataPos := Pos('function TH2ServerSession.HandleData', LSource);
  Check(LHandleDataPos > 0, 'HandleData implementation is present');
  LHandleDataBlock := Copy(LSource, LHandleDataPos, 700);
  Check(Pos('AFrame.Header.StreamID = 0', LHandleDataBlock) > 0,
    'HandleData explicitly checks DATA on connection stream');
  Check(Pos('RejectFrame(0, H2_ERR_PROTOCOL_ERROR, True)', LHandleDataBlock) > 0,
    'HandleData maps DATA stream 0 to connection-level PROTOCOL_ERROR');
end;

procedure TestHandleGoawayUsesSeparatePeerAndLocalStreamTrackingSourceContract;
var
  LSource: string;
  LHandleGoawayPos: SizeInt;
  LHandleGoawayBlock: string;
begin
  LSource := ReadSourceFile(ResolveSourcePath(H2_SESSION_SOURCE_PATH_FROM_TEST,
    H2_SESSION_SOURCE_PATH_FROM_ROOT));
  Check(Pos('FLastSeenPeerStreamID: UInt32;', LSource) > 0,
    'session tracks last seen peer stream id separately');
  Check(Pos('FPeerGoawayLastLocalStreamID: UInt32;', LSource) > 0,
    'session tracks peer GOAWAY last local stream id separately');
  LHandleGoawayPos := Pos('function TH2ServerSession.HandleGoaway', LSource);
  Check(LHandleGoawayPos > 0, 'HandleGoaway implementation is present');
  LHandleGoawayBlock := Copy(LSource, LHandleGoawayPos, 900);
  Check(Pos('LLastStreamID > FLastLocalStreamID', LHandleGoawayBlock) > 0,
    'HandleGoaway rejects LastStreamID beyond locally initiated streams');
  Check(Pos('LLastStreamID > FPeerGoawayLastLocalStreamID', LHandleGoawayBlock) > 0,
    'HandleGoaway requires peer GOAWAY LastStreamID to be non-increasing');
  Check(Pos('FPeerGoawayLastLocalStreamID := LLastStreamID', LHandleGoawayBlock) > 0,
    'HandleGoaway records peer GOAWAY last local stream id');
  Check(Pos('FLastSeenPeerStreamID := LLastStreamID', LHandleGoawayBlock) = 0,
    'HandleGoaway no longer overwrites last seen peer stream id');
end;

procedure TestStreamMapFindAndRemoveReturnsDetachedStream;
var
  LMap: TH2StreamMap;
  LConnectionFlow: TH2ConnectionFlowControl;
  LDecoder: THPackDecoder;
  LFirst: TH2Stream;
  LSecond: TH2Stream;
  LRemoved: TH2Stream;
begin
  LMap := TH2StreamMap.Create;
  try
    LConnectionFlow.Init(H2_DEFAULT_INITIAL_WINDOW_SIZE);
    LDecoder.Init;
    LFirst := LMap.FindOrCreate(1, H2_DEFAULT_INITIAL_WINDOW_SIZE,
      H2_DEFAULT_INITIAL_WINDOW_SIZE, LConnectionFlow, LDecoder);
    LSecond := LMap.FindOrCreate(3, H2_DEFAULT_INITIAL_WINDOW_SIZE,
      H2_DEFAULT_INITIAL_WINDOW_SIZE, LConnectionFlow, LDecoder);

    LRemoved := LMap.FindAndRemove(1);
    Check(LRemoved = LFirst, 'FindAndRemove returns the matched stream');
    CheckEqual(Int64(1), Int64(LMap.ActiveCount),
      'FindAndRemove removes exactly one active stream');
    Check(LMap.Find(1) = nil, 'FindAndRemove detaches removed stream from map');
    Check(LMap.ItemAt(0) = LSecond, 'FindAndRemove compacts remaining streams');
    CheckEqual(Int64(1), Int64(LRemoved.StreamID),
      'FindAndRemove returns a still-usable detached stream');
    LRemoved.Free;
  finally
    LMap.Free;
  end;
end;

procedure TestStreamMapFindAndRemoveSourceContract;
var
  LSource: string;
begin
  LSource := ReadSourceFile(ResolveSourcePath(H2_SESSION_SOURCE_PATH_FROM_TEST,
    H2_SESSION_SOURCE_PATH_FROM_ROOT));
  Check(Pos('procedure RemoveByIndex(const AIndex: SizeInt);', LSource) > 0,
    'TH2StreamMap declares RemoveByIndex');
  Check(Pos('function FindAndRemove(const AStreamID: UInt32): TH2Stream;', LSource) > 0,
    'TH2StreamMap declares FindAndRemove');
  Check(Pos('procedure TH2StreamMap.RemoveByIndex(const AIndex: SizeInt);', LSource) > 0,
    'TH2StreamMap implements RemoveByIndex');
  Check(Pos('function TH2StreamMap.FindAndRemove(const AStreamID: UInt32): TH2Stream;', LSource) > 0,
    'TH2StreamMap implements FindAndRemove');
  Check(Pos('RemoveByIndex(LIndex);', LSource) > 0,
    'FindAndRemove reuses RemoveByIndex extraction path');
  Check(Pos('FStreams.RemoveByIndex(LStreamIndex);', LSource) > 0,
    'reset-handling paths remove by known index');
  Check(Pos('FStreams.FindAndRemove(AFrame.Header.StreamID);', LSource) > 0,
    'RST_STREAM handling uses FindAndRemove');
end;

procedure TestSendResponseBodyAvoidsIntermediateBufferCopySourceContract;
var
  LSource: string;
  LSendPos: SizeInt;
  LClosePos: SizeInt;
  LSendBlock: string;
begin
  LSource := ReadSourceFile(ResolveSourcePath(H2_SESSION_SOURCE_PATH_FROM_TEST,
    H2_SESSION_SOURCE_PATH_FROM_ROOT));
  LSendPos := Pos('procedure TH2ServerSession.SendResponseBody', LSource);
  Check(LSendPos > 0, 'SendResponseBody implementation is present');
  LClosePos := Pos('procedure TH2ServerSession.CloseStreamIfTerminal', LSource);
  Check(LClosePos > LSendPos, 'CloseStreamIfTerminal source follows SendResponseBody');
  if (LSendPos <= 0) or (LClosePos <= LSendPos) then
    Exit;
  LSendBlock := Copy(LSource, LSendPos, LClosePos - LSendPos);
  Check(Pos('LBuffer: array of Byte;', LSendBlock) = 0,
    'SendResponseBody avoids intermediate byte buffer allocation');
  Check(Pos('Move(LBuffer[0], LPayload[1], LRead);', LSendBlock) = 0,
    'SendResponseBody avoids buffer-to-payload copy');
  Check(Pos('ABody.Read(LPayload[1], LChunkSize)', LSendBlock) > 0,
    'SendResponseBody reads directly into payload buffer');
end;

procedure TestRunPushPromiseSendsGoaway;
var
  LHandler: TCollectingHandler;
  LHandlerRef: IHttpHandler;
  LStream: TFakeTcpStream;
  LConnRef: ITcpStream;
  LSession: TH2ServerSession;
  LWire: AnsiString;
  LFrames: array[0..7] of TH2Frame;
  LFrameCount: SizeInt;
  LErrorCode: UInt32;
begin
  LHandler := TCollectingHandler.Create;
  LHandlerRef := LHandler as IHttpHandler;
  try
    LWire := ComposePrefaceHandshake +
      H2EncodeFrame(H2_FRAME_PUSH_PROMISE, H2_FLAG_PUSH_PROMISE_END_HEADERS, 1,
        ComposePushPromisePayload(2));
    LStream := TFakeTcpStream.Create(LWire);
    LConnRef := LStream as ITcpStream;
    try
      LSession := TH2ServerSession.Create(LStream, LHandler,
        TH2ServerTransportOptions.Default);
      try
        LSession.Run;
      finally
        LSession.Free;
      end;
      CheckEqual(Int64(0), Int64(LHandler.CallCount),
        'client PUSH_PROMISE does not reach handler');
      DecodeFrames(LStream.WrittenData, LFrames, LFrameCount);
      Check(FindGoawayError(LFrames, LFrameCount, LErrorCode),
        'server writes GOAWAY for client PUSH_PROMISE');
      CheckEqual(Int64(H2_ERR_PROTOCOL_ERROR), Int64(LErrorCode),
        'client PUSH_PROMISE GOAWAY uses PROTOCOL_ERROR');
    finally
      LConnRef := nil;
      LStream := nil;
    end;
  finally
    LHandlerRef := nil;
    LHandler := nil;
  end;
end;

procedure TestRunTrailingHeadersCompleteRequestWithoutOverwritingHeaders;
var
  LHandler: TCollectingHandler;
  LHandlerRef: IHttpHandler;
  LStream: TFakeTcpStream;
  LConnRef: ITcpStream;
  LSession: TH2ServerSession;
  LWire: AnsiString;
  LInitialHeaders: array[0..0] of THPackHeader;
  LTrailers: array[0..1] of THPackHeader;
  LFrames: array[0..7] of TH2Frame;
  LFrameCount: SizeInt;
  LRequestValues: TStringArray;
  LTrailerValues: TStringArray;
begin
  LHandler := TCollectingHandler.Create;
  LHandlerRef := LHandler as IHttpHandler;
  try
    LHandler.SetResponse(HTTP_STATUS_OK, '');
    LInitialHeaders[0].Name := 'x-request';
    LInitialHeaders[0].Value := 'initial';
    LTrailers[0].Name := 'x-request';
    LTrailers[0].Value := 'trailer';
    LTrailers[1].Name := 'x-trailer';
    LTrailers[1].Value := 'done';
    LWire := ComposePrefaceHandshake +
      H2EncodeFrame(H2_FRAME_HEADERS, H2_FLAG_HEADERS_END_HEADERS, 1,
        ComposeRequestHeadersWithExtras('POST', '/trailers',
          LInitialHeaders)) +
      H2EncodeFrame(H2_FRAME_HEADERS,
        H2_FLAG_HEADERS_END_HEADERS or H2_FLAG_HEADERS_END_STREAM, 1,
        EncodeHeaders(LTrailers));
    LStream := TFakeTcpStream.Create(LWire);
    LConnRef := LStream as ITcpStream;
    try
      LSession := TH2ServerSession.Create(LStream, LHandler,
        TH2ServerTransportOptions.Default);
      try
        LSession.Run;
      finally
        LSession.Free;
      end;
      CheckEqual(Int64(1), Int64(LHandler.CallCount),
        'trailing HEADERS complete request once');
      Check(LHandler.SeenHeaders <> nil, 'handler sees request headers');
      LRequestValues := LHandler.SeenHeaders.GetAll('x-request');
      CheckEqual(Int64(1), Int64(Length(LRequestValues)),
        'trailers do not duplicate request header values');
      CheckEqual('initial', LRequestValues[0],
        'request header value is preserved');
      CheckEqual(False, LHandler.SeenHeaders.Has('x-trailer'),
        'trailers are not exposed as request headers');
      Check(LHandler.SeenTrailers <> nil, 'handler sees request trailers');
      LTrailerValues := LHandler.SeenTrailers.GetAll('x-request');
      CheckEqual(Int64(1), Int64(Length(LTrailerValues)),
        'handler sees original trailer x-request value');
      CheckEqual('trailer', LTrailerValues[0],
        'request trailers keep trailer-scoped x-request value');
      LTrailerValues := LHandler.SeenTrailers.GetAll('x-trailer');
      CheckEqual(Int64(1), Int64(Length(LTrailerValues)),
        'handler sees trailer-only header');
      CheckEqual('done', LTrailerValues[0],
        'request trailers preserve trailer-only header');

      DecodeFrames(LStream.WrittenData, LFrames, LFrameCount);
      CheckEqual(Int64(H2_FRAME_HEADERS), Int64(LFrames[2].Header.FrameType),
        'server responds to request completed by trailers');
      Check((LFrames[2].Header.Flags and H2_FLAG_HEADERS_END_STREAM) <> 0,
        'header-only response closes stream after trailers');
    finally
      LConnRef := nil;
      LStream := nil;
    end;
  finally
    LHandlerRef := nil;
    LHandler := nil;
  end;
end;

procedure TestRunWindowUpdateResumesBlockedResponseBody;
var
  LHandler: TCollectingHandler;
  LHandlerRef: IHttpHandler;
  LStream: TFakeTcpStream;
  LConnRef: ITcpStream;
  LSession: TH2ServerSession;
  LWire: AnsiString;
  LFrames: array[0..9] of TH2Frame;
  LFrameCount: SizeInt;
  LEntries: TH2SettingEntries;
begin
  LHandler := TCollectingHandler.Create;
  LHandlerRef := LHandler as IHttpHandler;
  try
    LHandler.SetResponse(HTTP_STATUS_OK, 'abcdef');
    SetLength(LEntries, 1);
    LEntries[0].Identifier := H2_SETTINGS_INITIAL_WINDOW_SIZE;
    LEntries[0].Value := 3;
    LWire := ComposePrefaceHandshake +
      H2EncodeFrame(H2_FRAME_SETTINGS, 0, 0, H2EncodeSettingsPayload(LEntries)) +
      H2EncodeFrame(H2_FRAME_HEADERS,
        H2_FLAG_HEADERS_END_HEADERS or H2_FLAG_HEADERS_END_STREAM, 1,
        ComposeRequestHeaders('GET', '/resume')) +
      H2EncodeFrame(H2_FRAME_WINDOW_UPDATE, 0, 1, H2EncodeWindowUpdate(3));
    LStream := TFakeTcpStream.Create(LWire);
    LConnRef := LStream as ITcpStream;
    try
      LSession := TH2ServerSession.Create(LStream, LHandler,
        TH2ServerTransportOptions.Default);
      try
        LSession.Run;
      finally
        LSession.Free;
      end;
      CheckEqual(Int64(1), Int64(LHandler.CallCount),
        'handler executes once for blocked response body case');
      DecodeFrames(LStream.WrittenData, LFrames, LFrameCount);
      CheckEqual(Int64(6), Int64(LFrameCount),
        'server emits second DATA frame after WINDOW_UPDATE');
      CheckEqual(Int64(H2_FRAME_SETTINGS), Int64(LFrames[0].Header.FrameType),
        'first frame is server settings');
      CheckEqual(Int64(H2_FRAME_SETTINGS), Int64(LFrames[1].Header.FrameType),
        'second frame ACKs preface settings');
      CheckEqual(Int64(H2_FRAME_SETTINGS), Int64(LFrames[2].Header.FrameType),
        'third frame ACKs runtime settings');
      CheckEqual(Int64(H2_FRAME_HEADERS), Int64(LFrames[3].Header.FrameType),
        'fourth frame is response headers');
      CheckEqual(Int64(H2_FRAME_DATA), Int64(LFrames[4].Header.FrameType),
        'fifth frame is first response body chunk');
      CheckEqual('abc', string(LFrames[4].Payload),
        'first body chunk obeys reduced stream window');
      Check((LFrames[4].Header.Flags and H2_FLAG_DATA_END_STREAM) = 0,
        'first body chunk does not end stream while bytes remain');
      CheckEqual(Int64(H2_FRAME_DATA), Int64(LFrames[5].Header.FrameType),
        'sixth frame is resumed response body chunk');
      CheckEqual('def', string(LFrames[5].Payload),
        'second body chunk flushes after WINDOW_UPDATE');
      Check((LFrames[5].Header.Flags and H2_FLAG_DATA_END_STREAM) <> 0,
        'second body chunk ends stream');
    finally
      LConnRef := nil;
      LStream := nil;
    end;
  finally
    LHandlerRef := nil;
    LHandler := nil;
  end;
end;

procedure TestRunConnectionLevelWindowUpdateAdjustsSendWindow;
var
  LHandler: TCollectingHandler;
  LHandlerRef: IHttpHandler;
  LOptions: TH2ServerTransportOptions;
  LStream: TFakeTcpStream;
  LConnRef: ITcpStream;
  LSession: TH2ServerSession;
  LWire: AnsiString;
  LFrames: array[0..11] of TH2Frame;
  LFrameCount: SizeInt;
  LErrorCode: UInt32;
begin
  LHandler := TCollectingHandler.Create;
  LHandlerRef := LHandler as IHttpHandler;
  try
    LHandler.SetResponse(HTTP_STATUS_OK, 'abcdefghij');
    LOptions := TH2ServerTransportOptions.Default;
    LOptions.InitialConnectionWindowSize := 5;
    LWire := ComposePrefaceHandshake +
      H2EncodeFrame(H2_FRAME_HEADERS,
        H2_FLAG_HEADERS_END_HEADERS or H2_FLAG_HEADERS_END_STREAM, 1,
        ComposeRequestHeaders('GET', '/conn-window')) +
      H2EncodeFrame(H2_FRAME_WINDOW_UPDATE, 0, 0, H2EncodeWindowUpdate(100));
    LStream := TFakeTcpStream.Create(LWire);
    LConnRef := LStream as ITcpStream;
    try
      LSession := TH2ServerSession.Create(LStream, LHandler, LOptions);
      try
        LSession.Run;
      finally
        LSession.Free;
      end;
      CheckEqual(Int64(1), Int64(LHandler.CallCount),
        'connection WINDOW_UPDATE does not block request handling');
      CheckEqual('/conn-window', LHandler.SeenPath,
        'request still reaches handler after connection WINDOW_UPDATE');
      DecodeFrames(LStream.WrittenData, LFrames, LFrameCount);
      Check(HasFrameType(LFrames, LFrameCount, H2_FRAME_DATA),
        'response body is still emitted with connection WINDOW_UPDATE present');
      Check(not FindGoawayError(LFrames, LFrameCount, LErrorCode),
        'connection WINDOW_UPDATE does not trigger GOAWAY');
    finally
      LConnRef := nil;
      LStream := nil;
    end;
  finally
    LHandlerRef := nil;
    LHandler := nil;
  end;
end;

procedure TestRunWindowUpdateZeroIncrementSendsProtocolErrorGoaway;
var
  LHandler: TCollectingHandler;
  LHandlerRef: IHttpHandler;
  LStream: TFakeTcpStream;
  LConnRef: ITcpStream;
  LSession: TH2ServerSession;
  LWire: AnsiString;
  LFrames: array[0..7] of TH2Frame;
  LFrameCount: SizeInt;
  LErrorCode: UInt32;
begin
  LHandler := TCollectingHandler.Create;
  LHandlerRef := LHandler as IHttpHandler;
  try
    LWire := ComposePrefaceHandshake +
      H2EncodeFrame(H2_FRAME_WINDOW_UPDATE, 0, 0, H2EncodeWindowUpdate(0));
    LStream := TFakeTcpStream.Create(LWire);
    LConnRef := LStream as ITcpStream;
    try
      LSession := TH2ServerSession.Create(LStream, LHandler,
        TH2ServerTransportOptions.Default);
      try
        LSession.Run;
      finally
        LSession.Free;
      end;
      DecodeFrames(LStream.WrittenData, LFrames, LFrameCount);
      Check(FindGoawayError(LFrames, LFrameCount, LErrorCode),
        'zero-increment WINDOW_UPDATE triggers GOAWAY');
      CheckEqual(Int64(H2_ERR_PROTOCOL_ERROR), Int64(LErrorCode),
        'zero-increment WINDOW_UPDATE uses current PROTOCOL_ERROR contract');
    finally
      LConnRef := nil;
      LStream := nil;
    end;
  finally
    LHandlerRef := nil;
    LHandler := nil;
  end;
end;

procedure TestRunWindowUpdateExceedingMaxSendsFlowControlError;
var
  LHandler: TCollectingHandler;
  LHandlerRef: IHttpHandler;
  LOptions: TH2ServerTransportOptions;
  LStream: TFakeTcpStream;
  LConnRef: ITcpStream;
  LSession: TH2ServerSession;
  LWire: AnsiString;
  LFrames: array[0..9] of TH2Frame;
  LFrameCount: SizeInt;
  LErrorCode: UInt32;
begin
  LHandler := TCollectingHandler.Create;
  LHandlerRef := LHandler as IHttpHandler;
  try
    LOptions := TH2ServerTransportOptions.Default;
    LOptions.InitialConnectionWindowSize := 1;
    LWire := ComposePrefaceHandshake +
      H2EncodeFrame(H2_FRAME_WINDOW_UPDATE, 0, 0,
        H2EncodeWindowUpdate(H2_MAX_WINDOW_SIZE)) +
      H2EncodeFrame(H2_FRAME_WINDOW_UPDATE, 0, 0, H2EncodeWindowUpdate(1));
    LStream := TFakeTcpStream.Create(LWire);
    LConnRef := LStream as ITcpStream;
    try
      LSession := TH2ServerSession.Create(LStream, LHandler, LOptions);
      try
        LSession.Run;
      finally
        LSession.Free;
      end;
      DecodeFrames(LStream.WrittenData, LFrames, LFrameCount);
      Check(FindGoawayError(LFrames, LFrameCount, LErrorCode),
        'overflowing WINDOW_UPDATE triggers GOAWAY');
      CheckEqual(Int64(H2_ERR_FLOW_CONTROL_ERROR), Int64(LErrorCode),
        'overflowing WINDOW_UPDATE uses FLOW_CONTROL_ERROR');
    finally
      LConnRef := nil;
      LStream := nil;
    end;
  finally
    LHandlerRef := nil;
    LHandler := nil;
  end;
end;

procedure TestRunHeadersWithPaddingParsesCorrectly;
var
  LHandler: TCollectingHandler;
  LHandlerRef: IHttpHandler;
  LStream: TFakeTcpStream;
  LConnRef: ITcpStream;
  LSession: TH2ServerSession;
  LWire: AnsiString;
begin
  LHandler := TCollectingHandler.Create;
  LHandlerRef := LHandler as IHttpHandler;
  try
    LHandler.SetResponse(HTTP_STATUS_OK, '');
    LWire := ComposePrefaceHandshake +
      H2EncodeFrame(H2_FRAME_HEADERS,
        H2_FLAG_HEADERS_PADDED or H2_FLAG_HEADERS_END_HEADERS or
        H2_FLAG_HEADERS_END_STREAM, 1,
        AnsiChar(#2) + ComposeRequestHeaders('GET', '/padded') + '..');
    LStream := TFakeTcpStream.Create(LWire);
    LConnRef := LStream as ITcpStream;
    try
      LSession := TH2ServerSession.Create(LStream, LHandler,
        TH2ServerTransportOptions.Default);
      try
        LSession.Run;
      finally
        LSession.Free;
      end;
      CheckEqual(Int64(1), Int64(LHandler.CallCount),
        'padded HEADERS still reaches handler');
      CheckEqual('/padded', LHandler.SeenPath,
        'padding is stripped from HEADERS payload');
    finally
      LConnRef := nil;
      LStream := nil;
    end;
  finally
    LHandlerRef := nil;
    LHandler := nil;
  end;
end;

procedure TestRunDataWithPaddingDeliversUnpaddedBody;
var
  LHandler: TCollectingHandler;
  LHandlerRef: IHttpHandler;
  LStream: TFakeTcpStream;
  LConnRef: ITcpStream;
  LSession: TH2ServerSession;
  LWire: AnsiString;
begin
  LHandler := TCollectingHandler.Create;
  LHandlerRef := LHandler as IHttpHandler;
  try
    LHandler.SetResponse(HTTP_STATUS_OK, '');
    LWire := ComposePrefaceHandshake +
      H2EncodeFrame(H2_FRAME_HEADERS, H2_FLAG_HEADERS_END_HEADERS, 1,
        ComposeRequestHeaders('POST', '/padded-body')) +
      H2EncodeFrame(H2_FRAME_DATA,
        H2_FLAG_DATA_PADDED or H2_FLAG_DATA_END_STREAM, 1,
        AnsiChar(#3) + 'hello' + '...');
    LStream := TFakeTcpStream.Create(LWire);
    LConnRef := LStream as ITcpStream;
    try
      LSession := TH2ServerSession.Create(LStream, LHandler,
        TH2ServerTransportOptions.Default);
      try
        LSession.Run;
      finally
        LSession.Free;
      end;
      CheckEqual(Int64(1), Int64(LHandler.CallCount),
        'padded DATA still reaches handler');
      CheckEqual('hello', LHandler.SeenBody,
        'padding is stripped from DATA payload');
    finally
      LConnRef := nil;
      LStream := nil;
    end;
  finally
    LHandlerRef := nil;
    LHandler := nil;
  end;
end;

procedure TestRunRstStreamOnHalfClosedRemoteStreamIsNoop;
var
  LHandler: TCollectingHandler;
  LHandlerRef: IHttpHandler;
  LStream: TFakeTcpStream;
  LConnRef: ITcpStream;
  LSession: TH2ServerSession;
  LWire: AnsiString;
  LFrames: array[0..7] of TH2Frame;
  LFrameCount: SizeInt;
  LErrorCode: UInt32;
begin
  LHandler := TCollectingHandler.Create;
  LHandlerRef := LHandler as IHttpHandler;
  try
    LHandler.SetResponse(HTTP_STATUS_OK, '');
    LWire := ComposePrefaceHandshake +
      H2EncodeFrame(H2_FRAME_HEADERS,
        H2_FLAG_HEADERS_END_HEADERS or H2_FLAG_HEADERS_END_STREAM, 1,
        ComposeRequestHeaders('GET', '/half-closed')) +
      H2EncodeFrame(H2_FRAME_RST_STREAM, 0, 1, H2EncodeRstStream(H2_ERR_CANCEL));
    LStream := TFakeTcpStream.Create(LWire);
    LConnRef := LStream as ITcpStream;
    try
      LSession := TH2ServerSession.Create(LStream, LHandler,
        TH2ServerTransportOptions.Default);
      try
        CheckEqual(Int64(TCP_SERVER_CONN_OWNERSHIP_SERVER), Int64(LSession.Run),
          'RST_STREAM on half-closed remote stream returns normally');
      finally
        LSession.Free;
      end;
      DecodeFrames(LStream.WrittenData, LFrames, LFrameCount);
      Check(not FindGoawayError(LFrames, LFrameCount, LErrorCode),
        'RST_STREAM on half-closed remote stream does not trigger GOAWAY');
    finally
      LConnRef := nil;
      LStream := nil;
    end;
  finally
    LHandlerRef := nil;
    LHandler := nil;
  end;
end;

procedure TestRunRstStreamOnIdleStreamIsNoop;
var
  LHandler: TCollectingHandler;
  LHandlerRef: IHttpHandler;
  LStream: TFakeTcpStream;
  LConnRef: ITcpStream;
  LSession: TH2ServerSession;
  LWire: AnsiString;
  LFrames: array[0..7] of TH2Frame;
  LFrameCount: SizeInt;
  LErrorCode: UInt32;
begin
  LHandler := TCollectingHandler.Create;
  LHandlerRef := LHandler as IHttpHandler;
  try
    LWire := ComposePrefaceHandshake +
      H2EncodeFrame(H2_FRAME_RST_STREAM, 0, 99, H2EncodeRstStream(H2_ERR_CANCEL));
    LStream := TFakeTcpStream.Create(LWire);
    LConnRef := LStream as ITcpStream;
    try
      LSession := TH2ServerSession.Create(LStream, LHandler,
        TH2ServerTransportOptions.Default);
      try
        CheckEqual(Int64(TCP_SERVER_CONN_OWNERSHIP_SERVER), Int64(LSession.Run),
          'RST_STREAM on idle stream returns normally');
      finally
        LSession.Free;
      end;
      DecodeFrames(LStream.WrittenData, LFrames, LFrameCount);
      Check(not FindGoawayError(LFrames, LFrameCount, LErrorCode),
        'RST_STREAM on idle stream does not trigger GOAWAY');
    finally
      LConnRef := nil;
      LStream := nil;
    end;
  finally
    LHandlerRef := nil;
    LHandler := nil;
  end;
end;

procedure TestRunGoawayWithLastStreamIdAllowsFinishingEarlierStreams;
var
  LHandler: TCollectingHandler;
  LHandlerRef: IHttpHandler;
  LStream: TFakeTcpStream;
  LConnRef: ITcpStream;
  LSession: TH2ServerSession;
  LWire: AnsiString;
  LFrames: array[0..9] of TH2Frame;
  LFrameCount: SizeInt;
  LLastStreamID: UInt32;
  LErrorCode: UInt32;
begin
  LHandler := TCollectingHandler.Create;
  LHandlerRef := LHandler as IHttpHandler;
  try
    LHandler.SetResponse(HTTP_STATUS_OK, '');
    LWire := ComposePrefaceHandshake +
      H2EncodeFrame(H2_FRAME_HEADERS,
        H2_FLAG_HEADERS_END_HEADERS or H2_FLAG_HEADERS_END_STREAM, 1,
        ComposeRequestHeaders('GET', '/goaway-finish')) +
      H2EncodeFrame(H2_FRAME_GOAWAY, 0, 0,
        H2EncodeGoaway(0, H2_ERR_NO_ERROR, ''));
    LStream := TFakeTcpStream.Create(LWire);
    LConnRef := LStream as ITcpStream;
    try
      LSession := TH2ServerSession.Create(LStream, LHandler,
        TH2ServerTransportOptions.Default);
      try
        LSession.Run;
      finally
        LSession.Free;
      end;
      CheckEqual(Int64(1), Int64(LHandler.CallCount),
        'peer GOAWAY still allows earlier request to finish');
      DecodeFrames(LStream.WrittenData, LFrames, LFrameCount);
      Check(FindGoawayDetails(LFrames, LFrameCount, LLastStreamID, LErrorCode),
        'peer GOAWAY leads to graceful local GOAWAY');
      CheckEqual(Int64(1), Int64(LLastStreamID),
        'graceful local GOAWAY preserves last seen peer stream id');
      CheckEqual(Int64(H2_ERR_NO_ERROR), Int64(LErrorCode),
        'graceful local GOAWAY uses NO_ERROR');
      CheckEqual(Int64(H2_FRAME_HEADERS), Int64(LFrames[2].Header.FrameType),
        'server still emits response after peer GOAWAY');
    finally
      LConnRef := nil;
      LStream := nil;
    end;
  finally
    LHandlerRef := nil;
    LHandler := nil;
  end;
end;

procedure TestRunGoawayWithDecreasingLastStreamIdAccepted;
var
  LHandler: TCollectingHandler;
  LHandlerRef: IHttpHandler;
  LStream: TFakeTcpStream;
  LConnRef: ITcpStream;
  LSession: TH2ServerSession;
  LWire: AnsiString;
  LFrames: array[0..7] of TH2Frame;
  LFrameCount: SizeInt;
  LLastStreamID: UInt32;
  LErrorCode: UInt32;
begin
  LHandler := TCollectingHandler.Create;
  LHandlerRef := LHandler as IHttpHandler;
  try
    LWire := ComposePrefaceHandshake +
      H2EncodeFrame(H2_FRAME_GOAWAY, 0, 0,
        H2EncodeGoaway(0, H2_ERR_NO_ERROR, '')) +
      H2EncodeFrame(H2_FRAME_GOAWAY, 0, 0,
        H2EncodeGoaway(0, H2_ERR_NO_ERROR, ''));
    LStream := TFakeTcpStream.Create(LWire);
    LConnRef := LStream as ITcpStream;
    try
      LSession := TH2ServerSession.Create(LStream, LHandler,
        TH2ServerTransportOptions.Default);
      try
        CheckEqual(Int64(TCP_SERVER_CONN_OWNERSHIP_SERVER), Int64(LSession.Run),
          'decreasing peer GOAWAY sequence returns normally');
      finally
        LSession.Free;
      end;
      DecodeFrames(LStream.WrittenData, LFrames, LFrameCount);
      Check(FindGoawayDetails(LFrames, LFrameCount, LLastStreamID, LErrorCode),
        'decreasing peer GOAWAY sequence still leads to graceful local GOAWAY');
      CheckEqual(Int64(0), Int64(LLastStreamID),
        'decreasing peer GOAWAY preserves last local stream boundary');
      CheckEqual(Int64(H2_ERR_NO_ERROR), Int64(LErrorCode),
        'decreasing peer GOAWAY keeps NO_ERROR shutdown');
    finally
      LConnRef := nil;
      LStream := nil;
    end;
  finally
    LHandlerRef := nil;
    LHandler := nil;
  end;
end;

procedure TestRunPriorityFrameIsSilentlyIgnored;
var
  LHandler: TCollectingHandler;
  LHandlerRef: IHttpHandler;
  LStream: TFakeTcpStream;
  LConnRef: ITcpStream;
  LSession: TH2ServerSession;
  LWire: AnsiString;
begin
  LHandler := TCollectingHandler.Create;
  LHandlerRef := LHandler as IHttpHandler;
  try
    LHandler.SetResponse(HTTP_STATUS_OK, '');
    LWire := ComposePrefaceHandshake +
      H2EncodeFrame(H2_FRAME_PRIORITY, 0, 3, HexToBytes('0000000001')) +
      H2EncodeFrame(H2_FRAME_HEADERS,
        H2_FLAG_HEADERS_END_HEADERS or H2_FLAG_HEADERS_END_STREAM, 1,
        ComposeRequestHeaders('GET', '/priority'));
    LStream := TFakeTcpStream.Create(LWire);
    LConnRef := LStream as ITcpStream;
    try
      LSession := TH2ServerSession.Create(LStream, LHandler,
        TH2ServerTransportOptions.Default);
      try
        LSession.Run;
      finally
        LSession.Free;
      end;
      CheckEqual(Int64(1), Int64(LHandler.CallCount),
        'PRIORITY frame does not stop request handling');
      CheckEqual('/priority', LHandler.SeenPath,
        'request after PRIORITY still reaches handler');
    finally
      LConnRef := nil;
      LStream := nil;
    end;
  finally
    LHandlerRef := nil;
    LHandler := nil;
  end;
end;

procedure TestRunContinuationOnWrongStreamSendsGoaway;
var
  LHandler: TCollectingHandler;
  LHandlerRef: IHttpHandler;
  LStream: TFakeTcpStream;
  LConnRef: ITcpStream;
  LSession: TH2ServerSession;
  LWire: AnsiString;
  LFrames: array[0..7] of TH2Frame;
  LFrameCount: SizeInt;
  LErrorCode: UInt32;
begin
  LHandler := TCollectingHandler.Create;
  LHandlerRef := LHandler as IHttpHandler;
  try
    LWire := ComposePrefaceHandshake +
      H2EncodeFrame(H2_FRAME_HEADERS, 0, 1,
        ComposeRequestHeaders('GET', '/pending')) +
      H2EncodeFrame(H2_FRAME_CONTINUATION, H2_FLAG_CONTINUATION_END_HEADERS, 3,
        '');
    LStream := TFakeTcpStream.Create(LWire);
    LConnRef := LStream as ITcpStream;
    try
      LSession := TH2ServerSession.Create(LStream, LHandler,
        TH2ServerTransportOptions.Default);
      try
        LSession.Run;
      finally
        LSession.Free;
      end;
      DecodeFrames(LStream.WrittenData, LFrames, LFrameCount);
      Check(FindGoawayError(LFrames, LFrameCount, LErrorCode),
        'wrong-stream CONTINUATION triggers GOAWAY');
      CheckEqual(Int64(H2_ERR_PROTOCOL_ERROR), Int64(LErrorCode),
        'wrong-stream CONTINUATION uses PROTOCOL_ERROR');
    finally
      LConnRef := nil;
      LStream := nil;
    end;
  finally
    LHandlerRef := nil;
    LHandler := nil;
  end;
end;

procedure TestRunTwoConcurrentRequestsExecuteIndependently;
var
  LHandler: TCollectingHandler;
  LHandlerRef: IHttpHandler;
  LStream: TFakeTcpStream;
  LConnRef: ITcpStream;
  LSession: TH2ServerSession;
  LWire: AnsiString;
begin
  LHandler := TCollectingHandler.Create;
  LHandlerRef := LHandler as IHttpHandler;
  try
    LHandler.SetResponse(HTTP_STATUS_OK, '');
    LWire := ComposePrefaceHandshake +
      H2EncodeFrame(H2_FRAME_HEADERS,
        H2_FLAG_HEADERS_END_HEADERS or H2_FLAG_HEADERS_END_STREAM, 1,
        ComposeRequestHeaders('GET', '/one')) +
      H2EncodeFrame(H2_FRAME_HEADERS,
        H2_FLAG_HEADERS_END_HEADERS or H2_FLAG_HEADERS_END_STREAM, 3,
        ComposeRequestHeaders('GET', '/two'));
    LStream := TFakeTcpStream.Create(LWire);
    LConnRef := LStream as ITcpStream;
    try
      LSession := TH2ServerSession.Create(LStream, LHandler,
        TH2ServerTransportOptions.Default);
      try
        LSession.Run;
      finally
        LSession.Free;
      end;
      CheckEqual(Int64(2), Int64(LHandler.CallCount),
        'independent concurrent requests both execute');
    finally
      LConnRef := nil;
      LStream := nil;
    end;
  finally
    LHandlerRef := nil;
    LHandler := nil;
  end;
end;

procedure TestRunHandlerExceptionResetsStreamWithoutClosingConnection;
var
  LHandler: TFailingHandler;
  LHandlerRef: IHttpHandler;
  LStream: TFakeTcpStream;
  LConnRef: ITcpStream;
  LSession: TH2ServerSession;
  LWire: AnsiString;
  LFrames: array[0..7] of TH2Frame;
  LFrameCount: SizeInt;
  LErrorCode: UInt32;
begin
  LHandler := TFailingHandler.Create;
  LHandlerRef := LHandler as IHttpHandler;
  try
    LWire := ComposePrefaceHandshake +
      H2EncodeFrame(H2_FRAME_HEADERS,
        H2_FLAG_HEADERS_END_HEADERS or H2_FLAG_HEADERS_END_STREAM, 1,
        ComposeRequestHeaders('GET', '/boom'));
    LStream := TFakeTcpStream.Create(LWire);
    LConnRef := LStream as ITcpStream;
    try
      LSession := TH2ServerSession.Create(LStream, LHandler,
        TH2ServerTransportOptions.Default);
      try
        LSession.Run;
      finally
        LSession.Free;
      end;
      DecodeFrames(LStream.WrittenData, LFrames, LFrameCount);
      Check(FindRstStreamError(LFrames, LFrameCount, 1, LErrorCode),
        'handler exception resets stream');
      CheckEqual(Int64(H2_ERR_INTERNAL_ERROR), Int64(LErrorCode),
        'handler exception uses INTERNAL_ERROR');
      Check(not HasFrameType(LFrames, LFrameCount, H2_FRAME_GOAWAY),
        'handler exception stays stream-scoped');
    finally
      LConnRef := nil;
      LStream := nil;
    end;
  finally
    LHandlerRef := nil;
    LHandler := nil;
  end;
end;

begin
  with TTestRunner.Create('nextpas.core.http.impl.h2.session') do
  begin
    Run('Partial preface waits', @TestPartialPrefaceWaits);
    Run('Wrong preface is connection error', @TestWrongPrefaceIsConnectionError);
    Run('Preface without first frame waits', @TestPrefaceWithoutFirstFrameWaits);
    Run('Partial first frame waits', @TestPartialFirstFrameWaits);
    Run('Initial SETTINGS accepted', @TestInitialSettingsAccepted);
    Run('Initial SETTINGS with payload accepted',
      @TestInitialSettingsWithPayloadAccepted);
    Run('First frame must be SETTINGS', @TestFirstFrameMustBeSettings);
    Run('Initial SETTINGS must not ACK', @TestInitialSettingsMustNotAck);
    Run('Initial SETTINGS uses connection stream',
      @TestInitialSettingsUsesConnectionStream);
    Run('Run handshake and simple request response',
      @TestRunHandshakeAndSimpleRequestResponse);
    Run('Run handshake advertises MAX_HEADER_LIST_SIZE',
      @TestRunHandshakeAdvertisesMaxHeaderListSizeSetting);
    Run('Run client SETTINGS ACK is silently accepted',
      @TestRunSettingsAckFromClientIsSilentlyAccepted);
    Run('Run MaxConcurrentStreams exceeded sends REFUSED_STREAM',
      @TestRunMaxConcurrentStreamsExceededSendsRefusedStream);
    Run('Run peer SETTINGS INITIAL_WINDOW_SIZE updates open streams',
      @TestRunPeerSettingsInitialWindowSizeUpdatesOpenStreams);
    Run('Run invalid SETTINGS identifier is ignored',
      @TestRunInvalidSettingsIdentifierIsIgnored);
    Run('Run SETTINGS ENABLE_PUSH greater than one is protocol error',
      @TestRunSettingsEnablePushGreaterThanOneIsProtocolError);
    Run('Run missing :path pseudo header resets stream',
      @TestRunMissingPathPseudoHeaderResetsStream);
    Run('Run missing :authority and host resets stream',
      @TestRunMissingAuthorityAndHostResetsStream);
    Run('Run pseudo header after regular header resets stream',
      @TestRunPseudoHeaderAfterRegularHeaderResetsStream);
    Run('Run duplicate pseudo header resets stream',
      @TestRunDuplicatePseudoHeaderResetsStream);
    Run('Run connection specific header resets stream',
      @TestRunConnectionSpecificHeaderResetsStream);
    Run('Run non-trailers TE header resets stream',
      @TestRunNonTrailersTeHeaderResetsStream);
    Run('Run DATA END_STREAM triggers handler and flow control update',
      @TestRunDataEndStreamTriggersHandlerAndFlowControlUpdate);
    Run('Run DATA over MaxBodySize returns 413 without handler',
      @TestRunDataOverMaxBodySizeReturns413WithoutHandler);
    Run('Run headers over MaxHeaderListSize returns 431 without handler',
      @TestRunHeadersOverMaxHeaderListSizeReturns431WithoutHandler);
    Run('Run PING gets ACKed', @TestRunPingGetsAcked);
    Run('Run RST_STREAM cancels pending request',
      @TestRunRstStreamCancelsPendingRequest);
    Run('Run GOAWAY stops new streams', @TestRunGoawayStopsNewStreams);
    Run('Run GOAWAY rejects non-zero LastStreamID without local streams',
      @TestRunGoawayRejectsNonZeroLastStreamIDWithoutLocalStreams);
    Run('Run peer GOAWAY does not overwrite last seen peer stream id',
      @TestRunPeerGoawayDoesNotOverwriteLastSeenPeerStreamID);
    Run('Advance polls readable then writable',
      @TestAdvancePollsReadableThenWritable);
    Run('Run unknown extension frame is ignored',
      @TestRunUnknownExtensionFrameIsIgnored);
    Run('Run DATA on connection stream sends GOAWAY',
      @TestRunDataOnConnectionStreamSendsGoaway);
    Run('Run DATA on closed stream restores connection window',
      @TestRunDataOnClosedStreamRestoresConnectionWindow);
    Run('TH2StreamMap FindAndRemove returns detached stream',
      @TestStreamMapFindAndRemoveReturnsDetachedStream);
    Run('TH2StreamMap FindAndRemove source contract',
      @TestStreamMapFindAndRemoveSourceContract);
    Run('HandleData connection stream source contract',
      @TestHandleDataConnectionStreamSourceContract);
    Run('HandleGoaway split tracking source contract',
      @TestHandleGoawayUsesSeparatePeerAndLocalStreamTrackingSourceContract);
    Run('SendResponseBody avoids intermediate buffer copy source contract',
      @TestSendResponseBodyAvoidsIntermediateBufferCopySourceContract);
    Run('Run client PUSH_PROMISE sends GOAWAY',
      @TestRunPushPromiseSendsGoaway);
    Run('Run trailing HEADERS complete request without overwriting headers',
      @TestRunTrailingHeadersCompleteRequestWithoutOverwritingHeaders);
    Run('Run WINDOW_UPDATE resumes blocked response body',
      @TestRunWindowUpdateResumesBlockedResponseBody);
    Run('Run connection WINDOW_UPDATE adjusts send window',
      @TestRunConnectionLevelWindowUpdateAdjustsSendWindow);
    Run('Run WINDOW_UPDATE zero increment sends PROTOCOL_ERROR GOAWAY',
      @TestRunWindowUpdateZeroIncrementSendsProtocolErrorGoaway);
    Run('Run WINDOW_UPDATE exceeding max sends FLOW_CONTROL_ERROR',
      @TestRunWindowUpdateExceedingMaxSendsFlowControlError);
    Run('Run HEADERS with padding parses correctly',
      @TestRunHeadersWithPaddingParsesCorrectly);
    Run('Run DATA with padding delivers unpadded body',
      @TestRunDataWithPaddingDeliversUnpaddedBody);
    Run('Run RST_STREAM on half-closed remote stream is noop',
      @TestRunRstStreamOnHalfClosedRemoteStreamIsNoop);
    Run('Run RST_STREAM on idle stream is noop',
      @TestRunRstStreamOnIdleStreamIsNoop);
    Run('Run GOAWAY with last stream id allows finishing earlier streams',
      @TestRunGoawayWithLastStreamIdAllowsFinishingEarlierStreams);
    Run('Run GOAWAY with decreasing last stream id accepted',
      @TestRunGoawayWithDecreasingLastStreamIdAccepted);
    Run('Run PRIORITY frame is silently ignored',
      @TestRunPriorityFrameIsSilentlyIgnored);
    Run('Run CONTINUATION on wrong stream sends GOAWAY',
      @TestRunContinuationOnWrongStreamSendsGoaway);
    Run('Run two concurrent requests execute independently',
      @TestRunTwoConcurrentRequestsExecuteIndependently);
    Run('Run handler exception resets stream without closing connection',
      @TestRunHandlerExceptionResetsStreamWithoutClosingConnection);
    Summary;
  end;
end.
