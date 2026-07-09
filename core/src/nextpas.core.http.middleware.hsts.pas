unit nextpas.core.http.middleware.hsts;
{**
 * @desc HTTP Strict Transport Security (HSTS) middleware.
 *       Adds the Strict-Transport-Security header to responses, instructing
 *       browsers to only use HTTPS for future requests to this domain.
 *
 *       RFC 6797: The HSTS header tells the browser to remember the host
 *       as HSTS-only for the specified max-age, and optionally to include
 *       subdomains.
 *
 *       Typically placed after CORS middleware and before other response
 *       header middleware.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.http.intf;

type
  THstsOptions = record
    MaxAge: Int64;
    IncludeSubDomains: Boolean;
    Preload: Boolean;
    class function Default: THstsOptions; static;
  end;

{** @desc Create HSTS middleware with default settings (1 year, includeSubDomains).
   Only adds the header for HTTPS requests. }
function HstsMiddleware: IHttpMiddleware;

{** @desc Create HSTS middleware with custom options.
   AOptions.MaxAge: seconds the browser should remember HSTS (default: 31536000 = 1 year).
   AOptions.IncludeSubDomains: apply to all subdomains (default: true).
   AOptions.Preload: eligible for browser HSTS preload lists (default: false). }
function HstsMiddlewareWith(const AOptions: THstsOptions): IHttpMiddleware;

implementation

uses
  nextpas.core.errors,
  nextpas.core.http.base,
  nextpas.core.http.middleware,
  nextpas.core.text.conv;

class function THstsOptions.Default: THstsOptions;
begin
  Result.MaxAge := 31536000; { 1 year }
  Result.IncludeSubDomains := True;
  Result.Preload := False;
end;

function BuildHstsHeader(const AOptions: THstsOptions): string;
begin
  Result := 'max-age=' + IntToStr(AOptions.MaxAge);
  if AOptions.IncludeSubDomains then
    Result := Result + '; includeSubDomains';
  if AOptions.Preload then
    Result := Result + '; preload';
end;

function HstsMiddleware: IHttpMiddleware;
begin
  Result := HstsMiddlewareWith(THstsOptions.Default);
end;

function HstsMiddlewareWith(const AOptions: THstsOptions): IHttpMiddleware;
var
  LHeader: string;
begin
  if AOptions.MaxAge < 0 then
    raise EArgumentError.Create('HSTS max-age must not be negative');
  LHeader := BuildHstsHeader(AOptions);

  Result := MiddlewareFunc(function(const ANext: IHttpHandler): IHttpHandler
  begin
    Result := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    var
      LScheme: string;
    begin
      { RFC 6797 §7.2: UA MUST ignore HSTS header received over HTTP.
        Check request scheme; also honor X-Forwarded-Proto for reverse proxies. }
      LScheme := AReq.Headers.Get('x-forwarded-proto');
      if LScheme = '' then
        LScheme := AReq.Url.Scheme;
      if LScheme = 'https' then
        AW.GetHeaders.SetHeader('strict-transport-security', LHeader);
      ANext.ServeHTTP(AReq, AW);
    end);
  end);
end;

end.
