unit nextpas.compiler.sema.semantic_model;

{$mode objfpc}{$H+}

interface

uses
  np_semantic_model;

type
  TSemanticHirValueClass = np_semantic_model.TSemanticHirValueClass;
  TSemanticScalarKind = np_semantic_model.TSemanticScalarKind;
  TSemanticScalarTypeFact = np_semantic_model.TSemanticScalarTypeFact;
  TSemanticHirExprKind = np_semantic_model.TSemanticHirExprKind;
  TSemanticHirChildVec = np_semantic_model.TSemanticHirChildVec;
  TSemanticHirExpr = np_semantic_model.TSemanticHirExpr;
  TSemanticSymbol = np_semantic_model.TSemanticSymbol;
  TGenericParentRef = np_semantic_model.TGenericParentRef;
  TSemanticType = np_semantic_model.TSemanticType;
  TTypedHirNode = np_semantic_model.TTypedHirNode;
  TSemanticBinding = np_semantic_model.TSemanticBinding;
  TRuntimeContract = np_semantic_model.TRuntimeContract;
  TSemanticForeignProcedureBinding = np_semantic_model.TSemanticForeignProcedureBinding;
  TSemanticLibraryRequest = np_semantic_model.TSemanticLibraryRequest;
  TFieldMeta = np_semantic_model.TFieldMeta;
  TSemanticFieldMetaVec = np_semantic_model.TSemanticFieldMetaVec;
  TVmtSlot = np_semantic_model.TVmtSlot;
  TSemanticVmtSlotVec = np_semantic_model.TSemanticVmtSlotVec;
  TPropertyMeta = np_semantic_model.TPropertyMeta;
  TSemanticPropertyMetaVec = np_semantic_model.TSemanticPropertyMetaVec;
  TInterfaceSlotMeta = np_semantic_model.TInterfaceSlotMeta;
  TSemanticInterfaceSlotMetaVec = np_semantic_model.TSemanticInterfaceSlotMetaVec;
  TSemanticStringVec = np_semantic_model.TSemanticStringVec;
  TTypeMetadata = np_semantic_model.TTypeMetadata;
  TSemanticConstValue = np_semantic_model.TSemanticConstValue;
  TSemanticVarInitValue = np_semantic_model.TSemanticVarInitValue;
  TSemanticFloatConstValue = np_semantic_model.TSemanticFloatConstValue;
  TSemanticStringConstValue = np_semantic_model.TSemanticStringConstValue;
  TScopeKind = np_semantic_model.TScopeKind;
  TSemanticScope = np_semantic_model.TSemanticScope;

implementation

end.
