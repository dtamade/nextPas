program test_platform_pty;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.platform.pty,
  nextpas.core.platform.pty.base,
  nextpas.core.platform.error,
  nextpas.core.platform.posix.ffi;

var
  T: TTestSuite;

procedure TestPtyOpen;
var
  LPty: TPlatformPty;
  LSize: TPlatformPtySize;
  LRes: Int32;
begin
  FillChar(LPty, SizeOf(LPty), 0);
  FillChar(LSize, SizeOf(LSize), 0);
  LSize.FRows := 24;
  LSize.FCols := 80;
  LRes := platform_pty_open(LSize, LPty);
  if LRes = PLATFORM_ERR_UNSUPPORTED then
  begin
    Check(LRes = PLATFORM_ERR_UNSUPPORTED, 'unsupported on this platform');
    Exit;
  end;
  Check(LRes = 0, 'open must succeed');
  Check(platform_pty_master_fd(LPty) > -1, 'master fd must be positive');
  platform_pty_close(LPty);
end;

procedure TestPtyOpenDefaultSize;
var
  LPty: TPlatformPty;
  LSize: TPlatformPtySize;
  LRes: Int32;
begin
  FillChar(LPty, SizeOf(LPty), 0);
  FillChar(LSize, SizeOf(LSize), 0);
  LRes := platform_pty_open(LSize, LPty);
  if LRes = PLATFORM_ERR_UNSUPPORTED then
  begin
    Check(LRes = PLATFORM_ERR_UNSUPPORTED, 'unsupported on this platform');
    Exit;
  end;
  Check(LRes = 0, 'open with default size must succeed');
  platform_pty_close(LPty);
end;

procedure TestPtySpawnNilPath;
var
  LPty: TPlatformPty;
  LSize: TPlatformPtySize;
  LPid: Int32;
  LFailStage: TPlatformPtySpawnStage;
  LRes: Int32;
begin
  FillChar(LPty, SizeOf(LPty), 0);
  FillChar(LSize, SizeOf(LSize), 0);
  LSize.FRows := 24;
  LSize.FCols := 80;
  LRes := platform_pty_open(LSize, LPty);
  if LRes = PLATFORM_ERR_UNSUPPORTED then
  begin
    Check(LRes = PLATFORM_ERR_UNSUPPORTED, 'unsupported on this platform');
    Exit;
  end;
  Check(LRes = 0, 'open must succeed');
  LRes := platform_pty_spawn(LPty, nil, nil, nil, nil, LPid, LFailStage);
  Check(LRes = PLATFORM_ERR_INVALID, 'nil path must return invalid');
  platform_pty_close(LPty);
end;

procedure TestPtyClose;
var
  LPty: TPlatformPty;
  LSize: TPlatformPtySize;
  LRes: Int32;
begin
  FillChar(LPty, SizeOf(LPty), 0);
  FillChar(LSize, SizeOf(LSize), 0);
  LSize.FRows := 24;
  LSize.FCols := 80;
  LRes := platform_pty_open(LSize, LPty);
  if LRes = PLATFORM_ERR_UNSUPPORTED then
  begin
    Check(LRes = PLATFORM_ERR_UNSUPPORTED, 'unsupported on this platform');
    Exit;
  end;
  Check(LRes = 0, 'open must succeed');
  LRes := platform_pty_close(LPty);
  Check(LRes = 0, 'close must succeed');
end;

procedure TestPtyMasterFd;
var
  LPty: TPlatformPty;
  LSize: TPlatformPtySize;
  LRes: Int32;
begin
  FillChar(LPty, SizeOf(LPty), 0);
  FillChar(LSize, SizeOf(LSize), 0);
  LSize.FRows := 24;
  LSize.FCols := 80;
  LRes := platform_pty_open(LSize, LPty);
  if LRes = PLATFORM_ERR_UNSUPPORTED then
  begin
    Check(LRes = PLATFORM_ERR_UNSUPPORTED, 'unsupported on this platform');
    Exit;
  end;
  Check(LRes = 0, 'open must succeed');
  Check(platform_pty_master_fd(LPty) > -1, 'master fd must be positive');
  platform_pty_close(LPty);
end;

procedure TestPtyResize;
var
  LPty: TPlatformPty;
  LSize: TPlatformPtySize;
  LNewSize: TPlatformPtySize;
  LRes: Int32;
begin
  FillChar(LPty, SizeOf(LPty), 0);
  FillChar(LSize, SizeOf(LSize), 0);
  LSize.FRows := 24;
  LSize.FCols := 80;
  LRes := platform_pty_open(LSize, LPty);
  if LRes = PLATFORM_ERR_UNSUPPORTED then
  begin
    Check(LRes = PLATFORM_ERR_UNSUPPORTED, 'unsupported on this platform');
    Exit;
  end;
  Check(LRes = 0, 'open must succeed');

  FillChar(LNewSize, SizeOf(LNewSize), 0);
  LNewSize.FRows := 50;
  LNewSize.FCols := 120;
  LRes := platform_pty_resize(LPty, LNewSize);
  Check(LRes = 0, 'resize must succeed');

  platform_pty_close(LPty);
end;

procedure TestPtyCloseIdempotent;
var
  LPty: TPlatformPty;
  LSize: TPlatformPtySize;
  LRes: Int32;
begin
  FillChar(LPty, SizeOf(LPty), 0);
  FillChar(LSize, SizeOf(LSize), 0);
  LSize.FRows := 24;
  LSize.FCols := 80;
  LRes := platform_pty_open(LSize, LPty);
  if LRes = PLATFORM_ERR_UNSUPPORTED then
  begin
    Check(LRes = PLATFORM_ERR_UNSUPPORTED, 'unsupported on this platform');
    Exit;
  end;
  Check(LRes = 0, 'open must succeed');

  LRes := platform_pty_close(LPty);
  Check(LRes = 0, 'first close must succeed');
  LRes := platform_pty_close(LPty);
  Check(LRes = 0, 'second close must succeed (idempotent)');
end;

procedure TestPtyMasterFdAfterClose;
var
  LPty: TPlatformPty;
  LSize: TPlatformPtySize;
  LRes: Int32;
begin
  FillChar(LPty, SizeOf(LPty), 0);
  FillChar(LSize, SizeOf(LSize), 0);
  LSize.FRows := 24;
  LSize.FCols := 80;
  LRes := platform_pty_open(LSize, LPty);
  if LRes = PLATFORM_ERR_UNSUPPORTED then
  begin
    Check(LRes = PLATFORM_ERR_UNSUPPORTED, 'unsupported on this platform');
    Exit;
  end;
  Check(LRes = 0, 'open must succeed');

  platform_pty_close(LPty);
  Check(platform_pty_master_fd(LPty) = -1, 'master fd must be -1 after close');
end;

procedure TestPtySpawnEcho;
var
  LPty: TPlatformPty;
  LSize: TPlatformPtySize;
  LPid: Int32;
  LFailStage: TPlatformPtySpawnStage;
  LRes: Int32;
  LArgv: array[0..2] of PAnsiChar;
  LBuf: array[0..255] of AnsiChar;
  LRead: PtrInt;
begin
  FillChar(LPty, SizeOf(LPty), 0);
  FillChar(LSize, SizeOf(LSize), 0);
  LSize.FRows := 24;
  LSize.FCols := 80;
  LRes := platform_pty_open(LSize, LPty);
  if LRes = PLATFORM_ERR_UNSUPPORTED then
  begin
    Check(LRes = PLATFORM_ERR_UNSUPPORTED, 'unsupported on this platform');
    Exit;
  end;
  Check(LRes = 0, 'open must succeed');

  LArgv[0] := '/bin/echo';
  LArgv[1] := 'hello';
  LArgv[2] := nil;
  LRes := platform_pty_spawn(LPty, '/bin/echo', @LArgv[0], nil, nil, LPid, LFailStage);
  Check(LRes = 0, 'spawn must succeed');
  Check(LPid > 0, 'pid must be positive');

  { Read from master fd }
  FillChar(LBuf, SizeOf(LBuf), 0);
  LRead := nextpas.core.platform.posix.ffi.read(platform_pty_master_fd(LPty), @LBuf[0], SizeOf(LBuf));
  Check(LRead > 0, 'must read data from pty');
  Check(LBuf[0] = 'h', 'first char must be h');
  Check(LBuf[1] = 'e', 'second char must be e');

  platform_pty_close(LPty);
end;

begin
  T := TTestSuite.Create('nextpas.core.platform.pty');
  T.Test('open pty', @TestPtyOpen);
  T.Test('open pty default size', @TestPtyOpenDefaultSize);
  T.Test('spawn nil path returns invalid', @TestPtySpawnNilPath);
  T.Test('close pty', @TestPtyClose);
  T.Test('master fd', @TestPtyMasterFd);
  T.Test('resize pty', @TestPtyResize);
  T.Test('close idempotent', @TestPtyCloseIdempotent);
  T.Test('master fd after close', @TestPtyMasterFdAfterClose);
  T.Test('spawn echo', @TestPtySpawnEcho);
  if not T.Run then Halt(1);
end.
