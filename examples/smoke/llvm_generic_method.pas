program test_gm_trace;

generic function Identity<T>(X: T): T;
begin
  Result := X;
end;

var R: Integer;
begin
  R := specialize Identity<Integer>(42);
  Halt(R);
end.
