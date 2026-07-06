{ objfpc}{+}
program comprehensive_countdown_pass;
var I: Integer;
begin
  I:=10;
  while I>0 do begin
    if I=5 then Break;
    Dec(I);
  end;
  if I<>5 then Halt(1);
end.
