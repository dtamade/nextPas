{**
 * HashMap teaching consumer: multi-writer + Close → join → Free
 *
 * Charter C: T1 ShardedHashMap Close (not H3-2 bag/multimap subset).
 * Progress is sharded spin locks — not lock-free.
 *}
program t2_hashmap_join_free;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.errors,
  nextpas.core.atomic,
  nextpas.core.lockfree.hashmap,
  nextpas.core.platform.thread;

type
  TIntMap = specialize TShardedHashMap<Integer, Integer>;

const
  WRITES_PER_PRODUCER = 500;
  PRODUCER_COUNT = 4;

var
  GMap: TIntMap;
  GInserted: Int64;

function ProducerProc(AArg: Pointer): Pointer; cdecl;
var
  LI: Integer;
  LBase: Integer;
  LKey: Integer;
begin
  Result := nil;
  LBase := Integer(PtrUInt(AArg)) * WRITES_PER_PRODUCER;
  for LI := 1 to WRITES_PER_PRODUCER do
  begin
    LKey := LBase + LI;
    GMap.Insert(LKey, LKey);
    atomic_fetch_add_64(GInserted, 1, mo_relaxed);
  end;
end;

procedure RunHashMapJoinFree;
var
  LProducers: array[0..PRODUCER_COUNT - 1] of TPlatformThreadHandle;
  LI: Integer;
  LRet: Pointer;
  LRc: Int32;
  LValue: Integer;
  LExpected: Int64;
begin
  WriteLn('=== HashMap multi-writer Close → join → Free ===');
  GMap := TIntMap.Create(64);
  GInserted := 0;
  try
    for LI := 0 to PRODUCER_COUNT - 1 do
    begin
      LRc := platform_thread_create(LProducers[LI], @ProducerProc, Pointer(PtrUInt(LI)));
      if LRc <> 0 then
        raise EInvalidOperationError.Create('producer create failed');
    end;

    for LI := 0 to PRODUCER_COUNT - 1 do
      if platform_thread_join(LProducers[LI], LRet) <> 0 then
        raise EInvalidOperationError.Create('producer join failed');

    WriteLn('  Close map (after writers done)');
    GMap.Close;
    if not GMap.IsClosed then
      raise EInvalidOperationError.Create('expected closed');

    LExpected := Int64(PRODUCER_COUNT) * WRITES_PER_PRODUCER;
    if atomic_load_64(GInserted, mo_acquire) <> LExpected then
      raise EInvalidOperationError.Create('insert count mismatch');
    if GMap.Count <> PtrUInt(LExpected) then
      raise EInvalidOperationError.Create('map count mismatch');
    if not GMap.Find(1, LValue) or (LValue <> 1) then
      raise EInvalidOperationError.Create('expected key 1');
    if not GMap.Find(LExpected, LValue) or (LValue <> Integer(LExpected)) then
      raise EInvalidOperationError.Create('expected last key');
    if GMap.TryInsert(Integer(LExpected) + 1, 0) then
      raise EInvalidOperationError.Create('TryInsert after Close must fail');

    WriteLn('  inserted=', atomic_load_64(GInserted, mo_acquire),
      ' Count=', GMap.Count, ' IsClosed=', GMap.IsClosed);
    WriteLn('  join complete; Free next');
  finally
    GMap.Free;
    GMap := nil;
  end;
  WriteLn('  Free complete — Close → join → Free OK');
  WriteLn;
  WriteLn('t2_hashmap_join_free: pass');
end;

begin
  RunHashMapJoinFree;
end.
