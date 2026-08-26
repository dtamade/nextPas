program test_ssh_cipher;

{$I nextpas.core.settings.inc}

{ S2 gate：包加密编解码器。
 * 覆盖：算法表、工厂拒绝路径、chacha/gcm/ctr+etm 三族多包往返（含计数器连续性）、
 * OpenSSH 构造的独立 oracle 字节比对（RFC 8439 nonce 映射 / RFC 5647 IV 计数）、
 * 篡改检测、RFC 4231 HMAC-SHA2 向量。}

uses
  nextpas.core.system.sysutils,
  nextpas.core.ssh.base,
  nextpas.core.ssh.errors,
  nextpas.core.ssh.buffer,
  nextpas.core.ssh.cipher,
  nextpas.core.crypto.chacha20poly1305,
  nextpas.core.crypto.aesgcm,
  nextpas.core.crypto.hmac,
  nextpas.core.hash.base,
  nextpas.core.hash.intf,
  nextpas.core.test;

function HexToBytes(const AHex: string): TBytes;
var
  I: Integer;
begin
  Result := nil;
  SetLength(Result, Length(AHex) div 2);
  for I := 0 to High(Result) do
    Result[I] := StrToInt('$' + Copy(AHex, I * 2 + 1, 2));
end;

{ hex 字节串 → 原始字符内容（RFC 向量的 ASCII 数据）}
function HexToAscii(const AHex: string): string;
begin
  Result := '';
  SetLength(Result, Length(AHex) div 2);
  if Length(AHex) > 0 then
    Move(HexToBytes(AHex)[0], PByte(PChar(Result))^, Length(AHex) div 2);
end;

function BytesToHex(const AData: TBytes): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(AData) do
    Result := Result + LowerCase(IntToHex(AData[I], 2));
end;

procedure PutU32BEInto(var ADst: TBytes; APos: SizeUInt; AValue: UInt32);
begin
  ADst[APos] := Byte(AValue shr 24);
  ADst[APos + 1] := Byte((AValue shr 16) and $FF);
  ADst[APos + 2] := Byte((AValue shr 8) and $FF);
  ADst[APos + 3] := Byte(AValue and $FF);
end;

{ 确定性测试材料：重复填充 pattern }
function PatternBytes(APattern: Byte; ACount: Integer): TBytes;
begin
  Result := nil;
  SetLength(Result, ACount);
  if ACount > 0 then
    FillChar(Result[0], SizeUInt(ACount), APattern);
end;

type
  { 匿名断言块 }
  TVoidProc = reference to procedure;

procedure AssertNegotiationError(AProc: TVoidProc);
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    AProc;
  except
    on E: ESSHError do
    begin
      LRaised := True;
      CheckEqual(Ord(sekNegotiation), Ord(E.Kind));
    end;
  end;
  CheckTrue(LRaised, 'expected ESSHError(sekNegotiation)');
end;

procedure AssertCryptoError(AProc: TVoidProc);
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    AProc;
  except
    on E: ESSHError do
    begin
      LRaised := True;
      CheckEqual(Ord(sekCrypto), Ord(E.Kind));
    end;
  end;
  CheckTrue(LRaised, 'expected ESSHError(sekCrypto)');
end;

var
  LRunner: TSuiteRunner;
  LSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('ssh cipher');

  LSuite.Test('algorithm tables', procedure
  begin
    CheckTrue(SshCipherSupported('chacha20-poly1305@openssh.com'));
    CheckTrue(SshCipherSupported('aes256-gcm@openssh.com'));
    CheckTrue(SshCipherSupported('aes128-gcm@openssh.com'));
    CheckTrue(SshCipherSupported('aes256-ctr') and SshCipherSupported('aes192-ctr')
      and SshCipherSupported('aes128-ctr'));
    CheckFalse(SshCipherSupported('3des-ctr'));
    { '' 语义上是 none，属于受支持集合（工厂另有拒绝策略）}
    CheckTrue(SshCipherSupported(''));

    CheckTrue(SshMacSupported('hmac-sha2-256-etm@openssh.com'));
    CheckTrue(SshMacSupported('hmac-sha2-512-etm@openssh.com'));
    CheckFalse(SshMacSupported('hmac-sha1'));
    CheckFalse(SshMacSupported('hmac-sha1-etm@openssh.com'));

    { KDF 切片长度 }
    CheckEqual(64, SshCipherKeySize('chacha20-poly1305@openssh.com'));
    CheckEqual(32, SshCipherKeySize('aes256-gcm@openssh.com'));
    CheckEqual(16, SshCipherKeySize('aes128-gcm@openssh.com'));
    CheckEqual(32, SshCipherKeySize('aes256-ctr'));
    CheckEqual(24, SshCipherKeySize('aes192-ctr'));
    CheckEqual(16, SshCipherKeySize('aes128-ctr'));
    CheckEqual(0, SshCipherIvSize('chacha20-poly1305@openssh.com'));
    CheckEqual(12, SshCipherIvSize('aes256-gcm@openssh.com'));
    CheckEqual(16, SshCipherIvSize('aes128-ctr'));
    CheckEqual(32, SshMacKeySize('hmac-sha2-256-etm@openssh.com'));
    CheckEqual(64, SshMacKeySize('hmac-sha2-512-etm@openssh.com'));

    { ctr 族必须配 ETM MAC，AEAD 不需要 }
    CheckTrue(SshCipherRequiresMac('aes128-ctr'));
    CheckFalse(SshCipherRequiresMac('chacha20-poly1305@openssh.com'));
    CheckFalse(SshCipherRequiresMac('aes256-gcm@openssh.com'));

    { padding 对齐块：chacha 8，AES 族 16 }
    CheckEqual(8, CreateSshPacketSender('chacha20-poly1305@openssh.com', '',
      PatternBytes($AA, 64), nil, nil).PaddingBlock);
    CheckEqual(16, CreateSshPacketSender('aes256-gcm@openssh.com', '',
      PatternBytes($BB, 32), PatternBytes($01, 12), nil).PaddingBlock);
    CheckEqual(16, CreateSshPacketSender('aes128-ctr', 'hmac-sha2-256-etm@openssh.com',
      PatternBytes($CC, 16), PatternBytes($02, 16), PatternBytes($DD, 32)).PaddingBlock);
  end);

  LSuite.Test('factory rejects bad combos', procedure
  begin
    AssertNegotiationError(procedure
      begin
        CreateSshPacketSender('blowfish-cbc', '', nil, nil, nil);
      end);
    AssertNegotiationError(procedure
      begin
        { ctr 无 etm mac 必须拒绝 }
        CreateSshPacketSender('aes128-ctr', '',
          PatternBytes($11, 16), PatternBytes($22, 16), nil);
      end);
    AssertNegotiationError(procedure
      begin
        CreateSshPacketReceiver('aes128-ctr', 'hmac-sha1',
          PatternBytes($11, 16), PatternBytes($22, 16), PatternBytes($33, 20));
      end);
  end);

  LSuite.Test('chacha multi-packet roundtrip with frame helpers', procedure
  var
    LSend: ISshPacketSender;
    LRecv: ISshPacketReceiver;
    LKeyMat, LBody, LWire, LBack: TBytes;
    LSeq: UInt32;
    LHeader: TBytes;
    LRaised: Boolean;
  begin
    LKeyMat := HexToBytes('000102030405060708090a0b0c0d0e0f'
      + '101112131415161718191a1b1c1d1e1f'
      + '202122232425262728292a2b2c2d2e2f'
      + '303132333435363738393a3b3c3d3e3f');
    CheckEqual(64, Length(LKeyMat));
    LSend := CreateSshPacketSender('chacha20-poly1305@openssh.com', '', LKeyMat, nil, nil);
    LRecv := CreateSshPacketReceiver('chacha20-poly1305@openssh.com', '', LKeyMat, nil, nil);
    for LSeq := 0 to 2 do
    begin
      LBody := PatternBytes(Byte($40 + LSeq), 100 + 8 * Integer(LSeq) + 1);
      LWire := LSend.Protect(LBody, LSeq);
      { wire = 4B 掩码长度 + 密文 + 16B tag }
      CheckEqual(Int64(4 + Length(LBody) + 16), Int64(Length(LWire)));

      LHeader := Copy(LWire, 0, 4);
      CheckEqual(UInt64(Length(LBody)), UInt64(LRecv.BodyLengthFromHeader(LSeq, LHeader)));
      CheckEqual(UInt64(Length(LBody) + 16), UInt64(LRecv.TrailerSize(Length(LBody))));

      LBack := LRecv.Unprotect(LSeq, LWire);
      CheckEqual(BytesToHex(LBody), BytesToHex(LBack), 'roundtrip seq=' + IntToStr(LSeq));
    end;

    { 篡改密文中间字节 → AEAD 校验失败 }
    LBody := PatternBytes($43, 117);
    LWire := LSend.Protect(LBody, 2);
    LWire[10] := LWire[10] xor $01;
    LRaised := False;
    try
      LRecv.Unprotect(2, LWire);
    except
      on E: ESSHError do
      begin
        LRaised := True;
        CheckEqual(Ord(sekCrypto), Ord(E.Kind));
      end;
    end;
    CheckTrue(LRaised, 'expected tamper rejection');
  end);

  LSuite.Test('chacha wire matches OpenSSH construction oracle', procedure
  var
    LKeyMat, LMainKey, LHeaderKey, LNonce, LMask, LEncLen, LOracl, LWire: TBytes;
    LCt, LPolyKey, LMacData, LTag: TBytes;
    LSend: ISshPacketSender;
    LBody: TBytes;
    LLenField: UInt32;
  begin
    LKeyMat := PatternBytes($C7, 64);
    LMainKey := Copy(LKeyMat, 0, 32);
    LHeaderKey := Copy(LKeyMat, 32, 32);
    LBody := HexToBytes('cafed00dbaabe001');
    LLenField := UInt32(Length(LBody));

    { RFC 8439 nonce 映射：nonce12 = $00000000 || seq_BE64 低 32 位 }
    SetLength(LNonce, 12);
    FillChar(LNonce[0], 4, 0);
    LNonce[8] := $7F; LNonce[9] := $01; LNonce[10] := $E2; LNonce[11] := $33;

    { 长度字段掩码 = header key 的 counter=0 块首 4 字节（RFC 8439 §2.3.2 映射）}
    LMask := ChaCha20Block(LHeaderKey, LNonce, 0);
    SetLength(LEncLen, 4);
    LEncLen[0] := Byte(LLenField shr 24) xor LMask[0];
    LEncLen[1] := Byte((LLenField shr 16) and $FF) xor LMask[1];
    LEncLen[2] := Byte((LLenField shr 8) and $FF) xor LMask[2];
    LEncLen[3] := Byte(LLenField and $FF) xor LMask[3];

    { OpenSSH 构造（PROTOCOL.chacha20poly1305）：
      ct = main 流 counter=1；tag = 裸 Poly1305(encLen||ct)，key = main 块 0 前 32B }
    LCt := ChaCha20Xor(LMainKey, LNonce, 1, LBody);
    LPolyKey := Copy(ChaCha20Block(LMainKey, LNonce, 0), 0, 32);
    SetLength(LMacData, 4 + SizeUInt(Length(LCt)));
    Move(LEncLen[0], LMacData[0], 4);
    Move(LCt[0], LMacData[4], SizeUInt(Length(LCt)));
    LTag := Poly1305Raw(LPolyKey, LMacData);
    SetLength(LOracl, 4 + SizeUInt(Length(LCt)) + 16);
    Move(LEncLen[0], LOracl[0], 4);
    Move(LCt[0], LOracl[4], SizeUInt(Length(LCt)));
    Move(LTag[0], LOracl[4 + Length(LCt)], 16);

    LSend := CreateSshPacketSender('chacha20-poly1305@openssh.com', '', LKeyMat, nil, nil);
    LWire := LSend.Protect(LBody, $7F01E233);
    CheckEqual(BytesToHex(LOracl), BytesToHex(LWire),
      'full wire must equal independent oracle');
  end);

  LSuite.Test('gcm roundtrip and counter advance', procedure
  var
    LIV, LBody, LWire, LBack: TBytes;
    LSend: ISshPacketSender;
    LRecv: ISshPacketReceiver;
    LSeq: UInt32;
    LRaised: Boolean;
  begin
    LSend := CreateSshPacketSender('aes256-gcm@openssh.com', '',
      PatternBytes($31, 32), PatternBytes($5A, 12), nil);
    LRecv := CreateSshPacketReceiver('aes256-gcm@openssh.com', '',
      PatternBytes($31, 32), PatternBytes($5A, 12), nil);
    for LSeq := 10 to 12 do
    begin
      LBody := PatternBytes(Byte($50 + LSeq), 48);
      LWire := LSend.Protect(LBody, LSeq);
      CheckEqual(Int64(4 + Length(LBody) + 16), Int64(Length(LWire)));
      LBack := LRecv.Unprotect(LSeq, LWire);
      CheckEqual(BytesToHex(LBody), BytesToHex(LBack), 'gcm roundtrip seq=' + IntToStr(LSeq));
    end;

    { aes128-gcm@openssh.com 同路径 }
    LSend := CreateSshPacketSender('aes128-gcm@openssh.com', '',
      PatternBytes($77, 16), PatternBytes($6B, 12), nil);
    LRecv := CreateSshPacketReceiver('aes128-gcm@openssh.com', '',
      PatternBytes($77, 16), PatternBytes($6B, 12), nil);
    LBody := PatternBytes($99, 17);
    LWire := LSend.Protect(LBody, 0);
    LBack := LRecv.Unprotect(0, LWire);
    CheckEqual(BytesToHex(LBody), BytesToHex(LBack));

    { 篡改 tag → sekCrypto }
    LWire[Length(LWire) - 1] := LWire[Length(LWire) - 1] xor $80;
    LRaised := False;
    try
      LRecv.Unprotect(0, LWire);
    except
      on E: ESSHError do
      begin
        LRaised := True;
        CheckEqual(Ord(sekCrypto), Ord(E.Kind));
      end;
    end;
    CheckTrue(LRaised, 'expected gcm tamper rejection');
  end);

  LSuite.Test('gcm wire matches RFC 5647 counter oracle', procedure
  var
    LKey, LIV, LLenField, LCt, LTag, LOracl, LWire: TBytes;
    LSend: ISshPacketSender;
    LBody, LNonce: TBytes;
  begin
    LKey := PatternBytes($E3, 32);
    LIV := HexToBytes('00112233445566778899aabb');
    LBody := PatternBytes($42, 32);

    { RFC 5647：调用计数器从 1 起 → nonce = 前 8 字节 || BE32(1)；
      长度字段明文作为 AAD }
    SetLength(LLenField, 4);
    PutU32BEInto(LLenField, 0, UInt32(Length(LBody)));
    SetLength(LNonce, 12);
    Move(LIV[0], LNonce[0], 8);
    PutU32BEInto(LNonce, 8, 1);
    CheckTrue(PurePascalAESGCMEncrypt(LKey, LNonce, LBody, LLenField, LCt, LTag));
    SetLength(LOracl, 4 + Length(LCt) + Length(LTag));
    Move(LLenField[0], LOracl[0], 4);
    Move(LCt[0], LOracl[4], SizeUInt(Length(LCt)));
    Move(LTag[0], LOracl[4 + Length(LCt)], SizeUInt(Length(LTag)));

    LSend := CreateSshPacketSender('aes256-gcm@openssh.com', '', LKey, LIV, nil);
    LWire := LSend.Protect(LBody, 0);
    CheckEqual(BytesToHex(LOracl), BytesToHex(LWire),
      'gcm packet must equal independent counter=1 oracle');
  end);

  LSuite.Test('ctr+etm roundtrip keeps keystream across packets', procedure
  var
    LSend: ISshPacketSender;
    LRecv: ISshPacketReceiver;
    LBody, LWire, LBack: TBytes;
    LSeq: UInt32;
  begin
    LSend := CreateSshPacketSender('aes192-ctr', 'hmac-sha2-512-etm@openssh.com',
      PatternBytes($A5, 24), PatternBytes($0F, 16), PatternBytes($66, 64));
    LRecv := CreateSshPacketReceiver('aes192-ctr', 'hmac-sha2-512-etm@openssh.com',
      PatternBytes($A5, 24), PatternBytes($0F, 16), PatternBytes($66, 64));
    for LSeq := 0 to 3 do
    begin
      { 跨包非块对齐长度，检验 keystream 连续性 }
      LBody := PatternBytes(Byte($20 + LSeq), 13 + 7 * Integer(LSeq));
      LWire := LSend.Protect(LBody, LSeq);
      CheckEqual(Int64(4 + Length(LBody) + 64), Int64(Length(LWire)));
      LBack := LRecv.Unprotect(LSeq, LWire);
      CheckEqual(BytesToHex(LBody), BytesToHex(LBack),
        'ctr roundtrip seq=' + IntToStr(LSeq));
    end;
  end);

  LSuite.Test('ctr tamper detection both directions', procedure
  var
    LSend: ISshPacketSender;
    LRecv: ISshPacketReceiver;
    LBody, LWire: TBytes;
    LRaised: Boolean;
  begin
    LSend := CreateSshPacketSender('aes128-ctr', 'hmac-sha2-256-etm@openssh.com',
      PatternBytes($9D, 16), PatternBytes($71, 16), PatternBytes($08, 32));
    LRecv := CreateSshPacketReceiver('aes128-ctr', 'hmac-sha2-256-etm@openssh.com',
      PatternBytes($9D, 16), PatternBytes($71, 16), PatternBytes($08, 32));
    LBody := PatternBytes($EE, 21);

    { 翻转密文字节 → MAC 失配 }
    LWire := LSend.Protect(LBody, 5);
    LWire[6] := LWire[6] xor $10;
    LRaised := False;
    try
      LRecv.Unprotect(5, LWire);
    except
      on E: ESSHError do
      begin
        LRaised := True;
        CheckEqual(Ord(sekCrypto), Ord(E.Kind));
      end;
    end;
    CheckTrue(LRaised, 'cipher tamper must reject');

    { 恢复后翻转 MAC 尾字节 → 同样失败 }
    LWire := LSend.Protect(LBody, 5);
    LWire[Length(LWire) - 1] := LWire[Length(LWire) - 1] xor $FF;
    LRaised := False;
    try
      LRecv.Unprotect(5, LWire);
    except
      on E: ESSHError do
      begin
        LRaised := True;
        CheckEqual(Ord(sekCrypto), Ord(E.Kind));
      end;
    end;
    CheckTrue(LRaised, 'mac tail tamper must reject');

    { 序列号不一致 → MAC 失配（EtM 输入包含 seq）}
    LWire := LSend.Protect(LBody, 6);
    LRaised := False;
    try
      LRecv.Unprotect(5, LWire);
    except
      on E: ESSHError do
      begin
        LRaised := True;
        CheckEqual(Ord(sekCrypto), Ord(E.Kind));
      end;
    end;
    CheckTrue(LRaised, 'seq mismatch must reject');
  end);

  { EtM MAC 路径使用的 SHA-2 HMAC 原语对照 RFC 4231 }
  LSuite.Test('RFC 4231 HMAC-SHA-256/512 vectors', procedure

    function NewHmacHex(const AAlgo: THashAlgorithm; const AKeyHex, ADataHex: string): string;
    var
      LKey, LData: TBytes;
      LHasher: IHasher;
    begin
      LKey := HexToBytes(AKeyHex);
      LData := HexToBytes(ADataHex);
      LHasher := NewHMAC(AAlgo, LKey[0], SizeUInt(Length(LKey)));
      if Length(LData) > 0 then
        LHasher.Write(LData[0], SizeUInt(Length(LData)));
      Result := BytesToHex(LHasher.SumBytes);
    end;

  begin
    { Test Case 1：key=0x0b x20，data="Hi There" }
    CheckEqual('b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7',
      NewHmacHex(haSHA256, '0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b', '4869205468657265'));
    CheckEqual('87aa7cdea5ef619d4ff0b4241a1d6cb02379f4e2ce4ec2787ad0b30545e17cde'
      + 'daa833b7d6b8a702038b274eaea3f4e4be9d914eeb61f1702e696c203a126854',
      NewHmacHex(haSHA512, '0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b', '4869205468657265'));

    { Test Case 2：key="Jefe"，data="what do ya want for nothing?" }
    CheckEqual('5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843',
      NewHmacHex(haSHA256, '4a656665',
        '7768617420646f2079612077616e7420666f72206e6f7468696e673f'));
    CheckEqual('164b7a7bfcf819e2e395fbe73b56e0a387bd64222e831fd610270cd7ea250554'
      + '9758bf75c05a994a6d034f65f8f0e6fdcaeab1a34d4a6b4b636e070a38bce737',
      NewHmacHex(haSHA512, '4a656665',
        '7768617420646f2079612077616e7420666f72206e6f7468696e673f'));
  end);

  LRunner := TSuiteRunner.Create('nextpas.core.ssh.cipher');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then Halt(1);
end.
