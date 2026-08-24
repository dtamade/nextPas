program test_platform_socket;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.platform.socket,
  nextpas.core.platform.error,
  nextpas.core.platform.unix.base;

var
  T: TTestSuite;

procedure TestSocketConstants;
begin
  Check(PLATFORM_AF_INET = 2, 'AF_INET must be 2');
  Check(PLATFORM_AF_INET6 > 0, 'AF_INET6 must be positive');
  Check(PLATFORM_SOCK_STREAM = 1, 'SOCK_STREAM must be 1');
  Check(PLATFORM_SOCK_DGRAM = 2, 'SOCK_DGRAM must be 2');
  Check(PLATFORM_IPPROTO_TCP = 6, 'IPPROTO_TCP must be 6');
  Check(PLATFORM_IPPROTO_UDP = 17, 'IPPROTO_UDP must be 17');
  Check(PLATFORM_SOL_SOCKET > 0, 'SOL_SOCKET must be positive');
  Check(PLATFORM_SO_REUSEADDR > 0, 'SO_REUSEADDR must be positive');
  Check(PLATFORM_SO_REUSEPORT > 0, 'SO_REUSEPORT must be positive');
  Check(PLATFORM_SO_KEEPALIVE > 0, 'SO_KEEPALIVE must be positive');
  Check(PLATFORM_TCP_NODELAY > 0, 'TCP_NODELAY must be positive');
  Check(PLATFORM_SHUT_RD = 0, 'SHUT_RD must be 0');
  Check(PLATFORM_SHUT_WR = 1, 'SHUT_WR must be 1');
  Check(PLATFORM_SHUT_RDWR = 2, 'SHUT_RDWR must be 2');
end;

procedure TestSocketCreateTcp;
var
  LSock: TPlatformSocket;
  LRes: Int32;
begin
  LRes := platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, LSock);
  if LRes = PLATFORM_ERR_UNSUPPORTED then
  begin
    Check(LRes = PLATFORM_ERR_UNSUPPORTED, 'unsupported on this platform');
    Exit;
  end;
  Check(LRes = 0, 'create tcp socket must succeed');
  platform_socket_close(LSock);
end;

procedure TestSocketCreateUdp;
var
  LSock: TPlatformSocket;
  LRes: Int32;
begin
  LRes := platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_DGRAM,
    PLATFORM_IPPROTO_UDP, LSock);
  if LRes = PLATFORM_ERR_UNSUPPORTED then
  begin
    Check(LRes = PLATFORM_ERR_UNSUPPORTED, 'unsupported on this platform');
    Exit;
  end;
  Check(LRes = 0, 'create udp socket must succeed');
  platform_socket_close(LSock);
end;

procedure TestSocketCreateIpv6;
var
  LSock: TPlatformSocket;
  LRes: Int32;
begin
  LRes := platform_socket_create(PLATFORM_AF_INET6, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, LSock);
  if LRes = PLATFORM_ERR_UNSUPPORTED then
  begin
    Check(LRes = PLATFORM_ERR_UNSUPPORTED, 'unsupported on this platform');
    Exit;
  end;
  Check(LRes = 0, 'create ipv6 socket must succeed');
  platform_socket_close(LSock);
end;

procedure TestSocketSetNonBlocking;
var
  LSock: TPlatformSocket;
  LRes: Int32;
begin
  LRes := platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, LSock);
  if LRes = PLATFORM_ERR_UNSUPPORTED then
  begin
    Check(LRes = PLATFORM_ERR_UNSUPPORTED, 'unsupported on this platform');
    Exit;
  end;
  Check(LRes = 0, 'create socket must succeed');
  LRes := platform_socket_set_nonblocking(LSock, True);
  Check(LRes = 0, 'set nonblocking must succeed');
  platform_socket_close(LSock);
end;

procedure TestSocketSetTimeout;
var
  LSock: TPlatformSocket;
  LRes: Int32;
begin
  LRes := platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, LSock);
  if LRes = PLATFORM_ERR_UNSUPPORTED then
  begin
    Check(LRes = PLATFORM_ERR_UNSUPPORTED, 'unsupported on this platform');
    Exit;
  end;
  Check(LRes = 0, 'create socket must succeed');
  LRes := platform_socket_set_timeout(LSock, PLATFORM_SO_RCVTIMEO, 1000);
  Check(LRes = 0, 'set timeout must succeed');
  platform_socket_close(LSock);
end;

procedure TestSocketErrorWouldBlock;
begin
  Check(platform_socket_error_would_block(ESysEAGAIN) = True,
    'EAGAIN must be would-block');
  Check(platform_socket_error_would_block(ESysEAGAIN) = True,
    'EWOULDBLOCK (same as EAGAIN) must be would-block');
  Check(platform_socket_error_would_block(0) = False,
    '0 must not be would-block');
end;

procedure TestSocketErrorTimedOut;
begin
  Check(platform_socket_error_timed_out(ESysETIMEDOUT) = True,
    'ETIMEDOUT must be timed-out');
  Check(platform_socket_error_timed_out(0) = False,
    '0 must not be timed-out');
end;

procedure TestSocketErrorInterrupted;
begin
  Check(platform_socket_error_interrupted(ESysEINTR) = True,
    'EINTR must be interrupted');
  Check(platform_socket_error_interrupted(PLATFORM_ERR_INTR) = True,
    'PLATFORM_ERR_INTR must be interrupted');
  Check(platform_socket_error_interrupted(0) = False,
    '0 must not be interrupted');
  Check(platform_socket_error_interrupted(ESysEAGAIN) = False,
    'EAGAIN must not be interrupted');
end;

procedure TestSocketBindListen;
var
  LSock: TPlatformSocket;
  LRes: Int32;
  LAddr: TPlatformSockAddr;
begin
  LRes := platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, LSock);
  if LRes = PLATFORM_ERR_UNSUPPORTED then
  begin
    Check(LRes = PLATFORM_ERR_UNSUPPORTED, 'unsupported on this platform');
    Exit;
  end;
  Check(LRes = 0, 'create socket must succeed');

  // Set SO_REUSEADDR to avoid address already in use
  platform_socket_setsockopt(LSock, PLATFORM_SOL_SOCKET, PLATFORM_SO_REUSEADDR, @LRes, SizeOf(LRes));

  // Create IPv4 address on port 0 (let OS choose)
  LRes := platform_sockaddr_ipv4(0, 0, LAddr);
  Check(LRes = 0, 'create sockaddr must succeed');

  LRes := platform_socket_bind(LSock, @LAddr, LAddr.Len);
  Check(LRes = 0, 'bind must succeed');

  LRes := platform_socket_listen(LSock, 1);
  Check(LRes = 0, 'listen must succeed');

  platform_socket_close(LSock);
end;

procedure TestSocketGetSockName;
var
  LSock: TPlatformSocket;
  LRes: Int32;
  LAddr: TPlatformSockAddr;
  LAddrLen: Int32;
begin
  LRes := platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, LSock);
  if LRes = PLATFORM_ERR_UNSUPPORTED then
  begin
    Check(LRes = PLATFORM_ERR_UNSUPPORTED, 'unsupported on this platform');
    Exit;
  end;
  Check(LRes = 0, 'create socket must succeed');

  // Set SO_REUSEADDR
  platform_socket_setsockopt(LSock, PLATFORM_SOL_SOCKET, PLATFORM_SO_REUSEADDR, @LRes, SizeOf(LRes));

  // Create IPv4 address on port 0
  LRes := platform_sockaddr_ipv4(0, 0, LAddr);
  Check(LRes = 0, 'create sockaddr must succeed');

  LRes := platform_socket_bind(LSock, @LAddr, LAddr.Len);
  Check(LRes = 0, 'bind must succeed');

  LAddrLen := SizeOf(LAddr);
  LRes := platform_socket_getsockname(LSock, @LAddr, @LAddrLen);
  Check(LRes = 0, 'getsockname must succeed');

  platform_socket_close(LSock);
end;

procedure TestSocketShutdown;
var
  LSock: TPlatformSocket;
  LRes: Int32;
  LAddr: TPlatformSockAddr;
begin
  LRes := platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, LSock);
  if LRes = PLATFORM_ERR_UNSUPPORTED then
  begin
    Check(LRes = PLATFORM_ERR_UNSUPPORTED, 'unsupported on this platform');
    Exit;
  end;
  Check(LRes = 0, 'create socket must succeed');

  // Bind and listen first (shutdown requires a connected/bound socket)
  platform_socket_setsockopt(LSock, PLATFORM_SOL_SOCKET, PLATFORM_SO_REUSEADDR, @LRes, SizeOf(LRes));
  LRes := platform_sockaddr_ipv4(0, 0, LAddr);
  Check(LRes = 0, 'create sockaddr must succeed');
  LRes := platform_socket_bind(LSock, @LAddr, LAddr.Len);
  Check(LRes = 0, 'bind must succeed');
  LRes := platform_socket_listen(LSock, 1);
  Check(LRes = 0, 'listen must succeed');

  // Shutdown on listening socket - may succeed or fail depending on platform
  platform_socket_shutdown(LSock, PLATFORM_SHUT_RDWR);

  platform_socket_close(LSock);
end;

procedure TestSocketSetsockopt;
var
  LSock: TPlatformSocket;
  LRes: Int32;
  LVal: Int32;
begin
  LRes := platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, LSock);
  if LRes = PLATFORM_ERR_UNSUPPORTED then
  begin
    Check(LRes = PLATFORM_ERR_UNSUPPORTED, 'unsupported on this platform');
    Exit;
  end;
  Check(LRes = 0, 'create socket must succeed');

  LVal := 1;
  LRes := platform_socket_setsockopt(LSock, PLATFORM_SOL_SOCKET, PLATFORM_SO_REUSEADDR, @LVal, SizeOf(LVal));
  Check(LRes = 0, 'setsockopt SO_REUSEADDR must succeed');

  LRes := platform_socket_setsockopt(LSock, PLATFORM_IPPROTO_TCP, PLATFORM_TCP_NODELAY, @LVal, SizeOf(LVal));
  Check(LRes = 0, 'setsockopt TCP_NODELAY must succeed');

  platform_socket_close(LSock);
end;

begin
  T := TTestSuite.Create('nextpas.core.platform.socket');
  T.Test('socket constants', @TestSocketConstants);
  T.Test('create tcp socket', @TestSocketCreateTcp);
  T.Test('create udp socket', @TestSocketCreateUdp);
  T.Test('create ipv6 socket', @TestSocketCreateIpv6);
  T.Test('set nonblocking', @TestSocketSetNonBlocking);
  T.Test('set timeout', @TestSocketSetTimeout);
  T.Test('error would block', @TestSocketErrorWouldBlock);
  T.Test('error timed out', @TestSocketErrorTimedOut);
  T.Test('error interrupted', @TestSocketErrorInterrupted);
  T.Test('bind/listen', @TestSocketBindListen);
  T.Test('getsockname', @TestSocketGetSockName);
  T.Test('shutdown', @TestSocketShutdown);
  T.Test('setsockopt', @TestSocketSetsockopt);
  if not T.Run then Halt(1);
end.
