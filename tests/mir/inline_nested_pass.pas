program inline_nested_pass;

{ 内联：嵌套调用和递归 }

function Square(X: Integer): Integer;
begin
  Square := X * X;         { 应被内联 }
end;

function SumSquares(A, B: Integer): Integer;
begin
  SumSquares := Square(A) + Square(B);  { Square 内联，SumSquares 也可内联 }
end;

function TestNestedInline: Integer;
begin
  TestNestedInline := SumSquares(3, 4);  { 9 + 16 = 25 }
end;

function Inc2(X: Integer): Integer;
begin
  Inc2 := X + 1;
end;

function Inc4(X: Integer): Integer;
begin
  Inc4 := Inc2(Inc2(Inc2(Inc2(X))));  { 链式内联 }
end;

begin
  if TestNestedInline <> 25 then Halt(1);
  if Inc4(0) <> 4 then Halt(2);
  if Inc4(10) <> 14 then Halt(3);
end.
