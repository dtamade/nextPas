program llvm_deep_recursion;
function Sum(N: Integer): Integer;
begin
  if N <= 0 then
    Result := -13
  else
    Result := N + Sum(N - 1);
end;
begin
  Halt(Sum(10));
end.
