{ objfpc}{+}
program mir_opt15_pass;
var I,J,R:Integer;
begin
  R:=0;
  for I:=1 to 10 do for J:=1 to 10 do R:=R+I*J;
  if R<>3025 then Halt(1);
  I:=150;
  if I<>150 then Halt(2);
end.
