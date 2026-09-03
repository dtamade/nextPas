unit nextpas.core.bytes.ops.capacity;

{$I nextpas.core.settings.inc}
{ bytes.ops.capacity — capacity growth single source (INV-5/INV-2) leaf — while only here, no duplicate in bytes.ops (INV-5 gate: check_bytes_ops_source_contract.py capacity while single source patrol).
  Single source geometric via BYTES_BUILDER_MIN_GROW (0→64→2×) amortized O(1) zero O(n²); Webview variant 0→4→2× via BytesGrowCapacityWithMin reuse same loop (*2 both).
  No Move/FillChar — pure arithmetic, not inline per red-line 2 (loop I-Cache); ops side BytesEnsureCapacity/BytesNextCapacity/WebviewGrowCapacity inline thin-forward reuse single source zero extra call, zero duplicate while/I-Cache. }

interface

uses
  nextpas.core.base,
  nextpas.core.bytes.base,
  nextpas.core.exception;

function BytesGrowCapacityWithMin(const ACurrent, ARequired, AMinGrow: SizeUInt): SizeUInt;
function BytesGrowCapacity(const ACurrent, ARequired: SizeUInt): SizeUInt;
function BytesGrowCapacityIntWithMin(const ACurrent, ARequired, AMinGrow: Integer): Integer;
function BytesGrowCapacityInt(const ACurrent, ARequired: Integer): Integer;
function BytesNextCapacity(AOld, ANeed: SizeUInt): SizeUInt; inline;
function WebviewGrowCapacityForReuse(const ACurrent: Integer): Integer; inline;
function WebviewGrowCapacity(const ACurrent: Integer): Integer; inline;
{ Builder capacity estimates — overflow fail-closed pure arithmetic, inline. }
function BuilderCapForTwo(const ALen1, ALen2: SizeUInt): SizeUInt; inline;
function BuilderCapAdd(const A, B: SizeUInt): SizeUInt; inline;
function BuilderCapForJoin(const ATotal, ACount, ADelimLen: SizeUInt): SizeUInt; inline;
function BuilderCapWithMin(const AEstimate: SizeUInt; const AMin: SizeUInt = 32): SizeUInt; inline;

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

function WebviewGrowCapacity(const ACurrent: Integer): Integer; inline;
begin
  // perf: inline thin-forward alias for peripheral uniformity — reuse same single source 0→4→2× geometric, zero extra call
  Result := WebviewGrowCapacityForReuse(ACurrent);
end;

function BuilderCapForTwo(const ALen1, ALen2: SizeUInt): SizeUInt; inline;
begin
  if ALen1 > High(SizeUInt) - ALen2 then
    raise EOutOfMemory.Create('builder cap overflow');
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
    raise EOutOfMemory.Create('builder join cap overflow');
  LDelimTotal := (ACount - 1) * ADelimLen;
  Result := BuilderCapForTwo(ATotal, LDelimTotal);
end;

function BuilderCapWithMin(const AEstimate: SizeUInt; const AMin: SizeUInt): SizeUInt; inline;
begin
  if AEstimate < AMin then
    Result := AMin
  else
    Result := AEstimate;
end;

end.
