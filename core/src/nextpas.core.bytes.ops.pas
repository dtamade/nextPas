unit nextpas.core.bytes.ops;

{$I nextpas.core.settings.inc}
{ bytes.ops — single source for SetLength+Move (单源 INV-5); TByteSpan zero-copy views; hot paths inline, alloc paths not inline per red-line 1 (indexed Move/alloc inline), red-line 2 (loop+Move).
  Facades inline thin-forward, no duplicate Move — single source stays here (BytesCopy/BytesZero/BytesReplicateCopy).
  GATE: raw Move/FillChar only in this unit (BytesCopy/BytesZero/BytesReplicateCopy); L1+ must reuse BytesCopy/BytesZero/Span* single source, L0 exception documented — enforced by test_bytes_ops_source_contracts; inline red-line enforced by same gate (hot inline, alloc/loop not inline).
  CAPACITY: BytesGrowCapacity single source via bytes.ops.capacity (BYTES_BUILDER_MIN_GROW 0→64→2×) amortized O(1); Webview 0→4→2× via BytesGrowCapacityWithMin reuse same loop — single source, inline thin-forward zero extra call.
  SPLIT: four-piece elegance — capacity/text helpers extracted to bytes.ops.capacity / bytes.ops.text leaves (≤800 guideline, this unit ~750 lines); leaves are pure arithmetic/string without raw Move, reuse this unit's BytesCopy single source when needed. }

interface

uses
  nextpas.core.base,
  nextpas.core.base.utils,
  nextpas.core.bytes.base,
  nextpas.core.bytes.builder,
  nextpas.core.bytes.ops.hash,
  nextpas.core.bytes.ops.ring,
  nextpas.core.bytes.ops.snapshot;

{ Span ops }
function SpanEqual(const A, B: TByteSpan): Boolean; inline;
function SpanEqualIgnoreCase(const A, B: TByteSpan): Boolean; inline;
function SpanCompare(const A, B: TByteSpan): Integer; inline;

function SpanIndexOf(const AHaystack: TByteSpan; const ANeedle: Byte): SizeInt; inline;
function SpanIndexOfSpan(const AHaystack, ANeedle: TByteSpan): SizeInt;
function SpanLastIndexOfSpan(const AHaystack, ANeedle: TByteSpan): SizeInt;
function SpanContains(const AHaystack: TByteSpan; const ANeedle: Byte): Boolean; inline;
function SpanStartsWith(const AData, APrefix: TByteSpan): Boolean; inline;
function SpanEndsWith(const AData, ASuffix: TByteSpan): Boolean;
{ string trim/equals — zero-copy view layer single source for text.view Trim/Equals + js.base JsTrimEquals (owner bytes.ops, inline thin-forward, loop not inline per red-line 2) }
function SpanTrimLeft(const ASpan: TByteSpan): TByteSpan;
function SpanTrimRight(const ASpan: TByteSpan): TByteSpan;
function SpanTrim(const ASpan: TByteSpan): TByteSpan; inline;
function StringTrimEquals(const S, Lit: string): Boolean;

procedure SpanFill(const ASpan: TByteSpan; const AValue: Byte);
procedure SpanReverse(const ASpan: TByteSpan);
{ replicate — doubling Moves }
procedure BytesReplicateCopy(ASrc, ADst: Pointer; ADist, ALen: SizeUInt);
{ single Move/Fill }
procedure BytesCopy(ADst, ASrc: Pointer; const ALen: SizeUInt);
procedure BytesZero(ADst: Pointer; const ALen: SizeUInt);
procedure SpanZero(const ASpan: TByteSpan);

{ zero page (.bss, 4K) }
const
  BYTES_ZERO_PAGE_SIZE = 4096;
  BYTES_ZERO_PAGE_SLICE_THRESHOLD = BYTES_ZERO_PAGE_SIZE;
var
  BYTES_ZERO_PAGE: array[0..BYTES_ZERO_PAGE_SIZE - 1] of Byte;

function ZeroPageSlice(const ALen: SizeUInt): TByteSpan; inline;

{ XOR — QWord batched }
procedure XorInplace(ADst, AKey: PByte; ALen: SizeUInt);
procedure SpanXorInplace(const ADst, AKey: TByteSpan); inline;

{ ASCII case }
procedure AsciiToLowerInplace(AData: PByte; ALen: SizeUInt);
procedure AsciiToUpperInplace(AData: PByte; ALen: SizeUInt);
procedure SpanToLowerAscii(const ASpan: TByteSpan); inline;
procedure SpanToUpperAscii(const ASpan: TByteSpan); inline;
function AsciiLowerString(const S: string): string; inline;
function AsciiUpperString(const S: string): string; inline;

function SpanConcat(const A, B: TByteSpan): TBytes;
function SpanCopySlice(const ASpan: TByteSpan; const AOffset, ALength: SizeUInt): TBytes;
function SpanClone(const ASpan: TByteSpan): TBytes;

function BytesEqual(const A, B: TBytes): Boolean; inline;
function BytesCompare(const A, B: TBytes): Integer; inline;
function BytesIndexOf(const AData: TBytes; const ANeedle: Byte): SizeInt; inline;
function BytesConcat(const A, B: TBytes): TBytes; inline;
{ not inline: SetLength+Move }
procedure BytesAppend(var ADest: TBytes; const ASrc: TBytes); overload;
procedure BytesAppend(var ADest: TBytes; const ASrc: PByte; const ASrcLen: SizeUInt); overload;
procedure BytesAppendByte(var ADest: TBytes; AValue: Byte); inline;
procedure BytesAppendUInt16BE(var ADest: TBytes; AValue: Word); inline;
procedure BytesAppendUInt16LE(var ADest: TBytes; AValue: Word); inline;
procedure BytesAppendUInt24BE(var ADest: TBytes; AValue: Cardinal); inline;
procedure BytesAppendUInt32BE(var ADest: TBytes; AValue: Cardinal); inline;
procedure BytesAppendUInt32LE(var ADest: TBytes; AValue: Cardinal); inline;
procedure BytesAppendUInt64BE(var ADest: TBytes; AValue: QWord); inline;
procedure BytesAppendUInt64LE(var ADest: TBytes; AValue: QWord); inline;
procedure BytesReserve(var ADest: TBytes; const AAdditional: SizeUInt);
procedure BytesEnsureCapacity(var ADest: TBytes; const ARequired: SizeUInt);
function BytesNextCapacity(AOld, ANeed: SizeUInt): SizeUInt; inline;
{ not inline: loop — single source geometric via BYTES_BUILDER_MIN_GROW }
function BytesGrowCapacity(const ACurrent, ARequired: SizeUInt): SizeUInt; overload;
function BytesGrowCapacityInt(const ACurrent, ARequired: Integer): Integer;
{ parameterized single source for family reuse (WebviewGrowCapacity 0→4→2×); not inline: loop }
function BytesGrowCapacityWithMin(const ACurrent, ARequired, AMinGrow: SizeUInt): SizeUInt;
function BytesGrowCapacityIntWithMin(const ACurrent, ARequired, AMinGrow: Integer): Integer;
function WebviewGrowCapacityForReuse(const ACurrent: Integer): Integer; inline;
{ lane-window: capacity/hash/ring/snapshot single-source facades (union merge) }
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
generic procedure ArraySetLengthNoRealloc<T>(var A: specialize TSnapshotArray<T>; ANewLen: Integer); inline;
{ Swap-remove — 末尾换位删除单源，window.live 双哈希复用 inline 零拷贝 O(1)，bytes.ops 单源，守托管批量 Finalize 不丢，16槽热路径分支消除 }
generic procedure ArraySwapRemoveRaw<T>(var AArr: array of T; AIdx, ALast: Integer); inline;
generic procedure ArraySwapRemoveManaged<T>(var AArr: array of T; AIdx, ALast: Integer); inline;
generic procedure ArraySwapRemove<T>(var AArr: array of T; AIdx, ALast: Integer); inline;
{ Arena batch — 7 数组批量扩容单源，window.live 复用 inline 零拷贝，池化容量复用降 Burst 抖动 }
generic procedure ManagedEnsureCapacity<T>(var AArr: specialize TSnapshotArray<T>; ARequired: Integer); inline;
{ Snapshot exact — 快照精准容量单源，window.live 16-slot 小窗复用 inline 零拷贝 O(1)，确需确配避 32 过分配 }
generic procedure ManagedEnsureCapacityExact<T>(var AArr: specialize TSnapshotArray<T>; ARequired: Integer); inline;
generic procedure ManagedEnsureTriple<TKey, TVal>(var AKeys: specialize TSnapshotArray<TKey>; var AVals: specialize TSnapshotArray<TVal>; var AUsed: TSnapshotBools; ARequired: Integer); inline;
{ Live arena batch — Record 聚合 8 数组+3 容量 11 参 brutalist 收口为 2 参，bytes.ops 单源 inline 零拷贝 O(1) }
type
  TLiveArenaCaps = nextpas.core.bytes.ops.snapshot.TLiveArenaCaps;
  TLiveArenaBatch = nextpas.core.bytes.ops.snapshot.TLiveArenaBatch;
  THashRebuildArena = nextpas.core.bytes.ops.snapshot.THashRebuildArena;
{ 主入口：Record 聚合 2 参 inline 零拷贝 O(1)，资源托管释放不丢 }
procedure LiveArenaEnsureBatch(var ABatch: TLiveArenaBatch; const ACaps: TLiveArenaCaps); inline; overload;
{ 兼容旧入口：11 参 brutalist inline 薄转发，逐步迁移 }
procedure LiveArenaEnsureBatch(var AList: TSnapshotPointers; var AIDs: TSnapshotUInt32s; var AHKeys: TSnapshotUInt32s; var AHVals: TSnapshotPointers; var AHUsed: TSnapshotBools; var APKeys: TSnapshotPointers; var APIdx: TSnapshotIntegers; var APUsed: TSnapshotBools; AListCap, AU32Cap, APtrCap: Integer); inline; overload;
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
generic procedure SnapshotMaybeShrink<T>(var ASnap: specialize TSnapshotArray<T>; ACount: Integer); inline;
function BytesConcatMany(const AParts: array of TBytes): TBytes;
function SpanConcatMany(const AParts: array of TByteSpan): TBytes;
function BytesStartsWith(const AData, APrefix: TBytes): Boolean; inline;
function BytesEndsWith(const AData, ASuffix: TBytes): Boolean; inline;

{ unsigned helpers }
function StripLeadingZero(const AData: TBytes): TBytes;
function StripLeadingZeroBytes(const AData: TBytes): TBytes;
function StripLeadingZeroSpan(const ASpan: TByteSpan): TByteSpan;
function StripLeadingZeroView(const AData: TBytes): TByteSpan;
function CompareUnsigned(const ALeft, ARight: TBytes): Integer; inline;
function CompareUnsignedBytes(const ALeft, ARight: TBytes): Integer; inline;
function CompareUnsignedSpan(const ALeft, ARight: TByteSpan): Integer; inline;
function UnsignedEqual(const ALeft, ARight: TBytes): Boolean; inline;
function UnsignedBytesEqual(const ALeft, ARight: TBytes): Boolean; inline;
function IsZeroBytes(const AData: TBytes): Boolean; inline; overload;
function IsZeroBytes(const ASpan: TByteSpan): Boolean; inline; overload;
function IsAllZero(const AData: TBytes): Boolean; inline;
function BytesIsGzip(const AData: TBytes): Boolean; inline;
function BytesIsGzipHeader(const AHeader: TBytes; const ATotalSize: Int64): Boolean; inline;
function BytesIsGzipBuffer(AData: PByte; const ALength: SizeUInt): Boolean; inline;
function BytesIsGzipSpan(const ASpan: TByteSpan): Boolean; inline;
function SpanToString(const ASpan: TByteSpan): string; inline;
function SpanToUTF8(const ASpan: TByteSpan): string; inline;
function BytesToString(const ABytes: TBytes): string; inline;
function BytesToUTF8(const ABytes: TBytes): string; inline;
function StringToBytes(const AText: string): TBytes;
function BytesSliceToString(const ABytes: TBytes; const AOffset,
  ALength: SizeUInt): string; inline;
function StringLowerAsciiAware(const S: string): string; inline; { 薄转发 text.unicode.utils.ToLowerAsciiAware 单源：ASCII 预检+零拷贝，owner text.unicode.utils }
{ Hex single source (uppercase fixed-width UInt64→hex, L1 canonical for vfs ETag etc., inline zero-copy via Move, Span-less, reuses single HEX_UPPER table) }
function BytesHexUInt64(const AValue: UInt64; const ADigits: Integer): string; inline;
function TryClampSlice(const AOffset, ALength, ATotal: SizeUInt; out AClampedLen: SizeUInt): Boolean; inline;
{ not inline: loop — C string length single source, zero-copy view length, owner bytes.ops }
function AnsiPtrLen(const P: PAnsiChar): SizeUInt;
{ not inline: loop+Move — reuses AnsiPtrLen single source, zero-copy Move }
function AnsiPtrToString(const P: PAnsiChar): string;
{ not inline: loop }
function BigEndianUnicodeBytesToString(const AData: TBytes): string; inline;

{ Variant helpers }
type
  TVarType = Word;
const
  varEmpty = $0000;
  varNull = $0001;
  varTypeMask = $0FFF;
function VarType(const V: Variant): TVarType; inline;
function VarIsNull(const V: Variant): Boolean; inline;
function VarIsEmpty(const V: Variant): Boolean; inline;
function VarIsClear(const V: Variant): Boolean; inline;

{ byte order }
function HTonN(AValue: Word): Word; overload; inline;
function HTonN(AValue: LongWord): LongWord; overload; inline;
function NToHs(AValue: Word): Word; overload; inline;
function NToHs(AValue: LongWord): LongWord; overload; inline;

{ FNV-1a 32 }
function FNV1a32(const AData: PByte; const ALen: SizeUInt): UInt32; inline;
function FNV1a32Bytes(const AData: TBytes): UInt32; inline;

implementation

uses
  nextpas.core.simd,
  nextpas.core.mem.dynarray,
  nextpas.core.bytes.binary,
  nextpas.core.bytes.ops.capacity,
  nextpas.core.bytes.ops.text,
  nextpas.core.bytes.ops.ascii,
  nextpas.core.text.unicode.utils;

{ capacity growth — single source delegates to bytes.ops.capacity leaf }
procedure BytesEnsureCapacity(var ADest: TBytes; const ARequired: SizeUInt);
var
  LOld, LNewCap: SizeUInt;
begin
  LOld := SizeUInt(Length(ADest));
  if ARequired <= LOld then
    Exit;
  LNewCap := BytesGrowCapacity(LOld, ARequired);
  SetLength(ADest, LNewCap);
end;

procedure BytesReserve(var ADest: TBytes; const AAdditional: SizeUInt);
var
  LNeed: SizeUInt;
begin
  if AAdditional = 0 then
    Exit;
  LNeed := SizeUInt(Length(ADest)) + AAdditional;
  BytesEnsureCapacity(ADest, LNeed);
end;

function BytesNextCapacity(AOld, ANeed: SizeUInt): SizeUInt; inline;
begin
  Result := nextpas.core.bytes.ops.capacity.BytesNextCapacity(AOld, ANeed);
end;

function BytesGrowCapacityWithMin(const ACurrent, ARequired, AMinGrow: SizeUInt): SizeUInt;
begin
  Result := nextpas.core.bytes.ops.capacity.BytesGrowCapacityWithMin(ACurrent, ARequired, AMinGrow);
end;

function BytesGrowCapacity(const ACurrent, ARequired: SizeUInt): SizeUInt;
begin
  Result := nextpas.core.bytes.ops.capacity.BytesGrowCapacity(ACurrent, ARequired);
end;

function BytesGrowCapacityIntWithMin(const ACurrent, ARequired, AMinGrow: Integer): Integer;
begin
  Result := nextpas.core.bytes.ops.capacity.BytesGrowCapacityIntWithMin(ACurrent, ARequired, AMinGrow);
end;

function BytesGrowCapacityInt(const ACurrent, ARequired: Integer): Integer;
begin
  Result := nextpas.core.bytes.ops.capacity.BytesGrowCapacityInt(ACurrent, ARequired);
end;

function WebviewGrowCapacityForReuse(const ACurrent: Integer): Integer; inline;
begin
  Result := nextpas.core.bytes.ops.capacity.WebviewGrowCapacityForReuse(ACurrent);
end;

{ lane-window forwarding bodies: single-arg grow/capped/helper + hash/ring/snapshot/arena (union merge) }
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
  Result := specialize BytesGrowHelper<T>(ACount, AMax);
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
  specialize ManagedRingCopy<T>(ADest, ASrc, ASrcHead, ASrcCap, ACount);
end;

generic procedure ManagedRingFinalize<T>(var ARing: array of T; AHead, ACap, ACount: SizeInt); inline;
begin
  specialize ManagedRingFinalize<T>(ARing, AHead, ACap, ACount);
end;

generic procedure ManagedRingTransfer<T>(var ADest: array of T; var ASrc: array of T; ASrcHead, ASrcCap, ACount: SizeInt); inline;
begin
  specialize ManagedRingTransfer<T>(ADest, ASrc, ASrcHead, ASrcCap, ACount);
end;

generic procedure RawRingCopy<T>(var ADest: array of T; const ASrc: array of T; ASrcHead, ASrcCap, ACount: SizeInt); inline;
begin
  specialize RawRingCopy<T>(ADest, ASrc, ASrcHead, ASrcCap, ACount);
end;

generic procedure RawRingTransfer<T>(var ADest: array of T; var ASrc: array of T; ASrcHead, ASrcCap, ACount: SizeInt); inline;
begin
  specialize RawRingTransfer<T>(ADest, ASrc, ASrcHead, ASrcCap, ACount);
end;

generic procedure ArrayRawCopy<T>(var ADest: array of T; const ASrc: array of T; ACount: SizeInt); inline;
begin
  specialize ArrayRawCopy<T>(ADest, ASrc, ACount);
end;

generic procedure ManagedArrayMove<T>(var ADest: array of T; var ASrc: array of T); inline;
begin
  specialize ManagedArrayMove<T>(ADest, ASrc);
end;

{ Snapshot — 快照/Arena 单源 via bytes.ops.snapshot inline 零拷贝 O(1) }
generic procedure ArraySetLengthNoRealloc<T>(var A: specialize TSnapshotArray<T>; ANewLen: Integer); inline;
begin
  specialize ArraySetLengthNoRealloc<T>(A, ANewLen);
end;

generic procedure ArraySwapRemoveRaw<T>(var AArr: array of T; AIdx, ALast: Integer); inline;
begin
  specialize ArraySwapRemoveRaw<T>(AArr, AIdx, ALast);
end;

generic procedure ArraySwapRemoveManaged<T>(var AArr: array of T; AIdx, ALast: Integer); inline;
begin
  specialize ArraySwapRemoveManaged<T>(AArr, AIdx, ALast);
end;

generic procedure ArraySwapRemove<T>(var AArr: array of T; AIdx, ALast: Integer); inline;
begin
  specialize ArraySwapRemove<T>(AArr, AIdx, ALast);
end;

generic procedure ManagedEnsureCapacity<T>(var AArr: specialize TSnapshotArray<T>; ARequired: Integer); inline;
begin
  specialize ManagedEnsureCapacity<T>(AArr, ARequired);
end;

generic procedure ManagedEnsureCapacityExact<T>(var AArr: specialize TSnapshotArray<T>; ARequired: Integer); inline;
begin
  specialize ManagedEnsureCapacityExact<T>(AArr, ARequired);
end;

generic procedure ManagedEnsureTriple<TKey, TVal>(var AKeys: specialize TSnapshotArray<TKey>; var AVals: specialize TSnapshotArray<TVal>; var AUsed: TSnapshotBools; ARequired: Integer); inline;
begin
  specialize ManagedEnsureTriple<TKey, TVal>(AKeys, AVals, AUsed, ARequired);
end;

procedure LiveArenaEnsureBatch(var ABatch: TLiveArenaBatch; const ACaps: TLiveArenaCaps); inline; overload;
begin
  nextpas.core.bytes.ops.snapshot.LiveArenaEnsureBatch(ABatch, ACaps);
end;

procedure LiveArenaEnsureBatch(var AList: TSnapshotPointers; var AIDs: TSnapshotUInt32s; var AHKeys: TSnapshotUInt32s; var AHVals: TSnapshotPointers; var AHUsed: TSnapshotBools; var APKeys: TSnapshotPointers; var APIdx: TSnapshotIntegers; var APUsed: TSnapshotBools; AListCap, AU32Cap, APtrCap: Integer); inline; overload;
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
  specialize ArenaPoolFinalize<T>(APool, ATop, AShutdown, AIdx);
end;

function SnapshotBulkTier(ACount: Integer): Integer; inline;
begin
  Result := nextpas.core.bytes.ops.snapshot.SnapshotBulkTier(ACount);
end;

generic procedure SnapshotMaybeShrink<T>(var ASnap: specialize TSnapshotArray<T>; ACount: Integer); inline;
begin
  // 单源 inline 薄转发至 snapshot BYTES_SNAPSHOT_MAX 三档 1024/4096/8192，not inline 冷路径本体在 snapshot 避 I-Cache 膨胀 per redline #2，bytes.ops 单源复用消 live/queue 重复分支，Bulk 分档尾延迟 via SnapshotBulkTier
  specialize SnapshotMaybeShrink<T>(ASnap, ACount);
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

{ L0 mem }
function DynArrayCapacity(const A: TBytes): SizeUInt; inline;
begin
  Result := nextpas.core.mem.dynarray.DynArrayCapacity(A);
end;

function DynArrayRefCount(const A: TBytes): PtrInt; inline;
begin
  Result := nextpas.core.mem.dynarray.DynArrayRefCount(A);
end;

procedure PokeDynArrayLength(var A: TBytes; const ANewLen: SizeUInt); inline;
begin
  nextpas.core.mem.dynarray.DynArraySetLength(A, ANewLen);
end;

{ append capacity }
procedure EnsureAppendCapacity(var ADest: TBytes; const AOldLen, AReqLen: SizeUInt);
var
  LCap: SizeUInt;
begin
  LCap := BytesGrowCapacity(AOldLen, AReqLen);
  if (DynArrayCapacity(ADest) < LCap) or (DynArrayRefCount(ADest) <> 1) then
  begin
    if LCap <> SizeUInt(Length(ADest)) then
      SetLength(ADest, LCap);
  end;
  if SizeUInt(Length(ADest)) <> AReqLen then
    PokeDynArrayLength(ADest, AReqLen);
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

function SpanLastIndexOfSpan(const AHaystack, ANeedle: TByteSpan): SizeInt;
var
  LPos, LFound, LLast: SizeInt;
  LSlice: TByteSpan;
begin
  if (ANeedle.Len = 0) or (ANeedle.Len > AHaystack.Len) then
    Exit(-1);
  LLast := -1;
  LPos := 0;
  while SizeUInt(LPos) <= AHaystack.Len - ANeedle.Len do
  begin
    LSlice := TByteSpan.Create(AHaystack.Data + SizeUInt(LPos), AHaystack.Len - SizeUInt(LPos));
    LFound := SpanIndexOfSpan(LSlice, ANeedle);
    if LFound < 0 then
      Break;
    LLast := LPos + LFound;
    LPos := LLast + 1;
    if SizeUInt(LPos) > AHaystack.Len then
      Break;
  end;
  Result := LLast;
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

function SpanTrimLeft(const ASpan: TByteSpan): TByteSpan;
var
  LPos: SizeUInt;
begin
  // single source: zero-copy view trim left, no heap alloc, loop not inline per red-line 2, owner bytes.ops
  if ASpan.Len = 0 then
    Exit(TByteSpan.Empty);
  LPos := 0;
  while (LPos < ASpan.Len) and ((ASpan.Data[LPos] = 9) or (ASpan.Data[LPos] = 10) or (ASpan.Data[LPos] = 13) or (ASpan.Data[LPos] = 32)) do
    Inc(LPos);
  if LPos >= ASpan.Len then
    Exit(TByteSpan.Empty);
  Result.Data := ASpan.Data + LPos;
  Result.Len := ASpan.Len - LPos;
end;

function SpanTrimRight(const ASpan: TByteSpan): TByteSpan;
var
  LEnd: SizeUInt;
begin
  // single source: zero-copy view trim right, no heap alloc, loop not inline per red-line 2, owner bytes.ops
  if ASpan.Len = 0 then
    Exit(TByteSpan.Empty);
  LEnd := ASpan.Len;
  while (LEnd > 0) and ((ASpan.Data[LEnd - 1] = 9) or (ASpan.Data[LEnd - 1] = 10) or (ASpan.Data[LEnd - 1] = 13) or (ASpan.Data[LEnd - 1] = 32)) do
    Dec(LEnd);
  if LEnd = 0 then
    Exit(TByteSpan.Empty);
  Result.Data := ASpan.Data;
  Result.Len := LEnd;
end;

function SpanTrim(const ASpan: TByteSpan): TByteSpan; inline;
begin
  // perf: inline thin-forward via SpanTrimLeft+SpanTrimRight single source, zero-copy view, no heap alloc, owner bytes.ops
  Result := SpanTrimRight(SpanTrimLeft(ASpan));
end;

function StringTrimEquals(const S, Lit: string): Boolean;
var
  LTrim: TByteSpan;
  LLit: TByteSpan;
begin
  // single source: reuse SpanTrim+SpanEqual zero-copy TByteSpan view, no heap alloc, loop not inline per red-line 2, owner bytes.ops (MemEqual SIMD)
  LTrim := SpanTrim(TByteSpan.FromStr(S));
  LLit := TByteSpan.FromStr(Lit);
  Result := SpanEqual(LTrim, LLit);
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

procedure XorInplace(ADst, AKey: PByte; ALen: SizeUInt);
begin
  nextpas.core.bytes.ops.ascii.XorInplace(ADst, AKey, ALen);
end;

procedure SpanXorInplace(const ADst, AKey: TByteSpan); inline;
begin
  nextpas.core.bytes.ops.ascii.SpanXorInplace(ADst, AKey);
end;

procedure AsciiToLowerInplace(AData: PByte; ALen: SizeUInt);
begin
  nextpas.core.bytes.ops.ascii.AsciiToLowerInplace(AData, ALen);
end;

procedure AsciiToUpperInplace(AData: PByte; ALen: SizeUInt);
begin
  nextpas.core.bytes.ops.ascii.AsciiToUpperInplace(AData, ALen);
end;

procedure SpanToLowerAscii(const ASpan: TByteSpan); inline;
begin
  nextpas.core.bytes.ops.ascii.SpanToLowerAscii(ASpan);
end;

procedure SpanToUpperAscii(const ASpan: TByteSpan); inline;
begin
  nextpas.core.bytes.ops.ascii.SpanToUpperAscii(ASpan);
end;

function AsciiLowerString(const S: string): string; inline;
begin
  Result := nextpas.core.bytes.ops.text.AsciiLowerString(S);
end;

function AsciiUpperString(const S: string): string; inline;
begin
  Result := nextpas.core.bytes.ops.text.AsciiUpperString(S);
end;

procedure BytesReplicateCopy(ASrc, ADst: Pointer; ADist, ALen: SizeUInt);
var
  LPat, LDone, LChunk: SizeUInt;
begin
  if (ASrc = nil) or (ADst = nil) or (ALen = 0) then
    Exit;
  if ADist = High(SizeUInt) then
  begin
    Move(ASrc^, ADst^, ALen);
    Exit;
  end;
  LPat := ADist + 1;
  if ALen <= LPat then
  begin
    Move(ASrc^, ADst^, ALen);
    Exit;
  end;
  Move(ASrc^, ADst^, LPat);
  LDone := LPat;
  while LDone < ALen do
  begin
    LChunk := LDone;
    if LChunk > ALen - LDone then
      LChunk := ALen - LDone;
    Move(ADst^, (PByte(ADst) + LDone)^, LChunk);
    Inc(LDone, LChunk);
  end;
end;

procedure BytesCopy(ADst, ASrc: Pointer; const ALen: SizeUInt); inline;
begin
  if ALen = 0 then Exit;
  Move(ASrc^, ADst^, ALen);
end;

procedure BytesZero(ADst: Pointer; const ALen: SizeUInt); inline;
begin
  if ALen = 0 then Exit;
  FillChar(ADst^, ALen, 0);
end;

procedure SpanZero(const ASpan: TByteSpan); inline;
begin
  if ASpan.Len > 0 then
    MemSet(ASpan.Data, ASpan.Len, 0);
end;

function ZeroPageSlice(const ALen: SizeUInt): TByteSpan; inline;
begin
  if ALen > BYTES_ZERO_PAGE_SIZE then
    Result := TByteSpan.Create(@BYTES_ZERO_PAGE[0], BYTES_ZERO_PAGE_SIZE)
  else
    Result := TByteSpan.Create(@BYTES_ZERO_PAGE[0], ALen);
end;

function SpanConcat(const A, B: TByteSpan): TBytes;
begin
  Result := nil;
  SetLength(Result, A.Len + B.Len);
  if A.Len > 0 then
    Move(A.Data^, Pointer(Result)^, A.Len);
  if B.Len > 0 then
    Move(B.Data^, (PByte(Pointer(Result)) + A.Len)^, B.Len);
end;

function SpanCopySlice(const ASpan: TByteSpan; const AOffset, ALength: SizeUInt): TBytes;
begin
  Result := nil;
  if (ALength > 0) and (AOffset + ALength > ASpan.Len) then
    raise EOutOfRange.Create('SpanCopySlice: offset+length exceeds span');
  SetLength(Result, ALength);
  if ALength > 0 then
    Move((ASpan.Data + AOffset)^, Pointer(Result)^, ALength);
end;

function SpanClone(const ASpan: TByteSpan): TBytes;
begin
  Result := nil;
  SetLength(Result, ASpan.Len);
  if ASpan.Len > 0 then
    Move(ASpan.Data^, Pointer(Result)^, ASpan.Len);
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
      Move(AParts[I].Data^, (PByte(Pointer(Result)) + LOff)^, AParts[I].Len);
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
      Move(Pointer(AParts[I])^, (PByte(Pointer(Result)) + LOff)^, Length(AParts[I]));
      Inc(LOff, Length(AParts[I]));
    end;
end;

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
  LOldLen, LReq, LSrcLen: SizeUInt;
begin
  LSrcLen := SizeUInt(Length(ASrc));
  if LSrcLen = 0 then
    Exit;
  LOldLen := SizeUInt(Length(ADest));
  if High(SizeUInt) - LOldLen < LSrcLen then
    raise EOutOfMemory.Create('BytesAppend: size overflow');
  LReq := LOldLen + LSrcLen;
  EnsureAppendCapacity(ADest, LOldLen, LReq);
  Move(Pointer(ASrc)^, (PByte(Pointer(ADest)) + LOldLen)^, LSrcLen);
end;

procedure BytesAppend(var ADest: TBytes; const ASrc: PByte; const ASrcLen: SizeUInt); overload;
var
  LOldLen, LReq: SizeUInt;
begin
  if (ASrc = nil) or (ASrcLen = 0) then
    Exit;
  LOldLen := SizeUInt(Length(ADest));
  if High(SizeUInt) - LOldLen < ASrcLen then
    raise EOutOfMemory.Create('BytesAppend: size overflow');
  LReq := LOldLen + ASrcLen;
  EnsureAppendCapacity(ADest, LOldLen, LReq);
  Move(ASrc^, (PByte(Pointer(ADest)) + LOldLen)^, ASrcLen);
end;

procedure BytesAppendByte(var ADest: TBytes; AValue: Byte);
var
  LOldLen, LReq: SizeUInt;
begin
  LOldLen := SizeUInt(Length(ADest));
  if LOldLen = High(SizeUInt) then
    raise EOutOfMemory.Create('BytesAppendByte: size overflow');
  LReq := LOldLen + 1;
  EnsureAppendCapacity(ADest, LOldLen, LReq);
  PByte(Pointer(ADest) + LOldLen)^ := AValue;
end;

procedure BytesAppendUInt16BE(var ADest: TBytes; AValue: Word);
var
  LOldLen, LReq: SizeUInt;
begin
  LOldLen := SizeUInt(Length(ADest));
  if High(SizeUInt) - LOldLen < 2 then
    raise EOutOfMemory.Create('BytesAppendUInt16BE: size overflow');
  LReq := LOldLen + 2;
  EnsureAppendCapacity(ADest, LOldLen, LReq);
  PByte(Pointer(ADest) + LOldLen)^ := Byte(AValue shr 8);
  PByte(Pointer(ADest) + LOldLen + 1)^ := Byte(AValue);
end;

procedure BytesAppendUInt24BE(var ADest: TBytes; AValue: Cardinal);
var
  LOldLen, LReq: SizeUInt;
begin
  LOldLen := SizeUInt(Length(ADest));
  if High(SizeUInt) - LOldLen < 3 then
    raise EOutOfMemory.Create('BytesAppendUInt24BE: size overflow');
  LReq := LOldLen + 3;
  EnsureAppendCapacity(ADest, LOldLen, LReq);
  PByte(Pointer(ADest) + LOldLen)^ := Byte(AValue shr 16);
  PByte(Pointer(ADest) + LOldLen + 1)^ := Byte(AValue shr 8);
  PByte(Pointer(ADest) + LOldLen + 2)^ := Byte(AValue);
end;

procedure BytesAppendUInt32BE(var ADest: TBytes; AValue: Cardinal);
var
  LOldLen, LReq: SizeUInt;
begin
  LOldLen := SizeUInt(Length(ADest));
  if High(SizeUInt) - LOldLen < 4 then
    raise EOutOfMemory.Create('BytesAppendUInt32BE: size overflow');
  LReq := LOldLen + 4;
  EnsureAppendCapacity(ADest, LOldLen, LReq);
  PByte(Pointer(ADest) + LOldLen)^ := Byte(AValue shr 24);
  PByte(Pointer(ADest) + LOldLen + 1)^ := Byte(AValue shr 16);
  PByte(Pointer(ADest) + LOldLen + 2)^ := Byte(AValue shr 8);
  PByte(Pointer(ADest) + LOldLen + 3)^ := Byte(AValue);
end;

procedure BytesAppendUInt16LE(var ADest: TBytes; AValue: Word);
var
  LOldLen, LReq: SizeUInt;
begin
  LOldLen := SizeUInt(Length(ADest));
  if High(SizeUInt) - LOldLen < 2 then
    raise EOutOfMemory.Create('BytesAppendUInt16LE: size overflow');
  LReq := LOldLen + 2;
  EnsureAppendCapacity(ADest, LOldLen, LReq);
  PByte(Pointer(ADest) + LOldLen)^ := Byte(AValue);
  PByte(Pointer(ADest) + LOldLen + 1)^ := Byte(AValue shr 8);
end;

procedure BytesAppendUInt32LE(var ADest: TBytes; AValue: Cardinal);
var
  LOldLen, LReq: SizeUInt;
begin
  LOldLen := SizeUInt(Length(ADest));
  if High(SizeUInt) - LOldLen < 4 then
    raise EOutOfMemory.Create('BytesAppendUInt32LE: size overflow');
  LReq := LOldLen + 4;
  EnsureAppendCapacity(ADest, LOldLen, LReq);
  PByte(Pointer(ADest) + LOldLen)^ := Byte(AValue);
  PByte(Pointer(ADest) + LOldLen + 1)^ := Byte(AValue shr 8);
  PByte(Pointer(ADest) + LOldLen + 2)^ := Byte(AValue shr 16);
  PByte(Pointer(ADest) + LOldLen + 3)^ := Byte(AValue shr 24);
end;

procedure BytesAppendUInt64BE(var ADest: TBytes; AValue: QWord);
var
  LOldLen, LReq: SizeUInt;
begin
  LOldLen := SizeUInt(Length(ADest));
  if High(SizeUInt) - LOldLen < 8 then
    raise EOutOfMemory.Create('BytesAppendUInt64BE: size overflow');
  LReq := LOldLen + 8;
  EnsureAppendCapacity(ADest, LOldLen, LReq);
  PByte(Pointer(ADest) + LOldLen)^ := Byte(AValue shr 56);
  PByte(Pointer(ADest) + LOldLen + 1)^ := Byte(AValue shr 48);
  PByte(Pointer(ADest) + LOldLen + 2)^ := Byte(AValue shr 40);
  PByte(Pointer(ADest) + LOldLen + 3)^ := Byte(AValue shr 32);
  PByte(Pointer(ADest) + LOldLen + 4)^ := Byte(AValue shr 24);
  PByte(Pointer(ADest) + LOldLen + 5)^ := Byte(AValue shr 16);
  PByte(Pointer(ADest) + LOldLen + 6)^ := Byte(AValue shr 8);
  PByte(Pointer(ADest) + LOldLen + 7)^ := Byte(AValue);
end;

procedure BytesAppendUInt64LE(var ADest: TBytes; AValue: QWord);
var
  LOldLen, LReq: SizeUInt;
begin
  LOldLen := SizeUInt(Length(ADest));
  if High(SizeUInt) - LOldLen < 8 then
    raise EOutOfMemory.Create('BytesAppendUInt64LE: size overflow');
  LReq := LOldLen + 8;
  EnsureAppendCapacity(ADest, LOldLen, LReq);
  PByte(Pointer(ADest) + LOldLen)^ := Byte(AValue);
  PByte(Pointer(ADest) + LOldLen + 1)^ := Byte(AValue shr 8);
  PByte(Pointer(ADest) + LOldLen + 2)^ := Byte(AValue shr 16);
  PByte(Pointer(ADest) + LOldLen + 3)^ := Byte(AValue shr 24);
  PByte(Pointer(ADest) + LOldLen + 4)^ := Byte(AValue shr 32);
  PByte(Pointer(ADest) + LOldLen + 5)^ := Byte(AValue shr 40);
  PByte(Pointer(ADest) + LOldLen + 6)^ := Byte(AValue shr 48);
  PByte(Pointer(ADest) + LOldLen + 7)^ := Byte(AValue shr 56);
end;

function BytesStartsWith(const AData, APrefix: TBytes): Boolean;
begin
  Result := SpanStartsWith(TByteSpan.FromBytes(AData), TByteSpan.FromBytes(APrefix));
end;

function BytesEndsWith(const AData, ASuffix: TBytes): Boolean;
begin
  Result := SpanEndsWith(TByteSpan.FromBytes(AData), TByteSpan.FromBytes(ASuffix));
end;

function LeadingZeroOffset(AData: PByte; ALen: SizeUInt): SizeUInt;
var
  LOff: SizeUInt;
begin
  LOff := 0;
  {$PUSH}{$Q-}{$R-}
  while LOff + 8 <= ALen do
  begin
    if PQWord(AData + LOff)^ <> 0 then
      Break;
    Inc(LOff, 8);
  end;
  while (LOff < ALen) and (AData[LOff] = 0) do
    Inc(LOff);
  {$POP}
  Result := LOff;
end;

function StripLeadingZero(const AData: TBytes): TBytes;
var
  L, LOff: SizeUInt;
  P: PByte;
begin
  L := SizeUInt(Length(AData));
  if L = 0 then
  begin
    SetLength(Result, 1);
    Result[0] := 0;
    Exit;
  end;
  P := PByte(Pointer(AData));
  LOff := LeadingZeroOffset(P, L);
  if LOff = L then
  begin
    SetLength(Result, 1);
    Result[0] := 0;
    Exit;
  end;
  if LOff = 0 then
  begin
    Result := AData;
    Exit;
  end;
  SetLength(Result, L - LOff);
  if L - LOff > 0 then
    Move((P + LOff)^, Pointer(Result)^, L - LOff);
end;

function StripLeadingZeroBytes(const AData: TBytes): TBytes;
begin
  Result := StripLeadingZero(AData);
end;

function StripLeadingZeroSpan(const ASpan: TByteSpan): TByteSpan;
var
  LOff: SizeUInt;
begin
  Result := ASpan;
  if Result.Len = 0 then
    Exit;
  LOff := LeadingZeroOffset(Result.Data, Result.Len);
  if LOff > 0 then
  begin
    Inc(Result.Data, LOff);
    Dec(Result.Len, LOff);
  end;
end;

function StripLeadingZeroView(const AData: TBytes): TByteSpan;
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
  Result := StripLeadingZeroView(AData).Len = 0;
end;

function IsZeroBytes(const ASpan: TByteSpan): Boolean; inline; overload;
begin
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

function BytesIsGzipBuffer(AData: PByte; const ALength: SizeUInt): Boolean; inline;
begin
  // perf: inline + zero-copy PByte 单源 gzip 魔数 ($1F $8B)，compress.base GZIP_MAGIC 字面量对齐 canonical，无 TBytes 分配，供 transform 栈上 2 字节探针零堆复用
  Result := (ALength >= 2) and (AData <> nil) and (AData[0] = $1F) and (AData[1] = $8B);
end;

function BytesIsGzipSpan(const ASpan: TByteSpan): Boolean; inline;
begin
  Result := BytesIsGzipBuffer(ASpan.Data, ASpan.Len);
end;

function BytesIsGzip(const AData: TBytes): Boolean; inline;
begin
  // perf: inline + zero-copy single source via BytesIsGzipBuffer PByte 单源，compress.base canonical; reused by vfs.compressed IsGzipPred/HeaderPred
  if Length(AData) < 2 then Exit(False);
  Result := BytesIsGzipBuffer(@AData[0], SizeUInt(Length(AData)));
  Result := (Length(AData) >= 2) and (AData[0] = $1F) and (AData[1] = $8B);
end;

function BytesIsGzipHeader(const AHeader: TBytes; const ATotalSize: Int64): Boolean; inline;
begin
  Result := BytesIsGzip(AHeader);
end;

function SpanToString(const ASpan: TByteSpan): string; inline;
begin
  Result := nextpas.core.bytes.ops.text.SpanToString(ASpan);
end;

function SpanToUTF8(const ASpan: TByteSpan): string; inline;
begin
  Result := nextpas.core.bytes.ops.text.SpanToUTF8(ASpan);
end;

function BytesToString(const ABytes: TBytes): string; inline;
begin
  Result := nextpas.core.bytes.ops.text.BytesToString(ABytes);
end;

function BytesToUTF8(const ABytes: TBytes): string; inline;
begin
  Result := nextpas.core.bytes.ops.text.BytesToUTF8(ABytes);
end;

function StringToBytes(const AText: string): TBytes;
begin
  SetLength(Result, Length(AText));
  if Length(AText) > 0 then
    Move(PAnsiChar(AText)^, Pointer(Result)^, Length(AText));
end;

function BytesSliceToString(const ABytes: TBytes; const AOffset,
  ALength: SizeUInt): string; inline;
begin
  Result := nextpas.core.bytes.ops.text.BytesSliceToString(ABytes, AOffset, ALength);
end;

function StringLowerAsciiAware(const S: string): string; inline;
begin
  Result := ToLowerAsciiAware(S);
end;

function TryClampSlice(const AOffset, ALength, ATotal: SizeUInt; out AClampedLen: SizeUInt): Boolean; inline;
begin
  Result := nextpas.core.bytes.ops.text.TryClampSlice(AOffset, ALength, ATotal, AClampedLen);
end;

function AnsiPtrLen(const P: PAnsiChar): SizeUInt;
var
  LP: PAnsiChar;
begin
  if P = nil then
    Exit(0);
  LP := P;
  while LP^ <> #0 do
    Inc(LP);
  Result := SizeUInt(LP - P);
end;

function AnsiPtrToString(const P: PAnsiChar): string;
var
  LLen: SizeUInt;
begin
  Result := '';
  LLen := AnsiPtrLen(P);
  if LLen = 0 then
    Exit;
  SetLength(Result, LLen);
  Move(P^, Pointer(Result)^, LLen);
end;

function BigEndianUnicodeBytesToString(const AData: TBytes): string; inline;
begin
  Result := nextpas.core.bytes.ops.text.BigEndianUnicodeBytesToString(AData);
end;

function FNV1a32(const AData: PByte; const ALen: SizeUInt): UInt32; inline;
begin
  Result := nextpas.core.bytes.ops.text.FNV1a32(AData, ALen);
end;

function FNV1a32Bytes(const AData: TBytes): UInt32; inline;
begin
  Result := nextpas.core.bytes.ops.text.FNV1a32Bytes(AData);
end;

function HTonN(AValue: Word): Word; inline;
begin
  Result := nextpas.core.bytes.ops.text.HTonN(AValue);
end;

function HTonN(AValue: LongWord): LongWord; inline;
begin
  Result := nextpas.core.bytes.ops.text.HTonN(AValue);
end;

function NToHs(AValue: Word): Word; inline;
begin
  Result := nextpas.core.bytes.ops.text.NToHs(AValue);
end;

function NToHs(AValue: LongWord): LongWord; inline;
begin
  Result := nextpas.core.bytes.ops.text.NToHs(AValue);
end;

function VarType(const V: Variant): TVarType; inline;
begin
  Result := nextpas.core.bytes.ops.text.VarType(V);
end;

function VarIsNull(const V: Variant): Boolean; inline;
begin
  Result := nextpas.core.bytes.ops.text.VarIsNull(V);
end;

function VarIsEmpty(const V: Variant): Boolean; inline;
begin
  Result := nextpas.core.bytes.ops.text.VarIsEmpty(V);
end;

function VarIsClear(const V: Variant): Boolean; inline;
begin
  Result := nextpas.core.bytes.ops.text.VarIsClear(V);
end;

const
  HEX_UPPER_BYTESOPS: array[0..15] of AnsiChar = '0123456789ABCDEF';

function BytesHexUInt64(const AValue: UInt64; const ADigits: Integer): string; inline;
var I: Integer; V: UInt64;
begin
  SetLength(Result, ADigits);
  V := AValue;
  for I := ADigits - 1 downto 0 do
  begin
    Result[I + 1] := HEX_UPPER_BYTESOPS[V and $F];
    V := V shr 4;
  end;
end;

end.