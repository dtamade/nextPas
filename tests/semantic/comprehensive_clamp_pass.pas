{ objfpc}{+}
program comprehensive_clamp_pass;
function Clamp(V,Lo,Hi: Integer): Integer;
begin
  if V<Lo then Clamp:=Lo else if V>Hi then Clamp:=Hi else Clamp:=V;
end;
begin
  if Clamp(5,0,10)<>5 then Halt(1);
  if Clamp(-5,0,10)<>0 then Halt(2);
  if Clamp(15,0,10)<>10 then Halt(3);
end.
