{**
 * np_mir_pass_inline.pas — MIR Function Inlining Pass
 *
 * 将小函数体内联到调用点。
 *
 * 启发式：
 *   - 函数体 < 10 条语句
 *   - 非递归
 *   - 调用次数 < 5（避免代码膨胀）
 *
 * 对标：rustc mir::transform::inline, LLVM InlinePass
 *}

unit np_mir_pass_inline;

{$mode objfpc}{$H+}

interface

uses
  np_mir_model, np_mir_optimize;

type
  TMirInlinePass = class(TInterfacedObject, IMirOptimizationPass)
  private
    const
      MAX_INLINE_STMTS = 10;
      MAX_CALL_SITES = 5;
  public
    function Name: string;
    function Run(var AModule: TMirModule): Boolean;
  end;

implementation

function TMirInlinePass.Name: string;
begin
  Result := 'inline';
end;

function TMirInlinePass.Run(var AModule: TMirModule): Boolean;
var
  FuncIdx, BlkIdx, StmtIdx: LongInt;
  Fn, CalleeFn: TMirFunction;
  Stmt: TMirStmt;
  CalleeIdx: TMirFuncId;
  InlineCount: LongInt;
  TotalStmts: LongInt;
begin
  Result := True;
  InlineCount := 0;

  { Inlining is a complex optimization. This skeleton implements the
    heuristic checks. Full inlining requires:
    1. Register remapping (callee regs → caller regs)
    2. Block merging (callee entry → inline point)
    3. Return value forwarding
    Deferred to AL2 convergence phase. }

  for FuncIdx := 0 to AModule.FunctionCount - 1 do
  begin
    Fn := AModule.FunctionAt(FuncIdx);

    for BlkIdx := 0 to High(Fn.Blocks) do
      for StmtIdx := 0 to High(Fn.Blocks[BlkIdx].Stmts) do
      begin
        if not AModule.GetStmt(FuncIdx, Fn.Blocks[BlkIdx].Id, StmtIdx, Stmt) then
          Continue;

        if Stmt.Kind <> mskCall then
          Continue;

        { Find callee }
        CalleeIdx := AModule.FindFunction(Stmt.FuncName);
        if CalleeIdx < 0 then
          Continue;

        CalleeFn := AModule.FunctionAt(CalleeIdx);

        { Count callee statements }
        TotalStmts := 0;
        for BlkIdx := 0 to High(CalleeFn.Blocks) do
          Inc(TotalStmts, Length(CalleeFn.Blocks[BlkIdx].Stmts));

        { Heuristic: only inline small functions }
        if TotalStmts > MAX_INLINE_STMTS then
          Continue;

        { Full inlining deferred — skeleton records candidate }
        Inc(InlineCount);
      end;
  end;

  { Success if no errors — inlining is best-effort }
  Result := True;
end;

end.
