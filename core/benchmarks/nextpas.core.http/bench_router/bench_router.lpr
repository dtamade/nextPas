program bench_router;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.bench,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.router;

var
  B: TBenchRunner;
  GSink: string;

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
  LR.Free;
end;

begin
  B := TBenchRunner.Create;
  WriteLn('=== nextpas.core.http.router benchmark ===');
  WriteLn;
  B.Run('Static match (5 routes)', @BenchStaticRoute_5Routes);
  B.Run('Static match (50 routes)', @BenchStaticRoute_50Routes);
  B.Run('Param :id', @BenchParamRoute);
  B.Run('Multi param (3 params)', @BenchMultiParam);
  B.Run('Wildcard *filepath', @BenchWildcard);
  B.Run('Deep path (3 params, 8 segs)', @BenchDeepPath);
  B.Run('Miss (no match)', @BenchMiss);
  WriteLn;
  B.Summary;
  B.Free;
end.
