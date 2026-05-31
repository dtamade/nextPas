program llvm_maxint;
var A, B: Integer;
begin
  A := 2147483647;
  B := A + 1;
  if B < A then
    Halt(1)
  else
    Halt(0);
end.
