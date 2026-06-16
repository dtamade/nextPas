program test_list;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.testing,
  nextpas.core.mem.intf,
  failing_allocator,
  nextpas.core.collections,
  nextpas.core.collections.base,
  nextpas.core.collections.list,
  nextpas.core.collections.list.intf;

type
  IIntList = specialize IList<Integer>;
  TIntList = specialize TList<Integer>;
  TManagedRecord = record
    Initialized: Boolean;
    Id: Int32;
    class operator Initialize(var ARecord: TManagedRecord);
    class operator Finalize(var ARecord: TManagedRecord);
  end;
  TManagedRecordList = specialize TList<TManagedRecord>;

var
  T: TTestRunner;
  GManagedRecordAlive: Int32 = 0;
  GManagedRecordBadFinalize: Int32 = 0;

class operator TManagedRecord.Initialize(var ARecord: TManagedRecord);
begin
  ARecord.Initialized := True;
  ARecord.Id := 0;
  Inc(GManagedRecordAlive);
end;

class operator TManagedRecord.Finalize(var ARecord: TManagedRecord);
begin
  if not ARecord.Initialized then
    Inc(GManagedRecordBadFinalize)
  else
  begin
    ARecord.Initialized := False;
    Dec(GManagedRecordAlive);
  end;
end;

function MakeManagedRecord(AId: Int32): TManagedRecord;
begin
  Result.Id := AId;
end;

procedure TestPushFrontPopFront;
var
  LL: IIntList;
begin
  LL := specialize MakeList<Integer>;
  LL.PushFront(1);
  LL.PushFront(2);
  LL.PushFront(3);
  CheckEqual(Int64(3), Int64(LL.GetCount), 'count');
  CheckEqual(Int64(3), Int64(LL.PopFront), 'pop front LIFO');
  CheckEqual(Int64(2), Int64(LL.PopFront), 'pop front 2');
  CheckEqual(Int64(1), Int64(LL.PopFront), 'pop front 3');
  Check(LL.IsEmpty, 'empty after all pops');
end;

procedure TestPushBackPopBack;
var
  LL: IIntList;
begin
  LL := specialize MakeList<Integer>;
  LL.PushBack(10);
  LL.PushBack(20);
  LL.PushBack(30);
  CheckEqual(Int64(30), Int64(LL.PopBack), 'pop back LIFO');
  CheckEqual(Int64(20), Int64(LL.PopBack), 'pop back 2');
  CheckEqual(Int64(10), Int64(LL.PopBack), 'pop back 3');
end;

procedure TestFrontBack;
var
  LL: IIntList;
begin
  LL := specialize MakeList<Integer>;
  LL.PushBack(1);
  LL.PushBack(2);
  LL.PushBack(3);
  CheckEqual(Int64(1), Int64(LL.Front), 'front');
  CheckEqual(Int64(3), Int64(LL.Back), 'back');
  CheckEqual(Int64(3), Int64(LL.GetCount), 'front/back do not remove');
end;

procedure TestTryFrontTryBack;
var
  LL: IIntList;
  LVal: Integer;
begin
  LL := specialize MakeList<Integer>;
  Check(not LL.TryFront(LVal), 'try front on empty');
  Check(not LL.TryBack(LVal), 'try back on empty');
  LL.PushBack(42);
  Check(LL.TryFront(LVal), 'try front succeeds');
  CheckEqual(Int64(42), Int64(LVal), 'try front value');
  Check(LL.TryBack(LVal), 'try back succeeds');
  CheckEqual(Int64(42), Int64(LVal), 'try back value');
end;

procedure TestTryPopFrontTryPopBack;
var
  LL: IIntList;
  LVal: Integer;
begin
  LL := specialize MakeList<Integer>;
  Check(not LL.TryPopFront(LVal), 'try pop front on empty');
  Check(not LL.TryPopBack(LVal), 'try pop back on empty');
  LL.PushBack(10);
  LL.PushBack(20);
  Check(LL.TryPopFront(LVal), 'try pop front');
  CheckEqual(Int64(10), Int64(LVal), 'pop front value');
  Check(LL.TryPopBack(LVal), 'try pop back');
  CheckEqual(Int64(20), Int64(LVal), 'pop back value');
  Check(LL.IsEmpty, 'empty');
end;

procedure TestMixedPushPop;
var
  LL: IIntList;
begin
  LL := specialize MakeList<Integer>;
  LL.PushFront(2);
  LL.PushBack(3);
  LL.PushFront(1);
  LL.PushBack(4);
  CheckEqual(Int64(4), Int64(LL.GetCount), 'count');
  CheckEqual(Int64(1), Int64(LL.Front), 'front is 1');
  CheckEqual(Int64(4), Int64(LL.Back), 'back is 4');
  CheckEqual(Int64(1), Int64(LL.PopFront), 'pop 1');
  CheckEqual(Int64(4), Int64(LL.PopBack), 'pop 4');
  CheckEqual(Int64(2), Int64(LL.PopFront), 'pop 2');
  CheckEqual(Int64(3), Int64(LL.PopBack), 'pop 3');
end;

procedure TestClear;
var
  LL: IIntList;
begin
  LL := specialize MakeList<Integer>;
  LL.PushBack(1);
  LL.PushBack(2);
  LL.PushBack(3);
  LL.Clear;
  Check(LL.IsEmpty, 'empty after clear');
  CheckEqual(Int64(0), Int64(LL.GetCount), 'count 0');
end;

procedure TestStringType;
var
  LS: specialize IList<string>;
  LVal: string;
begin
  LS := specialize MakeList<string>;
  LS.PushBack('hello');
  LS.PushBack('world');
  CheckEqual(Int64(2), Int64(LS.GetCount), 'string list count');
  Check(LS.TryPopFront(LVal), 'pop string');
  CheckEqual('hello', LVal, 'string value');
end;

procedure TestManagedZeroReinitializesSlots;
var
  LL: TManagedRecordList;
begin
  GManagedRecordAlive := 0;
  GManagedRecordBadFinalize := 0;
  LL := TManagedRecordList.Create;
  try
    LL.PushBack(MakeManagedRecord(10));
    LL.PushBack(MakeManagedRecord(20));
    CheckEqual(Int64(2), Int64(GManagedRecordAlive), 'records alive after push');

    LL.Zero;
    CheckEqual(Int64(2), Int64(GManagedRecordAlive), 'zero reinitializes managed slots');
    CheckEqual(Int64(0), Int64(GManagedRecordBadFinalize), 'zero does not finalize uninitialized slots');

    LL.Clear;
    CheckEqual(Int64(0), Int64(GManagedRecordAlive), 'clear releases zeroed records once');
    CheckEqual(Int64(0), Int64(GManagedRecordBadFinalize), 'clear does not double-finalize zeroed records');
  finally
    LL.Free;
  end;
  CheckEqual(Int64(0), Int64(GManagedRecordAlive), 'records released after list free');
  CheckEqual(Int64(0), Int64(GManagedRecordBadFinalize), 'no bad finalize after list free');
end;

procedure TestTryLoadFromTryAppend;
var
  LL: IIntList;
  LSrc: specialize IList<Integer>;
begin
  LL := specialize MakeList<Integer>;
  LSrc := specialize MakeList<Integer>;
  LSrc.PushBack(10);
  LSrc.PushBack(20);
  LSrc.PushBack(30);
  Check(LL.TryLoadFrom(LSrc as TCollection), 'try load from');
  CheckEqual(Int64(3), Int64(LL.GetCount), 'loaded count');

  LSrc.Clear;
  LSrc.PushBack(40);
  LSrc.PushBack(50);
  Check(LL.TryAppend(LSrc as TCollection), 'try append');
  CheckEqual(Int64(5), Int64(LL.GetCount), 'appended count');
end;

procedure TestSerializeNilPositiveCountRaises;
var
  LL: TIntList;
  LRaised: Boolean;
begin
  LL := TIntList.Create;
  try
    LL.PushBack(10);

    LRaised := False;
    try
      LL.SerializeToArrayBuffer(nil, 1);
    except
      on E: EArgumentNil do
        LRaised := True;
    end;
    Check(LRaised, 'serialize nil destination raises');
  finally
    LL.Free;
  end;
end;

procedure TestSerializeCountPastEndRaises;
var
  LL: TIntList;
  LOut: Integer;
  LRaised: Boolean;
begin
  LL := TIntList.Create;
  try
    LL.PushBack(10);
    LRaised := False;
    try
      LL.SerializeToArrayBuffer(@LOut, 2);
    except
      on E: EOutOfRange do
        LRaised := True;
    end;
    Check(LRaised, 'serialize count past end raises');
  finally
    LL.Free;
  end;
end;

procedure TestPushBackBlockRegistryAllocationFailureIsAtomic;
var
  LL: TIntList;
  LAllocator: IAllocator;
  LAlloc: TFailingAllocatorSnapshot;
  LCaught: Boolean;
begin
  LAllocator := MakeFailingAllocator(2);
  LL := TIntList.Create(LAllocator);
  try
    LCaught := False;
    try
      LL.PushBack(10);
    except
      on E: EOutOfMemoryError do
        LCaught := True;
    end;

    Check(LCaught, 'node block registry allocation failure raises canonical OOM');
    CheckEqual(Int64(0), Int64(LL.GetCount), 'failed push keeps count unchanged');
    LAlloc := FailingAllocatorSnapshot;
    CheckEqual(Int64(2), Int64(LAlloc.GetMemCalls), 'failure happened on second GetMem');
    CheckEqual(Int64(1), Int64(LAlloc.FreeMemCalls), 'allocated node block released after registry failure');
  finally
    LL.Free;
  end;
end;

begin
  T := TTestRunner.Create('nextpas.core.collections.list');
  T.Run('PushFront/PopFront', @TestPushFrontPopFront);
  T.Run('PushBack/PopBack', @TestPushBackPopBack);
  T.Run('Front/Back', @TestFrontBack);
  T.Run('TryFront/TryBack', @TestTryFrontTryBack);
  T.Run('TryPopFront/TryPopBack', @TestTryPopFrontTryPopBack);
  T.Run('Mixed Push/Pop', @TestMixedPushPop);
  T.Run('Clear', @TestClear);
  T.Run('String type (leak check)', @TestStringType);
  T.Run('Managed Zero reinitializes slots', @TestManagedZeroReinitializesSlots);
  T.Run('TryLoadFrom/TryAppend', @TestTryLoadFromTryAppend);
  T.Run('SerializeToArrayBuffer nil positive count raises', @TestSerializeNilPositiveCountRaises);
  T.Run('SerializeToArrayBuffer count past end raises', @TestSerializeCountPastEndRaises);
  T.Run('PushBack block registry allocation failure is atomic', @TestPushBackBlockRegistryAllocationFailureIsAtomic);
  T.Summary;
end.
