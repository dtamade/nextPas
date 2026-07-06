{ objfpc}{+}
program test_dce_unit;
{ DCE pass 单元测试 — 死代码检测逻辑 }
type
  TMirStmtKind = (mskAssign, mskCall, mskAlloca, mskLoad, mskStore);
  TMirStmt = record Kind: TMirStmtKind; Dst: LongInt; SrcVal: LongInt; end;
function IsDeadStore(const Stmts: array of TMirStmt; Idx: LongInt): Boolean;
var I: LongInt;
begin
  IsDeadStore := True;
  if Stmts[Idx].Dst = 0 then Exit;
  for I := Idx + 1 to High(Stmts) do
    if (Stmts[I].Kind = mskAssign) and (Stmts[I].SrcVal = Stmts[Idx].Dst) then
      Exit(False);
end;
var Stmts: array[0..2] of TMirStmt;
begin
  Stmts[0].Kind := mskAssign; Stmts[0].Dst := 1; Stmts[0].SrcVal := 0;
  Stmts[1].Kind := mskAssign; Stmts[1].Dst := 2; Stmts[1].SrcVal := 0;
  Stmts[2].Kind := mskAssign; Stmts[2].Dst := 3; Stmts[2].SrcVal := 1;
  if IsDeadStore(Stmts, 1) <> True then Halt(1);
  if IsDeadStore(Stmts, 0) <> False then Halt(2);
end.
