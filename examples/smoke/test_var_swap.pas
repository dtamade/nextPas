program Test_var_swap;
procedure Swap(var A, B: Integer);
var
  Tmp: Integer;
begin
  Tmp := A;
  A := B;
  B := Tmp;
end;
var
  X, Y: Integer;
begin
  X := 3;
  Y := 7;
  Swap(X, Y);
  Halt(X * 10 + Y);
end.
