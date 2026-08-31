{**
 * nextpas.compiler.ir.mir.pass.deadarg.pas — MIR Dead Argument Elimination Pass
 *
 * 移除未被使用的函数参数，同时更新所有调用点。
 *
 * 算法：
 *   1. 分析函数体内对每个参数的使用
 *   2. 标记未使用的参数索引
 *   3. 从函数签名中移除
 *   4. 更新所有调用点（移除对应实参）
 *
 * ParamUsed / DeadIndices / NewParams 可挂 phase-scratch IAllocator。
 *
 * 对标：rustc mir::transform::dead_args, LLVM DeadArgElimination
 *}

unit nextpas.compiler.ir.mir.pass.deadarg;

{$mode objfpc}{$H+}
{$UNITPATH ../../core/src}

interface

uses
  nextpas.compiler.ir.mir.model, nextpas.compiler.ir.mir.optimize,
  nextpas.core.mem.intf,
  nextpas.core.collections.vec;

type
  TMirBoolVec = specialize TVec<Boolean>;
  TMirLongIntVec = specialize TVec<LongInt>;

  TMirDeadArgPass = class(TInterfacedObject, IMirOptimizationPass)
  private
    FAllocator: IAllocator;
  public
    constructor Create(AAllocator: IAllocator = nil);
    function Name: string;
    function Run(var AModule: TMirModule): Boolean;
  end;

implementation

constructor TMirDeadArgPass.Create(AAllocator: IAllocator);
begin
  inherited Create;
  FAllocator := AAllocator;
end;

function TMirDeadArgPass.Name: string;
begin
  Result := 'dead-arg';
end;

{ Check if a value ID appears in any operand position }
function IsValueUsedInStmt(const AStmt: TMirStmt; AValueId: TMirValueId): Boolean;

  function CheckOperand(const AOp: TMirOperand): Boolean;
  begin
    Result := (AOp.Kind in [mokLocal, mokMove]) and (AOp.Value = AValueId);
  end;

var
  I: LongInt;
begin
  Result := CheckOperand(AStmt.Src)
    or CheckOperand(AStmt.Lhs)
    or CheckOperand(AStmt.Rhs);
  if Result then Exit;

  if AStmt.Args <> nil then
    for I := 0 to LongInt(AStmt.Args.Count) - 1 do
      if CheckOperand(AStmt.Args[SizeUInt(I)]) then
        Exit(True);

  Result := False;
end;

{ Check if value is used in terminator }
function IsValueUsedInTerm(const ATerm: TMirTerminator; AValueId: TMirValueId): Boolean;
begin
  Result := (ATerm.ReturnValue = AValueId)
    or (ATerm.Cond = AValueId)
    or (ATerm.SwitchValue = AValueId);
end;

function CreateBoolVec(AAllocator: IAllocator): TMirBoolVec;
begin
  if AAllocator <> nil then
    Result := TMirBoolVec.Create(0, AAllocator)
  else
    Result := TMirBoolVec.Create;
end;

function CreateLongIntVec(AAllocator: IAllocator): TMirLongIntVec;
begin
  if AAllocator <> nil then
    Result := TMirLongIntVec.Create(0, AAllocator)
  else
    Result := TMirLongIntVec.Create;
end;

function CreateParamVec(AAllocator: IAllocator): TMirParamVec;
begin
  if AAllocator <> nil then
    Result := TMirParamVec.Create(0, AAllocator)
  else
    Result := TMirParamVec.Create;
end;

{ Remove dead params from a function and rewrite all call sites }
function EliminateDeadParams(var AModule: TMirModule; AFuncIdx: TMirFuncId;
  AAllocator: IAllocator): LongInt;
var
  Fn: TMirFunction;
  ParamUsed: TMirBoolVec;
  DeadIndices: TMirLongIntVec;
  BlkIdx, StmtIdx, ParamIdx, I: LongInt;
  ParamCount: LongInt;
  Stmt: TMirStmt;
  NewParams: TMirParamVec;
  Kept: array of TMirParam;
begin
  Result := 0;
  Fn := AModule.FunctionAt(AFuncIdx);

  if (Fn.Params = nil) or (Fn.Params.Count = 0) then
    Exit;
  ParamCount := LongInt(Fn.Params.Count);

  ParamUsed := CreateBoolVec(AAllocator);
  DeadIndices := CreateLongIntVec(AAllocator);
  NewParams := CreateParamVec(AAllocator);
  try
    { Step 1: Mark used parameters }
    ParamUsed.Resize(ParamCount);
    if ParamUsed.Count > 0 then
      ParamUsed.Zero(0, ParamUsed.Count);

    if Fn.Blocks <> nil then
      for BlkIdx := 0 to LongInt(Fn.Blocks.Count) - 1 do
    begin
      if Fn.Blocks[SizeUInt(BlkIdx)].Stmts <> nil then
          for StmtIdx := 0 to LongInt(Fn.Blocks[SizeUInt(BlkIdx)].Stmts.Count) - 1 do
      begin
        if not AModule.GetStmt(AFuncIdx, Fn.Blocks[SizeUInt(BlkIdx)].Id, StmtIdx, Stmt) then
          Continue;
        for ParamIdx := 0 to ParamCount - 1 do
          if IsValueUsedInStmt(Stmt, Fn.Params[SizeUInt(ParamIdx)].ValueId) then
            ParamUsed[ParamIdx] := True;
      end;

      { Check terminator }
      for ParamIdx := 0 to ParamCount - 1 do
        if IsValueUsedInTerm(Fn.Blocks[SizeUInt(BlkIdx)].Terminator,
          Fn.Params[SizeUInt(ParamIdx)].ValueId) then
          ParamUsed[ParamIdx] := True;
    end;

    { Step 2: Collect dead param indices }
    DeadIndices.Clear;
    for ParamIdx := 0 to LongInt(ParamUsed.Count) - 1 do
      if not ParamUsed[ParamIdx] then
      begin
        DeadIndices.Push(ParamIdx);
        Inc(Result);
      end;

    if Result = 0 then
      Exit;

    { Step 3: Remove dead params and write back via SetParams }
    NewParams.Clear;
    for ParamIdx := 0 to ParamCount - 1 do
      if ParamUsed[ParamIdx] then
        NewParams.Push(Fn.Params[SizeUInt(ParamIdx)]);

    SetLength(Kept, LongInt(NewParams.Count));
    for I := 0 to LongInt(NewParams.Count) - 1 do
      Kept[I] := NewParams[SizeUInt(I)];
    AModule.SetParams(Fn.Id, Kept);
  finally
    NewParams.Free;
    DeadIndices.Free;
    ParamUsed.Free;
  end;
end;

function TMirDeadArgPass.Run(var AModule: TMirModule): Boolean;
var
  FuncIdx: LongInt;
  TotalEliminated: LongInt;
begin
  Result := True;
  TotalEliminated := 0;

  for FuncIdx := 0 to AModule.FunctionCount - 1 do
    Inc(TotalEliminated, EliminateDeadParams(AModule, FuncIdx, FAllocator));

  Result := True;
end;

end.
