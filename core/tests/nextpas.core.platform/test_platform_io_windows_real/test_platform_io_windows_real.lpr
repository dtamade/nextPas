program test_platform_io_windows_real;

{ Real Windows runtime evidence only when compiled and run on a Windows host. }

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.platform.io.base,
  nextpas.core.platform.io,
  nextpas.core.platform.socket
  {$IFDEF NEXTPAS_WINDOWS},
  nextpas.core.platform.windows.base,
  nextpas.core.platform.windows.ffi
  {$ENDIF};

var
  T: TTestRunner;

{$IFDEF NEXTPAS_WINDOWS}

{ Helper: create a TCP socket for testing }
function CreateTestSocket(out ASocket: TPlatformSocket): Int32;
begin
  Result := platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, ASocket);
end;

{ Helper: create a TCP server socket bound to localhost }
function CreateServerSocket(APort: UInt16; out AServer: TPlatformSocket;
  out AAddr: TPlatformSockAddr): Int32;
begin
  Result := platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, AServer);
  if Result <> 0 then
    Exit;
  Result := platform_sockaddr_ipv4(APort, platform_htonl($7F000001), AAddr);
  if Result <> 0 then
    Exit;
  Result := platform_socket_bind(AServer, @AAddr, AAddr.Len);
end;

{ 1. Create and verify WSAStartup initialization }
procedure TestCreateWithWinsockInit;
var
  LPoller: TPlatformPoller;
  LErr: Int32;
begin
  LErr := platform_poller_create(LPoller);
  Check(LErr = 0, 'poller_create');
  Check(LPoller.WinsockStarted, 'WSAStartup was called');
  Check(platform_poller_close(LPoller) = 0, 'poller_close');
end;

{ 2. Close cleans up and second close is safe }
procedure TestCloseCleansUpWinsock;
var
  LPoller: TPlatformPoller;
begin
  Check(platform_poller_create(LPoller) = 0, 'poller_create');
  Check(platform_poller_close(LPoller) = 0, 'close first time');
  Check(platform_poller_close(LPoller) = 0, 'close second time (safe)');
end;

{ 3. Wait with a ready socket returns the readable event }
procedure TestWaitPollingWithReadySocket;
var
  LPoller: TPlatformPoller;
  LServer: TPlatformSocket;
  LClient: TPlatformSocket;
  LAccepted: TPlatformSocket;
  LAddr: TPlatformSockAddr;
  LEntries: array[0..3] of TPlatformPollEntry;
  LCount: Int32;
  LErr: Int32;
  LBuf: array[0..1] of Byte;
  LSent: Int32;
begin
  Check(platform_poller_create(LPoller) = 0, 'poller_create');

  { Create server socket }
  LErr := CreateServerSocket(0, LServer, LAddr);
  Check(LErr = 0, 'create server');
  Check(platform_socket_listen(LServer, 1) = 0, 'listen');

  { Get actual port }
  LErr := platform_socket_getsockname(LServer, @LAddr, @LAddr.Len);
  Check(LErr = 0, 'getsockname');

  { Create client and connect }
  LErr := CreateTestSocket(LClient);
  Check(LErr = 0, 'create client');
  LErr := platform_socket_connect(LClient, @LAddr, LAddr.Len);
  Check(LErr = 0, 'connect');

  { Accept connection }
  LErr := platform_socket_accept(LServer, nil, nil, LAccepted);
  Check(LErr = 0, 'accept');
  platform_socket_close(LServer);

  { Add accepted socket to poller }
  LErr := platform_poller_add(LPoller, LAccepted.Value, [peReadable], nil);
  Check(LErr = 0, 'add socket to poller');

  { Send data to make it readable }
  LBuf[0] := 42;
  LSent := 0;
  LErr := platform_socket_send(LClient, @LBuf[0], 1, 0, LSent);
  Check(LErr = 0, 'send data');
  platform_socket_close(LClient);

  { Wait should return the readable event }
  LCount := 0;
  LErr := platform_poller_wait(LPoller, @LEntries[0], 4, 100, LCount);
  Check(LErr = 0, 'wait');
  Check(LCount = 1, 'one event');
  Check(peReadable in LEntries[0].REvents, 'readable event');

  platform_socket_close(LAccepted);
  Check(platform_poller_close(LPoller) = 0, 'close poller');
end;

{ 4. Wait with no events returns timeout (0 count) }
procedure TestWaitTimeoutNoEvents;
var
  LPoller: TPlatformPoller;
  LEntries: array[0..3] of TPlatformPollEntry;
  LCount: Int32;
begin
  Check(platform_poller_create(LPoller) = 0, 'poller_create');

  { Wait with empty poller should return 0 immediately }
  LCount := 0;
  Check(platform_poller_wait(LPoller, @LEntries[0], 4, 0, LCount) = 0, 'wait timeout=0');
  Check(LCount = 0, 'no events on empty poller');

  Check(platform_poller_close(LPoller) = 0, 'close poller');
end;

{ 5. Adding duplicate fd returns error }
procedure TestAddDuplicateFdError;
var
  LPoller: TPlatformPoller;
  LSock: TPlatformSocket;
  LErr: Int32;
begin
  Check(platform_poller_create(LPoller) = 0, 'poller_create');
  LErr := CreateTestSocket(LSock);
  Check(LErr = 0, 'create socket');

  { First add should succeed }
  LErr := platform_poller_add(LPoller, LSock.Value, [peReadable], nil);
  Check(LErr = 0, 'first add');

  { Second add should fail with already exists }
  LErr := platform_poller_add(LPoller, LSock.Value, [peReadable], nil);
  Check(LErr <> 0, 'duplicate add should fail');

  platform_socket_close(LSock);
  Check(platform_poller_close(LPoller) = 0, 'close poller');
end;

{ 6. Remove non-existent fd returns error }
procedure TestRemoveNonexistentFdError;
var
  LPoller: TPlatformPoller;
  LErr: Int32;
begin
  Check(platform_poller_create(LPoller) = 0, 'poller_create');

  { Remove non-existent fd should fail }
  LErr := platform_poller_remove(LPoller, PtrUInt(9999));
  Check(LErr <> 0, 'remove nonexistent should fail');

  Check(platform_poller_close(LPoller) = 0, 'close poller');
end;

{ 7. Modify non-existent fd returns error }
procedure TestModifyNonexistentFdError;
var
  LPoller: TPlatformPoller;
  LErr: Int32;
begin
  Check(platform_poller_create(LPoller) = 0, 'poller_create');

  { Modify non-existent fd should fail }
  LErr := platform_poller_modify(LPoller, PtrUInt(9999), [peReadable], nil);
  Check(LErr <> 0, 'modify nonexistent should fail');

  Check(platform_poller_close(LPoller) = 0, 'close poller');
end;

{ 8. Enable wake socket pair creates successfully }
procedure TestEnableWakeSocketPair;
var
  LPoller: TPlatformPoller;
  LErr: Int32;
begin
  Check(platform_poller_create(LPoller) = 0, 'poller_create');

  LErr := platform_poller_enable_wake(LPoller, nil);
  Check(LErr = 0, 'enable_wake');

  { Verify wake sockets are created }
  Check(LPoller.WakeReadSocket <> PtrUInt(-1), 'wake read socket created');
  Check(LPoller.WakeWriteSocket <> PtrUInt(-1), 'wake write socket created');

  Check(platform_poller_close(LPoller) = 0, 'close poller');
end;

{ 9. Wake and drain roundtrip }
procedure TestWakeDrainRoundtrip;
var
  LPoller: TPlatformPoller;
  LEntries: array[0..3] of TPlatformPollEntry;
  LCount: Int32;
  LErr: Int32;
begin
  Check(platform_poller_create(LPoller) = 0, 'poller_create');
  LErr := platform_poller_enable_wake(LPoller, nil);
  Check(LErr = 0, 'enable_wake');

  { Send wake signal }
  LErr := platform_poller_wake(LPoller);
  Check(LErr = 0, 'wake');

  { Wait should return wake event }
  LCount := 0;
  LErr := platform_poller_wait(LPoller, @LEntries[0], 4, 100, LCount);
  Check(LErr = 0, 'wait');
  Check(LCount >= 1, 'got wake event');

  { Drain the wake signal }
  LErr := platform_poller_drain_wake(LPoller);
  Check(LErr = 0, 'drain_wake');

  { Second wait should timeout (no more wake events) }
  LCount := 0;
  LErr := platform_poller_wait(LPoller, @LEntries[0], 4, 50, LCount);
  Check(LErr = 0, 'second wait');
  Check(LCount = 0, 'no events after drain');

  Check(platform_poller_close(LPoller) = 0, 'close poller');
end;

{ 10. Poll multiple sockets simultaneously }
procedure TestPollMultipleSockets;
var
  LPoller: TPlatformPoller;
  LServer: TPlatformSocket;
  LClient1: TPlatformSocket;
  LClient2: TPlatformSocket;
  LAccepted1: TPlatformSocket;
  LAccepted2: TPlatformSocket;
  LAddr: TPlatformSockAddr;
  LEntries: array[0..5] of TPlatformPollEntry;
  LCount: Int32;
  LErr: Int32;
  LBuf: array[0..1] of Byte;
  LSent: Int32;
begin
  Check(platform_poller_create(LPoller) = 0, 'poller_create');

  { Create server socket }
  LErr := CreateServerSocket(0, LServer, LAddr);
  Check(LErr = 0, 'create server');
  Check(platform_socket_listen(LServer, 2) = 0, 'listen');

  { Get actual port }
  LErr := platform_socket_getsockname(LServer, @LAddr, @LAddr.Len);
  Check(LErr = 0, 'getsockname');

  { Create two clients and connect }
  LErr := CreateTestSocket(LClient1);
  Check(LErr = 0, 'create client1');
  LErr := platform_socket_connect(LClient1, @LAddr, LAddr.Len);
  Check(LErr = 0, 'connect client1');

  LErr := CreateTestSocket(LClient2);
  Check(LErr = 0, 'create client2');
  LErr := platform_socket_connect(LClient2, @LAddr, LAddr.Len);
  Check(LErr = 0, 'connect client2');

  { Accept connections }
  LErr := platform_socket_accept(LServer, nil, nil, LAccepted1);
  Check(LErr = 0, 'accept1');
  LErr := platform_socket_accept(LServer, nil, nil, LAccepted2);
  Check(LErr = 0, 'accept2');
  platform_socket_close(LServer);

  { Add both accepted sockets to poller }
  LErr := platform_poller_add(LPoller, LAccepted1.Value, [peReadable], nil);
  Check(LErr = 0, 'add accepted1');
  LErr := platform_poller_add(LPoller, LAccepted2.Value, [peReadable], nil);
  Check(LErr = 0, 'add accepted2');

  { Send data to both sockets }
  LBuf[0] := 1;
  LSent := 0;
  LErr := platform_socket_send(LClient1, @LBuf[0], 1, 0, LSent);
  Check(LErr = 0, 'send to client1');
  LBuf[0] := 2;
  LSent := 0;
  LErr := platform_socket_send(LClient2, @LBuf[0], 1, 0, LSent);
  Check(LErr = 0, 'send to client2');
  platform_socket_close(LClient1);
  platform_socket_close(LClient2);

  { Wait should return both readable events }
  LCount := 0;
  LErr := platform_poller_wait(LPoller, @LEntries[0], 4, 100, LCount);
  Check(LErr = 0, 'wait');
  Check(LCount = 2, 'two events');

  platform_socket_close(LAccepted1);
  platform_socket_close(LAccepted2);
  Check(platform_poller_close(LPoller) = 0, 'close poller');
end;

{$ELSE}

procedure TestNonWindowsSkip;
begin
  WriteLn('not Windows runtime evidence on this host');
  Check(True, 'non-Windows skip');
end;

{$ENDIF}

begin
  T := TTestRunner.Create('nextpas.core.platform.io.windows_real');
  {$IFDEF NEXTPAS_WINDOWS}
  T.Run('create_with_winsock_init', @TestCreateWithWinsockInit);
  T.Run('close_cleans_up_winsock', @TestCloseCleansUpWinsock);
  T.Run('wait_polling_with_ready_socket', @TestWaitPollingWithReadySocket);
  T.Run('wait_timeout_no_events', @TestWaitTimeoutNoEvents);
  T.Run('add_duplicate_fd_error', @TestAddDuplicateFdError);
  T.Run('remove_nonexistent_fd_error', @TestRemoveNonexistentFdError);
  T.Run('modify_nonexistent_fd_error', @TestModifyNonexistentFdError);
  T.Run('enable_wake_socket_pair', @TestEnableWakeSocketPair);
  T.Run('wake_drain_roundtrip', @TestWakeDrainRoundtrip);
  T.Run('poll_multiple_sockets', @TestPollMultipleSockets);
  {$ELSE}
  T.Run('non-Windows skip', @TestNonWindowsSkip);
  {$ENDIF}
  T.Summary;
end.