program test_platform_pty;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.testing,
  nextpas.core.platform.pty.base,
  nextpas.core.platform.pty,
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi;

var
  T: TTestRunner;

procedure TestOpenClose;
var
  LPty: TPlatformPty;
  LSize: TPlatformPtySize;
  LRc: Int32;
begin
  LSize.FCols := 80;
  LSize.FRows := 24;
  LSize.FXPixel := 0;
  LSize.FYPixel := 0;
  LRc := platform_pty_open(LSize, LPty);
  Check(LRc = 0, 'open should succeed');
  Check(LPty.FMasterFd > 2, 'master fd > 2');
  Check(LPty.FSlaveFd > 2, 'slave fd > 2');
  Check(LPty.FMasterFd <> LPty.FSlaveFd, 'master <> slave');
  LRc := platform_pty_close(LPty);
  Check(LRc = 0, 'close should succeed');
end;

procedure TestResize;
var
  LPty: TPlatformPty;
  LSize: TPlatformPtySize;
  LRc: Int32;
begin
  LSize.FCols := 80;
  LSize.FRows := 24;
  LSize.FXPixel := 0;
  LSize.FYPixel := 0;
  LRc := platform_pty_open(LSize, LPty);
  Check(LRc = 0, 'open');

  LSize.FCols := 120;
  LSize.FRows := 40;
  LRc := platform_pty_resize(LPty, LSize);
  Check(LRc = 0, 'resize should succeed');

  platform_pty_close(LPty);
end;

procedure TestSpawnEcho;
var
  LPty: TPlatformPty;
  LSize: TPlatformPtySize;
  LPid, LRc: Int32;
  LStage: TPlatformPtySpawnStage;
  LBuf: array[0..255] of AnsiChar;
  LN: ssize_t;
  LArgv: array[0..2] of PAnsiChar;
begin
  LSize.FCols := 80;
  LSize.FRows := 24;
  LSize.FXPixel := 0;
  LSize.FYPixel := 0;
  LRc := platform_pty_open(LSize, LPty);
  Check(LRc = 0, 'open');

  LArgv[0] := '/bin/echo';
  LArgv[1] := 'hello_pty';
  LArgv[2] := nil;
  LRc := platform_pty_spawn(LPty, '/bin/echo', @LArgv[0], nil, nil, LPid, LStage);
  Check(LRc = 0, 'spawn echo should succeed');
  Check(LPid > 0, 'pid > 0');

  FillChar(LBuf, SizeOf(LBuf), 0);
  LN := read(LPty.FMasterFd, @LBuf[0], 255);
  Check(LN > 0, 'should read output from pty');

  { PTY may add \r\n, check substring }
  Check(Pos('hello_pty', string(PAnsiChar(@LBuf[0]))) > 0, 'output contains hello_pty');

  platform_pty_close(LPty);
end;

procedure TestSpawnBadPath;
var
  LPty: TPlatformPty;
  LSize: TPlatformPtySize;
  LPid, LRc: Int32;
  LStage: TPlatformPtySpawnStage;
  LArgv: array[0..1] of PAnsiChar;
begin
  LSize.FCols := 80;
  LSize.FRows := 24;
  LSize.FXPixel := 0;
  LSize.FYPixel := 0;
  LRc := platform_pty_open(LSize, LPty);
  Check(LRc = 0, 'open');

  LArgv[0] := '/nonexistent_binary_xyz';
  LArgv[1] := nil;
  LRc := platform_pty_spawn(LPty, '/nonexistent_binary_xyz', @LArgv[0], nil, nil, LPid, LStage);
  Check(LRc <> 0, 'spawn bad path should fail');
  Check(LStage = ptssExec, 'fail stage should be exec');

  platform_pty_close(LPty);
end;

procedure TestSpawnCwd;
var
  LPty: TPlatformPty;
  LSize: TPlatformPtySize;
  LPid, LRc: Int32;
  LStage: TPlatformPtySpawnStage;
  LBuf: array[0..255] of AnsiChar;
  LN: ssize_t;
  LArgv: array[0..3] of PAnsiChar;
begin
  LSize.FCols := 80;
  LSize.FRows := 24;
  LSize.FXPixel := 0;
  LSize.FYPixel := 0;
  LRc := platform_pty_open(LSize, LPty);
  Check(LRc = 0, 'open');

  LArgv[0] := '/bin/sh';
  LArgv[1] := '-c';
  LArgv[2] := 'pwd';
  LArgv[3] := nil;
  LRc := platform_pty_spawn(LPty, '/bin/sh', @LArgv[0], nil, '/tmp', LPid, LStage);
  Check(LRc = 0, 'spawn pwd in /tmp');
  Check(LPid > 0, 'pid > 0');

  FillChar(LBuf, SizeOf(LBuf), 0);
  LN := read(LPty.FMasterFd, @LBuf[0], 255);
  Check(LN > 0, 'should read output');
  Check(Pos('/tmp', string(PAnsiChar(@LBuf[0]))) > 0, 'output contains /tmp');

  platform_pty_close(LPty);
end;

procedure TestMasterReadWrite;
var
  LPty: TPlatformPty;
  LSize: TPlatformPtySize;
  LPid, LRc: Int32;
  LStage: TPlatformPtySpawnStage;
  LBuf: array[0..255] of AnsiChar;
  LN: ssize_t;
  LArgv: array[0..1] of PAnsiChar;
  LMsg: PAnsiChar;
begin
  LSize.FCols := 80;
  LSize.FRows := 24;
  LSize.FXPixel := 0;
  LSize.FYPixel := 0;
  LRc := platform_pty_open(LSize, LPty);
  Check(LRc = 0, 'open');

  LArgv[0] := '/bin/cat';
  LArgv[1] := nil;
  LRc := platform_pty_spawn(LPty, '/bin/cat', @LArgv[0], nil, nil, LPid, LStage);
  Check(LRc = 0, 'spawn cat');

  LMsg := 'roundtrip_test'#10;
  write(LPty.FMasterFd, LMsg, 15);

  FillChar(LBuf, SizeOf(LBuf), 0);
  LN := read(LPty.FMasterFd, @LBuf[0], 255);
  Check(LN > 0, 'should read echo from cat');
  Check(Pos('roundtrip_test', string(PAnsiChar(@LBuf[0]))) > 0, 'roundtrip data');

  platform_pty_close(LPty);
end;

procedure TestMasterFd;
var
  LPty: TPlatformPty;
  LSize: TPlatformPtySize;
  LRc: Int32;
begin
  LSize.FCols := 80;
  LSize.FRows := 24;
  LSize.FXPixel := 0;
  LSize.FYPixel := 0;
  LRc := platform_pty_open(LSize, LPty);
  Check(LRc = 0, 'open');
  Check(platform_pty_master_fd(LPty) = PtrInt(LPty.FMasterFd), 'master_fd matches');
  platform_pty_close(LPty);
end;

begin
  T := TTestRunner.Create('platform.pty');
  T.Run('TestOpenClose', @TestOpenClose);
  T.Run('TestResize', @TestResize);
  T.Run('TestSpawnEcho', @TestSpawnEcho);
  T.Run('TestSpawnBadPath', @TestSpawnBadPath);
  T.Run('TestSpawnCwd', @TestSpawnCwd);
  T.Run('TestMasterReadWrite', @TestMasterReadWrite);
  T.Run('TestMasterFd', @TestMasterFd);
  T.Summary;
  if not T.AllPassed then
    Halt(1);
end.
