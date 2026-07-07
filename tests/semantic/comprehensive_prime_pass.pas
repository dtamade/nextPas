{ objfpc}{+}
program comprehensive_prime_pass;
function IsPrime(N: Integer): Boolean;
var I: Integer;
begin
  if N<2 then IsPrime:=False
  else begin
    IsPrime:=True;
    for I:=2 to N div 2 do
      if N mod I=0 then begin IsPrime:=False; Break; end;
  end;
end;
begin
  if IsPrime(2)<>True then Halt(1);
  if IsPrime(4)<>False then Halt(2);
  if IsPrime(17)<>True then Halt(3);
  if IsPrime(100)<>False then Halt(4);
end.
