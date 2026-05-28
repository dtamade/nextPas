program test_platform_net;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.net.base,
  nextpas.core.platform.net,
  nextpas.core.platform.posix.ffi,
  nextpas.core.platform.linux.base,
  nextpas.core.testing;

var
  T: TTestRunner;

procedure TestCreateClose;
var
  S: TPlatformSocket;
begin
  Check(platform_socket_create(afInet4, stStream, spTCP, S) = 0, 'create TCP');
  Check(S.Value >= 0, 'valid fd');
  Check(platform_socket_close(S) = 0, 'close');
  Check(S.Value < 0, 'fd invalidated');
end;

procedure TestCreateUDP;
var
  S: TPlatformSocket;
begin
  Check(platform_socket_create(afInet4, stDgram, spUDP, S) = 0, 'create UDP');
  Check(platform_socket_close(S) = 0, 'close');
end;

procedure TestBindListen;
var
  S: TPlatformSocket;
  LAddr: TPlatformSockAddr;
begin
  Check(platform_socket_create(afInet4, stStream, spTCP, S) = 0, 'create');
  Check(platform_socket_setopt_int(S, SOL_SOCKET, SO_REUSEADDR, 1) = 0, 'reuseaddr');
  Check(platform_sockaddr_loopback4(0, LAddr) = 0, 'addr');
  Check(platform_socket_bind(S, LAddr) = 0, 'bind');
  Check(platform_socket_listen(S, 5) = 0, 'listen');
  Check(platform_socket_close(S) = 0, 'close');
end;

procedure TestConnectAcceptSendRecv;
var
  LServer, LClient, LAccepted: TPlatformSocket;
  LAddr, LClientAddr: TPlatformSockAddr;
  LBuf: array[0..31] of AnsiChar;
  LSent, LRecvd: PtrUInt;
  LServerAddr: TPlatformSockAddr;
  LAddrLen: Int32;
begin
  Check(platform_socket_create(afInet4, stStream, spTCP, LServer) = 0, 'server create');
  Check(platform_socket_setopt_int(LServer, SOL_SOCKET, SO_REUSEADDR, 1) = 0, 'reuseaddr');
  Check(platform_sockaddr_loopback4(0, LAddr) = 0, 'addr port 0');
  Check(platform_socket_bind(LServer, LAddr) = 0, 'bind');
  Check(platform_socket_listen(LServer, 5) = 0, 'listen');

  // Get assigned port
  LAddrLen := SizeOf(LServerAddr.Storage);
  FillChar(LServerAddr, SizeOf(LServerAddr), 0);
  getsockname(LServer.Value, @LServerAddr.Storage, @LAddrLen);
  LServerAddr.Len := LAddrLen;

  Check(platform_socket_create(afInet4, stStream, spTCP, LClient) = 0, 'client create');
  Check(platform_socket_connect(LClient, LServerAddr) = 0, 'connect');

  Check(platform_socket_accept(LServer, LAccepted, LClientAddr) = 0, 'accept');

  LBuf := 'hello net';
  Check(platform_socket_send(LClient, @LBuf[0], 9, LSent) = 0, 'send');
  Check(LSent = 9, 'sent 9 bytes');

  FillChar(LBuf, SizeOf(LBuf), 0);
  Check(platform_socket_recv(LAccepted, @LBuf[0], 32, LRecvd) = 0, 'recv');
  Check(LRecvd = 9, 'recv 9 bytes');
  Check(LBuf[0] = 'h', 'data[0]');
  Check(LBuf[4] = 'o', 'data[4]');

  platform_socket_close(LAccepted);
  platform_socket_close(LClient);
  platform_socket_close(LServer);
end;

procedure TestShutdown;
var
  LServer, LClient, LAccepted: TPlatformSocket;
  LAddr, LServerAddr, LClientAddr: TPlatformSockAddr;
  LBuf: array[0..7] of Byte;
  LRecvd: PtrUInt;
  LAddrLen: Int32;
begin
  Check(platform_socket_create(afInet4, stStream, spTCP, LServer) = 0, 'server');
  Check(platform_socket_setopt_int(LServer, SOL_SOCKET, SO_REUSEADDR, 1) = 0, 'opt');
  platform_sockaddr_loopback4(0, LAddr);
  platform_socket_bind(LServer, LAddr);
  platform_socket_listen(LServer, 5);

  LAddrLen := SizeOf(LServerAddr.Storage);
  FillChar(LServerAddr, SizeOf(LServerAddr), 0);
  getsockname(LServer.Value, @LServerAddr.Storage, @LAddrLen);
  LServerAddr.Len := LAddrLen;

  platform_socket_create(afInet4, stStream, spTCP, LClient);
  platform_socket_connect(LClient, LServerAddr);
  platform_socket_accept(LServer, LAccepted, LClientAddr);

  Check(platform_socket_shutdown(LClient, shWrite) = 0, 'shutdown write');
  Check(platform_socket_recv(LAccepted, @LBuf[0], 8, LRecvd) = 0, 'recv after shutdown');
  Check(LRecvd = 0, 'recv returns 0 = EOF');

  platform_socket_close(LAccepted);
  platform_socket_close(LClient);
  platform_socket_close(LServer);
end;

procedure TestUDPSendRecv;
var
  LSender, LRecver: TPlatformSocket;
  LAddr, LRecvAddr: TPlatformSockAddr;
  LBuf: array[0..31] of AnsiChar;
  LSent, LRecvd: PtrUInt;
  LAddrLen: Int32;
begin
  Check(platform_socket_create(afInet4, stDgram, spUDP, LRecver) = 0, 'create recver');
  Check(platform_sockaddr_loopback4(0, LAddr) = 0, 'addr');
  Check(platform_socket_bind(LRecver, LAddr) = 0, 'bind');

  LAddrLen := SizeOf(LRecvAddr.Storage);
  FillChar(LRecvAddr, SizeOf(LRecvAddr), 0);
  getsockname(LRecver.Value, @LRecvAddr.Storage, @LAddrLen);
  LRecvAddr.Len := LAddrLen;

  Check(platform_socket_create(afInet4, stDgram, spUDP, LSender) = 0, 'create sender');
  LBuf := 'udp test';
  Check(platform_socket_connect(LSender, LRecvAddr) = 0, 'connect udp');
  Check(platform_socket_send(LSender, @LBuf[0], 8, LSent) = 0, 'send');
  Check(LSent = 8, 'sent 8');

  FillChar(LBuf, SizeOf(LBuf), 0);
  Check(platform_socket_recv(LRecver, @LBuf[0], 32, LRecvd) = 0, 'recv');
  Check(LRecvd = 8, 'recv 8');
  Check(LBuf[0] = 'u', 'data[0]');

  platform_socket_close(LSender);
  platform_socket_close(LRecver);
end;

procedure TestDoubleClose;
var
  S: TPlatformSocket;
begin
  Check(platform_socket_create(afInet4, stStream, spTCP, S) = 0, 'create');
  Check(platform_socket_close(S) = 0, 'close first');
  Check(platform_socket_close(S) <> 0, 'close second error');
end;

procedure TestConnectRefused;
var
  S: TPlatformSocket;
  LAddr: TPlatformSockAddr;
  R: Int32;
begin
  Check(platform_socket_create(afInet4, stStream, spTCP, S) = 0, 'create');
  Check(platform_sockaddr_loopback4(1, LAddr) = 0, 'addr port 1');
  R := platform_socket_connect(S, LAddr);
  Check(R <> 0, 'connect to port 1 fails');
  platform_socket_close(S);
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.net');
  T.Run('create/close TCP', @TestCreateClose);
  T.Run('create/close UDP', @TestCreateUDP);
  T.Run('bind/listen', @TestBindListen);
  T.Run('connect/accept/send/recv', @TestConnectAcceptSendRecv);
  T.Run('shutdown', @TestShutdown);
  T.Run('UDP send/recv', @TestUDPSendRecv);
  T.Run('double close', @TestDoubleClose);
  T.Run('connect refused', @TestConnectRefused);
  T.Summary;
end.
