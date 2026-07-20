{**
 * H3-2 Bag teaching consumer: multi-producer + multi-consumer + Close → join → Free
 *
 * Direct uses nextpas.core.lockfree.bag (not default T1 facade).
 * Demonstrates arClosed after Close and drain of already-added items.
 *}
program t2_bag_close_join_free;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.errors,
  nextpas.core.atomic,
  nextpas.core.lockfree.bag,
  nextpas.core.platform.thread;

type
  TIntBag = specialize TLockFreeBag<Integer>;

const
  ITEM_COUNT = 2000;
  PRODUCER_COUNT = 2;
  CONSUMER_COUNT = 2;
  BAG_CAP = 256;

var
  GBag: TIntBag;
  GProduced: Int64;
  GConsumed: Int64;
  GClosedAdds: Int64;

function ProducerProc(AArg: Pointer): Pointer; cdecl;
var
  LI: Integer;
  LRes: TLockFreeBagAddResult;
  LBase: Integer;
begin
  Result := nil;
  LBase := Integer(PtrUInt(AArg)) * ITEM_COUNT;
  for LI := 1 to ITEM_COUNT do
  begin
    while True do
    begin
      LRes := GBag.TryAdd(LBase + LI);
      case LRes of
        arAdded:
          begin
            atomic_fetch_add_64(GProduced, 1, mo_relaxed);
            Break;
          end;
        arClosed:
          begin
            atomic_fetch_add_64(GClosedAdds, 1, mo_relaxed);
            Exit;
          end;
        arFull:
          platform_thread_yield;
      end;
    end;
  end;
end;

function ConsumerProc(AArg: Pointer): Pointer; cdecl;
var
  LV: Integer;
begin
  Result := nil;
  while True do
  begin
    if GBag.TryTake(LV) then
    begin
      atomic_fetch_add_64(GConsumed, 1, mo_relaxed);
      Continue;
    end;
    if GBag.IsClosed and GBag.IsEmpty then
      Exit;
    platform_thread_yield;
  end;
end;

procedure RunBagCloseJoinFree;
var
  LProducers: array[0..PRODUCER_COUNT - 1] of TPlatformThreadHandle;
  LConsumers: array[0..CONSUMER_COUNT - 1] of TPlatformThreadHandle;
  LI: Integer;
  LRet: Pointer;
  LRc: Int32;
begin
  WriteLn('=== H3-2 Bag multi P/C Close → join → Free ===');
  GBag := TIntBag.Create(BAG_CAP);
  GProduced := 0;
  GConsumed := 0;
  GClosedAdds := 0;
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

    WriteLn('  Close bag (after producers done)');
    GBag.Close;

    for LI := 0 to CONSUMER_COUNT - 1 do
      if platform_thread_join(LConsumers[LI], LRet) <> 0 then
        raise EInvalidOperationError.Create('consumer join failed');

    WriteLn('  produced=', atomic_load_64(GProduced, mo_acquire),
      ' consumed=', atomic_load_64(GConsumed, mo_acquire),
      ' closed_add_hits=', atomic_load_64(GClosedAdds, mo_acquire));
    WriteLn('  IsClosed=', GBag.IsClosed, ' IsEmpty=', GBag.IsEmpty);
    if atomic_load_64(GConsumed, mo_acquire) <> atomic_load_64(GProduced, mo_acquire) then
      raise EInvalidOperationError.Create('produced/consumed mismatch');
    if not GBag.IsClosed then
      raise EInvalidOperationError.Create('expected closed');
    WriteLn('  join complete; Free next');
  finally
    GBag.Free;
    GBag := nil;
  end;
  WriteLn('  Free complete — Close → join → Free OK');
  WriteLn;
  WriteLn('t2_bag_close_join_free: pass');
end;

begin
  RunBagCloseJoinFree;
end.
