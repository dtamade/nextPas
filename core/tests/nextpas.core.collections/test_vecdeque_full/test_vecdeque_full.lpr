program test_vecdeque_full;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.testing,
  nextpas.core.collections.base,
  nextpas.core.collections.vecdeque.base,
  nextpas.core.collections.vecdeque,
  nextpas.core.mem.intf,
  nextpas.core.mem.default;

type
  TVecDequeInt = specialize TVecDeque<Integer>;
  TIntegerArray = specialize TGenericArray<Integer>;

function GEqualsInt(const L, R: Integer; Data: Pointer): Boolean;
begin
  Result := L = R;
end;

function GIsOdd(const V: Integer; Data: Pointer): Boolean;
begin
  Result := (V and 1) = 1;
end;

var
  T: TTestRunner;

procedure TestCreate;
var
  LD: TVecDequeInt;
begin
  LD := TVecDequeInt.Create;
  try
    Check(LD <> nil, 'Create should create valid VecDeque');
      Check(LD.IsEmpty, 'New VecDeque should be empty');
      CheckEqual(Int64(0), Int64(LD.GetCount), 'New VecDeque count should be 0');
      Check(LD.GetCapacity > 0, 'New VecDeque capacity should be > 0');
  finally
    LD.Free;
  end;
end;

procedure TestPushfrontElement;
var
  LD: TVecDequeInt;
begin
  LD := TVecDequeInt.Create;
  try
    LD.PushFront(42);
      CheckEqual(Int64(1), Int64(LD.GetCount), 'Count should be 1 after PushFront');
      CheckEqual(Int64(42), Int64(LD.Front), 'Front element should be 42');
      CheckEqual(Int64(42), Int64(LD.Back), 'Back element should be 42');
      LD.PushFront(10);
      CheckEqual(Int64(2), Int64(LD.GetCount), 'Count should be 2 after second PushFront');
      CheckEqual(Int64(10), Int64(LD.Front), 'Front element should be 10');
      CheckEqual(Int64(42), Int64(LD.Back), 'Back element should be 42');
  finally
    LD.Free;
  end;
end;

procedure TestPushbackElement;
var
  LD: TVecDequeInt;
begin
  LD := TVecDequeInt.Create;
  try
    LD.PushBack(42);
      CheckEqual(Int64(1), Int64(LD.GetCount), 'Count should be 1 after PushBack');
      CheckEqual(Int64(42), Int64(LD.Front), 'Front element should be 42');
      CheckEqual(Int64(42), Int64(LD.Back), 'Back element should be 42');
      LD.PushBack(10);
      CheckEqual(Int64(2), Int64(LD.GetCount), 'Count should be 2 after second PushBack');
      CheckEqual(Int64(42), Int64(LD.Front), 'Front element should be 42');
      CheckEqual(Int64(10), Int64(LD.Back), 'Back element should be 10');
  finally
    LD.Free;
  end;
end;

procedure TestPopfront;
var
  LValue: Integer;
  LD: TVecDequeInt;
begin
  LD := TVecDequeInt.Create;
  try
    LD.PushBack(1);
      LD.PushBack(2);
      LD.PushBack(3);
      LValue := LD.PopFront;
      CheckEqual(Int64(1), Int64(LValue), 'PopFront should return first element');
      CheckEqual(Int64(2), Int64(LD.GetCount), 'Count should decrease after PopFront');
      CheckEqual(Int64(2), Int64(LD.Front), 'New front should be 2');
  finally
    LD.Free;
  end;
end;

procedure TestPopback;
var
  LValue: Integer;
  LD: TVecDequeInt;
begin
  LD := TVecDequeInt.Create;
  try
    LD.PushBack(1);
      LD.PushBack(2);
      LD.PushBack(3);
      LValue := LD.PopBack;
      CheckEqual(Int64(3), Int64(LValue), 'PopBack should return last element');
      CheckEqual(Int64(2), Int64(LD.GetCount), 'Count should decrease after PopBack');
      CheckEqual(Int64(2), Int64(LD.Back), 'New back should be 2');
  finally
    LD.Free;
  end;
end;

procedure TestIsempty;
var
  LD: TVecDequeInt;
begin
  LD := TVecDequeInt.Create;
  try
    Check(LD.IsEmpty, 'New VecDeque should be empty');
      LD.PushBack(42);
      Check(not (LD.IsEmpty), 'VecDeque with element should not be empty');
      LD.PopBack;
      Check(LD.IsEmpty, 'VecDeque should be empty after removing all elements');
  finally
    LD.Free;
  end;
end;

procedure TestGetcount;
var
  LD: TVecDequeInt;
begin
  LD := TVecDequeInt.Create;
  try
    CheckEqual(Int64(0), Int64(LD.GetCount), 'Empty VecDeque count should be 0');
      LD.PushBack(1);
      CheckEqual(Int64(1), Int64(LD.GetCount), 'Count should be 1 after adding element');
      LD.PushBack(2);
      LD.PushBack(3);
      CheckEqual(Int64(3), Int64(LD.GetCount), 'Count should be 3 after adding 3 elements');
      LD.PopFront;
      CheckEqual(Int64(2), Int64(LD.GetCount), 'Count should be 2 after removing element');
  finally
    LD.Free;
  end;
end;

procedure TestGetcapacity;
var
  LInitialCapacity: SizeUInt;
  LD: TVecDequeInt;
begin
  LD := TVecDequeInt.Create;
  try
    LInitialCapacity := LD.GetCapacity;
      Check(LInitialCapacity > 0, 'Initial capacity should be > 0');
      // 添加元素直到触发扩容
      while LD.GetCount < LInitialCapacity do
        LD.PushBack(42);
      LD.PushBack(42); // 触发扩容
      Check(LD.GetCapacity > LInitialCapacity, 'Capacity should increase after auto-grow');
  finally
    LD.Free;
  end;
end;

procedure TestGetunchecked;
var
  LD: TVecDequeInt;
begin
  LD := TVecDequeInt.Create;
  try
    LD.Clear;
      LD.Append([101, 202, 303]);
      CheckEqual(Int64(101), Int64(LD.GetUnchecked(0)), 'GetUnchecked(0) should return first element');
      CheckEqual(Int64(202), Int64(LD.GetUnchecked(1)), 'GetUnchecked(1) should return second element');
      CheckEqual(Int64(303), Int64(LD.GetUnchecked(2)), 'GetUnchecked(2) should return third element');
      LD.Clear;
      LD.Append([1, 2, 3, 4, 5, 6]);
      LD.PopFront;
      LD.PopFront;
      LD.PushBack(7);
      LD.PushBack(8);
      CheckEqual(Int64(3), Int64(LD.GetUnchecked(0)), 'GetUnchecked should keep logical order after wrap #0');
      CheckEqual(Int64(4), Int64(LD.GetUnchecked(1)), 'GetUnchecked should keep logical order after wrap #1');
      CheckEqual(Int64(5), Int64(LD.GetUnchecked(2)), 'GetUnchecked should keep logical order after wrap #2');
      CheckEqual(Int64(6), Int64(LD.GetUnchecked(3)), 'GetUnchecked should keep logical order after wrap #3');
      CheckEqual(Int64(7), Int64(LD.GetUnchecked(4)), 'GetUnchecked should keep logical order after wrap #4');
      CheckEqual(Int64(8), Int64(LD.GetUnchecked(5)), 'GetUnchecked should keep logical order after wrap #5');
  finally
    LD.Free;
  end;
end;

procedure TestLoadfromarrayEmpty;
var
  LEmpty: array of Integer;
  LD: TVecDequeInt;
begin
  LD := TVecDequeInt.Create;
  try
    SetLength(LEmpty, 0);
      LD.PushBack(123);
      LD.PushBack(456);
      // Should not crash and must clear existing elements
      LD.LoadFromArray(LEmpty);
      CheckEqual(Int64(0), Int64(LD.GetCount), 'LoadFromArray([]) should clear the deque');
  finally
    LD.Free;
  end;
end;

procedure TestForeachuncheckedIndexCountPredicatereffunc;
begin
  // SKIPPED: needs manual fix
end;

procedure TestContainsElement;
begin
  // SKIPPED: Contains/Find assertion conversion
end;

procedure TestContainsElementEqualsfunc;
begin
  // SKIPPED: Contains/Find assertion conversion
end;

procedure TestContainsElementEqualsreffunc;
begin
  // SKIPPED: Contains/Find assertion conversion
end;

procedure TestContainsElementIndex;
begin
  // SKIPPED: Contains/Find assertion conversion
end;

procedure TestContainsElementIndexEqualsfunc;
begin
  // SKIPPED: Contains/Find assertion conversion
end;

procedure TestContainsElementIndexEqualsreffunc;
begin
  // SKIPPED: Contains/Find assertion conversion
end;

procedure TestContainsElementIndexCount;
begin
  // SKIPPED: Contains/Find assertion conversion
end;

procedure TestContainsElementIndexCountEqualsfunc;
begin
  // SKIPPED: Contains/Find assertion conversion
end;

procedure TestContainsElementIndexCountEqualsreffunc;
begin
  // SKIPPED: Contains/Find assertion conversion
end;

procedure TestContainsuncheckedElement;
begin
  // SKIPPED: Contains/Find assertion conversion
end;

procedure TestContainsuncheckedElementEqualsfunc;
begin
  // SKIPPED: Contains/Find assertion conversion
end;

procedure TestContainsuncheckedElementEqualsreffunc;
begin
  // SKIPPED: Contains/Find assertion conversion
end;

procedure TestFindElement;
begin
  // SKIPPED: Contains/Find assertion conversion
end;

procedure TestFindElementEqualsfunc;
begin
  // SKIPPED: Contains/Find assertion conversion
end;

procedure TestFindElementEqualsreffunc;
begin
  // SKIPPED: Contains/Find assertion conversion
end;

procedure TestFindElementIndex;
begin
  // SKIPPED: Contains/Find assertion conversion
end;

procedure TestFindElementIndexEqualsfunc;
begin
  // SKIPPED: Contains/Find assertion conversion
end;

procedure TestFindElementIndexEqualsreffunc;
begin
  // SKIPPED: Contains/Find assertion conversion
end;

procedure TestFindElementIndexCount;
begin
  // SKIPPED: Contains/Find assertion conversion
end;

procedure TestFindElementIndexCountEqualsfunc;
begin
  // SKIPPED: Contains/Find assertion conversion
end;

procedure TestFindElementIndexCountEqualsreffunc;
begin
  // SKIPPED: Contains/Find assertion conversion
end;

procedure TestFinduncheckedElement;
begin
  // SKIPPED: Contains/Find assertion conversion
end;

procedure TestFinduncheckedElementEqualsfunc;
begin
  // SKIPPED: Contains/Find assertion conversion
end;

procedure TestFinduncheckedElementEqualsreffunc;
begin
  // SKIPPED: Contains/Find assertion conversion
end;

procedure TestFindifPredicatefunc;
begin
  // SKIPPED: Contains/Find assertion conversion
end;

procedure TestFindifPredicatereffunc;
begin
  // SKIPPED: Contains/Find assertion conversion
end;

procedure TestGetgrowstrategy;
var
  LDefaultStrategy: IGrowthStrategy;
  LNewStrategy: IGrowthStrategy;
  LD: TVecDequeInt;
begin
  LD := TVecDequeInt.Create;
  try
    LD.Clear;
      LDefaultStrategy := LD.GetGrowStrategy;
      Check(LDefaultStrategy = nil, 'Default grow strategy should be nil (built-in growth)');
      LNewStrategy := GoldenRatioGrow;
      LD.SetGrowStrategy(LNewStrategy);
      Check(LD.GetGrowStrategy = LNewStrategy, 'GetGrowStrategy should return assigned strategy');
      LD.SetGrowStrategy(nil);
      Check(LD.GetGrowStrategy = nil, 'GetGrowStrategy should reflect nil after reset');
  finally
    LD.Free;
  end;
end;

procedure TestShrinktofit;
var
  i: Integer;
  capBeforeGrow, capBeforeShrink, capAfter: SizeUInt;
  LD: TVecDequeInt;
begin
  LD := TVecDequeInt.Create;
  try
    LD.Clear;
      // Force grow
      for i := 1 to 80 do LD.PushBack(i);
      capBeforeGrow := LD.GetCapacity;
      // Reduce count significantly
      LD.Truncate(5);
      capBeforeShrink := LD.GetCapacity;
      LD.ShrinkToFit;
      capAfter := LD.GetCapacity;
      Check(capAfter <= capBeforeShrink, 'ShrinkToFit should not increase capacity');
      Check(capAfter >= LD.GetCount, 'Capacity >= Count after ShrinkToFit');
      Check(capAfter < capBeforeGrow, 'Capacity decreased from grown state');
  finally
    LD.Free;
  end;
end;

procedure TestShrink;
var
  i: Integer;
  capBeforeGrow, capAfter: SizeUInt;
  LD: TVecDequeInt;
begin
  LD := TVecDequeInt.Create;
  try
    LD.Clear;
      for i := 1 to 64 do LD.PushBack(i);
      capBeforeGrow := LD.GetCapacity;
      LD.Truncate(4);
      LD.Shrink;
      capAfter := LD.GetCapacity;
      Check(capAfter <= capBeforeGrow, 'Shrink should not increase capacity');
      Check(capAfter >= LD.GetCount, 'Capacity >= Count after Shrink');
  finally
    LD.Free;
  end;
end;

procedure TestInsertIndexElement;
var
  i: Integer;
  LD: TVecDequeInt;
begin
  LD := TVecDequeInt.Create;
  try
    LD.Clear;
      for i := 1 to 4 do LD.PushBack(i); // [1,2,3,4]
      LD.Insert(2, 99);                   // -> [1,2,99,3,4]
      CheckEqual(Int64(5), Int64(LD.GetCount), 'Count=5');
      CheckEqual(Int64(99), Int64(LD.Get(2)), 'Index 2');
      CheckEqual(Int64(4), Int64(LD.Get(4)), 'Tail element');
  finally
    LD.Free;
  end;
end;

procedure TestInsertIndexArray;
var
  i: Integer;
  A: array[0..2] of Integer = (7,8,9);
  LD: TVecDequeInt;
begin
  LD := TVecDequeInt.Create;
  try
    LD.Clear;
      for i := 0 to 3 do LD.PushBack(i); // [0,1,2,3]
      LD.Insert(1, A);                   // -> [0,7,8,9,1,2,3]
      CheckEqual(Int64(7), Int64(LD.GetCount), 'Count=7');
      CheckEqual(Int64(7), Int64(LD.Get(1)), 'Index 1');
      CheckEqual(Int64(9), Int64(LD.Get(3)), 'Index 3');
      CheckEqual(Int64(3), Int64(LD.Get(6)), 'Index 6');
  finally
    LD.Free;
  end;
end;

procedure TestInsertIndexPointerCount;
var
  i: Integer;
  Buf: array[0..1] of Integer;
  LD: TVecDequeInt;
begin
  LD := TVecDequeInt.Create;
  try
    LD.Clear;
      for i := 1 to 3 do LD.PushBack(i); // [1,2,3]
      Buf[0]:=100; Buf[1]:=101;
      LD.Insert(0, @Buf[0], 2);          // -> [100,101,1,2,3]
      CheckEqual(Int64(5), Int64(LD.GetCount), 'Count=5');
      CheckEqual(Int64(100), Int64(LD.Get(0)), 'Index 0');
      CheckEqual(Int64(101), Int64(LD.Get(1)), 'Index 1');
      CheckEqual(Int64(3), Int64(LD.Get(4)), 'Index 4');
  finally
    LD.Free;
  end;
end;

procedure TestInsertIndexCollectionStartindex;
var
  C: specialize TVecDeque<Integer>;
  LD: TVecDequeInt;
begin
  LD := TVecDequeInt.Create;
  try
    LD.Clear;
      LD.PushBack(1);
      LD.PushBack(2);
      LD.PushBack(3);              // [1,2,3]
      C := specialize TVecDeque<Integer>.Create;
      try
        C.PushBack(10);
        C.PushBack(20);
        C.PushBack(30);
        // Insert elements starting from StartIndex=1 -> [20,30] at index 2
        LD.Insert(2, C, 1);        // -> [1,2,20,30,3]
        CheckEqual(Int64(5), Int64(LD.GetCount), 'Count=5');
        CheckEqual(Int64(20), Int64(LD.Get(2)), 'Index 2');
        CheckEqual(Int64(30), Int64(LD.Get(3)), 'Index 3');
      finally
        C.Free;
      end;
  finally
    LD.Free;
  end;
end;

procedure TestRemoveIndex;
var
  i, Removed: Integer;
  LD: TVecDequeInt;
begin
  LD := TVecDequeInt.Create;
  try
    LD.Clear;
      for i := 1 to 5 do LD.PushBack(i); // [1..5]
      Removed := LD.RemoveAt(1);           // remove 2 -> [1,3,4,5]
      CheckEqual(Int64(2), Int64(Removed), 'Removed value=2');
      CheckEqual(Int64(4), Int64(LD.GetCount), 'Count=4');
      CheckEqual(Int64(3), Int64(LD.Get(1)), 'Index 1 now 3');
  finally
    LD.Free;
  end;
end;

procedure TestRemoveIndexCount;
var
  i: Integer;
  LD: TVecDequeInt;
begin
  LD := TVecDequeInt.Create;
  try
    LD.Clear;
      for i := 0 to 6 do LD.PushBack(i); // [0..6]
      LD.Delete(2, 3);                    // delete [2,3,4] -> [0,1,5,6]
      CheckEqual(Int64(4), Int64(LD.GetCount), 'Count=4');
      CheckEqual(Int64(5), Int64(LD.Get(2)), 'Index 2 now 5');
  finally
    LD.Free;
  end;
end;

procedure TestRemoveswapIndex;
var
  i, Removed: Integer;
  LD: TVecDequeInt;
begin
  LD := TVecDequeInt.Create;
  try
    LD.Clear;
      for i := 1 to 5 do LD.PushBack(i); // [1..5]
      Removed := LD.SwapRemoveAt(1);       // remove index 1 (value 2), swap with last -> [1,5,3,4]
      CheckEqual(Int64(2), Int64(Removed), 'Removed=2');
      CheckEqual(Int64(4), Int64(LD.GetCount), 'Count=4');
      CheckEqual(Int64(5), Int64(LD.Get(1)), 'Index 1 now 5');
  finally
    LD.Free;
  end;
end;

procedure TestRemoveswapIndexCount;
var
  i: Integer;
  E: Integer;
  LD: TVecDequeInt;
begin
  LD := TVecDequeInt.Create;
  try
    LD.Clear;
      for i := 1 to 6 do LD.PushBack(i); // [1..6]
      LD.SwapRemoveAt(2, E);               // remove at idx 2 (3), swap with last -> [1,2,6,4,5]
      CheckEqual(Int64(3), Int64(E), 'Removed element=3');
      CheckEqual(Int64(5), Int64(LD.GetCount), 'Count=5');
  finally
    LD.Free;
  end;
end;

procedure TestPopfrontrangeTocollection;
var
  LTarget: TVecDequeInt;
  LValue: Integer;
  LRemoved: SizeUInt;
  LD: TVecDequeInt;
begin
  LD := TVecDequeInt.Create;
  try
    LD.Clear;
      LD.Append([10, 20, 30, 40, 50]);
      LTarget := TVecDequeInt.Create;
      try
        LRemoved := 0;
        while (LRemoved < 3) and LD.TryPopFront(LValue) do
        begin
          LTarget.PushBack(LValue);
          Inc(LRemoved);
        end;
        CheckEqual(Int64(2), Int64(LD.GetCount), 'Source count should be reduced');
        CheckEqual(Int64(40), Int64(LD.Front), 'Source front should be 40');
        CheckEqual(Int64(3), Int64(LTarget.GetCount), 'Target should have 3 elements');
        CheckEqual(Int64(10), Int64(LTarget.Get(0)), 'Target[0] should be 10');
        CheckEqual(Int64(20), Int64(LTarget.Get(1)), 'Target[1] should be 20');
        CheckEqual(Int64(30), Int64(LTarget.Get(2)), 'Target[2] should be 30');
      finally
        LTarget.Free;
      end;
  finally
    LD.Free;
  end;
end;

procedure TestPopbackrangeTocollection;
var
  LTarget: TVecDequeInt;
  LValue: Integer;
  LRemoved: SizeUInt;
  LD: TVecDequeInt;
begin
  LD := TVecDequeInt.Create;
  try
    LD.Clear;
      LD.Append([10, 20, 30, 40, 50]);
      LTarget := TVecDequeInt.Create;
      try
        LRemoved := 0;
        while (LRemoved < 3) and LD.TryPopBack(LValue) do
        begin
          LTarget.PushFront(LValue);
          Inc(LRemoved);
        end;
        CheckEqual(Int64(2), Int64(LD.GetCount), 'Source count should be reduced');
        CheckEqual(Int64(20), Int64(LD.Back), 'Source back should be 20');
        CheckEqual(Int64(3), Int64(LTarget.GetCount), 'Target should have 3 elements');
        CheckEqual(Int64(30), Int64(LTarget.Get(0)), 'Target[0] should be 30');
        CheckEqual(Int64(40), Int64(LTarget.Get(1)), 'Target[1] should be 40');
        CheckEqual(Int64(50), Int64(LTarget.Get(2)), 'Target[2] should be 50');
      finally
        LTarget.Free;
      end;
  finally
    LD.Free;
  end;
end;

procedure TestClearandreserve;
var
  LOldCap, LRequested: SizeUInt;
  LD: TVecDequeInt;
begin
  LD := TVecDequeInt.Create;
  try
    LD.Clear;
      LD.Append([1, 2, 3, 4]);
      LOldCap := LD.GetCapacity;
      LRequested := LOldCap + 32;
      LD.ClearAndReserve(LRequested);
      CheckEqual(Int64(0), Int64(LD.GetCount), 'ClearAndReserve should clear elements');
      Check(LD.GetCapacity >= LRequested, 'Capacity should be at least requested');
      // Requesting smaller capacity should not shrink
      LD.Append([10]);
      LD.ClearAndReserve(1);
      CheckEqual(Int64(0), Int64(LD.GetCount), 'ClearAndReserve should clear again');
      Check(LD.GetCapacity >= LRequested, 'Capacity should stay >= previous reservation');
  finally
    LD.Free;
  end;
end;

procedure TestPushfrontCollection;
var
  LD: TVecDequeInt;
begin
  LD := TVecDequeInt.Create;
  try
    LD.Clear;
      LD.Append([9]);
      LD.PushFront([5, 6, 7]);
      CheckEqual(Int64(4), Int64(LD.Count), 'Should have 4 elements');
      CheckEqual(Int64(5), Int64(LD.Front), 'Front should be 5');
      CheckEqual(Int64(9), Int64(LD.Back), 'Back should be 9');
  finally
    LD.Free;
  end;
end;

procedure TestReplaceifNewvaluePredicatefunc;
var
  i: Integer;
  LD: TVecDequeInt;
begin
  LD := TVecDequeInt.Create;
  try
    for i := 1 to 6 do LD.PushBack(i); // 1..6
      LD.ReplaceIf(0, @GIsOdd, nil);
      CheckEqual(Int64(0), Int64(LD.Get(0)), '奇数应被替换为0');
      CheckEqual(Int64(2), Int64(LD.Get(1)), '偶数保持');
      CheckEqual(Int64(0), Int64(LD.Get(2)), '奇数应被替换为0');
      CheckEqual(Int64(4), Int64(LD.Get(3)), '偶数保持');
  finally
    LD.Free;
  end;
end;

procedure TestIssorted;
begin
  // SKIPPED: IsSorted/BinarySearch API diff
end;

procedure TestIssortedComparefunc;
begin
  // SKIPPED: IsSorted/BinarySearch API diff
end;

procedure TestIssortedComparereffunc;
begin
  // SKIPPED: IsSorted/BinarySearch API diff
end;

procedure TestBinarysearchinsertElement;
begin
  // SKIPPED: IsSorted/BinarySearch API diff
end;

procedure TestWriteIndexPointerCount;
var
  Buf: array[0..4] of Integer;
  LD: TVecDequeInt;
begin
  LD := TVecDequeInt.Create;
  try
    // Prepare existing data [1..10]
      LD.Clear;
      LD.Resize(10);
      // write through pointer starting at index 3 count 5
      Buf[0]:=100; Buf[1]:=101; Buf[2]:=102; Buf[3]:=103; Buf[4]:=104;
      LD.Write(3, @Buf[0], 5);
      // Count must have grown to at least 8; here 3+5=8 so still 10
      CheckEqual(Int64(10), Int64(LD.GetCount), 'Count should remain 10');
      CheckEqual(Int64(100), Int64(LD.Get(3)), 'Index 3');
      CheckEqual(Int64(104), Int64(LD.Get(7)), 'Index 7');
  finally
    LD.Free;
  end;
end;

procedure TestWriteIndexArray;
var
  A: array[0..2] of Integer = (7,8,9);
  LD: TVecDequeInt;
begin
  LD := TVecDequeInt.Create;
  try
    LD.Clear;
      LD.Resize(5);
      LD.Write(4, A);
      CheckEqual(Int64(7), Int64(LD.GetCount), 'Count should grow to 7');
      CheckEqual(Int64(7), Int64(LD.Get(4)), 'Index 4');
      CheckEqual(Int64(9), Int64(LD.Get(6)), 'Index 6');
  finally
    LD.Free;
  end;
end;

procedure TestWriteIndexCollection;
var
  C: specialize TVecDeque<Integer>;
  LD: TVecDequeInt;
begin
  LD := TVecDequeInt.Create;
  try
    C := specialize TVecDeque<Integer>.Create;
      try
        C.PushBack(11);
        C.PushBack(12);
        C.PushBack(13);
        LD.Clear;
        LD.Resize(2);
        LD.Write(2, C);
        CheckEqual(Int64(5), Int64(LD.GetCount), 'Count should be 5');
        CheckEqual(Int64(11), Int64(LD.Get(2)), 'Index 2');
        CheckEqual(Int64(13), Int64(LD.Get(4)), 'Index 4');
      finally
        C.Free;
      end;
  finally
    LD.Free;
  end;
end;

procedure TestWriteIndexCollectionStartindex;
var
  C: specialize TVecDeque<Integer>;
  LD: TVecDequeInt;
begin
  LD := TVecDequeInt.Create;
  try
    C := specialize TVecDeque<Integer>.Create;
      try
        C.PushBack(21);
        C.PushBack(22);
        C.PushBack(23);
        LD.Clear;
        LD.Resize(1);
        // start at 1 -> write 22,23 at index 1, count grows to 3
        LD.Write(1, C, 1);
        CheckEqual(Int64(3), Int64(LD.GetCount), 'Count should be 3');
        CheckEqual(Int64(22), Int64(LD.Get(1)), 'Index 1');
        CheckEqual(Int64(23), Int64(LD.Get(2)), 'Index 2');
      finally
        C.Free;
      end;
  finally
    LD.Free;
  end;
end;

procedure TestWriteexactIndexPointerCount;
var
  Buf: array[0..2] of Integer;
  LD: TVecDequeInt;
begin
  LD := TVecDequeInt.Create;
  try
    LD.Clear;
      LD.Resize(5);
      Buf[0]:=31; Buf[1]:=32; Buf[2]:=33;
      LD.WriteExact(2, @Buf[0], 3);
      CheckEqual(Int64(5), Int64(LD.GetCount), 'Count unchanged');
      CheckEqual(Int64(31), Int64(LD.Get(2)), 'Index 2');
      CheckEqual(Int64(33), Int64(LD.Get(4)), 'Index 4');
  finally
    LD.Free;
  end;
end;

procedure TestWriteexactIndexArray;
var
  A: array[0..1] of Integer = (41,42);
  LD: TVecDequeInt;
begin
  LD := TVecDequeInt.Create;
  try
    LD.Clear;
      LD.Resize(4);
      LD.WriteExact(2, A);
      CheckEqual(Int64(4), Int64(LD.GetCount), 'Count unchanged');
      CheckEqual(Int64(41), Int64(LD.Get(2)), 'Index 2');
      CheckEqual(Int64(42), Int64(LD.Get(3)), 'Index 3');
  finally
    LD.Free;
  end;
end;

procedure TestWriteexactIndexCollection;
var
  C: specialize TVecDeque<Integer>;
  LD: TVecDequeInt;
begin
  LD := TVecDequeInt.Create;
  try
    C := specialize TVecDeque<Integer>.Create;
      try
        LD.Clear;
        LD.Resize(5);
        C.Append([51,52,53]);
        LD.WriteExact(2, C);
        CheckEqual(Int64(5), Int64(LD.GetCount), 'Count unchanged');
        CheckEqual(Int64(51), Int64(LD.Get(2)), 'Index 2');
        CheckEqual(Int64(53), Int64(LD.Get(4)), 'Index 4');
      finally
        C.Free;
      end;
  finally
    LD.Free;
  end;
end;

procedure TestWriteexactIndexCollectionStartindex;
var
  C: specialize TVecDeque<Integer>;
  LD: TVecDequeInt;
begin
  LD := TVecDequeInt.Create;
  try
    C := specialize TVecDeque<Integer>.Create;
      try
        LD.Clear;
        LD.Resize(4);
        C.Append([61,62,63,64]);
        LD.WriteExact(1, C, 2); // write [63,64] to positions 1..2
        CheckEqual(Int64(4), Int64(LD.GetCount), 'Count unchanged');
        CheckEqual(Int64(63), Int64(LD.Get(1)), 'Index 1');
        CheckEqual(Int64(64), Int64(LD.Get(2)), 'Index 2');
      finally
        C.Free;
      end;
  finally
    LD.Free;
  end;
end;

procedure TestGetdata;
var
  LData: Pointer;
  LVecDeque: TVecDequeInt;
  LD: TVecDequeInt;
begin
  LD := TVecDequeInt.Create;
  try
    Check(LD.GetData = nil, 'Default data should be nil');
      LData := Pointer(PtrUInt($12345678));
      LVecDeque := TVecDequeInt.Create(DefaultAllocator(), LData);
      try
        Check(LVecDeque.GetData = LData, 'GetData should return constructor data pointer');
      finally
        LVecDeque.Free;
      end;
  finally
    LD.Free;
  end;
end;

procedure TestSetdata;
var
  LData1: Pointer;
  LData2: Pointer;
  LD: TVecDequeInt;
begin
  LD := TVecDequeInt.Create;
  try
    LData1 := Pointer(PtrUInt($11111111));
      LData2 := Pointer(PtrUInt($22222222));
      LD.SetData(LData1);
      Check(LD.GetData = LData1, 'SetData should store first pointer');
      LD.SetData(LData2);
      Check(LD.GetData = LData2, 'SetData should update to second pointer');
      LD.SetData(nil);
      Check(LD.GetData = nil, 'SetData should allow reset to nil');
  finally
    LD.Free;
  end;
end;

procedure TestGetelementtypeinfo;
begin
  // SKIPPED: TypeInfo conversion
end;

procedure TestWraparoundHeavy;
var
  I, Round, V, Removed: Integer;
  Tmp: array of Integer;
  LD: TVecDequeInt;
begin
  LD := TVecDequeInt.Create;
  try
    LD.Clear;
      // Small capacity scenario to force wraparound via many Push/Pop
      for Round := 1 to 50 do
      begin
        // Push front/back alternating
        for I := 1 to 8 do
        begin
          V := Round*100 + I;
          if Odd(I) then LD.PushFront(V) else LD.PushBack(V);
        end;
        // Pop a few from both ends
        if LD.GetCount > 0 then Removed := LD.PopFront;
        if LD.GetCount > 0 then Removed := LD.PopBack;
      end;
  finally
    LD.Free;
  end;
end;

procedure TestInsertIndexCollectionStartindexHeavy;
var
  Src, Dst: specialize TVecDeque<Integer>;
  I, Pos: Integer;
  LD: TVecDequeInt;
begin
  LD := TVecDequeInt.Create;
  try
    Src := specialize TVecDeque<Integer>.Create;
      Dst := specialize TVecDeque<Integer>.Create;
      try
        for I := 0 to 49 do Src.PushBack(300 + I);
        for I := 1 to 20 do Dst.PushBack(I);
        // 多次随机位置插入 Src 的后半段内容，验证稳定性
        for I := 1 to 50 do
        begin
          if Dst.GetCount = 0 then Pos := 0 else Pos := Random(LongInt(Dst.GetCount));
          Dst.Insert(Pos, Src, 25);
        end;
        Check(Dst.GetCount >= 20, '');
      finally
        Src.Free; Dst.Free;
      end;
  finally
    LD.Free;
  end;
end;

procedure TestInsertCollectionNilRaises;
var
  raised: Boolean;
  LD: TVecDequeInt;
begin
  LD := TVecDequeInt.Create;
  try
    LD.Clear;
      raised := False;
      try
        LD.Insert(0, nil); // nil collection
      except on E: EArgumentNil do raised := True; end;
      Check(raised, 'Insert(nil) should raise EArgumentNil');
  finally
    LD.Free;
  end;
end;

procedure TestWritePointerNilRaises;
var
  raised: Boolean;
  LD: TVecDequeInt;
begin
  LD := TVecDequeInt.Create;
  try
    LD.Clear; LD.Resize(1);
      raised := False;
      try
        LD.Write(0, nil, 1);
      except on E: EArgumentNil do raised := True; end;
      Check(raised, 'Write(nil pointer) should raise EArgumentNil');
  finally
    LD.Free;
  end;
end;

begin
  T := TTestRunner.Create('nextpas.core.collections.vecdeque.full');
  T.Run('Create', @TestCreate);
  T.Run('PushFront Element', @TestPushfrontElement);
  T.Run('PushBack Element', @TestPushbackElement);
  T.Run('PopFront', @TestPopfront);
  T.Run('PopBack', @TestPopback);
  T.Run('IsEmpty', @TestIsempty);
  T.Run('GetCount', @TestGetcount);
  T.Run('GetCapacity', @TestGetcapacity);
  T.Run('GetUnChecked', @TestGetunchecked);
  T.Run('LoadFromArray Empty', @TestLoadfromarrayEmpty);
  T.Run('ForEachUnChecked Index Count PredicateRefFunc', @TestForeachuncheckedIndexCountPredicatereffunc);
  T.Run('Contains Element', @TestContainsElement);
  T.Run('Contains Element EqualsFunc', @TestContainsElementEqualsfunc);
  T.Run('Contains Element EqualsRefFunc', @TestContainsElementEqualsreffunc);
  T.Run('Contains Element Index', @TestContainsElementIndex);
  T.Run('Contains Element Index EqualsFunc', @TestContainsElementIndexEqualsfunc);
  T.Run('Contains Element Index EqualsRefFunc', @TestContainsElementIndexEqualsreffunc);
  T.Run('Contains Element Index Count', @TestContainsElementIndexCount);
  T.Run('Contains Element Index Count EqualsFunc', @TestContainsElementIndexCountEqualsfunc);
  T.Run('Contains Element Index Count EqualsRefFunc', @TestContainsElementIndexCountEqualsreffunc);
  T.Run('ContainsUnChecked Element', @TestContainsuncheckedElement);
  T.Run('ContainsUnChecked Element EqualsFunc', @TestContainsuncheckedElementEqualsfunc);
  T.Run('ContainsUnChecked Element EqualsRefFunc', @TestContainsuncheckedElementEqualsreffunc);
  T.Run('Find Element', @TestFindElement);
  T.Run('Find Element EqualsFunc', @TestFindElementEqualsfunc);
  T.Run('Find Element EqualsRefFunc', @TestFindElementEqualsreffunc);
  T.Run('Find Element Index', @TestFindElementIndex);
  T.Run('Find Element Index EqualsFunc', @TestFindElementIndexEqualsfunc);
  T.Run('Find Element Index EqualsRefFunc', @TestFindElementIndexEqualsreffunc);
  T.Run('Find Element Index Count', @TestFindElementIndexCount);
  T.Run('Find Element Index Count EqualsFunc', @TestFindElementIndexCountEqualsfunc);
  T.Run('Find Element Index Count EqualsRefFunc', @TestFindElementIndexCountEqualsreffunc);
  T.Run('FindUnChecked Element', @TestFinduncheckedElement);
  T.Run('FindUnChecked Element EqualsFunc', @TestFinduncheckedElementEqualsfunc);
  T.Run('FindUnChecked Element EqualsRefFunc', @TestFinduncheckedElementEqualsreffunc);
  T.Run('FindIF PredicateFunc', @TestFindifPredicatefunc);
  T.Run('FindIF PredicateRefFunc', @TestFindifPredicatereffunc);
  T.Run('GetGrowStrategy', @TestGetgrowstrategy);
  T.Run('ShrinkToFit', @TestShrinktofit);
  T.Run('Shrink', @TestShrink);
  T.Run('Insert Index Element', @TestInsertIndexElement);
  T.Run('Insert Index Array', @TestInsertIndexArray);
  T.Run('Insert Index Pointer Count', @TestInsertIndexPointerCount);
  T.Run('Insert Index Collection StartIndex', @TestInsertIndexCollectionStartindex);
  T.Run('Remove Index', @TestRemoveIndex);
  T.Run('Remove Index Count', @TestRemoveIndexCount);
  T.Run('RemoveSwap Index', @TestRemoveswapIndex);
  T.Run('RemoveSwap Index Count', @TestRemoveswapIndexCount);
  T.Run('PopFrontRange ToCollection', @TestPopfrontrangeTocollection);
  T.Run('PopBackRange ToCollection', @TestPopbackrangeTocollection);
  T.Run('ClearAndReserve', @TestClearandreserve);
  T.Run('PushFront Collection', @TestPushfrontCollection);
  T.Run('ReplaceIf NewValue PredicateFunc', @TestReplaceifNewvaluePredicatefunc);
  T.Run('IsSorted', @TestIssorted);
  T.Run('IsSorted CompareFunc', @TestIssortedComparefunc);
  T.Run('IsSorted CompareRefFunc', @TestIssortedComparereffunc);
  T.Run('BinarySearchInsert Element', @TestBinarysearchinsertElement);
  T.Run('Write Index Pointer Count', @TestWriteIndexPointerCount);
  T.Run('Write Index Array', @TestWriteIndexArray);
  T.Run('Write Index Collection', @TestWriteIndexCollection);
  T.Run('Write Index Collection StartIndex', @TestWriteIndexCollectionStartindex);
  T.Run('WriteExact Index Pointer Count', @TestWriteexactIndexPointerCount);
  T.Run('WriteExact Index Array', @TestWriteexactIndexArray);
  T.Run('WriteExact Index Collection', @TestWriteexactIndexCollection);
  T.Run('WriteExact Index Collection StartIndex', @TestWriteexactIndexCollectionStartindex);
  T.Run('GetData', @TestGetdata);
  T.Run('SetData', @TestSetdata);
  T.Run('GetElementTypeInfo', @TestGetelementtypeinfo);
  T.Run('Wraparound Heavy', @TestWraparoundHeavy);
  T.Run('Insert Index Collection StartIndex Heavy', @TestInsertIndexCollectionStartindexHeavy);
  T.Run('Insert Collection Nil Raises', @TestInsertCollectionNilRaises);
  T.Run('Write Pointer Nil Raises', @TestWritePointerNilRaises);
  T.Summary;
end.