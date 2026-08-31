unit nextpas.core.oauth.pkce;
{**
 * @desc OAuth2 PKCE（RFC 7636 S256）+ state 防 CSRF（B5 第二片）。
 *       verifier 43-128 unreserved 字符；challenge = BASE64URL(SHA256(verifier))；
 *       state = 'nonce.expiry.sig'（HMAC-SHA256 常量时间比较，过期即拒）。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.errors;

const
  { RFC 7636 §4.1：verifier 长度 43..128，字符集 unreserved }
  OAUTH2_VERIFIER_MIN = 43;
  OAUTH2_VERIFIER_MAX = 128;

{ 生成 code_verifier：32 安全随机字节 → base64url（43 字符）。
  随机源不可用抛 ENextPasError 派生错误。 }
function GenerateCodeVerifier: string;

{ 校验 verifier：长度 43..128 且全部为 unreserved（A-Z a-z 0-9 - . _ ~）。 }
function IsValidCodeVerifier(const AVerifier: string): Boolean;

{ S256 challenge：BASE64URL(SHA256(ASCIIVerifier))。
  AVerifier 非法抛 EArgumentError（RFC 7636 §4.2 plain 已弃用，仅 S256）。 }
function CodeChallengeS256(const AVerifier: string): string;

{ 签发防 CSRF state：'nonce.expiry.sig'。nonce=16 安全随机字节 hex；
  expiry=ANowSeconds+ATtlSeconds（十进制）；sig=base64url(HMAC-SHA256(
  ASecret, nonce+'.'+expiry))。ASecret 为空或 ATtlSeconds<=0 抛
  EArgumentError。 }
function SignOAuthState(const ASecret: string;
  const ANowSeconds, ATtlSeconds: Int64): string;

{ 校验 state：格式/签名（常量时间）/未过期三关，任一失败返回 False
  （不抛异常——state 来自不可信的 redirect query）。 }
function VerifyOAuthState(const AState, ASecret: string;
  const ANowSeconds: Int64): Boolean;

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.crypto.hmac,
  nextpas.core.crypto.random,
  nextpas.core.encoding,
  nextpas.core.hash;

function BytesToString(const AB: TBytes): string;
begin
  if Length(AB) = 0 then
    Exit('');
  SetString(Result, PAnsiChar(@AB[0]), Length(AB));
end;

function IsUnreservedChar(const ACh: Char): Boolean; inline;
begin
  case ACh of
    'A'..'Z', 'a'..'z', '0'..'9', '-', '.', '_', '~':
      Result := True;
  else
    Result := False;
  end;
end;

function CountDots(const AValue: string): Integer;
var
  LI: Integer;
begin
  Result := 0;
  for LI := 1 to Length(AValue) do
    if AValue[LI] = '.' then
      Inc(Result);
end;

function IntToStrDec(const AValue: Int64): string;
begin
  Str(AValue, Result);
end;

{ 常量时间字符串比较（语义对齐 jwt.FixedTimeEquals；局部实现避免跨单元
  暴露内部辅助） }
function FixedTimeEqualsStr(const A, B: string): Boolean;
var
  LI, LMax, LDiff: Integer;
  BA, BB: Byte;
begin
  LMax := Length(A);
  if Length(B) > LMax then
    LMax := Length(B);
  LDiff := Length(A) xor Length(B);
  for LI := 1 to LMax do
  begin
    if LI <= Length(A) then BA := Ord(A[LI]) else BA := 0;
    if LI <= Length(B) then BB := Ord(B[LI]) else BB := 0;
    LDiff := LDiff or (BA xor BB);
  end;
  Result := LDiff = 0;
end;

function IsValidCodeVerifier(const AVerifier: string): Boolean;
var
  LI: Integer;
begin
  Result := False;
  if (Length(AVerifier) < OAUTH2_VERIFIER_MIN) or
     (Length(AVerifier) > OAUTH2_VERIFIER_MAX) then
    Exit;
  for LI := 1 to Length(AVerifier) do
    if not IsUnreservedChar(AVerifier[LI]) then
      Exit;
  Result := True;
end;

function GenerateCodeVerifier: string;
var
  LRand: TBytes;
begin
  LRand := GenerateSecureRandomBytes(32);
  if Length(LRand) <> 32 then
    raise ENextPasError.Create('oauth2: secure random source unavailable');
  { 32 字节 → base64url 无 padding 恰 43 字符，全 unreserved }
  Result := Base64UrlEncode(LRand);
end;

function CodeChallengeS256(const AVerifier: string): string;
var
  LHasher: IHasher;
begin
  if not IsValidCodeVerifier(AVerifier) then
    raise EArgumentError.Create('oauth2: invalid code_verifier');
  LHasher := NewSHA256;
  LHasher.Write(PAnsiChar(AVerifier)^, Length(AVerifier));
  Result := Base64UrlEncode(LHasher.SumBytes);
end;

function SignOAuthState(const ASecret: string;
  const ANowSeconds, ATtlSeconds: Int64): string;
var
  LRand: TBytes;
  LNonce, LPayload, LSig: string;
begin
  if ASecret = '' then
    raise EArgumentError.Create('oauth2: empty state secret');
  if ATtlSeconds <= 0 then
    raise EArgumentError.Create('oauth2: state ttl must be positive');
  LRand := GenerateSecureRandomBytes(16);
  if Length(LRand) <> 16 then
    raise ENextPasError.Create('oauth2: secure random source unavailable');
  LNonce := HexEncode(LRand);
  LPayload := LNonce + '.' + IntToStrDec(ANowSeconds + ATtlSeconds);
  LSig := Base64UrlEncode(HMAC_SHA256(StringToBytes(ASecret),
    StringToBytes(LPayload)));
  Result := LPayload + '.' + LSig;
end;

function VerifyOAuthState(const AState, ASecret: string;
  const ANowSeconds: Int64): Boolean;
var
  LDot1, LDot2, LDots, LI: Integer;
  LNonce, LExpiryStr, LSig, LPayload, LExpectedSig: string;
  LExpiry, LValue: Int64;
  LValid: Boolean;
begin
  Result := False;
  if (ASecret = '') or (AState = '') then
    Exit;

  { 单趟扫描：恰 2 个 '.' 三段结构，记录前两个点位置 }
  LDot1 := 0;
  LDot2 := 0;
  LDots := 0;
  for LI := 1 to Length(AState) do
    if AState[LI] = '.' then
    begin
      Inc(LDots);
      if LDots = 1 then LDot1 := LI
      else if LDots = 2 then LDot2 := LI;
    end;
  if LDots <> 2 then
    Exit;

  LNonce := Copy(AState, 1, LDot1 - 1);
  LExpiryStr := Copy(AState, LDot1 + 1, LDot2 - LDot1 - 1);
  LSig := Copy(AState, LDot2 + 1, Length(AState) - LDot2);
  if (LNonce = '') or (LExpiryStr = '') or (LSig = '') then
    Exit;

  { expiry 十进制全数字 → Int64（溢出/非法即拒） }
  LExpiry := 0;
  LValid := Length(LExpiryStr) > 0;
  for LI := 1 to Length(LExpiryStr) do
  begin
    LValue := Ord(LExpiryStr[LI]) - Ord('0');
    if (LValue < 0) or (LValue > 9) then
    begin
      LValid := False;
      Break;
    end;
    if LExpiry > (High(Int64) - LValue) div 10 then
    begin
      LValid := False;
      Break;
    end;
    LExpiry := LExpiry * 10 + LValue;
  end;
  if not LValid then
    Exit;

  { 过期先判（便宜），再常量时间验签 }
  if ANowSeconds >= LExpiry then
    Exit;

  LPayload := LNonce + '.' + LExpiryStr;
  LExpectedSig := Base64UrlEncode(HMAC_SHA256(StringToBytes(ASecret),
    StringToBytes(LPayload)));
  Result := FixedTimeEqualsStr(LSig, LExpectedSig);
end;

end.
