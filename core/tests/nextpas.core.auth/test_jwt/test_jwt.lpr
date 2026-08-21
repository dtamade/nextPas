program test_jwt;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.test,
  nextpas.core.errors,
  nextpas.core.exception,
  nextpas.core.encoding.base64,
  nextpas.core.json,
  nextpas.core.time,
  nextpas.core.jwt;

var
  T: TTestSuite;

const
  { jwt.io 调试器默认示例（HS256 生态互操作向量，python3 hmac 独立复算核对）：
    header {"alg":"HS256","typ":"JWT"} / payload {"sub":"1234567890","name":"John Doe","iat":1516239022} }
  KNOWN_TOKEN =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9' + '.' +
    'eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ' + '.' +
    'SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c';
  KNOWN_SECRET = 'your-256-bit-secret';

{ 无 RTL 依赖的整数→十进制（对齐 test_http_router 先例） }
function IntToStr(const V: Int32): string;
begin
  Str(V, Result);
end;

function BytesOf(const AValue: string): TBytes;
begin
  if Length(AValue) = 0 then
    Exit(nil);
  SetLength(Result, Length(AValue));
  Move(PAnsiChar(AValue)^, Result[0], Length(AValue));
end;

function Base64UrlOf(const AValue: string): string;
begin
  Result := Base64UrlEncode(BytesOf(AValue));
end;

procedure TestSignRoundTrip;
var
  LToken: string;
  LClaims: TJwtClaims;
begin
  LToken := JwtSignHS256(
    '{"sub":"user-1","iss":"gw","aud":"api","exp":1000,"nbf":10,"iat":10,"jti":"id-7"}',
    'secret');
  LClaims := JwtVerifyHS256(LToken, 'secret', 500);
  CheckEqual('user-1', LClaims.Subject, 'sub');
  CheckEqual('gw', LClaims.Issuer, 'iss');
  CheckEqual('api', LClaims.Audience, 'aud');
  CheckEqual(Int64(1000), LClaims.ExpiresAt, 'exp');
  CheckEqual(Int64(10), LClaims.NotBefore, 'nbf');
  CheckEqual(Int64(10), LClaims.IssuedAt, 'iat');
  CheckEqual('id-7', LClaims.JwtId, 'jti');
end;

procedure TestKnownVector;
var
  LClaims: TJwtClaims;
begin
  LClaims := JwtVerifyHS256(KNOWN_TOKEN, KNOWN_SECRET, 0);
  CheckEqual('1234567890', LClaims.Subject, 'sub from known vector');
  CheckEqual(Int64(1516239022), LClaims.IssuedAt, 'iat from known vector');
  Check(Pos('"name":"John Doe"', LClaims.PayloadJson) > 0, 'custom claim in payload json');
end;

procedure TestWrongSecretRejected;
var
  LOk: Boolean;
begin
  LOk := False;
  try
    JwtVerifyHS256(KNOWN_TOKEN, 'wrong-secret', 0);
  except
    on E: EJwtError do LOk := E.Code = jeBadSignature;
    on E: Exception do LOk := False;
  end;
  Check(LOk, 'wrong secret -> jeBadSignature');
end;

procedure TestTamperedPayloadRejected;
var
  LP1, LP2: Integer;
  LTampered: string;
  LOk: Boolean;
begin
  { 把 payload 段换成 sub=...1234567891 的另一段，签名不再匹配 }
  LP1 := Pos('.', KNOWN_TOKEN);
  LP2 := Pos('.', Copy(KNOWN_TOKEN, LP1 + 1, MaxInt)) + LP1;
  LTampered := Copy(KNOWN_TOKEN, 1, LP1) + 'eyJzdWIiOiIxMjM0NTY3ODkxIn0' +
    Copy(KNOWN_TOKEN, LP2, MaxInt);
  LOk := False;
  try
    JwtVerifyHS256(LTampered, KNOWN_SECRET, 0);
  except
    on E: EJwtError do LOk := E.Code = jeBadSignature;
    on E: Exception do LOk := False;
  end;
  Check(LOk, 'tampered payload -> jeBadSignature');
end;

procedure TestExpiredBoundary;
var
  LToken: string;
  LOk: Boolean;
begin
  LToken := JwtSignHS256('{"exp":1000}', 's');
  { RFC 7519 §4.1.4：now >= exp 即过期（含相等边界） }
  LOk := False;
  try
    JwtVerifyHS256(LToken, 's', 1000);
  except
    on E: EJwtError do LOk := E.Code = jeExpired;
    on E: Exception do LOk := False;
  end;
  Check(LOk, 'exp == now -> expired');

  LOk := False;
  try
    JwtVerifyHS256(LToken, 's', 1001);
  except
    on E: EJwtError do LOk := E.Code = jeExpired;
    on E: Exception do LOk := False;
  end;
  Check(LOk, 'exp < now -> expired');

  JwtVerifyHS256(LToken, 's', 999); { now < exp 通过 }
end;

procedure TestNotYetValidBoundary;
var
  LToken: string;
  LOk: Boolean;
begin
  LToken := JwtSignHS256('{"nbf":100}', 's');
  LOk := False;
  try
    JwtVerifyHS256(LToken, 's', 99);
  except
    on E: EJwtError do LOk := E.Code = jeNotYetValid;
    on E: Exception do LOk := False;
  end;
  Check(LOk, 'now < nbf -> not yet valid');
  { nbf == now 生效（RFC 7519 §4.1.5：now >= nbf 即生效） }
  JwtVerifyHS256(LToken, 's', 100);
end;

procedure TestNoTimeClaimsPassAtAnyNow;
var
  LToken: string;
begin
  LToken := JwtSignHS256('{"sub":"x"}', 's');
  JwtVerifyHS256(LToken, 's', 0);
  JwtVerifyHS256(LToken, 's', 9999999999);
end;

procedure TestAlgNoneRejected;
var
  LToken: string;
  LOk: Boolean;
begin
  { 签名段给合法占位（空段会先触发 malformed；alg 白名单在验签前，占位即可到 header 校验） }
  LToken := Base64UrlOf('{"alg":"none","typ":"JWT"}') + '.' +
    Base64UrlOf('{"sub":"x"}') + '.' + Base64UrlOf('aa');
  LOk := False;
  try
    JwtVerifyHS256(LToken, 's', 0);
  except
    on E: EJwtError do LOk := E.Code = jeBadHeader;
    on E: Exception do LOk := False;
  end;
  Check(LOk, 'alg none -> jeBadHeader');
end;

procedure TestAlgMismatchRejected;
var
  LToken: string;
  LOk: Boolean;
begin
  { HS384 header 拼任意签名段 —— alg 白名单必须先拒 }
  LToken := Base64UrlOf('{"alg":"HS384","typ":"JWT"}') + '.' +
    Base64UrlOf('{"sub":"x"}') + '.' + Base64UrlOf('aa');
  LOk := False;
  try
    JwtVerifyHS256(LToken, 's', 0);
  except
    on E: EJwtError do LOk := E.Code = jeBadHeader;
    on E: Exception do LOk := False;
  end;
  Check(LOk, 'alg HS384 -> jeBadHeader');
end;

procedure TestMalformedTokens;
var
  LOk: Boolean;
  LI, LDot: Integer;
begin
  LOk := False;
  try
    JwtVerifyHS256('aaa.bbb', 's', 0);
  except
    on E: EJwtError do LOk := E.Code = jeMalformed;
    on E: Exception do LOk := False;
  end;
  Check(LOk, 'two segments -> malformed');

  LOk := False;
  try
    JwtVerifyHS256('a.b.c.d', 's', 0);
  except
    on E: EJwtError do LOk := E.Code = jeMalformed;
    on E: Exception do LOk := False;
  end;
  Check(LOk, 'four segments -> malformed');

  LOk := False;
  try
    JwtVerifyHS256('.payload.sig', 's', 0);
  except
    on E: EJwtError do LOk := E.Code = jeMalformed;
    on E: Exception do LOk := False;
  end;
  Check(LOk, 'empty header -> malformed');

  LOk := False;
  try
    JwtVerifyHS256(KNOWN_TOKEN + '!', KNOWN_SECRET, 0);
  except
    on E: EJwtError do LOk := E.Code = jeMalformed;
    on E: Exception do LOk := False;
  end;
  Check(LOk, 'trailing garbage in signature -> malformed');

  { 合法 base64 但签名不匹配：翻签名段首字符（S→T，完整 quantum 内；
    注意末字符处于 mod-4 余 3 组的丢弃位——core 严格拒绝非 canonical
    编码，翻它会得 jeMalformed 而非签名不匹配） }
    LDot := 0;
    for LI := Length(KNOWN_TOKEN) downto 1 do
      if KNOWN_TOKEN[LI] = '.' then
      begin
        LDot := LI;
        Break;
      end;
  LOk := False;
  try
    JwtVerifyHS256(Copy(KNOWN_TOKEN, 1, LDot) + 'T' +
      Copy(KNOWN_TOKEN, LDot + 2, MaxInt), KNOWN_SECRET, 0);
  except
    on E: EJwtError do LOk := E.Code = jeBadSignature;
    on E: Exception do LOk := False;
  end;
  Check(LOk, 'flipped signature char -> bad signature');
end;

procedure TestNonObjectPayloadRejected;
var
  LToken: string;
  LOk: Boolean;
begin
  { 验签先于 payload 解析（安全顺序：不信任未验签内容）——verify 路径上
    伪造 payload 只会得到 jeBadSignature；非对象 payload 的结构拒绝
    在 JwtDecode（inspect）路径可达 }
  LToken := Base64UrlOf('{"alg":"HS256","typ":"JWT"}') + '.' +
    Base64UrlOf('[1,2]') + '.' + Base64UrlOf('aa');
  LOk := False;
  try
    JwtVerifyHS256(LToken, 's', 0);
  except
    on E: EJwtError do LOk := E.Code = jeBadSignature;
    on E: Exception do LOk := False;
  end;
  Check(LOk, 'forged payload on verify path -> jeBadSignature');

  LOk := False;
  try
    JwtDecode(LToken);
  except
    on E: EJwtError do LOk := E.Code = jeBadPayload;
    on E: Exception do LOk := False;
  end;
  Check(LOk, 'array payload on decode path -> jeBadPayload');

  LOk := False;
  try
    JwtDecode(Base64UrlOf('{"alg":"HS256","typ":"JWT"}') + '.' +
      Base64UrlOf('42') + '.' + Base64UrlOf('aa'));
  except
    on E: EJwtError do LOk := E.Code = jeBadPayload;
    on E: Exception do LOk := False;
  end;
  Check(LOk, 'scalar payload on decode path -> jeBadPayload');
end;

procedure TestIssuerCheck;
var
  LToken: string;
  LOk: Boolean;
begin
  LToken := JwtSignHS256('{"iss":"gateway-a"}', 's');
  JwtVerifyHS256(LToken, 's', 0, 'gateway-a');
  LOk := False;
  try
    JwtVerifyHS256(LToken, 's', 0, 'gateway-b');
  except
    on E: EJwtError do LOk := E.Code = jeBadIssuer;
    on E: Exception do LOk := False;
  end;
  Check(LOk, 'issuer mismatch -> jeBadIssuer');
end;

procedure TestAudienceString;
var
  LToken: string;
  LOk: Boolean;
begin
  LToken := JwtSignHS256('{"aud":"api"}', 's');
  JwtVerifyHS256(LToken, 's', 0, '', 'api');
  LOk := False;
  try
    JwtVerifyHS256(LToken, 's', 0, '', 'other');
  except
    on E: EJwtError do LOk := E.Code = jeBadAudience;
    on E: Exception do LOk := False;
  end;
  Check(LOk, 'aud mismatch -> jeBadAudience');
end;

procedure TestAudienceArrayAnyMatch;
var
  LToken: string;
  LOk: Boolean;
begin
  LToken := JwtSignHS256('{"aud":["web","api"]}', 's');
  JwtVerifyHS256(LToken, 's', 0, '', 'web');
  JwtVerifyHS256(LToken, 's', 0, '', 'api');
  LOk := False;
  try
    JwtVerifyHS256(LToken, 's', 0, '', 'mobile');
  except
    on E: EJwtError do LOk := E.Code = jeBadAudience;
    on E: Exception do LOk := False;
  end;
  Check(LOk, 'aud array no match -> jeBadAudience');
  { 快照取首元素 }
  CheckEqual('web', JwtDecode(LToken).Audience, 'aud snapshot first element');
end;

procedure TestDecodeNoVerify;
var
  LClaims: TJwtClaims;
begin
  { inspect 语义：坏签名也解析 claims，不校验时间窗 }
  LClaims := JwtDecode(KNOWN_TOKEN);
  CheckEqual('1234567890', LClaims.Subject, 'decode sub');
  LClaims := JwtDecode(JwtSignHS256('{"exp":1}', 's'));
  CheckEqual(Int64(1), LClaims.ExpiresAt, 'decode exp without time check');
end;

procedure TestEmptySecretRaises;
var
  LOk: Boolean;
begin
  LOk := False;
  try
    JwtSignHS256('{}', '');
  except
    on E: EArgumentError do LOk := True;
    on E: Exception do LOk := False;
  end;
  Check(LOk, 'empty secret sign -> EArgumentError');

  LOk := False;
  try
    JwtVerifyHS256(KNOWN_TOKEN, '', 0);
  except
    on E: EArgumentError do LOk := True;
    on E: Exception do LOk := False;
  end;
  Check(LOk, 'empty secret verify -> EArgumentError');
end;

procedure TestSignNonObjectPayloadRaises;
var
  LOk: Boolean;
begin
  LOk := False;
  try
    JwtSignHS256('[1,2]', 's');
  except
    on E: EArgumentError do LOk := True;
    on E: Exception do LOk := False;
  end;
  Check(LOk, 'non-object payload sign -> EArgumentError');
end;

procedure TestFloatNumericDate;
var
  LToken: string;
  LClaims: TJwtClaims;
begin
  { NumericDate 允许小数秒（RFC 7519 §2）；截断到秒。now 取 exp-1 避开
    now >= exp 过期边界（截断后 1750000000） }
  LToken := JwtSignHS256('{"exp":1750000000.5}', 's');
  LClaims := JwtVerifyHS256(LToken, 's', 1749999999);
  CheckEqual(Int64(1750000000), LClaims.ExpiresAt, 'float numeric date truncated');
end;

{ —— 易用层 —— }

procedure TestBuildClaimsPayloadMinimal;
var
  LClaims: TJwtClaims;
  LPayload: string;
begin
  { 空字符串字段与 <=0 时间字段不写入（payload 最小化） }
  LClaims := Default(TJwtClaims);
  LClaims.Subject := 'u1';
  LPayload := BuildClaimsPayload(LClaims);
  Check(Pos('"sub":"u1"', LPayload) > 0, 'sub written');
  Check(Pos('iss', LPayload) = 0, 'empty iss omitted');
  Check(Pos('exp', LPayload) = 0, 'zero exp omitted');
  Check(Pos('{', LPayload) = 1, 'json object');
end;

procedure TestSignClaimsRoundTrip;
var
  LClaims, LBack: TJwtClaims;
  LToken: string;
begin
  LClaims := JwtSessionClaims('user-9', 'gw', 'api', 1000, 600);
  LToken := JwtSignHS256Claims(LClaims, 'secret');
  LBack := JwtVerifyHS256(LToken, 'secret', 1200);
  CheckEqual('user-9', LBack.Subject, 'sub');
  CheckEqual('gw', LBack.Issuer, 'iss');
  CheckEqual('api', LBack.Audience, 'aud');
  CheckEqual(Int64(1000), LBack.IssuedAt, 'iat');
  CheckEqual(Int64(1600), LBack.ExpiresAt, 'exp');
  CheckEqual(32, Length(LBack.JwtId), 'jti = 16-byte hex');
end;

procedure TestSessionClaimsTtlValidation;
var
  LOk: Boolean;

  procedure ExpectArgError(const ANow, ATtl: Int64; const AMsg: string);
  var
    LOkLocal: Boolean;
  begin
    LOkLocal := False;
    try
      JwtSessionClaims('u', '', '', ANow, ATtl);
    except
      on E: EArgumentError do LOkLocal := True;
      on E: Exception do LOkLocal := False;
    end;
    Check(LOkLocal, AMsg);
  end;

begin
  ExpectArgError(1000, 0, 'ttl = 0 -> EArgumentError');
  ExpectArgError(1000, -5, 'ttl < 0 -> EArgumentError');
  ExpectArgError(0, 60, 'now = 0 -> EArgumentError');
  ExpectArgError(-1, 60, 'now < 0 -> EArgumentError');
end;

procedure TestVerifyNow;
var
  LToken: string;
begin
  { 免 now 版本走真实时钟：60s TTL 会话 token 必然有效 }
  LToken := JwtSignHS256Claims(
    JwtSessionClaims('now-user', '', '', DateTimeToUnix(DateTimeUtcNow), 60), 's');
  CheckEqual('now-user', JwtVerifyHS256Now(LToken, 's').Subject, 'verify-now subject');
end;

procedure TestTryStyleOk;
var
  LOutcome: TJwtVerifyOutcome;
begin
  Check(TryJwtVerifyHS256(KNOWN_TOKEN, KNOWN_SECRET, 0, LOutcome),
    'try-style ok returns True');
  Check(LOutcome.Ok, 'outcome ok flag');
  CheckEqual('1234567890', LOutcome.Claims.Subject, 'try-style claims');
end;

procedure TestTryStyleExpiredNoRaise;
var
  LToken: string;
  LOutcome: TJwtVerifyOutcome;
  LOk: Boolean;
begin
  LToken := JwtSignHS256('{"exp":100}', 's');
  { 过期不抛异常：Ok=False + Code=jeExpired + Reason 可进日志 }
  LOk := True;
  try
    Check(not TryJwtVerifyHS256(LToken, 's', 200, LOutcome),
      'try-style expired returns False');
  except
    LOk := False;
  end;
  Check(LOk, 'try-style must not raise on expired');
  Check(LOutcome.Code = jeExpired, 'outcome code jeExpired');
  Check(Length(LOutcome.Reason) > 0, 'outcome reason for logs');
end;

procedure TestTryStyleEmptySecretReraises;
var
  LOutcome: TJwtVerifyOutcome;
  LOk: Boolean;
begin
  { 编程错误（空密钥）不被 Try 吞掉——fail-fast }
  LOk := False;
  try
    TryJwtVerifyHS256(KNOWN_TOKEN, '', 0, LOutcome);
  except
    on E: EArgumentError do LOk := True;
    on E: Exception do LOk := False;
  end;
  Check(LOk, 'empty secret re-raised even in try-style');
end;

begin
  T := TTestSuite.Create('nextpas.core.jwt');
  T.Test('Sign/verify round trip', @TestSignRoundTrip);
  T.Test('Known vector (jwt.io)', @TestKnownVector);
  T.Test('Wrong secret rejected', @TestWrongSecretRejected);
  T.Test('Tampered payload rejected', @TestTamperedPayloadRejected);
  T.Test('Expired boundary', @TestExpiredBoundary);
  T.Test('Not-yet-valid boundary', @TestNotYetValidBoundary);
  T.Test('No time claims pass at any now', @TestNoTimeClaimsPassAtAnyNow);
  T.Test('alg none rejected', @TestAlgNoneRejected);
  T.Test('alg mismatch rejected', @TestAlgMismatchRejected);
  T.Test('Malformed tokens', @TestMalformedTokens);
  T.Test('Non-object payload rejected', @TestNonObjectPayloadRejected);
  T.Test('Issuer check', @TestIssuerCheck);
  T.Test('Audience string check', @TestAudienceString);
  T.Test('Audience array any-match', @TestAudienceArrayAnyMatch);
  T.Test('Decode without verify', @TestDecodeNoVerify);
  T.Test('Empty secret raises', @TestEmptySecretRaises);
  T.Test('Sign non-object payload raises', @TestSignNonObjectPayloadRaises);
  T.Test('Float NumericDate truncated', @TestFloatNumericDate);
  T.Test('BuildClaimsPayload minimal', @TestBuildClaimsPayloadMinimal);
  T.Test('Sign claims round trip', @TestSignClaimsRoundTrip);
  T.Test('Session claims ttl validation', @TestSessionClaimsTtlValidation);
  T.Test('Verify now (real clock)', @TestVerifyNow);
  T.Test('Try-style ok', @TestTryStyleOk);
  T.Test('Try-style expired no raise', @TestTryStyleExpiredNoRaise);
  T.Test('Try-style empty secret re-raises', @TestTryStyleEmptySecretReraises);
  if not T.Run then Halt(1);
end.
