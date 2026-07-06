{**
 * np_sema_hir_lowering.pas
 *
 * AST→HIR 降级模块 — 从 TSemanticAnalyzer 提取
 *
 * 对标：rustc 的 hir_lowering, FPC 的 code generation
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
  np_sema_overload,
  np_base_types;

type
  { HIR 降级上下文 }
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

{ 标签发射 }
procedure EmitBlockLabel(var Ctx: TSemaHirLoweringContext; const ALabel: string);
procedure EmitGotoLabel(var Ctx: TSemaHirLoweringContext; const ALabel: string);

{ 运行时表达式附着 }
procedure AttachRuntimeReturnExpr(const Ctx: TSemaHirLoweringContext;
  const AHirNodeId: LongInt; const AReturnVarName: string);

{ 诊断发射 }
procedure EmitSemaError(const Ctx: TSemaHirLoweringContext;
  const ACode: string; const AMessage: string; const AByteOffset: LongInt);

implementation

{ === 标签发射 === }

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

{ === 运行时表达式附着 === }

procedure AttachRuntimeReturnExpr(const Ctx: TSemaHirLoweringContext;
  const AHirNodeId: LongInt; const AReturnVarName: string);
var
  Children: array of LongInt;
  ExprId, SymbolId: LongInt;
begin
  if (AHirNodeId <= 0) or (AReturnVarName = '') then
    Exit;
  SymbolId := Ctx.Model.FindSymbolByName(AReturnVarName);
  if SymbolId <= 0 then
    Exit;
  SetLength(Children, 0);
  ExprId := Ctx.Model.AddHirExpr(
    shekSymbolValue, 0,
    SymbolId, Children, 0, 0.0, '', '', 0, shvcScalar
  );
  Ctx.Model.SetTypedHirNodeExprId(AHirNodeId, ExprId);
end;

{ === 诊断发射 === }

procedure EmitSemaError(const Ctx: TSemaHirLoweringContext;
  const ACode: string; const AMessage: string; const AByteOffset: LongInt);
var
  EmptyPayload: TDiagnosticPayload;
begin
  EmptyPayload.Kind := dpkNone;
  Ctx.Diagnostics.EmitErrorWithPayload(
    ACode, 'sema',
    BuildCoreSourceSpan(Ctx.RootFileId, AByteOffset, 0),
    AMessage, EmptyPayload);
end;

end.
