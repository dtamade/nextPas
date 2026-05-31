program llvm_complex_expr;
function F(A, B, C, D: Integer): Integer;
begin
  Result := (A + B) * (C - D) + A mod B;
end;
begin
  Halt(F(5, 3, 9, 4));
end.
