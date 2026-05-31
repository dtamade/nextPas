program Llvm_record;
type
  TPoint = record
    X: Integer;
    Y: Integer;
  end;
var
  P: TPoint;
begin
  P.X := 20;
  P.Y := 22;
  WriteLn(P.X + P.Y);
  Halt(P.X + P.Y);
end.
