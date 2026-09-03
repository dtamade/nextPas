unit nextpas.core.bytes.ops.capacity;

{$I nextpas.core.settings.inc}
{ bytes.ops.capacity — capacity growth single source (INV-5/INV-2)
  Single source geometric via BYTES_BUILDER_MIN_GROW (0→64→2×) amortized O(1);
  Webview variant 0→4→2× via BytesGrowCapacityWithMin reuse same loop.
  No Move/FillChar — pure arithmetic, not inline per red-line 2 (loop). }

interface

uses
  nextpas.core.base,
  nextpas.core.bytes.base;

function BytesGrowCapacityWithMin(const ACurrent, ARequired, AMinGrow: SizeUInt): SizeUInt;
function BytesGrowCapacity(const ACurrent, ARequired: SizeUInt): SizeUInt;
function BytesGrowCapacityIntWithMin(const ACurrent, ARequired, AMinGrow: Integer): Integer;
function BytesGrowCapacityInt(const ACurrent, ARequired: Integer): Integer;
function BytesNextCapacity(AOld, ANeed: SizeUInt): SizeUInt; inline;
function WebviewGrowCapacityForReuse(const ACurrent: Integer): Integer; inline;

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

end.
