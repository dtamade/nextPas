program test_net_deep;

{$I nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils,
  nextpas.core.testing,
  nextpas.core.errors,
  nextpas.core.io.intf,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.net.base,
  nextpas.core.net.intf,
  nextpas.core.net.tcp,
  nextpas.core.net.udp,
  nextpas.core.net.resolve,
  nextpas.core.net,
  nextpas.core.platform.thread;

var
  T: TTestRunner;

{ --- Helpers --- }

var
  GPort: UInt16 = 0;
  GReady: Int32 = 0;

{ Echo server: reads until client shuts down write side, then echoes all back }
function EchoServer(AArg: Pointer): Pointer; cdecl;
var
  LListener: ITcpListener;
  LClient: ITcpStream;
  LBuf: array[0..65535] of Byte;
  LN, LTotal: SizeUInt;
begin
  Result := nil;
  LListener := TcpListen('127.0.0.1', 0);
  GPort := LListener.LocalAddr.Port;
  InterlockedExchange(GReady, 1);
  LClient := LListener.Accept;
  LTotal := 0;
  repeat
    LN := LClient.Read(LBuf[LTotal], SizeUInt(SizeOf(LBuf)) - LTotal);
    if LN = 0 then Break;
    Inc(LTotal, LN);
  until LTotal >= SizeOf(LBuf);
  if LTotal > 0 then
    LClient.Write(LBuf[0], LTotal);
  LClient.Close;
  LListener.Close;
end;

procedure WaitReady;
begin
  while InterlockedCompareExchange(GReady, 0, 0) = 0 do
    platform_thread_sleep_ns(1000000);
end;

procedure ResetReady;
begin
  GReady := 0;
end;

{ Multi-accept server: accepts N connections, echoes each }
var
  GMultiPort: UInt16 = 0;
  GMultiReady: Int32 = 0;
  GMultiCount: Int32 = 0;

function MultiAcceptServer(AArg: Pointer): Pointer; cdecl;
var
  LListener: ITcpListener;
  LClient: ITcpStream;
  LBuf: array[0..1023] of Byte;
  LN: SizeUInt;
  LI: Integer;
begin
  Result := nil;
  LListener := TcpListen('127.0.0.1', 0);
  GMultiPort := LListener.LocalAddr.Port;
  InterlockedExchange(GMultiReady, 1);
  for LI := 1 to GMultiCount do
  begin
    LClient := LListener.Accept;
    LN := LClient.Read(LBuf[0], SizeOf(LBuf));
    if LN > 0 then
      LClient.Write(LBuf[0], LN);
    LClient.Close;
  end;
  LListener.Close;
end;

{ --- Test 1: TCP connect + send + recv (loopback echo) --- }

procedure TestTcpConnectSendRecv;
var
  LHandle: TPlatformThreadHandle;
  LRetVal: Pointer;
  LClient: ITcpStream;
  LBuf: array[0..255] of Byte;
  LN: SizeUInt;
begin
  ResetReady;
  platform_thread_create(LHandle, @EchoServer, nil);
  WaitReady;
  LClient := TcpConnect('127.0.0.1', GPort);
  LClient.Write(PAnsiChar('deep_test')^, 9);
  LClient.Shutdown;
  LN := 0;
  repeat
    LN := LN + LClient.Read(LBuf[LN], 256 - LN);
  until LN >= 9;
  CheckEqual(Int64(9), Int64(LN), 'echo 9 bytes');
  Check(LBuf[0] = Ord('d'), 'first byte d');
  Check(LBuf[8] = Ord('t'), 'last byte t');
  LClient.Close;
  platform_thread_join(LHandle, LRetVal);
end;

{ --- Test 2: TCP listen + accept --- }

procedure TestTcpListenAccept;
var
  LListener: ITcpListener;
  LClient, LAccepted: ITcpStream;
  LBuf: array[0..31] of Byte;
  LN: SizeUInt;
begin
  LListener := TcpListen('127.0.0.1', 0);
  Check(LListener.LocalAddr.Port > 0, 'listener got port');
  LClient := TcpConnect('127.0.0.1', LListener.LocalAddr.Port);
  LAccepted := LListener.Accept;
  Check(LAccepted <> nil, 'accepted not nil');
  LClient.Write(PAnsiChar('hi')^, 2);
  LN := LAccepted.Read(LBuf[0], 32);
  CheckEqual(Int64(2), Int64(LN), 'accepted read 2');
  Check(LBuf[0] = Ord('h'), 'byte h');
  LAccepted.Close;
  LClient.Close;
  LListener.Close;
end;

{ --- Test 3: Address parsing (IPv4, IPv6, hostname) --- }

procedure TestAddressParsing;
var
  LA: TNetAddress;
begin
  LA := TNetAddress.Create('192.168.1.100', 8080);
  CheckEqual('192.168.1.100', LA.IP, 'ipv4 ip');
  CheckEqual(Int64(8080), Int64(LA.Port), 'ipv4 port');
  Check(not LA.IsIPv6, 'not ipv6');
  CheckEqual('192.168.1.100:8080', LA.ToString, 'ipv4 toString');

  LA := TNetAddress.IPv6('::1', 443);
  CheckEqual('::1', LA.IP, 'ipv6 ip');
  Check(LA.IsIPv6, 'is ipv6');
  CheckEqual('[::1]:443', LA.ToString, 'ipv6 toString');

  LA := TNetAddress.Loopback(9999);
  CheckEqual('127.0.0.1', LA.IP, 'loopback ip');
  CheckEqual(Int64(9999), Int64(LA.Port), 'loopback port');

  LA := TNetAddress.Any(0);
  CheckEqual('0.0.0.0', LA.IP, 'any ip');

  { Resolve localhost }
  LA := Resolve('localhost');
  CheckEqual('127.0.0.1', LA.IP, 'localhost resolves to 127.0.0.1');

  { Resolve IPv4 literal }
  LA := Resolve('10.0.0.1');
  CheckEqual('10.0.0.1', LA.IP, 'ipv4 literal passthrough');
end;

{ --- Test 4: Socket options (NoDelay, KeepAlive) --- }

procedure TestSocketOptions;
var
  LListener: ITcpListener;
  LClient: ITcpStream;
begin
  LListener := TcpListen('127.0.0.1', 0);
  LClient := TcpConnect('127.0.0.1', LListener.LocalAddr.Port);
  { These should not raise }
  LClient.SetNoDelay(True);
  LClient.SetNoDelay(False);
  LClient.SetKeepAlive(True);
  LClient.SetKeepAlive(False);
  Check(True, 'socket options set without error');
  LClient.Close;
  LListener.Close;
end;

{ --- Test 5: Connection refused (connect to closed port) --- }

procedure TestConnectionRefused;
var
  LGot: Boolean;
begin
  LGot := False;
  try
    { Port 1 is almost certainly not listening }
    TcpConnect('127.0.0.1', 1);
  except
    on E: ENetworkError do
      LGot := True;
  end;
  Check(LGot, 'connection refused raises ENetworkError');
end;

{ --- Test 6: Timeout on read (deadline) --- }

procedure TestReadTimeout;
var
  LListener: ITcpListener;
  LClient: ITcpStream;
  LBuf: array[0..31] of Byte;
  LGot: Boolean;
  LStart: TInstant;
begin
  LListener := TcpListen('127.0.0.1', 0);
  LClient := TcpConnect('127.0.0.1', LListener.LocalAddr.Port);
  LClient.SetReadDeadline(TDeadline.After(TDuration.FromMilliseconds(100)));
  LGot := False;
  LStart := TInstant.Now;
  try
    LClient.Read(LBuf[0], 32);
  except
    on E: ENetworkError do
      LGot := True;
  end;
  Check(LGot, 'read timeout raises');
  Check(LStart.Elapsed.AsMilliseconds >= 50, 'waited at least 50ms');
  Check(LStart.Elapsed.AsMilliseconds < 2000, 'did not wait too long');
  LClient.Close;
  LListener.Close;
end;

{ --- Test 7: Multiple connections --- }

procedure TestMultipleConnections;
var
  LHandle: TPlatformThreadHandle;
  LRetVal: Pointer;
  LClients: array[0..2] of ITcpStream;
  LBuf: array[0..31] of Byte;
  LN: SizeUInt;
  LI: Integer;
  LMsg: string;
begin
  GMultiCount := 3;
  GMultiReady := 0;
  platform_thread_create(LHandle, @MultiAcceptServer, nil);
  while InterlockedCompareExchange(GMultiReady, 0, 0) = 0 do
    platform_thread_sleep_ns(1000000);
  for LI := 0 to 2 do
  begin
    LClients[LI] := TcpConnect('127.0.0.1', GMultiPort);
    LMsg := 'msg' + Chr(Ord('0') + LI);
    LClients[LI].Write(LMsg[1], Length(LMsg));
    LClients[LI].Shutdown;
    LN := LClients[LI].Read(LBuf[0], 32);
    CheckEqual(Int64(4), Int64(LN), 'multi conn ' + Chr(Ord('0') + LI));
    LClients[LI].Close;
  end;
  platform_thread_join(LHandle, LRetVal);
end;

{ --- Test 8: Close/shutdown behavior --- }

procedure TestCloseShutdown;
var
  LListener: ITcpListener;
  LClient, LAccepted: ITcpStream;
  LBuf: array[0..31] of Byte;
  LN: SizeUInt;
begin
  LListener := TcpListen('127.0.0.1', 0);
  LClient := TcpConnect('127.0.0.1', LListener.LocalAddr.Port);
  LAccepted := LListener.Accept;
  { Write then shutdown write side }
  LClient.Write(PAnsiChar('abc')^, 3);
  LClient.Shutdown;
  { Server reads data }
  LN := LAccepted.Read(LBuf[0], 32);
  CheckEqual(Int64(3), Int64(LN), 'read before close');
  { Server reads again — should get 0 (EOF) }
  LN := LAccepted.Read(LBuf[0], 32);
  CheckEqual(Int64(0), Int64(LN), 'read after shutdown = EOF');
  LAccepted.Close;
  LClient.Close;
  LListener.Close;
end;

{ --- Test 9: Empty send/recv --- }

procedure TestEmptySendRecv;
var
  LListener: ITcpListener;
  LClient: ITcpStream;
  LBuf: array[0..31] of Byte;
  LN: SizeUInt;
begin
  LListener := TcpListen('127.0.0.1', 0);
  LClient := TcpConnect('127.0.0.1', LListener.LocalAddr.Port);
  { Write 0 bytes should return 0 }
  LN := LClient.Write(LBuf[0], 0);
  CheckEqual(Int64(0), Int64(LN), 'write 0 returns 0');
  { Read 0 bytes should return 0 }
  LN := LClient.Read(LBuf[0], 0);
  CheckEqual(Int64(0), Int64(LN), 'read 0 returns 0');
  LClient.Close;
  LListener.Close;
end;

{ --- Test 10: Large transfer (64KB) --- }

var
  GLargePort: UInt16 = 0;
  GLargeReady: Int32 = 0;

function LargeEchoServer(AArg: Pointer): Pointer; cdecl;
var
  LListener: ITcpListener;
  LClient: ITcpStream;
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LTotal: SizeUInt;
begin
  Result := nil;
  LListener := TcpListen('127.0.0.1', 0);
  GLargePort := LListener.LocalAddr.Port;
  InterlockedExchange(GLargeReady, 1);
  LClient := LListener.Accept;
  { Read all then echo all }
  LTotal := 0;
  repeat
    LN := LClient.Read(LBuf[0], SizeOf(LBuf));
    if LN = 0 then Break;
    LClient.Write(LBuf[0], LN);
    Inc(LTotal, LN);
  until False;
  LClient.Close;
  LListener.Close;
end;

procedure TestLargeTransfer;
const
  TRANSFER_SIZE = 65536;
var
  LHandle: TPlatformThreadHandle;
  LRetVal: Pointer;
  LClient: ITcpStream;
  LSendBuf: array[0..TRANSFER_SIZE - 1] of Byte;
  LRecvBuf: array[0..TRANSFER_SIZE - 1] of Byte;
  LI: Integer;
  LTotal, LN: SizeUInt;
begin
  GLargeReady := 0;
  platform_thread_create(LHandle, @LargeEchoServer, nil);
  while InterlockedCompareExchange(GLargeReady, 0, 0) = 0 do
    platform_thread_sleep_ns(1000000);
  { Fill with pattern }
  for LI := 0 to TRANSFER_SIZE - 1 do
    LSendBuf[LI] := Byte(LI and $FF);
  LClient := TcpConnect('127.0.0.1', GLargePort);
  LClient.Write(LSendBuf[0], TRANSFER_SIZE);
  LClient.Shutdown;
  { Read all back }
  LTotal := 0;
  repeat
    LN := LClient.Read(LRecvBuf[LTotal], TRANSFER_SIZE - LTotal);
    if LN = 0 then Break;
    Inc(LTotal, LN);
  until LTotal >= TRANSFER_SIZE;
  CheckEqual(Int64(TRANSFER_SIZE), Int64(LTotal), '64KB echoed');
  Check(LRecvBuf[0] = 0, 'first byte 0');
  Check(LRecvBuf[255] = 255, 'byte 255');
  Check(LRecvBuf[65535] = 255, 'last byte');
  LClient.Close;
  platform_thread_join(LHandle, LRetVal);
end;

{ --- Test 11: UDP send/recv loopback --- }

procedure TestUdpLoopback;
var
  LS: IUdpSocket;
  LBuf: array[0..63] of Byte;
  LN: SizeUInt;
  LFrom: TNetAddress;
  LPort: UInt16;
begin
  LS := UdpBind('127.0.0.1', 0);
  LPort := LS.LocalAddr.Port;
  Check(LPort > 0, 'udp got port');
  LS.SendTo(PAnsiChar('udp_test')^, 8, TNetAddress.Create('127.0.0.1', LPort));
  LN := LS.RecvFrom(LBuf[0], 64, LFrom);
  CheckEqual(Int64(8), Int64(LN), 'udp recv 8');
  Check(LBuf[0] = Ord('u'), 'udp first byte');
  Check(LBuf[7] = Ord('t'), 'udp last byte');
  CheckEqual('127.0.0.1', LFrom.IP, 'udp from addr');
  LS.Close;
end;

{ --- Test 12: UDP multiple datagrams --- }

procedure TestUdpMultipleDatagrams;
var
  LS: IUdpSocket;
  LBuf: array[0..63] of Byte;
  LN: SizeUInt;
  LFrom: TNetAddress;
  LPort: UInt16;
  LI: Integer;
begin
  LS := UdpBind('127.0.0.1', 0);
  LPort := LS.LocalAddr.Port;
  for LI := 1 to 5 do
    LS.SendTo(PAnsiChar('pkt')^, 3, TNetAddress.Create('127.0.0.1', LPort));
  for LI := 1 to 5 do
  begin
    LN := LS.RecvFrom(LBuf[0], 64, LFrom);
    CheckEqual(Int64(3), Int64(LN), 'udp multi pkt');
  end;
  LS.Close;
end;

{ --- Test 13: Resolve invalid host --- }

procedure TestResolveInvalid;
var
  LGot: Boolean;
begin
  LGot := False;
  try
    NetResolveIPv4('999.999.999.999');
  except
    on E: Exception do
      LGot := True;
  end;
  Check(LGot, 'invalid IPv4 raises');
end;

{ --- Test 14: LocalAddr / RemoteAddr --- }

procedure TestLocalRemoteAddr;
var
  LListener: ITcpListener;
  LClient, LAccepted: ITcpStream;
begin
  LListener := TcpListen('127.0.0.1', 0);
  LClient := TcpConnect('127.0.0.1', LListener.LocalAddr.Port);
  LAccepted := LListener.Accept;
  CheckEqual('127.0.0.1', LClient.LocalAddr.IP, 'client local ip');
  CheckEqual('127.0.0.1', LClient.RemoteAddr.IP, 'client remote ip');
  CheckEqual(Int64(LListener.LocalAddr.Port), Int64(LClient.RemoteAddr.Port), 'client remote port');
  CheckEqual('127.0.0.1', LAccepted.LocalAddr.IP, 'accepted local ip');
  CheckEqual('127.0.0.1', LAccepted.RemoteAddr.IP, 'accepted remote ip');
  Check(LAccepted.RemoteAddr.Port > 0, 'accepted remote port > 0');
  LAccepted.Close;
  LClient.Close;
  LListener.Close;
end;

{ --- Test 15: Write deadline --- }

procedure TestWriteDeadline;
var
  LListener: ITcpListener;
  LClient: ITcpStream;
  LBuf: array[0..65535] of Byte;
  LGot: Boolean;
  LI: Integer;
begin
  LListener := TcpListen('127.0.0.1', 0);
  LClient := TcpConnect('127.0.0.1', LListener.LocalAddr.Port);
  { Set a very short write deadline }
  LClient.SetWriteDeadline(TDeadline.After(TDuration.FromMilliseconds(1)));
  { Wait for deadline to expire }
  platform_thread_sleep_ns(5000000);
  LGot := False;
  FillChar(LBuf[0], SizeOf(LBuf), $AA);
  try
    { Try to flood — eventually should hit deadline }
    for LI := 1 to 10000 do
      LClient.Write(LBuf[0], 65536);
  except
    on E: ENetworkError do
      LGot := True;
  end;
  Check(LGot, 'write deadline triggers');
  LClient.Close;
  LListener.Close;
end;

{ --- Main --- }

begin
  T := TTestRunner.Create('nextpas.core.net [deep]');
  T.Run('TCP connect+send+recv', @TestTcpConnectSendRecv);
  T.Run('TCP listen+accept', @TestTcpListenAccept);
  T.Run('Address parsing', @TestAddressParsing);
  T.Run('Socket options', @TestSocketOptions);
  T.Run('Connection refused', @TestConnectionRefused);
  T.Run('Read timeout', @TestReadTimeout);
  T.Run('Multiple connections', @TestMultipleConnections);
  T.Run('Close/shutdown', @TestCloseShutdown);
  T.Run('Empty send/recv', @TestEmptySendRecv);
  T.Run('Large transfer 64KB', @TestLargeTransfer);
  T.Run('UDP loopback', @TestUdpLoopback);
  T.Run('UDP multiple datagrams', @TestUdpMultipleDatagrams);
  T.Run('Resolve invalid', @TestResolveInvalid);
  T.Run('LocalAddr/RemoteAddr', @TestLocalRemoteAddr);
  T.Run('Write deadline', @TestWriteDeadline);
  T.Summary;
end.
