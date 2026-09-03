unit nextpas.core.window.queue.ring;

{ window.queue ring — 64 slot pool via bytes.ops single source, inline 零拷贝 O(1)；家族内 shard 仅 queue uses。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.window.impl,
  nextpas.core.window.queue.base,
  nextpas.core.bytes.ops;

type
  TQueueRingArena = record
    Buf: array of TWindowWorkItem;
    procedure Clear; inline;
    procedure MaybeShrink(AHintCap: Integer); inline;
    procedure Ensure(ANewCap: Integer); inline;
  end;

function QueueRingArenaAcquire(out AFromPool: Boolean): TQueueRingArena;
procedure QueueRingArenaRecycle(var AArena: TQueueRingArena);
function QueueRingArenaPoolCapacity: Integer; inline;
function QueueRingArenaPoolTopSnapshot: Integer; inline;
procedure RequireQueueRingToken(const AToken: TWindowFamilyToken); inline;

implementation

uses
  nextpas.core.atomic;

const
  QUEUE_ARENA_POOL_SIZE = ARENA_POOL_SIZE;
  QUEUE_ARENA_MAX_RETRIES = ARENA_POOL_MAX_RETRIES;
  QUEUE_RING_SHRINK_THRESH = BYTES_SNAPSHOT_MAX;

var
  GQueueRingPool: array[0..QUEUE_ARENA_POOL_SIZE - 1] of TQueueRingArena;
  GQueueRingPoolTop: Int32 = -1;
  GQueueRingShutdown: Int32 = 0;
  GQueueRingLock: Int32 = 0; // 池 critical section：claim+Buf 转移同锁（见 bytes.ops ArenaPoolLock）
  GQueueRingFinalizeIdx: Integer;

procedure RequireQueueRingToken(const AToken: TWindowFamilyToken); inline;
begin
  RequireWindowFamilyToken(AToken);
end;

procedure TQueueRingArena.Clear; inline;
begin
  Buf := nil;
end;

procedure TQueueRingArena.MaybeShrink(AHintCap: Integer); inline;
begin
  if (Length(Buf) > QUEUE_RING_SHRINK_THRESH) and (Length(Buf) > AHintCap * 4) then
    specialize ArraySetLengthNoRealloc<TWindowWorkItem>(Buf, WindowGrowCapacity(AHintCap));
end;

procedure TQueueRingArena.Ensure(ANewCap: Integer); inline;
begin
  specialize ManagedEnsureCapacityExact<TWindowWorkItem>(Buf, ANewCap);
end;

function QueueRingArenaPoolCapacity: Integer; inline;
begin
  Result := QUEUE_ARENA_POOL_SIZE;
end;

function QueueRingArenaPoolTopSnapshot: Integer; inline;
begin
  Result := atomic_load(GQueueRingPoolTop, mo_acquire);
end;

function QueueRingArenaAcquire(out AFromPool: Boolean): TQueueRingArena;
var LIdx: Int32;
begin
  AFromPool := False;
  Result.Clear;
  ArenaPoolLock(GQueueRingLock);
  try
    if ArenaPoolAcquireSlot(GQueueRingPoolTop, GQueueRingShutdown, LIdx) then
    begin
      ManagedArrayMovePtr(Result.Buf, GQueueRingPool[LIdx].Buf);
      AFromPool := True;
    end;
  finally
    ArenaPoolUnlock(GQueueRingLock);
  end;
end;

procedure QueueRingArenaRecycle(var AArena: TQueueRingArena);
var LIdx: Int32;
begin
  AArena.MaybeShrink(QUEUE_ARENA_POOL_SIZE);
  if Length(AArena.Buf) = 0 then
  begin
    AArena.Clear;
    Exit;
  end;
  ArenaPoolLock(GQueueRingLock);
  try
    if ArenaPoolRecycleSlot(GQueueRingPoolTop, GQueueRingShutdown, LIdx) then
    begin
      ManagedArrayMovePtr(GQueueRingPool[LIdx].Buf, AArena.Buf);
      Exit;
    end;
  finally
    ArenaPoolUnlock(GQueueRingLock);
  end;
  if atomic_load(GQueueRingShutdown, mo_acquire) <> 0 then
  begin
    AArena.Clear;
    Exit;
  end;
  AArena.Clear;
end;

initialization
  GQueueRingPoolTop := -1;
  GQueueRingShutdown := 0;

finalization
  specialize ArenaPoolFinalize<TQueueRingArena>(GQueueRingPool, GQueueRingPoolTop, GQueueRingShutdown, GQueueRingFinalizeIdx);

end.
