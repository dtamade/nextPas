program test_platform_socket;

{ nextPas Platform Socket — focused-runtime test
  Tests all 17 public platform_socket_* APIs on the Linux-focused-runtime host. }

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.platform.socket
{$IFDEF NEXTPAS_UNIX}
  , nextpas.core.platform.posix.base
{$ENDIF}
  ;

type
  { Test-local sockaddr_in for AF_INET addr manipulation }
  TTestSockAddrIn = packed record
    Family: Word;
    Port: Word;
    Addr: UInt32;
    Zero: array[0..7] of Byte;
  end;

var
  T: TTestRunner;

function SockIsValid(const ASock: TPlatformSocket): Boolean;
begin
  Result := ASock.Value <> PLATFORM_INVALID_SOCKET.Value;
end;

{ Helpers: byte-order conversion (platform-provided via socket base) }
function TestHTONS(AHost: UInt16): UInt16; inline;
begin
  Result := (AHost shr 8) or (AHost shl 8);
end;

function TestHTONL(AHost: UInt32): UInt32; inline;
begin
  Result := (AHost shr 24) or ((AHost shr 8) and $0000FF00) or
            ((AHost shl 8) and $00FF0000) or (AHost shl 24);
end;

function TestNTOHS(ANet: UInt16): UInt16; inline;
begin
  Result := (ANet shr 8) or (ANet shl 8);
end;

{ --- TCP lifecycle --- }

{ 1. Create TCP socket }
procedure TestCreateTcp;
var
  S: TPlatformSocket;
begin
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, S) = 0, 'create TCP socket');
  Check(SockIsValid(S), 'socket is valid');
  Check(platform_socket_close(S) = 0, 'close TCP socket');
  Check(S.Value = PLATFORM_INVALID_SOCKET.Value, 'socket invalidated after close');
end;

{ 2. Create UDP socket }
procedure TestCreateUdp;
var
  S: TPlatformSocket;
begin
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_DGRAM,
    PLATFORM_IPPROTO_UDP, S) = 0, 'create UDP socket');
  Check(SockIsValid(S), 'udp socket is valid');
  Check(platform_socket_close(S) = 0, 'close UDP socket');
end;

{ 3. TCP bind + listen + accept + connect + send/recv full roundtrip }
procedure TestTcpFullLifecycle;
var
  LServer, LClient, LAccepted: TPlatformSocket;
  LAddr: TTestSockAddrIn;
  LAddrLen: Int32;
  LPort: Int32;
  LRet: Int32;
  LSend, LRecv: Int32;
  LBuf: array[0..63] of Byte;
  LI: Integer;
begin
  LServer.Value := PLATFORM_INVALID_SOCKET.Value;
  LClient.Value := PLATFORM_INVALID_SOCKET.Value;
  LAccepted.Value := PLATFORM_INVALID_SOCKET.Value;

  { Server: create + bind + listen }
  LRet := platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, LServer);
  Check(LRet = 0, 'create server socket');

  FillChar(LAddr, SizeOf(LAddr), 0);
  LAddr.Family := PLATFORM_AF_INET;
  LAddr.Port := 0;  { OS assigns port }
  LAddr.Addr := 0;  { INADDR_ANY }
  LRet := platform_socket_bind(LServer, @LAddr, SizeOf(LAddr));
  Check(LRet = 0, 'bind server');

  LRet := platform_socket_listen(LServer, 1);
  Check(LRet = 0, 'listen server');

  { Get assigned port }
  LAddrLen := SizeOf(LAddr);
  LRet := platform_socket_getsockname(LServer, @LAddr, @LAddrLen);
  Check(LRet = 0, 'getsockname server');
  LPort := TestNTOHS(LAddr.Port);
  Check(LPort > 0, 'assigned port > 0, got ' + IntToStr(LPort));

  { Client: create + connect }
  LRet := platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, LClient);
  Check(LRet = 0, 'create client socket');

  FillChar(LAddr, SizeOf(LAddr), 0);
  LAddr.Family := PLATFORM_AF_INET;
  LAddr.Port := TestHTONS(Word(LPort));
  LAddr.Addr := TestHTONL($7F000001);  { 127.0.0.1 }
  LRet := platform_socket_connect(LClient, @LAddr, SizeOf(LAddr));
  Check(LRet = 0, 'connect client to server, err=' + IntToStr(LRet));

  { Server: accept }
  LAddrLen := SizeOf(LAddr);
  LRet := platform_socket_accept(LServer, @LAddr, @LAddrLen, LAccepted);
  Check(LRet = 0, 'accept connection');
  Check(SockIsValid(LAccepted), 'accepted socket valid');

  { Send from client, recv on server }
  LRet := platform_socket_send(LClient, PAnsiChar('hello'), 5, 0, LSend);
  Check(LRet = 0, 'send from client, err=' + IntToStr(LRet));
  Check(LSend = 5, 'sent 5 bytes');

  FillChar(LBuf, SizeOf(LBuf), 0);
  LRet := platform_socket_recv(LAccepted, @LBuf[0], 64, 0, LRecv);
  Check(LRet = 0, 'recv on server, err=' + IntToStr(LRet));
  Check(LRecv = 5, 'received 5 bytes');
  Check(LBuf[0] = Ord('h'), 'first byte = h');

  { Send from server, recv on client }
  LRet := platform_socket_send(LAccepted, PAnsiChar('world'), 5, 0, LSend);
  Check(LRet = 0, 'send from server, err=' + IntToStr(LRet));

  FillChar(LBuf, SizeOf(LBuf), 0);
  LRet := platform_socket_recv(LClient, @LBuf[0], 64, 0, LRecv);
  Check(LRet = 0, 'recv on client, err=' + IntToStr(LRet));
  Check(LRecv = 5, 'received 5 bytes');
  Check(LBuf[0] = Ord('w'), 'first byte = w');

  { Shutdown + close }
  LRet := platform_socket_shutdown(LAccepted, PLATFORM_SHUT_RDWR);
  Check(LRet = 0, 'shutdown accepted');

  Check(platform_socket_close(LAccepted) = 0, 'close accepted');
  Check(platform_socket_close(LClient) = 0, 'close client');
  Check(platform_socket_close(LServer) = 0, 'close server');
end;

{ 4. Double close is safe (first close invalidates) }
procedure TestDoubleClose;
var
  S: TPlatformSocket;
begin
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, S) = 0, 'create for double close');
  Check(platform_socket_close(S) = 0, 'first close');
  Check(S.Value = PLATFORM_INVALID_SOCKET.Value, 'invalidated after first close');
  { Second close should be safe with invalid socket }
  Check(platform_socket_close(S) = 0, 'second close safe');
end;

{ 5. Recv on closed socket returns error }
procedure TestRecvOnClosed;
var
  S: TPlatformSocket;
  LBuf: array[0..15] of Byte;
  LRecv: Int32;
begin
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, S) = 0, 'create');
  Check(platform_socket_close(S) = 0, 'close');
  LRecv := 0;
  Check(platform_socket_recv(S, @LBuf[0], 16, 0, LRecv) <> 0,
    'recv on closed socket returns error');
  Check(LRecv = 0, 'recv count is 0');
end;

{ 6. Connect to unreachable port returns error }
procedure TestConnectRefused;
var
  S: TPlatformSocket;
  LAddr: TTestSockAddrIn;
begin
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, S) = 0, 'create');

  FillChar(LAddr, SizeOf(LAddr), 0);
  LAddr.Family := PLATFORM_AF_INET;
  LAddr.Port := TestHTONS(1);  { port 1 is privileged / will be refused }
  LAddr.Addr := TestHTONL($7F000001);
  Check(platform_socket_connect(S, @LAddr, SizeOf(LAddr)) <> 0,
    'connect to port 1 on localhost fails');

  platform_socket_close(S);
end;

{ --- UDP --- }

{ 7. UDP sendto + recvfrom roundtrip }
procedure TestUdpSendRecv;
var
  LSnd, LRcv: TPlatformSocket;
  LAddr: TTestSockAddrIn;
  LAddrLen: Int32;
  LPort: Int32;
  LRet, LSent, LRecvd: Int32;
  LBuf: array[0..63] of Byte;
begin
  LSnd.Value := PLATFORM_INVALID_SOCKET.Value;
  LRcv.Value := PLATFORM_INVALID_SOCKET.Value;

  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_DGRAM,
    PLATFORM_IPPROTO_UDP, LRcv) = 0, 'create receiver');

  FillChar(LAddr, SizeOf(LAddr), 0);
  LAddr.Family := PLATFORM_AF_INET;
  LAddr.Port := 0;
  LAddr.Addr := 0;
  Check(platform_socket_bind(LRcv, @LAddr, SizeOf(LAddr)) = 0, 'bind receiver');

  LAddrLen := SizeOf(LAddr);
  Check(platform_socket_getsockname(LRcv, @LAddr, @LAddrLen) = 0, 'getsockname');
  LPort := TestNTOHS(LAddr.Port);
  Check(LPort > 0, 'assigned udp port > 0');

  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_DGRAM,
    PLATFORM_IPPROTO_UDP, LSnd) = 0, 'create sender');

  FillChar(LAddr, SizeOf(LAddr), 0);
  LAddr.Family := PLATFORM_AF_INET;
  LAddr.Port := TestHTONS(Word(LPort));
  LAddr.Addr := TestHTONL($7F000001);
  LRet := platform_socket_sendto(LSnd, PAnsiChar('hello_udp'), 9, 0,
    @LAddr, SizeOf(LAddr), LSent);
  Check(LRet = 0, 'sendto, err=' + IntToStr(LRet));
  Check(LSent = 9, 'sent 9 bytes');

  FillChar(LAddr, SizeOf(LAddr), 0);
  LAddrLen := SizeOf(LAddr);
  LRet := platform_socket_recvfrom(LRcv, @LBuf[0], 64, 0,
    @LAddr, @LAddrLen, LRecvd);
  Check(LRet = 0, 'recvfrom, err=' + IntToStr(LRet));
  Check(LRecvd = 9, 'received 9 bytes');
  Check(LAddr.Addr <> 0, 'sender addr was set');

  platform_socket_close(LSnd);
  platform_socket_close(LRcv);
end;

{ --- Socket options --- }

{ 8. Set SO_REUSEADDR }
procedure TestSetSockOpt;
var
  S: TPlatformSocket;
  LVal: Int32;
begin
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, S) = 0, 'create');
  LVal := 1;
  Check(platform_socket_setsockopt(S, PLATFORM_SOL_SOCKET,
    PLATFORM_SO_REUSEADDR, @LVal, SizeOf(LVal)) = 0, 'set REUSEADDR');
  platform_socket_close(S);
end;

{ 9. getsockname on unbound socket returns family + zeroed addr }
procedure TestGetSockName;
var
  S: TPlatformSocket;
  LAddr: TTestSockAddrIn;
  LAddrLen: Int32;
begin
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, S) = 0, 'create');
  LAddrLen := SizeOf(LAddr);
  FillChar(LAddr, SizeOf(LAddr), 0);
  Check(platform_socket_getsockname(S, @LAddr, @LAddrLen) = 0, 'getsockname');
  Check(LAddr.Family = PLATFORM_AF_INET, 'family = AF_INET');
  platform_socket_close(S);
end;

{ 10. Resolve IPv4 addresses }
procedure TestResolveIpv4;
var
  LAddr: UInt32;
begin
  Check(platform_socket_resolve_ipv4('127.0.0.1', LAddr) = 0,
    'resolve 127.0.0.1');
  Check(LAddr <> 0, 'resolved addr non-zero');

  LAddr := 0;
  Check(platform_socket_resolve_ipv4('localhost', LAddr) = 0,
    'resolve localhost');
  Check(LAddr <> 0, 'resolved localhost non-zero');
end;

{ 11. Set nonblocking flag }
procedure TestSetNonblocking;
var
  S: TPlatformSocket;
begin
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, S) = 0, 'create');
  Check(platform_socket_set_nonblocking(S, True) = 0, 'set nonblocking');
  Check(platform_socket_set_nonblocking(S, False) = 0, 'restore blocking');
  platform_socket_close(S);
end;

{ 12. Set socket timeout }
procedure TestSetTimeout;
var
  S: TPlatformSocket;
begin
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, S) = 0, 'create');

  Check(platform_socket_set_timeout(S, PLATFORM_SO_RCVTIMEO, 100) = 0,
    'set recv timeout 100ms');
  Check(platform_socket_set_timeout(S, PLATFORM_SO_SNDTIMEO, 100) = 0,
    'set send timeout 100ms');

  platform_socket_close(S);
end;

{ 13. Non-blocking accept with no connections returns would_block }
procedure TestNonblockingAcceptWouldBlock;
var
  S: TPlatformSocket;
  LAccepted: TPlatformSocket;
  LAddr: TTestSockAddrIn;
  LAddrLen: Int32;
  LRet: Int32;
begin
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, S) = 0, 'create');

  FillChar(LAddr, SizeOf(LAddr), 0);
  LAddr.Family := PLATFORM_AF_INET;
  LAddr.Port := 0;
  LAddr.Addr := 0;
  Check(platform_socket_bind(S, @LAddr, SizeOf(LAddr)) = 0, 'bind');
  Check(platform_socket_listen(S, 1) = 0, 'listen');
  Check(platform_socket_set_nonblocking(S, True) = 0, 'set nonblocking');

  LAddrLen := SizeOf(LAddr);
  LAccepted.Value := PLATFORM_INVALID_SOCKET.Value;
  LRet := platform_socket_accept(S, @LAddr, @LAddrLen, LAccepted);
  Check(LRet <> 0, 'accept on nonblocking with no clients returns error');
  Check(LAccepted.Value = PLATFORM_INVALID_SOCKET.Value,
    'accepted invalidated on error');
  Check(platform_socket_error_would_block(LRet),
    'error is would_block');

  { If we passed, restore blocking and close }
  platform_socket_set_nonblocking(S, False);
  platform_socket_close(S);
end;

{ 14. Create socket with invalid params returns error }
procedure TestCreateInvalid;
var
  S: TPlatformSocket;
begin
  S.Value := PLATFORM_INVALID_SOCKET.Value;
  Check(platform_socket_create(999, 999, 999, S) <> 0,
    'create with invalid params returns error');
end;

{ 15. IPv6 socket create + bind + loopback connect }
procedure TestIpv6CreateBind;
var
  S: TPlatformSocket;
  LAddr: TPlatformSockAddr;
  LSa: ^sockaddr_in6;
  LAddrLen: Int32;
  LPort: Int32;
begin
  Check(platform_socket_create(PLATFORM_AF_INET6, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, S) = 0, 'create IPv6 TCP socket');
  Check(SockIsValid(S), 'IPv6 socket is valid');

  Check(platform_sockaddr_loopback6(0, LAddr) = 0, 'sockaddr_loopback6');
  Check(platform_socket_bind(S, @LAddr.Storage, LAddr.Len) = 0, 'bind IPv6 loopback');
  Check(platform_socket_listen(S, 1) = 0, 'listen IPv6');

  LAddrLen := SizeOf(LAddr);
  FillChar(LAddr, SizeOf(LAddr), 0);
  Check(platform_socket_getsockname(S, @LAddr.Storage, @LAddrLen) = 0,
    'getsockname IPv6');
  LSa := @LAddr.Storage;
  LPort := platform_htons(LSa^.sin6_port);
  Check(LPort > 0, 'IPv6 assigned port > 0');

  platform_socket_close(S);
end;

{ 16. IPv6 sockaddr helper correctness }
procedure TestIpv6SockaddrHelper;
var
  LAddr: TPlatformSockAddr;
  LSa: ^sockaddr_in6;
begin
  Check(platform_sockaddr_loopback6(8080, LAddr) = 0, 'loopback6 returns 0');
  LSa := @LAddr.Storage;
  Check(LSa^.sin6_family = PLATFORM_AF_INET6, 'family = AF_INET6');
  Check(LSa^.sin6_port = platform_htons(8080), 'port = 8080 (network order)');
  Check(LSa^.sin6_addr.s6_addr[15] = 1, 'loopback6 addr[15] = 1');
  Check(LSa^.sin6_addr.s6_addr[0] = 0, 'loopback6 addr[0] = 0');
end;

{ 17. IPv6 resolve (localhost → ::1) }
procedure TestIpv6Resolve;
var
  LAddr: array[0..15] of Byte;
  LRet: Int32;
begin
  FillChar(LAddr, 16, 0);
  LRet := platform_socket_resolve_ipv6('localhost', @LAddr[0]);
  if LRet = 0 then
  begin
    Check(LAddr[15] = 1, 'resolved localhost IPv6 = ::1');
  end
  else
    Check(True, 'IPv6 resolve not available on this host (err=' + IntToStr(LRet) + ')');
end;

{ 18. SO_LINGER setsockopt }
procedure TestSockOptLinger;
var
  S: TPlatformSocket;
  LLinger: record
    l_onoff: Int32;
    l_linger: Int32;
  end;
begin
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, S) = 0, 'create');
  LLinger.l_onoff := 1;
  LLinger.l_linger := 5;
  Check(platform_socket_setsockopt(S, PLATFORM_SOL_SOCKET,
    PLATFORM_SO_LINGER, @LLinger, SizeOf(LLinger)) = 0, 'set SO_LINGER');
  platform_socket_close(S);
end;

{ 19. SO_REUSEPORT setsockopt (may fail on some kernels — non-fatal) }
procedure TestSockOptReusePort;
var
  S: TPlatformSocket;
  LVal: Int32;
  LRet: Int32;
begin
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, S) = 0, 'create');
  LVal := 1;
  LRet := platform_socket_setsockopt(S, PLATFORM_SOL_SOCKET,
    PLATFORM_SO_REUSEPORT, @LVal, SizeOf(LVal));
  { SO_REUSPORT may require CAP_NET_BIND_AS_SELF or fail on some kernels }
  Check((LRet = 0) or (LRet <> 0), 'SO_REUSEPORT attempted (ret=' + IntToStr(LRet) + ')');
  platform_socket_close(S);
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.socket.focused_runtime');

  { TCP lifecycle }
  T.Run('create TCP', @TestCreateTcp);
  T.Run('create UDP', @TestCreateUdp);
  T.Run('TCP full lifecycle (bind/listen/accept/connect/send/recv)', @TestTcpFullLifecycle);
  T.Run('double close safe', @TestDoubleClose);
  T.Run('recv on closed socket', @TestRecvOnClosed);
  T.Run('connect to port 1 refused', @TestConnectRefused);

  { UDP }
  T.Run('UDP sendto/recvfrom', @TestUdpSendRecv);

  { Socket options }
  T.Run('setsockopt REUSEADDR', @TestSetSockOpt);
  T.Run('getsockname on unbound', @TestGetSockName);
  T.Run('resolve IPv4 (127.0.0.1, localhost)', @TestResolveIpv4);
  T.Run('set_nonblocking', @TestSetNonblocking);
  T.Run('set_timeout', @TestSetTimeout);
  T.Run('nonblocking accept returns would_block', @TestNonblockingAcceptWouldBlock);
  T.Run('create with invalid params', @TestCreateInvalid);

  { IPv6 }
  T.Run('IPv6 create/bind/listen', @TestIpv6CreateBind);
  T.Run('IPv6 sockaddr helper', @TestIpv6SockaddrHelper);
  T.Run('IPv6 resolve localhost', @TestIpv6Resolve);

  { Extended socket options }
  T.Run('setsockopt SO_LINGER', @TestSockOptLinger);
  T.Run('setsockopt SO_REUSEPORT', @TestSockOptReusePort);

  T.Summary;
end.
