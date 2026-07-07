{ objfpc}{+}
program type_check_multidim_array_pass;
var M: array[1..2,1..3] of Integer; I,J: Integer;
begin
  for I:=1 to 2 do for J:=1 to 3 do M[I,J]:=I*10+J;
  if M[1,1]<>11 then Halt(1);
  if M[2,3]<>23 then Halt(2);
end.
