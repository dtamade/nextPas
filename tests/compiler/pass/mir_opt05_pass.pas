{ objfpc}{+}
program mir_opt05_pass;
var I,J,R:Integer;
begin
  R:=0;
  for I:=1 to 10 do for J:=1 to 10 do R:=R+I*J;
  if R<>3025 then Halt(1);
  I:=50;
  if I<>50 then Halt(2);
end.
