program test_lockfree_slidingwindow;

{$mode objfpc}{$H+}

uses
  nextpas.core.thread.init,
  nextpas.core.platform.thread,
  nextpas.core.lockfree.slidingwindow,
  nextpas.core.errors,
  nextpas.core.test;

procedure TestBasicAllow;
var
  SW: TSlidingWindowLimiter;
begin
  SW := TSlidingWindowLimiter.Create(10, 1000);
  try
    Check(not SW.IsClosed, 'Should not be closed');
    Check(SW.TryAcquire = swAllowed, 'Should allow');
    Check(SW.GetLimit = 10, 'Limit');
    Check(SW.GetWindowMs = 1000, 'Window');
  finally
    SW.Free;
  end;
end;

procedure TestReject;
var
  SW: TSlidingWindowLimiter;
  I: Integer;
begin
  SW := TSlidingWindowLimiter.Create(3, 10000);
  try
    for I := 1 to 3 do
      Check(SW.TryAcquire = swAllowed, 'Should allow');
    Check(SW.TryAcquire = swRejected, 'Should reject after limit');
  finally
    SW.Free;
  end;
end;

procedure TestMultipleAcquire;
var
  SW: TSlidingWindowLimiter;
begin
  SW := TSlidingWindowLimiter.Create(10, 10000);
  try
    Check(SW.TryAcquireN(5) = swAllowed, 'Acquire 5');
    Check(SW.TryAcquireN(5) = swAllowed, 'Acquire 5 more');
    Check(SW.TryAcquireN(1) = swRejected, 'Should reject');
  finally
    SW.Free;
  end;
end;

procedure TestClose;
var
  SW: TSlidingWindowLimiter;
begin
  SW := TSlidingWindowLimiter.Create(10, 1000);
  try
    SW.Close;
    Check(SW.IsClosed, 'Should be closed');
    Check(SW.TryAcquire = swClosed, 'Should reject on closed');
  finally
    SW.Free;
  end;
end;

procedure TestWindowAdvancesWithElapsedTime;
var
  SW: TSlidingWindowLimiter;
begin
  SW := TSlidingWindowLimiter.Create(1, 20);
  try
    Check(SW.TryAcquire = swAllowed, 'Initial request should be allowed');
    Check(SW.TryAcquire = swRejected, 'Current window should be full');
    platform_thread_sleep_ms(50);
    Check(SW.TryAcquire = swAllowed, 'Two elapsed windows should clear prior weight');
  finally
    SW.Free;
  end;
end;

procedure TestWindowRejectsNanosecondOverflow;
var
  SW: TSlidingWindowLimiter;
  LRaised: Boolean;
begin
  SW := nil;
  LRaised := False;
  try
    try
      SW := TSlidingWindowLimiter.Create(1, High(Int64));
    except
      on E: EArgumentError do
        LRaised := True;
    end;
  finally
    SW.Free;
  end;
  Check(LRaised, 'Window milliseconds must fit the nanosecond representation');
end;

begin
  WriteLn('=== test_lockfree_slidingwindow ===');
  WriteLn;

  TestBasicAllow;
  WriteLn('  + Basic allow');

  TestReject;
  WriteLn('  + Reject after limit');

  TestMultipleAcquire;
  WriteLn('  + Multiple acquire');

  TestClose;
  WriteLn('  + Close semantics');

  TestWindowRejectsNanosecondOverflow;
  WriteLn('  + Window nanosecond overflow guard');

  TestWindowAdvancesWithElapsedTime;
  WriteLn('  + Elapsed-time window advance');

  WriteLn;
  WriteLn('All sliding window tests passed!');
end.
