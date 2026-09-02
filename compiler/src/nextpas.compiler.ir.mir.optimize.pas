{**
 * nextpas.compiler.ir.mir.optimize.pas — MIR optimization pass framework
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
 *
 * FPasses 表可挂 phase-scratch IAllocator（backend PhaseScratch）。
 *}

unit nextpas.compiler.ir.mir.optimize;

{$mode objfpc}{$H+}
{$UNITPATH ../../core/src}

interface

uses
  nextpas.compiler.ir.mir.model,
  nextpas.core.mem.intf,
  nextpas.core.collections.vec;

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

  TMirPassVec = specialize TVec<IMirOptimizationPass>;

  {**
   * TMirPassManager — MIR pass 注册/调度管理器
   *
   * 对标 rustc mir::pass_manager。
   * Optional AAllocator: phase scratch for the pass registry TVec.
   *}
  TMirPassManager = class
  private
    FAllocator: IAllocator;
    FPasses: TMirPassVec;
  public
    constructor Create(AAllocator: IAllocator = nil);
    destructor Destroy; override;
    procedure RegisterPass(const APass: IMirOptimizationPass);
    function RunAll(var AModule: TMirModule): Boolean;
    function PassCount: LongInt;
    { Phase scratch for pass-local work tables (DCE/CSE TVecs). }
    property Allocator: IAllocator read FAllocator;
  end;

implementation

constructor TMirPassManager.Create(AAllocator: IAllocator);
begin
  inherited Create;
  FAllocator := AAllocator;
  if FAllocator <> nil then
    FPasses := TMirPassVec.Create(0, FAllocator)
  else
    FPasses := TMirPassVec.Create;
end;

destructor TMirPassManager.Destroy;
begin
  FPasses.Free;
  inherited Destroy;
end;

procedure TMirPassManager.RegisterPass(const APass: IMirOptimizationPass);
begin
  FPasses.Push(APass);
end;

function TMirPassManager.RunAll(var AModule: TMirModule): Boolean;
var
  I: LongInt;
begin
  Result := True;
  for I := 0 to LongInt(FPasses.Count) - 1 do
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
  Result := LongInt(FPasses.Count);
end;

end.
