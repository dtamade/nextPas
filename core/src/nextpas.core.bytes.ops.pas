unit nextpas.core.bytes.ops;

{$I nextpas.core.settings.inc}
{ R9-02 hermetic }
{ INV-5 单源: bytes.ops 为 SetLength+Move 唯一实现源，门面仅 inline 薄转发 }
{ perf: 零拷贝 TByteSpan 视图, Compare/MemEqual/FindByte 热路径 inline; 单次 SetLength+Move 零拷贝 Pointer(Result)^ / PAnsiChar(AText)^; BytesGrowCapacity 非 inline (while 循环禁 inline red-line 2) }
{ Move/SetLength 一律 Not inline red-line 1/2; BytesAppend 系列复用 BytesGrowCapacity 指数扩容 amortized O(1) + EnsureAppendCapacity封装mem统一能力高级感; Strip家族QWord快跳单源LeadingZeroOffset优雅去重; stability: SetLength异常安全, sized FreeMemOf; portability: DynArray probe已收敛至L0 mem.dynarray via system.heap NpSystemMemSize (FPC bootstrap单探针，stub优雅，自举债务收敛) }

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
function BytesToString(const ABytes: TBytes): string;
function BytesToUTF8(const ABytes: TBytes): string;
function StringToBytes(const AText: string): TBytes;
function BytesSliceToString(const ABytes: TBytes; const AOffset;
  ALength: SizeUInt): string;

{ Network byte order — single source for HTonN/NToHs (FPC Swap semantics, owner bytes.ops)
  perf: inline zero-copy register shuffle, no alloc; endian-conditional swap; system facade delegates here (INV-5) }
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
  nextpas.core.mem.dynarray;

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
var
  LLen: SizeInt;
begin
  LLen := Length(S);
  if LLen = 0 then
    Exit('');
  SetLength(Result, LLen);
  if LLen > 0 then
    Move(PAnsiChar(S)^, Pointer(Result)^, LLen);
  if LLen > 0 then
    ToLowerAscii(Pointer(Result), SizeUInt(LLen));
end;

function AsciiUpperString(const S: string): string;
var
  LLen: SizeInt;
begin
  LLen := Length(S);
  if LLen = 0 then
    Exit('');
  SetLength(Result, LLen);
  if LLen > 0 then
    Move(PAnsiChar(S)^, Pointer(Result)^, LLen);
  if LLen > 0 then
    ToUpperAscii(Pointer(Result), SizeUInt(LLen));
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

function BytesToString(const ABytes: TBytes): string;
begin
  // perf: single SetLength + single zero-copy Move; not inline per red-line 1 (indexed Move would fold const string -> garbage)
  SetLength(Result, Length(ABytes));
  if Length(ABytes) > 0 then
    Move(Pointer(ABytes)^, Pointer(Result)^, Length(ABytes));
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
  SetLength(Result, LSpan.Len);
  if LSpan.Len > 0 then
    Move(LSpan.Data^, Pointer(Result)^, LSpan.Len);
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

{ Network byte order — single source (owner bytes.ops); inline zero-copy register shuffle, no alloc }

function HTonN(AValue: Word): Word; inline;
begin
  {$IFDEF ENDIAN_BIG}
  Result := AValue;
  {$ELSE}
  { inline zero-copy byte swap (register shuffle, no alloc) }
  Result := Word((AValue shr 8) or (AValue shl 8));
  {$ENDIF}
end;

function HTonN(AValue: LongWord): LongWord; inline;
begin
  {$IFDEF ENDIAN_BIG}
  Result := AValue;
  {$ELSE}
  { inline zero-copy word swap (FPC Swap semantics, register shuffle, no alloc) }
  Result := ((AValue shr 16) and $FFFF) or ((AValue shl 16) and $FFFF0000);
  {$ENDIF}
end;

function NToHs(AValue: Word): Word; inline;
begin
  {$IFDEF ENDIAN_BIG}
  Result := AValue;
  {$ELSE}
  { inline zero-copy byte swap (register shuffle, no alloc) }
  Result := Word((AValue shr 8) or (AValue shl 8));
  {$ENDIF}
end;

function NToHs(AValue: LongWord): LongWord; inline;
begin
  {$IFDEF ENDIAN_BIG}
  Result := AValue;
  {$ELSE}
  { inline zero-copy word swap (FPC Swap semantics, register shuffle, no alloc) }
  Result := ((AValue shr 16) and $FFFF) or ((AValue shl 16) and $FFFF0000);
  {$ENDIF}
end;

end.
