program test_platform_console_raw;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.console,
  nextpas.core.platform.posix.ffi,
  nextpas.core.testing;

var
  T: TTestRunner;

{ 用 pipe 测试 read/write/wait_readable（无需真实 TTY） }

procedure TestWriteReadPipe;
var
  LFds: array[0..1] of Int32;
  LBuf: array[0..15] of Byte;
  LMsg: array[0..4] of Byte;
  LWrote, LRead: Int32;
begin
  { pipe(fds): fds[0] 读端, fds[1] 写端 }
  if pipe(@LFds[0]) <> 0 then
  begin
    Fail('pipe() failed');
    Exit;
  end;
  LMsg[0] := Ord('h'); LMsg[1] := Ord('e'); LMsg[2] := Ord('l');
  LMsg[3] := Ord('l'); LMsg[4] := Ord('o');
  LWrote := platform_console_write(LFds[1], @LMsg[0], 5);
  CheckEqual(Int64(5), Int64(LWrote), 'wrote 5 bytes');
  LRead := platform_console_read(LFds[0], @LBuf[0], 16);
  CheckEqual(Int64(5), Int64(LRead), 'read 5 bytes');
  Check((LBuf[0] = Ord('h')) and (LBuf[4] = Ord('o')), 'content matches');
  close(LFds[0]);
  close(LFds[1]);
end;

procedure TestWaitReadableTimeout;
var
  LFds: array[0..1] of Int32;
  LResult: TPlatformConsoleWait;
begin
  if pipe(@LFds[0]) <> 0 then begin Fail('pipe() failed'); Exit; end;
  { 读端无数据 -> 超时 }
  LResult := platform_console_wait_readable(LFds[0], 10);
  Check(LResult = cwTimeout, 'empty pipe times out');
  close(LFds[0]);
  close(LFds[1]);
end;

procedure TestWaitReadableReady;
var
  LFds: array[0..1] of Int32;
  LMsg: Byte;
  LResult: TPlatformConsoleWait;
begin
  if pipe(@LFds[0]) <> 0 then begin Fail('pipe() failed'); Exit; end;
  LMsg := Ord('x');
  platform_console_write(LFds[1], @LMsg, 1);
  { 写入后读端应可读 }
  LResult := platform_console_wait_readable(LFds[0], 100);
  Check(LResult = cwReadable, 'pipe with data is readable');
  close(LFds[0]);
  close(LFds[1]);
end;

procedure TestIsTerminalPipe;
var
  LFds: array[0..1] of Int32;
begin
  if pipe(@LFds[0]) <> 0 then begin Fail('pipe() failed'); Exit; end;
  Check(not platform_console_is_terminal(LFds[0]), 'pipe not a terminal');
  close(LFds[0]);
  close(LFds[1]);
end;

procedure TestModeCarrierSize;
var
  LMode: TPlatformConsoleMode;
begin
  { 不透明载体足够大（>= termios 大小） }
  Check(SizeOf(LMode.Opaque) >= 64, 'opaque carrier >= 64 bytes');
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.console.raw');
  T.Run('write+read pipe', @TestWriteReadPipe);
  T.Run('wait readable timeout', @TestWaitReadableTimeout);
  T.Run('wait readable ready', @TestWaitReadableReady);
  T.Run('is terminal pipe', @TestIsTerminalPipe);
  T.Run('mode carrier size', @TestModeCarrierSize);
  T.Summary;
  if not T.AllPassed then
    Halt(1);
end.
