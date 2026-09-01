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

procedure SpanFill(const ASpan: TByteSpan; const AValue: Byte);
procedure SpanReverse(const ASpan: TByteSpan);
{ perf: LZ-dict overlapping replicate — inline + block Move via doubling, single source for CopyMatch, zero-copy, O(log n) Moves, overlap-safe }
procedure BytesReplicateCopy(ASrc, ADst: Pointer; ADist, ALen: SizeUInt); inline;

function SpanConcat(const A, B: TByteSpan): TBytes; inline;
function SpanCopySlice(const ASpan: TByteSpan; const AOffset, ALength: SizeUInt): TBytes;
function SpanClone(const ASpan: TByteSpan): TBytes;

function BytesEqual(const A, B: TBytes): Boolean; inline;
function BytesCompare(const A, B: TBytes): Integer; inline;
function BytesIndexOf(const AData: TBytes; const ANeedle: Byte): SizeInt; inline;
function BytesConcat(const A, B: TBytes): TBytes; inline;
{ perf: BytesAppend does SetLength+Move per call (O(n) realloc). For high-frequency
  or looped appends prefer IBytesBuilder (preallocated Grow) or BytesConcatMany/
  SpanConcatMany (single allocation) to avoid O(n²) churn. Keep inline for single-use
  convenience only. }
procedure BytesAppend(var ADest: TBytes; const ASrc: TBytes); inline; overload;
procedure BytesAppend(var ADest: TBytes; const ASrc: PByte; const ASrcLen: SizeUInt); inline; overload;
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
function BytesToString(const ABytes: TBytes): string; inline;
function BytesToUTF8(const ABytes: TBytes): string; inline;
function StringToBytes(const AText: string): TBytes;
function BytesSliceToString(const ABytes: TBytes; const AOffset,
  ALength: SizeUInt): string; inline;
function StringLowerAsciiAware(const S: string): string; inline; { 薄转发 text.unicode.utils.ToLowerAsciiAware 单源：ASCII 预检+零拷贝，owner text.unicode.utils }

implementation

uses
  nextpas.core.simd,
  nextpas.core.text.unicode.utils;

{ BytesEnsureCapacity/Reserve: safe SetLength-based growth (no header poke).
  Old impl used PSizeInt(Pointer(A))[-1] header hack + GCapMap/MemSize slab probe
  for amortized slack; that depends on FPC heap layout and races under multithread.
  New: capacity == Length (single source via RTL), no global state, no unsafe
  pointer arithmetic, fully portable to nextPas compiler and thread-safe per var.
  perf: inline + zero-copy Move in BytesAppend* callers (single Move per append);
  no extra alloc in failure path. For looped/high-frequency appends use
  IBytesBuilder (preallocated Grow) or BytesConcatMany/SpanConcatMany to avoid
  O(n²) SetLength churn. Stability: SetLength is exception-safe; no manual header
  writes that could corrupt heap on exception. }

procedure BytesEnsureCapacity(var ADest: TBytes; const ARequired: SizeUInt);
var
  LOld, LNewCap: SizeUInt;
begin
  LOld := SizeUInt(Length(ADest));
  if ARequired <= LOld then
    Exit;
  // single doubling growth to amortize when called directly; callers that need
  // exact length (BytesAppend) will SetLength to exact LNewLen themselves, so
  // this path is for standalone Reserve/Ensure. No header poke.
  LNewCap := LOld;
  if LNewCap < BYTES_BUILDER_MIN_GROW then
    LNewCap := BYTES_BUILDER_MIN_GROW;
  while LNewCap < ARequired do
  begin
    if LNewCap <= High(SizeUInt) div 2 then
      LNewCap := LNewCap * 2
    else
    begin
      LNewCap := ARequired;
      Break;
    end;
  end;
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
var LCap: SizeUInt;
begin
  if ANeed = 0 then Exit(0);
  if AOld = 0 then LCap := BYTES_BUILDER_MIN_GROW else LCap := AOld;
  if LCap < BYTES_BUILDER_MIN_GROW then LCap := BYTES_BUILDER_MIN_GROW;
  if LCap < 4 then LCap := 4;
  if LCap >= ANeed then Exit(LCap);
  while LCap < ANeed do
    if LCap <= High(SizeUInt) div 2 then LCap := LCap * 2 else Exit(ANeed);
  Result := LCap;
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

procedure BytesAppend(var ADest: TBytes; const ASrc: TBytes); inline; overload;
var
  LOldLen: SizeUInt;
begin
  // perf: inline + single SetLength + single Move (zero-copy via Move); no header poke
  if Length(ASrc) = 0 then
    Exit;
  LOldLen := SizeUInt(Length(ADest));
  SetLength(ADest, LOldLen + SizeUInt(Length(ASrc)));
  Move(ASrc[0], ADest[LOldLen], Length(ASrc));
end;

procedure BytesAppend(var ADest: TBytes; const ASrc: PByte; const ASrcLen: SizeUInt); inline; overload;
var
  LOldLen: SizeUInt;
begin
  if (ASrc = nil) or (ASrcLen = 0) then
    Exit;
  LOldLen := SizeUInt(Length(ADest));
  SetLength(ADest, LOldLen + ASrcLen);
  Move(ASrc^, ADest[LOldLen], ASrcLen);
end;

procedure BytesAppendByte(var ADest: TBytes; AValue: Byte); inline;
var
  LOldLen: SizeUInt;
begin
  LOldLen := SizeUInt(Length(ADest));
  SetLength(ADest, LOldLen + 1);
  ADest[LOldLen] := AValue;
end;

procedure BytesAppendUInt16BE(var ADest: TBytes; AValue: Word); inline;
var
  LOldLen: SizeUInt;
begin
  LOldLen := SizeUInt(Length(ADest));
  SetLength(ADest, LOldLen + 2);
  ADest[LOldLen] := Byte(AValue shr 8);
  ADest[LOldLen + 1] := Byte(AValue);
end;

procedure BytesAppendUInt24BE(var ADest: TBytes; AValue: Cardinal); inline;
var
  LOldLen: SizeUInt;
begin
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
  LOldLen := SizeUInt(Length(ADest));
  SetLength(ADest, LOldLen + 2);
  ADest[LOldLen] := Byte(AValue);
  ADest[LOldLen + 1] := Byte(AValue shr 8);
end;

procedure BytesAppendUInt32LE(var ADest: TBytes; AValue: Cardinal); inline;
var
  LOldLen: SizeUInt;
begin
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

function BytesIsGzip(const AData: TBytes): Boolean; inline;
begin
  // perf: inline + zero-copy single source gzip magic ($1F $8B), compress.base canonical; reused by vfs.compressed IsGzipPred/HeaderPred
  Result := (Length(AData) >= 2) and (AData[0] = $1F) and (AData[1] = $8B);
end;

function BytesIsGzipHeader(const AHeader: TBytes; const ATotalSize: Int64): Boolean; inline;
begin
  // perf: inline single source forward; ATotalSize kept for transform signature compat, zero-copy reuse
  Result := BytesIsGzip(AHeader);
end;

function BytesToString(const ABytes: TBytes): string; inline;
begin
  SetLength(Result, Length(ABytes));
  if Length(ABytes) > 0 then
    Move(ABytes[0], Result[1], Length(ABytes));
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
  SetLength(Result, LSpan.Len);
  if LSpan.Len > 0 then
    Move(LSpan.Data^, Result[1], LSpan.Len);
end;

function StringLowerAsciiAware(const S: string): string; inline;
begin
  Result := nextpas.core.text.unicode.utils.ToLowerAsciiAware(S);
end;

end.
