unit nextpas.core.bytes.ops;

{$I nextpas.core.settings.inc}
{ R9-02 hermetic }
{ INV-5 单源: bytes.ops is single source for SetLength+Move; facade inline thin-forward only. }
{ perf: zero-copy TByteSpan views; hot paths inline, alloc paths single SetLength+Move not inline (red-line 1, red-line 2). }

interface

uses
  nextpas.core.base,
  nextpas.core.base.utils,
  nextpas.core.bytes.base;

{ Span ops — single source (INV-5); inline/zero-copy TByteSpan view; hot path inline, alloc paths single SetLength+Move not inline }
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
{ respack/writer 单源：路径/内容零拷贝搬运与零填，inline 单 Move/Fill，无额外分配，显式标注 bytes.ops 单源防漂移 }
procedure BytesCopy(ADst, ASrc: Pointer; const ALen: SizeUInt); inline;
procedure BytesZero(ADst: Pointer; const ALen: SizeUInt); inline;
procedure SpanZero(const ASpan: TByteSpan); inline;

{ 全局零页单源（.bss 零初值，4K 对齐页）：writer.stream 万槽零填共享，无栈分配/无重复 FillChar，零拷贝分段直写；按需切片避免小间隙 4K memset }
const
  BYTES_ZERO_PAGE_SIZE = 4096;
  // 小间隙切片阈值：按需 slice 为 SizeUInt(N) 而非整页 4K memset；阈值即 BYTES_ZERO_PAGE_SIZE，零拷贝分段直写
  BYTES_ZERO_PAGE_SLICE_THRESHOLD = BYTES_ZERO_PAGE_SIZE;
var
  BYTES_ZERO_PAGE: array[0..BYTES_ZERO_PAGE_SIZE - 1] of Byte;

{ 零页切片单源 — writer.stream 复用入口；阈值切片避免小间隙 4K memset 零拷贝视图 }
function ZeroPageSlice(const ALen: SizeUInt): TByteSpan; inline;

{ perf: bulk XOR single source — QWord-batched (8B) + tail, zero-copy in-place; Not inline per red-line 2 (循环/SIMD 体 I-Cache 膨胀); owner bytes.ops }
procedure XorInplace(ADst, AKey: PByte; ALen: SizeUInt);
procedure SpanXorInplace(const ADst, AKey: TByteSpan); inline;

{ ASCII case — single source Vec bulk via simd (owner bytes.ops); not inline per red-line 2 (SIMD/loop I-Cache) }
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
{ single source bytes.ops: exponential via BytesGrowCapacity + single zero-copy Move amortized O(1), not inline per red-line 1/2 }
procedure BytesAppend(var ADest: TBytes; const ASrc: TBytes); overload;
procedure BytesAppend(var ADest: TBytes; const ASrc: PByte; const ASrcLen: SizeUInt); overload;
procedure BytesAppendByte(var ADest: TBytes; AValue: Byte);
procedure BytesAppendUInt16BE(var ADest: TBytes; AValue: Word);
procedure BytesAppendUInt24BE(var ADest: TBytes; AValue: Cardinal);
procedure BytesAppendUInt32BE(var ADest: TBytes; AValue: Cardinal);
procedure BytesReserve(var ADest: TBytes; const AAdditional: SizeUInt);
procedure BytesEnsureCapacity(var ADest: TBytes; const ARequired: SizeUInt);
function BytesNextCapacity(AOld, ANeed: SizeUInt): SizeUInt; inline;
{ perf: single source bytes.ops — single-source exponential grow for generic arrays — reuse everywhere to avoid linear SetLength churn.
  not inline per red-line 2: while loop I-Cache; pure capacity math zero-copy (no Move) but loop forbids inline. }
function BytesGrowCapacity(const ACurrent, ARequired: SizeUInt): SizeUInt;
function BytesGrowCapacityInt(const ACurrent, ARequired: Integer): Integer;
function BytesConcatMany(const AParts: array of TBytes): TBytes;
function SpanConcatMany(const AParts: array of TByteSpan): TBytes;
function BytesStartsWith(const AData, APrefix: TBytes): Boolean; inline;
function BytesEndsWith(const AData, ASuffix: TBytes): Boolean; inline;

{ Unsigned big-endian helpers (canonical single source for crypto/tls) }
{ perf: StripLeadingZero 家族单源 bytes.ops；View 零拷贝视图、Span 单遍扫描、Bytes 单次分配/CoW 共享；Not inline per red-line 2（QWord 快跳 while 循环体会 I-Cache 膨胀）}
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
{ single source for clamped slice extent — TStringView.Slice + SliceToStr share, zero-copy extent calc, inline hot path, owner bytes.ops }
function TryClampSlice(const AOffset, ALength, ATotal: SizeUInt; out AClampedLen: SizeUInt): Boolean; inline;
{ single source for PAnsiChar -> string (nil-safe, zero-copy Move); not inline per red-line 1/2 - loop/SetLength+Move }
function AnsiPtrToString(const P: PAnsiChar): string;
{ single source for BE UTF-16 bytes -> string (zero-copy WideChar view + SetString); not inline per red-line 2 - loop }
function BigEndianUnicodeBytesToString(const AData: TBytes): string;

{ Variant type helpers — single source via bytes.ops (INV-5), text/convert normalization point
  perf: inline zero-copy TVarData view, masked varTypeMask for by-ref/array, no alloc; system facade thin-forwards via text.conv -> bytes.ops }
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

{ Network byte order — single source via nextpas.core.bytes.binary endian helpers (FPC Swap semantics, owner bytes.ops thin-forward)
  perf: inline zero-copy register shuffle via bytes.binary.HostToNetwork*/SwapUInt* single source, no alloc/diverge; endian-conditional in binary; system facade delegates here (INV-5) }
function HTonN(AValue: Word): Word; overload; inline;
function HTonN(AValue: LongWord): LongWord; overload; inline;
function NToHs(AValue: Word): Word; overload; inline;
function NToHs(AValue: LongWord): LongWord; overload; inline;

{ FNV-1a 32 single source (owner: bytes.ops thin wrapper over base.HashBytes) — inline/zero-copy
  PByte+Len view, reuses checksum.fnv32 constants (2166136261/16777619), batch 8 via HashBytes }
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

{ safe SetLength growth; BytesEnsureCapacity: capacity==Length no header poke (capacity exposed as Length); BytesAppend 系列: exponential via BytesGrowCapacity + EnsureAppendCapacity封装mem.dynarray定长(capacity retained, amortized O(1) zero-copy Move)高级感; perf: single Move per append not inline red-line 1/2; stability: exception-safe; portability: DynArray via L0 mem.dynarray unified (system.heap MemSize单探针，stub优雅) }

procedure BytesEnsureCapacity(var ADest: TBytes; const ARequired: SizeUInt);
var
  LOld, LNewCap: SizeUInt;
begin
  LOld := SizeUInt(Length(ADest));
  if ARequired <= LOld then
    Exit;
  // single-source: delegate to BytesGrowCapacity to avoid divergent doubling/overflow branches
  // perf: inline capacity math (zero-copy), SetLength only once; exception-safe (no header poke)
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
  // not inline per red-line 2: while loop would I-Cache bloat if inlined; pure capacity math zero-copy
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
  // 指数预分配摊还 O(1): 溢出钳制至 High(Integer) 而非回退 LReq，避免大对象追加线性退化
  if LCap > SizeUInt(High(Integer)) then
    LCap := SizeUInt(High(Integer));
  Result := Integer(LCap);
end;

{ L0 mem unified: header probe hidden in mem.dynarray via system.heap NpSystemMemSize (single probe site, stub elegance, bootstrap converged). No direct heap probe, no header record here (L0 owned). Inline thin forward keeps bytes.ops single source + zero-copy evidence. }
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

{ 高级封装: 追加容量准备 — 指数扩容(capacity) + header poke定长，CoW感知，异常安全；隐藏 DynArray 底层 hack 的高级感 }
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
  // Vec bulk via simd single source; in-place, no alloc
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
  // INV-5 单源: SetLength+Move via SpanToString single source (TByteSpan view, single SetString alloc, zero-copy Move); perf inline thin-forward in facade
  Result := SpanToString(TByteSpan.Create(PByte(PAnsiChar(S)), SizeUInt(Length(S))));
  if Length(Result) > 0 then
    ToLowerAscii(Pointer(Result), SizeUInt(Length(Result)));
end;

function AsciiUpperString(const S: string): string;
begin
  if S = '' then
    Exit('');
  // INV-5 单源: SetLength+Move via SpanToString single source; zero-copy view
  Result := SpanToString(TByteSpan.Create(PByte(PAnsiChar(S)), SizeUInt(Length(S))));
  if Length(Result) > 0 then
    ToUpperAscii(Pointer(Result), SizeUInt(Length(Result)));
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
  // perf: threshold slice — small gap ALen < BYTES_ZERO_PAGE_SLICE_THRESHOLD avoids full 4K memset; zero-copy view into .bss page, single source for writer.stream 万槽零填
  if ALen > BYTES_ZERO_PAGE_SIZE then
    Result := TByteSpan.Create(@BYTES_ZERO_PAGE[0], BYTES_ZERO_PAGE_SIZE)
  else
    Result := TByteSpan.Create(@BYTES_ZERO_PAGE[0], ALen);
end;

function SpanConcat(const A, B: TByteSpan): TBytes;
begin
  Result := nil;
  SetLength(Result, A.Len + B.Len);
  // perf: single SetLength + zero-copy Moves; not inline per red-line 1 (Result[LOff] fed untyped would fold)
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
      // zero-copy single alloc: each span copied once; LOff tracks dest offset via pointer arith to avoid indexed untyped param
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
  // single allocation for all parts; each part copied once via zero-copy Move
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
  // perf: exponential grow via BytesGrowCapacity (single source, BYTES_BUILDER_MIN_GROW, *2 geometric) — single SetLength + single zero-copy Move amortized O(1); not inline per red-line 1/2
  // stability: exception-safe SetLength, sized poke for length (capacity retained), CoW-aware via RefCnt check — 封装于 EnsureAppendCapacity
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
  // perf: exponential grow via BytesGrowCapacity — amortized O(1) for loop appends; not inline per red-line 1/2; 封装高级感
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
  // not inline: per-call SetLength would bloat I-Cache when looped; exponential grow via BytesGrowCapacity amortized O(1); 封装
  LOldLen := SizeUInt(Length(ADest));
  if LOldLen = High(SizeUInt) then
    raise EOutOfMemory.Create('BytesAppendByte: size overflow');
  LReq := LOldLen + 1;
  EnsureAppendCapacity(ADest, LOldLen, LReq);
  // zero-copy single byte store (no Move)
  PByte(Pointer(ADest) + LOldLen)^ := AValue;
end;

procedure BytesAppendUInt16BE(var ADest: TBytes; AValue: Word);
var
  LOldLen, LReq: SizeUInt;
begin
  // not inline per red-line; exponential grow amortized O(1); 封装
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

{ 单源 helper: QWord 批量快跳去零 — Strip 家族唯一实现源；Not inline per red-line 2 (循环体 I-Cache 膨胀) }
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
  // perf: 零拷贝视图预分配后单次分配/CoW 共享；QWord 快跳单源 helper 优雅性，去重 while 重复
  // not inline per red-line 2: while 循环体禁 inline
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
    // no trim needed: zero-copy CoW share, avoids SetLength+Move allocation for hot small views
    Result := AData;
    Exit;
  end;
  // trimmed: single allocation + Move, no extra SpanClone allocation
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
  // 单源复用 LeadingZeroOffset — 零拷贝视图，去重 QWord 快跳重复
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
  // perf: single SetLength + single zero-copy Move; not inline; PAnsiChar deref avoids AText[1] folding
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
  // single source for clamped slice extent — TStringView.Slice + SliceToStr share, zero-copy extent calc, inline hot path, owner bytes.ops
  // perf: pure arithmetic, zero-copy view extent, inline
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
  { perf: single SetLength + single zero-copy Move (Pointer(Result)^); not inline per red-line 1/2 (loop+Move) single source }
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
  { perf: single SetLength(LWChars)+SetString; not inline per red-line 2 (loop I-Cache) single source }
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

{ Network byte order — single source via nextpas.core.bytes.binary endian helpers (owner bytes.ops thin-forward); inline zero-copy register shuffle, no alloc }

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
  { perf: inline zero-copy TVarData view (Word overlay at offset 0), masked varTypeMask for by-ref/array normalization, no alloc }
  Result := TVarDataView(V).VType and varTypeMask;
end;

function VarIsNull(const V: Variant): Boolean; inline;
begin
  { perf: inline zero-copy view, masked compare, no alloc }
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
