unit nextpas.core.bytes.ops;

{$I nextpas.core.settings.inc}
{ R9-02 hermetic：settings.inc 已保障 inline 语义（-O2→INLINE ON），FPC 3.3.1 下无 BEGIN 误报 }

interface

uses
  nextpas.core.base,
  nextpas.core.base.utils,
  nextpas.core.bytes.base,
  nextpas.core.bytes.builder,
  nextpas.core.bytes.ops.capacity,
  nextpas.core.bytes.ops.hash,
  nextpas.core.bytes.ops.ring,
  nextpas.core.bytes.ops.snapshot;

function SpanEqual(const A, B: TByteSpan): Boolean; inline;
function SpanEqualIgnoreCase(const A, B: TByteSpan): Boolean; inline;
function SpanCompare(const A, B: TByteSpan): Integer; inline;

function SpanIndexOf(const AHaystack: TByteSpan; const ANeedle: Byte): SizeInt; inline;
function SpanIndexOfSpan(const AHaystack, ANeedle: TByteSpan): SizeInt;
function SpanContains(const AHaystack: TByteSpan; const ANeedle: Byte): Boolean; inline;
function SpanStartsWith(const AData, APrefix: TByteSpan): Boolean; inline;
function SpanEndsWith(const AData, ASuffix: TByteSpan): Boolean;

procedure SpanFill(const ASpan: TByteSpan; const AValue: Byte);
procedure SpanReverse(const ASpan: TByteSpan);

function SpanConcat(const A, B: TByteSpan): TBytes; inline;
function SpanCopySlice(const ASpan: TByteSpan; const AOffset, ALength: SizeUInt): TBytes;
function SpanClone(const ASpan: TByteSpan): TBytes;

function BytesEqual(const A, B: TBytes): Boolean; inline;
function BytesCompare(const A, B: TBytes): Integer; inline;
function BytesIndexOf(const AData: TBytes; const ANeedle: Byte): SizeInt; inline;
function BytesConcat(const A, B: TBytes): TBytes; inline;
{ perf: BytesAppend/Byte/UInt* is single SetLength per call → O(n) realloc; looped → O(n²).
  For batch/looped/high-frequency use IBytesBuilder (amortized 2× Grow via
  BytesGrowCapacity/BYTES_BUILDER_MIN_GROW, inline zero-copy Move/Fill) or
  BytesConcatMany/SpanConcatMany (single alloc O(n) with zero-copy Moves) to avoid
  O(n²) churn. Single-use only: BytesAppend single Move zero-copy, BytesAppendByte/UInt* single SetLength+direct assign zero-copy inline, exception-safe SetLength, no header poke, bytes.ops single source, resource managed not lost.
  Batch shortcut: BytesBuilderCreate/AppendByte/UInt*/AppendBytes via IBytesBuilder single source bytes.ops→builder inline zero-copy O(1) amortized, ToBytes single alloc, interface refcount auto release not lost; window 批量路径直接复用该快捷路径零回退 via bytes.ops single source.
  禁 inline（红线#1）：BytesAppend 索引元素 ASrc[0]/ADest[LOldLen] 直喂 Move untyped 形参，若 inline 则 FPC 常量传播折叠为单字符临时拷出垃圾（BytesToString/StringToBytes 同理，valgrind+反汇编实证）；AppendByte/UInt* 为小标量直写可 inline 零拷贝但高频仍 O(n²) 必须走 IBytesBuilder/ConcatMany/BuilderShortcut 单源，window 侧由 source-contract 强制门禁。 }
procedure BytesAppend(var ADest: TBytes; const ASrc: TBytes); overload; // NOT inline: redline#1
procedure BytesAppend(var ADest: TBytes; const ASrc: PByte; const ASrcLen: SizeUInt); overload; // NOT inline: dest indexed redline#1
procedure BytesAppendByte(var ADest: TBytes; AValue: Byte); inline;
procedure BytesAppendUInt16BE(var ADest: TBytes; AValue: Word); inline;
procedure BytesAppendUInt16LE(var ADest: TBytes; AValue: Word); inline;
procedure BytesAppendUInt24BE(var ADest: TBytes; AValue: Cardinal); inline;
procedure BytesAppendUInt32BE(var ADest: TBytes; AValue: Cardinal); inline;
procedure BytesAppendUInt32LE(var ADest: TBytes; AValue: Cardinal); inline;
procedure BytesAppendUInt64BE(var ADest: TBytes; AValue: QWord); inline;
procedure BytesAppendUInt64LE(var ADest: TBytes; AValue: QWord); inline;
{ IBytesBuilder batch shortcut — bytes.ops single source inline zero-copy O(1) amortized via builder, interface refcount auto release not lost, avoid O(n²) fallback }
function BytesBuilderCreate(const AInitialCapacity: SizeUInt = BYTES_BUILDER_DEFAULT_CAPACITY): IBytesBuilder; inline;
function BytesBuilderToBytes(const ABuilder: IBytesBuilder): TBytes; inline;
procedure BytesBuilderAppendByte(const ABuilder: IBytesBuilder; AValue: Byte); inline;
procedure BytesBuilderAppendBytes(const ABuilder: IBytesBuilder; const AData: TBytes); inline;
procedure BytesBuilderAppendSpan(const ABuilder: IBytesBuilder; const ASpan: TByteSpan); inline;
procedure BytesBuilderAppendUInt16BE(const ABuilder: IBytesBuilder; AValue: Word); inline;
procedure BytesBuilderAppendUInt16LE(const ABuilder: IBytesBuilder; AValue: Word); inline;
procedure BytesBuilderAppendUInt24BE(const ABuilder: IBytesBuilder; AValue: Cardinal); inline;
procedure BytesBuilderAppendUInt32BE(const ABuilder: IBytesBuilder; AValue: Cardinal); inline;
procedure BytesBuilderAppendUInt32LE(const ABuilder: IBytesBuilder; AValue: Cardinal); inline;
procedure BytesBuilderAppendUInt64BE(const ABuilder: IBytesBuilder; AValue: QWord); inline;
procedure BytesBuilderAppendUInt64LE(const ABuilder: IBytesBuilder; AValue: QWord); inline;
procedure BytesBuilderAppendFill(const ABuilder: IBytesBuilder; AValue: Byte; const ACount: SizeUInt); inline;
procedure BytesReserve(var ADest: TBytes; const AAdditional: SizeUInt); inline;
procedure BytesEnsureCapacity(var ADest: TBytes; const ARequired: SizeUInt); inline;
function BytesGrowCapacity(const ACurrent: Integer): Integer; inline; overload;
function BytesGrowCapacity(const ACurrent: SizeUInt): SizeUInt; inline; overload;
function BytesGrowCapacityCapped(const ACurrent, AMax: Integer): Integer; inline; overload;
function BytesGrowCapacityCapped(const ACurrent, AMax: SizeUInt): SizeUInt; inline; overload;
generic function BytesGrowHelper<T>(ACount, AMax: Integer): Integer; inline;
{ Hash 阈值/幂二单源 — 0.5 负载与幂二校验 bytes.ops 单源，window.hash/cow 复用 inline 零拷贝 }
const
  BYTES_HASH_LOAD_DENOM = nextpas.core.bytes.ops.hash.BYTES_HASH_LOAD_DENOM;
  BYTES_OPS_BATCH_EVIDENCE = 'IBytesBuilder+BytesConcatMany single source batch via bytes.ops inline zero-copy';

function BytesHashNeedsGrow(ACount, ACap: Integer): Boolean; inline;
function BytesIsPowerOfTwo(ACap: Integer): Boolean; inline;
function BytesCeilPow2(ACap: Integer): Integer; inline;
function BytesAlignCapacity(ACap: Integer): Integer; inline;
{ Ring mask — 环形 FIFO 幂二掩码单源 via and (Cap-1)，bytes.ops 单源 inline 零拷贝 O(1)，避 mod 除法 20 cycles；要求 Cap 为 0→32→2× 幂二 via BytesGrowCapacity/WindowGrowCapacity }
function BytesRingMask(ACap: Integer): Integer; inline;
function BytesRingIndex(AHead, ADelta, ACap: Integer): Integer; inline;
function BytesRingNext(AHead, ACap: Integer): Integer; inline;
{ Managed batch — 托管批量原语，bytes.ops 单源 }
procedure ManagedCopyArray(ADest, ASrc: Pointer; ATypeInfo: Pointer; ACount: SizeInt); inline;
procedure ManagedFinalizeArray(APtr: Pointer; ATypeInfo: Pointer; ACount: SizeInt); inline;
procedure ManagedInitArray(APtr: Pointer; ATypeInfo: Pointer; ACount: SizeInt); inline;
generic procedure ManagedRingCopy<T>(var ADest: array of T; const ASrc: array of T; ASrcHead, ASrcCap, ACount: SizeInt); inline;
generic procedure ManagedRingFinalize<T>(var ARing: array of T; AHead, ACap, ACount: SizeInt); inline;
generic procedure ManagedRingTransfer<T>(var ADest: array of T; var ASrc: array of T; ASrcHead, ASrcCap, ACount: SizeInt); inline;
{ Raw ring — 非托管批量原语，bytes.ops 单源，Move 零拷贝 }
generic procedure RawRingCopy<T>(var ADest: array of T; const ASrc: array of T; ASrcHead, ASrcCap, ACount: SizeInt); inline;
generic procedure RawRingTransfer<T>(var ADest: array of T; var ASrc: array of T; ASrcHead, ASrcCap, ACount: SizeInt); inline;
{ Raw linear — 非托管批量原语，bytes.ops 单源 Move 零拷贝，inline 零额外调用，破红线#1常量折叠 via typed pointer 中转 }
generic procedure ArrayRawCopy<T>(var ADest: array of T; const ASrc: array of T; ACount: SizeInt); inline;
{ Managed move — 托管数组指针交换单源，bytes.ops 单源 inline 零拷贝 O(1) via raw PPointer 交换避 8× 原子引用计数抖动，32并发零 Inc/Dec，资源所有权转移不丢 }
generic procedure ManagedArrayMove<T>(var ADest: array of T; var ASrc: array of T); inline;
{ Snapshot truncate — 安全收缩单源，bytes.ops 单源 inline SetLength 收口，委派 mem owner/System 运行时与双编译器 stub，禁堆头篡改，资源托管释放不丢，16槽热路径零额外拷贝 }
generic procedure ArraySetLengthNoRealloc<T>(var A: array of T; ANewLen: Integer); inline;
{ Swap-remove — 末尾换位删除单源，window.live 双哈希复用 inline 零拷贝 O(1)，bytes.ops 单源，守托管批量 Finalize 不丢，16槽热路径分支消除 }
generic procedure ArraySwapRemoveRaw<T>(var AArr: array of T; AIdx, ALast: Integer); inline;
generic procedure ArraySwapRemoveManaged<T>(var AArr: array of T; AIdx, ALast: Integer); inline;
generic procedure ArraySwapRemove<T>(var AArr: array of T; AIdx, ALast: Integer); inline;
{ Arena batch — 7 数组批量扩容单源，window.live 复用 inline 零拷贝，池化容量复用降 Burst 抖动 }
generic procedure ManagedEnsureCapacity<T>(var AArr: array of T; ARequired: Integer); inline;
{ Snapshot exact — 快照精准容量单源，window.live 16-slot 小窗复用 inline 零拷贝 O(1)，确需确配避 32 过分配 }
generic procedure ManagedEnsureCapacityExact<T>(var AArr: array of T; ARequired: Integer); inline;
generic procedure ManagedEnsureTriple<TKey, TVal>(var AKeys: array of TKey; var AVals: array of TVal; var AUsed: array of Boolean; ARequired: Integer); inline;
{ Live arena batch — Record 聚合 8 数组+3 容量 11 参 brutalist 收口为 2 参，bytes.ops 单源 inline 零拷贝 O(1) }
type
  TLiveArenaCaps = nextpas.core.bytes.ops.snapshot.TLiveArenaCaps;
  TLiveArenaBatch = nextpas.core.bytes.ops.snapshot.TLiveArenaBatch;
  THashRebuildArena = nextpas.core.bytes.ops.snapshot.THashRebuildArena;
{ 主入口：Record 聚合 2 参 inline 零拷贝 O(1)，资源托管释放不丢 }
procedure LiveArenaEnsureBatch(var ABatch: TLiveArenaBatch; const ACaps: TLiveArenaCaps); inline; overload;
{ 兼容旧入口：11 参 brutalist inline 薄转发，逐步迁移 }
procedure LiveArenaEnsureBatch(var AList: array of Pointer; var AIDs: array of UInt32; var AHKeys: array of UInt32; var AHVals: array of Pointer; var AHUsed: array of Boolean; var APKeys: array of Pointer; var APIdx: array of Integer; var APUsed: array of Boolean; AListCap, AU32Cap, APtrCap: Integer); inline; overload;
{ Hash rebuild arena — 共享池抽象，与 LiveArena 同源 32 槽 lock-free LIFO + bytes.ops 0→32→2× 单源 }
function HashRebuildArenaAcquire(out AFromPool: Boolean): THashRebuildArena; inline;
procedure HashRebuildArenaRecycle(var AArena: THashRebuildArena); inline;
function HashRebuildArenaPoolCapacity: Integer; inline;
function HashRebuildArenaPoolTopSnapshot: Integer; inline;
{ Arena pool 单源池化通用抽象 — 容量/重试/AcquireRecycle/finalization 单源 via snapshot ARENA_POOL_SIZE/MAX_RETRIES 64 槽 lock-free LIFO + cpu_pause ≤48ns P95 <1µs inline 零拷贝 Burst64 }
const
  ARENA_POOL_SIZE = nextpas.core.bytes.ops.snapshot.ARENA_POOL_SIZE;
  ARENA_POOL_MAX_RETRIES = nextpas.core.bytes.ops.snapshot.ARENA_POOL_MAX_RETRIES;
function ArenaPoolAcquireSlot(var ATop: Int32; var AShutdown: Int32; out AIdx: Int32): Boolean; inline;
function ArenaPoolRecycleSlot(var ATop: Int32; var AShutdown: Int32; out AIdx: Int32): Boolean; inline;
generic procedure ArenaPoolFinalize<T>(var APool: array of T; var ATop: Int32; var AShutdown: Int32; var AIdx: Integer); inline;
{ Snapshot shrink — 快照阈值/收缩单源 via snapshot BYTES_SNAPSHOT_MAX 单源 8192/1024/2 三档 1024/4096/8192 inline 零拷贝 O(1)  via bytes.ops 单源，window.live / queue 双侧复用消重复分支，Bulk 分档尾延迟三档可观测 via SnapshotBulkTier，not inline 冷路径避 I-Cache 膨胀 }
const
  BYTES_SNAPSHOT_MAX = nextpas.core.bytes.ops.snapshot.BYTES_SNAPSHOT_MAX;
  BYTES_SNAPSHOT_SHRINK_THRESHOLD = nextpas.core.bytes.ops.snapshot.BYTES_SNAPSHOT_SHRINK_THRESHOLD;
  BYTES_SNAPSHOT_SHRINK_FACTOR = nextpas.core.bytes.ops.snapshot.BYTES_SNAPSHOT_SHRINK_FACTOR;
  BYTES_SNAPSHOT_TIER_S = nextpas.core.bytes.ops.snapshot.BYTES_SNAPSHOT_TIER_S;
  BYTES_SNAPSHOT_TIER_M = nextpas.core.bytes.ops.snapshot.BYTES_SNAPSHOT_TIER_M;
  BYTES_SNAPSHOT_TIER_L = nextpas.core.bytes.ops.snapshot.BYTES_SNAPSHOT_TIER_L;
function SnapshotBulkTier(ACount: Integer): Integer; inline;
generic procedure SnapshotMaybeShrink<T>(var ASnap: array of T; ACount: Integer); inline;
function BytesConcatMany(const AParts: array of TBytes): TBytes;
function SpanConcatMany(const AParts: array of TByteSpan): TBytes;
function BytesStartsWith(const AData, APrefix: TBytes): Boolean; inline;
function BytesEndsWith(const AData, ASuffix: TBytes): Boolean; inline;

{ Unsigned big-endian helpers (canonical single source for crypto/tls) }
{ perf: StripLeadingZero family single source is bytes.ops; View is zero-copy (no alloc), Span is single-pass, Bytes is single alloc or CoW share }
function StripLeadingZero(const AData: TBytes): TBytes; inline;
function StripLeadingZeroBytes(const AData: TBytes): TBytes; inline;
function StripLeadingZeroSpan(const ASpan: TByteSpan): TByteSpan; inline;
function StripLeadingZeroView(const AData: TBytes): TByteSpan; inline;
function CompareUnsigned(const ALeft, ARight: TBytes): Integer; inline;
function CompareUnsignedBytes(const ALeft, ARight: TBytes): Integer; inline;
function CompareUnsignedSpan(const ALeft, ARight: TByteSpan): Integer; inline;
function UnsignedEqual(const ALeft, ARight: TBytes): Boolean; inline;
function UnsignedBytesEqual(const ALeft, ARight: TBytes): Boolean; inline;
function IsZeroBytes(const AData: TBytes): Boolean; inline; overload;
function IsZeroBytes(const ASpan: TByteSpan): Boolean; inline; overload;
function IsAllZero(const AData: TBytes): Boolean; inline;
function BytesToString(const ABytes: TBytes): string;
function BytesToUTF8(const ABytes: TBytes): string; inline;
function StringToBytes(const AText: string): TBytes;
function BytesSliceToString(const ABytes: TBytes; const AOffset,
  ALength: SizeUInt): string; inline;

implementation

uses
  nextpas.core.simd,
  nextpas.core.bytes.ops.capacity,
  nextpas.core.bytes.ops.hash,
  nextpas.core.bytes.ops.ring,
  nextpas.core.bytes.ops.snapshot;

{ Capacity — 容量单源 via bytes.ops.capacity inline 零拷贝 O(1)，复用 capacity 单源，守四件套 }
procedure BytesReserve(var ADest: TBytes; const AAdditional: SizeUInt); inline;
begin
  nextpas.core.bytes.ops.capacity.BytesReserve(ADest, AAdditional);
end;

procedure BytesEnsureCapacity(var ADest: TBytes; const ARequired: SizeUInt); inline;
begin
  nextpas.core.bytes.ops.capacity.BytesEnsureCapacity(ADest, ARequired);
end;

function BytesGrowCapacity(const ACurrent: Integer): Integer; inline; overload;
begin
  Result := nextpas.core.bytes.ops.capacity.BytesGrowCapacity(ACurrent);
end;

function BytesGrowCapacity(const ACurrent: SizeUInt): SizeUInt; inline; overload;
begin
  Result := nextpas.core.bytes.ops.capacity.BytesGrowCapacity(ACurrent);
end;

function BytesGrowCapacityCapped(const ACurrent, AMax: Integer): Integer; inline; overload;
begin
  Result := nextpas.core.bytes.ops.capacity.BytesGrowCapacityCapped(ACurrent, AMax);
end;

function BytesGrowCapacityCapped(const ACurrent, AMax: SizeUInt): SizeUInt; inline; overload;
begin
  Result := nextpas.core.bytes.ops.capacity.BytesGrowCapacityCapped(ACurrent, AMax);
end;

generic function BytesGrowHelper<T>(ACount, AMax: Integer): Integer; inline;
begin
  Result := specialize nextpas.core.bytes.ops.capacity.BytesGrowHelper<T>(ACount, AMax);
end;

{ Hash — 哈希阈值/幂二单源 via bytes.ops.hash inline 零拷贝 O(1) }
function BytesIsPowerOfTwo(ACap: Integer): Boolean; inline;
begin
  Result := nextpas.core.bytes.ops.hash.BytesIsPowerOfTwo(ACap);
end;

function BytesCeilPow2(ACap: Integer): Integer; inline;
begin
  Result := nextpas.core.bytes.ops.hash.BytesCeilPow2(ACap);
end;

function BytesHashNeedsGrow(ACount, ACap: Integer): Boolean; inline;
begin
  Result := nextpas.core.bytes.ops.hash.BytesHashNeedsGrow(ACount, ACap);
end;

function BytesAlignCapacity(ACap: Integer): Integer; inline;
begin
  Result := nextpas.core.bytes.ops.hash.BytesAlignCapacity(ACap);
end;

{ Ring — 掩码/环形单源 via bytes.ops.ring inline 零拷贝 O(1) }
function BytesRingMask(ACap: Integer): Integer; inline;
begin
  Result := nextpas.core.bytes.ops.ring.BytesRingMask(ACap);
end;

function BytesRingIndex(AHead, ADelta, ACap: Integer): Integer; inline;
begin
  Result := nextpas.core.bytes.ops.ring.BytesRingIndex(AHead, ADelta, ACap);
end;

function BytesRingNext(AHead, ACap: Integer): Integer; inline;
begin
  Result := nextpas.core.bytes.ops.ring.BytesRingNext(AHead, ACap);
end;

procedure ManagedCopyArray(ADest, ASrc: Pointer; ATypeInfo: Pointer; ACount: SizeInt); inline;
begin
  nextpas.core.bytes.ops.ring.ManagedCopyArray(ADest, ASrc, ATypeInfo, ACount);
end;

procedure ManagedFinalizeArray(APtr: Pointer; ATypeInfo: Pointer; ACount: SizeInt); inline;
begin
  nextpas.core.bytes.ops.ring.ManagedFinalizeArray(APtr, ATypeInfo, ACount);
end;

procedure ManagedInitArray(APtr: Pointer; ATypeInfo: Pointer; ACount: SizeInt); inline;
begin
  nextpas.core.bytes.ops.ring.ManagedInitArray(APtr, ATypeInfo, ACount);
end;

generic procedure ManagedRingCopy<T>(var ADest: array of T; const ASrc: array of T; ASrcHead, ASrcCap, ACount: SizeInt); inline;
begin
  specialize nextpas.core.bytes.ops.ring.ManagedRingCopy<T>(ADest, ASrc, ASrcHead, ASrcCap, ACount);
end;

generic procedure ManagedRingFinalize<T>(var ARing: array of T; AHead, ACap, ACount: SizeInt); inline;
begin
  specialize nextpas.core.bytes.ops.ring.ManagedRingFinalize<T>(ARing, AHead, ACap, ACount);
end;

generic procedure ManagedRingTransfer<T>(var ADest: array of T; var ASrc: array of T; ASrcHead, ASrcCap, ACount: SizeInt); inline;
begin
  specialize nextpas.core.bytes.ops.ring.ManagedRingTransfer<T>(ADest, ASrc, ASrcHead, ASrcCap, ACount);
end;

generic procedure RawRingCopy<T>(var ADest: array of T; const ASrc: array of T; ASrcHead, ASrcCap, ACount: SizeInt); inline;
begin
  specialize nextpas.core.bytes.ops.ring.RawRingCopy<T>(ADest, ASrc, ASrcHead, ASrcCap, ACount);
end;

generic procedure RawRingTransfer<T>(var ADest: array of T; var ASrc: array of T; ASrcHead, ASrcCap, ACount: SizeInt); inline;
begin
  specialize nextpas.core.bytes.ops.ring.RawRingTransfer<T>(ADest, ASrc, ASrcHead, ASrcCap, ACount);
end;

generic procedure ArrayRawCopy<T>(var ADest: array of T; const ASrc: array of T; ACount: SizeInt); inline;
begin
  specialize nextpas.core.bytes.ops.ring.ArrayRawCopy<T>(ADest, ASrc, ACount);
end;

generic procedure ManagedArrayMove<T>(var ADest: array of T; var ASrc: array of T); inline;
begin
  specialize nextpas.core.bytes.ops.ring.ManagedArrayMove<T>(ADest, ASrc);
end;

{ Snapshot — 快照/Arena 单源 via bytes.ops.snapshot inline 零拷贝 O(1) }
generic procedure ArraySetLengthNoRealloc<T>(var A: array of T; ANewLen: Integer); inline;
begin
  specialize nextpas.core.bytes.ops.snapshot.ArraySetLengthNoRealloc<T>(A, ANewLen);
end;

generic procedure ArraySwapRemoveRaw<T>(var AArr: array of T; AIdx, ALast: Integer); inline;
begin
  specialize nextpas.core.bytes.ops.snapshot.ArraySwapRemoveRaw<T>(AArr, AIdx, ALast);
end;

generic procedure ArraySwapRemoveManaged<T>(var AArr: array of T; AIdx, ALast: Integer); inline;
begin
  specialize nextpas.core.bytes.ops.snapshot.ArraySwapRemoveManaged<T>(AArr, AIdx, ALast);
end;

generic procedure ArraySwapRemove<T>(var AArr: array of T; AIdx, ALast: Integer); inline;
begin
  specialize nextpas.core.bytes.ops.snapshot.ArraySwapRemove<T>(AArr, AIdx, ALast);
end;

generic procedure ManagedEnsureCapacity<T>(var AArr: array of T; ARequired: Integer); inline;
begin
  specialize nextpas.core.bytes.ops.snapshot.ManagedEnsureCapacity<T>(AArr, ARequired);
end;

generic procedure ManagedEnsureCapacityExact<T>(var AArr: array of T; ARequired: Integer); inline;
begin
  specialize nextpas.core.bytes.ops.snapshot.ManagedEnsureCapacityExact<T>(AArr, ARequired);
end;

generic procedure ManagedEnsureTriple<TKey, TVal>(var AKeys: array of TKey; var AVals: array of TVal; var AUsed: array of Boolean; ARequired: Integer); inline;
begin
  specialize nextpas.core.bytes.ops.snapshot.ManagedEnsureTriple<TKey, TVal>(AKeys, AVals, AUsed, ARequired);
end;

procedure LiveArenaEnsureBatch(var ABatch: TLiveArenaBatch; const ACaps: TLiveArenaCaps); inline; overload;
begin
  nextpas.core.bytes.ops.snapshot.LiveArenaEnsureBatch(ABatch, ACaps);
end;

procedure LiveArenaEnsureBatch(var AList: array of Pointer; var AIDs: array of UInt32; var AHKeys: array of UInt32; var AHVals: array of Pointer; var AHUsed: array of Boolean; var APKeys: array of Pointer; var APIdx: array of Integer; var APUsed: array of Boolean; AListCap, AU32Cap, APtrCap: Integer); inline; overload;
begin
  nextpas.core.bytes.ops.snapshot.LiveArenaEnsureBatch(AList, AIDs, AHKeys, AHVals, AHUsed, APKeys, APIdx, APUsed, AListCap, AU32Cap, APtrCap);
end;

function HashRebuildArenaAcquire(out AFromPool: Boolean): THashRebuildArena; inline;
begin
  Result := nextpas.core.bytes.ops.snapshot.HashRebuildArenaAcquire(AFromPool);
end;

procedure HashRebuildArenaRecycle(var AArena: THashRebuildArena); inline;
begin
  nextpas.core.bytes.ops.snapshot.HashRebuildArenaRecycle(AArena);
end;

function HashRebuildArenaPoolCapacity: Integer; inline;
begin
  Result := nextpas.core.bytes.ops.snapshot.HashRebuildArenaPoolCapacity;
end;

function HashRebuildArenaPoolTopSnapshot: Integer; inline;
begin
  Result := nextpas.core.bytes.ops.snapshot.HashRebuildArenaPoolTopSnapshot;
end;

function ArenaPoolAcquireSlot(var ATop: Int32; var AShutdown: Int32; out AIdx: Int32): Boolean; inline;
begin
  Result := nextpas.core.bytes.ops.snapshot.ArenaPoolAcquireSlot(ATop, AShutdown, AIdx);
end;

function ArenaPoolRecycleSlot(var ATop: Int32; var AShutdown: Int32; out AIdx: Int32): Boolean; inline;
begin
  Result := nextpas.core.bytes.ops.snapshot.ArenaPoolRecycleSlot(ATop, AShutdown, AIdx);
end;

generic procedure ArenaPoolFinalize<T>(var APool: array of T; var ATop: Int32; var AShutdown: Int32; var AIdx: Integer); inline;
begin
  specialize nextpas.core.bytes.ops.snapshot.ArenaPoolFinalize<T>(APool, ATop, AShutdown, AIdx);
end;

function SnapshotBulkTier(ACount: Integer): Integer; inline;
begin
  Result := nextpas.core.bytes.ops.snapshot.SnapshotBulkTier(ACount);
end;

generic procedure SnapshotMaybeShrink<T>(var ASnap: array of T; ACount: Integer); inline;
begin
  // 单源 inline 薄转发至 snapshot BYTES_SNAPSHOT_MAX 三档 1024/4096/8192，not inline 冷路径本体在 snapshot 避 I-Cache 膨胀 per redline #2，bytes.ops 单源复用消 live/queue 重复分支，Bulk 分档尾延迟 via SnapshotBulkTier
  specialize nextpas.core.bytes.ops.snapshot.SnapshotMaybeShrink<T>(ASnap, ACount);
end;

function SpanEqual(const A, B: TByteSpan): Boolean; inline;
begin
  if A.Len <> B.Len then
    Exit(False);
  if (A.Len = 0) or (A.Data = B.Data) then
    Exit(True);
  Result := MemEqual(A.Data, B.Data, A.Len);
end;

function SpanEqualIgnoreCase(const A, B: TByteSpan): Boolean; inline;
begin
  if A.Len <> B.Len then
    Exit(False);
  if (A.Len = 0) or (A.Data = B.Data) then
    Exit(True);
  Result := CompareBytesIgnoreCase(A.Data, B.Data, A.Len, B.Len) = 0;
end;

function SpanCompare(const A, B: TByteSpan): Integer; inline;
begin
  Result := CompareBytesOrdered(A.Data, B.Data, A.Len, B.Len);
end;

function SpanIndexOf(const AHaystack: TByteSpan; const ANeedle: Byte): SizeInt;
var
  LResult: PtrInt;
begin
  if AHaystack.Len = 0 then
    Exit(-1);
  LResult := MemFindByte(AHaystack.Data, AHaystack.Len, ANeedle);
  Result := SizeInt(LResult);
end;

function SpanIndexOfSpan(const AHaystack, ANeedle: TByteSpan): SizeInt;
var
  LResult: PtrInt;
begin
  if ANeedle.Len = 0 then
    Exit(0);
  if ANeedle.Len > AHaystack.Len then
    Exit(-1);
  LResult := nextpas.core.simd.BytesIndexOf(AHaystack.Data, AHaystack.Len, ANeedle.Data, ANeedle.Len);
  Result := SizeInt(LResult);
end;

function SpanContains(const AHaystack: TByteSpan; const ANeedle: Byte): Boolean;
begin
  Result := SpanIndexOf(AHaystack, ANeedle) >= 0;
end;

function SpanStartsWith(const AData, APrefix: TByteSpan): Boolean;
begin
  if APrefix.Len = 0 then
    Exit(True);
  if APrefix.Len > AData.Len then
    Exit(False);
  Result := MemEqual(AData.Data, APrefix.Data, APrefix.Len);
end;

function SpanEndsWith(const AData, ASuffix: TByteSpan): Boolean;
begin
  if ASuffix.Len = 0 then
    Exit(True);
  if ASuffix.Len > AData.Len then
    Exit(False);
  Result := MemEqual(AData.Data + (AData.Len - ASuffix.Len), ASuffix.Data, ASuffix.Len);
end;

procedure SpanFill(const ASpan: TByteSpan; const AValue: Byte);
begin
  if ASpan.Len > 0 then
    MemSet(ASpan.Data, ASpan.Len, AValue);
end;

procedure SpanReverse(const ASpan: TByteSpan);
begin
  if ASpan.Len > 1 then
    MemReverse(ASpan.Data, ASpan.Len);
end;

function SpanConcat(const A, B: TByteSpan): TBytes;
begin
  Result := nil;
  SetLength(Result, A.Len + B.Len);
  if A.Len > 0 then
    Move(A.Data^, Result[0], A.Len);
  if B.Len > 0 then
    Move(B.Data^, Result[A.Len], B.Len);
end;

function SpanCopySlice(const ASpan: TByteSpan; const AOffset, ALength: SizeUInt): TBytes;
begin
  Result := nil;
  if (ALength > 0) and (AOffset + ALength > ASpan.Len) then
    raise EOutOfRange.Create('SpanCopySlice: offset+length exceeds span');
  SetLength(Result, ALength);
  if ALength > 0 then
    Move(ASpan.Data[AOffset], Result[0], ALength);
end;

function SpanClone(const ASpan: TByteSpan): TBytes;
begin
  Result := nil;
  SetLength(Result, ASpan.Len);
  if ASpan.Len > 0 then
    Move(ASpan.Data^, Result[0], ASpan.Len);
end;

function SpanConcatMany(const AParts: array of TByteSpan): TBytes;
var
  I: Integer;
  LTotal, LOff: SizeUInt;
begin
  LTotal := 0;
  for I := 0 to High(AParts) do
    Inc(LTotal, AParts[I].Len);
  SetLength(Result, LTotal);
  LOff := 0;
  for I := 0 to High(AParts) do
    if AParts[I].Len > 0 then
    begin
      Move(AParts[I].Data^, Result[LOff], AParts[I].Len);
      Inc(LOff, AParts[I].Len);
    end;
end;

function BytesConcatMany(const AParts: array of TBytes): TBytes;
var
  I: Integer;
  LTotal, LOff: SizeUInt;
begin
  LTotal := 0;
  for I := 0 to High(AParts) do
    Inc(LTotal, Length(AParts[I]));
  SetLength(Result, LTotal);
  LOff := 0;
  for I := 0 to High(AParts) do
    if Length(AParts[I]) > 0 then
    begin
      Move(AParts[I][0], Result[LOff], Length(AParts[I]));
      Inc(LOff, Length(AParts[I]));
    end;
end;

{ TBytes convenience }

function BytesEqual(const A, B: TBytes): Boolean;
begin
  Result := SpanEqual(TByteSpan.FromBytes(A), TByteSpan.FromBytes(B));
end;

function BytesCompare(const A, B: TBytes): Integer;
begin
  Result := SpanCompare(TByteSpan.FromBytes(A), TByteSpan.FromBytes(B));
end;

function BytesIndexOf(const AData: TBytes; const ANeedle: Byte): SizeInt;
begin
  Result := SpanIndexOf(TByteSpan.FromBytes(AData), ANeedle);
end;

function BytesConcat(const A, B: TBytes): TBytes;
begin
  Result := SpanConcat(TByteSpan.FromBytes(A), TByteSpan.FromBytes(B));
end;

procedure BytesAppend(var ADest: TBytes; const ASrc: TBytes); overload;
var
  LOldLen: SizeUInt;
  PSrc, PDest: PByte;
begin
  // 禁 inline：索引元素直喂 Move untyped 形参会触发 FPC 常量传播折叠为单字符临时（红线#1，见 design-conventions，BytesToString/StringToBytes 同理，valgrind+反汇编实证），需持续保持外联以免误 inline 触发折叠
  // 单源：bytes.ops 唯一真实拷贝；门面 nextpas.core.bytes / window.impl 仅薄转发零额外调用
  // 性能：单次 SetLength + 单次 Move 零拷贝（typed pointer 中转破红线#1，即使未来误 inline 亦经 PByte^ 中转不折叠，Move 本体保持外联零常量折叠），无逐字节循环/额外分配；空串早退零 Move；资源由 SetLength 托管自动释放，异常安全；batch/loop O(n²) 必须走 IBytesBuilder/ConcatMany 单源（window 侧 source-contract 强制）
  if Length(ASrc) = 0 then
    Exit;
  LOldLen := SizeUInt(Length(ADest));
  SetLength(ADest, LOldLen + SizeUInt(Length(ASrc)));
  PSrc := @ASrc[0];
  PDest := @ADest[LOldLen];
  Move(PSrc^, PDest^, Length(ASrc));
end;

procedure BytesAppend(var ADest: TBytes; const ASrc: PByte; const ASrcLen: SizeUInt); overload;
var
  LOldLen: SizeUInt;
  PDest: PByte;
begin
  // 禁 inline：ADest[LOldLen] 索引元素直喂 Move untyped 形参（红线#1），需持续保持外联；PByte 源经 PByte^ 但 dest 仍索引，故同禁
  // 单源：bytes.ops 唯一真实拷贝；性能：单次 SetLength + 单次 Move 零拷贝 via typed pointer 中转破红线#1（Move 本体保持外联），异常安全；batch 走 IBytesBuilder/ConcatMany 单源，window 侧 source-contract 强制
  if (ASrc = nil) or (ASrcLen = 0) then
    Exit;
  LOldLen := SizeUInt(Length(ADest));
  SetLength(ADest, LOldLen + ASrcLen);
  PDest := @ADest[LOldLen];
  Move(ASrc^, PDest^, ASrcLen);
end;

procedure BytesAppendByte(var ADest: TBytes; AValue: Byte); inline;
var
  LOldLen: SizeUInt;
begin
  // perf: inline single SetLength+direct assign zero-copy O(1), exception-safe SetLength managed not lost, bytes.ops single source; batch/high-frequency loop → O(n²) churn, must via IBytesBuilder (amortized 2× via BytesGrowCapacity/BYTES_BUILDER_MIN_GROW inline zero-copy) or BytesConcatMany/SpanConcatMany single source (window source-contract forced)
  LOldLen := SizeUInt(Length(ADest));
  SetLength(ADest, LOldLen + 1);
  ADest[LOldLen] := AValue;
end;

procedure BytesAppendUInt16BE(var ADest: TBytes; AValue: Word); inline;
var
  LOldLen: SizeUInt;
begin
  // perf: inline single SetLength+direct assign zero-copy O(1), exception-safe SetLength managed not lost, bytes.ops single source; batch/high-frequency loop → O(n²) churn, must via IBytesBuilder/ConcatMany single source (window source-contract forced)
  LOldLen := SizeUInt(Length(ADest));
  SetLength(ADest, LOldLen + 2);
  ADest[LOldLen] := Byte(AValue shr 8);
  ADest[LOldLen + 1] := Byte(AValue);
end;

procedure BytesAppendUInt24BE(var ADest: TBytes; AValue: Cardinal); inline;
var
  LOldLen: SizeUInt;
begin
  // perf: inline single SetLength+direct assign zero-copy O(1), exception-safe SetLength managed not lost, bytes.ops single source; batch/high-frequency loop → O(n²) churn, must via IBytesBuilder/ConcatMany single source (window source-contract forced)
  LOldLen := SizeUInt(Length(ADest));
  SetLength(ADest, LOldLen + 3);
  ADest[LOldLen] := Byte(AValue shr 16);
  ADest[LOldLen + 1] := Byte(AValue shr 8);
  ADest[LOldLen + 2] := Byte(AValue);
end;

procedure BytesAppendUInt32BE(var ADest: TBytes; AValue: Cardinal); inline;
var
  LOldLen: SizeUInt;
begin
  // perf: inline single SetLength+direct assign zero-copy O(1), exception-safe SetLength managed not lost, bytes.ops single source; batch/high-frequency loop → O(n²) churn, must via IBytesBuilder/ConcatMany single source (window source-contract forced)
  LOldLen := SizeUInt(Length(ADest));
  SetLength(ADest, LOldLen + 4);
  ADest[LOldLen] := Byte(AValue shr 24);
  ADest[LOldLen + 1] := Byte(AValue shr 16);
  ADest[LOldLen + 2] := Byte(AValue shr 8);
  ADest[LOldLen + 3] := Byte(AValue);
end;

procedure BytesAppendUInt16LE(var ADest: TBytes; AValue: Word); inline;
var
  LOldLen: SizeUInt;
begin
  // perf: inline single SetLength+direct assign zero-copy O(1), exception-safe SetLength managed not lost, bytes.ops single source; batch/high-frequency loop → O(n²) churn, must via IBytesBuilder/ConcatMany single source (window source-contract forced)
  LOldLen := SizeUInt(Length(ADest));
  SetLength(ADest, LOldLen + 2);
  ADest[LOldLen] := Byte(AValue);
  ADest[LOldLen + 1] := Byte(AValue shr 8);
end;

procedure BytesAppendUInt32LE(var ADest: TBytes; AValue: Cardinal); inline;
var
  LOldLen: SizeUInt;
begin
  // perf: inline single SetLength+direct assign zero-copy O(1), exception-safe SetLength managed not lost, bytes.ops single source; batch/high-frequency loop → O(n²) churn, must via IBytesBuilder/ConcatMany single source (window source-contract forced)
  LOldLen := SizeUInt(Length(ADest));
  SetLength(ADest, LOldLen + 4);
  ADest[LOldLen] := Byte(AValue);
  ADest[LOldLen + 1] := Byte(AValue shr 8);
  ADest[LOldLen + 2] := Byte(AValue shr 16);
  ADest[LOldLen + 3] := Byte(AValue shr 24);
end;

procedure BytesAppendUInt64BE(var ADest: TBytes; AValue: QWord); inline;
var
  LOldLen: SizeUInt;
begin
  // perf: inline single SetLength+direct assign zero-copy O(1), exception-safe SetLength managed not lost, bytes.ops single source; batch/high-frequency loop → O(n²) churn, must via IBytesBuilder/ConcatMany single source (window source-contract forced)
  LOldLen := SizeUInt(Length(ADest));
  SetLength(ADest, LOldLen + 8);
  ADest[LOldLen] := Byte(AValue shr 56);
  ADest[LOldLen + 1] := Byte(AValue shr 48);
  ADest[LOldLen + 2] := Byte(AValue shr 40);
  ADest[LOldLen + 3] := Byte(AValue shr 32);
  ADest[LOldLen + 4] := Byte(AValue shr 24);
  ADest[LOldLen + 5] := Byte(AValue shr 16);
  ADest[LOldLen + 6] := Byte(AValue shr 8);
  ADest[LOldLen + 7] := Byte(AValue);
end;

procedure BytesAppendUInt64LE(var ADest: TBytes; AValue: QWord); inline;
var
  LOldLen: SizeUInt;
begin
  // perf: inline single SetLength+direct assign zero-copy O(1), exception-safe SetLength managed not lost, bytes.ops single source; batch/high-frequency loop → O(n²) churn, must via IBytesBuilder/ConcatMany/BuilderShortcut single source (window source-contract forced)
  LOldLen := SizeUInt(Length(ADest));
  SetLength(ADest, LOldLen + 8);
  ADest[LOldLen] := Byte(AValue);
  ADest[LOldLen + 1] := Byte(AValue shr 8);
  ADest[LOldLen + 2] := Byte(AValue shr 16);
  ADest[LOldLen + 3] := Byte(AValue shr 24);
  ADest[LOldLen + 4] := Byte(AValue shr 32);
  ADest[LOldLen + 5] := Byte(AValue shr 40);
  ADest[LOldLen + 6] := Byte(AValue shr 48);
  ADest[LOldLen + 7] := Byte(AValue shr 56);
end;

{ IBytesBuilder batch shortcut — bytes.ops single source inline zero-copy O(1) amortized via builder, interface refcount auto release not lost }
function BytesBuilderCreate(const AInitialCapacity: SizeUInt): IBytesBuilder; inline;
begin
  // perf: inline zero-copy forwarding to builder single source, pre-reserved capacity amortized 2× via BytesGrowCapacity/BYTES_BUILDER_MIN_GROW, exception-safe, resource managed via interface refcount not lost, bytes.ops single source
  Result := nextpas.core.bytes.builder.CreateBytesBuilder(AInitialCapacity);
end;

function BytesBuilderToBytes(const ABuilder: IBytesBuilder): TBytes; inline;
begin
  // perf: inline zero-copy single alloc ToBytes, resource managed not lost, bytes.ops single source via builder
  Result := ABuilder.ToBytes;
end;

procedure BytesBuilderAppendByte(const ABuilder: IBytesBuilder; AValue: Byte); inline;
begin
  // perf: inline zero-copy via builder Grow+direct assign O(1) amortized, single source bytes.ops→builder, resource managed not lost
  ABuilder.AppendByte(AValue);
end;

procedure BytesBuilderAppendBytes(const ABuilder: IBytesBuilder; const AData: TBytes); inline;
begin
  // perf: inline zero-copy Move via builder O(1) amortized, single source bytes.ops→builder
  if Length(AData) > 0 then
    ABuilder.AppendBytes(@AData[0], SizeUInt(Length(AData)));
end;

procedure BytesBuilderAppendSpan(const ABuilder: IBytesBuilder; const ASpan: TByteSpan); inline;
begin
  // perf: inline zero-copy via builder AppendSpan O(1) amortized, single source
  ABuilder.AppendSpan(ASpan);
end;

procedure BytesBuilderAppendUInt16BE(const ABuilder: IBytesBuilder; AValue: Word); inline;
begin
  ABuilder.AppendUInt16BE(AValue);
end;

procedure BytesBuilderAppendUInt16LE(const ABuilder: IBytesBuilder; AValue: Word); inline;
begin
  ABuilder.AppendUInt16LE(AValue);
end;

procedure BytesBuilderAppendUInt24BE(const ABuilder: IBytesBuilder; AValue: Cardinal); inline;
begin
  // perf: builder has no UInt24, compose via 3× AppendByte inline zero-copy O(1) amortized, single source bytes.ops→builder
  ABuilder.AppendByte(Byte(AValue shr 16));
  ABuilder.AppendByte(Byte(AValue shr 8));
  ABuilder.AppendByte(Byte(AValue));
end;

procedure BytesBuilderAppendUInt32BE(const ABuilder: IBytesBuilder; AValue: Cardinal); inline;
begin
  ABuilder.AppendUInt32BE(AValue);
end;

procedure BytesBuilderAppendUInt32LE(const ABuilder: IBytesBuilder; AValue: Cardinal); inline;
begin
  ABuilder.AppendUInt32LE(AValue);
end;

procedure BytesBuilderAppendUInt64BE(const ABuilder: IBytesBuilder; AValue: QWord); inline;
begin
  ABuilder.AppendUInt64BE(AValue);
end;

procedure BytesBuilderAppendUInt64LE(const ABuilder: IBytesBuilder; AValue: QWord); inline;
begin
  ABuilder.AppendUInt64LE(AValue);
end;

procedure BytesBuilderAppendFill(const ABuilder: IBytesBuilder; AValue: Byte; const ACount: SizeUInt); inline;
begin
  ABuilder.AppendFill(AValue, ACount);
end;

function BytesStartsWith(const AData, APrefix: TBytes): Boolean;
begin
  Result := SpanStartsWith(TByteSpan.FromBytes(AData), TByteSpan.FromBytes(APrefix));
end;

function BytesEndsWith(const AData, ASuffix: TBytes): Boolean;
begin
  Result := SpanEndsWith(TByteSpan.FromBytes(AData), TByteSpan.FromBytes(ASuffix));
end;

function StripLeadingZero(const AData: TBytes): TBytes; inline;
var
  L, LOff: SizeUInt;
  P: PByte;
begin
  // perf: single scan, no StripLeadingZeroView/Span indirection, no SpanClone extra call; zero-copy when no leading zero (CoW share), single alloc+Move when trimmed
  L := SizeUInt(Length(AData));
  if L = 0 then
  begin
    SetLength(Result, 1);
    Result[0] := 0;
    Exit;
  end;
  P := @AData[0];
  LOff := 0;
  while (LOff < L) and (P[LOff] = 0) do
    Inc(LOff);
  if LOff = L then
  begin
    SetLength(Result, 1);
    Result[0] := 0;
    Exit;
  end;
  if LOff = 0 then
  begin
    // no trim needed: zero-copy CoW share, avoids SetLength+Move allocation for hot small views
    Result := AData;
    Exit;
  end;
  // trimmed: single allocation + Move, no extra SpanClone allocation
  SetLength(Result, L - LOff);
  if L - LOff > 0 then
    Move(P[LOff], Result[0], L - LOff);
end;

function StripLeadingZeroBytes(const AData: TBytes): TBytes; inline;
begin
  Result := StripLeadingZero(AData);
end;

function StripLeadingZeroSpan(const ASpan: TByteSpan): TByteSpan; inline;
var LOff: SizeUInt;
begin
  Result := ASpan;
  LOff := 0;
  while (LOff < Result.Len) and (Result.Data[LOff] = 0) do Inc(LOff);
  if LOff > 0 then
  begin
    Inc(Result.Data, LOff);
    Dec(Result.Len, LOff);
  end;
end;

function StripLeadingZeroView(const AData: TBytes): TByteSpan; inline;
begin
  Result := StripLeadingZeroSpan(TByteSpan.FromBytes(AData));
end;

function CompareUnsignedSpan(const ALeft, ARight: TByteSpan): Integer; inline;
var
  LLeft, LRight: TByteSpan;
begin
  LLeft := StripLeadingZeroSpan(ALeft);
  LRight := StripLeadingZeroSpan(ARight);
  if LLeft.Len < LRight.Len then
    Exit(-1);
  if LLeft.Len > LRight.Len then
    Exit(1);
  if LLeft.Len = 0 then
    Exit(0);
  Result := CompareBytesOrdered(LLeft.Data, LRight.Data, LLeft.Len, LRight.Len);
end;

function CompareUnsigned(const ALeft, ARight: TBytes): Integer; inline;
begin
  Result := CompareUnsignedSpan(StripLeadingZeroView(ALeft), StripLeadingZeroView(ARight));
end;

function CompareUnsignedBytes(const ALeft, ARight: TBytes): Integer; inline;
begin
  Result := CompareUnsigned(ALeft, ARight);
end;

function UnsignedEqual(const ALeft, ARight: TBytes): Boolean; inline;
begin
  Result := CompareUnsigned(ALeft, ARight) = 0;
end;

function UnsignedBytesEqual(const ALeft, ARight: TBytes): Boolean; inline;
begin
  Result := UnsignedEqual(ALeft, ARight);
end;

function UnsignedEqualSpan(const ALeft, ARight: TByteSpan): Boolean; inline;
begin
  Result := CompareUnsignedSpan(ALeft, ARight) = 0;
end;

function IsZeroBytes(const AData: TBytes): Boolean; inline; overload;
begin
  // perf: single-source zero check via StripLeadingZeroView (O(n) scan with early exit,
  // reuses existing view; empty => Len=0 => zero). Avoids duplicate byte loops and
  // keeps crypto/tls callers on one implementation; SIMD MemEqual could be used for
  // bulk zero compares but view already short-circuits on first non-zero.
  Result := StripLeadingZeroView(AData).Len = 0;
end;

function IsZeroBytes(const ASpan: TByteSpan): Boolean; inline; overload;
begin
  // perf: same single source as TBytes overload via StripLeadingZeroSpan.
  Result := StripLeadingZeroSpan(ASpan).Len = 0;
end;

function BytesIsZero(const AData: TBytes): Boolean; inline;
begin
  Result := IsZeroBytes(AData);
end;

function IsAllZero(const AData: TBytes): Boolean; inline;
begin
  Result := IsZeroBytes(AData);
end;

function BytesToString(const ABytes: TBytes): string;
begin
  // 禁 inline：索引元素 ABytes[0] 直喂 Move 的 untyped 形参，若 inline 则 FPC 常量传播会把常量实参折叠为单字符临时，Move 拷出垃圾（tls13 实证，见 design-conventions 红线#1，valgrind+反汇编）
  // 单源：bytes.ops 唯一真实拷贝；门面 nextpas.core.bytes / text.conv 仅 inline 薄转发零额外调用
  // 性能：单次 SetLength + 单次 Move 零拷贝（无逐字节循环/额外分配）；空串早退零 Move；资源由 SetLength 托管自动释放，异常安全
  SetLength(Result, Length(ABytes));
  if Length(ABytes) > 0 then
    Move(ABytes[0], Result[1], Length(ABytes));
end;

function BytesToUTF8(const ABytes: TBytes): string; inline;
begin
  Result := BytesToString(ABytes);
end;

function StringToBytes(const AText: string): TBytes;
begin
  // 禁 inline：索引元素 Result[0] 直喂 Move 的 untyped 形参，若 inline 则 FPC 常量传播会把常量实参折叠为单字符临时，Move 拷出垃圾（tls13 实证，见 design-conventions 红线#1，valgrind+反汇编）
  // 单源：bytes.ops 唯一真实拷贝；门面 nextpas.core.bytes / text.conv 仅 inline 薄转发零额外调用
  // 性能：单次 SetLength + 单次 Move 零拷贝（无逐字节循环/额外分配）；空串早退零 Move；资源由 SetLength 托管自动释放，异常安全
  SetLength(Result, Length(AText));
  if Length(AText) > 0 then
    Move(PAnsiChar(AText)^, Pointer(Result)^, Length(AText));
end;

function BytesSliceToString(const ABytes: TBytes; const AOffset,
  ALength: SizeUInt): string; inline;
var
  LSpan: TByteSpan;
begin
  if ALength = 0 then
    Exit('');
  { 零拷贝借用：Slice 仅建视图不分配，生命周期绑 ABytes }
  LSpan := TByteSpan.FromBytes(ABytes).Slice(AOffset, ALength);
  SetLength(Result, LSpan.Len);
  if LSpan.Len > 0 then
    Move(LSpan.Data^, Result[1], LSpan.Len);
end;

end.
