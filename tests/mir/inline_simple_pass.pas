program inline_simple_pass;

{ 验证内联：小函数应被内联到调用点 }

function Add(A, B: Integer): Integer;
begin
  Add := A + B;           { 应被内联 }
end;

function Mul(A, B: Integer): Integer;
begin
  Mul := A * B;           { 应被内联 }
end;

function TestInlineChain: Integer;
var
  X, Y: Integer;
begin
  X := Add(3, 4);         { Add 应被内联 }
  Y := Mul(X, 2);         { Mul 应被内联 }
  TestInlineChain := Add(Y, 1);  { Add 再次被内联 }
  { 最终: (3+4)*2+1 = 15 }
end;

function TestInlineSmall: Integer;
begin
  TestInlineSmall := Add(10, 20);  { 30 }
end;

begin
  if TestInlineChain <> 15 then Halt(1);
  if TestInlineSmall <> 30 then Halt(2);
end.
