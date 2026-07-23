program test_platform_socket_wine;

{ Platform Socket Wine Runtime Smoke Test
  Cross-compiled to Win64 and run under Wine. }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.platform.socket;

var
  T: TTestSuite;

{$IFDEF NEXTPAS_WINDOWS}

function SockIsValid(const ASock: TPlatformSocket): Boolean;
begin
  Result := ASock.Value <> PLATFORM_INVALID_SOCKET.Value;
end;

procedure TestCreateTcp;
var
  S: TPlatformSocket;
begin
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, S) = 0, 'create TCP');
  Check(SockIsValid(S), 'valid socket');
  Check(platform_socket_close(S) = 0, 'close');
  Check(S.Value = PLATFORM_INVALID_SOCKET.Value, 'invalidated');
end;

procedure TestCreateUdp;
var
  S: TPlatformSocket;
begin
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_DGRAM,
    PLATFORM_IPPROTO_UDP, S) = 0, 'create UDP');
  Check(SockIsValid(S), 'valid socket');
  Check(platform_socket_close(S) = 0, 'close');
end;

procedure TestTcpBind;
const
  TCP_BACKLOG = 1;
var
  S: TPlatformSocket;
  LAddr: TPlatformSockAddr;
begin
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, S) = 0, 'create');
  Check(platform_sockaddr_loopback4(0, LAddr) = 0, 'loopback addr');
  Check(platform_socket_bind(S, @LAddr.Storage, LAddr.Len) = 0, 'bind');
  Check(platform_socket_listen(S, TCP_BACKLOG) = 0, 'listen');
  Check(platform_socket_close(S) = 0, 'close');
end;

procedure TestConnectRefused;
var
  S: TPlatformSocket;
  LAddr: TPlatformSockAddr;
begin
  Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, S) = 0, 'create');
  Check(platform_sockaddr_loopback4(1, LAddr) = 0, 'addr port 1');
  Check(platform_socket_connect(S, @LAddr.Storage, LAddr.Len) <> 0,
    'connect to port 1 fails under Wine');
  Check(platform_socket_close(S) = 0, 'close');
end;

{ PD-3-3: Windows pair is TCP loopback (domain ignored); must not be UNSUPPORTED. }
procedure TestSocketPair;
var
  S1, S2: TPlatformSocket;
  LSent, LRecv: Int32;
  LBuf: array[0..0] of AnsiChar;
begin
  Check(platform_socket_pair(0, PLATFORM_SOCK_STREAM, 0, S1, S2) = 0,
    'socket_pair succeeds');
  Check(SockIsValid(S1) and SockIsValid(S2), 'both ends valid');
  Check(S1.Value <> S2.Value, 'distinct ends');
  LBuf[0] := 'W';
  Check(platform_socket_send(S1, @LBuf[0], 1, 0, LSent) = 0, 'send wake byte');
  Check(LSent = 1, 'sent 1');
  Check(platform_socket_recv(S2, @LBuf[0], 1, 0, LRecv) = 0, 'recv wake byte');
  Check((LRecv = 1) and (LBuf[0] = 'W'), 'recv matches');
  Check(platform_socket_close(S1) = 0, 'close1');
  Check(platform_socket_close(S2) = 0, 'close2');
end;

{$ELSE}
procedure TestNonWindowsSkip;
begin
  WriteLn('not Windows runtime evidence on this host');
  Check(True, 'non-Windows skip');
end;
{$ENDIF}

begin
  T := TTestSuite.Create('nextpas.core.platform.socket.wine_runtime_smoke');
  {$IFDEF NEXTPAS_WINDOWS}
  T.Test('create TCP', @TestCreateTcp);
  T.Test('create UDP', @TestCreateUdp);
  T.Test('TCP bind+listen', @TestTcpBind);
  T.Test('connect refused', @TestConnectRefused);
  T.Test('socket_pair wake byte', @TestSocketPair);
  {$ELSE}
  T.Test('non-Windows skip', @TestNonWindowsSkip);
  {$ENDIF}
  if not T.Run then Halt(1);
end.
