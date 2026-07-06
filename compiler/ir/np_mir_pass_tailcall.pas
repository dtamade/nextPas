{**
 * np_mir_pass_tailcall.pas — MIR Tail Call Optimization Pass
 *
 * 将尾递归调用转换为循环（jump 到函数入口）。
 *
 * 条件：
 *   1. 调用是基本块的最后一个语句
 *   2. 调用目标是当前函数（自递归）
 *   3. 调用后紧跟 return（直接尾调用）
 *
 * 转换：
 *   递归:  call self(args); return
 *   循环:  assign params := args; goto entry_block
 *
 * 对标：LLVM TailCallElim, rustc mir::transform::tailcall
 *}

unit np_mir_pass_tailcall;

{$mode objfpc}{$H+}

interface

uses
  np_mir_model, np_mir_optimize;

type
  TMirTailCallPass = class(TInterfacedObject, IMirOptimizationPass)
  public
    function Name: string;
    function Run(var AModule: TMirModule): Boolean;
  end;

implementation

function TMirTailCallPass.Name: string;
begin
  Result := 'tail-call';
end;

{ Check if the block ends with a tail-recursive call }
function IsTailRecursiveCall(
  const AFunc: TMirFunction;
  const ABlock: TMirBlock;
  const AStmt: TMirStmt;
  out AIsTail: Boolean
): Boolean;
begin
  Result := False;
  AIsTail := False;

  if AStmt.Kind <> mskCall then
    Exit;
  if AStmt.FuncName <> AFunc.Name then
    Exit;

  { Check if call is the last statement before terminator }
  { The terminator should be a return of the call result }
  if ABlock.Terminator.Kind = mtkReturn then
  begin
    if ABlock.Terminator.ReturnValue = AStmt.Dst then
      AIsTail := True;
  end
  else if ABlock.Terminator.Kind = mtkReturn then
    AIsTail := True;  { Void return after call }

  Result := True;
end;

function TMirTailCallPass.Run(var AModule: TMirModule): Boolean;
var
  FuncIdx, BlkIdx, StmtIdx, I: LongInt;
  Fn: TMirFunction;
  Stmt: TMirStmt;
  IsTail: Boolean;
  TailCount: LongInt;
  AssignStmt: TMirStmt;
begin
  Result := True;
  TailCount := 0;

  for FuncIdx := 0 to AModule.FunctionCount - 1 do
  begin
    Fn := AModule.FunctionAt(FuncIdx);
    if Fn.IsExternal then
      Continue;
    if Length(Fn.Blocks) = 0 then
      Continue;

    for BlkIdx := 0 to High(Fn.Blocks) do
    begin
      if Length(Fn.Blocks[BlkIdx].Stmts) = 0 then
        Continue;

      { Check the last statement in the block }
      StmtIdx := High(Fn.Blocks[BlkIdx].Stmts);
      Stmt := Fn.Blocks[BlkIdx].Stmts[StmtIdx];

      if not IsTailRecursiveCall(Fn, Fn.Blocks[BlkIdx], Stmt, IsTail) then
        Continue;
      if not IsTail then
        Continue;

      { Transform: replace call with param assignments + goto entry }
      for I := 0 to High(Stmt.Args) do
      begin
        if I <= High(Fn.Params) then
        begin
          AssignStmt.Kind := mskAssign;
          AssignStmt.Dst := Fn.Params[I].ValueId;
          AssignStmt.Src := Stmt.Args[I];
          AssignStmt.Lhs.Kind := mokConst;
          AssignStmt.Rhs.Kind := mokConst;
          AssignStmt.Op := moAdd;
          AModule.SetStmt(FuncIdx, Fn.Blocks[BlkIdx].Id, StmtIdx - I, AssignStmt);
        end;
      end;

      { Change terminator to goto entry block }
      Fn.Blocks[BlkIdx].Terminator.Kind := mtkGoto;
      Fn.Blocks[BlkIdx].Terminator.Target := Fn.EntryBlockId;
      AModule.SetTerminator(FuncIdx, Fn.Blocks[BlkIdx].Id, Fn.Blocks[BlkIdx].Terminator);

      Inc(TailCount);
    end;
  end;

  Result := True;
end;

end.
