program bench_headers;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.bench,
  nextpas.core.http.intf,
  nextpas.core.http.headers;

var
  B: TBenchRunner;
  GSink: string;

procedure BenchSetGet_5Headers(aIters: Int64);
var
  LIt: Int64;
  LH: IHttpHeaders;
begin
  for LIt := 1 to aIters do
  begin
    LH := NewHttpHeaders;
    LH.Set_('content-type', 'text/html');
    LH.Set_('content-length', '1024');
    LH.Set_('server', 'nextpas');
    LH.Set_('date', 'Sat, 31 May 2026 12:00:00 GMT');
    LH.Set_('connection', 'keep-alive');
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
      LH.Set_(NAMES[LI], 'value');
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
  LH.Set_('content-type', 'text/html');
  LH.Set_('content-length', '1024');
  LH.Set_('server', 'nextpas');
  for LIt := 1 to aIters do
    GSink := LH.Get('x-nonexistent');
end;

procedure BenchGet_Hit(aIters: Int64);
var
  LIt: Int64;
  LH: IHttpHeaders;
begin
  LH := NewHttpHeaders;
  LH.Set_('content-type', 'text/html');
  LH.Set_('content-length', '1024');
  LH.Set_('server', 'nextpas');
  LH.Set_('date', 'Sat, 31 May 2026');
  LH.Set_('connection', 'keep-alive');
  for LIt := 1 to aIters do
    GSink := LH.Get('connection');
end;

procedure BenchHas(aIters: Int64);
var
  LIt: Int64;
  LH: IHttpHeaders;
  LB: Boolean;
begin
  LH := NewHttpHeaders;
  LH.Set_('content-type', 'text/html');
  LH.Set_('content-length', '1024');
  LH.Set_('server', 'nextpas');
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
    LH.Set_('header-' + Chr(Ord('a') + LI), 'value');
  for LIt := 1 to aIters do
    LClone := LH.Clone;
  GSink := LClone.Get('header-a');
end;

begin
  B := TBenchRunner.Create;
  WriteLn('=== nextpas.core.http.headers benchmark ===');
  WriteLn;
  B.Run('Set+Get 5 headers', @BenchSetGet_5Headers);
  B.Run('Set+Get 15 headers', @BenchSetGet_15Headers);
  B.Run('Add 15 headers', @BenchAdd_15Headers);
  B.Run('Get miss (3 headers)', @BenchGet_Miss);
  B.Run('Get hit (5 headers, last)', @BenchGet_Hit);
  B.Run('Has (3 headers)', @BenchHas);
  B.Run('Clone 10 headers', @BenchClone_10Headers);
  WriteLn;
  B.Summary;
  B.Free;
end.
