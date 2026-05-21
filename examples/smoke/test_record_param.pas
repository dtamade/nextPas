program Test_record_param;
type
  TPoint = record
    X: Integer;
    Y: Integer;
  end;

function SumPoint(P: TPoint): Integer;
begin
  Result := P.X + P.Y;
end;

var
  P: TPoint;
begin
  P.X := 15;
  P.Y := 25;
  Halt(SumPoint(P));
end.
