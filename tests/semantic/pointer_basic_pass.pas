program pointer_basic_pass;

type
  PInt = ^Integer;

var
  P: PInt;
  X: Integer;
begin
  X := 42;
  P := @X;
  P^ := 100;
end.
