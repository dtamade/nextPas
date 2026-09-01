unit nextpas.core.bytes.ops;

{$I nextpas.core.settings.inc}
{ bytes.ops — single source for SetLength+Move (单源); TByteSpan zero-copy views; hot paths inline, alloc paths not inline per red-line 1/2. }

interface

uses
  nextpas.core.base,
  nextpas.core.base.utils,
  nextpas.core.bytes.base;

{ Span ops }
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
{ replicate — doubling Moves }
procedure BytesReplicateCopy(ASrc, ADst: Pointer; ADist, ALen: SizeUInt);
{ single Move/Fill }
procedure BytesCopy(ADst, ASrc: Pointer; const ALen: SizeUInt);
procedure BytesZero(ADst: Pointer; const ALen: SizeUInt);
procedure SpanZero(const ASpan: TByteSpan);

{ global zero page (.bss, 4K) }
const
  BYTES_ZERO_PAGE_SIZE = 4096;
  BYTES_ZERO_PAGE_SLICE_THRESHOLD = BYTES_ZERO_PAGE_SIZE;
var
  BYTES_ZERO_PAGE: array[0..BYTES_ZERO_PAGE_SIZE - 1] of Byte;

function ZeroPageSlice(const ALen: SizeUInt): TByteSpan; inline;

{ bulk XOR — QWord batched }
procedure XorInplace(ADst, AKey: PByte; ALen: SizeUInt);
procedure SpanXorInplace(const ADst, AKey: TByteSpan); inline;

{ ASCII case — bulk via simd }
procedure AsciiToLowerInplace(AData: PByte; ALen: SizeUInt);
procedure AsciiToUpperInplace(AData: PByte; ALen: SizeUInt);
procedure SpanToLowerAscii(const ASpan: TByteSpan); inline;
procedure SpanToUpperAscii(const ASpan: TByteSpan); inline;
function AsciiLowerString(const S: string): string;
function AsciiUpperString(const S: string): string;

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
procedure BytesAppendByte(var ADest: TBytes; AValue: Byte);
procedure BytesAppendUInt16BE(var ADest: TBytes; AValue: Word);
procedure BytesAppendUInt24BE(var ADest: TBytes; AValue: Cardinal);
procedure BytesAppendUInt32BE(var ADest: TBytes; AValue: Cardinal);
procedure BytesReserve(var ADest: TBytes; const AAdditional: SizeUInt);
procedure BytesEnsureCapacity(var ADest: TBytes; const ARequired: SizeUInt);
function BytesNextCapacity(AOld, ANeed: SizeUInt): SizeUInt; inline;
{ not inline: loop }
function BytesGrowCapacity(const ACurrent, ARequired: SizeUInt): SizeUInt;
function BytesGrowCapacityInt(const ACurrent, ARequired: Integer): Integer;
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
function SpanToString(const ASpan: TByteSpan): string; inline;
function SpanToUTF8(const ASpan: TByteSpan): string; inline;
function BytesToString(const ABytes: TBytes): string; inline;
function BytesToUTF8(const ABytes: TBytes): string; inline;
function StringToBytes(const AText: string): TBytes;
function BytesSliceToString(const ABytes: TBytes; const AOffset;
  ALength: SizeUInt): string;
function TryClampSlice(const AOffset, ALength, ATotal: SizeUInt; out AClampedLen: SizeUInt): Boolean; inline;
{ not inline: loop+Move }
function AnsiPtrToString(const P: PAnsiChar): string;
{ not inline: loop }
function BigEndianUnicodeBytesToString(const AData: TBytes): string;

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
  nextpas.core.bytes.binary;

type
  TVarDataView = packed record
    VType: Word;
    Reserved: array[0..13] of Byte;
  end;
  PVarDataView = ^TVarDataView;

{ capacity growth — exponential via BytesGrowCapacity, exception-safe }

procedure BytesEnsureCapacity(var ADest: TBytes; const ARequired: SizeUInt);
var
  LOld, LNewCap: SizeUInt;
begin
  LOld := SizeUInt(Length(ADest));
  if ARequired <= LOld then
    Exit;
  // delegate to BytesGrowCapacity to keep single source
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
  Result := BytesGrowCapacity(AOld, ANeed);
end;

function BytesGrowCapacity(const ACurrent, ARequired: SizeUInt): SizeUInt;
var
  LNewCap: SizeUInt;
begin
  // not inline: loop
  if ARequired <= ACurrent then
    Exit(ACurrent);
  LNewCap := ACurrent;
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
  Result := LNewCap;
end;

function BytesGrowCapacityInt(const ACurrent, ARequired: Integer): Integer;
var
  LCur, LReq, LCap: SizeUInt;
begin
  if ARequired <= ACurrent then
    Exit(ACurrent);
  LCur := SizeUInt(ACurrent);
  LReq := SizeUInt(ARequired);
  LCap := BytesGrowCapacity(LCur, LReq);
  if LCap > SizeUInt(High(Integer)) then
    LCap := SizeUInt(High(Integer));
  Result := Integer(LCap);
end;

{ L0 mem — header probe via mem.dynarray }
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

{ ensure append capacity — exponential grow, CoW-aware }
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

procedure XorInplace(ADst, AKey: PByte; ALen: SizeUInt);
var
  LOff: SizeUInt;
begin
  if (ADst = nil) or (AKey = nil) or (ALen = 0) then
    Exit;
  LOff := 0;
  {$PUSH}{$Q-}{$R-}
  while LOff + 8 <= ALen do
  begin
    PQWord(ADst + LOff)^ := PQWord(ADst + LOff)^ xor PQWord(AKey + LOff)^;
    Inc(LOff, 8);
  end;
  while LOff < ALen do
  begin
    (ADst + LOff)^ := (ADst + LOff)^ xor (AKey + LOff)^;
    Inc(LOff);
  end;
  {$POP}
end;

procedure SpanXorInplace(const ADst, AKey: TByteSpan); inline;
begin
  if ADst.Len = 0 then
    Exit;
  if ADst.Len <> AKey.Len then
    raise EInvalidArgument.Create('SpanXorInplace: length mismatch');
  XorInplace(ADst.Data, AKey.Data, ADst.Len);
end;

procedure AsciiToLowerInplace(AData: PByte; ALen: SizeUInt);
begin
  if (AData = nil) or (ALen = 0) then
    Exit;
  ToLowerAscii(AData, ALen);
end;

procedure AsciiToUpperInplace(AData: PByte; ALen: SizeUInt);
begin
  if (AData = nil) or (ALen = 0) then
    Exit;
  ToUpperAscii(AData, ALen);
end;

procedure SpanToLowerAscii(const ASpan: TByteSpan); inline;
begin
  if ASpan.Len > 0 then
    AsciiToLowerInplace(ASpan.Data, ASpan.Len);
end;

procedure SpanToUpperAscii(const ASpan: TByteSpan); inline;
begin
  if ASpan.Len > 0 then
    AsciiToUpperInplace(ASpan.Data, ASpan.Len);
end;

function AsciiLowerString(const S: string): string;
begin
  if S = '' then
    Exit('');
  Result := SpanToString(TByteSpan.Create(PByte(PAnsiChar(S)), SizeUInt(Length(S))));
  if Length(Result) > 0 then
    ToLowerAscii(Pointer(Result), SizeUInt(Length(Result)));
end;

function AsciiUpperString(const S: string): string;
begin
  if S = '' then
    Exit('');
  Result := SpanToString(TByteSpan.Create(PByte(PAnsiChar(S)), SizeUInt(Length(S))));
  if Length(Result) > 0 then
    ToUpperAscii(Pointer(Result), SizeUInt(Length(Result)));
end;

procedure BytesReplicateCopy(ASrc, ADst: Pointer; ADist, ALen: SizeUInt);
var
  LPat, LDone, LChunk: SizeUInt;
begin
  // not inline: loop + Move
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
  // not inline: SetLength+Move
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
  LOldLen, LReq, LSrcLen: SizeUInt;
begin
  // not inline: SetLength+Move
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
  // not inline: SetLength+Move
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
  // not inline: SetLength
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

function BytesStartsWith(const AData, APrefix: TBytes): Boolean;
begin
  Result := SpanStartsWith(TByteSpan.FromBytes(AData), TByteSpan.FromBytes(APrefix));
end;

function BytesEndsWith(const AData, ASuffix: TBytes): Boolean;
begin
  Result := SpanEndsWith(TByteSpan.FromBytes(AData), TByteSpan.FromBytes(ASuffix));
end;

{ LeadingZero helper — QWord scan }
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
  // not inline: loop
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

function BytesIsGzip(const AData: TBytes): Boolean; inline;
begin
  Result := (Length(AData) >= 2) and (AData[0] = $1F) and (AData[1] = $8B);
end;

function BytesIsGzipHeader(const AHeader: TBytes; const ATotalSize: Int64): Boolean; inline;
begin
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

function BytesToUTF8(const ABytes: TBytes): string;
begin
  Result := BytesToString(ABytes);
end;

function StringToBytes(const AText: string): TBytes;
begin
  // not inline: SetLength+Move
  SetLength(Result, Length(AText));
  if Length(AText) > 0 then
    Move(PAnsiChar(AText)^, Pointer(Result)^, Length(AText));
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
  Result := SpanToString(LSpan);
end;

function TryClampSlice(const AOffset, ALength, ATotal: SizeUInt; out AClampedLen: SizeUInt): Boolean; inline;
begin
  if AOffset >= ATotal then
  begin
    AClampedLen := 0;
    Exit(False);
  end;
  if ALength > ATotal - AOffset then
    AClampedLen := ATotal - AOffset
  else
    AClampedLen := ALength;
  Result := True;
end;

function AnsiPtrToString(const P: PAnsiChar): string;
var
  LP: PAnsiChar;
  LLen: SizeUInt;
begin
  // not inline: loop+Move
  Result := '';
  if P = nil then
    Exit;
  LP := P;
  while LP^ <> #0 do
    Inc(LP);
  LLen := SizeUInt(LP - P);
  if LLen = 0 then
    Exit;
  SetLength(Result, LLen);
  if LLen > 0 then
    Move(P^, Pointer(Result)^, LLen);
end;

function BigEndianUnicodeBytesToString(const AData: TBytes): string;
var
  I, LCount: SizeInt;
  LWChars: array of WideChar;
begin
  // not inline: loop
  Result := '';
  LCount := Length(AData) div 2;
  if LCount = 0 then
    Exit;
  SetLength(LWChars, LCount);
  for I := 0 to LCount - 1 do
    LWChars[I] := WideChar((UInt16(AData[I * 2]) shl 8) or UInt16(AData[I * 2 + 1]));
  SetString(Result, PWideChar(LWChars), LCount);
end;

function FNV1a32(const AData: PByte; const ALen: SizeUInt): UInt32; inline;
begin
  Result := HashBytes(AData, ALen);
end;

function FNV1a32Bytes(const AData: TBytes): UInt32; inline;
begin
  if Length(AData) = 0 then
    Result := HashBytes(nil, 0)
  else
    Result := HashBytes(@AData[0], SizeUInt(Length(AData)));
end;

function HTonN(AValue: Word): Word; inline;
begin
  Result := Word(nextpas.core.bytes.binary.HostToNetwork16(UInt16(AValue)));
end;

function HTonN(AValue: LongWord): LongWord; inline;
begin
  Result := LongWord(nextpas.core.bytes.binary.HostToNetwork32Words(UInt32(AValue)));
end;

function NToHs(AValue: Word): Word; inline;
begin
  Result := Word(nextpas.core.bytes.binary.NetworkToHost16(UInt16(AValue)));
end;

function NToHs(AValue: LongWord): LongWord; inline;
begin
  Result := LongWord(nextpas.core.bytes.binary.NetworkToHost32Words(UInt32(AValue)));
end;

function VarType(const V: Variant): TVarType; inline;
begin
  Result := TVarDataView(V).VType and varTypeMask;
end;

function VarIsNull(const V: Variant): Boolean; inline;
begin
  Result := (TVarDataView(V).VType and varTypeMask) = varNull;
end;

function VarIsEmpty(const V: Variant): Boolean; inline;
begin
  Result := (TVarDataView(V).VType and varTypeMask) = varEmpty;
end;

function VarIsClear(const V: Variant): Boolean; inline;
var
  LType: Word;
begin
  LType := TVarDataView(V).VType and varTypeMask;
  Result := (LType = varEmpty) or (LType = varNull);
end;

end.
