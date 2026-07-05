program test_platform_signal;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.platform.signal,
  nextpas.core.platform.error;

var
  T: TTestSuite;

procedure TestSignalConstants;
begin
  Check(PLATFORM_SIGINT = 2, 'SIGINT must be 2');
  Check(PLATFORM_SIGTERM = 15, 'SIGTERM must be 15');
  Check(PLATFORM_SIGHUP = 1, 'SIGHUP must be 1');
  Check(PLATFORM_SIGPIPE = 13, 'SIGPIPE must be 13');
  Check(PLATFORM_SIGUSR1 > 0, 'SIGUSR1 must be positive');
  Check(PLATFORM_SIGUSR2 > 0, 'SIGUSR2 must be positive');
end;

procedure TestSignalIgnore;
var
  LRes: Int32;
begin
  LRes := platform_signal_ignore(PLATFORM_SIGUSR1);
  if LRes = PLATFORM_ERR_UNSUPPORTED then
  begin
    Check(LRes = PLATFORM_ERR_UNSUPPORTED, 'unsupported on this platform');
    Exit;
  end;
  Check(LRes = 0, 'ignore must succeed');
  LRes := platform_signal_reset(PLATFORM_SIGUSR1);
  Check(LRes = 0, 'reset must succeed');
end;

procedure TestSignalReset;
var
  LRes: Int32;
begin
  LRes := platform_signal_reset(PLATFORM_SIGUSR1);
  if LRes = PLATFORM_ERR_UNSUPPORTED then
  begin
    Check(LRes = PLATFORM_ERR_UNSUPPORTED, 'unsupported on this platform');
    Exit;
  end;
  Check(LRes = 0, 'reset must succeed');
end;

procedure TestSignalBlock;
var
  LRes: Int32;
begin
  LRes := platform_signal_block(PLATFORM_SIGUSR1);
  if LRes = PLATFORM_ERR_UNSUPPORTED then
  begin
    Check(LRes = PLATFORM_ERR_UNSUPPORTED, 'unsupported on this platform');
    Exit;
  end;
  Check(LRes = 0, 'block must succeed');
  LRes := platform_signal_unblock(PLATFORM_SIGUSR1);
  Check(LRes = 0, 'unblock must succeed');
end;

procedure TestSignalUnblock;
var
  LRes: Int32;
begin
  LRes := platform_signal_block(PLATFORM_SIGUSR1);
  if LRes = PLATFORM_ERR_UNSUPPORTED then
  begin
    Check(LRes = PLATFORM_ERR_UNSUPPORTED, 'unsupported on this platform');
    Exit;
  end;
  Check(LRes = 0, 'block must succeed');
  LRes := platform_signal_unblock(PLATFORM_SIGUSR1);
  Check(LRes = 0, 'unblock must succeed');
end;

begin
  T := TTestSuite.Create('nextpas.core.platform.signal');
  T.Test('signal constants', @TestSignalConstants);
  T.Test('ignore signal', @TestSignalIgnore);
  T.Test('reset signal', @TestSignalReset);
  T.Test('block signal', @TestSignalBlock);
  T.Test('unblock signal', @TestSignalUnblock);
  if not T.Run then Halt(1);
end.
