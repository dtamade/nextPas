unit nextpas.core.http.websocket;
{**
 * @desc WebSocket (RFC 6455) server-side implementation.
 *       Provides upgrade handshake and frame-level read/write.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.io.intf,
  nextpas.core.http.base,
  nextpas.core.http.intf;

type
  { Callback to validate WebSocket Origin header during upgrade.
    Return True to accept, False to reject with 403.
    AOrigin is the raw Origin header value (empty if absent). }
  TWebSocketOriginCheck = function(const AOrigin: string): Boolean;

  TWebSocketOptions = record
    MaxFrameSize: Int64;
    MaxMessageSize: Int64;
    { If set, called during upgrade to validate the Origin header.
      When nil, all origins are accepted (no validation). }
    OnCheckOrigin: TWebSocketOriginCheck;
    class function Default: TWebSocketOptions; static;
  end;

  TWebSocketOpcode = (
    wsOpContinuation = 0,
    wsOpText = 1,
    wsOpBinary = 2,
    wsOpClose = 8,
    wsOpPing = 9,
    wsOpPong = 10
  );

  TWebSocketFrame = record
    Fin: Boolean;
    Opcode: TWebSocketOpcode;
    Payload: string;
  end;

  IWebSocket = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-600000000001}']
    function ReadFrame: TWebSocketFrame;
    { Read a complete message, handling continuation frames automatically.
      Auto-responds to Ping frames with Pong (per RFC 6455).
      Returns the aggregated message (text or binary).
      Raises EHttpError on protocol errors or connection close. }
    function ReadMessage: TWebSocketFrame;
    procedure WriteText(const AData: string);
    procedure WriteBinary(const AData: string);
    procedure Ping(const AData: string);
    procedure Pong(const AData: string);
    procedure Close(const ACode: UInt16; const AReason: string);
    function IsOpen: Boolean;
  end;

const
  WEBSOCKET_DEFAULT_MAX_FRAME_SIZE = Int64(16777216);
  WEBSOCKET_DEFAULT_MAX_MESSAGE_SIZE = Int64(67108864);

{ Upgrade an HTTP connection to WebSocket.
  Validates Upgrade headers, sends 101 response, returns IWebSocket.
  The response writer must support IHttpHijacker to obtain the raw connection.
  Raises EHttpError if upgrade fails. }
function UpgradeWebSocket(const AReq: IHttpRequest;
  const AW: IHttpResponseWriter): IWebSocket; overload;
function UpgradeWebSocket(const AReq: IHttpRequest; const AW: IHttpResponseWriter;
  const AOptions: TWebSocketOptions): IWebSocket; overload;

{ Connect to a WebSocket server.
  Establishes TCP connection, performs client handshake, returns IWebSocket.
  Supports ws:// and wss:// schemes.
  Raises EHttpError if connection or handshake fails. }
function ConnectWebSocket(const AUrl: string): IWebSocket; overload;
function ConnectWebSocket(const AUrl: string;
  const AOptions: TWebSocketOptions): IWebSocket; overload;
function ConnectWebSocket(const AClient: IHttpClient;
  const AUrl: string): IWebSocket; overload;
function ConnectWebSocket(const AClient: IHttpClient;
  const AUrl: string;
  const AOptions: TWebSocketOptions): IWebSocket; overload;

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.hash,
  nextpas.core.hash.base,
  nextpas.core.encoding,
  nextpas.core.text.conv,
  nextpas.core.text.utf8,
  nextpas.core.websocket.base,
  nextpas.core.net,
  nextpas.core.net.base,
  nextpas.core.net.intf,
  nextpas.core.io.util,
  nextpas.core.http.url,
  nextpas.core.http.headers,
  nextpas.core.http.message,
  nextpas.core.http.client,
  nextpas.core.http.impl.tls.stream,
  nextpas.core.tls.random;

type
  TWebSocketImpl = class(TInterfacedObject, IWebSocket)
  private
    FReader: IReader;
    FWriter: IWriter;
    FOpen: Boolean;
    FCloseReceived: Boolean;
    FCloseSent: Boolean;
    FFragmentOpen: Boolean;
    FFragmentOpcode: TWebSocketOpcode;
    FFragmentPayloadSize: UInt64;
    FFragmentTextPayload: string;
    FOptions: TWebSocketOptions;
    FIsClient: Boolean;
    procedure WriteFrame(AOpcode: TWebSocketOpcode; const APayload: string);
    procedure WriteFrameRaw(AOpcode: TWebSocketOpcode; const APayload: string);
    procedure ReadExact(var ABuf; ACount: SizeUInt);
  public
    constructor Create(const AReader: IReader; const AWriter: IWriter;
      const AOptions: TWebSocketOptions; AIsClient: Boolean = False);
    function ReadFrame: TWebSocketFrame;
    function ReadMessage: TWebSocketFrame;
    procedure WriteText(const AData: string);
    procedure WriteBinary(const AData: string);
    procedure Ping(const AData: string);
    procedure Pong(const AData: string);
    procedure Close(const ACode: UInt16; const AReason: string);
    function IsOpen: Boolean;
  end;

{ Helpers }

class function TWebSocketOptions.Default: TWebSocketOptions;
begin
  Result.MaxFrameSize := WEBSOCKET_DEFAULT_MAX_FRAME_SIZE;
  Result.MaxMessageSize := WEBSOCKET_DEFAULT_MAX_MESSAGE_SIZE;
  Result.OnCheckOrigin := nil;
end;

procedure ValidateWebSocketOptions(const AOptions: TWebSocketOptions);
begin
  if AOptions.MaxFrameSize < 0 then
    raise EArgumentError.Create('WebSocket max frame size must not be negative');
  if AOptions.MaxMessageSize < 0 then
    raise EArgumentError.Create('WebSocket max message size must not be negative');
end;

function IsOWS(const ACh: Char): Boolean;
begin
  Result := (ACh = ' ') or (ACh = #9);
end;

function TrimOWS(const S: string): string;
var
  LFirst, LLast: Integer;
begin
  LFirst := 1;
  LLast := Length(S);
  while (LFirst <= LLast) and IsOWS(S[LFirst]) do
    Inc(LFirst);
  while (LLast >= LFirst) and IsOWS(S[LLast]) do
    Dec(LLast);
  if LFirst > LLast then
    Exit('');
  Result := Copy(S, LFirst, LLast - LFirst + 1);
end;

function LowerTrimOWS(const S: string): string;
var
  LFirst, LLast: Integer;
begin
  LFirst := 1;
  LLast := Length(S);
  while (LFirst <= LLast) and IsOWS(S[LFirst]) do
    Inc(LFirst);
  while (LLast >= LFirst) and IsOWS(S[LLast]) do
    Dec(LLast);
  if LFirst > LLast then
    Exit('');
  Result := LowerCase(Copy(S, LFirst, LLast - LFirst + 1));
end;

function HeaderValueHasToken(const AValue, AToken: string): Boolean;
var
  LStart, LPos: Integer;
begin
  Result := False;
  LStart := 1;
  while LStart <= Length(AValue) + 1 do
  begin
    LPos := LStart;
    while (LPos <= Length(AValue)) and (AValue[LPos] <> ',') do
      Inc(LPos);
    if LowerTrimOWS(Copy(AValue, LStart, LPos - LStart)) = AToken then
      Exit(True);
    LStart := LPos + 1;
  end;
end;

function HeaderValuesHaveToken(const AValues: TStringArray;
  const AToken: string): Boolean;
var
  LI: SizeInt;
begin
  Result := False;
  for LI := Low(AValues) to High(AValues) do
    if HeaderValueHasToken(AValues[LI], AToken) then
      Exit(True);
end;

function ComputeAcceptKey(const AKey: string): string;
var
  LConcat: string;
  LDigest: TSHA1Digest;
  LBytes: TBytes;
begin
  LConcat := AKey + WS_GUID;
  LDigest := SHA1Of(LConcat[1], SizeUInt(Length(LConcat)));
  SetLength(LBytes, SHA1_DIGEST_SIZE);
  Move(LDigest[0], LBytes[0], SHA1_DIGEST_SIZE);
  Result := Base64Encode(LBytes);
end;

procedure ValidateHandshakeKey(const AKey: string);
var
  LDecoded: TBytes;
begin
  try
    LDecoded := Base64Decode(AKey);
  except
    on E: EConvertError do
      raise EHttpError.Create('Invalid Sec-WebSocket-Key header');
  end;

  if Length(LDecoded) <> 16 then
    raise EHttpError.Create('Invalid Sec-WebSocket-Key header');
end;

function IsValidOpcode(const AOpcode: Byte): Boolean;
begin
  case AOpcode of
    $0, $1, $2, $8, $9, $A:
      Result := True;
  else
    Result := False;
  end;
end;

function IsValidCloseCode(const ACode: UInt16): Boolean;
begin
  Result :=
    (ACode >= 1000) and
    (ACode < 5000) and
    (ACode <> 1004) and
    (ACode <> 1005) and
    (ACode <> 1006) and
    (ACode <> 1015);
end;

procedure ValidateClosePayload(const APayload: string);
var
  LCode: UInt16;
begin
  if Length(APayload) = 0 then
    Exit;
  if Length(APayload) = 1 then
    raise EHttpError.Create('WebSocket: invalid close frame payload');

  LCode := (UInt16(Ord(APayload[1])) shl 8) or UInt16(Ord(APayload[2]));
  if not IsValidCloseCode(LCode) then
    raise EHttpError.Create('WebSocket: invalid close code');
  if (Length(APayload) > 2) and
     (not UTF8IsValid(PByte(@APayload[3]), SizeUInt(Length(APayload) - 2))) then
    raise EHttpError.Create('WebSocket: invalid close reason encoding');
end;

procedure ValidateTextPayload(const APayload: string);
begin
  if Length(APayload) = 0 then
    Exit;
  if not UTF8IsValid(PByte(@APayload[1]), SizeUInt(Length(APayload))) then
    raise EHttpError.Create('WebSocket: invalid text payload encoding');
end;

function SizeExceedsLimit(const ASize: UInt64; const ALimit: Int64): Boolean;
begin
  Result := (ALimit > 0) and (ASize > UInt64(ALimit));
end;

function CombinedSizeExceedsLimit(const ACurrent, AAdd: UInt64;
  const ALimit: Int64): Boolean;
begin
  if ALimit <= 0 then
    Exit(False);
  if AAdd > UInt64(ALimit) then
    Exit(True);
  if ACurrent > UInt64(ALimit) - AAdd then
    Exit(True);
  Result := False;
end;

procedure ValidateControlPayloadSize(const APayload: string);
begin
  if Length(APayload) > 125 then
    raise EHttpError.Create('WebSocket: control frame payload too large');
end;

{ UpgradeWebSocket }

function UpgradeWebSocket(const AReq: IHttpRequest;
  const AW: IHttpResponseWriter): IWebSocket;
begin
  Result := UpgradeWebSocket(AReq, AW, TWebSocketOptions.Default);
end;

function UpgradeWebSocket(const AReq: IHttpRequest; const AW: IHttpResponseWriter;
  const AOptions: TWebSocketOptions): IWebSocket;
var
  LUpgrade, LKey, LVersion, LOrigin: string;
  LConnectionValues, LKeyValues: TStringArray;
  LAccept: string;
  LResp: string;
  LHijacker: IHttpHijacker;
  LConn: ITcpStream;
begin
  if AReq = nil then
    raise EArgumentError.Create('WebSocket upgrade request is nil');
  if AW = nil then
    raise EArgumentError.Create('WebSocket upgrade response writer is nil');
  ValidateWebSocketOptions(AOptions);

  LUpgrade := LowerTrimOWS(AReq.Headers.Get('upgrade'));
  LConnectionValues := AReq.Headers.GetAll('connection');
  LKeyValues := AReq.Headers.GetAll('sec-websocket-key');
  if Length(LKeyValues) = 1 then
    LKey := TrimOWS(LKeyValues[0])
  else
    LKey := '';
  LVersion := TrimOWS(AReq.Headers.Get('sec-websocket-version'));

  { RFC 6455 Section 4.1: request must be GET with HTTP/1.1 }
  if AReq.Method <> hmGet then
    raise EHttpError.Create('WebSocket upgrade requires GET method');
  if AReq.Version <> hvHttp11 then
    raise EHttpError.Create('WebSocket upgrade requires HTTP/1.1');

  if LUpgrade <> 'websocket' then
    raise EHttpError.Create('Missing or invalid Upgrade header');
  if not HeaderValuesHaveToken(LConnectionValues, 'upgrade') then
    raise EHttpError.Create('Missing or invalid Connection header');
  if LKey = '' then
    raise EHttpError.Create('Missing Sec-WebSocket-Key header');
  ValidateHandshakeKey(LKey);
  if LVersion <> '13' then
    raise EHttpError.Create('Unsupported Sec-WebSocket-Version');

  { Origin validation }
  LOrigin := AReq.Headers.Get('origin');
  if Assigned(AOptions.OnCheckOrigin) then
  begin
    if not AOptions.OnCheckOrigin(LOrigin) then
      raise EHttpError.Create('WebSocket: origin not allowed');
  end
  else
  begin
    { Default: reject Origin: null (common non-browser bypass technique).
      Browsers always send a valid Origin; `null` typically indicates
      a sandboxed iframe or a non-browser client trying to evade checks.
      Also reject empty Origin as it indicates a non-browser client. }
    if (LOrigin = 'null') or (LOrigin = '') then
      raise EHttpError.Create('WebSocket: Origin must be present and non-null');
  end;

  { Hijack the connection }
  if not Supports(AW, IHttpHijacker, LHijacker) then
    raise EHttpError.Create('Response writer does not support connection hijack');
  LConn := LHijacker.Hijack;

  LAccept := ComputeAcceptKey(LKey);

  LResp := 'HTTP/1.1 101 Switching Protocols'#13#10 +
           'Upgrade: websocket'#13#10 +
           'Connection: Upgrade'#13#10 +
           'Sec-WebSocket-Accept: ' + LAccept + #13#10 +
           #13#10;
  try
    IoWriteAll(LConn as IWriter, LResp[1], SizeUInt(Length(LResp)));
  except
    LConn.Close;
    raise;
  end;

  Result := TWebSocketImpl.Create(LConn as IReader, LConn as IWriter, AOptions);
end;

{ TWebSocketImpl }

constructor TWebSocketImpl.Create(const AReader: IReader; const AWriter: IWriter;
  const AOptions: TWebSocketOptions; AIsClient: Boolean);
begin
  inherited Create;
  FReader := AReader;
  FWriter := AWriter;
  FOptions := AOptions;
  FIsClient := AIsClient;
  FOpen := True;
  FCloseReceived := False;
  FCloseSent := False;
  FFragmentOpen := False;
  FFragmentOpcode := wsOpContinuation;
  FFragmentPayloadSize := 0;
  FFragmentTextPayload := '';
end;

procedure TWebSocketImpl.ReadExact(var ABuf; ACount: SizeUInt);
var
  LPtr: PByte;
  LRead: SizeUInt;
begin
  LPtr := @ABuf;
  while ACount > 0 do
  begin
    LRead := FReader.Read(LPtr^, ACount);
    if LRead = 0 then
      raise EHttpError.Create('WebSocket: unexpected end of stream');
    Inc(LPtr, LRead);
    Dec(ACount, LRead);
  end;
end;

function TWebSocketImpl.ReadFrame: TWebSocketFrame;
var
  LHdr: array[0..1] of Byte;
  LPayloadLen: UInt64;
  LExtLen: array[0..7] of Byte;
  LMaskKey: array[0..3] of Byte;
  LMasked: Boolean;
  LOpcode: Byte;
  LBuf: string;
  I: SizeUInt;
begin
  Result := Default(TWebSocketFrame);
  if not FOpen then
    raise EHttpError.Create('WebSocket: connection closed');

  ReadExact(LHdr[0], 2);
  Result.Fin := (LHdr[0] and $80) <> 0;
  if (LHdr[0] and $70) <> 0 then
    raise EHttpError.Create('WebSocket: reserved bits set');
  LOpcode := LHdr[0] and $0F;
  if not IsValidOpcode(LOpcode) then
    raise EHttpError.Create('WebSocket: reserved or invalid opcode');
  if (LOpcode >= $08) and (not Result.Fin) then
    raise EHttpError.Create('WebSocket: control frames must not be fragmented');
  if (LOpcode = Byte(wsOpContinuation)) and (not FFragmentOpen) then
    raise EHttpError.Create('WebSocket: unexpected continuation frame');
  if (LOpcode in [Byte(wsOpText), Byte(wsOpBinary)]) and FFragmentOpen then
    raise EHttpError.Create('WebSocket: data frame interrupts fragmented message');
  Result.Opcode := TWebSocketOpcode(LOpcode);
  LMasked := (LHdr[1] and $80) <> 0;
  LPayloadLen := LHdr[1] and $7F;

  { RFC 6455 §5.3: Client frames MUST be masked, server frames MUST NOT be masked }
  if FIsClient then
  begin
    if LMasked then
      raise EHttpError.Create('WebSocket: server frames must not be masked');
  end
  else
  begin
    if not LMasked then
      raise EHttpError.Create('WebSocket: client frames must be masked');
  end;

  if LPayloadLen = 126 then
  begin
    ReadExact(LExtLen[0], 2);
    LPayloadLen := (UInt64(LExtLen[0]) shl 8) or UInt64(LExtLen[1]);
    if LPayloadLen < 126 then
      raise EHttpError.Create('WebSocket: non-canonical payload length');
  end
  else if LPayloadLen = 127 then
  begin
    ReadExact(LExtLen[0], 8);
    if (LExtLen[0] and $80) <> 0 then
      raise EHttpError.Create('WebSocket: invalid 64-bit payload length');
    LPayloadLen := 0;
    for I := 0 to 7 do
      LPayloadLen := (LPayloadLen shl 8) or UInt64(LExtLen[I]);
    if LPayloadLen < 65536 then
      raise EHttpError.Create('WebSocket: non-canonical payload length');
  end;

  if (LOpcode >= $08) and (LPayloadLen > 125) then
    raise EHttpError.Create('WebSocket: control frame payload too large');

  if SizeExceedsLimit(LPayloadLen, FOptions.MaxFrameSize) then
    raise EHttpError.Create('WebSocket: frame too large');
  if LPayloadLen > UInt64(High(SizeInt)) then
    raise EHttpError.Create('WebSocket: frame exceeds platform capacity');
  if LOpcode in [Byte(wsOpText), Byte(wsOpBinary)] then
  begin
    if SizeExceedsLimit(LPayloadLen, FOptions.MaxMessageSize) then
      raise EHttpError.Create('WebSocket: message too large');
  end
  else if LOpcode = Byte(wsOpContinuation) then
  begin
    if CombinedSizeExceedsLimit(FFragmentPayloadSize, LPayloadLen,
       FOptions.MaxMessageSize) then
      raise EHttpError.Create('WebSocket: message too large');
  end;

  if LMasked then
    ReadExact(LMaskKey[0], 4);

  SetLength(LBuf, LPayloadLen);
  if LPayloadLen > 0 then
  begin
    ReadExact(LBuf[1], SizeUInt(LPayloadLen));
    if LMasked then
      for I := 0 to SizeUInt(LPayloadLen) - 1 do
        LBuf[I + 1] := Chr(Ord(LBuf[I + 1]) xor LMaskKey[I mod 4]);
  end;

  Result.Payload := LBuf;

  if Result.Opcode = wsOpClose then
  begin
    ValidateClosePayload(Result.Payload);
    FCloseReceived := True;
  end;

  if Result.Opcode = wsOpContinuation then
  begin
    if FFragmentOpcode = wsOpText then
    begin
      FFragmentTextPayload := FFragmentTextPayload + Result.Payload;
      if Result.Fin then
        ValidateTextPayload(FFragmentTextPayload);
    end;
    if Result.Fin then
    begin
      FFragmentOpen := False;
      FFragmentOpcode := wsOpContinuation;
      FFragmentPayloadSize := 0;
      FFragmentTextPayload := '';
    end
    else
      Inc(FFragmentPayloadSize, LPayloadLen);
  end
  else if Result.Opcode in [wsOpText, wsOpBinary] then
  begin
    if Result.Fin then
    begin
      if Result.Opcode = wsOpText then
        ValidateTextPayload(Result.Payload);
    end
    else
    begin
      FFragmentOpen := True;
      FFragmentOpcode := Result.Opcode;
      FFragmentPayloadSize := LPayloadLen;
      if Result.Opcode = wsOpText then
        FFragmentTextPayload := Result.Payload
      else
        FFragmentTextPayload := '';
    end;
  end;
end;

function TWebSocketImpl.ReadMessage: TWebSocketFrame;
var
  LFrame: TWebSocketFrame;
  LPayload: string;
  LMessageOpcode: TWebSocketOpcode;
begin
  { Read frames until we get a complete data message }
  while True do
  begin
    LFrame := ReadFrame;

    case LFrame.Opcode of
      wsOpPing:
      begin
        { RFC 6455 §5.5.2: MUST respond to Ping with Pong }
        Pong(LFrame.Payload);
        { Continue reading for the actual message }
      end;

      wsOpPong:
      begin
        { Unsolicited pong — ignore and continue }
      end;

      wsOpClose:
      begin
        { Close frame — pass it through }
        Result := LFrame;
        Exit;
      end;

      wsOpText, wsOpBinary:
      begin
        if LFrame.Fin then
        begin
          { Single-frame message — return directly }
          Result := LFrame;
          Exit;
        end
        else
        begin
          { First fragment — collect continuation frames }
          LMessageOpcode := LFrame.Opcode;
          LPayload := LFrame.Payload;
          while True do
          begin
            LFrame := ReadFrame;
            if LFrame.Opcode = wsOpPing then
            begin
              Pong(LFrame.Payload);
              Continue;
            end;
            if LFrame.Opcode = wsOpPong then
              Continue;
            if LFrame.Opcode = wsOpClose then
            begin
              Result := LFrame;
              Exit;
            end;
            if LFrame.Opcode <> wsOpContinuation then
              raise EHttpError.Create('WebSocket: expected continuation frame');
            LPayload := LPayload + LFrame.Payload;
            if LFrame.Fin then
            begin
              Result.Opcode := LMessageOpcode;
              Result.Fin := True;
              Result.Payload := LPayload;
              Exit;
            end;
          end;
        end;
      end;

      wsOpContinuation:
        raise EHttpError.Create('WebSocket: unexpected continuation frame');
    end;
  end;
end;

procedure TWebSocketImpl.WriteFrameRaw(AOpcode: TWebSocketOpcode; const APayload: string);
var
  LHdr: array[0..9] of Byte;
  LHdrLen: Integer;
  LPayloadLen: SizeUInt;
  LMaskKey: array[0..3] of Byte;
  LMaskedPayload: string;
  I: SizeUInt;
begin
  LPayloadLen := SizeUInt(Length(APayload));

  LHdr[0] := $80 or Byte(AOpcode); { FIN + opcode }

  { RFC 6455 §5.3: Client frames MUST be masked }
  if FIsClient then
  begin
    { Generate cryptographically secure random mask key }
    SecureRandomBytes(@LMaskKey[0], 4);

    if LPayloadLen < 126 then
    begin
      LHdr[1] := $80 or Byte(LPayloadLen); { MASK bit set }
      LHdr[2] := LMaskKey[0];
      LHdr[3] := LMaskKey[1];
      LHdr[4] := LMaskKey[2];
      LHdr[5] := LMaskKey[3];
      LHdrLen := 6;
    end
    else if LPayloadLen < 65536 then
    begin
      LHdr[1] := $80 or 126; { MASK bit set }
      LHdr[2] := Byte(LPayloadLen shr 8);
      LHdr[3] := Byte(LPayloadLen);
      LHdr[4] := LMaskKey[0];
      LHdr[5] := LMaskKey[1];
      LHdr[6] := LMaskKey[2];
      LHdr[7] := LMaskKey[3];
      LHdrLen := 8;
    end
    else
    begin
      LHdr[1] := $80 or 127; { MASK bit set }
      LHdr[2] := Byte(UInt64(LPayloadLen) shr 56);
      LHdr[3] := Byte(UInt64(LPayloadLen) shr 48);
      LHdr[4] := Byte(UInt64(LPayloadLen) shr 40);
      LHdr[5] := Byte(UInt64(LPayloadLen) shr 32);
      LHdr[6] := Byte(LPayloadLen shr 24);
      LHdr[7] := Byte(LPayloadLen shr 16);
      LHdr[8] := Byte(LPayloadLen shr 8);
      LHdr[9] := Byte(LPayloadLen);
      LHdrLen := 10;
      { Mask key goes after 10-byte header }
    end;

    IoWriteAll(FWriter, LHdr[0], SizeUInt(LHdrLen));

    { Write mask key if 64-bit length }
    if LPayloadLen >= 65536 then
      IoWriteAll(FWriter, LMaskKey[0], 4);

    { Write masked payload }
    if LPayloadLen > 0 then
    begin
      SetLength(LMaskedPayload, LPayloadLen);
      for I := 0 to LPayloadLen - 1 do
        LMaskedPayload[I + 1] := Chr(Ord(APayload[I + 1]) xor LMaskKey[I mod 4]);
      IoWriteAll(FWriter, LMaskedPayload[1], LPayloadLen);
    end;
  end
  else
  begin
    { Server frames: no masking }
    if LPayloadLen < 126 then
    begin
      LHdr[1] := Byte(LPayloadLen);
      LHdrLen := 2;
    end
    else if LPayloadLen < 65536 then
    begin
      LHdr[1] := 126;
      LHdr[2] := Byte(LPayloadLen shr 8);
      LHdr[3] := Byte(LPayloadLen);
      LHdrLen := 4;
    end
    else
    begin
      LHdr[1] := 127;
      LHdr[2] := Byte(UInt64(LPayloadLen) shr 56);
      LHdr[3] := Byte(UInt64(LPayloadLen) shr 48);
      LHdr[4] := Byte(UInt64(LPayloadLen) shr 40);
      LHdr[5] := Byte(UInt64(LPayloadLen) shr 32);
      LHdr[6] := Byte(LPayloadLen shr 24);
      LHdr[7] := Byte(LPayloadLen shr 16);
      LHdr[8] := Byte(LPayloadLen shr 8);
      LHdr[9] := Byte(LPayloadLen);
      LHdrLen := 10;
    end;

    IoWriteAll(FWriter, LHdr[0], SizeUInt(LHdrLen));
    if LPayloadLen > 0 then
      IoWriteAll(FWriter, APayload[1], LPayloadLen);
  end;
end;

procedure TWebSocketImpl.WriteFrame(AOpcode: TWebSocketOpcode; const APayload: string);
begin
  if not IsOpen then
    raise EHttpError.Create('WebSocket: connection closed');
  if AOpcode in [wsOpClose, wsOpPing, wsOpPong] then
    ValidateControlPayloadSize(APayload);
  WriteFrameRaw(AOpcode, APayload);
end;

procedure TWebSocketImpl.WriteText(const AData: string);
begin
  ValidateTextPayload(AData);
  WriteFrame(wsOpText, AData);
end;

procedure TWebSocketImpl.WriteBinary(const AData: string);
begin
  WriteFrame(wsOpBinary, AData);
end;

procedure TWebSocketImpl.Ping(const AData: string);
begin
  WriteFrame(wsOpPing, AData);
end;

procedure TWebSocketImpl.Pong(const AData: string);
begin
  WriteFrame(wsOpPong, AData);
end;

procedure TWebSocketImpl.Close(const ACode: UInt16; const AReason: string);
var
  LPayload: string;
begin
  if FCloseSent then
    Exit; { Already sent close }
  SetLength(LPayload, 2 + Length(AReason));
  LPayload[1] := Chr(ACode shr 8);
  LPayload[2] := Chr(ACode and $FF);
  if Length(AReason) > 0 then
    Move(AReason[1], LPayload[3], Length(AReason));
  ValidateControlPayloadSize(LPayload);
  ValidateClosePayload(LPayload);
  FCloseSent := True;
  FOpen := False;
  WriteFrameRaw(wsOpClose, LPayload);
end;

function TWebSocketImpl.IsOpen: Boolean;
begin
  Result := FOpen and (not FCloseSent) and (not FCloseReceived);
end;

{ ConnectWebSocket helpers }

function GenerateWebSocketKey: string;
var
  LBytes: TBytes;
begin
  SetLength(LBytes, 16);
  SecureRandomBytes(@LBytes[0], 16);
  Result := Base64Encode(LBytes);
end;

function ValidateAcceptKey(const AKey, AAccept: string): Boolean;
var
  LConcat: string;
  LDigest: TSHA1Digest;
  LBytes: TBytes;
  LExpected: string;
begin
  LConcat := AKey + WS_GUID;
  LDigest := SHA1Of(LConcat[1], SizeUInt(Length(LConcat)));
  SetLength(LBytes, SHA1_DIGEST_SIZE);
  Move(LDigest[0], LBytes[0], SHA1_DIGEST_SIZE);
  LExpected := Base64Encode(LBytes);
  Result := AAccept = LExpected;
end;

procedure ReadHttpResponse(const AReader: IReader;
  out AStatusCode: Integer; out AHeaders: TStringArray);
const
  MAX_STATUS_LINE_SIZE = 4096;
  MAX_HEADER_LINE_SIZE = 8192;
  MAX_HEADER_BYTES = 65536;
  MAX_HEADER_COUNT = 256;
var
  LLine: string;
  LCh: Char;
  LLen: Integer;
  LHeaderCount: Integer;
  LHeaderBytes: SizeUInt;
begin
  AStatusCode := 0;
  LHeaderCount := 0;
  LHeaderBytes := 0;
  SetLength(AHeaders, 16);

  { Read status line }
  LLine := '';
  repeat
    LLen := AReader.Read(LCh, 1);
    if LLen = 0 then
      raise EHttpError.Create('WebSocket: unexpected end of stream reading response');
    if LCh <> #10 then
      LLine := LLine + LCh;
  until (LCh = #10) or (Length(LLine) > MAX_STATUS_LINE_SIZE);
  if Length(LLine) > MAX_STATUS_LINE_SIZE then
    raise EHttpError.Create('WebSocket: HTTP status line too large');

  { Remove trailing CR }
  if (Length(LLine) > 0) and (LLine[Length(LLine)] = #13) then
    LLine := Copy(LLine, 1, Length(LLine) - 1);

  { Parse status code }
  if Copy(LLine, 1, 8) <> 'HTTP/1.1' then
    raise EHttpError.Create('WebSocket: invalid HTTP response');
  if Length(LLine) < 12 then
    raise EHttpError.Create('WebSocket: invalid HTTP response');
  AStatusCode := StrToIntDef(Copy(LLine, 10, 3), 0);

  { Read headers }
  repeat
    LLine := '';
    repeat
      LLen := AReader.Read(LCh, 1);
      if LLen = 0 then
        raise EHttpError.Create('WebSocket: unexpected end of stream reading headers');
      if LCh <> #10 then
        LLine := LLine + LCh;
    until (LCh = #10) or (Length(LLine) > MAX_HEADER_LINE_SIZE);
    if Length(LLine) > MAX_HEADER_LINE_SIZE then
      raise EHttpError.Create('WebSocket: HTTP response header line too large');

    { Remove trailing CR }
    if (Length(LLine) > 0) and (LLine[Length(LLine)] = #13) then
      LLine := Copy(LLine, 1, Length(LLine) - 1);

    { Empty line marks end of headers }
    if LLine = '' then
      Break;

    Inc(LHeaderBytes, SizeUInt(Length(LLine)) + 2);
    if LHeaderBytes > MAX_HEADER_BYTES then
      raise EHttpError.Create('WebSocket: HTTP response headers too large');
    if LHeaderCount >= MAX_HEADER_COUNT then
      raise EHttpError.Create('WebSocket: too many HTTP response headers');

    { Store header }
    if LHeaderCount >= Length(AHeaders) then
      SetLength(AHeaders, LHeaderCount + 16);
    AHeaders[LHeaderCount] := LLine;
    Inc(LHeaderCount);
  until False;

  SetLength(AHeaders, LHeaderCount);
end;

function FindHeader(const AHeaders: TStringArray; const AName: string): string;
var
  I: Integer;
  LLine: string;
  LNameLower: string;
begin
  Result := '';
  LNameLower := LowerCase(AName);
  for I := 0 to High(AHeaders) do
  begin
    LLine := AHeaders[I];
    if Length(LLine) > Length(AName) + 1 then
    begin
      if (LowerCase(Copy(LLine, 1, Length(AName) + 1)) = LNameLower + ':') or
         (LowerCase(Copy(LLine, 1, Length(AName) + 2)) = LNameLower + ': ') then
      begin
        if LLine[Length(AName) + 1] = ':' then
          LLine := TrimOWS(Copy(LLine, Length(AName) + 2, MaxInt))
        else
          LLine := TrimOWS(Copy(LLine, Length(AName) + 3, MaxInt));
        if Result = '' then
          Result := LLine
        else
          Result := Result + ', ' + LLine;
      end;
    end;
  end;
end;

{ ConnectWebSocket implementation }

function ConnectWebSocket(const AUrl: string): IWebSocket;
begin
  Result := ConnectWebSocket(AUrl, TWebSocketOptions.Default);
end;

function ConnectWebSocket(const AUrl: string;
  const AOptions: TWebSocketOptions): IWebSocket;
var
  LClient: IHttpClient;
begin
  LClient := NewHttpClient;
  Result := ConnectWebSocket(LClient, AUrl, AOptions);
end;

function ConnectWebSocket(const AClient: IHttpClient;
  const AUrl: string): IWebSocket;
begin
  Result := ConnectWebSocket(AClient, AUrl, TWebSocketOptions.Default);
end;

function ConnectWebSocket(const AClient: IHttpClient;
  const AUrl: string;
  const AOptions: TWebSocketOptions): IWebSocket;
var
  LParsedUrl: TUrl;
  LScheme, LHost, LPath, LKey, LAccept: string;
  LPort: UInt16;
  LConn, LTlsConn: ITcpStream;
  LReader: IReader;
  LWriter: IWriter;
  LRequest: string;
  LStatusCode: Integer;
  LHeaders: TStringArray;
  LUpgrade, LConnection, LAcceptHeader: string;
begin
  if AClient = nil then
    raise EArgumentError.Create('WebSocket client is nil');
  if AUrl = '' then
    raise EArgumentError.Create('WebSocket URL is empty');
  ValidateWebSocketOptions(AOptions);

  { Parse URL }
  LParsedUrl := TUrl.Parse(AUrl);
  LScheme := LowerCase(LParsedUrl.Scheme);
  LHost := LParsedUrl.Host;
  LPath := LParsedUrl.Path;
  if LPath = '' then
    LPath := '/';

  { Validate scheme }
  if (LScheme <> 'ws') and (LScheme <> 'wss') then
    raise EHttpError.Create('WebSocket: invalid scheme (expected ws:// or wss://)');

  { Validate host and path for CRLF injection }
  if (Pos(#13, LHost) > 0) or (Pos(#10, LHost) > 0) then
    raise EHttpError.Create('WebSocket: CRLF in host');
  if (Pos(#13, LPath) > 0) or (Pos(#10, LPath) > 0) then
    raise EHttpError.Create('WebSocket: CRLF in path');

  { Include query string in request target }
  if LParsedUrl.RawQuery <> '' then
    LPath := LPath + '?' + LParsedUrl.RawQuery;

  { Determine port }
  LPort := LParsedUrl.Port;
  if LPort = 0 then
  begin
    if LScheme = 'wss' then
      LPort := 443
    else
      LPort := 80;
  end;

  { Establish TCP connection }
  LConn := TcpConnect(LHost, LPort);
  if LConn = nil then
    raise EHttpError.Create('WebSocket: failed to connect to ' + LHost + ':' + IntToStr(LPort));

  { Wrap with TLS if wss:// }
  if LScheme = 'wss' then
  begin
    LTlsConn := NewTlsClientTcpStream(LConn, nil, LHost, 'http/1.1');
    LReader := LTlsConn as IReader;
    LWriter := LTlsConn as IWriter;
  end
  else
  begin
    LReader := LConn as IReader;
    LWriter := LConn as IWriter;
  end;

  { Generate Sec-WebSocket-Key }
  LKey := GenerateWebSocketKey;

  { Build upgrade request }
  LRequest := 'GET ' + LPath + ' HTTP/1.1'#13#10 +
              'Host: ' + LHost;
  if (LScheme = 'ws') and (LPort <> 80) then
    LRequest := LRequest + ':' + IntToStr(LPort)
  else if (LScheme = 'wss') and (LPort <> 443) then
    LRequest := LRequest + ':' + IntToStr(LPort);
  LRequest := LRequest + #13#10 +
              'Upgrade: websocket'#13#10 +
              'Connection: Upgrade'#13#10 +
              'Sec-WebSocket-Key: ' + LKey + #13#10 +
              'Sec-WebSocket-Version: 13'#13#10 +
              #13#10;

  { Send upgrade request }
  IoWriteAll(LWriter, LRequest[1], SizeUInt(Length(LRequest)));

  { Read response }
  ReadHttpResponse(LReader, LStatusCode, LHeaders);

  { Validate response }
  if LStatusCode <> 101 then
    raise EHttpError.Create('WebSocket: expected 101, got ' + IntToStr(LStatusCode));

  LUpgrade := LowerCase(FindHeader(LHeaders, 'Upgrade'));
  LConnection := LowerCase(FindHeader(LHeaders, 'Connection'));
  LAcceptHeader := FindHeader(LHeaders, 'Sec-WebSocket-Accept');

  if not HeaderValueHasToken(LUpgrade, 'websocket') then
    raise EHttpError.Create('WebSocket: invalid Upgrade header');
  if not HeaderValueHasToken(LConnection, 'upgrade') then
    raise EHttpError.Create('WebSocket: invalid Connection header');
  if LAcceptHeader = '' then
    raise EHttpError.Create('WebSocket: missing Sec-WebSocket-Accept header');

  { Validate Accept key }
  if not ValidateAcceptKey(LKey, LAcceptHeader) then
    raise EHttpError.Create('WebSocket: invalid Sec-WebSocket-Accept');

  { Create WebSocket client }
  Result := TWebSocketImpl.Create(LReader, LWriter, AOptions, True);
end;

initialization
  Randomize;

end.
