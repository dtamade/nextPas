program Llvm_fibonacci;
var
  A, B, Temp, I, N: Integer;
begin
  N := 10;
  A := 0;
  B := 1;
  for I := 2 to N do
  begin
    Temp := A + B;
    A := B;
    B := Temp;
  end;
  WriteLn(B);
  Halt(B mod 100);
end.
