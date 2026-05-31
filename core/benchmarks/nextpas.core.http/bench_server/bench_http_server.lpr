program bench_http_server;
{**
 * @desc HTTP server hello-world QPS benchmark.
 *       Starts server, hammers it with concurrent connections, reports req/s.
 *}

{$I nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.server,
  nextpas.core.http.middleware,
  nextpas.core.net,
  nextpas.core.net.intf,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.platform.thread,
  nextpas.core.platform.time;

const
  NUM_REQUESTS = 10000;
  NUM_THREADS = 4;
  REQ_PER_THREAD = NUM_REQUESTS div NUM_THREADS;

var
  GServer: THttpServer;
  GPort: UInt16;
  GReady: Int32;
  GDone: Int32;
  GSuccess: Int32;

function ServerThread(AParam: Pointer): Pointer; cdecl;
begin
  Result := nil;
  GServer.ListenAndServe('127.0.0.1', 0);
end;

function ClientThread(AParam: Pointer): Pointer; cdecl;
var
  LI: Int32;
  LConn: ITcpStream;
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LTotal: SizeUInt;
const
  REQ: AnsiString = 'GET / HTTP/1.1'#13#10'Host: localhost'#13#10'Content-Length: 0'#13#10#13#10;
begin
  Result := nil;
  try
    LConn := TcpConnect('127.0.0.1', GPort);
    LConn.SetNoDelay(True);
    LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(10)));
    for LI := 1 to REQ_PER_THREAD do
    begin
      LConn.Write(PAnsiChar(REQ)^, Length(REQ));
      LTotal := 0;
      repeat
        LN := LConn.Read(LBuf[LTotal], 4096 - LTotal);
        if LN = 0 then Break;
        Inc(LTotal, LN);
      until LTotal >= 70;
      if LN = 0 then Break;
      InterlockedIncrement(GSuccess);
    end;
    LConn.Close;
  except
  end;
  InterlockedIncrement(GDone);
end;

var
  LHandle: TPlatformThreadHandle;
  LHandles: array[0..NUM_THREADS-1] of TPlatformThreadHandle;
  LI: Int32;
  LStart, LEnd: UInt64;
  LElapsedNs: UInt64;
  LReqPerSec: Double;

begin
  GReady := 0;
  GDone := 0;
  GSuccess := 0;

  GServer := THttpServer.Create(HandlerFunc(
    procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.Headers.Set_('content-type', 'text/plain');
      AW.Headers.Set_('content-length', '13');
      AW.WriteHeader(200);
      AW.Write(PAnsiChar('Hello, World!')^, 13);
    end), THttpServerOptions.Default);

  platform_thread_create(LHandle, @ServerThread, nil);
  while GServer.LocalAddr.Port = 0 do
    platform_thread_sleep_ns(1000000);
  GPort := GServer.LocalAddr.Port;

  WriteLn('=== HTTP Server Benchmark ===');
  WriteLn('  Requests: ', NUM_REQUESTS);
  WriteLn('  Threads:  ', NUM_THREADS);
  WriteLn('  Port:     ', GPort);
  WriteLn;

  LStart := platform_monotonic_ns;

  for LI := 0 to NUM_THREADS - 1 do
    platform_thread_create(LHandles[LI], @ClientThread, nil);

  while InterlockedCompareExchange(GDone, 0, 0) < NUM_THREADS do
    platform_thread_sleep_ns(1000000);

  LEnd := platform_monotonic_ns;
  LElapsedNs := LEnd - LStart;

  LReqPerSec := (GSuccess / (LElapsedNs / 1000000000.0));

  WriteLn('  Completed: ', GSuccess, ' / ', NUM_REQUESTS);
  WriteLn('  Elapsed:   ', LElapsedNs div 1000000, ' ms');
  WriteLn('  Req/s:     ', Trunc(LReqPerSec));
  WriteLn;

  GServer.Shutdown;
  GServer.Free;
end.
