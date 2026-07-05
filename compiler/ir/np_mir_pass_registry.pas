{**
 * np_mir_pass_registry.pas — MIR Pass 注册表
 *
 * 创建并注册所有 MIR 优化 Pass 到 TMirPassManager。
 *
 * 使用方式：
 *   PM := TMirPassManager.Create;
 *   RegisterAllMirPasses(PM);
 *   PM.RunAll(Module);
 *   PM.Free;
 *}

unit np_mir_pass_registry;

{$mode objfpc}{$H+}

interface

uses
  np_mir_optimize,
  np_mir_pass_constfold,
  np_mir_pass_dce,
  np_mir_pass_strength_red,
  np_mir_pass_inline,
  np_mir_pass_cse,
  np_mir_pass_deadarg;

{ 注册所有 MIR 优化 Pass }
procedure RegisterAllMirPasses(AManager: TMirPassManager);

implementation

procedure RegisterAllMirPasses(AManager: TMirPassManager);
begin
  { Order matters: constant folding first to enable other passes }
  AManager.RegisterPass(TMirConstFoldPass.Create);
  AManager.RegisterPass(TMirStrengthRedPass.Create);
  AManager.RegisterPass(TMirCsePass.Create);
  AManager.RegisterPass(TMirDcePass.Create);
  AManager.RegisterPass(TMirInlinePass.Create);
  AManager.RegisterPass(TMirDeadArgPass.Create);
end;

end.
