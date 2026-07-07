program record_field_access_pass;

type
  TPoint = record
    X, Y: Integer;
  end;
  TRect = record
    TopLeft, BottomRight: TPoint;
  end;

var
  P: TPoint;
  R: TRect;
  Sum: Integer;
begin
  P.X := 10;
  P.Y := 20;
  R.TopLeft := P;
  R.BottomRight.X := 30;
  R.BottomRight.Y := 40;
  Sum := P.X + P.Y + R.TopLeft.X + R.BottomRight.Y;
end.
