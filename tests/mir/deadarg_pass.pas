program deadarg_pass;

{ 验证死参数消除：未使用的参数应被移除 }

function UnusedSecond(A, B: Integer): Integer;
begin
  UnusedSecond := A * 2;  { B 未使用，应被 deadarg 消除 }
end;

function UnusedBoth(A, B: Integer): Integer;
begin
  UnusedBoth := 42;       { A 和 B 都未使用 }
end;

function OnlyUsesFirst(A, B, C: Integer): Integer;
begin
  OnlyUsesFirst := A + 1; { B 和 C 未使用 }
end;

begin
  if UnusedSecond(10, 999) <> 20 then Halt(1);
  if UnusedBoth(1, 2) <> 42 then Halt(2);
  if OnlyUsesFirst(5, 100, 200) <> 6 then Halt(3);
end.
