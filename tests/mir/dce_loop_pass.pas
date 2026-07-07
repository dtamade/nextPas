program dce_loop_pass;

{ 死代码消除：循环中的死代码 }

function TestDeadInLoop: Integer;
var
  I, Sum, Dead: Integer;
begin
  Sum := 0;
  for I := 1 to 10 do
  begin
    Sum := Sum + I;
    Dead := I * 2;    { Dead 未被使用，应被消除 }
  end;
  TestDeadInLoop := Sum;  { 55 }
end;

function TestDeadStore: Integer;
var
  X: Integer;
begin
  X := 100;
  X := 200;          { 第一次赋值被覆盖，应被消除 }
  TestDeadStore := X;  { 200 }
end;

function TestDeadAfterIf: Integer;
var
  X: Integer;
begin
  X := 1;
  if X > 0 then
    X := 10
  else
    X := -10;  { 死分支 }
  TestDeadAfterIf := X;  { 10 }
end;

begin
  if TestDeadInLoop <> 55 then Halt(1);
  if TestDeadStore <> 200 then Halt(2);
  if TestDeadAfterIf <> 10 then Halt(3);
end.
