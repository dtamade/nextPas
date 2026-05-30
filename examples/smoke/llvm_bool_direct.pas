program llvm_bool_direct;
var
  X, R, B: Integer;
begin
  X := 10;
  B := Ord((X mod 2) = 0);
  R := B;
  X := 7;
  B := Ord((X mod 2) = 0);
  R := R + B;
  Halt(R);
end.
