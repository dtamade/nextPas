unit nextpas.core.http.middleware.bodycache;
{**
 * @desc Body cache middleware. Reads the request body into memory and replaces
 *       it with a re-readable buffer. This allows downstream handlers and
 *       middleware to read the body multiple times (e.g., logging + validation
 *       + actual processing).
 *
 *       Default max = HTTP_DEFAULT_BODY_READ_MAX (4 MiB). Exceeding the limit
 *       writes 413 and does not enter the next handler.
 *       BodyCacheMiddlewareWith(0) = unlimited (tests/tools only).
 *
 *       GetBody reuses the cached TBytes via dynarray refcount (read-only
 *       IReader per call); no per-read payload copy.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.http.base,
  nextpas.core.http.intf;

{** @desc Cache request body with HTTP_DEFAULT_BODY_READ_MAX. }
function BodyCacheMiddleware: IHttpMiddleware;

{** @desc Cache request body with explicit max.
   AMaxBytes <= 0 means unlimited (tests/tools only).
   Oversize → 413 Payload Too Large, next handler not called. }
function BodyCacheMiddlewareWith(const AMaxBytes: Int64): IHttpMiddleware;

{** @desc Cache request body with no size bound (tests/tools only).
   Prefer BodyCacheMiddleware / BodyCacheMiddlewareWith(positive) in production. }
function BodyCacheMiddlewareUnlimited: IHttpMiddleware;

implementation

uses
  nextpas.core.errors,
  nextpas.core.http.middleware,
  nextpas.core.http.message;

type
  { Read-only view over shared cached TBytes (dynarray refcount; no Copy). }
  TCachedBodyReader = class(TInterfacedObject, IReader)
  private
    FData: TBytes;
    FPos: SizeUInt;
  public
    constructor Create(const AData: TBytes);
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
  end;

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

constructor TCachedBodyReader.Create(const AData: TBytes);
begin
  inherited Create;
  FData := AData; { share dynarray }
  FPos := 0;
end;

function TCachedBodyReader.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
var
  LAvail: SizeUInt;
begin
  if (ACount = 0) or (FData = nil) then
    Exit(0);
  if FPos >= SizeUInt(Length(FData)) then
    Exit(0);
  LAvail := SizeUInt(Length(FData)) - FPos;
  if ACount < LAvail then
    Result := ACount
  else
    Result := LAvail;
  if Result > 0 then
  begin
    Move(FData[FPos], ABuf, Result);
    Inc(FPos, Result);
  end;
end;

constructor TCachedBodyRequest.Create(const AInner: IHttpRequest;
  const ACachedBody: TBytes);
begin
  inherited Create(AInner);
  FCachedBody := ACachedBody;
end;

function TCachedBodyRequest.GetBody: IReader;
begin
  if FCachedBody = nil then
    Exit(nil);
  Result := TCachedBodyReader.Create(FCachedBody);
end;

function BodyCacheMiddleware: IHttpMiddleware;
begin
  Result := BodyCacheMiddlewareWith(HTTP_DEFAULT_BODY_READ_MAX);
end;

function BodyCacheMiddlewareWith(const AMaxBytes: Int64): IHttpMiddleware;
begin
  Result := MiddlewareFunc(function(const ANext: IHttpHandler): IHttpHandler
  begin
    Result := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    var
      LCachedBody: TBytes;
      LCachedReq: IHttpRequest;
    begin
      try
        LCachedBody := HttpReadRequestBodyBytesMax(AReq, AMaxBytes);
      except
        on E: EHttpError do
        begin
          if (E.Kind = hekBody) and (E.Op = 'body') then
          begin
            HttpWriteErrorPayloadTooLarge(AW, 'Request body too large');
            Exit;
          end;
          raise;
        end;
      end;
      LCachedReq := TCachedBodyRequest.Create(AReq, LCachedBody) as IHttpRequest;
      ANext.ServeHTTP(LCachedReq, AW);
    end);
  end);
end;

function BodyCacheMiddlewareUnlimited: IHttpMiddleware;
begin
  Result := BodyCacheMiddlewareWith(0);
end;

end.