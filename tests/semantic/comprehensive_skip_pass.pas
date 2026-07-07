{ objfpc}{+}
program comprehensive_skip_pass;
var I,Sum: Integer;
begin
  Sum:=0;
  for I:=1 to 10 do begin
    if I mod 2=0 then Continue;
    Sum:=Sum+I;
  end;
  if Sum<>25 then Halt(1);
end.
