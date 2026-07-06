{ objfpc}{+}
program comprehensive_power_pass;
function Power(Base,Exp: Integer): Integer;
var R: Integer;
begin
  R:=1;
  while Exp>0 do begin
    if Exp mod 2=1 then R:=R*Base;
    Base:=Base*Base;
    Exp:=Exp div 2;
  end;
  Power:=R;
end;
begin
  if Power(2,0)<>1 then Halt(1);
  if Power(2,10)<>1024 then Halt(2);
  if Power(3,4)<>81 then Halt(3);
  if Power(5,3)<>125 then Halt(4);
end.
