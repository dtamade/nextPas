{**
 * nextpas.compiler.ir.mir.pass.registry.pas — MIR Pass 注册表
 *
 * 创建并注册所有 MIR 优化 Pass 到 TMirPassManager。
 *
 * 使用方式：
 *   PM := TMirPassManager.Create;
 *   RegisterAllMirPasses(PM);
 *   PM.RunAll(Module);
 *   PM.Free;
 *}

unit nextpas.compiler.ir.mir.pass.registry;

{$mode objfpc}{$H+}

interface

uses
  nextpas.compiler.ir.mir.optimize,
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
  nextpas.compiler.ir.mir.pass.vectorize,
  nextpas.compiler.ir.mir.opt_level;

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
