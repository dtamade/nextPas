unit nextpas.compiler.ir.hir.lowering;

{$mode objfpc}{$H+}

interface

uses
  nextpas.compiler.syntax.green_tree,
  nextpas.compiler.lower.hir_lowering;

type
  TBuildTargetAddressExprFn = nextpas.compiler.lower.hir_lowering.TBuildTargetAddressExprFn;
  TBuildClassBaseAddressExprFn = nextpas.compiler.lower.hir_lowering.TBuildClassBaseAddressExprFn;
  TBuildByRefArgumentAddressExprFn = nextpas.compiler.lower.hir_lowering.TBuildByRefArgumentAddressExprFn;
  TBuildRuntimeArrayElementAddressHirExprFn = nextpas.compiler.lower.hir_lowering.TBuildRuntimeArrayElementAddressHirExprFn;
  TEvaluateIntegerConstantFn = nextpas.compiler.lower.hir_lowering.TEvaluateIntegerConstantFn;
  TInferExpressionTypeFn = nextpas.compiler.lower.hir_lowering.TInferExpressionTypeFn;
  TTypeIdForVariableFn = nextpas.compiler.lower.hir_lowering.TTypeIdForVariableFn;
  TTryGetDirectCallContractFn = nextpas.compiler.lower.hir_lowering.TTryGetDirectCallContractFn;
  TTryGetDispatchedMemberCallContractFn = nextpas.compiler.lower.hir_lowering.TTryGetDispatchedMemberCallContractFn;
  TTryGetOrdinaryMemberCallContractFn = nextpas.compiler.lower.hir_lowering.TTryGetOrdinaryMemberCallContractFn;
  TTryGetTypeCastTargetTypeIdFn = nextpas.compiler.lower.hir_lowering.TTryGetTypeCastTargetTypeIdFn;
  TTryGetIntrinsicExprNameFn = nextpas.compiler.lower.hir_lowering.TTryGetIntrinsicExprNameFn;
  TResolveTypeIdForOwnerFn = nextpas.compiler.lower.hir_lowering.TResolveTypeIdForOwnerFn;
  TEncodeRuntimeIntExprFoldFn = nextpas.compiler.lower.hir_lowering.TEncodeRuntimeIntExprFoldFn;
  TCanEmitStrCompareOperandFn = nextpas.compiler.lower.hir_lowering.TCanEmitStrCompareOperandFn;
  TEmitStrCompareOperandFn = nextpas.compiler.lower.hir_lowering.TEmitStrCompareOperandFn;
  TTypeMetaIsInterfaceFn = nextpas.compiler.lower.hir_lowering.TTypeMetaIsInterfaceFn;
  TTypeMetaInterfacesFn = nextpas.compiler.lower.hir_lowering.TTypeMetaInterfacesFn;
  TTypeMetaFieldIndexFn = nextpas.compiler.lower.hir_lowering.TTypeMetaFieldIndexFn;
  TSemaHirLoweringContext = nextpas.compiler.lower.hir_lowering.TSemaHirLoweringContext;
procedure EmitBlockLabel(var Ctx: TSemaHirLoweringContext; const ALabel: string);
procedure EmitGotoLabel(var Ctx: TSemaHirLoweringContext; const ALabel: string);
procedure AttachRuntimeReturnExpr(const Ctx: TSemaHirLoweringContext; const AHirNodeId: LongInt; const AReturnVarName: string);
procedure EmitSemaError(const Ctx: TSemaHirLoweringContext; const ACode: string; const AMessage: string; const AByteOffset: LongInt);
function EncodeRuntimeBoolExprFold(const Ctx: TSemaHirLoweringContext; const ANode: TGreenNode; out ABlob: string; const AAllowOwnedStringCompare: Boolean): Boolean;
function BuildRuntimeScalarHirExpr(const Ctx: TSemaHirLoweringContext; const ANode: TGreenNode; out AExprId: LongInt): Boolean;
function HirLowering_IsRuntimeStrVar(const Ctx: TSemaHirLoweringContext; const AName: string): Boolean;

implementation

procedure EmitBlockLabel(var Ctx: TSemaHirLoweringContext; const ALabel: string);
begin
  nextpas.compiler.lower.hir_lowering.EmitBlockLabel(Ctx, ALabel);
end;

procedure EmitGotoLabel(var Ctx: TSemaHirLoweringContext; const ALabel: string);
begin
  nextpas.compiler.lower.hir_lowering.EmitGotoLabel(Ctx, ALabel);
end;

procedure AttachRuntimeReturnExpr(const Ctx: TSemaHirLoweringContext; const AHirNodeId: LongInt; const AReturnVarName: string);
begin
  nextpas.compiler.lower.hir_lowering.AttachRuntimeReturnExpr(Ctx, AHirNodeId, AReturnVarName);
end;

procedure EmitSemaError(const Ctx: TSemaHirLoweringContext; const ACode: string; const AMessage: string; const AByteOffset: LongInt);
begin
  nextpas.compiler.lower.hir_lowering.EmitSemaError(Ctx, ACode, AMessage, AByteOffset);
end;

function EncodeRuntimeBoolExprFold(const Ctx: TSemaHirLoweringContext; const ANode: TGreenNode; out ABlob: string; const AAllowOwnedStringCompare: Boolean): Boolean;
begin
  Result := nextpas.compiler.lower.hir_lowering.EncodeRuntimeBoolExprFold(Ctx, ANode, ABlob, AAllowOwnedStringCompare);
end;

function BuildRuntimeScalarHirExpr(const Ctx: TSemaHirLoweringContext; const ANode: TGreenNode; out AExprId: LongInt): Boolean;
begin
  Result := nextpas.compiler.lower.hir_lowering.BuildRuntimeScalarHirExpr(Ctx, ANode, AExprId);
end;

function HirLowering_IsRuntimeStrVar(const Ctx: TSemaHirLoweringContext; const AName: string): Boolean;
begin
  Result := nextpas.compiler.lower.hir_lowering.HirLowering_IsRuntimeStrVar(Ctx, AName);
end;

end.