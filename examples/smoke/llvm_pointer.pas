program test_pointer;
var
  X: Integer;
  P: ^Integer;
begin
  X := 42;
  P := @X;
  Halt(P^);
end.
