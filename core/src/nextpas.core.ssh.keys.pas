unit nextpas.core.ssh.keys;

{** nextpas.core.ssh - 私钥容器解析。
 *
 * 支持：OpenSSH "openssh-key-v1" 容器中的 ssh-ed25519 与 ssh-rsa 密钥，
 * 未加密（cipher none / kdf none）与加密（cipher aes256-ctr / kdf bcrypt +
 * bcrypt_pbkdf 派生 48 字节 → AES-256-CTR 解密）两种形态。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.system.sysutils,
  nextpas.core.base,
  nextpas.core.text.strings,
  nextpas.core.ssh.base,
  nextpas.core.ssh.errors,
  nextpas.core.ssh.buffer;

type
  { 已解析的客户端私钥 }
  TSshPrivateKey = record
    Kind: TSshHostKeyAlg;
    Ed25519Seed: TBytes;   { hkEd25519：32 字节种子（Ed25519 签名输入）}
    RsaN: TBytes;          { hkRsa：模数（大端 magnitude，mpint 剥前导零）}
    RsaE: TBytes;          { hkRsa：公钥指数（通常 010001）}
    RsaD: TBytes;          { hkRsa：私钥指数（签名用）}
    RsaP: TBytes;          { hkRsa：素因子 p（CRT）}
    RsaQ: TBytes;          { hkRsa：素因子 q（CRT）}
    RsaIqmp: TBytes;       { hkRsa：q^{-1} mod p（CRT 系数）}
    RsaHasCrt: Boolean;    { hkRsa：是否具备完整 CRT 五元组（p/q/iqmp 均存在且有效）}
  end;

{** 解析 PEM 形式的 openssh-key-v1 容器内容。
 * 成功时返回 True 并给出私钥与其公钥 wire blob（用于 publickey 认证）。
 * 加密容器需提供口令（APassphrase）；未加密时口令被忽略。*}
function SshLoadPrivateKey(const AContent: string;
  out AKey: TSshPrivateKey; out APubBlob: TBytes;
  const APassphrase: string = ''): Boolean;

implementation

uses
  nextpas.core.encoding.base64,
  nextpas.core.crypto.bcrypt_pbkdf,
  nextpas.core.crypto.bigint,
  nextpas.core.ssh.cipher;

{ 按 '#' 换行切分（替代 SysUtils 字符串助手的多分隔符 Split）}
function SplitBase64Junk(const AValue: string): TStringArray;
var
  I: Integer;
  LChunk: string;

  procedure Flush;
  begin
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := LChunk;
    LChunk := '';
  end;

begin
  Result := nil;
  LChunk := '';
  for I := 1 to Length(AValue) do
    if (AValue[I] = '#') or (AValue[I] = #10) or (AValue[I] = #13) then
      Flush
    else
      LChunk := LChunk + AValue[I];
  Flush;
end;

const
  OPENSSH_KEY_MAGIC: array[0..14] of Byte = (
    Ord('o'), Ord('p'), Ord('e'), Ord('n'), Ord('s'), Ord('s'), Ord('h'),
    Ord('-'), Ord('k'), Ord('e'), Ord('y'), Ord('-'), Ord('v'), Ord('1'), 0);

function ExtractBase64Body(const AContent: string): string;
var
  I: Integer;
  LBeginMark, LEndMark: Integer;
  LLine: string;
  LLines: TStringArray;
const
  MARK_BEGIN = '-----BEGIN OPENSSH PRIVATE KEY-----';
  MARK_END = '-----END OPENSSH PRIVATE KEY-----';
begin
  Result := '';
  LBeginMark := Pos(MARK_BEGIN, AContent);
  LEndMark := Pos(MARK_END, AContent);
  if LBeginMark <= 0 then
    raise ESSHError.Create(sekKeyFormat,
      'ssh keys: not an openssh-key-v1 container (missing BEGIN marker)');
  if LEndMark <= 0 then
    raise ESSHError.Create(sekKeyFormat, 'ssh keys: missing END marker');
  LLine := Copy(AContent, LBeginMark + Length(MARK_BEGIN),
    LEndMark - LBeginMark - Length(MARK_BEGIN));
  LLines := SplitBase64Junk(LLine);
  for I := 0 to High(LLines) do
    Result := Result + Trim(LLines[I]);
end;

function StringToBytesPass(const AText: string): TBytes;
begin
  Result := nil;
  SetLength(Result, Length(AText));
  if Length(AText) > 0 then
    Move(PByte(PChar(AText))^, Result[0], SizeUInt(Length(AText)));
end;

function BytesEqualTrim(const A, B: TBytes): Boolean;
var
  I, LA, LB, SA, SB: Integer;
begin
  LA := Length(A); SA := 0;
  while (SA < LA) and (A[SA] = 0) do Inc(SA);
  LB := Length(B); SB := 0;
  while (SB < LB) and (B[SB] = 0) do Inc(SB);
  LA := LA - SA;
  LB := LB - SB;
  if LA <> LB then Exit(False);
  if LA = 0 then Exit(True);
  for I := 0 to LA - 1 do
    if A[SA + I] <> B[SB + I] then Exit(False);
  Result := True;
end;

function IsCrtValid(const AN, AP, AQ, AIqmp: TBytes): Boolean;
var
  LProd, LCheck: TBytes;
  LErr: string;
begin
  Result := False;
  if (Length(AN) = 0) or (Length(AP) = 0) or (Length(AQ) = 0) or (Length(AIqmp) = 0) then
    Exit;
  if (Length(AP) < 32) or (Length(AQ) < 32) or (Length(AIqmp) < 32) then
    Exit;
  if not TryBigIntMulFromUnsignedBytes(AP, AQ, LProd, LErr) then
    Exit;
  if not BytesEqualTrim(LProd, AN) then
    Exit;
  if not TryBigIntModMulFromUnsignedBytes(AQ, AIqmp, AP, LCheck, LErr) then
    Exit;
  if (Length(LCheck) <> 1) or (LCheck[0] <> 1) then
    Exit;
  Result := True;
end;

function SshLoadPrivateKey(const AContent: string;
  out AKey: TSshPrivateKey; out APubBlob: TBytes;
  const APassphrase: string = ''): Boolean;
var
  LBlob: TBytes;
  LR, LKdfR: TsshReader;
  LCipher, LKdf, LKeyType, LComment: string;
  LKdfOptions, LSalt, LPassBytes, LDerived, LKey, LIV, LPrivEnc: TBytes;
  LRounds: UInt32;
  LErr: string;
  LNKeys: UInt32;
  LPrivSection: TBytes;
  LCheck1, LCheck2: UInt32;
  LPubInPriv, LPrivRaw: TBytes;
  I: Integer;
begin
  Result := False;
  AKey := Default(TSshPrivateKey);
  APubBlob := nil;

  LBlob := Base64Decode(ExtractBase64Body(AContent));
  LR := TsshReader.Create(LBlob);
  try
    if SizeUInt(Length(LBlob)) < SizeUInt(Length(OPENSSH_KEY_MAGIC)) then
      raise ESSHError.Create(sekKeyFormat, 'ssh keys: container too short');
    for I := 0 to High(OPENSSH_KEY_MAGIC) do
      if LR.ReadByte <> OPENSSH_KEY_MAGIC[I] then
        raise ESSHError.Create(sekKeyFormat, 'ssh keys: bad magic');

    LCipher := LR.ReadStringText;
    LKdf := LR.ReadStringText;
    LKdfOptions := LR.ReadStringBytes;
    if (LCipher = 'none') and (LKdf = 'none') then
    begin
      if Length(LKdfOptions) <> 0 then
        raise ESSHError.Create(sekKeyFormat, 'ssh keys: kdfoptions must be empty for none');
    end
    else if (LCipher = 'aes256-ctr') and (LKdf = 'bcrypt') then
    begin
      { 保持外层解析，解密在读出 priv 段后进行 }
    end
    else
      raise ESSHError.Create(sekUnsupported,
        'ssh keys: unsupported cipher/kdf "' + LCipher + '/' + LKdf + '"');
    LNKeys := LR.ReadUInt32;
    if LNKeys <> 1 then
      raise ESSHError.Create(sekKeyFormat, 'ssh keys: expected exactly one key');
    APubBlob := LR.ReadStringBytes;
    LPrivEnc := LR.ReadStringBytes;
  finally
    LR.Free;
  end;

  if (LCipher = 'aes256-ctr') and (LKdf = 'bcrypt') then
  begin
    if Length(LKdfOptions) = 0 then
      raise ESSHError.Create(sekKeyFormat, 'ssh keys: missing bcrypt kdfoptions');
    LKdfR := TsshReader.Create(LKdfOptions);
    try
      LSalt := LKdfR.ReadStringBytes;
      LRounds := LKdfR.ReadUInt32;
    finally
      LKdfR.Free;
    end;
    if Length(LSalt) = 0 then
      raise ESSHError.Create(sekKeyFormat, 'ssh keys: bcrypt salt empty');
    if LRounds < 1 then
      raise ESSHError.Create(sekKeyFormat, 'ssh keys: bcrypt rounds must be >= 1');
    LPassBytes := StringToBytesPass(APassphrase);
    if Length(LPassBytes) = 0 then
      raise ESSHError.Create(sekKeyFormat, 'ssh keys: passphrase required for encrypted key');
    if not TryBcryptPbkdf(LPassBytes, LSalt, 48, LRounds, LDerived, LErr) then
      raise ESSHError.Create(sekKeyFormat, 'ssh keys: bcrypt_pbkdf failed: ' + LErr);
    SetLength(LKey, 32);
    SetLength(LIV, 16);
    Move(LDerived[0], LKey[0], 32);
    Move(LDerived[32], LIV[0], 16);
    { AES-256-CTR：CTR 初值为 IV，全零计数器跨块递增（SshAesCtrCrypt 封装）}
    LPrivSection := SshAesCtrCrypt(LKey, LIV, LPrivEnc);
    if (Length(LPrivSection) mod 16) <> 0 then
      raise ESSHError.Create(sekKeyFormat, 'ssh keys: decrypted priv section not block aligned');
  end
  else
    LPrivSection := LPrivEnc;

  LR := TsshReader.Create(LPrivSection);
  try
    LCheck1 := LR.ReadUInt32;
    LCheck2 := LR.ReadUInt32;
    if LCheck1 <> LCheck2 then
      raise ESSHError.Create(sekKeyFormat, 'ssh keys: checkint mismatch');
    LKeyType := LR.ReadStringText;
    if LKeyType = 'ssh-ed25519' then
    begin
      AKey.Kind := hkEd25519;
      LPubInPriv := LR.ReadStringBytes;
      LPrivRaw := LR.ReadStringBytes;
      if Length(LPrivRaw) < 32 then
        raise ESSHError.Create(sekKeyFormat, 'ssh keys: ed25519 private section too short');
      SetLength(AKey.Ed25519Seed, 32);
      Move(LPrivRaw[0], AKey.Ed25519Seed[0], 32);
      if Length(LPubInPriv) <> 32 then
        raise ESSHError.Create(sekKeyFormat, 'ssh keys: ed25519 embedded pubkey not 32 bytes');
    end
    else if LKeyType = 'ssh-rsa' then
    begin
      AKey.Kind := hkRsa;
      AKey.RsaN := LR.ReadMPInt;
      AKey.RsaE := LR.ReadMPInt;
      AKey.RsaD := LR.ReadMPInt;
      AKey.RsaIqmp := LR.ReadMPInt;
      AKey.RsaP := LR.ReadMPInt;
      AKey.RsaQ := LR.ReadMPInt;
      AKey.RsaHasCrt := IsCrtValid(AKey.RsaN, AKey.RsaP, AKey.RsaQ, AKey.RsaIqmp);
      if (Length(AKey.RsaE) = 0) or (Length(AKey.RsaD) = 0) or
         (Length(AKey.RsaN) < 32) then
        raise ESSHError.Create(sekKeyFormat, 'ssh keys: rsa key fields invalid');
    end
    else
      raise ESSHError.Create(sekUnsupported,
        'ssh keys: unsupported key type "' + LKeyType + '" in openssh container');
    LComment := LR.ReadStringText;
  finally
    LR.Free;
  end;
  Result := True;
end;

end.
