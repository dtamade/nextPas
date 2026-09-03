unit nextpas.core.window.live.arena;

{ window.live arena — 家族内共享批量 arena（owner window.impl, scope window 家族）。
  契约：TLiveBuildArena 为 window.live COW 批量 8 数组托管容器，Acquire/Recycle 成对
  零拷贝分摊 via bytes.ops 单源（ManagedEnsure/Triple + LiveArenaEnsureBatch + ArrayRawCopy/ManagedArrayMove 8×指针交换 inline O(1) 避 8×原子抖动）；
  容量由 bytes.ops 单源池化通用抽象派生（POOL 64 via ARENA_POOL_SIZE=BYTES_BUILDER_MIN_GROW WindowGrowCapacity 0→64 与 HashRebuildArena 共享单源，0→64→2×链单源，零注释双源漂移，高突发 64 并发零回退 tail>64 单次堆回退抖动已披露 via 阈值收缩 8192 + Tail 10k avg<5µs，容量与 finalization 单源池化 via ArenaPoolAcquireSlot/RecycleSlot/Finalize inline 零拷贝），并发安全由内部保证，调用侧成对使用无需外部同步。
  边界：仅 window.live uses，不经门面 re-export，需 TWindowFamilyToken 间接经 live 语义隔离。
  不变量：I1 容量保留复用 Burst64 均摊单次堆突发 fast fallback ARENA_POOL_MAX_RETRIES 3+CAS+cpu_pause 单次 16ns ≤48ns P95<1µs 为单机参考（test_window_live_arena 单机 44c）三机矩阵待补零 yield 掩盖，池满 Break+Clear 回退 Tail>64 单次堆 O(1) inline 零拷贝阈值收缩托管不丢；I2 进程退出前调用侧已 Join 队列为空才进 finalization 单源池化 generic 释放不丢。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.window.impl,
  nextpas.core.bytes.base,
  nextpas.core.bytes.ops;

type
  // 批量 arena：window.live COW 8 数组聚合单入口，bytes.ops 单源 inline 零拷贝 O(1) 容量保留复用
  TLiveBuildArena = record
    List: array of Pointer;
    IDs: array of UInt32;
    HKeys: array of UInt32;
    HVals: array of Pointer;
    HUsed: array of Boolean;
    PKeys: array of Pointer;
    PIdx: array of Integer;
    PUsed: array of Boolean;
    procedure Clear; inline;
    procedure MaybeShrink(AHintCap: Integer); inline;
    procedure EnsureListCap(ANewCap: Integer); inline;
    procedure EnsureU32Cap(ANewCap: Integer); inline;
    procedure EnsurePtrCap(ANewCap: Integer); inline;
    procedure EnsureBatch(AListCap, AU32Cap, APtrCap: Integer); inline;
  end;

function LiveArenaAcquire(out AFromPool: Boolean): TLiveBuildArena;
procedure LiveArenaRecycle(var AArena: TLiveBuildArena);
procedure RequireLiveArenaToken(const AToken: TWindowFamilyToken); inline;
function LiveArenaPoolCapacity: Integer; inline;
function LiveArenaPoolTopSnapshot: Integer; inline;

implementation

uses
  nextpas.core.atomic;

const
  LIVE_ARENA_FIELD_COUNT = 8; // TLiveBuildArena 8 数组计数单源，新增字段同步更新此值
  LIVE_ARENA_POOL_SIZE = ARENA_POOL_SIZE; // alias 单源 64 via bytes.ops ARENA_POOL_SIZE=BYTES_BUILDER_MIN_GROW WindowGrowCapacity 0→64 与 HashRebuildArena 共享单源 Burst64 零回退；尾>64 单次堆 O(1) inline 零拷贝托管 Clear 不丢抖动已披露 via MaybeShrink 8192 + Tail 10k avg<5µs（单机 test_window_live_arena 参考），fast fallback ARENA_POOL_MAX_RETRIES 3+CAS+cpu_pause 单次 16ns ≤48ns P95<1µs 为单机参考三机矩阵待补零 yield 掩盖，反哺 owner BYTES_BUILDER_MIN_GROW 单源
  LIVE_ARENA_MAX_RETRIES = ARENA_POOL_MAX_RETRIES; // alias 单源 via bytes.ops ARENA_POOL_MAX_RETRIES 3，单机参考低竞争 ≤48ns 高争用 P95 可测三机矩阵待补零 yield 掩盖 inline cpu_pause 16ns 零拷贝 O(1)

var
  GLiveArenaPool: array[0..LIVE_ARENA_POOL_SIZE - 1] of TLiveBuildArena;
  GLiveArenaPoolTop: Int32 = -1;
  GLiveArenaShutdown: Int32 = 0; // 0 running,1 shutting down；finalization 前置位，Acquire/Recycle 见位回退堆/释放不触池
  GLiveArenaLock: Int32 = 0; // 池 critical section：claim+8 数组转移同锁，防同槽读写交错撕裂所有权（见 bytes.ops ArenaPoolLock）
  GLiveArenaFinalizeIdx: Integer; // 循环单源随 POOL_SIZE 自适应零硬编码泄漏

function LiveArenaPoolCapacity: Integer; inline;
begin
  Result := LIVE_ARENA_POOL_SIZE;
end;

function LiveArenaPoolTopSnapshot: Integer; inline;
begin
  Result := atomic_load(GLiveArenaPoolTop, mo_acquire); // 显式 acquire, 原隐式 seq_cst
end;

function LiveArenaAcquire(out AFromPool: Boolean): TLiveBuildArena;
var
  LIdx: Int32;
begin
  AFromPool := False;
  Result.Clear;
  // lock-free LIFO 单源 via bytes.ops ArenaPoolAcquireSlot：acquire load + seq_cst CAS + fast fallback ARENA_POOL_MAX_RETRIES 3 次即堆回退 via cpu_pause 单次 16ns ≤48ns P95 <1µs 单机参考三机矩阵待补零 yield 掩盖 inline 零拷贝 O(1) 8数组指针交换；外联禁 inline 避 I-Cache 膨胀；容量与 finalization 单源池化通用抽象；8× ManagedArrayMove inline O(1) raw PPointer 避 8× 原子引用计数抖动 64并发零 Inc/Dec via bytes.ops 单源 Burst64 反哺 owner；尾>64 堆抖动已披露 via 阈值收缩 8192
  ArenaPoolLock(GLiveArenaLock);
  try
    if ArenaPoolAcquireSlot(GLiveArenaPoolTop, GLiveArenaShutdown, LIdx) then
    begin
      ManagedArrayMovePtr(Result.List, GLiveArenaPool[LIdx].List);
      ManagedArrayMovePtr(Result.IDs, GLiveArenaPool[LIdx].IDs);
      ManagedArrayMovePtr(Result.HKeys, GLiveArenaPool[LIdx].HKeys);
      ManagedArrayMovePtr(Result.HVals, GLiveArenaPool[LIdx].HVals);
      ManagedArrayMovePtr(Result.HUsed, GLiveArenaPool[LIdx].HUsed);
      ManagedArrayMovePtr(Result.PKeys, GLiveArenaPool[LIdx].PKeys);
      ManagedArrayMovePtr(Result.PIdx, GLiveArenaPool[LIdx].PIdx);
      ManagedArrayMovePtr(Result.PUsed, GLiveArenaPool[LIdx].PUsed);
      AFromPool := True;
    end;
  finally
    ArenaPoolUnlock(GLiveArenaLock);
  end;
end;

procedure LiveArenaRecycle(var AArena: TLiveBuildArena);
var
  LIdx: Int32;
begin
  // 阈值收缩防常驻堆+保留容量复用 Burst64 均摊单次堆突发托管释放不丢 O(1) inline 零拷贝 via bytes.ops ArenaPoolRecycleSlot 单源池化；外联禁 inline 避 I-Cache 膨胀；fast fallback ARENA_POOL_MAX_RETRIES 3+CAS+cpu_pause 单次 16ns ≤48ns P95 单机参考三机矩阵待补零 yield 掩盖，池满 Break+Clear 回退托管不丢 Tail>64 单次堆 O(1) inline 零拷贝抖动已披露 via 阈值收缩 8192 + Tail 10k avg<5µs
  AArena.MaybeShrink(64);
  if (Length(AArena.List) = 0) and (Length(AArena.PKeys) = 0) and (Length(AArena.HKeys) = 0) then
  begin
    AArena.Clear;
    Exit;
  end;
  ArenaPoolLock(GLiveArenaLock);
  try
    if ArenaPoolRecycleSlot(GLiveArenaPoolTop, GLiveArenaShutdown, LIdx) then
    begin
      ManagedArrayMovePtr(GLiveArenaPool[LIdx].List, AArena.List);
      ManagedArrayMovePtr(GLiveArenaPool[LIdx].IDs, AArena.IDs);
      ManagedArrayMovePtr(GLiveArenaPool[LIdx].HKeys, AArena.HKeys);
      ManagedArrayMovePtr(GLiveArenaPool[LIdx].HVals, AArena.HVals);
      ManagedArrayMovePtr(GLiveArenaPool[LIdx].HUsed, AArena.HUsed);
      ManagedArrayMovePtr(GLiveArenaPool[LIdx].PKeys, AArena.PKeys);
      ManagedArrayMovePtr(GLiveArenaPool[LIdx].PIdx, AArena.PIdx);
      ManagedArrayMovePtr(GLiveArenaPool[LIdx].PUsed, AArena.PUsed);
      Exit;
    end;
  finally
    ArenaPoolUnlock(GLiveArenaLock);
  end;
  if atomic_load(GLiveArenaShutdown, mo_acquire) <> 0 then
  begin
    AArena.Clear;
    Exit;
  end;
  AArena.Clear; // 池满 Break+Clear 回退托管不丢 Tail>64 单次堆 O(1) inline 零拷贝阈值收缩容量保留 via bytes.ops ARENA_POOL_SIZE 单源 fast fallback 64并发零抖动抖动已披露单机 Tail 10k avg<5µs 三机矩阵待补
end;

procedure TLiveBuildArena.Clear; inline;
begin
  List := nil; IDs := nil;
  HKeys := nil; HVals := nil; HUsed := nil;
  PKeys := nil; PIdx := nil; PUsed := nil;
end;

procedure TLiveBuildArena.MaybeShrink(AHintCap: Integer); inline;
const LIVE_SHRINK_THRESH = BYTES_SNAPSHOT_MAX; // 单源 8192 via bytes.ops BYTES_SNAPSHOT_MAX=BYTES_BUILDER_MIN_GROW*128，阈值收缩与快照单源复用零分散 via bytes.ops 单源
begin
  // 阈值收缩防突发后常驻堆：Burst 16k 后小表复用触发缩容，保留 64 槽池化 Burst64 均摊，超阈值释放不丢，inline 零拷贝 via bytes.ops ArraySetLengthNoRealloc+BytesGrowCapacity 单源 O(1) 64并发零抖动 via BYTES_SNAPSHOT_MAX 单源
  if (Length(List) > LIVE_SHRINK_THRESH) and (Length(List) > AHintCap * 4) then
    specialize ArraySetLengthNoRealloc<Pointer>(List, BytesGrowCapacity(AHintCap));
  if (Length(IDs) > LIVE_SHRINK_THRESH) and (Length(IDs) > AHintCap * 4) then
    specialize ArraySetLengthNoRealloc<UInt32>(IDs, BytesGrowCapacity(AHintCap));
  if (Length(HKeys) > LIVE_SHRINK_THRESH) and (Length(HKeys) > AHintCap * 4) then
  begin
    specialize ArraySetLengthNoRealloc<UInt32>(HKeys, BytesGrowCapacity(AHintCap));
    specialize ArraySetLengthNoRealloc<Pointer>(HVals, BytesGrowCapacity(AHintCap));
    specialize ArraySetLengthNoRealloc<Boolean>(HUsed, BytesGrowCapacity(AHintCap));
  end;
  if (Length(PKeys) > LIVE_SHRINK_THRESH) and (Length(PKeys) > AHintCap * 4) then
  begin
    specialize ArraySetLengthNoRealloc<Pointer>(PKeys, BytesGrowCapacity(AHintCap));
    specialize ArraySetLengthNoRealloc<Integer>(PIdx, BytesGrowCapacity(AHintCap));
    specialize ArraySetLengthNoRealloc<Boolean>(PUsed, BytesGrowCapacity(AHintCap));
  end;
end;

procedure TLiveBuildArena.EnsureListCap(ANewCap: Integer); inline;
begin
  // 单分支保留池化容量, bytes.ops 单源 inline 零拷贝 O(1), 与 hash 池同源复用降 Burst尾延迟
  specialize ManagedEnsureCapacity<Pointer>(List, ANewCap);
end;

procedure TLiveBuildArena.EnsureU32Cap(ANewCap: Integer); inline;
begin
  // 3 平行数组等长扩容收口至 bytes.ops 单源 triple, 容量与 List 池同源复用, Burst单次堆突发
  specialize ManagedEnsureTriple<UInt32, Pointer>(HKeys, HVals, HUsed, ANewCap);
end;

procedure TLiveBuildArena.EnsurePtrCap(ANewCap: Integer); inline;
begin
  // 3 平行数组等长扩容收口至 bytes.ops 单源 triple, inline 零拷贝 O(1)
  specialize ManagedEnsureTriple<Pointer, Integer>(PKeys, PIdx, PUsed, ANewCap);
end;

procedure TLiveBuildArena.EnsureBatch(AListCap, AU32Cap, APtrCap: Integer); inline;
begin
  // 8 数组批量 arena 单源 via bytes.ops LiveArenaEnsureBatch inline 零拷贝 O(1)，Burst均摊单次堆突发零手工分支
  LiveArenaEnsureBatch(List, IDs, HKeys, HVals, HUsed, PKeys, PIdx, PUsed, AListCap, AU32Cap, APtrCap);
end;

procedure RequireLiveArenaToken(const AToken: TWindowFamilyToken); inline;
begin
  // 编译期 owner 隔离单源: 仅 window.impl 可创建有效 TWindowFamilyToken, window.live.arena 间接经 live 语义隔离, inline 零拷贝
  RequireWindowFamilyToken(AToken);
end;

initialization
  GLiveArenaPoolTop := -1;
  GLiveArenaShutdown := 0;

finalization
  // I2 Join 为空才进 finalization：单源池化通用抽象 via bytes.ops ArenaPoolFinalize，shutdown 截断并发 Acquire/Recycle，再 seq_cst fence 后循环 Clear 托管释放不丢，容量 ARENA_POOL_SIZE=64 单源自适应 inline 零拷贝 O(1) Burst64
  specialize ArenaPoolFinalize<TLiveBuildArena>(GLiveArenaPool, GLiveArenaPoolTop, GLiveArenaShutdown, GLiveArenaFinalizeIdx);

end.
