{ objfpc}{+}
program comprehensive_bubblesort_pass;
var Arr: array[1..5] of Integer; I,J,T: Integer;
begin
  Arr[1]:=5; Arr[2]:=3; Arr[3]:=1; Arr[4]:=4; Arr[5]:=2;
  for I:=1 to 4 do
    for J:=1 to 5-I do
      if Arr[J]>Arr[J+1] then begin
        T:=Arr[J]; Arr[J]:=Arr[J+1]; Arr[J+1]:=T;
      end;
  if Arr[1]<>1 then Halt(1);
  if Arr[3]<>3 then Halt(2);
  if Arr[5]<>5 then Halt(3);
end.
