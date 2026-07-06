program test_platform_signal;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.signal,
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi,
  nextpas.core.test;

var
  T: TTestSuite;
  GHandlerCalled: Int32;
  GLastSignal: Int32;

procedure MyHandler(ASig: Int32); cdecl;
begin
  Inc(GHandlerCalled);
  GLastSignal := ASig;
end;

procedure TestSetHandler;
begin
  GHandlerCalled := 0;
  GLastSignal := 0;
  Check(platform_signal_set(PLATFORM_SIGUSR1, @MyHandler) = 0, 'set handler');
  kill(getpid, PLATFORM_SIGUSR1);
  Check(GHandlerCalled = 1, 'handler called once');
  Check(GLastSignal = PLATFORM_SIGUSR1, 'correct signal');
  platform_signal_reset(PLATFORM_SIGUSR1);
end;

procedure TestSetSIGINT;
begin
  Check(platform_signal_set(PLATFORM_SIGINT, @MyHandler) = 0, 'set SIGINT');
  platform_signal_reset(PLATFORM_SIGINT);
end;

procedure TestOverwriteHandler;
begin
  GHandlerCalled := 0;
  platform_signal_set(PLATFORM_SIGUSR2, @MyHandler);
  Check(platform_signal_set(PLATFORM_SIGUSR2, @MyHandler) = 0, 'overwrite');
  kill(getpid, PLATFORM_SIGUSR2);
  Check(GHandlerCalled = 1, 'new handler called');
  platform_signal_reset(PLATFORM_SIGUSR2);
end;

procedure TestBlockUnblock;
begin
  GHandlerCalled := 0;
  platform_signal_set(PLATFORM_SIGUSR1, @MyHandler);
  Check(platform_signal_block(PLATFORM_SIGUSR1) = 0, 'block');
  kill(getpid, PLATFORM_SIGUSR1);
  Check(GHandlerCalled = 0, 'handler not called while blocked');
  Check(platform_signal_unblock(PLATFORM_SIGUSR1) = 0, 'unblock');
  Check(GHandlerCalled = 1, 'handler called after unblock');
  platform_signal_reset(PLATFORM_SIGUSR1);
end;

procedure TestInvalidSignal;
begin
  Check(platform_signal_set(0, @MyHandler) <> 0, 'signal 0 returns error');
end;

procedure TestResetHandler;
begin
  platform_signal_set(PLATFORM_SIGUSR1, @MyHandler);
  Check(platform_signal_reset(PLATFORM_SIGUSR1) = 0, 'reset');
end;

procedure TestMultipleSignals;
begin
  GHandlerCalled := 0;
  platform_signal_set(PLATFORM_SIGUSR1, @MyHandler);
  platform_signal_set(PLATFORM_SIGUSR2, @MyHandler);
  kill(getpid, PLATFORM_SIGUSR1);
  kill(getpid, PLATFORM_SIGUSR2);
  Check(GHandlerCalled = 2, 'handler called twice for 2 signals');
  platform_signal_reset(PLATFORM_SIGUSR1);
  platform_signal_reset(PLATFORM_SIGUSR2);
end;

procedure TestHandlerSignalArg;
begin
  GHandlerCalled := 0;
  GLastSignal := 0;
  platform_signal_set(PLATFORM_SIGUSR2, @MyHandler);
  kill(getpid, PLATFORM_SIGUSR2);
  Check(GLastSignal = PLATFORM_SIGUSR2, 'handler got SIGUSR2');
  platform_signal_reset(PLATFORM_SIGUSR2);
end;

procedure TestIgnoreSignal;
begin
  // Ignore SIGUSR1, then send it — handler should NOT be called
  GHandlerCalled := 0;
  Check(platform_signal_ignore(PLATFORM_SIGUSR1) = 0, 'ignore signal');
  kill(getpid, PLATFORM_SIGUSR1);
  Check(GHandlerCalled = 0, 'handler not called when ignored');
  // Reset to default
  platform_signal_reset(PLATFORM_SIGUSR1);
end;

begin
  T := TTestSuite.Create('nextpas.core.platform.signal');
  T.Test('set handler + deliver', @TestSetHandler);
  T.Test('set SIGINT handler', @TestSetSIGINT);
  T.Test('overwrite handler', @TestOverwriteHandler);
  T.Test('block + unblock delivery', @TestBlockUnblock);
  T.Test('invalid signal', @TestInvalidSignal);
  T.Test('reset handler', @TestResetHandler);
  T.Test('multiple signals', @TestMultipleSignals);
  T.Test('handler receives correct signal', @TestHandlerSignalArg);
  T.Test('ignore signal', @TestIgnoreSignal);
  if not T.Run then Halt(1);
end.
