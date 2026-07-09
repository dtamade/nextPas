program test_lockfree_flatcombining;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.lockfree.flatcombining,
  nextpas.core.lockfree,
  nextpas.core.atomic,
  nextpas.core.test;

procedure TestFCCounterBasic;
var
  LCounter: TFlatCombiningCounter;
begin
  LCounter := TFlatCombiningCounter.Create(0);
  try
    CheckEqual(Int64(1), LCounter.Increment);
    CheckEqual(Int64(2), LCounter.Increment);
    CheckEqual(Int64(3), LCounter.Increment);

    CheckEqual(Int64(2), LCounter.Decrement);
    CheckEqual(Int64(1), LCounter.Decrement);

    CheckEqual(Int64(11), LCounter.Add(10));
    CheckEqual(Int64(6), LCounter.Sub(5));
  finally
    LCounter.Free;
  end;
end;

procedure TestFCCounterInitialValue;
var
  LCounter: TFlatCombiningCounter;
begin
  LCounter := TFlatCombiningCounter.Create(100);
  try
    CheckEqual(Int64(100), LCounter.GetValue);
    CheckEqual(Int64(101), LCounter.Increment);
    CheckEqual(Int64(100), LCounter.Decrement);
  finally
    LCounter.Free;
  end;
end;

procedure TestFCCounterClose;
var
  LCounter: TFlatCombiningCounter;
begin
  LCounter := TFlatCombiningCounter.Create(0);
  try
    LCounter.Increment;
    LCounter.Close;
    Check(LCounter.IsClosed, 'Should be closed');

    CheckEqual(Int64(1), LCounter.GetValue);
  finally
    LCounter.Free;
  end;
end;

procedure TestFCCounterMultipleOps;
var
  LCounter: TFlatCombiningCounter;
  LI: Integer;
begin
  LCounter := TFlatCombiningCounter.Create(0);
  try
    for LI := 1 to 100 do
      LCounter.Increment;

    CheckEqual(Int64(100), LCounter.GetValue);

    for LI := 1 to 50 do
      LCounter.Decrement;

    CheckEqual(Int64(50), LCounter.GetValue);
  finally
    LCounter.Free;
  end;
end;

procedure TestFCCounterAddSub;
var
  LCounter: TFlatCombiningCounter;
begin
  LCounter := TFlatCombiningCounter.Create(0);
  try
    CheckEqual(Int64(100), LCounter.Add(100));
    CheckEqual(Int64(150), LCounter.Add(50));
    CheckEqual(Int64(100), LCounter.Sub(50));
    CheckEqual(Int64(0), LCounter.Sub(100));
  finally
    LCounter.Free;
  end;
end;

begin
  WriteLn('=== test_lockfree_flatcombining ===');
  WriteLn;

  TestFCCounterBasic;
  WriteLn('  + Basic operations');

  TestFCCounterInitialValue;
  WriteLn('  + Initial value');

  TestFCCounterClose;
  WriteLn('  + Close semantics');

  TestFCCounterMultipleOps;
  WriteLn('  + Multiple operations');

  TestFCCounterAddSub;
  WriteLn('  + Add/Sub');

  WriteLn;
  WriteLn('All flat combining tests passed!');
end.
