{**
 * np_sema_hir_lowering.pas
 *
 * AST→HIR 降级模块 — 从 TSemanticAnalyzer 提取
 *}

unit np_sema_hir_lowering;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  np_green_tree,
  np_unit_graph,
  np_ast_facade,
  np_semantic_model,
  np_sema_builtins,
  np_sema_type_check,
  np_hir_model,
  np_source_database,
  np_diagnostics_sink,
  np_sema_overload;

type
  TSemaHirLoweringContext = record
    Model: TSemanticModel;
    UnitGraph: TUnitGraph;
    RootAst: TAstFacade;
    CurrentProcessingUnitId: string;
    CurrentScopeId: LongInt;
    ProcedureBodies: TProcedureBodyArray;
    ImportedUnitOwners: array of string;
    ImportedUnitTrees: array of TGreenTree;
    BuiltinRegistry: TBuiltinRegistry;
    HirModule: THIRModule;
    Diagnostics: TDiagnosticsSink;
    RootFileId: TSourceFileId;
    BlockLabelCounter: LongInt;
    CurrentMethodClass: string;
    CurrentBlockTerminated: Boolean;
  end;

procedure EmitBlockLabel(var Ctx: TSemaHirLoweringContext; const ALabel: string);
procedure EmitGotoLabel(var Ctx: TSemaHirLoweringContext; const ALabel: string);

implementation

procedure EmitBlockLabel(var Ctx: TSemaHirLoweringContext; const ALabel: string);
begin
  Ctx.Model.AddTypedHirNode('block-label-runtime', ALabel, 0, 0, ALabel);
  Ctx.CurrentBlockTerminated := False;
end;

procedure EmitGotoLabel(var Ctx: TSemaHirLoweringContext; const ALabel: string);
begin
  if Ctx.CurrentBlockTerminated then
    Exit;
  Ctx.Model.AddTypedHirNode('br-runtime', ALabel, 0, 0, ALabel);
  Ctx.CurrentBlockTerminated := True;
end;

end.
