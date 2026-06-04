program bench_http_server;
{**
 * @desc HTTP server hello-world QPS benchmark.
 *       Starts server, hammers it with concurrent connections, reports req/s.
 *}

{$I nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils,
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
  DEFAULT_NUM_REQUESTS = 20000;
  DEFAULT_NUM_THREADS = 4;

var
  GServer: THttpServer;
  GPort: UInt16;
  GDone: Int32;
  GSuccess: Int32;
  GRequests: Int32;
  GThreads: Int32;

function ServerThread(AParam: Pointer): Pointer; cdecl;
begin
  Result := nil;
  GServer.ListenAndServe('127.0.0.1', 0);
end;

function ClientThread(AParam: Pointer): Pointer; cdecl;
var
  LI: Int32;
  LRequests: Int32;
  LConn: ITcpStream;
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LTotal: SizeUInt;
const
  REQ: AnsiString = 'GET / HTTP/1.1'#13#10'Host: localhost'#13#10'Content-Length: 0'#13#10#13#10;
begin
  Result := nil;
  LRequests := Int32(PtrUInt(AParam));
  try
    LConn := TcpConnect('127.0.0.1', GPort);
    LConn.SetNoDelay(True);
    LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(10)));
    for LI := 1 to LRequests do
    begin
      LConn.Write(PAnsiChar(REQ)^, Length(REQ));
      LTotal := 0;
      repeat
        LN := LConn.Read(LBuf[LTotal], 4096 - LTotal);
        if LN = 0 then Break;
        Inc(LTotal, LN);
      until LTotal >= 50;
      if LN = 0 then Break;
      InterlockedIncrement(GSuccess);
    end;
    LConn.Close;
  except
  end;
  InterlockedIncrement(GDone);
end;

procedure ParseOptions;
var
  LI: Integer;
  LValue: Integer;
begin
  GRequests := DEFAULT_NUM_REQUESTS;
  GThreads := DEFAULT_NUM_THREADS;
  LI := 1;
  while LI <= ParamCount do
  begin
    if (ParamStr(LI) = '--requests') and (LI < ParamCount) then
    begin
      LValue := StrToIntDef(ParamStr(LI + 1), GRequests);
      if LValue > 0 then
        GRequests := LValue;
      Inc(LI, 2);
    end
    else if (ParamStr(LI) = '--threads') and (LI < ParamCount) then
    begin
      LValue := StrToIntDef(ParamStr(LI + 1), GThreads);
      if LValue > 0 then
        GThreads := LValue;
      Inc(LI, 2);
    end
    else
      Inc(LI);
  end;
  if GThreads > GRequests then
    GThreads := GRequests;
end;

var
  LHandle: TPlatformThreadHandle;
  LHandles: array of TPlatformThreadHandle;
  LI: Int32;
  LThreadRequests: Int32;
  LStart, LEnd: UInt64;
  LElapsedNs: UInt64;
  LReqPerSec: Double;
  LNsPerOp: Double;
  LRet: Pointer;

begin
  ParseOptions;
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
  WriteLn('  Requests: ', GRequests);
  WriteLn('  Threads:  ', GThreads);
  WriteLn('  Port:     ', GPort);
  WriteLn;

  LStart := platform_monotonic_ns;

  SetLength(LHandles, GThreads);
  for LI := 0 to GThreads - 1 do
  begin
    LThreadRequests := GRequests div GThreads;
    if LI < (GRequests mod GThreads) then
      Inc(LThreadRequests);
    platform_thread_create(LHandles[LI], @ClientThread, Pointer(PtrInt(LThreadRequests)));
  end;

  while InterlockedCompareExchange(GDone, 0, 0) < GThreads do
    platform_thread_sleep_ns(1000000);

  for LI := 0 to GThreads - 1 do
    platform_thread_join(LHandles[LI], LRet);

  LEnd := platform_monotonic_ns;
  LElapsedNs := LEnd - LStart;

  LReqPerSec := (GSuccess / (LElapsedNs / 1000000000.0));
  if GSuccess > 0 then
    LNsPerOp := LElapsedNs / GSuccess
  else
    LNsPerOp := 0.0;

  WriteLn('  Completed: ', GSuccess, ' / ', GRequests);
  WriteLn('  Elapsed:   ', LElapsedNs div 1000000, ' ms');
  WriteLn('  Req/s:     ', Trunc(LReqPerSec));
  WriteLn;
  WriteLn('operation=http.server.keepalive');
  WriteLn('impl=nextpas');
  WriteLn('iterations=', GRequests);
  WriteLn('threads=', GThreads);
  WriteLn('completed=', GSuccess);
  WriteLn('elapsed_ns=', LElapsedNs);
  WriteLn('ns/op=', Trunc(LNsPerOp));
  WriteLn('req/s=', Trunc(LReqPerSec));
  WriteLn;

  GServer.Shutdown;
  platform_thread_join(LHandle, LRet);
  GServer.Free;
end.
