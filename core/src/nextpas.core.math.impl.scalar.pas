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
function ExtendedIsNaN(const AValue: Extended): Boolean; inline;
function ExtendedIsInfinite(const AValue: Extended): Boolean; inline;
function DoubleQuietNaN: Double; inline;
function SingleQuietNaN: Single; inline;
function ExtendedQuietNaN: Extended; inline;
procedure RequireInt64Convertible(const AFunctionName: string; const AValue: Double); inline;
procedure RequireAbsConvertible(const AFunctionName: string; const AValue: Int32); overload; inline;
procedure RequireAbsConvertible(const AFunctionName: string; const AValue: Int64); overload; inline;

implementation

{$IF (SizeOf(Extended) > SizeOf(Double)) AND (DEFINED(CPUX86_64) OR DEFINED(CPUX86) OR DEFINED(CPUI386))}
  {$DEFINE NEXTPAS_MATH_EXTENDED_X87_80}
{$ELSEIF SizeOf(Extended) = SizeOf(Double)}
  {$DEFINE NEXTPAS_MATH_EXTENDED_DOUBLE_COMPAT}
{$ELSE}
  {$FATAL Unsupported Extended floating-point layout}
{$ENDIF}

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

function ExtendedIsNaN(const AValue: Extended): Boolean;
{$IFDEF NEXTPAS_MATH_EXTENDED_X87_80}
type
  TExtended10Bytes = packed array[0..9] of Byte;
{$ENDIF}
var
  {$IFDEF NEXTPAS_MATH_EXTENDED_X87_80}
  LBytes: TExtended10Bytes;
  LExp: UInt16;
  LFraction: UInt64;
  {$ELSE}
  LBits: UInt64;
  {$ENDIF}
begin
  {$IFDEF NEXTPAS_MATH_EXTENDED_X87_80}
  Move(AValue, LBytes, SizeOf(LBytes));
  LExp := (UInt16(LBytes[9]) and UInt16($7F)) shl 8;
  LExp := LExp or UInt16(LBytes[8]);
  LFraction := 0;
  Move(LBytes[0], LFraction, SizeOf(LFraction));
  Result := (LExp = UInt16($7FFF)) and
    ((LFraction and UInt64($7FFFFFFFFFFFFFFF)) <> 0);
  {$ELSE}
  Move(AValue, LBits, SizeOf(LBits));
  Result := ((LBits and UInt64($7FF0000000000000)) = UInt64($7FF0000000000000)) and
    ((LBits and UInt64($000FFFFFFFFFFFFF)) <> 0);
  {$ENDIF}
end;

function ExtendedIsInfinite(const AValue: Extended): Boolean;
{$IFDEF NEXTPAS_MATH_EXTENDED_X87_80}
type
  TExtended10Bytes = packed array[0..9] of Byte;
{$ENDIF}
var
  {$IFDEF NEXTPAS_MATH_EXTENDED_X87_80}
  LBytes: TExtended10Bytes;
  LExp: UInt16;
  LMantissa: UInt64;
  {$ELSE}
  LBits: UInt64;
  {$ENDIF}
begin
  {$IFDEF NEXTPAS_MATH_EXTENDED_X87_80}
  Move(AValue, LBytes, SizeOf(LBytes));
  LExp := (UInt16(LBytes[9]) and UInt16($7F)) shl 8;
  LExp := LExp or UInt16(LBytes[8]);
  LMantissa := 0;
  Move(LBytes[0], LMantissa, SizeOf(LMantissa));
  Result := (LExp = UInt16($7FFF)) and (LMantissa = UInt64($8000000000000000));
  {$ELSE}
  Move(AValue, LBits, SizeOf(LBits));
  Result := (LBits and UInt64($7FFFFFFFFFFFFFFF)) = UInt64($7FF0000000000000);
  {$ENDIF}
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

function ExtendedQuietNaN: Extended;
{$IFDEF NEXTPAS_MATH_EXTENDED_X87_80}
type
  TExtendedBytes = packed array[0..SizeOf(Extended) - 1] of Byte;
{$ENDIF}
var
  {$IFDEF NEXTPAS_MATH_EXTENDED_X87_80}
  LBytes: TExtendedBytes;
  {$ELSE}
  LBits: UInt64;
  {$ENDIF}
begin
  {$IFDEF NEXTPAS_MATH_EXTENDED_X87_80}
  FillChar(LBytes, SizeOf(LBytes), 0);
  LBytes[7] := Byte($C0);
  LBytes[8] := Byte($FF);
  LBytes[9] := Byte($7F);
  Move(LBytes, Result, SizeOf(Result));
  {$ELSE}
  LBits := UInt64($7FF8000000000000);
  Move(LBits, Result, SizeOf(Result));
  {$ENDIF}
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
