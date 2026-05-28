program test_platform_signal;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.signal,
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi,
  nextpas.core.testing;

var
  T: TTestRunner;
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

begin
  T := TTestRunner.Create('nextpas.core.platform.signal');
  T.Run('set handler + deliver', @TestSetHandler);
  T.Run('set SIGINT handler', @TestSetSIGINT);
  T.Run('overwrite handler', @TestOverwriteHandler);
  T.Run('block + unblock delivery', @TestBlockUnblock);
  T.Run('invalid signal', @TestInvalidSignal);
  T.Run('reset handler', @TestResetHandler);
  T.Run('multiple signals', @TestMultipleSignals);
  T.Run('handler receives correct signal', @TestHandlerSignalArg);
  T.Summary;
end.
