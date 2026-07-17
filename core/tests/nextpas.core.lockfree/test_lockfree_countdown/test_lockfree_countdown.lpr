program test_lockfree_countdown;

{$mode objfpc}{$H+}

uses
  nextpas.core.errors,
  nextpas.core.lockfree.countdown,
  nextpas.core.lockfree,
  nextpas.core.test;

procedure TestCountdownBasic;
var
  Latch: TCountDownLatch;
begin
  Latch := TCountDownLatch.Create(3);
  try
    CheckEqual(Int64(3), Latch.GetCount);
    Check(not Latch.IsClosed, 'Should not be closed');

    Latch.Done;
    CheckEqual(Int64(2), Latch.GetCount);

    Latch.Done;
    CheckEqual(Int64(1), Latch.GetCount);

    Latch.Done;
    CheckEqual(Int64(0), Latch.GetCount);
  finally
    Latch.Free;
  end;
end;

procedure TestCountdownDoneN;
var
  Latch: TCountDownLatch;
begin
  Latch := TCountDownLatch.Create(5);
  try
    Latch.DoneN(3);
    CheckEqual(Int64(2), Latch.GetCount);

    Latch.DoneN(2);
    CheckEqual(Int64(0), Latch.GetCount);
  finally
    Latch.Free;
  end;
end;

procedure TestCountdownWait;
var
  Latch: TCountDownLatch;
begin
  Latch := TCountDownLatch.Create(1);
  try
    Latch.Done;
    // Wait should return immediately since count is 0
    Latch.Wait;
    CheckEqual(Int64(0), Latch.GetCount);
  finally
    Latch.Free;
  end;
end;

procedure TestCountdownWaitZero;
var
  Latch: TCountDownLatch;
begin
  Latch := TCountDownLatch.Create(0);
  try
    // Wait should return immediately
    Latch.Wait;
    CheckEqual(Int64(0), Latch.GetCount);
  finally
    Latch.Free;
  end;
end;

procedure TestCountdownClose;
var
  Latch: TCountDownLatch;
begin
  Latch := TCountDownLatch.Create(5);
  try
    Latch.Done;
    Latch.Close;
    Check(Latch.IsClosed, 'Should be closed');

    // Can still read count
    CheckEqual(Int64(4), Latch.GetCount);
  finally
    Latch.Free;
  end;
end;

procedure TestCountdownTimeout;
var
  Latch: TCountDownLatch;
begin
  Latch := TCountDownLatch.Create(1);
  try
    // Timeout should fail since count > 0
    Check(not Latch.WaitTimeout(1000000), 'Should timeout'); // 1ms

    Latch.Done;
    // Should succeed now
    Check(Latch.WaitTimeout(1000000), 'Should not timeout');
  finally
    Latch.Free;
  end;
end;

procedure TestCountdownDoesNotUnderflow;
var
  Latch: TCountDownLatch;
begin
  Latch := TCountDownLatch.Create(1);
  try
    Latch.Done;
    Latch.Done;
    CheckEqual(Int64(0), Latch.GetCount, 'Done must saturate at zero');

    Latch.DoneN(4);
    CheckEqual(Int64(0), Latch.GetCount, 'DoneN must not drive count negative');
  finally
    Latch.Free;
  end;
end;

procedure TestCountdownTimeoutMustBePositive;
var
  Latch: TCountDownLatch;
  LGotZeroError: Boolean;
  LGotNegativeError: Boolean;
begin
  Latch := TCountDownLatch.Create(1);
  try
    LGotZeroError := False;
    try
      Latch.WaitTimeout(0);
    except
      on E: EArgumentError do
        LGotZeroError := True;
    end;
    Check(LGotZeroError, 'WaitTimeout(0) must raise EArgumentError');

    LGotNegativeError := False;
    try
      Latch.WaitTimeout(-1);
    except
      on E: EArgumentError do
        LGotNegativeError := True;
    end;
    Check(LGotNegativeError, 'WaitTimeout(-1) must raise EArgumentError');
  finally
    Latch.Free;
  end;
end;

begin
  WriteLn('=== test_lockfree_countdown ===');
  WriteLn;

  TestCountdownBasic;
  WriteLn('  + Basic Done');

  TestCountdownDoneN;
  WriteLn('  + DoneN');

  TestCountdownWait;
  WriteLn('  + Wait (count=1, done first)');

  TestCountdownWaitZero;
  WriteLn('  + Wait (count=0)');

  TestCountdownClose;
  WriteLn('  + Close semantics');

  TestCountdownTimeout;
  WriteLn('  + Timeout');

  TestCountdownDoesNotUnderflow;
  WriteLn('  + No underflow');

  TestCountdownTimeoutMustBePositive;
  WriteLn('  + Positive timeout validation');

  WriteLn;
  WriteLn('All countdown latch tests passed!');
end.
