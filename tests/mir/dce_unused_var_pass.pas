program dce_unused_var_pass;

{ 验证死代码消除：未使用变量应被消除 }

function TestUnusedVar: Integer;
var
  X, Y, Z: Integer;
begin
  X := 1;
  Y := 2;      { Y 未使用，应被 DCE 消除 }
  Z := X + 3;
  TestUnusedVar := Z;  { 结果应为 4 }
end;

function TestDeadBranch: Integer;
var
  A: Integer;
begin
  A := 10;
  if False then     { 死分支，应被消除 }
    A := 999;
  TestDeadBranch := A;  { 结果应为 10 }
end;

function TestDeadAfterReturn: Integer;
begin
  TestDeadAfterReturn := 42;
  Exit;
  TestDeadAfterReturn := 0;  { 不可达代码，应被消除 }
end;

begin
  if TestUnusedVar <> 4 then Halt(1);
  if TestDeadBranch <> 10 then Halt(2);
  if TestDeadAfterReturn <> 42 then Halt(3);
end.
