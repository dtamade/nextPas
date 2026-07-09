unit nextpas.core.http.middleware.requestid;
{**
 * @desc Request ID middleware. Ensures every request/response has a unique
 *       X-Request-Id header for distributed tracing and debugging.
 *       Preserves existing X-Request-Id from proxies/clients.
 *       Generates a new UUID v4 if not present.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.http.intf;

type
  {** Callback type for custom request ID generation.
     Called when no existing request ID is found in headers. }
  TRequestIdGenerator = reference to function: string;

{** @desc Create middleware that ensures X-Request-Id header on every response.
   Preserves existing request header, generates UUID v4 if missing. }
function RequestIdMiddleware: IHttpMiddleware;

{** @desc Create middleware with custom header name (default: 'x-request-id'). }
function RequestIdMiddlewareWith(const AHeaderName: string): IHttpMiddleware;

{** @desc Create middleware with custom header name and ID generator.
   AGenerator is called when no existing request ID is found. }
function RequestIdMiddlewareWithGenerator(const AHeaderName: string;
  const AGenerator: TRequestIdGenerator): IHttpMiddleware;

implementation

uses
  nextpas.core.platform.random,
  nextpas.core.http.middleware;

const
  HEX_CHARS: array[0..15] of Char = '0123456789abcdef';

function GenerateRequestId: string;
var
  LBytes: array[0..15] of Byte;
  I: Integer;
begin
  platform_random_bytes(@LBytes[0], 16);
  { Set UUID v4 version (4) and variant (10xx) bits }
  LBytes[6] := (LBytes[6] and $0F) or $40;
  LBytes[8] := (LBytes[8] and $3F) or $80;
  SetLength(Result, 36);
  for I := 0 to 3 do
  begin
    Result[I * 2 + 1] := HEX_CHARS[(LBytes[I] shr 4) and $F];
    Result[I * 2 + 2] := HEX_CHARS[LBytes[I] and $F];
  end;
  Result[9] := '-';
  for I := 4 to 5 do
  begin
    Result[I * 2 + 2] := HEX_CHARS[(LBytes[I] shr 4) and $F];
    Result[I * 2 + 3] := HEX_CHARS[LBytes[I] and $F];
  end;
  Result[14] := '-';
  for I := 6 to 7 do
  begin
    Result[I * 2 + 3] := HEX_CHARS[(LBytes[I] shr 4) and $F];
    Result[I * 2 + 4] := HEX_CHARS[LBytes[I] and $F];
  end;
  Result[19] := '-';
  for I := 8 to 9 do
  begin
    Result[I * 2 + 4] := HEX_CHARS[(LBytes[I] shr 4) and $F];
    Result[I * 2 + 5] := HEX_CHARS[LBytes[I] and $F];
  end;
  Result[24] := '-';
  for I := 10 to 15 do
  begin
    Result[I * 2 + 5] := HEX_CHARS[(LBytes[I] shr 4) and $F];
    Result[I * 2 + 6] := HEX_CHARS[LBytes[I] and $F];
  end;
end;

function RequestIdMiddleware: IHttpMiddleware;
begin
  Result := RequestIdMiddlewareWith('x-request-id');
end;

function RequestIdMiddlewareWith(const AHeaderName: string): IHttpMiddleware;
begin
  Result := RequestIdMiddlewareWithGenerator(AHeaderName, function: string
  begin
    Result := GenerateRequestId;
  end);
end;

function RequestIdMiddlewareWithGenerator(const AHeaderName: string;
  const AGenerator: TRequestIdGenerator): IHttpMiddleware;
var
  LHeader: string;
  LGen: TRequestIdGenerator;
begin
  LHeader := AHeaderName;
  if LHeader = '' then
    LHeader := 'x-request-id';
  LGen := AGenerator;

  Result := MiddlewareFunc(function(const ANext: IHttpHandler): IHttpHandler
  begin
    Result := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    var
      LRequestId: string;
    begin
      LRequestId := AReq.GetHeaders.Get(LHeader);
      if LRequestId = '' then
        LRequestId := LGen();
      AW.GetHeaders.SetHeader(LHeader, LRequestId);
      ANext.ServeHTTP(AReq, AW);
    end);
  end);
end;

end.
