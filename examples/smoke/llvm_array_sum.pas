program llvm_array_sum;
var
  Arr: array of Integer;
  I, S: Integer;
begin
  SetLength(Arr, 5);
  Arr[0] := 8;
  Arr[1] := 9;
  Arr[2] := 10;
  Arr[3] := 11;
  Arr[4] := 4;
  S := 0;
  for I := 0 to 4 do
    S := S + Arr[I];
  Halt(S);
end.
