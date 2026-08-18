unit nextpas.core.http.middleware.csrf;

{**
 * @desc CSRF (cross-site request forgery) protection via the double-submit
 *       cookie pattern:
 *         - On any request without a CSRF cookie, a fresh token is issued
 *           as a (non-HttpOnly) cookie so same-origin scripts can read it.
 *         - Safe methods (GET/HEAD/OPTIONS) pass without further checks.
 *         - State-changing methods require the token in the configured
 *           header; it is compared against the cookie token with
 *           TConstantTime.CompareStrings (constant time on equal-length
 *           inputs), failing closed with 403.
 *
 *       Secure modes:
 *         - csmSecure   → cookie named '__Host-<name>' + Secure attribute
 *                         (requires Path=/ and no Domain — the middleware
 *                         always sets Path=/). Use behind TLS.
 *         - csmInsecure → plain cookie name, no Secure attribute (dev/TLS
 *                         termination elsewhere).
 *         - csmAuto     → like csmInsecure; the application decides the
 *                         effective mode from its TLS configuration
 *                         (e.g. CsrfCfg.SecureMode := csmSecure when TLS).
 *
 *       Usage:
 *         LOpts := TCsrfConfig.Default;
 *         LOpts.SecureMode := csmSecure;
 *         router.Use(CsrfMiddleware(LOpts));
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.crypto.constant_time,
  nextpas.core.encoding.hex,
  nextpas.core.http.base,
  nextpas.core.http.cookie,
  nextpas.core.http.intf,
  nextpas.core.http.message,
  nextpas.core.http.middleware;

type
  TCsrfSecureMode = (csmAuto, csmSecure, csmInsecure);

  TCsrfConfig = record
    { Cookie name. Default 'csrf' (or '__Host-csrf' in csmSecure). }
    CookieName: string;
    { Header carrying the token for state-changing requests. Default
      'X-CSRF-Token'. }
    HeaderName: string;
    { Random token length in bytes. Bounded to [16, 64]. Default 32. }
    TokenLength: Integer;
    SecureMode: TCsrfSecureMode;
    { Set-Cookie SameSite attribute. Default ssStrict. }
    CookieSameSite: TSameSite;
    class function Default: TCsrfConfig; static;
  end;

{** @desc CSRF middleware with explicit configuration. }
function CsrfMiddleware(const AConfig: TCsrfConfig): IHttpMiddleware;

implementation

uses
  nextpas.core.crypto.random;

const
  DEFAULT_TOKEN_LENGTH = 32;

class function TCsrfConfig.Default: TCsrfConfig;
begin
  Result.CookieName := 'csrf';
  Result.HeaderName := 'X-CSRF-Token';
  Result.TokenLength := DEFAULT_TOKEN_LENGTH;
  Result.SecureMode := csmAuto;
  Result.CookieSameSite := ssStrict;
end;

type
  TCsrfMiddleware = class(TInterfacedObject, IHttpMiddleware)
  private
    FConfig: TCsrfConfig;
    FEffectiveCookieName: string;
    FSecure: Boolean;
    function GenerateToken: string;
    function IsSafeMethod(AMethod: THttpMethod): Boolean;
    function CookieTokenOf(const AReq: IHttpRequest): string;
  public
    constructor Create(const AConfig: TCsrfConfig);
    function Wrap(const ANext: IHttpHandler): IHttpHandler;
    property EffectiveCookieName: string read FEffectiveCookieName;
  end;

constructor TCsrfMiddleware.Create(const AConfig: TCsrfConfig);
begin
  inherited Create;
  if (AConfig.TokenLength < 16) or (AConfig.TokenLength > 64) then
    raise EHttpError.Create(hekArgument,
      'TokenLength must be between 16 and 64');
  FConfig := AConfig;

  case FConfig.SecureMode of
    csmSecure: FSecure := True;
    csmInsecure: FSecure := False;
  else
    FSecure := False;
  end;

  if FSecure then
    FEffectiveCookieName := '__Host-' + FConfig.CookieName
  else
    FEffectiveCookieName := FConfig.CookieName;
end;

function TCsrfMiddleware.GenerateToken: string;
var
  Bytes: TBytes;
begin
  Bytes := GenerateSecureRandomBytes(FConfig.TokenLength);
  Result := HexEncode(Bytes);
end;

function TCsrfMiddleware.IsSafeMethod(AMethod: THttpMethod): Boolean;
begin
  Result := (AMethod = hmGet) or (AMethod = hmHead) or (AMethod = hmOptions);
end;

function TCsrfMiddleware.CookieTokenOf(const AReq: IHttpRequest): string;
begin
  Result := ParseCookies(AReq.Headers.Get('Cookie')).Get(FEffectiveCookieName);
end;

function TCsrfMiddleware.Wrap(const ANext: IHttpHandler): IHttpHandler;
begin
  Result := HandlerFunc(procedure(const AReq: IHttpRequest;
    const AW: IHttpResponseWriter)
  var
    CookieToken, HeaderToken, NewToken: string;
    Cookie: TSetCookie;
  begin
    CookieToken := CookieTokenOf(AReq);

    if CookieToken = '' then
    begin
      NewToken := GenerateToken;
      Cookie := MakeCookie(FEffectiveCookieName, NewToken)
        .WithPath('/')
        .WithHttpOnly(False)
        .WithSecure(FSecure)
        .WithSameSite(FConfig.CookieSameSite);
      AW.Headers.Add('Set-Cookie', BuildSetCookie(Cookie));
    end;

    if IsSafeMethod(AReq.Method) then
    begin
      ANext.ServeHTTP(AReq, AW);
      Exit;
    end;

    if CookieToken = '' then
    begin
      HttpWriteResponseString(AW, 403, 'text/plain', 'CSRF token missing');
      Exit;
    end;

    HeaderToken := AReq.Headers.Get(FConfig.HeaderName);
    if HeaderToken = '' then
      HeaderToken := AReq.Headers.Get('X-Csrf-Token');

    if (HeaderToken = '') or (Length(HeaderToken) <> Length(CookieToken)) or
       (not TConstantTime.CompareStrings(HeaderToken, CookieToken)) then
    begin
      HttpWriteResponseString(AW, 403, 'text/plain', 'CSRF token mismatch');
      Exit;
    end;

    ANext.ServeHTTP(AReq, AW);
  end);
end;

function CsrfMiddleware(const AConfig: TCsrfConfig): IHttpMiddleware;
begin
  Result := TCsrfMiddleware.Create(AConfig);
end;

end.
