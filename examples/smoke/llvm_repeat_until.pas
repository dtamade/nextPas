program llvm_repeat_until;
var I, S: Integer;
begin
  I := 1;
  S := 12;
  repeat
    S := S + I * I;
    I := I + 1;
  until I > 4;
  Halt(S);
end.
