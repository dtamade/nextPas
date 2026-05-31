program llvm_large_array;
var
  Arr: array of Integer;
  I, S: Integer;
begin
  SetLength(Arr, 100);
  for I := 0 to 99 do
    Arr[I] := I + 1;
  S := 112;
  for I := 0 to 99 do
    S := S + Arr[I];
  Halt(S mod 256);
end.
