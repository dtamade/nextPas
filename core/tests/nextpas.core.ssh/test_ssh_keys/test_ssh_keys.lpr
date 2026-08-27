program test_ssh_keys;

{$I nextpas.core.settings.inc}

{ S3 gate：OpenSSH 私钥容器（openssh-key-v1 未加密 ed25519）。
 * 覆盖：容器手工构造 → 解析往返、PEM 盔甲变体、
 * 加密容器与不支持算法的 sekUnsupported 路径、
 * checkint/nkeys/marker 等结构错误路径。}

uses
  SysUtils,
  nextpas.core.system.sysutils,
  nextpas.core.ssh.base,
  nextpas.core.ssh.errors,
  nextpas.core.ssh.buffer,
  nextpas.core.ssh.keys,
  nextpas.core.ssh.rsa,
  nextpas.core.crypto.ed25519,
  nextpas.core.crypto.hash,
  nextpas.core.crypto.bcrypt_pbkdf,
  nextpas.core.ssh.cipher,
  nextpas.core.encoding.base64,
  ssh_rsa_kat,
  ssh_bcrypt_kat,
  nextpas.core.test;

function PatternBytes(APattern: Byte; ACount: Integer): TBytes;
begin
  Result := nil;
  SetLength(Result, ACount);
  if ACount > 0 then
    FillChar(Result[0], SizeUInt(ACount), APattern);
end;

function StringToBytes(const AText: string): TBytes;
begin
  Result := nil;
  SetLength(Result, Length(AText));
  if Length(AText) > 0 then
    Move(PByte(PChar(AText))^, Result[0], SizeUInt(Length(AText)));
end;

function BytesToHex(const AData: TBytes): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(AData) do
    Result := Result + LowerCase(IntToHex(AData[I], 2));
end;

function ConcatBytes(const A, B: TBytes): TBytes;
begin
  Result := nil;
  SetLength(Result, Length(A) + Length(B));
  if Length(A) > 0 then
    Move(A[0], Result[0], Length(A));
  if Length(B) > 0 then
    Move(B[0], Result[Length(A)], Length(B));
end;

{ ssh-ed25519 公钥 wire blob }
function Ed25519PubBlob(const APub: TBytes): TBytes;
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

{ 私段：checkint x2 || string(keytype) || string(pub) || string(seed||pub) || comment }
function MakePrivSection(const AKeyType: string; ACheck: UInt32;
  const APub, ASeed: TBytes): TBytes;
var
  LW: TsshWriter;
begin
  Result := nil;
  LW := TsshWriter.Create(256);
  try
    LW.PutUInt32(ACheck);
    LW.PutUInt32(ACheck);
    LW.PutStringText(AKeyType);
    LW.PutStringBytes(Copy(APub, 0, 32));
    LW.PutStringBytes(ConcatBytes(ASeed, Copy(APub, 0, 32)));
    LW.PutStringText('test comment');
    Result := LW.ToBytes;
  finally
    LW.Free;
  end;
end;

{ 容器：magic || cipher || kdf || kdfoptions || nkeys || pubkey || privsection }
function CraftContainer(const ACipherName, AKdfName: string;
  ANKeys: UInt32; const APubBlob, APrivSection: TBytes): TBytes;
var
  LW: TsshWriter;
begin
  Result := nil;
  LW := TsshWriter.Create(512);
  try
    LW.PutRaw(StringToBytes('openssh-key-v1'));
    LW.PutByte(0);
    LW.PutStringText(ACipherName);
    LW.PutStringText(AKdfName);
    LW.PutStringText('');
    LW.PutUInt32(ANKeys);
    LW.PutStringBytes(APubBlob);
    LW.PutStringBytes(APrivSection);
    Result := LW.ToBytes;
  finally
    LW.Free;
  end;
end;

function Base64Chunked(const AData: TBytes): string;
var
  LB64: string;
  I: Integer;
begin
  LB64 := Base64Encode(AData);
  Result := '';
  for I := 1 to Length(LB64) do
  begin
    Result := Result + LB64[I];
    if (I mod 70) = 0 then
      Result := Result + #10;
  end;
end;

function PemOf(const AContainer: TBytes): string;
begin
  Result := '-----BEGIN OPENSSH PRIVATE KEY-----' + #10
    + Base64Chunked(AContainer)
    + '-----END OPENSSH PRIVATE KEY-----' + #10;
end;

{ RSA 公钥 wire blob：string("ssh-rsa") || mpint e || mpint n }
function RsaPubBlob(const AE, AN: TBytes): TBytes;
var
  LW: TsshWriter;
begin
  Result := nil;
  LW := TsshWriter.Create(64);
  try
    LW.PutStringText('ssh-rsa');
    LW.PutMPInt(AE);
    LW.PutMPInt(AN);
    Result := LW.ToBytes;
  finally
    LW.Free;
  end;
end;

{ RSA 私段：checkint x2 || string(type) || mpint n,e,d,iqmp,p,q || comment。
  iqmp/p/q 用占位字节（解析器按序读出但不校验，签名只需 N/E/D）。}
function MakeRsaPrivSection(ACheck: UInt32; const AN, AE, AD: TBytes): TBytes;
var
  LW: TsshWriter;
begin
  Result := nil;
  LW := TsshWriter.Create(512);
  try
    LW.PutUInt32(ACheck);
    LW.PutUInt32(ACheck);
    LW.PutStringText('ssh-rsa');
    LW.PutMPInt(AN);
    LW.PutMPInt(AE);
    LW.PutMPInt(AD);
    LW.PutMPInt(PatternBytes($AA, 128));
    LW.PutMPInt(PatternBytes($BB, 128));
    LW.PutMPInt(PatternBytes($CC, 128));
    LW.PutStringText('s9-test');
    Result := LW.ToBytes;
  finally
    LW.Free;
  end;
end;

{ RSA 私段（真实 CRT 五元组，验证 HasCrt 准确性）}
function MakeRsaPrivSectionCrt(ACheck: UInt32; const AN, AE, AD, AP, AQ, AIqmp: TBytes): TBytes;
var
  LW: TsshWriter;
begin
  Result := nil;
  LW := TsshWriter.Create(768);
  try
    LW.PutUInt32(ACheck);
    LW.PutUInt32(ACheck);
    LW.PutStringText('ssh-rsa');
    LW.PutMPInt(AN);
    LW.PutMPInt(AE);
    LW.PutMPInt(AD);
    LW.PutMPInt(AIqmp);
    LW.PutMPInt(AP);
    LW.PutMPInt(AQ);
    LW.PutStringText('crt-valid');
    Result := LW.ToBytes;
  finally
    LW.Free;
  end;
end;

procedure ExpectKindError(const AContent: string; AExpected: TSshErrorKind;
  const AWhat: string);
var
  LKey: TSshPrivateKey;
  LPub: TBytes;
  LRaised: Boolean;
begin
  LRaised := False;
  try
    SshLoadPrivateKey(AContent, LKey, LPub);
  except
    on E: ESSHError do
    begin
      LRaised := True;
      CheckEqual(Ord(AExpected), Ord(E.Kind), AWhat);
    end;
  end;
  CheckTrue(LRaised, 'expected error for ' + AWhat);
end;

var
  LRunner: TSuiteRunner;
  LSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('ssh keys');

  LSuite.Test('unencrypted ed25519 container parses', procedure
  var
    LSeed, LPub, LContainer, LParsedPub: TBytes;
    LKey: TSshPrivateKey;
    LOk: Boolean;
  begin
    SetLength(LSeed, 32);
    FillChar(LSeed[0], 32, $3D);
    LPub := Ed25519PublicKeyFromPrivate(LSeed);

    LContainer := CraftContainer('none', 'none', 1,
      Ed25519PubBlob(LPub), MakePrivSection('ssh-ed25519', $A5A5A5A5, LPub, LSeed));

    LOk := SshLoadPrivateKey(PemOf(LContainer), LKey, LParsedPub);
    CheckTrue(LOk);
    CheckEqual(Ord(hkEd25519), Ord(LKey.Kind));
    CheckEqual(Int64(32), Int64(Length(LKey.Ed25519Seed)));
    CheckTrue(CompareMem(@LSeed[0], @LKey.Ed25519Seed[0], 32), 'seed roundtrip');
    CheckEqual(BytesToHex(Ed25519PubBlob(LPub)), BytesToHex(LParsedPub),
      'pub blob passthrough');
  end);

  LSuite.Test('armor variants: single line and comments', procedure
  var
    LSeed, LPub, LContainer, LParsedPub: TBytes;
    LKey: TSshPrivateKey;
    LOk: Boolean;
  begin
    SetLength(LSeed, 32);
    FillChar(LSeed[0], 32, $51);
    LPub := Ed25519PublicKeyFromPrivate(LSeed);
    LContainer := CraftContainer('none', 'none', 1,
      Ed25519PubBlob(LPub), MakePrivSection('ssh-ed25519', $11223344, LPub, LSeed));

    { 单行 base64 }
    LOk := SshLoadPrivateKey('-----BEGIN OPENSSH PRIVATE KEY-----'
      + Base64Encode(LContainer)
      + '-----END OPENSSH PRIVATE KEY-----', LKey, LParsedPub);
    CheckTrue(LOk, 'single-line armor');

    { 带注释行 }
    LOk := SshLoadPrivateKey('# private key' + #10 + PemOf(LContainer) + '# end',
      LKey, LParsedPub);
    CheckTrue(LOk, 'comment lines tolerated');
  end);

  LSuite.Test('encrypted container raises sekUnsupported', procedure
  var
    LSeed, LPub, LContainer, LParsedPub: TBytes;
    LKey: TSshPrivateKey;
  begin
    SetLength(LSeed, 32);
    FillChar(LSeed[0], 32, $6E);
    LPub := Ed25519PublicKeyFromPrivate(LSeed);
    { aes128-ctr 不是 openssh-key-v1 加密容器支持的 cipher，仅 aes256-ctr 受支持 }
    LContainer := CraftContainer('aes128-ctr', 'bcrypt',
      1, Ed25519PubBlob(LPub), MakePrivSection('ssh-ed25519', 1, LPub, LSeed));
    ExpectKindError(PemOf(LContainer), sekUnsupported, 'encrypted container');
  end);

  LSuite.Test('unsupported key type raises sekUnsupported', procedure
  var
    LSeed, LPub, LContainer, LParsedPub: TBytes;
    LKey: TSshPrivateKey;
  begin
    SetLength(LSeed, 32);
    FillChar(LSeed[0], 32, $77);
    LPub := Ed25519PublicKeyFromPrivate(LSeed);
    { ssh-dss：现代集合外，明确不支持（ssh-rsa 已支持，见下）}
    LContainer := CraftContainer('none', 'none', 1,
      Ed25519PubBlob(LPub), MakePrivSection('ssh-dss', 7, LPub, LSeed));
    ExpectKindError(PemOf(LContainer), sekUnsupported, 'dss key type');
  end);

  LSuite.Test('rsa container parses', procedure
  var
    LN, LD, LPubBlob: TBytes;
    LKey: TSshPrivateKey;
  begin
    LN := KatN;
    LD := KatD;
    CheckTrue(SshLoadPrivateKey(PemOf(CraftContainer('none', 'none', 1,
      RsaPubBlob(HexToBytesKat(KAT_E_HEX), LN),
      MakeRsaPrivSection(7, LN, HexToBytesKat(KAT_E_HEX), LD))),
      LKey, LPubBlob));
    CheckEqual(Ord(hkRsa), Ord(LKey.Kind));
    CheckTrue(Length(LKey.RsaN) = 256, 'modulus must be 256 bytes');
    CheckTrue(BytesToHex(LKey.RsaN) = BytesToHex(LN), 'modulus must roundtrip');
    CheckTrue(BytesToHex(LKey.RsaE) = KAT_E_HEX, 'exponent must be 010001');
    CheckTrue(BytesToHex(LKey.RsaD) = BytesToHex(LD), 'private exponent must roundtrip');
    CheckTrue(Length(LPubBlob) > 4, 'pub blob must be present');
  end);

  { 签名路径黄金向量：与 openssl dgst -sign 输出逐字节一致
    （PKCS#1 v1.5 确定性编码，允许精确断言）。}
  LSuite.Test('rsa sign matches openssl goldens', procedure
  var
    LN, LD, LSig: TBytes;
  begin
    LN := KatN;
    LD := KatD;

    CheckTrue(RsaSignPkcs1v15(LN, LD, SHA256(KatMsg),
      DIGEST_INFO_SHA256, LSig), 'sha256 sign must succeed');
    CheckTrue(BytesToHex(LSig) = BytesToHex(KatSigSha256),
      'sha256 signature must equal openssl output');

    CheckTrue(RsaSignPkcs1v15(LN, LD, SHA512(KatMsg),
      DIGEST_INFO_SHA512, LSig), 'sha512 sign must succeed');
    CheckTrue(BytesToHex(LSig) = BytesToHex(KatSigSha512),
      'sha512 signature must equal openssl output');

    { 摘要错配 DigestInfo → 验签必须拒绝 }
    CheckFalse(RsaVerifyPkcs1v15(HexToBytesKat(KAT_E_HEX), LN,
      SHA512(KatMsg), DIGEST_INFO_SHA256, KatSigSha512));
  end);

  LSuite.Test('rsa crt signature equals naive for both digests', procedure
  var
    LN, LD, LP, LQ, LIq, LSigNaive, LSigCrt: TBytes;
  begin
    LN := CrtKatN; LD := CrtKatD; LP := CrtKatP; LQ := CrtKatQ; LIq := CrtKatIqmp;
    CheckTrue(RsaSignPkcs1v15(LN, LD, SHA256(KatMsg), DIGEST_INFO_SHA256, LSigNaive), 'naive sha256');
    CheckTrue(RsaSignPkcs1v15Crt(LN, LD, LP, LQ, LIq, SHA256(KatMsg), DIGEST_INFO_SHA256, LSigCrt), 'crt sha256');
    CheckEqual(BytesToHex(LSigNaive), BytesToHex(LSigCrt), 'crt==naive sha256');
    CheckTrue(RsaVerifyPkcs1v15(HexToBytesKat(KAT_E_HEX), LN, SHA256(KatMsg), DIGEST_INFO_SHA256, LSigCrt), 'verify crt sha256');

    CheckTrue(RsaSignPkcs1v15(LN, LD, SHA512(KatMsg), DIGEST_INFO_SHA512, LSigNaive), 'naive sha512');
    CheckTrue(RsaSignPkcs1v15Crt(LN, LD, LP, LQ, LIq, SHA512(KatMsg), DIGEST_INFO_SHA512, LSigCrt), 'crt sha512');
    CheckEqual(BytesToHex(LSigNaive), BytesToHex(LSigCrt), 'crt==naive sha512');
    CheckTrue(RsaVerifyPkcs1v15(HexToBytesKat(KAT_E_HEX), LN, SHA512(KatMsg), DIGEST_INFO_SHA512, LSigCrt), 'verify crt sha512');
  end);

  LSuite.Test('rsa crt container parsing validates HasCrt', procedure
  var
    LN, LD, LP, LQ, LIq, LPubBlob: TBytes;
    LKey: TSshPrivateKey;
    LOk: Boolean;
  begin
    LN := CrtKatN; LD := CrtKatD; LP := CrtKatP; LQ := CrtKatQ; LIq := CrtKatIqmp;
    LPubBlob := RsaPubBlob(HexToBytesKat(KAT_E_HEX), LN);
    LOk := SshLoadPrivateKey(PemOf(CraftContainer('none', 'none', 1, LPubBlob,
      MakeRsaPrivSectionCrt(7, LN, HexToBytesKat(KAT_E_HEX), LD, LP, LQ, LIq))), LKey, LPubBlob);
    CheckTrue(LOk, 'valid crt container must parse');
    CheckTrue(LKey.RsaHasCrt, 'HasCrt must be true for valid p*q==n and q*iqmp%p==1');
    CheckEqual(BytesToHex(LP), BytesToHex(LKey.RsaP), 'p roundtrip');
    CheckEqual(BytesToHex(LQ), BytesToHex(LKey.RsaQ), 'q roundtrip');
    CheckEqual(BytesToHex(LIq), BytesToHex(LKey.RsaIqmp), 'iqmp roundtrip');
    { 哑数据容器必须落在 HasCrt=false，触发 naive 回退 }
    LOk := SshLoadPrivateKey(PemOf(CraftContainer('none', 'none', 1,
      RsaPubBlob(HexToBytesKat(KAT_E_HEX), LN),
      MakeRsaPrivSection(7, LN, HexToBytesKat(KAT_E_HEX), LD))), LKey, LPubBlob);
    CheckTrue(LOk);
    CheckFalse(LKey.RsaHasCrt, 'dummy crt must be invalid');
  end);

  LSuite.Test('RsaSignPkcs1v15Crt rejects invalid CRT params', procedure
  var
    LN, LD, LSigDummy, LSigNaive: TBytes;
  begin
    LN := CrtKatN; LD := CrtKatD;
    { 哑 p/q 仍能产出签名但结果与 naive 不同且验签失败；
      有 IsCrtValid 闸门的容器不会走到 CRT 路径（HasCrt=false 回退 naive）。
      仅 nil/空输入应直接返回 False。}
    CheckTrue(RsaSignPkcs1v15Crt(LN, LD, PatternBytes($AA, 128), PatternBytes($BB, 128),
      PatternBytes($CC, 128), SHA256(KatMsg), DIGEST_INFO_SHA256, LSigDummy), 'dummy p/q still produces bytes');
    CheckTrue(RsaSignPkcs1v15(LN, LD, SHA256(KatMsg), DIGEST_INFO_SHA256, LSigNaive));
    CheckFalse(BytesToHex(LSigDummy) = BytesToHex(LSigNaive), 'dummy crt must not match naive');
    CheckFalse(RsaVerifyPkcs1v15(HexToBytesKat(KAT_E_HEX), LN, SHA256(KatMsg), DIGEST_INFO_SHA256, LSigDummy), 'dummy crt sig must not verify');
    CheckFalse(RsaSignPkcs1v15Crt(nil, LD, CrtKatP, CrtKatQ, CrtKatIqmp,
      SHA256(KatMsg), DIGEST_INFO_SHA256, LSigDummy), 'nil N must fail');
    CheckFalse(RsaSignPkcs1v15Crt(LN, nil, CrtKatP, CrtKatQ, CrtKatIqmp,
      SHA256(KatMsg), DIGEST_INFO_SHA256, LSigDummy), 'nil D must fail');
  end);

  LSuite.Test('rsa crt bench Naive vs CRT (prints throughput)', procedure
  var
    LN, LD, LP, LQ, LIq, LSig: TBytes;
    I, LIter: Integer;
    T0, T1, TNaive, TCrt: QWord;
  begin
    LN := CrtKatN; LD := CrtKatD; LP := CrtKatP; LQ := CrtKatQ; LIq := CrtKatIqmp;
    LIter := 32;
    T0 := SysUtils.GetTickCount64;
    for I := 1 to LIter do
      CheckTrue(RsaSignPkcs1v15(LN, LD, SHA512(KatMsg), DIGEST_INFO_SHA512, LSig));
    T1 := SysUtils.GetTickCount64;
    TNaive := T1 - T0;
    if TNaive = 0 then TNaive := 1;
    T0 := SysUtils.GetTickCount64;
    for I := 1 to LIter do
      CheckTrue(RsaSignPkcs1v15Crt(LN, LD, LP, LQ, LIq, SHA512(KatMsg), DIGEST_INFO_SHA512, LSig));
    T1 := SysUtils.GetTickCount64;
    TCrt := T1 - T0;
    if TCrt = 0 then TCrt := 1;
    WriteLn(Format('  [bench] rsa-sha512 x%d naive=%d ms crt=%d ms speedup=%.2fx',
      [LIter, TNaive, TCrt, TNaive / TCrt]));
    { CRT 必须与 naive 等价已在前序用例保证；此处只断言 CRT 不显著更慢（>2x 回退即视为回归）}
    CheckTrue(TCrt * 2 <= TNaive * 3 + 20, 'crt should not be much slower than naive');
  end);

  LSuite.Test('encrypted rsa with CRT decrypts and HasCrt true', procedure
  var
    LN, LD, LP, LQ, LIq, LPubBlob, LPrivRaw, LContainer, LPubOut: TBytes;
    LKey: TSshPrivateKey;
    LPw, LSalt: string;
    LRounds: Cardinal;
    LPadded, LDerived, LAesKey, LAiv, LEnc, LKdfOpt: TBytes;
    LW2, LW: TsshWriter;
    LErr: string;
    LPad, I2: Integer;
    LSigNaive, LSigCrt: TBytes;
  begin
    LN := CrtKatN; LD := CrtKatD; LP := CrtKatP; LQ := CrtKatQ; LIq := CrtKatIqmp;
    LPubBlob := RsaPubBlob(HexToBytesKat(KAT_E_HEX), LN);
    LPrivRaw := MakeRsaPrivSectionCrt(99, LN, HexToBytesKat(KAT_E_HEX), LD, LP, LQ, LIq);
    LPadded := Copy(LPrivRaw, 0, Length(LPrivRaw));
    LPad := (16 - (Length(LPadded) mod 16)) mod 16;
    for I2 := 1 to LPad do
    begin SetLength(LPadded, Length(LPadded)+1); LPadded[High(LPadded)] := Byte(I2); end;
    LPw := 'crt-enc-pass';
    LSalt := 'crt-salt-1234567';
    LRounds := 16;
    CheckTrue(TryBcryptPbkdf(StringToBytes(LPw), StringToBytes(LSalt), 48, LRounds, LDerived, LErr));
    SetLength(LAesKey, 32); Move(LDerived[0], LAesKey[0], 32);
    SetLength(LAiv, 16); Move(LDerived[32], LAiv[0], 16);
    LEnc := SshAesCtrCrypt(LAesKey, LAiv, LPadded);
    LW2 := TsshWriter.Create(64);
    try LW2.PutStringBytes(StringToBytes(LSalt)); LW2.PutUInt32(LRounds); LKdfOpt := LW2.ToBytes; finally LW2.Free; end;
    LW := TsshWriter.Create(768);
    try
      LW.PutRaw(StringToBytes('openssh-key-v1')); LW.PutByte(0);
      LW.PutStringText('aes256-ctr'); LW.PutStringText('bcrypt'); LW.PutStringBytes(LKdfOpt);
      LW.PutUInt32(1); LW.PutStringBytes(LPubBlob); LW.PutStringBytes(LEnc);
      LContainer := LW.ToBytes;
    finally LW.Free; end;
    CheckTrue(SshLoadPrivateKey(PemOf(LContainer), LKey, LPubOut, LPw));
    CheckTrue(LKey.RsaHasCrt, 'encrypted crt must retain HasCrt');
    CheckTrue(RsaSignPkcs1v15Crt(LKey.RsaN, LKey.RsaD, LKey.RsaP, LKey.RsaQ, LKey.RsaIqmp,
      SHA512(KatMsg), DIGEST_INFO_SHA512, LSigCrt));
    CheckTrue(RsaSignPkcs1v15(LN, LD, SHA512(KatMsg), DIGEST_INFO_SHA512, LSigNaive));
    CheckEqual(BytesToHex(LSigNaive), BytesToHex(LSigCrt), 'encrypted crt sig must match naive');
  end);

  LSuite.Test('structure errors raise sekKeyFormat', procedure
  var
    LSeed, LPub, LContainer, LParsedPub: TBytes;
    LKey: TSshPrivateKey;
    LRaised: Boolean;
  begin
    SetLength(LSeed, 32);
    FillChar(LSeed[0], 32, $99);
    LPub := Ed25519PublicKeyFromPrivate(LSeed);

    { nkeys != 1 }
    LContainer := CraftContainer('none', 'none', 2,
      Ed25519PubBlob(LPub), MakePrivSection('ssh-ed25519', 1, LPub, LSeed));
    ExpectKindError(PemOf(LContainer), sekKeyFormat, 'nkeys=2');

    { 缺 BEGIN 标记 }
    LContainer := CraftContainer('none', 'none', 1,
      Ed25519PubBlob(LPub), MakePrivSection('ssh-ed25519', 1, LPub, LSeed));
    LRaised := False;
    try
      SshLoadPrivateKey(Base64Encode(LContainer), LKey, LParsedPub);
    except
      on E: ESSHError do
        LRaised := True;
    end;
    CheckTrue(LRaised, 'missing markers must raise');
  end);

  LSuite.Test('bcrypt_pbkdf five vectors match python-bcrypt', procedure
  var
    I: Integer;
    LPw, LSalt, LKey, LWant: TBytes;
    LErr: string;
  begin
    for I := 0 to High(BCRYPT_VECTORS) do
    begin
      LPw := StringToBytes(BCRYPT_VECTORS[I].Pass);
      LSalt := StringToBytes(BCRYPT_VECTORS[I].Salt);
      CheckTrue(TryBcryptPbkdf(LPw, LSalt, BCRYPT_VECTORS[I].KeyLen,
        BCRYPT_VECTORS[I].Rounds, LKey, LErr),
        'pbkdf should succeed vector ' + IntToStr(I));
      LWant := HexToBytes(BCRYPT_VECTORS[I].WantHex);
      CheckEqual(BytesToHex(LWant), BytesToHex(LKey),
        'vector ' + IntToStr(I) + ' mismatch');
    end;
  end);

  LSuite.Test('encrypted ed25519 container decrypts with correct passphrase', procedure
  var
    LSeed, LPub, LPrivRaw, LContainer, LPubOut: TBytes;
    LKey: TSshPrivateKey;
    LOk: Boolean;
    LSaltHex: string;
    LPw: string;
    LRounds: Cardinal;
    LPad, I: Integer;
    LPadded, LDerived, LAesKey, LAiv, LEnc, LKdfOpt: TBytes;
    LW2, LW: TsshWriter;
    LErr: string;
  begin
    SetLength(LSeed, 32);
    FillChar(LSeed[0], 32, $42);
    LPub := Ed25519PublicKeyFromPrivate(LSeed);
    LPrivRaw := MakePrivSection('ssh-ed25519', $A5A5A5A5, LPub, LSeed);
    { pad to 16 }
    LPadded := Copy(LPrivRaw, 0, Length(LPrivRaw));
    LPad := (16 - (Length(LPadded) mod 16)) mod 16;
    for I := 1 to LPad do
    begin
      SetLength(LPadded, Length(LPadded) + 1);
      LPadded[High(LPadded)] := Byte(I);
    end;
    LPw := 's3cret!';
    LSaltHex := 'salty__12345678';
    LRounds := 16;
    CheckTrue(TryBcryptPbkdf(StringToBytes(LPw), StringToBytes(LSaltHex), 48, LRounds, LDerived, LErr));
    SetLength(LAesKey, 32);
    SetLength(LAiv, 16);
    Move(LDerived[0], LAesKey[0], 32);
    Move(LDerived[32], LAiv[0], 16);
    LEnc := SshAesCtrCrypt(LAesKey, LAiv, LPadded);
    LW2 := TsshWriter.Create(64);
    try
      LW2.PutStringBytes(StringToBytes(LSaltHex));
      LW2.PutUInt32(LRounds);
      LKdfOpt := LW2.ToBytes;
    finally
      LW2.Free;
    end;
    LContainer := CraftContainer('aes256-ctr', 'bcrypt', 1, Ed25519PubBlob(LPub), LEnc);
    { patch kdfoptions: CraftContainer writes empty string, replace with real }
    { We built CraftContainer with empty, need to rebuild with correct kdfoptions }
    LW := TsshWriter.Create(512);
    try
      LW.PutRaw(StringToBytes('openssh-key-v1'));
      LW.PutByte(0);
      LW.PutStringText('aes256-ctr');
      LW.PutStringText('bcrypt');
      LW.PutStringBytes(LKdfOpt);
      LW.PutUInt32(1);
      LW.PutStringBytes(Ed25519PubBlob(LPub));
      LW.PutStringBytes(LEnc);
      LContainer := LW.ToBytes;
    finally
      LW.Free;
    end;
    LOk := SshLoadPrivateKey(PemOf(LContainer), LKey, LPubOut, LPw);
    CheckTrue(LOk);
    CheckEqual(Ord(hkEd25519), Ord(LKey.Kind));
    CheckTrue(CompareMem(@LSeed[0], @LKey.Ed25519Seed[0], 32), 'seed decrypt roundtrip');
    { wrong passphrase must fail checkint }
    ExpectKindError(PemOf(LContainer), sekKeyFormat, 'wrong passphrase should fail');
  end);

  LSuite.Test('encrypted ed25519 container wrong passphrase raises checkint', procedure
  var
    LSeed, LPub, LPrivRaw, LContainer, LPubOut: TBytes;
    LKey: TSshPrivateKey;
    LPw: string;
    LSalt: string;
    LRounds: Cardinal;
    LPadded, LDerived, LAesKey, LAiv, LEnc, LKdfOpt: TBytes;
    LW2, LW: TsshWriter;
    LErr: string;
    LPad, I: Integer;
    LRaised: Boolean;
  begin
    SetLength(LSeed, 32);
    FillChar(LSeed[0], 32, $99);
    LPub := Ed25519PublicKeyFromPrivate(LSeed);
    LPrivRaw := MakePrivSection('ssh-ed25519', $12345678, LPub, LSeed);
    LPadded := Copy(LPrivRaw, 0, Length(LPrivRaw));
    LPad := (16 - (Length(LPadded) mod 16)) mod 16;
    for I := 1 to LPad do
    begin
      SetLength(LPadded, Length(LPadded) + 1);
      LPadded[High(LPadded)] := Byte(I);
    end;
    LPw := 'correct horse';
    LSalt := 'testsalt12345678';
    LRounds := 16;
    CheckTrue(TryBcryptPbkdf(StringToBytes(LPw), StringToBytes(LSalt), 48, LRounds, LDerived, LErr));
    SetLength(LAesKey, 32); Move(LDerived[0], LAesKey[0], 32);
    SetLength(LAiv, 16); Move(LDerived[32], LAiv[0], 16);
    LEnc := SshAesCtrCrypt(LAesKey, LAiv, LPadded);
    LW2 := TsshWriter.Create(64);
    try LW2.PutStringBytes(StringToBytes(LSalt)); LW2.PutUInt32(LRounds); LKdfOpt := LW2.ToBytes; finally LW2.Free; end;
    LW := TsshWriter.Create(512);
    try
      LW.PutRaw(StringToBytes('openssh-key-v1')); LW.PutByte(0);
      LW.PutStringText('aes256-ctr'); LW.PutStringText('bcrypt'); LW.PutStringBytes(LKdfOpt);
      LW.PutUInt32(1); LW.PutStringBytes(Ed25519PubBlob(LPub)); LW.PutStringBytes(LEnc);
      LContainer := LW.ToBytes;
    finally LW.Free; end;
    LRaised := False;
    try
      SshLoadPrivateKey(PemOf(LContainer), LKey, LPubOut, 'wrong passphrase');
    except
      on E: ESSHError do LRaised := True;
    end;
    CheckTrue(LRaised, 'wrong passphrase must raise');
  end);

  LSuite.Test('encrypted rsa container decrypts', procedure
  var
    LN, LD, LPubBlob, LPrivRaw, LContainer, LPubOut: TBytes;
    LKey: TSshPrivateKey;
    LPw, LSalt: string;
    LRounds: Cardinal;
    LPadded, LDerived, LAesKey, LAiv, LEnc, LKdfOpt: TBytes;
    LW2, LW: TsshWriter;
    LErr: string;
    LPad, I: Integer;
  begin
    LN := KatN; LD := KatD;
    LPubBlob := RsaPubBlob(HexToBytesKat(KAT_E_HEX), LN);
    LPrivRaw := MakeRsaPrivSection(7, LN, HexToBytesKat(KAT_E_HEX), LD);
    LPadded := Copy(LPrivRaw, 0, Length(LPrivRaw));
    LPad := (16 - (Length(LPadded) mod 16)) mod 16;
    for I := 1 to LPad do
    begin SetLength(LPadded, Length(LPadded)+1); LPadded[High(LPadded)] := Byte(I); end;
    LPw := 'rsa-pass-123';
    LSalt := 'rsasalttest1234';
    LRounds := 16;
    CheckTrue(TryBcryptPbkdf(StringToBytes(LPw), StringToBytes(LSalt), 48, LRounds, LDerived, LErr));
    SetLength(LAesKey, 32); Move(LDerived[0], LAesKey[0], 32);
    SetLength(LAiv, 16); Move(LDerived[32], LAiv[0], 16);
    LEnc := SshAesCtrCrypt(LAesKey, LAiv, LPadded);
    LW2 := TsshWriter.Create(64);
    try LW2.PutStringBytes(StringToBytes(LSalt)); LW2.PutUInt32(LRounds); LKdfOpt := LW2.ToBytes; finally LW2.Free; end;
    LW := TsshWriter.Create(512);
    try
      LW.PutRaw(StringToBytes('openssh-key-v1')); LW.PutByte(0);
      LW.PutStringText('aes256-ctr'); LW.PutStringText('bcrypt'); LW.PutStringBytes(LKdfOpt);
      LW.PutUInt32(1); LW.PutStringBytes(LPubBlob); LW.PutStringBytes(LEnc);
      LContainer := LW.ToBytes;
    finally LW.Free; end;
    CheckTrue(SshLoadPrivateKey(PemOf(LContainer), LKey, LPubOut, LPw));
    CheckEqual(Ord(hkRsa), Ord(LKey.Kind));
    CheckTrue(BytesToHex(LKey.RsaN) = BytesToHex(LN), 'rsa N roundtrip encrypted');
    CheckTrue(BytesToHex(LKey.RsaD) = BytesToHex(LD), 'rsa D roundtrip encrypted');
  end);

  LSuite.Test('aes-ctr crypt roundtrip', procedure
  var
    LKey, LIV, LPlain, LCipher, LDec: TBytes;
    I: Integer;
  begin
    SetLength(LKey, 32); for I:=0 to 31 do LKey[I]:=Byte(I);
    SetLength(LIV, 16); for I:=0 to 15 do LIV[I]:=Byte(I*2);
    SetLength(LPlain, 48); for I:=0 to 47 do LPlain[I]:=Byte(I*3+7);
    LCipher := SshAesCtrCrypt(LKey, LIV, LPlain);
    LDec := SshAesCtrCrypt(LKey, LIV, LCipher);
    CheckEqual(BytesToHex(LPlain), BytesToHex(LDec), 'ctr roundtrip');
  end);

  LRunner := TSuiteRunner.Create('nextpas.core.ssh.keys');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then Halt(1);
end.
