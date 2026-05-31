program llvm_for_downto;
var I, S: Integer;
begin
  S := 0;
  for I := 10 downto 1 do
    S := S + I;
  Halt(S);
end.
