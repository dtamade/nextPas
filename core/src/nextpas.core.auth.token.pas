unit nextpas.core.auth.token;
{**
 * @desc 不透明令牌原语（auth 家族，批次 6）：会话令牌 / API key /
 *       CSRF 等场景的 CSPRNG 生成、严格解码与常量时间比较。
 *       算法零实现——底座复用 crypto.random（CSPRNG）、
 *       encoding.base64（Base64Url 无填充）、crypto.constant_time（比较）。
 *       契约见 docs/auth/CONTRACT.md §3：
 *       - 熵地板 128 位（16 字节）：低于下限的调用属编程错误，
 *         EArgumentError fail-fast（NIST SP 800-133 / OWASP 会话令牌下限）；
 *       - 字符集 [A-Za-z0-9_-]，无 '=' 填充（URL/cookie/header 安全）；
 *       - 存储摘要（如 API key 的 SHA-256 hex）由应用组合 hash.sha256，
 *         本单元不重复提供。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

const
  { 默认熵：32 字节 = 256 位。 }
  AUTH_TOKEN_DEFAULT_BYTES = 32;
  { 熵地板：16 字节 = 128 位。 }
  AUTH_TOKEN_MIN_BYTES = 16;

{ 生成 base64url 无填充令牌：AEntropyBytes 个 CSPRNG 字节 →
  ceil(AEntropyBytes*4/3) 个字符（16→22 / 32→43 / 48→64）。
  AEntropyBytes < AUTH_TOKEN_MIN_BYTES 抛 EArgumentError；
  CSPRNG 环境故障抛 ECryptoRandomError（透传 crypto.random）。 }
function NewAuthToken(AEntropyBytes: Integer = AUTH_TOKEN_DEFAULT_BYTES): string;

{ 严格 base64url 解码：非法字符 / 非法长度 / 非法或非规范填充返回 False
  不抛；空串合法（空字节）。填充仅在总长为 4 的倍数时接受
  （core 解码器 ValidatePadding 同规则）。结构与尾量子规范位先行校验，
  通过后才委托 core 解码器产字节——数据态走 False，不走异常控制流。 }
function TryDecodeAuthToken(const AToken: string; out ADest: TBytes): Boolean;

{ 令牌实际熵位数 = 解码后字节数 ×8；畸形输入返回 -1（文档化哨兵）。 }
function AuthTokenEntropyBits(const AToken: string): Integer;

{ 常量时间比较（防时序旁路）：内容相等才 True；耗时只随长度变化。
  仅长度差异可被观测——长度本身不属机密（令牌定长部署）。 }
function AuthTokensEqual(const A, B: string): Boolean;

implementation

uses
  nextpas.core.exception,
  nextpas.core.crypto.random,
  nextpas.core.crypto.constant_time,
  nextpas.core.encoding.base64;

function NewAuthToken(AEntropyBytes: Integer): string;
begin
  if AEntropyBytes < AUTH_TOKEN_MIN_BYTES then
    raise EArgumentError.Create('token entropy below 128-bit floor');
  Result := Base64UrlEncode(GenerateSecureRandomBytes(AEntropyBytes));
end;

{ base64url 字符 → 6 位值；非法字符 -1。 }
function B64UrlVal(C: Char): Integer;
begin
  case C of
    'A'..'Z': Result := Ord(C) - Ord('A');
    'a'..'z': Result := Ord(C) - Ord('a') + 26;
    '0'..'9': Result := Ord(C) - Ord('0') + 52;
    '-':      Result := 62;
    '_':      Result := 63;
  else
    Result := -1;
  end;
end;

function TryDecodeAuthToken(const AToken: string; out ADest: TBytes): Boolean;
var
  I, LLen, LPad, LBodyLen, LV: Integer;
begin
  Result := False;
  ADest := nil;

  LLen := Length(AToken);
  if LLen = 0 then
    Exit(True);                       { 空串合法（空字节）。 }

  if (LLen mod 4) = 1 then
    Exit;                             { 该长度恒不可解码。 }

  { 填充：只允许结尾 1-2 个 '='，且总长须为 4 的倍数
    （与 encoding.base64 ValidatePadding 规则一致）。 }
  LPad := 0;
  while (LPad < LLen) and (AToken[LLen - LPad] = '=') do
    Inc(LPad);
  if LPad > 2 then
    Exit;
  if (LPad > 0) and ((LLen mod 4) <> 0) then
    Exit;

  { 正文字符集：url 字母表（填充前）。 }
  LBodyLen := LLen - LPad;
  for I := 1 to LBodyLen do
    if B64UrlVal(AToken[I]) < 0 then
      Exit;

  { 尾量子规范位：余 2 时次字符低 4 位、余 3 时第三字符低 2 位必须为 0
    （非规范编码拒绝，防同文多形）。 }
  case LBodyLen mod 4 of
    2: begin
         LV := B64UrlVal(AToken[LBodyLen]);
         if (LV and %1111) <> 0 then
           Exit;
       end;
    3: begin
         LV := B64UrlVal(AToken[LBodyLen]);
         if (LV and %11) <> 0 then
           Exit;
       end;
  end;

  { 结构已证合法，core 解码器不再可能抛数据态错误。 }
  ADest := Base64UrlDecode(AToken);
  Result := True;
end;

function AuthTokenEntropyBits(const AToken: string): Integer;
var
  LDest: TBytes;
begin
  if not TryDecodeAuthToken(AToken, LDest) then
    Exit(-1);
  Result := Length(LDest) * 8;
end;

function AuthTokensEqual(const A, B: string): Boolean;
begin
  Result := TConstantTime.CompareStrings(A, B);
end;

end.
