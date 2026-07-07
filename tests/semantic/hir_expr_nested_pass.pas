program hir_expr_nested_pass;

function Square(X: Integer): Integer;
begin
  Square := X * X;
end;

function Cube(X: Integer): Integer;
begin
  Cube := X * X * X;
end;

var
  A, B, C: Integer;
begin
  A := 3;
  B := Square(A);
  C := Cube(Square(A) + B);
  A := A + B * C - Square(C);
end.
