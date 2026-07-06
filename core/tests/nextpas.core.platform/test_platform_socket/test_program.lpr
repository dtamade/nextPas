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
  if not T.Run then Halt(1);
end.
