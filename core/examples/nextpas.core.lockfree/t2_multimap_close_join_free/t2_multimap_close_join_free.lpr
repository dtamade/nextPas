{**
 * H3-2 MultiMap teaching consumer: multi-writer + Close → join → Free
 *
 * Direct uses nextpas.core.lockfree.multimap (not default T1 facade).
 * Progress is single-map spin lock (not lock-free) — still needs Close discipline.
 *}
program t2_multimap_close_join_free;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.errors,
  nextpas.core.atomic,
  nextpas.core.lockfree.multimap,
  nextpas.core.platform.thread;

type
  TIntMap = specialize TLockFreeMultiMap<Integer, Integer>;

const
  WRITES_PER_PRODUCER = 200;
  PRODUCER_COUNT = 2;
  MAP_CAP = 512; { power-of-two buckets; keep load low to avoid mmFull spin }

var
  GMap: TIntMap;
  GAdded: Int64;
  GClosedHits: Int64;

function ProducerProc(AArg: Pointer): Pointer; cdecl;
var
  LI: Integer;
  LRes: TLockFreeMultiMapAddResult;
  LId: Integer;
begin
  Result := nil;
  LId := Integer(PtrUInt(AArg));
  for LI := 1 to WRITES_PER_PRODUCER do
  begin
    while True do
    begin
      { key = LI (shared keys across producers → multi-value lists) }
      LRes := GMap.Add(LI, LId * 10000 + LI);
      case LRes of
        mmAdded:
          begin
            atomic_fetch_add_64(GAdded, 1, mo_relaxed);
            Break;
          end;
        mmClosed:
          begin
            atomic_fetch_add_64(GClosedHits, 1, mo_relaxed);
            Exit;
          end;
        mmFull:
          begin
            { capacity exhausted — stop this producer rather than spin forever }
            Exit;
          end;
        mmKeyExists:
          platform_thread_yield;
      end;
    end;
  end;
end;

procedure RunMultiMapCloseJoinFree;
var
  LProducers: array[0..PRODUCER_COUNT - 1] of TPlatformThreadHandle;
  LI: Integer;
  LRet: Pointer;
  LRc: Int32;
  LValues: array[0..15] of Integer;
  LFound: Integer;
begin
  WriteLn('=== H3-2 MultiMap multi-writer Close → join → Free ===');
  GMap := TIntMap.Create(MAP_CAP);
  GAdded := 0;
  GClosedHits := 0;
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

    WriteLn('  Close multimap (after writers done)');
    GMap.Close;

    if not GMap.IsClosed then
      raise EInvalidOperationError.Create('expected closed');
    if GMap.Add(999, 1) <> mmClosed then
      raise EInvalidOperationError.Create('Add after Close must return mmClosed');

    { Already-present keys remain readable after Close }
    LFound := GMap.Find(1, LValues);
    if LFound < 1 then
      raise EInvalidOperationError.Create('expected key 1 present after Close');

    WriteLn('  added=', atomic_load_64(GAdded, mo_acquire),
      ' closed_hits=', atomic_load_64(GClosedHits, mo_acquire),
      ' find(1)=', LFound);
    WriteLn('  IsClosed=', GMap.IsClosed);
    WriteLn('  join complete; Free next');
  finally
    GMap.Free;
    GMap := nil;
  end;
  WriteLn('  Free complete — Close → join → Free OK');
  WriteLn;
  WriteLn('t2_multimap_close_join_free: pass');
end;

begin
  RunMultiMapCloseJoinFree;
end.
