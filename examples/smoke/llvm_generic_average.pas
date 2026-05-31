program test_nested_arr;

generic function Sum<T>(Arr: array of T; Count: Integer): T;
var I: Integer; S: T;
begin
  S := 0;
  for I := 0 to Count - 1 do
    S := S + Arr[I];
  Result := S;
end;

generic function Average<T>(Arr: array of T; Count: Integer): T;
begin
  Result := specialize Sum<T>(Arr, Count) div Count;
end;

var A: array of Integer;
begin
  SetLength(A, 4);
  A[0] := 40;
  A[1] := 42;
  A[2] := 44;
  A[3] := 42;
  Halt(specialize Average<Integer>(A, 4));
end.
