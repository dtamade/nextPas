{**
 * nextpas.compiler.ir.mir.opt_level.pas — MIR Optimization Level Scheduler
 *
 * 根据优化级别选择哪些 pass 运行。
 *
 * O0: 无 MIR 优化（仅常量折叠保证正确性）
 * O1: 基础优化（6 个 base pass）
 * O2: 进阶优化（12 个 pass，含 LICM/escape/tailcall/devirt/vectorize）
 *
 * 对标：LLVM PassManagerBuilder, rustc -C opt-level
 *}

unit nextpas.compiler.ir.mir.opt_level;

{$mode objfpc}{$H+}

interface

uses
  nextpas.compiler.ir.mir.optimize;

type
  { 优化级别 }
  TMirOptLevel = (molO0, molO1, molO2);

  {**
   * RegisterPassesForLevel — 按优化级别注册 pass
   *
   * @param AManager  pass 管理器
   * @param ALevel    优化级别
   *}
procedure RegisterPassesForLevel(
  AManager: TMirPassManager;
  ALevel: TMirOptLevel
);

{ 从字符串解析优化级别 }
function ParseOptLevel(const AStr: string): TMirOptLevel;

implementation

uses
  SysUtils,
  nextpas.compiler.ir.mir.pass.constfold,
  nextpas.compiler.ir.mir.pass.dce,
  nextpas.compiler.ir.mir.pass.strength_red,
  nextpas.compiler.ir.mir.pass.inline,
  nextpas.compiler.ir.mir.pass.cse,
  nextpas.compiler.ir.mir.pass.deadarg,
  nextpas.compiler.ir.mir.pass.licm,
  nextpas.compiler.ir.mir.pass.escape,
  nextpas.compiler.ir.mir.pass.tailcall,
  nextpas.compiler.ir.mir.pass.devirt,
  nextpas.compiler.ir.mir.pass.inline_heuristic,
  nextpas.compiler.ir.mir.pass.vectorize;

function ParseOptLevel(const AStr: string): TMirOptLevel;
begin
  case LowerCase(AStr) of
    '0', 'o0': Result := molO0;
    '1', 'o1': Result := molO1;
    '2', 'o2': Result := molO2;
  else
    Result := molO1;  { 默认 O1 }
  end;
end;

procedure RegisterPassesForLevel(
  AManager: TMirPassManager;
  ALevel: TMirOptLevel
);
begin
  case ALevel of
    molO0:
      begin
        { O0: 仅常量折叠（保证正确性，不优化） }
        AManager.RegisterPass(TMirConstFoldPass.Create);
      end;

    molO1:
      begin
        { O1: 6 个基础 pass — 快速优化，适合开发阶段 }
        AManager.RegisterPass(TMirConstFoldPass.Create);
        AManager.RegisterPass(TMirStrengthRedPass.Create);
        { Work tables on phase-scratch when manager has Allocator }
        AManager.RegisterPass(TMirCsePass.Create(AManager.Allocator));
        AManager.RegisterPass(TMirDcePass.Create(AManager.Allocator));
        AManager.RegisterPass(TMirInlinePass.Create(AManager.Allocator));
        AManager.RegisterPass(TMirDeadArgPass.Create(AManager.Allocator));
      end;

    molO2:
      begin
        { O2: 全部 12 个 pass — 激进优化，适合发布构建 }
        { 基础 pass }
        AManager.RegisterPass(TMirConstFoldPass.Create);
        AManager.RegisterPass(TMirStrengthRedPass.Create);
        AManager.RegisterPass(TMirCsePass.Create(AManager.Allocator));
        { 进阶 pass }
        AManager.RegisterPass(TMirLicmPass.Create(AManager.Allocator));
        AManager.RegisterPass(TMirEscapePass.Create(AManager.Allocator));
        AManager.RegisterPass(TMirInlineHeuristicPass.Create);
        AManager.RegisterPass(TMirInlinePass.Create(AManager.Allocator));
        AManager.RegisterPass(TMirDcePass.Create(AManager.Allocator));
        AManager.RegisterPass(TMirTailCallPass.Create);
        AManager.RegisterPass(TMirDevirtPass.Create);
        AManager.RegisterPass(TMirVectorizePass.Create);
        AManager.RegisterPass(TMirDeadArgPass.Create(AManager.Allocator));
      end;
  end;
end;

end.
