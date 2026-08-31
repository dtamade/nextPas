unit nextpas.compiler.lower.hir_lowering;

{$mode objfpc}{$H+}

interface

uses
  np_hir_lowering;

type
  TBuildTargetAddressExprFn = np_hir_lowering.TBuildTargetAddressExprFn;
  TBuildClassBaseAddressExprFn = np_hir_lowering.TBuildClassBaseAddressExprFn;
  TBuildByRefArgumentAddressExprFn = np_hir_lowering.TBuildByRefArgumentAddressExprFn;
  TBuildRuntimeArrayElementAddressHirExprFn = np_hir_lowering.TBuildRuntimeArrayElementAddressHirExprFn;
  TEvaluateIntegerConstantFn = np_hir_lowering.TEvaluateIntegerConstantFn;
  TInferExpressionTypeFn = np_hir_lowering.TInferExpressionTypeFn;
  TTypeIdForVariableFn = np_hir_lowering.TTypeIdForVariableFn;
  TTryGetDirectCallContractFn = np_hir_lowering.TTryGetDirectCallContractFn;
  TTryGetDispatchedMemberCallContractFn = np_hir_lowering.TTryGetDispatchedMemberCallContractFn;
  TTryGetOrdinaryMemberCallContractFn = np_hir_lowering.TTryGetOrdinaryMemberCallContractFn;
  TTryGetTypeCastTargetTypeIdFn = np_hir_lowering.TTryGetTypeCastTargetTypeIdFn;
  TTryGetIntrinsicExprNameFn = np_hir_lowering.TTryGetIntrinsicExprNameFn;
  TResolveTypeIdForOwnerFn = np_hir_lowering.TResolveTypeIdForOwnerFn;
  TEncodeRuntimeIntExprFoldFn = np_hir_lowering.TEncodeRuntimeIntExprFoldFn;
  TCanEmitStrCompareOperandFn = np_hir_lowering.TCanEmitStrCompareOperandFn;
  TEmitStrCompareOperandFn = np_hir_lowering.TEmitStrCompareOperandFn;
  TSemaHirLoweringContext = np_hir_lowering.TSemaHirLoweringContext;

implementation

end.
