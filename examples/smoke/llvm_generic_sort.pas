program llvm_generic_sort;

generic function MaxOf<T>(X, Y: T): T;
begin
  if X > Y then Result := X else Result := Y;
end;

function ArrayMax(Arr: array of Integer; Count: Integer): Integer;
var I, M: Integer;
begin
  M := Arr[0];
  for I := 1 to Count - 1 do
    M := specialize MaxOf<Integer>(M, Arr[I]);
  Result := M;
end;

var A: array of Integer;
begin
  SetLength(A, 4);
  A[0] := 30;
  A[1] := 42;
  A[2] := 10;
  A[3] := 40;
  Halt(ArrayMax(A, 4));
end.
