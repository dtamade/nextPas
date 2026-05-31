program bench_http;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.time.base,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.router,
  nextpas.core.http.url,
  nextpas.core.http.headers;

const
  ROUTE_COUNT = 100;
  MATCH_ITERS = 10000;
  URL_ITERS = 100000;
  HEADER_ITERS = 100000;

{ BenchRouterMatch — register routes then match them repeatedly }

procedure BenchRouterMatch;
var
  LRouter: THttpRouter;
  LParams: TRouteParams;
  LHandler: THttpHandlerFunc;
  LStart: TInstant;
  LNs: Int64;
  I, J: Integer;
  LPaths: array[0..ROUTE_COUNT-1] of string;
begin
  LRouter := THttpRouter.Create;
  try
    LHandler := procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
    end;

    { Register ROUTE_COUNT routes with varying patterns }
    for I := 0 to ROUTE_COUNT - 1 do
    begin
      LPaths[I] := '/api/v1/resource' + IntToStr(I) + '/:id/action' + IntToStr(I mod 10);
      LRouter.Handle(hmGet, LPaths[I], LHandler);
    end;

    { Benchmark matching }
    LStart := TInstant.Now;
    for J := 1 to MATCH_ITERS do
      for I := 0 to ROUTE_COUNT - 1 do
      begin
        LParams := nil;
        LRouter.FindRoute(hmGet, '/api/v1/resource' + IntToStr(I) + '/42/action' + IntToStr(I mod 10), LParams);
      end;
    LNs := LStart.Elapsed.AsNanoseconds;
    WriteLn(Format('  RouterMatch %d routes x %d iters  %8.2f ms  %6.1f ns/match',
      [ROUTE_COUNT, MATCH_ITERS,
       LNs / 1000000.0,
       LNs / Double(ROUTE_COUNT * MATCH_ITERS)]));
  finally
    LRouter.Free;
  end;
end;

{ BenchUrlParse — parse URLs }

procedure BenchUrlParse;
const
  TEST_URLS: array[0..4] of string = (
    'http://example.com/path?key=value&foo=bar#section',
    'https://user:pass@api.example.com:8443/v2/resource/123',
    '/simple/path',
    'http://localhost:3000/api/v1/users?page=1&limit=50',
    'https://cdn.example.com/assets/img/logo.png?v=20260101'
  );
var
  LStart: TInstant;
  LNs: Int64;
  I, J: Integer;
  LUrl: TUrl;
begin
  LStart := TInstant.Now;
  for J := 1 to URL_ITERS do
    for I := 0 to High(TEST_URLS) do
      LUrl := TUrl.Parse(TEST_URLS[I]);
  LNs := LStart.Elapsed.AsNanoseconds;
  WriteLn(Format('  UrlParse %d urls x %d iters      %8.2f ms  %6.1f ns/parse',
    [Length(TEST_URLS), URL_ITERS,
     LNs / 1000000.0,
     LNs / Double(Length(TEST_URLS) * URL_ITERS)]));
  { Prevent optimization }
  if LUrl.Path = '$$impossible$$' then WriteLn('');
end;

{ BenchHeaderParse — create and populate headers }

procedure BenchHeaderParse;
var
  LStart: TInstant;
  LNs: Int64;
  I: Integer;
  LHeaders: IHttpHeaders;
begin
  LStart := TInstant.Now;
  for I := 1 to HEADER_ITERS do
  begin
    LHeaders := NewHttpHeaders;
    LHeaders.Set_('Content-Type', 'application/json; charset=utf-8');
    LHeaders.Set_('Authorization', 'Bearer eyJhbGciOiJIUzI1NiJ9.test.signature');
    LHeaders.Set_('Accept', 'application/json');
    LHeaders.Set_('X-Request-Id', '550e8400-e29b-41d4-a716-446655440000');
    LHeaders.Set_('Cache-Control', 'no-cache, no-store, must-revalidate');
    LHeaders.Add('Accept-Encoding', 'gzip');
    LHeaders.Add('Accept-Encoding', 'deflate');
    LHeaders.Add('Accept-Encoding', 'br');
    { Lookup }
    LHeaders.Get('Content-Type');
    LHeaders.Get('Authorization');
    LHeaders.Get('X-Request-Id');
    LHeaders.Has('X-Nonexistent');
    LHeaders := nil;
  end;
  LNs := LStart.Elapsed.AsNanoseconds;
  WriteLn(Format('  HeaderOps %d iters              %8.2f ms  %6.1f ns/iter',
    [HEADER_ITERS,
     LNs / 1000000.0,
     LNs / Double(HEADER_ITERS)]));
end;

begin
  WriteLn('=== nextpas.core.http benchmarks ===');
  WriteLn('');
  BenchRouterMatch;
  BenchUrlParse;
  BenchHeaderParse;
  WriteLn('');
  WriteLn('Done.');
end.
