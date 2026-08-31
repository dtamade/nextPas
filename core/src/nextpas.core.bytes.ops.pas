unit nextpas.core.bytes.ops;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.base.utils,
  nextpas.core.bytes.base;

function SpanEqual(const A, B: TByteSpan): Boolean; inline;
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
{ perf: BytesAppend does SetLength+Move per call (O(n) realloc). For high-frequency
  or looped appends prefer IBytesBuilder (preallocated Grow) or BytesConcatMany/
  SpanConcatMany (single allocation) to avoid O(n²) churn. Keep inline for single-use
  convenience only. }
procedure BytesAppend(var ADest: TBytes; const ASrc: TBytes); inline; overload;
procedure BytesAppend(var ADest: TBytes; const ASrc: PByte; const ASrcLen: SizeUInt); inline; overload;
procedure BytesAppendByte(var ADest: TBytes; AValue: Byte); inline;
procedure BytesAppendUInt16BE(var ADest: TBytes; AValue: Word); inline;
procedure BytesAppendUInt24BE(var ADest: TBytes; AValue: Cardinal); inline;
procedure BytesAppendUInt32BE(var ADest: TBytes; AValue: Cardinal); inline;
procedure BytesReserve(var ADest: TBytes; const AAdditional: SizeUInt); inline;
procedure BytesEnsureCapacity(var ADest: TBytes; const ARequired: SizeUInt); inline;
function BytesConcatMany(const AParts: array of TBytes): TBytes;
function SpanConcatMany(const AParts: array of TByteSpan): TBytes;
function BytesStartsWith(const AData, APrefix: TBytes): Boolean; inline;
function BytesEndsWith(const AData, ASuffix: TBytes): Boolean; inline;

{ Unsigned big-endian helpers (canonical single source for crypto/tls) }
function StripLeadingZero(const AData: TBytes): TBytes;
function StripLeadingZeroBytes(const AData: TBytes): TBytes; inline;
function StripLeadingZeroSpan(const ASpan: TByteSpan): TByteSpan; inline;
function StripLeadingZeroView(const AData: TBytes): TByteSpan; inline;
function CompareUnsigned(const ALeft, ARight: TBytes): Integer; inline;
function CompareUnsignedBytes(const ALeft, ARight: TBytes): Integer; inline;
function CompareUnsignedSpan(const ALeft, ARight: TByteSpan): Integer; inline;
function UnsignedEqual(const ALeft, ARight: TBytes): Boolean; inline;
function UnsignedBytesEqual(const ALeft, ARight: TBytes): Boolean; inline;
function UnsignedEqualSpan(const ALeft, ARight: TByteSpan): Boolean; inline;
function IsZeroBytes(const AData: TBytes): Boolean; inline; overload;
function IsZeroBytes(const ASpan: TByteSpan): Boolean; inline; overload;
function BytesIsZero(const AData: TBytes): Boolean; inline;
function IsAllZero(const AData: TBytes): Boolean; inline;
function BytesToString(const ABytes: TBytes): string; inline;
function BytesToUTF8(const ABytes: TBytes): string; inline;
function StringToBytes(const AText: string): TBytes;
function BytesSliceToString(const ABytes: TBytes; const AOffset,
  ALength: SizeUInt): string; inline;

implementation

uses
  nextpas.core.simd;

{ --- amortized O(1) append capacity (TBytes dynamic array slack) --- }
const
  CAP_MAP_SIZE = 32;

type
  TCapEntry = record
    Ptr: Pointer;
    Cap: SizeUInt;
    Used: Boolean;
  end;

var
  GCapMap: array[0..CAP_MAP_SIZE - 1] of TCapEntry;

function DynGetRefCnt(const A: TBytes): SizeInt; inline;
begin
  if Pointer(A) = nil then
    Exit(0);
  Result := PSizeInt(Pointer(A))[-2];
end;

procedure DynSetLen(var A: TBytes; const ANewLen: SizeUInt); inline;
begin
  if Pointer(A) = nil then
    Exit;
  PSizeInt(Pointer(A))[-1] := SizeInt(ANewLen);
end;

function CapGet(const APtr: Pointer; const AFallback: SizeUInt): SizeUInt; inline;
var
  I, Idx: SizeUInt;
begin
  if APtr = nil then
    Exit(0);
  Idx := (PtrUInt(APtr) shr 3) mod CAP_MAP_SIZE;
  for I := 0 to CAP_MAP_SIZE - 1 do
  begin
    if GCapMap[(Idx + I) mod CAP_MAP_SIZE].Used and (GCapMap[(Idx + I) mod CAP_MAP_SIZE].Ptr = APtr) then
      Exit(GCapMap[(Idx + I) mod CAP_MAP_SIZE].Cap);
  end;
  Result := AFallback;
end;

procedure CapSet(const AOldPtr, ANewPtr: Pointer; const ACap: SizeUInt); inline;
var
  I, Idx: SizeUInt;
begin
  if (AOldPtr <> nil) and (AOldPtr <> ANewPtr) then
  begin
    Idx := (PtrUInt(AOldPtr) shr 3) mod CAP_MAP_SIZE;
    for I := 0 to CAP_MAP_SIZE - 1 do
      if GCapMap[(Idx + I) mod CAP_MAP_SIZE].Used and (GCapMap[(Idx + I) mod CAP_MAP_SIZE].Ptr = AOldPtr) then
      begin
        GCapMap[(Idx + I) mod CAP_MAP_SIZE].Used := False;
        Break;
      end;
  end;
  if ANewPtr = nil then
    Exit;
  Idx := (PtrUInt(ANewPtr) shr 3) mod CAP_MAP_SIZE;
  for I := 0 to CAP_MAP_SIZE - 1 do
  begin
    if not GCapMap[(Idx + I) mod CAP_MAP_SIZE].Used then
    begin
      GCapMap[(Idx + I) mod CAP_MAP_SIZE].Ptr := ANewPtr;
      GCapMap[(Idx + I) mod CAP_MAP_SIZE].Cap := ACap;
      GCapMap[(Idx + I) mod CAP_MAP_SIZE].Used := True;
      Exit;
    end;
    if GCapMap[(Idx + I) mod CAP_MAP_SIZE].Ptr = ANewPtr then
    begin
      GCapMap[(Idx + I) mod CAP_MAP_SIZE].Cap := ACap;
      Exit;
    end;
  end;
  { map full: drop oldest slot (Idx) }
  GCapMap[Idx].Ptr := ANewPtr;
  GCapMap[Idx].Cap := ACap;
  GCapMap[Idx].Used := True;
end;

procedure BytesEnsureCapacity(var ADest: TBytes; const ARequired: SizeUInt); inline;
var
  LOldLen, LNewCap, LCurCap: SizeUInt;
  LOldPtr, LNewPtr: Pointer;
begin
  LOldLen := Length(ADest);
  if ARequired <= LOldLen then
    Exit;
  LCurCap := CapGet(Pointer(ADest), LOldLen);
  if ARequired <= LCurCap then
    Exit;
  if LCurCap < BYTES_BUILDER_MIN_GROW then
    LCurCap := BYTES_BUILDER_MIN_GROW;
  LNewCap := LCurCap;
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
  LOldPtr := Pointer(ADest);
  { single allocation, zero-copy via Move later; preserve logical len via header poke }
  SetLength(ADest, LNewCap);
  LNewPtr := Pointer(ADest);
  DynSetLen(ADest, LOldLen);
  CapSet(LOldPtr, LNewPtr, LNewCap);
end;

procedure BytesReserve(var ADest: TBytes; const AAdditional: SizeUInt); inline;
begin
  if AAdditional = 0 then
    Exit;
  BytesEnsureCapacity(ADest, Length(ADest) + AAdditional);
end;

function SpanEqual(const A, B: TByteSpan): Boolean; inline;
begin
  if A.Len <> B.Len then
    Exit(False);
  if (A.Len = 0) or (A.Data = B.Data) then
    Exit(True);
  Result := MemEqual(A.Data, B.Data, A.Len);
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

procedure BytesAppend(var ADest: TBytes; const ASrc: TBytes); inline; overload;
var
  LOldLen, LAdd, LNewLen, LCap: SizeUInt;
begin
  LAdd := Length(ASrc);
  if LAdd = 0 then
    Exit;
  LOldLen := Length(ADest);
  LNewLen := LOldLen + LAdd;
  LCap := CapGet(Pointer(ADest), LOldLen);
  if (Pointer(ADest) <> nil) and (LCap >= LNewLen) and (DynGetRefCnt(ADest) = 1) then
  begin
    Move(ASrc[0], PByte(Pointer(ADest))[LOldLen], LAdd);
    DynSetLen(ADest, LNewLen);
    Exit;
  end;
  BytesEnsureCapacity(ADest, LNewLen);
  Move(ASrc[0], PByte(Pointer(ADest))[LOldLen], LAdd);
  DynSetLen(ADest, LNewLen);
end;

procedure BytesAppend(var ADest: TBytes; const ASrc: PByte; const ASrcLen: SizeUInt); inline; overload;
var
  LOldLen, LNewLen, LCap: SizeUInt;
begin
  if (ASrc = nil) or (ASrcLen = 0) then
    Exit;
  LOldLen := Length(ADest);
  LNewLen := LOldLen + ASrcLen;
  LCap := CapGet(Pointer(ADest), LOldLen);
  if (Pointer(ADest) <> nil) and (LCap >= LNewLen) and (DynGetRefCnt(ADest) = 1) then
  begin
    Move(ASrc^, PByte(Pointer(ADest))[LOldLen], ASrcLen);
    DynSetLen(ADest, LNewLen);
    Exit;
  end;
  BytesEnsureCapacity(ADest, LNewLen);
  Move(ASrc^, PByte(Pointer(ADest))[LOldLen], ASrcLen);
  DynSetLen(ADest, LNewLen);
end;

procedure BytesAppendByte(var ADest: TBytes; AValue: Byte); inline;
var
  LOldLen, LNewLen, LCap: SizeUInt;
begin
  LOldLen := Length(ADest);
  LNewLen := LOldLen + 1;
  LCap := CapGet(Pointer(ADest), LOldLen);
  if (Pointer(ADest) <> nil) and (LCap >= LNewLen) and (DynGetRefCnt(ADest) = 1) then
  begin
    PByte(Pointer(ADest))[LOldLen] := AValue;
    DynSetLen(ADest, LNewLen);
    Exit;
  end;
  BytesEnsureCapacity(ADest, LNewLen);
  PByte(Pointer(ADest))[LOldLen] := AValue;
  DynSetLen(ADest, LNewLen);
end;

procedure BytesAppendUInt16BE(var ADest: TBytes; AValue: Word); inline;
var
  LOldLen, LNewLen, LCap: SizeUInt;
  P: PByte;
begin
  LOldLen := Length(ADest);
  LNewLen := LOldLen + 2;
  LCap := CapGet(Pointer(ADest), LOldLen);
  if (Pointer(ADest) <> nil) and (LCap >= LNewLen) and (DynGetRefCnt(ADest) = 1) then
  begin
    P := PByte(Pointer(ADest)) + LOldLen;
    P[0] := Byte(AValue shr 8);
    P[1] := Byte(AValue);
    DynSetLen(ADest, LNewLen);
    Exit;
  end;
  BytesEnsureCapacity(ADest, LNewLen);
  P := PByte(Pointer(ADest)) + LOldLen;
  P[0] := Byte(AValue shr 8);
  P[1] := Byte(AValue);
  DynSetLen(ADest, LNewLen);
end;

procedure BytesAppendUInt24BE(var ADest: TBytes; AValue: Cardinal); inline;
var
  LOldLen, LNewLen, LCap: SizeUInt;
  P: PByte;
begin
  LOldLen := Length(ADest);
  LNewLen := LOldLen + 3;
  LCap := CapGet(Pointer(ADest), LOldLen);
  if (Pointer(ADest) <> nil) and (LCap >= LNewLen) and (DynGetRefCnt(ADest) = 1) then
  begin
    P := PByte(Pointer(ADest)) + LOldLen;
    P[0] := Byte(AValue shr 16);
    P[1] := Byte(AValue shr 8);
    P[2] := Byte(AValue);
    DynSetLen(ADest, LNewLen);
    Exit;
  end;
  BytesEnsureCapacity(ADest, LNewLen);
  P := PByte(Pointer(ADest)) + LOldLen;
  P[0] := Byte(AValue shr 16);
  P[1] := Byte(AValue shr 8);
  P[2] := Byte(AValue);
  DynSetLen(ADest, LNewLen);
end;

procedure BytesAppendUInt32BE(var ADest: TBytes; AValue: Cardinal); inline;
var
  LOldLen, LNewLen, LCap: SizeUInt;
  P: PByte;
begin
  LOldLen := Length(ADest);
  LNewLen := LOldLen + 4;
  LCap := CapGet(Pointer(ADest), LOldLen);
  if (Pointer(ADest) <> nil) and (LCap >= LNewLen) and (DynGetRefCnt(ADest) = 1) then
  begin
    P := PByte(Pointer(ADest)) + LOldLen;
    P[0] := Byte(AValue shr 24);
    P[1] := Byte(AValue shr 16);
    P[2] := Byte(AValue shr 8);
    P[3] := Byte(AValue);
    DynSetLen(ADest, LNewLen);
    Exit;
  end;
  BytesEnsureCapacity(ADest, LNewLen);
  P := PByte(Pointer(ADest)) + LOldLen;
  P[0] := Byte(AValue shr 24);
  P[1] := Byte(AValue shr 16);
  P[2] := Byte(AValue shr 8);
  P[3] := Byte(AValue);
  DynSetLen(ADest, LNewLen);
end;

function BytesStartsWith(const AData, APrefix: TBytes): Boolean;
begin
  Result := SpanStartsWith(TByteSpan.FromBytes(AData), TByteSpan.FromBytes(APrefix));
end;

function BytesEndsWith(const AData, ASuffix: TBytes): Boolean;
begin
  Result := SpanEndsWith(TByteSpan.FromBytes(AData), TByteSpan.FromBytes(ASuffix));
end;

function StripLeadingZeroSpan(const ASpan: TByteSpan): TByteSpan; inline;
begin
  Result := ASpan;
  while (Result.Len > 0) and (Result.Data^ = 0) do
  begin
    Inc(Result.Data);
    Dec(Result.Len);
  end;
end;

function StripLeadingZeroView(const AData: TBytes): TByteSpan; inline;
begin
  Result := StripLeadingZeroSpan(TByteSpan.FromBytes(AData));
end;

function StripLeadingZero(const AData: TBytes): TBytes; inline;
var
  LView: TByteSpan;
begin
  LView := StripLeadingZeroView(AData);
  if LView.Len = 0 then
  begin
    SetLength(Result, 1);
    Result[0] := 0;
    Exit;
  end;
  Result := SpanClone(LView);
end;

function StripLeadingZeroBytes(const AData: TBytes): TBytes; inline;
begin
  Result := StripLeadingZero(AData);
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

function IsZeroBytes(const AData: TBytes): Boolean; inline;
begin
  // perf: single-source zero check via StripLeadingZeroView (O(n) scan with early exit,
  // reuses existing view; empty => Len=0 => zero). Avoids duplicate byte loops and
  // keeps crypto/tls callers on one implementation; SIMD MemEqual could be used for
  // bulk zero compares but view already short-circuits on first non-zero.
  Result := StripLeadingZeroView(AData).Len = 0;
end;

function IsZeroBytes(const ASpan: TByteSpan): Boolean; inline;
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

end.
