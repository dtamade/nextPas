{ objfpc}{+}
program comprehensive_sign_pass;
function Sign(X: Integer): Integer;
begin
  if X>0 then Sign:=1 else if X<0 then Sign:=-1 else Sign:=0;
end;
begin
  if Sign(10)<>1 then Halt(1);
  if Sign(-5)<>-1 then Halt(2);
  if Sign(0)<>0 then Halt(3);
end.
