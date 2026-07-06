{ objfpc}{+}
program test_licm_unit;
{ LICM pass 单元测试 — 循环不变量检测 }
function IsInvariant(DefBlock, LoopStart, LoopEnd: LongInt): Boolean;
begin
  IsInvariant := (DefBlock < LoopStart) or (DefBlock > LoopEnd);
end;
begin
  if IsInvariant(0, 2, 5) <> True then Halt(1);
  if IsInvariant(3, 2, 5) <> False then Halt(2);
  if IsInvariant(6, 2, 5) <> True then Halt(3);
  if IsInvariant(2, 2, 5) <> False then Halt(4);
end.
