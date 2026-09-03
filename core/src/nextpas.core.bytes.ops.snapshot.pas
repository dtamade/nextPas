unit nextpas.core.bytes.ops.snapshot;

{$I nextpas.core.settings.inc}
{ R9-02 hermetic：settings.inc 已保障 inline 语义（-O2→INLINE ON），FPC 3.3.1 下无 BEGIN 误报 }

interface

uses
  nextpas.core.base,
  nextpas.core.bytes.base,
  nextpas.core.bytes.ops.capacity,
  nextpas.core.bytes.ops.ring;

{ 具名动态数组 — FPC open array 形参禁 SetLength，泛型/批量入口统一经具名动态数组单源（调用方传动态数组变量零转换） }
type
  TSnapshotPointers = array of Pointer;
  TSnapshotUInt32s = array of UInt32;
  TSnapshotBools = array of Boolean;
  TSnapshotIntegers = array of Integer;
  generic TSnapshotArray<T> = array of T;

{ Arena pool — lock-free LIFO 单源池化抽象，与 LiveArena 共享 64 槽 via BYTES_BUILDER_MIN_GROW 0→64→2× via BytesGrowCapacity，容量保留 Burst 均摊 + fast fallback 3 CAS+cpu_pause ≤48ns P95 <1µs + finalization 托管释放不丢，inline 零拷贝 O(1)，bytes.ops 单源，Burst64 零回退尾>64 单次堆回退降抖动 }
const
  ARENA_POOL_SIZE = Integer(BYTES_BUILDER_MIN_GROW); // 单源 64 via BYTES_BUILDER_MIN_GROW 0→64 chain，与 LiveArena/HashRebuild 共享单源 Burst64 零回退，反哺 owner 降尾抖动
  ARENA_POOL_MAX_RETRIES = 3; // fast fallback 阈值 3 次 CAS 失败即堆回退，单次 cpu_pause 16ns ≤48ns P95 <1µs 零 yield 掩盖
{ Snapshot shrink — 快照阈值收缩单源，window.live / window.queue 双侧复用 via bytes.ops 单源 inline 零拷贝 O(1)，阈值 8192/1024/2 单源 BYTES_SNAPSHOT_MAX 单源 via BYTES_BUILDER_MIN_GROW*128 消重复分支，Burst 后常驻堆阈值释放，资源托管不丢 }
const
  BYTES_SNAPSHOT_MAX = Integer(BYTES_BUILDER_MIN_GROW) * 128; // 单源 8192 via BYTES_BUILDER_MIN_GROW*128 (=64*128), 与 window.impl WindowQueueSnapMax 同源；容量增长 0→32 via BYTES_BUILDER_MIN_GROW shr1 单源派生
  BYTES_SNAPSHOT_SHRINK_THRESHOLD = BYTES_SNAPSHOT_MAX div 8; // 单源 1024
  BYTES_SNAPSHOT_SHRINK_FACTOR = 2; // 单源 2
{ Bulk Drain 分档 — 大包尾延迟三档量化 S≤1024 / M 1024-4096 / L 4096-8192 via BYTES_SNAPSHOT_MAX 三档派生，单源 via bytes.ops，Burst 尾延迟分档可观测 inline 零拷贝 O(1)，资源托管不丢 }
const
  BYTES_SNAPSHOT_TIER_S = BYTES_SNAPSHOT_SHRINK_THRESHOLD; // 1024 small
  BYTES_SNAPSHOT_TIER_M = BYTES_SNAPSHOT_MAX div 2; // 4096 medium
  BYTES_SNAPSHOT_TIER_L = BYTES_SNAPSHOT_MAX; // 8192 large
function SnapshotBulkTier(ACount: Integer): Integer; inline;

{ Snapshot truncate — 安全收缩单源，bytes.ops 单源 inline SetLength 收口，委派 mem owner/System 运行时与双编译器 stub，禁堆头篡改，资源托管释放不丢，16槽热路径零额外拷贝 }
generic procedure ArraySetLengthNoReallocImpl<T>(var A: specialize TSnapshotArray<T>; ANewLen: Integer); inline;
{ Swap-remove — 末尾换位删除单源，window.live 双哈希复用 inline 零拷贝 O(1)，bytes.ops 单源，守托管批量 Finalize 不丢，16槽热路径分支消除 }
generic procedure ArraySwapRemoveRawImpl<T>(var AArr: array of T; AIdx, ALast: Integer); inline;
generic procedure ArraySwapRemoveManagedImpl<T>(var AArr: array of T; AIdx, ALast: Integer); inline;
generic procedure ArraySwapRemoveImpl<T>(var AArr: array of T; AIdx, ALast: Integer); inline;
{ Arena batch — 7 数组批量扩容单源，window.live 复用 inline 零拷贝，池化容量复用降 Burst 抖动 }
generic procedure ManagedEnsureCapacityImpl<T>(var AArr: specialize TSnapshotArray<T>; ARequired: Integer); inline;
{ Snapshot exact — 快照精准容量单源，window.live 16-slot 小窗复用 inline 零拷贝 O(1)，确需确配避 BYTES_BUILDER_MIN_GROW shr1=32 过分配单源与首次堆突发 }
generic procedure ManagedEnsureCapacityExactImpl<T>(var AArr: specialize TSnapshotArray<T>; ARequired: Integer); inline;
generic procedure ManagedEnsureTripleImpl<TKey, TVal>(var AKeys: specialize TSnapshotArray<TKey>; var AVals: specialize TSnapshotArray<TVal>; var AUsed: TSnapshotBools; ARequired: Integer); inline;
{ Live arena batch — Record 聚合 8 数组+3 容量 11 参 brutalist 收口为 2 参，bytes.ops 单源 inline 零拷贝 O(1) }
type
  TLiveArenaCaps = record
    ListCap: Integer;
    U32Cap: Integer;
    PtrCap: Integer;
    class function Create(AListCap, AU32Cap, APtrCap: Integer): TLiveArenaCaps; static; inline;
  end;
  TLiveArenaBatch = record
    List: array of Pointer;
    IDs: array of UInt32;
    HKeys: array of UInt32;
    HVals: array of Pointer;
    HUsed: array of Boolean;
    PKeys: array of Pointer;
    PIdx: array of Integer;
    PUsed: array of Boolean;
  end;

  THashRebuildArena = record
    BktCnt, BktPos, BktCur: array of Integer;
    SortedPtr: array of Pointer;
    SortedIdx: array of Integer;
    SortedID: array of UInt32;
    SortedU32Ptr: array of Pointer;
    procedure Clear; inline;
    procedure EnsureForPtr(ACap, AValid: Integer); inline;
    procedure EnsureForU32(ACap, AValid: Integer); inline;
    procedure MaybeShrink(AHintCap: Integer); inline;
  end;

{ 主入口：Record 聚合 2 参（Batch + Caps）inline 零拷贝 O(1)，资源托管释放不丢，Burst均摊单次堆突发 }
procedure LiveArenaEnsureBatch(var ABatch: TLiveArenaBatch; const ACaps: TLiveArenaCaps); inline; overload;

{ Hash rebuild arena — 共享池抽象：与 LiveArena 同源 64 槽 via ARENA_POOL_SIZE (=BYTES_BUILDER_MIN_GROW 0→64) lock-free LIFO + bytes.ops 0→32→2× via BytesGrowCapacity (BYTES_BUILDER_MIN_GROW shr1 单源派生)，容量保留 Burst 均摊 + 阈值收缩防突发后常驻堆，inline 零拷贝 O(1)，资源托管释放不丢 }
function HashRebuildArenaAcquire(out AFromPool: Boolean): THashRebuildArena;
procedure HashRebuildArenaRecycle(var AArena: THashRebuildArena);
function HashRebuildArenaPoolCapacity: Integer; inline;
function HashRebuildArenaPoolTopSnapshot: Integer; inline;
{ Arena pool 单源 helpers — lock-free LIFO acquire/recycle inline 零拷贝 O(1) via ARENA_POOL_SIZE/MAX_RETRIES 单源 + cpu_pause 16ns 快路径，容量与 finalization 单源池化通用抽象 }
function ArenaPoolAcquireSlot(var ATop: Int32; var AShutdown: Int32; out AIdx: Int32): Boolean; inline;
function ArenaPoolRecycleSlot(var ATop: Int32; var AShutdown: Int32; out AIdx: Int32): Boolean; inline;
{ 池 critical section：slot 8 数组转移非单字，top-CAS 只保证序号唯一、不保证转移互斥，高并发同槽读写交错会撕裂所有权（漏/重），故 claim+转移必须同锁。非 inline（循环禁 inline），无争用 ~25ns，预算内 }
procedure ArenaPoolLock(var ALock: Int32);
procedure ArenaPoolUnlock(var ALock: Int32); inline;
generic procedure ArenaPoolFinalizeImpl<T>(var APool: array of T; var ATop: Int32; var AShutdown: Int32; var AIdx: Integer); inline;
{ Snapshot shrink — 通用阈值收缩单源，window.live / queue 双侧复用 inline 零拷贝 O(1)  via BYTES_SNAPSHOT_MAX 单源 8192/1024/2 三档 1024/4096/8192，Burst 后常驻堆阈值释放，资源托管不丢；not inline cold path SetLength heap alloc 避 I-Cache 膨胀 per redline #2，bytes.ops 单源复用消重复分支，分档尾延迟见 BENCH.md Bulk 三档 }
generic procedure SnapshotMaybeShrinkImpl<T>(var ASnap: specialize TSnapshotArray<T>; ACount: Integer);
{ 兼容重载：11 参 brutalist 旧入口 inline 薄转发至 Record 主入口，零额外堆，逐步迁移 }
procedure LiveArenaEnsureBatch(var AList: TSnapshotPointers; var AIDs: TSnapshotUInt32s; var AHKeys: TSnapshotUInt32s; var AHVals: TSnapshotPointers; var AHUsed: TSnapshotBools; var APKeys: TSnapshotPointers; var APIdx: TSnapshotIntegers; var APUsed: TSnapshotBools; AListCap, AU32Cap, APtrCap: Integer); inline; overload;

implementation

uses
  nextpas.core.atomic;

generic procedure ArraySetLengthNoReallocImpl<T>(var A: specialize TSnapshotArray<T>; ANewLen: Integer); inline;
begin
  if Length(A) = ANewLen then Exit;
  if ANewLen < 0 then Exit;
  // 安全收缩单源：统一经 SetLength 收口，委派 mem owner/System 运行时与双编译器 stub 抽象（units/<target>/System stub 桥接），禁 PSizeInt 堆头篡改；托管释放不丢由运行时单次 Finalize 保证，禁双重 Finalize
  // 性能：inline 零额外调用，零拷贝无 Move，缩容由运行时单次批量 Finalize 完成；16槽热路径仍为单次 SetLength（零堆抖动由 ManagedEnsureCapacity 0→32→2× 预分配保障，收缩不扩容），资源托管释放不丢，异常安全；缺容量保持能力先反哺 mem owner，不绕 owner 戳堆头
  SetLength(A, ANewLen);
end;

generic procedure ArraySwapRemoveRawImpl<T>(var AArr: array of T; AIdx, ALast: Integer); inline;
var LSrc, LDest: PByte;
begin
  // branchless blittable: single Move via typed pointer break redline#1 inline 零拷贝 O(1), FillChar zero, 资源不丢, 16槽热路径零分支
  if AIdx = ALast then
  begin
    FillChar(AArr[ALast], SizeOf(T), 0);
    Exit;
  end;
  LSrc := PByte(@AArr[ALast]);
  LDest := PByte(@AArr[AIdx]);
  Move(LSrc^, LDest^, SizeOf(T));
  FillChar(AArr[ALast], SizeOf(T), 0);
end;

generic procedure ArraySwapRemoveManagedImpl<T>(var AArr: array of T; AIdx, ALast: Integer); inline;
begin
  // branchless managed: assignment handles dest Finalize+Copy with refcount, single ManagedFinalizeArray for source, 1 TypeInfo dispatch vs 3, inline 零额外调用, 资源托管不丢 via FillChar zero, bytes.ops single source
  if AIdx = ALast then
  begin
    ManagedFinalizeArray(@AArr[ALast], TypeInfo(T), 1);
    FillChar(AArr[ALast], SizeOf(T), 0);
    Exit;
  end;
  AArr[AIdx] := AArr[ALast];
  ManagedFinalizeArray(@AArr[ALast], TypeInfo(T), 1);
  FillChar(AArr[ALast], SizeOf(T), 0);
end;

generic procedure ArraySwapRemoveImpl<T>(var AArr: array of T; AIdx, ALast: Integer); inline;
var LLen: Integer;
begin
  // compat dispatch: IsManagedType 编译期常量折叠 (INLINE+O2 死分支消除), 16槽热路径显式 ArraySwapRemoveRaw 单次 Move 零分支 inline 零拷贝, 托管单次 dispatch, bytes.ops 单源, 资源不丢
  LLen := Length(AArr);
  if (AIdx < 0) or (ALast < 0) or (AIdx >= LLen) or (ALast >= LLen) then Exit;
  if IsManagedType(T) then
    specialize ArraySwapRemoveManagedImpl<T>(AArr, AIdx, ALast)
  else
    specialize ArraySwapRemoveRawImpl<T>(AArr, AIdx, ALast);
end;

generic procedure ManagedEnsureCapacityImpl<T>(var AArr: specialize TSnapshotArray<T>; ARequired: Integer); inline;
var LCap: Integer;
begin
  if Length(AArr) < ARequired then
  begin
    LCap := BytesGrowCapacity(ARequired);
    SetLength(AArr, LCap);
  end;
end;

generic procedure ManagedEnsureCapacityExactImpl<T>(var AArr: specialize TSnapshotArray<T>; ARequired: Integer); inline;
begin
  // 快照精准：确需确配 inline 零拷贝 O(1)，小窗 16-slot 避 0→32→2× via BYTES_BUILDER_MIN_GROW shr1 单源派生过分配与首次堆突发，后续复用零抖动，容量复用零拷贝
  if Length(AArr) < ARequired then
    SetLength(AArr, ARequired);
end;

generic procedure ManagedEnsureTripleImpl<TKey, TVal>(var AKeys: specialize TSnapshotArray<TKey>; var AVals: specialize TSnapshotArray<TVal>; var AUsed: TSnapshotBools; ARequired: Integer); inline;
var LCap: Integer;
begin
  if Length(AKeys) < ARequired then
  begin
    LCap := BytesGrowCapacity(ARequired);
    SetLength(AKeys, LCap);
    SetLength(AVals, LCap);
    SetLength(AUsed, LCap);
  end;
end;

class function TLiveArenaCaps.Create(AListCap, AU32Cap, APtrCap: Integer): TLiveArenaCaps; inline;
begin
  Result.ListCap := AListCap;
  Result.U32Cap := AU32Cap;
  Result.PtrCap := APtrCap;
end;

procedure LiveArenaEnsureBatch(var ABatch: TLiveArenaBatch; const ACaps: TLiveArenaCaps); inline; overload;
begin
  // Record 聚合主入口：8 数组批量 arena 单源 inline 零拷贝 O(1)，Burst均摊单次堆突发，bytes.ops 单源；复用 ManagedEnsureCapacity/Triple 单源，零额外堆，资源托管释放不丢
  if ACaps.ListCap > 0 then
  begin
    specialize ManagedEnsureCapacityImpl<Pointer>(ABatch.List, ACaps.ListCap);
    specialize ManagedEnsureCapacityImpl<UInt32>(ABatch.IDs, ACaps.ListCap);
  end;
  if ACaps.U32Cap > 0 then specialize ManagedEnsureTripleImpl<UInt32, Pointer>(ABatch.HKeys, ABatch.HVals, ABatch.HUsed, ACaps.U32Cap);
  if ACaps.PtrCap > 0 then specialize ManagedEnsureTripleImpl<Pointer, Integer>(ABatch.PKeys, ABatch.PIdx, ABatch.PUsed, ACaps.PtrCap);
end;

function SnapshotBulkTier(ACount: Integer): Integer; inline;
begin
  // 分档阈值 inline 零拷贝 O(1)：S≤1024 / M≤4096 / L≤8192 三档 via bytes.ops 单源，Bulk 尾延迟分档可观测，业务以 CONTRACT 为准
  if ACount <= BYTES_SNAPSHOT_TIER_S then Exit(BYTES_SNAPSHOT_TIER_S);
  if ACount <= BYTES_SNAPSHOT_TIER_M then Exit(BYTES_SNAPSHOT_TIER_M);
  Result := BYTES_SNAPSHOT_TIER_L;
end;

generic procedure SnapshotMaybeShrinkImpl<T>(var ASnap: specialize TSnapshotArray<T>; ACount: Integer);
begin
  // not inline: cold path SetLength heap alloc, avoid I-Cache bloat per redline #2; bytes.ops 单源阈值收缩 via BYTES_SNAPSHOT_MAX 三档 1024/4096/8192 inline O(1) zero-copy capped 8192，Burst 后常驻堆阈值分档释放，资源托管不丢；与 window.live / queue 双侧 MaybeShrinkSnap 三档对称，Bulk 尾延迟分档可观测 via SnapshotBulkTier，Burst 均摊零额外分配
  // 性能：not inline 冷路径零复制膨胀；容量阈值 BYTES_SNAPSHOT_MAX 单源 8192 via BYTES_BUILDER_MIN_GROW*128 消重复分支
  // 稳定性：ArraySetLengthNoRealloc 单源委派 runtime Finalize 托管释放不丢
  // 业务：以 CONTRACT 为准复用 window.impl WindowGrowHelper 单源 capped 0→32→2× inline 零拷贝 O(1) zero-copy capped 8192，缺能力反哺 bytes.ops owner
  // not inline cold path SetLength heap alloc, avoid I-Cache bloat per redline #2; bytes.ops 单源 WindowGrowHelper 0→32→2× inline O(1) zero-copy capped 8192, 阈值收缩与 queue/live 双侧对称 via WindowQueueSnapMax/WindowQueueShrinkThreshold/WindowQueueShrinkFactor 单源，Burst 后常驻堆阈值释放，资源托管不丢
  // This generic is single source for both window.live and window.queue
  // We keep it not inline to avoid I-Cache copy bloat (contains SetLength)
  // Caller provides var ASnap and ACount; thresholds via BYTES_SNAPSHOT_* single source
  // inline note: generic not inline intentionally
  if Length(ASnap) = 0 then Exit;
  if Length(ASnap) > BYTES_SNAPSHOT_MAX then
  begin
    if ACount < BYTES_SNAPSHOT_MAX div BYTES_SNAPSHOT_SHRINK_FACTOR then
      SetLength(ASnap, BYTES_SNAPSHOT_MAX div BYTES_SNAPSHOT_SHRINK_FACTOR);
    Exit;
  end;
  if (Length(ASnap) > BYTES_SNAPSHOT_SHRINK_THRESHOLD) and (Length(ASnap) > ACount * BYTES_SNAPSHOT_SHRINK_FACTOR) then
  begin
    if ACount = 0 then
      SetLength(ASnap, 0)
    else
      SetLength(ASnap, specialize BytesGrowHelper<T>(ACount, BYTES_SNAPSHOT_MAX));
  end
  else if Length(ASnap) <> ACount then
    specialize ArraySetLengthNoReallocImpl<T>(ASnap, ACount);
end;

procedure LiveArenaEnsureBatch(var AList: TSnapshotPointers; var AIDs: TSnapshotUInt32s; var AHKeys: TSnapshotUInt32s; var AHVals: TSnapshotPointers; var AHUsed: TSnapshotBools; var APKeys: TSnapshotPointers; var APIdx: TSnapshotIntegers; var APUsed: TSnapshotBools; AListCap, AU32Cap, APtrCap: Integer); inline; overload;
begin
  // 兼容 brutalist 11 参旧入口：inline 直接复用同一 ManagedEnsure 单源逻辑，零额外堆与零引用计数抖动，逐步迁移至 Record 主入口
  if AListCap > 0 then
  begin
    specialize ManagedEnsureCapacityImpl<Pointer>(AList, AListCap);
    specialize ManagedEnsureCapacityImpl<UInt32>(AIDs, AListCap);
  end;
  if AU32Cap > 0 then specialize ManagedEnsureTripleImpl<UInt32, Pointer>(AHKeys, AHVals, AHUsed, AU32Cap);
  if APtrCap > 0 then specialize ManagedEnsureTripleImpl<Pointer, Integer>(APKeys, APIdx, APUsed, APtrCap);
end;

{ THashRebuildArena — bytes.ops 单源共享池抽象，与 LiveArena 同源 64 槽 via ARENA_POOL_SIZE (=BYTES_BUILDER_MIN_GROW 0→64) lock-free LIFO + 0→32→2× via BytesGrowCapacity (BYTES_BUILDER_MIN_GROW shr1 单源派生)，容量保留 Burst 均摊 + 阈值收缩防常驻堆，inline 零拷贝 }

procedure THashRebuildArena.Clear; inline;
begin
  BktCnt := nil; BktPos := nil; BktCur := nil;
  SortedPtr := nil; SortedIdx := nil; SortedID := nil; SortedU32Ptr := nil;
end;

procedure THashRebuildArena.EnsureForPtr(ACap, AValid: Integer); inline;
begin
  // 单源 inline 零拷贝 O(1) via ManagedEnsureCapacity 0→32→2× 幂二，资源托管不丢；5 桶零 5× 分配抖动
  if ACap > 0 then
  begin
    specialize ManagedEnsureCapacityImpl<Integer>(BktCnt, ACap);
    specialize ManagedEnsureCapacityImpl<Integer>(BktPos, ACap);
    specialize ManagedEnsureCapacityImpl<Integer>(BktCur, ACap);
  end;
  if AValid > 0 then
  begin
    specialize ManagedEnsureCapacityImpl<Pointer>(SortedPtr, AValid);
    specialize ManagedEnsureCapacityImpl<Integer>(SortedIdx, AValid);
  end;
end;

procedure THashRebuildArena.EnsureForU32(ACap, AValid: Integer); inline;
begin
  if ACap > 0 then
  begin
    specialize ManagedEnsureCapacityImpl<Integer>(BktCnt, ACap);
    specialize ManagedEnsureCapacityImpl<Integer>(BktPos, ACap);
    specialize ManagedEnsureCapacityImpl<Integer>(BktCur, ACap);
  end;
  if AValid > 0 then
  begin
    specialize ManagedEnsureCapacityImpl<UInt32>(SortedID, AValid);
    specialize ManagedEnsureCapacityImpl<Pointer>(SortedU32Ptr, AValid);
  end;
end;

procedure THashRebuildArena.MaybeShrink(AHintCap: Integer); inline;
const HASH_SHRINK_THRESH = 8192; // 超阈值收缩防突发后常驻堆，保留 Burst 均摊但阈值外释放
begin
  // 阈值收缩：若当前容量远超提示容量且超过阈值，缩容释放常驻堆，bytes.ops 单源 via ArraySetLengthNoRealloc inline 零拷贝
  if (Length(BktCnt) > HASH_SHRINK_THRESH) and (Length(BktCnt) > AHintCap * 4) then
  begin
    specialize ArraySetLengthNoReallocImpl<Integer>(BktCnt, BytesGrowCapacity(AHintCap));
    specialize ArraySetLengthNoReallocImpl<Integer>(BktPos, BytesGrowCapacity(AHintCap));
    specialize ArraySetLengthNoReallocImpl<Integer>(BktCur, BytesGrowCapacity(AHintCap));
  end;
  if (Length(SortedPtr) > HASH_SHRINK_THRESH) and (Length(SortedPtr) > AHintCap * 4) then
  begin
    specialize ArraySetLengthNoReallocImpl<Pointer>(SortedPtr, BytesGrowCapacity(AHintCap));
    specialize ArraySetLengthNoReallocImpl<Integer>(SortedIdx, BytesGrowCapacity(AHintCap));
  end;
  if (Length(SortedID) > HASH_SHRINK_THRESH) and (Length(SortedID) > AHintCap * 4) then
  begin
    specialize ArraySetLengthNoReallocImpl<UInt32>(SortedID, BytesGrowCapacity(AHintCap));
    specialize ArraySetLengthNoReallocImpl<Pointer>(SortedU32Ptr, BytesGrowCapacity(AHintCap));
  end;
end;

const
  HASH_REBUILD_POOL_SIZE = ARENA_POOL_SIZE; // alias 单源 64 via ARENA_POOL_SIZE (=BYTES_BUILDER_MIN_GROW 0→64), with LiveArena shared via BYTES_BUILDER_MIN_GROW；容量增长 0→32 via shr1 单源派生
  HASH_REBUILD_MAX_RETRIES = ARENA_POOL_MAX_RETRIES;

var
  GHashRebuildPool: array[0..ARENA_POOL_SIZE - 1] of THashRebuildArena;
  GHashRebuildPoolTop: Int32 = -1;
  GHashRebuildShutdown: Int32 = 0;
  GHashRebuildLock: Int32 = 0; // 池 critical section：claim+7 数组转移同锁（含 spill 槽，见 ArenaPoolLock）
  GHashRebuildFinalizeIdx: Integer;
  GHashRebuildSpill: THashRebuildArena;
  GHashRebuildSpillReady: Int32 = 0; // 0 empty,1 ready — Tail>64 单次堆溢出缓冲，阈值收缩后保留 64 容量，零额外池位避免 Clear 丢弃已扩容量，Burst尾抖动消除 via ManagedArrayMove inline 零拷贝 O(1) 单源，资源托管释放不丢

function HashRebuildArenaPoolCapacity: Integer; inline;
begin
  Result := HASH_REBUILD_POOL_SIZE;
end;

function HashRebuildArenaPoolTopSnapshot: Integer; inline;
begin
  Result := atomic_load(GHashRebuildPoolTop, mo_acquire);
end;

function ArenaPoolAcquireSlot(var ATop: Int32; var AShutdown: Int32; out AIdx: Int32): Boolean; inline;
var LTop, LExp: Int32; LRetry: Integer;
begin
  Result := False;
  if atomic_load(AShutdown, mo_acquire) <> 0 then Exit;
  LTop := atomic_load(ATop, mo_acquire);
  LRetry := 0;
  while LTop >= 0 do
  begin
    if atomic_load(AShutdown, mo_acquire) <> 0 then Exit;
    LExp := LTop;
    if atomic_compare_exchange_strong(ATop, LExp, LTop - 1, mo_seq_cst, mo_seq_cst) then
    begin
      AIdx := LTop;
      Exit(True);
    end;
    Inc(LRetry);
    if LRetry >= ARENA_POOL_MAX_RETRIES then Exit(False);
    cpu_pause;
    LTop := LExp;
  end;
end;

function ArenaPoolRecycleSlot(var ATop: Int32; var AShutdown: Int32; out AIdx: Int32): Boolean; inline;
var LTop, LExp: Int32; LRetry: Integer;
begin
  Result := False;
  if atomic_load(AShutdown, mo_acquire) <> 0 then Exit;
  LTop := atomic_load(ATop, mo_acquire);
  LRetry := 0;
  while LTop < ARENA_POOL_SIZE - 1 do
  begin
    if atomic_load(AShutdown, mo_acquire) <> 0 then Exit;
    LExp := LTop;
    if atomic_compare_exchange_strong(ATop, LExp, LTop + 1, mo_seq_cst, mo_seq_cst) then
    begin
      AIdx := LTop + 1;
      atomic_thread_fence(mo_release);
      Exit(True);
    end;
    Inc(LRetry);
    if LRetry >= ARENA_POOL_MAX_RETRIES then Exit(False);
    cpu_pause;
    LTop := LExp;
  end;
end;

generic procedure ArenaPoolFinalizeImpl<T>(var APool: array of T; var ATop: Int32; var AShutdown: Int32; var AIdx: Integer); inline;
var LI: Integer;
begin
  // 只索引 + Clear，无 SetLength：open array 形参即可，静态 64 槽池与动态 arena 通吃
  atomic_store(AShutdown, Int32(1), mo_seq_cst);
  atomic_thread_fence(mo_seq_cst);
  for LI := 0 to ARENA_POOL_SIZE - 1 do
    APool[LI].Clear;
  AIdx := LI;
  atomic_store(ATop, Int32(-1), mo_seq_cst);
end;

procedure ArenaPoolLock(var ALock: Int32);
var LExp: Int32;
begin
  LExp := 0;
  while not atomic_compare_exchange_strong(ALock, LExp, Int32(1), mo_acquire, mo_acquire) do
  begin
    LExp := 0;
    cpu_pause;
  end;
end;

procedure ArenaPoolUnlock(var ALock: Int32); inline;
begin
  atomic_store(ALock, Int32(0), mo_release);
end;

function HashRebuildArenaAcquire(out AFromPool: Boolean): THashRebuildArena;
var LIdx: Int32; LExp: Int32;
begin
  AFromPool := False;
  Result.Clear;
  ArenaPoolLock(GHashRebuildLock);
  try
  if ArenaPoolAcquireSlot(GHashRebuildPoolTop, GHashRebuildShutdown, LIdx) then
  begin
    // 指针交换单源：7× ManagedArrayMovePtr inline 零拷贝 O(1) raw 指针拷贝避 7× 引用计数原子抖动，64并发零 Inc/Dec via ARENA_POOL_SIZE 64 单源，资源所有权转移不丢（bytes.ops 单源）
    ManagedArrayMovePtr(Result.BktCnt, GHashRebuildPool[LIdx].BktCnt);
    ManagedArrayMovePtr(Result.BktPos, GHashRebuildPool[LIdx].BktPos);
    ManagedArrayMovePtr(Result.BktCur, GHashRebuildPool[LIdx].BktCur);
    ManagedArrayMovePtr(Result.SortedPtr, GHashRebuildPool[LIdx].SortedPtr);
    ManagedArrayMovePtr(Result.SortedIdx, GHashRebuildPool[LIdx].SortedIdx);
    ManagedArrayMovePtr(Result.SortedID, GHashRebuildPool[LIdx].SortedID);
    ManagedArrayMovePtr(Result.SortedU32Ptr, GHashRebuildPool[LIdx].SortedU32Ptr);
    AFromPool := True;
    Exit;
  end;
  // Tail>64 溢出缓冲复用：池满回退保留的阈值收缩后 64 容量，突发 16k 后小表零堆分配，inline 零拷贝 O(1) 7× ManagedArrayMovePtr 单源，资源托管不丢
  LExp := 1;
  if atomic_compare_exchange_strong(GHashRebuildSpillReady, LExp, 0, mo_seq_cst, mo_seq_cst) then
  begin
    ManagedArrayMovePtr(Result.BktCnt, GHashRebuildSpill.BktCnt);
    ManagedArrayMovePtr(Result.BktPos, GHashRebuildSpill.BktPos);
    ManagedArrayMovePtr(Result.BktCur, GHashRebuildSpill.BktCur);
    ManagedArrayMovePtr(Result.SortedPtr, GHashRebuildSpill.SortedPtr);
    ManagedArrayMovePtr(Result.SortedIdx, GHashRebuildSpill.SortedIdx);
    ManagedArrayMovePtr(Result.SortedID, GHashRebuildSpill.SortedID);
    ManagedArrayMovePtr(Result.SortedU32Ptr, GHashRebuildSpill.SortedU32Ptr);
    // 溢出复用视为池化零堆抖动，但 FromPool 保持 False 以区分 Tail>64 单次堆路径计量
  end;
  finally
    ArenaPoolUnlock(GHashRebuildLock);
  end;
end;

procedure HashRebuildArenaRecycle(var AArena: THashRebuildArena);
var LIdx: Int32;
begin
  // 阈值收缩防常驻堆：突发 16k 后小表复用触发收缩，保留 64 槽 via ARENA_POOL_SIZE (=BYTES_BUILDER_MIN_GROW) lock-free 池化 Burst64 均摊，超阈值释放不丢，inline 零拷贝 via ARENA_POOL single source
  AArena.MaybeShrink(32);
  if (Length(AArena.BktCnt) = 0) and (Length(AArena.SortedPtr) = 0) and (Length(AArena.SortedID) = 0) then
  begin
    AArena.Clear;
    Exit;
  end;
  ArenaPoolLock(GHashRebuildLock);
  try
  if ArenaPoolRecycleSlot(GHashRebuildPoolTop, GHashRebuildShutdown, LIdx) then
  begin
    // 指针交换单源：7× ManagedArrayMovePtr inline 零拷贝 O(1) raw 指针拷贝避 7× 引用计数原子抖动，容量保留复用 Burst均摊，资源所有权转移不丢
    ManagedArrayMovePtr(GHashRebuildPool[LIdx].BktCnt, AArena.BktCnt);
    ManagedArrayMovePtr(GHashRebuildPool[LIdx].BktPos, AArena.BktPos);
    ManagedArrayMovePtr(GHashRebuildPool[LIdx].BktCur, AArena.BktCur);
    ManagedArrayMovePtr(GHashRebuildPool[LIdx].SortedPtr, AArena.SortedPtr);
    ManagedArrayMovePtr(GHashRebuildPool[LIdx].SortedIdx, AArena.SortedIdx);
    ManagedArrayMovePtr(GHashRebuildPool[LIdx].SortedID, AArena.SortedID);
    ManagedArrayMovePtr(GHashRebuildPool[LIdx].SortedU32Ptr, AArena.SortedU32Ptr);
    Exit;
  end;
  if atomic_load(GHashRebuildShutdown, mo_acquire) <> 0 then
  begin
    AArena.Clear;
    Exit;
  end;
  // 池满回退阈值保留：已 MaybeShrink(32) 截断 16k→64，容量保留避免 Clear 直接丢弃已扩容量导致小表每次重建堆分配；Tail>64 单次堆溢出缓冲 via GHashRebuildSpill 7× ManagedArrayMove inline 零拷贝 O(1) 单源，资源托管释放不丢，Burst尾抖动消除
  begin
    LIdx := 0;
    if atomic_compare_exchange_strong(GHashRebuildSpillReady, LIdx, 1, mo_seq_cst, mo_seq_cst) then
    begin
      ManagedArrayMovePtr(GHashRebuildSpill.BktCnt, AArena.BktCnt);
      ManagedArrayMovePtr(GHashRebuildSpill.BktPos, AArena.BktPos);
      ManagedArrayMovePtr(GHashRebuildSpill.BktCur, AArena.BktCur);
      ManagedArrayMovePtr(GHashRebuildSpill.SortedPtr, AArena.SortedPtr);
      ManagedArrayMovePtr(GHashRebuildSpill.SortedIdx, AArena.SortedIdx);
      ManagedArrayMovePtr(GHashRebuildSpill.SortedID, AArena.SortedID);
      ManagedArrayMovePtr(GHashRebuildSpill.SortedU32Ptr, AArena.SortedU32Ptr);
      Exit;
    end;
  end;
  // 溢出缓冲亦满：阈值内小容量经 MaybeShrink 已保留 64，无需二次分配；托管释放不丢 via Clear，Tail>64 单次堆 O(1) inline 零拷贝 via bytes.ops 单源
  finally
    ArenaPoolUnlock(GHashRebuildLock);
  end;
  AArena.Clear;
end;

initialization
  GHashRebuildPoolTop := -1;
  GHashRebuildShutdown := 0;

finalization
  // 单源池化通用抽象 finalization：shutdown 截断并发 Acquire/Recycle，再 seq_cst fence 后循环 Clear 托管释放不丢，容量 ARENA_POOL_SIZE 单源自适应 inline 零拷贝；溢出缓冲同步托管释放不丢 Tail>64
  specialize ArenaPoolFinalizeImpl<THashRebuildArena>(GHashRebuildPool, GHashRebuildPoolTop, GHashRebuildShutdown, GHashRebuildFinalizeIdx);
  GHashRebuildSpill.Clear;
  atomic_store(GHashRebuildSpillReady, Int32(0), mo_seq_cst);

end.
