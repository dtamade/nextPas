program llvm_bool_assign;
var
  X, R: Integer;
  B: Integer;
begin
  X := 7;
  if X mod 2 = 1 then
    B := 21
  else
    B := 0;
  R := B;
  X := 10;
  if X mod 2 = 0 then
    B := 21
  else
    B := 0;
  R := R + B;
  Halt(R);
end.
