program deadarg_multi_pass;

{ 死参数消除：多参数场景 }

function OnlyThird(A, B, C: Integer): Integer;
begin
  OnlyThird := C * 2;  { A 和 B 未使用 }
end;

function OnlyFirstAndLast(A, B, C, D: Integer): Integer;
begin
  OnlyFirstAndLast := A + D;  { B 和 C 未使用 }
end;

function AllUsed(A, B: Integer): Integer;
begin
  AllUsed := A + B;  { 所有参数都使用，不应消除 }
end;

begin
  if OnlyThird(1, 2, 3) <> 6 then Halt(1);
  if OnlyFirstAndLast(1, 2, 3, 4) <> 5 then Halt(2);
  if AllUsed(10, 20) <> 30 then Halt(3);
end.
