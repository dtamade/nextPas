program test_http_mem;
{**
 * Product-path wire: nextpas.core.http.mem → nextpas.core.mem.
 * Locks request-scoped Arena helpers and RequestArenaMiddleware lifecycle.
 *}

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.fs,
  nextpas.core.http,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.headers,
  nextpas.core.http.middleware,
  nextpas.core.http.middleware.requestarena,
  nextpas.core.http.mem,
  nextpas.core.mem.intf,
  nextpas.core.mem.arena.intf,
  nextpas.core.mem.default,
  nextpas.core.mem.allocator.growing;

var
  T: TTestSuite;
  LRunPassed: Boolean;

type
  TStubWriter = class(TInterfacedObject, IHttpResponseWriter)
  private
    FHeaders: IHttpHeaders;
    FStatus: THttpStatus;
  public
    constructor Create;
    procedure WriteHeader(const AStatus: THttpStatus);
    function GetStatus: THttpStatus;
    function GetHeaders: IHttpHeaders;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Flush;
  end;

constructor TStubWriter.Create;
begin
  inherited Create;
  FHeaders := NewHttpHeaders;
  FStatus := 0;
end;

procedure TStubWriter.WriteHeader(const AStatus: THttpStatus);
begin
  FStatus := AStatus;
end;

function TStubWriter.GetStatus: THttpStatus;
begin
  Result := FStatus;
end;

function TStubWriter.GetHeaders: IHttpHeaders;
begin
  Result := FHeaders;
end;

function TStubWriter.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  Result := ACount;
end;

procedure TStubWriter.Flush;
begin
end;

procedure TestHttpRequestArenaHelpers;
var
  LArena: IArena;
  LAlloc: IAllocator;
  LPtr: Pointer;
  I: Integer;
begin
  LArena := HttpCreateRequestArena;
  Check(LArena <> nil, 'default request arena');
  Check(HTTP_DEFAULT_REQUEST_ARENA = 256 * 1024, 'default cap const');
  for I := 1 to 32 do
  begin
    LPtr := LArena.Alloc(64 + SizeUInt(I));
    Check(LPtr <> nil, 'scratch alloc');
    PByte(LPtr)^ := Byte(I);
  end;
  Check(LArena.UsedSize > 0, 'used');
  LArena.Reset;
  Check(LArena.UsedSize = 0, 'reset');

  LArena := HttpCreateRequestArena(4096);
  Check(LArena <> nil, 'custom cap');
  Check(LArena.Alloc(128) <> nil, 'alloc custom');

  LAlloc := HttpCreateRequestAllocator(8192);
  Check(LAlloc <> nil, 'request allocator');
  Check(not LAlloc.Traits.SupportsRealloc, 'arena no realloc');
  LPtr := LAlloc.GetMem(256);
  Check(LPtr <> nil, 'plugin GetMem');
  LAlloc.FreeMem(LPtr); { no-op by contract }
end;

procedure TestHttpProcessHeapSameAsMem;
var
  LHeap: TGrowingAllocator;
  LAlloc: IAllocator;
  LPtr: Pointer;
begin
  LHeap := HttpProcessHeap;
  LAlloc := HttpProcessAllocator;
  Check(LHeap = DefaultHeap, 'HttpProcessHeap = DefaultHeap');
  Check(LAlloc = DefaultAllocator, 'HttpProcessAllocator = DefaultAllocator');
  LPtr := LHeap.GetMem(48);
  Check(LPtr <> nil, 'process heap alloc');
  LHeap.FreeMem(LPtr, 48);
end;

procedure TestHandlerScopedArenaPattern;
var
  LArena: IArena;
  LHdr, LBody, LScratch: Pointer;
  R: Integer;
  LBodySize: SizeUInt;
const
  BODY_SIZES: array[0..3] of SizeUInt = (64, 256, 1024, 4096);
begin
  { SC7 / M2-4 product pattern via HTTP public API (not mem-only tests). }
  for R := 1 to 50 do
  begin
    LArena := HttpCreateRequestArena;
    LBodySize := BODY_SIZES[R mod Length(BODY_SIZES)];
    LHdr := LArena.Alloc(128);
    LBody := LArena.Alloc(LBodySize);
    LScratch := LArena.Alloc(64);
    Check(LHdr <> nil, 'hdr');
    Check(LBody <> nil, 'body');
    Check(LScratch <> nil, 'scratch');
    PByte(LHdr)^ := Byte(R);
    PByte(LBody)^ := Byte(R xor $A5);
    { end of request — drop arena (interface nil) }
    LArena := nil;
  end;
  Check(True, '50 request scopes');
end;

procedure TestFacadeReexport;
var
  LArena: IArena;
begin
  { nextpas.core.http re-exports helpers }
  LArena := nextpas.core.http.HttpCreateRequestArena(1024);
  Check(LArena <> nil, 'facade HttpCreateRequestArena');
  Check(LArena.Alloc(32) <> nil, 'facade arena alloc');
  Check(nextpas.core.http.HttpProcessHeap = DefaultHeap, 'facade heap');
end;

procedure TestHttpUseRequestArenaHelper;
var
  LRouter: IHttpRouter;
  LHandler: IHttpHandler;
  LReq: IHttpRequest;
  LW: IHttpResponseWriter;
  LUsed: SizeUInt;
begin
  LUsed := 0;
  LRouter := NewRouter;
  HttpUseRequestArena(LRouter);
  LRouter.Get('/x',
    procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    var
      LArena: IArena;
    begin
      LArena := HttpRequestArenaOf(AReq);
      Check(LArena <> nil, 'mounted arena');
      Check(LArena.Alloc(64) <> nil, 'mounted alloc');
      LUsed := LArena.UsedSize;
      AW.WriteHeader(HTTP_STATUS_OK);
    end);
  LHandler := LRouter;
  LReq := NewRequest(hmGet, 'http://localhost/x');
  LW := TStubWriter.Create;
  LHandler.ServeHTTP(LReq, LW);
  Check(LUsed > 0, 'HttpUseRequestArena path used');
  Check(HttpRequestArenaOf(LReq) = nil, 'cleaned after ServeHTTP');
end;

procedure TestHttpWithRequestArenaAndServerFactory;
var
  LInner, LHandler: IHttpHandler;
  LReq: IHttpRequest;
  LW: IHttpResponseWriter;
  LServer: IHttpServer;
  LUsed: SizeUInt;
  LStats: string;
  LAlloc: IAllocator;
  LOpts: THttpServerOptions;
begin
  LUsed := 0;
  LInner := HandlerFunc(
    procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    var
      LArena: IArena;
      LPlugin: IAllocator;
      LPtr: Pointer;
    begin
      LArena := HttpRequestArenaOf(AReq);
      Check(LArena <> nil, 'server-level arena');
      Check(LArena.Alloc(48) <> nil, 'server-level alloc');
      LPlugin := HttpRequestAllocatorOf(AReq);
      Check(LPlugin <> nil, 'request allocator');
      LPtr := LPlugin.GetMem(32);
      Check(LPtr <> nil, 'request alloc GetMem');
      LPlugin.FreeMem(LPtr); { no-op by contract }
      LUsed := LArena.UsedSize;
      AW.WriteHeader(HTTP_STATUS_OK);
    end);
  LHandler := HttpWithRequestArena(LInner);
  LReq := NewRequest(hmGet, 'http://localhost/root');
  LW := TStubWriter.Create;
  LHandler.ServeHTTP(LReq, LW);
  Check(LUsed > 0, 'HttpWithRequestArena used');
  Check(HttpRequestArenaOf(LReq) = nil, 'cleaned after root wrap');
  Check(HttpRequestAllocatorOf(LReq) = nil, 'alloc cleaned after root wrap');

  LServer := NewHttpServerWithRequestArena(LInner);
  Check(LServer <> nil, 'NewHttpServerWithRequestArena');
  Check(not LServer.IsRunning, 'constructed idle');
  { No-arg factory bases on Production (finite RW), not Default. }
  LOpts := THttpServerOptions.Production.WithRequestArena;
  CheckEqual(30000, LOpts.ReadTimeout,
    'Production.WithRequestArena ReadTimeout template');
  CheckEqual(30000, LOpts.WriteTimeout,
    'Production.WithRequestArena WriteTimeout template');
  Check(LOpts.RequestArena, 'Production.WithRequestArena enables arena');

  LOpts := THttpServerOptions.Default.WithRequestArena;
  Check(LOpts.RequestArena, 'options RequestArena');
  CheckEqual(30000, LOpts.ReadTimeout, 'Default.WithRequestArena keeps RW=30000 (PD-1B)');
  LServer := NewHttpServer(LInner, LOpts);
  Check(LServer <> nil, 'NewHttpServer WithRequestArena options');

  LStats := HttpFormatProcessMemStats;
  Check(Pos('live_bytes=', LStats) > 0, 'HttpFormatProcessMemStats live_bytes');
  Check(Pos('heap_debug=', LStats) > 0, 'HttpFormatProcessMemStats heap_debug');

  LAlloc := HttpRequestAllocatorOf(nil);
  Check(LAlloc = nil, 'nil request allocator');
end;

procedure TestRequestArenaMiddlewareLifecycle;
var
  LHandler: IHttpHandler;
  LReq: IHttpRequest;
  LW: IHttpResponseWriter;
  LSawArena: Boolean;
  LUsed: SizeUInt;
  LR: Integer;
begin
  LSawArena := False;
  LUsed := 0;
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    var
      LArena: IArena;
      LPtr: Pointer;
    begin
      LArena := HttpRequestArenaOf(AReq);
      LSawArena := LArena <> nil;
      if LArena <> nil then
      begin
        LPtr := LArena.Alloc(128);
        Check(LPtr <> nil, 'middleware arena alloc');
        LUsed := LArena.UsedSize;
      end;
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [RequestArenaMiddleware]
  );
  LReq := NewRequest(hmGet, 'http://localhost/scratch');
  LW := TStubWriter.Create;
  LHandler.ServeHTTP(LReq, LW);
  Check(LSawArena, 'arena present during handler');
  Check(LUsed > 0, 'scratch used during handler');
  Check(HttpRequestArenaOf(LReq) = nil, 'arena cleaned after request');

  { Custom capacity via facade }
  LSawArena := False;
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    var
      LArena: IArena;
    begin
      LArena := nextpas.core.http.HttpRequestArenaOf(AReq);
      LSawArena := (LArena <> nil) and (LArena.Alloc(64) <> nil);
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [RequestArenaMiddlewareWith(8192)]
  );
  LReq := NewRequest(hmPost, 'http://localhost/body');
  LW := TStubWriter.Create;
  LHandler.ServeHTTP(LReq, LW);
  Check(LSawArena, 'custom-cap arena via facade');

  { Nil without middleware }
  LReq := NewRequest(hmGet, 'http://localhost/no-mw');
  Check(HttpRequestArenaOf(LReq) = nil, 'nil without middleware');

  { Multi-request isolation }
  for LR := 1 to 20 do
  begin
    LHandler := Chain(
      HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
      var
        LArena: IArena;
      begin
        LArena := HttpRequestArenaOf(AReq);
        Check(LArena <> nil, 'isolated arena');
        Check(LArena.Alloc(32) <> nil, 'isolated alloc');
        AW.WriteHeader(HTTP_STATUS_OK);
      end),
      [RequestArenaMiddleware]
    );
    LReq := NewRequest(hmGet, 'http://localhost/r');
    LW := TStubWriter.Create;
    LHandler.ServeHTTP(LReq, LW);
    Check(HttpRequestArenaOf(LReq) = nil, 'cleaned each request');
  end;
end;

procedure TestHttpAttachDetachRequestArena;
{ Kernel attach path used by H1 connection-scoped RequestArena. }
var
  LReq: IHttpRequest;
  LArena: IArena;
  LPtr: Pointer;
  I: Integer;
  LUsed: SizeUInt;
begin
  LArena := HttpCreateRequestArena(8192);
  Check(LArena <> nil, 'conn arena');
  LReq := NewRequest(hmGet, 'http://localhost/attach');

  { Simulate H1 InvokeHandler: Reset → attach → handler → detach → Reset. }
  for I := 1 to 5 do
  begin
    LArena.Reset;
    HttpAttachRequestArena(LReq, LArena);
    try
      Check(HttpRequestArenaOf(LReq) = LArena, 'attach maps arena');
      LPtr := LArena.Alloc(64);
      Check(LPtr <> nil, 'alloc under attach');
      LUsed := LArena.UsedSize;
      Check(LUsed > 0, 'used under attach');
      Check(HttpRequestAllocatorOf(LReq) <> nil, 'allocator under attach');
    finally
      HttpDetachRequestArena(LReq);
      LArena.Reset;
    end;
    Check(HttpRequestArenaOf(LReq) = nil, 'detach clears map');
    Check(LArena.UsedSize = 0, 'reset after detach');
  end;

  { Nil-safe }
  HttpAttachRequestArena(nil, LArena);
  HttpDetachRequestArena(nil);
  HttpAttachRequestArena(LReq, nil);
  Check(HttpRequestArenaOf(LReq) = nil, 'nil arena attach is no-op');
end;

procedure TestRequestArenaNoGlobalMap;
{ SAFE-3: arena attachment is request-local Supports, not GArenaMap. }
var
  LSrc: string;
begin
  LSrc := ReadFileText('../../../src/nextpas.core.http.middleware.requestarena.pas');
  Check(Pos('GArenaMap', LSrc) = 0, 'no GArenaMap');
  Check(Pos('TRTLCriticalSection', LSrc) = 0, 'no RTL critical section map lock');
  Check(Pos('IHttpRequestWithArena', LSrc) > 0, 'uses IHttpRequestWithArena');
end;

begin
  T := TTestSuite.Create('nextpas.core.http.mem');
  T.Test('request arena helpers', @TestHttpRequestArenaHelpers);
  T.Test('process heap aliases', @TestHttpProcessHeapSameAsMem);
  T.Test('handler scoped arena pattern', @TestHandlerScopedArenaPattern);
  T.Test('http facade re-export', @TestFacadeReexport);
  T.Test('RequestArenaMiddleware lifecycle', @TestRequestArenaMiddlewareLifecycle);
  T.Test('HttpUseRequestArena helper', @TestHttpUseRequestArenaHelper);
  T.Test('HttpWithRequestArena + server factory', @TestHttpWithRequestArenaAndServerFactory);
  T.Test('HttpAttach/Detach kernel path', @TestHttpAttachDetachRequestArena);
  T.Test('RequestArena no global map', @TestRequestArenaNoGlobalMap);
  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
