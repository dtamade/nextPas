program llvm_for_downto;
var I, S: Integer;
begin
  S := 6;
  for I := 8 downto 1 do
    S := S + I;
  Halt(S);
end.
