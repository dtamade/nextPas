program test_platform_io_wine;

{ Real Windows runtime evidence only when compiled and run on a Windows host. }

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.platform.io.base,
  nextpas.core.platform.io
  {$IFDEF NEXTPAS_WINDOWS},
  nextpas.core.platform.windows.base,
  nextpas.core.platform.windows.ffi
  {$ENDIF};

var
  T: TTestRunner;

{$IFDEF NEXTPAS_WINDOWS}

function CreateDummySocket: TSocket;
begin
  Result := winsock_socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
end;

{ 1. Create and close a poller }
procedure TestCreateClose;
var
  P: TPlatformPoller;
begin
  Check(platform_poller_create(P) = 0, 'create');
  Check(platform_poller_close(P) = 0, 'close');
end;

{ 2. Wait with timeout=0 returns immediately with no events }
procedure TestTimeoutZero;
var
  P: TPlatformPoller;
  LEntries: array[0..3] of TPlatformPollEntry;
  LCount: Int32;
begin
  Check(platform_poller_create(P) = 0, 'create');
  Check(platform_poller_wait(P, @LEntries[0], 4, 0, LCount) = 0, 'wait timeout=0');
  Check(LCount = 0, 'no events on empty poller');
  Check(platform_poller_close(P) = 0, 'close');
end;

{ 3. Add and remove a socket fd }
procedure TestAddRemove;
var
  P: TPlatformPoller;
  LSock: TSocket;
begin
  Check(platform_poller_create(P) = 0, 'create poller');
  LSock := CreateDummySocket;
  Check(LSock <> TSocket(INVALID_SOCKET), 'create dummy socket');
  Check(platform_poller_add(P, PtrUInt(LSock), [peReadable], nil) = 0, 'add socket');
  Check(platform_poller_remove(P, PtrUInt(LSock)) = 0, 'remove socket');
  closesocket(LSock);
  Check(platform_poller_close(P) = 0, 'close poller');
end;

{ 4. Modify fd events }
procedure TestModify;
var
  P: TPlatformPoller;
  LSock: TSocket;
begin
  Check(platform_poller_create(P) = 0, 'create poller');
  LSock := CreateDummySocket;
  Check(LSock <> TSocket(INVALID_SOCKET), 'create dummy socket');
  Check(platform_poller_add(P, PtrUInt(LSock), [peReadable], nil) = 0, 'add with peReadable');
  Check(platform_poller_modify(P, PtrUInt(LSock), [peWritable], Pointer(42)) = 0, 'modify to peWritable');
  closesocket(LSock);
  Check(platform_poller_close(P) = 0, 'close poller');
end;

{$ELSE}

procedure TestNonWindowsSkip;
begin
  WriteLn('not Windows runtime evidence on this host');
  Check(True, 'non-Windows skip');
end;

{$ENDIF}

begin
  T := TTestRunner.Create('nextpas.core.platform.io.wine_runtime_smoke');
  {$IFDEF NEXTPAS_WINDOWS}
  T.Run('create/close', @TestCreateClose);
  T.Run('timeout zero', @TestTimeoutZero);
  T.Run('add/remove', @TestAddRemove);
  T.Run('modify', @TestModify);
  {$ELSE}
  T.Run('non-Windows skip', @TestNonWindowsSkip);
  {$ENDIF}
  T.Summary;
end.