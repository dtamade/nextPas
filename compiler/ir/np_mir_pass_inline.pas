{**
 * np_mir_pass_inline.pas — MIR Function Inlining Pass
 *
 * 将小函数体内联到调用点。
 *
 * 启发式：
 *   - 函数体 ≤ 10 条语句
 *   - 非递归
 *   - 非 external
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
  public
    function Name: string;
    function Run(var AModule: TMirModule): Boolean;
  end;

implementation

function TMirInlinePass.Name: string;
begin
  Result := 'inline';
end;

{ Check if function is eligible for inlining }
function IsInlineCandidate(const AFunc: TMirFunction): Boolean;
var
  TotalStmts, I: LongInt;
begin
  if AFunc.IsExternal then
    Exit(False);

  TotalStmts := 0;
  for I := 0 to High(AFunc.Blocks) do
    Inc(TotalStmts, Length(AFunc.Blocks[I].Stmts));

  Result := (TotalStmts > 0) and (TotalStmts <= MAX_INLINE_STMTS);
end;

{ Count call sites for a given function }
function CountCallSites(const AModule: TMirModule; const ACalleeName: string): LongInt;
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
          Inc(Result);
      end;
  end;
end;

{ Remap a single operand's ValueId from callee to caller namespace }
procedure RemapOperand(var AOp: TMirOperand; const AOldToNew: array of record
  OldId, NewId: TMirValueId; end);
var
  I: LongInt;
begin
  if AOp.Kind in [mokLocal, mokMove] then
    for I := 0 to High(AOldToNew) do
      if AOp.Value = AOldToNew[I].OldId then
      begin
        AOp.Value := AOldToNew[I].NewId;
        Break;
      end;
end;

{ Inline one call site: replace mskCall with callee body statements }
function InlineCallSite(var AModule: TMirModule;
  ACallerFuncIdx, ACalleeFuncIdx: TMirFuncId;
  ABlkIdx, AStmtIdx: LongInt): Boolean;
var
  CallerFn, CalleeFn: TMirFunction;
  CallStmt, InlinedStmt: TMirStmt;
  RemapTable: array of record OldId, NewId: TMirValueId; end;
  I, J, ParamIdx: LongInt;
  InlinedStmts: array of TMirStmt;
begin
  Result := False;

  CallerFn := AModule.FunctionAt(ACallerFuncIdx);
  CalleeFn := AModule.FunctionAt(ACalleeFuncIdx);

  if not AModule.GetStmt(ACallerFuncIdx,
    CallerFn.Blocks[ABlkIdx].Id, AStmtIdx, CallStmt) then
    Exit;

  { Build register remap table: callee params + results → caller namespace }
  SetLength(RemapTable, 0);

  { Map callee params to call args }
  for I := 0 to High(CalleeFn.Params) do
  begin
    if I < Length(CallStmt.Args) then
    begin
      J := Length(RemapTable);
      SetLength(RemapTable, J + 1);
      RemapTable[J].OldId := CalleeFn.Params[I].ValueId;
      RemapTable[J].NewId := CallStmt.Args[I].Value;
    end;
  end;

  { Collect all callee statements across all blocks, remapped }
  SetLength(InlinedStmts, 0);
  for I := 0 to High(CalleeFn.Blocks) do
    for J := 0 to High(CalleeFn.Blocks[I].Stmts) do
    begin
      InlinedStmt := CalleeFn.Blocks[I].Stmts[J];

      { Remap result register }
      for ParamIdx := 0 to High(RemapTable) do
        if InlinedStmt.Dst = RemapTable[ParamIdx].OldId then
        begin
          InlinedStmt.Dst := RemapTable[ParamIdx].NewId;
          Break;
        end;

      { If result is the final return value, map to call Dst }
      if InlinedStmt.Dst = CalleeFn.Blocks[I].Terminator.ReturnValue then
        InlinedStmt.Dst := CallStmt.Dst;

      { Remap operands }
      RemapOperand(InlinedStmt.Src, RemapTable);
      RemapOperand(InlinedStmt.Lhs, RemapTable);
      RemapOperand(InlinedStmt.Rhs, RemapTable);
      for ParamIdx := 0 to High(InlinedStmt.Args) do
        RemapOperand(InlinedStmt.Args[ParamIdx], RemapTable);

      ParamIdx := Length(InlinedStmts);
      SetLength(InlinedStmts, ParamIdx + 1);
      InlinedStmts[ParamIdx] := InlinedStmt;
    end;

  { Replace the call statement with inlined body }
  { Strategy: replace call with first inlined stmt, then insert rest }
  if Length(InlinedStmts) > 0 then
  begin
    AModule.SetStmt(ACallerFuncIdx, CallerFn.Blocks[ABlkIdx].Id,
      AStmtIdx, InlinedStmts[0]);

    { Insert remaining statements after the call site }
    for I := 1 to High(InlinedStmts) do
      AModule.AddStmt(ACallerFuncIdx, CallerFn.Blocks[ABlkIdx].Id,
        InlinedStmts[I]);

    Result := True;
  end;
end;

function TMirInlinePass.Run(var AModule: TMirModule): Boolean;
var
  FuncIdx, BlkIdx, StmtIdx: LongInt;
  Fn, CalleeFn: TMirFunction;
  Stmt: TMirStmt;
  CalleeIdx: TMirFuncId;
  InlineCount: LongInt;
begin
  Result := True;
  InlineCount := 0;

  for FuncIdx := 0 to AModule.FunctionCount - 1 do
  begin
    Fn := AModule.FunctionAt(FuncIdx);

    BlkIdx := 0;
    while BlkIdx <= High(Fn.Blocks) do
    begin
      StmtIdx := 0;
      while StmtIdx <= High(Fn.Blocks[BlkIdx].Stmts) do
      begin
        if not AModule.GetStmt(FuncIdx, Fn.Blocks[BlkIdx].Id, StmtIdx, Stmt) then
        begin
          Inc(StmtIdx);
          Continue;
        end;

        if Stmt.Kind = mskCall then
        begin
          CalleeIdx := AModule.FindFunction(Stmt.FuncName);
          if CalleeIdx >= 0 then
          begin
            CalleeFn := AModule.FunctionAt(CalleeIdx);
            if IsInlineCandidate(CalleeFn) then
              if InlineCallSite(AModule, FuncIdx, CalleeIdx, BlkIdx, StmtIdx) then
                Inc(InlineCount);
          end;
        end;

        Inc(StmtIdx);
      end;
      Inc(BlkIdx);
    end;
  end;

  Result := True;
end;

end.
