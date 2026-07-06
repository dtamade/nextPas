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
  np_mir_pass_deadarg,
  np_mir_pass_licm,
  np_mir_pass_escape,
  np_mir_pass_tailcall,
  np_mir_pass_devirt,
  np_mir_pass_inline_heuristic,
  np_mir_pass_vectorize,
  np_mir_opt_level;

{ 注册所有 MIR 优化 Pass（默认 O2） }
procedure RegisterAllMirPasses(AManager: TMirPassManager);

{ 按优化级别注册 Pass }
procedure RegisterMirPassesForLevel(
  AManager: TMirPassManager;
  const AOptLevel: string
);

implementation

procedure RegisterAllMirPasses(AManager: TMirPassManager);
begin
  RegisterMirPassesForLevel(AManager, 'O2');
end;

procedure RegisterMirPassesForLevel(
  AManager: TMirPassManager;
  const AOptLevel: string
);
begin
  RegisterPassesForLevel(AManager, ParseOptLevel(AOptLevel));
end;

end.
