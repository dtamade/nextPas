{**
 * nextpas.compiler.ir.mir.pass.tailcall.pas — MIR Tail Call Optimization Pass
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

unit nextpas.compiler.ir.mir.pass.tailcall;

{$mode objfpc}{$H+}

interface

uses
  nextpas.compiler.ir.mir.model, nextpas.compiler.ir.mir.optimize;

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
  FuncIdx, BlkIdx, StmtIdx, I, ArgCount: LongInt;
  Fn: TMirFunction;
  Stmt: TMirStmt;
  Term: TMirTerminator;
  IsTail: Boolean;
  TailCount: LongInt;
  AssignStmt: TMirStmt;
  SavedArgs: array of TMirOperand;
begin
  Result := True;
  TailCount := 0;

  for FuncIdx := 0 to AModule.FunctionCount - 1 do
  begin
    Fn := AModule.FunctionAt(FuncIdx);
    if Fn.IsExternal then
      Continue;
    if (Fn.Blocks = nil) or (Fn.Blocks.Count = 0) then
      Continue;

    if Fn.Blocks <> nil then
      for BlkIdx := 0 to LongInt(Fn.Blocks.Count) - 1 do
    begin
      if (Fn.Blocks[SizeUInt(BlkIdx)].Stmts = nil) or (Fn.Blocks[SizeUInt(BlkIdx)].Stmts.Count = 0) then
        Continue;

      { Check the last statement in the block }
      StmtIdx := LongInt(Fn.Blocks[SizeUInt(BlkIdx)].Stmts.Count) - 1;
      Stmt := Fn.Blocks[SizeUInt(BlkIdx)].Stmts[SizeUInt(StmtIdx)];

      if not IsTailRecursiveCall(Fn, Fn.Blocks[SizeUInt(BlkIdx)], Stmt, IsTail) then
        Continue;
      if not IsTail then
        Continue;

      { Snapshot args before SetStmt frees the call's Args TVec. }
      ArgCount := 0;
      if Stmt.Args <> nil then
        ArgCount := LongInt(Stmt.Args.Count);
      SetLength(SavedArgs, ArgCount);
      for I := 0 to ArgCount - 1 do
        SavedArgs[I] := Stmt.Args[SizeUInt(I)];

      { Transform: replace call with param assignments + goto entry }
      for I := 0 to ArgCount - 1 do
      begin
        if (Fn.Params <> nil) and (I < LongInt(Fn.Params.Count)) then
        begin
          FillChar(AssignStmt, SizeOf(AssignStmt), 0);
          AssignStmt.Kind := mskAssign;
          AssignStmt.Dst := Fn.Params[SizeUInt(I)].ValueId;
          AssignStmt.Src := SavedArgs[I];
          AssignStmt.Lhs.Kind := mokConst;
          AssignStmt.Rhs.Kind := mokConst;
          AssignStmt.Op := moAdd;
          AModule.SetStmt(FuncIdx, Fn.Blocks[SizeUInt(BlkIdx)].Id, StmtIdx - I, AssignStmt);
        end;
      end;

      { Change terminator to goto entry block (local copy — TVec is value-indexed) }
      Term := Fn.Blocks[SizeUInt(BlkIdx)].Terminator;
      Term.Kind := mtkGoto;
      Term.Target := Fn.EntryBlockId;
      AModule.SetTerminator(FuncIdx, Fn.Blocks[SizeUInt(BlkIdx)].Id, Term);

      Inc(TailCount);
    end;
  end;

  Result := True;
end;

end.
