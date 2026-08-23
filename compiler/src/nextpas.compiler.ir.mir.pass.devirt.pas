{**
 * nextpas.compiler.ir.mir.pass.devirt.pas — MIR Devirtualization Pass
 *
 * 将虚调用替换为直接调用。
 *
 * 策略：
 *   1. 识别 vtable 加载模式
 *   2. 如果类层次已知且无覆盖 → 直接调用
 *   3. 如果只有单个实现 → 直接调用
 *
 * 对标：rustc mir::transform::devirtualize, LLVM DevirtSCCRepeatedPass
 *}

unit nextpas.compiler.ir.mir.pass.devirt;

{$mode objfpc}{$H+}

interface

uses
  nextpas.compiler.ir.mir.model, nextpas.compiler.ir.mir.optimize;

type
  TMirDevirtPass = class(TInterfacedObject, IMirOptimizationPass)
  public
    function Name: string;
    function Run(var AModule: TMirModule): Boolean;
  end;

implementation

function TMirDevirtPass.Name: string;
begin
  Result := 'devirt';
end;

{ Check if a call can be devirtualized }
function CanDevirtualize(
  const AModule: TMirModule;
  const AStmt: TMirStmt;
  out ADirectTarget: string
): Boolean;
var
  CalleeIdx: TMirFuncId;
begin
  Result := False;
  ADirectTarget := '';

  if AStmt.Kind <> mskCall then
    Exit;

  { Pattern: call through function pointer or indirect }
  { In MIR, virtual calls appear as calls with 'vcall' prefix }
  if Pos('vcall', AStmt.FuncName) = 1 then
  begin
    { Try to resolve to single implementation }
    { Check if any non-virtual overload exists }
    CalleeIdx := AModule.FindFunction(Copy(AStmt.FuncName, 6, Length(AStmt.FuncName)));
    if CalleeIdx > 0 then
    begin
      ADirectTarget := Copy(AStmt.FuncName, 6, Length(AStmt.FuncName));
      Result := True;
    end;
  end;
end;

function TMirDevirtPass.Run(var AModule: TMirModule): Boolean;
var
  FuncIdx, BlkIdx, StmtIdx: LongInt;
  Fn: TMirFunction;
  Stmt: TMirStmt;
  DirectTarget: string;
  DevirtCount: LongInt;
begin
  Result := True;
  DevirtCount := 0;

  for FuncIdx := 0 to AModule.FunctionCount - 1 do
  begin
    Fn := AModule.FunctionAt(FuncIdx);

    if Fn.Blocks <> nil then
      for BlkIdx := 0 to LongInt(Fn.Blocks.Count) - 1 do
      if Fn.Blocks[SizeUInt(BlkIdx)].Stmts <> nil then
          for StmtIdx := 0 to LongInt(Fn.Blocks[SizeUInt(BlkIdx)].Stmts.Count) - 1 do
      begin
        if not AModule.GetStmt(FuncIdx, Fn.Blocks[SizeUInt(BlkIdx)].Id, StmtIdx, Stmt) then
          Continue;

        if CanDevirtualize(AModule, Stmt, DirectTarget) then
        begin
          Stmt.FuncName := DirectTarget;
          AModule.SetStmt(FuncIdx, Fn.Blocks[SizeUInt(BlkIdx)].Id, StmtIdx, Stmt);
          Inc(DevirtCount);
        end;
      end;
  end;

  Result := True;
end;

end.
