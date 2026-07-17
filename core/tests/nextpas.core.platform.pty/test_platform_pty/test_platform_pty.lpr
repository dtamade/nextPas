program test_platform_pty;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.fs,
  nextpas.core.fs.util,
  nextpas.core.test,
  nextpas.core.text.conv,
  nextpas.core.platform.pty.base,
  nextpas.core.platform.pty
{$IFDEF NEXTPAS_UNIX}
  ,
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi
{$ENDIF}
  ;

var
  T: TTestSuite;

function LoadSourceText(const ARelativePath: string): string;
begin
  Check(FileExists(ARelativePath), 'source file exists: ' + ARelativePath);
  Result := FsReadFileText(ARelativePath);
end;

procedure CheckContains(const ASource, AToken, AMessage: string);
begin
  Check(Pos(AToken, ASource) > 0, AMessage + ': ' + AToken);
end;

{$IFDEF NEXTPAS_UNIX}
procedure TestOpenClose;
var
  LPty: TPlatformPty;
  LSize: TPlatformPtySize;
  LRc: Int32;
begin
  LSize.Cols := 80;
  LSize.Rows := 24;
  LSize.XPixel := 0;
  LSize.YPixel := 0;
  LRc := platform_pty_open(LSize, LPty);
  Check(LRc = 0, 'open should succeed');
  Check(LPty.MasterFd > 2, 'master fd > 2');
  Check(LPty.SlaveFd > 2, 'slave fd > 2');
  Check(LPty.MasterFd <> LPty.SlaveFd, 'master <> slave');
  LRc := platform_pty_close(LPty);
  Check(LRc = 0, 'close should succeed');
end;

procedure TestResize;
var
  LPty: TPlatformPty;
  LSize: TPlatformPtySize;
  LRc: Int32;
begin
  LSize.Cols := 80;
  LSize.Rows := 24;
  LSize.XPixel := 0;
  LSize.YPixel := 0;
  LRc := platform_pty_open(LSize, LPty);
  Check(LRc = 0, 'open');

  LSize.Cols := 120;
  LSize.Rows := 40;
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
  LSize.Cols := 80;
  LSize.Rows := 24;
  LSize.XPixel := 0;
  LSize.YPixel := 0;
  LRc := platform_pty_open(LSize, LPty);
  Check(LRc = 0, 'open');

  LArgv[0] := '/bin/echo';
  LArgv[1] := 'hello_pty';
  LArgv[2] := nil;
  LRc := platform_pty_spawn(LPty, '/bin/echo', @LArgv[0], nil, nil, LPid, LStage);
  Check(LRc = 0, 'spawn echo should succeed');
  Check(LPid > 0, 'pid > 0');

  FillChar(LBuf, SizeOf(LBuf), 0);
  LN := read(LPty.MasterFd, @LBuf[0], 255);
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
  LSize.Cols := 80;
  LSize.Rows := 24;
  LSize.XPixel := 0;
  LSize.YPixel := 0;
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
  LSize.Cols := 80;
  LSize.Rows := 24;
  LSize.XPixel := 0;
  LSize.YPixel := 0;
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
  LSize.Cols := 80;
  LSize.Rows := 24;
  LSize.XPixel := 0;
  LSize.YPixel := 0;
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
  LN := read(LPty.MasterFd, @LBuf[0], 255);
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
  LSize.Cols := 80;
  LSize.Rows := 24;
  LSize.XPixel := 0;
  LSize.YPixel := 0;
  LRc := platform_pty_open(LSize, LPty);
  Check(LRc = 0, 'open');

  LArgv[0] := '/bin/sh';
  LArgv[1] := '-c';
  LArgv[2] := 'read line; printf "%s\n" "$line"';
  LArgv[3] := nil;
  LRc := platform_pty_spawn(LPty, '/bin/sh', @LArgv[0], nil, nil, LPid, LStage);
  Check(LRc = 0, 'spawn echo shell');

  LMsg := 'roundtrip_test'#10;
  write(LPty.MasterFd, LMsg, 15);

  FillChar(LBuf, SizeOf(LBuf), 0);
  LN := read(LPty.MasterFd, @LBuf[0], 255);
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
  LSize.Cols := 80;
  LSize.Rows := 24;
  LSize.XPixel := 0;
  LSize.YPixel := 0;
  LRc := platform_pty_open(LSize, LPty);
  Check(LRc = 0, 'open');
  Check(platform_pty_master_fd(LPty) = PtrInt(LPty.MasterFd), 'master_fd matches');
  platform_pty_close(LPty);
end;

procedure TestDoubleClose;
var
  LPty: TPlatformPty;
  LSize: TPlatformPtySize;
  LRc: Int32;
begin
  LSize.Cols := 80;
  LSize.Rows := 24;
  LSize.XPixel := 0;
  LSize.YPixel := 0;
  LRc := platform_pty_open(LSize, LPty);
  Check(LRc = 0, 'open');
  Check(platform_pty_close(LPty) = 0, 'first close');
  // Second close should succeed (no-op since fds are already -1)
  Check(platform_pty_close(LPty) = 0, 'second close no-op');
end;

procedure TestResizeAfterClose;
var
  LPty: TPlatformPty;
  LSize: TPlatformPtySize;
  LRc: Int32;
begin
  LSize.Cols := 80;
  LSize.Rows := 24;
  LSize.XPixel := 0;
  LSize.YPixel := 0;
  LRc := platform_pty_open(LSize, LPty);
  Check(LRc = 0, 'open');
  platform_pty_close(LPty);

  LSize.Cols := 120;
  LRc := platform_pty_resize(LPty, LSize);
  Check(LRc <> 0, 'resize after close should fail');
end;

procedure TestSpawnWithEnv;
var
  LPty: TPlatformPty;
  LSize: TPlatformPtySize;
  LPid, LRc: Int32;
  LStage: TPlatformPtySpawnStage;
  LBuf: array[0..255] of AnsiChar;
  LN: ssize_t;
  LArgv: array[0..3] of PAnsiChar;
  LEnvp: array[0..2] of PAnsiChar;
begin
  LSize.Cols := 80;
  LSize.Rows := 24;
  LSize.XPixel := 0;
  LSize.YPixel := 0;
  LRc := platform_pty_open(LSize, LPty);
  Check(LRc = 0, 'open');

  LArgv[0] := '/bin/sh';
  LArgv[1] := '-c';
  LArgv[2] := 'echo $NEXTPAS_TEST_VAR';
  LArgv[3] := nil;
  LEnvp[0] := 'NEXTPAS_TEST_VAR=hello_env';
  LEnvp[1] := nil;
  LRc := platform_pty_spawn(LPty, '/bin/sh', @LArgv[0], @LEnvp[0], nil, LPid, LStage);
  Check(LRc = 0, 'spawn with env');
  Check(LPid > 0, 'pid > 0');

  FillChar(LBuf, SizeOf(LBuf), 0);
  LN := read(LPty.MasterFd, @LBuf[0], 255);
  Check(LN > 0, 'should read output');
  Check(Pos('hello_env', string(PAnsiChar(@LBuf[0]))) > 0, 'output contains env var');

  platform_pty_close(LPty);
  waitpid(LPid, nil, 0);
end;

procedure TestSpawnLargeOutput;
var
  LPty: TPlatformPty;
  LSize: TPlatformPtySize;
  LPid, LRc: Int32;
  LStage: TPlatformPtySpawnStage;
  LBuf: array[0..4095] of AnsiChar;
  LN: ssize_t;
  LArgv: array[0..3] of PAnsiChar;
begin
  LSize.Cols := 80;
  LSize.Rows := 24;
  LSize.XPixel := 0;
  LSize.YPixel := 0;
  LRc := platform_pty_open(LSize, LPty);
  Check(LRc = 0, 'open');

  LArgv[0] := '/bin/sh';
  LArgv[1] := '-c';
  LArgv[2] := 'for i in $(seq 1 20); do echo "line_$i"; done';
  LArgv[3] := nil;
  LRc := platform_pty_spawn(LPty, '/bin/sh', @LArgv[0], nil, nil, LPid, LStage);
  Check(LRc = 0, 'spawn large output');
  Check(LPid > 0, 'pid > 0');

  FillChar(LBuf, SizeOf(LBuf), 0);
  LN := read(LPty.MasterFd, @LBuf[0], 4095);
  Check(LN > 0, 'should read output');
  Check(Pos('line_1', string(PAnsiChar(@LBuf[0]))) > 0, 'output contains line_1');

  platform_pty_close(LPty);
  waitpid(LPid, nil, 0);
end;

procedure TestResizeMultiple;
var
  LPty: TPlatformPty;
  LSize: TPlatformPtySize;
  I: Int32;
begin
  LSize.Cols := 80;
  LSize.Rows := 24;
  LSize.XPixel := 0;
  LSize.YPixel := 0;
  Check(platform_pty_open(LSize, LPty) = 0, 'open');
  for I := 0 to 9 do
  begin
    LSize.Cols := 80 + I;
    LSize.Rows := 24 + I;
    Check(platform_pty_resize(LPty, LSize) = 0, 'resize ' + IntToStr(I));
  end;
  platform_pty_close(LPty);
end;

procedure TestOpenCloseCycle;
var
  LPty: TPlatformPty;
  LSize: TPlatformPtySize;
  I: Int32;
begin
  LSize.Cols := 80;
  LSize.Rows := 24;
  LSize.XPixel := 0;
  LSize.YPixel := 0;
  for I := 0 to 9 do
  begin
    Check(platform_pty_open(LSize, LPty) = 0, 'open ' + IntToStr(I));
    platform_pty_close(LPty);
  end;
end;

procedure TestSpawnNilArgv;
var
  LPty: TPlatformPty;
  LSize: TPlatformPtySize;
  LPid, LRc: Int32;
  LStage: TPlatformPtySpawnStage;
begin
  LSize.Cols := 80; LSize.Rows := 24;
  LSize.XPixel := 0; LSize.YPixel := 0;
  Check(platform_pty_open(LSize, LPty) = 0, 'open');
  { nil argv is passed to execvp — behavior is implementation-defined }
  LRc := platform_pty_spawn(LPty, '/bin/true', nil, nil, nil, LPid, LStage);
  { We just verify it doesn't crash; result depends on platform }
  Check(True, 'spawn with nil argv did not crash');
  if LRc = 0 then
    platform_pty_close(LPty)
  else
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
  LSize.Cols := 80;
  LSize.Rows := 24;
  LSize.XPixel := 0;
  LSize.YPixel := 0;
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

procedure TestPosixExitSourceContract;
var
  LSource: string;
begin
  LSource := LoadSourceText('../../../src/nextpas.core.platform.pty.pas');
  CheckContains(LSource, 'posix_exit is _exit',
    'pty child failure path must document posix_exit semantics');
end;

procedure TestWindowsMasterFdInvalidSourceContract;
var
  LSource: string;
begin
  LSource := LoadSourceText('../../../src/nextpas.core.platform.pty.pas');
  CheckContains(LSource, 'if APty.PipeOut = 0 then',
    'windows master_fd must normalize closed pipe handle before exposing it');
  CheckContains(LSource, 'Exit(-1);',
    'windows master_fd must return -1 for invalid handle state');
end;

procedure TestUnsupportedCloseSourceContract;
var
  LSource: string;
begin
  LSource := LoadSourceText('../../../src/nextpas.core.platform.pty.pas');
  CheckContains(LSource,
    'function platform_pty_close(var APty: TPlatformPty): Int32;' + LineEnding +
    'begin FillChar(APty, SizeOf(APty), 0); Result := PLATFORM_ERR_UNSUPPORTED; end;',
    'unsupported close should still clear the PTY carrier before returning unsupported');
end;

procedure TestPtySizeEmptySemantics;
var
  LSize: TPlatformPtySize;
begin
  LSize.Cols := 0;
  LSize.Rows := 24;
  LSize.XPixel := 0;
  LSize.YPixel := 0;
  Check(not LSize.IsEmpty, 'single zero dimension is invalid, not empty');

  LSize.Cols := 80;
  LSize.Rows := 0;
  Check(not LSize.IsEmpty, 'other single zero dimension is invalid, not empty');

  LSize.Cols := 0;
  LSize.Rows := 0;
  Check(LSize.IsEmpty, 'both zero dimensions are empty');
end;

procedure TestWindowsValiditySourceContract;
var
  LSource: string;
begin
  LSource := LoadSourceText('../../../src/nextpas.core.platform.pty.base.pas');
  CheckContains(LSource,
    'function TPlatformPty.IsMasterValid: Boolean;' + LineEnding +
    'begin' + LineEnding +
    '{$IFDEF NEXTPAS_UNIX}' + LineEnding +
    '  Result := MasterFd >= 0;' + LineEnding +
    '{$ENDIF}' + LineEnding +
    '{$IFDEF NEXTPAS_WINDOWS}' + LineEnding +
    '  Result := (PipeIn <> 0) and (PipeOut <> 0);',
    'windows master validity must follow host pipe readiness');
  CheckContains(LSource,
    'function TPlatformPty.IsSlaveValid: Boolean;' + LineEnding +
    'begin' + LineEnding +
    '{$IFDEF NEXTPAS_UNIX}' + LineEnding +
    '  Result := SlaveFd >= 0;' + LineEnding +
    '{$ENDIF}' + LineEnding +
    '{$IFDEF NEXTPAS_WINDOWS}' + LineEnding +
    '  Result := ConPty <> nil;',
    'windows slave validity must follow pseudoconsole readiness');
end;

begin
  T := TTestSuite.Create('platform.pty');
{$IFDEF NEXTPAS_UNIX}
  T.Test('TestOpenClose', @TestOpenClose);
  T.Test('TestResize', @TestResize);
  T.Test('TestSpawnEcho', @TestSpawnEcho);
  T.Test('TestSpawnBadPath', @TestSpawnBadPath);
  T.Test('TestSpawnBadCwd', @TestSpawnBadCwd);
  T.Test('TestSpawnCwd', @TestSpawnCwd);
  T.Test('TestMasterReadWrite', @TestMasterReadWrite);
  T.Test('TestMasterFd', @TestMasterFd);
  T.Test('TestDoubleClose', @TestDoubleClose);
  T.Test('TestResizeAfterClose', @TestResizeAfterClose);
  T.Test('TestSpawnWithEnv', @TestSpawnWithEnv);
  T.Test('TestSpawnLargeOutput', @TestSpawnLargeOutput);
  T.Test('TestResizeMultiple', @TestResizeMultiple);
  T.Test('TestOpenCloseCycle', @TestOpenCloseCycle);
  T.Test('TestSpawnNilArgv', @TestSpawnNilArgv);
{$ELSE}
  T.Test('TestPtyApiShape', @TestPtyApiShape);
{$ENDIF}
  T.Test('posix_exit source contract', @TestPosixExitSourceContract);
  T.Test('Windows master_fd invalid source contract',
    @TestWindowsMasterFdInvalidSourceContract);
  T.Test('unsupported close source contract', @TestUnsupportedCloseSourceContract);
  T.Test('pty size empty semantics', @TestPtySizeEmptySemantics);
  T.Test('windows validity source contract', @TestWindowsValiditySourceContract);
  if not T.Run then Halt(1);
end.
