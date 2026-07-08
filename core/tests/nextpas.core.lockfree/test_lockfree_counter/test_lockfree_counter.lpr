program test_lockfree_counter;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.lockfree.counter,
  nextpas.core.lockfree,
  nextpas.core.atomic,
  nextpas.core.test;

procedure TestCounterBasic;
var
  LCounter: TConcurrentCounter;
begin
  LCounter := TConcurrentCounter.Create;
  try
    // Initial value
    CheckEqual(Int64(0), LCounter.Load);
    Check(not LCounter.IsClosed, 'Counter should not be closed');

    // Increment
    CheckEqual(Int64(1), LCounter.Increment);
    CheckEqual(Int64(2), LCounter.Increment);
    CheckEqual(Int64(3), LCounter.Increment);

    // Decrement
    CheckEqual(Int64(2), LCounter.Decrement);
    CheckEqual(Int64(1), LCounter.Decrement);

    // Add/Sub
    CheckEqual(Int64(11), LCounter.Add(10));
    CheckEqual(Int64(6), LCounter.Sub(5));

    // Store/Load
    LCounter.Store(42);
    CheckEqual(Int64(42), LCounter.Load);

    // Reset
    LCounter.Reset;
    CheckEqual(Int64(0), LCounter.Load);
  finally
    LCounter.Free;
  end;
end;

procedure TestCounterInitialValue;
var
  LCounter: TConcurrentCounter;
begin
  LCounter := TConcurrentCounter.Create(100);
  try
    CheckEqual(Int64(100), LCounter.Load);
    CheckEqual(Int64(101), LCounter.Increment);
    CheckEqual(Int64(100), LCounter.Decrement);
  finally
    LCounter.Free;
  end;
end;

procedure TestCounterClose;
var
  LCounter: TConcurrentCounter;
begin
  LCounter := TConcurrentCounter.Create;
  try
    LCounter.Increment;
    LCounter.Close;
    Check(LCounter.IsClosed, 'Counter should be closed');

    // Can still read
    CheckEqual(Int64(1), LCounter.Load);
  finally
    LCounter.Free;
  end;
end;

procedure TestCounterLargeValues;
var
  LCounter: TConcurrentCounter;
begin
  LCounter := TConcurrentCounter.Create;
  try
    LCounter.Store(1000000);
    CheckEqual(Int64(1000000), LCounter.Load);
    CheckEqual(Int64(1000001), LCounter.Increment);
    CheckEqual(Int64(1000000), LCounter.Decrement);
  finally
    LCounter.Free;
  end;
end;

begin
  WriteLn('=== test_lockfree_counter ===');
  WriteLn;

  TestCounterBasic;
  WriteLn('  + Basic operations');

  TestCounterInitialValue;
  WriteLn('  + Initial value');

  TestCounterClose;
  WriteLn('  + Close semantics');

  TestCounterLargeValues;
  WriteLn('  + Large values');

  WriteLn;
  WriteLn('All counter tests passed!');
end.
