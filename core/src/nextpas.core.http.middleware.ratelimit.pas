unit nextpas.core.http.middleware.ratelimit;
{**
 * @desc Rate limiting middleware. Tracks request counts per client IP
 *       within a sliding time window. Returns 429 Too Many Requests
 *       when the limit is exceeded.
 *
 *       Sets standard rate-limit headers on every response:
 *       - X-RateLimit-Limit: max requests per window
 *       - X-RateLimit-Remaining: remaining requests in current window
 *       - X-RateLimit-Reset: seconds until the window resets
 *
 *       Client IP is read from X-Forwarded-For (first entry) or X-Real-IP
 *       header, falling back to RemoteAddr.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.http.intf;

type
  TRateLimitOptions = record
    MaxRequests: Int32;
    WindowSeconds: Int32;
  end;

{** @desc Rate limit middleware with default 100 requests per 60 seconds. }
function RateLimitMiddleware: IHttpMiddleware;

{** @desc Rate limit middleware with custom options.
   AOptions.MaxRequests: max requests per window (must be > 0).
   AOptions.WindowSeconds: window duration in seconds (must be > 0). }
function RateLimitMiddlewareWith(const AOptions: TRateLimitOptions): IHttpMiddleware;

implementation

uses
  SysUtils,
  DateUtils,
  nextpas.core.errors,
  nextpas.core.http.base,
  nextpas.core.http.middleware,
  nextpas.core.http.message,
  nextpas.core.text.conv;

type
  TLimitEntry = record
    IP: string;
    Count: Int32;
    WindowStart: Int64;
  end;

var
  GEntries: array of TLimitEntry;
  GEntriesLock: TRTLCriticalSection;

function NowEpoch: Int64;
begin
  Result := Int64(DateTimeToUnix(Now));
end;

function ExtractClientIP(const AReq: IHttpRequest): string;
var
  LForwarded: string;
  LPos: SizeInt;
begin
  LForwarded := AReq.GetHeaders.Get('x-forwarded-for');
  if LForwarded <> '' then
  begin
    LPos := Pos(',', LForwarded);
    if LPos > 0 then
      Result := Trim(Copy(LForwarded, 1, LPos - 1))
    else
      Result := Trim(LForwarded);
    Exit;
  end;
  Result := AReq.GetHeaders.Get('x-real-ip');
  if Result <> '' then
    Exit;
  Result := AReq.GetRemoteAddr;
end;

function FindOrCreateEntry(const AIP: string; ANow: Int64;
  AWindowSec: Int32): Int32;
var
  LI: Int32;
  LLen: Int32;
begin
  LLen := Length(GEntries);
  for LI := 0 to LLen - 1 do
  begin
    if GEntries[LI].IP = AIP then
    begin
      if ANow - GEntries[LI].WindowStart >= Int64(AWindowSec) then
      begin
        GEntries[LI].Count := 0;
        GEntries[LI].WindowStart := ANow;
      end;
      Exit(LI);
    end;
  end;
  SetLength(GEntries, LLen + 1);
  GEntries[LLen].IP := AIP;
  GEntries[LLen].Count := 0;
  GEntries[LLen].WindowStart := ANow;
  Result := LLen;
end;

function RateLimitMiddleware: IHttpMiddleware;
var
  LOpts: TRateLimitOptions;
begin
  LOpts.MaxRequests := 100;
  LOpts.WindowSeconds := 60;
  Result := RateLimitMiddlewareWith(LOpts);
end;

function RateLimitMiddlewareWith(const AOptions: TRateLimitOptions): IHttpMiddleware;
var
  LMax: Int32;
  LWindow: Int32;
begin
  if AOptions.MaxRequests <= 0 then
    raise EArgumentError.Create('rate limit max requests must be positive');
  if AOptions.WindowSeconds <= 0 then
    raise EArgumentError.Create('rate limit window seconds must be positive');

  LMax := AOptions.MaxRequests;
  LWindow := AOptions.WindowSeconds;

  Result := MiddlewareFunc(function(const ANext: IHttpHandler): IHttpHandler
  begin
    Result := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    var
      LIP: string;
      LIdx: Int32;
      LNow: Int64;
      LRemaining: Int32;
      LReset: Int64;
    begin
      LIP := ExtractClientIP(AReq);
      LNow := NowEpoch;

      EnterCriticalSection(GEntriesLock);
      try
        LIdx := FindOrCreateEntry(LIP, LNow, LWindow);
        Inc(GEntries[LIdx].Count);
        LRemaining := LMax - GEntries[LIdx].Count;
        if LRemaining < 0 then
          LRemaining := 0;
        LReset := Int64(LWindow) - (LNow - GEntries[LIdx].WindowStart);
        if LReset < 0 then
          LReset := 0;

        AW.GetHeaders.SetHeader('x-ratelimit-limit', IntToStr(Int64(LMax)));
        AW.GetHeaders.SetHeader('x-ratelimit-remaining', IntToStr(Int64(LRemaining)));
        AW.GetHeaders.SetHeader('x-ratelimit-reset', IntToStr(LReset));

        if GEntries[LIdx].Count > LMax then
        begin
          HttpWriteErrorTooManyRequests(AW, 'Rate limit exceeded');
          Exit;
        end;
      finally
        LeaveCriticalSection(GEntriesLock);
      end;

      ANext.ServeHTTP(AReq, AW);
    end);
  end);
end;

initialization
  InitCriticalSection(GEntriesLock);

finalization
  DoneCriticalSection(GEntriesLock);

end.
