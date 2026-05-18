program Field_access_pass;
type
  TPoint = record
    X: Integer;
    Y: Integer;
  end;
  TRect = record
    TopLeft: TPoint;
    Width: Integer;
    Height: Integer;
  end;
function Area(const R: TRect): Integer;
begin
  Area := R.Width * R.Height;
end;
var
  P: TPoint;
  R: TRect;
  A: Integer;
begin
  P.X := 10;
  P.Y := 20;
  R.TopLeft := P;
  R.Width := 100;
  R.Height := 50;
  A := Area(R);
end.
