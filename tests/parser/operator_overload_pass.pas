program Operator_overload_pass;

{$mode objfpc}{$H+}

type
  TVector = record
    X: Integer;
    Y: Integer;
  end;

operator + (A, B: TVector): TVector;
begin
  Result.X := A.X + B.X;
  Result.Y := A.Y + B.Y;
end;

operator - (A, B: TVector): TVector;
begin
  Result.X := A.X - B.X;
  Result.Y := A.Y - B.Y;
end;

operator = (A, B: TVector): Boolean;
begin
  Result := (A.X = B.X) and (A.Y = B.Y);
end;

var
  V1, V2, V3: TVector;
begin
  V1.X := 1;
  V1.Y := 2;
  V2.X := 3;
  V2.Y := 4;
  V3 := V1 + V2;
end.
