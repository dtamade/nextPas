program Label_section_pass;
label 100, 200;
var
  X: Integer;
begin
  X := 1;
  goto 100;
  X := 2;
100:
  X := 3;
end.
