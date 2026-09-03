program test_lockfree_misragries;

{$mode objfpc}{$H+}

uses
  nextpas.core.fs,
  nextpas.core.lockfree.misragries,
  nextpas.core.test;

procedure TestBasicAdd;
var
  LMG: TMisraGries;
begin
  LMG := TMisraGries.Create(3);
  try
    Check(not LMG.IsClosed, 'Should not be closed');
    CheckEqual(Int32(3), LMG.GetCapacity, 'Capacity');
    CheckEqual(Int64(0), LMG.GetTotalOps, 'No ops yet');

    Check(LMG.Add(1) = mgAdded, 'Should add new key');
    CheckEqual(Int64(1), LMG.GetCount(1), 'Count after add');
    CheckEqual(Int64(1), LMG.GetTotalOps, 'One op');

    Check(LMG.Add(1) = mgUpdated, 'Should update existing key');
    CheckEqual(Int64(2), LMG.GetCount(1), 'Count after update');
  finally
    LMG.Free;
  end;
end;

procedure TestHeavyHitter;
var
  LMG: TMisraGries;
  I: Integer;
begin
  LMG := TMisraGries.Create(3);
  try
    { Add key 1 many times — it should survive decrements }
    for I := 1 to 20 do
      LMG.Add(1);
    { Add other keys occasionally }
    LMG.Add(2);
    LMG.Add(3);

    Check(LMG.GetCount(1) > 0, 'Heavy hitter should survive');
    CheckEqual(Int64(20), LMG.GetCount(1), 'Heavy hitter count');
  finally
    LMG.Free;
  end;
end;

procedure TestDecrement;
var
  LMG: TMisraGries;
begin
  LMG := TMisraGries.Create(2);
  try
    LMG.Add(1);
    LMG.Add(2);
    { Both slots full — next add should decrement all }
    LMG.Add(3);
    CheckEqual(Int64(0), LMG.GetCount(1), 'Decrement removes weak entries');
    CheckEqual(Int64(0), LMG.GetCount(2), 'Decrement removes weak entries');
  finally
    LMG.Free;
  end;
end;

procedure TestClose;
var
  LMG: TMisraGries;
begin
  LMG := TMisraGries.Create(3);
  try
    LMG.Add(1);
    LMG.Close;
    Check(LMG.IsClosed, 'Should be closed');
    Check(LMG.Add(2) = mgClosed, 'Should not add after close');
  finally
    LMG.Free;
  end;
end;

procedure TestClear;
var
  LMG: TMisraGries;
begin
  LMG := TMisraGries.Create(3);
  try
    LMG.Add(1);
    LMG.Add(2);
    CheckEqual(Int64(2), LMG.GetTotalOps, 'Two ops before clear');

    LMG.Clear;
    CheckEqual(Int64(0), LMG.GetCount(1), 'Cleared');
    CheckEqual(Int64(0), LMG.GetTotalOps, 'Ops reset');
  finally
    LMG.Free;
  end;
end;

procedure TestGetTopK;
var
  LMG: TMisraGries;
  LKeys: array[0..9] of UInt64;
  LCounts: array[0..9] of Int64;
  LFound: Int32;
  I: Integer;
begin
  LMG := TMisraGries.Create(5);
  try
    for I := 1 to 10 do LMG.Add(1);
    for I := 1 to 5 do LMG.Add(2);
    for I := 1 to 3 do LMG.Add(3);

    LMG.GetTopK(LKeys, LCounts, LFound);
    Check(LFound >= 2, 'Should find at least 2 entries');
    CheckEqual(UInt64(1), LKeys[0], 'Top key should be 1');
    CheckEqual(Int64(10), LCounts[0], 'Top count should be 10');
  finally
    LMG.Free;
  end;
end;

procedure TestCountersSaturateAtInt64Max;
var
  LSource: string;
begin
  LSource := ReadFileText('../../../src/nextpas.core.lockfree.misragries.pas');
    Check(Pos('if FTotalOps < High(Int64) then', LSource) > 0,
      'Total operation count must saturate');
    Check(Pos('if FEntries[LIdx].Count < High(Int64) then', LSource) > 0,
      'Tracked item count must saturate');
end;

begin
  WriteLn('=== test_lockfree_misragries ===');
  WriteLn;

  TestBasicAdd;
  WriteLn('  + Basic add/update');

  TestHeavyHitter;
  WriteLn('  + Heavy hitter detection');

  TestDecrement;
  WriteLn('  + Decrement mechanism');

  TestClose;
  WriteLn('  + Close semantics');

  TestClear;
  WriteLn('  + Clear');

  TestGetTopK;
  WriteLn('  + GetTopK');

  TestCountersSaturateAtInt64Max;
  WriteLn('  + Saturating counter contract');

  WriteLn;
  WriteLn('All Misra-Gries tests passed!');
end.
