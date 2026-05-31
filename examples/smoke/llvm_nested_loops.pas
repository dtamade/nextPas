program llvm_nested_loops;
var I, J, S: Integer;
begin
  S := 27;
  for I := 1 to 5 do
    for J := 1 to I do
      S := S + 1;
  Halt(S);
end.
