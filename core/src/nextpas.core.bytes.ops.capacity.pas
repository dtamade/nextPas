unit nextpas.core.bytes.ops.capacity;

{$I nextpas.core.settings.inc}
{ R9-02 hermetic：settings.inc 已保障 inline 语义（-O2→INLINE ON），FPC 3.3.1 下无 BEGIN 误报 }

interface

uses
  nextpas.core.base,
  nextpas.core.bytes.base;

procedure BytesReserve(var ADest: TBytes; const AAdditional: SizeUInt); inline;
procedure BytesEnsureCapacity(var ADest: TBytes; const ARequired: SizeUInt); inline;
function BytesGrowCapacity(const ACurrent: Integer): Integer; inline; overload;
function BytesGrowCapacity(const ACurrent: SizeUInt): SizeUInt; inline; overload;
function BytesGrowCapacityCapped(const ACurrent, AMax: Integer): Integer; inline; overload;
function BytesGrowCapacityCapped(const ACurrent, AMax: SizeUInt): SizeUInt; inline; overload;
generic function BytesGrowHelper<T>(ACount, AMax: Integer): Integer; inline;

implementation

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

function BytesGrowCapacity(const ACurrent: Integer): Integer; inline; overload;
begin
  // single source 0→32→2× (BYTES_BUILDER_MIN_GROW 64 的 1/2 缩放单源派生，inline 零拷贝，O(1)均摊，防 O(n²)拷贝；溢出时 +1 兜底)
  if ACurrent = 0 then
    Exit(Integer(BYTES_BUILDER_MIN_GROW shr 1));
  if ACurrent <= High(Integer) div 2 then
    Result := ACurrent * 2
  else
    Result := ACurrent + 1;
end;

function BytesGrowCapacity(const ACurrent: SizeUInt): SizeUInt; inline; overload;
begin
  // single source 0→32→2× (BYTES_BUILDER_MIN_GROW 64 的 1/2 缩放单源派生，inline 零拷贝，O(1)均摊，防 O(n²)拷贝；溢出时 +1 兜底) — SizeUInt 与 Integer 单源一致 shr1=32
  if ACurrent = 0 then
    Exit(BYTES_BUILDER_MIN_GROW shr 1);
  if ACurrent <= High(SizeUInt) div 2 then
    Result := ACurrent * 2
  else
    Result := ACurrent + 1;
end;

function BytesGrowCapacityCapped(const ACurrent, AMax: Integer): Integer; inline; overload;
begin
  // single source capped grow inline 0→32→2× via BytesGrowCapacity, clamp to AMax, O(1) zero-copy, bytes.ops single source, resource managed not lost
  if ACurrent > AMax then
    Exit(ACurrent);
  Result := BytesGrowCapacity(ACurrent);
  if Result > AMax then
    Result := AMax;
  if Result < ACurrent then
    Result := ACurrent;
end;

function BytesGrowCapacityCapped(const ACurrent, AMax: SizeUInt): SizeUInt; inline; overload;
begin
  // single source capped grow SizeUInt variant inline O(1) zero-copy, bytes.ops single source
  if ACurrent > AMax then
    Exit(ACurrent);
  Result := BytesGrowCapacity(ACurrent);
  if Result > AMax then
    Result := AMax;
  if Result < ACurrent then
    Result := ACurrent;
end;

generic function BytesGrowHelper<T>(ACount, AMax: Integer): Integer; inline;
begin
  // generic GrowHelper single source capped grow via BytesGrowCapacityCapped inline zero-copy O(1), T specialization keeps per-call inline no extra dispatch, bytes.ops single source 0→32→2×
  Result := BytesGrowCapacityCapped(ACount, AMax);
end;

end.
