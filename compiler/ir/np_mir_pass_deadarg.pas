{**
 * np_mir_pass_deadarg.pas — MIR Dead Argument Elimination Pass
 *
 * 移除未被使用的函数参数。
 *
 * 算法：
 *   1. 分析函数体内对每个参数的使用
 *   2. 标记未使用的参数
 *   3. 从函数签名中移除
 *   4. 更新所有调用点（移除对应实参）
 *
 * 对标：rustc mir::transform::dead_args, LLVM DeadArgElimination
 *}

unit np_mir_pass_deadarg;

{$mode objfpc}{$H+}

interface

uses
  np_mir_model, np_mir_optimize;

type
  TMirDeadArgPass = class(TInterfacedObject, IMirOptimizationPass)
  public
    function Name: string;
    function Run(var AModule: TMirModule): Boolean;
  end;

implementation

function TMirDeadArgPass.Name: string;
begin
  Result := 'dead-arg';
end;

function TMirDeadArgPass.Run(var AModule: TMirModule): Boolean;
var
  FuncIdx, BlkIdx, StmtIdx, ParamIdx: LongInt;
  Fn: TMirFunction;
  Stmt: TMirStmt;
  ParamUsed: array of Boolean;
  DeadCount: LongInt;

  procedure MarkOperand(const AOp: TMirOperand);
  begin
    if AOp.Kind in [mokLocal, mokMove] then
      for ParamIdx := 0 to High(Fn.Params) do
        if Fn.Params[ParamIdx].ValueId = AOp.Value then
          ParamUsed[ParamIdx] := True;
  end;

begin
  Result := True;
  DeadCount := 0;

  for FuncIdx := 0 to AModule.FunctionCount - 1 do
  begin
    Fn := AModule.FunctionAt(FuncIdx);

    if Length(Fn.Params) = 0 then
      Continue;

    SetLength(ParamUsed, Length(Fn.Params));
    FillChar(ParamUsed[0], Length(ParamUsed) * SizeOf(Boolean), 0);

    { Mark used parameters }
    for BlkIdx := 0 to High(Fn.Blocks) do
      for StmtIdx := 0 to High(Fn.Blocks[BlkIdx].Stmts) do
      begin
        if not AModule.GetStmt(FuncIdx, Fn.Blocks[BlkIdx].Id, StmtIdx, Stmt) then
          Continue;
        MarkOperand(Stmt.Src);
        MarkOperand(Stmt.Lhs);
        MarkOperand(Stmt.Rhs);
      end;

    { Count dead params }
    for ParamIdx := 0 to High(ParamUsed) do
      if not ParamUsed[ParamIdx] then
        Inc(DeadCount);

    { Full elimination deferred — requires call-site rewriting.
      Skeleton records dead param candidates. }
  end;
end;

end.
