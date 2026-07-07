{ objfpc}{+}
program comprehensive_gcd_pass;
function GCD(A,B: Integer): Integer;
begin
  while B<>0 do begin
    if A>B then A:=A-B else B:=B-A;
  end;
  GCD:=A;
end;
begin
  if GCD(48,18)<>6 then Halt(1);
  if GCD(7,13)<>1 then Halt(2);
  if GCD(100,10)<>10 then Halt(3);
end.
