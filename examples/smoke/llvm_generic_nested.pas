program test_nested_spec2;

generic function Add<T>(X, Y: T): T;
begin
  Result := X + Y;
end;

generic function Mul<T>(X, Y: T): T;
begin
  Result := X * Y;
end;

generic function MulAdd<T>(X, Y, Z: T): T;
begin
  Result := specialize Add<T>(specialize Mul<T>(X, Y), Z);
end;

begin
  Halt(specialize MulAdd<Integer>(3, 4, 5));
end.
