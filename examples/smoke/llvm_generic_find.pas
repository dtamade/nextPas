program llvm_generic_find;

generic function Find<T>(Arr: array of T; Count: Integer; Target: T): Integer;
var I: Integer;
begin
  Result := 0 - 1;
  for I := 0 to Count - 1 do
    if Arr[I] = Target then
    begin
      Result := I;
      Break;
    end;
end;

var
  A: array of Integer;
begin
  SetLength(A, 5);
  A[0] := 10;
  A[1] := 20;
  A[2] := 30;
  A[3] := 40;
  A[4] := 50;
  Halt(specialize Find<Integer>(A, 5, 30) + 100);
end.
