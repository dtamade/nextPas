{**
 * nextpas.compiler.ir.mir.pass.dce.pas — MIR Dead Code Elimination Pass
 *
 * 消除无用的赋值语句。
 *
 * 算法：
 *   1. 标记所有"活跃"的虚拟寄存器（被使用的）
 *   2. 删除对"死亡"寄存器的赋值（Dst 不再被读取）
 *   3. 迭代直到不动点
 *
 * UsedRegs 位图可挂 phase-scratch IAllocator（TVec on PhaseScratch）。
 *
 * 对标：rustc mir::transform::dce
 *}

unit nextpas.compiler.ir.mir.pass.dce;

{$mode objfpc}{$H+}
{$UNITPATH ../../core/src}

interface

uses
  nextpas.compiler.ir.mir.model, nextpas.compiler.ir.mir.optimize,
  nextpas.core.mem.intf,
  nextpas.core.collections.vec;

type
  TMirBoolVec = specialize TVec<Boolean>;

  TMirDcePass = class(TInterfacedObject, IMirOptimizationPass)
  private
    FAllocator: IAllocator;
  public
    constructor Create(AAllocator: IAllocator = nil);
    function Name: string;
    function Run(var AModule: TMirModule): Boolean;
  end;

implementation

constructor TMirDcePass.Create(AAllocator: IAllocator);
begin
  inherited Create;
  FAllocator := AAllocator;
end;

function TMirDcePass.Name: string;
begin
  Result := 'dce';
end;

function TMirDcePass.Run(var AModule: TMirModule): Boolean;
var
  FuncIdx, BlkIdx, StmtIdx: LongInt;
  Fn: TMirFunction;
  Stmt: TMirStmt;
  UsedRegs: TMirBoolVec;
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

  if FAllocator <> nil then
    UsedRegs := TMirBoolVec.Create(0, FAllocator)
  else
    UsedRegs := TMirBoolVec.Create;
  try
    for FuncIdx := 0 to AModule.FunctionCount - 1 do
    begin
      Fn := AModule.FunctionAt(FuncIdx);

      { Track max register count for this function }
      MaxReg := 0;
      if Fn.Blocks <> nil then
      for BlkIdx := 0 to LongInt(Fn.Blocks.Count) - 1 do
        if Fn.Blocks[SizeUInt(BlkIdx)].Stmts <> nil then
          for StmtIdx := 0 to LongInt(Fn.Blocks[SizeUInt(BlkIdx)].Stmts.Count) - 1 do
          if Fn.Blocks[SizeUInt(BlkIdx)].Stmts[SizeUInt(StmtIdx)].Dst > MaxReg then
            MaxReg := Fn.Blocks[SizeUInt(BlkIdx)].Stmts[SizeUInt(StmtIdx)].Dst;

      if MaxReg = 0 then
        Continue;

      UsedRegs.Resize(MaxReg);

      Changed := True;
      while Changed do
      begin
        Changed := False;

        { Reset use tracking }
        if UsedRegs.Count > 0 then
          UsedRegs.Zero(0, UsedRegs.Count);

        { Mark all used registers }
        if Fn.Blocks <> nil then
      for BlkIdx := 0 to LongInt(Fn.Blocks.Count) - 1 do
          if Fn.Blocks[SizeUInt(BlkIdx)].Stmts <> nil then
          for StmtIdx := 0 to LongInt(Fn.Blocks[SizeUInt(BlkIdx)].Stmts.Count) - 1 do
          begin
            if not AModule.GetStmt(FuncIdx, Fn.Blocks[SizeUInt(BlkIdx)].Id, StmtIdx, Stmt) then
              Continue;
            MarkOperand(Stmt.Src);
            MarkOperand(Stmt.Lhs);
            MarkOperand(Stmt.Rhs);
          end;

        { Remove unused assignments }
        if Fn.Blocks <> nil then
      for BlkIdx := 0 to LongInt(Fn.Blocks.Count) - 1 do
          if Fn.Blocks[SizeUInt(BlkIdx)].Stmts <> nil then
          for StmtIdx := 0 to LongInt(Fn.Blocks[SizeUInt(BlkIdx)].Stmts.Count) - 1 do
          begin
            if not AModule.GetStmt(FuncIdx, Fn.Blocks[SizeUInt(BlkIdx)].Id, StmtIdx, Stmt) then
              Continue;
            if (Stmt.Dst > 0) and (Stmt.Dst <= MaxReg) and not UsedRegs[Stmt.Dst - 1] then
            begin
              Stmt.Kind := mskAssign;
              Stmt.Dst := 0;
              Stmt.Src.Kind := mokConst;
              Stmt.Src.ConstVal.IntVal := 0;
              AModule.SetStmt(FuncIdx, Fn.Blocks[SizeUInt(BlkIdx)].Id, StmtIdx, Stmt);
              Changed := True;
              Inc(RemovedCount);
            end;
          end;
      end;
    end;
  finally
    UsedRegs.Free;
  end;
end;

end.
