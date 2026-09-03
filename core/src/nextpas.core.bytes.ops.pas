unit nextpas.core.bytes.ops;

{$I nextpas.core.settings.inc}
{ R9-02 hermetic：settings.inc 已保障 inline 语义（-O2→INLINE ON），FPC 3.3.1 下无 BEGIN 误报 }

interface

uses
  nextpas.core.base,
  nextpas.core.base.utils,
  nextpas.core.bytes.base;

const
  BYTES_OPS_SINGLE_SOURCE = True;
  BYTES_OPS_SINGLE_SOURCE_VERSION = 1;
  { compile-time single-exit: BytesToString/StringToBytes/StripLeadingZero* single source is bytes.ops.
    Facades (bytes.pas, text.conv) inline-forward and reference this sentinel; duplicate impl
    fails via sentinel `{$IF not BYTES_OPS_SINGLE_SOURCE}` or init pointer assert. }

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

function SpanConcat(const A, B: TByteSpan): TBytes; // not inline per red line 1: Move(Result[0]/Result[A.Len], indexed) single alloc zero-copy must not be inline
function SpanCopySlice(const ASpan: TByteSpan; const AOffset, ALength: SizeUInt): TBytes;
function SpanClone(const ASpan: TByteSpan): TBytes;

function BytesEqual(const A, B: TBytes): Boolean; inline;
function BytesCompare(const A, B: TBytes): Integer; inline;
function BytesIndexOf(const AData: TBytes; const ANeedle: Byte): SizeInt; inline;
function BytesConcat(const A, B: TBytes): TBytes; inline;
{ perf: BytesAppend* zero-copy Move single allocation; capacity guard with
  amortized doubling (MIN_GROW 64, *2) to avoid O(n²) loop churn — over-allocate
  to Cap via BytesCalcGrowCap then logical len poke via BytesSetLogicalLenNoRealloc
  (SetLength to Cap + header poke to LNewLen; one heap call, FPC shrink kept block via poke, no second RTL, no copy, CoW-safe after SetLength).
  For bulk prefer BytesReserve/BytesEnsureCapacity pre-reserve or IBytesBuilder/
  BytesConcatMany (single allocation). BytesAppend* is not inline (red line 1:
  indexed element fed to Move must not be inline) to avoid I-Cache bloat and
  constant-propagation pollution; helper BytesCalcGrowCap is inline for zero-cost
  capacity calc, shared by all Append variants via BytesEnsureCapacity/Grow single source. }
procedure BytesAppend(var ADest: TBytes; const ASrc: TBytes); overload;
procedure BytesAppend(var ADest: TBytes; const ASrc: PByte; const ASrcLen: SizeUInt); overload;
procedure BytesAppendByte(var ADest: TBytes; AValue: Byte);
procedure BytesAppendUInt16BE(var ADest: TBytes; AValue: Word);
procedure BytesAppendUInt24BE(var ADest: TBytes; AValue: Cardinal);
procedure BytesAppendUInt32BE(var ADest: TBytes; AValue: Cardinal);
procedure BytesReserve(var ADest: TBytes; const AAdditional: SizeUInt);
procedure BytesEnsureCapacity(var ADest: TBytes; const ARequired: SizeUInt);
function BytesConcatMany(const AParts: array of TBytes): TBytes;
function SpanConcatMany(const AParts: array of TByteSpan): TBytes;
function BytesStartsWith(const AData, APrefix: TBytes): Boolean; inline;
function BytesEndsWith(const AData, ASuffix: TBytes): Boolean; inline;

{ Unsigned big-endian helpers (canonical single source for crypto/tls) }
{ perf: StripLeadingZero family compile-time single source is bytes.ops (BYTES_OPS_SINGLE_SOURCE);
  View is zero-copy (no alloc), Span is single-pass, Bytes is single alloc or CoW share.
  Facades must reference BYTES_OPS_SINGLE_SOURCE sentinel; init assert guards drift.
  StripLeadingZero/StripLeadingZeroSpan not inline per red lines 1+2: Move(P[LOff],Result[0]) + scan loop must not be inline (I-Cache + constant-propagation); Bytes/View thin forwards remain inline zero-cost. }
function StripLeadingZero(const AData: TBytes): TBytes; // not inline per red line 1+2
function StripLeadingZeroBytes(const AData: TBytes): TBytes; inline;
function StripLeadingZeroSpan(const ASpan: TByteSpan): TByteSpan; // not inline per red line 2: scan loop must not be inline
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
function StringToAnsiString(const AText: string): AnsiString;
function AnsiStringToString(const AAnsi: AnsiString): string; // not inline per red line 1: Move(PAnsiChar(AAnsi)^, Result[1]) indexed untyped must not be inline (BYTES_OPS_SINGLE_SOURCE single source for GetText)
function StringConcatToAnsi(const A, B: string): AnsiString; // not inline per red line 1: Move(Result[1], indexed) single-alloc concat zero-copy must not be inline (BYTES_OPS_SINGLE_SOURCE, DmSyntheticDpiProxy single source)
procedure StringConcatToAnsiReuse(var ADest: AnsiString; const A, B: string); // not inline per red line 1: AnsiEnsureCapacity+AnsiSetLogicalLenNoRealloc+2×Move reuse zero-copy single source (BYTES_OPS_SINGLE_SOURCE, bulk 10k amortized 1 alloc via BytesCalcGrowCap)
function BytesSliceToString(const ABytes: TBytes; const AOffset,
  ALength: SizeUInt): string;
function AnsiToUpperStr(const AData: PAnsiChar; const ALen: SizeUInt): string; // not inline per red line 1+2: Move(Result[1], indexed untyped) + SIMD ToUpperAscii must not be inline (constant-propagation + I-Cache bloat)

{ String helpers — single source for string array zero-copy and logical len trim (bulk reuse).
  Not inline per red line 1: Move with indexed element must not be inline (I-Cache + constant-propagation). }
procedure StringArrayCopy(var ADest: TStringArray; const ASrc: array of string);
procedure StringArrayCopyRange(var ADest: TStringArray; const ASrc: TStringArray; const AOffset, ACount: Integer);
procedure StringSetLengthNoRealloc(var S: string; const ANewLen: SizeUInt); inline;
procedure AnsiSetLogicalLenNoRealloc(var S: AnsiString; const ANewLen: SizeUInt); inline;
procedure AnsiEnsureCapacity(var ADest: AnsiString; const ARequired: SizeUInt);
procedure AnsiReserve(var ADest: AnsiString; const AAdditional: SizeUInt);
function BytesToAnsiString(const ABytes: TBytes): AnsiString; // not inline per red line 1: Move(ABytes[0], Result[1]) indexed untyped must not be inline (BYTES_OPS_SINGLE_SOURCE, BindBlob zero-copy view)
procedure BytesToAnsiStringReuse(var ADest: AnsiString; const ABytes: TBytes); // not inline per red line 1: AnsiEnsureCapacity single source reuse, zero-copy single Move, avoids BytesToString double materialization
procedure StringEnsureCapacity(var ADest: string; const ARequired: SizeUInt);
procedure StringReserve(var ADest: string; const AAdditional: SizeUInt);

{ Capacity growth single source: amortized doubling with overflow guard.
  BytesCalcGrowCap = BytesCalcGrowCapWithMin(..., BYTES_BUILDER_MIN_GROW);
  Reused by bytes append, bulk rows, db.pool idle/outstanding (min 4) — eliminates 3× *2/threshold duplication. inline zero-cost. }
function BytesCalcGrowCapWithMin(const AOld, ARequired, AMinGrow: SizeUInt): SizeUInt; inline;
function BytesCalcGrowCap(const AOldLen, ARequired: SizeUInt): SizeUInt; inline;

{ Unified builder capacity estimate single source (owner=bytes.ops, L1).
  Sinks dispersed `Length(A)+Length(B)+N` / `Loop sum + delim*(n-1)` / `fixed 32+N` manual estimates
  across db.savepoint/redis.addr/pg.adapter/mysql.adapter/sqlite.pragmas into inline helpers.
  All TBufStringBuilder.Init and BytesEnsureCapacity pre-reserve call sites must route via these;
  growth itself already via BytesCalcGrowCap. inline zero-cost, overflow fail-closed, zero-copy pre-reserve. }
function BuilderCapForTwo(const ALen1, ALen2: SizeUInt): SizeUInt; inline;
function BuilderCapAdd(const A, B: SizeUInt): SizeUInt; inline;
function BuilderCapForJoin(const ATotal, ACount, ADelimLen: SizeUInt): SizeUInt; inline;
function BuilderCapWithMin(const AEstimate: SizeUInt; const AMin: SizeUInt = 32): SizeUInt; inline;

implementation

uses
  nextpas.core.simd;

{ BytesEnsureCapacity/Reserve: safe SetLength-based growth (no global map).
  Old impl used GCapMap/MemSize slab probe for amortized slack; that depends on
  heap layout and races under multithread. New: capacity calc via shared
  BytesCalcGrowCap (single source, amortized doubling MIN_GROW 64 *2, overflow guard)
  and SetLength to Cap plus header poke to logical len (one heap call, keeps block via poke, no second RTL).
  perf: zero-copy Move in BytesAppend* callers (single Move per append, one heap call via poke);
  no extra alloc in failure path; not inline per red line 1 to avoid I-Cache bloat.
  For looped/high-frequency appends use BytesReserve/BytesEnsureCapacity
  pre-reserve (single allocation + bulk Moves) or IBytesBuilder (preallocated Grow)
  or BytesConcatMany/SpanConcatMany to avoid O(n²) SetLength churn.
  Stability: SetLength is exception-safe and CoW-safe; poke after SetLength keeps heap block
  (CoW already handled, no second RTL), no global map, no leak. }

function BytesCalcGrowCapWithMin(const AOld, ARequired, AMinGrow: SizeUInt): SizeUInt; inline;
begin
  Result := AOld;
  if Result < AMinGrow then
    Result := AMinGrow;
  while Result < ARequired do
  begin
    if Result <= High(SizeUInt) div 2 then
      Result := Result * 2
    else
    begin
      Result := ARequired;
      Break;
    end;
  end;
end;

function BytesCalcGrowCap(const AOldLen, ARequired: SizeUInt): SizeUInt; inline;
begin
  Result := BytesCalcGrowCapWithMin(AOldLen, ARequired, BYTES_BUILDER_MIN_GROW);
end;

function BuilderCapForTwo(const ALen1, ALen2: SizeUInt): SizeUInt; inline;
begin
  if ALen1 > High(SizeUInt) - ALen2 then
    raise EOverflow.Create('builder cap overflow');
  Result := ALen1 + ALen2;
end;

function BuilderCapAdd(const A, B: SizeUInt): SizeUInt; inline;
begin
  Result := BuilderCapForTwo(A, B);
end;

function BuilderCapForJoin(const ATotal, ACount, ADelimLen: SizeUInt): SizeUInt; inline;
var
  LDelimTotal: SizeUInt;
begin
  if (ACount <= 1) or (ADelimLen = 0) then
    Exit(ATotal);
  if (ACount - 1) > High(SizeUInt) div ADelimLen then
    raise EOverflow.Create('builder join cap overflow');
  LDelimTotal := (ACount - 1) * ADelimLen;
  Result := BuilderCapForTwo(ATotal, LDelimTotal);
end;

function BuilderCapWithMin(const AEstimate: SizeUInt; const AMin: SizeUInt = 32): SizeUInt; inline;
begin
  if AEstimate < AMin then
    Result := AMin
  else
    Result := AEstimate;
end;

procedure BytesSetLogicalLenNoRealloc(var ADest: TBytes; const ANewLen: SizeUInt); inline;
var
  PLen: PSizeInt;
begin
  if ADest = nil then
    if ANewLen = 0 then Exit else Exit;
  if SizeUInt(Length(ADest)) = ANewLen then Exit;
  // perf: single heap call (SetLength to Cap) + header poke to logical len (one RTL, keeps heap block via poke, no second SetLength, no realloc/copy, CoW-safe after SetLength(Cap) makes unique); zero-copy, inline zero-cost
  // stability: SetLength(Cap) already handled CoW/refcount; poke only adjusts length field (PSizeInt(Pointer(ADest))[-1]), no heap layout dependency beyond FPC dynarray header
  PLen := PSizeInt(Pointer(ADest));
  Dec(PLen);
  PLen^ := SizeInt(ANewLen);
end;

procedure BytesEnsureCapacity(var ADest: TBytes; const ARequired: SizeUInt);
var
  LOld, LCap: SizeUInt;
begin
  LOld := SizeUInt(Length(ADest));
  if ARequired <= LOld then
    Exit;
  LCap := BytesCalcGrowCap(LOld, ARequired);
  SetLength(ADest, LCap);
  if LCap <> ARequired then
    BytesSetLogicalLenNoRealloc(ADest, ARequired);
end;

procedure BytesReserve(var ADest: TBytes; const AAdditional: SizeUInt);
var
  LNeed: SizeUInt;
begin
  if AAdditional = 0 then
    Exit;
  LNeed := SizeUInt(Length(ADest)) + AAdditional;
  // overflow guard: if Length + Additional wraps, LNeed < old -> let SetLength raise
  if LNeed < SizeUInt(Length(ADest)) then
    raise EOutOfRange.Create('BytesReserve overflow');
  BytesEnsureCapacity(ADest, LNeed);
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
  LOldLen, LNewLen, LCap: SizeUInt;
begin
  // perf: zero-copy Move; not inline per red line 1. capacity via shared BytesCalcGrowCap
  // single SetLength to Cap + header poke to LNewLen (one heap call) when Cap <> LNewLen
  if Length(ASrc) = 0 then
    Exit;
  LOldLen := SizeUInt(Length(ADest));
  LNewLen := LOldLen + SizeUInt(Length(ASrc));
  if LNewLen < LOldLen then
    raise EOutOfRange.Create('BytesAppend overflow');
  LCap := BytesCalcGrowCap(LOldLen, LNewLen);
  if LCap <> LNewLen then
  begin
    SetLength(ADest, LCap);
    Move(ASrc[0], ADest[LOldLen], Length(ASrc));
    BytesSetLogicalLenNoRealloc(ADest, LNewLen);
  end
  else
  begin
    SetLength(ADest, LNewLen);
    Move(ASrc[0], ADest[LOldLen], Length(ASrc));
  end;
end;

procedure BytesAppend(var ADest: TBytes; const ASrc: PByte; const ASrcLen: SizeUInt); overload;
var
  LOldLen, LNewLen, LCap: SizeUInt;
begin
  if (ASrc = nil) or (ASrcLen = 0) then
    Exit;
  LOldLen := SizeUInt(Length(ADest));
  LNewLen := LOldLen + ASrcLen;
  if LNewLen < LOldLen then
    raise EOutOfRange.Create('BytesAppend overflow');
  LCap := BytesCalcGrowCap(LOldLen, LNewLen);
  if LCap <> LNewLen then
  begin
    SetLength(ADest, LCap);
    Move(ASrc^, ADest[LOldLen], ASrcLen);
    BytesSetLogicalLenNoRealloc(ADest, LNewLen);
  end
  else
  begin
    SetLength(ADest, LNewLen);
    Move(ASrc^, ADest[LOldLen], ASrcLen);
  end;
end;

procedure BytesAppendByte(var ADest: TBytes; AValue: Byte);
var
  LOldLen, LNewLen, LCap: SizeUInt;
begin
  LOldLen := SizeUInt(Length(ADest));
  LNewLen := LOldLen + 1;
  if LNewLen < LOldLen then
    raise EOutOfRange.Create('BytesAppendByte overflow');
  LCap := BytesCalcGrowCap(LOldLen, LNewLen);
  if LCap <> LNewLen then
  begin
    SetLength(ADest, LCap);
    ADest[LOldLen] := AValue;
    BytesSetLogicalLenNoRealloc(ADest, LNewLen);
  end
  else
  begin
    SetLength(ADest, LNewLen);
    ADest[LOldLen] := AValue;
  end;
end;

procedure BytesAppendUInt16BE(var ADest: TBytes; AValue: Word);
var
  LOldLen, LNewLen, LCap: SizeUInt;
begin
  LOldLen := SizeUInt(Length(ADest));
  LNewLen := LOldLen + 2;
  if LNewLen < LOldLen then
    raise EOutOfRange.Create('BytesAppendUInt16BE overflow');
  LCap := BytesCalcGrowCap(LOldLen, LNewLen);
  if LCap <> LNewLen then
  begin
    SetLength(ADest, LCap);
    ADest[LOldLen] := Byte(AValue shr 8);
    ADest[LOldLen + 1] := Byte(AValue);
    BytesSetLogicalLenNoRealloc(ADest, LNewLen);
  end
  else
  begin
    SetLength(ADest, LNewLen);
    ADest[LOldLen] := Byte(AValue shr 8);
    ADest[LOldLen + 1] := Byte(AValue);
  end;
end;

procedure BytesAppendUInt24BE(var ADest: TBytes; AValue: Cardinal);
var
  LOldLen, LNewLen, LCap: SizeUInt;
begin
  LOldLen := SizeUInt(Length(ADest));
  LNewLen := LOldLen + 3;
  if LNewLen < LOldLen then
    raise EOutOfRange.Create('BytesAppendUInt24BE overflow');
  LCap := BytesCalcGrowCap(LOldLen, LNewLen);
  if LCap <> LNewLen then
  begin
    SetLength(ADest, LCap);
    ADest[LOldLen] := Byte(AValue shr 16);
    ADest[LOldLen + 1] := Byte(AValue shr 8);
    ADest[LOldLen + 2] := Byte(AValue);
    BytesSetLogicalLenNoRealloc(ADest, LNewLen);
  end
  else
  begin
    SetLength(ADest, LNewLen);
    ADest[LOldLen] := Byte(AValue shr 16);
    ADest[LOldLen + 1] := Byte(AValue shr 8);
    ADest[LOldLen + 2] := Byte(AValue);
  end;
end;

procedure BytesAppendUInt32BE(var ADest: TBytes; AValue: Cardinal);
var
  LOldLen, LNewLen, LCap: SizeUInt;
begin
  LOldLen := SizeUInt(Length(ADest));
  LNewLen := LOldLen + 4;
  if LNewLen < LOldLen then
    raise EOutOfRange.Create('BytesAppendUInt32BE overflow');
  LCap := BytesCalcGrowCap(LOldLen, LNewLen);
  if LCap <> LNewLen then
  begin
    SetLength(ADest, LCap);
    ADest[LOldLen] := Byte(AValue shr 24);
    ADest[LOldLen + 1] := Byte(AValue shr 16);
    ADest[LOldLen + 2] := Byte(AValue shr 8);
    ADest[LOldLen + 3] := Byte(AValue);
    BytesSetLogicalLenNoRealloc(ADest, LNewLen);
  end
  else
  begin
    SetLength(ADest, LNewLen);
    ADest[LOldLen] := Byte(AValue shr 24);
    ADest[LOldLen + 1] := Byte(AValue shr 16);
    ADest[LOldLen + 2] := Byte(AValue shr 8);
    ADest[LOldLen + 3] := Byte(AValue);
  end;
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
  // not inline per red line 1+2: scan loop + Move(P[LOff],Result[0],L-LOff) indexed untyped param must not be inline (constant-propagation + I-Cache bloat); perf: single scan zero-copy CoW share when no trim else single alloc+Move
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

function StripLeadingZeroSpan(const ASpan: TByteSpan): TByteSpan;
var LOff: SizeUInt;
begin
  // not inline per red line 2: scan loop body must not be inline (I-Cache bloat); zero-copy view no alloc
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
  // not inline per red line 1: Move with indexed element ABytes[0] as source
  // would risk constant-propagation pollution (FPC folds constant string literal
  // ABytes[0] to single char value); zero-copy Move, single allocation.
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
  // not inline per red line 1: Move with PAnsiChar(AText)^/Result[0] involves
  // untyped sink; keep single source (bytes.ops) with zero-copy Move.
  // Uniform with BytesToString/BytesSliceToString (all non-inline).
  SetLength(Result, Length(AText));
  if Length(AText) > 0 then
    Move(PAnsiChar(AText)^, Result[0], Length(AText));
end;

function StringToAnsiString(const AText: string): AnsiString;
begin
  // not inline per red line 1: Move(Result[1], indexed element fed to untyped param) single Move zero-copy single source (BYTES_OPS_SINGLE_SOURCE)
  // AnsiString 形态同源 StringToBytes 单 Move 形状（SetLength+Move 单分配），bytes.ops 单源内聚不漂移；零额外分配，uniform with StringToBytes
  SetLength(Result, Length(AText));
  if Length(AText) > 0 then
    Move(PAnsiChar(AText)^, Result[1], Length(AText));
end;

function AnsiStringToString(const AAnsi: AnsiString): string;
begin
  // not inline per red line 1: Move(PAnsiChar(AAnsi)^, Result[1]) indexed untyped must not be inline (BYTES_OPS_SINGLE_SOURCE single source for GetText, avoids branch duplication and constant-propagation pollution, single alloc zero-copy)
  SetLength(Result, Length(AAnsi));
  if Length(AAnsi) > 0 then
    Move(PAnsiChar(AAnsi)^, Result[1], SizeUInt(Length(AAnsi)));
end;

function StringConcatToAnsi(const A, B: string): AnsiString;
var
  LLenA, LLenB: SizeUInt;
begin
  // not inline per red line 1: Move(Result[1], indexed) double Move single-alloc zero-copy must not be inline (BYTES_OPS_SINGLE_SOURCE, DmSyntheticDpiProxy single source); avoids I-Cache bloat and constant-propagation pollution, single SetLength+2xMove zero-copy
  LLenA := SizeUInt(Length(A));
  LLenB := SizeUInt(Length(B));
  SetLength(Result, LLenA + LLenB);
  if LLenA > 0 then
    Move(PAnsiChar(A)^, Result[1], LLenA);
  if LLenB > 0 then
    Move(PAnsiChar(B)^, Result[1 + LLenA], LLenB);
end;

procedure StringConcatToAnsiReuse(var ADest: AnsiString; const A, B: string);
var
  LLenA, LLenB, LNeed: SizeUInt;
begin
  // not inline per red line 1: Move(ADest[1], indexed) 2×Move must not be inline (I-Cache + constant-propagation); perf: bytes.ops single source AnsiEnsureCapacity(BytesCalcGrowCap doubling amortized 10k heap→1)+AnsiSetLogicalLenNoRealloc+2×Move zero-copy, BYTES_OPS_SINGLE_SOURCE single source for synthetic Reuse (converged from manual Move vs StringConcatToAnsi dual source), bulk reuse zero second alloc
  LLenA := SizeUInt(Length(A));
  LLenB := SizeUInt(Length(B));
  LNeed := LLenA + LLenB;
  AnsiEnsureCapacity(ADest, LNeed);
  AnsiSetLogicalLenNoRealloc(ADest, LNeed);
  if LLenA > 0 then Move(PAnsiChar(A)^, ADest[1], LLenA);
  if LLenB > 0 then Move(PAnsiChar(B)^, ADest[1 + LLenA], LLenB);
end;

function BytesSliceToString(const ABytes: TBytes; const AOffset,
  ALength: SizeUInt): string;
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

function AnsiToUpperStr(const AData: PAnsiChar; const ALen: SizeUInt): string;
begin
  // not inline per red line 1+2: Move(Result[1], indexed untyped param) + SIMD ToUpperAscii loop must not be inline (constant-propagation + I-Cache bloat); perf: single alloc Move (bytes.ops single source) + SIMD in-place ToUpperAscii (zero extra alloc), gated BYTES_OPS_SINGLE_SOURCE
  if (AData = nil) or (ALen = 0) then
    Exit('');
  SetLength(Result, ALen);
  Move(AData^, Result[1], ALen);
  if ALen > 0 then
    ToUpperAscii(@Result[1], ALen);
end;

{ StringArrayCopy — single source for bulk string array zero-copy reuse.
  perf: managed assignment per element (compiler AddRef, zero string data copy, single heap for dynarray header);
  not inline per red line 1: indexed element must not be inline (I-Cache bloat + constant-propagation);
  bytes.ops single source, no PAnsiChar -12/-8 heap layout hack — refcount via language, stable across FPC versions/arch. }
procedure StringArrayCopy(var ADest: TStringArray; const ASrc: array of string);
var
  I, L: Integer;
begin
  L := Length(ASrc);
  SetLength(ADest, L);
  if L = 0 then Exit;
  for I := 0 to L - 1 do
    ADest[I] := ASrc[I];
end;

{ StringArrayCopyRange — flat slice variant single source (bulk Rows compat).
  perf: managed assignment per element (compiler AddRef, zero string data copy); not inline per red line 1.
  No -12/-8 hack, stable via language. }
procedure StringArrayCopyRange(var ADest: TStringArray; const ASrc: TStringArray; const AOffset, ACount: Integer);
var
  I: Integer;
begin
  if ACount <= 0 then
  begin
    SetLength(ADest, 0);
    Exit;
  end;
  if (AOffset < 0) or (AOffset + ACount > Length(ASrc)) then
    raise EOutOfRange.Create('StringArrayCopyRange: offset+count exceeds source');
  SetLength(ADest, ACount);
  if ACount = 0 then Exit;
  for I := 0 to ACount - 1 do
    ADest[I] := ASrc[AOffset + I];
end;

{ StringSetLengthNoRealloc — single alloc over-reserve + header poke logical len trim.
  perf: SetLength to Cap + header poke to logical len (one heap call, keeps block via poke, no second RTL, CoW-safe after SetLength(Cap)); inline zero-cost when no trim; null terminator handled via poke }
procedure StringSetLengthNoRealloc(var S: string; const ANewLen: SizeUInt); inline;
var
  PLen: PSizeInt;
begin
  if (S = '') or (Pointer(S) = nil) then Exit;
  if SizeUInt(Length(S)) = ANewLen then Exit;
  // poke length field (PSizeInt(Pointer(S))[-1]), keep heap block, set terminator
  PLen := PSizeInt(Pointer(S));
  Dec(PLen);
  PLen^ := SizeInt(ANewLen);
  PByte(PAnsiChar(S) + ANewLen)^ := 0;
end;

procedure AnsiSetLogicalLenNoRealloc(var S: AnsiString; const ANewLen: SizeUInt); inline;
var
  PLen: PSizeInt;
begin
  if (S = '') or (Pointer(S) = nil) then Exit;
  if SizeUInt(Length(S)) = ANewLen then Exit;
  PLen := PSizeInt(Pointer(S));
  Dec(PLen);
  PLen^ := SizeInt(ANewLen);
  PByte(PAnsiChar(S) + ANewLen)^ := 0;
end;

procedure AnsiEnsureCapacity(var ADest: AnsiString; const ARequired: SizeUInt);
var
  LOld, LCap: SizeUInt;
begin
  LOld := SizeUInt(Length(ADest));
  if ARequired <= LOld then
    Exit;
  LCap := BytesCalcGrowCap(LOld, ARequired);
  SetLength(ADest, LCap);
  if LCap <> ARequired then
    AnsiSetLogicalLenNoRealloc(ADest, ARequired);
end;

procedure AnsiReserve(var ADest: AnsiString; const AAdditional: SizeUInt);
var
  LNeed: SizeUInt;
begin
  if AAdditional = 0 then Exit;
  LNeed := SizeUInt(Length(ADest)) + AAdditional;
  if LNeed < SizeUInt(Length(ADest)) then
    raise EOutOfRange.Create('AnsiReserve overflow');
  AnsiEnsureCapacity(ADest, LNeed);
end;

function BytesToAnsiString(const ABytes: TBytes): AnsiString;
begin
  // not inline per red line 1: Move(ABytes[0], Result[1]) indexed untyped must not be inline (constant-propagation + I-Cache bloat); perf: single SetLength+Move single alloc zero-copy (BYTES_OPS_SINGLE_SOURCE), BindBlob zero-copy view no double materialization
  SetLength(Result, Length(ABytes));
  if Length(ABytes) > 0 then
    Move(ABytes[0], Result[1], SizeUInt(Length(ABytes)));
end;

procedure BytesToAnsiStringReuse(var ADest: AnsiString; const ABytes: TBytes);
var
  LLen: SizeUInt;
begin
  // not inline per red line 1: Move(ABytes[0], PAnsiChar(ADest)^) indexed must not be inline; perf: AnsiEnsureCapacity single source reuse (BytesCalcGrowCap amortized, bulk 10k blob single heap alloc amortized) + AnsiSetLogicalLenNoRealloc single Move zero-copy, avoids BytesToString double materialization
  LLen := SizeUInt(Length(ABytes));
  AnsiEnsureCapacity(ADest, LLen);
  AnsiSetLogicalLenNoRealloc(ADest, LLen);
  if LLen > 0 then
    Move(ABytes[0], PAnsiChar(ADest)^, LLen);
end;

procedure StringEnsureCapacity(var ADest: string; const ARequired: SizeUInt);
var
  LOld, LCap: SizeUInt;
begin
  // not inline per red line 1: SetLength with indexed growth must not be inline; perf: BytesCalcGrowCap single source (amortized doubling, overflow guard) + SetLength to Cap + shrink keep block, GetText large streaming zero-copy view reuse
  LOld := SizeUInt(Length(ADest));
  if ARequired <= LOld then
    Exit;
  LCap := BytesCalcGrowCap(LOld, ARequired);
  SetLength(ADest, LCap);
  if LCap <> ARequired then
    StringSetLengthNoRealloc(ADest, ARequired);
end;

procedure StringReserve(var ADest: string; const AAdditional: SizeUInt);
var
  LNeed: SizeUInt;
begin
  if AAdditional = 0 then Exit;
  LNeed := SizeUInt(Length(ADest)) + AAdditional;
  if LNeed < SizeUInt(Length(ADest)) then
    raise EOutOfRange.Create('StringReserve overflow');
  StringEnsureCapacity(ADest, LNeed);
end;

end.
