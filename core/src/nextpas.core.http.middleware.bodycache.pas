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
  { Wraps IHttpRequest, replacing Body with a cached TBytes buffer }
  TCachedBodyRequest = class(TInterfacedObject, IHttpRequest)
  private
    FInner: IHttpRequest;
    FCachedBody: TBytes;
    function GetMethod: THttpMethod;
    function GetUrl: TUrl;
    function GetPath: string;
    function GetRawQuery: string;
    function GetVersion: THttpVersion;
    function GetHeaders: IHttpHeaders;
    function GetTrailers: IHttpHeaders;
    function GetBody: IReader;
    function GetContentLength: Int64;
    function GetRemoteAddr: string;
    function PathParam(const AName: string): string;
    function QueryParam(const AName: string): string;
  public
    constructor Create(const AInner: IHttpRequest; const ACachedBody: TBytes);
  end;

constructor TCachedBodyRequest.Create(const AInner: IHttpRequest;
  const ACachedBody: TBytes);
begin
  inherited Create;
  FInner := AInner;
  FCachedBody := ACachedBody;
end;

function TCachedBodyRequest.GetMethod: THttpMethod;
begin
  Result := FInner.GetMethod;
end;

function TCachedBodyRequest.GetUrl: TUrl;
begin
  Result := FInner.GetUrl;
end;

function TCachedBodyRequest.GetPath: string;
begin
  Result := FInner.GetPath;
end;

function TCachedBodyRequest.GetRawQuery: string;
begin
  Result := FInner.GetRawQuery;
end;

function TCachedBodyRequest.GetVersion: THttpVersion;
begin
  Result := FInner.GetVersion;
end;

function TCachedBodyRequest.GetHeaders: IHttpHeaders;
begin
  Result := FInner.GetHeaders;
end;

function TCachedBodyRequest.GetTrailers: IHttpHeaders;
begin
  Result := FInner.GetTrailers;
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

function TCachedBodyRequest.GetContentLength: Int64;
begin
  Result := FInner.GetContentLength;
end;

function TCachedBodyRequest.GetRemoteAddr: string;
begin
  Result := FInner.GetRemoteAddr;
end;

function TCachedBodyRequest.PathParam(const AName: string): string;
begin
  Result := FInner.PathParam(AName);
end;

function TCachedBodyRequest.QueryParam(const AName: string): string;
begin
  Result := FInner.QueryParam(AName);
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
