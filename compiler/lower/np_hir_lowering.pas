{**
 * np_hir_lowering.pas
 *
 * AST→HIR 降级模块 — 从 sema/ 提取到 lower/ 桥接层
 *
 * 职责：将 AST 节点降级为 HIR 表达式/语句
 * 依赖方向：sema → lower → ir
 *
 * 对标：rustc 的 hir_lowering, FPC 的 code generation
 *}

unit np_hir_lowering;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  nextpas.compiler.syntax.green_tree,
  np_unit_graph,
  nextpas.compiler.syntax.ast_facade,
  np_semantic_model,
  np_sema_builtins,
  np_sema_type_check,
  np_sema_runtime_vars,
  np_hir_model,
  np_source_database,
  nextpas.compiler.diagnostics.sink,
  np_sema_overload,
  np_base_types;

type
  { 回调函数类型 — 用于桥接尚未提取到独立模块的方法 }

  TBuildTargetAddressExprFn = function(const Ctx: Pointer; const ATargetNode: TGreenNode;
    out AExprId: LongInt): Boolean;
  TBuildClassBaseAddressExprFn = function(const Ctx: Pointer; const ABaseName,
    AClassName: string; out AExprId: LongInt): Boolean;
  TBuildByRefArgumentAddressExprFn = function(const Ctx: Pointer;
    const AArgNode: TGreenNode; out AExprId: LongInt): Boolean;
  TBuildRuntimeArrayElementAddressHirExprFn = function(const Ctx: Pointer;
    const ANode: TGreenNode; out AExprId: LongInt): Boolean;
  TEvaluateIntegerConstantFn = function(const Ctx: Pointer; const ANode: TGreenNode;
    out AValue: Int64): Boolean;
  TInferExpressionTypeFn = function(const Ctx: Pointer;
    const ANode: TGreenNode): LongInt;
  TTypeIdForVariableFn = function(const Ctx: Pointer;
    const AName: string): LongInt;
  TTryGetDirectCallContractFn = function(const Ctx: Pointer; const ACallNode: TGreenNode;
    out ACalleeName, AParamKinds: string; out AResultTypeId: LongInt): Boolean;
  TTryGetDispatchedMemberCallContractFn = function(const Ctx: Pointer;
    const ACallNode: TGreenNode; out AExprKind: TSemanticHirExprKind;
    out AReceiverVarName, ACalleeName, AParamKinds: string;
    out ASlotIndex, AReturnTypeId: LongInt): Boolean;
  TTryGetOrdinaryMemberCallContractFn = function(const Ctx: Pointer;
    const ACallNode: TGreenNode; out AReceiverVarName, ACalleeName,
    AParamKinds: string; out AResultTypeId: LongInt): Boolean;
  TTryGetTypeCastTargetTypeIdFn = function(const Ctx: Pointer;
    const ACallNode: TGreenNode; out ATypeId: LongInt): Boolean;
  TTryGetIntrinsicExprNameFn = function(const Ctx: Pointer;
    const ACallNode: TGreenNode; out AIntrinsicName: string): Boolean;
  TResolveTypeIdForOwnerFn = function(const Ctx: Pointer; const ATypeName,
    AOwnerUnitId: string): LongInt;
  TEncodeRuntimeIntExprFoldFn = function(const Ctx: Pointer;
    const ANode: TGreenNode; out ABlob: string): Boolean;
  TCanEmitStrCompareOperandFn = function(const Ctx: Pointer;
    const ANode: TGreenNode; AAllowOwned: Boolean): Boolean;
  TEmitStrCompareOperandFn = function(const Ctx: Pointer;
    const ANode: TGreenNode; AAllowOwned: Boolean;
    out ABlob: string): Boolean;

  { HIR 降级上下文 }
  TSemaHirLoweringContext = record
    { 数据成员 }
    Model: TSemanticModel;
    UnitGraph: TUnitGraph;
    RootAst: TAstFacade;
    CurrentProcessingUnitId: string;
    CurrentScopeId: LongInt;
    ProcedureBodies: TProcedureBodyVec;
    ImportedUnitOwners: TSemaImportedOwnerVec;
    ImportedUnitTrees: TSemaImportedTreeVec;
    BuiltinRegistry: TBuiltinRegistry;
    HirModule: THIRModule;
    Diagnostics: TDiagnosticsSink;
    RootFileId: TSourceFileId;
    BlockLabelCounter: LongInt;
    CurrentMethodClass: string;
    CurrentRetVarName: string;
    RuntimeVars: TSemaRuntimeVarRegistry;
    CurrentBlockTerminated: Boolean;
    { 回调 — 尚未提取到独立模块的方法 }
    CallbackCtx: Pointer;
    BuildTargetAddressExpr: TBuildTargetAddressExprFn;
    BuildClassBaseAddressExpr: TBuildClassBaseAddressExprFn;
    BuildByRefArgumentAddressExpr: TBuildByRefArgumentAddressExprFn;
    BuildRuntimeArrayElementAddressHirExpr: TBuildRuntimeArrayElementAddressHirExprFn;
    EvaluateIntegerConstant: TEvaluateIntegerConstantFn;
    InferExpressionType: TInferExpressionTypeFn;
    TypeIdForVariable: TTypeIdForVariableFn;
    TryGetDirectCallContract: TTryGetDirectCallContractFn;
    TryGetDispatchedMemberCallContract: TTryGetDispatchedMemberCallContractFn;
    TryGetOrdinaryMemberCallContract: TTryGetOrdinaryMemberCallContractFn;
    TryGetTypeCastTargetTypeId: TTryGetTypeCastTargetTypeIdFn;
    TryGetIntrinsicExprName: TTryGetIntrinsicExprNameFn;
    ResolveTypeIdForOwner: TResolveTypeIdForOwnerFn;
    EncodeRuntimeIntExprFold: TEncodeRuntimeIntExprFoldFn;
    CanEmitStrCompareOperand: TCanEmitStrCompareOperandFn;
    EmitStrCompareOperand: TEmitStrCompareOperandFn;
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

{ AST→HIR 布尔表达式折叠 }
function EncodeRuntimeBoolExprFold(const Ctx: TSemaHirLoweringContext;
  const ANode: TGreenNode; out ABlob: string;
  const AAllowOwnedStringCompare: Boolean): Boolean;

{ AST→HIR 表达式降级 }
function BuildRuntimeScalarHirExpr(const Ctx: TSemaHirLoweringContext;
  const ANode: TGreenNode; out AExprId: LongInt): Boolean;

{ 运行时变量查询 }
function HirLowering_IsRuntimeStrVar(const Ctx: TSemaHirLoweringContext;
  const AName: string): Boolean;

implementation

{ === 标签发射 === }

{$I np_hir_lowering_helpers.inc}

{$I np_hir_lowering_scalar.inc}

{$I np_hir_lowering_bool.inc}
end.
