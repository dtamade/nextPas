{**
 * T1 MSQueue teaching consumer: multi P/C + Close → join → Free
 *
 * CONTRACT §1.3: Close rejects publish; Destroy Close+drain does not replace join.
 * Michael–Scott lock-free unbounded MPMC (on default lockfree facade).
 *}
program t1_msqueue_close_join_free;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.errors,
  nextpas.core.atomic,
  nextpas.core.lockfree.msqueue,
  nextpas.core.platform.thread;

type
  TIntQ = specialize TLockFreeMsQueueImpl<Integer>;

const
  ITEM_COUNT = 2000;
  PRODUCER_COUNT = 2;
  CONSUMER_COUNT = 2;

var
  GQ: TIntQ;
  GProduced: Int64;
  GConsumed: Int64;
  GClosedEnq: Int64;

function ProducerProc(AArg: Pointer): Pointer; cdecl;
var
  LI: Integer;
  LBase: Integer;
begin
  Result := nil;
  LBase := Integer(PtrUInt(AArg)) * ITEM_COUNT;
  for LI := 1 to ITEM_COUNT do
  begin
    while not GQ.TryEnqueue(LBase + LI) do
    begin
      if GQ.IsClosed then
      begin
        atomic_fetch_add_64(GClosedEnq, 1, mo_relaxed);
        Exit;
      end;
      platform_thread_yield;
    end;
    atomic_fetch_add_64(GProduced, 1, mo_relaxed);
  end;
end;

function ConsumerProc(AArg: Pointer): Pointer; cdecl;
var
  LV: Integer;
begin
  Result := nil;
  while True do
  begin
    if GQ.TryDequeue(LV) then
    begin
      atomic_fetch_add_64(GConsumed, 1, mo_relaxed);
      Continue;
    end;
    if GQ.IsClosed and GQ.IsEmpty then
      Exit;
    platform_thread_yield;
  end;
end;

procedure RunMsQueueCloseJoinFree;
var
  LProducers: array[0..PRODUCER_COUNT - 1] of TPlatformThreadHandle;
  LConsumers: array[0..CONSUMER_COUNT - 1] of TPlatformThreadHandle;
  LI: Integer;
  LRet: Pointer;
  LRc: Int32;
begin
  WriteLn('=== T1 MSQueue multi P/C Close → join → Free ===');
  GQ := TIntQ.Create(64);
  GProduced := 0;
  GConsumed := 0;
  GClosedEnq := 0;
  try
    for LI := 0 to CONSUMER_COUNT - 1 do
    begin
      LRc := platform_thread_create(LConsumers[LI], @ConsumerProc, nil);
      if LRc <> 0 then
        raise EInvalidOperationError.Create('consumer create failed');
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

    WriteLn('  Close MSQueue (after producers done)');
    GQ.Close;

    for LI := 0 to CONSUMER_COUNT - 1 do
      if platform_thread_join(LConsumers[LI], LRet) <> 0 then
        raise EInvalidOperationError.Create('consumer join failed');

    WriteLn('  produced=', atomic_load_64(GProduced, mo_acquire),
      ' consumed=', atomic_load_64(GConsumed, mo_acquire),
      ' closed_enq_hits=', atomic_load_64(GClosedEnq, mo_acquire));
    WriteLn('  IsClosed=', GQ.IsClosed, ' IsEmpty=', GQ.IsEmpty);
    if atomic_load_64(GConsumed, mo_acquire) <> atomic_load_64(GProduced, mo_acquire) then
      raise EInvalidOperationError.Create('produced/consumed mismatch');
    if not GQ.IsClosed then
      raise EInvalidOperationError.Create('expected closed');
    if GQ.TryEnqueue(1) then
      raise EInvalidOperationError.Create('enqueue after Close must fail');
    WriteLn('  join complete; Free next');
  finally
    GQ.Free;
    GQ := nil;
  end;
  WriteLn('  Free complete — Close → join → Free OK');
  WriteLn;
  WriteLn('t1_msqueue_close_join_free: pass');
end;

begin
  RunMsQueueCloseJoinFree;
end.
