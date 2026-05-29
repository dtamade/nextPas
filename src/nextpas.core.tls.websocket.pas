unit nextpas.core.tls.websocket;

{$mode objfpc}{$H+}{$J-}

interface

uses
  SysUtils, Classes, nextpas.core.tls.base;

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
    FIN: Boolean;
    Opcode: TWebSocketOpcode;
    Masked: Boolean;
    PayloadLength: UInt64;
    MaskKey: array[0..3] of Byte;
    Payload: TBytes;
  end;

  TWebSocketConnection = class
  private
    FStream: TStream;
    FIsClient: Boolean;
  public
    constructor Create(AStream: TStream; AIsClient: Boolean);
    function SendText(const AText: string): Boolean;
    function SendBinary(const AData: TBytes): Boolean;
    function SendPing(const AData: TBytes): Boolean;
    function SendClose(ACode: Word; const AReason: string): Boolean;
    function ReadFrame(out AFrame: TWebSocketFrame): Boolean;
    function BuildUpgradeRequest(const AHost, APath: string; out AKey: string): string;
    class function ValidateUpgradeResponse(const AResponse, AKey: string): Boolean;
  end;

implementation

uses
  nextpas.core.tls.base64, nextpas.core.tls.crypto.hash, nextpas.core.tls.random;

const
  WS_GUID = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11';

constructor TWebSocketConnection.Create(AStream: TStream; AIsClient: Boolean);
begin
  inherited Create;
  FStream := AStream;
  FIsClient := AIsClient;
end;

function BuildFrame(AOpcode: TWebSocketOpcode; const APayload: TBytes; AMask: Boolean): TBytes;
var
  LHeaderLen, LPayloadLen, I: Integer;
  LMaskKey: array[0..3] of Byte;
begin
  LPayloadLen := Length(APayload);

  if LPayloadLen < 126 then
    LHeaderLen := 2
  else if LPayloadLen < 65536 then
    LHeaderLen := 4
  else
    LHeaderLen := 10;

  if AMask then Inc(LHeaderLen, 4);

  SetLength(Result, LHeaderLen + LPayloadLen);

  Result[0] := $80 or Byte(AOpcode); // FIN + opcode
  if LPayloadLen < 126 then
    Result[1] := Byte(LPayloadLen)
  else if LPayloadLen < 65536 then
  begin
    Result[1] := 126;
    Result[2] := Byte(LPayloadLen shr 8);
    Result[3] := Byte(LPayloadLen);
  end
  else
  begin
    Result[1] := 127;
    Result[2] := 0; Result[3] := 0; Result[4] := 0; Result[5] := 0;
    Result[6] := Byte(LPayloadLen shr 24);
    Result[7] := Byte(LPayloadLen shr 16);
    Result[8] := Byte(LPayloadLen shr 8);
    Result[9] := Byte(LPayloadLen);
  end;

  if AMask then
  begin
    Result[1] := Result[1] or $80;
    SecureRandomBytes(@LMaskKey[0], 4);
    Move(LMaskKey[0], Result[LHeaderLen - 4], 4);
    for I := 0 to LPayloadLen - 1 do
      Result[LHeaderLen + I] := APayload[I] xor LMaskKey[I mod 4];
  end
  else
  begin
    if LPayloadLen > 0 then
      Move(APayload[0], Result[LHeaderLen], LPayloadLen);
  end;
end;

function TWebSocketConnection.SendText(const AText: string): Boolean;
var
  LData, LFrame: TBytes;
begin
  LData := TEncoding.UTF8.GetBytes(AText);
  LFrame := BuildFrame(wsOpText, LData, FIsClient);
  FStream.WriteBuffer(LFrame[0], Length(LFrame));
  Result := True;
end;

function TWebSocketConnection.SendBinary(const AData: TBytes): Boolean;
var
  LFrame: TBytes;
begin
  LFrame := BuildFrame(wsOpBinary, AData, FIsClient);
  FStream.WriteBuffer(LFrame[0], Length(LFrame));
  Result := True;
end;

function TWebSocketConnection.SendPing(const AData: TBytes): Boolean;
var
  LFrame: TBytes;
begin
  LFrame := BuildFrame(wsOpPing, AData, FIsClient);
  FStream.WriteBuffer(LFrame[0], Length(LFrame));
  Result := True;
end;

function TWebSocketConnection.SendClose(ACode: Word; const AReason: string): Boolean;
var
  LPayload, LFrame: TBytes;
begin
  SetLength(LPayload, 2 + Length(AReason));
  LPayload[0] := Byte(ACode shr 8);
  LPayload[1] := Byte(ACode);
  if Length(AReason) > 0 then
    Move(AReason[1], LPayload[2], Length(AReason));
  LFrame := BuildFrame(wsOpClose, LPayload, FIsClient);
  FStream.WriteBuffer(LFrame[0], Length(LFrame));
  Result := True;
end;

function TWebSocketConnection.ReadFrame(out AFrame: TWebSocketFrame): Boolean;
var
  LHeader: TBytes;
  LRead, I: Integer;
  LLen: UInt64;
begin
  Result := False;
  SetLength(LHeader, 2);
  LRead := FStream.Read(LHeader[0], 2);
  if LRead < 2 then Exit;

  AFrame.FIN := (LHeader[0] and $80) <> 0;
  AFrame.Opcode := TWebSocketOpcode(LHeader[0] and $0F);
  AFrame.Masked := (LHeader[1] and $80) <> 0;
  LLen := LHeader[1] and $7F;

  if LLen = 126 then
  begin
    SetLength(LHeader, 2);
    if FStream.Read(LHeader[0], 2) < 2 then Exit;
    LLen := (UInt64(LHeader[0]) shl 8) or UInt64(LHeader[1]);
  end
  else if LLen = 127 then
  begin
    SetLength(LHeader, 8);
    if FStream.Read(LHeader[0], 8) < 8 then Exit;
    LLen := 0;
    for I := 0 to 7 do
      LLen := (LLen shl 8) or UInt64(LHeader[I]);
  end;

  AFrame.PayloadLength := LLen;

  if AFrame.Masked then
  begin
    if FStream.Read(AFrame.MaskKey[0], 4) < 4 then Exit;
  end;

  SetLength(AFrame.Payload, LLen);
  if LLen > 0 then
  begin
    LRead := FStream.Read(AFrame.Payload[0], LLen);
    if LRead < Integer(LLen) then Exit;
    if AFrame.Masked then
      for I := 0 to Integer(LLen) - 1 do
        AFrame.Payload[I] := AFrame.Payload[I] xor AFrame.MaskKey[I mod 4];
  end;

  Result := True;
end;

function TWebSocketConnection.BuildUpgradeRequest(const AHost, APath: string; out AKey: string): string;
var
  LKeyBytes: TBytes;
begin
  SetLength(LKeyBytes, 16);
  SecureRandomBytes(@LKeyBytes[0], 16);
  AKey := TBase64Utils.Encode(LKeyBytes);

  Result :=
    'GET ' + APath + ' HTTP/1.1'#13#10 +
    'Host: ' + AHost + #13#10 +
    'Upgrade: websocket'#13#10 +
    'Connection: Upgrade'#13#10 +
    'Sec-WebSocket-Key: ' + AKey + #13#10 +
    'Sec-WebSocket-Version: 13'#13#10 +
    #13#10;
end;

class function TWebSocketConnection.ValidateUpgradeResponse(const AResponse, AKey: string): Boolean;
var
  LExpected: string;
  LHash: TBytes;
begin
  LHash := SHA1(TEncoding.ASCII.GetBytes(AKey + WS_GUID));
  LExpected := TBase64Utils.Encode(LHash);
  Result := Pos(LExpected, AResponse) > 0;
end;

end.
