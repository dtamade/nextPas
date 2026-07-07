{ objfpc}{+}
program comprehensive_summation_pass;
function SumTo(N: Integer): Integer;
begin
  if N<=0 then SumTo:=0
  else SumTo:=N+SumTo(N-1);
end;
begin
  if SumTo(0)<>0 then Halt(1);
  if SumTo(1)<>1 then Halt(2);
  if SumTo(10)<>55 then Halt(3);
  if SumTo(100)<>5050 then Halt(4);
end.
