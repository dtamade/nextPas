program test_platform_pty;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.platform.pty,
  nextpas.core.platform.pty.base,
  nextpas.core.platform.error;

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

begin
  T := TTestSuite.Create('nextpas.core.platform.pty');
  T.Test('open pty', @TestPtyOpen);
  T.Test('open pty default size', @TestPtyOpenDefaultSize);
  T.Test('spawn nil path returns invalid', @TestPtySpawnNilPath);
  T.Test('close pty', @TestPtyClose);
  T.Test('master fd', @TestPtyMasterFd);
  if not T.Run then Halt(1);
end.
