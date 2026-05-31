program test_record_ret;
type
  TPoint = record
    X, Y: Integer;
  end;

function MakePoint(AX, AY: Integer): TPoint;
begin
  Result.X := AX;
  Result.Y := AY;
end;

var P: TPoint;
begin
  P := MakePoint(10, 32);
  Halt(P.X + P.Y);
end.
