program Llvm_record;
type
  TPoint = record
    X: Integer;
    Y: Integer;
  end;
var
  P: TPoint;
begin
  P.X := 3;
  P.Y := 4;
  WriteLn(P.X + P.Y);
  Halt(P.X + P.Y);
end.
