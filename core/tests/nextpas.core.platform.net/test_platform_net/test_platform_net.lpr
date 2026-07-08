program test_platform_net;

{ nextPas Platform Net — focused-runtime test
  Now uses platform.socket (net layer merged into socket). }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.socket,
  nextpas.core.test
{$IFDEF NEXTPAS_UNIX}
  , nextpas.core.platform.posix.base,
    nextpas.core.platform.posix.ffi
{$ENDIF}
{$IFDEF NEXTPAS_WINDOWS}
  , nextpas.core.platform.windows.base,
    nextpas.core.platform.windows.ffi
{$ENDIF}
  ;

var
  T: TTestSuite;

function GetBoundSocketAddress(const ASock: TPlatformSocket;
  out AAddr: TPlatformSockAddr): Int32;
var
  LAddrLen: Int32;
begin
  LAddrLen := SizeOf(AAddr.Storage);
  FillChar(AAddr, SizeOf(AAddr), 0);
{$IFDEF NEXTPAS_UNIX}
  Result := getsockname(ASock.Value, @AAddr.Storage, @LAddrLen);
{$ENDIF}
{$IFDEF NEXTPAS_WINDOWS}
  Result := winsock_getsockname(ASock.Value, @AAddr.Storage, @LAddrLen);
{$ENDIF}
{$IF not defined(NEXTPAS_UNIX) and not defined(NEXTPAS_WINDOWS)}
  Result := -1;
{$ENDIF}
  if Result = 0 then
    AAddr.Len := LAddrLen;
end;

function SocketIsValid(const ASock: TPlatformSocket): Boolean;
begin
  Result := ASock.Value <> PLATFORM_INVALID_SOCKET.Value;
end;

function SocketIsInvalid(const ASock: TPlatformSocket): Boolean;
begin
  Result := not SocketIsValid(ASock);
end;

procedure TestCreateClose;
var
  S: TPlatformSocket;
begin
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, S) = 0, 'create TCP');
  Check(SocketIsValid(S), 'valid socket');
  Check(platform_socket_close(S) = 0, 'close');
  Check(SocketIsInvalid(S), 'socket invalidated');
end;

procedure TestCreateUDP;
var
  S: TPlatformSocket;
begin
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_DGRAM,
    PLATFORM_IPPROTO_UDP, S) = 0, 'create UDP');
  Check(platform_socket_close(S) = 0, 'close');
end;

procedure TestBindListen;
var
  S: TPlatformSocket;
  LAddr: TPlatformSockAddr;
  LVal: Int32;
begin
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, S) = 0, 'create');
  LVal := 1;
  Check(platform_socket_setsockopt(S, PLATFORM_SOL_SOCKET,
    PLATFORM_SO_REUSEADDR, @LVal, SizeOf(LVal)) = 0, 'reuseaddr');
  Check(platform_sockaddr_loopback4(0, LAddr) = 0, 'addr');
  Check(platform_socket_bind(S, @LAddr.Storage, LAddr.Len) = 0, 'bind');
  Check(platform_socket_listen(S, 5) = 0, 'listen');
  Check(platform_socket_close(S) = 0, 'close');
end;

procedure TestConnectAcceptSendRecv;
var
  LServer, LClient, LAccepted: TPlatformSocket;
  LAddr, LClientAddr: TPlatformSockAddr;
  LBuf: array[0..31] of AnsiChar;
  LSent, LRecvd: Int32;
  LServerAddr: TPlatformSockAddr;
begin
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, LServer) = 0, 'server create');
  Check(platform_sockaddr_loopback4(0, LAddr) = 0, 'addr port 0');
  Check(platform_socket_bind(LServer, @LAddr.Storage, LAddr.Len) = 0, 'bind');
  Check(platform_socket_listen(LServer, 5) = 0, 'listen');

  Check(GetBoundSocketAddress(LServer, LServerAddr) = 0, 'assigned server port');

  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, LClient) = 0, 'client create');
  Check(platform_socket_connect(LClient, @LServerAddr.Storage,
    LServerAddr.Len) = 0, 'connect');

  FillChar(LClientAddr, SizeOf(LClientAddr), 0);
  Check(platform_socket_accept(LServer, @LClientAddr.Storage,
    @LClientAddr.Len, LAccepted) = 0, 'accept');

  LBuf := 'hello net';
  Check(platform_socket_send(LClient, @LBuf[0], 9, 0, LSent) = 0, 'send');
  Check(LSent = 9, 'sent 9 bytes');

  FillChar(LBuf, SizeOf(LBuf), 0);
  Check(platform_socket_recv(LAccepted, @LBuf[0], 32, 0, LRecvd) = 0, 'recv');
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
  LRecvd: Int32;
begin
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, LServer) = 0, 'server');
  platform_sockaddr_loopback4(0, LAddr);
  platform_socket_bind(LServer, @LAddr.Storage, LAddr.Len);
  platform_socket_listen(LServer, 5);

  Check(GetBoundSocketAddress(LServer, LServerAddr) = 0, 'assigned server port');

  platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, LClient);
  platform_socket_connect(LClient, @LServerAddr.Storage, LServerAddr.Len);
  FillChar(LClientAddr, SizeOf(LClientAddr), 0);
  platform_socket_accept(LServer, @LClientAddr.Storage, @LClientAddr.Len, LAccepted);

  Check(platform_socket_shutdown(LClient, PLATFORM_SHUT_WR) = 0,
    'shutdown write');
  Check(platform_socket_recv(LAccepted, @LBuf[0], 8, 0, LRecvd) = 0,
    'recv after shutdown');
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
  LSent, LRecvd: Int32;
begin
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_DGRAM,
    PLATFORM_IPPROTO_UDP, LRecver) = 0, 'create recver');
  Check(platform_sockaddr_loopback4(0, LAddr) = 0, 'addr');
  Check(platform_socket_bind(LRecver, @LAddr.Storage, LAddr.Len) = 0, 'bind');

  Check(GetBoundSocketAddress(LRecver, LRecvAddr) = 0, 'assigned receiver port');

  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_DGRAM,
    PLATFORM_IPPROTO_UDP, LSender) = 0, 'create sender');
  LBuf := 'udp test';
  Check(platform_socket_connect(LSender, @LRecvAddr.Storage,
    LRecvAddr.Len) = 0, 'connect udp');
  Check(platform_socket_send(LSender, @LBuf[0], 8, 0, LSent) = 0, 'send');
  Check(LSent = 8, 'sent 8');

  FillChar(LBuf, SizeOf(LBuf), 0);
  Check(platform_socket_recv(LRecver, @LBuf[0], 32, 0, LRecvd) = 0, 'recv');
  Check(LRecvd = 8, 'recv 8');
  Check(LBuf[0] = 'u', 'data[0]');

  platform_socket_close(LSender);
  platform_socket_close(LRecver);
end;

procedure TestDoubleClose;
var
  S: TPlatformSocket;
begin
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, S) = 0, 'create');
  Check(platform_socket_close(S) = 0, 'close first');
  Check(platform_socket_close(S) = 0, 'close second (safe no-op)');
end;

procedure TestConnectRefused;
var
  S: TPlatformSocket;
  LAddr: TPlatformSockAddr;
  R: Int32;
begin
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, S) = 0, 'create');
  Check(platform_sockaddr_loopback4(1, LAddr) = 0, 'addr port 1');
  R := platform_socket_connect(S, @LAddr.Storage, LAddr.Len);
  Check(R <> 0, 'connect to port 1 fails');
  platform_socket_close(S);
end;

procedure TestIpv6UdpSendRecv;
var
  LSender, LRecver: TPlatformSocket;
  LAddr, LRecvAddr: TPlatformSockAddr;
  LBuf: array[0..31] of AnsiChar;
  LSent, LRecvd: Int32;
begin
  Check(platform_socket_create(PLATFORM_AF_INET6, PLATFORM_SOCK_DGRAM,
    PLATFORM_IPPROTO_UDP, LRecver) = 0, 'create ipv6 recver');
  Check(platform_sockaddr_loopback6(0, LAddr) = 0, 'ipv6 addr');
  if platform_socket_bind(LRecver, @LAddr.Storage, LAddr.Len) <> 0 then
  begin
    platform_socket_close(LRecver);
    Check(True, 'IPv6 not available, skipped');
    Exit;
  end;

  LRecvAddr.Len := SizeOf(LRecvAddr.Storage);
  FillChar(LRecvAddr.Storage, SizeOf(LRecvAddr.Storage), 0);
  Check(platform_socket_getsockname(LRecver, @LRecvAddr.Storage,
    @LRecvAddr.Len) = 0, 'getsockname ipv6');

  Check(platform_socket_create(PLATFORM_AF_INET6, PLATFORM_SOCK_DGRAM,
    PLATFORM_IPPROTO_UDP, LSender) = 0, 'create ipv6 sender');
  LBuf := 'ipv6_udp';
  Check(platform_socket_sendto(LSender, @LBuf[0], 8, 0,
    @LRecvAddr.Storage, LRecvAddr.Len, LSent) = 0, 'sendto ipv6');
  Check(LSent = 8, 'sent 8');

  FillChar(LBuf, SizeOf(LBuf), 0);
  Check(platform_socket_recvfrom(LRecver, @LBuf[0], 32, 0,
    @LRecvAddr.Storage, @LRecvAddr.Len, LRecvd) = 0, 'recvfrom ipv6');
  Check(LRecvd = 8, 'recv 8');
  Check(LBuf[0] = 'i', 'data[0]');

  platform_socket_close(LSender);
  platform_socket_close(LRecver);
end;

procedure TestCreateInvalidFamily;
var
  S: TPlatformSocket;
begin
  { Invalid address family should fail }
  Check(platform_socket_create(999, PLATFORM_SOCK_STREAM, 0, S) <> 0,
    'invalid family returns error');
end;

procedure TestCreateInvalidType;
var
  S: TPlatformSocket;
begin
  { Invalid socket type should fail }
  Check(platform_socket_create(PLATFORM_AF_INET, 999, 0, S) <> 0,
    'invalid type returns error');
end;

procedure TestShutdownInvalidSocket;
var
  S: TPlatformSocket;
begin
  { Shutdown on closed socket should fail gracefully }
  S.Value := -1;
  platform_socket_shutdown(S, PLATFORM_SHUT_WR);
  Check(True, 'shutdown on invalid socket did not crash');
end;

procedure TestIpv4SendtoRecvfrom;
var
  LSender, LRecver: TPlatformSocket;
  LAddr, LRecvAddr: TPlatformSockAddr;
  LBuf: array[0..31] of AnsiChar;
  LSent, LRecvd: Int32;
begin
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_DGRAM,
    PLATFORM_IPPROTO_UDP, LRecver) = 0, 'create recver');
  Check(platform_sockaddr_loopback4(0, LAddr) = 0, 'addr');
  Check(platform_socket_bind(LRecver, @LAddr.Storage, LAddr.Len) = 0, 'bind');

  Check(GetBoundSocketAddress(LRecver, LRecvAddr) = 0, 'assigned receiver port');

  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_DGRAM,
    PLATFORM_IPPROTO_UDP, LSender) = 0, 'create sender');
  LBuf := 'v4_sendto';
  Check(platform_socket_sendto(LSender, @LBuf[0], 9, 0,
    @LRecvAddr.Storage, LRecvAddr.Len, LSent) = 0, 'sendto');
  Check(LSent = 9, 'sent 9');

  FillChar(LBuf, SizeOf(LBuf), 0);
  Check(platform_socket_recvfrom(LRecver, @LBuf[0], 32, 0,
    @LRecvAddr.Storage, @LRecvAddr.Len, LRecvd) = 0, 'recvfrom');
  Check(LRecvd = 9, 'recv 9');
  Check(LBuf[0] = 'v', 'data[0]');

  platform_socket_close(LSender);
  platform_socket_close(LRecver);
end;

procedure TestGetsocknameOnAccepted;
var
  LServer, LClient, LAccepted: TPlatformSocket;
  LAddr, LServerAddr, LAcceptedAddr, LClientAddr: TPlatformSockAddr;
begin
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, LServer) = 0, 'server create');
  Check(platform_sockaddr_loopback4(0, LAddr) = 0, 'addr port 0');
  Check(platform_socket_bind(LServer, @LAddr.Storage, LAddr.Len) = 0, 'bind');
  Check(platform_socket_listen(LServer, 5) = 0, 'listen');

  Check(GetBoundSocketAddress(LServer, LServerAddr) = 0, 'server port');

  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, LClient) = 0, 'client create');
  Check(platform_socket_connect(LClient, @LServerAddr.Storage,
    LServerAddr.Len) = 0, 'connect');

  FillChar(LAcceptedAddr, SizeOf(LAcceptedAddr), 0);
  Check(platform_socket_accept(LServer, @LAcceptedAddr.Storage,
    @LAcceptedAddr.Len, LAccepted) = 0, 'accept');

  { accepted socket should have a local address }
  FillChar(LAcceptedAddr, SizeOf(LAcceptedAddr), 0);
  LAcceptedAddr.Len := SizeOf(LAcceptedAddr.Storage);
  Check(platform_socket_getsockname(LAccepted, @LAcceptedAddr.Storage,
    @LAcceptedAddr.Len) = 0, 'getsockname on accepted');

  { client should know its peer }
  FillChar(LClientAddr, SizeOf(LClientAddr), 0);
  LClientAddr.Len := SizeOf(LClientAddr.Storage);
  Check(platform_socket_getpeername(LClient, @LClientAddr.Storage,
    @LClientAddr.Len) = 0, 'getpeername on client');

  platform_socket_close(LAccepted);
  platform_socket_close(LClient);
  platform_socket_close(LServer);
end;

procedure TestTcpSendtoFails;
var
  LServer, LClient: TPlatformSocket;
  LAddr, LServerAddr: TPlatformSockAddr;
  LSent: Int32;
  LBuf: array[0..7] of AnsiChar;
begin
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, LServer) = 0, 'server create');
  Check(platform_sockaddr_loopback4(0, LAddr) = 0, 'addr');
  Check(platform_socket_bind(LServer, @LAddr.Storage, LAddr.Len) = 0, 'bind');
  Check(platform_socket_listen(LServer, 5) = 0, 'listen');

  Check(GetBoundSocketAddress(LServer, LServerAddr) = 0, 'server port');

  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, LClient) = 0, 'client create');
  Check(platform_socket_connect(LClient, @LServerAddr.Storage,
    LServerAddr.Len) = 0, 'connect');

  { sendto on a connected TCP socket should still work (address is ignored) }
  LBuf := 'tcp_sto';
  Check(platform_socket_sendto(LClient, @LBuf[0], 7, 0,
    @LServerAddr.Storage, LServerAddr.Len, LSent) = 0, 'sendto on TCP');
  Check(LSent = 7, 'sent 7');

  platform_socket_close(LClient);
  platform_socket_close(LServer);
end;

procedure TestLoopback4Addr;
var
  LAddr: TPlatformSockAddr;
begin
  Check(platform_sockaddr_loopback4(8080, LAddr) = 0, 'loopback4 port 8080');
  Check(LAddr.Len > 0, 'addr len > 0');
end;

procedure TestLoopback6Addr;
var
  LAddr: TPlatformSockAddr;
begin
  Check(platform_sockaddr_loopback6(9090, LAddr) = 0, 'loopback6 port 9090');
  Check(LAddr.Len > 0, 'addr len > 0');
end;

procedure TestErrorWouldBlock;
var
  S: TPlatformSocket;
begin
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, S) = 0, 'create');
  Check(not platform_socket_error_would_block(0), '0 is not would_block');
  Check(not platform_socket_error_would_block(-1), '-1 is not would_block');
  platform_socket_close(S);
end;

begin
  T := TTestSuite.Create('nextpas.core.platform.net');
  T.Test('create/close TCP', @TestCreateClose);
  T.Test('create/close UDP', @TestCreateUDP);
  T.Test('bind/listen', @TestBindListen);
  T.Test('connect/accept/send/recv', @TestConnectAcceptSendRecv);
  T.Test('shutdown', @TestShutdown);
  T.Test('UDP send/recv', @TestUDPSendRecv);
  T.Test('double close', @TestDoubleClose);
  T.Test('connect refused', @TestConnectRefused);
  T.Test('IPv6 UDP send/recv', @TestIpv6UdpSendRecv);
  T.Test('create invalid family', @TestCreateInvalidFamily);
  T.Test('create invalid type', @TestCreateInvalidType);
  T.Test('shutdown invalid socket', @TestShutdownInvalidSocket);
  T.Test('loopback4 addr', @TestLoopback4Addr);
  T.Test('loopback6 addr', @TestLoopback6Addr);
  T.Test('IPv4 sendto/recvfrom', @TestIpv4SendtoRecvfrom);
  T.Test('getsockname on accepted', @TestGetsocknameOnAccepted);
  T.Test('TCP sendto works', @TestTcpSendtoFails);
  T.Test('error_would_block classification', @TestErrorWouldBlock);
  if not T.Run then Halt(1);
end.
