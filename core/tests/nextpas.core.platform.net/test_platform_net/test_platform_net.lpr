program test_platform_net;

{ nextPas Platform Net — focused-runtime test
  Now uses platform.socket (net layer merged into socket). }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.socket,
  nextpas.core.testing
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
  T: TTestRunner;

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
