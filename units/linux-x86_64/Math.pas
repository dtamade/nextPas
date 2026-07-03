unit Math;

{$mode objfpc}{$H+}

interface

uses nextpas.core.math.scalar;

function Max(AA, AB: Double): Double; overload; inline;
function Min(AA, AB: Double): Double; overload; inline;
function Max(AA, AB: Single): Single; overload; inline;
function Min(AA, AB: Single): Single; overload; inline;
function Max(AA, AB: Integer): Integer; overload; inline;
function Min(AA, AB: Integer): Integer; overload; inline;
function Max(AA, AB: Int64): Int64; overload; inline;
function Min(AA, AB: Int64): Int64; overload; inline;

implementation

function Max(AA, AB: Double): Double;
begin
  Result := nextpas.core.math.scalar.Max(AA, AB);
end;

function Min(AA, AB: Double): Double;
begin
  Result := nextpas.core.math.scalar.Min(AA, AB);
end;

function Max(AA, AB: Single): Single;
begin
  Result := nextpas.core.math.scalar.Max(AA, AB);
end;

function Min(AA, AB: Single): Single;
begin
  Result := nextpas.core.math.scalar.Min(AA, AB);
end;

function Max(AA, AB: Integer): Integer;
begin
  Result := nextpas.core.math.scalar.Max(AA, AB);
end;

function Min(AA, AB: Integer): Integer;
begin
  Result := nextpas.core.math.scalar.Min(AA, AB);
end;

function Max(AA, AB: Int64): Int64;
begin
  Result := nextpas.core.math.scalar.Max(AA, AB);
end;

function Min(AA, AB: Int64): Int64;
begin
  Result := nextpas.core.math.scalar.Min(AA, AB);
end;

end.
