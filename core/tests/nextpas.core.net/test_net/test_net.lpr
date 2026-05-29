program test_net;

{$I nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils,
  nextpas.core.testing,
  nextpas.core.errors,
  nextpas.core.io.intf,
  nextpas.core.net.base,
  nextpas.core.net.intf,
  nextpas.core.net.tcp,
  nextpas.core.net.udp,
  nextpas.core.net.resolve,
  nextpas.core.net,
  nextpas.core.platform.thread;

var
  T: TTestRunner;

{ TCP echo test }

var
  GListenerReady: Int32 = 0;
  GTcpPort: UInt16 = 19876;

function TcpEchoServer(AArg: Pointer): Pointer; cdecl;
var
  LListener: ITcpListener;
  LClient: ITcpStream;
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LTotal: SizeUInt;
begin
  Result := nil;
  LListener := TcpListen('127.0.0.1', GTcpPort);
  InterlockedExchange(GListenerReady, 1);
  LClient := LListener.Accept;
  LTotal := 0;
  repeat
    LN := LClient.Read(LBuf[LTotal], SizeOf(LBuf) - LTotal);
    if LN = 0 then Break;
    Inc(LTotal, LN);
  until False;
  if LTotal > 0 then
    LClient.Write(LBuf[0], LTotal);
  LClient.Close;
  LListener.Close;
end;

procedure TestTcpEcho;
var
  LHandle: TPlatformThreadHandle;
  LRetVal: Pointer;
  LClient: ITcpStream;
  LBuf: array[0..255] of Byte;
  LN: SizeUInt;
begin
  GListenerReady := 0;
  platform_thread_create(LHandle, @TcpEchoServer, nil);
  while InterlockedCompareExchange(GListenerReady, 0, 0) = 0 do
    platform_thread_sleep_ns(1000000);
  LClient := TcpConnect('127.0.0.1', GTcpPort);
  LClient.Write(PAnsiChar('hello')^, 5);
  LClient.Shutdown;
  LN := LClient.Read(LBuf[0], 256);
  CheckEqual(SizeUInt(5), LN, 'echo 5 bytes');
  CheckEqual(Byte(Ord('h')), LBuf[0], 'first byte');
  CheckEqual(Byte(Ord('o')), LBuf[4], 'last byte');
  LClient.Close;
  platform_thread_join(LHandle, LRetVal);
end;

procedure TestTcpLargeData;
var
  LHandle: TPlatformThreadHandle;
  LRetVal: Pointer;
  LClient: ITcpStream;
  LBuf: array[0..1023] of Byte;
  LTotal: SizeUInt;
  LN: SizeUInt;
begin
  GListenerReady := 0;
  GTcpPort := 19877;
  platform_thread_create(LHandle, @TcpEchoServer, nil);
  while InterlockedCompareExchange(GListenerReady, 0, 0) = 0 do
    platform_thread_sleep_ns(1000000);
  LClient := TcpConnect('127.0.0.1', GTcpPort);
  FillChar(LBuf[0], 1024, $AA);
  LClient.Write(LBuf[0], 1024);
  LClient.Shutdown;
  LTotal := 0;
  while LTotal < 1024 do
  begin
    LN := LClient.Read(LBuf[LTotal], 1024 - LTotal);
    if LN = 0 then Break;
    Inc(LTotal, LN);
  end;
  CheckEqual(SizeUInt(1024), LTotal, '1KB echo');
  CheckEqual(Byte($AA), LBuf[0]);
  CheckEqual(Byte($AA), LBuf[1023]);
  LClient.Close;
  platform_thread_join(LHandle, LRetVal);
end;

{ UDP test }

procedure TestUdpSendRecv;
var
  LS: IUdpSocket;
  LBuf: array[0..31] of Byte;
  LN: SizeUInt;
  LFrom: TNetAddress;
begin
  LS := UdpBind('127.0.0.1', 19878);
  LS.SendTo(PAnsiChar('ping')^, 4, TNetAddress.Create('127.0.0.1', 19878));
  LN := LS.RecvFrom(LBuf[0], 32, LFrom);
  CheckEqual(SizeUInt(4), LN, 'udp recv 4');
  CheckEqual(Byte(Ord('p')), LBuf[0]);
  LS.Close;
end;

{ Resolve test }

procedure TestResolve;
var
  LA: TNetAddress;
begin
  LA := Resolve('localhost');
  CheckEqual('127.0.0.1', LA.IP, 'localhost resolves');
end;

{ Address test }

procedure TestNetAddress;
var
  LA: TNetAddress;
begin
  LA := TNetAddress.Create('192.168.1.1', 8080);
  CheckEqual('192.168.1.1:8080', LA.ToString, 'ipv4 toString');
  Check(not LA.IsIPv6, 'not ipv6');
  LA := TNetAddress.IPv6('::1', 443);
  CheckEqual('[::1]:443', LA.ToString, 'ipv6 toString');
  Check(LA.IsIPv6, 'is ipv6');
end;

{ Error test }

procedure TestConnectRefused;
var
  LGot: Boolean;
begin
  LGot := False;
  try
    TcpConnect('127.0.0.1', 1);
  except
    on E: ENetworkError do
      LGot := True;
  end;
  Check(LGot, 'connection refused raises');
end;

{ ITcpStream as IReader/IWriter }

var
  GIoPort: UInt16 = 19879;
  GIoReady: Int32 = 0;

function IoEchoServer(AArg: Pointer): Pointer; cdecl;
var
  LListener: ITcpListener;
  LClient: ITcpStream;
  LBuf: array[0..255] of Byte;
  LN: SizeUInt;
begin
  Result := nil;
  LListener := TcpListen('127.0.0.1', GIoPort);
  InterlockedExchange(GIoReady, 1);
  LClient := LListener.Accept;
  LN := (LClient as IReader).Read(LBuf[0], 256);
  if LN > 0 then
    (LClient as IWriter).Write(LBuf[0], LN);
  LClient.Close;
  LListener.Close;
end;

procedure TestIoIntegration;
var
  LHandle: TPlatformThreadHandle;
  LRetVal: Pointer;
  LClient: ITcpStream;
  LReader: IReader;
  LWriter: IWriter;
  LBuf: array[0..31] of Byte;
  LN: SizeUInt;
begin
  GIoReady := 0;
  platform_thread_create(LHandle, @IoEchoServer, nil);
  while InterlockedCompareExchange(GIoReady, 0, 0) = 0 do
    platform_thread_sleep_ns(1000000);
  LClient := TcpConnect('127.0.0.1', GIoPort);
  LWriter := LClient as IWriter;
  LReader := LClient as IReader;
  LWriter.Write(PAnsiChar('io')^, 2);
  LN := LReader.Read(LBuf[0], 32);
  CheckEqual(SizeUInt(2), LN, 'io echo');
  CheckEqual(Byte(Ord('i')), LBuf[0]);
  LClient.Close;
  platform_thread_join(LHandle, LRetVal);
end;

begin
  T := TTestRunner.Create('nextpas.core.net');
  T.Run('TCP echo', @TestTcpEcho);
  T.Run('TCP large data', @TestTcpLargeData);
  T.Run('UDP send/recv', @TestUdpSendRecv);
  T.Run('Resolve', @TestResolve);
  T.Run('NetAddress', @TestNetAddress);
  T.Run('Connect refused', @TestConnectRefused);
  T.Run('IO integration', @TestIoIntegration);
  T.Summary;
end.
