unit nextpas.core.math;

{$I nextpas.core.settings.inc}

interface

uses
  Math,
  nextpas.core.base;

function IsAddOverflow(aA, aB: SizeUInt): Boolean; overload; inline;
function IsAddOverflow(aA, aB: UInt32): Boolean; overload; inline;
function IsMulOverflow(aA, aB: SizeUInt): Boolean; overload; inline;
function IsMulOverflow(aA, aB: UInt32): Boolean; overload; inline;

function Min(aA, aB: SizeUInt): SizeUInt; overload; inline;
function Max(aA, aB: SizeUInt): SizeUInt; overload; inline;
function Min(aA, aB: SizeInt): SizeInt; overload; inline;
function Max(aA, aB: SizeInt): SizeInt; overload; inline;
function Min(aA, aB: Double): Double; overload; inline;
function Max(aA, aB: Double): Double; overload; inline;
function Ceil(x: Double): Int64; overload; inline;
function IsNaN(x: Double): Boolean; overload; inline;
function IsInfinite(x: Double): Boolean; overload; inline;

implementation

function IsAddOverflow(aA, aB: SizeUInt): Boolean;
begin
  Result := aA > High(SizeUInt) - aB;
end;

function IsAddOverflow(aA, aB: UInt32): Boolean;
begin
  Result := aA > High(UInt32) - aB;
end;

function IsMulOverflow(aA, aB: SizeUInt): Boolean;
begin
  Result := (aA <> 0) and (aB > High(SizeUInt) div aA);
end;

function IsMulOverflow(aA, aB: UInt32): Boolean;
begin
  Result := (aA <> 0) and (aB > High(UInt32) div aA);
end;

function Min(aA, aB: SizeUInt): SizeUInt;
begin
  if aA < aB then
    Result := aA
  else
    Result := aB;
end;

function Max(aA, aB: SizeUInt): SizeUInt;
begin
  if aA > aB then
    Result := aA
  else
    Result := aB;
end;

function Min(aA, aB: SizeInt): SizeInt;
begin
  if aA < aB then
    Result := aA
  else
    Result := aB;
end;

function Max(aA, aB: SizeInt): SizeInt;
begin
  if aA > aB then
    Result := aA
  else
    Result := aB;
end;

function Min(aA, aB: Double): Double;
begin
  if aA < aB then
    Result := aA
  else
    Result := aB;
end;

function Max(aA, aB: Double): Double;
begin
  if aA > aB then
    Result := aA
  else
    Result := aB;
end;

function Ceil(x: Double): Int64;
begin
  Result := Int64(Math.Ceil(x));
end;

function IsNaN(x: Double): Boolean;
begin
  Result := Math.IsNaN(x);
end;

function IsInfinite(x: Double): Boolean;
begin
  Result := Math.IsInfinite(x);
end;

end.
