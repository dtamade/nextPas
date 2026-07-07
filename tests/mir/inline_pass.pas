{ objfpc}{+}
program test_inline_unit;
{ Inline pass 单元测试 — 内联候选判断 }
function IsInlineCandidate(StmtCount, BlockCount: LongInt; IsExternal: Boolean): Boolean;
begin
  if IsExternal then Exit(False);
  IsInlineCandidate := (StmtCount > 0) and (StmtCount <= 10);
end;
begin
  if IsInlineCandidate(5, 1, False) <> True then Halt(1);
  if IsInlineCandidate(15, 1, False) <> False then Halt(2);
  if IsInlineCandidate(5, 1, True) <> False then Halt(3);
  if IsInlineCandidate(0, 1, False) <> False then Halt(4);
end.
