{**
 * np_mir_optimize.pas — MIR optimization pass framework
 *
 * 对标 rustc MIR optimization passes。
 * 提供 Pass 注册/调度框架。具体优化 pass 在阶段 3 实现。
 *
 * 预定义的 pass：
 *   - ConstantFolding
 *   - DeadCodeElimination
 *   - StrengthReduction
 *   - Inlining
 *   - CommonSubexpressionElimination
 *   - DeadArgElimination
 *}

unit np_mir_optimize;

{$mode objfpc}{$H+}

interface

uses
  np_mir_model;

type
  {**
   * IMirOptimizationPass — MIR 优化 pass 接口
   *
   * 每个 pass 实现此接口，由 TMirPassManager 按注册顺序调度。
   *}
  IMirOptimizationPass = interface
    function Name: string;
    function Run(var AModule: TMirModule): Boolean;
  end;

  {**
   * TMirPassManager — MIR pass 注册/调度管理器
   *
   * 对标 rustc mir::pass_manager。
   *}
  TMirPassManager = class
  private
    FPasses: array of IMirOptimizationPass;
  public
    procedure RegisterPass(const APass: IMirOptimizationPass);
    function RunAll(var AModule: TMirModule): Boolean;
    function PassCount: LongInt;
  end;

implementation

procedure TMirPassManager.RegisterPass(const APass: IMirOptimizationPass);
var
  Idx: SizeInt;
begin
  Idx := Length(FPasses);
  SetLength(FPasses, Idx + 1);
  FPasses[Idx] := APass;
end;

function TMirPassManager.RunAll(var AModule: TMirModule): Boolean;
var
  I: LongInt;
begin
  Result := True;
  for I := 0 to High(FPasses) do
  begin
    if not FPasses[I].Run(AModule) then
    begin
      Result := False;
      Exit;
    end;
  end;
end;

function TMirPassManager.PassCount: LongInt;
begin
  Result := Length(FPasses);
end;

end.
