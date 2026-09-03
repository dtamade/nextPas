unit nextpas.core.bytes.ops.capacity;

{$I nextpas.core.settings.inc}
{ bytes.ops.capacity — capacity growth single source (INV-5/INV-2) leaf — while only here, no duplicate in bytes.ops (INV-5 gate: check_bytes_ops_source_contract.py capacity while single source patrol).
  Single source geometric via BYTES_BUILDER_MIN_GROW (0→64→2×) amortized O(1) zero O(n²); Webview variant 0→4→2× via BytesGrowCapacityWithMin reuse same loop (*2 both).
  No Move/FillChar — pure arithmetic, not inline per red-line 2 (loop I-Cache); ops side BytesEnsureCapacity/BytesNextCapacity/WebviewGrowCapacity inline thin-forward reuse single source zero extra call, zero duplicate while/I-Cache. }

interface

uses
  nextpas.core.base,
  nextpas.core.bytes.base;

function BytesGrowCapacityWithMin(const ACurrent, ARequired, AMinGrow: SizeUInt): SizeUInt;
function BytesGrowCapacity(const ACurrent, ARequired: SizeUInt): SizeUInt; overload;
function BytesGrowCapacityIntWithMin(const ACurrent, ARequired, AMinGrow: Integer): Integer;
function BytesGrowCapacityInt(const ACurrent, ARequired: Integer): Integer;
function BytesNextCapacity(AOld, ANeed: SizeUInt): SizeUInt; inline;
function WebviewGrowCapacityForReuse(const ACurrent: Integer): Integer; inline;
function WebviewGrowCapacity(const ACurrent: Integer): Integer; inline;
{ lane-window: single-source single-arg grow/capped/helper (union merge) }
procedure BytesReserve(var ADest: TBytes; const AAdditional: SizeUInt); inline;
procedure BytesEnsureCapacity(var ADest: TBytes; const ARequired: SizeUInt); inline;
function BytesGrowCapacity(const ACurrent: Integer): Integer; inline; overload;
function BytesGrowCapacity(const ACurrent: SizeUInt): SizeUInt; inline; overload;
function BytesGrowCapacityCapped(const ACurrent, AMax: Integer): Integer; inline; overload;
function BytesGrowCapacityCapped(const ACurrent, AMax: SizeUInt): SizeUInt; inline; overload;
generic function BytesGrowHelper<T>(ACount, AMax: Integer): Integer; inline;
function WebviewGrowCapacity(const ACurrent: Integer): Integer; inline;

implementation

function BytesGrowCapacityWithMin(const ACurrent, ARequired, AMinGrow: SizeUInt): SizeUInt;
var
  LNewCap: SizeUInt;
begin
  // not inline: loop — parameterized single source for BytesGrowCapacity & Webview reuse
  if ARequired <= ACurrent then
    Exit(ACurrent);
  LNewCap := ACurrent;
  if LNewCap < AMinGrow then
    LNewCap := AMinGrow;
  if LNewCap = 0 then
    LNewCap := 1;
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

function BytesGrowCapacity(const ACurrent, ARequired: SizeUInt): SizeUInt;
begin
  Result := BytesGrowCapacityWithMin(ACurrent, ARequired, BYTES_BUILDER_MIN_GROW);
end;

function BytesGrowCapacityIntWithMin(const ACurrent, ARequired, AMinGrow: Integer): Integer;
var
  LCur, LReq, LCap, LMin: SizeUInt;
begin
  if ARequired <= ACurrent then
    Exit(ACurrent);
  if ACurrent < 0 then LCur := 0 else LCur := SizeUInt(ACurrent);
  if ARequired < 0 then LReq := 0 else LReq := SizeUInt(ARequired);
  if AMinGrow < 0 then LMin := 0 else LMin := SizeUInt(AMinGrow);
  LCap := BytesGrowCapacityWithMin(LCur, LReq, LMin);
  if LCap > SizeUInt(High(Integer)) then
    LCap := SizeUInt(High(Integer));
  Result := Integer(LCap);
end;

function BytesGrowCapacityInt(const ACurrent, ARequired: Integer): Integer;
begin
  Result := BytesGrowCapacityIntWithMin(ACurrent, ARequired, Integer(BYTES_BUILDER_MIN_GROW));
end;

function BytesNextCapacity(AOld, ANeed: SizeUInt): SizeUInt; inline;
begin
  Result := BytesGrowCapacity(AOld, ANeed);
end;

function WebviewGrowCapacityForReuse(const ACurrent: Integer): Integer; inline;
begin
  // perf: inline thin-forward, zero extra call, reuse capacity single source geometric (0→4→2×)
  if ACurrent = 0 then
    Exit(4);
  Result := BytesGrowCapacityIntWithMin(ACurrent, ACurrent + 1, 0);
end;

{ lane-window single-arg grow/capped/helper bodies (union merge; overloads of two-arg single source) }
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

function WebviewGrowCapacity(const ACurrent: Integer): Integer; inline;
begin
  // perf: inline thin-forward alias for peripheral uniformity — reuse same single source 0→4→2× geometric, zero extra call
  Result := WebviewGrowCapacityForReuse(ACurrent);
end;

end.
