program test_websocket;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.testing,
  nextpas.core.websocket.base,
  nextpas.core.websocket;

var
  T: TTestRunner;

procedure TestAcceptKeyRFC;
var
  LResult: string;
begin
  { RFC 6455 Section 1.3 test vector (verified with Node.js, Python, OpenSSL) }
  LResult := WebSocketAcceptKey('dGhlIHNhbXBsZSBub25jZQ==');
  CheckEqual('s3pPLMBiTxaQ9kYGzzhZRbK+xOo=', LResult,
    'RFC 6455 accept key');
end;

procedure TestGenerateKey;
var
  LKey: string;
begin
  LKey := WebSocketGenerateKey;
  { Base64 of 16 bytes = 24 chars (with padding) }
  CheckEqual(Int64(24), Int64(Length(LKey)), 'key length 24');
  { Last char should be = (16 bytes -> 24 base64 chars with padding) }
  Check(LKey[24] = '=', 'ends with padding');
end;

procedure TestEncodeDecodeSmallFrame;
var
  LFrame, LDecoded: TWebSocketFrame;
  LEncoded: TBytes;
  LConsumed: SizeUInt;
  LOk: Boolean;
begin
  LFrame := Default(TWebSocketFrame);
  LFrame.Fin := True;
  LFrame.Opcode := WS_OPCODE_TEXT;
  SetLength(LFrame.Payload, 5);
  LFrame.Payload[0] := Ord('H');
  LFrame.Payload[1] := Ord('e');
  LFrame.Payload[2] := Ord('l');
  LFrame.Payload[3] := Ord('l');
  LFrame.Payload[4] := Ord('o');

  { Server: no masking }
  LEncoded := WebSocketEncodeFrame(LFrame, wsrServer);
  LOk := TryWebSocketDecodeFrame(LEncoded, 0, wsrClient, LDecoded, LConsumed);
  Check(LOk, 'decode ok');
  Check(LDecoded.Fin, 'fin');
  CheckEqual(Int64(WS_OPCODE_TEXT), Int64(LDecoded.Opcode), 'opcode');
  CheckEqual(Int64(5), Int64(Length(LDecoded.Payload)), 'payload len');
  Check(LDecoded.Payload[0] = Ord('H'), 'byte 0');
  Check(LDecoded.Payload[4] = Ord('o'), 'byte 4');
  CheckEqual(Int64(Length(LEncoded)), Int64(LConsumed), 'consumed all');
end;

procedure TestEncodeDecodeMediumFrame;
var
  LFrame, LDecoded: TWebSocketFrame;
  LEncoded: TBytes;
  LConsumed: SizeUInt;
  LOk: Boolean;
  I: Integer;
begin
  LFrame := Default(TWebSocketFrame);
  LFrame.Fin := True;
  LFrame.Opcode := WS_OPCODE_BINARY;
  SetLength(LFrame.Payload, 300);
  for I := 0 to 299 do
    LFrame.Payload[I] := Byte(I mod 256);

  LEncoded := WebSocketEncodeFrame(LFrame, wsrServer);
  LOk := TryWebSocketDecodeFrame(LEncoded, 0, wsrClient, LDecoded, LConsumed);
  Check(LOk, 'decode ok');
  CheckEqual(Int64(300), Int64(Length(LDecoded.Payload)), 'payload len');
  Check(LDecoded.Payload[0] = 0, 'byte 0');
  Check(LDecoded.Payload[255] = 255, 'byte 255');
  Check(LDecoded.Payload[299] = 43, 'byte 299');
end;

procedure TestEncodeDecodeLargeFrame;
var
  LFrame, LDecoded: TWebSocketFrame;
  LEncoded: TBytes;
  LConsumed: SizeUInt;
  LOk: Boolean;
  I: Integer;
  LSize: Integer;
begin
  LSize := 70000;
  LFrame := Default(TWebSocketFrame);
  LFrame.Fin := True;
  LFrame.Opcode := WS_OPCODE_BINARY;
  SetLength(LFrame.Payload, LSize);
  for I := 0 to LSize - 1 do
    LFrame.Payload[I] := Byte(I mod 256);

  LEncoded := WebSocketEncodeFrame(LFrame, wsrServer);
  LOk := TryWebSocketDecodeFrame(LEncoded, 0, wsrClient, LDecoded, LConsumed);
  Check(LOk, 'decode ok');
  CheckEqual(Int64(LSize), Int64(Length(LDecoded.Payload)), 'payload len');
  Check(LDecoded.Payload[0] = 0, 'first byte');
  Check(LDecoded.Payload[LSize - 1] = Byte((LSize - 1) mod 256), 'last byte');
end;

procedure TestClientMasking;
var
  LFrame, LDecoded: TWebSocketFrame;
  LEncoded: TBytes;
  LConsumed: SizeUInt;
  LOk: Boolean;
begin
  LFrame := Default(TWebSocketFrame);
  LFrame.Fin := True;
  LFrame.Opcode := WS_OPCODE_TEXT;
  SetLength(LFrame.Payload, 4);
  LFrame.Payload[0] := Ord('T');
  LFrame.Payload[1] := Ord('e');
  LFrame.Payload[2] := Ord('s');
  LFrame.Payload[3] := Ord('t');

  { Client: must mask }
  LEncoded := WebSocketEncodeFrame(LFrame, wsrClient);
  { Verify mask bit is set in wire format }
  Check((LEncoded[1] and $80) <> 0, 'mask bit set');

  { Decode should unmask and recover original payload }
  LOk := TryWebSocketDecodeFrame(LEncoded, 0, wsrServer, LDecoded, LConsumed);
  Check(LOk, 'decode ok');
  Check(LDecoded.Masked, 'frame reports masked');
  CheckEqual(Int64(4), Int64(Length(LDecoded.Payload)), 'payload len');
  Check(LDecoded.Payload[0] = Ord('T'), 'byte 0');
  Check(LDecoded.Payload[1] = Ord('e'), 'byte 1');
  Check(LDecoded.Payload[2] = Ord('s'), 'byte 2');
  Check(LDecoded.Payload[3] = Ord('t'), 'byte 3');
end;

procedure TestServerNoMasking;
var
  LFrame: TWebSocketFrame;
  LEncoded: TBytes;
begin
  LFrame := Default(TWebSocketFrame);
  LFrame.Fin := True;
  LFrame.Opcode := WS_OPCODE_TEXT;
  SetLength(LFrame.Payload, 3);
  LFrame.Payload[0] := Ord('A');
  LFrame.Payload[1] := Ord('B');
  LFrame.Payload[2] := Ord('C');

  LEncoded := WebSocketEncodeFrame(LFrame, wsrServer);
  { Verify mask bit is NOT set }
  Check((LEncoded[1] and $80) = 0, 'mask bit not set');
  { Payload should be in clear }
  Check(LEncoded[2] = Ord('A'), 'payload[0] clear');
  Check(LEncoded[3] = Ord('B'), 'payload[1] clear');
  Check(LEncoded[4] = Ord('C'), 'payload[2] clear');
end;

procedure TestMaskUnmaskRoundTrip;
var
  LData, LOriginal: TBytes;
  LMask: array[0..3] of Byte;
  I: Integer;
begin
  SetLength(LData, 10);
  SetLength(LOriginal, 10);
  for I := 0 to 9 do
  begin
    LData[I] := Byte(I * 17);
    LOriginal[I] := LData[I];
  end;
  LMask[0] := $AA; LMask[1] := $BB; LMask[2] := $CC; LMask[3] := $DD;

  { Mask }
  WebSocketMask(LData, LMask);
  { Should be different }
  Check(LData[0] <> LOriginal[0], 'masked differs');

  { Unmask (same operation) }
  WebSocketMask(LData, LMask);
  for I := 0 to 9 do
    Check(LData[I] = LOriginal[I], 'round-trip byte ' + IntToStr(I));
end;

procedure TestTextFrameHelper;
var
  LEncoded: TBytes;
  LDecoded: TWebSocketFrame;
  LConsumed: SizeUInt;
  LStr: string;
begin
  LEncoded := WebSocketTextFrame('Hello', wsrServer);
  Check(TryWebSocketDecodeFrame(LEncoded, 0, wsrClient, LDecoded, LConsumed), 'decode');
  CheckEqual(Int64(WS_OPCODE_TEXT), Int64(LDecoded.Opcode), 'opcode');
  Check(LDecoded.Fin, 'fin');
  CheckEqual(Int64(5), Int64(Length(LDecoded.Payload)), 'len');
  SetLength(LStr, 5);
  Move(LDecoded.Payload[0], LStr[1], 5);
  CheckEqual('Hello', LStr, 'text');
end;

procedure TestBinaryFrameHelper;
var
  LData, LEncoded: TBytes;
  LDecoded: TWebSocketFrame;
  LConsumed: SizeUInt;
begin
  SetLength(LData, 3);
  LData[0] := 1; LData[1] := 2; LData[2] := 3;
  LEncoded := WebSocketBinaryFrame(LData, wsrServer);
  Check(TryWebSocketDecodeFrame(LEncoded, 0, wsrClient, LDecoded, LConsumed), 'decode');
  CheckEqual(Int64(WS_OPCODE_BINARY), Int64(LDecoded.Opcode), 'opcode');
  CheckEqual(Int64(3), Int64(Length(LDecoded.Payload)), 'len');
end;

procedure TestPingPongFrameHelpers;
var
  LPing, LPong: TBytes;
  LDecoded: TWebSocketFrame;
  LConsumed: SizeUInt;
  LPingPayload: TBytes;
begin
  LPing := WebSocketPingFrame(wsrServer);
  Check(TryWebSocketDecodeFrame(LPing, 0, wsrClient, LDecoded, LConsumed), 'decode ping');
  CheckEqual(Int64(WS_OPCODE_PING), Int64(LDecoded.Opcode), 'ping opcode');
  Check(LDecoded.Fin, 'ping fin');

  SetLength(LPingPayload, 2);
  LPingPayload[0] := $AB; LPingPayload[1] := $CD;
  LPong := WebSocketPongFrame(LPingPayload, wsrServer);
  Check(TryWebSocketDecodeFrame(LPong, 0, wsrClient, LDecoded, LConsumed), 'decode pong');
  CheckEqual(Int64(WS_OPCODE_PONG), Int64(LDecoded.Opcode), 'pong opcode');
  CheckEqual(Int64(2), Int64(Length(LDecoded.Payload)), 'pong payload len');
  Check(LDecoded.Payload[0] = $AB, 'pong byte 0');
  Check(LDecoded.Payload[1] = $CD, 'pong byte 1');
end;

procedure TestCloseFrameWithCodeAndReason;
var
  LEncoded: TBytes;
  LDecoded: TWebSocketFrame;
  LConsumed: SizeUInt;
  LCode: UInt16;
  LReason: string;
begin
  LEncoded := WebSocketCloseFrame(WS_CLOSE_NORMAL, 'bye', wsrServer);
  Check(TryWebSocketDecodeFrame(LEncoded, 0, wsrClient, LDecoded, LConsumed), 'decode');
  CheckEqual(Int64(WS_OPCODE_CLOSE), Int64(LDecoded.Opcode), 'opcode');
  Check(LDecoded.Fin, 'fin');
  { Payload: 2 bytes code + reason }
  CheckEqual(Int64(5), Int64(Length(LDecoded.Payload)), 'payload len');
  LCode := (UInt16(LDecoded.Payload[0]) shl 8) or UInt16(LDecoded.Payload[1]);
  CheckEqual(Int64(WS_CLOSE_NORMAL), Int64(LCode), 'close code');
  SetLength(LReason, 3);
  Move(LDecoded.Payload[2], LReason[1], 3);
  CheckEqual('bye', LReason, 'reason');
end;

procedure TestDecodeIncompleteData;
var
  LData: TBytes;
  LDecoded: TWebSocketFrame;
  LConsumed: SizeUInt;
begin
  { Only 1 byte - not enough for header }
  SetLength(LData, 1);
  LData[0] := $81;
  Check(not TryWebSocketDecodeFrame(LData, 0, wsrClient, LDecoded, LConsumed), 'too short');

  { Header says 5 bytes payload but only 3 available }
  SetLength(LData, 4);
  LData[0] := $81; { FIN + TEXT }
  LData[1] := 5;   { payload len = 5 }
  LData[2] := Ord('A');
  LData[3] := Ord('B');
  Check(not TryWebSocketDecodeFrame(LData, 0, wsrClient, LDecoded, LConsumed), 'incomplete payload');
end;

procedure TestControlFramePayloadLimit;
var
  LEncoded: TBytes;
  LDecoded: TWebSocketFrame;
  LConsumed: SizeUInt;
begin
  { Build a ping frame with 126 bytes payload (exceeds 125 limit) }
  { We manually craft the wire bytes to test decoder rejection }
  SetLength(LEncoded, 4 + 126);
  LEncoded[0] := $89; { FIN + PING }
  LEncoded[1] := 126; { extended length indicator }
  LEncoded[2] := 0;   { extended length high byte }
  LEncoded[3] := 126; { extended length low byte = 126 }
  { Fill payload }
  FillChar(LEncoded[4], 126, $AA);

  Check(not TryWebSocketDecodeFrame(LEncoded, 0, wsrClient, LDecoded, LConsumed), 'control frame > 125 rejected');
end;

procedure TestServerRejectsUnmaskedFrame;
var
  LEncoded: TBytes;
  LDecoded: TWebSocketFrame;
  LConsumed: SizeUInt;
begin
  { Craft an unmasked text frame (as if from client but without mask) }
  SetLength(LEncoded, 7);
  LEncoded[0] := $81; { FIN + TEXT }
  LEncoded[1] := 5;   { payload len = 5, mask bit NOT set }
  LEncoded[2] := Ord('H');
  LEncoded[3] := Ord('e');
  LEncoded[4] := Ord('l');
  LEncoded[5] := Ord('l');
  LEncoded[6] := Ord('o');
  { Server must reject unmasked frames }
  Check(not TryWebSocketDecodeFrame(LEncoded, 0, wsrServer, LDecoded, LConsumed), 'server rejects unmasked');
end;

procedure TestClientRejectsMaskedFrame;
var
  LFrame: TWebSocketFrame;
  LEncoded: TBytes;
  LDecoded: TWebSocketFrame;
  LConsumed: SizeUInt;
begin
  { Encode as client (masked), then try to decode as client - should reject }
  LFrame := Default(TWebSocketFrame);
  LFrame.Fin := True;
  LFrame.Opcode := WS_OPCODE_TEXT;
  SetLength(LFrame.Payload, 4);
  LFrame.Payload[0] := Ord('T');
  LFrame.Payload[1] := Ord('e');
  LFrame.Payload[2] := Ord('s');
  LFrame.Payload[3] := Ord('t');
  LEncoded := WebSocketEncodeFrame(LFrame, wsrClient);
  { Client must reject masked frames (server MUST NOT mask) }
  Check(not TryWebSocketDecodeFrame(LEncoded, 0, wsrClient, LDecoded, LConsumed), 'client rejects masked');
end;

procedure TestControlFrameMustHaveFin;
var
  LEncoded: TBytes;
  LDecoded: TWebSocketFrame;
  LConsumed: SizeUInt;
begin
  { Craft a ping frame without FIN bit }
  SetLength(LEncoded, 2);
  LEncoded[0] := $09; { PING without FIN }
  LEncoded[1] := 0;   { no payload, no mask }
  Check(not TryWebSocketDecodeFrame(LEncoded, 0, wsrClient, LDecoded, LConsumed), 'control frame without FIN rejected');
end;

begin
  T := TTestRunner.Create('nextpas.core.websocket');
  T.Run('AcceptKey RFC vector', @TestAcceptKeyRFC);
  T.Run('GenerateKey length', @TestGenerateKey);
  T.Run('Encode/decode small frame', @TestEncodeDecodeSmallFrame);
  T.Run('Encode/decode medium frame', @TestEncodeDecodeMediumFrame);
  T.Run('Encode/decode large frame', @TestEncodeDecodeLargeFrame);
  T.Run('Client masking', @TestClientMasking);
  T.Run('Server no masking', @TestServerNoMasking);
  T.Run('Mask/unmask round-trip', @TestMaskUnmaskRoundTrip);
  T.Run('Text frame helper', @TestTextFrameHelper);
  T.Run('Binary frame helper', @TestBinaryFrameHelper);
  T.Run('Ping/Pong frame helpers', @TestPingPongFrameHelpers);
  T.Run('Close frame with code+reason', @TestCloseFrameWithCodeAndReason);
  T.Run('Decode incomplete data', @TestDecodeIncompleteData);
  T.Run('Control frame payload limit', @TestControlFramePayloadLimit);
  T.Run('Server rejects unmasked', @TestServerRejectsUnmaskedFrame);
  T.Run('Client rejects masked', @TestClientRejectsMaskedFrame);
  T.Run('Control frame must have FIN', @TestControlFrameMustHaveFin);
  T.Summary;
end.
