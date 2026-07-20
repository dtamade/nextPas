{**
 * T1 SegQueue teaching consumer: N producers + N workers + Close → join → Free
 *
 * Mirrors the multi-worker task-pool pattern (thread.pool uses SegQueue of nodes).
 * Lifecycle is the same as Channel/MPSC: Close → join → Free.
 *
 * In-tree teaching proof for nextpas.core.lockfree; not a production integration.
 *}
program t1_segqueue_workers;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.errors,
  nextpas.core.atomic,
  nextpas.core.lockfree,
  nextpas.core.lockfree.base,
  nextpas.core.platform.thread;

type
  TIntSeg = specialize TSegQueue<Integer>;

const
  ITEM_COUNT = 4000;
  PRODUCER_COUNT = 2;
  WORKER_COUNT = 2;

var
  GQueue: TIntSeg;
  GProduced: Int64;
  GConsumed: Int64;
  GClosedHits: Int64;

function ProducerProc(AArg: Pointer): Pointer; cdecl;
var
  LI: Integer;
  LErr: TLockFreeTryError;
  LBase: Integer;
  LIdx: PtrUInt;
begin
  Result := nil;
  LIdx := PtrUInt(AArg);
  LBase := Integer(LIdx) * ITEM_COUNT;
  for LI := 1 to ITEM_COUNT do
  begin
    while True do
    begin
      if GQueue.TryEnqueueEx(LBase + LI, LErr) then
      begin
        atomic_fetch_add_64(GProduced, 1, mo_relaxed);
        Break;
      end;
      if LErr = lfteClosed then
      begin
        atomic_fetch_add_64(GClosedHits, 1, mo_relaxed);
        Exit;
      end;
      platform_thread_yield;
    end;
  end;
end;

function WorkerProc(AArg: Pointer): Pointer; cdecl;
var
  LV: Integer;
  LErr: TLockFreeTryError;
begin
  Result := nil;
  while True do
  begin
    if GQueue.TryDequeueEx(LV, LErr) then
    begin
      atomic_fetch_add_64(GConsumed, 1, mo_relaxed);
      Continue;
    end;
    if LErr = lfteClosed then
      Exit;
    platform_thread_yield;
  end;
end;

procedure RunSegQueueWorkers;
var
  LProducers: array[0..PRODUCER_COUNT - 1] of TPlatformThreadHandle;
  LWorkers: array[0..WORKER_COUNT - 1] of TPlatformThreadHandle;
  LI: Integer;
  LRet: Pointer;
  LRc: Int32;
begin
  WriteLn('=== T1 SegQueue N-prod + N-worker Close → join → Free ===');
  GQueue := TIntSeg.Create;
  GProduced := 0;
  GConsumed := 0;
  GClosedHits := 0;
  try
    for LI := 0 to WORKER_COUNT - 1 do
    begin
      LRc := platform_thread_create(LWorkers[LI], @WorkerProc, nil);
      if LRc <> 0 then
        raise EInvalidOperationError.Create('worker create failed');
    end;
    for LI := 0 to PRODUCER_COUNT - 1 do
    begin
      LRc := platform_thread_create(LProducers[LI], @ProducerProc, Pointer(PtrUInt(LI)));
      if LRc <> 0 then
        raise EInvalidOperationError.Create('producer create failed');
    end;

    for LI := 0 to PRODUCER_COUNT - 1 do
      if platform_thread_join(LProducers[LI], LRet) <> 0 then
        raise EInvalidOperationError.Create('producer join failed');

    WriteLn('  Close queue (after producers done)');
    GQueue.Close;

    for LI := 0 to WORKER_COUNT - 1 do
      if platform_thread_join(LWorkers[LI], LRet) <> 0 then
        raise EInvalidOperationError.Create('worker join failed');

    WriteLn('  produced=', atomic_load_64(GProduced, mo_acquire),
      ' consumed=', atomic_load_64(GConsumed, mo_acquire),
      ' closed_hits=', atomic_load_64(GClosedHits, mo_acquire));
    WriteLn('  IsClosed=', GQueue.IsClosed);
    if atomic_load_64(GConsumed, mo_acquire) <> atomic_load_64(GProduced, mo_acquire) then
      raise EInvalidOperationError.Create('produced/consumed mismatch');
    if not GQueue.IsClosed then
      raise EInvalidOperationError.Create('expected closed');
    WriteLn('  join complete; Free next');
  finally
    GQueue.Free;
    GQueue := nil;
  end;
  WriteLn('  Free complete — Close → join → Free OK');
  WriteLn;
  WriteLn('t1_segqueue_workers: pass');
end;

begin
  RunSegQueueWorkers;
end.
