{**
 * H2-6 minimal real consumer: T1 Channel Close → join → Free
 *
 * Spawns producer + consumer platform threads against TLockFreeChannel,
 * then demonstrates the safe lifecycle: Close → join threads → Free.
 * Also exercises Try*Ex diagnostics (full / empty / closed).
 *
 * This is an in-tree consumer proof for nextpas.core.lockfree T1, not a
 * cross-module production integration.
 *}
program t1_close_join_free;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.errors,
  nextpas.core.atomic,
  nextpas.core.lockfree,
  nextpas.core.lockfree.base,
  nextpas.core.platform.thread;

type
  TIntChannel = specialize TLockFreeChannel<Integer>;

const
  ITEM_COUNT = 5000;
  CHANNEL_CAP = 64;

var
  GChannel: TIntChannel;
  GProduced: Int64;
  GConsumed: Int64;
  GClosedPublishHits: Int64;

function ProducerProc(AArg: Pointer): Pointer; cdecl;
var
  LI: Integer;
  LErr: TLockFreeTryError;
begin
  Result := nil;
  for LI := 1 to ITEM_COUNT do
  begin
    while True do
    begin
      if GChannel.TrySendEx(LI, LErr) then
      begin
        atomic_fetch_add_64(GProduced, 1, mo_relaxed);
        Break;
      end;
      if LErr = lfteClosed then
      begin
        atomic_fetch_add_64(GClosedPublishHits, 1, mo_relaxed);
        Exit;
      end;
      { full: yield briefly }
      platform_thread_yield;
    end;
  end;
end;

function ConsumerProc(AArg: Pointer): Pointer; cdecl;
var
  LV: Integer;
  LErr: TLockFreeTryError;
begin
  Result := nil;
  while True do
  begin
    if GChannel.TryReceiveEx(LV, LErr) then
    begin
      atomic_fetch_add_64(GConsumed, 1, mo_relaxed);
      Continue;
    end;
    if LErr = lfteClosed then
      Exit;
    platform_thread_yield;
  end;
end;

procedure RunCloseJoinFree;
var
  LProducer, LConsumer: TPlatformThreadHandle;
  LRet: Pointer;
  LRc: Int32;
begin
  WriteLn('=== H2-6 T1 Close → join → Free consumer ===');
  GChannel := TIntChannel.Create(CHANNEL_CAP);
  GProduced := 0;
  GConsumed := 0;
  GClosedPublishHits := 0;
  try
    LRc := platform_thread_create(LConsumer, @ConsumerProc, nil);
    if LRc <> 0 then
      raise EInvalidOperationError.Create('consumer thread create failed');
    LRc := platform_thread_create(LProducer, @ProducerProc, nil);
    if LRc <> 0 then
      raise EInvalidOperationError.Create('producer thread create failed');

    { Wait until most items are in flight, then close. }
    while atomic_load_64(GProduced, mo_acquire) < (ITEM_COUNT div 2) do
      platform_thread_yield;

    WriteLn('  Close channel (mid-stream)');
    GChannel.Close;

    if platform_thread_join(LProducer, LRet) <> 0 then
      raise EInvalidOperationError.Create('producer join failed');
    if platform_thread_join(LConsumer, LRet) <> 0 then
      raise EInvalidOperationError.Create('consumer join failed');

    WriteLn('  produced=', GProduced, ' consumed=', GConsumed,
      ' closed_publish_hits=', GClosedPublishHits);
    WriteLn('  IsClosed=', GChannel.IsClosed);
    if GConsumed > GProduced then
      raise EInvalidOperationError.Create('consumed > produced');
    if not GChannel.IsClosed then
      raise EInvalidOperationError.Create('expected closed');
    WriteLn('  join complete; Free next');
  finally
    GChannel.Free;
    GChannel := nil;
  end;
  WriteLn('  Free complete — Close → join → Free OK');
  WriteLn;
end;

begin
  RunCloseJoinFree;
  WriteLn('t1_close_join_free: pass');
end.
