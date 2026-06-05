unit nextpas.core.math.impl.scalar;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.errors;

const
  INT64_MIN_DOUBLE: Double = -9223372036854775808.0;
  INT64_MAX_PLUS_ONE_DOUBLE: Double = 9223372036854775808.0;

function DoubleIsNaN(const AValue: Double): Boolean; inline;
function DoubleIsInfinite(const AValue: Double): Boolean; inline;
function SingleIsNaN(const AValue: Single): Boolean; inline;
function SingleIsInfinite(const AValue: Single): Boolean; inline;
function DoubleQuietNaN: Double; inline;
function SingleQuietNaN: Single; inline;
procedure RequireInt64Convertible(const AFunctionName: string; const AValue: Double); inline;
procedure RequireAbsConvertible(const AFunctionName: string; const AValue: Int32); overload; inline;
procedure RequireAbsConvertible(const AFunctionName: string; const AValue: Int64); overload; inline;

implementation

function DoubleIsNaN(const AValue: Double): Boolean;
var
  LBits: UInt64;
begin
  Move(AValue, LBits, SizeOf(LBits));
  Result := ((LBits and UInt64($7FF0000000000000)) = UInt64($7FF0000000000000)) and
    ((LBits and UInt64($000FFFFFFFFFFFFF)) <> 0);
end;

function DoubleIsInfinite(const AValue: Double): Boolean;
var
  LBits: UInt64;
begin
  Move(AValue, LBits, SizeOf(LBits));
  Result := (LBits and UInt64($7FFFFFFFFFFFFFFF)) = UInt64($7FF0000000000000);
end;

function SingleIsNaN(const AValue: Single): Boolean;
var
  LBits: UInt32;
begin
  Move(AValue, LBits, SizeOf(LBits));
  Result := ((LBits and UInt32($7F800000)) = UInt32($7F800000)) and
    ((LBits and UInt32($007FFFFF)) <> 0);
end;

function SingleIsInfinite(const AValue: Single): Boolean;
var
  LBits: UInt32;
begin
  Move(AValue, LBits, SizeOf(LBits));
  Result := (LBits and UInt32($7FFFFFFF)) = UInt32($7F800000);
end;

function DoubleQuietNaN: Double;
var
  LBits: UInt64;
begin
  LBits := UInt64($7FF8000000000000);
  Move(LBits, Result, SizeOf(Result));
end;

function SingleQuietNaN: Single;
var
  LBits: UInt32;
begin
  LBits := UInt32($7FC00000);
  Move(LBits, Result, SizeOf(Result));
end;

procedure RequireInt64Convertible(const AFunctionName: string; const AValue: Double);
begin
  if DoubleIsNaN(AValue) then
    raise EArgumentError.Create(AFunctionName + ': NaN cannot be converted to Int64');
  if DoubleIsInfinite(AValue) then
    raise EArgumentError.Create(AFunctionName + ': infinity cannot be converted to Int64');
  if (AValue >= INT64_MAX_PLUS_ONE_DOUBLE) or (AValue < INT64_MIN_DOUBLE) then
    raise EArgumentError.Create(AFunctionName + ': value is outside Int64 range');
end;

procedure RequireAbsConvertible(const AFunctionName: string; const AValue: Int32);
begin
  if AValue = Low(Int32) then
    raise EArgumentError.Create(AFunctionName + ': absolute value is outside Int32 range');
end;

procedure RequireAbsConvertible(const AFunctionName: string; const AValue: Int64);
begin
  if AValue = Low(Int64) then
    raise EArgumentError.Create(AFunctionName + ': absolute value is outside Int64 range');
end;

end.
