program Nested_expressions_pass;
type
  TPoint = record
    X: Integer;
    Y: Integer;
  end;
  TRect = record
    TopLeft: TPoint;
    BottomRight: TPoint;
  end;
var
  R: TRect;
  Arr: array[1..10] of TPoint;
  I, J: Integer;
  P: ^Integer;
begin
  R.TopLeft.X := 0;
  R.TopLeft.Y := 0;
  R.BottomRight.X := 100;
  R.BottomRight.Y := 200;

  Arr[1].X := 5;
  Arr[1].Y := 10;
  Arr[2 + 1].X := 15;

  I := R.TopLeft.X + R.BottomRight.X;
  J := Arr[1].X * 2;

  I := (I + J) * (I - J);
  I := -I;
  I := not 0;
end.
