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
    procedure WriteText(const AData: string);
    procedure WriteBinary(const AData: string);
    procedure Ping(const AData: string);
    procedure Pong(const AData: string);
    procedure Close(const ACode: UInt16; const AReason: string);
    function IsOpen: Boolean;
  end;

{ Upgrade an HTTP connection to WebSocket.
  Validates Upgrade headers, sends 101 response, returns IWebSocket.
  The response writer must support IHttpHijacker to obtain the raw connection.
  Raises EHttpError if upgrade fails. }
function UpgradeWebSocket(const AReq: IHttpRequest;
  const AW: IHttpResponseWriter): IWebSocket;

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.base,
  nextpas.core.hash,
  nextpas.core.hash.base,
  nextpas.core.encoding,
  nextpas.core.net.intf;

const
  WS_GUID = '258EAFA5-E914-47DA-95CA-5AB53DC85B11';

type
  TWebSocketImpl = class(TInterfacedObject, IWebSocket)
  private
    FReader: IReader;
    FWriter: IWriter;
    FOpen: Boolean;
    FCloseReceived: Boolean;
    FCloseSent: Boolean;
    procedure WriteFrame(AOpcode: TWebSocketOpcode; const APayload: string);
    procedure WriteFrameRaw(AOpcode: TWebSocketOpcode; const APayload: string);
    procedure ReadExact(var ABuf; ACount: SizeUInt);
  public
    constructor Create(const AReader: IReader; const AWriter: IWriter);
    function ReadFrame: TWebSocketFrame;
    procedure WriteText(const AData: string);
    procedure WriteBinary(const AData: string);
    procedure Ping(const AData: string);
    procedure Pong(const AData: string);
    procedure Close(const ACode: UInt16; const AReason: string);
    function IsOpen: Boolean;
  end;

{ Helpers }

function LowerCase(const S: string): string;
var
  I: Integer;
begin
  SetLength(Result, Length(S));
  for I := 1 to Length(S) do
    if (S[I] >= 'A') and (S[I] <= 'Z') then
      Result[I] := Chr(Ord(S[I]) + 32)
    else
      Result[I] := S[I];
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
end;

{ UpgradeWebSocket }

function UpgradeWebSocket(const AReq: IHttpRequest;
  const AW: IHttpResponseWriter): IWebSocket;
var
  LUpgrade, LConnection, LKey, LVersion: string;
  LAccept: string;
  LResp: string;
  LHijacker: IHttpHijacker;
  LConn: ITcpStream;
begin
  LUpgrade := LowerCase(AReq.Headers.Get('upgrade'));
  LConnection := LowerCase(AReq.Headers.Get('connection'));
  LKey := AReq.Headers.Get('sec-websocket-key');
  LVersion := AReq.Headers.Get('sec-websocket-version');

  if LUpgrade <> 'websocket' then
    raise EHttpError.Create('Missing or invalid Upgrade header');
  if Pos('upgrade', LConnection) = 0 then
    raise EHttpError.Create('Missing or invalid Connection header');
  if LKey = '' then
    raise EHttpError.Create('Missing Sec-WebSocket-Key header');
  if LVersion <> '13' then
    raise EHttpError.Create('Unsupported Sec-WebSocket-Version');

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
  LConn.Write(LResp[1], SizeUInt(Length(LResp)));

  Result := TWebSocketImpl.Create(LConn as IReader, LConn as IWriter);
end;

{ TWebSocketImpl }

constructor TWebSocketImpl.Create(const AReader: IReader; const AWriter: IWriter);
begin
  inherited Create;
  FReader := AReader;
  FWriter := AWriter;
  FOpen := True;
  FCloseReceived := False;
  FCloseSent := False;
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
  LOpcode := LHdr[0] and $0F;
  if not IsValidOpcode(LOpcode) then
    raise EHttpError.Create('WebSocket: reserved or invalid opcode');
  if (LOpcode >= $08) and (not Result.Fin) then
    raise EHttpError.Create('WebSocket: control frames must not be fragmented');
  Result.Opcode := TWebSocketOpcode(LOpcode);
  LMasked := (LHdr[1] and $80) <> 0;
  LPayloadLen := LHdr[1] and $7F;

  if not LMasked then
    raise EHttpError.Create('WebSocket: client frames must be masked');

  if LPayloadLen = 126 then
  begin
    ReadExact(LExtLen[0], 2);
    LPayloadLen := (UInt64(LExtLen[0]) shl 8) or UInt64(LExtLen[1]);
  end
  else if LPayloadLen = 127 then
  begin
    ReadExact(LExtLen[0], 8);
    LPayloadLen := 0;
    for I := 0 to 7 do
      LPayloadLen := (LPayloadLen shl 8) or UInt64(LExtLen[I]);
  end;

  if (LOpcode >= $08) and (LPayloadLen > 125) then
    raise EHttpError.Create('WebSocket: control frame payload too large');

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
end;

procedure TWebSocketImpl.WriteFrameRaw(AOpcode: TWebSocketOpcode; const APayload: string);
var
  LHdr: array[0..9] of Byte;
  LHdrLen: Integer;
  LPayloadLen: SizeUInt;
begin
  LPayloadLen := SizeUInt(Length(APayload));

  LHdr[0] := $80 or Byte(AOpcode); { FIN + opcode }
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
    LHdr[2] := 0; LHdr[3] := 0; LHdr[4] := 0; LHdr[5] := 0;
    LHdr[6] := Byte(LPayloadLen shr 24);
    LHdr[7] := Byte(LPayloadLen shr 16);
    LHdr[8] := Byte(LPayloadLen shr 8);
    LHdr[9] := Byte(LPayloadLen);
    LHdrLen := 10;
  end;

  FWriter.Write(LHdr[0], SizeUInt(LHdrLen));
  if LPayloadLen > 0 then
    FWriter.Write(APayload[1], LPayloadLen);
end;

procedure TWebSocketImpl.WriteFrame(AOpcode: TWebSocketOpcode; const APayload: string);
begin
  if not FOpen then
    raise EHttpError.Create('WebSocket: connection closed');
  WriteFrameRaw(AOpcode, APayload);
end;

procedure TWebSocketImpl.WriteText(const AData: string);
begin
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
  FCloseSent := True;
  FOpen := False;
  WriteFrameRaw(wsOpClose, LPayload);
end;

function TWebSocketImpl.IsOpen: Boolean;
begin
  Result := FOpen and (not FCloseSent) and (not FCloseReceived);
end;

end.
