program Callable_scope_pass;
function Add(X, Y: Integer): Integer;
begin
  Add := X + Y;
end;
function Mul(X, Y: Integer): Integer;
begin
  Mul := X * Y;
end;
function Negate(X: Integer): Integer;
begin
  Negate := 0 - X;
end;
var
  A, B, C: Integer;
begin
  A := Add(3, 4);
  B := Mul(5, 6);
  C := Negate(A);
end.
