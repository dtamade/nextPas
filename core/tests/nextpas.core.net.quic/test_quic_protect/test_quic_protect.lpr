program test_quic_protect;

{ QUIC 包保护层单元测试（RFC 9001 §5.4/§5.5 + RFC 9000 §17.1/附录 A）：
  - PN 编解码：RFC 9000 附录 A.2/A.3 文字样例逐条对拍；
  - A.2 Client Initial / A.3 Server Initial 黄金向量整包逐字节
    （protect 与 unprotect 双向）；
  - ChaCha20 相：A.5 密钥派生对拍 + §5.4.4 掩码 oracle + 合成往返；
  - 畸形/篡改拒绝面。
  仅依赖 nextPas/core（无 system 垫片）。 }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.fs.path,
  nextpas.core.fs.util,
  nextpas.core.net.quic.varint,
  nextpas.core.net.quic.pn,
  nextpas.core.net.quic.header,
  nextpas.core.net.quic.tls,
  nextpas.core.net.quic.protect,
  nextpas.core.test;

{$I ../../fpc_rtl_uses_scan.inc}
{$I quic_protect_vectors.inc}
const
  cHexDigits: array[0..15] of Char = '0123456789abcdef';

function HexNibbleVal(C: Char): Byte;
begin
  case C of
    '0'..'9': Result := Ord(C) - Ord('0');
    'a'..'f': Result := Ord(C) - Ord('a') + 10;
    'A'..'F': Result := Ord(C) - Ord('A') + 10;
  else
    Result := 0;
  end;
end;

function HexToBytes(const AHex: string): TBytes;
var
  I: Integer;
begin
  Result := nil;
  SetLength(Result, Length(AHex) div 2);
  for I := 0 to Length(Result) - 1 do
    Result[I] := (HexNibbleVal(AHex[I * 2 + 1]) shl 4) or HexNibbleVal(AHex[I * 2 + 2]);
end;

function BytesToHex(const AData: TBytes): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to Length(AData) - 1 do
  begin
    Result := Result + cHexDigits[AData[I] shr 4];
    Result := Result + cHexDigits[AData[I] and $0F];
  end;
end;

function ConstBytes(const AArr: array of Byte): TBytes;
var
  LI: Integer;
begin
  Result := nil;
  SetLength(Result, Length(AArr));
  for LI := 0 to High(AArr) do
    Result[LI] := AArr[LI];
end;

function HexSlice(const ABuf: TBytes; AFrom, ACount: Integer): string;
var
  LI: Integer;
begin
  Result := '';
  for LI := AFrom to AFrom + ACount - 1 do
  begin
    Result := Result + cHexDigits[ABuf[LI] shr 4];
    Result := Result + cHexDigits[ABuf[LI] and $0F];
  end;
end;

{ 复制进指定大小的新缓冲，尾部显式补零（PADDING 帧） }
function PaddedTo(const AData: TBytes; ASize: Integer): TBytes;
var
  LI: Integer;
begin
  Result := nil;
  SetLength(Result, ASize);
  for LI := 0 to ASize - 1 do
    Result[LI] := $00;
  for LI := 0 to Length(AData) - 1 do
    if LI < ASize then
      Result[LI] := AData[LI];
end;

var
  LRunner: TSuiteRunner;
  LSuite: TTestSuite;
  LClientKeys, LServerKeys, LChaChaKeys: TQuicPacketKeys;

begin
  LSuite := TTestSuite.Create('quic_protect');

  { ---------- PN 编解码（RFC 9000 附录 A 样例） ---------- }
  LSuite.Test('pn encode length RFC examples', procedure
  begin
    CheckEqual(1, QuicPnEncodedLen(25));
    CheckEqual(2, QuicPnEncodedLen(15293));
    CheckEqual(4, QuicPnEncodedLen(494878333));
    { largest_acked=0xabe8b3：0xac5c02 -> 16 位；0xace8fe -> 24 位（原文） }
    CheckEqual(2, QuicPnEncodedLenAfter($ABE8B3, $AC5C02));
    CheckEqual(3, QuicPnEncodedLenAfter($ABE8B3, $ACE8FE));
  end);

  LSuite.Test('pn decode closest-to-largest', procedure
  begin
    { 原文样例：largest=0xa82f30ea，截断 0x9b32(16b) -> 0xa82f9b32 }
    CheckEqual(UInt64($A82F9B32), QuicPnDecode($A82F30EA, $9B32, 16));
    { 窗口下沿回绕：largest=0x1FF pn=0 截断 1B -> 0x200 }
    CheckEqual(UInt64($200), QuicPnDecode($1FF, $00, 8));
    { 无需回绕：直取候选 }
    CheckEqual(UInt64($105), QuicPnDecode($104, $05, 8));
  end);

  LSuite.Test('pn append/decode roundtrip all widths', procedure
  var
    LPns: array[0..3] of UInt64;
    LLens: array[0..3] of Integer;
    LBuf: TBytes;
    LI, LL: Integer;
    LV: UInt64;
  begin
    LPns[0] := 7;        LLens[0] := 1;
    LPns[1] := 15293;    LLens[1] := 2;
    LPns[2] := 654360564; LLens[2] := 3;
    LPns[3] := UInt64($3FFFFFFFFFFFFFFF); LLens[3] := 4;
    for LI := 0 to 3 do
    begin
      LBuf := nil;
      QuicPnAppend(LBuf, LPns[LI], LLens[LI]);
      CheckEqual(LLens[LI], Length(LBuf));
      LV := 0;
      for LL := 0 to LLens[LI] - 1 do
        LV := (LV shl 8) or LBuf[LL];
      CheckTrue((LV and ((UInt64(1) shl (8 * LLens[LI])) - 1)) = LV);
      { 解码恢复：largest = pn-1 时必须精确还原 }
      if LPns[LI] > 0 then
        CheckEqual(LPns[LI],
          QuicPnDecode(LPns[LI] - 1, LV and ((UInt64(1) shl (8 * LLens[LI])) - 1),
            8 * LLens[LI]));
    end;
  end);

  { ---------- 密钥组派生（RFC 9001 A.1 / A.5 发布值） ---------- }
  LSuite.Test('packet keys match published constants', procedure
  var
    LSec: TQuicInitialSecrets;
    LAesSec, LChaChaSec: TBytes;
    LAesKeys: TQuicPacketKeys;
  begin
    LSec := DeriveQuicInitialSecrets(HexToBytes('8394c8f03e515708'));
    LAesSec := LSec.ClientSecret;
    LAesKeys := QuicMakePacketKeys(LAesSec, qcsAes128GcmSha256);
    CheckEqual('1f369613dd76d5467730efcbe3b1a22d', BytesToHex(LAesKeys.Key));
    CheckEqual('fa044b2f42a3fd3b46fb255c', BytesToHex(LAesKeys.Iv));
    CheckEqual('9f50449e04a0e810283a1e9933adedd2', BytesToHex(LAesKeys.Hp));

    LChaChaSec := HexToBytes(
      '9ac312a7f877468ebe69422748ad00a15443f18203a07d6060f688f30f21632b');
    LChaChaKeys := QuicMakePacketKeys(LChaChaSec, qcsChaCha20Poly1305Sha256);
    CheckEqual(32, Length(LChaChaKeys.Key));
    CheckEqual(12, Length(LChaChaKeys.Iv));
    CheckEqual(32, Length(LChaChaKeys.Hp));
    CheckEqual('c6d98ff3441c3fe1b2182094f69caa2ed4b716b65488960a7a984979fb23e1c8',
      BytesToHex(LChaChaKeys.Key));
    CheckEqual('e0459b3474bdd0e44a41c144', BytesToHex(LChaChaKeys.Iv));
    CheckEqual('25a282b9e82f06f21f488917a4fc8f1b73573685608597d0efcb076b0ab7a7a4',
      BytesToHex(LChaChaKeys.Hp));

    LServerKeys := QuicMakePacketKeys(LSec.ServerSecret, qcsAes128GcmSha256);
    CheckEqual('cf3a5331653c364c88f0f379b6067e37', BytesToHex(LServerKeys.Key));
    LClientKeys := LAesKeys;
  end);

  LSuite.Test('chacha hp mask oracle vectors', procedure
  var
    LMask: TBytes;
  begin
    { RFC 9001 A.5 已知掩码 aefefe7d03 }
    LMask := QuicHeaderProtectionMaskForSuite(LChaChaKeys.Hp,
      HexToBytes('5e5cd55c41f69080575d7999c25a5bfb'),
      qcsChaCha20Poly1305Sha256);
    CheckEqual(5, Length(LMask));
    CheckEqual('aefefe7d03', BytesToHex(LMask));
    { python cryptography 独立 oracle 向量 }
    LMask := QuicHeaderProtectionMaskForSuite(LChaChaKeys.Hp,
      HexToBytes('000102030405060708090a0b0c0d0e0f'),
      qcsChaCha20Poly1305Sha256);
    CheckEqual('eea95834ab', BytesToHex(LMask));
    LMask := QuicHeaderProtectionMaskForSuite(LChaChaKeys.Hp,
      HexToBytes('00000000000000000000000000000000'),
      qcsChaCha20Poly1305Sha256);
    CheckEqual('8683fb9b2d', BytesToHex(LMask));
  end);

  { ---------- A.2 Client Initial 整包黄金向量 ---------- }
  LSuite.Test('A.2 protect byte-exact against RFC packet', procedure
  var
    LClearHdr, LPayload, LOut, LPkt: TBytes;
  begin
    LPayload := PaddedTo(ConstBytes(cFrame), 1162);
    LClearHdr := nil;
    QuicBeginLongHeader(LClearHdr, qltInitial, cQuicVersionV1,
      HexToBytes('8394c8f03e515708'), nil, nil);
    QuicVarintAppend(LClearHdr, 1182);   { Length = pn4 + 1162 + tag16 }
    { 回填明文首字节：form|fixed|Initial(00)|res(00)|pnlen(11)=C3 }
    LClearHdr[0] := QuicLongFirstByte(qltInitial, 0, 3);
    LOut := QuicProtectPacket(LClearHdr, 2, 4, LPayload, LClientKeys);
    LPkt := ConstBytes(cPacket2);
    CheckEqual(Length(LPkt), Length(LOut));
    CheckEqual(BytesToHex(LPkt), BytesToHex(LOut));
    { 首字节应为掩码后形态 c0、明文 PN 线上为 7b9aec34 }
    CheckEqual(Byte($C0), LOut[0]);
    CheckEqual('7b9aec34', HexSlice(LOut, 18, 4));
  end);

  LSuite.Test('A.2 unprotect recovers pn and payload', procedure
  var
    LPkt, LPayload: TBytes;
    LPn: UInt64;
    LOk: Boolean;
  begin
    LPayload := PaddedTo(ConstBytes(cFrame), 1162);
    LPkt := ConstBytes(cPacket2);
    LOk := TryQuicUnprotectPacket(LPkt, -1, LClientKeys, 1, LPn, LPayload);
    CheckTrue(LOk, 'unprotect ok');
    CheckEqual(UInt64(2), LPn, 'pn recovered');
    CheckEqual(1162, Length(LPayload), 'payload len');
    { 前缀 = CRYPTO 帧，其余应为 PADDING 零字节 }
    CheckEqual(BytesToHex(ConstBytes(cFrame)), HexSlice(LPayload, 0, Length(cFrame)), 'frame prefix');
    CheckEqual(True, LPayload[Length(LPayload) - 1] = $00, 'padding tail zero');
  end);

  { ---------- A.3 Server Initial 整包黄金向量 ---------- }
  LSuite.Test('A.3 protect byte-exact both directions', procedure
  var
    LClearHdr, LPayload, LOut, LPkt, LUpPn: TBytes;
    LPn: UInt64;
    LOk: Boolean;
  begin
    LPayload := ConstBytes(cPayload3);
    LClearHdr := nil;
    QuicBeginLongHeader(LClearHdr, qltInitial, cQuicVersionV1,
      HexToBytes(''), HexToBytes('f067a5502a4262b5'), nil);
    QuicVarintAppend(LClearHdr, 117);   { Length = pn2 + 99 + tag16 }
    { 回填明文首字节：Initial|res(00)|pnlen(01)=C1 }
    LClearHdr[0] := QuicLongFirstByte(qltInitial, 0, 1);
    LOut := QuicProtectPacket(LClearHdr, 1, 2, LPayload, LServerKeys);
    LPkt := ConstBytes(cPacket3);
    CheckEqual(Length(LPkt), Length(LOut));
    CheckEqual(BytesToHex(LPkt), BytesToHex(LOut));
    CheckEqual(Byte($CF), LOut[0]);

    LOk := TryQuicUnprotectPacket(LPkt, -1, LServerKeys, 0, LPn, LUpPn);
    CheckTrue(LOk);
    CheckEqual(UInt64(1), LPn);
    CheckEqual(BytesToHex(LPayload), BytesToHex(LUpPn));
  end);

  { ---------- 篡改拒绝面 ---------- }
  LSuite.Test('tampered auth tag rejected at every byte', procedure
  var
    LPkt, LBad: TBytes;
    LPn: UInt64;
    LPay: TBytes;
    LI: Integer;
    LRejected: Boolean;
  begin
    LPkt := ConstBytes(cPacket3);
    { 任一 tag 字节翻转必须失败 }
    LRejected := True;
    for LI := Length(LPkt) - 16 to Length(LPkt) - 1 do
    begin
      LBad := ConstBytes(cPacket3);
      LBad[LI] := LBad[LI] xor $01;
      LRejected := LRejected and
        (not TryQuicUnprotectPacket(LBad, -1, LServerKeys, 0, LPn, LPay));
    end;
    CheckTrue(LRejected);
  end);

  LSuite.Test('payload tamper and wrong key rejected', procedure
  var
    LPkt, LBad: TBytes;
    LPn: UInt64;
    LPay: TBytes;
  begin
    LPkt := ConstBytes(cPacket3);
    LBad := ConstBytes(cPacket3);
    LBad[40] := LBad[40] xor $80;   { 密文中段翻转 }
    CheckFalse(TryQuicUnprotectPacket(LBad, -1, LServerKeys, 0, LPn, LPay));
    CheckFalse(TryQuicUnprotectPacket(LPkt, -1, LClientKeys, 0, LPn, LPay));
    { 首字节保留位污染（模拟错误掩码路径） }
    LBad := ConstBytes(cPacket3);
    LBad[0] := LBad[0] xor $10;
    CheckFalse(TryQuicUnprotectPacket(LBad, -1, LServerKeys, 0, LPn, LPay));
  end);

  LSuite.Test('truncated buffers rejected cleanly', procedure
  var
    LPkt, LSlice: TBytes;
    LPn: UInt64;
    LPay: TBytes;
    LI: Integer;
    LOkAll: Boolean;
  begin
    LPkt := ConstBytes(cPacket3);
    LOkAll := True;
    for LI := 0 to Length(LPkt) - 1 do
    begin
      SetLength(LSlice, LI);
      if LI > 0 then
        Move(LPkt[0], LSlice[0], LI);
      if TryQuicUnprotectPacket(LSlice, -1, LServerKeys, 0, LPn, LPay) then
        LOkAll := False;
    end;
    CheckTrue(LOkAll);
  end);

  { ---------- ChaCha20 短头合成往返 ---------- }
  LSuite.Test('chacha short header synthetic roundtrip', procedure
  var
    LClearHdr, LPayload, LOut: TBytes;
    LPn: UInt64;
    LPay: TBytes;
    LOk: Boolean;
  const
    cBigPn = UInt64(654360564);
  begin
    { 短头首字节：form=0 fixed=1 spin=0 kp=0 res=0 pnlen=10(3B) -> 42 }
    LClearHdr := TBytes.Create($42);
    LPayload := TBytes.Create($01);   { PING 帧 }
    LOut := QuicProtectPacket(LClearHdr, cBigPn, 3, LPayload, LChaChaKeys);
    CheckTrue(Length(LOut) >= 21, 'protect emitted packet');
    CheckEqual(21, Length(LOut), 'packet len');
    LOk := TryQuicUnprotectPacket(LOut, 0, LChaChaKeys, cBigPn - 1, LPn, LPay);
    CheckTrue(LOk, 'unprotect ok');
    CheckEqual(cBigPn, LPn, 'pn recovered');
    CheckEqual(1, Length(LPay), 'payload len');
    CheckEqual(Byte($01), LPay[0], 'payload byte');
    { 确定性：同输入同输出 }
    CheckEqual(BytesToHex(LOut),
      BytesToHex(QuicProtectPacket(LClearHdr, cBigPn, 3, LPayload, LChaChaKeys)));
  end);

  LSuite.Test('header peek on protected packets', procedure
  var
    LPkt: TBytes;
    LInfo: TQuicHeaderPeek;
  begin
    LPkt := ConstBytes(cPacket2);
    CheckTrue(TryPeekQuicHeader(LPkt, -1, LInfo));
    CheckTrue(LInfo.IsLong);
    CheckEqual(UInt32(cQuicVersionV1), LInfo.Version);
    CheckEqual(Int64(Ord(qltInitial)), Int64(Ord(LInfo.PacketType)));
    CheckEqual('8394c8f03e515708', BytesToHex(LInfo.DstCid));
    CheckEqual(18, LInfo.PnOffset);
    CheckEqual(UInt64(1182), LInfo.Length);

    LPkt := ConstBytes(cPacket3);
    CheckTrue(TryPeekQuicHeader(LPkt, -1, LInfo));
    CheckEqual(0, Length(LInfo.DstCid));
    CheckEqual('f067a5502a4262b5', BytesToHex(LInfo.SrcCid));
    CheckEqual(UInt64(117), LInfo.Length);
  end);

  LSuite.Test('header peek rejects malformed', procedure
  var
    LInfo: TQuicHeaderPeek;
  begin
    CheckFalse(TryPeekQuicHeader(nil, -1, LInfo));
    { 固定位为 0 且非长头 -> 拒 }
    CheckFalse(TryPeekQuicHeader(HexToBytes('00'), -1, LInfo));
    { 长头但缓冲不足版本字段 }
    CheckFalse(TryPeekQuicHeader(HexToBytes('ff0000'), -1, LInfo));
    { DCID 长度声明越界 }
    CheckFalse(TryPeekQuicHeader(HexToBytes('e300000001ff'), -1, LInfo));
  end);

  { 源码契约：四个新单元不得裸 uses FPC RTL }
  LSuite.Test('source contract: no bare FPC RTL in quic units', procedure
  var
    LSrcPath, LHit: string;
    LNames: array[0..3] of string;
    LI: Integer;
  begin
    LNames[0] := 'nextpas.core.net.quic.pn.pas';
    LNames[1] := 'nextpas.core.net.quic.header.pas';
    LNames[2] := 'nextpas.core.net.quic.tls.pas';
    LNames[3] := 'nextpas.core.net.quic.protect.pas';
    for LI := 0 to 3 do
    begin
      LSrcPath := FsPathAbs(FsPathJoin([FsPathDir(ParamStr(0)),
        '..', '..', '..', '..', 'src', LNames[LI]]));
      Check(not FindBareFpcRtlInUses(FsReadFileText(LSrcPath), LHit),
        LNames[LI] + ' — no bare FPC RTL (hit: ' + LHit + ')');
    end;
  end);

  LRunner := TSuiteRunner.Create('nextpas.core.net.quic.protect');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then Halt(1);
end.
