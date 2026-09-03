program test_async_signal;
{$mode ObjFPC}{$H+}{$J-}

uses
  nextpas.core.platform.thread,
  nextpas.core.base, nextpas.core.errors,
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi,
  nextpas.core.platform.linux.base,
  nextpas.core.async.base, nextpas.core.async.signal;

const
  HEAPTRC_ACTIVE =
    {$IFDEF HEAPTRC_ACTIVE} True {$ELSE} False {$ENDIF};

var
  GTestsPassed: Integer = 0;
  GTestsFailed: Integer = 0;
  GSignalReceived: Integer = 0;
  GLastSignal: Integer = 0;

procedure Check(ACondition: Boolean; const ATestName: string);
begin
  if ACondition then
  begin
    Inc(GTestsPassed);
    WriteLn('  ✓ ', ATestName);
  end
  else
  begin
    Inc(GTestsFailed);
    WriteLn('  ✗ FAIL: ', ATestName);
  end;
end;

procedure TestSignalCallback(ASigNum: Int32; AContext: Pointer);
begin
  Inc(GSignalReceived);
  GLastSignal := ASigNum;
end;

{ Test 1: Create signal handler }
procedure TestCreateHandler;
var
  LHandler: IAsyncSignalHandler;
begin
  WriteLn('TestCreateHandler:');
  LHandler := CreateAsyncSignalHandler;
  Check(LHandler <> nil, 'handler created');
  Check(LHandler.Count = 0, 'initial count is 0');
  Check(LHandler.Fd < 0, 'no signalfd when no signals registered');
end;

{ Test 2: Register signal }
procedure TestRegisterSignal;
var
  LHandler: IAsyncSignalHandler;
begin
  WriteLn('TestRegisterSignal:');
  LHandler := CreateAsyncSignalHandler;
  Check(LHandler.RegisterSignal(SIGUSR1, @TestSignalCallback), 'register SIGUSR1');
  Check(LHandler.Count = 1, 'count is 1');
  Check(LHandler.IsRegistered(SIGUSR1), 'SIGUSR1 is registered');
  Check(not LHandler.IsRegistered(SIGUSR2), 'SIGUSR2 is not registered');
  Check(LHandler.Fd >= 0, 'signalfd created');
end;

{ Test 3: Register multiple signals }
procedure TestRegisterMultiple;
var
  LHandler: IAsyncSignalHandler;
begin
  WriteLn('TestRegisterMultiple:');
  LHandler := CreateAsyncSignalHandler;
  Check(LHandler.RegisterSignal(SIGUSR1, @TestSignalCallback), 'register SIGUSR1');
  Check(LHandler.RegisterSignal(SIGUSR2, @TestSignalCallback), 'register SIGUSR2');
  Check(LHandler.Count = 2, 'count is 2');
  Check(LHandler.IsRegistered(SIGUSR1), 'SIGUSR1 registered');
  Check(LHandler.IsRegistered(SIGUSR2), 'SIGUSR2 registered');
end;

{ Test 4: Unregister signal }
procedure TestUnregisterSignal;
var
  LHandler: IAsyncSignalHandler;
begin
  WriteLn('TestUnregisterSignal:');
  LHandler := CreateAsyncSignalHandler;
  Check(LHandler.RegisterSignal(SIGUSR1, @TestSignalCallback), 'register SIGUSR1');
  Check(LHandler.RegisterSignal(SIGUSR2, @TestSignalCallback), 'register SIGUSR2');

  LHandler.UnregisterSignal(SIGUSR1);
  Check(LHandler.Count = 1, 'count is 1 after unregister');
  Check(not LHandler.IsRegistered(SIGUSR1), 'SIGUSR1 unregistered');
  Check(LHandler.IsRegistered(SIGUSR2), 'SIGUSR2 still registered');
end;

{ Test 5: Unregister all }
procedure TestUnregisterAll;
var
  LHandler: IAsyncSignalHandler;
begin
  WriteLn('TestUnregisterAll:');
  LHandler := CreateAsyncSignalHandler;
  LHandler.RegisterSignal(SIGUSR1, @TestSignalCallback);
  LHandler.RegisterSignal(SIGUSR2, @TestSignalCallback);

  LHandler.UnregisterAll;
  Check(LHandler.Count = 0, 'count is 0 after unregister all');
  Check(not LHandler.IsRegistered(SIGUSR1), 'SIGUSR1 unregistered');
  Check(not LHandler.IsRegistered(SIGUSR2), 'SIGUSR2 unregistered');
end;

{ Test 6: Duplicate registration fails }
procedure TestDuplicateRegistration;
var
  LHandler: IAsyncSignalHandler;
begin
  WriteLn('TestDuplicateRegistration:');
  LHandler := CreateAsyncSignalHandler;
  Check(LHandler.RegisterSignal(SIGUSR1, @TestSignalCallback), 'first registration succeeds');
  Check(not LHandler.RegisterSignal(SIGUSR1, @TestSignalCallback), 'duplicate fails');
  Check(LHandler.Count = 1, 'count is still 1');
end;

{ Test 7: Signal delivery via signalfd }
procedure TestSignalDelivery;
var
  LHandler: IAsyncSignalHandler;
  LPid: pid_t;
begin
  WriteLn('TestSignalDelivery:');
  LHandler := CreateAsyncSignalHandler;
  GSignalReceived := 0;
  GLastSignal := 0;

  Check(LHandler.RegisterSignal(SIGUSR1, @TestSignalCallback), 'register SIGUSR1');
  Check(LHandler.Fd >= 0, 'signalfd created');

  { Send signal to self }
  LPid := getpid;
  kill(LPid, SIGUSR1);

  { Small delay for signal delivery }
  platform_thread_sleep_ms(10);

  { Process signals }
  Check(LHandler.ProcessSignals = 1, 'processed 1 signal');
  Check(GSignalReceived = 1, 'callback fired once');
  Check(GLastSignal = SIGUSR1, 'correct signal number');
end;

{ Test 8: Multiple signal delivery }
procedure TestMultipleSignalDelivery;
var
  LHandler: IAsyncSignalHandler;
  LPid: pid_t;
begin
  WriteLn('TestMultipleSignalDelivery:');
  LHandler := CreateAsyncSignalHandler;
  GSignalReceived := 0;

  Check(LHandler.RegisterSignal(SIGUSR1, @TestSignalCallback), 'register SIGUSR1');
  Check(LHandler.RegisterSignal(SIGUSR2, @TestSignalCallback), 'register SIGUSR2');

  { Send both signals }
  LPid := getpid;
  kill(LPid, SIGUSR1);
  kill(LPid, SIGUSR2);
  platform_thread_sleep_ms(10);

  { Process signals }
  Check(LHandler.ProcessSignals >= 1, 'processed signals');
  Check(GSignalReceived >= 1, 'callbacks fired');
end;

{ Test 9: One-shot option }
procedure TestOneShot;
var
  LHandler: IAsyncSignalHandler;
  LPid: pid_t;
begin
  WriteLn('TestOneShot:');
  LHandler := CreateAsyncSignalHandler;
  GSignalReceived := 0;

  Check(LHandler.RegisterSignal(SIGUSR1, @TestSignalCallback, nil, [soOneShot]),
    'register SIGUSR1 with one-shot');
  Check(LHandler.IsRegistered(SIGUSR1), 'SIGUSR1 registered');

  { Send signal }
  LPid := getpid;
  kill(LPid, SIGUSR1);
  platform_thread_sleep_ms(10);

  { Process signals }
  Check(LHandler.ProcessSignals = 1, 'processed 1 signal');
  Check(GSignalReceived = 1, 'callback fired');
  Check(not LHandler.IsRegistered(SIGUSR1), 'auto-unregistered after one-shot');
  Check(LHandler.Count = 0, 'count is 0');
end;

{ Test 10: ProcessSignals with no signals }
procedure TestProcessNoSignals;
var
  LHandler: IAsyncSignalHandler;
begin
  WriteLn('TestProcessNoSignals:');
  LHandler := CreateAsyncSignalHandler;
  LHandler.RegisterSignal(SIGUSR1, @TestSignalCallback);

  { No signals sent }
  Check(LHandler.ProcessSignals = 0, 'processed 0 signals');
end;

{ Main }
begin
  WriteLn('=== test_async_signal ===');
  WriteLn;

  TestCreateHandler;
  WriteLn;

  TestRegisterSignal;
  WriteLn;

  TestRegisterMultiple;
  WriteLn;

  TestUnregisterSignal;
  WriteLn;

  TestUnregisterAll;
  WriteLn;

  TestDuplicateRegistration;
  WriteLn;

  TestSignalDelivery;
  WriteLn;

  TestMultipleSignalDelivery;
  WriteLn;

  TestOneShot;
  WriteLn;

  TestProcessNoSignals;
  WriteLn;

  WriteLn('=== Results ===');
  WriteLn('Passed: ', GTestsPassed);
  WriteLn('Failed: ', GTestsFailed);
  WriteLn('Total:  ', GTestsPassed + GTestsFailed);
  WriteLn;

  if GTestsFailed > 0 then
  begin
    WriteLn('FAILED');
    Halt(1);
  end
  else
    WriteLn('OK');
end.
