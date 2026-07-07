{$mode objfpc}{$H+}
program hir_lowering_array_pass;

{ HIR lowering：数组访问 }

var
  Arr: array[1..5] of Integer;
  I, Sum: Integer;
begin
  for I := 1 to 5 do
    Arr[I] := I * 10;

  Sum := 0;
  for I := 1 to 5 do
    Sum := Sum + Arr[I];

  if Sum <> 150 then Halt(1);
  if Arr[1] <> 10 then Halt(2);
  if Arr[5] <> 50 then Halt(3);
end.
