{$mode objfpc}{$H+}
program hir_lowering_nested_pass;

{ HIR lowering：嵌套表达式 }

function Square(X: Integer): Integer;
begin
  Square := X * X;
end;

var
  A, B, C, R: Integer;
begin
  A := 2;
  B := 3;
  C := 4;
  R := Square(A) + Square(B) + Square(C);
  if R <> 29 then Halt(1);  { 4 + 9 + 16 = 29 }

  R := Square(A + B);
  if R <> 25 then Halt(2);  { (2+3)^2 = 25 }

  R := Square(Square(2));
  if R <> 16 then Halt(3);  { (2^2)^2 = 16 }
end.
