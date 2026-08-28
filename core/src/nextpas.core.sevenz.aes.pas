unit nextpas.core.sevenz.aes;

{**
 * nextpas.core.sevenz.aes - 7z AES-256 加密 coder 支持
 *
 * 属性解析与密钥派生逐字对齐官方 7-Zip CPP/7zip/Crypto/7zAes.cpp：
 * - props[0]：低 6 位 NumCyclesPower，bit7/bit6 标记盐/IV 存在；
 *   props[1]：高半字节+存在位 = 盐长，低半字节+存在位 = IV 长
 * - 密钥派生：NumCyclesPower=$3F 时取 salt||password||补零；否则对
 *   2^power 轮 salt||password||LE32(r) 做 SHA256（复用 hash.sha256）
 * - 数据面为 AES-256-CBC 无填充（复用 crypto.aescbc），IV 按零补足
 *   16 字节；块长由容器 pack 尺寸保证
 * 口令以 UTF-16LE 字节序列进入 KDF（7z 规范）。
 * 偏离参考实现一处：NumCyclesPower 上界在解析入口即校验——参考实现把
 * 校验放在扩展路径末尾，单字节属性路径可放行 power>24 并在派生时
 * 进入 2^57 轮循环；此处提前拒绝以消除该挂死面。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.sevenz.base;

type
  { AES coder 属性（解析结果，IV 以零补足 16 字节供 CBC 直接使用） }
  TSevenZAesProps = record
    NumCyclesPower: Byte;
    SaltSize: Integer;
    Salt: array[0..15] of Byte;
    IvSize: Integer;
    Iv: array[0..15] of Byte;
  end;

{ 解析 AES coder 属性；空属性按参考实现的默认值处理（power=0、无盐、零 IV），
  长度不符或 power 超界抛 ESevenZError }
procedure SevenZParseAesProps(const AProps: TBytes;
  out AOut: TSevenZAesProps);

{ 由属性与密码派生 32 字节 AES 密钥 }
procedure SevenZDeriveAesKey(const AProps: TSevenZAesProps;
  const APassword: string; out AKey: TBytes);

{ 按参考 WriteCoderProperties 布局序列化属性：b0 = power |（盐非零置
  $80）|（IV 非零置 $40）；任一存在时 b1 =（盐长-1)<<4 |（IV长-1），
  后接盐与 IV 原文。与 SevenZParseAesProps 严格互逆 }
function SevenZBuildAesProps(ANumCyclesPower: Byte;
  const ASalt, AIv: TBytes): TBytes;

{ 解密一段 AES-256-CBC 数据（长度须为 16 的倍数） }
procedure SevenZAesDecryptData(const AProps: TSevenZAesProps;
  const APassword: string; const AData: TBytes; out AOut: TBytes);

{ 加密一段 AES-256-CBC 数据（长度须为 16 的倍数；容器 pack 的块取整
  零填充由调用方负责，与读端按声明尺寸截断对称） }
procedure SevenZAesEncryptData(const AProps: TSevenZAesProps;
  const APassword: string; const AData: TBytes; out AOut: TBytes);

{ 便捷入口：解析原始属性字节后直接解密（执行引擎路径） }
procedure SevenZAesDecryptProps(const AProps: TBytes;
  const APassword: string; const AData: TBytes; out AOut: TBytes);

implementation

uses
  nextpas.core.errors,
  nextpas.core.hash.intf,
  nextpas.core.hash.sha256,
  nextpas.core.crypto.aescbc;

procedure SevenZParseAesProps(const AProps: TBytes;
  out AOut: TSevenZAesProps);
var
  LPos: SizeInt;
begin
  AOut := Default(TSevenZAesProps);
  if Length(AProps) = 0 then
    Exit;  { 参考实现对空属性返回默认值 }
  {$PUSH}{$Q-}{$R-}
  AOut.NumCyclesPower := AProps[0] and $3F;
  {$POP}
  { 防御性上界：参考实现延后到扩展路径末尾才校验，单字节属性可放行
    power>24 造成派生循环挂死；此处入口即拒 }
  if (AOut.NumCyclesPower > 24) and (AOut.NumCyclesPower <> $3F) then
    raise ESevenZError.CreateFmt(
      'aes cycles power %d not supported', [AOut.NumCyclesPower]);
  if (AProps[0] and $C0) = 0 then
  begin
    if Length(AProps) <> 1 then
      raise ESevenZError.Create('aes props trailing bytes');
    Exit;
  end;
  if Length(AProps) < 2 then
    raise ESevenZError.Create('aes props too short');
  {$PUSH}{$Q-}{$R-}
  AOut.SaltSize := ((AProps[0] shr 7) and 1) + (AProps[1] shr 4);
  AOut.IvSize := ((AProps[0] shr 6) and 1) + (AProps[1] and $0F);
  {$POP}
  if (AOut.SaltSize > 16) or (AOut.IvSize > 16) then
    raise ESevenZError.Create('aes props salt/iv size out of range');
  if Length(AProps) <> 2 + AOut.SaltSize + AOut.IvSize then
    raise ESevenZError.Create('aes props size mismatch');
  LPos := 2;
  Move(AProps[LPos], AOut.Salt[0], AOut.SaltSize);
  Inc(LPos, AOut.SaltSize);
  Move(AProps[LPos], AOut.Iv[0], AOut.IvSize);
end;

procedure SevenZDeriveAesKey(const AProps: TSevenZAesProps;
  const APassword: string; out AKey: TBytes);
var
  LPw: TBytes;
  LI, LPos: Integer;
  LHasher: IHasher;
  LRound: UInt64;
  LRoundBuf: array[0..7] of Byte;
  LRounds: UInt64;
begin
  AKey := nil;
  { 7z 规范：口令以 UTF-16LE 字节序列进入 KDF }
  LPw := SevenZUtf8ToUtf16Le(APassword);
  SetLength(AKey, 32);
  if AProps.NumCyclesPower = $3F then
  begin
    LPos := 0;
    if AProps.SaltSize > 0 then
      Move(AProps.Salt[0], AKey[LPos], AProps.SaltSize);
    Inc(LPos, AProps.SaltSize);
    for LI := 0 to High(LPw) do
      if LPos < 32 then
      begin
        AKey[LPos] := LPw[LI];
        Inc(LPos);
      end;
    for LI := LPos to 31 do
      AKey[LI] := 0;
    Exit;
  end;
  LHasher := NewSHA256;
  LRounds := UInt64(1) shl AProps.NumCyclesPower;
  FillChar(LRoundBuf, SizeOf(LRoundBuf), 0);
  for LRound := 0 to LRounds - 1 do
  begin
    if AProps.SaltSize > 0 then
      LHasher.Write(AProps.Salt[0], SizeUInt(AProps.SaltSize));
    if Length(LPw) > 0 then
      LHasher.Write(LPw[0], SizeUInt(Length(LPw)));
    {$PUSH}{$Q-}{$R-}
    for LI := 0 to 7 do
      LRoundBuf[LI] := Byte((LRound shr (8 * LI)) and $FF);
    {$POP}
    LHasher.Write(LRoundBuf[0], 8);
  end;
  AKey := LHasher.SumBytes;
end;

function SevenZBuildAesProps(ANumCyclesPower: Byte;
  const ASalt, AIv: TBytes): TBytes;
var
  LPos: SizeInt;
  LSaltNib, LIvNib: Byte;
begin
  Result := nil;
  { 与解析端同一约束：非法档位/超长盐 IV 在序列化前即拒 }
  if (ANumCyclesPower > 24) and (ANumCyclesPower <> $3F) then
    raise ESevenZError.CreateFmt(
      'aes cycles power %d not supported', [ANumCyclesPower]);
  if (Length(ASalt) > 16) or (Length(AIv) > 16) then
    raise ESevenZError.Create('aes salt/iv longer than 16 bytes');
  if (Length(ASalt) = 0) and (Length(AIv) = 0) then
    SetLength(Result, 1)
  else
    SetLength(Result, 2 + Length(ASalt) + Length(AIv));
  Result[0] := ANumCyclesPower;
  if Length(ASalt) > 0 then
    Result[0] := Result[0] or $80;
  if Length(AIv) > 0 then
    Result[0] := Result[0] or $40;
  if Length(Result) > 1 then
  begin
    if Length(ASalt) > 0 then
      LSaltNib := Byte(Length(ASalt) - 1)
    else
      LSaltNib := 0;
    if Length(AIv) > 0 then
      LIvNib := Byte(Length(AIv) - 1)
    else
      LIvNib := 0;
    {$PUSH}{$Q-}{$R-}
    Result[1] := Byte((LSaltNib shl 4) or LIvNib);
    {$POP}
    LPos := 2;
    if Length(ASalt) > 0 then
    begin
      Move(ASalt[0], Result[LPos], Length(ASalt));
      Inc(LPos, Length(ASalt));
    end;
    if Length(AIv) > 0 then
      Move(AIv[0], Result[LPos], Length(AIv));
  end;
end;

procedure SevenZAesDecryptData(const AProps: TSevenZAesProps;
  const APassword: string; const AData: TBytes; out AOut: TBytes);
var
  LKey, LIv: TBytes;
begin
  if (Length(AData) mod 16) <> 0 then
    raise ESevenZError.Create('aes data not block aligned');
  SevenZDeriveAesKey(AProps, APassword, LKey);
  { 属性解析时 Iv 已零补足 16 字节 }
  SetLength(LIv, 16);
  Move(AProps.Iv[0], LIv[0], 16);
  AOut := AESCBCDecryptNoPadding(LKey, LIv, AData);
end;

procedure SevenZAesEncryptData(const AProps: TSevenZAesProps;
  const APassword: string; const AData: TBytes; out AOut: TBytes);
var
  LKey, LIv: TBytes;
begin
  if (Length(AData) mod 16) <> 0 then
    raise ESevenZError.Create('aes data not block aligned');
  SevenZDeriveAesKey(AProps, APassword, LKey);
  SetLength(LIv, 16);
  Move(AProps.Iv[0], LIv[0], 16);
  AOut := AESCBCEncryptNoPadding(LKey, LIv, AData);
end;

procedure SevenZAesDecryptProps(const AProps: TBytes;
  const APassword: string; const AData: TBytes; out AOut: TBytes);
var
  LParsed: TSevenZAesProps;
begin
  SevenZParseAesProps(AProps, LParsed);
  SevenZAesDecryptData(LParsed, APassword, AData, AOut);
end;

end.
