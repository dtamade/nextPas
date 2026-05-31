program llvm_generic_swap;

generic function Add2<T>(A, B: T): T;
begin
  Result := A + B;
end;

generic function Min2<T>(A, B: T): T;
begin
  if A < B then
    Result := A
  else
    Result := B;
end;

var X, Y: Integer;
begin
  X := specialize Add2<Integer>(10, 32);
  Y := specialize Min2<Integer>(X, 50);
  Halt(Y);
end.
