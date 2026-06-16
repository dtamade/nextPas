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

{ Bind a socket to 127.0.0.1 port 0 (OS-assigned) and return the
  resulting bound address in AResult. }
function BindLoopback0(var S: TPlatformSocket;
  out AResult: TPlatformSockAddr): Int32;
var
  LAddrLen: Int32;
begin
  Check(platform_sockaddr_loopback4(0, AResult) = 0, 'loopback addr port 0');
  Result := platform_socket_bind(S, @AResult.Storage, AResult.Len);
  if Result = 0 then
  begin
    { Retrieve the OS-assigned port }
    LAddrLen := SizeOf(AResult);
    Check(platform_socket_getsockname(S, @AResult.Storage, @LAddrLen) = 0,
      'getsockname after port 0 bind');
    AResult.Len := LAddrLen;
  end;
end;

procedure TestTcpBindSpecificPort;
var
  S: TPlatformSocket;
  LAddr: TPlatformSockAddr;
  LLocal: TPlatformSockAddr;
  LAddrLen: Int32;
  LBoundPort: UInt16;
begin
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, S) = 0, 'create');
  try
    Check(BindLoopback0(S, LAddr) = 0, 'bind to port 0');
    { Verify OS assigned a non-zero port by reading it back }
    LAddrLen := SizeOf(LLocal);
    Check(platform_socket_getsockname(S, @LLocal.Storage, @LAddrLen) = 0,
      'getsockname');
    LBoundPort := platform_htons(PWord(@LLocal.Storage[2])^);
    Check(LBoundPort > 0, 'OS-assigned port > 0');
  finally
    platform_socket_close(S);
  end;
end;

procedure TestTcpListenBacklog;
var
  S: TPlatformSocket;
  LAddr: TPlatformSockAddr;
begin
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, S) = 0, 'create');
  try
    Check(BindLoopback0(S, LAddr) = 0, 'bind');
    Check(platform_socket_listen(S, 8) = 0, 'listen backlog=8');
  finally
    platform_socket_close(S);
  end;
end;

procedure TestAcceptReturnsClient;
var
  LSrv, LClient, LAccepted: TPlatformSocket;
  LAddr: TPlatformSockAddr;
  LAddrLen: Int32;
begin
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, LSrv) = 0, 'create server');
  try
    Check(BindLoopback0(LSrv, LAddr) = 0, 'bind');
    Check(platform_socket_listen(LSrv, 2) = 0, 'listen');

    Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
      PLATFORM_IPPROTO_TCP, LClient) = 0, 'create client');
    try
      Check(platform_socket_connect(LClient, @LAddr.Storage, LAddr.Len) = 0,
        'connect');

      LAddrLen := SizeOf(LAddr);
      Check(platform_socket_accept(LSrv, @LAddr.Storage, @LAddrLen, LAccepted) = 0,
        'accept');
      try
        Check(LAccepted.Value <> PLATFORM_INVALID_SOCKET.Value,
          'accept returns valid');
      finally
        platform_socket_close(LAccepted);
      end;
    finally
      platform_socket_close(LClient);
    end;
  finally
    platform_socket_close(LSrv);
  end;
end;

procedure TestFullTcpRoundtrip;
const
  MSG: PAnsiChar = 'Hello nextPas';
var
  LSrv, LClient, LAccepted: TPlatformSocket;
  LAddr: TPlatformSockAddr;
  LAddrLen: Int32;
  LBuf: array[0..31] of AnsiChar;
  LSent, LRecv: Integer;
begin
  FillChar(LBuf, SizeOf(LBuf), 0);

  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, LSrv) = 0, 'create server');
  try
    Check(BindLoopback0(LSrv, LAddr) = 0, 'bind');
    Check(platform_socket_listen(LSrv, 2) = 0, 'listen');

    Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
      PLATFORM_IPPROTO_TCP, LClient) = 0, 'create client');
    try
      Check(platform_socket_connect(LClient, @LAddr.Storage, LAddr.Len) = 0,
        'connect');

      LAddrLen := SizeOf(LAddr);
      Check(platform_socket_accept(LSrv, @LAddr.Storage, @LAddrLen, LAccepted) = 0,
        'accept');
      try
        { Send from client }
        Check(platform_socket_send(LClient, MSG, Length(MSG), 0, LSent) = 0,
          'send');
        Check(LSent = Length(MSG), 'sent ' + IntToStr(LSent) + ' bytes');

        { Recv on accepted }
        Check(platform_socket_recv(LAccepted, @LBuf[0], 32, 0, LRecv) = 0,
          'recv');
        Check(LRecv = LSent, 'recv ' + IntToStr(LRecv) + ' bytes');
        Check(CompareMem(@LBuf[0], MSG, LSent), 'payload matches');
      finally
        platform_socket_close(LAccepted);
      end;
    finally
      platform_socket_close(LClient);
    end;
  finally
    platform_socket_close(LSrv);
  end;
end;

procedure TestShutdownRdwr;
var
  LSrv, LClient, LAccepted: TPlatformSocket;
  LAddr: TPlatformSockAddr;
  LAddrLen: Int32;
begin
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, LSrv) = 0, 'create server');
  try
    Check(BindLoopback0(LSrv, LAddr) = 0, 'bind');
    Check(platform_socket_listen(LSrv, 2) = 0, 'listen');

    Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
      PLATFORM_IPPROTO_TCP, LClient) = 0, 'create client');
    try
      Check(platform_socket_connect(LClient, @LAddr.Storage, LAddr.Len) = 0,
        'connect');

      LAddrLen := SizeOf(LAddr);
      Check(platform_socket_accept(LSrv, @LAddr.Storage, @LAddrLen, LAccepted) = 0,
        'accept');
      try
        Check(platform_socket_shutdown(LAccepted, PLATFORM_SHUT_RDWR) = 0,
          'shutdown accepted');
        Check(platform_socket_shutdown(LClient, PLATFORM_SHUT_RDWR) = 0,
          'shutdown client');
      finally
        platform_socket_close(LAccepted);
      end;
    finally
      platform_socket_close(LClient);
    end;
  finally
    platform_socket_close(LSrv);
  end;
end;

procedure TestSetsockoptKeepalive;
var
  S: TPlatformSocket;
  LVal: Int32;
begin
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, S) = 0, 'create');
  try
    LVal := 1;
    Check(platform_socket_setsockopt(S, PLATFORM_SOL_SOCKET,
      PLATFORM_SO_KEEPALIVE, @LVal, SizeOf(LVal)) = 0, 'set SO_KEEPALIVE');
  finally
    platform_socket_close(S);
  end;
end;

procedure TestSetsockoptNodelay;
var
  S: TPlatformSocket;
  LVal: Int32;
begin
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, S) = 0, 'create');
  try
    LVal := 1;
    Check(platform_socket_setsockopt(S, PLATFORM_IPPROTO_TCP,
      PLATFORM_TCP_NODELAY, @LVal, SizeOf(LVal)) = 0, 'set TCP_NODELAY');
  finally
    platform_socket_close(S);
  end;
end;

procedure TestSetsockoptRcvtimeo;
var
  LSrv, LClient: TPlatformSocket;
  LAddr: TPlatformSockAddr;
  LBuf: array[0..15] of AnsiChar;
  LRecv, LVal: Integer;
begin
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, LSrv) = 0, 'create server');
  try
    Check(BindLoopback0(LSrv, LAddr) = 0, 'bind');
    Check(platform_socket_listen(LSrv, 2) = 0, 'listen');

    Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
      PLATFORM_IPPROTO_TCP, LClient) = 0, 'create client');
    try
      Check(platform_socket_connect(LClient, @LAddr.Storage, LAddr.Len) = 0,
        'connect');

      { Set recv timeout and verify it times out }
      LVal := 100;
      Check(platform_socket_setsockopt(LClient, PLATFORM_SOL_SOCKET,
        PLATFORM_SO_RCVTIMEO, @LVal, SizeOf(LVal)) = 0,
        'set SO_RCVTIMEO 100ms');

      Check(platform_socket_recv(LClient, @LBuf[0], 16, 0, LRecv) <> 0,
        'recv times out');
    finally
      platform_socket_close(LClient);
    end;
  finally
    platform_socket_close(LSrv);
  end;
end;

procedure TestSetsockoptSndtimeo;
var
  S: TPlatformSocket;
  LVal: Int32;
begin
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, S) = 0, 'create');
  try
    LVal := 200;
    Check(platform_socket_setsockopt(S, PLATFORM_SOL_SOCKET,
      PLATFORM_SO_SNDTIMEO, @LVal, SizeOf(LVal)) = 0,
      'set SO_SNDTIMEO 200ms');
  finally
    platform_socket_close(S);
  end;
end;

procedure TestGetsocknameAfterBind;
var
  S: TPlatformSocket;
  LAddr, LLocal: TPlatformSockAddr;
  LAddrLen: Int32;
begin
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, S) = 0, 'create');
  try
    Check(BindLoopback0(S, LAddr) = 0, 'bind');

    LAddrLen := SizeOf(LLocal);
    Check(platform_socket_getsockname(S, @LLocal.Storage, @LAddrLen) = 0,
      'getsockname');

    { Verify the port was bound correctly by re-binding to same port should fail }
    Check(platform_socket_bind(S, @LAddr.Storage, LAddr.Len) <> 0,
      'rebind to same port fails (confirms port bound)');
  finally
    platform_socket_close(S);
  end;
end;

procedure TestGetpeernameAfterConnect;
var
  LSrv, LClient, LAccepted: TPlatformSocket;
  LAddr, LPeer: TPlatformSockAddr;
  LAddrLen: Int32;
begin
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, LSrv) = 0, 'create server');
  try
    Check(BindLoopback0(LSrv, LAddr) = 0, 'bind');
    Check(platform_socket_listen(LSrv, 2) = 0, 'listen');

    Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
      PLATFORM_IPPROTO_TCP, LClient) = 0, 'create client');
    try
      Check(platform_socket_connect(LClient, @LAddr.Storage, LAddr.Len) = 0,
        'connect');

      LAddrLen := SizeOf(LAddr);
      Check(platform_socket_accept(LSrv, @LAddr.Storage, @LAddrLen, LAccepted) = 0,
        'accept');
      try
        LAddrLen := SizeOf(LPeer);
        Check(platform_socket_getpeername(LClient, @LPeer.Storage, @LAddrLen) = 0,
          'getpeername');

        { Verify getpeername succeeded — port is in the peer addr struct }
        Check(LAddrLen > 0, 'peer addr len > 0');
      finally
        platform_socket_close(LAccepted);
      end;
    finally
      platform_socket_close(LClient);
    end;
  finally
    platform_socket_close(LSrv);
  end;
end;

procedure TestUdpSendtoRecvfrom;
const
  MSG: PAnsiChar = 'UDP hello';
var
  LSnd, LRcv: TPlatformSocket;
  LAddr: TPlatformSockAddr;
  LFromAddr: TPlatformSockAddr;
  LFromLen: Int32;
  LBuf: array[0..31] of AnsiChar;
  LSent, LRecv: Integer;
begin
  FillChar(LBuf, SizeOf(LBuf), 0);

  { Receiver — bind to port 0 }
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_DGRAM,
    PLATFORM_IPPROTO_UDP, LRcv) = 0, 'create receiver');
  try
    Check(BindLoopback0(LRcv, LAddr) = 0, 'bind receiver');

    { Sender }
    Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_DGRAM,
      PLATFORM_IPPROTO_UDP, LSnd) = 0, 'create sender');
    try
      Check(platform_socket_sendto(LSnd, MSG, Length(MSG), 0,
        @LAddr.Storage, LAddr.Len, LSent) = 0, 'sendto');
      Check(LSent = Length(MSG), 'sent ' + IntToStr(LSent) + ' bytes');

      { Receive }
      LFromLen := SizeOf(LFromAddr);
      Check(platform_socket_recvfrom(LRcv, @LBuf[0], 32, 0,
        @LFromAddr.Storage, @LFromLen, LRecv) = 0, 'recvfrom');
      Check(LRecv = LSent, 'recv ' + IntToStr(LRecv) + ' bytes');
      Check(CompareMem(@LBuf[0], MSG, LSent), 'payload matches');
    finally
      platform_socket_close(LSnd);
    end;
  finally
    platform_socket_close(LRcv);
  end;
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
  try
    Check(platform_socket_set_nonblocking(S, True) = 0,
      'set nonblocking true');
  finally
    platform_socket_close(S);
  end;
end;

procedure TestSetNonblockingFalse;
var
  S: TPlatformSocket;
begin
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, S) = 0, 'create');
  try
    Check(platform_socket_set_nonblocking(S, True) = 0,
      'set nonblocking true');
    Check(platform_socket_set_nonblocking(S, False) = 0,
      'set nonblocking false');
  finally
    platform_socket_close(S);
  end;
end;

procedure TestErrorWouldBlock;
var
  LSrv, LClient, LAccepted: TPlatformSocket;
  LAddr: TPlatformSockAddr;
  LAddrLen: Int32;
  LBuf: array[0..15] of AnsiChar;
  LRecv: Integer;
  LErr: Integer;
begin
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, LSrv) = 0, 'create server');
  try
    Check(BindLoopback0(LSrv, LAddr) = 0, 'bind');
    Check(platform_socket_listen(LSrv, 2) = 0, 'listen');

    Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
      PLATFORM_IPPROTO_TCP, LClient) = 0, 'create client');
    try
      Check(platform_socket_connect(LClient, @LAddr.Storage, LAddr.Len) = 0,
        'connect');

      LAddrLen := SizeOf(LAddr);
      Check(platform_socket_accept(LSrv, @LAddr.Storage, @LAddrLen, LAccepted) = 0,
        'accept');
      try
        { Set nonblocking and recv — should get WOULDBLOCK since no data sent }
        Check(platform_socket_set_nonblocking(LAccepted, True) = 0,
          'set nonblocking');
        LErr := platform_socket_recv(LAccepted, @LBuf[0], 16, 0, LRecv);
        Check(LErr <> 0, 'recv returns error');
        Check(platform_socket_error_would_block(LErr),
          'error is WOULDBLOCK');
      finally
        platform_socket_close(LAccepted);
      end;
    finally
      platform_socket_close(LClient);
    end;
  finally
    platform_socket_close(LSrv);
  end;
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
