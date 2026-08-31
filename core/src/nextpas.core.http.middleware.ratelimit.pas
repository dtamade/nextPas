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
 *
 *       Each middleware instance maintains its own isolated rate-limit state,
 *       so different routes can have independent limits.
 *
 *       MaxKeys caps distinct tracked IPs (default 10000). When full, new
 *       keys are rejected with 429 (predictable; no LRU eviction).
 *       MaxKeys=0 means unlimited keys (tests/tools only).
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.http.intf;

type
  TRateLimitOptions = record
    MaxRequests: Int32;
    WindowSeconds: Int32;
    { If True, read client IP from X-Forwarded-For / X-Real-IP headers.
      Only enable when behind a trusted reverse proxy that sets these headers.
      Default: False (use RemoteAddr only). }
    TrustProxyHeaders: Boolean;
    { Max distinct client keys retained. Default 10000.
      0 = unlimited (tests/tools only). Negative rejected at construct. }
    MaxKeys: Int32;
  end;

{** @desc Rate limit middleware with default 100 requests per 60 seconds,
   MaxKeys=10000. }
function RateLimitMiddleware: IHttpMiddleware;

{** @desc Rate limit middleware with custom options.
   AOptions.MaxRequests: max requests per window (must be > 0).
   AOptions.WindowSeconds: window duration in seconds (must be > 0).
   AOptions.MaxKeys: max distinct IPs (0=unlimited tests-only; default 10000). }
function RateLimitMiddlewareWith(const AOptions: TRateLimitOptions): IHttpMiddleware;

implementation

uses
  nextpas.core.errors,
  nextpas.core.time.offsetdatetime,
  nextpas.core.http.base,
  nextpas.core.http.middleware,
  nextpas.core.http.message,
  nextpas.core.text.conv,
  nextpas.core.sync;

type
  TLimitEntry = record
    IP: string;
    Count: Int32;
    WindowStart: Int64;
  end;

  { Instance-scoped rate limit state. Each middleware call creates its own
    TRateLimitState, so different routes/servers have independent limits. }
  TRateLimitState = class
  private
    FEntries: array of TLimitEntry;
    FLock: IMutex;
    FCleanupCounter: Int32;
    FMaxRequests: Int32;
    FWindowSeconds: Int32;
    FMaxKeys: Int32;
    FTrustProxyHeaders: Boolean;
    procedure CleanupExpiredEntries(ANow: Int64);
    { Returns entry index, or -1 when a new key cannot be created (MaxKeys full). }
    function FindOrCreateEntry(const AIP: string; ANow: Int64): Int32;
  public
    constructor Create(const AOptions: TRateLimitOptions);
    destructor Destroy; override;
    function ProcessRequest(const AReq: IHttpRequest;
      const AW: IHttpResponseWriter): Boolean;
  end;

  { Class-based middleware that owns TRateLimitState and frees it on destruction.
    Prevents the state + critical section from leaking when the middleware
    is discarded (the old closure-capture pattern leaked both). }
  TRateLimitMiddleware = class(TInterfacedObject, IHttpMiddleware)
  private
    FState: TRateLimitState;
  public
    constructor Create(const AOptions: TRateLimitOptions);
    destructor Destroy; override;
    function Wrap(const ANext: IHttpHandler): IHttpHandler;
  end;

const
  CLEANUP_INTERVAL = 64;
  DEFAULT_MAX_KEYS = 10000;

function NowEpoch: Int64;
begin
  Result := TOffsetDateTime.NowUtc.ToUnixSeconds;
end;

{ TRateLimitState }

constructor TRateLimitState.Create(const AOptions: TRateLimitOptions);
begin
  inherited Create;
  FMaxRequests := AOptions.MaxRequests;
  FWindowSeconds := AOptions.WindowSeconds;
  FTrustProxyHeaders := AOptions.TrustProxyHeaders;
  FMaxKeys := AOptions.MaxKeys; { 0 = unlimited keys (tests/tools) }
  FCleanupCounter := 0;
  FLock := Mutex;
end;

destructor TRateLimitState.Destroy;
begin
  FLock := nil;
  inherited Destroy;
end;

procedure TRateLimitState.CleanupExpiredEntries(ANow: Int64);
var
  LI, LWrite, LLen: Int32;
begin
  LLen := Length(FEntries);
  LWrite := 0;
  for LI := 0 to LLen - 1 do
  begin
    if ANow - FEntries[LI].WindowStart < Int64(FWindowSeconds) then
    begin
      if LWrite <> LI then
        FEntries[LWrite] := FEntries[LI];
      Inc(LWrite);
    end;
  end;
  if LWrite < LLen then
    SetLength(FEntries, LWrite);
end;

function TRateLimitState.FindOrCreateEntry(const AIP: string;
  ANow: Int64): Int32;
var
  LI: Int32;
  LLen: Int32;
begin
  LLen := Length(FEntries);
  for LI := 0 to LLen - 1 do
  begin
    if FEntries[LI].IP = AIP then
    begin
      if ANow - FEntries[LI].WindowStart >= Int64(FWindowSeconds) then
      begin
        FEntries[LI].Count := 0;
        FEntries[LI].WindowStart := ANow;
      end;
      Exit(LI);
    end;
  end;

  if (FMaxKeys > 0) and (LLen >= FMaxKeys) then
  begin
    CleanupExpiredEntries(ANow);
    LLen := Length(FEntries);
    if LLen >= FMaxKeys then
      Exit(-1);
  end;

  SetLength(FEntries, LLen + 1);
  FEntries[LLen].IP := AIP;
  FEntries[LLen].Count := 0;
  FEntries[LLen].WindowStart := ANow;
  Result := LLen;
end;

function ExtractClientIP(const AReq: IHttpRequest;
  ATrustProxyHeaders: Boolean): string;
var
  LForwarded: string;
  LPos: SizeInt;
begin
  if ATrustProxyHeaders then
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
  end;
  { Fallback to the peer address without the port: RemoteAddr renders
    'ip:port', which would make every connection's ephemeral port a
    distinct key and the limiter never trigger. }
  Result := AReq.GetRemoteIp;
end;

{ Returns True if request is allowed, False if rate-limited (429 already written). }
function TRateLimitState.ProcessRequest(const AReq: IHttpRequest;
  const AW: IHttpResponseWriter): Boolean;
var
  LIP: string;
  LIdx: Int32;
  LNow: Int64;
  LRemaining: Int32;
  LReset: Int64;
begin
  Result := True;
  LIP := ExtractClientIP(AReq, FTrustProxyHeaders);
  LNow := NowEpoch;

  FLock.Acquire;
  try
    LIdx := FindOrCreateEntry(LIP, LNow);
    if LIdx < 0 then
    begin
      { Distinct-key capacity exhausted: reject new IP without allocating. }
      AW.GetHeaders.SetHeader('x-ratelimit-limit', IntToStr(Int64(FMaxRequests)));
      AW.GetHeaders.SetHeader('x-ratelimit-remaining', '0');
      AW.GetHeaders.SetHeader('x-ratelimit-reset', IntToStr(Int64(FWindowSeconds)));
      AW.GetHeaders.SetHeader('retry-after', IntToStr(Int64(FWindowSeconds)));
      HttpWriteErrorTooManyRequests(AW, 'Rate limit key capacity exceeded');
      Result := False;
    end
    else
    begin
      Inc(FEntries[LIdx].Count);
      LRemaining := FMaxRequests - FEntries[LIdx].Count;
      if LRemaining < 0 then
        LRemaining := 0;
      LReset := Int64(FWindowSeconds) - (LNow - FEntries[LIdx].WindowStart);
      if LReset < 0 then
        LReset := 0;

      AW.GetHeaders.SetHeader('x-ratelimit-limit', IntToStr(Int64(FMaxRequests)));
      AW.GetHeaders.SetHeader('x-ratelimit-remaining', IntToStr(Int64(LRemaining)));
      AW.GetHeaders.SetHeader('x-ratelimit-reset', IntToStr(LReset));

      if FEntries[LIdx].Count > FMaxRequests then
      begin
        AW.GetHeaders.SetHeader('retry-after', IntToStr(LReset));
        HttpWriteErrorTooManyRequests(AW, 'Rate limit exceeded');
        Result := False;
      end;
    end;

    { Periodic cleanup: after we're done using LIdx, evict expired entries
      to prevent unbounded memory growth. }
    Inc(FCleanupCounter);
    if FCleanupCounter >= CLEANUP_INTERVAL then
    begin
      FCleanupCounter := 0;
      CleanupExpiredEntries(LNow);
    end;
  finally
    FLock.Release;
  end;
end;

function RateLimitMiddleware: IHttpMiddleware;
var
  LOpts: TRateLimitOptions;
begin
  LOpts := Default(TRateLimitOptions);
  LOpts.MaxRequests := 100;
  LOpts.WindowSeconds := 60;
  LOpts.TrustProxyHeaders := False;
  LOpts.MaxKeys := DEFAULT_MAX_KEYS;
  Result := RateLimitMiddlewareWith(LOpts);
end;

function RateLimitMiddlewareWith(const AOptions: TRateLimitOptions): IHttpMiddleware;
begin
  if AOptions.MaxRequests <= 0 then
    raise EHttpError.Create(hekArgument, 'rate limit max requests must be positive');
  if AOptions.WindowSeconds <= 0 then
    raise EHttpError.Create(hekArgument, 'rate limit window seconds must be positive');
  if AOptions.MaxKeys < 0 then
    raise EHttpError.Create(hekArgument, 'rate limit max keys must be >= 0');
  Result := TRateLimitMiddleware.Create(AOptions);
end;

{ TRateLimitMiddleware }

constructor TRateLimitMiddleware.Create(const AOptions: TRateLimitOptions);
begin
  inherited Create;
  FState := TRateLimitState.Create(AOptions);
end;

destructor TRateLimitMiddleware.Destroy;
begin
  FState.Free;
  inherited Destroy;
end;

function TRateLimitMiddleware.Wrap(const ANext: IHttpHandler): IHttpHandler;
begin
  Result := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    if FState.ProcessRequest(AReq, AW) then
      ANext.ServeHTTP(AReq, AW);
  end);
end;

end.