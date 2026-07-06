{ objfpc}{+}
program comprehensive_range_check_pass;
function InRange(Lo,Hi,X: Integer): Boolean;
begin InRange:=(X>=Lo) and (X<=Hi); end;
begin
  if not InRange(1,10,5) then Halt(1);
  if InRange(1,10,0) then Halt(2);
  if InRange(1,10,11) then Halt(3);
end.
