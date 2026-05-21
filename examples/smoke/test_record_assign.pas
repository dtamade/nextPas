program Test_record_assign;
type
  TPoint = record
    X: Integer;
    Y: Integer;
  end;
var
  P1, P2: TPoint;
begin
  P1.X := 10;
  P1.Y := 20;
  P2 := P1;
  Halt(P2.X + P2.Y);
end.
