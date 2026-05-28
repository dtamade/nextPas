program test_vec;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.collections.vec.intf,
  nextpas.core.collections.vec;

type
  IIntVec = specialize IVec<Integer>;
  TIntVec = specialize TVec<Integer>;
  IStrVec = specialize IVec<string>;
  TStrVec = specialize TVec<string>;

var
  T: TTestRunner;

procedure TestCreate;
var
  LV: IIntVec;
begin
  LV := TIntVec.Create;
  Check(LV.IsEmpty);
  CheckEqual(Int64(0), Int64(LV.Count));
end;

procedure TestAdd;
var
  LV: IIntVec;
begin
  LV := TIntVec.Create;
  LV.Push(10);
  LV.Push(20);
  LV.Push(30);
  CheckEqual(Int64(3), Int64(LV.Count));
  CheckEqual(Int64(10), Int64(LV[0]));
  CheckEqual(Int64(20), Int64(LV[1]));
  CheckEqual(Int64(30), Int64(LV[2]));
end;

procedure TestInsert;
var
  LV: IIntVec;
begin
  LV := TIntVec.Create;
  LV.Push(1);
  LV.Push(3);
  LV.Insert(1, 2);
  CheckEqual(Int64(3), Int64(LV.Count));
  CheckEqual(Int64(1), Int64(LV[0]));
  CheckEqual(Int64(2), Int64(LV[1]));
  CheckEqual(Int64(3), Int64(LV[2]));
end;

procedure TestDelete;
var
  LV: IIntVec;
begin
  LV := TIntVec.Create;
  LV.Push(10);
  LV.Push(20);
  LV.Push(30);
  LV.Delete(1);
  CheckEqual(Int64(2), Int64(LV.Count));
  CheckEqual(Int64(10), Int64(LV[0]));
  CheckEqual(Int64(30), Int64(LV[1]));
end;

procedure TestDeleteSwap;
var
  LV: IIntVec;
begin
  LV := TIntVec.Create;
  LV.Push(10);
  LV.Push(20);
  LV.Push(30);
  LV.DeleteSwap(0);
  CheckEqual(Int64(2), Int64(LV.Count));
  CheckEqual(Int64(30), Int64(LV[0]));
  CheckEqual(Int64(20), Int64(LV[1]));
end;

procedure TestPop;
var
  LV: IIntVec;
begin
  LV := TIntVec.Create;
  LV.Push(1);
  LV.Push(2);
  LV.Push(3);
  CheckEqual(Int64(3), Int64(LV.Pop));
  CheckEqual(Int64(2), Int64(LV.Count));
  CheckEqual(Int64(2), Int64(LV.Pop));
  CheckEqual(Int64(1), Int64(LV.Count));
end;

procedure TestGrow;
var
  LV: IIntVec;
  LI: Integer;
begin
  LV := TIntVec.Create;
  for LI := 0 to 999 do
    LV.Push(LI);
  CheckEqual(Int64(1000), Int64(LV.Count));
  CheckEqual(Int64(0), Int64(LV[0]));
  CheckEqual(Int64(999), Int64(LV[999]));
end;

procedure TestContains;
var
  LV: IIntVec;
begin
  LV := TIntVec.Create;
  LV.Push(5);
  LV.Push(10);
  LV.Push(15);
  Check(LV.Contains(10));
  Check(not LV.Contains(7));
end;

procedure TestIndexOf;
var
  LV: IIntVec;
begin
  LV := TIntVec.Create;
  LV.Push(100);
  LV.Push(200);
  LV.Push(300);
  CheckEqual(Int64(1), LV.Find(200));
  CheckEqual(Int64(-1), LV.Find(999));
end;

procedure TestReserve;
var
  LV: IIntVec;
begin
  LV := TIntVec.Create;
  LV.Reserve(100);
  Check(LV.Capacity >= 100);
  CheckEqual(Int64(0), Int64(LV.Count));
end;

procedure TestString;
var
  LV: IStrVec;
begin
  LV := TStrVec.Create;
  LV.Push('hello');
  LV.Push('world');
  CheckEqual(Int64(2), Int64(LV.Count));
  CheckEqual('hello', LV[0]);
  CheckEqual('world', LV[1]);
end;

procedure TestClear;
var
  LV: IIntVec;
begin
  LV := TIntVec.Create;
  LV.Push(1);
  LV.Push(2);
  LV.Clear;
  Check(LV.IsEmpty);
  Check(LV.Capacity > 0);
end;

procedure TestAutoFree;
var
  LV: IIntVec;
begin
  LV := TIntVec.Create;
  LV.Push(42);
  LV := nil;
  // no crash = interface ref-counting freed the object
  Check(True);
end;

procedure TestPush;
var
  LV: TIntVec;
begin
  LV := TIntVec.Create;
  try
    LV.Push(10);
    LV.Push(20);
    LV.Push([30, 40, 50]);
    CheckEqual(Int64(5), Int64(LV.Count), 'count after push');
    CheckEqual(Int64(10), Int64(LV.Get(0)), 'first');
    CheckEqual(Int64(50), Int64(LV.Get(4)), 'last');
  finally
    LV.Free;
  end;
end;

procedure TestPeekAndTryPeek;
var
  LV: TIntVec;
  LVal: Integer;
begin
  LV := TIntVec.Create;
  try
    LV.Push(1);
    LV.Push(2);
    LV.Push(3);
    CheckEqual(Int64(3), Int64(LV.Peek), 'peek returns last');
    CheckEqual(Int64(3), Int64(LV.Count), 'peek does not remove');
    Check(LV.TryPeek(LVal), 'try peek');
    CheckEqual(Int64(3), Int64(LVal), 'try peek value');
  finally
    LV.Free;
  end;
end;

procedure TestRemoveAt;
var
  LV: TIntVec;
begin
  LV := TIntVec.Create;
  try
    LV.Push([10, 20, 30, 40]);
    CheckEqual(Int64(20), Int64(LV.RemoveAt(1)), 'remove at 1');
    CheckEqual(Int64(3), Int64(LV.Count), 'count after remove');
    CheckEqual(Int64(30), Int64(LV.Get(1)), 'shifted');
  finally
    LV.Free;
  end;
end;

procedure TestSwapRemoveAt;
var
  LV: TIntVec;
begin
  LV := TIntVec.Create;
  try
    LV.Push([10, 20, 30, 40]);
    CheckEqual(Int64(20), Int64(LV.SwapRemoveAt(1)), 'swap remove at 1');
    CheckEqual(Int64(3), Int64(LV.Count), 'count');
    CheckEqual(Int64(40), Int64(LV.Get(1)), 'last swapped in');
  finally
    LV.Free;
  end;
end;

procedure TestTryRemoveAt;
var
  LV: TIntVec;
  LVal: Integer;
begin
  LV := TIntVec.Create;
  try
    LV.Push([10, 20, 30]);
    Check(LV.TryRemoveAt(1, LVal), 'try remove at 1');
    CheckEqual(Int64(20), Int64(LVal), 'removed value');
    Check(not LV.TryRemoveAt(99, LVal), 'try remove invalid index');
  finally
    LV.Free;
  end;
end;

procedure TestDrain;
var
  LV: TIntVec;
  LDrained: IIntVec;
begin
  LV := TIntVec.Create;
  try
    LV.Push([1, 2, 3, 4, 5]);
    LDrained := LV.Drain(1, 3);
    CheckEqual(Int64(3), Int64(LDrained.Count), 'drained count');
    CheckEqual(Int64(2), Int64(LDrained.Get(0)), 'drained[0]');
    CheckEqual(Int64(4), Int64(LDrained.Get(2)), 'drained[2]');
    CheckEqual(Int64(2), Int64(LV.Count), 'source count after drain');
    CheckEqual(Int64(1), Int64(LV.Get(0)), 'source[0]');
    CheckEqual(Int64(5), Int64(LV.Get(1)), 'source[1]');
  finally
    LV.Free;
  end;
end;

procedure TestSplitOff;
var
  LV: TIntVec;
  LRight: IIntVec;
begin
  LV := TIntVec.Create;
  try
    LV.Push([1, 2, 3, 4, 5]);
    LRight := LV.SplitOff(3);
    CheckEqual(Int64(3), Int64(LV.Count), 'left count');
    CheckEqual(Int64(2), Int64(LRight.Count), 'right count');
    CheckEqual(Int64(4), Int64(LRight.Get(0)), 'right[0]');
    CheckEqual(Int64(5), Int64(LRight.Get(1)), 'right[1]');
  finally
    LV.Free;
  end;
end;

procedure TestShrinkToFit;
var
  LV: TIntVec;
begin
  LV := TIntVec.Create;
  try
    LV.Reserve(100);
    LV.Push([1, 2, 3]);
    Check(LV.GetCapacity >= 100, 'capacity after reserve');
    LV.ShrinkToFit;
    CheckEqual(Int64(3), Int64(LV.GetCapacity), 'capacity after shrink');
    CheckEqual(Int64(3), Int64(LV.Count), 'count preserved');
  finally
    LV.Free;
  end;
end;

procedure TestTruncate;
var
  LV: TIntVec;
begin
  LV := TIntVec.Create;
  try
    LV.Push([1, 2, 3, 4, 5]);
    LV.Truncate(3);
    CheckEqual(Int64(3), Int64(LV.Count), 'count after truncate');
    CheckEqual(Int64(3), Int64(LV.Get(2)), 'last element');
  finally
    LV.Free;
  end;
end;

procedure TestFirstLast;
var
  LV: TIntVec;
begin
  LV := TIntVec.Create;
  try
    LV.Push([10, 20, 30]);
    CheckEqual(Int64(10), Int64(LV.First), 'first');
    CheckEqual(Int64(30), Int64(LV.Last), 'last');
  finally
    LV.Free;
  end;
end;

begin
  T := TTestRunner.Create('nextpas.core.collections.vec');
  T.Run('Create', @TestCreate);
  T.Run('Add', @TestAdd);
  T.Run('Insert', @TestInsert);
  T.Run('Delete', @TestDelete);
  T.Run('DeleteSwap', @TestDeleteSwap);
  T.Run('Pop', @TestPop);
  T.Run('Grow (1000 elements)', @TestGrow);
  T.Run('Contains', @TestContains);
  T.Run('IndexOf', @TestIndexOf);
  T.Run('Reserve', @TestReserve);
  T.Run('String type', @TestString);
  T.Run('Clear', @TestClear);
  T.Run('Auto free (interface)', @TestAutoFree);
  T.Run('Push', @TestPush);
  T.Run('Peek/TryPeek', @TestPeekAndTryPeek);
  T.Run('RemoveAt', @TestRemoveAt);
  T.Run('SwapRemoveAt', @TestSwapRemoveAt);
  T.Run('TryRemoveAt', @TestTryRemoveAt);
  T.Run('Drain', @TestDrain);
  T.Run('SplitOff', @TestSplitOff);
  T.Run('ShrinkToFit', @TestShrinkToFit);
  T.Run('Truncate', @TestTruncate);
  T.Run('First/Last', @TestFirstLast);
  T.Summary;
end.
