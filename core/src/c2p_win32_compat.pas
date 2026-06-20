unit c2p_win32_compat;
{ Pure Pascal implementations of C99/POSIX functions missing from msvcrt.
  Only compiled on Windows via {$IFDEF WINDOWS}. }

{$mode objfpc}{$H+}
{$IFDEF WINDOWS}

interface

function c2p_log2(x: Double): Double;
function c2p_round(x: Double): Double;
function c2p_roundf(x: Single): Single;
function c2p_trunc(x: Double): Double;
function c2p_truncf(x: Single): Single;

implementation

uses nextpas.core.math;

function c2p_log2(x: Double): Double;
begin
  Result := Log2(x);
end;

function c2p_round(x: Double): Double;
begin
  Result := System.Round(x);
end;

function c2p_roundf(x: Single): Single;
begin
  Result := Single(System.Round(x));
end;

function c2p_trunc(x: Double): Double;
begin
  Result := System.Trunc(x);
end;

function c2p_truncf(x: Single): Single;
begin
  Result := Single(System.Trunc(x));
end;

{$ENDIF}
end.
