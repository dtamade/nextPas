unit nextpas.core.ssh.hostkey;

{** nextpas.core.ssh - 主机公钥解析、验签、指纹与 known_hosts。
 *
 * 支持 ssh-ed25519、ssh-rsa（rsa-sha2-256/512，PKCS#1 v1.5）与
 * ecdsa-sha2-nistp256（P-256，SHA-256，mpint(r,s)→DER 转换后调 crypto.ecdsa）。
 * known_hosts 支持：明文模式（含 * ? 通配、逗号列表）、[host]:port 形式、
 * |1|salt|hash 散列条目（HMAC-SHA1）；@cert-authority/@revoked 行跳过。
 *
 * RSA 验签路径：bigint 模幂（公钥指数）→ EMSA-PKCS1-v1_5 重造 → 常数时间比较。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.text.strings,
  nextpas.core.text.conv,
  nextpas.core.text.utils,
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
    EcdsaP256X: TBytes;   { hkEcdsaP256：32 字节 X }
    EcdsaP256Y: TBytes;   { hkEcdsaP256：32 字节 Y }
  end;

{** 构造 ecdsa-sha2-nistp256 公钥 wire blob。供测试与上层构造器复用。*}
function SshEcdsaP256PubToBlob(const AX, AY: TBytes): TBytes;

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
  nextpas.core.crypto.ecdsa,
  nextpas.core.crypto.asn1,
  nextpas.core.encoding.base64,
  nextpas.core.platform.files.text,
  nextpas.core.ssh.rsa;

{ 从 AFrom 起查找字符（替代 StrUtils.PosEx，冷路径无需优化）}
function PosCharFrom(const AChar: Char; const AText: string; AFrom: Integer): Integer;
var
  I: Integer;
begin
  for I := AFrom to Length(AText) do
    if AText[I] = AChar then
      Exit(I);
  Result := 0;
end;

{ ---- 公钥 blob 解析 ---- }

function SshParseHostKey(const ABlob: TBytes; out AInfo: TSshHostKeyInfo): Boolean;
var
  LR: TsshReader;
  LAlg, LCurve: string;
  LQ: TBytes;
  LPoint: TECPoint;
  LErr: string;
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
    if LAlg = 'ecdsa-sha2-nistp256' then
    begin
      LCurve := LR.ReadStringText;
      if LCurve <> 'nistp256' then
        raise ESSHError.Create(sekKeyFormat, 'ssh hostkey: ecdsa curve must be nistp256');
      LQ := LR.ReadStringBytes;
      if (Length(LQ) <> 65) or (LQ[0] <> $04) then
        raise ESSHError.Create(sekKeyFormat, 'ssh hostkey: ecdsa point must be 65-byte uncompressed');
      AInfo.AlgName := LAlg;
      AInfo.Kind := hkEcdsaP256;
      SetLength(AInfo.EcdsaP256X, 32);
      SetLength(AInfo.EcdsaP256Y, 32);
      Move(LQ[1], AInfo.EcdsaP256X[0], 32);
      Move(LQ[33], AInfo.EcdsaP256Y[0], 32);
      LPoint.X := AInfo.EcdsaP256X;
      LPoint.Y := AInfo.EcdsaP256Y;
      LPoint.IsInfinity := False;
      if not TryValidateP256Point(LPoint, LErr) then
        raise ESSHError.Create(sekKeyFormat, 'ssh hostkey: ecdsa point invalid: ' + LErr);
      Exit(True);
    end;
    AInfo := Default(TSshHostKeyInfo);
  finally
    LR.Free;
  end;
end;

function SshEcdsaP256PubToBlob(const AX, AY: TBytes): TBytes;
var
  LW: TsshWriter;
  LQ: TBytes;
  LPadX, LPadY: TBytes;
  LErr: string;
begin
  if not TryToFixedLength32(AX, LPadX, LErr) then
    raise ESSHError.Create(sekKeyFormat, 'ssh hostkey: ecdsa X pad failed: ' + LErr);
  if not TryToFixedLength32(AY, LPadY, LErr) then
    raise ESSHError.Create(sekKeyFormat, 'ssh hostkey: ecdsa Y pad failed: ' + LErr);
  SetLength(LQ, 65);
  LQ[0] := $04;
  Move(LPadX[0], LQ[1], 32);
  Move(LPadY[0], LQ[33], 32);
  LW := TsshWriter.Create(128);
  try
    LW.PutStringText('ecdsa-sha2-nistp256');
    LW.PutStringText('nistp256');
    LW.PutStringBytes(LQ);
    Result := LW.ToBytes;
  finally
    LW.Free;
  end;
end;

{ ---- RSA PKCS#1 v1.5 验签 ---- }

{ DigestInfo 前缀、EM 编码与常数时间比较统一收口在 nextpas.core.ssh.rsa：
  签名（客户端 publickey）与验签（主机密钥）共享同一套编码逻辑，
  RsaVerifyPkcs1v15 直接由该单元提供。 }

{ ---- 服务方签名验证 ---- }

function SshVerifyHostSignature(const AInfo: TSshHostKeyInfo; const AAlgName: string;
  const AH: TBytes; const ASigBlob: TBytes): Boolean;
var
  LR: TsshReader;
  LSigRaw: TBytes;
  LSigAlgName: string;
  LErr: string;
  LWriter: TASN1Writer;
  LDER, LPub: TBytes;
  LR2: TsshReader;
  LRBytes, LSBytes: TBytes;
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
    hkEcdsaP256:
      begin
        if LSigAlgName <> 'ecdsa-sha2-nistp256' then
          Exit;
        try
          LR2 := TsshReader.Create(LSigRaw);
          try
            LRBytes := LR2.ReadMPInt;
            LSBytes := LR2.ReadMPInt;
            if LR2.Remaining <> 0 then
              Exit;
          finally
            LR2.Free;
          end;
        except
          Exit;
        end;
        LWriter := TASN1Writer.Create;
        try
          LWriter.BeginSequence;
          LWriter.WriteBigInteger(LRBytes);
          LWriter.WriteBigInteger(LSBytes);
          LWriter.EndSequence;
          LDER := LWriter.GetData;
        finally
          LWriter.Free;
        end;
        SetLength(LPub, 65);
        LPub[0] := $04;
        if (Length(AInfo.EcdsaP256X) <> 32) or (Length(AInfo.EcdsaP256Y) <> 32) then
          Exit;
        Move(AInfo.EcdsaP256X[0], LPub[1], 32);
        Move(AInfo.EcdsaP256Y[0], LPub[33], 32);
        Result := TryECDSAVerifyP256SHA256(AH, LPub, LDER, LErr);
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
  LRaw := StringsSplit(LTrimmed, ' ', True);
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

  LCands := StringsSplit(APatterns, ',');
  for I := 0 to High(LCands) do
  begin
    LOne := Trim(LCands[I]);
    if LOne = '' then
      Continue;
    if Copy(LOne, 1, Length(HASH_MARK)) = HASH_MARK then
    begin
      { |1|salt_b64|hash_b64，HMAC-SHA1(salt, hostname) }
      LPipe1 := Length(HASH_MARK);
      LPipe2 := PosCharFrom('|', LOne, LPipe1 + 1);
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
    if TConstantTime.CompareBytes(LCandidates[I], ABlob) = 1 then
      Exit(True);
end;

end.
