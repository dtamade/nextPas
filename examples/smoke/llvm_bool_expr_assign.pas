program llvm_bool_expr_assign;
var
  X, R: Integer;
begin
  X := 7;
  if (X mod 2) = 1 then
    R := 1
  else
    R := 0;
  X := 10;
  if (X mod 2) = 0 then
    R := R + 1;
  X := 15;
  if (X mod 3) = 0 then
    R := R + 1;
  Halt(R);
end.
