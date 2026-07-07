{ objfpc}{+}
program type_check_static_array_pass;
var Arr: array[1..3] of Integer; I: Integer;
begin
  Arr[1]:=10; Arr[2]:=20; Arr[3]:=30;
  if Arr[1]<>10 then Halt(1);
  if Arr[3]<>30 then Halt(2);
  I:=Arr[1]+Arr[2]+Arr[3];
  if I<>60 then Halt(3);
end.
