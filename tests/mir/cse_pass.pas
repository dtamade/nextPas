{ objfpc}{+}
program test_cse_unit;
{ CSE pass 单元测试 — 公共子表达式检测 }
type
  TMirStmt = record Op: string; Lhs, Rhs: LongInt; Dst: LongInt; end;
function FindCommonExpr(const Stmts: array of TMirStmt; I, J: LongInt): Boolean;
begin
  FindCommonExpr := (Stmts[I].Op = Stmts[J].Op) and
    (Stmts[I].Lhs = Stmts[J].Lhs) and (Stmts[I].Rhs = Stmts[J].Rhs);
end;
var Stmts: array[0..3] of TMirStmt;
begin
  Stmts[0].Op:='add'; Stmts[0].Lhs:=1; Stmts[0].Rhs:=2; Stmts[0].Dst:=10;
  Stmts[1].Op:='mul'; Stmts[1].Lhs:=3; Stmts[1].Rhs:=4; Stmts[1].Dst:=11;
  Stmts[2].Op:='add'; Stmts[2].Lhs:=1; Stmts[2].Rhs:=2; Stmts[2].Dst:=12;
  Stmts[3].Op:='add'; Stmts[3].Lhs:=5; Stmts[3].Rhs:=6; Stmts[3].Dst:=13;
  if FindCommonExpr(Stmts, 0, 2) <> True then Halt(1);
  if FindCommonExpr(Stmts, 0, 1) <> False then Halt(2);
  if FindCommonExpr(Stmts, 0, 3) <> False then Halt(3);
end.
