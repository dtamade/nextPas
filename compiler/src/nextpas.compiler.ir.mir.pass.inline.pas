{**
 * nextpas.compiler.ir.mir.pass.inline.pas — MIR Function Inlining Pass
 *
 * 将小函数体内联到调用点。
 *
 * 启发式：
 *   - 函数体 ≤ 10 条语句
 *   - 非递归
 *   - 非 external
 *
 * RemapTable / InlinedStmts 可挂 phase-scratch IAllocator。
 *
 * 对标：rustc mir::transform::inline, LLVM InlinePass
 *}

unit nextpas.compiler.ir.mir.pass.inline;

{$mode objfpc}{$H+}
{$UNITPATH ../../core/src}

interface

uses
  nextpas.compiler.ir.mir.model, nextpas.compiler.ir.mir.optimize,
  nextpas.core.mem.intf,
  nextpas.core.collections.vec;

const
  MAX_INLINE_STMTS = 10;

type
  TValueRemapEntry = record
    OldId: TMirValueId;
    NewId: TMirValueId;
  end;

  TMirValueRemapVec = specialize TVec<TValueRemapEntry>;
  TMirStmtVec = specialize TVec<TMirStmt>;

  TMirInlinePass = class(TInterfacedObject, IMirOptimizationPass)
  private
    FAllocator: IAllocator;
  public
    constructor Create(AAllocator: IAllocator = nil);
    function Name: string;
    function Run(var AModule: TMirModule): Boolean;
  end;

implementation

constructor TMirInlinePass.Create(AAllocator: IAllocator);
begin
  inherited Create;
  FAllocator := AAllocator;
end;

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
  if AFunc.Blocks <> nil then
    for I := 0 to LongInt(AFunc.Blocks.Count) - 1 do
      if AFunc.Blocks[SizeUInt(I)].Stmts <> nil then
        Inc(TotalStmts, LongInt(AFunc.Blocks[SizeUInt(I)].Stmts.Count));

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
    if Fn.Blocks <> nil then
      for BI := 0 to LongInt(Fn.Blocks.Count) - 1 do
      if Fn.Blocks[SizeUInt(BI)].Stmts <> nil then
          for SI := 0 to LongInt(Fn.Blocks[SizeUInt(BI)].Stmts.Count) - 1 do
      begin
        if not AModule.GetStmt(FI, Fn.Blocks[SizeUInt(BI)].Id, SI, Stmt) then
          Continue;
        if (Stmt.Kind = mskCall) and (Stmt.FuncName = ACalleeName) then
          Inc(Result);
      end;
  end;
end;

{ Remap a single operand's ValueId from callee to caller namespace }
procedure RemapOperand(var AOp: TMirOperand; AOldToNew: TMirValueRemapVec);
var
  I: LongInt;
begin
  if AOp.Kind in [mokLocal, mokMove] then
    for I := 0 to LongInt(AOldToNew.Count) - 1 do
      if AOp.Value = AOldToNew[I].OldId then
      begin
        AOp.Value := AOldToNew[I].NewId;
        Break;
      end;
end;

function CreateRemapVec(AAllocator: IAllocator): TMirValueRemapVec;
begin
  if AAllocator <> nil then
    Result := TMirValueRemapVec.Create(0, AAllocator)
  else
    Result := TMirValueRemapVec.Create;
end;

function CreateStmtVec(AAllocator: IAllocator): TMirStmtVec;
begin
  if AAllocator <> nil then
    Result := TMirStmtVec.Create(0, AAllocator)
  else
    Result := TMirStmtVec.Create;
end;

{ Inline one call site: replace mskCall with callee body statements }
function InlineCallSite(var AModule: TMirModule;
  ACallerFuncIdx, ACalleeFuncIdx: TMirFuncId;
  ABlkIdx, AStmtIdx: LongInt;
  AAllocator: IAllocator): Boolean;
var
  CallerFn, CalleeFn: TMirFunction;
  CallStmt, InlinedStmt: TMirStmt;
  RemapTable: TMirValueRemapVec;
  Entry: TValueRemapEntry;
  I, J, ParamIdx: LongInt;
  InlinedStmts: TMirStmtVec;
begin
  Result := False;

  CallerFn := AModule.FunctionAt(ACallerFuncIdx);
  CalleeFn := AModule.FunctionAt(ACalleeFuncIdx);

  if not AModule.GetStmt(ACallerFuncIdx,
    CallerFn.Blocks[SizeUInt(ABlkIdx)].Id, AStmtIdx, CallStmt) then
    Exit;

  RemapTable := CreateRemapVec(AAllocator);
  InlinedStmts := CreateStmtVec(AAllocator);
  try
    { Map callee params to call args }
    if CalleeFn.Params <> nil then
      for I := 0 to LongInt(CalleeFn.Params.Count) - 1 do
      begin
        if (CallStmt.Args <> nil) and (I < LongInt(CallStmt.Args.Count)) then
        begin
          Entry.OldId := CalleeFn.Params[SizeUInt(I)].ValueId;
          Entry.NewId := CallStmt.Args[SizeUInt(I)].Value;
          RemapTable.Push(Entry);
        end;
      end;

    { Collect all callee statements across all blocks, remapped }
    if CalleeFn.Blocks <> nil then
      for I := 0 to LongInt(CalleeFn.Blocks.Count) - 1 do
      if CalleeFn.Blocks[SizeUInt(I)].Stmts <> nil then
          for J := 0 to LongInt(CalleeFn.Blocks[SizeUInt(I)].Stmts.Count) - 1 do
      begin
        InlinedStmt := CalleeFn.Blocks[SizeUInt(I)].Stmts[SizeUInt(J)];
        { Deep-clone Args so caller owns an independent TVec. }
        InlinedStmt.Args := CloneMirOperandVec(InlinedStmt.Args);

        { Remap result register }
        for ParamIdx := 0 to LongInt(RemapTable.Count) - 1 do
          if InlinedStmt.Dst = RemapTable[ParamIdx].OldId then
          begin
            InlinedStmt.Dst := RemapTable[ParamIdx].NewId;
            Break;
          end;

        { If result is the final return value, map to call Dst }
        if InlinedStmt.Dst = CalleeFn.Blocks[SizeUInt(I)].Terminator.ReturnValue then
          InlinedStmt.Dst := CallStmt.Dst;

        { Remap operands }
        RemapOperand(InlinedStmt.Src, RemapTable);
        RemapOperand(InlinedStmt.Lhs, RemapTable);
        RemapOperand(InlinedStmt.Rhs, RemapTable);
        if InlinedStmt.Args <> nil then
          for ParamIdx := 0 to LongInt(InlinedStmt.Args.Count) - 1 do
            RemapOperand(InlinedStmt.Args.GetPtr(SizeUInt(ParamIdx))^,
              RemapTable);

        InlinedStmts.Push(InlinedStmt);
      end;

    { Replace the call statement with inlined body }
    if InlinedStmts.Count > 0 then
    begin
      AModule.SetStmt(ACallerFuncIdx, CallerFn.Blocks[SizeUInt(ABlkIdx)].Id,
        AStmtIdx, InlinedStmts[0]);

      { Insert remaining statements after the call site }
      for I := 1 to LongInt(InlinedStmts.Count) - 1 do
        AModule.AddStmt(ACallerFuncIdx, CallerFn.Blocks[SizeUInt(ABlkIdx)].Id,
          InlinedStmts[I]);

      Result := True;
    end;
  finally
    InlinedStmts.Free;
    RemapTable.Free;
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
    while (Fn.Blocks <> nil) and (BlkIdx < LongInt(Fn.Blocks.Count)) do
    begin
      StmtIdx := 0;
      while (Fn.Blocks[SizeUInt(BlkIdx)].Stmts <> nil) and (StmtIdx < LongInt(Fn.Blocks[SizeUInt(BlkIdx)].Stmts.Count)) do
      begin
        if not AModule.GetStmt(FuncIdx, Fn.Blocks[SizeUInt(BlkIdx)].Id, StmtIdx, Stmt) then
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
              if InlineCallSite(AModule, FuncIdx, CalleeIdx, BlkIdx, StmtIdx,
                FAllocator) then
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
