unit Math;

{$mode objfpc}{$H+}

interface

function Max(A, B: Integer): Integer; inline; overload;
function Max(A, B: Int64): Int64; inline; overload;
function Max(A, B: Double): Double; inline; overload;
function Min(A, B: Integer): Integer; inline; overload;
function Min(A, B: Int64): Int64; inline; overload;
function Min(A, B: Double): Double; inline; overload;
function Abs(A: Integer): Integer; inline; overload;
function Abs(A: Int64): Int64; inline; overload;
function Abs(A: Double): Double; inline; overload;
function Ln(X: Double): Double;
function Log2(X: Double): Double;
function Power(Base, Exponent: Double): Double;
function Floor(X: Double): Int64;
function Ceil(X: Double): Int64;
function Round(X: Double): Int64;
function Sqrt(X: Double): Double;
function Sin(X: Double): Double;
function Cos(X: Double): Double;
function ArcTan2(Y, X: Double): Double;
function Exp(X: Double): Double;

implementation

function Max(A, B: Integer): Integer; begin if A > B then Result := A else Result := B; end;
function Max(A, B: Int64): Int64; begin if A > B then Result := A else Result := B; end;
function Max(A, B: Double): Double; begin if A > B then Result := A else Result := B; end;
function Min(A, B: Integer): Integer; begin if A < B then Result := A else Result := B; end;
function Min(A, B: Int64): Int64; begin if A < B then Result := A else Result := B; end;
function Min(A, B: Double): Double; begin if A < B then Result := A else Result := B; end;
function Abs(A: Integer): Integer; begin if A < 0 then Result := -A else Result := A; end;
function Abs(A: Int64): Int64; begin if A < 0 then Result := -A else Result := A; end;
function Abs(A: Double): Double; begin if A < 0 then Result := -A else Result := A; end;
function Ln(X: Double): Double; begin Result := System.Ln(X); end;
function Log2(X: Double): Double; begin Result := System.Ln(X) / System.Ln(2); end;
function Power(Base, Exponent: Double): Double; begin Result := System.Exp(Exponent * System.Ln(Base)); end;
function Floor(X: Double): Int64; begin Result := Trunc(X); if Frac(X) < 0 then Dec(Result); end;
function Ceil(X: Double): Int64; begin Result := Trunc(X); if Frac(X) > 0 then Inc(Result); end;
function Round(X: Double): Int64; begin Result := System.Round(X); end;
function Sqrt(X: Double): Double; begin Result := System.Sqrt(X); end;
function Sin(X: Double): Double; begin Result := System.Sin(X); end;
function Cos(X: Double): Double; begin Result := System.Cos(X); end;
function ArcTan2(Y, X: Double): Double; begin Result := System.ArcTan(Y / X); end;
function Exp(X: Double): Double; begin Result := System.Exp(X); end;

end.
