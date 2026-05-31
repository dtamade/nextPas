program llvm_array_sum;
var
  Arr: array of Integer;
  I, S: Integer;
begin
  SetLength(Arr, 5);
  Arr[0] := 10;
  Arr[1] := 20;
  Arr[2] := 30;
  Arr[3] := 40;
  Arr[4] := 50;
  S := 0;
  for I := 0 to 4 do
    S := S + Arr[I];
  Halt(S);
end.
