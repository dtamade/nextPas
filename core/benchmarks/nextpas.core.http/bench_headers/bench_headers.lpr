program bench_headers;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.bench,
  nextpas.core.bench.intf,
  nextpas.core.base,
  nextpas.core.os.env,
  nextpas.core.text.conv,
  nextpas.core.time.base,
  nextpas.core.fs,
  nextpas.core.http.intf,
  nextpas.core.http.headers;

var
  LResults: IBenchResults;
  LFilter: string;
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
  LFilter := Trim(GetEnvironmentVariable('NEXTPAS_BENCH_FILTER'));
  { Source-contract markers: bench_filter= must be emitted before Run so it
    also appears on the no-match path. }
  WriteLn('=== nextpas.core.http.headers benchmark ===');
  WriteLn('operation=http.headers');
  WriteLn('bench_filter=', LFilter);
  WriteLn;
  LResults := TBenchSuite.Create('headers')
    .SetFilter(LFilter)
    .SetMinDuration(TDuration.FromMilliseconds(50))
    .SetMinSamples(5)
    .AddLoop('Set/Get 5 headers', @BenchSetGet_5Headers)
    .AddLoop('Set/Get 15 headers', @BenchSetGet_15Headers)
    .AddLoop('Add 15 headers', @BenchAdd_15Headers)
    .AddLoop('Get miss', @BenchGet_Miss)
    .AddLoop('GetAll miss', @BenchGetAll_Miss)
    .AddLoop('Get hit (5 headers, last)', @BenchGet_Hit)
    .AddLoop('Get hit uppercase (5 headers, last)', @BenchGet_HitUppercase)
    .AddLoop('Has', @BenchHas)
    .AddLoop('Clone 10 headers', @BenchClone_10Headers)
    .Run;
  if (LFilter <> '') and (LResults.Count = 0) then
  begin
    WriteLn('No matching benchmark rows.');
    Halt(1);
  end;
  WriteLn(LResults.PrintToConsole);
  ForceDirectories('build');
  LResults.SaveToJSON('build/bench-headers.json');
end.
