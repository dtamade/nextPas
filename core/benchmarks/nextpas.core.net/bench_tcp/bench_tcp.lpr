program bench_tcp;

{$I nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  nextpas.core.bench,
  nextpas.core.net,
  nextpas.core.platform.thread;

var
  B: TBenchRunner;
  GPort: UInt16;
  GReady: Int32;

const
  MSG_SIZE = 1024;

function EchoServer(AParam: Pointer): Pointer; cdecl;
var
  LListener: ITcpListener;
  LConn: ITcpStream;
  LBuf: array[0..MSG_SIZE - 1] of Byte;
  LN: SizeUInt;
begin
  LListener := TcpListen('127.0.0.1', 0);
  GPort := LListener.LocalAddr.Port;
  InterlockedIncrement(GReady);
  LConn := LListener.Accept;
  repeat
    LN := LConn.Read(LBuf[0], MSG_SIZE);
    if LN > 0 then
      LConn.Write(LBuf[0], LN);
  until LN = 0;
  LConn.Close;
  LListener.Close;
  Result := nil;
end;

procedure BenchTcpRoundTrip1K(aIters: Int64);
var
  LHandle: TPlatformThreadHandle;
  LRetVal: Pointer;
  LConn: ITcpStream;
  LBuf: array[0..MSG_SIZE - 1] of Byte;
  LIt: Int64;
  LN: SizeUInt;
begin
  GReady := 0;
  platform_thread_create(LHandle, @EchoServer, nil);
  while InterlockedCompareExchange(GReady, 0, 0) = 0 do ;
  LConn := TcpConnect('127.0.0.1', GPort);
  LConn.SetNoDelay(True);
  FillChar(LBuf[0], MSG_SIZE, Byte('x'));
  for LIt := 1 to aIters do
  begin
    LConn.Write(LBuf[0], MSG_SIZE);
    LN := 0;
    while LN < MSG_SIZE do
      LN := LN + LConn.Read(LBuf[LN], MSG_SIZE - LN);
  end;
  LConn.Shutdown;
  LConn.Close;
  platform_thread_join(LHandle, LRetVal);
end;

function ThroughputServer(AParam: Pointer): Pointer; cdecl;
var
  LListener: ITcpListener;
  LConn: ITcpStream;
  LBuf: array[0..65535] of Byte;
  LN: SizeUInt;
begin
  LListener := TcpListen('127.0.0.1', 0);
  GPort := LListener.LocalAddr.Port;
  InterlockedIncrement(GReady);
  LConn := LListener.Accept;
  repeat
    LN := LConn.Read(LBuf[0], 65536);
  until LN = 0;
  LConn.Close;
  LListener.Close;
  Result := nil;
end;

procedure BenchTcpThroughput64K(aIters: Int64);
var
  LHandle: TPlatformThreadHandle;
  LRetVal: Pointer;
  LConn: ITcpStream;
  LBuf: array[0..65535] of Byte;
  LIt: Int64;
begin
  GReady := 0;
  platform_thread_create(LHandle, @ThroughputServer, nil);
  while InterlockedCompareExchange(GReady, 0, 0) = 0 do ;
  LConn := TcpConnect('127.0.0.1', GPort);
  LConn.SetNoDelay(True);
  FillChar(LBuf[0], 65536, Byte('y'));
  for LIt := 1 to aIters do
    LConn.Write(LBuf[0], 65536);
  LConn.Shutdown;
  LConn.Close;
  platform_thread_join(LHandle, LRetVal);
end;

begin
  B := TBenchRunner.Create;
  WriteLn('=== nextpas.core.net TCP benchmark ===');
  WriteLn;
  B.Run('TCP echo round-trip 1KB', @BenchTcpRoundTrip1K);
  B.Run('TCP write throughput 64KB', @BenchTcpThroughput64K);
  WriteLn;
  B.Summary;
  B.Free;
end.
