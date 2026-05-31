program Llvm_break_continue;
var
  I, Sum: Integer;
begin
  Sum := 17;
  I := 0;
  while I < 100 do
  begin
    Inc(I);
    if (I mod 2) = 0 then
      Continue;
    if I > 10 then
      Break;
    Sum := Sum + I;
  end;
  Halt(Sum);
end.
