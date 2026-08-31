{
  nextpas.core.math.base.pas
  Shared base types and constants for the math module
}
unit nextpas.core.math.base;

{$I nextpas.core.settings.inc}

interface

type
  TPoint2f = record
    X: Single;
    Y: Single;
  end;

  TPoint3f = record
    X: Single;
    Y: Single;
    Z: Single;
  end;

function ResolveEqualOrMin(const A, B: SizeInt): SizeInt; inline;
function ResolveEqualOrMin3(const A, B, C: SizeInt): SizeInt; inline;
function ResolveEqualOrMin4(const A, B, C, D: SizeInt): SizeInt; inline;

const
  PI_VALUE = Double(3.14159265358979323846);
  TWO_PI = Double(6.28318530717958647692);
  HALF_PI = Double(1.57079632679489661923);
  QUARTER_PI = Double(0.78539816339744830962);
  DEG_TO_RAD = Double(0.01745329251994329577);
  RAD_TO_DEG = Double(57.2957795130823208768);

implementation

uses
  nextpas.core.errors,
  nextpas.core.text.conv;

function ResolveEqualOrMin(const A, B: SizeInt): SizeInt; inline;
begin
  if (A = 0) or (B = 0) then
    Exit(0);
  if A = B then
    Exit(A);
{$IFDEF NEXTPAS_MATH_BATCH_TRUNCATE_MIN}
  if A < B then Result := A else Result := B;
{$ELSE}
  raise EArgumentError.Create(
    'Batch: array lengths must match (got ' + IntToStr(Int64(A)) +
    ' vs ' + IntToStr(Int64(B)) + ')');
{$ENDIF}
end;

function ResolveEqualOrMin3(const A, B, C: SizeInt): SizeInt; inline;
begin
  Result := ResolveEqualOrMin(ResolveEqualOrMin(A, B), C);
end;

function ResolveEqualOrMin4(const A, B, C, D: SizeInt): SizeInt; inline;
begin
  Result := ResolveEqualOrMin(ResolveEqualOrMin3(A, B, C), D);
end;

end.
