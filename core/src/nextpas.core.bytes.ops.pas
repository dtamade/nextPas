unit nextpas.core.bytes.ops;

{$I nextpas.core.settings.inc}
{ bytes.ops — single source for Move/FillChar (BytesCopy inline Move(ASrc^,ADst^,ALen) @288-292, BytesZero FillChar) and capacity via bytes.ops.capacity leaf single source (0→64→2×, Webview 0→4→2×, while only in leaf — no duplicate while in ops, thin-forward, gate patrol).
  red-line 1: no inline indexed Move / SetLength+Move batch — 单源 BytesCopy/BytesZero inline single Move, BytesAppendRaw single site not inline (single SetLength+BytesCopy → single Move zero-copy).
  red-line 2: no inline loop/SIMD body — BytesReplicateCopy/BytesAppendRaw/Grow/BytesAppend* family not inline (loop/SetLength+Move batch I-Cache), capacity while only in bytes.ops.capacity leaf, thin-forward 30+ inline exempt but guarded (no loop+Move/SetLength in inline).
  单源 INV-5: text/ascii leaves thin-forward (no Move); high-frequency loops MUST use IBytesBuilder/ConcatMany single alloc (avoid per-call SetLength+Move O(n) → O(n²) if looped).
  gate: check_bytes_ops_source_contract.py — red-line 1/2 full patrol, BytesCopy inline single Move(ASrc^,ADst^,ALen) @289 zero-copy, BytesAppend* NotInline+O(n²) cross-module patrol, capacity single source while-only-in-leaf }

interface

uses
  nextpas.core.base,
  nextpas.core.base.utils,
  nextpas.core.bytes.base;

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
{ perf: LZ-dict overlapping replicate — not inline per red-line 2 (while doubling + Move I-Cache) — single source for CopyMatch, zero-copy, O(log n) Moves, overlap-safe }
procedure BytesReplicateCopy(ASrc, ADst: Pointer; ADist, ALen: SizeUInt);
{ respack/writer 单源：路径/内容零拷贝搬运与零填，inline 单 Move/Fill，无额外分配，显式标注 bytes.ops 单源防漂移 }
procedure BytesCopy(ADst, ASrc: Pointer; const ALen: SizeUInt); inline; // red-line 1/2: inline single Move(ASrc^,ADst^,ALen) zero-copy, no loop/SetLength, gate @288 patrol, facade thin-forward exempt but I-Cache guarded
procedure BytesZero(ADst: Pointer; const ALen: SizeUInt); inline; // red-line 1/2: inline single FillChar zero-copy, no loop, gate patrol, facade thin-forward exempt I-Cache guarded
procedure SpanZero(const ASpan: TByteSpan); inline;

{ 全局零页单源（.bss 零初值，4K 对齐页）：writer.stream 万槽零填共享，无栈分配/无重复 FillChar，零拷贝分段直写；按需切片避免小间隙 4K memset }
const
  BYTES_ZERO_PAGE_SIZE = 4096;
var
  BYTES_ZERO_PAGE: array[0..BYTES_ZERO_PAGE_SIZE - 1] of Byte;

function SpanConcat(const A, B: TByteSpan): TBytes;
function SpanCopySlice(const ASpan: TByteSpan; const AOffset, ALength: SizeUInt): TBytes;
function SpanClone(const ASpan: TByteSpan): TBytes;

function BytesEqual(const A, B: TBytes): Boolean; inline;
function BytesCompare(const A, B: TBytes): Integer; inline;
function BytesIndexOf(const AData: TBytes; const ANeedle: Byte): SizeInt; inline;
function BytesConcat(const A, B: TBytes): TBytes; inline;
{ perf: BytesAppend does SetLength+Move per call (O(n) → O(n²) if looped); MUST prefer IBytesBuilder (geometric via bytes.ops.capacity 0→64→2×) or BytesConcatMany/SpanConcatMany single alloc — zero-copy single BytesCopy via BytesAppendRaw single site; not inline per red-line 1/2 (SetLength+Move batch, I-Cache, gate: check_bytes_ops_source_contract.py cross-module loop-append patrol; per-call O(n) → O(n²) if looped, high-frequency MUST use builder) }
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
function BytesNextCapacity(AOld, ANeed: SizeUInt): SizeUInt; inline;
function BytesGrowCapacity(const ACurrent, ARequired: SizeUInt): SizeUInt;
function BytesGrowCapacityInt(const ACurrent, ARequired: Integer): Integer;
function BytesGrowCapacityWithMin(const ACurrent, ARequired, AMinGrow: SizeUInt): SizeUInt;
function BytesGrowCapacityIntWithMin(const ACurrent, ARequired, AMinGrow: Integer): Integer;
function WebviewGrowCapacityForReuse(const ACurrent: Integer): Integer; inline;
function WebviewGrowCapacity(const ACurrent: Integer): Integer; inline;
function BytesConcatMany(const AParts: array of TBytes): TBytes;
function SpanConcatMany(const AParts: array of TByteSpan): TBytes;
function BytesStartsWith(const AData, APrefix: TBytes): Boolean; inline;
function BytesEndsWith(const AData, ASuffix: TBytes): Boolean; inline;

{ Unsigned big-endian helpers (canonical single source for crypto/tls) }
{ perf: StripLeadingZero family single source is bytes.ops; View is zero-copy (no alloc), Span is single-pass, Bytes is single alloc or CoW share }
function StripLeadingZero(const AData: TBytes): TBytes;
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
{ Hex single source (uppercase fixed-width UInt64→hex, L1 canonical for vfs ETag etc., not inline per red-line 2 (loop+SetLength I-Cache), Span-less, reuses single HEX_UPPER table) }
function BytesHexUInt64(const AValue: UInt64; const ADigits: Integer): string;

implementation

uses
  nextpas.core.simd,
  nextpas.core.bytes.ops.capacity,
  nextpas.core.text.unicode.utils;

{ BytesEnsureCapacity/Reserve: safe SetLength-based growth (no header poke).
  Single source geometric via bytes.ops.capacity.BytesGrowCapacity (BYTES_BUILDER_MIN_GROW 0→64→2×, amortized O(1), INV-2/INV-5) — no duplicate while, no I-Cache bloat, threshold reuse.
  Old impl used PSizeInt header hack + MemSize slab probe; now capacity == Length via RTL, no global state, no unsafe pointer, thread-safe per var.
  perf: not inline per red-line 1/2 (SetLength batch + capacity loop I-Cache) — zero-copy BytesCopy in BytesAppend* callers (single BytesCopy per append), no extra alloc in failure path. For looped/high-frequency appends MUST use
  IBytesBuilder (preallocated Grow) or BytesConcatMany/SpanConcatMany to avoid
  O(n²) SetLength churn (single alloc, geometric). Stability: SetLength exception-safe; no manual header writes. }

procedure BytesEnsureCapacity(var ADest: TBytes; const ARequired: SizeUInt);
var
  LNewCap: SizeUInt;
begin
  if SizeUInt(Length(ADest)) >= ARequired then
    Exit;
  // capacity single source reuse: geometric via bytes.ops.capacity (0→64→2×), no duplicate while/I-Cache, threshold single source
  LNewCap := nextpas.core.bytes.ops.capacity.BytesGrowCapacity(SizeUInt(Length(ADest)), ARequired);
  SetLength(ADest, LNewCap);
end;

procedure BytesReserve(var ADest: TBytes; const AAdditional: SizeUInt);
var
  LNeed: SizeUInt;
begin
  if AAdditional = 0 then
    Exit;
  // overflow guard: if Length + Additional wraps, let SetLength raise
  LNeed := SizeUInt(Length(ADest)) + AAdditional;
  BytesEnsureCapacity(ADest, LNeed);
end;

function BytesNextCapacity(AOld, ANeed: SizeUInt): SizeUInt; inline;
begin
  // perf: inline thin-forward zero extra call, capacity single source reuse via bytes.ops.capacity (0→64→2× geometric, amortized O(1), no duplicate while/I-Cache)
  Result := nextpas.core.bytes.ops.capacity.BytesNextCapacity(AOld, ANeed);
end;

function BytesGrowCapacity(const ACurrent, ARequired: SizeUInt): SizeUInt;
begin
  Result := nextpas.core.bytes.ops.capacity.BytesGrowCapacity(ACurrent, ARequired);
end;

function BytesGrowCapacityInt(const ACurrent, ARequired: Integer): Integer;
begin
  Result := nextpas.core.bytes.ops.capacity.BytesGrowCapacityInt(ACurrent, ARequired);
end;

function BytesGrowCapacityWithMin(const ACurrent, ARequired, AMinGrow: SizeUInt): SizeUInt;
begin
  Result := nextpas.core.bytes.ops.capacity.BytesGrowCapacityWithMin(ACurrent, ARequired, AMinGrow);
end;

function BytesGrowCapacityIntWithMin(const ACurrent, ARequired, AMinGrow: Integer): Integer;
begin
  Result := nextpas.core.bytes.ops.capacity.BytesGrowCapacityIntWithMin(ACurrent, ARequired, AMinGrow);
end;

function WebviewGrowCapacityForReuse(const ACurrent: Integer): Integer; inline;
begin
  Result := nextpas.core.bytes.ops.capacity.WebviewGrowCapacityForReuse(ACurrent);
end;

function WebviewGrowCapacity(const ACurrent: Integer): Integer; inline;
begin
  // perf: inline thin-forward alias unified peripheral WebviewGrowCapacity — reuse bytes.ops.capacity.WebviewGrowCapacity single source 0→4→2×, zero extra call
  Result := nextpas.core.bytes.ops.capacity.WebviewGrowCapacity(ACurrent);
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

procedure BytesReplicateCopy(ASrc, ADst: Pointer; ADist, ALen: SizeUInt);
var
  LSrc, LDst: PByte;
  LPeriod, LDone, LRem, LChunk: SizeUInt;
begin
  if ALen = 0 then
    Exit;
  LSrc := PByte(ASrc);
  LDst := PByte(ADst);
  LPeriod := ADist + 1;
  if ALen <= LPeriod then
  begin
    BytesCopy(LDst, LSrc, ALen);
    Exit;
  end;
  BytesCopy(LDst, LSrc, LPeriod);
  LDone := LPeriod;
  LRem := ALen - LPeriod;
  Inc(LDst, LPeriod);
  while LRem > 0 do
  begin
    LChunk := LDone;
    if LChunk > LRem then
      LChunk := LRem;
    BytesCopy(LDst, LDst - LDone, LChunk);
    Inc(LDst, LChunk);
    Dec(LRem, LChunk);
    Inc(LDone, LChunk);
  end;
end;

procedure BytesCopy(ADst, ASrc: Pointer; const ALen: SizeUInt); inline;
begin
  // gate: must stay inline single Move(ASrc^,ADst^,ALen) zero-copy, red-line 1 禁索引Move/SetLength+Move批量 单源 not inline — patrol check_bytes_ops_source_contract.py 全量巡检
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

function SpanConcat(const A, B: TByteSpan): TBytes;
begin
  Result := nil;
  SetLength(Result, A.Len + B.Len);
  if A.Len > 0 then
    BytesCopy(@Result[0], A.Data, A.Len);
  if B.Len > 0 then
    BytesCopy(@Result[A.Len], B.Data, B.Len);
end;

function SpanCopySlice(const ASpan: TByteSpan; const AOffset, ALength: SizeUInt): TBytes;
begin
  Result := nil;
  if (ALength > 0) and (AOffset + ALength > ASpan.Len) then
    raise EOutOfRange.Create('SpanCopySlice: offset+length exceeds span');
  SetLength(Result, ALength);
  if ALength > 0 then
    BytesCopy(@Result[0], ASpan.Data + AOffset, ALength);
end;

function SpanClone(const ASpan: TByteSpan): TBytes;
begin
  Result := nil;
  SetLength(Result, ASpan.Len);
  if ASpan.Len > 0 then
    BytesCopy(@Result[0], ASpan.Data, ASpan.Len);
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
      BytesCopy(@Result[LOff], AParts[I].Data, AParts[I].Len);
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
      BytesCopy(@Result[LOff], @AParts[I][0], SizeUInt(Length(AParts[I])));
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

procedure BytesAppendRaw(var ADest: TBytes; ASrc: PByte; ALen: SizeUInt);
var LOldLen: SizeUInt;
begin
  // internal single source for BytesAppend batch: not inline per red-line 1/2 (SetLength+BytesCopy batch I-Cache single site), zero-copy BytesCopy single Move, no header poke; loops MUST use IBytesBuilder/ConcatMany single alloc (O(n²) churn avoidance)
  if (ASrc = nil) or (ALen = 0) then Exit;
  LOldLen := SizeUInt(Length(ADest));
  SetLength(ADest, LOldLen + ALen);
  BytesCopy(@ADest[LOldLen], ASrc, ALen);
end;

procedure BytesAppend(var ADest: TBytes; const ASrc: TBytes); overload;
begin
  // not inline per red-line 1/2 — single source via BytesAppendRaw → BytesCopy (INV-5), zero-copy single Move; high-frequency/loops MUST use IBytesBuilder (geometric Grow) or BytesConcatMany/SpanConcatMany single allocation
  if Length(ASrc) = 0 then Exit;
  BytesAppendRaw(ADest, @ASrc[0], SizeUInt(Length(ASrc)));
end;

procedure BytesAppend(var ADest: TBytes; const ASrc: PByte; const ASrcLen: SizeUInt); overload;
begin
  // not inline per red-line 1/2 — single source via BytesAppendRaw → BytesCopy, zero-copy single Move; loops MUST use IBytesBuilder/ConcatMany
  BytesAppendRaw(ADest, ASrc, ASrcLen);
end;

procedure BytesAppendByte(var ADest: TBytes; AValue: Byte);
var LBuf: Byte;
begin
  // not inline per red-line 1/2 (per-call SetLength O(n) → O(n²) if looped, single source via BytesAppendRaw) — single use only; loops MUST use IBytesBuilder geometric (BYTES_BUILDER_MIN_GROW 0→64→2× single source) or BytesConcatMany/SpanConcatMany single alloc; gate: check_bytes_ops_source_contract.py cross-module loop-append patrol; zero-copy via BytesAppendRaw → single BytesCopy Move (stack LBuf single Move, no loop/I-Cache)
  LBuf := AValue;
  BytesAppendRaw(ADest, @LBuf, 1);
end;

procedure BytesAppendUInt16BE(var ADest: TBytes; AValue: Word);
var LBuf: array[0..1] of Byte;
begin
  // not inline per red-line 1/2 (SetLength batch O(n) → O(n²) if looped, single source via BytesAppendRaw) — single use only; loops MUST use IBytesBuilder geometric 0→64→2× or BytesConcatMany single alloc; gate patrol
  LBuf[0] := Byte(AValue shr 8);
  LBuf[1] := Byte(AValue);
  BytesAppendRaw(ADest, @LBuf[0], 2);
end;

procedure BytesAppendUInt24BE(var ADest: TBytes; AValue: Cardinal);
var LBuf: array[0..2] of Byte;
begin
  // not inline per red-line 1/2 (SetLength batch O(n) → O(n²) if looped, single source via BytesAppendRaw) — single use; loops MUST use IBytesBuilder/ConcatMany; gate patrol
  LBuf[0] := Byte(AValue shr 16);
  LBuf[1] := Byte(AValue shr 8);
  LBuf[2] := Byte(AValue);
  BytesAppendRaw(ADest, @LBuf[0], 3);
end;

procedure BytesAppendUInt32BE(var ADest: TBytes; AValue: Cardinal);
var LBuf: array[0..3] of Byte;
begin
  // not inline per red-line 1/2 (SetLength batch O(n) → O(n²) if looped, single source via BytesAppendRaw → BytesCopy single Move zero-copy) — single use; loops MUST use IBytesBuilder/ConcatMany
  LBuf[0] := Byte(AValue shr 24);
  LBuf[1] := Byte(AValue shr 16);
  LBuf[2] := Byte(AValue shr 8);
  LBuf[3] := Byte(AValue);
  BytesAppendRaw(ADest, @LBuf[0], 4);
end;

procedure BytesAppendUInt16LE(var ADest: TBytes; AValue: Word);
var LBuf: array[0..1] of Byte;
begin
  // not inline per red-line 1/2 (SetLength batch O(n) → O(n²) if looped, single source via BytesAppendRaw) — single use; loops MUST use IBytesBuilder/ConcatMany; gate patrol
  LBuf[0] := Byte(AValue);
  LBuf[1] := Byte(AValue shr 8);
  BytesAppendRaw(ADest, @LBuf[0], 2);
end;

procedure BytesAppendUInt32LE(var ADest: TBytes; AValue: Cardinal);
var LBuf: array[0..3] of Byte;
begin
  // not inline per red-line 1/2 (SetLength batch O(n) → O(n²) if looped, single source via BytesAppendRaw) — single use; loops MUST use IBytesBuilder/ConcatMany; gate patrol
  LBuf[0] := Byte(AValue);
  LBuf[1] := Byte(AValue shr 8);
  LBuf[2] := Byte(AValue shr 16);
  LBuf[3] := Byte(AValue shr 24);
  BytesAppendRaw(ADest, @LBuf[0], 4);
end;

procedure BytesAppendUInt64BE(var ADest: TBytes; AValue: QWord);
var LBuf: array[0..7] of Byte;
begin
  // not inline per red-line 1/2 (SetLength batch O(n) → O(n²) if looped, single source via BytesAppendRaw) — single use; loops MUST use IBytesBuilder/ConcatMany; gate patrol
  LBuf[0] := Byte(AValue shr 56);
  LBuf[1] := Byte(AValue shr 48);
  LBuf[2] := Byte(AValue shr 40);
  LBuf[3] := Byte(AValue shr 32);
  LBuf[4] := Byte(AValue shr 24);
  LBuf[5] := Byte(AValue shr 16);
  LBuf[6] := Byte(AValue shr 8);
  LBuf[7] := Byte(AValue);
  BytesAppendRaw(ADest, @LBuf[0], 8);
end;

procedure BytesAppendUInt64LE(var ADest: TBytes; AValue: QWord);
var LBuf: array[0..7] of Byte;
begin
  // not inline per red-line 1/2 (SetLength batch O(n) → O(n²) if looped, single source via BytesAppendRaw) — single use; loops MUST use IBytesBuilder/ConcatMany; gate patrol
  LBuf[0] := Byte(AValue);
  LBuf[1] := Byte(AValue shr 8);
  LBuf[2] := Byte(AValue shr 16);
  LBuf[3] := Byte(AValue shr 24);
  LBuf[4] := Byte(AValue shr 32);
  LBuf[5] := Byte(AValue shr 40);
  LBuf[6] := Byte(AValue shr 48);
  LBuf[7] := Byte(AValue shr 56);
  BytesAppendRaw(ADest, @LBuf[0], 8);
end;

function BytesStartsWith(const AData, APrefix: TBytes): Boolean;
begin
  Result := SpanStartsWith(TByteSpan.FromBytes(AData), TByteSpan.FromBytes(APrefix));
end;

function BytesEndsWith(const AData, ASuffix: TBytes): Boolean;
begin
  Result := SpanEndsWith(TByteSpan.FromBytes(AData), TByteSpan.FromBytes(ASuffix));
end;

function StripLeadingZero(const AData: TBytes): TBytes;
var
  L, LOff: SizeUInt;
  P: PByte;
begin
  // not inline per red-line 1/2 (SetLength+Move batch + while loop I-Cache) — single scan zero-copy CoW single alloc+Move
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
  // trimmed: single allocation + BytesCopy, no extra SpanClone allocation
  SetLength(Result, L - LOff);
  if L - LOff > 0 then
    BytesCopy(@Result[0], P + LOff, L - LOff);
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
end;

function BytesIsGzipHeader(const AHeader: TBytes; const ATotalSize: Int64): Boolean; inline;
begin
  // perf: inline single source forward; ATotalSize kept for transform signature compat, zero-copy reuse
  Result := BytesIsGzip(AHeader);
end;

function SpanToString(const ASpan: TByteSpan): string; inline;
begin
  if ASpan.Len = 0 then
    Exit('');
  SetString(Result, PAnsiChar(ASpan.Data), ASpan.Len);
end;

function SpanToUTF8(const ASpan: TByteSpan): string; inline;
begin
  Result := SpanToString(ASpan);
end;

function BytesToString(const ABytes: TBytes): string; inline;
begin
  Result := SpanToString(TByteSpan.FromBytes(ABytes));
end;

function BytesToUTF8(const ABytes: TBytes): string; inline;
begin
  Result := BytesToString(ABytes);
end;

function StringToBytes(const AText: string): TBytes;
begin
  // not inline per red-line 1 (SetLength+Move batch I-Cache) — single BytesCopy zero-copy PAnsiChar single source
  SetLength(Result, Length(AText));
  if Length(AText) > 0 then
    BytesCopy(@Result[0], PAnsiChar(AText), SizeUInt(Length(AText)));
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
  Result := SpanToString(LSpan);
end;

function StringLowerAsciiAware(const S: string): string; inline;
begin
  Result := nextpas.core.text.unicode.utils.ToLowerAsciiAware(S);
end;

const
  HEX_UPPER_BYTESOPS: array[0..15] of AnsiChar = '0123456789ABCDEF';

function BytesHexUInt64(const AValue: UInt64; const ADigits: Integer): string;
var I: Integer; V: UInt64;
begin
  // not inline per red-line 2 (loop+SetLength I-Cache) — fixed-width hex single pass zero-copy via table
  SetLength(Result, ADigits);
  V := AValue;
  for I := ADigits - 1 downto 0 do
  begin
    Result[I + 1] := HEX_UPPER_BYTESOPS[V and $F];
    V := V shr 4;
  end;
end;

end.
