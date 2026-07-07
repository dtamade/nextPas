{ objfpc}{+}
program comprehensive_triangle_pass;
function Triangle(N: Integer): Integer;
begin Triangle:=N*(N+1) div 2; end;
begin
  if Triangle(0)<>0 then Halt(1);
  if Triangle(1)<>1 then Halt(2);
  if Triangle(10)<>55 then Halt(3);
  if Triangle(100)<>5050 then Halt(4);
end.
