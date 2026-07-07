{$mode objfpc}{$H+}
program type_check_dynarray_pass;

{ 类型检查：动态数组 }

var
  Arr: array of Integer;
  I, Sum: Integer;
begin
  SetLength(Arr, 5);
  for I := 0 to 4 do
    Arr[I] := (I + 1) * 10;

  Sum := 0;
  for I := 0 to 4 do
    Sum := Sum + Arr[I];

  if Sum <> 150 then Halt(1);
  if Length(Arr) <> 5 then Halt(2);
  if Arr[0] <> 10 then Halt(3);
  if Arr[4] <> 50 then Halt(4);
end.
