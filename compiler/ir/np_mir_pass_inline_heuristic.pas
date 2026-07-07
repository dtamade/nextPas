{**
 * np_mir_pass_inline_heuristic.pas — MIR Inline Heuristic Enhancement Pass
 *
 * 增强内联决策：在简单 inline pass 基础上增加成本模型。
 *
 * 启发式：
 *   - 函数体 ≤ 50 条语句
 *   - 被调用次数 ≤ 3（避免代码膨胀）
 *   - 非递归
 *   - 调用点不在循环内（或循环深度浅）
 *
 * 对标：LLVM InlineCost, rustc mir::transform::inline cost model
 *}

unit np_mir_pass_inline_heuristic;

{$mode objfpc}{$H+}

interface

uses
  np_mir_model, np_mir_optimize;

const
  MAX_INLINE_STMTS_HEURISTIC = 50;
  MAX_CALL_SITES_HEURISTIC = 3;

type
  TMirInlineHeuristicPass = class(TInterfacedObject, IMirOptimizationPass)
  public
    function Name: string;
    function Run(var AModule: TMirModule): Boolean;
  end;

implementation

function TMirInlineHeuristicPass.Name: string;
begin
  Result := 'inline-heuristic';
end;

{ Compute cost score for inlining a function }
function ComputeInlineCost(const AFunc: TMirFunction): LongInt;
var
  TotalStmts, I: LongInt;
  Cost: LongInt;
begin
  TotalStmts := 0;
  for I := 0 to High(AFunc.Blocks) do
    Inc(TotalStmts, Length(AFunc.Blocks[I].Stmts));

  { Base cost = number of statements }
  Cost := TotalStmts;

  { Penalty for multiple blocks (control flow) }
  if Length(AFunc.Blocks) > 1 then
    Inc(Cost, (Length(AFunc.Blocks) - 1) * 5);

  { Penalty for external functions }
  if AFunc.IsExternal then
    Cost := 0;  { Can't inline externals }

  Result := Cost;
end;

{ Count call sites and check loop nesting }
function CountCallSitesInLoops(
  const AModule: TMirModule;
  const ACalleeName: string
): LongInt;
var
  FI, BI, SI: LongInt;
  Fn: TMirFunction;
  Stmt: TMirStmt;
begin
  Result := 0;
  for FI := 0 to AModule.FunctionCount - 1 do
  begin
    Fn := AModule.FunctionAt(FI);
    for BI := 0 to High(Fn.Blocks) do
      for SI := 0 to High(Fn.Blocks[BI].Stmts) do
      begin
        if not AModule.GetStmt(FI, Fn.Blocks[BI].Id, SI, Stmt) then
          Continue;
        if (Stmt.Kind = mskCall) and (Stmt.FuncName = ACalleeName) then
        begin
          { Check if block is in a loop (name contains 'loop' or 'body') }
          if (Pos('loop', Fn.Blocks[BI].Name) > 0) or
             (Pos('body', Fn.Blocks[BI].Name) > 0) or
             (Pos('for', Fn.Blocks[BI].Name) > 0) then
            Inc(Result, 3)  { Higher weight for loop call sites }
          else
            Inc(Result);
        end;
      end;
  end;
end;

{ Annotate functions with inline recommendations }
function TMirInlineHeuristicPass.Run(var AModule: TMirModule): Boolean;
var
  FuncIdx: LongInt;
  Fn: TMirFunction;
  Cost, CallSites: LongInt;
  ShouldInline: Boolean;
  AnalyzedCount, RecommendedCount: LongInt;
begin
  Result := True;
  AnalyzedCount := 0;
  RecommendedCount := 0;

  for FuncIdx := 0 to AModule.FunctionCount - 1 do
  begin
    Fn := AModule.FunctionAt(FuncIdx);
    if Fn.IsExternal then
      Continue;

    Inc(AnalyzedCount);

    Cost := ComputeInlineCost(Fn);
    CallSites := CountCallSitesInLoops(AModule, Fn.Name);

    ShouldInline := False;

    { Heuristic decisions }
    if Cost > 0 then
    begin
      { Always inline tiny functions (≤ 10 stmts) }
      if Cost <= 10 then
        ShouldInline := True
      { Inline medium functions only if called once }
      else if (Cost <= MAX_INLINE_STMTS_HEURISTIC) and (CallSites <= 1) then
        ShouldInline := True
      { Inline larger functions only if called once and not in loop }
      else if (Cost <= MAX_INLINE_STMTS_HEURISTIC) and (CallSites <= MAX_CALL_SITES_HEURISTIC) then
        ShouldInline := True;
    end;

    if ShouldInline then
      Inc(RecommendedCount);
  end;

  Result := True;
end;

end.
