unit nextpas.core.ssh.hostkey;

{** nextpas.core.ssh - 主机公钥解析、验签、指纹与 known_hosts。
 *
 * 支持 ssh-ed25519 与 ssh-rsa（rsa-sha2-256/512 签名，PKCS#1 v1.5）。
 * known_hosts 支持：明文模式（含 * ? 通配、逗号列表）、[host]:port 形式、
 * |1|salt|hash 散列条目（HMAC-SHA1）；@cert-authority/@revoked 行跳过。
 *
 * RSA 验签路径：bigint 模幂（公钥指数）→ EMSA-PKCS1-v1_5 重造 → 常数时间比较。 *}

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  Math,
  StrUtils,
  nextpas.core.base,
  nextpas.core.hash.base,
  nextpas.core.ssh.base,
  nextpas.core.ssh.errors,
  nextpas.core.ssh.buffer;

type
  { 已解析的主机公钥 }
  TSshHostKeyInfo = record
    AlgName: string;      { blob 内声明的算法名 }
    Kind: TSshHostKeyAlg;
    Ed25519Pub: TBytes;   { hkEd25519：32 字节公钥 }
    RsaE: TBytes;         { hkRsa：大端 magnitude }
    RsaN: TBytes;
  end;

{** 解析 RFC 4253 §6.6 公钥 wire blob。不认识的算法返回 False。*}
function SshParseHostKey(const ABlob: TBytes; out AInfo: TSshHostKeyInfo): Boolean;

{** 验证交换散列 H 的服务方签名。
 * AAlgName 为协商的签名算法（ssh-ed25519 / rsa-sha2-512 / rsa-sha2-256），
 * 非空时必须与签名 blob 内声明一致；ASigBlob 为 string(alg)+string(sig) 结构。*}
function SshVerifyHostSignature(const AInfo: TSshHostKeyInfo; const AAlgName: string;
  const AH: TBytes; const ASigBlob: TBytes): Boolean;

{** "SHA256:<base64 无填充>" 指纹（OpenSSH 格式）。*}
function SshFingerprintSHA256(const ABlob: TBytes): string;

type
  { known_hosts 条目集合 }
  TSshKnownHosts = class
  private
    FPatterns: TStringArray;   { 每条目的 pattern 字段原样保留 }
    FBlobs: TBlobArray;
    FCount: Integer;
    procedure AddEntry(const APatterns: string; const ABlob: TBytes);
  public
    constructor Create;

    { 文件不存在时保持空集合（策略由调用方决定）}
    procedure LoadFromFile(const APath: string);
    procedure AddLine(const ALine: string);
    function Count: Integer;

    { 返回匹配该主机的全部密钥 blob（可能为空数组）}
    function BlobsForHost(const AHostName: string; APort: Word): TBlobArray;

    { 便捷判定：该主机的记录里是否已包含此 blob }
    function ContainsKey(const AHostName: string; APort: Word;
      const ABlob: TBytes): Boolean;
  end;

{ 通配符匹配：'*' 任意串、'?' 单字符；大小写敏感 }
function SshWildMatch(const APattern, AValue: string): Boolean;

implementation

uses
  nextpas.core.crypto.hash,
  nextpas.core.crypto.ed25519,
  nextpas.core.crypto.bigint,
  nextpas.core.crypto.constant_time,
  nextpas.core.crypto.hmac,
  nextpas.core.encoding.base64,
  nextpas.core.platform.files.text;

{ ---- 公钥 blob 解析 ---- }

function SshParseHostKey(const ABlob: TBytes; out AInfo: TSshHostKeyInfo): Boolean;
var
  LR: TsshReader;
  LAlg: string;
begin
  Result := False;
  LR := TsshReader.Create(ABlob);
  try
    LAlg := LR.ReadStringText;
    if LAlg = 'ssh-ed25519' then
    begin
      AInfo.AlgName := LAlg;
      AInfo.Kind := hkEd25519;
      AInfo.Ed25519Pub := LR.ReadStringBytes;
      if Length(AInfo.Ed25519Pub) <> 32 then
        raise ESSHError.Create(sekKeyFormat, 'ssh hostkey: ed25519 public key not 32 bytes');
      Exit(True);
    end;
    if LAlg = 'ssh-rsa' then
    begin
      AInfo.AlgName := LAlg;
      AInfo.Kind := hkRsa;
      AInfo.RsaE := LR.ReadMPInt;
      AInfo.RsaN := LR.ReadMPInt;
      if (Length(AInfo.RsaE) = 0) or (Length(AInfo.RsaN) < 32) then
        raise ESSHError.Create(sekKeyFormat, 'ssh hostkey: rsa key fields invalid');
      Exit(True);
    end;
    AInfo := Default(TSshHostKeyInfo);
  finally
    LR.Free;
  end;
end;

{ ---- RSA PKCS#1 v1.5 验签 ---- }

const
  { DigestInfo DER 前缀（RFC 8017 §9.2）}
  DIGEST_INFO_SHA256: array[0..18] of Byte = (
    $30, $31, $30, $0d, $06, $09, $60, $86, $48, $01,
    $65, $03, $04, $02, $01, $05, $00, $04, $20);
  DIGEST_INFO_SHA512: array[0..18] of Byte = (
    $30, $51, $30, $0d, $06, $09, $60, $86, $48, $01,
    $65, $03, $04, $02, $03, $05, $00, $04, $20);

{ modexp 结果右对齐到模长（bigint 输出可能剥离了前导零）}
function LeftPadTo(const AValue: TBytes; ALen: Integer): TBytes;
var
  LOff: SizeUInt;
begin
  Result := nil;
  SetLength(Result, ALen);
  FillChar(Result[0], SizeUInt(ALen), 0);
  if SizeUInt(Length(AValue)) > SizeUInt(ALen) then
    Exit;
  LOff := SizeUInt(ALen) - SizeUInt(Length(AValue));
  if Length(AValue) > 0 then
    Move(AValue[0], Result[LOff], SizeUInt(Length(AValue)));
end;

function RsaVerifyPkcs1v15(const AE, AN, AMsgHash: TBytes;
  const ADigestInfo: array of Byte; ASig: TBytes): Boolean;
var
  LEmRaw, LEm, LExpected: TBytes;
  LErr: string;
  LTLen, LPsLen, LPos: Integer;
begin
  Result := False;
  if (Length(ASig) = 0) or (SizeUInt(Length(ASig)) > SizeUInt(Length(AN))) then
    Exit;
  if not TryBigIntModExpFromUnsignedBytes(ASig, AE, AN, LEmRaw, LErr) then
    Exit;

  LTLen := Length(ADigestInfo) + Length(AMsgHash);
  LPsLen := Length(AN) - 3 - LTLen;
  if (LPsLen < 8) or (Length(LEmRaw) > Length(AN)) then
    Exit;

  { 期望 EM = 00 01 FF..FF 00 || DigestInfo || Hash，模长定长 }
  SetLength(LExpected, Length(AN));
  FillChar(LExpected[0], SizeUInt(Length(LExpected)), 0);
  LExpected[1] := $01;
  for LPos := 2 to LPsLen + 1 do
    LExpected[LPos] := $FF;
  LPos := LPsLen + 2;
  LExpected[LPos] := $00;
  Inc(LPos);
  Move(ADigestInfo[0], LExpected[LPos], SizeUInt(Length(ADigestInfo)));
  Inc(LPos, Length(ADigestInfo));
  Move(AMsgHash[0], LExpected[LPos], SizeUInt(Length(AMsgHash)));

  LEm := LeftPadTo(LEmRaw, Length(AN));
  Result := TConstantTime.CompareBytes(LEm, LExpected) = 1;
end;

{ ---- 服务方签名验证 ---- }

function SshVerifyHostSignature(const AInfo: TSshHostKeyInfo; const AAlgName: string;
  const AH: TBytes; const ASigBlob: TBytes): Boolean;
var
  LR: TsshReader;
  LSigRaw: TBytes;
  LSigAlgName: string;
begin
  Result := False;
  LR := TsshReader.Create(ASigBlob);
  try
    LSigAlgName := LR.ReadStringText;
    LSigRaw := LR.ReadStringBytes;
  finally
    LR.Free;
  end;
  if (AAlgName <> '') and (LSigAlgName <> AAlgName) then
    Exit;

  case AInfo.Kind of
    hkEd25519:
      begin
        if (LSigAlgName <> 'ssh-ed25519') or (Length(LSigRaw) <> 64) then
          Exit;
        Result := Ed25519Verify(AInfo.Ed25519Pub, AH, LSigRaw);
      end;
    hkRsa:
      begin
        if LSigAlgName = 'rsa-sha2-512' then
          Result := RsaVerifyPkcs1v15(AInfo.RsaE, AInfo.RsaN, AH,
            DIGEST_INFO_SHA512, LSigRaw)
        else if LSigAlgName = 'rsa-sha2-256' then
          Result := RsaVerifyPkcs1v15(AInfo.RsaE, AInfo.RsaN, AH,
            DIGEST_INFO_SHA256, LSigRaw);
        { 裸 ssh-rsa（SHA-1）不在现代集合内：拒绝 }
      end;
    else
      Result := False;
  end;
end;

{ ---- 指纹 ---- }

function SshFingerprintSHA256(const ABlob: TBytes): string;
var
  LB64: string;
begin
  LB64 := Base64Encode(SHA256(ABlob));
  while (Length(LB64) > 0) and (LB64[Length(LB64)] = '=') do
    Delete(LB64, Length(LB64), 1);
  Result := 'SHA256:' + LB64;
end;

{ ---- 通配符匹配 ---- }

{ 经典双指针回溯：'*' 任意串、'?' 恰好一字符 }
function SshWildMatch(const APattern, AValue: string): Boolean;
var
  P, V, LStarP, LStarV: Integer;
begin
  P := 1;
  V := 1;
  LStarP := 0;
  LStarV := 0;
  while V <= Length(AValue) do
  begin
    if (P <= Length(APattern))
      and ((APattern[P] = '?') or (APattern[P] = AValue[V])) then
    begin
      Inc(P);
      Inc(V);
    end
    else if (P <= Length(APattern)) and (APattern[P] = '*') then
    begin
      LStarP := P;
      LStarV := V;
      Inc(P);
    end
    else if LStarP > 0 then
    begin
      P := LStarP + 1;
      Inc(LStarV);
      V := LStarV;
    end
    else
      Exit(False);
  end;
  while (P <= Length(APattern)) and (APattern[P] = '*') do
    Inc(P);
  Result := P > Length(APattern);
end;

{ ---- known_hosts ---- }

constructor TSshKnownHosts.Create;
begin
  inherited Create;
  FCount := 0;
end;

procedure TSshKnownHosts.AddEntry(const APatterns: string; const ABlob: TBytes);
begin
  Inc(FCount);
  SetLength(FPatterns, FCount);
  SetLength(FBlobs, FCount);
  FPatterns[FCount - 1] := APatterns;
  FBlobs[FCount - 1] := ABlob;
end;

procedure TSshKnownHosts.LoadFromFile(const APath: string);
var
  LContent: AnsiString;
  I, LStart: Integer;
begin
  if not FileReadAllText(APath, LContent) then
    Exit;                       { 文件不存在/不可读：保持当前集合 }
  LStart := 1;
  for I := 1 to Length(LContent) + 1 do
  begin
    if (I > Length(LContent)) or (LContent[I] = #10) then
    begin
      AddLine(Copy(LContent, LStart, I - LStart));
      LStart := I + 1;
    end;
  end;
end;

procedure TSshKnownHosts.AddLine(const ALine: string);
var
  LTrimmed: string;
  LRaw, LParts: TStringArray;
  I, LKept: Integer;
  LBlob: TBytes;
begin
  LTrimmed := Trim(ALine);
  if (LTrimmed = '') or (LTrimmed[1] = '#') then
    Exit;
  { @cert-authority / @revoked 标记行：当前不支持 CA 语义，跳过 }
  if LTrimmed[1] = '@' then
    Exit;
  { 手工剔除空字段：known_hosts 允许连续空格分隔 }
  LRaw := LTrimmed.Split([' ']);
  SetLength(LParts, Length(LRaw));
  LKept := 0;
  for I := 0 to High(LRaw) do
    if LRaw[I] <> '' then
    begin
      LParts[LKept] := LRaw[I];
      Inc(LKept);
    end;
  if LKept < 3 then
    Exit;
  LBlob := Base64Decode(LParts[2]);
  if Length(LBlob) > 0 then
    AddEntry(LParts[0], LBlob);
end;

function TSshKnownHosts.Count: Integer;
begin
  Result := FCount;
end;

{ 该 pattern 字段是否匹配查询名（含 |1| 散列条目处理）}
function PatternMatches(const APatterns, AHostName: string; APort: Word): Boolean;
const
  HASH_MARK = '|1|';
var
  LCands: TStringArray;
  I: Integer;
  LQueryPlain, LQueryPorted, LOne: string;
  LPipe1, LPipe2: Integer;
  LSalt, LExpectHash: TBytes;
begin
  Result := False;
  LQueryPlain := AHostName;
  if APort = SSH_DEFAULT_PORT then
    LQueryPorted := ''
  else
    LQueryPorted := '[' + AHostName + ']:' + IntToStr(APort);

  LCands := APatterns.Split([',']);
  for I := 0 to High(LCands) do
  begin
    LOne := Trim(LCands[I]);
    if LOne = '' then
      Continue;
    if Copy(LOne, 1, Length(HASH_MARK)) = HASH_MARK then
    begin
      { |1|salt_b64|hash_b64，HMAC-SHA1(salt, hostname) }
      LPipe1 := Length(HASH_MARK);
      LPipe2 := PosEx('|', LOne, LPipe1 + 1);
      if LPipe2 <= 0 then
        Continue;
      LSalt := Base64Decode(Copy(LOne, LPipe1 + 1, LPipe2 - LPipe1 - 1));
      LExpectHash := Base64Decode(Copy(LOne, LPipe2 + 1, MaxInt));
      if Length(LSalt) = 0 then
        Continue;
      if (LQueryPorted <> '')
        and (TConstantTime.CompareBytes(
               HMAC_SHA1(LSalt, SshBytesFromText(LQueryPorted)), LExpectHash) = 1) then
        Exit(True);
      if TConstantTime.CompareBytes(HMAC_SHA1(LSalt, SshBytesFromText(LQueryPlain)),
             LExpectHash) = 1 then
        Exit(True);
    end
    else
    begin
      if (LQueryPorted <> '') and SshWildMatch(LOne, LQueryPorted) then
        Exit(True);
      if SshWildMatch(LOne, LQueryPlain) then
        Exit(True);
    end;
  end;
end;

function TSshKnownHosts.BlobsForHost(const AHostName: string; APort: Word): TBlobArray;
var
  I, LOut: Integer;
begin
  Result := nil;
  LOut := 0;
  for I := 0 to FCount - 1 do
  begin
    if PatternMatches(FPatterns[I], AHostName, APort) then
    begin
      Inc(LOut);
      SetLength(Result, LOut);
      Result[LOut - 1] := FBlobs[I];
    end;
  end;
end;

function TSshKnownHosts.ContainsKey(const AHostName: string; APort: Word;
  const ABlob: TBytes): Boolean;
var
  LCandidates: TBlobArray;
  I: Integer;
begin
  Result := False;
  LCandidates := BlobsForHost(AHostName, APort);
  for I := 0 to High(LCandidates) do
    if (Length(LCandidates[I]) = Length(ABlob))
      and ((Length(ABlob) = 0)
        or CompareMem(@LCandidates[I][0], @ABlob[0], SizeUInt(Length(ABlob)))) then
      Exit(True);
end;

end.
