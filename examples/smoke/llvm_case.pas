program Llvm_case;
var
  X, R: Integer;
begin
  X := 3;
  case X of
    1: R := 10;
    2: R := 20;
    3: R := 30;
    4, 5: R := 45;
  else
    R := 99;
  end;
  Halt(R);
end.
