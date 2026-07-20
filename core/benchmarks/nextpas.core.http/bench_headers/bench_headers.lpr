program bench_headers;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.bench,
  nextpas.core.bench.intf,
  nextpas.core.time.base,
  nextpas.core.fs,
  nextpas.core.http.intf,
  nextpas.core.http.headers;

var
  LResults: IBenchResults;
  GSink: string;

procedure BenchSetGet_5Headers(aIters: Int64);
var
  LIt: Int64;
  LH: IHttpHeaders;
begin
  for LIt := 1 to aIters do
  begin
    LH := NewHttpHeaders;
    LH.SetHeader('content-type', 'text/html');
    LH.SetHeader('content-length', '1024');
    LH.SetHeader('server', 'nextpas');
    LH.SetHeader('date', 'Sat, 31 May 2026 12:00:00 GMT');
    LH.SetHeader('connection', 'keep-alive');
    GSink := LH.Get('content-type');
  end;
end;

procedure BenchSetGet_15Headers(aIters: Int64);
var
  LIt: Int64;
  LI: Int32;
  LH: IHttpHeaders;
const
  NAMES: array[0..14] of string = (
    'content-type', 'content-length', 'server', 'date', 'connection',
    'cache-control', 'etag', 'last-modified', 'accept-encoding',
    'x-request-id', 'x-forwarded-for', 'x-real-ip', 'vary',
    'access-control-allow-origin', 'strict-transport-security');
begin
  for LIt := 1 to aIters do
  begin
    LH := NewHttpHeaders;
    for LI := 0 to 14 do
      LH.SetHeader(NAMES[LI], 'value');
    GSink := LH.Get('x-request-id');
  end;
end;

procedure BenchAdd_15Headers(aIters: Int64);
var
  LIt: Int64;
  LI: Int32;
  LH: IHttpHeaders;
const
  NAMES: array[0..14] of string = (
    'content-type', 'content-length', 'server', 'date', 'connection',
    'cache-control', 'etag', 'last-modified', 'accept-encoding',
    'x-request-id', 'x-forwarded-for', 'x-real-ip', 'vary',
    'access-control-allow-origin', 'strict-transport-security');
begin
  for LIt := 1 to aIters do
  begin
    LH := NewHttpHeaders;
    for LI := 0 to 14 do
      LH.Add(NAMES[LI], 'value');
    GSink := LH.Get('x-request-id');
  end;
end;

procedure BenchGet_Miss(aIters: Int64);
var
  LIt: Int64;
  LH: IHttpHeaders;
begin
  LH := NewHttpHeaders;
  LH.SetHeader('content-type', 'text/html');
  LH.SetHeader('content-length', '1024');
  LH.SetHeader('server', 'nextpas');
  for LIt := 1 to aIters do
    GSink := LH.Get('x-nonexistent');
end;

procedure BenchGetAll_Miss(aIters: Int64);
var
  LIt: Int64;
  LH: IHttpHeaders;
  LAll: TStringArray;
begin
  LH := NewHttpHeaders;
  LH.SetHeader('content-type', 'text/html');
  LH.SetHeader('content-length', '1024');
  LH.SetHeader('server', 'nextpas');
  LH.SetHeader('date', 'Sat, 31 May 2026');
  LH.SetHeader('connection', 'keep-alive');
  for LIt := 1 to aIters do
    LAll := LH.GetAll('expect');
  if Length(LAll) > 0 then
    GSink := LAll[0];
end;

procedure BenchGet_Hit(aIters: Int64);
var
  LIt: Int64;
  LH: IHttpHeaders;
begin
  LH := NewHttpHeaders;
  LH.SetHeader('content-type', 'text/html');
  LH.SetHeader('content-length', '1024');
  LH.SetHeader('server', 'nextpas');
  LH.SetHeader('date', 'Sat, 31 May 2026');
  LH.SetHeader('connection', 'keep-alive');
  for LIt := 1 to aIters do
    GSink := LH.Get('connection');
end;

procedure BenchGet_HitUppercase(aIters: Int64);
var
  LIt: Int64;
  LH: IHttpHeaders;
begin
  LH := NewHttpHeaders;
  LH.SetHeader('content-type', 'text/html');
  LH.SetHeader('content-length', '1024');
  LH.SetHeader('server', 'nextpas');
  LH.SetHeader('date', 'Sat, 31 May 2026');
  LH.SetHeader('connection', 'keep-alive');
  for LIt := 1 to aIters do
    GSink := LH.Get('CONNECTION');
end;

procedure BenchHas(aIters: Int64);
var
  LIt: Int64;
  LH: IHttpHeaders;
  LB: Boolean;
begin
  LH := NewHttpHeaders;
  LH.SetHeader('content-type', 'text/html');
  LH.SetHeader('content-length', '1024');
  LH.SetHeader('server', 'nextpas');
  for LIt := 1 to aIters do
    LB := LH.Has('content-length');
  if LB then ;
end;

procedure BenchClone_10Headers(aIters: Int64);
var
  LIt: Int64;
  LH, LClone: IHttpHeaders;
  LI: Int32;
begin
  LH := NewHttpHeaders;
  for LI := 1 to 10 do
    LH.SetHeader('header-' + Chr(Ord('a') + LI), 'value');
  for LIt := 1 to aIters do
    LClone := LH.Clone;
  GSink := LClone.Get('header-a');
end;

begin
  WriteLn('=== nextpas.core.http.headers benchmark ===');
  WriteLn('operation=http.headers');
  WriteLn;
  LResults := TBenchSuite.Create('headers')
    .SetQuiet(True)
    .SetMinDuration(TDuration.FromMilliseconds(50))
    .SetMinSamples(5)
    .AddLoop('Headers/SetGet/5', @BenchSetGet_5Headers)
    .AddLoop('Headers/SetGet/15', @BenchSetGet_15Headers)
    .AddLoop('Headers/Add/15', @BenchAdd_15Headers)
    .AddLoop('Headers/Get/miss', @BenchGet_Miss)
    .AddLoop('Headers/GetAll/miss', @BenchGetAll_Miss)
    .AddLoop('Headers/Get/hit', @BenchGet_Hit)
    .AddLoop('Headers/Get/hitUpper', @BenchGet_HitUppercase)
    .AddLoop('Headers/Has', @BenchHas)
    .AddLoop('Headers/Clone/10', @BenchClone_10Headers)
    .Run;
  WriteLn(LResults.PrintToConsole);
  ForceDirectories('build');
  LResults.SaveToJSON('build/bench-headers.json');
end.
