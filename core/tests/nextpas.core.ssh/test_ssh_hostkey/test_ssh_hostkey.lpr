program test_ssh_hostkey;

{$I nextpas.core.settings.inc}

{ S3 gate：主机公钥解析、验签、指纹与 known_hosts。
 * 覆盖：ed25519/rsa blob 解析与错误路径、SHA256 指纹格式、
 * ed25519 真实签名验证（正/负路径）、RSA PKCS#1 v1.5 验证
 * （e=1 数学构造的正例 + 篡改负例）、通配符匹配、
 * known_hosts 明文/[host]:port/|1| 散列条目与文件加载。}

uses
  nextpas.core.bytes.ops,
  nextpas.core.ssh.base,
  nextpas.core.ssh.errors,
  nextpas.core.ssh.buffer,
  nextpas.core.ssh.hostkey,
  nextpas.core.crypto.ed25519,
  nextpas.core.crypto.ecdsa,
  nextpas.core.crypto.asn1,
  nextpas.core.crypto.hmac,
  nextpas.core.crypto.hash,
  nextpas.core.hash.base,
  nextpas.core.encoding.base64,
  nextpas.core.platform.files.text,
  ssh_rsa_kat,
  nextpas.core.test, nextpas.core.base, nextpas.core.fs, nextpas.core.text.conv;

function HexToBytes(const AHex: string): TBytes;
var
  I: Integer;
begin
  Result := nil;
  SetLength(Result, Length(AHex) div 2);
  for I := 0 to High(Result) do
    Result[I] := StrToInt('$' + Copy(AHex, I * 2 + 1, 2));
end;

function PatternBytes(APattern: Byte; ACount: Integer): TBytes;
begin
  Result := nil;
  SetLength(Result, ACount);
  if ACount > 0 then
    FillChar(Result[0], SizeUInt(ACount), APattern);
end;

function BytesToHex(const AData: TBytes): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(AData) do
    Result := Result + LowerCase(IntToHex(AData[I], 2));
end;

{ string(alg) || string(sig) 结构 }
function SigBlobOf(const AAlgName: string; const ARawSig: TBytes): TBytes;
var
  LW: TsshWriter;
begin
  Result := nil;
  LW := TsshWriter.Create(128);
  try
    LW.PutStringText(AAlgName);
    LW.PutStringBytes(ARawSig);
    Result := LW.ToBytes;
  finally
    LW.Free;
  end;
end;

function Ed25519HostKeyBlob(const APub: TBytes): TBytes;
var
  LW: TsshWriter;
begin
  Result := nil;
  LW := TsshWriter.Create(64);
  try
    LW.PutStringText('ssh-ed25519');
    LW.PutStringBytes(APub);
    Result := LW.ToBytes;
  finally
    LW.Free;
  end;
end;

function RsaHostKeyBlob(const AE, AN: TBytes): TBytes;
var
  LW: TsshWriter;
begin
  Result := nil;
  LW := TsshWriter.Create(256);
  try
    LW.PutStringText('ssh-rsa');
    LW.PutMPInt(AE);
    LW.PutMPInt(AN);
    Result := LW.ToBytes;
  finally
    LW.Free;
  end;
end;

function EcdsaSshSigRaw(const ADER: TBytes): TBytes;
var
  LR: TASN1Reader;
  LRoot: TASN1Node;
  LRBytes, LSBytes: TBytes;
  LW: TsshWriter;
begin
  Result := nil;
  LR := TASN1Reader.Create(ADER);
  try
    LRoot := LR.Parse;
    try
      LRBytes := LRoot.GetChild(0).AsBigInteger;
      LSBytes := LRoot.GetChild(1).AsBigInteger;
    finally
      LRoot.Free;
    end;
  finally
    LR.Free;
  end;
  LW := TsshWriter.Create(80);
  try
    LW.PutMPInt(LRBytes);
    LW.PutMPInt(LSBytes);
    Result := LW.ToBytes;
  finally
    LW.Free;
  end;
end;

const
  { RFC 8017 §9.2 DigestInfo 前缀（SHA-256），与实现一致 }
  DIGEST_INFO_SHA256_HEX = '3031300d060960864801650304020105000420';

{ 断言 blob 解析抛 sekKeyFormat }
procedure ExpectKeyFormatError(const ABlob: TBytes);
var
  LInfo: TSshHostKeyInfo;
  LRaised: Boolean;
begin
  LRaised := False;
  try
    SshParseHostKey(ABlob, LInfo);
  except
    on E: ESSHError do
    begin
      LRaised := True;
      CheckEqual(Ord(sekKeyFormat), Ord(E.Kind));
    end;
  end;
  CheckTrue(LRaised, 'expected ESSHError(sekKeyFormat)');
end;

var
  LRunner: TSuiteRunner;
  LSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('ssh hostkey');

  LSuite.Test('ed25519 blob parse', procedure
  var
    LBlob: TBytes;
    LInfo: TSshHostKeyInfo;
    LPub, LSeed: TBytes;
  begin
    SetLength(LSeed, 32);
    FillChar(LSeed[0], 32, $E7);
    LPub := Ed25519PublicKeyFromPrivate(LSeed);
    CheckEqual(Int64(32), Int64(Length(LPub)));
    LBlob := Ed25519HostKeyBlob(LPub);
    CheckTrue(SshParseHostKey(LBlob, LInfo));
    CheckEqual('ssh-ed25519', LInfo.AlgName);
    CheckEqual(Ord(hkEd25519), Ord(LInfo.Kind));
    CheckEqual(BytesToHex(LPub), BytesToHex(LInfo.Ed25519Pub));

    { 公钥长度非 32 → sekKeyFormat }
    ExpectKeyFormatError(Ed25519HostKeyBlob(PatternBytes($11, 31)));
  end);

  LSuite.Test('rsa blob parse and rejects', procedure
  var
    LInfo: TSshHostKeyInfo;
    LE, LN: TBytes;
    LW: TsshWriter;
  begin
    LE := HexToBytes('010001');
    LN := PatternBytes($FF, 64);
    CheckTrue(SshParseHostKey(RsaHostKeyBlob(LE, LN), LInfo));
    CheckEqual(Ord(hkRsa), Ord(LInfo.Kind));
    { e=65537 的 magnitude 字节 }
    CheckEqual('010001', BytesToHex(LInfo.RsaE));
    CheckEqual(Int64(64), Int64(Length(LInfo.RsaN)));

    { N < 32 字节 → sekKeyFormat }
    ExpectKeyFormatError(RsaHostKeyBlob(LE, PatternBytes($FF, 16)));
    { 空 E → sekKeyFormat }
    ExpectKeyFormatError(RsaHostKeyBlob(nil, LN));

    { 未知算法返回 False：string('ssh-dss') 后无字段 }
    LW := TsshWriter.Create(32);
    try
      LW.PutStringText('ssh-dss');
      CheckFalse(SshParseHostKey(LW.ToBytes, LInfo));
    finally
      LW.Free;
    end;
  end);

  LSuite.Test('fingerprint format matches independent encoding', procedure
  var
    LBlob, LDigest: TBytes;
    LB64: string;
    LExpect: string;
  begin
    LBlob := PatternBytes($C9, 51);
    LDigest := SHA256(LBlob);
    LB64 := Base64Encode(LDigest);
    while (Length(LB64) > 0) and (LB64[Length(LB64)] = '=') do
      Delete(LB64, Length(LB64), 1);
    LExpect := 'SHA256:' + LB64;
    CheckEqual(LExpect, SshFingerprintSHA256(LBlob));
    { 无填充：结尾不应有 '=' }
    CheckTrue(Copy(SshFingerprintSHA256(LBlob), Length(SshFingerprintSHA256(LBlob)), 1) <> '=');
  end);

  LSuite.Test('ed25519 signature verify positive and negative', procedure
  var
    LSeed, LPub, LAH, LSig: TBytes;
    LInfo: TSshHostKeyInfo;
  begin
    SetLength(LSeed, 32);
    FillChar(LSeed[0], 32, $E7);
    LPub := Ed25519PublicKeyFromPrivate(LSeed);
    CheckTrue(SshParseHostKey(Ed25519HostKeyBlob(LPub), LInfo));
    LAH := SHA256(PatternBytes($33, 100));

    CheckTrue(Ed25519Sign(LSeed, LAH, LSig), 'signing must succeed');
    CheckTrue(SshVerifyHostSignature(LInfo, 'ssh-ed25519', LAH,
      SigBlobOf('ssh-ed25519', LSig)), 'valid sig must verify');

    { 篡改 H → False }
    CheckFalse(SshVerifyHostSignature(LInfo, '', BytesConcat(Copy(LAH, 0, 31),
      HexToBytes('ff')), SigBlobOf('ssh-ed25519', LSig)));

    { 协商算法与签名算法不一致 → False }
    CheckFalse(SshVerifyHostSignature(LInfo, 'rsa-sha2-512', LAH,
      SigBlobOf('ssh-ed25519', LSig)));

    { 错误的签名长度 → False }
    CheckFalse(SshVerifyHostSignature(LInfo, '', LAH, SigBlobOf('ssh-ed25519',
      PatternBytes($01, 63))));
  end);

  { RSA e=1 数学构造：sig^1 mod n = sig，因此 EM 本身即合法签名。
    该构造只用于验证实现的 PKCS#1 v1.5 比对逻辑，不依赖 RSA 签名器。}
  LSuite.Test('rsa pkcs1 v1.5 verify via e=1 construction', procedure
  var
    LInfo: TSshHostKeyInfo;
    LN, LEM, LAH, LSig: TBytes;
    LW: TsshWriter;
    I, LPsLen: Integer;
  begin
    LN := PatternBytes($FF, 64);          { 模长 64 字节，大于任何 EM }
    CheckTrue(SshParseHostKey(RsaHostKeyBlob(HexToBytes('01'), LN), LInfo));
    LAH := SHA256(PatternBytes($44, 77));

    { 构造期望 EM = 00 01 FF..FF 00 || DigestInfo || Hash，定长 64 }
    SetLength(LEM, 64);
    FillChar(LEM[0], 64, 0);
    LEM[1] := $01;
    LPsLen := 64 - 3 - (Length(HexToBytes(DIGEST_INFO_SHA256_HEX)) + 32);
    for I := 2 to LPsLen + 1 do
      LEM[I] := $FF;
    LEM[LPsLen + 2] := $00;
    LW := TsshWriter.Create(128);
    try
      LW.PutRaw(HexToBytes(DIGEST_INFO_SHA256_HEX));
      LW.PutRaw(LAH);
      Move(LW.ToBytes[0], LEM[LPsLen + 3],
        SizeUInt(Length(HexToBytes(DIGEST_INFO_SHA256_HEX)) + 32));
    finally
      LW.Free;
    end;

    LSig := LEM;
    CheckTrue(SshVerifyHostSignature(LInfo, 'rsa-sha2-256', LAH,
      SigBlobOf('rsa-sha2-256', LSig)), 'e=1 constructed rsa sig must verify');

    { 篡改签名一个字节 → False }
    LSig[20] := LSig[20] xor $08;
    CheckFalse(SshVerifyHostSignature(LInfo, '', LAH, SigBlobOf('rsa-sha2-256', LSig)));
  end);

  { 外部黄金向量：openssl dgst -sha256/-sha512 -sign 对固定消息产出。
    e=1 构造只覆盖 EM 比对逻辑，这里用真实 RSA 签名双向锁定两条
    DigestInfo 路径——SHA-512 前缀曾带错摘要长度字节（$20 应为 $40）
    且无外部向量覆盖，真实签名恒验败。 }
  LSuite.Test('rsa pkcs1 v1.5 verify against openssl signatures', procedure
  var
    LInfo: TSshHostKeyInfo;
    LN, LMsgBytes, LSig256, LSig512: TBytes;
  begin
    LN := KatN;
    CheckTrue(SshParseHostKey(RsaHostKeyBlob(HexToBytes(KAT_E_HEX), LN), LInfo));
    LMsgBytes := KatMsg;
    LSig256 := KatSigSha256;
    LSig512 := KatSigSha512;
    CheckEqual(Int64(256), Int64(Length(LSig256)));
    CheckEqual(Int64(256), Int64(Length(LSig512)));

    CheckTrue(SshVerifyHostSignature(LInfo, 'rsa-sha2-256', SHA256(LMsgBytes),
      SigBlobOf('rsa-sha2-256', LSig256)), 'openssl sha256 sig must verify');
    CheckTrue(SshVerifyHostSignature(LInfo, 'rsa-sha2-512', SHA512(LMsgBytes),
      SigBlobOf('rsa-sha2-512', LSig512)), 'openssl sha512 sig must verify');

    { 摘要与签名算法错配 / 篡改 → False }
    CheckFalse(SshVerifyHostSignature(LInfo, 'rsa-sha2-512', SHA512(LMsgBytes),
      SigBlobOf('rsa-sha2-512', LSig256)));
    LSig512[100] := LSig512[100] xor $10;
    CheckFalse(SshVerifyHostSignature(LInfo, '', SHA512(LMsgBytes),
      SigBlobOf('rsa-sha2-512', LSig512)));
  end);

  LSuite.Test('wildmatch semantics', procedure
  begin
    CheckTrue(SshWildMatch('*.example.com', 'host.example.com'));
    CheckTrue(SshWildMatch('host?', 'host1'));
    CheckTrue(SshWildMatch('*', 'anything'));
    CheckTrue(SshWildMatch('a*b*c', 'aXXbYYc'));
    CheckFalse(SshWildMatch('*.example.com', 'example.com'));
    CheckFalse(SshWildMatch('host?', 'host12'));
    CheckFalse(SshWildMatch('a?c', 'abcX'));
  end);

  LSuite.Test('knownhosts plaintext port and hashed entries', procedure
  var
    LKH: TSshKnownHosts;
    LBlobA, LBlobB, LSalt, LHash: TBytes;
    LLine: string;
  begin
    LKH := TSshKnownHosts.Create;
    try
      LBlobA := PatternBytes($AA, 48);
      LBlobB := PatternBytes($BB, 48);

      { 注释 / @marker / 空行 / 字段不足 全部跳过 }
      LKH.AddLine('# a comment');
      LKH.AddLine('@cert-authority *.example.com AAAA');
      LKH.AddLine('');
      LKH.AddLine('only-one-field');
      CheckEqual(Int64(0), Int64(LKH.Count));

      { 明文条目：多空格分隔（空字段剔除）也接受 }
      LKH.AddLine('host1.example.com,*.example.com   ssh-ed25519 '
        + Base64Encode(LBlobA));
      { [host]:port 条目 }
      LKH.AddLine('[host1.example.com]:2222 ssh-ed25519 ' + Base64Encode(LBlobB));
      { |1| 散列条目 }
      LSalt := PatternBytes($7E, 8);
      LHash := HMAC_SHA1(LSalt, SshBytesFromText('hashed.example.com'));
      LLine := '|1|' + Base64Encode(LSalt) + '|' + Base64Encode(LHash)
        + ' ssh-ed25519 ' + Base64Encode(LBlobA);
      LKH.AddLine(LLine);
      CheckEqual(Int64(3), Int64(LKH.Count));

      { 默认端口查询：命中明文条目；散列条目属于另一主机 }
      CheckEqual(Int64(1), Int64(Length(LKH.BlobsForHost('host1.example.com', 22))));
      CheckTrue(LKH.ContainsKey('host1.example.com', 22, LBlobA));
      CheckFalse(LKH.ContainsKey('host1.example.com', 22, LBlobB));

      { 散列条目按主机名命中；同时 *.example.com 通配也覆盖该主机 }
      CheckEqual(Int64(2), Int64(Length(LKH.BlobsForHost('hashed.example.com', 22))));
      CheckTrue(LKH.ContainsKey('hashed.example.com', 22, LBlobA));

      { 非默认端口命中 [host]:port 条目；无端口限定的条目对该主机全端口生效
        （OpenSSH known_hosts 语义）}
      CheckTrue(LKH.ContainsKey('host1.example.com', 2222, LBlobB));
      CheckTrue(LKH.ContainsKey('host1.example.com', 2222, LBlobA));

      { 未被任何模式覆盖的主机 }
      CheckEqual(Int64(0), Int64(Length(LKH.BlobsForHost('other.invalid', 22))));
    finally
      LKH.Free;
    end;
  end);

  LSuite.Test('knownhosts load from file keeps empty on missing', procedure
  var
    LKH: TSshKnownHosts;
    LBlob: TBytes;
    LPath: string;
    LContent: AnsiString;
  begin
    LKH := TSshKnownHosts.Create;
    try
      { 文件不存在：保持空集合 }
      LKH.LoadFromFile('/nonexistent/known_hosts_for_ssh_test');
      CheckEqual(Int64(0), Int64(LKH.Count));

      LPath := GetTempDir() + 'nextpas_ssh_known_hosts_test';
      LBlob := PatternBytes($CC, 40);
      LContent := '# test' + #10
        + 'tmp.example.com ssh-ed25519 ' + Base64Encode(LBlob) + #10;
      CheckTrue(FileWriteAllText(LPath, LContent));
      LKH.LoadFromFile(LPath);
      CheckEqual(Int64(1), Int64(LKH.Count));
      CheckTrue(LKH.ContainsKey('tmp.example.com', 22, LBlob));
      DeleteFile(LPath);
    finally
      LKH.Free;
    end;
  end);

  LSuite.Test('ecdsa blob parse and roundtrip', procedure
  var
    LPriv, LBlob: TBytes;
    LPoint: TECPoint;
    LErr: string;
    LInfo: TSshHostKeyInfo;
    LX, LY: TBytes;
  begin
    LPriv := HexToBytes('c9afa9d845ba75166b5c215767b1d6934e50c3db36e89b127b8a622b120f6721');
    CheckTrue(TryP256ScalarMultBase(LPriv, LPoint, LErr));
    CheckTrue(TryToFixedLength32(LPoint.X, LX, LErr));
    CheckTrue(TryToFixedLength32(LPoint.Y, LY, LErr));
    LBlob := SshEcdsaP256PubToBlob(LX, LY);
    CheckTrue(SshParseHostKey(LBlob, LInfo));
    CheckEqual('ecdsa-sha2-nistp256', LInfo.AlgName);
    CheckEqual(Ord(hkEcdsaP256), Ord(LInfo.Kind));
    CheckEqual(BytesToHex(LX), BytesToHex(LInfo.EcdsaP256X));
    CheckEqual(BytesToHex(LY), BytesToHex(LInfo.EcdsaP256Y));
    { 指纹稳定 }
    CheckTrue(Copy(SshFingerprintSHA256(LBlob), 1, 7) = 'SHA256:');
    { 错误点：截断 blob 必须失败（抛异常或返回 False）}
    begin
      LInfo := Default(TSshHostKeyInfo);
      try
        CheckFalse(SshParseHostKey(Copy(LBlob, 0, 20), LInfo), 'truncated ecdsa blob must not parse');
      except
        on E: ESSHError do
          CheckTrue(True, 'truncated raises');
      end;
    end;
    { 坏曲线名：nistp384 应被拒绝（抛 sekKeyFormat）}
    begin
      LInfo := Default(TSshHostKeyInfo);
      try
        CheckFalse(SshParseHostKey(HexToBytes('0000001365636473612d736861322d6e69737470323536000000086e6973747033383400000041041111111111111111111111111111111111111111111111111111111111111111222222222222222222222222222222222222222222222222222222222222222222'), LInfo), 'bad curve must not parse');
      except
        on E: ESSHError do
          CheckEqual(Ord(sekKeyFormat), Ord(E.Kind), 'bad curve must be sekKeyFormat');
      end;
    end;
  end);

  LSuite.Test('ecdsa signature verify positive and negative', procedure
  var
    LPriv, LBlob, LH, LDER, LSigRaw, LSigBlob: TBytes;
    LPoint: TECPoint;
    LErr: string;
    LInfo: TSshHostKeyInfo;
    LX, LY: TBytes;
  begin
    LPriv := HexToBytes('c9afa9d845ba75166b5c215767b1d6934e50c3db36e89b127b8a622b120f6721');
    CheckTrue(TryP256ScalarMultBase(LPriv, LPoint, LErr));
    CheckTrue(TryToFixedLength32(LPoint.X, LX, LErr));
    CheckTrue(TryToFixedLength32(LPoint.Y, LY, LErr));
    LBlob := SshEcdsaP256PubToBlob(LX, LY);
    CheckTrue(SshParseHostKey(LBlob, LInfo));
    LH := SHA256(HexToBytes('6e6578747061732065636473612074657374')); // 'nextpas ecdsa test'
    CheckTrue(TryECDSASignP256SHA256(LH, LPriv, LDER, LErr));
    LSigRaw := EcdsaSshSigRaw(LDER);
    LSigBlob := SigBlobOf('ecdsa-sha2-nistp256', LSigRaw);
    CheckTrue(SshVerifyHostSignature(LInfo, 'ecdsa-sha2-nistp256', LH, LSigBlob), 'valid ecdsa sig must verify');
    { 算法名不一致 → False }
    CheckFalse(SshVerifyHostSignature(LInfo, 'ssh-ed25519', LH, LSigBlob));
    { 篡改 H → False }
    CheckFalse(SshVerifyHostSignature(LInfo, '', BytesConcat(Copy(LH, 0, 31), HexToBytes('ff')), LSigBlob));
    { 篡改签名 → False }
    LSigRaw[10] := LSigRaw[10] xor $01;
    CheckFalse(SshVerifyHostSignature(LInfo, '', LH, SigBlobOf('ecdsa-sha2-nistp256', LSigRaw)));
  end);

  LSuite.Test('ecdsa known_hosts roundtrip with hash and plain', procedure
  var
    LKH: TSshKnownHosts;
    LPriv, LBlob: TBytes;
    LPoint: TECPoint;
    LX, LY: TBytes;
    LErr: string;
    LSalt, LHash: TBytes;
    LLine: string;
  begin
    LPriv := HexToBytes('c9afa9d845ba75166b5c215767b1d6934e50c3db36e89b127b8a622b120f6721');
    CheckTrue(TryP256ScalarMultBase(LPriv, LPoint, LErr));
    CheckTrue(TryToFixedLength32(LPoint.X, LX, LErr));
    CheckTrue(TryToFixedLength32(LPoint.Y, LY, LErr));
    LBlob := SshEcdsaP256PubToBlob(LX, LY);
    LKH := TSshKnownHosts.Create;
    try
      LKH.AddLine('ecdsa.example.com ecdsa-sha2-nistp256 ' + Base64Encode(LBlob));
      CheckTrue(LKH.ContainsKey('ecdsa.example.com', 22, LBlob));
      LSalt := PatternBytes($5A, 16);
      LHash := HMAC_SHA1(LSalt, SshBytesFromText('hashed-ecdsa.example.com'));
      LLine := '|1|' + Base64Encode(LSalt) + '|' + Base64Encode(LHash) + ' ecdsa-sha2-nistp256 ' + Base64Encode(LBlob);
      LKH.AddLine(LLine);
      CheckTrue(LKH.ContainsKey('hashed-ecdsa.example.com', 22, LBlob));
    finally
      LKH.Free;
    end;
  end);

  LRunner := TSuiteRunner.Create('nextpas.core.ssh.hostkey');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then Halt(1);
end.
