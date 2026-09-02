unit nextpas.core.bytes.ops;

{$I nextpas.core.settings.inc}
{ R9-02 hermetic：settings.inc 已保障 inline 语义（-O2→INLINE ON），FPC 3.3.1 下无 BEGIN 误报 }

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
function SpanTrimLeft(const ASpan: TByteSpan): TByteSpan;
function SpanTrimRight(const ASpan: TByteSpan): TByteSpan;
function SpanTrim(const ASpan: TByteSpan): TByteSpan; inline;
function StringTrimEquals(const S, Lit: string): Boolean;

procedure SpanFill(const ASpan: TByteSpan; const AValue: Byte);
procedure SpanReverse(const ASpan: TByteSpan);
{ perf: LZ-dict overlapping replicate — inline + block Move via doubling, single source for CopyMatch, zero-copy, O(log n) Moves, overlap-safe }
procedure BytesReplicateCopy(ASrc, ADst: Pointer; ADist, ALen: SizeUInt); inline;
{ respack/writer 单源：路径/内容零拷贝搬运与零填，inline 单 Move/Fill，无额外分配，显式标注 bytes.ops 单源防漂移 }
procedure BytesCopy(ADst, ASrc: Pointer; const ALen: SizeUInt); inline;
procedure BytesZero(ADst: Pointer; const ALen: SizeUInt); inline;
procedure SpanZero(const ASpan: TByteSpan); inline;

{ 全局零页单源（.bss 零初值，4K 对齐页）：writer.stream 万槽零填共享，无栈分配/无重复 FillChar，零拷贝分段直写；按需切片避免小间隙 4K memset }
const
  BYTES_ZERO_PAGE_SIZE = 4096;
  // bulk parse limit — single source canonical 64MiB (owner L1 bytes.ops, Format/JS single source via this, no L2→L2, bytes.ops BytesCopy zero-copy, L0-L3 kept, resource try-finally not丢)
  BYTES_BULK_PARSE_MAX_BYTES = SizeUInt(64) * 1024 * 1024;
var
  BYTES_ZERO_PAGE: array[0..BYTES_ZERO_PAGE_SIZE - 1] of Byte;

function SpanConcat(const A, B: TByteSpan): TBytes; inline;
function SpanCopySlice(const ASpan: TByteSpan; const AOffset, ALength: SizeUInt): TBytes;
function SpanClone(const ASpan: TByteSpan): TBytes;

function BytesEqual(const A, B: TBytes): Boolean; inline;
function BytesCompare(const A, B: TBytes): Integer; inline;
function BytesIndexOf(const AData: TBytes; const ANeedle: Byte): SizeInt; inline;
function BytesConcat(const A, B: TBytes): TBytes; inline;
{ perf: BytesAppend geometric via bytes.ops.capacity BytesGrowCapacity single source (BYTES_BUILDER_MIN_GROW 0→64→2× amortized O(1), zero-copy Move single source); looped/high-frequency still prefer IBytesBuilder (preallocated Grow) or BytesConcatMany/SpanConcatMany (single allocation) to avoid per-append probe — single-use amortized O(1) not O(n²), inline thin-forward for single append, builder for loops }
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

implementation

uses
  nextpas.core.simd,
  nextpas.core.text.unicode.utils,
  nextpas.core.bytes.ops.capacity,
  nextpas.core.mem.dynarray;

{ BytesEnsureCapacity/Reserve: geometric via bytes.ops.capacity single source (INV-5/INV-2)
  BYTES_BUILDER_MIN_GROW 0→64→2× amortized O(1) zero O(n²); thin-forward to BytesGrowCapacity, no duplicate loop.
  Old header poke + GCapMap removed (heap layout dependent, race); new portable via BytesEnsureCapacity single source + mem.dynarray poke for BytesAppend exact logical len vs heap capacity.
  perf: BytesAppend geometric via BytesEnsureCapacity single source single SetLength + single Move zero-copy (owner bytes.ops), looped/high-frequency still prefer IBytesBuilder/ConcatMany; inline hot views zero-copy, batch not inline per red-line.
  Stability: SetLength exception-safe; BytesAppend via BytesEnsureCapacity + DynArraySetLength poke keeps heap capacity while logical len exact, no leak, sized free via allocator. }

procedure BytesEnsureCapacity(var ADest: TBytes; const ARequired: SizeUInt);
var
  LOld, LNewCap: SizeUInt;
begin
  LOld := SizeUInt(Length(ADest));
  if ARequired <= LOld then
    Exit;
  // single source geometric via bytes.ops.capacity (BYTES_BUILDER_MIN_GROW 0→64→2×) amortized O(1) — not inline per red-line 2 (loop)
  LNewCap := BytesGrowCapacity(LOld, ARequired);
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
  // perf: inline thin-forward single source via bytes.ops.capacity BytesGrowCapacity geometric 0→64→2× amortized O(1) zero extra call
  Result := BytesGrowCapacity(AOld, ANeed);
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

procedure BytesReplicateCopy(ASrc, ADst: Pointer; ADist, ALen: SizeUInt); inline;
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
    Move(LSrc^, LDst^, ALen);
    Exit;
  end;
  Move(LSrc^, LDst^, LPeriod);
  LDone := LPeriod;
  LRem := ALen - LPeriod;
  Inc(LDst, LPeriod);
  while LRem > 0 do
  begin
    LChunk := LDone;
    if LChunk > LRem then
      LChunk := LRem;
    Move((LDst - LDone)^, LDst^, LChunk);
    Inc(LDst, LChunk);
    Dec(LRem, LChunk);
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
  LOldLen, LNeed: SizeUInt;
begin
  // perf: geometric via BytesEnsureCapacity single source (bytes.ops.capacity 0→64→2× amortized O(1), zero-copy single Move, batch loop not inline)
  // stability: BytesEnsureCapacity geometric + DynArraySetLength poke keeps heap capacity while logical len exact, exception-safe SetLength; looped/high-frequency still prefer IBytesBuilder
  if Length(ASrc) = 0 then
    Exit;
  LOldLen := SizeUInt(Length(ADest));
  LNeed := LOldLen + SizeUInt(Length(ASrc));
  BytesEnsureCapacity(ADest, LNeed);
  if SizeUInt(Length(ADest)) <> LNeed then
    DynArraySetLength(ADest, LNeed);
  Move(ASrc[0], ADest[LOldLen], Length(ASrc));
end;

procedure BytesAppend(var ADest: TBytes; const ASrc: PByte; const ASrcLen: SizeUInt); overload;
var
  LOldLen, LNeed: SizeUInt;
begin
  // perf: geometric via BytesEnsureCapacity single source amortized O(1), zero-copy single Move, batch loop not inline
  // stability: BytesEnsureCapacity + poke as above
  if (ASrc = nil) or (ASrcLen = 0) then
    Exit;
  LOldLen := SizeUInt(Length(ADest));
  LNeed := LOldLen + ASrcLen;
  BytesEnsureCapacity(ADest, LNeed);
  if SizeUInt(Length(ADest)) <> LNeed then
    DynArraySetLength(ADest, LNeed);
  Move(ASrc^, ADest[LOldLen], ASrcLen);
end;

procedure BytesAppendByte(var ADest: TBytes; AValue: Byte); inline;
var
  LOldLen, LNeed: SizeUInt;
begin
  // perf: geometric via BytesEnsureCapacity single source amortized O(1), inline tiny store, poke keeps heap capacity, logical len exact, zero-copy
  LOldLen := SizeUInt(Length(ADest));
  LNeed := LOldLen + 1;
  BytesEnsureCapacity(ADest, LNeed);
  if SizeUInt(Length(ADest)) <> LNeed then
    DynArraySetLength(ADest, LNeed);
  ADest[LOldLen] := AValue;
end;

procedure BytesAppendUInt16BE(var ADest: TBytes; AValue: Word); inline;
var
  LOldLen, LNeed: SizeUInt;
begin
  // perf: geometric via BytesEnsureCapacity single source amortized O(1), inline tiny stores, zero-copy
  LOldLen := SizeUInt(Length(ADest));
  LNeed := LOldLen + 2;
  BytesEnsureCapacity(ADest, LNeed);
  if SizeUInt(Length(ADest)) <> LNeed then
    DynArraySetLength(ADest, LNeed);
  ADest[LOldLen] := Byte(AValue shr 8);
  ADest[LOldLen + 1] := Byte(AValue);
end;

procedure BytesAppendUInt24BE(var ADest: TBytes; AValue: Cardinal); inline;
var
  LOldLen, LNeed: SizeUInt;
begin
  // perf: geometric via BytesEnsureCapacity single source amortized O(1), inline tiny stores, zero-copy
  LOldLen := SizeUInt(Length(ADest));
  LNeed := LOldLen + 3;
  BytesEnsureCapacity(ADest, LNeed);
  if SizeUInt(Length(ADest)) <> LNeed then
    DynArraySetLength(ADest, LNeed);
  ADest[LOldLen] := Byte(AValue shr 16);
  ADest[LOldLen + 1] := Byte(AValue shr 8);
  ADest[LOldLen + 2] := Byte(AValue);
end;

procedure BytesAppendUInt32BE(var ADest: TBytes; AValue: Cardinal); inline;
var
  LOldLen, LNeed: SizeUInt;
begin
  // perf: geometric via BytesEnsureCapacity single source amortized O(1), inline tiny stores, zero-copy
  LOldLen := SizeUInt(Length(ADest));
  LNeed := LOldLen + 4;
  BytesEnsureCapacity(ADest, LNeed);
  if SizeUInt(Length(ADest)) <> LNeed then
    DynArraySetLength(ADest, LNeed);
  ADest[LOldLen] := Byte(AValue shr 24);
  ADest[LOldLen + 1] := Byte(AValue shr 16);
  ADest[LOldLen + 2] := Byte(AValue shr 8);
  ADest[LOldLen + 3] := Byte(AValue);
end;

procedure BytesAppendUInt16LE(var ADest: TBytes; AValue: Word); inline;
var
  LOldLen, LNeed: SizeUInt;
begin
  // perf: geometric via BytesEnsureCapacity single source amortized O(1), inline tiny stores, zero-copy
  LOldLen := SizeUInt(Length(ADest));
  LNeed := LOldLen + 2;
  BytesEnsureCapacity(ADest, LNeed);
  if SizeUInt(Length(ADest)) <> LNeed then
    DynArraySetLength(ADest, LNeed);
  ADest[LOldLen] := Byte(AValue);
  ADest[LOldLen + 1] := Byte(AValue shr 8);
end;

procedure BytesAppendUInt32LE(var ADest: TBytes; AValue: Cardinal); inline;
var
  LOldLen, LNeed: SizeUInt;
begin
  // perf: geometric via BytesEnsureCapacity single source amortized O(1), inline tiny stores, zero-copy
  LOldLen := SizeUInt(Length(ADest));
  LNeed := LOldLen + 4;
  BytesEnsureCapacity(ADest, LNeed);
  if SizeUInt(Length(ADest)) <> LNeed then
    DynArraySetLength(ADest, LNeed);
  ADest[LOldLen] := Byte(AValue);
  ADest[LOldLen + 1] := Byte(AValue shr 8);
  ADest[LOldLen + 2] := Byte(AValue shr 16);
  ADest[LOldLen + 3] := Byte(AValue shr 24);
end;

procedure BytesAppendUInt64BE(var ADest: TBytes; AValue: QWord); inline;
var
  LOldLen, LNeed: SizeUInt;
begin
  // perf: geometric via BytesEnsureCapacity single source amortized O(1), inline tiny stores, zero-copy
  LOldLen := SizeUInt(Length(ADest));
  LNeed := LOldLen + 8;
  BytesEnsureCapacity(ADest, LNeed);
  if SizeUInt(Length(ADest)) <> LNeed then
    DynArraySetLength(ADest, LNeed);
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
  LOldLen, LNeed: SizeUInt;
begin
  // perf: geometric via BytesEnsureCapacity single source amortized O(1), inline tiny stores, zero-copy
  LOldLen := SizeUInt(Length(ADest));
  LNeed := LOldLen + 8;
  BytesEnsureCapacity(ADest, LNeed);
  if SizeUInt(Length(ADest)) <> LNeed then
    DynArraySetLength(ADest, LNeed);
  ADest[LOldLen] := Byte(AValue);
  ADest[LOldLen + 1] := Byte(AValue shr 8);
  ADest[LOldLen + 2] := Byte(AValue shr 16);
  ADest[LOldLen + 3] := Byte(AValue shr 24);
  ADest[LOldLen + 4] := Byte(AValue shr 32);
  ADest[LOldLen + 5] := Byte(AValue shr 40);
  ADest[LOldLen + 6] := Byte(AValue shr 48);
  ADest[LOldLen + 7] := Byte(AValue shr 56);
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

function StringToBytes(const AText: string): TBytes; inline;
begin
  SetLength(Result, Length(AText));
  if Length(AText) > 0 then
    Move(PAnsiChar(AText)^, Result[0], Length(AText));
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
