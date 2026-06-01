unit nextpas.core.websocket;
{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.websocket.base;

type
  TWebSocketRole = nextpas.core.websocket.base.TWebSocketRole;
  TWebSocketFrame = nextpas.core.websocket.base.TWebSocketFrame;
  TWebSocketMessage = nextpas.core.websocket.base.TWebSocketMessage;

{ Handshake }
function WebSocketAcceptKey(const AClientKey: string): string;
function WebSocketGenerateKey: string;

{ Frame encode/decode }
function WebSocketEncodeFrame(const AFrame: TWebSocketFrame; ARole: TWebSocketRole): TBytes;
function TryWebSocketDecodeFrame(const AData: TBytes; AOffset: SizeUInt;
  ARole: TWebSocketRole; out AFrame: TWebSocketFrame; out AConsumed: SizeUInt): Boolean;

{ Convenience frame builders }
function WebSocketTextFrame(const AText: string; ARole: TWebSocketRole): TBytes;
function WebSocketBinaryFrame(const AData: TBytes; ARole: TWebSocketRole): TBytes;
function WebSocketPingFrame(ARole: TWebSocketRole): TBytes;
function WebSocketPongFrame(const APingPayload: TBytes; ARole: TWebSocketRole): TBytes;
function WebSocketCloseFrame(ACode: UInt16; const AReason: string; ARole: TWebSocketRole): TBytes;

{ Masking }
procedure WebSocketMask(var AData: TBytes; const AMaskKey: array of Byte);

implementation

uses
  nextpas.core.hash.intf,
  nextpas.core.hash.sha1,
  nextpas.core.hash.base,
  nextpas.core.encoding.base64,
  nextpas.core.platform.random;

{ --- Handshake --- }

function WebSocketAcceptKey(const AClientKey: string): string;
var
  LInput: string;
  LHasher: IHasher;
  LDigest: TBytes;
  LInputBytes: TBytes;
begin
  LInput := AClientKey + WS_GUID;
  SetLength(LInputBytes, Length(LInput));
  Move(LInput[1], LInputBytes[0], Length(LInput));

  LHasher := NewSHA1;
  LHasher.Write(LInputBytes[0], Length(LInputBytes));
  SetLength(LDigest, SHA1_DIGEST_SIZE);
  LHasher.Sum(LDigest[0], SHA1_DIGEST_SIZE);

  Result := Base64Encode(LDigest);
end;

function WebSocketGenerateKey: string;
var
  LBytes: TBytes;
begin
  SetLength(LBytes, 16);
  platform_random_bytes(@LBytes[0], 16);
  Result := Base64Encode(LBytes);
end;

{ --- Masking --- }

procedure WebSocketMask(var AData: TBytes; const AMaskKey: array of Byte);
var
  LI, LLen: SizeUInt;
  LMask32: UInt32;
  LP: PUInt32;
begin
  LLen := Length(AData);
  if LLen = 0 then Exit;

  // Build 4-byte mask word
  LMask32 := UInt32(AMaskKey[0]) or (UInt32(AMaskKey[1]) shl 8) or
             (UInt32(AMaskKey[2]) shl 16) or (UInt32(AMaskKey[3]) shl 24);

  // XOR 4 bytes at a time
  LP := PUInt32(@AData[0]);
  LI := 0;
  while LI + 4 <= LLen do
  begin
    LP^ := LP^ xor LMask32;
    Inc(LP);
    Inc(LI, 4);
  end;

  // Handle remaining bytes
  while LI < LLen do
  begin
    AData[LI] := AData[LI] xor AMaskKey[LI and 3];
    Inc(LI);
  end;
end;

{ --- Frame encoding --- }

function WebSocketEncodeFrame(const AFrame: TWebSocketFrame; ARole: TWebSocketRole): TBytes;
var
  LPayloadLen: SizeUInt;
  LHeaderLen: SizeUInt;
  LMask: Boolean;
  LPos: SizeUInt;
  LMaskKey: array[0..3] of Byte;
  I: SizeUInt;
begin
  Result := nil;
  LPayloadLen := Length(AFrame.Payload);
  LMask := (ARole = wsrClient);

  { Calculate header size }
  LHeaderLen := 2;
  if LPayloadLen < 126 then
    { no extended length }
  else if LPayloadLen <= 65535 then
    Inc(LHeaderLen, 2)
  else
    Inc(LHeaderLen, 8);
  if LMask then
    Inc(LHeaderLen, 4);

  SetLength(Result, LHeaderLen + LPayloadLen);

  { Byte 0: FIN + Opcode }
  Result[0] := AFrame.Opcode and $0F;
  if AFrame.Fin then
    Result[0] := Result[0] or $80;

  { Byte 1: MASK + Payload length }
  if LPayloadLen < 126 then
    Result[1] := Byte(LPayloadLen)
  else if LPayloadLen <= 65535 then
    Result[1] := 126
  else
    Result[1] := 127;
  if LMask then
    Result[1] := Result[1] or $80;

  LPos := 2;

  { Extended payload length }
  if LPayloadLen >= 126 then
  begin
    if LPayloadLen <= 65535 then
    begin
      Result[LPos] := Byte(LPayloadLen shr 8);
      Result[LPos + 1] := Byte(LPayloadLen);
      Inc(LPos, 2);
    end
    else
    begin
      Result[LPos]     := Byte(LPayloadLen shr 56);
      Result[LPos + 1] := Byte(LPayloadLen shr 48);
      Result[LPos + 2] := Byte(LPayloadLen shr 40);
      Result[LPos + 3] := Byte(LPayloadLen shr 32);
      Result[LPos + 4] := Byte(LPayloadLen shr 24);
      Result[LPos + 5] := Byte(LPayloadLen shr 16);
      Result[LPos + 6] := Byte(LPayloadLen shr 8);
      Result[LPos + 7] := Byte(LPayloadLen);
      Inc(LPos, 8);
    end;
  end;

  { Mask key }
  if LMask then
  begin
    if AFrame.Masked then
    begin
      Move(AFrame.MaskKey[0], LMaskKey[0], 4);
    end
    else
    begin
      platform_random_bytes(@LMaskKey[0], 4);
    end;
    Move(LMaskKey[0], Result[LPos], 4);
    Inc(LPos, 4);
  end;

  { Payload (masked if client) }
  if LPayloadLen > 0 then
  begin
    Move(AFrame.Payload[0], Result[LPos], LPayloadLen);
    if LMask then
    begin
      { Unrolled 4-byte XOR }
      I := 0;
      while I + 4 <= LPayloadLen do
      begin
        PUInt32(@Result[LPos + I])^ := PUInt32(@Result[LPos + I])^ xor PUInt32(@LMaskKey[0])^;
        Inc(I, 4);
      end;
      while I < LPayloadLen do
      begin
        Result[LPos + I] := Result[LPos + I] xor LMaskKey[I and 3];
        Inc(I);
      end;
    end;
  end;
end;

function TryWebSocketDecodeFrame(const AData: TBytes; AOffset: SizeUInt;
  ARole: TWebSocketRole; out AFrame: TWebSocketFrame; out AConsumed: SizeUInt): Boolean;
var
  LDataLen, LPos: SizeUInt;
  LByte0, LByte1: Byte;
  LPayloadLen: UInt64;
  LMasked: Boolean;
  I: SizeUInt;
begin
  AFrame := Default(TWebSocketFrame);
  AConsumed := 0;
  LDataLen := SizeUInt(Length(AData));

  if AOffset + 2 > LDataLen then
    Exit(False);

  LByte0 := AData[AOffset];
  LByte1 := AData[AOffset + 1];

  AFrame.Fin := (LByte0 and $80) <> 0;
  AFrame.Opcode := LByte0 and $0F;
  LMasked := (LByte1 and $80) <> 0;
  AFrame.Masked := LMasked;
  LPayloadLen := LByte1 and $7F;

  LPos := AOffset + 2;

  if LPayloadLen = 126 then
  begin
    if LPos + 2 > LDataLen then
      Exit(False);
    LPayloadLen := (UInt64(AData[LPos]) shl 8) or UInt64(AData[LPos + 1]);
    Inc(LPos, 2);
  end
  else if LPayloadLen = 127 then
  begin
    if LPos + 8 > LDataLen then
      Exit(False);
    LPayloadLen := (UInt64(AData[LPos]) shl 56) or (UInt64(AData[LPos + 1]) shl 48)
      or (UInt64(AData[LPos + 2]) shl 40) or (UInt64(AData[LPos + 3]) shl 32)
      or (UInt64(AData[LPos + 4]) shl 24) or (UInt64(AData[LPos + 5]) shl 16)
      or (UInt64(AData[LPos + 6]) shl 8) or UInt64(AData[LPos + 7]);
    Inc(LPos, 8);
  end;

  { Control frames must have Fin=True and payload <= 125 bytes }
  if (AFrame.Opcode >= $8) then
  begin
    if not AFrame.Fin then
      Exit(False);
    if LPayloadLen > WS_MAX_CONTROL_PAYLOAD then
      Exit(False);
  end;

  { Max payload size check }
  if LPayloadLen > WS_MAX_FRAME_SIZE then
    Exit(False);

  { Role enforcement: server expects masked frames from client }
  if ARole = wsrServer then
  begin
    if not LMasked then
      Exit(False);
  end
  else
  begin
    { Client expects unmasked frames from server }
    if LMasked then
      Exit(False);
  end;

  if LMasked then
  begin
    if LPos + 4 > LDataLen then
      Exit(False);
    Move(AData[LPos], AFrame.MaskKey[0], 4);
    Inc(LPos, 4);
  end;

  if LPos + LPayloadLen > LDataLen then
    Exit(False);

  SetLength(AFrame.Payload, LPayloadLen);
  if LPayloadLen > 0 then
  begin
    Move(AData[LPos], AFrame.Payload[0], LPayloadLen);
    if LMasked then
    begin
      { Unrolled 4-byte XOR }
      I := 0;
      while I + 4 <= LPayloadLen do
      begin
        PUInt32(@AFrame.Payload[I])^ := PUInt32(@AFrame.Payload[I])^ xor PUInt32(@AFrame.MaskKey[0])^;
        Inc(I, 4);
      end;
      while I < LPayloadLen do
      begin
        AFrame.Payload[I] := AFrame.Payload[I] xor AFrame.MaskKey[I and 3];
        Inc(I);
      end;
    end;
  end;

  AConsumed := LPos + LPayloadLen - AOffset;
  Result := True;
end;

{ --- Convenience frame builders --- }

function BuildFrame(AOpcode: Byte; const APayload: TBytes; ARole: TWebSocketRole): TBytes;
var
  LFrame: TWebSocketFrame;
begin
  LFrame := Default(TWebSocketFrame);
  LFrame.Fin := True;
  LFrame.Opcode := AOpcode;
  LFrame.Payload := APayload;
  Result := WebSocketEncodeFrame(LFrame, ARole);
end;

function WebSocketTextFrame(const AText: string; ARole: TWebSocketRole): TBytes;
var
  LPayload: TBytes;
begin
  SetLength(LPayload, Length(AText));
  if Length(AText) > 0 then
    Move(AText[1], LPayload[0], Length(AText));
  Result := BuildFrame(WS_OPCODE_TEXT, LPayload, ARole);
end;

function WebSocketBinaryFrame(const AData: TBytes; ARole: TWebSocketRole): TBytes;
begin
  Result := BuildFrame(WS_OPCODE_BINARY, AData, ARole);
end;

function WebSocketPingFrame(ARole: TWebSocketRole): TBytes;
begin
  Result := BuildFrame(WS_OPCODE_PING, nil, ARole);
end;

function WebSocketPongFrame(const APingPayload: TBytes; ARole: TWebSocketRole): TBytes;
begin
  Result := BuildFrame(WS_OPCODE_PONG, APingPayload, ARole);
end;

function WebSocketCloseFrame(ACode: UInt16; const AReason: string; ARole: TWebSocketRole): TBytes;
var
  LPayload: TBytes;
  LReasonLen: Integer;
begin
  LReasonLen := Length(AReason);
  SetLength(LPayload, 2 + LReasonLen);
  LPayload[0] := Byte(ACode shr 8);
  LPayload[1] := Byte(ACode);
  if LReasonLen > 0 then
    Move(AReason[1], LPayload[2], LReasonLen);
  Result := BuildFrame(WS_OPCODE_CLOSE, LPayload, ARole);
end;

end.
