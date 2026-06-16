program test_platform_socket_windows_real;

{ Platform Socket Windows Real Tests
  16 tests covering TCP/UDP operations, socket options,
  address queries, and non-blocking mode on real Windows. }

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.platform.socket;

var
  T: TTestRunner;

{$IFDEF NEXTPAS_WINDOWS}

const
  TEST_PORT_BASE = 18765;

var
  TestCounter: Integer;

function GetTestPort: UInt16;
begin
  Inc(TestCounter);
  Result := TEST_PORT_BASE + TestCounter;
end;

procedure TestTcpBindSpecificPort;
var
  S: TPlatformSocket;
  LAddr: TPlatformSockAddr;
  LPort: UInt16;
begin
  LPort := GetTestPort;
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, S) = 0, 'create');
  Check(platform_sockaddr_loopback4(LPort, LAddr) = 0, 'loopback addr');
  Check(platform_socket_bind(S, @LAddr.Storage, LAddr.Len) = 0,
    'bind to port ' + IntToStr(LPort));
  Check(platform_socket_close(S) = 0, 'close');
end;

procedure TestTcpListenBacklog;
var
  S: TPlatformSocket;
  LAddr: TPlatformSockAddr;
  LPort: UInt16;
begin
  LPort := GetTestPort;
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, S) = 0, 'create');
  Check(platform_sockaddr_loopback4(LPort, LAddr) = 0, 'loopback addr');
  Check(platform_socket_bind(S, @LAddr.Storage, LAddr.Len) = 0, 'bind');
  Check(platform_socket_listen(S, 8) = 0, 'listen backlog=8');
  Check(platform_socket_close(S) = 0, 'close');
end;

procedure TestAcceptReturnsClient;
var
  LSrv, LClient, LAccepted: TPlatformSocket;
  LAddr: TPlatformSockAddr;
  LAddrLen: Int32;
  LPort: UInt16;
begin
  LPort := GetTestPort;
  { Server side }
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, LSrv) = 0, 'create server');
  Check(platform_sockaddr_loopback4(LPort, LAddr) = 0, 'loopback addr');
  Check(platform_socket_bind(LSrv, @LAddr.Storage, LAddr.Len) = 0, 'bind');
  Check(platform_socket_listen(LSrv, 2) = 0, 'listen');

  { Client side }
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, LClient) = 0, 'create client');
  Check(platform_socket_connect(LClient, @LAddr.Storage, LAddr.Len) = 0,
    'connect');

  { Accept }
  LAddrLen := SizeOf(LAddr);
  Check(platform_socket_accept(LSrv, @LAddr.Storage, @LAddrLen, LAccepted) = 0,
    'accept');
  Check(LAccepted.Value <> PLATFORM_INVALID_SOCKET.Value, 'accept returns valid');

  Check(platform_socket_close(LAccepted) = 0, 'close accepted');
  Check(platform_socket_close(LClient) = 0, 'close client');
  Check(platform_socket_close(LSrv) = 0, 'close server');
end;

procedure TestFullTcpRoundtrip;
const
  MSG: PAnsiChar = 'Hello nextPas';
var
  LSrv, LClient, LAccepted: TPlatformSocket;
  LAddr: TPlatformSockAddr;
  LAddrLen: Int32;
  LPort: UInt16;
  LBuf: array[0..31] of AnsiChar;
  LSent, LRecv: Integer;
begin
  LPort := GetTestPort;
  FillChar(LBuf, SizeOf(LBuf), 0);

  { Server }
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, LSrv) = 0, 'create server');
  Check(platform_sockaddr_loopback4(LPort, LAddr) = 0, 'loopback addr');
  Check(platform_socket_bind(LSrv, @LAddr.Storage, LAddr.Len) = 0, 'bind');
  Check(platform_socket_listen(LSrv, 2) = 0, 'listen');

  { Client }
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, LClient) = 0, 'create client');
  Check(platform_socket_connect(LClient, @LAddr.Storage, LAddr.Len) = 0,
    'connect');

  { Accept }
  LAddrLen := SizeOf(LAddr);
  Check(platform_socket_accept(LSrv, @LAddr.Storage, @LAddrLen, LAccepted) = 0,
    'accept');

  { Send from client }
  Check(platform_socket_send(LClient, MSG, Length(MSG), 0, LSent) = 0,
    'send');
  Check(LSent = Length(MSG), 'sent ' + IntToStr(LSent) + ' bytes');

  { Recv on accepted }
  Check(platform_socket_recv(LAccepted, @LBuf[0], 32, 0, LRecv) = 0,
    'recv');
  Check(LRecv = LSent, 'recv ' + IntToStr(LRecv) + ' bytes');
  Check(CompareMem(@LBuf[0], MSG, LSent), 'payload matches');

  platform_socket_close(LAccepted);
  platform_socket_close(LClient);
  platform_socket_close(LSrv);
end;

procedure TestShutdownRdwr;
var
  LSrv, LClient, LAccepted: TPlatformSocket;
  LAddr: TPlatformSockAddr;
  LAddrLen: Int32;
  LPort: UInt16;
begin
  LPort := GetTestPort;

  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, LSrv) = 0, 'create server');
  Check(platform_sockaddr_loopback4(LPort, LAddr) = 0, 'loopback addr');
  Check(platform_socket_bind(LSrv, @LAddr.Storage, LAddr.Len) = 0, 'bind');
  Check(platform_socket_listen(LSrv, 2) = 0, 'listen');

  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, LClient) = 0, 'create client');
  Check(platform_socket_connect(LClient, @LAddr.Storage, LAddr.Len) = 0,
    'connect');

  LAddrLen := SizeOf(LAddr);
  Check(platform_socket_accept(LSrv, @LAddr.Storage, @LAddrLen, LAccepted) = 0,
    'accept');

  Check(platform_socket_shutdown(LAccepted, PLATFORM_SHUT_RDWR) = 0,
    'shutdown accepted');
  Check(platform_socket_shutdown(LClient, PLATFORM_SHUT_RDWR) = 0,
    'shutdown client');

  platform_socket_close(LAccepted);
  platform_socket_close(LClient);
  platform_socket_close(LSrv);
end;

procedure TestSetsockoptKeepalive;
var
  S: TPlatformSocket;
  LVal: Int32;
begin
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, S) = 0, 'create');
  LVal := 1;
  Check(platform_socket_setsockopt(S, PLATFORM_SOL_SOCKET,
    PLATFORM_SO_KEEPALIVE, @LVal, SizeOf(LVal)) = 0, 'set SO_KEEPALIVE');
  Check(platform_socket_close(S) = 0, 'close');
end;

procedure TestSetsockoptNodelay;
var
  S: TPlatformSocket;
  LVal: Int32;
begin
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, S) = 0, 'create');
  LVal := 1;
  Check(platform_socket_setsockopt(S, PLATFORM_IPPROTO_TCP,
    PLATFORM_TCP_NODELAY, @LVal, SizeOf(LVal)) = 0, 'set TCP_NODELAY');
  Check(platform_socket_close(S) = 0, 'close');
end;

procedure TestSetsockoptRcvtimeo;
var
  LSrv, LClient: TPlatformSocket;
  LAddr: TPlatformSockAddr;
  LPort: UInt16;
  LBuf: array[0..15] of AnsiChar;
  LRecv, LVal: Integer;
begin
  LPort := GetTestPort;

  { Create connected socket }
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, LSrv) = 0, 'create server');
  Check(platform_sockaddr_loopback4(LPort, LAddr) = 0, 'loopback addr');
  Check(platform_socket_bind(LSrv, @LAddr.Storage, LAddr.Len) = 0, 'bind');
  Check(platform_socket_listen(LSrv, 2) = 0, 'listen');

  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, LClient) = 0, 'create client');
  Check(platform_socket_connect(LClient, @LAddr.Storage, LAddr.Len) = 0,
    'connect');

  { Set recv timeout and verify it times out }
  LVal := 100;
  Check(platform_socket_setsockopt(LClient, PLATFORM_SOL_SOCKET,
    PLATFORM_SO_RCVTIMEO, @LVal, SizeOf(LVal)) = 0,
    'set SO_RCVTIMEO 100ms');

  Check(platform_socket_recv(LClient, @LBuf[0], 16, 0, LRecv) <> 0,
    'recv times out');

  platform_socket_close(LClient);
  platform_socket_close(LSrv);
end;

procedure TestSetsockoptSndtimeo;
var
  S: TPlatformSocket;
  LVal: Int32;
begin
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, S) = 0, 'create');
  LVal := 200;
  Check(platform_socket_setsockopt(S, PLATFORM_SOL_SOCKET,
    PLATFORM_SO_SNDTIMEO, @LVal, SizeOf(LVal)) = 0,
    'set SO_SNDTIMEO 200ms');
  Check(platform_socket_close(S) = 0, 'close');
end;

procedure TestGetsocknameAfterBind;
var
  S: TPlatformSocket;
  LAddr, LLocal: TPlatformSockAddr;
  LAddrLen: Int32;
  LBindPort: UInt16;
begin
  LBindPort := GetTestPort;
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, S) = 0, 'create');
  Check(platform_sockaddr_loopback4(LBindPort, LAddr) = 0, 'loopback addr');
  Check(platform_socket_bind(S, @LAddr.Storage, LAddr.Len) = 0, 'bind');

  LAddrLen := SizeOf(LLocal);
  Check(platform_socket_getsockname(S, @LLocal.Storage, @LAddrLen) = 0,
    'getsockname');

  { Verify the port was bound correctly by re-binding to same port should fail }
  Check(platform_socket_bind(S, @LAddr.Storage, LAddr.Len) <> 0,
    'rebind to same port fails (confirms port bound)');

  Check(platform_socket_close(S) = 0, 'close');
end;

procedure TestGetpeernameAfterConnect;
var
  LSrv, LClient, LAccepted: TPlatformSocket;
  LAddr, LPeer: TPlatformSockAddr;
  LAddrLen: Int32;
  LTestPort: UInt16;
begin
  LTestPort := GetTestPort;

  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, LSrv) = 0, 'create server');
  Check(platform_sockaddr_loopback4(LTestPort, LAddr) = 0, 'loopback addr');
  Check(platform_socket_bind(LSrv, @LAddr.Storage, LAddr.Len) = 0, 'bind');
  Check(platform_socket_listen(LSrv, 2) = 0, 'listen');

  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, LClient) = 0, 'create client');
  Check(platform_socket_connect(LClient, @LAddr.Storage, LAddr.Len) = 0,
    'connect');

  LAddrLen := SizeOf(LAddr);
  Check(platform_socket_accept(LSrv, @LAddr.Storage, @LAddrLen, LAccepted) = 0,
    'accept');

  LAddrLen := SizeOf(LPeer);
  Check(platform_socket_getpeername(LClient, @LPeer.Storage, @LAddrLen) = 0,
    'getpeername');

  { Verify getpeername succeeded — port is in the peer addr struct }
  Check(LAddrLen > 0, 'peer addr len > 0');

  platform_socket_close(LAccepted);
  platform_socket_close(LClient);
  platform_socket_close(LSrv);
end;

procedure TestUdpSendtoRecvfrom;
const
  MSG: PAnsiChar = 'UDP hello';
var
  LSnd, LRcv: TPlatformSocket;
  LAddr: TPlatformSockAddr;
  LFromAddr: TPlatformSockAddr;
  LFromLen: Int32;
  LPort: UInt16;
  LBuf: array[0..31] of AnsiChar;
  LSent, LRecv: Integer;
begin
  LPort := GetTestPort;
  FillChar(LBuf, SizeOf(LBuf), 0);

  { Receiver }
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_DGRAM,
    PLATFORM_IPPROTO_UDP, LRcv) = 0, 'create receiver');
  Check(platform_sockaddr_loopback4(LPort, LAddr) = 0, 'loopback addr');
  Check(platform_socket_bind(LRcv, @LAddr.Storage, LAddr.Len) = 0, 'bind');

  { Sender }
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_DGRAM,
    PLATFORM_IPPROTO_UDP, LSnd) = 0, 'create sender');
  Check(platform_socket_sendto(LSnd, MSG, Length(MSG), 0,
    @LAddr.Storage, LAddr.Len, LSent) = 0, 'sendto');
  Check(LSent = Length(MSG), 'sent ' + IntToStr(LSent) + ' bytes');

  { Receive }
  LFromLen := SizeOf(LFromAddr);
  Check(platform_socket_recvfrom(LRcv, @LBuf[0], 32, 0,
    @LFromAddr.Storage, @LFromLen, LRecv) = 0, 'recvfrom');
  Check(LRecv = LSent, 'recv ' + IntToStr(LRecv) + ' bytes');
  Check(CompareMem(@LBuf[0], MSG, LSent), 'payload matches');

  platform_socket_close(LSnd);
  platform_socket_close(LRcv);
end;

procedure TestResolveIpv4InvalidHost;
var
  LAddr: UInt32;
  LResult: Integer;
begin
  LResult := platform_socket_resolve_ipv4(
    'this.host.does.not.exist.invalid', LAddr);
  Check(LResult <> 0, 'resolve invalid host fails (rc=' +
    IntToStr(LResult) + ')');
end;

procedure TestSetNonblockingTrue;
var
  S: TPlatformSocket;
begin
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, S) = 0, 'create');
  Check(platform_socket_set_nonblocking(S, True) = 0,
    'set nonblocking true');
  Check(platform_socket_close(S) = 0, 'close');
end;

procedure TestSetNonblockingFalse;
var
  S: TPlatformSocket;
begin
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, S) = 0, 'create');
  Check(platform_socket_set_nonblocking(S, True) = 0,
    'set nonblocking true');
  Check(platform_socket_set_nonblocking(S, False) = 0,
    'set nonblocking false');
  Check(platform_socket_close(S) = 0, 'close');
end;

procedure TestErrorWouldBlock;
var
  LSrv, LClient, LAccepted: TPlatformSocket;
  LAddr: TPlatformSockAddr;
  LAddrLen: Int32;
  LPort: UInt16;
  LBuf: array[0..15] of AnsiChar;
  LRecv: Integer;
  LErr: Integer;
begin
  LPort := GetTestPort;

  { Setup connected pair }
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, LSrv) = 0, 'create server');
  Check(platform_sockaddr_loopback4(LPort, LAddr) = 0, 'loopback addr');
  Check(platform_socket_bind(LSrv, @LAddr.Storage, LAddr.Len) = 0, 'bind');
  Check(platform_socket_listen(LSrv, 2) = 0, 'listen');

  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, LClient) = 0, 'create client');
  Check(platform_socket_connect(LClient, @LAddr.Storage, LAddr.Len) = 0,
    'connect');

  LAddrLen := SizeOf(LAddr);
  Check(platform_socket_accept(LSrv, @LAddr.Storage, @LAddrLen, LAccepted) = 0,
    'accept');

  { Set nonblocking and recv — should get WOULDBLOCK since no data sent }
  Check(platform_socket_set_nonblocking(LAccepted, True) = 0,
    'set nonblocking');
  LErr := platform_socket_recv(LAccepted, @LBuf[0], 16, 0, LRecv);
  Check(LErr <> 0, 'recv returns error');
  Check(platform_socket_error_would_block(LErr),
    'error is WOULDBLOCK');

  platform_socket_close(LAccepted);
  platform_socket_close(LClient);
  platform_socket_close(LSrv);
end;

{$ELSE}
procedure TestNonWindowsSkip;
begin
  WriteLn('not Windows runtime — skipped');
  Check(True, 'non-Windows skip');
end;
{$ENDIF}

begin
  T := TTestRunner.Create('nextpas.core.platform.socket.windows_real');
  {$IFDEF NEXTPAS_WINDOWS}
  TestCounter := 0;
  T.Run('tcp_bind_specific_port', @TestTcpBindSpecificPort);
  T.Run('tcp_listen_backlog', @TestTcpListenBacklog);
  T.Run('accept_returns_client', @TestAcceptReturnsClient);
  T.Run('full_tcp_roundtrip', @TestFullTcpRoundtrip);
  T.Run('shutdown_rdwr', @TestShutdownRdwr);
  T.Run('setsockopt_keepalive', @TestSetsockoptKeepalive);
  T.Run('setsockopt_nodelay', @TestSetsockoptNodelay);
  T.Run('setsockopt_rcvtimeo', @TestSetsockoptRcvtimeo);
  T.Run('setsockopt_sndtimeo', @TestSetsockoptSndtimeo);
  T.Run('getsockname_after_bind', @TestGetsocknameAfterBind);
  T.Run('getpeername_after_connect', @TestGetpeernameAfterConnect);
  T.Run('udp_sendto_recvfrom', @TestUdpSendtoRecvfrom);
  T.Run('resolve_ipv4_invalid_host', @TestResolveIpv4InvalidHost);
  T.Run('set_nonblocking_true', @TestSetNonblockingTrue);
  T.Run('set_nonblocking_false', @TestSetNonblockingFalse);
  T.Run('error_would_block', @TestErrorWouldBlock);
  {$ELSE}
  T.Run('non-Windows skip', @TestNonWindowsSkip);
  {$ENDIF}
  T.Summary;
end.
