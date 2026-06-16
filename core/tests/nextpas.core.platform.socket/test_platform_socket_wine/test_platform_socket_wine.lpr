program test_platform_socket_wine;

{ Platform Socket Wine Runtime Smoke Test
  Cross-compiled to Win64 and run under Wine. }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.testing,
  nextpas.core.platform.socket;

var
  T: TTestRunner;

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

{$ELSE}
procedure TestNonWindowsSkip;
begin
  WriteLn('not Windows runtime evidence on this host');
  Check(True, 'non-Windows skip');
end;
{$ENDIF}

begin
  T := TTestRunner.Create('nextpas.core.platform.socket.wine_runtime_smoke');
  {$IFDEF NEXTPAS_WINDOWS}
  T.Run('create TCP', @TestCreateTcp);
  T.Run('create UDP', @TestCreateUdp);
  T.Run('TCP bind+listen', @TestTcpBind);
  T.Run('connect refused', @TestConnectRefused);
  {$ELSE}
  T.Run('non-Windows skip', @TestNonWindowsSkip);
  {$ENDIF}
  T.Summary;
end.
