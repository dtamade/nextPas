{**
 * np_mir_pass_dce.pas — MIR Dead Code Elimination Pass
 *
 * 消除无用的赋值语句。
 *
 * 算法：
 *   1. 标记所有"活跃"的虚拟寄存器（被使用的）
 *   2. 删除对"死亡"寄存器的赋值（Dst 不再被读取）
 *   3. 迭代直到不动点
 *
 * 对标：rustc mir::transform::dce
 *}

unit np_mir_pass_dce;

{$mode objfpc}{$H+}

interface

uses
  np_mir_model, np_mir_optimize;

type
  TMirDcePass = class(TInterfacedObject, IMirOptimizationPass)
  public
    function Name: string;
    function Run(var AModule: TMirModule): Boolean;
  end;

implementation

function TMirDcePass.Name: string;
begin
  Result := 'dce';
end;

function TMirDcePass.Run(var AModule: TMirModule): Boolean;
var
  FuncIdx, BlkIdx, StmtIdx: LongInt;
  Fn: TMirFunction;
  Stmt: TMirStmt;
  UsedRegs: array of Boolean;
  MaxReg: TMirValueId;
  Changed: Boolean;
  RemovedCount: LongInt;

  procedure MarkUsed(AReg: TMirValueId);
  begin
    if (AReg > 0) and (AReg <= MaxReg) then
      UsedRegs[AReg - 1] := True;
  end;

  procedure MarkOperand(const AOp: TMirOperand);
  begin
    if AOp.Kind in [mokLocal, mokMove] then
      MarkUsed(AOp.Value);
  end;

begin
  Result := True;
  RemovedCount := 0;

  for FuncIdx := 0 to AModule.FunctionCount - 1 do
  begin
    Fn := AModule.FunctionAt(FuncIdx);

    { Track max register count for this function }
    MaxReg := 0;
    for BlkIdx := 0 to High(Fn.Blocks) do
      for StmtIdx := 0 to High(Fn.Blocks[BlkIdx].Stmts) do
        if Fn.Blocks[BlkIdx].Stmts[StmtIdx].Dst > MaxReg then
          MaxReg := Fn.Blocks[BlkIdx].Stmts[StmtIdx].Dst;

    if MaxReg = 0 then
      Continue;

    SetLength(UsedRegs, MaxReg);

    Changed := True;
    while Changed do
    begin
      Changed := False;

      { Reset use tracking }
      FillChar(UsedRegs[0], Length(UsedRegs) * SizeOf(Boolean), 0);

      { Mark all used registers }
      for BlkIdx := 0 to High(Fn.Blocks) do
        for StmtIdx := 0 to High(Fn.Blocks[BlkIdx].Stmts) do
        begin
          if not AModule.GetStmt(FuncIdx, Fn.Blocks[BlkIdx].Id, StmtIdx, Stmt) then
            Continue;
          MarkOperand(Stmt.Src);
          MarkOperand(Stmt.Lhs);
          MarkOperand(Stmt.Rhs);
        end;

      { Remove unused assignments }
      for BlkIdx := 0 to High(Fn.Blocks) do
        for StmtIdx := 0 to High(Fn.Blocks[BlkIdx].Stmts) do
        begin
          if not AModule.GetStmt(FuncIdx, Fn.Blocks[BlkIdx].Id, StmtIdx, Stmt) then
            Continue;
          if (Stmt.Dst > 0) and (Stmt.Dst <= MaxReg) and not UsedRegs[Stmt.Dst - 1] then
          begin
            Stmt.Kind := mskAssign;
            Stmt.Dst := 0;
            Stmt.Src.Kind := mokConst;
            Stmt.Src.ConstVal.IntVal := 0;
            AModule.SetStmt(FuncIdx, Fn.Blocks[BlkIdx].Id, StmtIdx, Stmt);
            Changed := True;
            Inc(RemovedCount);
          end;
        end;
    end;
  end;
end;

end.
