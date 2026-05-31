program llvm_maxint;
var A, B: Integer;
begin
  A := 2147483647;
  B := A + 1;
  if B < A then
    Halt(42)
  else
    Halt(42);
end.
