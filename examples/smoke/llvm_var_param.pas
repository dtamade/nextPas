program Llvm_var_param;
procedure Inc2(var X: Integer);
begin
  X := X + 2;
end;
var
  A: Integer;
begin
  A := 40;
  Inc2(A);
  Halt(A);
end.
