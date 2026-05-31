program llvm_while_break;
var I, S: Integer;
begin
  I := 0;
  S := 0;
  while I < 100 do
  begin
    S := S + I;
    I := I + 1;
    if I = 8 then
      Break;
  end;
  Halt(S);
end.
