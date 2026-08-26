program test_ssh_keys;

{$I nextpas.core.settings.inc}

{ S3 gate：OpenSSH 私钥容器（openssh-key-v1 未加密 ed25519）。
 * 覆盖：容器手工构造 → 解析往返、PEM 盔甲变体、
 * 加密容器与不支持算法的 sekUnsupported 路径、
 * checkint/nkeys/marker 等结构错误路径。}

uses
  nextpas.core.system.sysutils,
  nextpas.core.ssh.base,
  nextpas.core.ssh.errors,
  nextpas.core.ssh.buffer,
  nextpas.core.ssh.keys,
  nextpas.core.crypto.ed25519,
  nextpas.core.encoding.base64,
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
    LContainer := CraftContainer('aes256-ctr', 'bcrypt',
      1, Ed25519PubBlob(LPub), MakePrivSection('ssh-ed25519', 1, LPub, LSeed));
    ExpectKindError(PemOf(LContainer), sekUnsupported, 'encrypted container');
  end);

  LSuite.Test('non-ed25519 key type raises sekUnsupported', procedure
  var
    LSeed, LPub, LContainer, LParsedPub: TBytes;
    LKey: TSshPrivateKey;
  begin
    SetLength(LSeed, 32);
    FillChar(LSeed[0], 32, $77);
    LPub := Ed25519PublicKeyFromPrivate(LSeed);
    LContainer := CraftContainer('none', 'none', 1,
      Ed25519PubBlob(LPub), MakePrivSection('ssh-rsa', 7, LPub, LSeed));
    ExpectKindError(PemOf(LContainer), sekUnsupported, 'rsa key type');
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

  LRunner := TSuiteRunner.Create('nextpas.core.ssh.keys');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then Halt(1);
end.
