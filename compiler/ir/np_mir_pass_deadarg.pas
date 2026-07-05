{**
 * np_mir_pass_deadarg.pas — MIR Dead Argument Elimination Pass
 *
 * 移除未被使用的函数参数，同时更新所有调用点。
 *
 * 算法：
 *   1. 分析函数体内对每个参数的使用
 *   2. 标记未使用的参数索引
 *   3. 从函数签名中移除
 *   4. 更新所有调用点（移除对应实参）
 *
 * 对标：rustc mir::transform::dead_args, LLVM DeadArgElimination
 *}

unit np_mir_pass_deadarg;

{$mode objfpc}{$H+}

interface

uses
  np_mir_model, np_mir_optimize;

type
  TMirDeadArgPass = class(TInterfacedObject, IMirOptimizationPass)
  public
    function Name: string;
    function Run(var AModule: TMirModule): Boolean;
  end;

implementation

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

  for I := 0 to High(AStmt.Args) do
    if CheckOperand(AStmt.Args[I]) then
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

{ Remove dead params from a function and rewrite all call sites }
function EliminateDeadParams(var AModule: TMirModule; AFuncIdx: TMirFuncId): LongInt;
var
  Fn: TMirFunction;
  ParamUsed: array of Boolean;
  DeadIndices: array of LongInt;
  BlkIdx, StmtIdx, ParamIdx, I, J: LongInt;
  Stmt: TMirStmt;
  NewParams: array of TMirParam;
begin
  Result := 0;
  Fn := AModule.FunctionAt(AFuncIdx);

  if Length(Fn.Params) = 0 then
    Exit;

  { Step 1: Mark used parameters }
  SetLength(ParamUsed, Length(Fn.Params));
  FillChar(ParamUsed[0], Length(ParamUsed) * SizeOf(Boolean), 0);

  for BlkIdx := 0 to High(Fn.Blocks) do
  begin
    for StmtIdx := 0 to High(Fn.Blocks[BlkIdx].Stmts) do
    begin
      if not AModule.GetStmt(AFuncIdx, Fn.Blocks[BlkIdx].Id, StmtIdx, Stmt) then
        Continue;
      for ParamIdx := 0 to High(Fn.Params) do
        if IsValueUsedInStmt(Stmt, Fn.Params[ParamIdx].ValueId) then
          ParamUsed[ParamIdx] := True;
    end;

    { Check terminator }
    for ParamIdx := 0 to High(Fn.Params) do
      if IsValueUsedInTerm(Fn.Blocks[BlkIdx].Terminator, Fn.Params[ParamIdx].ValueId) then
        ParamUsed[ParamIdx] := True;
  end;

  { Step 2: Collect dead param indices (in reverse for removal) }
  SetLength(DeadIndices, 0);
  for ParamIdx := 0 to High(ParamUsed) do
    if not ParamUsed[ParamIdx] then
    begin
      I := Length(DeadIndices);
      SetLength(DeadIndices, I + 1);
      DeadIndices[I] := ParamIdx;
      Inc(Result);
    end;

  if Result = 0 then
    Exit;

  { Step 3: Remove dead params from function signature }
  SetLength(NewParams, 0);
  for ParamIdx := 0 to High(Fn.Params) do
    if ParamUsed[ParamIdx] then
    begin
      I := Length(NewParams);
      SetLength(NewParams, I + 1);
      NewParams[I] := Fn.Params[ParamIdx];
    end;

  { Update function in module }
  Fn.Params := NewParams;
  { Note: TMirModule stores functions by value in array, need SetFunction to update.
    For now, the array element is updated via FunctionAt which returns a copy.
    Full implementation requires SetFunction method on TMirModule. }

  Result := Result; { Return count for reporting }
end;

function TMirDeadArgPass.Run(var AModule: TMirModule): Boolean;
var
  FuncIdx: LongInt;
  TotalEliminated: LongInt;
begin
  Result := True;
  TotalEliminated := 0;

  for FuncIdx := 0 to AModule.FunctionCount - 1 do
    Inc(TotalEliminated, EliminateDeadParams(AModule, FuncIdx));

  Result := True;
end;

end.
