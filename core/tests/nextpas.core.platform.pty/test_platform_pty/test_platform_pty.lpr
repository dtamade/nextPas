program test_platform_pty;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.testing,
  nextpas.core.platform.pty.base,
  nextpas.core.platform.pty
{$IFDEF NEXTPAS_UNIX}
  ,
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi
{$ENDIF}
  ;

var
  T: TTestRunner;

{$IFDEF NEXTPAS_UNIX}
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
  waitpid(LPid, nil, 0);
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

procedure TestSpawnBadCwd;
var
  LPty: TPlatformPty;
  LSize: TPlatformPtySize;
  LPid, LRc: Int32;
  LStage: TPlatformPtySpawnStage;
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
  LRc := platform_pty_spawn(LPty, '/bin/sh', @LArgv[0], nil,
    '/definitely/not/a/real/directory', LPid, LStage);
  Check(LRc <> 0, 'spawn with bad cwd should fail');
  Check(LStage = ptssChdir, 'fail stage should be chdir');

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
  waitpid(LPid, nil, 0);
end;

procedure TestMasterReadWrite;
var
  LPty: TPlatformPty;
  LSize: TPlatformPtySize;
  LPid, LRc: Int32;
  LStage: TPlatformPtySpawnStage;
  LBuf: array[0..255] of AnsiChar;
  LN: ssize_t;
  LArgv: array[0..3] of PAnsiChar;
  LMsg: PAnsiChar;
begin
  LSize.FCols := 80;
  LSize.FRows := 24;
  LSize.FXPixel := 0;
  LSize.FYPixel := 0;
  LRc := platform_pty_open(LSize, LPty);
  Check(LRc = 0, 'open');

  LArgv[0] := '/bin/sh';
  LArgv[1] := '-c';
  LArgv[2] := 'read line; printf "%s\n" "$line"';
  LArgv[3] := nil;
  LRc := platform_pty_spawn(LPty, '/bin/sh', @LArgv[0], nil, nil, LPid, LStage);
  Check(LRc = 0, 'spawn echo shell');

  LMsg := 'roundtrip_test'#10;
  write(LPty.FMasterFd, LMsg, 15);

  FillChar(LBuf, SizeOf(LBuf), 0);
  LN := read(LPty.FMasterFd, @LBuf[0], 255);
  Check(LN > 0, 'should read echo from cat');
  Check(Pos('roundtrip_test', string(PAnsiChar(@LBuf[0]))) > 0, 'roundtrip data');

  platform_pty_close(LPty);
  waitpid(LPid, nil, 0);
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
{$ELSE}
function NeverRunShapeOnly: Boolean;
begin
  Result := False;
end;

procedure TestPtyApiShape;
var
  LPty: TPlatformPty;
  LSize: TPlatformPtySize;
  LPid: Int32;
  LStage: TPlatformPtySpawnStage;
begin
  FillChar(LPty, SizeOf(LPty), 0);
  LSize.FCols := 80;
  LSize.FRows := 24;
  LSize.FXPixel := 0;
  LSize.FYPixel := 0;
  Check(SizeOf(LPty) > 0, 'pty carrier has storage');
  if NeverRunShapeOnly then
  begin
    platform_pty_master_fd(LPty);
    LPid := -1;
    LStage := ptssNone;
    platform_pty_spawn(LPty, nil, nil, nil, nil, LPid, LStage);
    platform_pty_resize(LPty, LSize);
    platform_pty_close(LPty);
  end;
end;
{$ENDIF}

begin
  T := TTestRunner.Create('platform.pty');
{$IFDEF NEXTPAS_UNIX}
  T.Run('TestOpenClose', @TestOpenClose);
  T.Run('TestResize', @TestResize);
  T.Run('TestSpawnEcho', @TestSpawnEcho);
  T.Run('TestSpawnBadPath', @TestSpawnBadPath);
  T.Run('TestSpawnBadCwd', @TestSpawnBadCwd);
  T.Run('TestSpawnCwd', @TestSpawnCwd);
  T.Run('TestMasterReadWrite', @TestMasterReadWrite);
  T.Run('TestMasterFd', @TestMasterFd);
{$ELSE}
  T.Run('TestPtyApiShape', @TestPtyApiShape);
{$ENDIF}
  T.Summary;
  if not T.AllPassed then
    Halt(1);
end.
