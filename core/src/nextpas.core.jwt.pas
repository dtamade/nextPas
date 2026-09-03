unit nextpas.core.jwt;
{**
 * @desc JWT (RFC 7519)：HS256 签发/验证 + claims 提取（B5 反哺首片）。
 *       三段 base64url 无 padding；alg 白名单严格 HS256（防 alg confusion）；
 *       签名常量时间比较（防时序侧信道）；exp/nbf 时钟由调用方注入
 *       （ANowSeconds，可测性 + core 时钟注入惯例）。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.exception;

type
  { 验证失败分类：调用方按 code 决定 HTTP 映射（401/403）与日志粒度。 }
  TJwtErrorCode = (
    jeMalformed,     { 段数 != 2 个 '.' / base64url 非法 / 空段 }
    jeBadHeader,     { header 非 JSON 对象 / alg 缺失或非 HS256 / typ 存在但非 JWT }
    jeBadPayload,    { payload 非 JSON 对象 }
    jeBadSignature,  { 签名不匹配（常量时间比较） }
    jeExpired,       { exp 存在且 now >= exp（RFC 7519 §4.1.4） }
    jeNotYetValid,   { nbf 存在且 now < nbf }
    jeBadIssuer,     { iss 与调用方期望不符 }
    jeBadAudience    { aud 缺失或与调用方期望不符 }
  );

  EJwtError = class(ENextPasError)
  private
    FCode: TJwtErrorCode;
  public
    constructor Create(const ACode: TJwtErrorCode; const AMessage: string); reintroduce;
    property Code: TJwtErrorCode read FCode;
  end;

  { 常用 claims 快照。数值 claim 0 = 无此 claim；PayloadJson 保留原始
    紧凑 JSON 供自定义 claim 访问。 }
  TJwtClaims = record
    Subject: string;      { sub }
    Issuer: string;       { iss }
    Audience: string;     { aud：string 形态取原值；array 形态取首元素 }
    ExpiresAt: Int64;     { exp，epoch 秒 }
    NotBefore: Int64;     { nbf，epoch 秒 }
    IssuedAt: Int64;      { iat，epoch 秒 }
    JwtId: string;        { jti }
    PayloadJson: string;  { 原始 payload 紧凑 JSON }
  end;

{ HS256 签发：APayloadJson 为紧凑 JSON **对象**字符串（非对象抛
  EArgumentError；自定义 claims 经 core.json 构造后传入）。
  返回 header.payload.signature。ASecret 为空抛 EArgumentError。 }
function JwtSignHS256(const APayloadJson, ASecret: string): string;

{ —— 易用层 —— }

type
  { Try 风格验证结果：业务侧免 try/except。Ok=False 时 Code/Reason 给失败因
    （Reason 复用异常消息，可直接进日志）；Ok=True 时 Claims 有效。 }
  TJwtVerifyOutcome = record
    Ok: Boolean;
    Code: TJwtErrorCode;
    Reason: string;
    Claims: TJwtClaims;
  end;

{ 结构化 claims → payload 紧凑 JSON。空字符串字段与 <=0 的时间字段不写入
  （payload 最小化，不泄露未设置项）。 }
function BuildClaimsPayload(const AClaims: TJwtClaims): string;

{ 一行签发：结构化 claims 直接出 token（= BuildClaimsPayload + JwtSignHS256，
  payload 合法性由构造保证）。ASecret 为空抛 EArgumentError。 }
function JwtSignHS256Claims(const AClaims: TJwtClaims; const ASecret: string): string;

{ 会话 claims 速造：sub/iss/aud + iat=ANowSeconds、exp=ANow+ATtl、
  jti = 安全随机 16 字节 hex（随机源不可用时留空，调用方可自填）。
  ATtlSeconds <= 0 抛 EArgumentError。 }
function JwtSessionClaims(const ASubject, AIssuer, AAudience: string;
  const ANowSeconds, ATtlSeconds: Int64): TJwtClaims;

{ 免 now 验证：内部取 core.time UTC 当前 Unix 秒。测试/回放等需要确定性
  时钟的场景仍用显式 ANowSeconds 版本 JwtVerifyHS256。 }
function JwtVerifyHS256Now(const AToken, ASecret: string;
  const AIssuer: string = ''; const AAudience: string = ''): TJwtClaims;

{ Try 风格验证：语义同 JwtVerifyHS256 但失败不抛异常，AOutcome.Code/Reason
  给失败因。编程错误（ASecret 为空）仍抛 EArgumentError——不掩盖调用方 bug。 }
function TryJwtVerifyHS256(const AToken, ASecret: string; const ANowSeconds: Int64;
  out AOutcome: TJwtVerifyOutcome;
  const AIssuer: string = ''; const AAudience: string = ''): Boolean;

{ 验证 + 解析：格式 → header(alg 白名单) → 签名(常量时间) → exp/nbf →
  可选 iss/aud（AIssuer/AAudience 非空才校验；aud 数组形态任一匹配即通过）。
  ANowSeconds 由调用方注入。失败 raise EJwtError。 }
function JwtVerifyHS256(const AToken, ASecret: string; const ANowSeconds: Int64;
  const AIssuer: string = ''; const AAudience: string = ''): TJwtClaims;

{ 仅解析不验签、不校验时间窗（inspect 用途）。失败 raise EJwtError。 }
function JwtDecode(const AToken: string): TJwtClaims;

implementation

uses
  nextpas.core.json.value,
  nextpas.core.bytes.ops,
  nextpas.core.crypto.hmac,
  nextpas.core.crypto.random,
  nextpas.core.encoding,
  nextpas.core.json.builder,
  nextpas.core.json,
  nextpas.core.json.value,
  nextpas.core.time;

constructor EJwtError.Create(const ACode: TJwtErrorCode; const AMessage: string);
begin
  inherited Create(AMessage);
  FCode := ACode;
end;

procedure RaiseJwt(const ACode: TJwtErrorCode; const AMsg: string);
begin
  raise EJwtError.Create(ACode, AMsg);
end;

{ 常量时间 TBytes 比较：迭代 max 长度、越界位取 0、长度差并入同一累积值，
  不因首个差异提前退出（语义对齐 tls.secure.SecureCompare；局部实现避免
  auth→tls 依赖链拖入 fs/classes/logging 整栈）。 }
function FixedTimeEquals(const A, B: TBytes): Boolean;
var
  I, LMax, LDiff: Integer;
  BA, BB: Byte;
begin
  LMax := Length(A);
  if Length(B) > LMax then
    LMax := Length(B);
  LDiff := Length(A) xor Length(B);
  for I := 0 to LMax - 1 do
  begin
    if I < Length(A) then BA := A[I] else BA := 0;
    if I < Length(B) then BB := B[I] else BB := 0;
    LDiff := LDiff or (BA xor BB);
  end;
  Result := LDiff = 0;
end;

{ 拆三段并 base64url 解码 header/payload；ASigningInput 为原始
  "header.payload" 前缀（验签输入，保留 base64 形态）。
  全串必须恰含 2 个 '.' 且三段均非空（base64url 字符集不含 '.'，
  因此「恰 2 个点」等价于「恰好 3 段」）。失败 raise jeMalformed。 }
procedure SplitToken(const AToken: string; out AHeaderJson, APayloadJson,
  ASigningInput, ASignatureB64: string);
var
  LI, LDots, PDot1, PDot2: Integer;
begin
  LDots := 0;
  PDot1 := 0;
  PDot2 := 0;
  for LI := 1 to Length(AToken) do
    if AToken[LI] = '.' then
    begin
      Inc(LDots);
      if LDots = 1 then PDot1 := LI else PDot2 := LI;
    end;
  if LDots <> 2 then
    RaiseJwt(jeMalformed, 'jwt: expected header.payload.signature');

  AHeaderJson := Copy(AToken, 1, PDot1 - 1);
  APayloadJson := Copy(AToken, PDot1 + 1, PDot2 - PDot1 - 1);
  ASignatureB64 := Copy(AToken, PDot2 + 1, Length(AToken) - PDot2);
  ASigningInput := Copy(AToken, 1, PDot2 - 1);
  if (AHeaderJson = '') or (APayloadJson = '') or (ASignatureB64 = '') then
    RaiseJwt(jeMalformed, 'jwt: empty segment');

  try
    AHeaderJson := BytesToString(Base64UrlDecode(AHeaderJson));
    APayloadJson := BytesToString(Base64UrlDecode(APayloadJson));
  except
    on E: EConvertError do
      RaiseJwt(jeMalformed, 'jwt: invalid base64url segment');
  end;
end;

{ 提取常用 claims。ARoot 为已解析的 payload 根对象（ADoc 保活其内存）。 }
procedure ExtractClaims(const ARoot: TJsonValue; out AClaims: TJwtClaims);
var
  LV: TJsonValue;
  LI: UInt32;
begin
  AClaims := Default(TJwtClaims);

  LV := ARoot.Get('sub');
  if LV.IsStr then
    AClaims.Subject := LV.AsStr.ToString;

  LV := ARoot.Get('iss');
  if LV.IsStr then
    AClaims.Issuer := LV.AsStr.ToString;

  { aud：string 或 array of string（RFC 7519 §4.1.3）；数组取首元素快照 }
  LV := ARoot.Get('aud');
  if LV.IsStr then
    AClaims.Audience := LV.AsStr.ToString
  else if LV.IsArray and (LV.ArrayLen > 0) then
    for LI := 0 to LV.ArrayLen - 1 do
      if LV.ArrayGet(LI).IsStr then
      begin
        AClaims.Audience := LV.ArrayGet(LI).AsStr.ToString;
        Break;
      end;

  { NumericDate 允许带小数秒（RFC 7519 §2）；AsInt 截断到秒 }
  LV := ARoot.Get('exp');
  if LV.IsInt or LV.IsFloat then
    AClaims.ExpiresAt := LV.AsInt;
  LV := ARoot.Get('nbf');
  if LV.IsInt or LV.IsFloat then
    AClaims.NotBefore := LV.AsInt;
  LV := ARoot.Get('iat');
  if LV.IsInt or LV.IsFloat then
    AClaims.IssuedAt := LV.AsInt;

  LV := ARoot.Get('jti');
  if LV.IsStr then
    AClaims.JwtId := LV.AsStr.ToString;
end;

{ aud 完整校验：string 相等或数组任一元素相等。AAudience 非空才进入。 }
procedure CheckAudience(const ARoot: TJsonValue; const AAudience: string);
var
  LV: TJsonValue;
  LI: UInt32;
begin
  if AAudience = '' then
    Exit;
  LV := ARoot.Get('aud');
  if LV.IsStr then
  begin
    if LV.AsStr.ToString = AAudience then
      Exit;
    RaiseJwt(jeBadAudience, 'jwt: audience mismatch');
  end;
  if LV.IsArray then
  begin
    for LI := 0 to LV.ArrayLen - 1 do
      if LV.ArrayGet(LI).IsStr and (LV.ArrayGet(LI).AsStr.ToString = AAudience) then
        Exit;
    RaiseJwt(jeBadAudience, 'jwt: audience mismatch');
  end;
  RaiseJwt(jeBadAudience, 'jwt: audience missing');
end;

function ParsePayload(const APayloadJson: string; out ARoot: TJsonValue;
  out ADoc: IJsonDocument): TJwtClaims;
var
  LDoc: IJsonDocument;
begin
  LDoc := JsonParse(APayloadJson);
  if (LDoc = nil) or LDoc.HasError or (not LDoc.Root.IsObject) then
    RaiseJwt(jeBadPayload, 'jwt: payload is not a JSON object');
  ARoot := LDoc.Root;
  ADoc := LDoc; { 保活：TJsonValue 引用文档内存，接口出作用域即释放 }
  ExtractClaims(ARoot, Result);
end;

function JwtSignHS256(const APayloadJson, ASecret: string): string;
var
  LDoc: IJsonDocument;
  LHeader, LSigningInput: string;
  LMac: TBytes;
begin
  if ASecret = '' then
    raise EArgumentError.Create('jwt: empty secret');
  LDoc := JsonParse(APayloadJson);
  if (LDoc = nil) or LDoc.HasError or (not LDoc.Root.IsObject) then
    raise EArgumentError.Create('jwt: payload must be a JSON object');

  LHeader := '{"alg":"HS256","typ":"JWT"}';
  LSigningInput :=
    Base64UrlEncode(StringToBytes(LHeader)) + '.' +
    Base64UrlEncode(StringToBytes(APayloadJson));
  LMac := HMAC_SHA256(StringToBytes(ASecret), StringToBytes(LSigningInput));
  Result := LSigningInput + '.' + Base64UrlEncode(LMac);
end;

{ —— 易用层 —— }

function BuildClaimsPayload(const AClaims: TJwtClaims): string;
var
  B: IJsonBuilder;
begin
  B := JsonBuilder;
  B.BeginObject;
  if AClaims.Subject <> '' then
  begin
    B.Key('sub');
    B.Str(AClaims.Subject);
  end;
  if AClaims.Issuer <> '' then
  begin
    B.Key('iss');
    B.Str(AClaims.Issuer);
  end;
  if AClaims.Audience <> '' then
  begin
    B.Key('aud');
    B.Str(AClaims.Audience);
  end;
  if AClaims.ExpiresAt > 0 then
  begin
    B.Key('exp');
    B.Int(AClaims.ExpiresAt);
  end;
  if AClaims.NotBefore > 0 then
  begin
    B.Key('nbf');
    B.Int(AClaims.NotBefore);
  end;
  if AClaims.IssuedAt > 0 then
  begin
    B.Key('iat');
    B.Int(AClaims.IssuedAt);
  end;
  if AClaims.JwtId <> '' then
  begin
    B.Key('jti');
    B.Str(AClaims.JwtId);
  end;
  B.EndObject;
  Result := B.ToString;
end;

function JwtSignHS256Claims(const AClaims: TJwtClaims; const ASecret: string): string;
begin
  Result := JwtSignHS256(BuildClaimsPayload(AClaims), ASecret);
end;

function JwtSessionClaims(const ASubject, AIssuer, AAudience: string;
  const ANowSeconds, ATtlSeconds: Int64): TJwtClaims;
var
  LRand: TBytes;
begin
  { now <= 0 静默通过会造出 1970 年即过期的 token（exp=now+ttl），
    错误延迟到验证期才暴露——构造期 fail-fast }
  if (ANowSeconds <= 0) or (ATtlSeconds <= 0) then
    raise EArgumentError.Create('jwt: now and ttl must be positive');
  Result := Default(TJwtClaims);
  Result.Subject := ASubject;
  Result.Issuer := AIssuer;
  Result.Audience := AAudience;
  Result.IssuedAt := ANowSeconds;
  Result.ExpiresAt := ANowSeconds + ATtlSeconds;
  LRand := GenerateSecureRandomBytes(16);
  if Length(LRand) = 16 then
    Result.JwtId := HexEncode(LRand)
  else
    Result.JwtId := ''; { 随机源不可用时留空，调用方可自填 }
end;

function JwtVerifyHS256Now(const AToken, ASecret: string;
  const AIssuer: string = ''; const AAudience: string = ''): TJwtClaims;
begin
  Result := JwtVerifyHS256(AToken, ASecret,
    DateTimeToUnix(DateTimeUtcNow), AIssuer, AAudience);
end;

function TryJwtVerifyHS256(const AToken, ASecret: string; const ANowSeconds: Int64;
  out AOutcome: TJwtVerifyOutcome;
  const AIssuer: string = ''; const AAudience: string = ''): Boolean;
begin
  AOutcome := Default(TJwtVerifyOutcome);
  try
    AOutcome.Claims := JwtVerifyHS256(AToken, ASecret, ANowSeconds, AIssuer, AAudience);
    AOutcome.Ok := True;
  except
    on E: EJwtError do
    begin
      AOutcome.Code := E.Code;
      AOutcome.Reason := E.Message;
    end;
    on E: EArgumentError do
      raise; { 编程错误（空密钥）不吞——不掩盖调用方 bug }
    on E: Exception do
    begin
      AOutcome.Code := jeMalformed;
      AOutcome.Reason := E.Message;
    end;
  end;
  Result := AOutcome.Ok;
end;

function JwtDecode(const AToken: string): TJwtClaims;
var
  LHeaderJson, LPayloadJson, LSigningInput, LSigB64: string;
  LRoot: TJsonValue;
  LDoc: IJsonDocument;
begin
  SplitToken(AToken, LHeaderJson, LPayloadJson, LSigningInput, LSigB64);
  Result := ParsePayload(LPayloadJson, LRoot, LDoc);
  Result.PayloadJson := LPayloadJson;
end;

function JwtVerifyHS256(const AToken, ASecret: string; const ANowSeconds: Int64;
  const AIssuer: string = ''; const AAudience: string = ''): TJwtClaims;
var
  LHeaderJson, LPayloadJson, LSigningInput, LSigB64: string;
  LRoot: TJsonValue;
  LDoc, LHeaderDoc: IJsonDocument;
  LAlg, LTyp: TJsonValue;
  LExpected, LGiven: TBytes;
begin
  if ASecret = '' then
    raise EArgumentError.Create('jwt: empty secret');

  SplitToken(AToken, LHeaderJson, LPayloadJson, LSigningInput, LSigB64);

  { header：alg 必须严格等于 HS256（拒绝 none/其他算法 —— alg confusion 防线）；
    typ 存在时须为 JWT（RFC 7515 §4.1.2 建议大小写敏感） }
  LHeaderDoc := JsonParse(LHeaderJson);
  if (LHeaderDoc = nil) or LHeaderDoc.HasError or (not LHeaderDoc.Root.IsObject) then
    RaiseJwt(jeBadHeader, 'jwt: header is not a JSON object');
  LAlg := LHeaderDoc.Root.Get('alg');
  if (not LAlg.IsStr) or (LAlg.AsStr.ToString <> 'HS256') then
    RaiseJwt(jeBadHeader, 'jwt: alg must be HS256');
  LTyp := LHeaderDoc.Root.Get('typ');
  if LTyp.IsStr and (LTyp.AsStr.ToString <> 'JWT') then
    RaiseJwt(jeBadHeader, 'jwt: typ must be JWT');

  { 签名：HMAC-SHA256(header.payload, secret)，常量时间比较 }
  LExpected := HMAC_SHA256(StringToBytes(ASecret), StringToBytes(LSigningInput));
  try
    LGiven := Base64UrlDecode(LSigB64);
  except
    on E: EConvertError do
      RaiseJwt(jeMalformed, 'jwt: invalid base64url signature segment');
  end;
  if not FixedTimeEquals(LExpected, LGiven) then
    RaiseJwt(jeBadSignature, 'jwt: signature mismatch');

  Result := ParsePayload(LPayloadJson, LRoot, LDoc);
  Result.PayloadJson := LPayloadJson;

  { 时间窗（RFC 7519 §4.1.4/§4.1.5）：now >= exp 过期；now < nbf 未生效 }
  if (Result.ExpiresAt > 0) and (ANowSeconds >= Result.ExpiresAt) then
    RaiseJwt(jeExpired, 'jwt: token expired');
  if (Result.NotBefore > 0) and (ANowSeconds < Result.NotBefore) then
    RaiseJwt(jeNotYetValid, 'jwt: token not yet valid');

  { 可选 iss/aud 校验 }
  if (AIssuer <> '') and (Result.Issuer <> AIssuer) then
    RaiseJwt(jeBadIssuer, 'jwt: issuer mismatch');
  CheckAudience(LRoot, AAudience);
end;

end.
