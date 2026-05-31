program llvm_generic_array_param;

generic function Sum<T>(Arr: array of T; Count: Integer): T;
var I: Integer;
    S: T;
begin
  S := 0;
  for I := 0 to Count - 1 do
    S := S + Arr[I];
  Result := S;
end;

var
  A: array of Integer;
begin
  SetLength(A, 4);
  A[0] := 10;
  A[1] := 11;
  A[2] := 12;
  A[3] := 9;
  Halt(specialize Sum<Integer>(A, 4));
end.
