unit nextpas.core.auth.password;
{**
 * @desc 密码哈希原语（auth 家族，批次 6）：Argon2id 画像 + PHC 存取 +
 *       登录期重哈希判定。算法零实现——底座复用 crypto.argon2
 *       （Argon2HashStr/Verify）、crypto.random（盐）、text.utf8（规范化）。
 *       契约见 docs/auth/CONTRACT.md §2：
 *       - 口令 string 一律按 UTF-8 规范化为字节（RFC 9106 口令即字节串，
 *         应用层唯一规范形，避免平台码页歧义）；
 *       - 空口令 / 非法画像 = 编程错误，EArgumentError fail-fast
 *         （jwt 空密钥同款纪律）；
 *       - 校验失败（格式不符 / 口令错误）= 数据态，一律 False 不抛。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.crypto.argon2;

type
  { Argon2id 参数画像。盐固定 16 字节 CSPRNG（crypto.argon2 内部行为，
    本单元契约钉死）；Default 取 OWASP Password Storage Cheat Sheet
    的 Argon2id 建议（19 MiB / t=2 / p=1），属快照值，运维可按算力覆盖；
    NeedsRehash 保证存量哈希可平滑升级。 }
  TArgon2Profile = record
    MemoryKiB: Integer;   { m：KiB，≥8*Parallelism 且 ≥8 }
    TimeCost: Integer;    { t：迭代次数，≥1 }
    Parallelism: Integer; { p：并行度，≥1 }
    HashLen: Integer;     { 派生哈希字节数，≥16（本单元地板，严于算法下限 4） }
  end;

{ OWASP ASAS 默认画像（m=19456 KiB, t=2, p=1, hash=32）。 }
function DefaultArgon2Profile: TArgon2Profile;

{ 画像合法性：MemoryKiB ≥ 8*Parallelism 且 ≥8、TimeCost ≥1、Parallelism ≥1、
  HashLen ≥16。非法画像进 HashPassword 抛 EArgumentError。 }
function IsValidArgon2Profile(const AProfile: TArgon2Profile): Boolean;

{ 按 UTF-8 规范化口令后以画像哈希，返回 PHC 编码串
  （$argon2id$v=19$m=…,t=…,p=…$<b64salt>$<b64hash>），直接入库。
  空口令 / 非法画像抛 EArgumentError；每次调用随机新盐（同口令两哈希必不同）。 }
function HashPassword(const APassword: string): string; overload;
function HashPassword(const APassword: string;
  const AProfile: TArgon2Profile): string; overload;
function HashPassword(const APassword: TBytes;
  const AProfile: TArgon2Profile): string; overload;

{ PHC 编码串校验：解析成功且重算结果常量时间相等才 True。
  格式不合法 / 版本非 19 / 长度不符 / 口令错误一律 False（fail-closed 数据态）。 }
function VerifyPassword(const APassword: string;
  const AEncodedHash: string): Boolean; overload;
function VerifyPassword(const APassword: TBytes;
  const AEncodedHash: string): Boolean; overload;

{ 登录期透明升级判定（单向，只升不降）：
  - 任一维度（m/t/p）低于画像或类型非 argon2id → True；
  - 编码串畸形不可解析 → True（升级尝试无害，正确性仍由 Verify 把关）；
  - 强于或等于画像 → False（不因调低默认画像触发降级扰动）。
  无画像重载按 DefaultArgon2Profile 判定。 }
function NeedsRehash(const AEncodedHash: string): Boolean; overload;
function NeedsRehash(const AEncodedHash: string;
  const AProfile: TArgon2Profile): Boolean; overload;

implementation

uses
  nextpas.core.exception,
  nextpas.core.text.utf8;

type
  { 局部字符串数组：避免引 SysUtils（其 TStringArray 会遮蔽接口区
    nextpas.core.base 同名类型致签名失配——mailsrv.store 教训）。 }
  TPhcSegments = array of string;

function DefaultArgon2Profile: TArgon2Profile;
begin
  Result.MemoryKiB := 19456;  { 19 MiB }
  Result.TimeCost := 2;
  Result.Parallelism := 1;
  Result.HashLen := 32;
end;

function IsValidArgon2Profile(const AProfile: TArgon2Profile): Boolean;
begin
  Result := (AProfile.Parallelism >= 1)
        and (AProfile.TimeCost >= 1)
        and (AProfile.MemoryKiB >= 8)
        and (AProfile.MemoryKiB >= 8 * AProfile.Parallelism)
        and (AProfile.HashLen >= 16);
end;

procedure ValidateProfileOrRaise(const AProfile: TArgon2Profile);
begin
  if not IsValidArgon2Profile(AProfile) then
    raise EArgumentError.Create('TArgon2Profile out of range');
end;

procedure RequireNonEmptyPassword(const APassword: TBytes);
begin
  if Length(APassword) = 0 then
    raise EArgumentError.Create('empty password');
end;

function StringToUtf8Bytes(const AValue: string): TBytes;
begin
  if Length(AValue) = 0 then
    Exit(nil);
  Result := UTF8ToBytes(AValue);
end;

function HashPassword(const APassword: string): string;
begin
  Result := HashPassword(APassword, DefaultArgon2Profile);
end;

function HashPassword(const APassword: string;
  const AProfile: TArgon2Profile): string;
begin
  Result := HashPassword(StringToUtf8Bytes(APassword), AProfile);
end;

function HashPassword(const APassword: TBytes;
  const AProfile: TArgon2Profile): string;
begin
  RequireNonEmptyPassword(APassword);
  ValidateProfileOrRaise(AProfile);
  { 盐（16 字节 CSPRNG）与 PHC 序列化由 crypto.argon2 承担。 }
  Result := Argon2HashStr(APassword, AProfile.MemoryKiB, AProfile.TimeCost,
    AProfile.Parallelism, AProfile.HashLen, atArgon2id);
end;

function VerifyPassword(const APassword: string;
  const AEncodedHash: string): Boolean;
begin
  if Length(APassword) = 0 then
    Exit(False);
  Result := Argon2Verify(StringToUtf8Bytes(APassword), AEncodedHash);
end;

function VerifyPassword(const APassword: TBytes;
  const AEncodedHash: string): Boolean;
begin
  if Length(APassword) = 0 then
    Exit(False);
  Result := Argon2Verify(APassword, AEncodedHash);
end;

{ '$' 分段（含首尾空段，与 PHC 形态一一对应；同 crypto.argon2 内部做法）。 }
function SplitDollar(const AValue: string): TPhcSegments;
var
  I, LStart: Integer;
begin
  Result := nil;
  LStart := 1;
  for I := 1 to Length(AValue) do
    if AValue[I] = '$' then
    begin
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := Copy(AValue, LStart, I - LStart);
      LStart := I + 1;
    end;
  SetLength(Result, Length(Result) + 1);
  Result[High(Result)] := Copy(AValue, LStart, Length(AValue) - LStart + 1);
end;

function SplitComma(const AValue: string): TPhcSegments;
var
  I, LStart: Integer;
begin
  Result := nil;
  LStart := 1;
  for I := 1 to Length(AValue) do
    if AValue[I] = ',' then
    begin
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := Copy(AValue, LStart, I - LStart);
      LStart := I + 1;
    end;
  SetLength(Result, Length(Result) + 1);
  Result[High(Result)] := Copy(AValue, LStart, Length(AValue) - LStart + 1);
end;

{ 'k=<digits>' → 数值；键不符 / 空 / 非纯十进制返回 False。 }
function TryParamInt(const ASegment, AKey: string; out AValue: Integer): Boolean;
var
  LTail: string;
  LCode: Integer;
begin
  Result := False;
  if Length(ASegment) <= Length(AKey) then
    Exit;
  if Copy(ASegment, 1, Length(AKey)) <> AKey then
    Exit;
  if ASegment[Length(AKey) + 1] <> '=' then
    Exit;
  LTail := Copy(ASegment, Length(AKey) + 2, MaxInt);
  if Length(LTail) = 0 then
    Exit;
  Val(LTail, AValue, LCode);
  Result := LCode = 0;
end;

function NeedsRehash(const AEncodedHash: string): Boolean;
begin
  Result := NeedsRehash(AEncodedHash, DefaultArgon2Profile);
end;

function NeedsRehash(const AEncodedHash: string;
  const AProfile: TArgon2Profile): Boolean;
var
  LSegs, LParams: TPhcSegments;
  LMem, LTime, LPar: Integer;
begin
  { PHC 形态：'' / argon2id / v=19 / m=..,t=..,p=.. / salt / hash。
    键名顺序钉死为本单元产出的形态；外来形态一律视为需升级。 }
  Result := True;

  LSegs := SplitDollar(AEncodedHash);
  if Length(LSegs) <> 6 then
    Exit;
  if LSegs[1] <> 'argon2id' then
    Exit;
  if LSegs[2] <> 'v=19' then
    Exit;

  LParams := SplitComma(LSegs[3]);
  if Length(LParams) <> 3 then
    Exit;
  if not TryParamInt(LParams[0], 'm', LMem) then
    Exit;
  if not TryParamInt(LParams[1], 't', LTime) then
    Exit;
  if not TryParamInt(LParams[2], 'p', LPar) then
    Exit;

  Result := (LMem < AProfile.MemoryKiB)
         or (LTime < AProfile.TimeCost)
         or (LPar < AProfile.Parallelism);
end;

end.
