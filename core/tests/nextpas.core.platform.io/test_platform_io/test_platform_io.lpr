program test_platform_io;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.io.base,
  nextpas.core.platform.io,
  nextpas.core.platform.posix.ffi,
  nextpas.core.testing;

var
  T: TTestRunner;

procedure TestCreateClose;
var
  P: TPlatformPoller;
begin
  Check(platform_poller_create(P) = 0, 'create');
  Check(platform_poller_close(P) = 0, 'close');
end;

procedure TestDoubleClose;
var
  P: TPlatformPoller;
begin
  Check(platform_poller_create(P) = 0, 'create');
  Check(platform_poller_close(P) = 0, 'close first');
  Check(platform_poller_close(P) <> 0, 'close second returns error');
end;

procedure TestPipeReadable;
var
  P: TPlatformPoller;
  LPipeFd: array[0..1] of Int32;
  LEntries: array[0..3] of TPlatformPollEntry;
  LCount: Int32;
  LBuf: Byte;
  LWritten: PtrInt;
begin
  Check(pipe(@LPipeFd[0]) = 0, 'pipe');
  Check(platform_poller_create(P) = 0, 'create');
  Check(platform_poller_add(P, LPipeFd[0], [peReadable], nil) = 0, 'add read end');

  LBuf := 42;
  LWritten := write(LPipeFd[1], @LBuf, 1);
  Check(LWritten = 1, 'write to pipe');

  Check(platform_poller_wait(P, @LEntries[0], 4, 1000, LCount) = 0, 'wait');
  Check(LCount = 1, 'got 1 event');
  Check(peReadable in LEntries[0].REvents, 'event is readable');

  close(LPipeFd[0]);
  close(LPipeFd[1]);
  Check(platform_poller_close(P) = 0, 'close poller');
end;

procedure TestTimeoutZero;
var
  P: TPlatformPoller;
  LPipeFd: array[0..1] of Int32;
  LEntries: array[0..3] of TPlatformPollEntry;
  LCount: Int32;
begin
  Check(pipe(@LPipeFd[0]) = 0, 'pipe');
  Check(platform_poller_create(P) = 0, 'create');
  Check(platform_poller_add(P, LPipeFd[0], [peReadable], nil) = 0, 'add');

  Check(platform_poller_wait(P, @LEntries[0], 4, 0, LCount) = 0, 'wait timeout=0');
  Check(LCount = 0, 'no events ready');

  close(LPipeFd[0]);
  close(LPipeFd[1]);
  platform_poller_close(P);
end;

procedure TestRemove;
var
  P: TPlatformPoller;
  LPipeFd: array[0..1] of Int32;
  LEntries: array[0..3] of TPlatformPollEntry;
  LCount: Int32;
  LBuf: Byte;
begin
  Check(pipe(@LPipeFd[0]) = 0, 'pipe');
  Check(platform_poller_create(P) = 0, 'create');
  Check(platform_poller_add(P, LPipeFd[0], [peReadable], nil) = 0, 'add');
  Check(platform_poller_remove(P, LPipeFd[0]) = 0, 'remove');

  LBuf := 1;
  write(LPipeFd[1], @LBuf, 1);

  Check(platform_poller_wait(P, @LEntries[0], 4, 0, LCount) = 0, 'wait after remove');
  Check(LCount = 0, 'no events after remove');

  close(LPipeFd[0]);
  close(LPipeFd[1]);
  platform_poller_close(P);
end;

procedure TestUserData;
var
  P: TPlatformPoller;
  LPipeFd: array[0..1] of Int32;
  LEntries: array[0..3] of TPlatformPollEntry;
  LCount: Int32;
  LBuf: Byte;
  LTag: PtrUInt;
begin
  LTag := $DEADBEEF;
  Check(pipe(@LPipeFd[0]) = 0, 'pipe');
  Check(platform_poller_create(P) = 0, 'create');
  Check(platform_poller_add(P, LPipeFd[0], [peReadable], Pointer(LTag)) = 0, 'add with userdata');

  LBuf := 7;
  write(LPipeFd[1], @LBuf, 1);

  Check(platform_poller_wait(P, @LEntries[0], 4, 1000, LCount) = 0, 'wait');
  Check(LCount = 1, 'got event');
  Check(PtrUInt(LEntries[0].UserData) = LTag, 'userdata preserved');

  close(LPipeFd[0]);
  close(LPipeFd[1]);
  platform_poller_close(P);
end;

procedure TestMultipleFds;
var
  P: TPlatformPoller;
  LPipe1, LPipe2: array[0..1] of Int32;
  LEntries: array[0..7] of TPlatformPollEntry;
  LCount: Int32;
  LBuf: Byte;
begin
  Check(pipe(@LPipe1[0]) = 0, 'pipe1');
  Check(pipe(@LPipe2[0]) = 0, 'pipe2');
  Check(platform_poller_create(P) = 0, 'create');
  Check(platform_poller_add(P, LPipe1[0], [peReadable], Pointer(PtrUInt(1))) = 0, 'add pipe1');
  Check(platform_poller_add(P, LPipe2[0], [peReadable], Pointer(PtrUInt(2))) = 0, 'add pipe2');

  LBuf := 1;
  write(LPipe1[1], @LBuf, 1);
  write(LPipe2[1], @LBuf, 1);

  Check(platform_poller_wait(P, @LEntries[0], 8, 1000, LCount) = 0, 'wait');
  Check(LCount = 2, 'got 2 events');

  close(LPipe1[0]); close(LPipe1[1]);
  close(LPipe2[0]); close(LPipe2[1]);
  platform_poller_close(P);
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.io');
  T.Run('create/close', @TestCreateClose);
  T.Run('double close', @TestDoubleClose);
  T.Run('pipe readable', @TestPipeReadable);
  T.Run('timeout zero', @TestTimeoutZero);
  T.Run('remove stops events', @TestRemove);
  T.Run('userdata preserved', @TestUserData);
  T.Run('multiple fds', @TestMultipleFds);
  T.Summary;
end.
