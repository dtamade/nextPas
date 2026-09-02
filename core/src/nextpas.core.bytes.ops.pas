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
{ perf: BytesAppend uses amortized NextPow2 growth (bytes.ops single source via simd.bitops NextPow2, inline, zero-copy Move, header poke preserves slack) — looped appends amortized O(1) (no O(n²) churn). For bulk/very high-frequency still prefer IBytesBuilder (preallocated Grow) or BytesConcatMany/SpanConcatMany single allocation. Keep inline for convenience. }
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
procedure BytesReserve(var ADest: TBytes; const AAdditional: SizeUInt); inline;
procedure BytesEnsureCapacity(var ADest: TBytes; const ARequired: SizeUInt); inline;
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
function BytesToString(const ABytes: TBytes): string;
function BytesToUTF8(const ABytes: TBytes): string;
function StringToBytes(const AText: string): TBytes;
function BytesSliceToString(const ABytes: TBytes; const AOffset,
  ALength: SizeUInt): string;
{ C string length single source: PAnsiChar null-terminated length, SIMD via System.StrLen (SSE2/AVX2/NEON), inline zero-copy, replaces scalar while AP[LLen]<>#0 loop; nil=>0; single source for text.utils CStrToStr/webview ViewFromPChar hot scheme path }
function CStrLen(const AP: PAnsiChar): SizeUInt; inline;
function StringLowerAsciiAware(const S: string): string; inline; { 薄转发 text.unicode.utils.ToLowerAsciiAware 单源：ASCII 预检+零拷贝，owner text.unicode.utils }

{ vec/smallvec 生长单源：0→4→2× 倍增，inline 零额外调用，bytes.ops 唯一权威；webview/collections 复用此单源 }
function VecGrowCapacity(ACurrent: Integer): Integer; inline;
{ 通用动态数组 Grow：Count 与物理 Length 精确对比，inline 薄转发单源，消除约30个样板重复，零额外调用 }
generic procedure VecGrow<T>(var AArr: array of T; ACount: Integer); inline;
{ 零拷贝快照：按 ACount 精确截断/复制 ADest := copy(ASrc,0,ACount)，nil 零分配，inline 零额外调用，单源治理 Builder 等全量 SetLength 直写漂移；managed 类型逐元素赋值保 refcnt，blittable 单次 Move 批量零拷贝（编译器批量 Move 优化且避免托管类型 refcnt 抖动）}
generic procedure VecSnapshot<T>(var ADest: array of T; const ASrc: array of T; ACount: Integer); inline;
{ 零拷贝截断：按 ACount 精确 SetLength，inline 单源，消除手写 SetLength 重复 }
generic procedure VecTrim<T>(var AArr: array of T; ACount: Integer); inline;
{ 紧凑 Vec 删除单源：Swap O(1) 零拷贝末尾换位 + ordered O(n) 保序，bytes.ops 唯一权威；Swap/ordered 均含扫描循环按 design-conventions §2 红线二去 inline 避 I-Cache 膨胀；webview.live 薄转发，热关闭路径默认 Swap 避免 O(n²) }
generic procedure VecRemoveSwap<T>(var AArr: array of T; var ACount: Integer; const AValue: T);
generic procedure VecRemoveOrdered<T>(var AArr: array of T; var ACount: Integer; const AValue: T);
{ 零拷贝批量拷贝单源：managed 逐元素保 refcnt，blittable 单次 Move 零拷贝，inline 单源供线性容扩/环形线性化复用 }
generic procedure VecCopy<T>(const ASrc: array of T; var ADst: array of T; ACount: Integer); inline;
{ 环形线性化单源：两段式免模线性化，复用 VecCopy 单源，inline 零额外调用，供 Dispatcher/ CircularBuffer 单源复用 }
generic procedure VecRingCopy<T>(const ASrc: array of T; AHead, ACount: Integer; var ADst: array of T); inline;

{ L1 通用紧凑 Vec 注册表单源（CONTRACT §1.2/§50 可抽候选已反哺落地 L1 bytes.ops）：供 webview.live/window.live 家族薄转发，inline 零额外调用，0→4→2× VecGrowCapacity 单源，Swap O(1) 零拷贝，Default(T) 释放不丢 — 家族内不另立重复实现 }
type
  generic TCompactLiveRegistry<T> = class
  private
    FList: array of T;
    FCount: Integer;
  public
    procedure Register(const AInst: T); inline;
    procedure Unregister(const AInst: T); inline;
    procedure UnregisterSwap(const AInst: T); inline;
    function Count: Integer; inline;
    function IsEmpty: Boolean; inline;
    function At(AIndex: Integer): T; inline;
    procedure Snapshot(var ADest: array of T); inline;
    procedure Trim; inline;
    procedure Clear;
    destructor Destroy; override;
  end;

implementation

uses
  nextpas.core.simd,
  nextpas.core.simd.bitops,
  nextpas.core.text.unicode.utils;

{ BytesEnsureCapacity/Reserve: amortized NextPow2 growth (single source simd.bitops) + header poke preserves heap slack.
  Old exact SetLength per BytesAppend caused O(n²) copy churn in loops; new keeps logical Length via header poke
  (PSizeInt(ADest)[-1]) while heap block stays pow2-sized, so looped appends are amortized O(1) with single zero-copy Move.
  For bulk still prefer IBytesBuilder/ConcatMany single allocation. Stability: SetLength exception-safe; poke only after
  successful SetLength, nil guard, no leak; per-var affine (no global map), inline hot path. }

procedure BytesEnsureCapacity(var ADest: TBytes; const ARequired: SizeUInt); inline;
var
  LOldLen, LCap, LNewCap: SizeUInt;
begin
  LOldLen := SizeUInt(Length(ADest));
  if ARequired <= LOldLen then
    Exit;
  // infer current heap capacity from logical length (pow2 slack via prior poke)
  if LOldLen = 0 then
    LCap := 0
  else if LOldLen <= BYTES_BUILDER_MIN_GROW then
    LCap := BYTES_BUILDER_MIN_GROW
  else
  begin
{$IFDEF CPU64}
    LCap := SizeUInt(NextPow2_64(TU64(LOldLen)));
{$ELSE}
    LCap := SizeUInt(NextPow2_32(TU32(LOldLen)));
{$ENDIF}
    if LCap = 0 then
      LCap := LOldLen;
    if LCap < BYTES_BUILDER_MIN_GROW then
      LCap := BYTES_BUILDER_MIN_GROW;
  end;
  if ARequired <= LCap then
    Exit;
  // need grow: single-source NextPow2 (O(1) bit-ops, inline, zero-copy)
  if ARequired <= BYTES_BUILDER_MIN_GROW then
    LNewCap := BYTES_BUILDER_MIN_GROW
  else
  begin
{$IFDEF CPU64}
    LNewCap := SizeUInt(NextPow2_64(TU64(ARequired)));
{$ELSE}
    LNewCap := SizeUInt(NextPow2_32(TU32(ARequired)));
{$ENDIF}
    if LNewCap = 0 then
      LNewCap := ARequired;
    if LNewCap < BYTES_BUILDER_MIN_GROW then
      LNewCap := BYTES_BUILDER_MIN_GROW;
  end;
  SetLength(ADest, LNewCap);
  // restore logical length (keep heap slack), exception-safe: poke only after success
  if Pointer(ADest) <> nil then
    PSizeInt(Pointer(ADest))[-1] := SizeInt(LOldLen);
end;

procedure BytesReserve(var ADest: TBytes; const AAdditional: SizeUInt); inline;
var
  LNeed: SizeUInt;
begin
  if AAdditional = 0 then
    Exit;
  // overflow guard: let SetLength raise on wrap
  LNeed := SizeUInt(Length(ADest)) + AAdditional;
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
  LOldLen, LNeed: SizeUInt;
begin
  // perf: inline + amortized NextPow2 growth (bytes.ops single source) + single zero-copy Move, header poke preserves slack
  if Length(ASrc) = 0 then
    Exit;
  LOldLen := SizeUInt(Length(ADest));
  LNeed := LOldLen + SizeUInt(Length(ASrc));
  BytesEnsureCapacity(ADest, LNeed);
  if Pointer(ADest) <> nil then
    PSizeInt(Pointer(ADest))[-1] := SizeInt(LNeed)
  else
    SetLength(ADest, LNeed);
  Move(ASrc[0], PByte(Pointer(ADest))[LOldLen], Length(ASrc));
end;

procedure BytesAppend(var ADest: TBytes; const ASrc: PByte; const ASrcLen: SizeUInt); inline; overload;
var
  LOldLen, LNeed: SizeUInt;
begin
  // perf: inline + amortized growth + single Move zero-copy, header poke keeps capacity
  if (ASrc = nil) or (ASrcLen = 0) then
    Exit;
  LOldLen := SizeUInt(Length(ADest));
  LNeed := LOldLen + ASrcLen;
  BytesEnsureCapacity(ADest, LNeed);
  if Pointer(ADest) <> nil then
    PSizeInt(Pointer(ADest))[-1] := SizeInt(LNeed)
  else
    SetLength(ADest, LNeed);
  Move(ASrc^, PByte(Pointer(ADest))[LOldLen], ASrcLen);
end;

procedure BytesAppendByte(var ADest: TBytes; AValue: Byte); inline;
var
  LOldLen, LNeed: SizeUInt;
begin
  // perf: inline + amortized growth + direct store zero-copy, header poke preserves slack
  LOldLen := SizeUInt(Length(ADest));
  LNeed := LOldLen + 1;
  BytesEnsureCapacity(ADest, LNeed);
  if Pointer(ADest) <> nil then
    PSizeInt(Pointer(ADest))[-1] := SizeInt(LNeed)
  else
    SetLength(ADest, LNeed);
  PByte(Pointer(ADest))[LOldLen] := AValue;
end;

procedure BytesAppendUInt16BE(var ADest: TBytes; AValue: Word); inline;
var
  LOldLen, LNeed: SizeUInt; P: PByte;
begin
  LOldLen := SizeUInt(Length(ADest));
  LNeed := LOldLen + 2;
  BytesEnsureCapacity(ADest, LNeed);
  if Pointer(ADest) <> nil then
    PSizeInt(Pointer(ADest))[-1] := SizeInt(LNeed)
  else
    SetLength(ADest, LNeed);
  P := PByte(Pointer(ADest)) + LOldLen;
  P[0] := Byte(AValue shr 8);
  P[1] := Byte(AValue);
end;

procedure BytesAppendUInt24BE(var ADest: TBytes; AValue: Cardinal); inline;
var
  LOldLen, LNeed: SizeUInt; P: PByte;
begin
  LOldLen := SizeUInt(Length(ADest));
  LNeed := LOldLen + 3;
  BytesEnsureCapacity(ADest, LNeed);
  if Pointer(ADest) <> nil then
    PSizeInt(Pointer(ADest))[-1] := SizeInt(LNeed)
  else
    SetLength(ADest, LNeed);
  P := PByte(Pointer(ADest)) + LOldLen;
  P[0] := Byte(AValue shr 16);
  P[1] := Byte(AValue shr 8);
  P[2] := Byte(AValue);
end;

procedure BytesAppendUInt32BE(var ADest: TBytes; AValue: Cardinal); inline;
var
  LOldLen, LNeed: SizeUInt; P: PByte;
begin
  LOldLen := SizeUInt(Length(ADest));
  LNeed := LOldLen + 4;
  BytesEnsureCapacity(ADest, LNeed);
  if Pointer(ADest) <> nil then
    PSizeInt(Pointer(ADest))[-1] := SizeInt(LNeed)
  else
    SetLength(ADest, LNeed);
  P := PByte(Pointer(ADest)) + LOldLen;
  P[0] := Byte(AValue shr 24);
  P[1] := Byte(AValue shr 16);
  P[2] := Byte(AValue shr 8);
  P[3] := Byte(AValue);
end;

procedure BytesAppendUInt16LE(var ADest: TBytes; AValue: Word); inline;
var
  LOldLen, LNeed: SizeUInt; P: PByte;
begin
  LOldLen := SizeUInt(Length(ADest));
  LNeed := LOldLen + 2;
  BytesEnsureCapacity(ADest, LNeed);
  if Pointer(ADest) <> nil then
    PSizeInt(Pointer(ADest))[-1] := SizeInt(LNeed)
  else
    SetLength(ADest, LNeed);
  P := PByte(Pointer(ADest)) + LOldLen;
  P[0] := Byte(AValue);
  P[1] := Byte(AValue shr 8);
end;

procedure BytesAppendUInt32LE(var ADest: TBytes; AValue: Cardinal); inline;
var
  LOldLen, LNeed: SizeUInt; P: PByte;
begin
  LOldLen := SizeUInt(Length(ADest));
  LNeed := LOldLen + 4;
  BytesEnsureCapacity(ADest, LNeed);
  if Pointer(ADest) <> nil then
    PSizeInt(Pointer(ADest))[-1] := SizeInt(LNeed)
  else
    SetLength(ADest, LNeed);
  P := PByte(Pointer(ADest)) + LOldLen;
  P[0] := Byte(AValue);
  P[1] := Byte(AValue shr 8);
  P[2] := Byte(AValue shr 16);
  P[3] := Byte(AValue shr 24);
end;

procedure BytesAppendUInt64BE(var ADest: TBytes; AValue: QWord); inline;
var
  LOldLen, LNeed: SizeUInt; P: PByte;
begin
  LOldLen := SizeUInt(Length(ADest));
  LNeed := LOldLen + 8;
  BytesEnsureCapacity(ADest, LNeed);
  if Pointer(ADest) <> nil then
    PSizeInt(Pointer(ADest))[-1] := SizeInt(LNeed)
  else
    SetLength(ADest, LNeed);
  P := PByte(Pointer(ADest)) + LOldLen;
  P[0] := Byte(AValue shr 56);
  P[1] := Byte(AValue shr 48);
  P[2] := Byte(AValue shr 40);
  P[3] := Byte(AValue shr 32);
  P[4] := Byte(AValue shr 24);
  P[5] := Byte(AValue shr 16);
  P[6] := Byte(AValue shr 8);
  P[7] := Byte(AValue);
end;

procedure BytesAppendUInt64LE(var ADest: TBytes; AValue: QWord); inline;
var
  LOldLen, LNeed: SizeUInt; P: PByte;
begin
  LOldLen := SizeUInt(Length(ADest));
  LNeed := LOldLen + 8;
  BytesEnsureCapacity(ADest, LNeed);
  if Pointer(ADest) <> nil then
    PSizeInt(Pointer(ADest))[-1] := SizeInt(LNeed)
  else
    SetLength(ADest, LNeed);
  P := PByte(Pointer(ADest)) + LOldLen;
  P[0] := Byte(AValue);
  P[1] := Byte(AValue shr 8);
  P[2] := Byte(AValue shr 16);
  P[3] := Byte(AValue shr 24);
  P[4] := Byte(AValue shr 32);
  P[5] := Byte(AValue shr 40);
  P[6] := Byte(AValue shr 48);
  P[7] := Byte(AValue shr 56);
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

function BytesToString(const ABytes: TBytes): string;
begin
  // non-inline per design-conventions §2 red-line 1 (Move(ABytes[0],Result[1]) forbids inline, avoids const-fold garbage); single alloc + single Move zero-copy
  SetLength(Result, Length(ABytes));
  if Length(ABytes) > 0 then
    Move(ABytes[0], Result[1], Length(ABytes));
end;

function BytesToUTF8(const ABytes: TBytes): string;
begin
  Result := BytesToString(ABytes);
end;

function StringToBytes(const AText: string): TBytes;
begin
  // non-inline per design-conventions §2 red-line 1 (Move(...,Result[0]) forbids inline, avoids const-fold garbage); single alloc + single Move zero-copy
  SetLength(Result, Length(AText));
  if Length(AText) > 0 then
    Move(PAnsiChar(AText)^, Result[0], Length(AText));
end;

function BytesSliceToString(const ABytes: TBytes; const AOffset,
  ALength: SizeUInt): string;
var
  LSpan: TByteSpan;
begin
  // non-inline per design-conventions §2 red-line 1 (Move(...,Result[1]) forbids inline); view zero-copy + single Move
  if ALength = 0 then
    Exit('');
  { 零拷贝借用：Slice 仅建视图不分配，生命周期绑 ABytes }
  LSpan := TByteSpan.FromBytes(ABytes).Slice(AOffset, ALength);
  SetLength(Result, LSpan.Len);
  if LSpan.Len > 0 then
    Move(LSpan.Data^, Result[1], LSpan.Len);
end;

function CStrLen(const AP: PAnsiChar): SizeUInt; inline;
begin
  if AP = nil then
    Exit(0);
  // perf: single-source C string len via System.StrLen SIMD (SSE2/AVX2/NEON), inline zero-copy, replaces scalar O(n) while loop on hot scheme path; nil guard zero alloc
  Result := SizeUInt(System.StrLen(AP));
end;

function StringLowerAsciiAware(const S: string): string; inline;
begin
  Result := nextpas.core.text.unicode.utils.ToLowerAsciiAware(S);
end;

function VecGrowCapacity(ACurrent: Integer): Integer; inline;
begin
  if ACurrent = 0 then
    Result := 4
  else
    Result := ACurrent * 2;
end;

generic procedure VecGrow<T>(var AArr: array of T; ACount: Integer); inline;
begin
  if ACount = Length(AArr) then
    SetLength(AArr, VecGrowCapacity(Length(AArr)));
end;

generic procedure VecSnapshot<T>(var ADest: array of T; const ASrc: array of T; ACount: Integer); inline;
var
  I: Integer;
begin
  // perf: inline + nil zero-alloc fast path + single SetLength + blittable single Move (bulk, zero refcnt churn) vs managed per-elem (refcnt safe), single source; inline zero-copy single source for live registry/webview
  if ACount <= 0 then
  begin
    ADest := nil;
    Exit;
  end;
  SetLength(ADest, ACount);
  if System.IsManagedType(T) then
  begin
    for I := 0 to ACount - 1 do
      ADest[I] := ASrc[I];
  end
  else if ACount > 0 then
    Move(ASrc[0], ADest[0], SizeUInt(ACount) * SizeUInt(SizeOf(T)));
end;

generic procedure VecTrim<T>(var AArr: array of T; ACount: Integer); inline;
begin
  // perf: inline single SetLength, single source for trim/snapshot tail, zero extra call
  if ACount <= 0 then
    AArr := nil
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
    Move(ASrc[0], ADst[0], SizeUInt(ACount) * SizeUInt(SizeOf(T)));
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
      Move(ASrc[AHead], ADst[0], SizeUInt(ACount) * SizeUInt(SizeOf(T)));
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
        Move(ASrc[AHead], ADst[0], SizeUInt(LTail) * SizeUInt(SizeOf(T)));
      if ACount - LTail > 0 then
        Move(ASrc[0], ADst[LTail], SizeUInt(ACount - LTail) * SizeUInt(SizeOf(T)));
    end;
  end;
end;

{ TCompactLiveRegistry — L1 single source for webview.live/window.live compact Vec registry, inline thin-forward, zero duplicate }

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

generic procedure TCompactLiveRegistry.Snapshot(var ADest: array of T); inline;
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

generic destructor TCompactLiveRegistry.Destroy;
begin
  Clear;
  inherited Destroy;
end;

end.
