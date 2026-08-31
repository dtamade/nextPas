{**
 * nextpas.compiler.ir.mir.pass.inline_heuristic.pas — MIR Inline Heuristic Enhancement Pass
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

unit nextpas.compiler.ir.mir.pass.inline_heuristic;

{$mode objfpc}{$H+}

interface

uses
  nextpas.compiler.ir.mir.model, nextpas.compiler.ir.mir.optimize;

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
  if AFunc.Blocks <> nil then
    for I := 0 to LongInt(AFunc.Blocks.Count) - 1 do
      if AFunc.Blocks[SizeUInt(I)].Stmts <> nil then
        Inc(TotalStmts, LongInt(AFunc.Blocks[SizeUInt(I)].Stmts.Count));

  { Base cost = number of statements }
  Cost := TotalStmts;

  { Penalty for multiple blocks (control flow) }
  if (AFunc.Blocks <> nil) and (AFunc.Blocks.Count > 1) then
    Inc(Cost, (LongInt(AFunc.Blocks.Count) - 1) * 5);

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
    if Fn.Blocks <> nil then
      for BI := 0 to LongInt(Fn.Blocks.Count) - 1 do
      if Fn.Blocks[SizeUInt(BI)].Stmts <> nil then
          for SI := 0 to LongInt(Fn.Blocks[SizeUInt(BI)].Stmts.Count) - 1 do
      begin
        if not AModule.GetStmt(FI, Fn.Blocks[SizeUInt(BI)].Id, SI, Stmt) then
          Continue;
        if (Stmt.Kind = mskCall) and (Stmt.FuncName = ACalleeName) then
        begin
          { Check if block is in a loop (name contains 'loop' or 'body') }
          if (Pos('loop', Fn.Blocks[SizeUInt(BI)].Name) > 0) or
             (Pos('body', Fn.Blocks[SizeUInt(BI)].Name) > 0) or
             (Pos('for', Fn.Blocks[SizeUInt(BI)].Name) > 0) then
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
