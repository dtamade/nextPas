program llvm_bool_direct;
var
  X, R, B: Integer;
begin
  X := 10;
  B := Ord((X mod 2) = 0);
  R := B * 21;
  X := 8;
  B := Ord((X mod 2) = 0);
  R := R + B * 21;
  Halt(R);
end.
