program VarParamLiteral;
procedure Inc2(var X: Integer);
begin
  X := X + 1;
end;
begin
  Inc2(42);
end.
