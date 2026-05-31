program llvm_bubblesort;
var
  Arr: array of Integer;
  I, J, Tmp, N: Integer;
begin
  N := 5;
  SetLength(Arr, N);
  Arr[0] := 42;
  Arr[1] := 17;
  Arr[2] := 92;
  Arr[3] := 4;
  Arr[4] := 28;

  for I := 0 to N - 2 do
    for J := 0 to N - 2 - I do
      if Arr[J] > Arr[J + 1] then
      begin
        Tmp := Arr[J];
        Arr[J] := Arr[J + 1];
        Arr[J + 1] := Tmp;
      end;

  Halt(Arr[0] * 10 + Arr[4] mod 10);
end.
