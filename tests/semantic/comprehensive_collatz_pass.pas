{ objfpc}{+}
program comprehensive_collatz_pass;
function Collatz(N: Integer): Integer;
var Steps: Integer;
begin
  Steps:=0;
  while N<>1 do begin
    if N mod 2=0 then N:=N div 2 else N:=3*N+1;
    Inc(Steps);
    if Steps>1000 then Exit(-1);
  end;
  Collatz:=Steps;
end;
begin
  if Collatz(1)<>0 then Halt(1);
  if Collatz(6)<>8 then Halt(2);
  if Collatz(27)<>111 then Halt(3);
end.
