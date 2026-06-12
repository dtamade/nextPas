program test_swisstable;

{$I nextpas.core.settings.inc}
{$modeswitch advancedrecords}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.collections.hashmap.swiss,
  nextpas.core.collections.hashmap.swiss.str;

type
  TIntSwiss = specialize TSwissTable<Integer, Integer>;
  TStrSwiss = specialize TSwissTable<string, Integer>;
  TStringKeySwiss = specialize TSwissTableStr<Integer>;
  TManagedRecord = record
    Initialized: Boolean;
    Id: Int32;
    Payload: string;
    class operator Initialize(var ARecord: TManagedRecord);
    class operator Finalize(var ARecord: TManagedRecord);
  end;
  TManagedRecordSwiss = specialize TSwissTable<TManagedRecord, TManagedRecord>;

var
  T: TTestRunner;
  GManagedRecordAlive: Int32 = 0;
  GManagedRecordBadFinalize: Int32 = 0;
  GManagedRecordDrainVisits: Int32 = 0;

class operator TManagedRecord.Initialize(var ARecord: TManagedRecord);
begin
  ARecord.Initialized := True;
  ARecord.Id := 0;
  ARecord.Payload := '';
  Inc(GManagedRecordAlive);
end;

class operator TManagedRecord.Finalize(var ARecord: TManagedRecord);
begin
  if not ARecord.Initialized then
    Inc(GManagedRecordBadFinalize)
  else
  begin
    ARecord.Initialized := False;
    ARecord.Payload := '';
    Dec(GManagedRecordAlive);
  end;
end;

function HashFirstSwissGroup(const AKey: Integer): UInt32;
begin
  Result := UInt32(AKey and $7F);
end;

function EqualInteger(const L, R: Integer): Boolean;
begin
  Result := L = R;
end;

function MakeManagedRecord(AId: Int32): TManagedRecord;
begin
  Result.Id := AId;
  Result.Payload := 'managed-' + IntToStr(AId);
end;

function HashManagedRecord(const AKey: TManagedRecord): UInt32;
begin
  Result := InlineHashMix32(UInt32(AKey.Id));
end;

function EqualManagedRecord(const L, R: TManagedRecord): Boolean;
begin
  Result := L.Id = R.Id;
end;

function KeepManagedRecordOdd(const AKey: TManagedRecord; const AValue: TManagedRecord): Boolean;
begin
  Result := (AKey.Id mod 2) = 1;
end;

procedure VisitManagedRecord(const AKey: TManagedRecord; const AValue: TManagedRecord);
begin
  Inc(GManagedRecordDrainVisits);
end;

procedure ResetManagedRecordCounters;
begin
  GManagedRecordAlive := 0;
  GManagedRecordBadFinalize := 0;
  GManagedRecordDrainVisits := 0;
end;

procedure TestPutGet;
var M: TIntSwiss; v: Integer;
begin
  M := TIntSwiss.Create;
  M.Put(1, 10); M.Put(2, 20); M.Put(3, 30);
  CheckEqual(Int64(3), Int64(M.Count), 'count');
  Check(M.TryGetValue(1, v), 'get 1'); CheckEqual(Int64(10), Int64(v), 'val 1');
  Check(M.TryGetValue(2, v), 'get 2'); CheckEqual(Int64(20), Int64(v), 'val 2');
  Check(M.TryGetValue(3, v), 'get 3'); CheckEqual(Int64(30), Int64(v), 'val 3');
  Check(not M.TryGetValue(99, v), 'miss');
  M.Free;
end;

procedure TestUpdate;
var M: TIntSwiss; v: Integer;
begin
  M := TIntSwiss.Create;
  M.Put(1, 10);
  M.Put(1, 99);
  CheckEqual(Int64(1), Int64(M.Count), 'count after update');
  Check(M.TryGetValue(1, v), 'get'); CheckEqual(Int64(99), Int64(v), 'updated val');
  M.Free;
end;

procedure TestRemove;
var M: TIntSwiss;
begin
  M := TIntSwiss.Create;
  M.Put(1, 10); M.Put(2, 20); M.Put(3, 30);
  Check(M.Remove(2), 'remove 2');
  CheckEqual(Int64(2), Int64(M.Count), 'count after remove');
  Check(not M.ContainsKey(2), 'not contains 2');
  Check(M.ContainsKey(1), 'still contains 1');
  Check(M.ContainsKey(3), 'still contains 3');
  M.Free;
end;

procedure TestGrow;
var M: TIntSwiss; i, v: Integer; ok: Boolean;
begin
  M := TIntSwiss.Create;
  for i := 0 to 9999 do M.Put(i, i * 2);
  CheckEqual(Int64(10000), Int64(M.Count), 'count 10000');
  ok := True;
  for i := 0 to 9999 do
    if not M.TryGetValue(i, v) or (v <> i * 2) then ok := False;
  Check(ok, 'all values correct');
  M.Free;
end;

procedure TestRemoveReinsert;
var M: TIntSwiss; i, v: Integer;
begin
  M := TIntSwiss.Create;
  for i := 0 to 999 do M.Put(i, i);
  for i := 0 to 499 do M.Remove(i * 2);
  CheckEqual(Int64(500), Int64(M.Count), 'count after remove');
  for i := 0 to 499 do M.Put(i * 2, i * 2 + 1000);
  CheckEqual(Int64(1000), Int64(M.Count), 'count after reinsert');
  Check(M.TryGetValue(0, v), 'get 0'); CheckEqual(Int64(1000), Int64(v), 'reinserted val');
  M.Free;
end;

procedure TestDeletedSlotReuseKeepsStableCapacity;
var
  M: TIntSwiss;
  I: Integer;
  InitialCapacity: SizeUInt;
begin
  M := TIntSwiss.Create(GROUP_SIZE * 4, @HashFirstSwissGroup, @EqualInteger);
  try
    for I := 0 to GROUP_SIZE - 1 do
      M.Put(I, I);

    InitialCapacity := M.Capacity;

    for I := 1 to Integer(InitialCapacity) do
    begin
      Check(M.Remove(0), 'remove churn key');
      M.Put(0, I);
      CheckEqual(Int64(GROUP_SIZE), Int64(M.Count), 'stable count');
    end;

    CheckEqual(Int64(InitialCapacity), Int64(M.Capacity),
      'deleted slot reuse keeps capacity stable');
  finally
    M.Free;
  end;
end;

procedure TestGrowthBudgetExhaustionReusesBeforeGrow;
var
  M: TIntSwiss;
  I, V: Integer;
  InitialCapacity, GrowthLimit: SizeUInt;
begin
  M := TIntSwiss.Create(GROUP_SIZE * 4, @HashFirstSwissGroup, @EqualInteger);
  try
    InitialCapacity := M.Capacity;
    GrowthLimit := InitialCapacity - InitialCapacity div 8;

    for I := 0 to Integer(GrowthLimit) - 1 do
      M.Put(I, I);

    CheckEqual(Int64(GrowthLimit), Int64(M.Count), 'growth limit count');

    M.Put(0, -1);
    CheckEqual(Int64(InitialCapacity), Int64(M.Capacity),
      'update at growth limit keeps capacity');
    CheckEqual(Int64(GrowthLimit), Int64(M.Count),
      'update at growth limit keeps count');
    Check(M.TryGetValue(0, V), 'get updated key');
    CheckEqual(Int64(-1), Int64(V), 'updated value');

    Check(M.Remove(0), 'remove full-group key at growth limit');
    M.Put(0, -2);
    CheckEqual(Int64(InitialCapacity), Int64(M.Capacity),
      'deleted slot at growth limit keeps capacity');
    CheckEqual(Int64(GrowthLimit), Int64(M.Count),
      'deleted slot at growth limit keeps count');
    Check(M.TryGetValue(0, V), 'get reused deleted slot key');
    CheckEqual(Int64(-2), Int64(V), 'reused deleted slot value');
  finally
    M.Free;
  end;
end;

procedure TestStringKey;
var M: TStrSwiss; i, v: Integer; ok: Boolean;
begin
  M := TStrSwiss.Create;
  for i := 0 to 999 do M.Put('key' + IntToStr(i), i);
  CheckEqual(Int64(1000), Int64(M.Count), 'str count');
  ok := True;
  for i := 0 to 999 do
    if not M.TryGetValue('key' + IntToStr(i), v) or (v <> i) then ok := False;
  Check(ok, 'str values correct');
  Check(not M.ContainsKey('nope'), 'str miss');
  M.Remove('key500');
  CheckEqual(Int64(999), Int64(M.Count), 'str count after remove');
  M.Free;
end;

procedure TestStringSpecializedGrowthBudgetReusesBeforeGrow;
var
  M: TStringKeySwiss;
  I, V: Integer;
  InitialCapacity, GrowthLimit: SizeUInt;
begin
  M := TStringKeySwiss.Create(128);
  try
    InitialCapacity := M.Capacity;
    GrowthLimit := InitialCapacity - InitialCapacity div 8;

    for I := 0 to Integer(GrowthLimit) - 1 do
      M.Put('key' + IntToStr(I), I);

    CheckEqual(Int64(GrowthLimit), Int64(M.Count), 'string specialized growth limit count');

    M.Put('key0', -1);
    CheckEqual(Int64(InitialCapacity), Int64(M.Capacity),
      'string specialized update at growth limit keeps capacity');
    Check(M.TryGetValue('key0', V), 'string specialized get updated key');
    CheckEqual(Int64(-1), Int64(V), 'string specialized updated value');

    Check(M.Remove('key0'), 'string specialized remove full table key');
    M.Put('key0', -2);
    CheckEqual(Int64(InitialCapacity), Int64(M.Capacity),
      'string specialized deleted slot at growth limit keeps capacity');
    CheckEqual(Int64(GrowthLimit), Int64(M.Count),
      'string specialized deleted slot keeps count');
    Check(M.TryGetValue('key0', V), 'string specialized get reused key');
    CheckEqual(Int64(-2), Int64(V), 'string specialized reused value');
  finally
    M.Free;
  end;
end;

procedure TestClear;
var M: TIntSwiss;
begin
  M := TIntSwiss.Create;
  M.Put(1, 1); M.Put(2, 2);
  M.Clear;
  CheckEqual(Int64(0), Int64(M.Count), 'count after clear');
  Check(not M.ContainsKey(1), 'not contains after clear');
  M.Put(3, 3);
  CheckEqual(Int64(1), Int64(M.Count), 'usable after clear');
  M.Free;
end;

procedure TestPrealloc;
var M: TIntSwiss; i, v: Integer; ok: Boolean;
begin
  M := TIntSwiss.Create(10000);
  for i := 0 to 9999 do M.Put(i, i);
  CheckEqual(Int64(10000), Int64(M.Count), 'prealloc count');
  ok := True;
  for i := 0 to 9999 do
    if not M.TryGetValue(i, v) or (v <> i) then ok := False;
  Check(ok, 'prealloc values');
  M.Free;
end;

function KeepOdd(const AKey: Integer; const AValue: Integer): Boolean;
begin
  Result := (AKey mod 2) = 1;
end;

procedure TestRetain;
var M: TIntSwiss; i: Integer;
begin
  M := TIntSwiss.Create;
  for i := 0 to 99 do M.Put(i, i);
  M.Retain(@KeepOdd);
  CheckEqual(Int64(50), Int64(M.Count), 'retain count');
  Check(M.ContainsKey(1), 'has odd');
  Check(not M.ContainsKey(0), 'no even');
  M.Free;
end;

var GDrainSum: Int64;

procedure DrainVisit(const AKey: Integer; const AValue: Integer);
begin
  Inc(GDrainSum, AKey);
end;

procedure TestDrain;
var M: TIntSwiss;
begin
  M := TIntSwiss.Create;
  M.Put(1, 10); M.Put(2, 20); M.Put(3, 30);
  GDrainSum := 0;
  M.Drain(@DrainVisit);
  CheckEqual(Int64(6), GDrainSum, 'drain sum');
  CheckEqual(Int64(0), Int64(M.Count), 'empty after drain');
  M.Free;
end;

procedure TestReserve;
var M: TIntSwiss; i, v: Integer; ok: Boolean;
begin
  M := TIntSwiss.Create;
  M.Reserve(500);
  Check(M.Capacity >= 500, 'capacity after reserve');
  for i := 0 to 499 do M.Put(i, i);
  CheckEqual(Int64(500), Int64(M.Count), 'count');
  ok := True;
  for i := 0 to 499 do
    if not M.TryGetValue(i, v) or (v <> i) then ok := False;
  Check(ok, 'all values');
  M.Free;
end;

procedure TestForEachAndEnumerator;
var M: TIntSwiss; E: TIntSwiss.TSlot; sum: Int64; count: Integer;
begin
  M := TIntSwiss.Create;
  M.Put(1, 10); M.Put(2, 20); M.Put(3, 30);
  sum := 0; count := 0;
  for E in M do
  begin
    Inc(sum, E.Key);
    Inc(count);
  end;
  CheckEqual(Int64(3), Int64(count), 'enum count');
  CheckEqual(Int64(6), sum, 'enum sum');
  M.Free;
end;

procedure TestManagedRecordSlotCleanup;
var
  M: TManagedRecordSwiss;
  I: Integer;
begin
  ResetManagedRecordCounters;
  M := TManagedRecordSwiss.Create(0, @HashManagedRecord, @EqualManagedRecord);
  try
    for I := 0 to 31 do
      M.Put(MakeManagedRecord(I), MakeManagedRecord(I + 1000));

    Check(M.Remove(MakeManagedRecord(4)), 'managed record remove existing key');
    Check(not M.Remove(MakeManagedRecord(400)), 'managed record remove missing key');
    CheckEqual(Int64(0), Int64(GManagedRecordBadFinalize),
      'managed record remove does not finalize uninitialized slot bytes');

    M.Retain(@KeepManagedRecordOdd);
    CheckEqual(Int64(0), Int64(GManagedRecordBadFinalize),
      'managed record retain does not finalize uninitialized slot bytes');
    CheckEqual(Int64(16), Int64(M.Count), 'managed record retain count');

    GManagedRecordDrainVisits := 0;
    M.Drain(@VisitManagedRecord);
    CheckEqual(Int64(16), Int64(GManagedRecordDrainVisits),
      'managed record drain visits retained items');
    CheckEqual(Int64(0), Int64(GManagedRecordBadFinalize),
      'managed record drain does not finalize uninitialized slot bytes');
    CheckEqual(Int64(0), Int64(M.Count), 'managed record drain empties table');
  finally
    M.Free;
  end;

  CheckEqual(Int64(0), Int64(GManagedRecordAlive),
    'managed record remove/retain/drain releases all slots');
  CheckEqual(Int64(0), Int64(GManagedRecordBadFinalize),
    'managed record remove/retain/drain leaves no bad finalizers');
end;

begin
  T := TTestRunner.Create('nextpas.core.collections.swisstable');
  T.Run('Put/Get', @TestPutGet);
  T.Run('Update', @TestUpdate);
  T.Run('Remove', @TestRemove);
  T.Run('Grow (10000 elements)', @TestGrow);
  T.Run('Remove + Reinsert', @TestRemoveReinsert);
  T.Run('Deleted slot reuse keeps stable capacity', @TestDeletedSlotReuseKeepsStableCapacity);
  T.Run('Growth budget exhaustion reuses before grow', @TestGrowthBudgetExhaustionReusesBeforeGrow);
  T.Run('String key', @TestStringKey);
  T.Run('String specialized growth budget reuses before grow',
    @TestStringSpecializedGrowthBudgetReusesBeforeGrow);
  T.Run('Clear', @TestClear);
  T.Run('Prealloc', @TestPrealloc);
  T.Run('Retain', @TestRetain);
  T.Run('Drain', @TestDrain);
  T.Run('Reserve', @TestReserve);
  T.Run('ForEach/Enumerator', @TestForEachAndEnumerator);
  T.Run('Managed record slot cleanup', @TestManagedRecordSlotCleanup);
  T.Summary;
end.
