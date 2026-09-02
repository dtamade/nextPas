{**
 * nextpas.compiler.ir.mir.pass.licm.pas — MIR Loop-Invariant Code Motion Pass
 *
 * 将循环不变量提升到循环外，减少重复计算。
 *
 * 算法：
 *   1. 识别循环（通过回边检测 back-edge）
 *   2. 对每条语句检查操作数是否在循环外定义
 *   3. 如果所有操作数都是循环不变量 → 提升到 pre-header
 *
 * LoopBlocks 可挂 phase-scratch IAllocator。
 *
 * 对标：LLVM LICM, rustc mir::transform::licm
 *}

unit nextpas.compiler.ir.mir.pass.licm;

{$mode objfpc}{$H+}
{$UNITPATH ../../core/src}

interface

uses
  nextpas.compiler.ir.mir.model, nextpas.compiler.ir.mir.optimize,
  nextpas.core.mem.intf,
  nextpas.core.collections.vec;

type
  TMirBlockIdVec = specialize TVec<TMirBlockId>;

  TMirLicmPass = class(TInterfacedObject, IMirOptimizationPass)
  private
    FAllocator: IAllocator;
  public
    constructor Create(AAllocator: IAllocator = nil);
    function Name: string;
    function Run(var AModule: TMirModule): Boolean;
  end;

implementation

constructor TMirLicmPass.Create(AAllocator: IAllocator);
begin
  inherited Create;
  FAllocator := AAllocator;
end;

function TMirLicmPass.Name: string;
begin
  Result := 'licm';
end;

{ Check if a value is defined outside the loop (invariant) }
function IsLoopInvariant(
  const AModule: TMirModule;
  const AFunc: TMirFunction;
  ALoopBlocks: TMirBlockIdVec;
  const AValueId: TMirValueId
): Boolean;
var
  BI, SI: LongInt;
  InLoop: Boolean;
begin
  { Value 0 is always invariant (represents void/none) }
  if AValueId = 0 then
    Exit(True);

  { Check if value is defined in any loop block }
  if AFunc.Blocks <> nil then
      for BI := 0 to LongInt(AFunc.Blocks.Count) - 1 do
  begin
    { Skip blocks not in the loop }
    InLoop := False;
    for SI := 0 to LongInt(ALoopBlocks.Count) - 1 do
      if AFunc.Blocks[SizeUInt(BI)].Id = ALoopBlocks[SI] then
      begin
        InLoop := True;
        Break;
      end;
    if not InLoop then
      Continue;

    if AFunc.Blocks[SizeUInt(BI)].Stmts <> nil then
          for SI := 0 to LongInt(AFunc.Blocks[SizeUInt(BI)].Stmts.Count) - 1 do
      if AFunc.Blocks[SizeUInt(BI)].Stmts[SizeUInt(SI)].Dst = AValueId then
        Exit(False);  { Defined inside loop → not invariant }
  end;

  Result := True;
end;

{ Check if a statement's operands are all loop-invariant }
function StmtIsLoopInvariant(
  const AModule: TMirModule;
  const AFunc: TMirFunction;
  ALoopBlocks: TMirBlockIdVec;
  const AStmt: TMirStmt
): Boolean;
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
  ALoopBlocks: TMirBlockIdVec
): Boolean;
var
  BI: LongInt;
  HeaderIdx: LongInt;
  TargetId: TMirBlockId;
begin
  Result := False;
  ALoopBlocks.Clear;

  { Find the header block index }
  HeaderIdx := -1;
  if AFunc.Blocks <> nil then
      for BI := 0 to LongInt(AFunc.Blocks.Count) - 1 do
    if AFunc.Blocks[SizeUInt(BI)].Id = AHeaderBlockId then
    begin
      HeaderIdx := BI;
      Break;
    end;
  if HeaderIdx < 0 then
    Exit;

  { Simple loop detection: collect all blocks between header and back-edge }
  ALoopBlocks.Push(AHeaderBlockId);

  if AFunc.Blocks <> nil then
    for BI := HeaderIdx + 1 to LongInt(AFunc.Blocks.Count) - 1 do
  begin
    TargetId := 0;
    case AFunc.Blocks[SizeUInt(BI)].Terminator.Kind of
      mtkGoto: TargetId := AFunc.Blocks[SizeUInt(BI)].Terminator.Target;
      mtkIf:
        begin
          if AFunc.Blocks[SizeUInt(BI)].Terminator.TrueBlock = AHeaderBlockId then
            TargetId := AHeaderBlockId
          else if AFunc.Blocks[SizeUInt(BI)].Terminator.FalseBlock = AHeaderBlockId then
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
    ALoopBlocks.Push(AFunc.Blocks[SizeUInt(BI)].Id);
  end;
end;

function TMirLicmPass.Run(var AModule: TMirModule): Boolean;
var
  FuncIdx, BlkIdx, StmtIdx, LoopBlkIdx: LongInt;
  Fn: TMirFunction;
  Stmt, HoistedStmt: TMirStmt;
  LoopBlocks: TMirBlockIdVec;
  HoistedCount: LongInt;
  Hoisted: Boolean;
begin
  Result := True;
  HoistedCount := 0;

  if FAllocator <> nil then
    LoopBlocks := TMirBlockIdVec.Create(0, FAllocator)
  else
    LoopBlocks := TMirBlockIdVec.Create;
  try
    for FuncIdx := 0 to AModule.FunctionCount - 1 do
    begin
      Fn := AModule.FunctionAt(FuncIdx);

      if Fn.Blocks <> nil then
      for BlkIdx := 0 to LongInt(Fn.Blocks.Count) - 1 do
      begin
        { Try to detect loop starting at this block }
        if not DetectLoopBlocks(Fn, Fn.Blocks[SizeUInt(BlkIdx)].Id, LoopBlocks) then
          Continue;
        if LoopBlocks.Count = 0 then
          Continue;

        { For each loop block, check if statements can be hoisted }
        Hoisted := False;
        for LoopBlkIdx := 0 to LongInt(LoopBlocks.Count) - 1 do
        begin
          StmtIdx := 0;
          while (Fn.Blocks[SizeUInt(LoopBlkIdx)].Stmts <> nil) and (StmtIdx < LongInt(Fn.Blocks[SizeUInt(LoopBlkIdx)].Stmts.Count)) do
          begin
            if not AModule.GetStmt(FuncIdx, LoopBlocks[LoopBlkIdx], StmtIdx, Stmt) then
            begin
              Inc(StmtIdx);
              Continue;
            end;

            if StmtIsLoopInvariant(AModule, Fn, LoopBlocks, Stmt) then
            begin
              { Hoist with cloned Args so both entries own independent TVecs. }
              HoistedStmt := Stmt;
              HoistedStmt.Args := CloneMirOperandVec(Stmt.Args);
              AModule.AddStmt(FuncIdx, LoopBlocks[0], HoistedStmt);

              { Nop original; SetStmt frees previous Args (differs from nil). }
              FillChar(Stmt, SizeOf(Stmt), 0);
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
  finally
    LoopBlocks.Free;
  end;

  Result := True;
end;

end.
