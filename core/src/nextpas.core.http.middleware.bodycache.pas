unit nextpas.core.http.middleware.bodycache;
{**
 * @desc Body cache middleware. Reads the request body into memory and replaces
 *       it with a re-readable buffer. This allows downstream handlers and
 *       middleware to read the body multiple times (e.g., logging + validation
 *       + actual processing).
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.http.base,
  nextpas.core.http.intf;

{** @desc Create middleware that caches the request body for re-reading.
   The body is read into memory once; downstream handlers receive a request
   whose Body returns a fresh reader each time. }
function BodyCacheMiddleware: IHttpMiddleware;

implementation

uses
  nextpas.core.http.middleware,
  nextpas.core.http.message,
  nextpas.core.io.memory;

type
  { Wraps IHttpRequest, replacing Body with a cached TBytes buffer.
    Forwards context/options via THttpRequestWrapper. }
  TCachedBodyRequest = class(THttpRequestWrapper)
  private
    FCachedBody: TBytes;
  protected
    function GetBody: IReader; override;
  public
    constructor Create(const AInner: IHttpRequest; const ACachedBody: TBytes);
  end;

constructor TCachedBodyRequest.Create(const AInner: IHttpRequest;
  const ACachedBody: TBytes);
begin
  inherited Create(AInner);
  FCachedBody := ACachedBody;
end;

function TCachedBodyRequest.GetBody: IReader;
var
  LCopy: TBytes;
begin
  if FCachedBody = nil then
    Exit(nil);
  LCopy := Copy(FCachedBody, 0, Length(FCachedBody));
  Result := CreateBytesStreamFrom(LCopy) as IReader;
end;

function BodyCacheMiddleware: IHttpMiddleware;
begin
  Result := MiddlewareFunc(function(const ANext: IHttpHandler): IHttpHandler
  begin
    Result := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    var
      LCachedBody: TBytes;
      LCachedReq: IHttpRequest;
    begin
      LCachedBody := HttpReadRequestBodyBytes(AReq);
      LCachedReq := TCachedBodyRequest.Create(AReq, LCachedBody) as IHttpRequest;
      ANext.ServeHTTP(LCachedReq, AW);
    end);
  end);
end;

end.
