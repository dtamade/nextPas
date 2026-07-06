program array_basic_pass;

type
  TIntArray = array of Integer;

var
  Arr: TIntArray;
  I, Sum: Integer;
begin
  SetLength(Arr, 5);
  Arr[0] := 1;
  Arr[1] := 2;
  Arr[2] := 3;
  Arr[3] := 4;
  Arr[4] := 5;
  Sum := 0;
  for I := 0 to High(Arr) do
    Sum := Sum + Arr[I];
end.
