program test_vec;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.testing,
  nextpas.core.collections,
  nextpas.core.collections.vec.intf,
  nextpas.core.collections.vec;

type
  IIntVec = specialize IVec<Integer>;
  TIntVec = specialize TVec<Integer>;
  IStrVec = specialize IVec<string>;
  TStrVec = specialize TVec<string>;

function IsEven(const V: Integer; Data: Pointer): Boolean;
begin
  Result := (V mod 2) = 0;
end;

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

procedure TestReserveFailureRaisesOutOfMemory;
var
  LV: IIntVec;
  LCaught: Boolean;
begin
  LCaught := False;
  LV := TIntVec.Create;
  LV.Push(1);
  try
    try
      LV.Reserve(SizeUInt(-1));
    except
      on E: EOutOfMemoryError do
        LCaught := True;
    end;
  finally
    LV := nil;
  end;
  Check(LCaught, 'Reserve overflow failure raises canonical OOM');
end;

procedure TestReserveExactFailureRaisesOutOfMemory;
var
  LV: IIntVec;
  LCaught: Boolean;
begin
  LCaught := False;
  LV := TIntVec.Create;
  LV.Push(1);
  try
    try
      LV.ReserveExact(SizeUInt(-1));
    except
      on E: EOutOfMemoryError do
        LCaught := True;
    end;
  finally
    LV := nil;
  end;
  Check(LCaught, 'ReserveExact overflow failure raises canonical OOM');
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

procedure TestTryPop;
var
  LV: TIntVec;
  LVal: Integer;
begin
  LV := TIntVec.Create;
  try
    Check(not LV.TryPop(LVal), 'try pop on empty');
    LV.Push([1, 2, 3]);
    Check(LV.TryPop(LVal), 'try pop');
    CheckEqual(Int64(3), Int64(LVal), 'popped value');
    CheckEqual(Int64(2), Int64(LV.Count), 'count after pop');
  finally
    LV.Free;
  end;
end;

procedure TestTrySwapRemoveAt;
var
  LV: TIntVec;
  LVal: Integer;
begin
  LV := TIntVec.Create;
  try
    LV.Push([10, 20, 30, 40]);
    Check(LV.TrySwapRemoveAt(1, LVal), 'try swap remove');
    CheckEqual(Int64(20), Int64(LVal), 'removed value');
    CheckEqual(Int64(3), Int64(LV.Count), 'count');
    Check(not LV.TrySwapRemoveAt(99, LVal), 'invalid index');
  finally
    LV.Free;
  end;
end;

procedure TestFilter;
var
  LV: TIntVec;
  LFiltered: IIntVec;
begin
  LV := TIntVec.Create;
  try
    LV.Push([1, 2, 3, 4, 5, 6]);
    LFiltered := LV.Filter(@IsEven, nil);
    CheckEqual(Int64(3), Int64(LFiltered.Count), 'filtered count');
    CheckEqual(Int64(2), Int64(LFiltered.Get(0)), 'filtered[0]');
    CheckEqual(Int64(4), Int64(LFiltered.Get(1)), 'filtered[1]');
    CheckEqual(Int64(6), Int64(LFiltered.Get(2)), 'filtered[2]');
    CheckEqual(Int64(6), Int64(LV.Count), 'source unchanged');
  finally
    LV.Free;
  end;
end;

procedure TestRetain;
var
  LV: TIntVec;
begin
  LV := TIntVec.Create;
  try
    LV.Push([1, 2, 3, 4, 5, 6]);
    LV.Retain(@IsEven, nil);
    CheckEqual(Int64(3), Int64(LV.Count), 'retained count');
    CheckEqual(Int64(2), Int64(LV.Get(0)), 'retained[0]');
    CheckEqual(Int64(4), Int64(LV.Get(1)), 'retained[1]');
    CheckEqual(Int64(6), Int64(LV.Get(2)), 'retained[2]');
  finally
    LV.Free;
  end;
end;

procedure TestAnyAll;
var
  LV: TIntVec;
begin
  LV := TIntVec.Create;
  try
    LV.Push([2, 4, 6]);
    Check(LV.All(@IsEven, nil), 'all even');
    Check(LV.Any(@IsEven, nil), 'any even');
    LV.Push(3);
    Check(not LV.All(@IsEven, nil), 'not all even after odd');
    Check(LV.Any(@IsEven, nil), 'still any even');
  finally
    LV.Free;
  end;
end;

procedure TestDedup;
var
  LV: TIntVec;
begin
  LV := TIntVec.Create;
  try
    LV.Push([1, 1, 2, 2, 2, 3, 3, 1]);
    LV.Dedup;
    CheckEqual(Int64(4), Int64(LV.Count), 'dedup adjacent');
    CheckEqual(Int64(1), Int64(LV.Get(0)), '[0]');
    CheckEqual(Int64(2), Int64(LV.Get(1)), '[1]');
    CheckEqual(Int64(3), Int64(LV.Get(2)), '[2]');
    CheckEqual(Int64(1), Int64(LV.Get(3)), '[3] non-adjacent dup kept');
  finally
    LV.Free;
  end;
end;

procedure TestSplice;
var
  LV: TIntVec;
begin
  LV := TIntVec.Create;
  try
    LV.Push([1, 2, 3, 4, 5]);
    LV.Splice(1, 2, [10, 20, 30]);
    CheckEqual(Int64(6), Int64(LV.Count), 'count after splice');
    CheckEqual(Int64(1), Int64(LV.Get(0)), '[0]');
    CheckEqual(Int64(10), Int64(LV.Get(1)), '[1] inserted');
    CheckEqual(Int64(20), Int64(LV.Get(2)), '[2] inserted');
    CheckEqual(Int64(30), Int64(LV.Get(3)), '[3] inserted');
    CheckEqual(Int64(4), Int64(LV.Get(4)), '[4] shifted');
    CheckEqual(Int64(5), Int64(LV.Get(5)), '[5] shifted');
  finally
    LV.Free;
  end;
end;

procedure TestEnsureCapacity;
var
  LV: TIntVec;
begin
  LV := TIntVec.Create;
  try
    LV.EnsureCapacity(50);
    Check(LV.GetCapacity >= 50, 'capacity ensured');
    CheckEqual(Int64(0), Int64(LV.Count), 'count unchanged');
  finally
    LV.Free;
  end;
end;

procedure TestReserveExact;
var
  LV: TIntVec;
begin
  LV := TIntVec.Create;
  try
    LV.Push([1, 2, 3]);
    LV.ReserveExact(5);
    Check(LV.GetCapacity >= 8, 'reserve exact grows');
    CheckEqual(Int64(3), Int64(LV.Count), 'count unchanged');
  finally
    LV.Free;
  end;
end;

procedure TestResizeExact;
var
  LV: TIntVec;
begin
  LV := TIntVec.Create;
  try
    LV.Push([1, 2, 3, 4, 5]);
    LV.ResizeExact(3);
    CheckEqual(Int64(3), Int64(LV.Count), 'count after resize down');
    Check(LV.GetCapacity <= 5, 'capacity shrunk');
  finally
    LV.Free;
  end;
end;

procedure TestSetCapacity;
var
  LV: TIntVec;
begin
  LV := TIntVec.Create;
  try
    LV.Push([1, 2, 3]);
    LV.SetCapacity(10);
    CheckEqual(Int64(10), Int64(LV.GetCapacity), 'capacity set');
    CheckEqual(Int64(3), Int64(LV.Count), 'count unchanged');
  finally
    LV.Free;
  end;
end;

procedure TestFreeBuffer;
var
  LV: TIntVec;
begin
  LV := TIntVec.Create;
  try
    LV.Push([1, 2, 3]);
    LV.FreeBuffer;
    CheckEqual(Int64(0), Int64(LV.Count), 'count 0 after free buffer');
    CheckEqual(Int64(0), Int64(LV.GetCapacity), 'capacity 0');
  finally
    LV.Free;
  end;
end;

procedure TestWrite;
var
  LV: TIntVec;
begin
  LV := TIntVec.Create;
  try
    LV.Push([1, 2, 3]);
    LV.Write(1, [10, 20, 30]);
    CheckEqual(Int64(4), Int64(LV.Count), 'write extends');
    CheckEqual(Int64(1), Int64(LV.Get(0)), '[0] unchanged');
    CheckEqual(Int64(10), Int64(LV.Get(1)), '[1] written');
    CheckEqual(Int64(30), Int64(LV.Get(3)), '[3] written');
  finally
    LV.Free;
  end;
end;

procedure TestWriteExact;
var
  LV: TIntVec;
begin
  LV := TIntVec.Create;
  try
    LV.Push([0, 0, 0, 0, 0]);
    LV.WriteExact(2, [7, 8, 9]);
    CheckEqual(Int64(5), Int64(LV.Count), 'count unchanged');
    CheckEqual(Int64(7), Int64(LV.Get(2)), '[2]');
    CheckEqual(Int64(9), Int64(LV.Get(4)), '[4]');
  finally
    LV.Free;
  end;
end;

procedure TestTryLoadFrom;
var
  LV, LSrc: TIntVec;
begin
  LV := TIntVec.Create;
  LSrc := TIntVec.Create;
  try
    LSrc.Push([10, 20, 30]);
    Check(LV.TryLoadFrom(LSrc), 'try load from');
    CheckEqual(Int64(3), Int64(LV.Count), 'count');
    CheckEqual(Int64(10), Int64(LV.Get(0)), '[0]');
  finally
    LSrc.Free;
    LV.Free;
  end;
end;

procedure TestTryAppend;
var
  LV, LSrc: TIntVec;
begin
  LV := TIntVec.Create;
  LSrc := TIntVec.Create;
  try
    LV.Push([1, 2]);
    LSrc.Push([3, 4]);
    Check(LV.TryAppend(LSrc), 'try append');
    CheckEqual(Int64(4), Int64(LV.Count), 'count');
    CheckEqual(Int64(3), Int64(LV.Get(2)), '[2]');
  finally
    LSrc.Free;
    LV.Free;
  end;
end;

function SameDiv10(const A, B: Integer; aData: Pointer): Boolean;
begin
  Result := (A div 10) = (B div 10);
end;

procedure TestDedupBy;
var
  LV: TIntVec;
begin
  LV := TIntVec.Create;
  try
    LV.Push([11, 12, 21, 22, 23, 31]);
    LV.DedupBy(@SameDiv10, nil);
    CheckEqual(Int64(3), Int64(LV.Count), 'dedup by div10');
    CheckEqual(Int64(11), Int64(LV.Get(0)), '[0]');
    CheckEqual(Int64(21), Int64(LV.Get(1)), '[1]');
    CheckEqual(Int64(31), Int64(LV.Get(2)), '[2]');
  finally
    LV.Free;
  end;
end;

procedure TestGetSetGrowStrategy;
var
  LV: TIntVec;
begin
  LV := TIntVec.Create;
  try
    Check(LV.GetGrowStrategy <> nil, 'has default strategy');
    LV.SetGrowStrategy(DoublingGrow);
    Check(LV.GetGrowStrategy <> nil, 'strategy set');
  finally
    LV.Free;
  end;
end;

procedure TestRemoveCopyAt;
var
  LV: TIntVec;
  LDst: Integer;
begin
  LV := TIntVec.Create;
  try
    LV.Push([10, 20, 30, 40]);
    LV.RemoveCopyAt(1, @LDst, 1);
    CheckEqual(Int64(20), Int64(LDst), 'copied value');
    CheckEqual(Int64(3), Int64(LV.Count), 'count after remove copy');
  finally
    LV.Free;
  end;
end;

procedure TestSwapRemoveCopyAt;
var
  LV: TIntVec;
  LDst: Integer;
begin
  LV := TIntVec.Create;
  try
    LV.Push([10, 20, 30, 40]);
    LV.SwapRemoveCopyAt(1, @LDst, 1);
    CheckEqual(Int64(20), Int64(LDst), 'copied value');
    CheckEqual(Int64(3), Int64(LV.Count), 'count');
    CheckEqual(Int64(40), Int64(LV.Get(1)), 'last swapped in');
  finally
    LV.Free;
  end;
end;

procedure TestSortAdversarial;
var
  LV: TIntVec;
  i: Integer;
begin
  LV := TIntVec.Create;
  try
    for i := 999 downto 0 do
      LV.Push(i);
    LV.Sort;
    for i := 0 to 998 do
      Check(LV.Get(i) <= LV.Get(i + 1), 'reverse sorted');

    LV.Clear;
    for i := 0 to 999 do
      LV.Push(42);
    LV.Sort;
    for i := 0 to 999 do
      CheckEqual(Int64(42), Int64(LV.Get(i)), 'all same');

    LV.Clear;
    for i := 0 to 999 do
      LV.Push(i);
    LV.Sort;
    for i := 0 to 998 do
      Check(LV.Get(i) <= LV.Get(i + 1), 'already sorted');
  finally
    LV.Free;
  end;
end;

procedure TestPushPointerBulk;
var
  LV: TIntVec;
  LSrc: array[0..4] of Integer;
begin
  LSrc[0] := 10; LSrc[1] := 20; LSrc[2] := 30; LSrc[3] := 40; LSrc[4] := 50;
  LV := TIntVec.Create;
  try
    LV.Push(@LSrc[0], 5);
    CheckEqual(Int64(5), Int64(LV.Count), 'count');
    CheckEqual(Int64(10), Int64(LV.Get(0)), '[0]');
    CheckEqual(Int64(30), Int64(LV.Get(2)), '[2]');
    CheckEqual(Int64(50), Int64(LV.Get(4)), '[4]');
  finally
    LV.Free;
  end;
end;

procedure TestInsertPointerBulk;
var
  LV: TIntVec;
  LSrc: array[0..1] of Integer;
begin
  LSrc[0] := 77; LSrc[1] := 88;
  LV := TIntVec.Create;
  try
    LV.Push([1, 2, 3]);
    LV.Insert(1, @LSrc[0], 2);
    CheckEqual(Int64(5), Int64(LV.Count), 'count');
    CheckEqual(Int64(1), Int64(LV.Get(0)), '[0]');
    CheckEqual(Int64(77), Int64(LV.Get(1)), 'inserted[0]');
    CheckEqual(Int64(88), Int64(LV.Get(2)), 'inserted[1]');
    CheckEqual(Int64(2), Int64(LV.Get(3)), 'shifted[0]');
    CheckEqual(Int64(3), Int64(LV.Get(4)), 'shifted[1]');
  finally
    LV.Free;
  end;
end;

procedure TestDeleteMulti;
var
  LV: TIntVec;
begin
  LV := TIntVec.Create;
  try
    LV.Push([10, 20, 30, 40, 50]);
    LV.Delete(1, 2);
    CheckEqual(Int64(3), Int64(LV.Count), 'count');
    CheckEqual(Int64(10), Int64(LV.Get(0)), '[0]');
    CheckEqual(Int64(40), Int64(LV.Get(1)), '[1]');
    CheckEqual(Int64(50), Int64(LV.Get(2)), '[2]');
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
  T.Run('Reserve failure raises OOM', @TestReserveFailureRaisesOutOfMemory);
  T.Run('ReserveExact failure raises OOM', @TestReserveExactFailureRaisesOutOfMemory);
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
  T.Run('TryPop', @TestTryPop);
  T.Run('TrySwapRemoveAt', @TestTrySwapRemoveAt);
  T.Run('Filter', @TestFilter);
  T.Run('Retain', @TestRetain);
  T.Run('Any/All', @TestAnyAll);
  T.Run('Dedup', @TestDedup);
  T.Run('Splice', @TestSplice);
  T.Run('EnsureCapacity', @TestEnsureCapacity);
  T.Run('ReserveExact', @TestReserveExact);
  T.Run('ResizeExact', @TestResizeExact);
  T.Run('SetCapacity', @TestSetCapacity);
  T.Run('FreeBuffer', @TestFreeBuffer);
  T.Run('Write', @TestWrite);
  T.Run('WriteExact', @TestWriteExact);
  T.Run('TryLoadFrom', @TestTryLoadFrom);
  T.Run('TryAppend', @TestTryAppend);
  T.Run('DedupBy', @TestDedupBy);
  T.Run('Get/SetGrowStrategy', @TestGetSetGrowStrategy);
  T.Run('RemoveCopyAt', @TestRemoveCopyAt);
  T.Run('SwapRemoveCopyAt', @TestSwapRemoveCopyAt);
  T.Run('Sort adversarial inputs', @TestSortAdversarial);
  T.Run('Push(Pointer, Count) bulk', @TestPushPointerBulk);
  T.Run('Insert(Index, Pointer, Count) bulk', @TestInsertPointerBulk);
  T.Run('Delete(Index, Count) multi', @TestDeleteMulti);
  T.Summary;
end.
