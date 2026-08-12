program bench_router;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.bench,
  nextpas.core.base,
  nextpas.core.os.env,
  nextpas.core.text.conv,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.message,
  nextpas.core.http.router;

var
  LResults: IBenchResults;
  LFilter: string;
  GSink: string;
  GDispatchCount: Int64;

procedure BenchStaticRoute_5Routes(aIters: Int64);
var
  LIt: Int64;
  LR: THttpRouter;
  LParams: TRouteParams;
  LHandler: THttpHandlerFunc;
begin
  LR := THttpRouter.Create;
  LR.Get('/users', nil);
  LR.Get('/posts', nil);
  LR.Get('/comments', nil);
  LR.Get('/tags', nil);
  LR.Get('/health', nil);
  for LIt := 1 to aIters do
  begin
    LParams := nil;
    LHandler := LR.FindRoute(hmGet, '/health', LParams);
  end;
  if LHandler <> nil then
    Inc(GDispatchCount);
  LR.Free;
end;

procedure BenchStaticRoute_50Routes(aIters: Int64);
var
  LIt: Int64;
  LI: Int32;
  LR: THttpRouter;
  LParams: TRouteParams;
  LHandler: THttpHandlerFunc;
begin
  LR := THttpRouter.Create;
  for LI := 1 to 50 do
    LR.Get('/route' + Chr(Ord('a') + (LI mod 26)) + Chr(Ord('a') + (LI div 26)), nil);
  LR.Get('/target', nil);
  for LIt := 1 to aIters do
  begin
    LParams := nil;
    LHandler := LR.FindRoute(hmGet, '/target', LParams);
  end;
  if LHandler <> nil then
    Inc(GDispatchCount);
  LR.Free;
end;

procedure BenchParamRoute(aIters: Int64);
var
  LIt: Int64;
  LR: THttpRouter;
  LParams: TRouteParams;
  LHandler: THttpHandlerFunc;
begin
  LR := THttpRouter.Create;
  LR.Get('/users/:id', nil);
  for LIt := 1 to aIters do
  begin
    LParams := nil;
    LHandler := LR.FindRoute(hmGet, '/users/12345', LParams);
  end;
  if LHandler <> nil then
    Inc(GDispatchCount);
  if LParams <> nil then GSink := LParams[0].Value;
  LR.Free;
end;

procedure BenchMultiParam(aIters: Int64);
var
  LIt: Int64;
  LR: THttpRouter;
  LParams: TRouteParams;
  LHandler: THttpHandlerFunc;
begin
  LR := THttpRouter.Create;
  LR.Get('/users/:uid/posts/:pid/comments/:cid', nil);
  for LIt := 1 to aIters do
  begin
    LParams := nil;
    LHandler := LR.FindRoute(hmGet, '/users/42/posts/99/comments/7', LParams);
  end;
  if LHandler <> nil then
    Inc(GDispatchCount);
  LR.Free;
end;

procedure BenchWildcard(aIters: Int64);
var
  LIt: Int64;
  LR: THttpRouter;
  LParams: TRouteParams;
  LHandler: THttpHandlerFunc;
begin
  LR := THttpRouter.Create;
  LR.Get('/static/*filepath', nil);
  for LIt := 1 to aIters do
  begin
    LParams := nil;
    LHandler := LR.FindRoute(hmGet, '/static/css/app.min.css', LParams);
  end;
  if LHandler <> nil then
    Inc(GDispatchCount);
  LR.Free;
end;

procedure BenchDeepPath(aIters: Int64);
var
  LIt: Int64;
  LR: THttpRouter;
  LParams: TRouteParams;
  LHandler: THttpHandlerFunc;
begin
  LR := THttpRouter.Create;
  LR.Get('/api/v1/organizations/:org/projects/:proj/builds/:build/logs', nil);
  for LIt := 1 to aIters do
  begin
    LParams := nil;
    LHandler := LR.FindRoute(hmGet, '/api/v1/organizations/acme/projects/web/builds/123/logs', LParams);
  end;
  if LHandler <> nil then
    Inc(GDispatchCount);
  LR.Free;
end;

procedure BenchMiss(aIters: Int64);
var
  LIt: Int64;
  LR: THttpRouter;
  LParams: TRouteParams;
  LHandler: THttpHandlerFunc;
begin
  LR := THttpRouter.Create;
  LR.Get('/users', nil);
  LR.Get('/posts', nil);
  LR.Get('/health', nil);
  for LIt := 1 to aIters do
  begin
    LParams := nil;
    LHandler := LR.FindRoute(hmGet, '/nonexistent', LParams);
  end;
  if LHandler <> nil then
    Inc(GDispatchCount);
  LR.Free;
end;

procedure BenchHandlerDispatch(aIters: Int64);
var
  LIt: Int64;
  LR: THttpRouter;
  LReq: IHttpRequest;
begin
  LR := THttpRouter.Create;
  try
    LR.Get('/health',
      procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
      begin
        Inc(GDispatchCount);
      end);
    LReq := NewGetRequest('/health');
    for LIt := 1 to aIters do
      LR.ServeHTTP(LReq, nil);
  finally
    LR.Free;
  end;
end;

procedure BenchDirectCall(aIters: Int64);
var
  LIt: Int64;
  LReq: IHttpRequest;
  LHandler: THttpHandlerFunc;
begin
  LReq := NewGetRequest('/health');
  LHandler := procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    Inc(GDispatchCount);
  end;
  for LIt := 1 to aIters do
    LHandler(LReq, nil);
end;

begin
  LFilter := Trim(GetEnvironmentVariable('NEXTPAS_BENCH_FILTER'));
  { Source-contract marker: bench_filter= must be emitted before Run so it
    also appears on the no-match path. }
  WriteLn('=== nextpas.core.http.router benchmark ===');
  WriteLn('operation=http.router.dispatch');
  WriteLn('bench_filter=', LFilter);
  WriteLn;
  LResults := TBenchSuite.Create('Static match (5 routes)')
    .SetFilter(LFilter)
    .AddLoop('Static match (5 routes)', @BenchStaticRoute_5Routes)
    .AddLoop('Static match (50 routes)', @BenchStaticRoute_50Routes)
    .AddLoop('Param :id', @BenchParamRoute)
    .AddLoop('Multi param (3 params)', @BenchMultiParam)
    .AddLoop('Wildcard *filepath', @BenchWildcard)
    .AddLoop('Deep path (3 params, 8 segs)', @BenchDeepPath)
    .AddLoop('Miss (no match)', @BenchMiss)
    .AddLoop('handler dispatch (match + no-op handler)', @BenchHandlerDispatch)
    .AddLoop('direct call (same request, no router)', @BenchDirectCall)
    .Run;
  if (LFilter <> '') and (LResults.Count = 0) then
  begin
    WriteLn('No matching benchmark rows.');
    Halt(1);
  end;
  WriteLn(LResults.PrintToConsole);
end.
