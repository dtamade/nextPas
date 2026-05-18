program For_in_pass;
var
  Arr: array[1..5] of Integer;
  I: Integer;
  Total: Integer;
begin
  Arr[1] := 10;
  Arr[2] := 20;
  Arr[3] := 30;
  Arr[4] := 40;
  Arr[5] := 50;
  Total := 0;
  for I in Arr do
    Total := Total + I;
end.
