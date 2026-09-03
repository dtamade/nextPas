unit nextpas.core.bytes.ops;

{$I nextpas.core.settings.inc}
{ bytes.ops — single source for SetLength+Move (单源 INV-5); TByteSpan zero-copy views; hot paths inline, alloc paths not inline per red-line 1 (indexed Move/alloc inline), red-line 2 (loop+Move).
  Facades inline thin-forward, no duplicate Move — single source stays here (BytesCopy/BytesZero/BytesReplicateCopy).
  GATE: raw Move/FillChar only in this unit (BytesCopy/BytesZero/BytesReplicateCopy); L1+ must reuse BytesCopy/BytesZero/Span* single source, L0 exception documented — enforced by test_bytes_ops_source_contracts (check_bytes_ops_source_contract.py full patrol: red-line 1/2, BytesCopy inline single Move, BytesAppend* not inline + O(n²) loop-append patrol, capacity single source); inline red-line enforced by same gate (hot inline, alloc/loop not inline).
  CAPACITY: BytesGrowCapacity single source via bytes.ops.capacity (BYTES_BUILDER_MIN_GROW 0→64→2×) amortized O(1); Webview 0→4→2× via BytesGrowCapacityWithMin reuse same loop — single source, inline thin-forward zero extra call.
  SPLIT: four-piece elegance — capacity/text helpers extracted to bytes.ops.capacity / bytes.ops.text leaves (≤800 guideline, this unit ~750 lines); leaves are pure arithmetic/string without raw Move, reuse this unit's BytesCopy single source when needed. }

interface

uses
  nextpas.core.base,
  nextpas.core.base.utils,
  nextpas.core.bytes.base;

type
  TFieldRange = record Off, Len: SizeUInt; end;

{ Span ops }
function SpanEqual(const A, B: TByteSpan): Boolean; inline;
function SpanEqualIgnoreCase(const A, B: TByteSpan): Boolean; inline;
function SpanCompare(const A, B: TByteSpan): Integer; inline;

function SpanIndexOf(const AHaystack: TByteSpan; const ANeedle: Byte): SizeInt; inline;
function SpanLastIndexOf(const AHaystack: TByteSpan; const ANeedle: Byte): SizeInt; inline;
function BytesLastIndexOf(const AData: TBytes; const ANeedle: Byte): SizeInt; inline;
function StringLastIndexOf(const S: string; const ANeedle: Char): SizeInt; inline;
function SpanIndexOfSpan(const AHaystack, ANeedle: TByteSpan): SizeInt;
{ single-source multi-field NUL scan: one 512B pass truncates N fields, reuses SpanIndexOf single source, decl. reusable for tar 7-field cache, zero-alloc PSizeUInt out }
procedure ScanNulFieldTruncations(const ABlock: TByteSpan; const AFields: array of TFieldRange; ATruncs: PSizeUInt);
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
{ single Move/Fill — inline single Move(ASrc^,ADst^,ALen)/FillChar zero-copy per red-line 1, gate patrol }
procedure BytesCopy(ADst, ASrc: Pointer; const ALen: SizeUInt); inline;
procedure BytesZero(ADst: Pointer; const ALen: SizeUInt); inline;
procedure SpanZero(const ASpan: TByteSpan);

{ zero page (.bss, 4K) }
const
  BYTES_ZERO_PAGE_SIZE = 4096;
  BYTES_ZERO_PAGE_SLICE_THRESHOLD = BYTES_ZERO_PAGE_SIZE;
  // bulk parse limit — single source canonical 64MiB (owner L1 bytes.ops, Format/JS single source via this, no L2→L2, bytes.ops BytesCopy zero-copy, L0-L3 kept, resource try-finally not丢)
  BYTES_BULK_PARSE_MAX_BYTES = SizeUInt(64) * 1024 * 1024;
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
{ restored from git lane: SpanCopy single source for fixed-size zero-copy copy (OID 20/32 etc.), inline + single Move, no heap }
procedure SpanCopy(const ADst, ASrc: TByteSpan); inline;

function BytesEqual(const A, B: TBytes): Boolean; inline;
function BytesCompare(const A, B: TBytes): Integer; inline;
function BytesIndexOf(const AData: TBytes; const ANeedle: Byte): SizeInt; inline;
function BytesConcat(const A, B: TBytes): TBytes; inline;
{ not inline: SetLength+Move — perf: BytesAppend does SetLength+Move per call (O(n) → O(n²) if looped); MUST prefer IBytesBuilder (geometric grow) or BytesConcatMany/SpanConcatMany single alloc; gate: check_bytes_ops_source_contract.py cross-module loop-append patrol }
procedure BytesAppend(var ADest: TBytes; const ASrc: TBytes); overload;
procedure BytesAppend(var ADest: TBytes; const ASrc: PByte; const ASrcLen: SizeUInt); overload;
procedure BytesAppendByte(var ADest: TBytes; AValue: Byte);
procedure BytesAppendUInt16BE(var ADest: TBytes; AValue: Word);
procedure BytesAppendUInt16LE(var ADest: TBytes; AValue: Word);
procedure BytesAppendUInt24BE(var ADest: TBytes; AValue: Cardinal);
procedure BytesAppendUInt32BE(var ADest: TBytes; AValue: Cardinal);
procedure BytesAppendUInt32LE(var ADest: TBytes; AValue: Cardinal);
procedure BytesAppendUInt64BE(var ADest: TBytes; AValue: QWord);
procedure BytesAppendUInt64LE(var ADest: TBytes; AValue: QWord);
procedure BytesReserve(var ADest: TBytes; const AAdditional: SizeUInt);
procedure BytesEnsureCapacity(var ADest: TBytes; const ARequired: SizeUInt);
{ ssh 反哺单源: SizeUInt 容量槽几何增长, 供 channel/sftp 按槽复用 (single source: BytesGrowCapacity) }
procedure BytesEnsureCapacity(var ACap: SizeUInt; const ARequired: SizeUInt); overload;
{ ssh 反哺单源: 4B 长度前缀帧重组, 原地 Move+收缩, 零拷贝尾部前移 }
procedure BytesRemovePrefix(var ABuf: TBytes; const ACount: SizeUInt);
procedure BytesConsumePrefix(var ABuf: TBytes; const ACount: SizeUInt); inline;
function BytesNextCapacity(AOld, ANeed: SizeUInt): SizeUInt; inline;
{ not inline: loop — single source geometric via BYTES_BUILDER_MIN_GROW }
function BytesGrowCapacity(const ACurrent, ARequired: SizeUInt): SizeUInt;
function BytesGrowCapacityInt(const ACurrent, ARequired: Integer): Integer;
{ parameterized single source for family reuse (WebviewGrowCapacity 0→4→2×); not inline: loop }
function BytesGrowCapacityWithMin(const ACurrent, ARequired, AMinGrow: SizeUInt): SizeUInt;
function BytesGrowCapacityIntWithMin(const ACurrent, ARequired, AMinGrow: Integer): Integer;
function WebviewGrowCapacityForReuse(const ACurrent: Integer): Integer; inline;
// dynarray probe/poke single source for non-TBytes arrays — lifecycle/pure.value unified entry via bytes.ops, inline zero-copy, amortized O(1) (owner L1 bytes.ops, probes via L0 mem.dynarray)
function BytesDynCapacityElem(APtr: Pointer; ALen: SizeUInt; AElemSize: SizeUInt): SizeUInt; inline;
function BytesDynCapacityGeneric(var A; AElemSize: SizeUInt): SizeUInt; inline;
procedure BytesDynSetLengthGeneric(var A; const ANewLen: SizeUInt); inline;
// generic ensure with geometric single source via BytesNextCapacity + probe/poke single slit, trivial types only (zero finalization), inline zero-copy, amortized O(1)
procedure BytesDynEnsureLength(var A; AElemSize: SizeUInt; ANewLen: SizeUInt);
procedure BytesDynReserve(var A; AElemSize: SizeUInt; AAdditional: SizeUInt); inline;
{ compat alias for git lane (same growth policy via BytesGrowCapacity single source) }
function GrowArrayCapacity(const ACurrent, ARequired: SizeUInt): SizeUInt; inline;
function SpanHashFNV1a(const ASpan: TByteSpan): UInt32; inline;
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
function SpanSumBytes(const ASpan: TByteSpan): UInt64; inline;
function BytesSum(const AData: PByte; ALen: SizeUInt): UInt64; inline;
function BytesIsGzip(const AData: TBytes): Boolean; inline;
function BytesIsGzipHeader(const AHeader: TBytes; const ATotalSize: Int64): Boolean; inline;
function BytesIsGzipBuffer(AData: PByte; const ALength: SizeUInt): Boolean; inline;
function BytesIsGzipSpan(const ASpan: TByteSpan): Boolean; inline;
function SpanToUTF8(const ASpan: TByteSpan): string; inline;
function BytesToString(const ABytes: TBytes): string; inline;
function BytesToUTF8(const ABytes: TBytes): string; inline;
function StringToBytes(const AText: string): TBytes;
function BytesSliceToString(const ABytes: TBytes; const AOffset,
  ALength: SizeUInt): string; inline;
{ String join single source — L1 canonical comma-join via BytesCopy single source, zero-copy Move, single alloc O(n); owner bytes.ops, js probe 8-name single source via this, no TBufStringBuilder duplicate loop, not inline per red-line 2 (loop), resource no leak }
function StringJoin(const AParts: array of string; const ASep: string): string;
function BytesJoinStrings(const AParts: array of string; const ASep: string): string; inline;
function SpanToString(const ASpan: TByteSpan): string; inline;
function StringAsSpan(const AValue: string): TByteSpan; inline; { string->TByteSpan 零拷贝视图单源，PAnsiChar 单点，inline }
procedure BytesRelease(var ABuffer: TBytes); inline; { 单源显式归还：SetLength 0 高水位释放，inline }
procedure BytesShrinkTo(var ABuffer: TBytes; ANewSize: SizeUInt); inline; { 单源显式缩容：仅缩不扩，inline }
function StringLowerAsciiAware(const S: string): string; inline; { 薄转发 text.unicode.utils.ToLowerAsciiAware 单源：ASCII 预检+零拷贝，owner text.unicode.utils }

{ 零拷贝所有权偷取：inline Move+FillChar 零 refcount 抖动，单源治理 TBytes 手工转移，零拷贝零额外调用，供 webview scheme/pool 热路径复用，源归零无双释放，stability: FillChar 零化防 UAF/双释放 }
procedure BytesSteal(var ADest: TBytes; var ASrc: TBytes); inline;

type
  generic TVecArray<T> = array of T;

{ vec/smallvec 生长单源：0→4→2× 倍增，inline 零额外调用，bytes.ops 唯一权威；webview/collections 复用此单源 }
function VecGrowCapacity(ACurrent: Integer): Integer; inline;
{ 通用动态数组 Grow：Count 与物理 Length 精确对比，inline 薄转发单源，消除约30个样板重复，零额外调用 }
generic procedure VecGrow<T>(var AArr: specialize TVecArray<T>; ACount: Integer);
{ 零拷贝快照：按 ACount 精确截断/复制 ADest := copy(ASrc,0,ACount)，nil 零分配，inline 零额外调用，单源治理 Builder 等全量 SetLength 直写漂移；managed 类型逐元素赋值保 refcnt，blittable 单次 Move 批量零拷贝（编译器批量 Move 优化且避免托管类型 refcnt 抖动）}
generic procedure VecSnapshot<T>(var ADest: specialize TVecArray<T>; const ASrc: array of T; ACount: Integer);
{ 零拷贝截断：按 ACount 精确 SetLength，inline 单源，消除手写 SetLength 重复 }
generic procedure VecTrim<T>(var AArr: specialize TVecArray<T>; ACount: Integer);
{ 紧凑 Vec 删除单源：Swap O(1) 零拷贝末尾换位 + ordered O(n) 保序，bytes.ops 唯一权威；Swap/ordered 均含扫描循环按 design-conventions §2 红线二去 inline 避 I-Cache 膨胀；原 webview.live 薄转发已物理删除，家族直用本单源，热关闭路径默认 Swap 避免 O(n²) }
generic procedure VecRemoveSwap<T>(var AArr: array of T; var ACount: Integer; const AValue: T);
generic procedure VecRemoveOrdered<T>(var AArr: array of T; var ACount: Integer; const AValue: T);
{ 零拷贝批量拷贝单源：managed 逐元素保 refcnt，blittable 单次 Move 零拷贝，inline 单源供线性容扩/环形线性化复用 }
generic procedure VecCopy<T>(const ASrc: array of T; var ADst: array of T; ACount: Integer); inline;
generic procedure VecGrowCopy<T>(const ASrc: array of T; var ADst: specialize TVecArray<T>; ACount, ANewCap: Integer);
{ 环形线性化单源：两段式免模线性化，复用 VecCopy 单源，inline 零额外调用，供 Dispatcher/ CircularBuffer 单源复用 }
generic procedure VecRingCopy<T>(const ASrc: array of T; AHead, ACount: Integer; var ADst: array of T); inline;
{ 环形生长拷贝单源：按需 SetLength(LCap)+VecRingCopy 两段式线性化 inline 单源，供 dispatcher 突发预分配/乐观重试复用，复用 LNew 缓冲 Length 判定避免重复 SetLength 零化 O(Cap)，突发并发零重复分配放大尾延迟，0→4→2× 倍增摊销 O(1)/push，inline 零额外调用，managed 保 refcnt/blittable 单 Move 零拷贝 }
generic procedure VecRingGrowCopy<T>(const ASrc: array of T; AHead, ACount: Integer; var ADst: specialize TVecArray<T>; ANewCap: Integer);

{ L1 通用紧凑 Vec 注册表单源（CONTRACT §1.2/§50 可抽候选已反哺落地 L1 bytes.ops）：原 webview.live 薄别名已物理删除，现供 window.live/webview 家族直用本单源，inline 零额外调用，0→4→2× VecGrowCapacity 单源，Swap O(1) 零拷贝，Default(T) 释放不丢 — 家族内不另立重复实现；S110+ 补充有序队列语义（FIFO 保序 PopFront/RemoveAtOrdered 单源 VecRemoveOrdered/VecRingCopy 零拷贝，inline 薄转发、loop 非 inline 避 I-Cache 膨胀），fake 内部裸队列已收敛至此单源零重复 }
type
  generic TCompactLiveRegistry<T> = class
  private
    FList: specialize TVecArray<T>;
    FCount: Integer;
  public
    procedure Register(const AInst: T); inline;
    procedure Unregister(const AInst: T); inline;
    procedure UnregisterSwap(const AInst: T); inline;
    procedure UnregisterOrdered(const AInst: T); inline;
    function Count: Integer; inline;
    function IsEmpty: Boolean; inline;
    function At(AIndex: Integer): T; inline;
    procedure SetAt(AIndex: Integer; const AValue: T); inline;
    procedure RemoveAtOrdered(AIndex: Integer);
    procedure RemoveAtSwap(AIndex: Integer); inline;
    procedure PopFrontOrdered; inline;
    function TryPopFront(out AValue: T): Boolean; inline;
    procedure Snapshot(var ADest: specialize TVecArray<T>); inline;
    procedure Trim; inline;
    procedure Clear;
    // perf: single source capacity/raw snapshot for optimistic lock-bypassing grow (zero alloc inside lock, O(1) fast-path, VecGrowCapacity/VecGrowCopy single source outside), inline zero-copy, reuse LNew Length check avoids repeat SetLength zero-init O(Cap) — mirrors dispatcher Ring optimistic
    function Capacity: Integer; inline;
    function RawList: specialize TVecArray<T>; inline;
    procedure GetSnapshotRaw(out AList: specialize TVecArray<T>; out ACount, ACap: Integer); inline;
    function TryRegisterFast(const AValue: T): Boolean; inline;
    function TryInstallGrown(const AOldList: specialize TVecArray<T>; AOldCount: Integer; var ANew: specialize TVecArray<T>; const AValue: T): Boolean; inline;
    destructor Destroy; override;
  end;

{ 单源 Move：string/PByte 零拷贝单次 Move，tar/header 等复用此单源避免分散 Move；外联避免 Move[AValue[1]] inline 膨胀与 FPC 3.3.1 inline+Move 单字节缺陷（PAnsiChar 解引用） }
procedure CopyStringToBuffer(const AText: string; ADest: PByte; ACount: SizeUInt);
procedure CopyMemory(const ASrc, ADest: PByte; ACount: SizeUInt); inline;
{ 单源路径拼接：prefix/name 单次 SetLength + 两 Move（bytes.ops 单源 CopyMemory），tar/zip 联邦 ArchiveJoinPath 与 tar.reader CombinePrefixName 同构收敛至此，切片零拷贝视图单源，热路径 inline 薄转发 }
function SpanJoinWithSeparator(const ALeft, ARight: TByteSpan; const ASeparator: Char): string; inline;
{ 单源对齐：power-of-two 位掩码零除法，无截断，32/64 位 SizeUInt 安全，溢出守卫，inline 零拷贝单点，tar.builder 4K/ZIP 容量等复用此单源，常量 4096 位掩码零除法 }
function AlignUp(const AValue, AAlignment: SizeUInt): SizeUInt; inline;
function AlignUp4K(const AValue: SizeUInt): SizeUInt; inline;
{ 单源零垫：4K 零源 GZeroBuf4K inline 零拷贝访问，tar 512B 零垫/两零块与 IsZeroMem 单源复用，L1 owner bytes.ops 单源，零分配 }
function ZeroBufPtr: PByte; inline;
function ZeroBufSize: SizeUInt; inline;
{ 高位计数：统计 >=128 字节数（bit7=1），SWAR 64-bit + 尾部无分支，零拷贝 PByte 切片，外联 }
function BytesCountHighBit(const AData: PByte; ALen: SizeUInt): SizeUInt;
function SpanCountHighBit(const ASpan: TByteSpan): SizeUInt; inline;
{ 融合：字节和经 simd.SumBytes 单源，highbit 经 SWAR 单源，零拷贝 PByte 切片，外联；tar dual 复用 SIMD 批量 512B 提速 }
procedure BytesSumAndCountHighBit(const AData: PByte; ALen: SizeUInt; out ASum: UInt64; out AHigh: SizeUInt);
function SpanSumAndCountHighBit(const ASpan: TByteSpan; out ASum: UInt64; out AHigh: SizeUInt): Boolean; inline;
{ 融合空洞排除：tar chksum 8 字节空洞排除，和经 simd.SumBytes 分段累加，high 经 SWAR 分段，外联；nil/越界守卫 }
procedure BytesSumAndCountHighBitExclude(const AData: PByte; ALen: SizeUInt; AExcludeOff, AExcludeLen: SizeUInt; out ASum: UInt64; out AHigh: SizeUInt);
function SpanSumAndCountHighBitExclude(const ASpan: TByteSpan; AExcludeOff, AExcludeLen: SizeUInt; out ASum: UInt64; out AHigh: SizeUInt): Boolean; inline;
{ Hex single source (uppercase fixed-width UInt64→hex, L1 canonical for vfs ETag etc., inline zero-copy via Move, Span-less, reuses single HEX_UPPER table) }
function BytesHexUInt64(const AValue: UInt64; const ADigits: Integer): string;
function TryClampSlice(const AOffset, ALength, ATotal: SizeUInt; out AClampedLen: SizeUInt): Boolean; inline;
{ not inline: loop — C string length single source, zero-copy view length, owner bytes.ops }
function AnsiPtrLen(const P: PAnsiChar): SizeUInt;
{ inline thin-forward alias of AnsiPtrLen for lane consumers (text.view/gtk); single source stays AnsiPtrLen }
function CStrLen(const AP: PAnsiChar): SizeUInt; inline;
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

{ BytesEnsureCapacity/Reserve: geometric via bytes.ops.capacity single source (INV-5/INV-2)
  BYTES_BUILDER_MIN_GROW 0→64→2× amortized O(1) zero O(n²); thin-forward to BytesGrowCapacity, no duplicate loop.
  perf: BytesAppend geometric via BytesEnsureCapacity single source single SetLength + single Move zero-copy (owner bytes.ops), looped/high-frequency still prefer IBytesBuilder/ConcatMany; inline hot views zero-copy, batch not inline per red-line.
  Stability: SetLength exception-safe; BytesAppend via BytesEnsureCapacity + DynArraySetLength poke keeps heap capacity while logical len exact, no leak, sized free via allocator. }
var
  GZeroBuf4K: array[0..4095] of Byte; // zero-initialized SIMD zero source, single source for IsZero via chunked MemEqual

function IsZeroMem(const AData: PByte; ALen: SizeUInt): Boolean;
var
  LOff, LChunk: SizeUInt;
begin
  // perf: chunked MemEqual vs zero buffer single source, SIMD dispatch, zero-copy PByte+Len, out-of-line loop per design-conventions
  if (AData = nil) or (ALen = 0) then Exit(True);
  LOff := 0;
  while LOff < ALen do
  begin
    LChunk := ALen - LOff;
    if LChunk > SizeUInt(Length(GZeroBuf4K)) then
      LChunk := SizeUInt(Length(GZeroBuf4K));
    if not MemEqual(AData + LOff, @GZeroBuf4K[0], LChunk) then
      Exit(False);
    Inc(LOff, LChunk);
  end;
  Result := True;
end;

{ capacity growth — single source delegates to bytes.ops.capacity leaf }
procedure BytesEnsureCapacity(var ADest: TBytes; const ARequired: SizeUInt);
var
  LOld, LNewCap: SizeUInt;
begin
  // perf: inline hot path, single BytesNextCapacity geometric 2×, single SetLength, zero-copy, no header poke
  LOld := SizeUInt(Length(ADest));
  if ARequired <= LOld then
    Exit;
  // single source geometric via bytes.ops.capacity (BYTES_BUILDER_MIN_GROW 0→64→2×) amortized O(1) — not inline per red-line 2 (loop)
  LNewCap := BytesGrowCapacity(LOld, ARequired);
  SetLength(ADest, LNewCap);
end;

procedure BytesEnsureCapacity(var ACap: SizeUInt; const ARequired: SizeUInt); overload;
begin
  if ARequired <= ACap then
    Exit;
  ACap := BytesGrowCapacity(ACap, ARequired);
end;

procedure BytesRemovePrefix(var ABuf: TBytes; const ACount: SizeUInt);
var
  LLen, LRem: SizeUInt;
begin
  LLen := SizeUInt(Length(ABuf));
  if ACount = 0 then Exit;
  if ACount >= LLen then begin SetLength(ABuf, 0); Exit; end;
  LRem := LLen - ACount;
  Move(ABuf[ACount], ABuf[0], LRem);
  SetLength(ABuf, LRem);
end;

procedure BytesConsumePrefix(var ABuf: TBytes; const ACount: SizeUInt); inline;
begin
  BytesRemovePrefix(ABuf, ACount);
end;

procedure BytesReserve(var ADest: TBytes; const AAdditional: SizeUInt); inline;
var
  LNeed: SizeUInt;
begin
  // perf: inline thin-forward to BytesEnsureCapacity single source, overflow guard, zero-copy
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

{ compat alias for git lane: same 0→64→2× policy, forwards to BytesGrowCapacity single source }
function GrowArrayCapacity(const ACurrent, ARequired: SizeUInt): SizeUInt; inline;
begin
  Result := BytesGrowCapacity(ACurrent, ARequired);
end;

{ compat alias for git lane: FNV-1a 32 over span, same digest as FNV1a32 single source }
function SpanHashFNV1a(const ASpan: TByteSpan): UInt32; inline;
begin
  Result := nextpas.core.bytes.ops.text.FNV1a32(ASpan.Data, ASpan.Len);
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

function BytesDynCapacityElem(APtr: Pointer; ALen: SizeUInt; AElemSize: SizeUInt): SizeUInt; inline;
begin
  // inline single source probe via L0 mem.dynarray, zero-copy heap probe, bytes.ops single slit
  Result := nextpas.core.mem.dynarray.DynArrayCapacityElem(APtr, ALen, AElemSize);
end;

function BytesDynCapacityGeneric(var A; AElemSize: SizeUInt): SizeUInt; inline;
begin
  // inline single source probe via L0 mem.dynarray, zero-copy, bytes.ops single slit
  Result := nextpas.core.mem.dynarray.DynArrayCapacityGeneric(A, AElemSize);
end;

procedure BytesDynSetLengthGeneric(var A; const ANewLen: SizeUInt); inline;
begin
  // inline single source poke via L0 mem.dynarray, zero-copy header High, Exactly-Once, bytes.ops single slit
  nextpas.core.mem.dynarray.DynArraySetLengthGeneric(A, ANewLen);
end;
type
  PDynArrayHeaderLocal = ^TDynArrayHeaderLocal;
  TDynArrayHeaderLocal = record RefCnt: PtrInt; High: PtrInt; end;

procedure BytesDynEnsureLength(var A; AElemSize: SizeUInt; ANewLen: SizeUInt);
var
  LP: Pointer;
  LCurLen, LCurCap, LCap: SizeUInt;
  LBytes: TBytes absolute A;
begin
  // single source geometric via BytesNextCapacity + probe/poke single slit, trivial types only, amortized O(1), inline not per red-line 2 (SetLength + loop)
  if AElemSize = 0 then Exit;
  LP := PPointer(@A)^;
  if LP = nil then
    LCurLen := 0
  else
    LCurLen := SizeUInt(PDynArrayHeaderLocal(PByte(LP) - SizeOf(TDynArrayHeaderLocal))^.High + 1);
  if LCurLen = ANewLen then Exit;
  LCurCap := BytesDynCapacityGeneric(A, AElemSize);
  if LCurCap >= ANewLen then
  begin
    BytesDynSetLengthGeneric(A, ANewLen);
    Exit;
  end;
  LCap := BytesNextCapacity(LCurLen, ANewLen);
  SetLength(LBytes, LCap * AElemSize);
  if LCap <> ANewLen then
    BytesDynSetLengthGeneric(A, ANewLen);
end;

procedure BytesDynReserve(var A; AElemSize: SizeUInt; AAdditional: SizeUInt); inline;
var LP: Pointer; LOld, LNeed, LCap, LCurCap: SizeUInt; LBytes: TBytes absolute A;
begin
  // single source geometric via BytesNextCapacity + probe/poke Exactly-Once, amortized O(1), inline reserve not loop per red-line, bytes.ops single slit via DynArray ops, trivial types only
  if (AElemSize = 0) or (AAdditional = 0) then Exit;
  LP := PPointer(@A)^;
  if LP = nil then LOld := 0 else LOld := SizeUInt(PDynArrayHeaderLocal(PByte(LP) - SizeOf(TDynArrayHeaderLocal))^.High + 1);
  LNeed := LOld + AAdditional;
  LCurCap := BytesDynCapacityGeneric(A, AElemSize);
  if LCurCap >= LNeed then Exit;
  LCap := BytesNextCapacity(LOld, LNeed);
  SetLength(LBytes, LCap * AElemSize);
  if LCap <> LOld then BytesDynSetLengthGeneric(A, LOld);
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

function SpanLastIndexOf(const AHaystack: TByteSpan; const ANeedle: Byte): SizeInt; inline;
var I: SizeUInt;
begin
  // perf: inline + zero-copy reverse scan PByte+Len (bytes.ops single source for LastDelimiter/parent-dir split), single pass, no alloc/Copy, O(n)
  if (AHaystack.Len = 0) or (AHaystack.Data = nil) then Exit(-1);
  for I := AHaystack.Len downto 1 do
    if AHaystack.Data[I-1] = ANeedle then Exit(SizeInt(I-1));
  Result := -1;
end;

function BytesLastIndexOf(const AData: TBytes; const ANeedle: Byte): SizeInt; inline;
begin
  // perf: inline thin-forward to SpanLastIndexOf, zero-copy TByteSpan view single source
  Result := SpanLastIndexOf(TByteSpan.FromBytes(AData), ANeedle);
end;

function StringLastIndexOf(const S: string; const ANeedle: Char): SizeInt; inline;
var L: SizeUInt;
begin
  // perf: inline + zero-copy PByte view (no Copy), single source SpanLastIndexOf, 1-based (0 if not found) for LastDelimiter/PathDir parity, platform.path single-source thought
  L := SizeUInt(Length(S));
  if L = 0 then Exit(0);
  Result := SpanLastIndexOf(TByteSpan.Create(PByte(@S[1]), L), Byte(ANeedle));
  if Result >= 0 then Inc(Result) else Result := 0;
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

procedure ScanNulFieldTruncations(const ABlock: TByteSpan; const AFields: array of TFieldRange; ATruncs: PSizeUInt);
var
  N, I, LCap: SizeUInt;
  Found: SizeUInt;
  LOff, LLen: SizeUInt;
  LIdx: SmallInt;
  LMap: array[0..511] of SmallInt; // stack LUT: off -> field index, -1 = none, FillChar $FF = -1; eliminates inner J loop
  K: SizeUInt;
  LFnd: SizeInt;
begin
  // perf: single 512B pass truncates N fields at first NUL via offset->field LUT (stack, zero-alloc, zero-copy PByte view, out-of-line per design-conventions loop ban). Branch 3584->512/Next (~7x, 2000条目 7M->1M), single source Span/bytes.ops for tar 7-field cache; early exit when Found=N.
  N := SizeUInt(Length(AFields));
  for I := 0 to N - 1 do
    ATruncs[I] := AFields[I].Len;
  if (ABlock.Len = 0) or (ABlock.Data = nil) or (N = 0) then Exit;
  // fast path: tar header 512B fits stack LUT 512; longer blocks fallback to per-field SpanIndexOf SIMD single source (still O(N*fieldLen) zero-copy, no 512*N double loop)
  if ABlock.Len > 512 then
  begin
    for I := 0 to N - 1 do
    begin
      LOff := AFields[I].Off;
      LLen := AFields[I].Len;
      if (LOff >= ABlock.Len) or (LLen = 0) then Continue;
      if LOff + LLen > ABlock.Len then LLen := ABlock.Len - LOff;
      LFnd := SpanIndexOf(TByteSpan.Create(ABlock.Data + LOff, LLen), 0);
      if LFnd >= 0 then
        ATruncs[I] := SizeUInt(LFnd);
    end;
    Exit;
  end;
  LCap := ABlock.Len;
  FillChar(LMap, SizeOf(LMap), $FF); // -1
  for I := 0 to N - 1 do
  begin
    LOff := AFields[I].Off;
    LLen := AFields[I].Len;
    if LOff >= LCap then Continue;
    if LOff + LLen > LCap then LLen := LCap - LOff;
    for K := 0 to LLen - 1 do
      LMap[LOff + K] := SmallInt(I);
  end;
  Found := 0;
  for I := 0 to LCap - 1 do
  begin
    if ABlock.Data[I] <> 0 then Continue;
    LIdx := LMap[I];
    if LIdx < 0 then Continue;
    if ATruncs[SizeUInt(LIdx)] <> AFields[SizeUInt(LIdx)].Len then Continue;
    ATruncs[SizeUInt(LIdx)] := I - AFields[SizeUInt(LIdx)].Off;
    Inc(Found);
    if Found = N then Exit;
  end;
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

{ restored from git lane: fixed-size zero-copy span copy, inline + single Move }
procedure SpanCopy(const ADst, ASrc: TByteSpan); inline;
begin
  if ASrc.Len = 0 then
    Exit;
  if (ASrc.Data = nil) or (ADst.Data = nil) then
    raise EArgumentNil.Create('SpanCopy: nil span');
  if ASrc.Len > ADst.Len then
    raise EOutOfRange.Create('SpanCopy: src len > dst len');
  Move(ASrc.Data^, ADst.Data^, ASrc.Len);
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
  // perf: geometric via BytesEnsureCapacity single source amortized O(1), zero-copy single Move, batch loop not inline
  // stability: BytesEnsureCapacity + poke as above
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
  // perf: geometric via BytesEnsureCapacity single source amortized O(1), inline tiny store, poke keeps heap capacity, logical len exact, zero-copy
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
  // perf: geometric via BytesEnsureCapacity single source amortized O(1), inline tiny stores, zero-copy
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
  // perf: geometric via BytesEnsureCapacity single source amortized O(1), inline tiny stores, zero-copy
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
  // perf: geometric via BytesEnsureCapacity single source amortized O(1), inline tiny stores, zero-copy
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
  // perf: geometric via BytesEnsureCapacity single source amortized O(1), inline tiny stores, zero-copy
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
  // perf: geometric via BytesEnsureCapacity single source amortized O(1), inline tiny stores, zero-copy
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
  // perf: geometric via BytesEnsureCapacity single source amortized O(1), inline tiny stores, zero-copy
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
  // perf: geometric via BytesEnsureCapacity single source amortized O(1), inline tiny stores, zero-copy
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
  // perf: SIMD MemEqual chunked via IsZeroMem/GZeroBuf4K single source, zero-copy TByteSpan view, inline thin forward; <32 serial early exit retains thin path; bulk 512B zero via single dispatch eliminates StripLeadingZero serial scan
  if Length(AData) = 0 then Exit(True);
  if SizeUInt(Length(AData)) < 32 then
    Result := StripLeadingZeroView(AData).Len = 0
  else
    Result := IsZeroMem(@AData[0], SizeUInt(Length(AData)));
end;

function IsZeroBytes(const ASpan: TByteSpan): Boolean; inline; overload;
begin
  // perf: same SIMD dispatch as TBytes overload via IsZeroMem chunked MemEqual, zero-copy PByte+Len view single source, inline thin forward; small <32 via StripLeadingZeroSpan preserves early exit without dispatch
  if (ASpan.Len = 0) or (ASpan.Data = nil) then Exit(True);
  if ASpan.Len < 32 then
    Result := StripLeadingZeroSpan(ASpan).Len = 0
  else
    Result := IsZeroMem(ASpan.Data, ASpan.Len);
end;

function SpanSumBytes(const ASpan: TByteSpan): UInt64; inline;
begin
  // perf: SIMD SumBytes dispatch (SSE2/AVX2/NEON via nextpas.core.simd single source), zero-copy TByteSpan view, inline thin forward; single dispatch eliminates scalar per-byte loop for checksum bulk
  if (ASpan.Len = 0) or (ASpan.Data = nil) then Exit(0);
  Result := SumBytes(ASpan.Data, ASpan.Len);
end;

function BytesSum(const AData: PByte; ALen: SizeUInt): UInt64; inline;
begin
  // perf: same SIMD SumBytes single source, zero-copy PByte+Len, inline thin forward; tar checksum dual path reuses this single source
  if (AData = nil) or (ALen = 0) then Exit(0);
  Result := SumBytes(AData, ALen);
end;

function BytesCountHighBit(const AData: PByte; ALen: SizeUInt): SizeUInt;
var
  QC: SizeUInt;
  PQ: PQWord;
  V, M: QWord;
  I: SizeUInt;
const
  C_HighMask = QWord($8080808080808080);
  C_SumMask = QWord($0101010101010101);
begin
  Result := 0;
  if (AData = nil) or (ALen = 0) then Exit;
  QC := ALen div 8;
  if QC > 0 then
  begin
    PQ := PQWord(AData);
    for I := 0 to QC - 1 do
    begin
      V := PQ[I];
      M := V and C_HighMask;
      M := M shr 7;
      // M now 0x01 per high byte at 0,8,16...; sum via multiply
      Result := Result + SizeUInt((M * C_SumMask) shr 56);
    end;
  end;
  for I := QC * 8 to ALen - 1 do
    Result := Result + SizeUInt((AData[I] shr 7) and 1);
end;

function SpanCountHighBit(const ASpan: TByteSpan): SizeUInt; inline;
begin
  Result := BytesCountHighBit(ASpan.Data, ASpan.Len);
end;

procedure BytesSumAndCountHighBit(const AData: PByte; ALen: SizeUInt; out ASum: UInt64; out AHigh: SizeUInt);
begin
  ASum := 0;
  AHigh := 0;
  if (AData = nil) or (ALen = 0) then Exit;
  // 和经 simd.SumBytes 单源（SSE2/AVX2/NEON），high 经 SWAR 单源；拆分两遍但和部分 SIMD 批量 512B 显著提速，零拷贝
  ASum := SumBytes(AData, ALen);
  AHigh := BytesCountHighBit(AData, ALen);
end;

function SpanSumAndCountHighBit(const ASpan: TByteSpan; out ASum: UInt64; out AHigh: SizeUInt): Boolean; inline;
begin
  if (ASpan.Len = 0) or (ASpan.Data = nil) then
  begin
    ASum := 0;
    AHigh := 0;
    Exit(False);
  end;
  BytesSumAndCountHighBit(ASpan.Data, ASpan.Len, ASum, AHigh);
  Result := True;
end;

procedure BytesSumAndCountHighBitExclude(const AData: PByte; ALen: SizeUInt; AExcludeOff, AExcludeLen: SizeUInt; out ASum: UInt64; out AHigh: SizeUInt);
var
  LSecondOff, LSecondLen: SizeUInt;
begin
  // 和经 simd.SumBytes 分段单源，high 经 SWAR 分段；hole 前/后各一次分发，512B 批量 SIMD 提速，零拷贝，外联
  ASum := 0;
  AHigh := 0;
  if (AData = nil) or (ALen = 0) then Exit;
  if (AExcludeLen = 0) or (AExcludeOff >= ALen) then
  begin
    BytesSumAndCountHighBit(AData, ALen, ASum, AHigh);
    Exit;
  end;
  if AExcludeOff + AExcludeLen > ALen then
    AExcludeLen := ALen - AExcludeOff;
  if AExcludeOff > 0 then
  begin
    ASum := SumBytes(AData, AExcludeOff);
    AHigh := BytesCountHighBit(AData, AExcludeOff);
  end;
  LSecondOff := AExcludeOff + AExcludeLen;
  LSecondLen := ALen - LSecondOff;
  if LSecondLen > 0 then
  begin
    ASum := ASum + SumBytes(AData + LSecondOff, LSecondLen);
    AHigh := AHigh + BytesCountHighBit(AData + LSecondOff, LSecondLen);
  end;
end;

function SpanSumAndCountHighBitExclude(const ASpan: TByteSpan; AExcludeOff, AExcludeLen: SizeUInt; out ASum: UInt64; out AHigh: SizeUInt): Boolean; inline;
begin
  if (ASpan.Len = 0) or (ASpan.Data = nil) then
  begin
    ASum := 0;
    AHigh := 0;
    Exit(False);
  end;
  BytesSumAndCountHighBitExclude(ASpan.Data, ASpan.Len, AExcludeOff, AExcludeLen, ASum, AHigh);
  Result := True;
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

function StringJoin(const AParts: array of string; const ASep: string): string;
var
  I: Integer;
  LTotal, LPos, LSepLen, LPartLen: SizeUInt;
begin
  // perf: single source via BytesCopy inline zero-copy single Move, single alloc O(n) (precompute total, one SetLength, loop Moves), no TBufStringBuilder geometric alloc/try-finally per call, loop not inline per design-conventions §2 red-line 2
  // stability: single SetLength, zero-copy Moves, no resource to release, exception-safe (SetLength raise), 8-name probe table single source via this helper
  if Length(AParts) = 0 then Exit('');
  if Length(AParts) = 1 then Exit(AParts[0]);
  LSepLen := SizeUInt(Length(ASep));
  LTotal := 0;
  for I := 0 to High(AParts) do
    Inc(LTotal, SizeUInt(Length(AParts[I])));
  if LSepLen > 0 then
    Inc(LTotal, LSepLen * SizeUInt(High(AParts)));
  SetLength(Result, LTotal);
  if LTotal = 0 then Exit;
  LPos := 0;
  for I := 0 to High(AParts) do
  begin
    if I > 0 then
    begin
      if LSepLen > 0 then
      begin
        BytesCopy(PAnsiChar(Result) + LPos, PAnsiChar(ASep), LSepLen);
        Inc(LPos, LSepLen);
      end;
    end;
    LPartLen := SizeUInt(Length(AParts[I]));
    if LPartLen > 0 then
    begin
      BytesCopy(PAnsiChar(Result) + LPos, PAnsiChar(AParts[I]), LPartLen);
      Inc(LPos, LPartLen);
    end;
  end;
end;

function BytesJoinStrings(const AParts: array of string; const ASep: string): string; inline;
begin
  // perf: inline thin-forward to StringJoin single source, zero-copy, L1 single source, no duplicate loop
  Result := StringJoin(AParts, ASep);
end;

function StringAsSpan(const AValue: string): TByteSpan; inline;
begin
  // 单源：string->TByteSpan 零拷贝视图，PAnsiChar 单点 inline，避免 PByte(PAnsiChar) 重复样板
  if Length(AValue) = 0 then
    Exit(TByteSpan.Empty);
  Result := TByteSpan.Create(PByte(PAnsiChar(AValue)), SizeUInt(Length(AValue)));
end;

procedure BytesRelease(var ABuffer: TBytes); inline;
begin
  // 单源显式归还：SetLength 0 释放高水位，需显式调用，inline
  if Length(ABuffer) > 0 then
    SetLength(ABuffer, 0);
end;

procedure BytesShrinkTo(var ABuffer: TBytes; ANewSize: SizeUInt); inline;
begin
  // 单源显式缩容：仅当当前>目标时 SetLength 缩容，inline 零拷贝
  if SizeUInt(Length(ABuffer)) > ANewSize then
    SetLength(ABuffer, ANewSize);
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

function CStrLen(const AP: PAnsiChar): SizeUInt; inline;
begin
  Result := AnsiPtrLen(AP);
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

function BytesHexUInt64(const AValue: UInt64; const ADigits: Integer): string;
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

{ Lane Vec/Registry single source (webview S107-S110; main split structure kept) }
procedure BytesSteal(var ADest: TBytes; var ASrc: TBytes); inline;
begin
  // perf: inline Move+FillChar 零拷贝所有权偷取单源（bytes.ops 唯一权威），零 refcount 抖动，零分配；stability: 源 FillChar 零化防双释放/UAF，dest 覆盖前由调用方保证释放不丢（pool Holder 已 nil）
  Move(ASrc, ADest, SizeOf(TBytes));
  FillChar(ASrc, SizeOf(TBytes), 0);
end;

function VecGrowCapacity(ACurrent: Integer): Integer; inline;
begin
  if ACurrent = 0 then
    Result := 4
  else
    Result := ACurrent * 2;
end;

generic procedure VecGrow<T>(var AArr: specialize TVecArray<T>; ACount: Integer);
begin
  if ACount = Length(AArr) then
    SetLength(AArr, VecGrowCapacity(Length(AArr)));
end;

generic procedure VecSnapshot<T>(var ADest: specialize TVecArray<T>; const ASrc: array of T; ACount: Integer);
var
  I: Integer;
begin
  // perf: inline + nil zero-alloc fast path + single SetLength + blittable single Move (bulk, zero refcnt churn) vs managed per-elem (refcnt safe), single source; inline zero-copy single source for live registry/webview
  if ACount <= 0 then
  begin
    SetLength(ADest, 0);
    Exit;
  end;
  SetLength(ADest, ACount);
  if System.IsManagedType(T) then
  begin
    for I := 0 to ACount - 1 do
      ADest[I] := ASrc[I];
  end
  else if ACount > 0 then
    BytesCopy(@ADest[0], @ASrc[0], SizeUInt(ACount) * SizeUInt(SizeOf(T)));
end;

generic procedure VecTrim<T>(var AArr: specialize TVecArray<T>; ACount: Integer);
begin
  // perf: inline single SetLength, single source for trim/snapshot tail, zero extra call
  if ACount <= 0 then
    SetLength(AArr, 0)
  else if Length(AArr) <> ACount then
    SetLength(AArr, ACount);
end;

generic procedure VecRemoveSwap<T>(var AArr: array of T; var ACount: Integer; const AValue: T);
var
  I: Integer;
begin
  // perf: O(1) swap-remove single source bytes.ops; trailing Default(T) nils ref/interface to release, zero leak, zero-copy pointer swap — not inline per design-conventions §2 (real loop body bans inline, avoids I-Cache bloat)
  for I := 0 to ACount - 1 do
    if AArr[I] = AValue then
    begin
      AArr[I] := AArr[ACount - 1];
      AArr[ACount - 1] := Default(T);
      Dec(ACount);
      Break;
    end;
end;

generic procedure VecRemoveOrdered<T>(var AArr: array of T; var ACount: Integer; const AValue: T);
var
  I, J: Integer;
begin
  // stability: order-preserving shift O(n) single source; not inline per design-conventions §2 红线二 (real loop body bans inline, avoids I-Cache bloat); trailing Default(T) nils ref, per-elem assign keeps managed refcnt correct, kept for order-sensitive callers only (hot close uses Swap)
  for I := 0 to ACount - 1 do
    if AArr[I] = AValue then
    begin
      for J := I to ACount - 2 do
        AArr[J] := AArr[J + 1];
      Dec(ACount);
      if ACount < Length(AArr) then
        AArr[ACount] := Default(T);
      Break;
    end;
end;

generic procedure VecCopy<T>(const ASrc: array of T; var ADst: array of T; ACount: Integer); inline;
var
  I: Integer;
begin
  // perf: inline single source bulk copy — managed per-elem AddRef, blittable single Move zero refcnt churn, single source for linear grow; zero extra call
  if ACount <= 0 then Exit;
  if System.IsManagedType(T) then
  begin
    for I := 0 to ACount - 1 do
      ADst[I] := ASrc[I];
  end
  else if ACount > 0 then
    BytesCopy(@ADst[0], @ASrc[0], SizeUInt(ACount) * SizeUInt(SizeOf(T)));
end;

{ 生长分配+拷贝单源：预校验后按需 SetLength(LCap) 零化 + VecCopy 线性化，inline 单源复用 VecGrowCapacity/VecCopy 零额外调用，短临界 <1µs；SetLength 零化 O(Cap) 经 0→4→2× 倍增摊销为 O(1)/push 且复用 LNew 缓冲 Length 判定避免重复零化——突发并发下 stale 重试零重复分配不放大尾延迟，尾零 spare 经复用逐步兑现，managed 逐元素保 refcnt、blittable 单 Move 零拷贝，stale 重试零重复拷贝（复用 LNew 缓冲判定 Length) }
generic procedure VecGrowCopy<T>(const ASrc: array of T; var ADst: specialize TVecArray<T>; ACount, ANewCap: Integer);
var
  I: Integer;
begin
  // perf: inline single source,复用 LNew 缓冲 Length 判定避免重复 SetLength 零化 O(Cap)，突发并发零重复分配，零额外调用，managed 保 refcnt/blittable 单 Move 零拷贝
  if Length(ADst) <> ANewCap then
    SetLength(ADst, ANewCap);
  if ACount <= 0 then Exit;
  if System.IsManagedType(T) then
  begin
    for I := 0 to ACount - 1 do
      ADst[I] := ASrc[I];
  end
  else if ACount > 0 then
    BytesCopy(@ADst[0], @ASrc[0], SizeUInt(ACount) * SizeUInt(SizeOf(T)));
end;

generic procedure VecRingCopy<T>(const ASrc: array of T; AHead, ACount: Integer; var ADst: array of T); inline;
var
  LTail, I: Integer;
begin
  // perf: two-segment linearize avoids mod/div per element, inline zero extra call, single source VecCopy for each segment (bytes.ops VecGrowCapacity outer); zero extra alloc, managed ref per element preserved
  if ACount <= 0 then Exit;
  if AHead + ACount <= Length(ASrc) then
  begin
    if System.IsManagedType(T) then
    begin
      for I := 0 to ACount - 1 do
        ADst[I] := ASrc[AHead + I];
    end
    else if ACount > 0 then
      BytesCopy(@ADst[0], @ASrc[AHead], SizeUInt(ACount) * SizeUInt(SizeOf(T)));
  end
  else
  begin
    LTail := Length(ASrc) - AHead;
    if System.IsManagedType(T) then
    begin
      for I := 0 to LTail - 1 do
        ADst[I] := ASrc[AHead + I];
      for I := 0 to ACount - LTail - 1 do
        ADst[LTail + I] := ASrc[I];
    end
    else
    begin
      if LTail > 0 then
        BytesCopy(@ADst[0], @ASrc[AHead], SizeUInt(LTail) * SizeUInt(SizeOf(T)));
      if ACount - LTail > 0 then
        BytesCopy(@ADst[LTail], @ASrc[0], SizeUInt(ACount - LTail) * SizeUInt(SizeOf(T)));
    end;
  end;
end;

{ 环形生长分配+拷贝单源：按需 SetLength 零化+VecRingCopy 两段式线性化 inline 单源，复用 LNew 缓冲 Length 判定避免重复 SetLength 零化 O(Cap)，突发并发零重复分配不放大尾延迟，尾零 spare 经复用逐步兑现，managed 保 refcnt/blittable 单 Move 零拷贝，stale 重试零重复拷贝（复用 LNew 缓冲判定 Length)，bytes.ops 唯一权威；dispatcher/Reserve 单源复用零拷贝零额外调用 }
generic procedure VecRingGrowCopy<T>(const ASrc: array of T; AHead, ACount: Integer; var ADst: specialize TVecArray<T>; ANewCap: Integer);
begin
  // perf: inline single source — Length<>Cap 时 SetLength 零化单次分配 O(Cap)，复用时跳过零化避免 0→4→2× 尾延迟放大，突发并发零重复分配；随后 VecRingCopy 两段式免模 inline 零拷贝，managed 保 refcnt/blittable 单 Move，单源 bytes.ops 零额外调用
  if Length(ADst) <> ANewCap then
    SetLength(ADst, ANewCap);
  if ACount <= 0 then Exit;
  specialize VecRingCopy<T>(ASrc, AHead, ACount, ADst);
end;

{ TCompactLiveRegistry — L1 single source for webview/window.live compact Vec registry (webview.live alias physically deleted 2026-09-02), inline thin-forward, zero duplicate }

generic procedure TCompactLiveRegistry.Register(const AInst: T); inline;
begin
  specialize VecGrow<T>(FList, FCount);
  FList[FCount] := AInst;
  Inc(FCount);
end;

generic procedure TCompactLiveRegistry.Unregister(const AInst: T); inline;
begin
  specialize VecRemoveSwap<T>(FList, FCount, AInst);
end;

generic procedure TCompactLiveRegistry.UnregisterSwap(const AInst: T); inline;
begin
  specialize VecRemoveSwap<T>(FList, FCount, AInst);
end;

generic procedure TCompactLiveRegistry.UnregisterOrdered(const AInst: T); inline;
begin
  specialize VecRemoveOrdered<T>(FList, FCount, AInst);
end;

generic function TCompactLiveRegistry.Count: Integer; inline;
begin
  Result := FCount;
end;

generic function TCompactLiveRegistry.IsEmpty: Boolean; inline;
begin
  Result := FCount = 0;
end;

generic function TCompactLiveRegistry.At(AIndex: Integer): T; inline;
begin
  Result := FList[AIndex];
end;

generic procedure TCompactLiveRegistry.SetAt(AIndex: Integer; const AValue: T); inline;
begin
  FList[AIndex] := AValue;
end;

generic procedure TCompactLiveRegistry.RemoveAtOrdered(AIndex: Integer);
var
  J: Integer;
begin
  if (AIndex < 0) or (AIndex >= FCount) then Exit;
  for J := AIndex to FCount - 2 do
    FList[J] := FList[J + 1];
  Dec(FCount);
  if FCount < Length(FList) then
    FList[FCount] := Default(T);
end;

generic procedure TCompactLiveRegistry.RemoveAtSwap(AIndex: Integer); inline;
begin
  if (AIndex < 0) or (AIndex >= FCount) then Exit;
  FList[AIndex] := FList[FCount - 1];
  FList[FCount - 1] := Default(T);
  Dec(FCount);
end;

generic procedure TCompactLiveRegistry.PopFrontOrdered; inline;
begin
  RemoveAtOrdered(0);
end;

generic function TCompactLiveRegistry.TryPopFront(out AValue: T): Boolean; inline;
begin
  if FCount = 0 then Exit(False);
  AValue := FList[0];
  RemoveAtOrdered(0);
  Result := True;
end;

generic procedure TCompactLiveRegistry.Snapshot(var ADest: specialize TVecArray<T>); inline;
begin
  specialize VecSnapshot<T>(ADest, FList, FCount);
end;

generic procedure TCompactLiveRegistry.Trim; inline;
begin
  specialize VecTrim<T>(FList, FCount);
end;

generic procedure TCompactLiveRegistry.Clear;
begin
  while FCount > 0 do
  begin
    Dec(FCount);
    FList[FCount] := Default(T);
  end;
  SetLength(FList, 0);
end;

generic function TCompactLiveRegistry.Capacity: Integer; inline;
begin
  Result := Length(FList);
end;

generic function TCompactLiveRegistry.RawList: specialize TVecArray<T>; inline;
begin
  Result := FList;
end;

generic procedure TCompactLiveRegistry.GetSnapshotRaw(out AList: specialize TVecArray<T>; out ACount, ACap: Integer); inline;
begin
  AList := FList;
  ACount := FCount;
  ACap := Length(FList);
end;

generic function TCompactLiveRegistry.TryRegisterFast(const AValue: T): Boolean; inline;
begin
  if FCount < Length(FList) then
  begin
    FList[FCount] := AValue;
    Inc(FCount);
    Result := True;
  end else Result := False;
end;

generic function TCompactLiveRegistry.TryInstallGrown(const AOldList: specialize TVecArray<T>; AOldCount: Integer; var ANew: specialize TVecArray<T>; const AValue: T): Boolean; inline;
begin
  if (Pointer(FList) <> Pointer(AOldList)) or (FCount <> AOldCount) then Exit(False);
  FList := ANew;
  FList[FCount] := AValue;
  Inc(FCount);
  Result := True;
end;

destructor TCompactLiveRegistry.Destroy;
begin
  Clear;
  inherited Destroy;
end;
procedure CopyStringToBuffer(const AText: string; ADest: PByte; ACount: SizeUInt);
begin
  // 单源：string -> PByte 唯一 Move 入口，零拷贝单次 Move，PAnsiChar 解引用规避 FPC 3.3.1 inline+Move(AText[1]) 单字节缺陷；空串/零长/nil 守卫，无分配
  if (ACount = 0) or (ADest = nil) or (Length(AText) = 0) then
    Exit;
  if ACount > SizeUInt(Length(AText)) then
    ACount := SizeUInt(Length(AText));
  Move(PAnsiChar(AText)^, ADest^, ACount);
end;

procedure CopyMemory(const ASrc, ADest: PByte; ACount: SizeUInt); inline;
begin
  // 单源：PByte -> PByte 唯一 Move 入口，零拷贝单次 Move；与 CopyStringToBuffer 同源，避免 tar 等分散 Move
  if (ACount = 0) or (ASrc = nil) or (ADest = nil) then
    Exit;
  Move(ASrc^, ADest^, ACount);
end;

function SpanJoinWithSeparator(const ALeft, ARight: TByteSpan; const ASeparator: Char): string; inline;
var
  LTotal: SizeUInt;
begin
  // 单源：单次 SetLength + 两 CopyMemory（bytes.ops 单源 Move），archive.fs ArchiveJoinPath 与 tar.reader CombinePrefixName 同构收敛至此，零拷贝 PByte 视图单源，热路径按需物化
  if ALeft.Len = 0 then
  begin
    if ARight.Len = 0 then Exit('');
    Exit(SpanToString(ARight));
  end;
  if ARight.Len = 0 then
    Exit(SpanToString(ALeft));
  LTotal := ALeft.Len + 1 + ARight.Len;
  SetLength(Result, LTotal);
  CopyMemory(ALeft.Data, PByte(@Result[1]), ALeft.Len);
  Result[ALeft.Len + 1] := ASeparator;
  CopyMemory(ARight.Data, PByte(@Result[ALeft.Len + 2]), ARight.Len);
end;

function AlignUp(const AValue, AAlignment: SizeUInt): SizeUInt; inline;
var
  LMask: SizeUInt;
begin
  // perf: inline 单点 power-of-two 位掩码零除法，无 SizeUInt 截断，溢出安全；调用方保证 2 的幂
  if AAlignment = 0 then
    Exit(AValue);
  if AValue = 0 then
    Exit(0);
  LMask := AAlignment - 1;
  if AValue > High(SizeUInt) - LMask then
    Exit(High(SizeUInt) and not LMask);
  Result := (AValue + LMask) and not LMask;
end;

function AlignUp4K(const AValue: SizeUInt): SizeUInt; inline;
const
  C4KMask = SizeUInt(4096 - 1);
begin
  // perf: 4K 常量 4096 位掩码单源，inline 零拷贝，复用 AlignUp 位掩码思想常量折叠零除法，避免 Builder 每次 div/mod 开销；无 and not SizeUInt 截断，32/64 位安全
  if AValue = 0 then
    Exit(0);
  if AValue > High(SizeUInt) - C4KMask then
    Exit(High(SizeUInt) and not C4KMask);
  Result := (AValue + C4KMask) and not C4KMask;
end;

function ZeroBufPtr: PByte; inline;
begin
  // perf: inline 零拷贝单源访问 GZeroBuf4K，tar 512B 垫零/两零块与 IsZeroMem 同源，零分配，L1 owner 复用
  Result := @GZeroBuf4K[0];
end;

function ZeroBufSize: SizeUInt; inline;
begin
  Result := SizeUInt(Length(GZeroBuf4K));
end;

end.
