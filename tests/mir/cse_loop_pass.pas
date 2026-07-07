program cse_loop_pass;

{ CSE：循环中的公共子表达式 }

function TestCseInLoop: Integer;
var
  I, A, B, Sum: Integer;
begin
  A := 3;
  B := 7;
  Sum := 0;
  for I := 1 to 5 do
    Sum := Sum + (A * B);  { A*B 是循环不变量，应被 CSE 提升 }
  TestCseInLoop := Sum;    { 5 * 21 = 105 }
end;

function TestCseAcrossBranches: Integer;
var
  X, Base, R: Integer;
begin
  X := 10;
  Base := X * 2 + 1;   { 21 }
  if X > 5 then
    R := Base + 1       { Base 复用 }
  else
    R := Base - 1;
  TestCseAcrossBranches := R;  { 22 }
end;

begin
  if TestCseInLoop <> 105 then Halt(1);
  if TestCseAcrossBranches <> 22 then Halt(2);
end.
