program llvm_pointer_swap;

procedure SwapByPtr(A, B: ^Integer);
var Tmp: Integer;
begin
  Tmp := A^;
  A^ := B^;
  B^ := Tmp;
end;

var X, Y: Integer;
begin
  X := 10;
  Y := 42;
  SwapByPtr(@X, @Y);
  Halt(X);
end.
