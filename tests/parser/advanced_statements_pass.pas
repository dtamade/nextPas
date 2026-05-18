program Advanced_statements_pass;

{$mode objfpc}{$H+}

type
  TPoint = record
    X: Integer;
    Y: Integer;
  end;

  TRect = record
    TopLeft: TPoint;
    BottomRight: TPoint;
  end;

function MakePoint(AX, AY: Integer): TPoint;
begin
  Result.X := AX;
  Result.Y := AY;
end;

function Clamp(AValue, AMin, AMax: Integer): Integer;
begin
  if AValue < AMin then
    Exit(AMin);
  if AValue > AMax then
    Exit(AMax);
  Result := AValue;
end;

function RectWidth(const R: TRect): Integer;
begin
  with R do
    Result := BottomRight.X - TopLeft.X;
end;

var
  P: TPoint;
  R: TRect;
  I: Integer;
  Arr: array of Integer;
begin
  P := MakePoint(10, 20);
  I := Clamp(P.X, 0, 100);

  R.TopLeft := MakePoint(0, 0);
  R.BottomRight := MakePoint(100, 200);
  I := RectWidth(R);

  SetLength(Arr, 5);
  Arr[0] := 1;
  Arr[1] := 2;
end.
