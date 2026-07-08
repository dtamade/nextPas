unit nextpas.core.http.middleware.metrics;
{**
 * @desc Metrics middleware. Collects basic HTTP request metrics:
 *       total request count, status code class counts, and total duration.
 *       Thread-safe via TRTLCriticalSection.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.http.intf;

type
  {** Callback for per-request metrics notifications.
     AStatus is the HTTP status code, ADurationUs is request duration in microseconds. }
  THttpMetricsCallback = reference to procedure(const AStatus: Int64; const ADurationUs: Int64);

  {** Snapshot of collected HTTP metrics. }
  THttpMetrics = record
    TotalRequests: Int64;
    Status2xx: Int64;
    Status3xx: Int64;
    Status4xx: Int64;
    Status5xx: Int64;
    TotalDurationUs: Int64;
  end;

  {** Thread-safe metrics collector. Pass to MetricsMiddleware, then read via Snapshot. }
  IHttpMetricsCollector = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']
    function Snapshot: THttpMetrics;
    procedure Reset;
    procedure RecordRequest(const AStatus: Int64; const ADurationUs: Int64);
  end;

{** @desc Create a new metrics collector. Thread-safe. }
function NewHttpMetricsCollector: IHttpMetricsCollector;

{** @desc Create metrics middleware that records request counts and durations.
   Thread-safe; share one collector across handlers. }
function MetricsMiddleware(const ACollector: IHttpMetricsCollector): IHttpMiddleware;

{** @desc Create metrics middleware that calls ACallback on every request with
   status code and duration in microseconds. No collector needed; useful for
   pushing metrics to external systems (StatsD, Prometheus, logs). }
function MetricsMiddlewareWith(const ACallback: THttpMetricsCallback): IHttpMiddleware;

implementation

uses
  SysUtils,
  nextpas.core.errors,
  nextpas.core.http.base,
  nextpas.core.http.middleware,
  nextpas.core.time.base;

type
  THttpMetricsCollector = class(TInterfacedObject, IHttpMetricsCollector)
  private
    FLock: TRTLCriticalSection;
    FMetrics: THttpMetrics;
  public
    constructor Create;
    destructor Destroy; override;
    function Snapshot: THttpMetrics;
    procedure Reset;
    procedure RecordRequest(const AStatus: Int64; const ADurationUs: Int64);
  end;

constructor THttpMetricsCollector.Create;
begin
  inherited Create;
  InitCriticalSection(FLock);
  FillChar(FMetrics, SizeOf(FMetrics), 0);
end;

destructor THttpMetricsCollector.Destroy;
begin
  DoneCriticalSection(FLock);
  inherited;
end;

function THttpMetricsCollector.Snapshot: THttpMetrics;
begin
  EnterCriticalSection(FLock);
  try
    Result := FMetrics;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

procedure THttpMetricsCollector.Reset;
begin
  EnterCriticalSection(FLock);
  try
    FillChar(FMetrics, SizeOf(FMetrics), 0);
  finally
    LeaveCriticalSection(FLock);
  end;
end;

procedure THttpMetricsCollector.RecordRequest(const AStatus: Int64; const ADurationUs: Int64);
begin
  EnterCriticalSection(FLock);
  try
    Inc(FMetrics.TotalRequests);
    Inc(FMetrics.TotalDurationUs, ADurationUs);
    if (AStatus >= 200) and (AStatus < 300) then
      Inc(FMetrics.Status2xx)
    else if (AStatus >= 300) and (AStatus < 400) then
      Inc(FMetrics.Status3xx)
    else if (AStatus >= 400) and (AStatus < 500) then
      Inc(FMetrics.Status4xx)
    else if (AStatus >= 500) and (AStatus < 600) then
      Inc(FMetrics.Status5xx);
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function NewHttpMetricsCollector: IHttpMetricsCollector;
begin
  Result := THttpMetricsCollector.Create;
end;

function MetricsMiddleware(const ACollector: IHttpMetricsCollector): IHttpMiddleware;
var
  LCollector: IHttpMetricsCollector;
begin
  if ACollector = nil then
    raise EArgumentError.Create('MetricsMiddleware collector must not be nil');
  LCollector := ACollector;

  Result := MiddlewareFunc(function(const ANext: IHttpHandler): IHttpHandler
  begin
    Result := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    var
      LStart: TInstant;
      LDuration: TDuration;
    begin
      LStart := TInstant.Now;
      ANext.ServeHTTP(AReq, AW);
      LDuration := LStart.Elapsed;
      LCollector.RecordRequest(Int64(AW.GetStatus), LDuration.AsMicroseconds);
    end);
  end);
end;

function MetricsMiddlewareWith(const ACallback: THttpMetricsCallback): IHttpMiddleware;
var
  LCallback: THttpMetricsCallback;
begin
  if not Assigned(ACallback) then
    raise EArgumentError.Create('MetricsMiddlewareWith callback must not be nil');
  LCallback := ACallback;

  Result := MiddlewareFunc(function(const ANext: IHttpHandler): IHttpHandler
  begin
    Result := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    var
      LStart: TInstant;
      LDuration: TDuration;
    begin
      LStart := TInstant.Now;
      ANext.ServeHTTP(AReq, AW);
      LDuration := LStart.Elapsed;
      LCallback(Int64(AW.GetStatus), LDuration.AsMicroseconds);
    end);
  end);
end;

end.
