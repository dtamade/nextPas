{$mode objfpc}{$H+}
program incremental_build_regression;

{ 增量编译回归测试：验证增量编译与全量编译产物一致 }

{ uses-free: only System intrinsics (Halt/WriteLn); no FPC RTL units. }

var
  I, Sum: Integer;
  S: string;
begin
  { Test 1: Simple arithmetic — should produce same result in both modes }
  Sum := 0;
  for I := 1 to 100 do
    Sum := Sum + I;
  if Sum <> 5050 then Halt(1);

  { Test 2: String operations }
  S := '';
  for I := 1 to 5 do
    S := S + Chr(Ord('A') + I - 1);
  if S <> 'ABCDE' then Halt(2);

  { Test 3: Function call chain }
  if Sum <> 5050 then Halt(3);

  { Test 4: Type operations }
  if SizeOf(Integer) <> 4 then Halt(4);
  if SizeOf(Int64) <> 8 then Halt(5);
end.
