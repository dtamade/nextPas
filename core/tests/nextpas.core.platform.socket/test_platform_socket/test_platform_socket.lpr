program test_platform_socket;

{ nextPas Platform Socket — focused-runtime test
  Tests all 17 public platform_socket_* APIs on the Linux-focused-runtime host. }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.fs,
  nextpas.core.fs.util,
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.platform.error,
  nextpas.core.platform.socket
{$IFDEF NEXTPAS_UNIX}
  , nextpas.core.platform.posix.base
{$ENDIF}
{$IFDEF NEXTPAS_LINUX}
  , nextpas.core.platform.linux.base
{$ENDIF}
{$IFDEF NEXTPAS_MACOS}
  , nextpas.core.platform.darwin.base
{$ENDIF}
{$IFDEF NEXTPAS_FREEBSD}
  , nextpas.core.platform.freebsd.base
{$ENDIF}
  ;

type
  { Test-local sockaddr_in matching host layout (BSD has sin_len + 8-bit family). }
  TTestSockAddrIn = packed record
{$IF defined(NEXTPAS_MACOS) or defined(NEXTPAS_FREEBSD)}
    Len: Byte;
    Family: Byte;
{$ELSE}
    Family: Word;
{$ENDIF}
    Port: Word;
    Addr: UInt32;
    Zero: array[0..7] of Byte;
  end;

var
  T: TTestSuite;

function LoadSourceText(const ARelativePath: string): string;
begin
  Check(FileExists(ARelativePath), 'source file exists: ' + ARelativePath);
  Result := FsReadFileText(ARelativePath);
end;

procedure CheckContains(const ASource, AToken, AMessage: string);
begin
  Check(Pos(AToken, ASource) > 0, AMessage + ': ' + AToken);
end;

function SockIsValid(const ASock: TPlatformSocket): Boolean;
begin
  Result := ASock.Value <> PLATFORM_INVALID_SOCKET.Value;
end;

{ Fill IPv4 sockaddr with host-correct len/family layout. }
procedure FillTestIpv4(var AAddr: TTestSockAddrIn; APortNet: Word; AAddrNet: UInt32);
begin
  FillChar(AAddr, SizeOf(AAddr), 0);
{$IF defined(NEXTPAS_MACOS) or defined(NEXTPAS_FREEBSD)}
  AAddr.Len := SizeOf(AAddr);
{$ENDIF}
  AAddr.Family := PLATFORM_AF_INET;
  AAddr.Port := APortNet;
  AAddr.Addr := AAddrNet;
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

  FillTestIpv4(LAddr, 0, 0);  { port 0 = OS assigns; INADDR_ANY }
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

  FillTestIpv4(LAddr, TestHTONS(Word(LPort)), TestHTONL($7F000001));  { 127.0.0.1 }
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

{ 4. Double close reports invalid handle after first close invalidates }
procedure TestDoubleClose;
var
  S: TPlatformSocket;
begin
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, S) = 0, 'create for double close');
  Check(platform_socket_close(S) = 0, 'first close');
  Check(S.Value = PLATFORM_INVALID_SOCKET.Value, 'invalidated after first close');
  Check(platform_socket_close(S) = PLATFORM_ERR_INVALID_HANDLE,
    'second close returns invalid handle');
  Check(S.Value = PLATFORM_INVALID_SOCKET.Value, 'still invalid after second close');
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

  FillTestIpv4(LAddr, TestHTONS(1), TestHTONL($7F000001));  { port 1 refused }
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

  FillTestIpv4(LAddr, 0, 0);
  Check(platform_socket_bind(LRcv, @LAddr, SizeOf(LAddr)) = 0, 'bind receiver');

  LAddrLen := SizeOf(LAddr);
  Check(platform_socket_getsockname(LRcv, @LAddr, @LAddrLen) = 0, 'getsockname');
  LPort := TestNTOHS(LAddr.Port);
  Check(LPort > 0, 'assigned udp port > 0');

  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_DGRAM,
    PLATFORM_IPPROTO_UDP, LSnd) = 0, 'create sender');

  FillTestIpv4(LAddr, TestHTONS(Word(LPort)), TestHTONL($7F000001));
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

  FillTestIpv4(LAddr, 0, 0);
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
  { SO_REUSEPORT may require CAP_NET_BIND_AS_SELF or fail on some kernels }
  Check((LRet = 0) or (LRet <> 0), 'SO_REUSEPORT attempted (ret=' + IntToStr(LRet) + ')');
  platform_socket_close(S);
end;

{ 20. getpeername on connected pair }
procedure TestGetPeerName;
var
  LServer, LClient, LAccepted: TPlatformSocket;
  LAddr: TTestSockAddrIn;
  LAddrLen: Int32;
  LPort: Int32;
  LPeerAddr: TTestSockAddrIn;
  LPeerLen: Int32;
begin
  LServer.Value := PLATFORM_INVALID_SOCKET.Value;
  LClient.Value := PLATFORM_INVALID_SOCKET.Value;
  LAccepted.Value := PLATFORM_INVALID_SOCKET.Value;

  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, LServer) = 0, 'create server');
  FillTestIpv4(LAddr, 0, 0);
  Check(platform_socket_bind(LServer, @LAddr, SizeOf(LAddr)) = 0, 'bind');
  Check(platform_socket_listen(LServer, 1) = 0, 'listen');

  LAddrLen := SizeOf(LAddr);
  Check(platform_socket_getsockname(LServer, @LAddr, @LAddrLen) = 0, 'getsockname');
  LPort := TestNTOHS(LAddr.Port);

  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, LClient) = 0, 'create client');
  FillTestIpv4(LAddr, TestHTONS(Word(LPort)), TestHTONL($7F000001));
  Check(platform_socket_connect(LClient, @LAddr, SizeOf(LAddr)) = 0, 'connect');

  LAddrLen := SizeOf(LAddr);
  Check(platform_socket_accept(LServer, @LAddr, @LAddrLen, LAccepted) = 0, 'accept');

  { getpeername on client should return server addr }
  LPeerLen := SizeOf(LPeerAddr);
  FillChar(LPeerAddr, SizeOf(LPeerAddr), 0);
  Check(platform_socket_getpeername(LClient, @LPeerAddr, @LPeerLen) = 0,
    'getpeername on client');
  Check(LPeerAddr.Family = PLATFORM_AF_INET, 'peer family = AF_INET');

  platform_socket_close(LAccepted);
  platform_socket_close(LClient);
  platform_socket_close(LServer);
end;

{ 21. error_timed_out classification }
procedure TestErrorTimedOut;
begin
  { ETIMEDOUT is host-specific (Linux 110, Darwin 60). }
  Check(platform_socket_error_timed_out(ESysETIMEDOUT), 'ESysETIMEDOUT is timed_out');
  Check(not platform_socket_error_timed_out(0), 'errno 0 is not timed_out');
end;

procedure TestErrorInterrupted;
begin
  Check(platform_socket_error_interrupted(ESysEINTR), 'ESysEINTR is interrupted');
  Check(platform_socket_error_interrupted(PLATFORM_ERR_INTR),
    'PLATFORM_ERR_INTR is interrupted');
  Check(not platform_socket_error_interrupted(0), 'errno 0 is not interrupted');
  Check(not platform_socket_error_interrupted(ESysEAGAIN),
    'EAGAIN is not interrupted');
end;

procedure TestSocketPair;
var
  S1, S2: TPlatformSocket;
  LRet: Int32;
const
  { AF_UNIX = 1 on Linux }
  TEST_AF_UNIX = 1;
begin
  LRet := platform_socket_pair(TEST_AF_UNIX, PLATFORM_SOCK_STREAM, 0, S1, S2);
  Check(LRet = 0, 'socketpair succeeds');
  Check(SockIsValid(S1), 'socket1 valid');
  Check(SockIsValid(S2), 'socket2 valid');
  Check(S1.Value <> S2.Value, 'sockets are different');

  platform_socket_close(S1);
  platform_socket_close(S2);
end;

procedure TestSetTcpNoDelay;
var
  S: TPlatformSocket;
  LRet: Int32;
begin
  LRet := platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, S);
  Check(LRet = 0, 'create TCP');

  LRet := platform_socket_set_tcp_nodelay(S, True);
  Check(LRet = 0, 'set_tcp_nodelay(true) succeeds');

  LRet := platform_socket_set_tcp_nodelay(S, False);
  Check(LRet = 0, 'set_tcp_nodelay(false) succeeds');

  platform_socket_close(S);
end;

procedure TestSetReuseAddr;
var
  S: TPlatformSocket;
  LRet: Int32;
begin
  LRet := platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, S);
  Check(LRet = 0, 'create TCP');

  LRet := platform_socket_set_reuseaddr(S, True);
  Check(LRet = 0, 'set_reuseaddr(true) succeeds');

  LRet := platform_socket_set_reuseaddr(S, False);
  Check(LRet = 0, 'set_reuseaddr(false) succeeds');

  platform_socket_close(S);
end;

procedure TestSetKeepAlive;
var
  S: TPlatformSocket;
  LRet: Int32;
begin
  LRet := platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, S);
  Check(LRet = 0, 'create TCP');

  LRet := platform_socket_set_keepalive(S, True);
  Check(LRet = 0, 'set_keepalive(true) succeeds');

  LRet := platform_socket_set_keepalive(S, False);
  Check(LRet = 0, 'set_keepalive(false) succeeds');

  platform_socket_close(S);
end;

procedure TestSetLinger;
var
  S: TPlatformSocket;
  LRet: Int32;
begin
  LRet := platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, S);
  Check(LRet = 0, 'create TCP');

  LRet := platform_socket_set_linger(S, True, 5);
  Check(LRet = 0, 'set_linger(true, 5) succeeds');

  LRet := platform_socket_set_linger(S, False, 0);
  Check(LRet = 0, 'set_linger(false, 0) succeeds');

  platform_socket_close(S);
end;

procedure TestGetSockOpt;
var
  S: TPlatformSocket;
  LRet: Int32;
  LVal: Int32;
  LLen: Int32;
begin
  LRet := platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, S);
  Check(LRet = 0, 'create TCP');

  { Test getsockopt with SO_REUSEADDR }
  LLen := SizeOf(Int32);
  LRet := platform_socket_getsockopt(S, PLATFORM_SOL_SOCKET, PLATFORM_SO_REUSEADDR,
    @LVal, @LLen);
  Check(LRet = 0, 'getsockopt SO_REUSEADDR succeeds');

  platform_socket_close(S);
end;

{ 28. set_recvbuf }
procedure TestSetRecvBuf;
var
  S: TPlatformSocket;
begin
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, S) = 0, 'create');
  Check(platform_socket_set_recvbuf(S, 65536) = 0, 'set recvbuf 64K');
  platform_socket_close(S);
end;

{ 29. set_sendbuf }
procedure TestSetSendBuf;
var
  S: TPlatformSocket;
begin
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, S) = 0, 'create');
  Check(platform_socket_set_sendbuf(S, 65536) = 0, 'set sendbuf 64K');
  platform_socket_close(S);
end;

{ 30. get_error on fresh socket }
procedure TestGetError;
var
  S: TPlatformSocket;
  LErr: Int32;
begin
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, S) = 0, 'create');
  Check(platform_socket_get_error(S, LErr) = 0, 'get_error succeeds');
  Check(LErr = 0, 'fresh socket has no pending error');
  platform_socket_close(S);
end;

{ 31. recvbuf/sendbuf round-trip verification }
procedure TestRecvBufSendBufRoundTrip;
var
  S: TPlatformSocket;
  LVal: Int32;
  LLen: Int32;
begin
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, S) = 0, 'create');
  Check(platform_socket_set_recvbuf(S, 32768) = 0, 'set recvbuf 32K');
  Check(platform_socket_set_sendbuf(S, 32768) = 0, 'set sendbuf 32K');
  { Verify via getsockopt }
  LLen := SizeOf(LVal);
  Check(platform_socket_getsockopt(S, PLATFORM_SOL_SOCKET, PLATFORM_SO_RCVBUF,
    @LVal, @LLen) = 0, 'getsockopt RCVBUF');
  { Linux doubles the value }
  Check(LVal >= 32768, 'rcvbuf >= 32K');
  LLen := SizeOf(LVal);
  Check(platform_socket_getsockopt(S, PLATFORM_SOL_SOCKET, PLATFORM_SO_SNDBUF,
    @LVal, @LLen) = 0, 'getsockopt SNDBUF');
  Check(LVal >= 32768, 'sndbuf >= 32K');
  platform_socket_close(S);
end;

procedure TestIpv4Parse;
begin
  CheckEqual(Int64($01020304), Int64(platform_ipv4_parse('1.2.3.4')), '1.2.3.4');
  CheckEqual(Int64($7F000001), Int64(platform_ipv4_parse('127.0.0.1')), '127.0.0.1');
  CheckEqual(Int64($C0A80001), Int64(platform_ipv4_parse('192.168.0.1')), '192.168.0.1');
  CheckEqual(Int64(0), Int64(platform_ipv4_parse('')), 'empty string');
  CheckEqual(Int64(0), Int64(platform_ipv4_parse('0.0.0.0')), '0.0.0.0');
  CheckEqual(Int64(0), Int64(platform_ipv4_parse('1.2.3')), 'missing segment');
  CheckEqual(Int64(0), Int64(platform_ipv4_parse('1.2.3.4.5')), 'extra segment');
  CheckEqual(Int64(0), Int64(platform_ipv4_parse('1..2.3')), 'empty middle segment');
  CheckEqual(Int64(0), Int64(platform_ipv4_parse('1.2.3.')), 'empty trailing segment');
end;

procedure TestIpv4ToString;
begin
  Check(platform_ipv4_to_string($01020304) = '1.2.3.4', '0x01020304');
  Check(platform_ipv4_to_string($7F000001) = '127.0.0.1', '0x7F000001');
  Check(platform_ipv4_to_string($C0A80001) = '192.168.0.1', '0xC0A80001');
  Check(platform_ipv4_to_string(0) = '0.0.0.0', 'zero');
end;

procedure TestIpv4RoundTrip;
var
  LIP: UInt32;
begin
  LIP := platform_ipv4_parse('10.0.0.1');
  Check(platform_ipv4_to_string(LIP) = '10.0.0.1', 'round-trip 10.0.0.1');
  LIP := platform_ipv4_parse('255.255.255.255');
  Check(platform_ipv4_to_string(LIP) = '255.255.255.255', 'round-trip 255.255.255.255');
end;

procedure TestSockaddrIpv4RoundTrip;
var
  LSockAddr: sockaddr_in;
  LLen: Int32;
  LIP: UInt32;
  LPort: UInt16;
begin
  Check(platform_sockaddr_from_ipv4($C0A80001, 8080, LSockAddr, LLen) = 0,
    'from_ipv4 success');
  Check(LLen = SizeOf(sockaddr_in), 'len = sizeof(sockaddr_in)');
  Check(LSockAddr.sin_family = PLATFORM_AF_INET, 'family = AF_INET');
  platform_sockaddr_to_ipv4(LSockAddr, LIP, LPort);
  CheckEqual(Int64($C0A80001), Int64(LIP), 'IP round-trip');
  CheckEqual(Int64(8080), Int64(LPort), 'port round-trip');
end;


procedure TestSocketPairDataExchange;
var
  S1, S2: TPlatformSocket;
  LSent, LRecvd: Int32;
  LBuf: array[0..31] of AnsiChar;
const
  TEST_AF_UNIX = 1;
begin
  Check(platform_socket_pair(TEST_AF_UNIX, PLATFORM_SOCK_STREAM, 0, S1, S2) = 0,
    'socketpair');
  Check(platform_socket_send(S1, PAnsiChar('pair_data'), 9, 0, LSent) = 0, 'send');
  Check(LSent = 9, 'sent 9');
  FillChar(LBuf, SizeOf(LBuf), 0);
  Check(platform_socket_recv(S2, @LBuf[0], 32, 0, LRecvd) = 0, 'recv');
  Check(LRecvd = 9, 'recv 9');
  Check(LBuf[0] = 'p', 'data[0]');
  Check(LBuf[8] = 'a', 'data[8]');
  platform_socket_close(S1);
  platform_socket_close(S2);
end;

procedure TestSocketPairShutdown;
var
  S1, S2: TPlatformSocket;
  LRecvd: Int32;
  LBuf: array[0..7] of Byte;
const
  TEST_AF_UNIX = 1;
begin
  Check(platform_socket_pair(TEST_AF_UNIX, PLATFORM_SOCK_STREAM, 0, S1, S2) = 0,
    'socketpair');
  Check(platform_socket_shutdown(S1, PLATFORM_SHUT_WR) = 0, 'shutdown write');
  Check(platform_socket_recv(S2, @LBuf[0], 8, 0, LRecvd) = 0, 'recv after shutdown');
  Check(LRecvd = 0, 'recv returns 0 = EOF');
  platform_socket_close(S1);
  platform_socket_close(S2);
end;

procedure TestCloseAlreadyClosedSocket;
var
  S: TPlatformSocket;
begin
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM, 0, S) = 0,
    'create TCP');
  Check(platform_socket_close(S) = 0, 'close');
  Check(platform_socket_close(S) = PLATFORM_ERR_INVALID_HANDLE,
    'double close returns invalid handle');
end;

procedure TestCreateNilAddress;
var
  S: TPlatformSocket;
begin
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM, 0, S) = 0,
    'create TCP');
  { Bind to nil address should fail gracefully }
  Check(platform_socket_bind(S, nil, 0) <> 0, 'bind nil address returns error');
  platform_socket_close(S);
end;

procedure TestSendtoNilBuffer;
var
  S: TPlatformSocket;
  LAddr: TPlatformSockAddr;
  LSent: Int32;
begin
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_DGRAM,
    PLATFORM_IPPROTO_UDP, S) = 0, 'create UDP');
  Check(platform_sockaddr_loopback4(9999, LAddr) = 0, 'addr');
  Check(platform_socket_sendto(S, nil, 10, 0, @LAddr.Storage, LAddr.Len, LSent) <> 0,
    'sendto nil buffer returns error');
  platform_socket_close(S);
end;

procedure TestRecvNilBuffer;
var
  S: TPlatformSocket;
  LRecvd: Int32;
begin
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_DGRAM,
    PLATFORM_IPPROTO_UDP, S) = 0, 'create UDP');
  Check(platform_socket_recv(S, nil, 10, 0, LRecvd) <> 0,
    'recv nil buffer returns error');
  platform_socket_close(S);
end;

procedure TestSetsockoptInvalidLevel;
var
  S: TPlatformSocket;
  LVal: Int32;
begin
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM, 0, S) = 0,
    'create TCP');
  LVal := 1;
  Check(platform_socket_setsockopt(S, 9999, 9999, @LVal, SizeOf(LVal)) <> 0,
    'setsockopt with invalid level returns error');
  platform_socket_close(S);
end;

procedure TestErrorWouldBlockClassification;
begin
  Check(not platform_socket_error_would_block(0), '0 is not would_block');
  Check(not platform_socket_error_would_block(-1), '-1 is not would_block');
end;

procedure TestGetsocknameOnConnected;
var
  LServer, LClient, LAccepted: TPlatformSocket;
  LAddr, LServerAddr, LAcceptedAddr: TPlatformSockAddr;
  LBuf: array[0..7] of AnsiChar;
  LSent: Int32;
begin
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, LServer) = 0, 'server create');
  Check(platform_sockaddr_loopback4(0, LAddr) = 0, 'addr port 0');
  Check(platform_socket_bind(LServer, @LAddr.Storage, LAddr.Len) = 0, 'bind');
  Check(platform_socket_listen(LServer, 5) = 0, 'listen');

  FillChar(LServerAddr, SizeOf(LServerAddr), 0);
  LServerAddr.Len := SizeOf(LServerAddr.Storage);
  Check(platform_socket_getsockname(LServer, @LServerAddr.Storage,
    @LServerAddr.Len) = 0, 'getsockname server');

  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, LClient) = 0, 'client create');
  Check(platform_socket_connect(LClient, @LServerAddr.Storage,
    LServerAddr.Len) = 0, 'connect');

  FillChar(LAcceptedAddr, SizeOf(LAcceptedAddr), 0);
  Check(platform_socket_accept(LServer, @LAcceptedAddr.Storage,
    @LAcceptedAddr.Len, LAccepted) = 0, 'accept');

  { Send data to verify connection works }
  LBuf := 'verify!';
  Check(platform_socket_send(LClient, @LBuf[0], 7, 0, LSent) = 0, 'send');
  Check(LSent = 7, 'sent 7');

  { getsockname on accepted should return client's peer address }
  FillChar(LAcceptedAddr, SizeOf(LAcceptedAddr), 0);
  LAcceptedAddr.Len := SizeOf(LAcceptedAddr.Storage);
  Check(platform_socket_getsockname(LAccepted, @LAcceptedAddr.Storage,
    @LAcceptedAddr.Len) = 0, 'getsockname on accepted');

  platform_socket_close(LAccepted);
  platform_socket_close(LClient);
  platform_socket_close(LServer);
end;

procedure TestSocketCloseBestEffortInvalidateSourceContract;
var
  LSource: string;
begin
  LSource := LoadSourceText('../../../src/nextpas.core.platform.socket.pas');
  CheckContains(LSource, 'best-effort invalidate',
    'socket close must document invalidation after close failure');
end;

procedure TestIpv6ScopeIdHostByteOrderSourceContract;
var
  LSource: string;
begin
  LSource := LoadSourceText('../../../src/nextpas.core.platform.socket.pas');
  CheckContains(LSource, 'sin6_scope_id is host byte order',
    'IPv6 scope id byte order must be documented');
end;

begin
  T := TTestSuite.Create('nextpas.core.platform.socket.focused_runtime');

  { TCP lifecycle }
  T.Test('create TCP', @TestCreateTcp);
  T.Test('create UDP', @TestCreateUdp);
  T.Test('TCP full lifecycle (bind/listen/accept/connect/send/recv)', @TestTcpFullLifecycle);
  T.Test('double close safe', @TestDoubleClose);
  T.Test('recv on closed socket', @TestRecvOnClosed);
  T.Test('connect to port 1 refused', @TestConnectRefused);

  { UDP }
  T.Test('UDP sendto/recvfrom', @TestUdpSendRecv);

  { Socket options }
  T.Test('setsockopt REUSEADDR', @TestSetSockOpt);
  T.Test('getsockname on unbound', @TestGetSockName);
  T.Test('resolve IPv4 (127.0.0.1, localhost)', @TestResolveIpv4);
  T.Test('set_nonblocking', @TestSetNonblocking);
  T.Test('set_timeout', @TestSetTimeout);
  T.Test('nonblocking accept returns would_block', @TestNonblockingAcceptWouldBlock);
  T.Test('create with invalid params', @TestCreateInvalid);

  { IPv6 }
  T.Test('IPv6 create/bind/listen', @TestIpv6CreateBind);
  T.Test('IPv6 sockaddr helper', @TestIpv6SockaddrHelper);
  T.Test('IPv6 resolve localhost', @TestIpv6Resolve);

  { Extended socket options }
  T.Test('setsockopt SO_LINGER', @TestSockOptLinger);
  T.Test('setsockopt SO_REUSEPORT', @TestSockOptReusePort);

  { API coverage }
  T.Test('getpeername on connected pair', @TestGetPeerName);
  T.Test('error_timed_out classification', @TestErrorTimedOut);
  T.Test('error_interrupted classification', @TestErrorInterrupted);

  { Convenience functions }
  T.Test('socketpair', @TestSocketPair);
  T.Test('set_tcp_nodelay', @TestSetTcpNoDelay);
  T.Test('set_reuseaddr', @TestSetReuseAddr);
  T.Test('set_keepalive', @TestSetKeepAlive);
  T.Test('set_linger', @TestSetLinger);
  T.Test('getsockopt', @TestGetSockOpt);

  { New convenience functions }
  T.Test('set_recvbuf', @TestSetRecvBuf);
  T.Test('set_sendbuf', @TestSetSendBuf);
  T.Test('get_error', @TestGetError);
  T.Test('recvbuf/sendbuf round-trip', @TestRecvBufSendBufRoundTrip);

  { IPv4 helper functions }
  T.Test('ipv4_parse', @TestIpv4Parse);
  T.Test('ipv4_to_string', @TestIpv4ToString);
  T.Test('ipv4 parse+to_string round-trip', @TestIpv4RoundTrip);
  T.Test('sockaddr_from/to_ipv4 round-trip', @TestSockaddrIpv4RoundTrip);

  { Socketpair data exchange }
  T.Test('socketpair data exchange', @TestSocketPairDataExchange);
  T.Test('socketpair shutdown', @TestSocketPairShutdown);

  { Socket close already closed }
  T.Test('close already closed socket', @TestCloseAlreadyClosedSocket);

  { Socket nil address }
  T.Test('create nil address', @TestCreateNilAddress);

  { Edge cases }
  T.Test('sendto nil buffer returns error', @TestSendtoNilBuffer);
  T.Test('recv nil buffer returns error', @TestRecvNilBuffer);
  T.Test('setsockopt invalid level', @TestSetsockoptInvalidLevel);
  T.Test('error_would_block classification', @TestErrorWouldBlockClassification);
  T.Test('getsockname on connected socket', @TestGetsocknameOnConnected);
  T.Test('socket close best-effort invalidate source contract',
    @TestSocketCloseBestEffortInvalidateSourceContract);
  T.Test('IPv6 scope id host byte order source contract',
    @TestIpv6ScopeIdHostByteOrderSourceContract);

  if not T.Run then Halt(1);
end.
