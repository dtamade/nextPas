unit nextpas.core.math;

{$I nextpas.core.settings.inc}

interface

uses
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
  if aA < aB then Result := aA else Result := aB;
end;

function Max(aA, aB: SizeUInt): SizeUInt;
begin
  if aA > aB then Result := aA else Result := aB;
end;

function Min(aA, aB: SizeInt): SizeInt;
begin
  if aA < aB then Result := aA else Result := aB;
end;

function Max(aA, aB: SizeInt): SizeInt;
begin
  if aA > aB then Result := aA else Result := aB;
end;

function Min(aA, aB: Double): Double;
begin
  if aA < aB then Result := aA else Result := aB;
end;

function Max(aA, aB: Double): Double;
begin
  if aA > aB then Result := aA else Result := aB;
end;

function Ceil(x: Double): Int64;
var LI: Int64;
begin
  LI := System.Trunc(x);
  if (x > 0) and (x <> LI) then Inc(LI);
  Result := LI;
end;

function IsNaN(x: Double): Boolean;
var LI: UInt64;
begin
  Move(x, LI, 8);
  Result := (LI and $7FF0000000000000 = $7FF0000000000000) and (LI and $000FFFFFFFFFFFFF <> 0);
end;

function IsInfinite(x: Double): Boolean;
var LI: UInt64;
begin
  Move(x, LI, 8);
  Result := (LI and $7FFFFFFFFFFFFFFF) = $7FF0000000000000;
end;

end.
