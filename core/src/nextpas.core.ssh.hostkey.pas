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
  nextpas.core.text.view,
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
  IHostKeyFileReader = interface
    ['{9C1E6E10-4A11-4F72-9D30-5A0000000007}']
    function ReadAllText(const APath: string; out AContent: string): Boolean;
  end;

  TDefaultHostKeyFileReader = class(TInterfacedObject, IHostKeyFileReader)
  public
    function ReadAllText(const APath: string; out AContent: string): Boolean;
  end;

  { known_hosts 条目集合 }
  TSshKnownHosts = class
  private
    FPatterns: TStringArray;   { 每条目的 pattern 字段原样保留 }
    FBlobs: TBlobArray;
    FCount: Integer;
    FCap: SizeUInt;
    procedure AddEntry(const APatterns: string; const ABlob: TBytes);
  public
    constructor Create;

    { 文件不存在时保持空集合（策略由调用方决定）}
    procedure LoadFromFile(const APath: string); overload;
    procedure LoadFromFile(const APath: string; const AReader: IHostKeyFileReader); overload;
    procedure LoadFromReader(const AReader: IHostKeyFileReader; const APath: string);
    procedure AddLine(const ALine: string); overload;
    procedure AddLine(const ALine: TStringView); overload;
    function Count: Integer;

    { 返回匹配该主机的全部密钥 blob（可能为空数组）}
    function BlobsForHost(const AHostName: string; APort: Word): TBlobArray;

    { 便捷判定：该主机的记录里是否已包含此 blob }
    function ContainsKey(const AHostName: string; APort: Word;
      const ABlob: TBytes): Boolean;
  end;

{ 通配符匹配：'*' 任意串、'?' 单字符，'[' ']' 字面量；大小写敏感 - OpenSSH known_hosts 语义私有实现 }
function SshWildMatch(const APattern, AValue: string): Boolean; inline;

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.crypto.hash,
  nextpas.core.crypto.ed25519,
  nextpas.core.crypto.bigint,
  nextpas.core.crypto.constant_time,
  nextpas.core.crypto.hmac,
  nextpas.core.crypto.ecdsa,
  nextpas.core.crypto.asn1,
  nextpas.core.encoding.base64,
  nextpas.core.platform.fs,
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
  LLen: Integer;
begin
  LB64 := Base64Encode(SHA256(ABlob));
  LLen := Length(LB64);
  while (LLen > 0) and (LB64[LLen] = '=') do
    Dec(LLen);
  SetLength(LB64, LLen);
  Result := 'SHA256:' + LB64;
end;

{ ---- 通配符匹配 ---- }

{ OpenSSH known_hosts 语义：仅 '*'（任意串，含 '/' 外一切字符）与 '?'（单字符），
  '[' ']' 为 '[host]:port' 条目字面量（非字符类）。L1 text.strings.GlobMatch 为
  路径 glob（'*' 不跨分隔符、'[' 开字符类、无转义），语义不合，故此处保留双指针
  回溯私有实现（源自主仓已删的 text.wildmatch.match，行为经 test_ssh_hostkey 锁定）。 }
function SshPatternMatch(APattern: PAnsiChar; APatternLen: SizeUInt;
  AValue: PAnsiChar; AValueLen: SizeUInt): Boolean;
var
  P, V, StarP, StarV: SizeInt;
begin
  if APatternLen = 0 then
    Exit(AValueLen = 0);
  if AValueLen = 0 then
  begin
    for P := 0 to SizeInt(APatternLen) - 1 do
      if APattern[P] <> '*' then
        Exit(False);
    Exit(True);
  end;
  P := 0;
  V := 0;
  StarP := -1;
  StarV := 0;
  while V < SizeInt(AValueLen) do
  begin
    if (P < SizeInt(APatternLen)) and ((APattern[P] = '?') or (APattern[P] = AValue[V])) then
    begin
      Inc(P);
      Inc(V);
    end
    else if (P < SizeInt(APatternLen)) and (APattern[P] = '*') then
    begin
      StarP := P;
      StarV := V;
      Inc(P);
    end
    else if StarP >= 0 then
    begin
      P := StarP + 1;
      Inc(StarV);
      V := StarV;
    end
    else
      Exit(False);
  end;
  while (P < SizeInt(APatternLen)) and (APattern[P] = '*') do
    Inc(P);
  Result := P >= SizeInt(APatternLen);
end;

function SshWildMatch(const APattern, AValue: string): Boolean; inline;
begin
  if APattern = '' then
    Exit(AValue = '');
  if AValue = '' then
    Exit(SshPatternMatch(PAnsiChar(APattern), SizeUInt(Length(APattern)), nil, 0));
  Result := SshPatternMatch(PAnsiChar(APattern), SizeUInt(Length(APattern)),
    PAnsiChar(AValue), SizeUInt(Length(AValue)));
end;

{ ---- known_hosts ---- }

constructor TSshKnownHosts.Create;
begin
  inherited Create;
  FCount := 0;
  FCap := 0;
end;

procedure TSshKnownHosts.AddEntry(const APatterns: string; const ABlob: TBytes);
begin
  Inc(FCount);
  if SizeUInt(FCount) > FCap then
  begin
    BytesEnsureCapacity(FCap, SizeUInt(FCount));
    SetLength(FPatterns, FCap);
    SetLength(FBlobs, FCap);
  end;
  FPatterns[FCount - 1] := APatterns;
  FBlobs[FCount - 1] := ABlob;
end;

function TDefaultHostKeyFileReader.ReadAllText(const APath: string; out AContent: string): Boolean;
var
  LData: Pointer;
  LLen: PtrUInt;
  LRes: Int32;
begin
  // L2→L0 合规：经 nextpas.core.platform.fs（L0）直读，不依赖同层 nextpas.core.fs；零拷贝 Move 单次分配
  // perf: single platform_fs_read_file alloc + single Move (zero-copy via Move), no intermediate TBytes+Copy
  // stability: platform_fs_free_buf in finally guarantees no leak on SetLength/OOM exception
  AContent := '';
  Result := False;
  if APath = '' then
    Exit;
  LData := nil;
  LLen := 0;
  LRes := platform_fs_read_file(PAnsiChar(APath), LData, LLen);
  if LRes <> 0 then
    Exit;
  try
    SetLength(AContent, LLen);
    if LLen > 0 then
      Move(LData^, AContent[1], LLen);
    Result := True;
  finally
    platform_fs_free_buf(LData);
  end;
end;

procedure TSshKnownHosts.LoadFromFile(const APath: string);
var LReader: IHostKeyFileReader;
begin
  LReader := TDefaultHostKeyFileReader.Create;
  LoadFromFile(APath, LReader);
end;

procedure TSshKnownHosts.LoadFromFile(const APath: string; const AReader: IHostKeyFileReader);
begin
  LoadFromReader(AReader, APath);
end;

procedure TSshKnownHosts.LoadFromReader(const AReader: IHostKeyFileReader; const APath: string);
var
  LContent: string;
  LView, LLine: TStringView;
  LStart, I: SizeUInt;
begin
  if (AReader = nil) or not AReader.ReadAllText(APath, LContent) then
    Exit;                       { 文件不存在/不可读：保持当前集合 }
  // perf: TByteSpan/TStringView 零拷贝视图遍 LContent，O(n) 单次扫描零中间分配；bytes.ops 单源 Move 仅存最终 AddEntry
  // stability: LContent 生命周期覆盖全部 view，切片不逃逸，AddLine 内 ToString 仅对有效条目两份拷贝
  LView := TStringView.FromStr(LContent);
  LStart := 0;
  for I := 0 to LView.Len do
  begin
    if (I = LView.Len) or (LView.Data[I] = #10) then
    begin
      LLine := LView.Slice(LStart, I - LStart);
      // CRLF 尾 #13 由 AddLine.Trim 单源 IsWhitespace 零拷贝剔除
      AddLine(LLine);
      LStart := I + 1;
    end;
  end;
end;

procedure TSshKnownHosts.AddLine(const ALine: string); inline;
begin
  // perf: string 薄转发至 view 单源，零拷贝 Trim/切片，inline 消除调用开销
  AddLine(TStringView.FromStr(ALine));
end;

procedure TSshKnownHosts.AddLine(const ALine: TStringView);
var
  LView: TStringView;
  LFields: array[0..2] of TStringView;
  LCount: Integer;
  LPos, LStart: SizeUInt;
  LPattern, LB64: string;
  LBlob: TBytes;
begin
  // perf: 单源 bytes.ops/TStringView 零拷贝 Trim+Slice；仅有效条目触发两份 ToString（pattern+blob b64）
  LView := ALine.Trim;
  if LView.IsEmpty then
    Exit;
  if (LView.Data[0] = '#') or (LView.Data[0] = '@') then
    Exit; { # 注释 / @cert-authority/@revoked：当前不支持 CA 语义，跳过 }
  LCount := 0;
  LPos := 0;
  while (LPos < LView.Len) and (LCount < 3) do
  begin
    while (LPos < LView.Len) and (LView.Data[LPos] = ' ') do
      Inc(LPos);
    if LPos >= LView.Len then
      Break;
    LStart := LPos;
    while (LPos < LView.Len) and (LView.Data[LPos] <> ' ') do
      Inc(LPos);
    LFields[LCount] := LView.Slice(LStart, LPos - LStart);
    Inc(LCount);
  end;
  if LCount < 3 then
    Exit;
  LPattern := LFields[0].ToString;
  LB64 := LFields[2].ToString;
  LBlob := Base64Decode(LB64);
  if Length(LBlob) > 0 then
    AddEntry(LPattern, LBlob);
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
    LQueryPorted := '[' + AHostName + ']:' + nextpas.core.text.conv.IntToStr(Int64(APort));

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
  LCap: SizeUInt;
begin
  Result := nil;
  LOut := 0;
  LCap := 0;
  for I := 0 to FCount - 1 do
  begin
    if PatternMatches(FPatterns[I], AHostName, APort) then
    begin
      if SizeUInt(LOut + 1) > LCap then
      begin
        BytesEnsureCapacity(LCap, SizeUInt(LOut + 1));
        SetLength(Result, LCap);
      end;
      Result[LOut] := FBlobs[I];
      Inc(LOut);
    end;
  end;
  if SizeUInt(LOut) <> LCap then
    SetLength(Result, LOut);
end;

function TSshKnownHosts.ContainsKey(const AHostName: string; APort: Word;
  const ABlob: TBytes): Boolean;
var
  LCandidates: TBlobArray;
  I: Integer;
  LFound: Integer;
begin
  LFound := 0;
  LCandidates := BlobsForHost(AHostName, APort);
  for I := 0 to High(LCandidates) do
    LFound := LFound or TConstantTime.CompareBytes(LCandidates[I], ABlob);
  Result := LFound = 1;
end;

end.
