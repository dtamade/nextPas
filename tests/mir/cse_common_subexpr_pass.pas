program cse_common_subexpr_pass;

{ 验证公共子表达式消除：重复计算应被复用 }

function TestRepeatedAdd: Integer;
var
  A, B, X, Y: Integer;
begin
  A := 10;
  B := 20;
  X := A + B;      { A+B 第一次计算 }
  Y := A + B;      { A+B 应被 CSE 复用 }
  TestRepeatedAdd := X + Y;  { 结果应为 60 }
end;

function TestRepeatedMul: Integer;
var
  A, B, X, Y: Integer;
begin
  A := 3;
  B := 7;
  X := A * B;
  Y := A * B;
  TestRepeatedMul := X + Y;  { 结果应为 42 }
end;

function TestComplexExpr: Integer;
var
  A, B, C, R1, R2: Integer;
begin
  A := 2;
  B := 3;
  C := 4;
  R1 := (A + B) * C;
  R2 := (A + B) * C;  { 整个 (A+B)*C 应被 CSE 复用 }
  TestComplexExpr := R1 + R2;  { 结果应为 40 }
end;

begin
  if TestRepeatedAdd <> 60 then Halt(1);
  if TestRepeatedMul <> 42 then Halt(2);
  if TestComplexExpr <> 40 then Halt(3);
end.
