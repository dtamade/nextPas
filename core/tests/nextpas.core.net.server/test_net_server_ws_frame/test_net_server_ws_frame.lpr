program test_net_server_ws_frame;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.base,
  nextpas.core.test,
  nextpas.core.websocket.base,
  nextpas.core.net.server.ws.frame;

{ 手工构造原始帧（绕过编码器以覆盖编码器自身不产生的非法形态）。
  AMask 少于 4 项时自动补 0；AFin=False 时不置 FIN 位。 }
function RawFrame(const AOpcode: Byte; const AFin, AMasked: Boolean;
  const APayload: TBytes; const AMask: array of Byte): TBytes;
var
  LLen: Int64;
  LMask: array[0..3] of Byte;
  LIndex: Int32;
  LPos: SizeUInt;
  LTotal: SizeUInt;
begin
  Result := nil;
  LLen := Length(APayload);
  if LLen < 126 then
    LTotal := 2
  else if LLen < 65536 then
    LTotal := 4
  else
    LTotal := 10;
  if AMasked then
    Inc(LTotal, 4);
  Inc(LTotal, SizeUInt(LLen));
  SetLength(Result, LTotal);

  if AFin then
    Result[0] := $80 or AOpcode
  else
    Result[0] := AOpcode;
  if LLen < 126 then
    Result[1] := Byte(LLen)
  else if LLen < 65536 then
    Result[1] := 126
  else
    Result[1] := 127;
  if AMasked then
    Result[1] := Result[1] or $80;
  LPos := 2;
  if LLen >= 126 then
  begin
    if LLen < 65536 then
    begin
      Result[LPos] := Byte(LLen shr 8);
      Result[LPos + 1] := Byte(LLen);
      Inc(LPos, 2);
    end
    else
    begin
      for LIndex := 0 to 7 do
        Result[LPos + SizeUInt(LIndex)] := Byte(UInt64(LLen) shr (8 * (7 - LIndex)));
      Inc(LPos, 8);
    end;
  end;
  for LIndex := 0 to 3 do
  begin
    if LIndex < Length(AMask) then
      LMask[LIndex] := AMask[LIndex]
    else
      LMask[LIndex] := 0;
    if AMasked then
      Result[LPos + SizeUInt(LIndex)] := LMask[LIndex];
  end;
  if AMasked then
    Inc(LPos, 4);
  if LLen > 0 then
  begin
    if AMasked then
      for LIndex := 0 to Length(APayload) - 1 do
        Result[LPos + SizeUInt(LIndex)] := APayload[LIndex] xor LMask[LIndex mod 4]
    else
      Move(APayload[0], Result[LPos], SizeUInt(LLen));
  end;
end;

function BytesFromString(const AValue: string): TBytes;
begin
  Result := nil;
  SetLength(Result, Length(AValue));
  if Length(AValue) > 0 then
    Move(AValue[1], Result[0], SizeUInt(Length(AValue)));
end;

{ 单帧解码助手：期望帧头声明不超过负载上限 8192 }
function DecodeOne(const AWire: TBytes): TNetWsDecodeCode;
var
  D: TNetWsFrameDecoder;
  F: TNetWsFrame;
begin
  D := TNetWsFrameDecoder.Create(False, 8192, 16384);
  D.Feed(AWire);
  Result := D.TryDecode(F);
end;

{ 循环推进：一次喂入后反复 TryDecode 直到非 NeedMore（覆盖多阶段解析） }
function DecodeAll(const AWire: TBytes; const AMaxFrame, AMaxMessage: Int64): TNetWsDecodeCode;
var
  D: TNetWsFrameDecoder;
  F: TNetWsFrame;
begin
  D := TNetWsFrameDecoder.Create(False, AMaxFrame, AMaxMessage);
  D.Feed(AWire);
  repeat
    Result := D.TryDecode(F);
  until Result <> nwsDecodeNeedMore;
end;

procedure TestMaskedTextRoundtrip;
var
  E: TNetWsFrameEncoder;
  D: TNetWsFrameDecoder;
  W: TBytes;
  F: TNetWsFrame;
  C: TNetWsEncodeCode;
begin
  C := E.BuildFrame(Byte(WS_OPCODE_TEXT), True, BytesFromString('hello'),
    nwsClient, W);
  CheckEqual(Int64(Ord(nwsEncodeOk)), Int64(Ord(C)),
    'client text frame should encode');
  D := TNetWsFrameDecoder.Create(False, 4096, 8192);
  D.Feed(W);
  CheckEqual(Int64(Ord(nwsDecodeFrame)), Int64(Ord(D.TryDecode(F))),
    'masked text frame should decode');
  CheckTrue(F.Fin, 'fin should be set');
  CheckEqual(Int64(Byte(WS_OPCODE_TEXT)), Int64(F.Opcode),
    'opcode should be text');
  CheckEqual(BytesFromString('hello'), F.Payload);
end;

procedure TestByteByByteFeed;
var
  E: TNetWsFrameEncoder;
  D: TNetWsFrameDecoder;
  P: TBytes;
  W: TBytes;
  F: TNetWsFrame;
  C: TNetWsDecodeCode;
  I: SizeUInt;
  SeenNeedMore: Boolean;
begin
  P := BytesFromString('incremental');
  CheckEqual(Int64(Ord(nwsEncodeOk)), Int64(Ord(E.BuildFrame(
    Byte(WS_OPCODE_BINARY), True, P, nwsClient, W))), 'encode');
  CheckTrue(SizeUInt(Length(W)) > SizeUInt(Length(P)),
    'wire should carry header + mask key');
  D := TNetWsFrameDecoder.Create(False, 4096, 8192);
  SeenNeedMore := False;
  for I := 0 to SizeUInt(Length(W)) - 1 do
  begin
    D.Feed(@W[I], 1);
    C := D.TryDecode(F);
    if I < SizeUInt(Length(W)) - 1 then
    begin
      CheckEqual(Int64(Ord(nwsDecodeNeedMore)), Int64(Ord(C)),
        'partial feed must not produce a frame');
      SeenNeedMore := True;
    end;
  end;
  CheckTrue(SeenNeedMore, 'NeedMore should have been observed mid-feed');
  CheckEqual(Int64(Byte(WS_OPCODE_BINARY)), Int64(F.Opcode), 'binary opcode');
  CheckEqual(P, F.Payload);
end;

procedure TestMaskEnforcement;
var
  D: TNetWsFrameDecoder;
  F: TNetWsFrame;
  W: TBytes;
begin
  { server 角色必须收掩码帧 }
  W := RawFrame(Byte(WS_OPCODE_TEXT), True, False, BytesFromString('x'), []);
  D := TNetWsFrameDecoder.Create(False, 4096, 8192);
  D.Feed(W);
  CheckEqual(Int64(Ord(nwsDecodeProtocolError)), Int64(Ord(D.TryDecode(F))),
    'server role must reject unmasked frames');
  { client 角色必须收非掩码帧 }
  W := RawFrame(Byte(WS_OPCODE_TEXT), True, True, BytesFromString('x'),
    [1, 2, 3, 4]);
  D := TNetWsFrameDecoder.Create(True, 4096, 8192);
  D.Feed(W);
  CheckEqual(Int64(Ord(nwsDecodeProtocolError)), Int64(Ord(D.TryDecode(F))),
    'client role must reject masked frames');
  { client 角色正常收非掩码帧 }
  D := TNetWsFrameDecoder.Create(True, 4096, 8192);
  W := RawFrame(Byte(WS_OPCODE_TEXT), True, False, BytesFromString('x'), []);
  D.Feed(W);
  CheckEqual(Int64(Ord(nwsDecodeFrame)), Int64(Ord(D.TryDecode(F))),
    'client role should decode unmasked');
end;

procedure TestExtendedLengths;
var
  D: TNetWsFrameDecoder;
  F: TNetWsFrame;
  W: TBytes;
  P: TBytes;
  C: TNetWsDecodeCode;
  I: SizeUInt;
begin
  { 7-bit 上限 125 }
  SetLength(P, 125);
  for I := 0 to SizeUInt(High(P)) do
    P[I] := Byte(I);
  W := RawFrame(Byte(WS_OPCODE_BINARY), True, True, P, [0, 0, 0, 0]);
  D := TNetWsFrameDecoder.Create(False, 65536, 65536);
  D.Feed(W);
  CheckEqual(Int64(Ord(nwsDecodeFrame)), Int64(Ord(D.TryDecode(F))),
    'len 125 should decode');
  CheckEqual(P, F.Payload);
  { 126 形式：65535 }
  SetLength(P, 65535);
  for I := 0 to SizeUInt(High(P)) do
    P[I] := Byte(1 + (I mod 127));
  W := RawFrame(Byte(WS_OPCODE_BINARY), True, True, P, [9, 8, 7, 6]);
  C := DecodeAll(W, 65536, 65536);
  CheckEqual(Int64(Ord(nwsDecodeFrame)), Int64(Ord(C)),
    'len 65535 (126-form) should decode');
  D := TNetWsFrameDecoder.Create(False, 65536, 65536);
  D.Feed(W);
  while D.TryDecode(F) = nwsDecodeNeedMore do
  begin
  end;
  CheckEqual(Integer(65535), Integer(Length(F.Payload)), '65535 payload length');
  { 非规范：126 形式值 125 }
  W := RawFrame(Byte(WS_OPCODE_TEXT), True, True, nil, [0, 0, 0, 0]);
  W[1] := $80 or 126;
  SetLength(W, Length(W) + 2);
  Move(W[2], W[4], SizeUInt(Length(W) - 4));
  W[2] := 0;
  W[3] := 125;
  C := DecodeOne(W);
  CheckEqual(Int64(Ord(nwsDecodeProtocolError)), Int64(Ord(C)),
    '126-form len < 126 must be rejected');
  { 非规范：127 形式值 65535 }
  W := RawFrame(Byte(WS_OPCODE_TEXT), True, True, nil, [0, 0, 0, 0]);
  W[1] := $80 or 127;
  SetLength(W, Length(W) + 8);
  Move(W[2], W[10], SizeUInt(Length(W) - 10));
  for I := 0 to 7 do
    W[2 + SizeUInt(I)] := 0;
  W[2 + 6] := $FF;
  W[2 + 7] := $FF;
  C := DecodeOne(W);
  CheckEqual(Int64(Ord(nwsDecodeProtocolError)), Int64(Ord(C)),
    '127-form len < 65536 must be rejected');
  { 64 位长度最高位为 1 }
  W := RawFrame(Byte(WS_OPCODE_TEXT), True, True, nil, [0, 0, 0, 0]);
  W[1] := $80 or 127;
  SetLength(W, Length(W) + 8);
  Move(W[2], W[10], SizeUInt(Length(W) - 10));
  for I := 0 to 7 do
    W[2 + SizeUInt(I)] := 0;
  W[2] := $80;
  C := DecodeOne(W);
  CheckEqual(Int64(Ord(nwsDecodeProtocolError)), Int64(Ord(C)),
    '64-bit length high bit must be rejected');
end;

procedure TestControlFrames;
var
  D: TNetWsFrameDecoder;
  F: TNetWsFrame;
  W: TBytes;
  C: TNetWsDecodeCode;
begin
  { 合法 ping（掩码、载荷 5） }
  W := RawFrame(Byte(WS_OPCODE_PING), True, True, BytesFromString('abcde'),
    [1, 2, 3, 4]);
  D := TNetWsFrameDecoder.Create(False, 4096, 8192);
  D.Feed(W);
  C := D.TryDecode(F);
  CheckEqual(Int64(Ord(nwsDecodeFrame)), Int64(Ord(C)), 'ping should decode');
  CheckEqual(Int64(Byte(WS_OPCODE_PING)), Int64(F.Opcode), 'ping opcode');
  CheckEqual(BytesFromString('abcde'), F.Payload);
  { 控帧载荷 > 125 }
  W := RawFrame(Byte(WS_OPCODE_PING), True, True, nil, [0, 0, 0, 0]);
  W[1] := $80 or 126;
  SetLength(W, Length(W) + 2);
  Move(W[2], W[4], SizeUInt(Length(W) - 4));
  W[2] := 0;
  W[3] := 126;
  C := DecodeOne(W);
  CheckEqual(Int64(Ord(nwsDecodeProtocolError)), Int64(Ord(C)),
    'control payload > 125 must be rejected');
  { 控帧分片（FIN=0） }
  W := RawFrame(Byte(WS_OPCODE_PING), False, True, BytesFromString('a'),
    [0, 0, 0, 0]);
  C := DecodeOne(W);
  CheckEqual(Int64(Ord(nwsDecodeProtocolError)), Int64(Ord(C)),
    'fragmented control frame must be rejected');
end;

procedure TestCloseFrames;
var
  D: TNetWsFrameDecoder;
  F: TNetWsFrame;
  W: TBytes;
  C: TNetWsDecodeCode;
begin
  { 合法 close：1000 + reason }
  W := RawFrame(Byte(WS_OPCODE_CLOSE), True, True,
    BytesFromString(#3 + #$E8 + 'by'), [0, 0, 0, 0]);
  D := TNetWsFrameDecoder.Create(False, 4096, 8192);
  D.Feed(W);
  C := D.TryDecode(F);
  CheckEqual(Int64(Ord(nwsDecodeFrame)), Int64(Ord(C)),
    'close frame should decode');
  CheckEqual(UInt64(1000), UInt64(F.CloseCode), 'close code 1000');
  CheckEqual('by', F.CloseReason, 'close reason');
  { close 之后不再产出帧 }
  C := D.TryDecode(F);
  CheckEqual(Int64(Ord(nwsDecodeClosed)), Int64(Ord(C)),
    'after close decoder must report closed');
  { 1 字节载荷（code 不完整） }
  W := RawFrame(Byte(WS_OPCODE_CLOSE), True, True, TBytes.Create($03), [0, 0, 0, 0]);
  C := DecodeOne(W);
  CheckEqual(Int64(Ord(nwsDecodeProtocolError)), Int64(Ord(C)),
    '1-byte close payload rejected');
  { 非法 close code 999 }
  W := RawFrame(Byte(WS_OPCODE_CLOSE), True, True, BytesFromString(#3 + #$E7), [0, 0, 0, 0]);
  C := DecodeOne(W);
  CheckEqual(Int64(Ord(nwsDecodeProtocolError)), Int64(Ord(C)),
    'close code 999 rejected');
  { 保留 code 1005 }
  W := RawFrame(Byte(WS_OPCODE_CLOSE), True, True, BytesFromString(#3 + #$ED), [0, 0, 0, 0]);
  C := DecodeOne(W);
  CheckEqual(Int64(Ord(nwsDecodeProtocolError)), Int64(Ord(C)),
    'close code 1005 rejected');
  { 非法 UTF-8 reason }
  W := RawFrame(Byte(WS_OPCODE_CLOSE), True, True,
    BytesFromString(#3 + #$E8 + #$FF), [0, 0, 0, 0]);
  C := DecodeOne(W);
  CheckEqual(Int64(Ord(nwsDecodeProtocolError)), Int64(Ord(C)),
    'invalid utf-8 reason rejected');
end;

procedure TestFragmentation;
var
  D: TNetWsFrameDecoder;
  F: TNetWsFrame;
  W: TBytes;
  C: TNetWsDecodeCode;
begin
  D := TNetWsFrameDecoder.Create(False, 4096, 8192);
  { 文本 fin=false "he" }
  W := RawFrame(Byte(WS_OPCODE_TEXT), False, True, BytesFromString('he'), [0, 0, 0, 0]);
  D.Feed(W);
  C := D.TryDecode(F);
  CheckEqual(Int64(Ord(nwsDecodeFrame)), Int64(Ord(C)), 'fragment should decode');
  CheckTrue(not F.Fin, 'fragment should not be final');
  CheckEqual(BytesFromString('he'), F.Payload);
  { 续片 fin=false "ll" }
  W := RawFrame(Byte(WS_OPCODE_CONTINUATION), False, True, BytesFromString('ll'), [0, 0, 0, 0]);
  D.Feed(W);
  C := D.TryDecode(F);
  CheckEqual(Int64(Ord(nwsDecodeFrame)), Int64(Ord(C)), 'continuation should decode');
  { 终续片 "o" }
  W := RawFrame(Byte(WS_OPCODE_CONTINUATION), True, True, BytesFromString('o'), [0, 0, 0, 0]);
  D.Feed(W);
  C := D.TryDecode(F);
  CheckEqual(Int64(Ord(nwsDecodeFrame)), Int64(Ord(C)),
    'final continuation should decode');
  CheckTrue(F.Fin, 'assembled message should be final');
  CheckEqual(Int64(Byte(WS_OPCODE_TEXT)), Int64(F.Opcode),
    'assembled opcode restored to text');
  CheckEqual(BytesFromString('hello'), F.Payload);
  { 无分片却来续片 }
  D := TNetWsFrameDecoder.Create(False, 4096, 8192);
  W := RawFrame(Byte(WS_OPCODE_CONTINUATION), True, True, BytesFromString('x'), [0, 0, 0, 0]);
  D.Feed(W);
  C := D.TryDecode(F);
  CheckEqual(Int64(Ord(nwsDecodeProtocolError)), Int64(Ord(C)),
    'continuation without open fragment rejected');
  { 分片未完又来数据帧 }
  D := TNetWsFrameDecoder.Create(False, 4096, 8192);
  W := RawFrame(Byte(WS_OPCODE_TEXT), False, True, BytesFromString('ab'), [0, 0, 0, 0]);
  D.Feed(W);
  C := D.TryDecode(F);
  CheckEqual(Int64(Ord(nwsDecodeFrame)), Int64(Ord(C)), 'open fragment');
  W := RawFrame(Byte(WS_OPCODE_BINARY), True, True, BytesFromString('zz'), [0, 0, 0, 0]);
  D.Feed(W);
  C := D.TryDecode(F);
  CheckEqual(Int64(Ord(nwsDecodeProtocolError)), Int64(Ord(C)),
    'data frame interrupting fragment rejected');
end;

procedure TestSizeLimits;
var
  D: TNetWsFrameDecoder;
  F: TNetWsFrame;
  W: TBytes;
  P: TBytes;
  C: TNetWsDecodeCode;
begin
  { 单帧超过 MaxFrameSize：声明 1024 字节帧头（无需喂负载） }
  W := RawFrame(Byte(WS_OPCODE_TEXT), True, True, nil, [0, 0, 0, 0]);
  W[1] := $80 or 126;
  SetLength(W, Length(W) + 2);
  Move(W[2], W[4], SizeUInt(Length(W) - 4));
  W[2] := $04;
  W[3] := $00; { 1024 }
  D := TNetWsFrameDecoder.Create(False, 512, 4096);
  D.Feed(W);
  repeat
    C := D.TryDecode(F);
  until C <> nwsDecodeNeedMore;
  CheckEqual(Int64(Ord(nwsDecodeTooLarge)), Int64(Ord(C)),
    'frame over MaxFrameSize must be TooLarge');
  { 分片累计超过 MaxMessageSize：首片 40 + 续片 40 > 64 }
  D := TNetWsFrameDecoder.Create(False, 4096, 64);
  SetLength(P, 40);
  FillChar(P[0], 40, $41);
  W := RawFrame(Byte(WS_OPCODE_TEXT), False, True, P, [0, 0, 0, 0]);
  D.Feed(W);
  C := D.TryDecode(F);
  CheckEqual(Int64(Ord(nwsDecodeFrame)), Int64(Ord(C)),
    'first fragment within message limit');
  W := RawFrame(Byte(WS_OPCODE_CONTINUATION), True, True, P, [0, 0, 0, 0]);
  D.Feed(W);
  C := D.TryDecode(F);
  CheckEqual(Int64(Ord(nwsDecodeTooLarge)), Int64(Ord(C)),
    'message exceeding MaxMessageSize must be TooLarge');
end;

procedure TestHeaderCorruption;
var
  C: TNetWsDecodeCode;
  W: TBytes;
begin
  { 保留位 RSV1/RSV2/RSV3 }
  W := RawFrame(Byte(WS_OPCODE_TEXT), True, True, BytesFromString('x'), [0, 0, 0, 0]);
  W[0] := W[0] or $40;
  C := DecodeOne(W);
  CheckEqual(Int64(Ord(nwsDecodeProtocolError)), Int64(Ord(C)),
    'RSV1 must be rejected without deflate');
  W := RawFrame(Byte(WS_OPCODE_TEXT), True, True, BytesFromString('x'), [0, 0, 0, 0]);
  W[0] := $80 or Byte(WS_OPCODE_TEXT) or $30;
  C := DecodeOne(W);
  CheckEqual(Int64(Ord(nwsDecodeProtocolError)), Int64(Ord(C)),
    'RSV2/RSV3 must be rejected');
  { 非法 opcode 0x3 }
  W := RawFrame($03, True, True, BytesFromString('x'), [0, 0, 0, 0]);
  C := DecodeOne(W);
  CheckEqual(Int64(Ord(nwsDecodeProtocolError)), Int64(Ord(C)),
    'reserved opcode must be rejected');
  { 文本载荷非法 UTF-8 }
  W := RawFrame(Byte(WS_OPCODE_TEXT), True, True,
    TBytes.Create($C0, $AF), [0, 0, 0, 0]);
  C := DecodeOne(W);
  CheckEqual(Int64(Ord(nwsDecodeProtocolError)), Int64(Ord(C)),
    'invalid text utf-8 must be rejected');
end;

procedure TestEncoderValidation;
var
  E: TNetWsFrameEncoder;
  W: TBytes;
begin
  CheckEqual(Int64(Ord(nwsEncodeInvalid)), Int64(Ord(
    E.BuildFrame($03, True, nil, nwsServer, W))),
    'reserved opcode must not encode');
  CheckEqual(Int64(Ord(nwsEncodeOk)), Int64(Ord(
    E.BuildFrame(Byte(WS_OPCODE_PING), True, nil, nwsServer, W))),
    'empty ping should encode ok');
  CheckEqual(Int64(Ord(nwsEncodeInvalid)), Int64(Ord(
    E.BuildFrame(Byte(WS_OPCODE_PING), False, nil, nwsServer, W))),
    'fragmented control must not encode');
  CheckEqual(Int64(Ord(nwsEncodeInvalid)), Int64(Ord(
    E.BuildFrame(Byte(WS_OPCODE_PONG), True,
      BytesFromString(StringOfChar('x', 126)), nwsServer, W))),
    'control payload > 125 must not encode');
  CheckEqual(Int64(Ord(nwsEncodeInvalid)), Int64(Ord(
    E.BuildCloseFrame(999, '', nwsServer, W))),
    'invalid close code must not encode');
  CheckEqual(Int64(Ord(nwsEncodeInvalid)), Int64(Ord(
    E.BuildCloseFrame(1000, #$FF + 'bad', nwsServer, W))),
    'invalid close reason utf-8 must not encode');
  CheckEqual(Int64(Ord(nwsEncodeOk)), Int64(Ord(
    E.BuildCloseFrame(1000, 'bye', nwsServer, W))),
    'valid close frame should encode');
end;

procedure TestServerRoleWireExact;
var
  E: TNetWsFrameEncoder;
  W: TBytes;
begin
  CheckEqual(Int64(Ord(nwsEncodeOk)), Int64(Ord(
    E.BuildFrame(Byte(WS_OPCODE_TEXT), True, nil, nwsServer, W))),
    'encode empty text');
  CheckEqual(Integer(2), Integer(Length(W)),
    'server frame header should be 2 bytes');
  CheckEqual($81, Integer(W[0]), 'server text frame first byte 0x81');
  CheckEqual(0, Integer(W[1]), 'server text frame second byte 0x00');
end;

procedure TestRoundtripAcrossOpcodes;
var
  E: TNetWsFrameEncoder;
  D: TNetWsFrameDecoder;
  F: TNetWsFrame;
  W: TBytes;
  C: TNetWsEncodeCode;
  I: TNetWsRole;
begin
  for I := TNetWsRole(nwsServer) to TNetWsRole(nwsClient) do
  begin
    C := E.BuildFrame(Byte(WS_OPCODE_BINARY), True,
      TBytes.Create(0, 1, 2, 253, 254, 255), I, W);
    CheckEqual(Int64(Ord(nwsEncodeOk)), Int64(Ord(C)), 'encode binary');
    { 解码端用对侧角色：nwsServer 编码产物（非掩码）须由 client 端解码器
      （AIsClient=True）接收；nwsClient 编码产物（掩码）由 server 端解码器接收 }
    D := TNetWsFrameDecoder.Create(I = nwsServer, 4096, 8192);
    D.Feed(W);
    CheckEqual(Int64(Ord(nwsDecodeFrame)), Int64(Ord(D.TryDecode(F))),
      'decode opposite role');
    CheckEqual(TBytes.Create(0, 1, 2, 253, 254, 255), F.Payload);
  end;
end;

procedure TestResetReuse;
var
  D: TNetWsFrameDecoder;
  F: TNetWsFrame;
  W: TBytes;
begin
  D := TNetWsFrameDecoder.Create(False, 4096, 8192);
  W := RawFrame(Byte(WS_OPCODE_TEXT), True, True, BytesFromString('one'), [0, 0, 0, 0]);
  D.Feed(W);
  CheckEqual(Int64(Ord(nwsDecodeFrame)), Int64(Ord(D.TryDecode(F))),
    'first decode before reset');
  D.Reset;
  W := RawFrame(Byte(WS_OPCODE_BINARY), True, True, BytesFromString('two'), [0, 0, 0, 0]);
  D.Feed(W);
  CheckEqual(Int64(Ord(nwsDecodeFrame)), Int64(Ord(D.TryDecode(F))),
    'decode after reset');
  CheckEqual(Int64(Byte(WS_OPCODE_BINARY)), Int64(F.Opcode),
    'opcode reset to binary');
  CheckEqual(BytesFromString('two'), F.Payload);
end;

procedure TestEmptyAndPartial;
var
  D: TNetWsFrameDecoder;
  F: TNetWsFrame;
  W: TBytes;
begin
  D := TNetWsFrameDecoder.Create(False, 4096, 8192);
  CheckEqual(Int64(Ord(nwsDecodeNeedMore)), Int64(Ord(D.TryDecode(F))),
    'empty feed should need more');
  W := RawFrame(Byte(WS_OPCODE_TEXT), True, True, BytesFromString('partial'), [0, 0, 0, 0]);
  D.Feed(@W[0], 4);
  CheckEqual(Int64(Ord(nwsDecodeNeedMore)), Int64(Ord(D.TryDecode(F))),
    'partial header should need more');
  D.Feed(@W[4], SizeUInt(Length(W)) - 4);
  CheckEqual(Int64(Ord(nwsDecodeFrame)), Int64(Ord(D.TryDecode(F))),
    'completed frame should decode');
end;

procedure TestDecoderEntryMidStage;
var
  D: TNetWsFrameDecoder;
  F: TNetWsFrame;
  W: TBytes;
  C: TNetWsDecodeCode;
begin
  W := RawFrame(Byte(WS_OPCODE_TEXT), True, True, BytesFromString('x'), [0, 0, 0, 0]);
  D := TNetWsFrameDecoder.Create(False, 4096, 8192);
  { 2 字节头 + 掩码键 4 字节齐备后仍缺负载 }
  D.Feed(@W[0], 6);
  C := D.TryDecode(F);
  CheckTrue((C = nwsDecodeNeedMore) or (C = nwsDecodeFrame),
    'header+mask stage should make bounded progress');
  D.Feed(@W[6], 1);
  CheckEqual(Int64(Ord(nwsDecodeFrame)), Int64(Ord(D.TryDecode(F))),
    'payload completion should decode');
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.net.server.ws.frame');
  T.Test('Masked text frame roundtrip', @TestMaskedTextRoundtrip);
  T.Test('Byte-by-byte incremental feed', @TestByteByByteFeed);
  T.Test('Mask enforcement by role', @TestMaskEnforcement);
  T.Test('Extended payload lengths and canonicality', @TestExtendedLengths);
  T.Test('Control frames (ping/pong rules)', @TestControlFrames);
  T.Test('Close frames and payload validation', @TestCloseFrames);
  T.Test('Fragmentation assembly rules', @TestFragmentation);
  T.Test('Frame/message size limits', @TestSizeLimits);
  T.Test('Header corruption and reserved bits', @TestHeaderCorruption);
  T.Test('Encoder validation', @TestEncoderValidation);
  T.Test('Server-role wire layout is exact', @TestServerRoleWireExact);
  T.Test('Encode/decode roundtrip across roles', @TestRoundtripAcrossOpcodes);
  T.Test('Reset reuses decoder', @TestResetReuse);
  T.Test('Empty and partial feeds', @TestEmptyAndPartial);
  T.Test('Mid-stage entry progress', @TestDecoderEntryMidStage);
  if not T.Run then Halt(1);
end.