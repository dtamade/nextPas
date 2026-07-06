{**
 * np_mir_pass_licm.pas — MIR Loop-Invariant Code Motion Pass
 *
 * 将循环不变量提升到循环外，减少重复计算。
 *
 * 算法：
 *   1. 识别循环（通过回边检测 back-edge）
 *   2. 对每条语句检查操作数是否在循环外定义
 *   3. 如果所有操作数都是循环不变量 → 提升到 pre-header
 *
 * 对标：LLVM LICM, rustc mir::transform::licm
 *}

unit np_mir_pass_licm;

{$mode objfpc}{$H+}

interface

uses
  np_mir_model, np_mir_optimize;

type
  TMirLicmPass = class(TInterfacedObject, IMirOptimizationPass)
  public
    function Name: string;
    function Run(var AModule: TMirModule): Boolean;
  end;

implementation

function TMirLicmPass.Name: string;
begin
  Result := 'licm';
end;

{ Check if a value is defined outside the loop (invariant) }
function IsLoopInvariant(
  const AModule: TMirModule;
  const AFunc: TMirFunction;
  const ALoopBlocks: array of TMirBlockId;
  const AValueId: TMirValueId
): Boolean;
var
  BI, SI: LongInt;
  Blk: TMirBlock;
  InLoop: Boolean;
begin
  { Value 0 is always invariant (represents void/none) }
  if AValueId = 0 then
    Exit(True);

  { Check if value is defined in any loop block }
  for BI := 0 to High(AFunc.Blocks) do
  begin
    { Skip blocks not in the loop }
    InLoop := False;
    for SI := 0 to High(ALoopBlocks) do
      if AFunc.Blocks[BI].Id = ALoopBlocks[SI] then
      begin
        InLoop := True;
        Break;
      end;
    if not InLoop then
      Continue;

    for SI := 0 to High(AFunc.Blocks[BI].Stmts) do
      if AFunc.Blocks[BI].Stmts[SI].Dst = AValueId then
        Exit(False);  { Defined inside loop → not invariant }
  end;

  Result := True;
end;

{ Check if a statement's operands are all loop-invariant }
function StmtIsLoopInvariant(
  const AModule: TMirModule;
  const AFunc: TMirFunction;
  const ALoopBlocks: array of TMirBlockId;
  const AStmt: TMirStmt
): Boolean;
var
  I: LongInt;
begin
  case AStmt.Kind of
    mskAssign:
      Result := IsLoopInvariant(AModule, AFunc, ALoopBlocks, AStmt.Src.Value);
    mskUnary:
      Result := IsLoopInvariant(AModule, AFunc, ALoopBlocks, AStmt.Src.Value);
    mskBinary:
      Result := IsLoopInvariant(AModule, AFunc, ALoopBlocks, AStmt.Lhs.Value) and
                IsLoopInvariant(AModule, AFunc, ALoopBlocks, AStmt.Rhs.Value);
    mskLoad:
      Result := IsLoopInvariant(AModule, AFunc, ALoopBlocks, AStmt.Src.Value);
    else
      Result := False;  { Conservative: calls/alloca/store not hoisted }
  end;
end;

{ Detect loop blocks via back-edge from terminator }
function DetectLoopBlocks(
  const AFunc: TMirFunction;
  const AHeaderBlockId: TMirBlockId;
  out ALoopBlocks: array of TMirBlockId
): Boolean;
var
  BI, Idx: LongInt;
  HeaderIdx: LongInt;
  TargetId: TMirBlockId;
begin
  Result := False;
  SetLength(ALoopBlocks, 0);

  { Find the header block index }
  HeaderIdx := -1;
  for BI := 0 to High(AFunc.Blocks) do
    if AFunc.Blocks[BI].Id = AHeaderBlockId then
    begin
      HeaderIdx := BI;
      Break;
    end;
  if HeaderIdx < 0 then
    Exit;

  { Simple loop detection: collect all blocks between header and back-edge }
  Idx := 0;
  SetLength(ALoopBlocks, 1);
  ALoopBlocks[0] := AHeaderBlockId;

  for BI := HeaderIdx + 1 to High(AFunc.Blocks) do
  begin
    TargetId := 0;
    case AFunc.Blocks[BI].Terminator.Kind of
      mtkGoto: TargetId := AFunc.Blocks[BI].Terminator.Target;
      mtkIf:
        begin
          if AFunc.Blocks[BI].Terminator.TrueBlock = AHeaderBlockId then
            TargetId := AHeaderBlockId
          else if AFunc.Blocks[BI].Terminator.FalseBlock = AHeaderBlockId then
            TargetId := AHeaderBlockId;
        end;
    end;

    if TargetId = AHeaderBlockId then
    begin
      { Found back-edge: all blocks from header to here are in the loop }
      Result := True;
      Exit;
    end;

    { Add block to loop body }
    Inc(Idx);
    SetLength(ALoopBlocks, Idx + 1);
    ALoopBlocks[Idx] := AFunc.Blocks[BI].Id;
  end;
end;

function TMirLicmPass.Run(var AModule: TMirModule): Boolean;
var
  FuncIdx, BlkIdx, StmtIdx, LoopBlkIdx: LongInt;
  Fn: TMirFunction;
  Stmt: TMirStmt;
  LoopBlocks: array of TMirBlockId;
  HoistedCount: LongInt;
  Hoisted: Boolean;
begin
  Result := True;
  HoistedCount := 0;

  for FuncIdx := 0 to AModule.FunctionCount - 1 do
  begin
    Fn := AModule.FunctionAt(FuncIdx);

    for BlkIdx := 0 to High(Fn.Blocks) do
    begin
      { Try to detect loop starting at this block }
      if not DetectLoopBlocks(Fn, Fn.Blocks[BlkIdx].Id, LoopBlocks) then
        Continue;
      if Length(LoopBlocks) = 0 then
        Continue;

      { For each loop block, check if statements can be hoisted }
      Hoisted := False;
      for LoopBlkIdx := 0 to High(LoopBlocks) do
      begin
        StmtIdx := 0;
        while StmtIdx < Length(Fn.Blocks[LoopBlkIdx].Stmts) do
        begin
          if not AModule.GetStmt(FuncIdx, LoopBlocks[LoopBlkIdx], StmtIdx, Stmt) then
          begin
            Inc(StmtIdx);
            Continue;
          end;

          if StmtIsLoopInvariant(AModule, Fn, LoopBlocks, Stmt) then
          begin
            { Hoist: move to header block (insert before loop statements) }
            AModule.AddStmt(FuncIdx, LoopBlocks[0], Stmt);

            { Remove from current position by replacing with nop-style assign }
            Stmt.Kind := mskAssign;
            Stmt.Src := MirIntConst(0, 32);
            Stmt.Dst := 0;
            AModule.SetStmt(FuncIdx, LoopBlocks[LoopBlkIdx], StmtIdx, Stmt);

            Hoisted := True;
            Inc(HoistedCount);
          end;

          Inc(StmtIdx);
        end;
      end;
    end;
  end;

  Result := True;
end;

end.
