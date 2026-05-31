program llvm_complex_expr;
function F(A, B, C, D: Integer): Integer;
begin
  Result := (A + B) * (C - D) + A mod B;
end;
begin
  Halt(F(7, 3, 10, 4));
end.
