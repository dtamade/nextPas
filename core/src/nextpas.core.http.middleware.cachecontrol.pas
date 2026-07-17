unit nextpas.core.http.middleware.cachecontrol;
{**
 * @desc Cache-Control response header middleware. Sets Cache-Control header
 *       on every response to control HTTP caching behavior.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.http.intf;

{** @desc Set Cache-Control header on every response with the given value.
   Example values: 'no-cache', 'max-age=3600', 'public, max-age=86400'. }
function CacheControlMiddleware(const AValue: string): IHttpMiddleware;

{** @desc Convenience: sets Cache-Control: no-cache, no-store, must-revalidate.
   Prevents all caching. Suitable for dynamic/sensitive responses. }
function NoCacheMiddleware: IHttpMiddleware;

{** @desc Convenience: sets Cache-Control: public, max-age=N.
   Allows caching for N seconds. }
function MaxAgeMiddleware(const ASeconds: Int64): IHttpMiddleware;

implementation

uses
  nextpas.core.errors,
  nextpas.core.http.base,
  nextpas.core.http.middleware,
  nextpas.core.text.conv;

function CacheControlMiddleware(const AValue: string): IHttpMiddleware;
var
  LValue: string;
begin
  LValue := AValue;
  Result := MiddlewareFunc(function(const ANext: IHttpHandler): IHttpHandler
  begin
    Result := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      ANext.ServeHTTP(AReq, AW);
      AW.GetHeaders.SetHeader('cache-control', LValue);
    end);
  end);
end;

function NoCacheMiddleware: IHttpMiddleware;
begin
  Result := CacheControlMiddleware('no-cache, no-store, must-revalidate');
end;

function MaxAgeMiddleware(const ASeconds: Int64): IHttpMiddleware;
begin
  if ASeconds < 0 then
    raise EHttpError.Create(hekArgument, 'max-age must not be negative');
  Result := CacheControlMiddleware('public, max-age=' + IntToStr(ASeconds));
end;

end.
