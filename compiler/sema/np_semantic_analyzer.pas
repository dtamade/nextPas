unit np_semantic_analyzer;

{$mode objfpc}{$H+}
{$UNITPATH .}
{$UNITPATH ../diagnostics}
{$UNITPATH ../frontend}
{$UNITPATH ../syntax}
{$UNITPATH ../../core/src}

interface

uses
  np_ast_facade, np_base_types, np_diagnostics_sink, np_preprocessor,
  np_source_database, np_unit_graph, np_semantic_model, np_green_tree, np_lexer,
  np_hir_types, np_sema_name_set, np_sema_builtins, np_sema_overload,
  np_sema_type_check, np_sema_hir_lowering, np_sema_runtime_vars,
  np_sema_string_ownership,
  nextpas.core.collections.vec;

type
  TStringVec = specialize TVec<string>;

  TGenericCacheEntry = record
    Key: string;
    TypeId: LongInt;
  end;

  TGenericCacheVec = specialize TVec<TGenericCacheEntry>;

  TParamSnapshot = record
    Name: string;
    HadValue: Boolean;
    PriorValue: Int64;
  end;
  TParamSnapshots = array of TParamSnapshot;

  TTypeIdArray = array of LongInt;

  TPendingSignatureEntry = record
    SymbolId: LongInt;
    GenericName: string;
    MethodShortName: string;
    OwnerUnitId: string;
    ParamNames: array of string;
    ArgTypes: array of string;
  end;

  TSemanticAnalyzer = class
  private
    FRootAst: TAstFacade;
    FUnitGraph: TUnitGraph;
    FDiagnostics: TDiagnosticsSink;
    FRootFileId: TSourceFileId;
    FNoFold: Boolean;
    FModel: TSemanticModel;
    FProcedureBodies: TProcedureBodyArray;
    FCompilerProcNames: array of string;
    FCompilerProcCount: LongInt;
    FGenericWorkQueue: array of LongInt;
    FGenericWorkCount: LongInt;
    FGenericCache: TGenericCacheVec;
    FPendingSignatures: array of TPendingSignatureEntry;
    FInliningStack: TStringVec;
    FBlockLabelCounter: LongInt;
    FCurrentBlockTerminated: Boolean;
    FCurrentScopeId: LongInt;
    FCurrentProcessingUnitId: string;
    FBreakLabels: TStringVec;
    FContinueLabels: TStringVec;
    FBuiltinRegistry: TBuiltinRegistry;
    FRuntimeVars: TSemaRuntimeVarRegistry;
    FCurrentMethodClass: string;
    FCurrentRetVarName: string;
    FCurrentOwnedStringReturn: Boolean;
    FImportedUnitTrees: array of TGreenTree;
    FImportedUnitOwners: array of string;
    procedure RegisterRuntimeVar(const AName: string);
    procedure RegisterRuntimeStrVar(const AName: string);
    procedure RegisterOwnedRuntimeStrVar(const AName: string);
    procedure RegisterBorrowedRuntimeStrVar(const AName: string);
    procedure RegisterOwnedStringReturnFunc(const AName: string);
    procedure ClearPendingStringTempReleases;
    procedure QueuePendingStringTempRelease(const ATempName, ASourceName: string);
    procedure EmitPendingStringTempReleases;
    procedure RegisterConcatOwnedStringReturnConsumers(
      const AConcatNode: TGreenNode; var AChanged: Boolean);
    procedure RegisterRuntimeArrVar(const AName: string);
    procedure RegisterBorrowedRuntimeArrVar(const AName: string);
    procedure RegisterClassVar(const AName, AClassName: string);
    procedure RegisterRecordVar(const AName, ATypeName: string);
    procedure RegisterPointerVar(const AName, APointeeTypeName: string);
    procedure RegisterVarParam(const AName: string);
    procedure RegisterPtrReturnFunc(const AName, AClassName: string);
    procedure RegisterImportedUnitTree(const ATree: TGreenTree;
      const AOwnerUnitId: string);
    function IsRuntimeVar(const AName: string): Boolean;
    function IsRuntimeStrVar(const AName: string): Boolean;
    function IsOwnedRuntimeStrVar(const AName: string): Boolean;
    function IsBorrowedRuntimeStrVar(const AName: string): Boolean;
    function IsOwnedStringReturnFunc(const AName: string): Boolean;
    function IsRootOwnedStringReturnCandidate(const AEntry: TProcedureBodyEntry;
      const AIsStrReturn: Boolean): Boolean;
    function DeclReturnsString(const ADecl: TGreenNode): Boolean;
    function DeclaresStringLocal(const ADecl: TGreenNode;
      const AName: string): Boolean;
    function StringReturnFunctionNameFromNode(const ANode: TGreenNode;
      out AName: string): Boolean;
    function FunctionCallReturnsString(const ANode: TGreenNode): Boolean;
    function MemberCallReturnsString(const ANode: TGreenNode): Boolean;
    function TypeIdIsManagedString(const ATypeId: LongInt): Boolean;
    function IsSupportedOwnedStringReturnIdentifierTarget(
      const ATargetNode: TGreenNode): Boolean;
    function IsSupportedOwnedStringReturnStoreTarget(
      const ATargetNode: TGreenNode): Boolean;
    function IsSupportedOwnedStringReturnConsumerTarget(
      const ATargetNode: TGreenNode): Boolean;
    function AssignmentOwnsStringReturn(const ANode: TGreenNode;
      const AEntry: TProcedureBodyEntry): Boolean;
    function AssignmentOwnsTopLevelStringReturn(const ANode: TGreenNode): Boolean;
    function CallArgumentOwnsStringReturn(
      const ACallNode, AArgNode: TGreenNode; AArgPosition: LongInt;
      out AFuncName: string): Boolean;
    function DirectOwnedStringReturnAssignmentNode(const ANode: TGreenNode): Boolean;
    function IsSupportedOwnedStringReturnArgument(
      const ACallNode, AArgNode: TGreenNode; AArgPosition: LongInt): Boolean;
    function LengthArgumentOwnsStringReturn(
      const ANode: TGreenNode; out AFuncName: string): Boolean;
    function IsSupportedOwnedStringReturnLengthArgument(
      const ANode: TGreenNode; out AFuncName: string): Boolean;
    function EmitOwnedStringLengthTemp(const ANode: TGreenNode;
      out ABlob: string): Boolean;
    function EmitOwnedStringConcatLengthTemp(const ANode: TGreenNode;
      out ABlob: string): Boolean;
    function CopyArgumentOwnsStringReturn(
      const ANode: TGreenNode; out AFuncName: string): Boolean;
    function IsSupportedOwnedStringReturnCopyArgument(
      const ANode: TGreenNode; out AFuncName: string): Boolean;
    function EmitOwnedStringCopyTemp(const ACopyNode: TGreenNode;
      const ADestName: string; out ATempName: string): Boolean;
    function WriteArgumentOwnsStringReturn(
      const ANode: TGreenNode; out AFuncName: string): Boolean;
    function IsSupportedOwnedStringReturnWriteArgument(
      const ANode: TGreenNode; out AFuncName: string): Boolean;
    function EmitOwnedStringWriteTemp(
      const ANode: TGreenNode; out ATempName: string): Boolean;
    function EmitOwnedStringConcatWriteTemp(
      const ANode: TGreenNode; out ATempName: string): Boolean;
    function ConcatOperandOwnsStringReturn(
      const ANode: TGreenNode; out AFuncName: string): Boolean;
    function IsSupportedOwnedStringReturnConcatOperand(
      const ANode: TGreenNode; out AFuncName: string): Boolean;
    function ConcatExpressionConsumesOwnedStringReturnDeferred(
      const ANode: TGreenNode;
      const AInsideDirectOwnedAssignmentRhs: Boolean): Boolean;
    function CompareOperandOwnsStringReturn(
      const ANode: TGreenNode; out AFuncName: string): Boolean;
    function IsSupportedOwnedStringReturnCompareOperand(
      const ANode: TGreenNode; out AFuncName: string): Boolean;
    function BoolConditionHasSupportedOwnedStringCompare(
      const ANode: TGreenNode): Boolean;
    function CompareExpressionConsumesOwnedStringReturnDeferred(
      const ANode: TGreenNode): Boolean;
    function NodeConsumesOwnedStringReturnDeferred(const ANode: TGreenNode;
      const AInsideDirectOwnedAssignmentRhs: Boolean): Boolean;
    procedure ScanOwnedStringReturnConsumers(const ANode: TGreenNode;
      const AEntry: TProcedureBodyEntry; var AChanged: Boolean);
    procedure ScanTopLevelOwnedStringReturnConsumers(const ANode: TGreenNode;
      var AChanged: Boolean);
    procedure CheckDeferredOwnedStringReturnConsumers(const ANode: TGreenNode);
    procedure PreRegisterOwnedStringReturnConsumers;
    function IsRuntimeArrVar(const AName: string): Boolean;
    function IsBorrowedRuntimeArrVar(const AName: string): Boolean;
    function IsStaticRuntimeArrVar(const AName: string): Boolean;
    function DynArrayElemSizeOfVar(const AName: string): Int64;
    procedure EmitOwnedStringCleanupNodes(const AExceptName: string = '');
    procedure EmitOwnedDynArrayCleanupNodes;
    function IsManagedRecord(const ATypeName: string): Boolean;
    procedure EmitOwnedManagedRecordCleanupNodes;
    function IsRecordVar(const AName: string): Boolean;
    function IsVarParam(const AName: string): Boolean;
    function IsVarParamAtPosition(const ADecl: TGreenNode; APosition: LongInt): Boolean;
    function LookupClassVar(const AName: string): string;
    function LookupRecordVar(const AName: string): string;
    function LookupPointerVar(const AName: string): string;
    function LookupPtrReturnFunc(const AName: string): string;
    function ConcatTreeHasSupportedOwnedStringReturn(
      const ANode: TGreenNode): Boolean;
    function CanEmitStrConcatOperand(const ANode: TGreenNode): Boolean;
    function EmitStrConcatOperand(const ANode: TGreenNode;
      const ADestVar: string): string;
    function CanEmitStrCompareOperand(const ANode: TGreenNode;
      const AAllowOwnedStringReturn: Boolean): Boolean;
    function EmitStrCompareOperand(const ANode: TGreenNode;
      const AAllowOwnedStringReturn: Boolean; out ABlob: string): Boolean;
    function EncodeStrCallArgs(const ACallNode: TGreenNode;
      const ADestVar: string): string;
    function EncodeCallStatementArgs(
      const ACallName: string; const ACallNode, ADeclNode: TGreenNode): string;
    function NewBlockLabel(const APrefix: string): string;
    procedure FillOwnershipContext(out Ctx: TSemaOwnershipContext);
    procedure EmitBlockLabel(const ALabel: string);
    procedure EmitGotoLabel(const ALabel: string);
    procedure RegisterProcedureBody(const AName: string;
      const ABody: TGreenNode; const ADecl: TGreenNode;
      const AOwnerUnitId: string);
    function ProcedureBodyScopeIdForDecl(const ADecl: TGreenNode): LongInt;
    function ParamDeclTypeId(const AParamDecl: TGreenNode;
      const AOwnerUnitId: string): LongInt;
    // === overload resolution group (→ np_sema_overload.pas) ===
    function LookupProcedureBody(const AName: string;
      out ABody: TGreenNode; out ADecl: TGreenNode): Boolean;
    function LookupCallBindingDeclaration(const AName: string;
      const AArgCount: LongInt; const AArgTypeIds: TTypeIdArray;
      const AArgSignature: string;
      const AHasArgSignature: Boolean;
      const AHasTypeMismatchEvidence: Boolean;
      out AResolutionFailureKind: string;
      out ABody: TGreenNode;
      out ADecl: TGreenNode; out AOwnerUnitId: string): Boolean;
    function OwnerUnitAllowsProjectSourceDiagnostic(
      const AOwnerUnitId: string
    ): Boolean;
    function HasInstalledSourceImports: Boolean;
    function UnitDirectlyImports(
      const AOwnerUnitId: string;
      const AImportedUnitId: string
    ): Boolean;
    function IsCurrentlyInlining(const AName: string): Boolean;
    procedure PushInlining(const AName: string);
    procedure PopInlining;
    function CountDeclParams(const ADecl: TGreenNode): LongInt;
    function CountRequiredDeclParams(const ADecl: TGreenNode): LongInt;
    function DeclReturnTypeId(const ADecl: TGreenNode;
      const AOwnerUnitId: string): LongInt;
    function DeclAcceptsArgCount(const ADecl: TGreenNode;
      const AArgCount: LongInt): Boolean;
    function DeclParamSignatureMatchesArgs(const ADecl: TGreenNode;
      const AArgSignature: string; const AArgCount: LongInt): Boolean;
    function GetParamSignature(const ADecl: TGreenNode): string;
    function GetParamIdentitySignature(const ADecl: TGreenNode): string;
    function GetSubstitutedParamSignature(const ADecl: TGreenNode;
      const AParamNames, AArgTypes: array of string): string;
    function MangledName(const AName: string; AParamCount: LongInt): string;
    function MangledNameSig(const AName: string; const ASig: string): string;
    function HasOverload(const AName: string): Boolean;
    function LookupOverload(const AName: string; AArgCount: LongInt;
      out ABody: TGreenNode; out ADecl: TGreenNode): Boolean;
    function CallArgumentCount(const ACallNode: TGreenNode): LongInt;
    function CallArgumentTypeIds(const ACallNode: TGreenNode;
      out ATypeIds: TTypeIdArray): Boolean;
    function TypeIdArrayHasKnownTypes(const ATypeIds: TTypeIdArray): Boolean;
    function BareCallCalleeName(const ACallNode: TGreenNode): string;
    function IsIntrinsicExprName(const AName: string): Boolean;
    function TryGetTypeCastTargetTypeId(const ACallNode: TGreenNode;
      out ATargetTypeId: LongInt): Boolean;
    function TryGetIntrinsicExprName(const ACallNode: TGreenNode;
      out AName: string): Boolean;
    function IsWrappedCallChild(
      const AParent: TGreenNode;
      const AChild: TGreenNode
    ): Boolean;
    function IsImplicitSelfCallNode(const ACallNode: TGreenNode): Boolean;
    function IsQualifiedCallNode(const ACallNode: TGreenNode): Boolean;
    function ExtractDirectMemberCall(
      const ACallNode: TGreenNode;
      out AReceiverName: string;
      out AMemberName: string;
      out AMemberOffset: LongInt;
      out AArgCount: LongInt
    ): Boolean;
    function TypeIdForVariable(const AName: string): LongInt;
    function TypeIdForMemberReceiver(
      const AName: string;
      const ACurrentMethodClass: string;
      const ACurrentOwnerUnitId: string
    ): LongInt;
    function TryResolveTypeNameMemberCallTarget(
      const AReceiverName: string;
      const AMemberName: string;
      const AArgCount: LongInt;
      const AArgTypeIds: TTypeIdArray;
      const AArgSignature: string;
      const AHasArgSignature: Boolean;
      const AHasTypeMismatchEvidence: Boolean;
      out AReceiverTypeId: LongInt;
      out ATargetSymbolId: LongInt
    ): Boolean;
    function TypeSymbolForTypeId(
      const ATypeId: LongInt;
      out ASymbol: TSemanticSymbol
    ): Boolean;
    function ClassTypeHasKnownNonMethodMember(
      const AClassTypeId: LongInt;
      const AMemberName: string
    ): Boolean;
    function TypeIdHasKnownClassLayout(const ATypeId: LongInt): Boolean;
    function IsDeferredSystemObjectMember(const AMemberName: string): Boolean;
    function TypeMetaSize(const ATypeName: string): Int64;
    function TypeMetaIsRecord(const ATypeName: string): Boolean;
    function TypeMetaIsClass(const ATypeName: string): Boolean;
    function TypeMetaIsInterface(const ATypeName: string): Boolean;
    function TypeIsInterfaceByName(const ATypeName: string): Boolean;
    function TypeMetaFieldIndex(const ATypeName, AFieldName: string): Int64;
    function TypeMetaFieldIsStr(const ATypeName, AFieldName: string): Boolean;
    function TypeMetaFieldIsPtr(const ATypeName, AFieldName: string): Boolean;
    function TypeMetaFieldIsDynArray(const ATypeName, AFieldName: string): Boolean;
    function TypeMetaFieldDynArrayElemSize(
      const ATypeName, AFieldName: string): Int64;
    function TypeMetaVmtSlot(const ATypeName, AMethodName: string): Int64;
    function TypeMetaRetPtr(const ATypeName, AMethodName: string): Boolean;
    function TypeMetaRetStr(const ATypeName, AMethodName: string): Boolean;
    function TypeMetaParentClass(const ATypeName: string): string;
    function NextClassAncestorName(const ATypeName: string): string;
    function TypeMetaVmtCount(const ATypeName: string): Int64;
    function TypeMetaInterfaces(const ATypeName: string): string;
    function TypeSignatureForTypeId(const ATypeId: LongInt): string;
    function TypeIdHasStableScalarFact(const ATypeId: LongInt): Boolean;
    function CanonicalTypeId(const ATypeId: LongInt): LongInt;
    function IsPointerTypeId(const ATypeId: LongInt): Boolean;
    function DeclParamTypesExactMatch(const ADecl: TGreenNode;
      const AOwnerUnitId: string; const AArgTypeIds: TTypeIdArray;
      const AArgCount: LongInt): Boolean;
    function DeclParamTypesCompatibleMatch(const ADecl: TGreenNode;
      const AOwnerUnitId: string; const AArgTypeIds: TTypeIdArray;
      const AArgCount: LongInt): Boolean;
    function CallArgumentSignature(
      const ACallNode: TGreenNode;
      out ASignature: string
    ): Boolean;
    function ExpressionTypeFactIsStable(
      const ANode: TGreenNode;
      const ACurrentOwnerUnitId: string
    ): Boolean;
    function CallArgumentSignatureIsStable(
      const ACallNode: TGreenNode;
      const ACurrentOwnerUnitId: string
    ): Boolean;
    function MethodSymbolIdForExactClassTypeMember(
      const AClassTypeId: LongInt;
      const AMemberName: string;
      const AArgCount: LongInt;
      const AArgTypeIds: TTypeIdArray;
      const AArgSignature: string;
      const AHasArgSignature: Boolean;
      const AHasTypeMismatchEvidence: Boolean;
      const AAllowNoMatchingOverloadDiagnostic: Boolean;
      out AMethodNameFound: Boolean;
      out AResolutionFailureKind: string;
      out ACandidates: TOverloadCandidateArray
    ): LongInt;
    function MethodSymbolIdForClassTypeMember(
      const AClassTypeId: LongInt;
      const AMemberName: string;
      const AArgCount: LongInt;
      const AArgTypeIds: TTypeIdArray;
      const AArgSignature: string;
      const AHasArgSignature: Boolean;
      const AHasTypeMismatchEvidence: Boolean;
      out AResolutionFailureKind: string;
      out ACandidates: TOverloadCandidateArray
    ): LongInt;
    function TryRegisterMemberCallBinding(
      const ACallNode: TGreenNode;
      const ACurrentMethodClass: string;
      const ACurrentOwnerUnitId: string;
      out AResolutionFailureKind: string;
      out AFailureName: string;
      out AFailureOffset: LongInt;
      out AActualArgCount: LongInt;
      out ACandidates: TOverloadCandidateArray
    ): Boolean;
    function TryRegisterImplicitSelfBareMethodCallBinding(
      const ACallNode: TGreenNode;
      const ACurrentMethodClass: string;
      const ACurrentOwnerUnitId: string;
      out AResolutionFailureKind: string;
      out AFailureName: string;
      out AFailureOffset: LongInt
    ): Boolean;
    function BindCallArgs(const ADecl: TGreenNode;
      const ACallNode: TGreenNode;
      const ANameSkip: LongInt): TParamSnapshots;
    procedure RestoreCallArgs(const ASnapshots: TParamSnapshots);
    function EnsureUnitScope(const AOwnerUnitId: string): LongInt;
    function CallableSymbolIdForDeclaration(const ADecl: TGreenNode;
      const AOwnerUnitId: string): LongInt;
    procedure RegisterCallBinding(const ACallNode: TGreenNode;
      const ADecl: TGreenNode; const AOwnerUnitId: string);
    procedure SeedCallBindings;
    procedure SeedCallBindingsInNode(
      const ANode: TGreenNode;
      const ACurrentMethodClass: string;
      const ACurrentOwnerUnitId: string
    );
    function DuplicateImportName: string;
    procedure EmitSemaError(
      const ACode: string;
      const AMessage: string;
      const AByteOffset: LongInt
    );
    function IsSimpleIdentifierName(const AName: string): Boolean;
    function RegisterSymbol(
      const AName: string;
      const AKind: string;
      const AOwnerUnitId: string;
      const ATypeId: LongInt;
      const AByteOffset: LongInt
    ): LongInt;
    function IsBuiltinProcedure(const AName: string): Boolean; inline;
    function InferExpressionType(const ANode: TGreenNode): LongInt;
    function AreTypesCompatible(const ALhsTypeId, ARhsTypeId: LongInt): Boolean;
    procedure SeedBuiltinTypes;
    procedure SeedCachedTypeGaps;
    procedure AssignScopesToSymbols;
    procedure CheckDuplicateDeclarations;
    procedure CheckUndeclaredIdentifiers;
    procedure CheckIdentifiersInNode(const ANode: TGreenNode);
    procedure CheckTypeMismatches;
    procedure CheckTypeMismatchesInNode(const ANode: TGreenNode);
    procedure CheckUnusedSymbols;
    procedure CheckUnreachableCode;
    procedure CheckUnreachableInNode(const ANode: TGreenNode;
      var ATerminated: Boolean);
    procedure CheckDuplicateCaseLabels;
    procedure CheckCaseLabelsInNode(const ANode: TGreenNode);
    procedure SeedDeclarations;
    procedure CheckAssignmentTypes;
    procedure SeedUnitSymbolsAndHir;
    procedure SeedForeignProcedureBindings;
    procedure SeedRuntimeContracts;
    procedure RebindExplicitClassParents;
    function ResolveTypeId(const ATypeName: string): LongInt;
    function ResolveTypeIdForOwner(
      const ATypeName: string;
      const APreferredOwnerUnitId: string;
      const AAllowDirectImportSearch: Boolean = True
    ): LongInt;
    function ImplicitSystemObjectParentTypeId(const AClassName: string): LongInt;
    function FindSymbolByName(const AName: string): LongInt;
    procedure ProcessVarSection(const ANode: TGreenNode;
      const AOwnerUnitId: string);
    procedure ProcessConstSection(const ANode: TGreenNode;
      const AOwnerUnitId: string);
    procedure ProcessProcedureDecl(const ANode: TGreenNode;
      const AOwnerUnitId: string);
    procedure ProcessFunctionDecl(const ANode: TGreenNode;
      const AOwnerUnitId: string);
    procedure ProcessTypeSection(const ANode: TGreenNode;
      const AOwnerUnitId: string);
    procedure InstantiateGenericType(const AInstanceTypeId: LongInt;
      const ASpecText: string; const AOwnerUnitId: string);
    function ResolveOrInstantiateInlineGeneric(const ASpecText: string;
      const AOwnerUnitId: string): LongInt;
    procedure ProcessEnumType(const ANode: TGreenNode;
      const AOwnerUnitId: string; const ATypeId: LongInt);
    procedure ProcessRecordFields(const ANode: TGreenNode;
      const AOwnerUnitId: string; const ATypeId: LongInt);
    procedure ProcessClassFields(const ANode: TGreenNode;
      const AOwnerUnitId: string; const ATypeId: LongInt);
    procedure AppendWhereConstraint(const ATypeId: LongInt;
      const AWhereSpec: string);
    procedure ProcessInterfaceMethods(const ANode: TGreenNode;
      const AOwnerUnitId: string; const ATypeId: LongInt);
    procedure VerifyInterfaceImplementation(const AClassTypeId: LongInt;
      const AInterfaceList: string; const AOwnerUnitId: string);
    procedure RegisterInterfaceSlots(const AClassTypeId: LongInt;
      const AInterfaceList: string);
    function CheckSingleConstraint(const AArgType: string;
      const AConstraint: string): Boolean;
    procedure RegisterStructuredGenericParent(const ATypeId: LongInt;
      const AParentSpec: string; const AOwnerUnitId: string);
    procedure CompletePendingSignatures;
    procedure WalkDeclarations(const ANode: TGreenNode;
      const AOwnerUnitId: string);
    procedure WalkAssignmentStatements(const ANode: TGreenNode);
    procedure UnrollAssignmentForLoop(const ANode: TGreenNode);
    procedure UnrollAssignmentWhileLoop(const ANode: TGreenNode);
    procedure UnrollAssignmentRepeatLoop(const ANode: TGreenNode);
    function EvaluateIntegerConstant(const ANode: TGreenNode;
      out AValue: Int64): Boolean;
    function EvaluateFloatConstant(const ANode: TGreenNode;
      out AValue: Double): Boolean;
    function ArrayElementTypeNode(const AArrayTypeNode: TGreenNode): TGreenNode;
    function TryGetArrayTypeBounds(const AArrayTypeNode: TGreenNode;
      out ALow, AHigh, ALength: Int64): Boolean;
    function FindArrayTypeNodeForVarDecl(const AVarSection: TGreenNode;
      const ADeclIndex: LongInt): TGreenNode;
    procedure RegisterArrayVarMetadata(const AVarName: string;
      const AArrayTypeNode: TGreenNode; out AOperand: string);
    function EvaluateStringConstant(const ANode: TGreenNode;
      out AValue: string): Boolean;
    procedure WalkHaltCalls(const ANode: TGreenNode);
    procedure AttachRuntimeReturnExpr(const AHirNodeId: LongInt;
      const AReturnVarName: string);
    procedure AttachRuntimeConditionExpr(const AHirNodeId: LongInt;
      const ACondNode: TGreenNode);
    function BuildRuntimeArrayElementAddressHirExpr(const ANode: TGreenNode;
      out AExprId: LongInt): Boolean;
    function FindSymbolByNameAndType(const AName: string;
      const ATypeId: LongInt): LongInt;
    function EnsureSelfSymbolId(out ASelfTypeId: LongInt): LongInt;
    function LookupFieldMetaByTypeName(const ATypeName, AFieldName: string;
      out AOwnerTypeId: LongInt; out AFieldMeta: TFieldMeta): Boolean;
    function BuildRecordBaseAddressExpr(const ARecordName,
      ARecordTypeName: string; out AExprId: LongInt): Boolean;
    function BuildClassBaseAddressExpr(const ABaseName, AClassName: string;
      out AExprId: LongInt): Boolean;
    function BuildClassFieldTargetExpr(const ABaseName, AClassName,
      AFieldName: string; out AExprId: LongInt): Boolean;
    function TryClassFieldArrayAccess(const AArrayAccessNode: TGreenNode;
      out ABaseName, AClassName, AFieldName: string): Boolean;
    function TryCurrentClassFieldArrayAccess(
      const AArrayAccessNode: TGreenNode; out AFieldName: string): Boolean;
    function BuildClassFieldArrayElementTargetExpr(
      const AArrayAccessNode: TGreenNode; out AExprId: LongInt): Boolean;
    function ResolveArrayAccessElementTypeId(
      const AArrayAccessNode: TGreenNode; out AElementTypeId: LongInt): Boolean;
    function BuildByRefArgumentAddressExpr(const ATargetNode: TGreenNode;
      out AExprId: LongInt): Boolean;
    procedure AttachStatementCallExpr(const AHirNodeId: LongInt;
      const ACallNode: TGreenNode);
    function TryBuildLegacyParamKindsFromSignature(
      const AArgSignature: string; const AParamCount: LongInt;
      out AParamKinds: string): Boolean;
    function TryBuildLegacyParamKindsForDecl(const ADeclNode: TGreenNode;
      const AParamCount: LongInt; out AParamKinds: string): Boolean;
    function TryGetDirectCallContract(const ACallNode: TGreenNode;
      out ACalleeName, AParamKinds: string; out AReturnTypeId: LongInt): Boolean;
    function TryGetOrdinaryMemberCallContract(const ACallNode: TGreenNode;
      out AReceiverVarName, ACalleeName, AParamKinds: string;
      out AReturnTypeId: LongInt): Boolean;
    function FindTypeDeclNodeInRoot(const ARootNode: TGreenNode;
      const ATypeName: string; out ATypeDeclNode,
      ATypeBodyNode: TGreenNode): Boolean;
    function FindTypeDeclNode(const ATypeName, AOwnerUnitId: string;
      out ATypeDeclNode, ATypeBodyNode: TGreenNode): Boolean;
    function FindTypeMethodDecl(const ATypeName, AOwnerUnitId,
      AMethodName: string; const AArgCount: LongInt;
      const AArgSignature: string; const AHasArgSignature: Boolean;
      out ADeclNode: TGreenNode): Boolean;
    function TryGetDispatchedMemberCallContract(const ACallNode: TGreenNode;
      out AExprKind: TSemanticHirExprKind;
      out AReceiverVarName, ACalleeName, AParamKinds: string;
      out ASlotIndex, AReturnTypeId: LongInt): Boolean;
    function BuildTargetAddressExpr(const ATargetNode: TGreenNode;
      out AExprId: LongInt): Boolean;
    function BuildRuntimeScalarHirExpr(const ANode: TGreenNode;
      out AExprId: LongInt): Boolean;
    function EncodeRuntimeIntExprFold(const ANode: TGreenNode;
      out ABlob: string): Boolean;
    function EncodeRuntimeBoolExprFold(const ANode: TGreenNode;
      out ABlob: string;
      const AAllowOwnedStringCompare: Boolean = False): Boolean;
    procedure LowerRuntimeIfStatement(
      const AIfNode: TGreenNode; const ACondBlob: string);
    procedure LowerRuntimeWhileStatement(const ANode: TGreenNode);
    procedure LowerRuntimeForStatement(const ANode: TGreenNode);
    procedure LowerRuntimeRepeatStatement(const ANode: TGreenNode);
    procedure LowerRuntimeCaseStatement(const ANode: TGreenNode);
    procedure LowerRuntimeTryFinallyStatement(const ANode: TGreenNode);
    procedure LowerRuntimeTryExceptStatement(const ANode: TGreenNode);
    procedure UnrollHaltForLoop(const ANode: TGreenNode);
    procedure UnrollHaltWhileLoop(const ANode: TGreenNode);
    procedure UnrollHaltRepeatLoop(const ANode: TGreenNode);
    procedure SeedRuntimeVarDecls;
    procedure WalkRuntimeVarDecls(const ANode: TGreenNode);
    procedure SeedHaltCalls;
    procedure PreRegisterFunctionReturnTypes;
    procedure SeedFunctionBodies;
    procedure SeedUnitLifecycleBodies;
    procedure SeedImportedUnitBodies;
  public
    constructor Create(
      const ARootAst: TAstFacade;
      const AUnitGraph: TUnitGraph;
      const ADiagnostics: TDiagnosticsSink;
      const ARootFileId: TSourceFileId;
      const ANoFold: Boolean
    );
    destructor Destroy; override;
    procedure Analyze;
    function DetachModel: TSemanticModel;
    function Status: string;
  end;

implementation

uses
  nextpas.core.text.conv, nextpas.core.path, nextpas.core.fs.util,
  nextpas.core.system.contracts, np_symbol_cache;

type
  TStringArray = array of string;

  TCachedSymbolEntry = record
    Name: string;
    Kind: string;
    OwnerUnitId: string;
    ParamCount: LongInt;
    MinParamCount: LongInt;
    ParamSignature: string;
    TypeId: LongInt;
    TypeRefName: string;
    ByteOffset: LongInt;
  end;

  TCachedUnitSymbols = record
    SourcePath: string;
    FileAge: Int64;
    Symbols: array of TCachedSymbolEntry;
    SymbolCount: LongInt;
  end;

var
  GImportedUnitCache: array of TCachedUnitSymbols;
  GImportedUnitCacheCount: LongInt = 0;
  GDiskCache: TDiskSymbolCache = nil;

{ === Ownership bridge callbacks === }

function OwnershipBridge_LookupProcedureBody(const ACtx: Pointer;
  const AName: string; out ABody: TGreenNode; out ADecl: TGreenNode): Boolean;
begin
  Result := TSemanticAnalyzer(ACtx).LookupProcedureBody(AName, ABody, ADecl);
end;

function OwnershipBridge_DeclReturnsString(const ACtx: Pointer;
  const ADecl: TGreenNode): Boolean;
begin
  Result := TSemanticAnalyzer(ACtx).DeclReturnsString(ADecl);
end;

function OwnershipBridge_LookupClassVar(const ACtx: Pointer;
  const AName: string): string;
begin
  Result := TSemanticAnalyzer(ACtx).LookupClassVar(AName);
end;

function OwnershipBridge_TypeMetaRetStr(const ACtx: Pointer;
  const ATypeName, AMethodName: string): Boolean;
begin
  Result := TSemanticAnalyzer(ACtx).TypeMetaRetStr(ATypeName, AMethodName);
end;
function OwnershipBridge_IsRuntimeStrVar(const ACtx: Pointer;
  const AName: string): Boolean;
begin
  Result := TSemanticAnalyzer(ACtx).IsRuntimeStrVar(AName);
end;

function OwnershipBridge_IsOwnedStringReturnFunc(const ACtx: Pointer;
  const AName: string): Boolean;
begin
  Result := TSemanticAnalyzer(ACtx).IsOwnedStringReturnFunc(AName);
end;

procedure OwnershipBridge_RegisterOwnedStringReturnFunc(const ACtx: Pointer;
  const AName: string);
begin
  TSemanticAnalyzer(ACtx).RegisterOwnedStringReturnFunc(AName);
end;

function OwnershipBridge_IsRuntimeVar(const ACtx: Pointer;
  const AName: string): Boolean;
begin
  Result := TSemanticAnalyzer(ACtx).IsRuntimeVar(AName);
end;

procedure OwnershipBridge_RegisterRuntimeStrVar(const ACtx: Pointer;
  const AName: string);
begin
  TSemanticAnalyzer(ACtx).RegisterRuntimeStrVar(AName);
end;

procedure OwnershipBridge_RegisterRuntimeVar(const ACtx: Pointer;
  const AName: string);
begin
  TSemanticAnalyzer(ACtx).RegisterRuntimeVar(AName);
end;

function OwnershipBridge_HasOverload(const ACtx: Pointer;
  const AName: string): Boolean;
begin
  Result := TSemanticAnalyzer(ACtx).HasOverload(AName);
end;

function OwnershipBridge_EncodeRuntimeIntExprFold(const ACtx: Pointer;
  const ANode: TGreenNode; out ABlob: string): Boolean;
begin
  Result := TSemanticAnalyzer(ACtx).EncodeRuntimeIntExprFold(ANode, ABlob);
end;

function OwnershipBridge_IsVarParamAtPosition(const ACtx: Pointer;
  const ADecl: TGreenNode; APosition: LongInt): Boolean;
begin
  Result := TSemanticAnalyzer(ACtx).IsVarParamAtPosition(ADecl, APosition);
end;

function OwnershipBridge_DecodePascalStringLiteral(const ACtx: Pointer;
  const AText: string): string;
var
  Raw: string;
  Index: SizeInt;
begin
  Result := '';
  if Length(AText) < 2 then
    Exit;
  if (AText[1] <> '''') or (AText[Length(AText)] <> '''') then
    Exit;
  Raw := Copy(AText, 2, Length(AText) - 2);
  Index := 1;
  while Index <= Length(Raw) do
  begin
    if (Raw[Index] = '''') and (Index < Length(Raw)) and (Raw[Index + 1] = '''') then
    begin
      Result := Result + '''';
      Inc(Index, 2);
    end
    else
    begin
      Result := Result + Raw[Index];
      Inc(Index);
    end;
  end;
end;

function OwnershipBridge_IsBorrowedRuntimeStrVar(const ACtx: Pointer;
  const AName: string): Boolean;
begin
  Result := TSemanticAnalyzer(ACtx).IsBorrowedRuntimeStrVar(AName);
end;

function OwnershipBridge_IsBorrowedRuntimeArrVar(const ACtx: Pointer;
  const AName: string): Boolean;
begin
  Result := TSemanticAnalyzer(ACtx).IsBorrowedRuntimeArrVar(AName);
end;

function OwnershipBridge_IsStaticRuntimeArrVar(const ACtx: Pointer;
  const AName: string): Boolean;
begin
  Result := TSemanticAnalyzer(ACtx).IsStaticRuntimeArrVar(AName);
end;

function OwnershipBridge_DynArrayElemSizeOfVar(const ACtx: Pointer;
  const AName: string): Int64;
begin
  Result := TSemanticAnalyzer(ACtx).DynArrayElemSizeOfVar(AName);
end;

function OwnershipBridge_EvaluateStringConstant(const ACtx: Pointer;
  const ANode: TGreenNode; out AValue: string): Boolean;
begin
  Result := TSemanticAnalyzer(ACtx).EvaluateStringConstant(ANode, AValue);
end;

function OwnershipBridge_TypeMetaFieldIndex(const ACtx: Pointer;
  const ATypeName, AFieldName: string): Int64;
begin
  Result := TSemanticAnalyzer(ACtx).TypeMetaFieldIndex(ATypeName, AFieldName);
end;

function OwnershipBridge_TypeMetaFieldIsStr(const ACtx: Pointer;
  const ATypeName, AFieldName: string): Boolean;
begin
  Result := TSemanticAnalyzer(ACtx).TypeMetaFieldIsStr(ATypeName, AFieldName);
end;

procedure OwnershipBridge_EmitSemaError(const ACtx: Pointer;
  const ACode, AMessage: string; const AByteOffset: LongInt);
begin
  TSemanticAnalyzer(ACtx).EmitSemaError(ACode, AMessage, AByteOffset);
end;

procedure TSemanticAnalyzer.FillOwnershipContext(
  out Ctx: TSemaOwnershipContext);
begin
  Ctx.Model := FModel;
  Ctx.CurrentScopeId := FCurrentScopeId;
  Ctx.CurrentMethodClass := FCurrentMethodClass;
  Ctx.CurrentRetVarName := FCurrentRetVarName;
  Ctx.CurrentBlockTerminated := FCurrentBlockTerminated;
  Ctx.BlockLabelCounter := FBlockLabelCounter;
  Ctx.Diagnostics := FDiagnostics;
  Ctx.RootFileId := FRootFileId;
  Ctx.RootAst := FRootAst;
  Ctx.UnitGraph := FUnitGraph;
  Ctx.CurrentProcessingUnitId := FCurrentProcessingUnitId;
  Ctx.ProcedureBodies := FProcedureBodies;
  Ctx.RuntimeVars := FRuntimeVars;
  Ctx.CallbackCtx := Pointer(Self);
  Ctx.LookupProcedureBody := @OwnershipBridge_LookupProcedureBody;
  Ctx.DeclReturnsString := @OwnershipBridge_DeclReturnsString;
  Ctx.LookupClassVar := @OwnershipBridge_LookupClassVar;
  Ctx.TypeMetaRetStr := @OwnershipBridge_TypeMetaRetStr;
  Ctx.IsRuntimeStrVar := @OwnershipBridge_IsRuntimeStrVar;
  Ctx.IsOwnedStringReturnFunc := @OwnershipBridge_IsOwnedStringReturnFunc;
  Ctx.RegisterOwnedStringReturnFunc := @OwnershipBridge_RegisterOwnedStringReturnFunc;
  Ctx.IsRuntimeVar := @OwnershipBridge_IsRuntimeVar;
  Ctx.RegisterRuntimeStrVar := @OwnershipBridge_RegisterRuntimeStrVar;
  Ctx.RegisterRuntimeVar := @OwnershipBridge_RegisterRuntimeVar;
  Ctx.HasOverload := @OwnershipBridge_HasOverload;
  Ctx.EncodeRuntimeIntExprFold := @OwnershipBridge_EncodeRuntimeIntExprFold;
  Ctx.IsVarParamAtPosition := @OwnershipBridge_IsVarParamAtPosition;
  Ctx.DecodePascalStringLiteral := @OwnershipBridge_DecodePascalStringLiteral;
  Ctx.IsBorrowedRuntimeStrVar := @OwnershipBridge_IsBorrowedRuntimeStrVar;
  Ctx.IsBorrowedRuntimeArrVar := @OwnershipBridge_IsBorrowedRuntimeArrVar;
  Ctx.IsStaticRuntimeArrVar := @OwnershipBridge_IsStaticRuntimeArrVar;
  Ctx.DynArrayElemSizeOfVar := @OwnershipBridge_DynArrayElemSizeOfVar;
  Ctx.EvaluateStringConstant := @OwnershipBridge_EvaluateStringConstant;
  Ctx.TypeMetaFieldIndex := @OwnershipBridge_TypeMetaFieldIndex;
  Ctx.TypeMetaFieldIsStr := @OwnershipBridge_TypeMetaFieldIsStr;
  Ctx.EmitSemaError := @OwnershipBridge_EmitSemaError;
end;

function FindCachedUnit(const APath: string; AAge: Int64): LongInt;
var
  I: LongInt;
begin
  for I := 0 to GImportedUnitCacheCount - 1 do
    if SameText(GImportedUnitCache[I].SourcePath, APath) and
      (GImportedUnitCache[I].FileAge = AAge) then
      Exit(I);
  Result := -1;
end;

function ContainsString(
  const AItems: TStringArray;
  const AValue: string
): Boolean;
var
  Index: LongInt;
begin
  for Index := 0 to Length(AItems) - 1 do
    if AItems[Index] = AValue then
      Exit(True);

  Result := False;
end;

procedure AppendString(var AItems: TStringArray; const AValue: string);
var
  NextIndex: SizeInt;
begin
  NextIndex := Length(AItems);
  SetLength(AItems, NextIndex + 1);
  AItems[NextIndex] := AValue;
end;

function DecodePascalStringLiteral(const AText: string): string; forward;

function ParamNameIsByRef(const AName: string): Boolean;
begin
  Result := (Pos('var:', AName) = 1) or (Pos('out:', AName) = 1);
end;

function StripParamModifier(const AName: string): string;
begin
  Result := AName;
  if ParamNameIsByRef(AName) then
    Result := Copy(AName, 5, Length(AName));
end;

constructor TSemanticAnalyzer.Create(
  const ARootAst: TAstFacade;
  const AUnitGraph: TUnitGraph;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId;
  const ANoFold: Boolean
);
begin
  inherited Create;
  FRootAst := ARootAst;
  FUnitGraph := AUnitGraph;
  FDiagnostics := ADiagnostics;
  FRootFileId := ARootFileId;
  FNoFold := ANoFold;
  FModel := TSemanticModel.Create;
  FBlockLabelCounter := 0;
  FCurrentScopeId := 0;
  FBreakLabels := specialize TVec<string>.Create;
  FContinueLabels := specialize TVec<string>.Create;
  { FVarParamNames now managed by FRuntimeVars }
  FInliningStack := specialize TVec<string>.Create;
  FGenericCache := specialize TVec<TGenericCacheEntry>.Create;
  FBuiltinRegistry := TBuiltinRegistry.Create;
  FRuntimeVars := TSemaRuntimeVarRegistry.Create;
end;

function TSemanticAnalyzer.NewBlockLabel(const APrefix: string): string;
begin
  Inc(FBlockLabelCounter);
  Result := APrefix + IntToStr(FBlockLabelCounter);
end;

procedure TSemanticAnalyzer.RegisterRuntimeVar(const AName: string);
begin
  FRuntimeVars.RegisterRuntimeVar(AName);
end;

function TSemanticAnalyzer.IsRuntimeVar(const AName: string): Boolean;
begin
  Result := FRuntimeVars.IsRuntimeVar(AName);
end;

procedure TSemanticAnalyzer.RegisterRuntimeStrVar(const AName: string);
begin
  FRuntimeVars.RegisterRuntimeStrVar(AName);
end;

procedure TSemanticAnalyzer.RegisterOwnedRuntimeStrVar(const AName: string);
begin
  FRuntimeVars.RegisterOwnedRuntimeStrVar(AName);
end;

procedure TSemanticAnalyzer.RegisterBorrowedRuntimeStrVar(const AName: string);
begin
  FRuntimeVars.RegisterBorrowedRuntimeStrVar(AName);
end;

procedure TSemanticAnalyzer.RegisterOwnedStringReturnFunc(const AName: string);
begin
  FRuntimeVars.RegisterOwnedStringReturnFunc(AName);
end;

function TSemanticAnalyzer.IsRuntimeStrVar(const AName: string): Boolean;
var
  SymId: LongInt;
  TypeId: LongInt;
  TypeName: string;
begin
  { Check registered runtime string vars via FRuntimeVars }
  if FRuntimeVars.IsRuntimeStrVar(AName) then
    Exit(True);
  { Also accept any string-typed variable — they hold safe string values }
  SymId := FModel.FindSymbolByName(AName);
  if SymId > 0 then
  begin
    TypeId := FModel.SymbolAt(SymId - 1).TypeId;
    if TypeId > 0 then
    begin
      TypeName := FModel.TypeAt(TypeId - 1).Name;
      if SameText(TypeName, 'String') or SameText(TypeName, 'AnsiString') then
        Exit(True);
    end;
  end;
  Result := False;
end;

function TSemanticAnalyzer.IsOwnedRuntimeStrVar(const AName: string): Boolean;
begin
  Result := FRuntimeVars.IsOwnedRuntimeStrVar(AName);
end;

function TSemanticAnalyzer.IsBorrowedRuntimeStrVar(const AName: string): Boolean;
begin
  Result := FRuntimeVars.IsBorrowedRuntimeStrVar(AName);
end;

function TSemanticAnalyzer.IsOwnedStringReturnFunc(const AName: string): Boolean;
begin
  Result := FRuntimeVars.IsOwnedStringReturnFunc(AName);
end;

procedure TSemanticAnalyzer.ClearPendingStringTempReleases;
begin
  FRuntimeVars.ClearPendingStringTempReleases;
end;

procedure TSemanticAnalyzer.QueuePendingStringTempRelease(
  const ATempName, ASourceName: string);
begin
  FRuntimeVars.QueuePendingStringTempRelease(ATempName, ASourceName);
end;

procedure TSemanticAnalyzer.EmitPendingStringTempReleases;
var
  I: LongInt;
  TempNames: TStringArray;
  TempSources: TStringArray;
begin
  TempNames := FRuntimeVars.GetPendingStringTempNames;
  TempSources := FRuntimeVars.GetPendingStringTempSources;
  for I := High(TempNames) downto 0 do
    FModel.AddTypedHirNode('string-temp-release-runtime',
      TempSources[I], 0, 0, TempNames[I]);
  FRuntimeVars.ClearPendingStringTempReleases;
end;

procedure TSemanticAnalyzer.RegisterConcatOwnedStringReturnConsumers(
  const AConcatNode: TGreenNode; var AChanged: Boolean);
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  np_sema_string_ownership.RegisterConcatOwnedStringReturnConsumers(Ctx, AConcatNode, AChanged);
end;


function TSemanticAnalyzer.IsRootOwnedStringReturnCandidate(
  const AEntry: TProcedureBodyEntry; const AIsStrReturn: Boolean): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := np_sema_string_ownership.IsRootOwnedStringReturnCandidate(Ctx, AEntry, AIsStrReturn);
end;


function TSemanticAnalyzer.DeclReturnsString(const ADecl: TGreenNode): Boolean;
begin
  Result := np_sema_type_check.DeclReturnsString(ADecl);
end;

function TSemanticAnalyzer.DeclaresStringLocal(const ADecl: TGreenNode;
  const AName: string): Boolean;
begin
  Result := np_sema_type_check.DeclaresStringLocal(ADecl, AName);
end;

function TSemanticAnalyzer.StringReturnFunctionNameFromNode(
  const ANode: TGreenNode; out AName: string): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := np_sema_string_ownership.StringReturnFunctionNameFromNode(
    Ctx, ANode, AName);
end;

function TSemanticAnalyzer.FunctionCallReturnsString(
  const ANode: TGreenNode): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := np_sema_string_ownership.FunctionCallReturnsString(Ctx, ANode);
end;

function TSemanticAnalyzer.MemberCallReturnsString(
  const ANode: TGreenNode): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := np_sema_string_ownership.MemberCallReturnsString(Ctx, ANode);
end;

function TSemanticAnalyzer.TypeIdIsManagedString(
  const ATypeId: LongInt): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := np_sema_string_ownership.TypeIdIsManagedString(Ctx, ATypeId);
end;

function TSemanticAnalyzer.IsSupportedOwnedStringReturnIdentifierTarget(
  const ATargetNode: TGreenNode): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := np_sema_string_ownership.IsSupportedOwnedStringReturnIdentifierTarget(Ctx, ATargetNode);
end;


function TSemanticAnalyzer.IsSupportedOwnedStringReturnStoreTarget(
  const ATargetNode: TGreenNode): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := np_sema_string_ownership.IsSupportedOwnedStringReturnStoreTarget(Ctx, ATargetNode);
end;


function TSemanticAnalyzer.IsSupportedOwnedStringReturnConsumerTarget(
  const ATargetNode: TGreenNode): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := np_sema_string_ownership.IsSupportedOwnedStringReturnConsumerTarget(Ctx, ATargetNode);
end;


function TSemanticAnalyzer.AssignmentOwnsStringReturn(const ANode: TGreenNode;
  const AEntry: TProcedureBodyEntry): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := np_sema_string_ownership.AssignmentOwnsStringReturn(Ctx, ANode, AEntry);
end;


function TSemanticAnalyzer.AssignmentOwnsTopLevelStringReturn(
  const ANode: TGreenNode): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := np_sema_string_ownership.AssignmentOwnsTopLevelStringReturn(Ctx, ANode);
end;


function TSemanticAnalyzer.CallArgumentOwnsStringReturn(
  const ACallNode, AArgNode: TGreenNode; AArgPosition: LongInt;
  out AFuncName: string): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := np_sema_string_ownership.CallArgumentOwnsStringReturn(Ctx, ACallNode, AArgNode, AArgPosition, AFuncName);
end;


function TSemanticAnalyzer.DirectOwnedStringReturnAssignmentNode(
  const ANode: TGreenNode): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := np_sema_string_ownership.DirectOwnedStringReturnAssignmentNode(Ctx, ANode);
end;


function TSemanticAnalyzer.IsSupportedOwnedStringReturnArgument(
  const ACallNode, AArgNode: TGreenNode; AArgPosition: LongInt): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := np_sema_string_ownership.IsSupportedOwnedStringReturnArgument(Ctx, ACallNode, AArgNode, AArgPosition);
end;


function TSemanticAnalyzer.LengthArgumentOwnsStringReturn(
  const ANode: TGreenNode; out AFuncName: string): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := np_sema_string_ownership.LengthArgumentOwnsStringReturn(Ctx, ANode, AFuncName);
end;


function TSemanticAnalyzer.IsSupportedOwnedStringReturnLengthArgument(
  const ANode: TGreenNode; out AFuncName: string): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := np_sema_string_ownership.IsSupportedOwnedStringReturnLengthArgument(Ctx, ANode, AFuncName);
end;


function TSemanticAnalyzer.EmitOwnedStringLengthTemp(const ANode: TGreenNode;
  out ABlob: string): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := np_sema_string_ownership.EmitOwnedStringLengthTemp(Ctx, ANode, ABlob);
end;


function TSemanticAnalyzer.EmitOwnedStringConcatLengthTemp(
  const ANode: TGreenNode; out ABlob: string): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := np_sema_string_ownership.EmitOwnedStringConcatLengthTemp(Ctx, ANode, ABlob);
end;


function TSemanticAnalyzer.CopyArgumentOwnsStringReturn(
  const ANode: TGreenNode; out AFuncName: string): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := np_sema_string_ownership.CopyArgumentOwnsStringReturn(Ctx, ANode, AFuncName);
end;


function TSemanticAnalyzer.IsSupportedOwnedStringReturnCopyArgument(
  const ANode: TGreenNode; out AFuncName: string): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := np_sema_string_ownership.IsSupportedOwnedStringReturnCopyArgument(Ctx, ANode, AFuncName);
end;


function TSemanticAnalyzer.EmitOwnedStringCopyTemp(const ACopyNode: TGreenNode;
  const ADestName: string; out ATempName: string): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := np_sema_string_ownership.EmitOwnedStringCopyTemp(Ctx, ACopyNode, ADestName, ATempName);
end;


function TSemanticAnalyzer.WriteArgumentOwnsStringReturn(
  const ANode: TGreenNode; out AFuncName: string): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := np_sema_string_ownership.WriteArgumentOwnsStringReturn(Ctx, ANode, AFuncName);
end;


function TSemanticAnalyzer.IsSupportedOwnedStringReturnWriteArgument(
  const ANode: TGreenNode; out AFuncName: string): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := np_sema_string_ownership.IsSupportedOwnedStringReturnWriteArgument(Ctx, ANode, AFuncName);
end;


function TSemanticAnalyzer.EmitOwnedStringWriteTemp(
  const ANode: TGreenNode; out ATempName: string): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := np_sema_string_ownership.EmitOwnedStringWriteTemp(Ctx, ANode, ATempName);
end;


function TSemanticAnalyzer.EmitOwnedStringConcatWriteTemp(
  const ANode: TGreenNode; out ATempName: string): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := np_sema_string_ownership.EmitOwnedStringConcatWriteTemp(Ctx, ANode, ATempName);
end;


function TSemanticAnalyzer.ConcatOperandOwnsStringReturn(
  const ANode: TGreenNode; out AFuncName: string): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := np_sema_string_ownership.ConcatOperandOwnsStringReturn(Ctx, ANode, AFuncName);
end;


function TSemanticAnalyzer.IsSupportedOwnedStringReturnConcatOperand(
  const ANode: TGreenNode; out AFuncName: string): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := np_sema_string_ownership.IsSupportedOwnedStringReturnConcatOperand(Ctx, ANode, AFuncName);
end;


function TSemanticAnalyzer.ConcatExpressionConsumesOwnedStringReturnDeferred(
  const ANode: TGreenNode; const AInsideDirectOwnedAssignmentRhs: Boolean): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := np_sema_string_ownership.ConcatExpressionConsumesOwnedStringReturnDeferred(Ctx, ANode, AInsideDirectOwnedAssignmentRhs);
end;


function TSemanticAnalyzer.CompareOperandOwnsStringReturn(
  const ANode: TGreenNode; out AFuncName: string): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := np_sema_string_ownership.CompareOperandOwnsStringReturn(Ctx, ANode, AFuncName);
end;


function TSemanticAnalyzer.IsSupportedOwnedStringReturnCompareOperand(
  const ANode: TGreenNode; out AFuncName: string): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := np_sema_string_ownership.IsSupportedOwnedStringReturnCompareOperand(Ctx, ANode, AFuncName);
end;


function TSemanticAnalyzer.BoolConditionHasSupportedOwnedStringCompare(
  const ANode: TGreenNode): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := np_sema_string_ownership.BoolConditionHasSupportedOwnedStringCompare(Ctx, ANode);
end;


function TSemanticAnalyzer.CompareExpressionConsumesOwnedStringReturnDeferred(
  const ANode: TGreenNode): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := np_sema_string_ownership.CompareExpressionConsumesOwnedStringReturnDeferred(Ctx, ANode);
end;


function TSemanticAnalyzer.NodeConsumesOwnedStringReturnDeferred(
  const ANode: TGreenNode;
  const AInsideDirectOwnedAssignmentRhs: Boolean): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := np_sema_string_ownership.NodeConsumesOwnedStringReturnDeferred(Ctx, ANode, AInsideDirectOwnedAssignmentRhs);
end;


procedure TSemanticAnalyzer.ScanOwnedStringReturnConsumers(
  const ANode: TGreenNode; const AEntry: TProcedureBodyEntry;
  var AChanged: Boolean);
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  np_sema_string_ownership.ScanOwnedStringReturnConsumers(Ctx, ANode, AEntry, AChanged);
end;


procedure TSemanticAnalyzer.ScanTopLevelOwnedStringReturnConsumers(
  const ANode: TGreenNode; var AChanged: Boolean);
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  np_sema_string_ownership.ScanTopLevelOwnedStringReturnConsumers(Ctx, ANode, AChanged);
end;


procedure TSemanticAnalyzer.CheckDeferredOwnedStringReturnConsumers(
  const ANode: TGreenNode);
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  np_sema_string_ownership.CheckDeferredOwnedStringReturnConsumers(Ctx, ANode);
end;


procedure TSemanticAnalyzer.PreRegisterOwnedStringReturnConsumers;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  np_sema_string_ownership.PreRegisterOwnedStringReturnConsumers(Ctx);
end;


procedure TSemanticAnalyzer.RegisterRuntimeArrVar(const AName: string);
begin
  FRuntimeVars.RegisterRuntimeArrVar(AName);
end;

procedure TSemanticAnalyzer.RegisterBorrowedRuntimeArrVar(const AName: string);
begin
  FRuntimeVars.RegisterBorrowedRuntimeArrVar(AName);
end;

function TSemanticAnalyzer.IsRuntimeArrVar(const AName: string): Boolean;
begin
  Result := FRuntimeVars.IsRuntimeArrVar(AName);
end;

function TSemanticAnalyzer.IsBorrowedRuntimeArrVar(const AName: string): Boolean;
begin
  Result := FRuntimeVars.IsBorrowedRuntimeArrVar(AName);
end;

function TSemanticAnalyzer.IsStaticRuntimeArrVar(const AName: string): Boolean;
var
  Value: Int64;
begin
  Result := FModel.LookupConstValue(AName + '$arr_static', Value) and
    (Value <> 0);
end;

function TSemanticAnalyzer.DynArrayElemSizeOfVar(const AName: string): Int64;
begin
  Result := 8;
  if not FModel.LookupConstValue(AName + '$arr_elem_size', Result) then
    Result := 8;
end;

procedure TSemanticAnalyzer.EmitOwnedStringCleanupNodes(const AExceptName: string);
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  np_sema_string_ownership.EmitOwnedStringCleanupNodes(Ctx, AExceptName);
end;


procedure TSemanticAnalyzer.EmitOwnedDynArrayCleanupNodes;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  np_sema_string_ownership.EmitOwnedDynArrayCleanupNodes(Ctx);
end;


function TSemanticAnalyzer.IsManagedRecord(const ATypeName: string): Boolean;
var
  Meta: TTypeMetadata;
  I: LongInt;
begin
  Result := False;
  if not FModel.GetTypeMetaByName(ATypeName, Meta) then
    Exit;
  if not Meta.IsRecord then
    Exit;
  for I := 0 to High(Meta.Fields) do
  begin
    if Meta.Fields[I].IsString or Meta.Fields[I].IsDynArray then
      Exit(True);
    { 递归检查嵌套 record }
    if Meta.Fields[I].IsRecord then
    begin
      if (Meta.Fields[I].TypeId > 0) and
        (Meta.Fields[I].TypeId <= FModel.TypeCount) and
        IsManagedRecord(FModel.TypeAt(Meta.Fields[I].TypeId - 1).Name) then
        Exit(True);
    end;
  end;
end;

procedure TSemanticAnalyzer.EmitOwnedManagedRecordCleanupNodes;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  np_sema_string_ownership.EmitOwnedManagedRecordCleanupNodes(Ctx);
end;


procedure TSemanticAnalyzer.RegisterClassVar(const AName, AClassName: string);
var
  V: Int64;
begin
  if FModel.LookupConstValue(FRuntimeVars.LookupClassVar(AName) + '$vmt_count', V) and
    TypeMetaIsInterface(FRuntimeVars.LookupClassVar(AName)) then
    Exit;
  FRuntimeVars.RegisterClassVar(AName, AClassName);
end;

function TSemanticAnalyzer.LookupClassVar(const AName: string): string;
begin
  Result := FRuntimeVars.LookupClassVar(AName);
end;

procedure TSemanticAnalyzer.RegisterRecordVar(const AName, ATypeName: string);
begin
  FRuntimeVars.RegisterRecordVar(AName, ATypeName);
end;

procedure TSemanticAnalyzer.RegisterPointerVar(const AName,
  APointeeTypeName: string);
begin
  FRuntimeVars.RegisterPointerVar(AName, APointeeTypeName);
end;

function TSemanticAnalyzer.IsRecordVar(const AName: string): Boolean;
begin
  Result := FRuntimeVars.IsRecordVar(AName);
end;

procedure TSemanticAnalyzer.RegisterVarParam(const AName: string);
begin
  FRuntimeVars.RegisterVarParam(AName);
end;

function TSemanticAnalyzer.IsVarParam(const AName: string): Boolean;
begin
  Result := FRuntimeVars.IsVarParam(AName);
end;

function TSemanticAnalyzer.IsVarParamAtPosition(
  const ADecl: TGreenNode; APosition: LongInt): Boolean;
var
  J, K, ParamIdx: LongInt;
  Child, ParamChild: TGreenNode;
begin
  Result := False;
  if ADecl = nil then Exit;
  for J := 0 to ADecl.ChildCount - 1 do
  begin
    Child := ADecl.ChildAt(J);
    if (Child <> nil) and (Child.NodeKind = gnkParameterList) then
    begin
      ParamIdx := 0;
      for K := 0 to Child.ChildCount - 1 do
      begin
        ParamChild := Child.ChildAt(K);
        if (ParamChild = nil) or (ParamChild.NodeKind <> gnkParameterDecl) then
          Continue;
        if ParamIdx = APosition then
        begin
          Result := ParamNameIsByRef(ParamChild.Text);
          Exit;
        end;
        Inc(ParamIdx);
      end;
      Exit;
    end;
  end;
end;

function TSemanticAnalyzer.LookupRecordVar(const AName: string): string;
begin
  Result := FRuntimeVars.LookupRecordVar(AName);
end;

function TSemanticAnalyzer.LookupPointerVar(const AName: string): string;
begin
  Result := FRuntimeVars.LookupPointerVar(AName);
end;

procedure TSemanticAnalyzer.RegisterPtrReturnFunc(const AName, AClassName: string);
begin
  FRuntimeVars.RegisterPtrReturnFunc(AName, AClassName);
end;

procedure TSemanticAnalyzer.RegisterImportedUnitTree(const ATree: TGreenTree;
  const AOwnerUnitId: string);
var
  NextIndex: SizeInt;
begin
  if ATree = nil then
    Exit;
  NextIndex := Length(FImportedUnitTrees);
  SetLength(FImportedUnitTrees, NextIndex + 1);
  SetLength(FImportedUnitOwners, NextIndex + 1);
  FImportedUnitTrees[NextIndex] := ATree;
  FImportedUnitOwners[NextIndex] := AOwnerUnitId;
end;

function TSemanticAnalyzer.LookupPtrReturnFunc(const AName: string): string;
begin
  Result := FRuntimeVars.LookupPtrReturnFunc(AName);
end;

function TSemanticAnalyzer.EmitStrConcatOperand(const ANode: TGreenNode;
  const ADestVar: string): string;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := np_sema_string_ownership.EmitStrConcatOperand(Ctx, ANode, ADestVar);
end;


function TSemanticAnalyzer.ConcatTreeHasSupportedOwnedStringReturn(
  const ANode: TGreenNode): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := np_sema_string_ownership.ConcatTreeHasSupportedOwnedStringReturn(Ctx, ANode);
end;


function TSemanticAnalyzer.CanEmitStrConcatOperand(
  const ANode: TGreenNode): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := np_sema_string_ownership.CanEmitStrConcatOperand(Ctx, ANode);
end;


function TSemanticAnalyzer.CanEmitStrCompareOperand(const ANode: TGreenNode;
  const AAllowOwnedStringReturn: Boolean): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := np_sema_string_ownership.CanEmitStrCompareOperand(Ctx, ANode, AAllowOwnedStringReturn);
end;


function TSemanticAnalyzer.EmitStrCompareOperand(const ANode: TGreenNode;
  const AAllowOwnedStringReturn: Boolean; out ABlob: string): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := np_sema_string_ownership.EmitStrCompareOperand(Ctx, ANode, AAllowOwnedStringReturn, ABlob);
end;


function TSemanticAnalyzer.EncodeStrCallArgs(const ACallNode: TGreenNode;
  const ADestVar: string): string;
var
  ArgIndex: LongInt;
  ArgNode: TGreenNode;
  Blob, LitValue, SourceName, TempName: string;
begin
  Result := '';
  ArgIndex := 0;
  if ACallNode.NodeKind = gnkFunctionCall then
    ArgIndex := 1;
  ClearPendingStringTempReleases;
  while ArgIndex < ACallNode.ChildCount do
  begin
    ArgNode := ACallNode.ChildAt(ArgIndex);
    if ArgNode = nil then
    begin
      Inc(ArgIndex);
      Continue;
    end;
    if (ArgNode.NodeKind = gnkIdentifier) and IsRuntimeStrVar(ArgNode.Text) then
      Blob := 'strvar ' + ArgNode.Text + #10
    else if IsSupportedOwnedStringReturnArgument(ACallNode, ArgNode,
      ArgIndex - 1) and StringReturnFunctionNameFromNode(ArgNode, SourceName) then
    begin
      Inc(FBlockLabelCounter);
      TempName := '$str_arg_tmp_' + IntToStr(FBlockLabelCounter);
      RegisterRuntimeVar(TempName);
      RegisterRuntimeStrVar(TempName);
      FModel.AddTypedHirNode('var-decl-tstring-runtime', TempName,
        0, 0, TempName);
      FModel.AddTypedHirNode('string-temp-owned-runtime', SourceName,
        0, 0, TempName + #9 + 'callee ' + SourceName + #9 +
        'ptr len owner alloc_size');
      FModel.AddTypedHirNode('string-temp-borrow-arg-runtime',
        ACallNode.Text, 0, 0, 'strvar ' + TempName + #10);
      QueuePendingStringTempRelease(TempName, SourceName);
      Blob := 'strvar ' + TempName + #10;
    end
    else if ArgNode.NodeKind = gnkStringLiteral then
    begin
      LitValue := DecodePascalStringLiteral(ArgNode.Text);
      Blob := EmitStrConcatOperand(ArgNode, ADestVar);
      if Blob <> '' then
        Blob := 'strvar ' + Blob + #10
      else
        Blob := '';
    end
    else if EncodeRuntimeIntExprFold(ArgNode, Blob) then
      { Blob already set }
    else
      Blob := '';
    if Blob <> '' then
    begin
      if Result <> '' then
        Result := Result + #9 + Blob
      else
        Result := Blob;
    end;
    Inc(ArgIndex);
  end;
end;

function TSemanticAnalyzer.EncodeCallStatementArgs(
  const ACallName: string; const ACallNode, ADeclNode: TGreenNode): string;
var
  ArgIndex, ParamIndex: LongInt;
  ArgNode: TGreenNode;
  Decoded, SourceName, TempName: string;
begin
  Result := ACallName;
  ClearPendingStringTempReleases;
  if ACallNode = nil then
    Exit;
  if ACallNode.NodeKind = gnkFunctionCall then
    ArgIndex := 1
  else
    ArgIndex := 0;
  ParamIndex := 0;
  while ArgIndex < ACallNode.ChildCount do
  begin
    ArgNode := ACallNode.ChildAt(ArgIndex);
    if (ArgNode <> nil) and (ArgNode.NodeKind = gnkIdentifier) and
      IsVarParamAtPosition(ADeclNode, ParamIndex) and
      IsRuntimeVar(ArgNode.Text) then
      Result := Result + #9 + 'varref ' + ArgNode.Text + #10
    else if (ArgNode <> nil) and (ArgNode.NodeKind = gnkIdentifier) and
      IsRuntimeStrVar(ArgNode.Text) then
      Result := Result + #9 + 'strvar ' + ArgNode.Text + #10
    else if (ArgNode <> nil) and IsSupportedOwnedStringReturnArgument(
      ACallNode, ArgNode, ParamIndex) and
      StringReturnFunctionNameFromNode(ArgNode, SourceName) then
    begin
      Inc(FBlockLabelCounter);
      TempName := '$str_arg_tmp_' + IntToStr(FBlockLabelCounter);
      RegisterRuntimeVar(TempName);
      RegisterRuntimeStrVar(TempName);
      FModel.AddTypedHirNode('var-decl-tstring-runtime', TempName,
        0, 0, TempName);
      FModel.AddTypedHirNode('string-temp-owned-runtime', SourceName,
        0, 0, TempName + #9 + 'callee ' + SourceName + #9 +
        'ptr len owner alloc_size');
      FModel.AddTypedHirNode('string-temp-borrow-arg-runtime',
        ACallName, 0, 0, 'strvar ' + TempName + #10);
      QueuePendingStringTempRelease(TempName, SourceName);
      Result := Result + #9 + 'strvar ' + TempName + #10;
    end
    else if (ArgNode <> nil) and (ArgNode.NodeKind = gnkStringLiteral) then
      Result := Result + #9 + 'strlit ' + ArgNode.Text + #10
    else if (ArgNode <> nil) and EncodeRuntimeIntExprFold(ArgNode, Decoded) then
      Result := Result + #9 + Decoded;
    Inc(ArgIndex);
    Inc(ParamIndex);
  end;
end;

procedure TSemanticAnalyzer.EmitBlockLabel(const ALabel: string);
var Ctx: TSemaHirLoweringContext;
begin
  Ctx.Model := FModel;
  Ctx.CurrentBlockTerminated := FCurrentBlockTerminated;
  np_sema_hir_lowering.EmitBlockLabel(Ctx, ALabel);
  FCurrentBlockTerminated := Ctx.CurrentBlockTerminated;
end;

procedure TSemanticAnalyzer.EmitGotoLabel(const ALabel: string);
var Ctx: TSemaHirLoweringContext;
begin
  Ctx.Model := FModel;
  Ctx.CurrentBlockTerminated := FCurrentBlockTerminated;
  np_sema_hir_lowering.EmitGotoLabel(Ctx, ALabel);
  FCurrentBlockTerminated := Ctx.CurrentBlockTerminated;
end;
destructor TSemanticAnalyzer.Destroy;
var
  Index: LongInt;
begin
  for Index := 0 to Length(FImportedUnitTrees) - 1 do
    FImportedUnitTrees[Index].Free;
  FBreakLabels.Free;
  FContinueLabels.Free;
  { FVarParamNames now managed by FRuntimeVars }
  FInliningStack.Free;
  FGenericCache.Free;
  FBuiltinRegistry.Free;
  FRuntimeVars.Free;
  FModel.Free;
  inherited Destroy;
end;

function TSemanticAnalyzer.DuplicateImportName: string;
var
  SeenImports: TStringArray;
  Index: LongInt;
  ImportName: string;
  ImportId: string;
begin
  { Only flag duplicates WITHIN the same section.
    FPC allows the same unit in both interface and implementation uses. }
  SeenImports := nil;
  for Index := 0 to FRootAst.InterfaceUseCount - 1 do
  begin
    ImportName := FRootAst.InterfaceUseAt(Index);
    ImportId := NormalizeUnitIdentity(ImportName);
    if ContainsString(SeenImports, ImportId) then
      Exit(ImportName);
    AppendString(SeenImports, ImportId);
  end;

  SeenImports := nil;
  for Index := 0 to FRootAst.ImplementationUseCount - 1 do
  begin
    ImportName := FRootAst.ImplementationUseAt(Index);
    ImportId := NormalizeUnitIdentity(ImportName);
    if ContainsString(SeenImports, ImportId) then
      Exit(ImportName);
    AppendString(SeenImports, ImportId);
  end;

  Result := '';
end;

function TSemanticAnalyzer.CountDeclParams(const ADecl: TGreenNode): LongInt;
begin
  Result := np_sema_overload.CountDeclParams(ADecl);
end;

function TSemanticAnalyzer.CountRequiredDeclParams(
  const ADecl: TGreenNode): LongInt;
begin
  Result := np_sema_overload.CountRequiredDeclParams(ADecl);
end;

function TSemanticAnalyzer.DeclReturnTypeId(const ADecl: TGreenNode;
  const AOwnerUnitId: string): LongInt;
var
  Child: TGreenNode;
  Index: LongInt;
begin
  Result := 0;
  if ADecl = nil then
    Exit;

  case ADecl.NodeKind of
    gnkFunctionDecl:
      Index := 0;
    gnkClassMethod:
      begin
        Index := 0;
        if (ADecl.ChildCount > 0) and (ADecl.ChildAt(0) <> nil) and
          (ADecl.ChildAt(0).NodeKind = gnkIdentifier) then
          Index := 1;
      end;
  else
    Exit;
  end;

  for Index := Index to ADecl.ChildCount - 1 do
  begin
    Child := ADecl.ChildAt(Index);
    if (Child = nil) or (Child.NodeKind <> gnkIdentifier) then
      Continue;
    Result := ResolveTypeIdForOwner(Child.Text, AOwnerUnitId);
    if Result > 0 then
      Exit;
  end;
end;

function TSemanticAnalyzer.DeclAcceptsArgCount(const ADecl: TGreenNode;
  const AArgCount: LongInt): Boolean;
begin
  Result := np_sema_overload.DeclAcceptsArgCount(ADecl, AArgCount);
end;

function TSemanticAnalyzer.DeclParamSignatureMatchesArgs(
  const ADecl: TGreenNode; const AArgSignature: string; const AArgCount: LongInt): Boolean;
var Ctx: TSemaOverloadContext;
begin
  Ctx.Model := FModel;
  Ctx.UnitGraph := FUnitGraph;
  Ctx.RootAst := FRootAst;
  Ctx.CurrentProcessingUnitId := FCurrentProcessingUnitId;
  Ctx.CurrentScopeId := FCurrentScopeId;
  Ctx.ProcedureBodies := FProcedureBodies;
  Ctx.ImportedUnitOwners := FImportedUnitOwners;
  Ctx.ImportedUnitTrees := FImportedUnitTrees;
  Ctx.BuiltinRegistry := FBuiltinRegistry;
  Result := np_sema_overload.DeclParamSignatureMatchesArgs(Ctx, ADecl, AArgSignature, AArgCount);
end;

function TSemanticAnalyzer.GetParamSignature(const ADecl: TGreenNode): string;
var Ctx: TSemaOverloadContext;
begin
  Ctx.Model := FModel;
  Ctx.UnitGraph := FUnitGraph;
  Ctx.RootAst := FRootAst;
  Ctx.CurrentProcessingUnitId := FCurrentProcessingUnitId;
  Ctx.CurrentScopeId := FCurrentScopeId;
  Ctx.ProcedureBodies := FProcedureBodies;
  Ctx.ImportedUnitOwners := FImportedUnitOwners;
  Ctx.ImportedUnitTrees := FImportedUnitTrees;
  Ctx.BuiltinRegistry := FBuiltinRegistry;
  Result := np_sema_overload.GetParamSignature(Ctx, ADecl);
end;

function TSemanticAnalyzer.GetParamIdentitySignature(
  const ADecl: TGreenNode
): string;
begin
  Result := np_sema_overload.GetParamIdentitySignature(ADecl);
end;

function TSemanticAnalyzer.GetSubstitutedParamSignature(
  const ADecl: TGreenNode;
  const AParamNames, AArgTypes: array of string): string;
var
  J, K, P: LongInt;
  Child, ParamChild, TypeChild: TGreenNode;
  TypeId: LongInt;
  TypeName, SubstType: string;
  Dummy: Int64;
  Found: Boolean;
  TypeSig: string;
begin
  Result := '';
  if ADecl = nil then Exit;
  for J := 0 to ADecl.ChildCount - 1 do
  begin
    Child := ADecl.ChildAt(J);
    if (Child <> nil) and (Child.NodeKind = gnkParameterList) then
    begin
      for K := 0 to Child.ChildCount - 1 do
      begin
        ParamChild := Child.ChildAt(K);
        if (ParamChild = nil) or (ParamChild.NodeKind <> gnkParameterDecl) then
          Continue;
        TypeName := '';
        TypeChild := nil;
        if ParamChild.ChildCount > 0 then
        begin
          TypeChild := ParamChild.ChildAt(0);
          if TypeChild <> nil then
            TypeName := TypeChild.Text;
        end;
        Found := False;
        for P := 0 to High(AParamNames) do
        begin
          if SameText(TypeName, AParamNames[P]) then
          begin
            SubstType := LowerCase(AArgTypes[P]);
            TypeId := ResolveTypeId(AArgTypes[P]);
            TypeSig := TypeSignatureForTypeId(TypeId);
            if TypeSig <> '' then
              Result := Result + TypeSig
            else if (SubstType = 'string') or (SubstType = 'ansistring') then
              Result := Result + 's'
            else if (SubstType = 'boolean') or (SubstType = 'bool') then
              Result := Result + 'b'
            else if TypeMetaIsRecord(AArgTypes[P]) then
              Result := Result + 'r'
            else if TypeMetaSize(AArgTypes[P]) > 0 then
              Result := Result + 'p'
            else
              Result := Result + 'i';
            Found := True;
            Break;
          end;
        end;
        if not Found then
        begin
          TypeName := LowerCase(TypeName);
          TypeId := 0;
          if TypeChild <> nil then
          begin
            TypeId := ResolveTypeIdForOwner(
              TypeChild.Text,
              NormalizeUnitIdentity(FCurrentProcessingUnitId)
            );
            if TypeId <= 0 then
              TypeId := ResolveTypeIdForOwner(
                TypeChild.Text,
                NormalizeUnitIdentity(FUnitGraph.RootName)
              );
            if TypeId <= 0 then
              TypeId := ResolveTypeId(TypeChild.Text);
          end;
          TypeSig := TypeSignatureForTypeId(TypeId);
          if TypeSig <> '' then
            Result := Result + TypeSig
          else if (TypeName = 'string') or (TypeName = 'ansistring') then
            Result := Result + 's'
          else if (TypeName = 'boolean') or (TypeName = 'bool') then
            Result := Result + 'b'
          else if (TypeChild <> nil) and TypeMetaIsRecord(TypeChild.Text) then
            Result := Result + 'r'
          else if (TypeChild <> nil) and TypeIsInterfaceByName(TypeChild.Text) then
            Result := Result + 'f'
          else if SameText(TypeName, 'integer') or SameText(TypeName, 'longint') or
            SameText(TypeName, 'longword') or SameText(TypeName, 'cardinal') or
            SameText(TypeName, 'smallint') or SameText(TypeName, 'word') or
            SameText(TypeName, 'byte') or SameText(TypeName, 'shortint') or
            SameText(TypeName, 'int64') or SameText(TypeName, 'qword') or
            SameText(TypeName, 'uint64') or SameText(TypeName, 'sizeint') or
            SameText(TypeName, 'sizeuint') or SameText(TypeName, 'uint32') or
            SameText(TypeName, 'ptruint') or SameText(TypeName, 'ptrint') then
            Result := Result + 'i'
          else if (TypeChild <> nil) then
          begin
            if (FModel.FindTypeByName(TypeChild.Text) > 0) and
              SameText(FModel.TypeAt(FModel.FindTypeByName(TypeChild.Text) - 1).Kind, 'class') then
              Result := Result + 'c'
            else if TypeMetaIsClass(TypeChild.Text) then
              Result := Result + 'c'
            else if TypeMetaSize(TypeChild.Text) > 0 then
              Result := Result + 'p'
            else
              Result := Result + 'i';
          end
          else
            Result := Result + 'i';
        end;
      end;
      Exit;
    end;
  end;
end;

function TSemanticAnalyzer.MangledName(const AName: string;
  AParamCount: LongInt): string;
begin
  Result := np_sema_overload.MangledName(AName, AParamCount);
end;

function TSemanticAnalyzer.MangledNameSig(const AName: string;
  const ASig: string): string;
begin
  Result := np_sema_overload.MangledNameSig(AName, ASig);
end;

procedure TSemanticAnalyzer.RegisterProcedureBody(const AName: string;
  const ABody: TGreenNode; const ADecl: TGreenNode;
  const AOwnerUnitId: string);
var
  Index: LongInt;
  NextIndex: SizeInt;
  Sig, ExistingSig, CleanName: string;
begin
  if Pos(';compilerproc', AName) > 0 then
  begin
    CleanName := Copy(AName, 1, Pos(';', AName) - 1);
    if FCompilerProcCount >= Length(FCompilerProcNames) then
      SetLength(FCompilerProcNames, FCompilerProcCount + 16);
    FCompilerProcNames[FCompilerProcCount] := CleanName;
    Inc(FCompilerProcCount);
  end
  else
    CleanName := AName;
  Sig := GetParamIdentitySignature(ADecl);
  for Index := 0 to Length(FProcedureBodies) - 1 do
    if SameText(FProcedureBodies[Index].Name, CleanName) and
      SameText(FProcedureBodies[Index].OwnerUnitId, AOwnerUnitId) then
    begin
      ExistingSig := GetParamIdentitySignature(FProcedureBodies[Index].Decl);
      if ExistingSig = Sig then
      begin
        FProcedureBodies[Index].Body := ABody;
        FProcedureBodies[Index].Decl := ADecl;
        FProcedureBodies[Index].OwnerUnitId := AOwnerUnitId;
        FProcedureBodies[Index].ScopeId := FCurrentScopeId;
        Exit;
      end;
    end;
  NextIndex := Length(FProcedureBodies);
  SetLength(FProcedureBodies, NextIndex + 1);
  FProcedureBodies[NextIndex].Name := CleanName;
  FProcedureBodies[NextIndex].Body := ABody;
  FProcedureBodies[NextIndex].Decl := ADecl;
  FProcedureBodies[NextIndex].OwnerUnitId := AOwnerUnitId;
  FProcedureBodies[NextIndex].ScopeId := FCurrentScopeId;
end;

function TSemanticAnalyzer.ProcedureBodyScopeIdForDecl(
  const ADecl: TGreenNode
): LongInt;
var
  Index, NameMatchCount, NameMatchScopeId: LongInt;
  DeclName: string;
begin
  Result := 0;
  if ADecl = nil then
    Exit;
  DeclName := ADecl.Text;
  { Try exact pointer match first }
  for Index := 0 to Length(FProcedureBodies) - 1 do
    if FProcedureBodies[Index].Decl = ADecl then
      Exit(FProcedureBodies[Index].ScopeId);
  { Fallback: name match for overloaded declarations sharing same body entry.
    Only when exactly one entry has this name (no ambiguity). }
  if DeclName <> '' then
  begin
    NameMatchCount := 0;
    NameMatchScopeId := 0;
    for Index := 0 to Length(FProcedureBodies) - 1 do
      if SameText(FProcedureBodies[Index].Name, DeclName) then
      begin
        Inc(NameMatchCount);
        NameMatchScopeId := FProcedureBodies[Index].ScopeId;
      end;
    if NameMatchCount = 1 then
      Result := NameMatchScopeId;
  end;
end;

function TSemanticAnalyzer.ParamDeclTypeId(
  const AParamDecl: TGreenNode; const AOwnerUnitId: string): LongInt;
var Ctx: TSemaOverloadContext;
begin
  Ctx.Model := FModel;
  Ctx.UnitGraph := FUnitGraph;
  Ctx.RootAst := FRootAst;
  Ctx.CurrentProcessingUnitId := FCurrentProcessingUnitId;
  Ctx.CurrentScopeId := FCurrentScopeId;
  Ctx.ProcedureBodies := FProcedureBodies;
  Ctx.ImportedUnitOwners := FImportedUnitOwners;
  Ctx.ImportedUnitTrees := FImportedUnitTrees;
  Ctx.BuiltinRegistry := FBuiltinRegistry;
  Result := np_sema_overload.ParamDeclTypeId(Ctx, AParamDecl, AOwnerUnitId);
end;

function TSemanticAnalyzer.LookupProcedureBody(const AName: string;
  out ABody: TGreenNode; out ADecl: TGreenNode): Boolean;
var
  Index: LongInt;
begin
  ABody := nil;
  ADecl := nil;
  for Index := 0 to Length(FProcedureBodies) - 1 do
    if SameText(FProcedureBodies[Index].Name, AName) then
    begin
      ABody := FProcedureBodies[Index].Body;
      ADecl := FProcedureBodies[Index].Decl;
      Exit(True);
    end;
  Result := False;
end;

function TSemanticAnalyzer.HasOverload(const AName: string): Boolean;
begin
  Result := np_sema_overload.HasOverload(AName, FProcedureBodies);
end;

function TSemanticAnalyzer.LookupOverload(const AName: string;
  AArgCount: LongInt; out ABody: TGreenNode; out ADecl: TGreenNode): Boolean;
begin
  Result := np_sema_overload.LookupOverload(AName, AArgCount, FProcedureBodies, ABody, ADecl);
end;

function TSemanticAnalyzer.LookupCallBindingDeclaration(
  const AName: string; const AArgCount: LongInt;
  const AArgTypeIds: TTypeIdArray; const AArgSignature: string;
  const AHasArgSignature: Boolean; const AHasTypeMismatchEvidence: Boolean;
  out AResolutionFailureKind: string;
  out ABody: TGreenNode; out ADecl: TGreenNode; out AOwnerUnitId: string): Boolean;
var Ctx: TSemaOverloadContext;
begin
  Ctx.Model := FModel;
  Ctx.UnitGraph := FUnitGraph;
  Ctx.RootAst := FRootAst;
  Ctx.CurrentProcessingUnitId := FCurrentProcessingUnitId;
  Ctx.CurrentScopeId := FCurrentScopeId;
  Ctx.ProcedureBodies := FProcedureBodies;
  Ctx.ImportedUnitOwners := FImportedUnitOwners;
  Ctx.ImportedUnitTrees := FImportedUnitTrees;
  Ctx.BuiltinRegistry := FBuiltinRegistry;
  Result := np_sema_overload.LookupCallBindingDeclaration(
    Ctx, AName, AArgCount, AArgTypeIds, AArgSignature,
    AHasArgSignature, AHasTypeMismatchEvidence,
    AResolutionFailureKind, ABody, ADecl, AOwnerUnitId);
end;

function TSemanticAnalyzer.OwnerUnitAllowsProjectSourceDiagnostic(
  const AOwnerUnitId: string
): Boolean;
var
  Ctx: TSemaImportContext;
begin
  Ctx.UnitGraph := FUnitGraph;
  Ctx.RootAst := FRootAst;
  Ctx.ImportedUnitOwners := FImportedUnitOwners;
  Ctx.ImportedUnitTrees := FImportedUnitTrees;
  Result := np_sema_overload.OwnerUnitAllowsProjectSourceDiagnostic(Ctx, AOwnerUnitId);
end;

function TSemanticAnalyzer.HasInstalledSourceImports: Boolean;
var
  Index: LongInt;
  ResolvedUnit: TResolvedUnit;
begin
  Result := False;
  for Index := 0 to FUnitGraph.ResolvedUnitCount - 1 do
  begin
    ResolvedUnit := FUnitGraph.ResolvedUnitAt(Index);
    if SameText(ResolvedUnit.OriginClass, 'installed-source') then
      Exit(True);
  end;
end;

function TSemanticAnalyzer.UnitDirectlyImports(
  const AOwnerUnitId: string;
  const AImportedUnitId: string
): Boolean;
var
  Ctx: TSemaImportContext;
begin
  Ctx.UnitGraph := FUnitGraph;
  Ctx.RootAst := FRootAst;
  Ctx.ImportedUnitOwners := FImportedUnitOwners;
  Ctx.ImportedUnitTrees := FImportedUnitTrees;
  Result := np_sema_overload.UnitDirectlyImports(Ctx, AOwnerUnitId, AImportedUnitId);
end;

function TSemanticAnalyzer.ExpressionTypeFactIsStable(
  const ANode: TGreenNode;
  const ACurrentOwnerUnitId: string
): Boolean;
var
  CallName: string;
  CurrentOwnerUnitId: string;
  Index: LongInt;
  RootOwnerUnitId: string;
  Sym: TSemanticSymbol;
  SymId: LongInt;
  TargetTypeId: LongInt;
begin
  Result := False;
  if ANode = nil then
    Exit;

  CurrentOwnerUnitId := NormalizeUnitIdentity(ACurrentOwnerUnitId);
  RootOwnerUnitId := NormalizeUnitIdentity(FUnitGraph.RootName);

  case ANode.NodeKind of
    gnkIntegerLiteral, gnkRealLiteral, gnkStringLiteral, gnkCharLiteral:
      Exit(True);
    gnkIdentifier:
      begin
        if SameText(ANode.Text, 'True') or SameText(ANode.Text, 'False') then
          Exit(True);
        SymId := FModel.LookupSymbol(ANode.Text, FCurrentScopeId);
        if SymId <= 0 then
          Exit(False);
        Sym := FModel.SymbolAt(SymId - 1);
        if SameText(Sym.Kind, 'function') then
        begin
          Exit((Sym.ParamCount = 0) and
            (
              SameText(Sym.OwnerUnitId, RootOwnerUnitId) or
              (
                (CurrentOwnerUnitId <> '') and
                SameText(Sym.OwnerUnitId, CurrentOwnerUnitId) and
                OwnerUnitAllowsProjectSourceDiagnostic(Sym.OwnerUnitId)
              )
            ) and
            TypeIdHasStableScalarFact(Sym.TypeId));
        end
        else if (not SameText(Sym.Kind, 'variable')) and
          (not SameText(Sym.Kind, 'parameter')) and
          (not SameText(Sym.Kind, 'field')) then
          Exit(False);
        if TypeIdHasStableScalarFact(Sym.TypeId) then
          Exit(True);
        if (Sym.TypeId > 0) and (Sym.TypeId <= FModel.TypeCount) then
        begin
          if SameText(FModel.TypeAt(Sym.TypeId - 1).Kind, 'interface') then
            Exit(True);
          if SameText(FModel.TypeAt(Sym.TypeId - 1).Kind, 'class') then
            Exit(True);
        end;
        Exit(False);
      end;
    gnkFunctionCall:
      begin
        SymId := FModel.LookupSymbol(ANode.Text, FCurrentScopeId);
        if SymId > 0 then
        begin
          Sym := FModel.SymbolAt(SymId - 1);
          Exit(SameText(Sym.Kind, 'function') and (Sym.ParamCount = 0) and
            (
              SameText(Sym.OwnerUnitId, RootOwnerUnitId) or
              (
                (CurrentOwnerUnitId <> '') and
                SameText(Sym.OwnerUnitId, CurrentOwnerUnitId) and
                OwnerUnitAllowsProjectSourceDiagnostic(Sym.OwnerUnitId)
              )
            ) and
            (ANode.ChildCount <= 1) and TypeIdHasStableScalarFact(Sym.TypeId));
        end;
        if (ANode.ChildCount > 0) and (ANode.ChildAt(0) <> nil) and
          (ANode.ChildAt(0).NodeKind = gnkDotAccess) then
          Exit(ExpressionTypeFactIsStable(ANode.ChildAt(0), CurrentOwnerUnitId));
        Exit(False);
      end;
    gnkBinaryExpression, gnkUnaryExpression:
      begin
        for Index := 0 to ANode.ChildCount - 1 do
          if not ExpressionTypeFactIsStable(
            ANode.ChildAt(Index),
            CurrentOwnerUnitId
          ) then
            Exit(False);
        Exit(True);
      end;
    gnkDotAccess:
      begin
        if ANode.ChildCount < 2 then
          Exit(False);
        if (ANode.ChildAt(0) = nil) or (ANode.ChildAt(1) = nil) then
          Exit(False);
        if ANode.ChildAt(0).NodeKind = gnkIdentifier then
        begin
          SymId := FModel.LookupSymbol(ANode.ChildAt(0).Text, FCurrentScopeId);
          if SymId <= 0 then
          begin
            if SameText(ANode.ChildAt(0).Text, 'Self') and
              (FCurrentMethodClass <> '') then
              Exit(True);
            Exit(False);
          end;
          Sym := FModel.SymbolAt(SymId - 1);
          if Sym.TypeId <= 0 then
            Exit(False);
          if TypeIdHasStableScalarFact(Sym.TypeId) then
            Exit(True);
          if SameText(FModel.TypeAt(Sym.TypeId - 1).Kind, 'interface') then
            Exit(True);
          if SameText(FModel.TypeAt(Sym.TypeId - 1).Kind, 'class') then
            Exit(True);
          Exit(False);
        end;
        Exit(ExpressionTypeFactIsStable(ANode.ChildAt(0), CurrentOwnerUnitId));
      end;
  end;
end;

function TSemanticAnalyzer.CallArgumentSignatureIsStable(
  const ACallNode: TGreenNode;
  const ACurrentOwnerUnitId: string
): Boolean;
var
  ArgRoot: TGreenNode;
  Index: LongInt;
begin
  Result := False;
  if ACallNode = nil then
    Exit;

  ArgRoot := ACallNode;
  if (ACallNode.NodeKind = gnkProcedureCallStatement) and
    (ACallNode.ChildCount > 0) and
    (ACallNode.ChildAt(0) <> nil) and
    (ACallNode.ChildAt(0).NodeKind = gnkFunctionCall) then
    ArgRoot := ACallNode.ChildAt(0);

  if ArgRoot.NodeKind <> gnkFunctionCall then
    Exit(True);

  for Index := 1 to ArgRoot.ChildCount - 1 do
    if not ExpressionTypeFactIsStable(
      ArgRoot.ChildAt(Index),
      ACurrentOwnerUnitId
    ) then
      Exit(False);
  Result := True;
end;

function TSemanticAnalyzer.CallArgumentCount(const ACallNode: TGreenNode): LongInt;
begin
  Result := np_sema_type_check.CallArgumentCount(ACallNode);
end;

function TSemanticAnalyzer.BareCallCalleeName(
  const ACallNode: TGreenNode
): string;
begin
  Result := np_sema_type_check.BareCallCalleeName(ACallNode);
end;

function TSemanticAnalyzer.IsIntrinsicExprName(const AName: string): Boolean;
begin
  Result := np_sema_type_check.IsIntrinsicExprName(AName);
end;

function TSemanticAnalyzer.TryGetTypeCastTargetTypeId(
  const ACallNode: TGreenNode;
  out ATargetTypeId: LongInt
): Boolean;
var
  CalleeNode: TGreenNode;
begin
  ATargetTypeId := 0;
  if (ACallNode = nil) or (ACallNode.NodeKind <> gnkFunctionCall) or
    (ACallNode.ChildCount <> 2) then
    Exit(False);

  CalleeNode := ACallNode.ChildAt(0);
  if (CalleeNode = nil) or (CalleeNode.NodeKind <> gnkIdentifier) or
    (Trim(CalleeNode.Text) = '') then
    Exit(False);

  ATargetTypeId := ResolveTypeIdForOwner(
    CalleeNode.Text,
    NormalizeUnitIdentity(FCurrentProcessingUnitId)
  );
  if ATargetTypeId <= 0 then
    ATargetTypeId := ResolveTypeIdForOwner(
      CalleeNode.Text,
      NormalizeUnitIdentity(FUnitGraph.RootName)
    );
  if ATargetTypeId <= 0 then
    ATargetTypeId := ResolveTypeId(CalleeNode.Text);
  Result := ATargetTypeId > 0;
end;

function TSemanticAnalyzer.TryGetIntrinsicExprName(
  const ACallNode: TGreenNode;
  out AName: string
): Boolean;
var
  CalleeNode: TGreenNode;
  DummyTypeId: LongInt;
begin
  AName := '';
  if (ACallNode = nil) or (ACallNode.NodeKind <> gnkFunctionCall) or
    (ACallNode.ChildCount < 1) then
    Exit(False);

  if TryGetTypeCastTargetTypeId(ACallNode, DummyTypeId) then
    Exit(False);

  CalleeNode := ACallNode.ChildAt(0);
  if (CalleeNode = nil) or (CalleeNode.NodeKind <> gnkIdentifier) then
    Exit(False);

  AName := CalleeNode.Text;
  Result := IsIntrinsicExprName(AName);
  if not Result then
    AName := '';
end;

function TSemanticAnalyzer.IsWrappedCallChild(
  const AParent: TGreenNode;
  const AChild: TGreenNode
): Boolean;
begin
  Result := np_sema_type_check.IsWrappedCallChild(AParent, AChild);
end;

function TSemanticAnalyzer.IsImplicitSelfCallNode(
  const ACallNode: TGreenNode
): Boolean;
begin
  Result := np_sema_type_check.IsImplicitSelfCallNode(ACallNode);
end;

function TSemanticAnalyzer.IsQualifiedCallNode(
  const ACallNode: TGreenNode
): Boolean;
begin
  Result := np_sema_type_check.IsQualifiedCallNode(ACallNode);
end;

function TSemanticAnalyzer.ExtractDirectMemberCall(
  const ACallNode: TGreenNode;
  out AReceiverName: string;
  out AMemberName: string;
  out AMemberOffset: LongInt;
  out AArgCount: LongInt
): Boolean;
begin
  Result := np_sema_type_check.ExtractDirectMemberCall(ACallNode, AReceiverName, AMemberName, AMemberOffset, AArgCount);
end;

function TSemanticAnalyzer.TypeIdForVariable(const AName: string): LongInt;
var
  Index: LongInt;
  Symbol: TSemanticSymbol;
begin
  Result := 0;
  if AName = '' then
    Exit;

  if FCurrentScopeId > 0 then
  begin
    Index := FModel.LookupSymbol(AName, FCurrentScopeId);
    if Index > 0 then
    begin
      Symbol := FModel.SymbolAt(Index - 1);
      if (SameText(Symbol.Kind, 'variable') or
        SameText(Symbol.Kind, 'parameter')) and
        (Symbol.TypeId > 0) and (Symbol.TypeId <= FModel.TypeCount) then
        Exit(Symbol.TypeId);
    end;
  end;

  for Index := 0 to FModel.SymbolCount - 1 do
  begin
    Symbol := FModel.SymbolAt(Index);
    if SameText(Symbol.Name, AName) and
      (SameText(Symbol.Kind, 'variable') or
       SameText(Symbol.Kind, 'parameter')) and
      (Symbol.TypeId > 0) and (Symbol.TypeId <= FModel.TypeCount) then
      Exit(Symbol.TypeId);
  end;
end;

function TSemanticAnalyzer.TypeIdForMemberReceiver(
  const AName: string;
  const ACurrentMethodClass: string;
  const ACurrentOwnerUnitId: string
): LongInt;
begin
  Result := 0;
  if SameText(AName, 'Self') and (ACurrentMethodClass <> '') then
    Exit(ResolveTypeIdForOwner(
      ACurrentMethodClass,
      ACurrentOwnerUnitId
    ));

  Result := TypeIdForVariable(AName);
  if Result > 0 then
    Exit;
  if AName = '' then
    Exit;

  Result := ResolveTypeIdForOwner(
    AName,
    NormalizeUnitIdentity(FUnitGraph.RootName),
    False
  );
end;

function TSemanticAnalyzer.TryResolveTypeNameMemberCallTarget(
      const AReceiverName: string;
      const AMemberName: string;
      const AArgCount: LongInt;
      const AArgTypeIds: TTypeIdArray;
      const AArgSignature: string;
      const AHasArgSignature: Boolean;
      const AHasTypeMismatchEvidence: Boolean;
      out AReceiverTypeId: LongInt;
  out ATargetSymbolId: LongInt
): Boolean;
var
  CandidateResolutionFailure: string;
  CandidateTargetSymbolId: LongInt;
  CandidateTypeId: LongInt;
  Candidates: TOverloadCandidateArray;
  Index: LongInt;
  MatchCount: LongInt;
  SeenIndex: LongInt;
  SeenTypeIds: specialize TVec<LongInt>;
  Symbol: TSemanticSymbol;
  TypeAlreadySeen: Boolean;
begin
  Result := False;
  AReceiverTypeId := 0;
  ATargetSymbolId := 0;
  if (AReceiverName = '') or (AMemberName = '') then
    Exit;

  MatchCount := 0;
  SeenTypeIds := specialize TVec<LongInt>.Create;
  for Index := 0 to FModel.SymbolCount - 1 do
  begin
    Symbol := FModel.SymbolAt(Index);
    if not SameText(Symbol.Kind, 'type') or
      not SameText(Symbol.Name, AReceiverName) or
      (Symbol.TypeId <= 0) or (Symbol.TypeId > FModel.TypeCount) then
      Continue;

    CandidateTypeId := Symbol.TypeId;
    TypeAlreadySeen := False;
    for SeenIndex := 0 to SeenTypeIds.Count - 1 do
      if SeenTypeIds[SeenIndex] = CandidateTypeId then
      begin
        TypeAlreadySeen := True;
        Break;
      end;
    if TypeAlreadySeen then
      Continue;

    SeenTypeIds.Push(CandidateTypeId);

    CandidateResolutionFailure := '';
    SetLength(Candidates, 0);
    CandidateTargetSymbolId := MethodSymbolIdForClassTypeMember(
      CandidateTypeId,
      AMemberName,
      AArgCount,
      AArgTypeIds,
      AArgSignature,
      AHasArgSignature,
      AHasTypeMismatchEvidence,
      CandidateResolutionFailure,
      Candidates
    );
    if CandidateTargetSymbolId <= 0 then
      Continue;

    Inc(MatchCount);
    if MatchCount > 1 then
      Exit(False);

    AReceiverTypeId := CandidateTypeId;
    ATargetSymbolId := CandidateTargetSymbolId;
  end;

  SeenTypeIds.Free;
  Result := MatchCount = 1;
end;

function TSemanticAnalyzer.TypeSymbolForTypeId(
  const ATypeId: LongInt;
  out ASymbol: TSemanticSymbol
): Boolean;
begin
  Result := np_sema_type_check.TypeSymbolForTypeId(FModel, ATypeId, ASymbol);
end;

function TSemanticAnalyzer.ClassTypeHasKnownNonMethodMember(
  const AClassTypeId: LongInt;
  const AMemberName: string
): Boolean;
var
  ConstValue: Int64;
  MemberPrefix: string;
  StringValue: string;
  TypeSymbol: TSemanticSymbol;
  FieldMeta: TFieldMeta;
begin
  Result := False;
  if (AClassTypeId <= 0) or (AMemberName = '') then
    Exit;
  if FModel.GetFieldMetaByName(AClassTypeId, AMemberName, FieldMeta) then
    Exit(True);
  if not TypeSymbolForTypeId(AClassTypeId, TypeSymbol) then
    Exit;
  MemberPrefix := TypeSymbol.Name + '.' + AMemberName;
  Result :=
    FModel.LookupConstValue(MemberPrefix + '$idx', ConstValue) or
    FModel.LookupStringConstValue(MemberPrefix + '$read', StringValue) or
    FModel.LookupStringConstValue(MemberPrefix + '$write', StringValue);
end;

function TSemanticAnalyzer.TypeIdHasKnownClassLayout(
  const ATypeId: LongInt
): Boolean;
begin
  Result := np_sema_type_check.TypeIdHasKnownClassLayout(FModel, ATypeId);
end;

function TSemanticAnalyzer.IsDeferredSystemObjectMember(
  const AMemberName: string
): Boolean;
begin
  Result := np_sema_type_check.IsDeferredSystemObjectMember(AMemberName);
end;

function TSemanticAnalyzer.TypeMetaSize(const ATypeName: string): Int64;
begin
  Result := np_sema_type_check.TypeMetaSize(FModel, ATypeName);
end;

function TSemanticAnalyzer.TypeMetaIsRecord(const ATypeName: string): Boolean;
begin
  Result := np_sema_type_check.TypeMetaIsRecord(FModel, ATypeName);
end;

function TSemanticAnalyzer.TypeMetaIsClass(const ATypeName: string): Boolean;
begin
  Result := np_sema_type_check.TypeMetaIsClass(FModel, ATypeName);
end;

function TSemanticAnalyzer.TypeMetaIsInterface(const ATypeName: string): Boolean;
begin
  Result := np_sema_type_check.TypeMetaIsInterface(FModel, ATypeName);
end;

function TSemanticAnalyzer.TypeIsInterfaceByName(const ATypeName: string): Boolean;
begin
  Result := np_sema_type_check.TypeIsInterfaceByName(FModel, ATypeName);
end;

function TSemanticAnalyzer.TypeMetaFieldIndex(
  const ATypeName, AFieldName: string): Int64;
begin
  Result := np_sema_type_check.TypeMetaFieldIndex(FModel, ATypeName, AFieldName);
end;

function TSemanticAnalyzer.TypeMetaFieldIsStr(
  const ATypeName, AFieldName: string): Boolean;
begin
  Result := np_sema_type_check.TypeMetaFieldIsStr(FModel, ATypeName, AFieldName);
end;

function TSemanticAnalyzer.TypeMetaFieldIsPtr(
  const ATypeName, AFieldName: string): Boolean;
begin
  Result := np_sema_type_check.TypeMetaFieldIsPtr(FModel, ATypeName, AFieldName);
end;

function TSemanticAnalyzer.TypeMetaFieldIsDynArray(
  const ATypeName, AFieldName: string): Boolean;
begin
  Result := np_sema_type_check.TypeMetaFieldIsDynArray(FModel, ATypeName, AFieldName);
end;

function TSemanticAnalyzer.TypeMetaFieldDynArrayElemSize(
  const ATypeName, AFieldName: string): Int64;
begin
  Result := np_sema_type_check.TypeMetaFieldDynArrayElemSize(FModel, ATypeName, AFieldName);
end;

function TSemanticAnalyzer.TypeMetaVmtSlot(
  const ATypeName, AMethodName: string): Int64;
begin
  Result := np_sema_type_check.TypeMetaVmtSlot(FModel, ATypeName, AMethodName);
end;

function TSemanticAnalyzer.TypeMetaRetPtr(
  const ATypeName, AMethodName: string): Boolean;
begin
  Result := np_sema_type_check.TypeMetaRetPtr(FModel, ATypeName, AMethodName);
end;

function TSemanticAnalyzer.TypeMetaRetStr(
  const ATypeName, AMethodName: string): Boolean;
begin
  Result := np_sema_type_check.TypeMetaRetStr(FModel, ATypeName, AMethodName);
end;

function TSemanticAnalyzer.TypeMetaParentClass(const ATypeName: string): string;
begin
  Result := np_sema_type_check.TypeMetaParentClass(FModel, ATypeName);
end;

function TSemanticAnalyzer.NextClassAncestorName(const ATypeName: string): string;
begin
  Result := np_sema_type_check.NextClassAncestorName(FModel, ATypeName);
end;

function TSemanticAnalyzer.TypeMetaVmtCount(const ATypeName: string): Int64;
begin
  Result := np_sema_type_check.TypeMetaVmtCount(FModel, ATypeName);
end;

function TSemanticAnalyzer.TypeMetaInterfaces(const ATypeName: string): string;
begin
  Result := np_sema_type_check.TypeMetaInterfaces(FModel, ATypeName);
end;

function TSemanticAnalyzer.TypeSignatureForTypeId(const ATypeId: LongInt): string;
var Ctx: TSemaOverloadContext;
begin
  Ctx.Model := FModel;
  Ctx.UnitGraph := FUnitGraph;
  Ctx.RootAst := FRootAst;
  Ctx.CurrentProcessingUnitId := FCurrentProcessingUnitId;
  Ctx.CurrentScopeId := FCurrentScopeId;
  Ctx.ProcedureBodies := FProcedureBodies;
  Ctx.ImportedUnitOwners := FImportedUnitOwners;
  Ctx.ImportedUnitTrees := FImportedUnitTrees;
  Ctx.BuiltinRegistry := FBuiltinRegistry;
  Result := np_sema_overload.TypeSignatureForTypeId(Ctx, ATypeId);
end;

function TSemanticAnalyzer.TypeIdHasStableScalarFact(
  const ATypeId: LongInt
): Boolean;
var
  TypeInfo: TSemanticType;
begin
  Result := False;
  if (ATypeId <= 0) or (ATypeId > FModel.TypeCount) then
    Exit;

  TypeInfo := FModel.TypeAt(ATypeId - 1);
  if FModel.TypeHasScalarFact(ATypeId) then
    Exit(True);

  if not SameText(TypeInfo.Kind, 'builtin') then
    Exit;

  Result :=
    SameText(TypeInfo.Name, 'AnsiString') or
    SameText(TypeInfo.Name, 'RawByteString') or
    SameText(TypeInfo.Name, 'ShortString') or
    SameText(TypeInfo.Name, 'WideString') or
    SameText(TypeInfo.Name, 'UnicodeString');
end;

function TSemanticAnalyzer.CallArgumentSignature(
  const ACallNode: TGreenNode;
  out ASignature: string
): Boolean;
var
  ArgNode: TGreenNode;
  ArgRoot: TGreenNode;
  ArgTypeId: LongInt;
  Index: LongInt;
  TypeSig: string;
begin
  ASignature := '';
  Result := False;
  if ACallNode = nil then
    Exit;

  ArgRoot := ACallNode;
  if (ACallNode.NodeKind = gnkProcedureCallStatement) and
    (ACallNode.ChildCount > 0) and
    (ACallNode.ChildAt(0) <> nil) and
    (ACallNode.ChildAt(0).NodeKind = gnkFunctionCall) then
    ArgRoot := ACallNode.ChildAt(0);

  if ArgRoot.NodeKind <> gnkFunctionCall then
    Exit(True);

  for Index := 1 to ArgRoot.ChildCount - 1 do
  begin
    ArgNode := ArgRoot.ChildAt(Index);
    ArgTypeId := InferExpressionType(ArgNode);
    TypeSig := TypeSignatureForTypeId(ArgTypeId);
    if TypeSig = '' then
      Exit(False);
    ASignature := ASignature + TypeSig;
  end;
  Result := True;
end;

function TSemanticAnalyzer.CallArgumentTypeIds(
  const ACallNode: TGreenNode;
  out ATypeIds: TTypeIdArray
): Boolean;
var
  ArgNode: TGreenNode;
  ArgRoot: TGreenNode;
  ArgTypeId: LongInt;
  Index: LongInt;
begin
  SetLength(ATypeIds, 0);
  Result := False;
  if ACallNode = nil then
    Exit;

  ArgRoot := ACallNode;
  if (ACallNode.NodeKind = gnkProcedureCallStatement) and
    (ACallNode.ChildCount > 0) and
    (ACallNode.ChildAt(0) <> nil) and
    (ACallNode.ChildAt(0).NodeKind = gnkFunctionCall) then
    ArgRoot := ACallNode.ChildAt(0);

  if ArgRoot.NodeKind <> gnkFunctionCall then
  begin
    Result := True;
    Exit;
  end;

  SetLength(ATypeIds, ArgRoot.ChildCount - 1);
  for Index := 1 to ArgRoot.ChildCount - 1 do
  begin
    ArgNode := ArgRoot.ChildAt(Index);
    ArgTypeId := InferExpressionType(ArgNode);
    ATypeIds[Index - 1] := ArgTypeId;
  end;
  Result := True;
end;

function TSemanticAnalyzer.TypeIdArrayHasKnownTypes(
  const ATypeIds: TTypeIdArray
): Boolean;
begin
  Result := np_sema_overload.TypeIdArrayHasKnownTypes(ATypeIds);
end;

function TSemanticAnalyzer.CanonicalTypeId(const ATypeId: LongInt): LongInt;
var Ctx: TSemaOverloadContext;
begin
  Ctx.Model := FModel;
  Ctx.UnitGraph := FUnitGraph;
  Ctx.RootAst := FRootAst;
  Ctx.CurrentProcessingUnitId := FCurrentProcessingUnitId;
  Ctx.CurrentScopeId := FCurrentScopeId;
  Ctx.ProcedureBodies := FProcedureBodies;
  Ctx.ImportedUnitOwners := FImportedUnitOwners;
  Ctx.ImportedUnitTrees := FImportedUnitTrees;
  Ctx.BuiltinRegistry := FBuiltinRegistry;
  Result := np_sema_overload.CanonicalTypeId(Ctx, ATypeId);
end;

function TSemanticAnalyzer.IsPointerTypeId(const ATypeId: LongInt): Boolean;
var Ctx: TSemaOverloadContext;
begin
  Ctx.Model := FModel;
  Ctx.UnitGraph := FUnitGraph;
  Ctx.RootAst := FRootAst;
  Ctx.CurrentProcessingUnitId := FCurrentProcessingUnitId;
  Ctx.CurrentScopeId := FCurrentScopeId;
  Ctx.ProcedureBodies := FProcedureBodies;
  Ctx.ImportedUnitOwners := FImportedUnitOwners;
  Ctx.ImportedUnitTrees := FImportedUnitTrees;
  Ctx.BuiltinRegistry := FBuiltinRegistry;
  Result := np_sema_overload.IsPointerTypeId(Ctx, ATypeId);
end;

function TSemanticAnalyzer.DeclParamTypesExactMatch(
  const ADecl: TGreenNode; const AOwnerUnitId: string;
  const AArgTypeIds: TTypeIdArray; const AArgCount: LongInt): Boolean;
var Ctx: TSemaOverloadContext;
begin
  Ctx.Model := FModel;
  Ctx.UnitGraph := FUnitGraph;
  Ctx.RootAst := FRootAst;
  Ctx.CurrentProcessingUnitId := FCurrentProcessingUnitId;
  Ctx.CurrentScopeId := FCurrentScopeId;
  Ctx.ProcedureBodies := FProcedureBodies;
  Ctx.ImportedUnitOwners := FImportedUnitOwners;
  Ctx.ImportedUnitTrees := FImportedUnitTrees;
  Ctx.BuiltinRegistry := FBuiltinRegistry;
  Result := np_sema_overload.DeclParamTypesExactMatch(Ctx, ADecl, AOwnerUnitId, AArgTypeIds, AArgCount);
end;

function TSemanticAnalyzer.DeclParamTypesCompatibleMatch(
  const ADecl: TGreenNode; const AOwnerUnitId: string;
  const AArgTypeIds: TTypeIdArray; const AArgCount: LongInt): Boolean;
var Ctx: TSemaOverloadContext;
begin
  Ctx.Model := FModel;
  Ctx.UnitGraph := FUnitGraph;
  Ctx.RootAst := FRootAst;
  Ctx.CurrentProcessingUnitId := FCurrentProcessingUnitId;
  Ctx.CurrentScopeId := FCurrentScopeId;
  Ctx.ProcedureBodies := FProcedureBodies;
  Ctx.ImportedUnitOwners := FImportedUnitOwners;
  Ctx.ImportedUnitTrees := FImportedUnitTrees;
  Ctx.BuiltinRegistry := FBuiltinRegistry;
  Result := np_sema_overload.DeclParamTypesCompatibleMatch(Ctx, ADecl, AOwnerUnitId, AArgTypeIds, AArgCount);
end;

function TSemanticAnalyzer.MethodSymbolIdForExactClassTypeMember(
  const AClassTypeId: LongInt;
  const AMemberName: string;
  const AArgCount: LongInt;
  const AArgTypeIds: TTypeIdArray;
  const AArgSignature: string;
  const AHasArgSignature: Boolean;
  const AHasTypeMismatchEvidence: Boolean;
  const AAllowNoMatchingOverloadDiagnostic: Boolean;
  out AMethodNameFound: Boolean;
  out AResolutionFailureKind: string;
  out ACandidates: TOverloadCandidateArray
): LongInt;
var
  BodyCandidateCount: LongInt;
  BodyCompatibleMatchCount: LongInt;
  BodyCompatibleMatchIndex: LongInt;
  BodyExactMatchCount: LongInt;
  BodyExactMatchIndex: LongInt;
  BodyMatchCount: LongInt;
  BestDist: LongInt;
  BestSymbolId: LongInt;
  Dist: LongInt;
  HasArgTypeIds: Boolean;
  Index: LongInt;
  QualifiedName: string;
  SameOwnerCount: LongInt;
  SameOwnerSymbolId: LongInt;
  Symbol: TSemanticSymbol;
  SignatureMatchCount: LongInt;
  SignatureSymbolId: LongInt;
  SymbolId: LongInt;
  SymbolMatchCount: LongInt;
  TypeSymbol: TSemanticSymbol;
begin
  Result := 0;
  AMethodNameFound := False;
  AResolutionFailureKind := '';
  if (AClassTypeId <= 0) or (AMemberName = '') then
    Exit;
  if not TypeSymbolForTypeId(AClassTypeId, TypeSymbol) then
    Exit;

  { Skip overload resolution for constructors/destructors with many overloads }
  if SameText(AMemberName, 'Create') or SameText(AMemberName, 'Destroy') or
    SameText(AMemberName, 'CreateFmt') or SameText(AMemberName, 'CreateRes') or
    SameText(AMemberName, 'Equal') then
  begin
    QualifiedName := TypeSymbol.Name + '.' + AMemberName;
    for Index := 0 to FModel.SymbolCount - 1 do
    begin
      Symbol := FModel.SymbolAt(Index);
      if SameText(Symbol.Name, QualifiedName) and
        (SameText(Symbol.Kind, 'constructor') or
         SameText(Symbol.Kind, 'destructor') or
         SameText(Symbol.Kind, 'method')) then
      begin
        AMethodNameFound := True;
        if (AArgCount >= Symbol.MinParamCount) and
           (AArgCount <= Symbol.ParamCount) then
        begin
          Result := Symbol.SymbolId;
          Exit;
        end;
      end;
    end;
    Exit;
  end;

  QualifiedName := TypeSymbol.Name + '.' + AMemberName;
  HasArgTypeIds := (Length(AArgTypeIds) = AArgCount) and
    TypeIdArrayHasKnownTypes(AArgTypeIds);
  SymbolId := 0;
  SignatureSymbolId := 0;
  SymbolMatchCount := 0;
  SignatureMatchCount := 0;
  SetLength(ACandidates, 0);
  for Index := 0 to FModel.SymbolCount - 1 do
  begin
    Symbol := FModel.SymbolAt(Index);
    if SameText(Symbol.Name, QualifiedName) and
      (SameText(Symbol.Kind, 'method') or
       SameText(Symbol.Kind, 'constructor') or
       SameText(Symbol.Kind, 'destructor')) then
    begin
      AMethodNameFound := True;
      SetLength(ACandidates, Length(ACandidates) + 1);
      ACandidates[High(ACandidates)].Name := Symbol.Name;
      ACandidates[High(ACandidates)].ParamCount := Symbol.ParamCount;
      ACandidates[High(ACandidates)].ParamSignature := Symbol.ParamSignature;
      ACandidates[High(ACandidates)].DeclByteOffset := Symbol.ByteOffset;
      if (AArgCount < Symbol.MinParamCount) or (AArgCount > Symbol.ParamCount) then
        ACandidates[High(ACandidates)].MismatchReason := 'param-count'
      else if AHasArgSignature and
        (not SameText(Copy(Symbol.ParamSignature, 1, Length(AArgSignature)), AArgSignature)) then
        ACandidates[High(ACandidates)].MismatchReason := 'type-mismatch'
      else
        ACandidates[High(ACandidates)].MismatchReason := '';
      if (AArgCount >= Symbol.MinParamCount) and (AArgCount <= Symbol.ParamCount) then
      begin
        Inc(SymbolMatchCount);
        SymbolId := Symbol.SymbolId;
        if (Symbol.ParamSignature = '') or
          (AHasArgSignature and
           SameText(Copy(Symbol.ParamSignature, 1, Length(AArgSignature)), AArgSignature)) then
        begin
          Inc(SignatureMatchCount);
          SignatureSymbolId := Symbol.SymbolId;
        end;
      end;
    end;
  end;
  BodyCandidateCount := 0;
  BodyCompatibleMatchCount := 0;
  BodyCompatibleMatchIndex := -1;
  BodyExactMatchCount := 0;
  BodyExactMatchIndex := -1;
  BodyMatchCount := 0;
  for Index := 0 to Length(FProcedureBodies) - 1 do
    if SameText(FProcedureBodies[Index].Name, QualifiedName) and
      SameText(FProcedureBodies[Index].OwnerUnitId, TypeSymbol.OwnerUnitId) then
    begin
      Inc(BodyCandidateCount);
      if DeclAcceptsArgCount(FProcedureBodies[Index].Decl, AArgCount) then
      begin
        if HasArgTypeIds and DeclParamTypesExactMatch(
          FProcedureBodies[Index].Decl,
          TypeSymbol.OwnerUnitId,
          AArgTypeIds,
          AArgCount
        ) then
        begin
          BodyExactMatchIndex := Index;
          Inc(BodyExactMatchCount);
        end
        else if HasArgTypeIds and DeclParamTypesCompatibleMatch(
          FProcedureBodies[Index].Decl,
          TypeSymbol.OwnerUnitId,
          AArgTypeIds,
          AArgCount
        ) then
        begin
          BodyCompatibleMatchIndex := Index;
          Inc(BodyCompatibleMatchCount);
        end;
        if (not AHasArgSignature) or
          SameText(GetParamSignature(FProcedureBodies[Index].Decl), AArgSignature) then
          Inc(BodyMatchCount);
      end;
    end;
  if HasArgTypeIds and
    ((BodyExactMatchCount > 0) or (BodyCompatibleMatchCount > 0)) then
  begin
    if BodyExactMatchCount = 1 then
      Exit(CallableSymbolIdForDeclaration(
        FProcedureBodies[BodyExactMatchIndex].Decl,
        TypeSymbol.OwnerUnitId
      ));
    if BodyExactMatchCount > 1 then
    begin
      AResolutionFailureKind := 'ambiguous-overload';
      Exit(0);
    end;
    if BodyCompatibleMatchCount = 1 then
      Exit(CallableSymbolIdForDeclaration(
        FProcedureBodies[BodyCompatibleMatchIndex].Decl,
        TypeSymbol.OwnerUnitId
      ));
    if BodyCompatibleMatchCount > 1 then
    begin
      AResolutionFailureKind := 'ambiguous-overload';
      Exit(0);
    end;
  end;
  if SymbolMatchCount = 0 then
  begin
    if AMethodNameFound and (
      SameText(
        TypeSymbol.OwnerUnitId,
        NormalizeUnitIdentity(FUnitGraph.RootName)
      ) or OwnerUnitAllowsProjectSourceDiagnostic(TypeSymbol.OwnerUnitId)
    ) then
      AResolutionFailureKind := 'wrong-argument-count';
    Exit;
  end;
  if AHasTypeMismatchEvidence and
    (SymbolMatchCount = 1) and AHasArgSignature and
    (SignatureMatchCount = 0) then
  begin
    if SameText(
      TypeSymbol.OwnerUnitId,
      NormalizeUnitIdentity(FUnitGraph.RootName)
    ) or OwnerUnitAllowsProjectSourceDiagnostic(TypeSymbol.OwnerUnitId) then
    begin
      AResolutionFailureKind := 'type-mismatch';
      Exit;
    end;
  end;
  if SymbolMatchCount > 1 then
  begin
    if AHasArgSignature and (SignatureMatchCount = 1) then
      SymbolId := SignatureSymbolId
    else if AHasArgSignature and (SignatureMatchCount > 1) then
    begin
      // Multiple symbols with matching signature — prefer the one from
      // the same owner unit as the receiver type. If exactly one matches
      // the owner unit, use it (local definition wins over imported
      // duplicate). If more than one matches the same owner unit, it is
      // a genuine ambiguous overload within the same unit.
      SameOwnerCount := 0;
      SameOwnerSymbolId := 0;
      for Index := 0 to FModel.SymbolCount - 1 do
      begin
        Symbol := FModel.SymbolAt(Index);
        if SameText(Symbol.Name, QualifiedName) and
          (SameText(Symbol.Kind, 'method') or
           SameText(Symbol.Kind, 'constructor') or
           SameText(Symbol.Kind, 'destructor')) and
          (AArgCount >= Symbol.MinParamCount) and
          (AArgCount <= Symbol.ParamCount) and
          AHasArgSignature and
          SameText(Copy(Symbol.ParamSignature, 1, Length(AArgSignature)), AArgSignature) and
          SameText(Symbol.OwnerUnitId, TypeSymbol.OwnerUnitId) then
        begin
          Inc(SameOwnerCount);
          if SameOwnerSymbolId = 0 then
            SameOwnerSymbolId := Symbol.SymbolId;
        end;
      end;
      if SameOwnerCount = 1 then
        SymbolId := SameOwnerSymbolId
      else
      begin
        AResolutionFailureKind := 'ambiguous-overload';
        SymbolId := 0;
      end;
    end
    else if not AHasArgSignature then
    begin
        BestDist := MaxInt;
        BestSymbolId := 0;
        for Index := 0 to FModel.SymbolCount - 1 do
        begin
          Symbol := FModel.SymbolAt(Index);
          if SameText(Symbol.Name, QualifiedName) and
            (SameText(Symbol.Kind, 'method') or
             SameText(Symbol.Kind, 'constructor') or
             SameText(Symbol.Kind, 'destructor')) and
            (AArgCount >= Symbol.MinParamCount) and
            (AArgCount <= Symbol.ParamCount) then
          begin
            Dist := Symbol.ParamCount - AArgCount;
            if Dist < 0 then Dist := -Dist;
            if (Dist < BestDist) or
              ((Dist = BestDist) and (BestSymbolId = 0)) then
            begin
              BestDist := Dist;
              BestSymbolId := Symbol.SymbolId;
            end;
          end;
        end;
        if BestSymbolId > 0 then
        begin
          SymbolId := BestSymbolId;
          // Continue to body check below
        end
        else
        begin
          if SameText(
            TypeSymbol.OwnerUnitId,
            NormalizeUnitIdentity(FUnitGraph.RootName)
          ) or OwnerUnitAllowsProjectSourceDiagnostic(TypeSymbol.OwnerUnitId) then
            AResolutionFailureKind := 'ambiguous-overload';
          Exit;
        end;
      end
    else if SignatureMatchCount = 0 then
    begin
      if AAllowNoMatchingOverloadDiagnostic and AHasTypeMismatchEvidence and
        (
          SameText(TypeSymbol.OwnerUnitId, NormalizeUnitIdentity(FUnitGraph.RootName)) or
          OwnerUnitAllowsProjectSourceDiagnostic(TypeSymbol.OwnerUnitId)
        ) then
        AResolutionFailureKind := 'no-matching-overload';
      Exit;
    end
    else
    begin
      if BestSymbolId > 0 then
      begin
        AResolutionFailureKind := 'ambiguous-overload';
        SymbolId := 0;
      end;
      Exit;
    end;
  end;
  if SymbolId <= 0 then
    Exit;

  if BodyCandidateCount = 0 then
    Exit(SymbolId);
  if BodyMatchCount > 1 then
  begin
    AResolutionFailureKind := 'ambiguous-overload';
    Exit;
  end;
  if BodyMatchCount = 0 then
    Exit;

  Result := SymbolId;
end;

function TSemanticAnalyzer.MethodSymbolIdForClassTypeMember(
  const AClassTypeId: LongInt;
  const AMemberName: string;
  const AArgCount: LongInt;
  const AArgTypeIds: TTypeIdArray;
  const AArgSignature: string;
  const AHasArgSignature: Boolean;
  const AHasTypeMismatchEvidence: Boolean;
  out AResolutionFailureKind: string;
  out ACandidates: TOverloadCandidateArray
): LongInt;
var
  CurrentTypeId: LongInt;
  Depth: LongInt;
  MethodNameFound: Boolean;
  TypeSymbol: TSemanticSymbol;
  AliasMeta: TTypeMetadata;
  PrevTypeId: LongInt;
begin
  Result := 0;
  AResolutionFailureKind := '';
  CurrentTypeId := AClassTypeId;
  Depth := 0;
  if not TypeIdHasKnownClassLayout(CurrentTypeId) then
  begin
    if FModel.GetTypeMeta(CurrentTypeId, AliasMeta) and
      (AliasMeta.AliasTargetTypeId > 0) then
      CurrentTypeId := AliasMeta.AliasTargetTypeId;
    if not TypeIdHasKnownClassLayout(CurrentTypeId) then
      Exit;
  end;
  while (CurrentTypeId > 0) and (Depth < 32) do
  begin
    if ClassTypeHasKnownNonMethodMember(CurrentTypeId, AMemberName) then
    begin
      if TypeSymbolForTypeId(CurrentTypeId, TypeSymbol) and
        (
          SameText(
            TypeSymbol.OwnerUnitId,
            NormalizeUnitIdentity(FUnitGraph.RootName)
          ) or
          OwnerUnitAllowsProjectSourceDiagnostic(TypeSymbol.OwnerUnitId)
        ) then
        AResolutionFailureKind := 'invalid-call-shape';
      Exit;
    end;

    Result := MethodSymbolIdForExactClassTypeMember(
      CurrentTypeId,
      AMemberName,
      AArgCount,
      AArgTypeIds,
      AArgSignature,
      AHasArgSignature,
      AHasTypeMismatchEvidence,
      (Depth = 0) or (
        TypeSymbolForTypeId(CurrentTypeId, TypeSymbol) and
        (
          SameText(
            TypeSymbol.OwnerUnitId,
            NormalizeUnitIdentity(FUnitGraph.RootName)
          ) or
          OwnerUnitAllowsProjectSourceDiagnostic(TypeSymbol.OwnerUnitId)
        )
      ),
      MethodNameFound,
      AResolutionFailureKind,
      ACandidates
    );
    if Result > 0 then
      Exit;
    if AResolutionFailureKind <> '' then
      Exit;
    if MethodNameFound then
      Exit;
    if (CurrentTypeId <= 0) or (CurrentTypeId > FModel.TypeCount) then
      Exit;
    PrevTypeId := CurrentTypeId;
    CurrentTypeId := FModel.TypeAt(PrevTypeId - 1).ParentTypeId;
    if (CurrentTypeId = 0) and FModel.GetTypeMeta(PrevTypeId, AliasMeta) and
      (AliasMeta.AliasTargetTypeId > 0) then
      CurrentTypeId := AliasMeta.AliasTargetTypeId;
    Inc(Depth);
  end;
  if IsDeferredSystemObjectMember(AMemberName) then
    Exit;
  if TypeSymbolForTypeId(AClassTypeId, TypeSymbol) and
    (not SameText(
      TypeSymbol.OwnerUnitId,
      NormalizeUnitIdentity(FUnitGraph.RootName)
    )) and
    (not OwnerUnitAllowsProjectSourceDiagnostic(TypeSymbol.OwnerUnitId)) then
    Exit;
  AResolutionFailureKind := 'unknown-member';
end;

function TSemanticAnalyzer.TryRegisterMemberCallBinding(
  const ACallNode: TGreenNode;
  const ACurrentMethodClass: string;
  const ACurrentOwnerUnitId: string;
  out AResolutionFailureKind: string;
  out AFailureName: string;
  out AFailureOffset: LongInt;
  out AActualArgCount: LongInt;
  out ACandidates: TOverloadCandidateArray
): Boolean;
var
  ArgCount: LongInt;
  ArgTypeIds: TTypeIdArray;
  ArgSignature: string;
  Candidates: TOverloadCandidateArray;
  HasArgSignature: Boolean;
  HasTypeMismatchEvidence: Boolean;
  MemberName: string;
  MemberOffset: LongInt;
  ReceiverName: string;
  ReceiverTypeId: LongInt;
  TargetSymbolId: LongInt;
begin
  Result := False;
  AResolutionFailureKind := '';
  AFailureName := '';
  AFailureOffset := 0;
  AActualArgCount := 0;
  TargetSymbolId := 0;
  SetLength(ACandidates, 0);
  if not ExtractDirectMemberCall(
    ACallNode,
    ReceiverName,
    MemberName,
    MemberOffset,
    ArgCount
  ) then
    Exit;
  AActualArgCount := ArgCount;
  AFailureName := MemberName;
  AFailureOffset := MemberOffset;
  if not CallArgumentTypeIds(ACallNode, ArgTypeIds) then
    SetLength(ArgTypeIds, 0);
  HasArgSignature := CallArgumentSignature(ACallNode, ArgSignature);
  HasTypeMismatchEvidence := HasArgSignature and
    CallArgumentSignatureIsStable(ACallNode, ACurrentOwnerUnitId);
  ReceiverTypeId := TypeIdForMemberReceiver(
    ReceiverName,
    ACurrentMethodClass,
    ACurrentOwnerUnitId
  );
  if ReceiverTypeId <= 0 then
  begin
    if not TryResolveTypeNameMemberCallTarget(
      ReceiverName,
      MemberName,
      ArgCount,
      ArgTypeIds,
      ArgSignature,
      HasArgSignature,
      HasTypeMismatchEvidence,
      ReceiverTypeId,
      TargetSymbolId
    ) then
      Exit;
  end;

  if TargetSymbolId <= 0 then
  begin
    TargetSymbolId := MethodSymbolIdForClassTypeMember(
      ReceiverTypeId,
      MemberName,
      ArgCount,
      ArgTypeIds,
      ArgSignature,
      HasArgSignature,
      HasTypeMismatchEvidence,
      AResolutionFailureKind,
      Candidates
    );
    ACandidates := Candidates;
  end;
  if TargetSymbolId <= 0 then
    Exit;

  if (ACurrentMethodClass = '') or
    (not SameText(ACurrentMethodClass,
      FModel.TypeAt(ReceiverTypeId - 1).Name)) then
  begin
    if SameText(FModel.SymbolAt(TargetSymbolId - 1).Visibility, 'private') and
      (not SameText(FModel.SymbolAt(TargetSymbolId - 1).OwnerUnitId,
        ACurrentOwnerUnitId)) then
    begin
      AResolutionFailureKind := 'inaccessible-member';
      Exit;
    end;
    if SameText(FModel.SymbolAt(TargetSymbolId - 1).Visibility, 'protected') and
      (not SameText(FModel.SymbolAt(TargetSymbolId - 1).OwnerUnitId,
        ACurrentOwnerUnitId)) then
    begin
      AResolutionFailureKind := 'inaccessible-member';
      Exit;
    end;
  end;

  FModel.AddBinding(
    'member-call',
    MemberName,
    ACurrentOwnerUnitId,
    MemberOffset,
    TargetSymbolId
  );
  Result := True;
end;

function TSemanticAnalyzer.TryRegisterImplicitSelfBareMethodCallBinding(
  const ACallNode: TGreenNode;
  const ACurrentMethodClass: string;
  const ACurrentOwnerUnitId: string;
  out AResolutionFailureKind: string;
  out AFailureName: string;
  out AFailureOffset: LongInt
): Boolean;
var
  ArgCount: LongInt;
  ArgTypeIds: TTypeIdArray;
  ArgSignature: string;
  CallName: string;
  HasArgSignature: Boolean;
  HasTypeMismatchEvidence: Boolean;
  ImplicitCandidates: TOverloadCandidateArray;
  ReceiverTypeId: LongInt;
  TargetSymbolId: LongInt;
begin
  Result := False;
  AResolutionFailureKind := '';
  AFailureName := '';
  AFailureOffset := 0;
  if (ACurrentMethodClass = '') or (ACallNode = nil) or
    not (ACallNode.NodeKind in [gnkProcedureCallStatement, gnkFunctionCall]) then
    Exit;

  CallName := BareCallCalleeName(ACallNode);
  if CallName = '' then
    Exit;
  AFailureName := CallName;
  AFailureOffset := ACallNode.ByteOffset;

  ReceiverTypeId := TypeIdForMemberReceiver(
    'Self',
    ACurrentMethodClass,
    ACurrentOwnerUnitId
  );
  if ReceiverTypeId <= 0 then
    Exit;

  ArgCount := CallArgumentCount(ACallNode);
  if not CallArgumentTypeIds(ACallNode, ArgTypeIds) then
    SetLength(ArgTypeIds, 0);
  HasArgSignature := CallArgumentSignature(ACallNode, ArgSignature);
  HasTypeMismatchEvidence := HasArgSignature and
    CallArgumentSignatureIsStable(ACallNode, ACurrentOwnerUnitId);
  TargetSymbolId := MethodSymbolIdForClassTypeMember(
    ReceiverTypeId,
    CallName,
    ArgCount,
    ArgTypeIds,
    ArgSignature,
    HasArgSignature,
    HasTypeMismatchEvidence,
    AResolutionFailureKind,
    ImplicitCandidates
  );
  if TargetSymbolId <= 0 then
    Exit;

  FModel.AddBinding(
    'member-call',
    CallName,
    ACurrentOwnerUnitId,
    ACallNode.ByteOffset,
    TargetSymbolId
  );
  Result := True;
end;

function TSemanticAnalyzer.BindCallArgs(const ADecl: TGreenNode;
  const ACallNode: TGreenNode;
  const ANameSkip: LongInt): TParamSnapshots;
var
  ParamList: TGreenNode;
  ParamDecl, ArgNode: TGreenNode;
  Index, ParamIndex, ArgIndex: LongInt;
  Value, Prior: Int64;
  Snap: TParamSnapshot;
begin
  Result := nil;
  if (ADecl = nil) or (ACallNode = nil) then
    Exit;
  ParamList := nil;
  for Index := 0 to ADecl.ChildCount - 1 do
    if (ADecl.ChildAt(Index) <> nil) and
      (ADecl.ChildAt(Index).NodeKind = gnkParameterList) then
    begin
      ParamList := ADecl.ChildAt(Index);
      Break;
    end;
  if ParamList = nil then
    Exit;
  ParamIndex := 0;
  for Index := 0 to ParamList.ChildCount - 1 do
  begin
    ParamDecl := ParamList.ChildAt(Index);
    if (ParamDecl = nil) or (ParamDecl.NodeKind <> gnkParameterDecl) then
      Continue;
    ArgIndex := ANameSkip + ParamIndex;
    if ArgIndex >= ACallNode.ChildCount then
      Break;
    ArgNode := ACallNode.ChildAt(ArgIndex);
    if (ArgNode <> nil) and EvaluateIntegerConstant(ArgNode, Value) then
    begin
      Snap.Name := ParamDecl.Text;
      Snap.HadValue := FModel.LookupVarInitValue(ParamDecl.Text, Prior);
      Snap.PriorValue := Prior;
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := Snap;
      FModel.AddVarInitValue(ParamDecl.Text, Value);
    end;
    Inc(ParamIndex);
  end;
end;

procedure TSemanticAnalyzer.RestoreCallArgs(const ASnapshots: TParamSnapshots);
var
  Index: LongInt;
begin
  for Index := High(ASnapshots) downto 0 do
  begin
    if ASnapshots[Index].HadValue then
      FModel.AddVarInitValue(ASnapshots[Index].Name,
        ASnapshots[Index].PriorValue)
    else
      FModel.RemoveVarInitValue(ASnapshots[Index].Name);
  end;
end;

function TSemanticAnalyzer.EnsureUnitScope(
  const AOwnerUnitId: string
): LongInt;
var
  Index: LongInt;
  Scope: TSemanticScope;
begin
  Result := 0;
  if Trim(AOwnerUnitId) = '' then
    Exit;

  for Index := 0 to FModel.ScopeCount - 1 do
  begin
    Scope := FModel.ScopeAt(Index);
    if (Scope.Kind = skUnit) and
      SameText(NormalizeUnitIdentity(Scope.Name), AOwnerUnitId) then
      Exit(Scope.ScopeId);
  end;

  Result := FModel.AddScope(skUnit, AOwnerUnitId, 1);
end;

function TSemanticAnalyzer.CallableSymbolIdForDeclaration(
  const ADecl: TGreenNode;
  const AOwnerUnitId: string
): LongInt;
var
  Child: TGreenNode;
  ExpectedKind: string;
  Index: LongInt;
  ParamCount: LongInt;
  ParamSignature: string;
  Symbol: TSemanticSymbol;
  TypeId: LongInt;
begin
  Result := 0;
  if ADecl = nil then
    Exit;

  if Pos('.', ADecl.Text) > 0 then
    Exit;

  if ADecl.NodeKind = gnkFunctionDecl then
    ExpectedKind := 'function'
  else if ADecl.NodeKind = gnkProcedureDecl then
    ExpectedKind := 'procedure'
  else
    ExpectedKind := '';
  ParamCount := CountDeclParams(ADecl);
  ParamSignature := GetParamSignature(ADecl);

  for Index := 0 to FModel.SymbolCount - 1 do
  begin
    Symbol := FModel.SymbolAt(Index);
    if (Symbol.ByteOffset = ADecl.ByteOffset) and
      SameText(Symbol.Name, ADecl.Text) and
      ((AOwnerUnitId = '') or SameText(Symbol.OwnerUnitId, AOwnerUnitId)) and
      (SameText(Symbol.Kind, 'procedure') or
       SameText(Symbol.Kind, 'function') or
       SameText(Symbol.Kind, 'method')) then
      Exit(Symbol.SymbolId);
  end;

  for Index := 0 to FModel.SymbolCount - 1 do
  begin
    Symbol := FModel.SymbolAt(Index);
    if SameText(Symbol.Name, ADecl.Text) and
      ((AOwnerUnitId = '') or SameText(Symbol.OwnerUnitId, AOwnerUnitId)) and
      ((ExpectedKind = '') or SameText(Symbol.Kind, ExpectedKind)) and
      (Symbol.ParamCount = ParamCount) and
      SameText(Symbol.ParamSignature, ParamSignature) then
      Exit(Symbol.SymbolId);
  end;

  if (ExpectedKind = '') or (AOwnerUnitId = '') then
    Exit;

  TypeId := 0;
  if ADecl.NodeKind = gnkFunctionDecl then
    for Index := 0 to ADecl.ChildCount - 1 do
    begin
      Child := ADecl.ChildAt(Index);
      if (Child <> nil) and (Child.NodeKind = gnkIdentifier) then
      begin
        TypeId := ResolveTypeIdForOwner(Child.Text, AOwnerUnitId);
        Break;
      end;
    end;

  Result := FModel.AddSymbol(
    ADecl.Text,
    ExpectedKind,
    AOwnerUnitId,
    TypeId,
    ADecl.ByteOffset
  );
  FModel.SetSymbolParamCount(Result, ParamCount);
  FModel.SetSymbolMinParamCount(Result, CountRequiredDeclParams(ADecl));
  FModel.SetSymbolParamSignature(Result, ParamSignature);
  FModel.SetSymbolScope(Result, EnsureUnitScope(AOwnerUnitId));
end;

procedure TSemanticAnalyzer.RegisterCallBinding(
  const ACallNode: TGreenNode;
  const ADecl: TGreenNode;
  const AOwnerUnitId: string
);
var
  SymbolId: LongInt;
begin
  if (ACallNode = nil) or (ADecl = nil) then
    Exit;

  SymbolId := CallableSymbolIdForDeclaration(ADecl, AOwnerUnitId);
  if SymbolId <= 0 then
    Exit;

  FModel.AddBinding(
    'call',
    ACallNode.Text,
    NormalizeUnitIdentity(FUnitGraph.RootName),
    ACallNode.ByteOffset,
    SymbolId
  );
end;

procedure TSemanticAnalyzer.SeedCallBindingsInNode(
  const ANode: TGreenNode;
  const ACurrentMethodClass: string;
  const ACurrentOwnerUnitId: string
);
var
  ArgIndex: LongInt;
  ArgTypeIds: TTypeIdArray;
  ArgSignature: string;
  BodyNode: TGreenNode;
  CallableScopeId: LongInt;
  Child: TGreenNode;
  DeclNode: TGreenNode;
  HasArgSignature: Boolean;
  HasTypeMismatchEvidence: Boolean;
  ImplicitSelfBound: Boolean;
  Index: LongInt;
  MemberFailureName: string;
  MemberFailureOffset: LongInt;
  MemberActualArgCount: LongInt;
  MemberCandidates: TOverloadCandidateArray;
  Payload: TDiagnosticPayload;
  MethodClass: string;
  CallableOwnerUnitId: string;
  QualifiedPos: LongInt;
  ResolutionFailureKind: string;
  SavedResKind: string;
  SavedScopeId: LongInt;
  TypeCastTargetTypeId: LongInt;
begin
  if ANode = nil then
    Exit;

  MethodClass := ACurrentMethodClass;
  SavedScopeId := FCurrentScopeId;
  if ANode.NodeKind in [gnkProcedureDecl, gnkFunctionDecl] then
  begin
    QualifiedPos := Pos('.', ANode.Text);
    if QualifiedPos > 1 then
      MethodClass := Copy(ANode.Text, 1, QualifiedPos - 1);
    CallableScopeId := ProcedureBodyScopeIdForDecl(ANode);
    if CallableScopeId > 0 then
      FCurrentScopeId := CallableScopeId;
  end;

  if ANode.NodeKind in [gnkProcedureCallStatement, gnkFunctionCall] then
  begin
    if IsQualifiedCallNode(ANode) then
    begin
      if (not TryRegisterMemberCallBinding(
        ANode,
        MethodClass,
        ACurrentOwnerUnitId,
        ResolutionFailureKind,
        MemberFailureName,
        MemberFailureOffset,
        MemberActualArgCount,
        MemberCandidates
      )) and SameText(ResolutionFailureKind, 'ambiguous-overload') then
      begin
        EmitSemaError(
          'sema.ambiguous-overload',
          'ambiguous call to overloaded function "' + MemberFailureName + '"',
          MemberFailureOffset
        );
      end
      else if SameText(ResolutionFailureKind, 'wrong-argument-count') then
      begin
        Payload.Kind := dpkWrongArgumentCount;
        Payload.ActualCount := MemberActualArgCount;
        Payload.ExpectedCount := 0;
        if Length(MemberCandidates) > 0 then
          Payload.ExpectedCount := MemberCandidates[0].ParamCount;
        Payload.Candidates := MemberCandidates;
        FDiagnostics.EmitErrorWithPayload(
          'sema.wrong-argument-count', 'sema',
          BuildCoreSourceSpan(FRootFileId, MemberFailureOffset, 0),
          'wrong number of arguments for "' + MemberFailureName + '"',
          Payload);
        FModel.MarkFailure;
      end
      else if SameText(ResolutionFailureKind, 'type-mismatch') then
        EmitSemaError(
          'sema.type-mismatch',
          'argument type mismatch for "' + MemberFailureName + '"',
          MemberFailureOffset
        )
      else if SameText(ResolutionFailureKind, 'no-matching-overload') then
      begin
        Payload.Kind := dpkOverloadCandidates;
        Payload.Candidates := MemberCandidates;
        FDiagnostics.EmitErrorWithPayload(
          'sema.no-matching-overload', 'sema',
          BuildCoreSourceSpan(FRootFileId, MemberFailureOffset, 0),
          'no matching overload for "' + MemberFailureName + '"',
          Payload);
        FModel.MarkFailure;
      end
      else if SameText(ResolutionFailureKind, 'unknown-member') then
        EmitSemaError(
          'sema.unknown-member',
          'unknown member "' + MemberFailureName + '"',
          MemberFailureOffset
        )
      else if SameText(ResolutionFailureKind, 'invalid-call-shape') then
        EmitSemaError(
          'sema.invalid-call-shape',
          'member "' + MemberFailureName + '" is not callable',
          MemberFailureOffset
        )
      else if SameText(ResolutionFailureKind, 'inaccessible-member') then
        EmitSemaError(
          'sema.inaccessible-member',
          'cannot access private member "' + MemberFailureName + '"',
          MemberFailureOffset
        );
    end
    else if Pos('.', ANode.Text) = 0 then
    begin
      { Type cast: TypeId(Arg) — skip call binding for type casts }
      if TryGetTypeCastTargetTypeId(ANode, TypeCastTargetTypeId) then
      begin
        { Type cast detected; no call binding needed }
      end
      else
      begin
      MemberFailureName := ANode.Text;
      MemberFailureOffset := ANode.ByteOffset;
      if not CallArgumentTypeIds(ANode, ArgTypeIds) then
        SetLength(ArgTypeIds, 0);
      HasArgSignature := CallArgumentSignature(ANode, ArgSignature);
      HasTypeMismatchEvidence := HasArgSignature and
        CallArgumentSignatureIsStable(ANode, ACurrentOwnerUnitId);
      ImplicitSelfBound := False;
      if SameText(ANode.Text, 'ACallback') then
      if LookupCallBindingDeclaration(
        ANode.Text,
        CallArgumentCount(ANode),
        ArgTypeIds,
        ArgSignature,
        HasArgSignature,
        HasTypeMismatchEvidence,
        ResolutionFailureKind,
        BodyNode,
        DeclNode,
        CallableOwnerUnitId
      ) then
        RegisterCallBinding(ANode, DeclNode, CallableOwnerUnitId)
      else
      begin
        if (MethodClass <> '') and
          (SameText(ResolutionFailureKind, 'unknown-callable') or
           SameText(ResolutionFailureKind, 'wrong-argument-count') or
           SameText(ResolutionFailureKind, 'type-mismatch') or
           SameText(ResolutionFailureKind, 'no-matching-overload')) then
        begin
          SavedResKind := ResolutionFailureKind;
          ImplicitSelfBound := TryRegisterImplicitSelfBareMethodCallBinding(
            ANode,
            MethodClass,
            ACurrentOwnerUnitId,
            ResolutionFailureKind,
            MemberFailureName,
            MemberFailureOffset
          );
          if not ImplicitSelfBound then
            ResolutionFailureKind := SavedResKind;
        end;
        if (not ImplicitSelfBound) and
          SameText(ResolutionFailureKind, 'ambiguous-overload') then
        begin
          EmitSemaError(
            'sema.ambiguous-overload',
            'ambiguous call to overloaded function "' + MemberFailureName + '"',
            MemberFailureOffset
          );
        end
        else if (not ImplicitSelfBound) and
          SameText(ResolutionFailureKind, 'wrong-argument-count') then
          EmitSemaError(
            'sema.wrong-argument-count',
            'wrong number of arguments for "' + MemberFailureName + '"',
            MemberFailureOffset
          )
        else if (not ImplicitSelfBound) and
          SameText(ResolutionFailureKind, 'type-mismatch') then
          EmitSemaError(
            'sema.type-mismatch',
            'argument type mismatch for "' + MemberFailureName + '"',
            MemberFailureOffset
          )
        else if (not ImplicitSelfBound) and
          SameText(ResolutionFailureKind, 'no-matching-overload') then
          EmitSemaError(
            'sema.no-matching-overload',
            'no matching overload for "' + MemberFailureName + '"',
            MemberFailureOffset
          )
        else if (not ImplicitSelfBound) and
          SameText(ResolutionFailureKind, 'unknown-member') then
          EmitSemaError(
            'sema.unknown-member',
            'unknown member "' + MemberFailureName + '"',
            MemberFailureOffset
          )
        else if (not ImplicitSelfBound) and
          SameText(ResolutionFailureKind, 'invalid-call-shape') then
          EmitSemaError(
            'sema.invalid-call-shape',
            'member "' + MemberFailureName + '" is not callable',
            MemberFailureOffset
          )
        else if (not ImplicitSelfBound) and
          SameText(ResolutionFailureKind, 'unknown-callable') and
          (MethodClass = '') then
          EmitSemaError(
            'sema.unknown-callable',
            'unknown callable "' + ANode.Text + '"',
            ANode.ByteOffset
          );
      end;
      end; { not a type cast }
    end;
  end;

  for Index := 0 to ANode.ChildCount - 1 do
  begin
    Child := ANode.ChildAt(Index);
    if Child = nil then
      Continue;
    if IsWrappedCallChild(ANode, Child) then
    begin
      for ArgIndex := 1 to Child.ChildCount - 1 do
        SeedCallBindingsInNode(
          Child.ChildAt(ArgIndex),
          MethodClass,
          ACurrentOwnerUnitId
        );
      Continue;
    end;
    if Child <> nil then
      SeedCallBindingsInNode(Child, MethodClass, ACurrentOwnerUnitId);
  end;
  FCurrentScopeId := SavedScopeId;
end;

procedure TSemanticAnalyzer.SeedCallBindings;
var
  Index: LongInt;
  RootOwnerUnitId: string;
begin
  if (FRootAst = nil) or (FRootAst.RootNode = nil) then
    Exit;

  RootOwnerUnitId := NormalizeUnitIdentity(FUnitGraph.RootName);
  FCurrentProcessingUnitId := RootOwnerUnitId;
  SeedCallBindingsInNode(FRootAst.RootNode, '', RootOwnerUnitId);
  for Index := 0 to Length(FProcedureBodies) - 1 do
    if (Pos('.', FProcedureBodies[Index].Name) > 0) and
      OwnerUnitAllowsProjectSourceDiagnostic(
        FProcedureBodies[Index].OwnerUnitId
      ) then
    begin
      FCurrentProcessingUnitId :=
        NormalizeUnitIdentity(FProcedureBodies[Index].OwnerUnitId);
      SeedCallBindingsInNode(
        FProcedureBodies[Index].Decl,
        '',
        FProcedureBodies[Index].OwnerUnitId
      );
    end;
end;

function TSemanticAnalyzer.IsCurrentlyInlining(const AName: string): Boolean;
var
  Index: LongInt;
begin
  for Index := 0 to FInliningStack.Count - 1 do
    if SameText(FInliningStack[Index], AName) then
      Exit(True);
  Result := False;
end;

procedure TSemanticAnalyzer.PushInlining(const AName: string);
begin
  FInliningStack.Push(AName);
end;

procedure TSemanticAnalyzer.PopInlining;
begin
  if FInliningStack.Count > 0 then
    FInliningStack.Pop;
end;

function EncodeRuntimeIntExpr(const ANode: TGreenNode;
  out ABlob: string): Boolean; forward;

function EncodeRuntimeBoolExpr(const ANode: TGreenNode;
  out ABlob: string): Boolean;
var
  LeftBlob, RightBlob, Op, Pred: string;
begin
  ABlob := '';
  if ANode = nil then
    Exit(False);
  if ANode.NodeKind <> gnkBinaryExpression then
    Exit(False);
  if ANode.ChildCount < 2 then
    Exit(False);
  Op := ANode.Text;
  if Op = '=' then Pred := 'eq'
  else if Op = '<>' then Pred := 'ne'
  else if Op = '<' then Pred := 'slt'
  else if Op = '<=' then Pred := 'sle'
  else if Op = '>' then Pred := 'sgt'
  else if Op = '>=' then Pred := 'sge'
  else
    Exit(False);
  if not EncodeRuntimeIntExpr(ANode.ChildAt(0), LeftBlob) then
    Exit(False);
  if not EncodeRuntimeIntExpr(ANode.ChildAt(1), RightBlob) then
    Exit(False);
  ABlob := LeftBlob + RightBlob + 'cmp ' + Pred + #10;
  Result := True;
end;

function EncodeRuntimeIntExpr(const ANode: TGreenNode;
  out ABlob: string): Boolean;
var
  LeftBlob, RightBlob, Op: string;
  Parsed: Int64;
  ParseCode: Word;
begin
  ABlob := '';
  if ANode = nil then
    Exit(False);
  case ANode.NodeKind of
    gnkIntegerLiteral:
      begin
        Val(ANode.Text, Parsed, ParseCode);
        if ParseCode <> 0 then
          Exit(False);
        ABlob := 'int ' + IntToStr(Parsed) + #10;
        Exit(True);
      end;
    gnkIdentifier:
      begin
        if ANode.Text = '' then
          Exit(False);
        ABlob := 'var ' + ANode.Text + #10;
        Exit(True);
      end;
    gnkUnaryExpression:
      begin
        if ANode.ChildCount < 1 then
          Exit(False);
        if not EncodeRuntimeIntExpr(ANode.ChildAt(0), LeftBlob) then
          Exit(False);
        Op := ANode.Text;
        if Op = '-' then
        begin
          ABlob := LeftBlob + 'neg' + #10;
          Exit(True);
        end
        else if Op = '+' then
        begin
          ABlob := LeftBlob;
          Exit(True);
        end
        else
          Exit(False);
      end;
    gnkBinaryExpression:
      begin
        if ANode.ChildCount < 2 then
          Exit(False);
        if not EncodeRuntimeIntExpr(ANode.ChildAt(0), LeftBlob) then
          Exit(False);
        if not EncodeRuntimeIntExpr(ANode.ChildAt(1), RightBlob) then
          Exit(False);
        Op := ANode.Text;
        if Op = '+' then
          ABlob := LeftBlob + RightBlob + 'add' + #10
        else if Op = '-' then
          ABlob := LeftBlob + RightBlob + 'sub' + #10
        else if Op = '*' then
          ABlob := LeftBlob + RightBlob + 'mul' + #10
        else if SameText(Op, 'div') then
          ABlob := LeftBlob + RightBlob + 'div' + #10
        else if SameText(Op, 'mod') then
          ABlob := LeftBlob + RightBlob + 'mod' + #10
        else
          Exit(False);
        Exit(True);
      end;
    gnkFunctionCall:
      begin
        if ANode.ChildCount < 1 then
          Exit(False);
        if ANode.ChildAt(0).NodeKind <> gnkIdentifier then
          Exit(False);
        if SameText(ANode.ChildAt(0).Text, 'Length') and
          (ANode.ChildCount = 2) and
          (ANode.ChildAt(1) <> nil) and
          (ANode.ChildAt(1).NodeKind = gnkIdentifier) then
        begin
          ABlob := 'var ' + ANode.ChildAt(1).Text + '$len' + #10;
          Exit(True);
        end;
        ABlob := '';
        for Parsed := 1 to ANode.ChildCount - 1 do
        begin
          if not EncodeRuntimeIntExpr(ANode.ChildAt(Parsed), RightBlob) then
            Exit(False);
          ABlob := ABlob + RightBlob;
        end;
        ABlob := ABlob + 'call ' + ANode.ChildAt(0).Text + ' ' +
          IntToStr(ANode.ChildCount - 1) + #10;
        Exit(True);
      end;
    gnkDotAccess:
      begin
        if ANode.ChildCount < 2 then
          Exit(False);
        if ANode.ChildAt(0).NodeKind <> gnkIdentifier then
          Exit(False);
        if ANode.ChildAt(1).NodeKind <> gnkIdentifier then
          Exit(False);
        ABlob := 'var ' + ANode.ChildAt(0).Text + '.' +
          ANode.ChildAt(1).Text + #10;
        Exit(True);
      end;
    gnkArrayAccess:
      begin
        if ANode.ChildCount < 2 then
          Exit(False);
        if ANode.ChildAt(0).NodeKind <> gnkIdentifier then
          Exit(False);
        if not EncodeRuntimeIntExpr(ANode.ChildAt(1), LeftBlob) then
          Exit(False);
        ABlob := LeftBlob + 'arrload ' + ANode.ChildAt(0).Text + #10;
        Exit(True);
      end;
  end;
  Result := False;
end;

procedure TSemanticAnalyzer.EmitSemaError(
  const ACode: string;
  const AMessage: string;
  const AByteOffset: LongInt
);
var
  EmptyPayload: TDiagnosticPayload;
begin
  EmptyPayload.Kind := dpkNone;
  FDiagnostics.EmitErrorWithPayload(
    ACode, 'sema',
    BuildCoreSourceSpan(FRootFileId, AByteOffset, 0),
    AMessage, EmptyPayload);
  FModel.MarkFailure;
end;

function TSemanticAnalyzer.IsSimpleIdentifierName(const AName: string): Boolean;
begin
  Result := np_sema_type_check.IsSimpleIdentifierName(AName);
end;

function TSemanticAnalyzer.RegisterSymbol(
  const AName: string;
  const AKind: string;
  const AOwnerUnitId: string;
  const ATypeId: LongInt;
  const AByteOffset: LongInt
): LongInt;
var
  Existing: LongInt;
begin
  if (FCurrentScopeId > 0) and (AName <> '') then
  begin
    Existing := FModel.FindSymbolInScope(AName, FCurrentScopeId);
    if (Existing > 0) and
      not SameText(AKind, 'parameter') and
      not SameText(FModel.SymbolAt(Existing - 1).Kind, 'parameter') and
      not SameText(AKind, 'constant') and
      not SameText(FModel.SymbolAt(Existing - 1).Kind, 'constant') and
      not (SameText(AKind, 'type') and
           SameText(FModel.SymbolAt(Existing - 1).Kind, 'type')) then
    begin
      EmitSemaError(
        'sema.duplicate-declaration',
        'duplicate identifier "' + AName + '"',
        AByteOffset
      );
    end;
  end;
  Result := FModel.AddSymbol(AName, AKind, AOwnerUnitId, ATypeId, AByteOffset);
  if FCurrentScopeId > 0 then
    FModel.SetSymbolScope(Result, FCurrentScopeId);
end;

function TSemanticAnalyzer.IsBuiltinProcedure(const AName: string): Boolean;
begin
  Result := FBuiltinRegistry.IsBuiltinProcedure(AName);
end;

function TSemanticAnalyzer.InferExpressionType(const ANode: TGreenNode): LongInt;
var
  ArgNode: TGreenNode;
  BaseTypeId: LongInt;
  CallName: string;
  FieldMeta: TFieldMeta;
  LStrTypeId: LongInt;
  RType: LongInt;
  SymId: LongInt;
  TargetTypeId: LongInt;
  Sym: TSemanticSymbol;
  LReceiverTypeId: LongInt;
  LFieldMeta: TFieldMeta;
  LTypeName: string;
  LDotPos: LongInt;
  LReceiverName: string;
  LMemberName: string;
  LQualifiedName: string;
  LBodyIdx: LongInt;
begin
  Result := 0;
  if ANode = nil then
    Exit;
  case ANode.NodeKind of
    gnkIntegerLiteral:
      Result := FModel.FindTypeByName('Integer');
    gnkRealLiteral:
      Result := FModel.FindTypeByName('Double');
    gnkStringLiteral:
      Result := FModel.FindTypeByName('AnsiString');
    gnkCharLiteral:
      Result := FModel.FindTypeByName('Char');
    gnkIdentifier:
      begin
        if SameText(ANode.Text, 'True') or SameText(ANode.Text, 'False') then
          Exit(FModel.FindTypeByName('Boolean'));
        SymId := FModel.LookupSymbol(ANode.Text, FCurrentScopeId);
        if SymId <= 0 then
          SymId := FModel.FindSymbolByName(ANode.Text);
        if SymId > 0 then
        begin
          Sym := FModel.SymbolAt(SymId - 1);
          Result := Sym.TypeId;
        end
        else
          Result := FModel.FindTypeByName(ANode.Text);
      end;
    gnkBinaryExpression:
      begin
        if ANode.Text = '+' then
        begin
          LStrTypeId := FModel.FindTypeByName('AnsiString');
          Result := InferExpressionType(ANode.ChildAt(0));
          if Result = LStrTypeId then
            Exit;
          RType := InferExpressionType(ANode.ChildAt(1));
          if RType = LStrTypeId then
          begin
            Result := LStrTypeId;
            Exit;
          end;
          if Result = 0 then
            Result := RType;
          if Result = 0 then
            Result := FModel.FindTypeByName('Integer');
        end
        else if (ANode.Text = '=') or (ANode.Text = '<>') or
          (ANode.Text = '<') or (ANode.Text = '>') or
          (ANode.Text = '<=') or (ANode.Text = '>=') or
          (ANode.Text = 'in') or (ANode.Text = 'is') then
          Result := FModel.FindTypeByName('Boolean')
        else if (ANode.Text = 'and') or (ANode.Text = 'or') or
          (ANode.Text = 'xor') then
        begin
          Result := InferExpressionType(ANode.ChildAt(0));
          if Result = FModel.FindTypeByName('Boolean') then
            Exit;
          Result := FModel.FindTypeByName('Integer');
        end
        else if ANode.Text = '/' then
          Result := FModel.FindTypeByName('Double')
        else
        begin
          Result := InferExpressionType(ANode.ChildAt(0));
          if Result = 0 then
            Result := FModel.FindTypeByName('Integer');
        end;
      end;
    gnkUnaryExpression:
      begin
        if ANode.Text = '@' then
          Exit(FModel.FindTypeByName('Pointer'));
        if ANode.Text = 'not' then
          Result := InferExpressionType(ANode.ChildAt(0))
        else
          Result := InferExpressionType(ANode.ChildAt(0));
        if Result = 0 then
          Result := FModel.FindTypeByName('Integer');
      end;
    gnkFunctionCall:
      begin
        if TryGetTypeCastTargetTypeId(ANode, TargetTypeId) then
          Exit(TargetTypeId);
        if TryGetIntrinsicExprName(ANode, CallName) then
        begin
          if SameText(CallName, 'Default') and (ANode.ChildCount >= 2) then
          begin
            ArgNode := ANode.ChildAt(1);
            if (ArgNode <> nil) and (ArgNode.NodeKind = gnkIdentifier) then
            begin
              Result := ResolveTypeIdForOwner(
                ArgNode.Text,
                NormalizeUnitIdentity(FCurrentProcessingUnitId)
              );
              if Result <= 0 then
                Result := ResolveTypeIdForOwner(
                  ArgNode.Text,
                  NormalizeUnitIdentity(FUnitGraph.RootName)
                );
            end;
            if Result <= 0 then
              Result := InferExpressionType(ArgNode);
            Exit;
          end;
          if SameText(CallName, 'SizeOf') or SameText(CallName, 'High') or
            SameText(CallName, 'Low') or SameText(CallName, 'Length') or
            SameText(CallName, 'Ord') or SameText(CallName, 'Round') or
            SameText(CallName, 'Trunc') or SameText(CallName, 'Floor') or
            SameText(CallName, 'Ceil') then
            Exit(FModel.FindTypeByName('Integer'));
          if SameText(CallName, 'Chr') then
            Exit(FModel.FindTypeByName('Char'));
          if SameText(CallName, 'Assigned') then
            Exit(FModel.FindTypeByName('Boolean'));
          if SameText(CallName, 'Supports') or SameText(CallName, 'IsFinite') then
            Exit(FModel.FindTypeByName('Boolean'));
          if SameText(CallName, 'Min') or SameText(CallName, 'Max') then
          begin
            if ANode.ChildCount >= 2 then
              Result := InferExpressionType(ANode.ChildAt(1));
            if Result = 0 then
              Result := FModel.FindTypeByName('Integer');
            Exit;
          end;
          if SameText(CallName, 'Sqrt') then
            Exit(FModel.FindTypeByName('Double'));
          if SameText(CallName, 'Pred') or SameText(CallName, 'Succ') or
            SameText(CallName, 'Abs') or SameText(CallName, 'Sqr') then
          begin
            if ANode.ChildCount >= 2 then
              Result := InferExpressionType(ANode.ChildAt(1));
            if Result = 0 then
              Result := FModel.FindTypeByName('Integer');
            Exit;
          end;
        end;
        SymId := FModel.LookupSymbol(BareCallCalleeName(ANode), FCurrentScopeId);
        if SymId > 0 then
        begin
          Sym := FModel.SymbolAt(SymId - 1);
          Result := Sym.TypeId;
        end
        else if Pos('.', ANode.Text) > 1 then
        begin
          LDotPos := Pos('.', ANode.Text);
          LReceiverName := Copy(ANode.Text, 1, LDotPos - 1);
          LMemberName := Copy(ANode.Text, LDotPos + 1, Length(ANode.Text));
          LReceiverTypeId := 0;
          if SameText(LReceiverName, 'Self') and (FCurrentMethodClass <> '') then
            LReceiverTypeId := FModel.FindTypeByName(FCurrentMethodClass)
          else
          begin
            SymId := FModel.LookupSymbol(LReceiverName, FCurrentScopeId);
            if SymId > 0 then
            begin
              Sym := FModel.SymbolAt(SymId - 1);
              LReceiverTypeId := Sym.TypeId;
            end;
          end;
          if LReceiverTypeId > 0 then
          begin
            LTypeName := FModel.TypeAt(LReceiverTypeId - 1).Name;
            LQualifiedName := LTypeName + '.' + LMemberName;
            for LBodyIdx := 0 to Length(FProcedureBodies) - 1 do
              if SameText(FProcedureBodies[LBodyIdx].Name, LQualifiedName) then
              begin
                Result := DeclReturnTypeId(
                  FProcedureBodies[LBodyIdx].Decl,
                  FProcedureBodies[LBodyIdx].OwnerUnitId);
                if Result > 0 then
                  Break;
              end;
          end;
        end
        else if (ANode.ChildCount > 0) and (ANode.ChildAt(0) <> nil) and
          (ANode.ChildAt(0).NodeKind = gnkDotAccess) then
          Result := InferExpressionType(ANode.ChildAt(0));
      end;
    gnkDotAccess:
      begin
        if ANode.ChildCount < 2 then
          Exit;
        if (ANode.ChildAt(0) = nil) or (ANode.ChildAt(1) = nil) then
          Exit;
        LReceiverTypeId := 0;
        if SameText(ANode.ChildAt(0).Text, 'Self') and
          (FCurrentMethodClass <> '') then
        begin
          LReceiverTypeId := FModel.FindTypeByName(FCurrentMethodClass);
          if LReceiverTypeId <= 0 then
          begin
            SymId := FModel.LookupSymbol(FCurrentMethodClass, FCurrentScopeId);
            if SymId > 0 then
            begin
              Sym := FModel.SymbolAt(SymId - 1);
              if SameText(Sym.Kind, 'type') then
                LReceiverTypeId := Sym.TypeId;
            end;
          end;
        end
        else if ANode.ChildAt(0).NodeKind = gnkIdentifier then
        begin
          SymId := FModel.LookupSymbol(ANode.ChildAt(0).Text, FCurrentScopeId);
          if SymId > 0 then
          begin
            Sym := FModel.SymbolAt(SymId - 1);
            LReceiverTypeId := Sym.TypeId;
          end;
          { Fall back to FindTypeByName for type names used as
            class method receivers (e.g. TOffsetDateTime.Now) }
          if LReceiverTypeId <= 0 then
            LReceiverTypeId := FModel.FindTypeByName(
              ANode.ChildAt(0).Text);
        end
        else
          LReceiverTypeId := InferExpressionType(ANode.ChildAt(0));
        if LReceiverTypeId <= 0 then
          Exit;
        LTypeName := '';
        if LReceiverTypeId > 0 then
          LTypeName := FModel.TypeAt(LReceiverTypeId - 1).Name;
        if LTypeName <> '' then
        begin
          if FModel.GetFieldMetaByName(LReceiverTypeId, ANode.ChildAt(1).Text,
            LFieldMeta) then
            Result := LFieldMeta.TypeId
          else
          begin
            LQualifiedName := LTypeName + '.' + ANode.ChildAt(1).Text;
            for LBodyIdx := 0 to Length(FProcedureBodies) - 1 do
              if SameText(FProcedureBodies[LBodyIdx].Name, LQualifiedName) then
              begin
                Result := DeclReturnTypeId(
                  FProcedureBodies[LBodyIdx].Decl,
                  FProcedureBodies[LBodyIdx].OwnerUnitId);
                if Result > 0 then
                  Break;
              end;
            if Result <= 0 then
            begin
              if FModel.TypeAt(LReceiverTypeId - 1).InstantiatedFrom > 0 then
              begin
                LReceiverTypeId := FModel.TypeAt(LReceiverTypeId - 1).InstantiatedFrom;
                LTypeName := FModel.TypeAt(LReceiverTypeId - 1).Name;
                LQualifiedName := LTypeName + '.' + ANode.ChildAt(1).Text;
                for LBodyIdx := 0 to Length(FProcedureBodies) - 1 do
                  if SameText(FProcedureBodies[LBodyIdx].Name, LQualifiedName) then
                  begin
                    Result := DeclReturnTypeId(
                      FProcedureBodies[LBodyIdx].Decl,
                      FProcedureBodies[LBodyIdx].OwnerUnitId);
                    if Result > 0 then
                      Break;
                  end;
              end;
            end;
            if Result <= 0 then
            begin
              while FModel.TypeAt(LReceiverTypeId - 1).ParentTypeId > 0 do
              begin
                LReceiverTypeId := FModel.TypeAt(LReceiverTypeId - 1).ParentTypeId;
                if FModel.TypeAt(LReceiverTypeId - 1).InstantiatedFrom > 0 then
                  LReceiverTypeId := FModel.TypeAt(LReceiverTypeId - 1).InstantiatedFrom;
                LTypeName := FModel.TypeAt(LReceiverTypeId - 1).Name;
                LQualifiedName := LTypeName + '.' + ANode.ChildAt(1).Text;
                for LBodyIdx := 0 to Length(FProcedureBodies) - 1 do
                  if SameText(FProcedureBodies[LBodyIdx].Name, LQualifiedName) then
                  begin
                    Result := DeclReturnTypeId(
                      FProcedureBodies[LBodyIdx].Decl,
                      FProcedureBodies[LBodyIdx].OwnerUnitId);
                    if Result > 0 then
                      Break;
                  end;
                if Result > 0 then
                  Break;
              end;
            end;
            { Fall back to symbol table for class methods not in
              FProcedureBodies (e.g. TOffsetDateTime.Now) }
            if Result <= 0 then
            begin
              LQualifiedName := LTypeName + '.' + ANode.ChildAt(1).Text;
              for LBodyIdx := 0 to FModel.SymbolCount - 1 do
              begin
                Sym := FModel.SymbolAt(LBodyIdx);
                if SameText(Sym.Name, LQualifiedName) and
                  (SameText(Sym.Kind, 'method') or
                   SameText(Sym.Kind, 'function')) then
                begin
                  if Sym.ReturnTypeId > 0 then
                    Result := Sym.ReturnTypeId
                  else
                    Result := Sym.TypeId;
                  if Result > 0 then
                    Break;
                end;
              end;
            end;
          end;
        end;
      end;
    gnkDereference:
      begin
        if (ANode.ChildCount >= 1) and (ANode.ChildAt(0) <> nil) then
        begin
          BaseTypeId := InferExpressionType(ANode.ChildAt(0));
          if (BaseTypeId > 0) and (BaseTypeId <= FModel.TypeCount) then
          begin
            CallName := FModel.TypeAt(CanonicalTypeId(BaseTypeId) - 1).Name;
            if (Length(CallName) > 1) and (CallName[1] = 'P') then
            begin
              Result := FModel.FindTypeByName(Copy(CallName, 2, Length(CallName) - 1));
              if Result > 0 then
                Exit;
            end;
          end;
        end;
        Result := 0;
      end;
    gnkArrayAccess:
      Result := 0;
  end;
end;

function TSemanticAnalyzer.AreTypesCompatible(const ALhsTypeId, ARhsTypeId: LongInt): Boolean;
var Ctx: TSemaOverloadContext;
begin
  Ctx.Model := FModel;
  Ctx.UnitGraph := FUnitGraph;
  Ctx.RootAst := FRootAst;
  Ctx.CurrentProcessingUnitId := FCurrentProcessingUnitId;
  Ctx.CurrentScopeId := FCurrentScopeId;
  Ctx.ProcedureBodies := FProcedureBodies;
  Ctx.ImportedUnitOwners := FImportedUnitOwners;
  Ctx.ImportedUnitTrees := FImportedUnitTrees;
  Ctx.BuiltinRegistry := FBuiltinRegistry;
  Result := np_sema_overload.AreTypesCompatible(Ctx, ALhsTypeId, ARhsTypeId);
end;

procedure TSemanticAnalyzer.SeedBuiltinTypes;
begin
  np_sema_builtins.SeedBuiltinTypes(FModel);
end;

procedure TSemanticAnalyzer.SeedCachedTypeGaps;
var
  HasClassLikeMembers: Boolean;
  I, J: LongInt;
  ExistingTypeId: LongInt;
  MemberSym, TypeSym: TSemanticSymbol;
  ParentTypeId: LongInt;
  Meta: TTypeMetadata;
  OwnerUnitId: string;
begin
  { Cached units only register symbols, not types. Seed type entries for
    type symbols from cached units that are missing from the model. }
  for I := 0 to FModel.SymbolCount - 1 do
  begin
    TypeSym := FModel.SymbolAt(I);
    if not SameText(TypeSym.Kind, 'type') then
      Continue;
    OwnerUnitId := NormalizeUnitIdentity(TypeSym.OwnerUnitId);
    if OwnerUnitId = '' then
      Continue;

    ExistingTypeId := 0;
    if (TypeSym.TypeId > 0) and (TypeSym.TypeId <= FModel.TypeCount) then
      ExistingTypeId := TypeSym.TypeId
    else
      ExistingTypeId := ResolveTypeIdForOwner(TypeSym.Name, OwnerUnitId, False);
    if ExistingTypeId <= 0 then
      ExistingTypeId := FModel.FindTypeByName(TypeSym.Name);

    if ExistingTypeId <= 0 then
    begin
      ExistingTypeId := FModel.AddType(TypeSym.Name, 'declared');
      FModel.SetTypeOwner(ExistingTypeId, OwnerUnitId);
    end;
    FModel.SetSymbolTypeId(TypeSym.SymbolId, ExistingTypeId);

    HasClassLikeMembers := False;
    for J := 0 to FModel.SymbolCount - 1 do
    begin
      MemberSym := FModel.SymbolAt(J);
      if SameText(MemberSym.OwnerUnitId, OwnerUnitId) and
        SameText(MemberSym.Kind, 'method') and
        (Pos(LowerCase(FModel.TypeAt(ExistingTypeId - 1).Name) + '.',
          LowerCase(MemberSym.Name)) = 1) then
      begin
        HasClassLikeMembers := True;
        Break;
      end;
    end;

    if HasClassLikeMembers or SameText(TypeSym.Name, 'Exception') or
      SameText(TypeSym.Name, 'ExceptClass') or
      (SameText(Copy(TypeSym.Name, 1, 1), 'E') and
       (Length(TypeSym.Name) > 1) and
       (TypeSym.Name[2] in ['A'..'Z'])) then
    begin
      ParentTypeId := 0;
      if not SameText(TypeSym.Name, 'TObject') then
        ParentTypeId := FModel.FindTypeByName('TObject');
      if ParentTypeId > 0 then
        FModel.SetTypeParent(ExistingTypeId, ParentTypeId);
      FillChar(Meta, SizeOf(Meta), 0);
      Meta.TypeId := ExistingTypeId;
      Meta.Size := 8;
      Meta.VmtCount := 0;
      Meta.ParentClassId := ParentTypeId;
      if ParentTypeId > 0 then
        Meta.ParentClassName := 'TObject';
      FModel.SetTypeMeta(ExistingTypeId, Meta);
      FModel.AddConstValue(TypeSym.Name + '$size', 8);
      FModel.AddConstValue(TypeSym.Name + '$vmt_count', 0);
      if ParentTypeId > 0 then
        FModel.AddStringConstValue(TypeSym.Name + '$parent_class', 'TObject');
    end;
  end;
end;

procedure TSemanticAnalyzer.AssignScopesToSymbols;
var
  I: LongInt;
  Sym: TSemanticSymbol;
begin
  for I := 0 to FModel.SymbolCount - 1 do
  begin
    Sym := FModel.SymbolAt(I);
    if Sym.ScopeId = 0 then
      FModel.SetSymbolScope(Sym.SymbolId, FCurrentScopeId);
  end;
end;

{ === Validation methods (extracted to np_sema_validation.inc) === }
{$I np_sema_validation.inc}

procedure TSemanticAnalyzer.SeedUnitSymbolsAndHir;
var
  Index: LongInt;
  ResolvedUnit: TResolvedUnit;
  SymbolId: LongInt;
begin
  FModel.SetRootName(FUnitGraph.RootName);
  FModel.AddTypedHirNode('compilation-root', FUnitGraph.RootName, 0, 0, '');

  for Index := 0 to FUnitGraph.ResolvedUnitCount - 1 do
  begin
    ResolvedUnit := FUnitGraph.ResolvedUnitAt(Index);
    SymbolId := FModel.AddSymbol(
      ResolvedUnit.CanonicalName,
      'unit',
      ResolvedUnit.UnitId,
      0,
      0
    );
    FModel.AddTypedHirNode(
      'resolved-unit',
      ResolvedUnit.CanonicalName,
      SymbolId,
      0,
      ''
    );
  end;
end;

procedure TSemanticAnalyzer.SeedRuntimeContracts;
  procedure AddRuntimeContract(const AContractName, AKind: string);
  begin
    FModel.AddRuntimeContract(AContractName);
    FModel.AddTypedHirNode(AKind, AContractName, 0, 0, '');
  end;

  procedure SeedUnitLifecycle;
  var
    RootNode, Child, ImplChild: TGreenNode;
    I, J: LongInt;
    HirId: LongInt;
    UnitName: string;
  begin
    if FRootAst = nil then
      Exit;
    RootNode := FRootAst.RootNode;
    if RootNode = nil then
      Exit;
    UnitName := FUnitGraph.RootName;
    for I := 0 to RootNode.ChildCount - 1 do
    begin
      Child := RootNode.ChildAt(I);
      if Child.NodeKind = gnkImplementationSection then
      begin
        for J := 0 to Child.ChildCount - 1 do
        begin
          ImplChild := Child.ChildAt(J);
          if ImplChild.NodeKind = gnkInitializationSection then
          begin
            FModel.AddRuntimeContract(NPSYSTEM_UNIT_INIT);
            HirId := FModel.AddTypedHirNode('unit-init-runtime', UnitName, 0, 0, UnitName);
            FModel.SetTypedHirNodeGreenRef(HirId, ImplChild);
          end
          else if ImplChild.NodeKind = gnkFinalizationSection then
          begin
            FModel.AddRuntimeContract(NPSYSTEM_UNIT_FINI);
            HirId := FModel.AddTypedHirNode('unit-fini-runtime', UnitName, 0, 0, UnitName);
            FModel.SetTypedHirNodeGreenRef(HirId, ImplChild);
          end;
        end;
        Break;
      end;
    end;
  end;

begin
  if (FRootAst.RootKindName = 'program') or
    (FRootAst.RootKindName = 'library') or
    (FRootAst.RootKindName = 'package') then
  begin
    AddRuntimeContract(NPSYSTEM_PROCESS_INIT, 'process-init-runtime');
    { process_fini 不在此处 seed，而是在 Analyze 末尾 SeedHaltCalls 之后，
      确保 HIR 顺序为: process_init → 用户代码 → process_fini }
  end
  else if FRootAst.RootKindName = 'unit' then
    SeedUnitLifecycle;
end;

procedure TSemanticAnalyzer.SeedForeignProcedureBindings;
var
  ForeignProcedureDecl: TForeignProcedureDecl;
  Index: LongInt;
  RootOwnerUnitId: string;
  SymbolId: LongInt;
begin
  if FRootAst = nil then
    Exit;

  RootOwnerUnitId := NormalizeUnitIdentity(FUnitGraph.RootName);
  for Index := 0 to FRootAst.ForeignProcedureDeclCount - 1 do
  begin
    ForeignProcedureDecl := FRootAst.ForeignProcedureDeclAt(Index);
    if not ForeignProcedureDecl.HasExplicitSymbolName then
    begin
      EmitSemaError(
        'sema.missing-external-symbol-name',
        'external procedure "' + ForeignProcedureDecl.ProcedureName +
          '" must declare explicit foreign symbol name via name ''<symbol>''',
        ForeignProcedureDecl.ByteOffset
      );
      Exit;
    end;

    SymbolId := FModel.AddSymbol(
      ForeignProcedureDecl.ProcedureName,
      'foreign-procedure',
      RootOwnerUnitId,
      0,
      ForeignProcedureDecl.ByteOffset
    );
    FModel.AddForeignProcedureBinding(
      ForeignProcedureDecl.ProcedureName,
      ForeignProcedureDecl.CallingConvention,
      ForeignProcedureDecl.LibraryId,
      ForeignProcedureDecl.ExternalSymbolName,
      SymbolId
    );
    FModel.AddTypedHirNode(
      'foreign-procedure-binding',
      ForeignProcedureDecl.ProcedureName,
      SymbolId,
      0,
      ''
    );
    FModel.AddLibraryRequest(
      ForeignProcedureDecl.LibraryId,
      'shared',
      'strong'
    );
  end;
end;

procedure TSemanticAnalyzer.Analyze;
var
  DuplicateName: string;
begin
  if (FRootAst = nil) or (FUnitGraph = nil) or not FRootAst.IsValid then
  begin
    FModel.MarkFailure;
    Exit;
  end;

  DuplicateName := DuplicateImportName;
  if DuplicateName <> '' then
  begin
    EmitSemaError(
      'sema.duplicate-declaration',
      'duplicate unit import: "' + DuplicateName + '"',
      0
    );
    Exit;
  end;

  SeedBuiltinTypes;
  FModel.AddScope(skCompilation, FUnitGraph.RootName, 0);
  FCurrentScopeId := FModel.AddScope(skUnit, FUnitGraph.RootName, 1);
  SeedImportedUnitBodies;
  SeedCachedTypeGaps;
  SeedDeclarations;
  RebindExplicitClassParents;
  CompletePendingSignatures;
  AssignScopesToSymbols;
  SeedCallBindings;
  CheckDuplicateDeclarations;
  CheckUndeclaredIdentifiers;
  CheckTypeMismatches;
  CheckAssignmentTypes;
  SeedUnitSymbolsAndHir;
  SeedForeignProcedureBindings;
  if FDiagnostics.HasErrors then
    Exit;
  SeedRuntimeContracts;
  SeedRuntimeVarDecls;
  if FNoFold then
    PreRegisterOwnedStringReturnConsumers;
  if FNoFold then
    PreRegisterFunctionReturnTypes;
  FGenericWorkCount := 0;
  SetLength(FGenericWorkQueue, 64);
  SeedHaltCalls;
  { process_fini 在用户代码之后 seed，确保退出序列为:
    process_init → 用户 main → process_fini (对标 FPC 的 init→main→flush→finalize 序列) }
  if (FRootAst <> nil) and ((FRootAst.RootKindName = 'program') or
    (FRootAst.RootKindName = 'library') or
    (FRootAst.RootKindName = 'package')) then
  begin
    FModel.AddRuntimeContract(NPSYSTEM_PROCESS_FINI);
    FModel.AddTypedHirNode('process-fini-runtime', NPSYSTEM_PROCESS_FINI, 0, 0, '');
  end;
  if FNoFold then
  begin
    SeedFunctionBodies;
    SeedUnitLifecycleBodies;
  end;

  // Store unit init order from topological sort
  if FUnitGraph <> nil then
    FModel.SetUnitInitOrder(FUnitGraph.TopologicalInitOrder);

  CheckUnusedSymbols;
  CheckUnreachableCode;
  CheckDuplicateCaseLabels;

  if FDiagnostics.HasErrors then
    FModel.MarkFailure
  else
    FModel.MarkReady;
end;

function TSemanticAnalyzer.DetachModel: TSemanticModel;
begin
  if FModel.Status = 'deferred' then
    FModel.MarkReady;
  Result := FModel;
  FModel := nil;
end;

function TSemanticAnalyzer.Status: string;
begin
  if FModel = nil then
    Exit('deferred');

  Result := FModel.Status;
end;

function TSemanticAnalyzer.ResolveTypeId(const ATypeName: string): LongInt;
var Ctx: TSemaOverloadContext;
begin
  Ctx.Model := FModel;
  Ctx.UnitGraph := FUnitGraph;
  Ctx.RootAst := FRootAst;
  Ctx.CurrentProcessingUnitId := FCurrentProcessingUnitId;
  Ctx.CurrentScopeId := FCurrentScopeId;
  Ctx.ProcedureBodies := FProcedureBodies;
  Ctx.ImportedUnitOwners := FImportedUnitOwners;
  Ctx.ImportedUnitTrees := FImportedUnitTrees;
  Ctx.BuiltinRegistry := FBuiltinRegistry;
  Result := np_sema_overload.ResolveTypeId(Ctx, ATypeName);
end;

function TSemanticAnalyzer.ResolveTypeIdForOwner(
  const ATypeName: string;
  const APreferredOwnerUnitId: string;
  const AAllowDirectImportSearch: Boolean): LongInt;
var Ctx: TSemaOverloadContext;
begin
  Ctx.Model := FModel;
  Ctx.UnitGraph := FUnitGraph;
  Ctx.RootAst := FRootAst;
  Ctx.CurrentProcessingUnitId := FCurrentProcessingUnitId;
  Ctx.CurrentScopeId := FCurrentScopeId;
  Ctx.ProcedureBodies := FProcedureBodies;
  Ctx.ImportedUnitOwners := FImportedUnitOwners;
  Ctx.ImportedUnitTrees := FImportedUnitTrees;
  Ctx.BuiltinRegistry := FBuiltinRegistry;
  Result := np_sema_overload.ResolveTypeIdForOwner(Ctx, ATypeName, APreferredOwnerUnitId, AAllowDirectImportSearch);
end;

function TSemanticAnalyzer.ImplicitSystemObjectParentTypeId(
  const AClassName: string
): LongInt;
var
  TypeSymbol: TSemanticSymbol;
begin
  Result := 0;
  if SameText(AClassName, 'TObject') then
    Exit;

  Result := ResolveTypeIdForOwner('TObject', 'system');
  if Result <= 0 then
    Exit;
  if not TypeSymbolForTypeId(Result, TypeSymbol) then
  begin
    Result := 0;
    Exit;
  end;
  if not SameText(TypeSymbol.OwnerUnitId, 'system') then
    Result := 0;
end;

function TSemanticAnalyzer.FindSymbolByName(const AName: string): LongInt;
begin
  if AName = '' then
    Exit(0);
  Result := FModel.FindSymbolByName(AName);
end;

procedure TSemanticAnalyzer.ProcessVarSection(const ANode: TGreenNode;
  const AOwnerUnitId: string);
var
  I, J: LongInt;
  Child, TypeChild: TGreenNode;
  SymbolId: LongInt;
  TypeId: LongInt;
begin
  if ANode = nil then
    Exit;
  for I := 0 to ANode.ChildCount - 1 do
  begin
    Child := ANode.ChildAt(I);
    if (Child = nil) or (Child.NodeKind <> gnkVarDecl) then
      Continue;
    TypeId := 0;
    for J := 0 to Child.ChildCount - 1 do
    begin
      TypeChild := Child.ChildAt(J);
      if (TypeChild <> nil) and (TypeChild.NodeKind = gnkIdentifier) then
      begin
        TypeId := ResolveTypeIdForOwner(TypeChild.Text, AOwnerUnitId);
        if (TypeId = 0) and (Pos('<', TypeChild.Text) > 0) then
          TypeId := ResolveOrInstantiateInlineGeneric(TypeChild.Text, AOwnerUnitId);
        Break;
      end;
    end;
    SymbolId := FModel.AddSymbol(Child.Text, 'variable', AOwnerUnitId, TypeId,
      Child.ByteOffset);
    if FCurrentScopeId > 0 then
      FModel.SetSymbolScope(SymbolId, FCurrentScopeId);
  end;
end;

procedure TSemanticAnalyzer.ProcessConstSection(const ANode: TGreenNode;
  const AOwnerUnitId: string);
var
  I, J: LongInt;
  Child, ValueChild: TGreenNode;
  Value: Int64;
  FloatValue: Double;
  StringValue: string;
begin
  if ANode = nil then
    Exit;
  for I := 0 to ANode.ChildCount - 1 do
  begin
    Child := ANode.ChildAt(I);
    if (Child = nil) or (Child.NodeKind <> gnkConstDecl) then
      Continue;
    FModel.AddSymbol(Child.Text, 'constant', AOwnerUnitId, 0,
      Child.ByteOffset);
    for J := 0 to Child.ChildCount - 1 do
    begin
      ValueChild := Child.ChildAt(J);
      if EvaluateIntegerConstant(ValueChild, Value) then
      begin
        FModel.AddConstValue(Child.Text, Value);
        Break;
      end;
      if EvaluateFloatConstant(ValueChild, FloatValue) then
      begin
        FModel.AddFloatConstValue(Child.Text, FloatValue);
        Break;
      end;
      if EvaluateStringConstant(ValueChild, StringValue) then
      begin
        FModel.AddStringConstValue(Child.Text, StringValue);
        Break;
      end;
    end;
  end;
end;

procedure TSemanticAnalyzer.ProcessProcedureDecl(const ANode: TGreenNode;
  const AOwnerUnitId: string);
var
  SymbolId: LongInt;
  Index, J: LongInt;
  Child, ParamChild: TGreenNode;
  CallableScopeId, SavedScopeId: LongInt;
  ParamTypeId: LongInt;
  ParamCount: LongInt;
  SymCountBefore: LongInt;
begin
  if ANode = nil then
    Exit;
  SymbolId := FModel.AddSymbol(ANode.Text, 'procedure', AOwnerUnitId, 0,
    ANode.ByteOffset);
  FModel.AddTypedHirNode('procedure-decl', ANode.Text, SymbolId, 0, '');

  CallableScopeId := FModel.AddScope(skCallable, ANode.Text, FCurrentScopeId);
  SavedScopeId := FCurrentScopeId;
  FCurrentScopeId := CallableScopeId;
  ParamCount := 0;

  for Index := 0 to ANode.ChildCount - 1 do
  begin
    Child := ANode.ChildAt(Index);
    if Child = nil then
      Continue;
    if Child.NodeKind = gnkParameterList then
    begin
      for J := 0 to Child.ChildCount - 1 do
      begin
        ParamChild := Child.ChildAt(J);
        if (ParamChild <> nil) and (ParamChild.NodeKind = gnkParameterDecl) then
        begin
          ParamTypeId := ParamDeclTypeId(ParamChild, AOwnerUnitId);
          SymbolId := FModel.AddSymbol(
            StripParamModifier(ParamChild.Text),
            'parameter',
            AOwnerUnitId,
            ParamTypeId,
            ParamChild.ByteOffset);
          FModel.SetSymbolScope(SymbolId, CallableScopeId);
          Inc(ParamCount);
        end;
      end;
    end
    else if Child.NodeKind = gnkVarSection then
    begin
      SymCountBefore := FModel.SymbolCount;
      ProcessVarSection(Child, AOwnerUnitId);
      for ParamTypeId := SymCountBefore + 1 to FModel.SymbolCount do
        FModel.SetSymbolScope(ParamTypeId, CallableScopeId);
    end
    else if Child.NodeKind = gnkProcedureDecl then
      ProcessProcedureDecl(Child, AOwnerUnitId)
    else if Child.NodeKind = gnkFunctionDecl then
      ProcessFunctionDecl(Child, AOwnerUnitId)
    else if Child.NodeKind = gnkBeginBlock then
    begin
      RegisterProcedureBody(ANode.Text, Child, ANode, AOwnerUnitId);
      Break;
    end
    else if Child.NodeKind = gnkAsmBlock then
    begin
      RegisterProcedureBody(ANode.Text, Child, ANode, AOwnerUnitId);
      Break;
    end;
  end;

  FModel.SetSymbolParamCount(SymbolId, ParamCount);
  FModel.SetSymbolMinParamCount(SymbolId, CountRequiredDeclParams(ANode));
  FModel.SetSymbolParamSignature(SymbolId, GetParamSignature(ANode));
  FCurrentScopeId := SavedScopeId;
end;

procedure TSemanticAnalyzer.ProcessFunctionDecl(const ANode: TGreenNode;
  const AOwnerUnitId: string);
var
  SymbolId: LongInt;
  TypeId: LongInt;
  J: LongInt;
  Child, ParamChild: TGreenNode;
  CallableScopeId, SavedScopeId: LongInt;
  ParamTypeId: LongInt;
  ParamCount: LongInt;
  SymCountBefore: LongInt;
begin
  if ANode = nil then
    Exit;
  TypeId := 0;
  for J := 0 to ANode.ChildCount - 1 do
  begin
    Child := ANode.ChildAt(J);
    if (Child <> nil) and (Child.NodeKind = gnkIdentifier) then
    begin
      TypeId := ResolveTypeIdForOwner(Child.Text, AOwnerUnitId);
      Break;
    end;
  end;
  SymbolId := FModel.AddSymbol(ANode.Text, 'function', AOwnerUnitId, TypeId,
    ANode.ByteOffset);
  FModel.AddTypedHirNode('function-decl', ANode.Text, SymbolId, TypeId, '');

  CallableScopeId := FModel.AddScope(skCallable, ANode.Text, FCurrentScopeId);
  SavedScopeId := FCurrentScopeId;
  FCurrentScopeId := CallableScopeId;
  ParamCount := 0;

  for J := 0 to ANode.ChildCount - 1 do
  begin
    Child := ANode.ChildAt(J);
    if Child = nil then
      Continue;
    if Child.NodeKind = gnkParameterList then
    begin
      for TypeId := 0 to Child.ChildCount - 1 do
      begin
        ParamChild := Child.ChildAt(TypeId);
        if (ParamChild <> nil) and (ParamChild.NodeKind = gnkParameterDecl) then
        begin
          ParamTypeId := ParamDeclTypeId(ParamChild, AOwnerUnitId);
          SymbolId := FModel.AddSymbol(
            StripParamModifier(ParamChild.Text),
            'parameter',
            AOwnerUnitId,
            ParamTypeId,
            ParamChild.ByteOffset);
          FModel.SetSymbolScope(SymbolId, CallableScopeId);
          Inc(ParamCount);
        end;
      end;
    end
    else if Child.NodeKind = gnkVarSection then
    begin
      SymCountBefore := FModel.SymbolCount;
      ProcessVarSection(Child, AOwnerUnitId);
      for ParamTypeId := SymCountBefore + 1 to FModel.SymbolCount do
        FModel.SetSymbolScope(ParamTypeId, CallableScopeId);
    end
    else if Child.NodeKind = gnkProcedureDecl then
      ProcessProcedureDecl(Child, AOwnerUnitId)
    else if Child.NodeKind = gnkFunctionDecl then
      ProcessFunctionDecl(Child, AOwnerUnitId)
    else if Child.NodeKind = gnkBeginBlock then
    begin
      RegisterProcedureBody(ANode.Text, Child, ANode, AOwnerUnitId);
      Break;
    end
    else if Child.NodeKind = gnkAsmBlock then
    begin
      RegisterProcedureBody(ANode.Text, Child, ANode, AOwnerUnitId);
      Break;
    end;
  end;

  FModel.SetSymbolParamCount(SymbolId, ParamCount);
  FModel.SetSymbolMinParamCount(SymbolId, CountRequiredDeclParams(ANode));
  FModel.SetSymbolParamSignature(SymbolId, GetParamSignature(ANode));
  FCurrentScopeId := SavedScopeId;
end;

procedure TSemanticAnalyzer.ProcessEnumType(const ANode: TGreenNode;
  const AOwnerUnitId: string; const ATypeId: LongInt);
var
  I: LongInt;
  Child: TGreenNode;
  Ordinal: Int64;
begin
  if ANode = nil then
    Exit;
  Ordinal := 0;
  for I := 0 to ANode.ChildCount - 1 do
  begin
    Child := ANode.ChildAt(I);
    if (Child <> nil) and (Child.NodeKind = gnkIdentifier) then
    begin
      FModel.AddSymbol(Child.Text, 'enum-value', AOwnerUnitId, ATypeId,
        Child.ByteOffset);
      FModel.AddConstValue(Child.Text, Ordinal);
      Inc(Ordinal);
    end;
  end;
end;

procedure TSemanticAnalyzer.ProcessRecordFields(const ANode: TGreenNode;
  const AOwnerUnitId: string; const ATypeId: LongInt);
var
  I: LongInt;
  Child: TGreenNode;
  RecordScopeId: LongInt;
  FieldTypeId: LongInt;
  TypeChild: TGreenNode;
  J: LongInt;
  FieldIndex: LongInt;
  NameNode: TGreenNode;
  SymbolId: LongInt;
  RecName: string;
  Meta: TTypeMetadata;
  FieldMeta: TTypeMetadata;
begin
  if ANode = nil then
    Exit;
  RecName := FModel.TypeAt(ATypeId - 1).Name;
  RecordScopeId := FModel.AddScope(skRecord, '', FCurrentScopeId);
  FieldIndex := 0;
  Meta.TypeId := ATypeId;
  Meta.IsRecord := True;
  Meta.VmtCount := 0;
  Meta.ParentClassId := 0;
  Meta.ParentClassName := '';
  Meta.Interfaces := '';
  Meta.ArrElemSize := 0;
  Meta.ArrElemType := '';
  Meta.ArrLowBound := 0;
  Meta.ArrHighBound := -1;
  Meta.ArrLength := 0;
  Meta.IsStaticArray := False;
  SetLength(Meta.Fields, 0);
  SetLength(Meta.VmtSlots, 0);
  SetLength(Meta.RetPtrMethods, 0);
  SetLength(Meta.Properties, 0);
  for I := 0 to ANode.ChildCount - 1 do
  begin
    Child := ANode.ChildAt(I);
    if Child = nil then
      Continue;
    if Child.NodeKind = gnkClassMethod then
    begin
      if Child.ChildCount > 0 then
      begin
        NameNode := Child.ChildAt(0);
        if (NameNode <> nil) and (NameNode.NodeKind = gnkIdentifier) then
        begin
          SymbolId := FModel.AddSymbol(
            RecName + '.' + NameNode.Text,
            'method', AOwnerUnitId, ATypeId, Child.ByteOffset);
          FModel.SetSymbolParamCount(SymbolId, CountDeclParams(Child));
          FModel.SetSymbolMinParamCount(SymbolId, CountRequiredDeclParams(Child));
          FModel.SetSymbolParamSignature(SymbolId, GetParamSignature(Child));
          FModel.SetSymbolReturnTypeId(SymbolId,
            DeclReturnTypeId(Child, AOwnerUnitId));
          FModel.SetSymbolScope(SymbolId, RecordScopeId);
        end;
      end;
      Continue;
    end;
    if Child.NodeKind <> gnkVarDecl then
      Continue;
    FieldTypeId := 0;
    TypeChild := nil;
    for J := 0 to Child.ChildCount - 1 do
    begin
      TypeChild := Child.ChildAt(J);
      if (TypeChild <> nil) and (TypeChild.NodeKind = gnkIdentifier) then
      begin
        FieldTypeId := ResolveTypeIdForOwner(TypeChild.Text, AOwnerUnitId);
        Break;
      end;
    end;
    FModel.AddSymbol(Child.Text, 'field', AOwnerUnitId, FieldTypeId,
      Child.ByteOffset);
    FModel.SetSymbolScope(FModel.SymbolCount, RecordScopeId);
    FModel.AddConstValue(RecName + '.' + Child.Text + '$idx', FieldIndex);
    SetLength(Meta.Fields, Length(Meta.Fields) + 1);
    Meta.Fields[High(Meta.Fields)].Name := Child.Text;
    Meta.Fields[High(Meta.Fields)].Index := FieldIndex;
    { 检测字段类型 — 与 class 字段路径一致 }
    Meta.Fields[High(Meta.Fields)].IsString :=
      (TypeChild <> nil) and (TypeChild.NodeKind = gnkIdentifier) and
      (SameText(TypeChild.Text, 'String') or
       SameText(TypeChild.Text, 'AnsiString'));
    Meta.Fields[High(Meta.Fields)].IsPointer := False;
    Meta.Fields[High(Meta.Fields)].IsDynArray :=
      (Child.ChildCount > 0) and (Child.ChildAt(0) <> nil) and
      (Child.ChildAt(0).NodeKind = gnkArrayType);
    Meta.Fields[High(Meta.Fields)].IsRecord :=
      (FieldTypeId > 0) and FModel.GetTypeMeta(FieldTypeId, FieldMeta) and
      FieldMeta.IsRecord;
    Meta.Fields[High(Meta.Fields)].TypeId := FieldTypeId;
    if Meta.Fields[High(Meta.Fields)].IsString then
      Inc(FieldIndex, 3)
    else if Meta.Fields[High(Meta.Fields)].IsDynArray then
      Inc(FieldIndex, 2)
    else if Meta.Fields[High(Meta.Fields)].IsRecord then
    begin
      if (FieldTypeId > 0) and FModel.GetTypeMeta(FieldTypeId, FieldMeta) then
        Inc(FieldIndex, FieldMeta.Size div 8)
      else
        Inc(FieldIndex, 1);
    end
    else
      Inc(FieldIndex, 1);
  end;
  FModel.AddConstValue(RecName + '$size', FieldIndex * 8);
  FModel.AddConstValue(RecName + '$record', 1);
  Meta.Size := FieldIndex * 8;
  FModel.SetTypeMeta(ATypeId, Meta);
end;

procedure TSemanticAnalyzer.AppendWhereConstraint(const ATypeId: LongInt;
  const AWhereSpec: string);
var
  ColonPos: LongInt;
  ParamName, Constraint: string;
begin
  ColonPos := Pos(':', AWhereSpec);
  if ColonPos <= 0 then
    Exit;
  ParamName := Copy(AWhereSpec, 1, ColonPos - 1);
  Constraint := Copy(AWhereSpec, ColonPos + 1, MaxInt);
  FModel.AppendTypeConstraint(ATypeId, ParamName, Constraint);
end;

procedure TSemanticAnalyzer.ProcessInterfaceMethods(const ANode: TGreenNode;
  const AOwnerUnitId: string; const ATypeId: LongInt);
var
  I, J: LongInt;
  Child, NameNode: TGreenNode;
  IntfName, ParentIntfName, MethShort: string;
  SymbolId: LongInt;
  Meta: TTypeMetadata;
  ParentIntfTypeId: LongInt;
  Symbol: TSemanticSymbol;
begin
  if ANode = nil then
    Exit;
  IntfName := FModel.TypeAt(ATypeId - 1).Name;
  if (ANode.ChildCount > 0) and (ANode.ChildAt(0) <> nil) and
    (ANode.ChildAt(0).NodeKind = gnkIdentifier) then
  begin
    ParentIntfName := ANode.ChildAt(0).Text;
    ParentIntfTypeId := 0;
    for I := 0 to FModel.TypeCount - 1 do
      if SameText(FModel.TypeAt(I).Name, ParentIntfName) then
      begin
        ParentIntfTypeId := FModel.TypeAt(I).TypeId;
        Break;
      end;
    if ParentIntfTypeId > 0 then
    begin
      FModel.SetTypeParent(ATypeId, ParentIntfTypeId);
      for I := 0 to FModel.SymbolCount - 1 do
      begin
        Symbol := FModel.SymbolAt(I);
        if (Symbol.TypeId = ParentIntfTypeId) and
          SameText(Symbol.Kind, 'method') and
          (Pos(ParentIntfName + '.', Symbol.Name) = 1) then
        begin
          MethShort := Copy(Symbol.Name, Length(ParentIntfName) + 2, MaxInt);
          SymbolId := FModel.AddSymbol(IntfName + '.' + MethShort,
            'method', AOwnerUnitId, ATypeId, Symbol.ByteOffset);
          FModel.SetSymbolParamCount(SymbolId, Symbol.ParamCount);
          FModel.SetSymbolMinParamCount(SymbolId, Symbol.MinParamCount);
          FModel.SetSymbolParamSignature(SymbolId, Symbol.ParamSignature);
          if TypeMetaRetStr(ParentIntfName, MethShort) then
            FModel.AddConstValue(IntfName + '$ret_str_' + MethShort, 1);
        end;
      end;
    end;
  end;
  for I := 0 to ANode.ChildCount - 1 do
  begin
    Child := ANode.ChildAt(I);
    if (Child = nil) or (Child.NodeKind <> gnkClassMethod) then
      Continue;
    if Child.ChildCount > 0 then
    begin
      NameNode := Child.ChildAt(0);
      if (NameNode <> nil) and (NameNode.NodeKind = gnkIdentifier) then
      begin
        SymbolId := FModel.AddSymbol(
          IntfName + '.' + NameNode.Text,
          'method', AOwnerUnitId, ATypeId, Child.ByteOffset);
        FModel.SetSymbolParamCount(SymbolId, CountDeclParams(Child));
        FModel.SetSymbolMinParamCount(SymbolId, CountRequiredDeclParams(Child));
        FModel.SetSymbolParamSignature(SymbolId, GetParamSignature(Child));
        FModel.SetSymbolReturnTypeId(SymbolId,
          DeclReturnTypeId(Child, AOwnerUnitId));
        if DeclReturnsString(Child) then
          FModel.AddConstValue(IntfName + '$ret_str_' + NameNode.Text, 1);
      end;
    end;
  end;
  with Meta do
  begin
    TypeId := ATypeId;
    Size := 8;
    IsRecord := False;
    VmtCount := 0;
    ParentClassId := 0;
    ParentClassName := '';
    Interfaces := '';
    ArrElemSize := 0;
    ArrElemType := '';
    ArrLowBound := 0;
    ArrHighBound := -1;
    ArrLength := 0;
    IsStaticArray := False;
    SetLength(Fields, 0);
    SetLength(VmtSlots, 0);
    SetLength(RetPtrMethods, 0);
    SetLength(Properties, 0);
  end;
  for I := 0 to FModel.SymbolCount - 1 do
  begin
    Symbol := FModel.SymbolAt(I);
    if SameText(Symbol.Kind, 'method') and
      (Pos(IntfName + '.', Symbol.Name) = 1) then
    begin
      MethShort := Copy(Symbol.Name, Length(IntfName) + 2, MaxInt);
      SetLength(Meta.VmtSlots, Meta.VmtCount + 1);
      Meta.VmtSlots[Meta.VmtCount].MethodName := MethShort;
      Meta.VmtSlots[Meta.VmtCount].SlotIndex := Meta.VmtCount;
      Meta.VmtSlots[Meta.VmtCount].FuncQualName := IntfName + '.' + MethShort;
      Inc(Meta.VmtCount);
    end;
  end;
  FModel.AddConstValue(IntfName + '$vmt_count', Meta.VmtCount);
  FModel.AddConstValue(IntfName + '$interface', 1);
  FModel.SetTypeMeta(ATypeId, Meta);
end;

procedure TSemanticAnalyzer.VerifyInterfaceImplementation(
  const AClassTypeId: LongInt; const AInterfaceList: string;
  const AOwnerUnitId: string);
var
  I, J, K: LongInt;
  IntfName, ClsN, MethN, CheckName: string;
  IntfTypeId: LongInt;
  Symbol: TSemanticSymbol;
  QualIntfMethod: string;
  Found: Boolean;
  CurrentCheckTypeId: LongInt;
begin
  I := 1;
  while I <= Length(AInterfaceList) do
  begin
    J := I;
    while (J <= Length(AInterfaceList)) and (AInterfaceList[J] <> ',') do
      Inc(J);
    IntfName := Trim(Copy(AInterfaceList, I, J - I));
    I := J + 1;
    if IntfName = '' then
      Continue;
    IntfTypeId := 0;
    for K := 0 to FModel.TypeCount - 1 do
      if SameText(FModel.TypeAt(K).Name, IntfName) then
      begin
        IntfTypeId := FModel.TypeAt(K).TypeId;
        Break;
      end;
    if IntfTypeId <= 0 then
      Continue;
    for K := 0 to FModel.SymbolCount - 1 do
    begin
      Symbol := FModel.SymbolAt(K);
      if (Symbol.TypeId = IntfTypeId) and SameText(Symbol.Kind, 'method') then
      begin
        QualIntfMethod := IntfName + '.';
        if Pos(QualIntfMethod, Symbol.Name) = 1 then
        begin
          MethN := Copy(Symbol.Name, Length(QualIntfMethod) + 1, MaxInt);
          Found := False;
          CurrentCheckTypeId := AClassTypeId;
          while (CurrentCheckTypeId > 0) and (not Found) and
                (CurrentCheckTypeId <> FModel.TypeAt(CurrentCheckTypeId - 1).ParentTypeId) do
          begin
            ClsN := FModel.TypeAt(CurrentCheckTypeId - 1).Name;
            for J := 0 to FModel.SymbolCount - 1 do
              if SameText(FModel.SymbolAt(J).Name, ClsN + '.' + MethN) and
                (SameText(FModel.SymbolAt(J).Kind, 'method') or
                 SameText(FModel.SymbolAt(J).Kind, 'constructor')) then
              begin
                Found := True;
                Break;
              end;
            if not Found then
              CurrentCheckTypeId := FModel.TypeAt(CurrentCheckTypeId - 1).ParentTypeId;
          end;
          if not Found then
            FDiagnostics.EmitError('sema.missing-interface-method', 'sema',
              FRootFileId, 0,
              FModel.TypeAt(AClassTypeId - 1).Name +
              ' does not implement ' + IntfName + '.' + MethN);
        end;
      end;
    end;
  end;
end;

procedure TSemanticAnalyzer.RegisterInterfaceSlots(const AClassTypeId: LongInt;
  const AInterfaceList: string);
var
  I, J, SlotOffset: LongInt;
  IntfName, ClsName: string;
  Meta: TTypeMetadata;
  IntfNames: array of string;
  IntfCount: LongInt;
begin
  if not FModel.GetTypeMeta(AClassTypeId, Meta) then
    Exit;
  ClsName := FModel.TypeAt(AClassTypeId - 1).Name;
  IntfCount := 0;
  I := 1;
  while I <= Length(AInterfaceList) do
  begin
    J := I;
    while (J <= Length(AInterfaceList)) and (AInterfaceList[J] <> ',') do
      Inc(J);
    IntfName := Trim(Copy(AInterfaceList, I, J - I));
    I := J + 1;
    if SameText(IntfName, 'TObject') or SameText(IntfName, 'TInterfacedObject') then
      Continue;
    Inc(IntfCount);
    SetLength(IntfNames, IntfCount);
    IntfNames[IntfCount - 1] := IntfName;
  end;
  if IntfCount = 0 then
    Exit;
  SlotOffset := LongInt(Meta.Size div 8);
  if SlotOffset <= 0 then
    SlotOffset := Length(Meta.Fields) + 1;
  SetLength(Meta.InterfaceSlots, IntfCount);
  for I := 0 to IntfCount - 1 do
  begin
    Meta.InterfaceSlots[I].InterfaceName := IntfNames[I];
    Meta.InterfaceSlots[I].SlotOffset := SlotOffset + I;
    FModel.AddConstValue(ClsName + '$intf_offset_' + IntfNames[I],
      (SlotOffset + I) * 8);
  end;
  Meta.Size := (SlotOffset + IntfCount) * 8;
  FModel.AddConstValue(ClsName + '$size', Meta.Size);
  FModel.SetTypeMeta(AClassTypeId, Meta);
end;

function TSemanticAnalyzer.CheckSingleConstraint(const AArgType: string;
  const AConstraint: string): Boolean;
var
  IntfList: string;
  SubConstraints: TStringVec;
  I, J: LongInt;
  SC: string;
begin
  Result := True;
  SubConstraints := TStringVec.Create;
  try
    I := 1;
    while I <= Length(AConstraint) do
    begin
      J := I;
      while (J <= Length(AConstraint)) and (AConstraint[J] <> '|') do
        Inc(J);
      SubConstraints.Push(Trim(Copy(AConstraint, I, J - I)));
      I := J + 1;
    end;
    for I := 0 to SubConstraints.Count - 1 do
    begin
      SC := SubConstraints[I];
      if SC = '' then
        Continue;
      if SameText(SC, 'class') then
      begin
        if not TypeMetaIsClass(AArgType) then
        begin
          FDiagnostics.EmitError('sema.constraint-violation', 'sema',
            FRootFileId, 0,
            'type ' + AArgType + ' does not satisfy constraint "class"');
          Result := False;
          Exit;
        end;
      end
      else if SameText(SC, 'record') then
      begin
        if not TypeMetaIsRecord(AArgType) then
        begin
          FDiagnostics.EmitError('sema.constraint-violation', 'sema',
            FRootFileId, 0,
            'type ' + AArgType + ' does not satisfy constraint "record"');
          Result := False;
          Exit;
        end;
      end
      else
      begin
        if not TypeMetaIsClass(AArgType) then
        begin
          FDiagnostics.EmitError('sema.constraint-violation', 'sema',
            FRootFileId, 0,
            'type ' + AArgType + ' does not satisfy interface constraint "' +
            SC + '" (must be a class type)');
          Result := False;
          Exit;
        end;
        IntfList := TypeMetaInterfaces(AArgType);
        if (IntfList = '') or (Pos(',' + SC + ',', ',' + IntfList + ',') = 0) then
        begin
          FDiagnostics.EmitError('sema.constraint-violation', 'sema',
            FRootFileId, 0,
            'type ' + AArgType + ' does not implement interface "' + SC + '"');
          Result := False;
          Exit;
        end;
      end;
    end;
  finally
    SubConstraints.Free;
  end;
end;

procedure TSemanticAnalyzer.RegisterStructuredGenericParent(
  const ATypeId: LongInt; const AParentSpec: string;
  const AOwnerUnitId: string);
var
  LtPos, GtPos, I, J: LongInt;
  ParentName, ArgStr: string;
  ParentTypeId: LongInt;
  OwnerParams: string;
  ArgNames: TStringVec;
  ArgIndices: array of LongInt;
begin
  LtPos := Pos('<', AParentSpec);
  if LtPos <= 0 then
    Exit;
  ParentName := Copy(AParentSpec, 1, LtPos - 1);
  GtPos := 0;
  J := 1;
  for I := LtPos + 1 to Length(AParentSpec) do
  begin
    if AParentSpec[I] = '<' then Inc(J)
    else if AParentSpec[I] = '>' then
    begin
      Dec(J);
      if J = 0 then begin GtPos := I; Break; end;
    end;
  end;
  if GtPos <= LtPos then
    GtPos := Length(AParentSpec) + 1;
  ArgStr := Copy(AParentSpec, LtPos + 1, GtPos - LtPos - 1);

  ParentTypeId := 0;
  for I := 0 to FModel.TypeCount - 1 do
    if SameText(FModel.TypeAt(I).Name, ParentName) and
      (FModel.TypeAt(I).TypeParams <> '') and
      SameText(FModel.TypeAt(I).OwnerUnitId, AOwnerUnitId) then
    begin
      ParentTypeId := FModel.TypeAt(I).TypeId;
      Break;
    end;
  if ParentTypeId <= 0 then
    for I := 0 to FModel.TypeCount - 1 do
      if SameText(FModel.TypeAt(I).Name, ParentName) and
        (FModel.TypeAt(I).TypeParams <> '') then
      begin
        ParentTypeId := FModel.TypeAt(I).TypeId;
        Break;
      end;
  if ParentTypeId <= 0 then
    Exit;

  OwnerParams := FModel.TypeAt(ATypeId - 1).TypeParams;

  ArgNames := TStringVec.Create;
  I := 1;
  while I <= Length(ArgStr) do
  begin
    J := I;
    GtPos := 0;
    while J <= Length(ArgStr) do
    begin
      if ArgStr[J] = '<' then Inc(GtPos)
      else if ArgStr[J] = '>' then Dec(GtPos)
      else if (ArgStr[J] = ',') and (GtPos = 0) then Break;
      Inc(J);
    end;
    ArgNames.Push(Trim(Copy(ArgStr, I, J - I)));
    I := J + 1;
  end;

  SetLength(ArgIndices, ArgNames.Count);
  for I := 0 to ArgNames.Count - 1 do
  begin
    ArgIndices[I] := -1;
    J := 1;
    GtPos := 0;
    while J <= Length(OwnerParams) do
    begin
      if SameText(Copy(OwnerParams, J, Length(ArgNames[I])), ArgNames[I]) and
        ((J + Length(ArgNames[I]) - 1 = Length(OwnerParams)) or
         (OwnerParams[J + Length(ArgNames[I])] = ',')) then
      begin
        ArgIndices[I] := GtPos;
        Break;
      end;
      while (J <= Length(OwnerParams)) and (OwnerParams[J] <> ',') do Inc(J);
      Inc(J);
      Inc(GtPos);
    end;
  end;

  ArgNames.Free;
  FModel.SetTypeGenericParent(ATypeId, ParentTypeId, ArgIndices);
end;

procedure TSemanticAnalyzer.CompletePendingSignatures;
var
  I, BodyIdx: LongInt;
  Decl: TGreenNode;
  SubstSig: string;
  QualName: string;
begin
  for I := 0 to Length(FPendingSignatures) - 1 do
  begin
    QualName := FPendingSignatures[I].GenericName + '.' +
      FPendingSignatures[I].MethodShortName;
    Decl := nil;
    for BodyIdx := 0 to Length(FProcedureBodies) - 1 do
    begin
      if SameText(FProcedureBodies[BodyIdx].Name, QualName) and
        SameText(FProcedureBodies[BodyIdx].OwnerUnitId,
          FPendingSignatures[I].OwnerUnitId) then
      begin
        Decl := FProcedureBodies[BodyIdx].Decl;
        Break;
      end;
    end;
    if Decl = nil then
      for BodyIdx := 0 to Length(FProcedureBodies) - 1 do
        if SameText(FProcedureBodies[BodyIdx].Name, QualName) then
        begin
          Decl := FProcedureBodies[BodyIdx].Decl;
          Break;
        end;
    if Decl <> nil then
    begin
      SubstSig := GetSubstitutedParamSignature(Decl,
        FPendingSignatures[I].ParamNames,
        FPendingSignatures[I].ArgTypes);
      FModel.SetSymbolParamSignature(FPendingSignatures[I].SymbolId, SubstSig);
    end;
  end;
  SetLength(FPendingSignatures, 0);
end;

procedure TSemanticAnalyzer.ProcessClassFields(const ANode: TGreenNode;
  const AOwnerUnitId: string; const ATypeId: LongInt);
var
  I, J: LongInt;
  Child, NameNode: TGreenNode;
  FieldTypeId: LongInt;
  FieldIndex: LongInt;
  ClassScopeId: LongInt;
  ClsName, ParentName, ConstName, FieldName, ParentStringVal: string;
  CurrentVisibility: string;
  ParentFieldVal: Int64;
  DotPos, IdxPos: LongInt;
  ParentTypeId: LongInt;
  PointerTypeId: LongInt;
  SymbolId: LongInt;
  Meta, ParentMeta: TTypeMetadata;
  VmtCount: LongInt;
  HasParentMeta: Boolean;
  IsArrayField, IsDynArrayField: Boolean;
  LowBound, HighBound, ArrayLength: Int64;
begin
  if ANode = nil then
    Exit;
  ClassScopeId := FModel.AddScope(skRecord, '', FCurrentScopeId);
  ClsName := FModel.TypeAt(ATypeId - 1).Name;
  FieldIndex := 1;
  ParentName := '';
  if (ANode.ChildCount > 0) and (ANode.ChildAt(0) <> nil) and
    (ANode.ChildAt(0).NodeKind = gnkIdentifier) then
    ParentName := ANode.ChildAt(0).Text
  else if (ATypeId > 0) and (ATypeId <= FModel.TypeCount) then
  begin
    ParentTypeId := FModel.TypeAt(ATypeId - 1).ParentTypeId;
    if (ParentTypeId > 0) and (ParentTypeId <= FModel.TypeCount) then
      ParentName := FModel.TypeAt(ParentTypeId - 1).Name;
  end;
  if (ParentName = '') and (not SameText(ClsName, 'TObject')) then
    ParentName := 'TObject';
  VmtCount := 0;
  SetLength(Meta.Fields, 0);
  SetLength(Meta.VmtSlots, 0);
  SetLength(Meta.RetPtrMethods, 0);
  SetLength(Meta.Properties, 0);
  HasParentMeta := (ParentName <> '') and FModel.GetTypeMetaByName(ParentName, ParentMeta);
  if ParentName <> '' then
  begin
    ParentFieldVal := TypeMetaSize(ParentName);
    if ParentFieldVal > 0 then
    begin
      FieldIndex := LongInt(ParentFieldVal) div 8;
      if HasParentMeta then
      begin
        for J := 0 to High(ParentMeta.Fields) do
        begin
          FModel.AddConstValue(ClsName + '.' + ParentMeta.Fields[J].Name + '$idx',
            ParentMeta.Fields[J].Index);
          if ParentMeta.Fields[J].IsString then
            FModel.AddConstValue(ClsName + '.' + ParentMeta.Fields[J].Name + '$str', 1);
          if ParentMeta.Fields[J].IsPointer then
            FModel.AddConstValue(ClsName + '.' + ParentMeta.Fields[J].Name + '$ptr', 1);
          if ParentMeta.Fields[J].IsDynArray then
            FModel.AddConstValue(ClsName + '.' + ParentMeta.Fields[J].Name + '$arr', 1);
          if FModel.LookupStringConstValue(
            ParentName + '.' + ParentMeta.Fields[J].Name + '$arr_elem_type',
            ParentStringVal) then
            FModel.AddStringConstValue(
              ClsName + '.' + ParentMeta.Fields[J].Name + '$arr_elem_type',
              ParentStringVal);
          if FModel.LookupConstValue(
            ParentName + '.' + ParentMeta.Fields[J].Name + '$arr_elem_size',
            ParentFieldVal) then
            FModel.AddConstValue(
              ClsName + '.' + ParentMeta.Fields[J].Name + '$arr_elem_size',
              ParentFieldVal);
          SetLength(Meta.Fields, Length(Meta.Fields) + 1);
          Meta.Fields[High(Meta.Fields)] := ParentMeta.Fields[J];
        end;
      end
      else
      begin
        for J := 0 to FModel.ConstValueCount - 1 do
        begin
          ConstName := FModel.ConstValueNameAt(J);
          if (Pos(ParentName + '.', ConstName) = 1) and
            (Pos('$idx', ConstName) > 0) then
          begin
            DotPos := Pos('.', ConstName);
            IdxPos := Pos('$idx', ConstName);
            FieldName := Copy(ConstName, DotPos + 1, IdxPos - DotPos - 1);
            FModel.AddConstValue(ClsName + '.' + FieldName + '$idx',
              FModel.ConstValueAt(J));
          end
          else if (Pos(ParentName + '.', ConstName) = 1) and
            (Pos('$str', ConstName) > 0) then
          begin
            DotPos := Pos('.', ConstName);
            IdxPos := Pos('$str', ConstName);
            FieldName := Copy(ConstName, DotPos + 1, IdxPos - DotPos - 1);
            FModel.AddConstValue(ClsName + '.' + FieldName + '$str',
              FModel.ConstValueAt(J));
          end
          else if (Pos(ParentName + '.', ConstName) = 1) and
            (Pos('$ptr', ConstName) > 0) then
          begin
            DotPos := Pos('.', ConstName);
            IdxPos := Pos('$ptr', ConstName);
            FieldName := Copy(ConstName, DotPos + 1, IdxPos - DotPos - 1);
            FModel.AddConstValue(ClsName + '.' + FieldName + '$ptr',
              FModel.ConstValueAt(J));
          end
          else if (Pos(ParentName + '.', ConstName) = 1) and
            (Pos('$arr', ConstName) = Length(ConstName) - 3) then
          begin
            DotPos := Pos('.', ConstName);
            IdxPos := Pos('$arr', ConstName);
            FieldName := Copy(ConstName, DotPos + 1, IdxPos - DotPos - 1);
            FModel.AddConstValue(ClsName + '.' + FieldName + '$arr',
              FModel.ConstValueAt(J));
          end;
        end;
      end;
    end;
    if HasParentMeta then
    begin
      VmtCount := ParentMeta.VmtCount;
      FModel.AddConstValue(ClsName + '$vmt_count', VmtCount);
      for J := 0 to High(ParentMeta.VmtSlots) do
      begin
        FModel.AddConstValue(ClsName + '$vmt_slot_' +
          ParentMeta.VmtSlots[J].MethodName, ParentMeta.VmtSlots[J].SlotIndex);
        FModel.AddStringConstValue(ClsName + '$vmt_func_' +
          IntToStr(ParentMeta.VmtSlots[J].SlotIndex),
          ParentMeta.VmtSlots[J].FuncQualName);
        SetLength(Meta.VmtSlots, Length(Meta.VmtSlots) + 1);
        Meta.VmtSlots[High(Meta.VmtSlots)] := ParentMeta.VmtSlots[J];
      end;
    end
    else
    begin
      ParentFieldVal := TypeMetaVmtCount(ParentName);
      if ParentFieldVal >= 0 then
      begin
        VmtCount := LongInt(ParentFieldVal);
        FModel.AddConstValue(ClsName + '$vmt_count', VmtCount);
        for J := 0 to FModel.ConstValueCount - 1 do
        begin
          ConstName := FModel.ConstValueNameAt(J);
          if (Pos(ParentName + '$vmt_slot_', ConstName) = 1) then
          begin
            FieldName := Copy(ConstName,
              Length(ParentName + '$vmt_slot_') + 1, Length(ConstName));
            FModel.AddConstValue(ClsName + '$vmt_slot_' + FieldName,
              FModel.ConstValueAt(J));
          end;
        end;
        for J := 0 to VmtCount - 1 do
        begin
          ConstName := ParentName + '$vmt_func_' + IntToStr(J);
          if FModel.LookupStringConstValue(ConstName, FieldName) then
            FModel.AddStringConstValue(
              ClsName + '$vmt_func_' + IntToStr(J), FieldName);
        end;
      end;
    end;
    FModel.AddStringConstValue(ClsName + '$parent_class', ParentName);
  end;
  CurrentVisibility := 'public';
  for I := 0 to ANode.ChildCount - 1 do
  begin
    Child := ANode.ChildAt(I);
    if Child = nil then
      Continue;
    if (Child.NodeKind = gnkIdentifier) and (Pos('where:', Child.Text) = 1) then
    begin
      AppendWhereConstraint(ATypeId, Copy(Child.Text, 7, MaxInt));
      Continue;
    end;
    if Child.NodeKind = gnkVisibilityLabel then
    begin
      CurrentVisibility := LowerCase(Child.Text);
      Continue;
    end;
    if Child.NodeKind = gnkClassField then
    begin
      FieldTypeId := 0;
      IsArrayField := (Child.ChildCount > 0) and (Child.ChildAt(0) <> nil) and
        (Child.ChildAt(0).NodeKind = gnkArrayType);
      IsDynArrayField := IsArrayField and
        (not TryGetArrayTypeBounds(
          Child.ChildAt(0), LowBound, HighBound, ArrayLength));
      if Child.ChildCount > 0 then
      begin
        NameNode := Child.ChildAt(0);
        if (NameNode <> nil) and (NameNode.NodeKind = gnkIdentifier) then
          FieldTypeId := ResolveTypeIdForOwner(NameNode.Text, AOwnerUnitId);
        if (NameNode <> nil) and (NameNode.NodeKind = gnkArrayType) then
        begin
          PointerTypeId := FModel.FindTypeByName('Pointer');
          if PointerTypeId > 0 then
            FieldTypeId := PointerTypeId;
        end;
      end;
      FModel.AddSymbol(Child.Text, 'field', AOwnerUnitId, FieldTypeId,
        Child.ByteOffset);
      FModel.SetSymbolScope(FModel.SymbolCount, ClassScopeId);
      FModel.SetSymbolVisibility(FModel.SymbolCount, CurrentVisibility);
      FModel.AddConstValue(
        ClsName + '.' + Child.Text + '$idx',
        FieldIndex);
      if IsArrayField then
      begin
        if IsDynArrayField then
          FModel.AddConstValue(ClsName + '.' + Child.Text + '$arr', 1);
        NameNode := ArrayElementTypeNode(Child.ChildAt(0));
        if NameNode <> nil then
        begin
          FModel.AddStringConstValue(
            ClsName + '.' + Child.Text + '$arr_elem_type',
            NameNode.Text);
          if TypeMetaIsRecord(NameNode.Text) then
            FModel.AddConstValue(
              ClsName + '.' + Child.Text + '$arr_elem_size',
              TypeMetaSize(NameNode.Text))
          else
            FModel.AddConstValue(
              ClsName + '.' + Child.Text + '$arr_elem_size',
              8);
        end;
      end;
      if (Child.ChildCount > 0) and (Child.ChildAt(0) <> nil) and
        ((TypeMetaSize(Child.ChildAt(0).Text) > 0) or
         SameText(Child.ChildAt(0).Text, ClsName)) then
        FModel.AddConstValue(
          ClsName + '.' + Child.Text + '$ptr', 1);
      if (Child.ChildCount > 0) and (Child.ChildAt(0) <> nil) and
        (SameText(Child.ChildAt(0).Text, 'String') or
         SameText(Child.ChildAt(0).Text, 'AnsiString')) then
      begin
        FModel.AddConstValue(ClsName + '.' + Child.Text + '$str', 1);
        Inc(FieldIndex, 4);
      end
      else if IsDynArrayField then
        Inc(FieldIndex, 2)
      else if (Child.ChildCount > 0) and (Child.ChildAt(0) <> nil) and
        TypeMetaIsRecord(Child.ChildAt(0).Text) and
        (TypeMetaSize(Child.ChildAt(0).Text) > 0) then
      begin
        ParentFieldVal := TypeMetaSize(Child.ChildAt(0).Text);
        for J := 0 to FModel.ConstValueCount - 1 do
        begin
          ConstName := FModel.ConstValueNameAt(J);
          if (Pos(Child.ChildAt(0).Text + '.', ConstName) = 1) and
            (Pos('$idx', ConstName) > 0) then
          begin
            DotPos := Pos('.', ConstName);
            IdxPos := Pos('$idx', ConstName);
            FieldName := Copy(ConstName, DotPos + 1, IdxPos - DotPos - 1);
            FModel.AddConstValue(
              ClsName + '.' + Child.Text + '.' + FieldName + '$idx',
              FieldIndex + FModel.ConstValueAt(J));
          end;
        end;
        Inc(FieldIndex, ParentFieldVal div 8);
      end
      else
        Inc(FieldIndex);
      SetLength(Meta.Fields, Length(Meta.Fields) + 1);
      Meta.Fields[High(Meta.Fields)].Name := Child.Text;
      Meta.Fields[High(Meta.Fields)].Index :=
        TypeMetaFieldIndex(ClsName, Child.Text);
      Meta.Fields[High(Meta.Fields)].IsString :=
        (Child.ChildCount > 0) and (Child.ChildAt(0) <> nil) and
        (SameText(Child.ChildAt(0).Text, 'String') or
         SameText(Child.ChildAt(0).Text, 'AnsiString'));
      Meta.Fields[High(Meta.Fields)].IsPointer :=
        (Child.ChildCount > 0) and (Child.ChildAt(0) <> nil) and
        ((TypeMetaSize(Child.ChildAt(0).Text) > 0) or
         SameText(Child.ChildAt(0).Text, ClsName));
      Meta.Fields[High(Meta.Fields)].IsDynArray := IsDynArrayField;
      Meta.Fields[High(Meta.Fields)].TypeId := FieldTypeId;
    end
    else if Child.NodeKind = gnkClassMethod then
    begin
      if Child.ChildCount > 0 then
      begin
        NameNode := Child.ChildAt(0);
        if (NameNode <> nil) and (NameNode.NodeKind = gnkIdentifier) then
        begin
          SymbolId := FModel.AddSymbol(
            ClsName + '.' + NameNode.Text,
            'method', AOwnerUnitId, ATypeId, Child.ByteOffset);
          FModel.SetSymbolParamCount(SymbolId, CountDeclParams(Child));
          FModel.SetSymbolMinParamCount(SymbolId, CountRequiredDeclParams(Child));
          FModel.SetSymbolParamSignature(SymbolId, GetParamSignature(Child));
          FModel.SetSymbolReturnTypeId(SymbolId,
            DeclReturnTypeId(Child, AOwnerUnitId));
          FModel.SetSymbolVisibility(SymbolId, CurrentVisibility);
          FModel.SetSymbolScope(SymbolId, ClassScopeId);
          if Pos(';virtual', Child.Text) > 0 then
          begin
            FModel.AddConstValue(
              ClsName + '$vmt_slot_' + NameNode.Text, VmtCount);
            FModel.AddStringConstValue(
              ClsName + '$vmt_func_' + IntToStr(VmtCount),
              ClsName + '.' + NameNode.Text);
            SetLength(Meta.VmtSlots, Length(Meta.VmtSlots) + 1);
            Meta.VmtSlots[High(Meta.VmtSlots)].MethodName := NameNode.Text;
            Meta.VmtSlots[High(Meta.VmtSlots)].SlotIndex := VmtCount;
            Meta.VmtSlots[High(Meta.VmtSlots)].FuncQualName :=
              ClsName + '.' + NameNode.Text;
            Inc(VmtCount);
            FModel.AddConstValue(ClsName + '$vmt_count', VmtCount);
            if Pos(';abstract', Child.Text) > 0 then
              FModel.AddStringConstValue(
                ClsName + '$abstract_' + NameNode.Text, 'true');
          end
          else if Pos(';override', Child.Text) > 0 then
          begin
            ParentFieldVal := TypeMetaVmtSlot(ParentName, NameNode.Text);
            if ParentFieldVal >= 0 then
            begin
              FModel.AddConstValue(
                ClsName + '$vmt_slot_' + NameNode.Text, ParentFieldVal);
              FModel.AddStringConstValue(
                ClsName + '$vmt_func_' + IntToStr(ParentFieldVal),
                ClsName + '.' + NameNode.Text);
              for J := 0 to High(Meta.VmtSlots) do
                if Meta.VmtSlots[J].SlotIndex = ParentFieldVal then
                begin
                  Meta.VmtSlots[J].FuncQualName := ClsName + '.' + NameNode.Text;
                  Break;
                end;
            end;
          end;
          if (Child.ChildCount > 1) and (Child.ChildAt(1) <> nil) and
            (Child.ChildAt(1).NodeKind = gnkIdentifier) and
            ((TypeMetaSize(Child.ChildAt(1).Text) > 0) or
             SameText(Child.ChildAt(1).Text, ClsName)) then
            FModel.AddConstValue(
              ClsName + '$ret_ptr_' + NameNode.Text, 1);
          if (Child.ChildCount > 1) and (Child.ChildAt(1) <> nil) and
            (Child.ChildAt(1).NodeKind = gnkIdentifier) and
            (SameText(Child.ChildAt(1).Text, 'String') or
             SameText(Child.ChildAt(1).Text, 'AnsiString')) then
            FModel.AddConstValue(
              ClsName + '$ret_str_' + NameNode.Text, 1);
        end;
      end;
    end
    else if Child.NodeKind = gnkClassProperty then
    begin
      for J := 0 to Child.ChildCount - 1 do
      begin
        NameNode := Child.ChildAt(J);
        if (NameNode <> nil) and (NameNode.NodeKind = gnkIdentifier) then
        begin
          if Pos('read:', NameNode.Text) = 1 then
            FModel.AddStringConstValue(
              ClsName + '.' + Child.Text + '$read',
              Copy(NameNode.Text, 6, Length(NameNode.Text)))
          else if Pos('write:', NameNode.Text) = 1 then
            FModel.AddStringConstValue(
              ClsName + '.' + Child.Text + '$write',
              Copy(NameNode.Text, 7, Length(NameNode.Text)));
        end;
      end;
    end;
  end;
  FModel.AddConstValue(
    ClsName + '$size',
    FieldIndex * 8);
  if VmtCount = 0 then
    FModel.AddConstValue(ClsName + '$vmt_count', 0);
  Meta.TypeId := ATypeId;
  Meta.Size := FieldIndex * 8;
  Meta.IsRecord := False;
  Meta.VmtCount := VmtCount;
  Meta.ParentClassId := FModel.TypeAt(ATypeId - 1).ParentTypeId;
  Meta.ParentClassName := ParentName;
  Meta.Interfaces := '';
  Meta.ArrElemSize := 0;
  Meta.ArrElemType := '';
  Meta.ArrLowBound := 0;
  Meta.ArrHighBound := -1;
  Meta.ArrLength := 0;
  Meta.IsStaticArray := False;
  FModel.SetTypeMeta(ATypeId, Meta);
end;

procedure TSemanticAnalyzer.ProcessTypeSection(const ANode: TGreenNode;
  const AOwnerUnitId: string);
var
  I, J, K: LongInt;
  Child, TypeChild: TGreenNode;
  SymbolId: LongInt;
  TypeId: LongInt;
  ParentTypeId: LongInt;
  InterfaceList: string;
  SizeVal: Int64;
  AliasTargetId: LongInt;
  AliasTargetMeta: TTypeMetadata;
  AliasHasTargetMeta: Boolean;
  AliasLocalMeta: TTypeMetadata;
  TypeName: string;
  TypeKind: string;
begin
  if ANode = nil then
    Exit;
  for I := 0 to ANode.ChildCount - 1 do
  begin
    Child := ANode.ChildAt(I);
    if (Child = nil) or (Child.NodeKind <> gnkTypeDecl) then
      Continue;
    if Child.Text = '' then
      Continue;
    { Handle {$compiler_root} and {$compiler_type_kind} directives }
    TypeName := Child.Text;
    TypeKind := 'declared';
    if Copy(TypeName, 1, 14) = 'compiler_root:' then
    begin
      TypeName := Copy(TypeName, 15, Length(TypeName));
      TypeKind := 'class';
    end
    else if Copy(TypeName, 1, 18) = 'compiler_type_kind:' then
    begin
      TypeName := Copy(TypeName, 19, Length(TypeName));
      TypeKind := 'enum';
    end;
    TypeId := FModel.AddType(TypeName, TypeKind);
    FModel.SetTypeOwner(TypeId, AOwnerUnitId);
    SymbolId := FModel.AddSymbol(TypeName, 'type', AOwnerUnitId, TypeId,
      Child.ByteOffset);
    if FCurrentScopeId > 0 then
      FModel.SetSymbolScope(SymbolId, FCurrentScopeId);
    for J := 0 to Child.ChildCount - 1 do
    begin
      TypeChild := Child.ChildAt(J);
      if (TypeChild <> nil) and (TypeChild.NodeKind = gnkTypeParamList) then
      begin
        FModel.SetTypeParams(TypeId, TypeChild);
        Break;
      end;
    end;
    for J := 0 to Child.ChildCount - 1 do
    begin
      TypeChild := Child.ChildAt(J);
      if TypeChild = nil then
        Continue;
      if TypeChild.NodeKind = gnkEnumType then
        ProcessEnumType(TypeChild, AOwnerUnitId, TypeId)
      else if TypeChild.NodeKind = gnkRecordType then
        ProcessRecordFields(TypeChild, AOwnerUnitId, TypeId)
      else if TypeChild.NodeKind = gnkClassType then
      begin
        { Detect "class of TRef" — exactly one identifier child, no body }
        if (not SameText(TypeChild.Text, 'interface')) and
          (TypeChild.ChildCount = 1) and
          (TypeChild.ChildAt(0) <> nil) and
          (TypeChild.ChildAt(0).NodeKind = gnkIdentifier) then
        begin
          AliasTargetId := ResolveTypeIdForOwner(
            TypeChild.ChildAt(0).Text, AOwnerUnitId);
          if AliasTargetId > 0 then
          begin
            AliasHasTargetMeta := FModel.GetTypeMeta(
              AliasTargetId, AliasTargetMeta);
            if not FModel.GetTypeMeta(TypeId, AliasLocalMeta) then
              FillChar(AliasLocalMeta, SizeOf(AliasLocalMeta), 0);
            AliasLocalMeta.TypeId := TypeId;
            AliasLocalMeta.AliasTargetTypeId := AliasTargetId;
            if AliasHasTargetMeta and (AliasTargetMeta.Size > 0) then
            begin
              AliasLocalMeta.Size := AliasTargetMeta.Size;
              AliasLocalMeta.VmtCount := AliasTargetMeta.VmtCount;
              AliasLocalMeta.ParentClassId := AliasTargetId;
              if FModel.TypeAt(AliasTargetId - 1).Name <> '' then
                AliasLocalMeta.ParentClassName :=
                  FModel.TypeAt(AliasTargetId - 1).Name;
            end;
            FModel.SetTypeMeta(TypeId, AliasLocalMeta);
            FModel.SetTypeParent(TypeId, AliasTargetId);
            FModel.SetTypeKind(TypeId, 'class');
            if TypeMetaSize(Child.Text) <= 0 then
              FModel.AddConstValue(Child.Text + '$size', 8);
          end;
          { Skip normal class processing — this is a class reference type }
        end
        else
        begin
        ParentTypeId := 0;
        if not SameText(TypeChild.Text, 'interface') then
          ParentTypeId := ImplicitSystemObjectParentTypeId(Child.Text);
        if TypeChild.ChildCount > 0 then
        begin
          if TypeChild.ChildAt(0).NodeKind = gnkIdentifier then
          begin
            ParentTypeId := ResolveTypeIdForOwner(
              TypeChild.ChildAt(0).Text,
              AOwnerUnitId
            );
            if (ParentTypeId > 0) and
              (not SameText(FModel.TypeAt(ParentTypeId - 1).Kind, 'class')) and
              (not SameText(FModel.TypeAt(ParentTypeId - 1).Kind, 'interface')) and
              (not SameText(FModel.TypeAt(ParentTypeId - 1).Kind, 'declared')) and
              (not FModel.LookupConstValue(TypeChild.ChildAt(0).Text + '$size', SizeVal)) and
              (TypeMetaSize(TypeChild.ChildAt(0).Text) <= 0) then
              ParentTypeId := 0;
            if (ParentTypeId = 0) and (Pos('<', TypeChild.ChildAt(0).Text) > 0) then
            begin
              FModel.AddStringConstValue(
                AOwnerUnitId + '.' + Child.Text + '$generic_parent',
                TypeChild.ChildAt(0).Text);
              RegisterStructuredGenericParent(TypeId, TypeChild.ChildAt(0).Text,
                AOwnerUnitId);
            end;
          end;
        end
        else if not SameText(TypeChild.Text, 'interface') then
          ParentTypeId := ImplicitSystemObjectParentTypeId(Child.Text);
        if ParentTypeId > 0 then
          FModel.SetTypeParent(TypeId, ParentTypeId);
        if (not SameText(TypeChild.Text, 'interface')) and
          (TypeMetaSize(Child.Text) <= 0) then
          FModel.AddConstValue(Child.Text + '$size', 8);
        InterfaceList := '';
        for K := 0 to TypeChild.ChildCount - 1 do
        begin
          if (TypeChild.ChildAt(K) <> nil) and
            (TypeChild.ChildAt(K).NodeKind = gnkIdentifier) and
            (Pos('where:', TypeChild.ChildAt(K).Text) = 0) then
          begin
            if (K = 0) and (ParentTypeId > 0) then
              Continue;
            if InterfaceList <> '' then
              InterfaceList := InterfaceList + ',';
            InterfaceList := InterfaceList + TypeChild.ChildAt(K).Text;
          end;
        end;
        if InterfaceList <> '' then
          FModel.AddStringConstValue(Child.Text + '$interfaces', InterfaceList);
        if not SameText(TypeChild.Text, 'interface') then
        begin
          ProcessClassFields(TypeChild, AOwnerUnitId, TypeId);
          if InterfaceList <> '' then
          begin
            VerifyInterfaceImplementation(TypeId, InterfaceList, AOwnerUnitId);
            RegisterInterfaceSlots(TypeId, InterfaceList);
          end;
        end
        else
          ProcessInterfaceMethods(TypeChild, AOwnerUnitId, TypeId);
        end; { else: normal class (not class-of) }
      end
      else if (TypeChild.NodeKind = gnkIdentifier) and
        (Pos('<', TypeChild.Text) > 0) then
        InstantiateGenericType(TypeId, TypeChild.Text, AOwnerUnitId)
      else if TypeChild.NodeKind = gnkIdentifier then
      begin
        AliasTargetId := ResolveTypeIdForOwner(
          TypeChild.Text, AOwnerUnitId);
        if AliasTargetId > 0 then
        begin
          AliasHasTargetMeta := FModel.GetTypeMeta(
            AliasTargetId, AliasTargetMeta);
          if not FModel.GetTypeMeta(TypeId, AliasLocalMeta) then
            FillChar(AliasLocalMeta, SizeOf(AliasLocalMeta), 0);
          AliasLocalMeta.TypeId := TypeId;
          AliasLocalMeta.AliasTargetTypeId := AliasTargetId;
          if AliasHasTargetMeta and (AliasTargetMeta.Size > 0) then
          begin
            AliasLocalMeta.Size := AliasTargetMeta.Size;
            AliasLocalMeta.IsRecord := AliasTargetMeta.IsRecord;
            AliasLocalMeta.VmtCount := AliasTargetMeta.VmtCount;
            AliasLocalMeta.ParentClassId := AliasTargetId;
            if FModel.TypeAt(AliasTargetId - 1).Name <> '' then
              AliasLocalMeta.ParentClassName := FModel.TypeAt(AliasTargetId - 1).Name;
          end;
          FModel.SetTypeMeta(TypeId, AliasLocalMeta);
          FModel.SetTypeParent(TypeId, AliasTargetId);
        end;
      end;
    end;
  end;
end;

procedure TSemanticAnalyzer.InstantiateGenericType(
  const AInstanceTypeId: LongInt;
  const ASpecText: string;
  const AOwnerUnitId: string);
var
  GenericName: string;
  LtPos, GtPos: LongInt;
  GenericTypeId: LongInt;
  GenericType: TSemanticType;
  InstanceName: string;
  I, J, BodyIdx: LongInt;
  SizeVal: Int64;
  Symbol: TSemanticSymbol;
  NewSymbolId: LongInt;
  QualPrefix: string;
  ArgStr, ParamStr, ConstraintStr: string;
  ArgTypes: TStringVec;
  ParamNames: TStringVec;
  Constraints: TStringVec;
  MethodShortName: string;
  SubstSig: string;
  Decl: TGreenNode;
  GenericMeta: TTypeMetadata;
  HasGenericMeta: Boolean;
begin
  LtPos := Pos('<', ASpecText);
  if LtPos <= 0 then
    Exit;
  GenericName := Copy(ASpecText, 1, LtPos - 1);
  GtPos := 0;
  J := 1;
  for I := LtPos + 1 to Length(ASpecText) do
  begin
    if ASpecText[I] = '<' then
      Inc(J)
    else if ASpecText[I] = '>' then
    begin
      Dec(J);
      if J = 0 then
      begin
        GtPos := I;
        Break;
      end;
    end;
  end;
  if GtPos <= LtPos then
    GtPos := Length(ASpecText) + 1;
  ArgStr := Copy(ASpecText, LtPos + 1, GtPos - LtPos - 1);

  GenericTypeId := 0;
  for I := 0 to FModel.TypeCount - 1 do
  begin
    GenericType := FModel.TypeAt(I);
    if SameText(GenericType.Name, GenericName) and
      (GenericType.TypeParams <> '') and
      SameText(GenericType.OwnerUnitId, AOwnerUnitId) then
    begin
      GenericTypeId := GenericType.TypeId;
      Break;
    end;
  end;
  if GenericTypeId <= 0 then
  begin
    for I := 0 to FModel.TypeCount - 1 do
    begin
      GenericType := FModel.TypeAt(I);
      if SameText(GenericType.Name, GenericName) and
        (GenericType.TypeParams <> '') then
      begin
        GenericTypeId := GenericType.TypeId;
        Break;
      end;
    end;
  end;
  if GenericTypeId <= 0 then
    Exit;
  GenericType := FModel.TypeAt(GenericTypeId - 1);
  ParamStr := GenericType.TypeParams;
  ConstraintStr := GenericType.TypeConstraints;
  if AInstanceTypeId <= 0 then
    Exit;
  FModel.SetTypeInstantiatedFrom(AInstanceTypeId, GenericTypeId);

  ArgTypes := TStringVec.Create;
  I := 1;
  while I <= Length(ArgStr) do
  begin
    J := I;
    GtPos := 0;
    while J <= Length(ArgStr) do
    begin
      if ArgStr[J] = '<' then
        Inc(GtPos)
      else if ArgStr[J] = '>' then
        Dec(GtPos)
      else if (ArgStr[J] = ',') and (GtPos = 0) then
        Break;
      Inc(J);
    end;
    ArgTypes.Push(Trim(Copy(ArgStr, I, J - I)));
    I := J + 1;
  end;

  ParamNames := TStringVec.Create;
  I := 1;
  while I <= Length(ParamStr) do
  begin
    J := I;
    while (J <= Length(ParamStr)) and (ParamStr[J] <> ',') do
      Inc(J);
    ParamNames.Push(Trim(Copy(ParamStr, I, J - I)));
    I := J + 1;
  end;

  for I := 0 to ArgTypes.Count - 1 do
  begin
    if Pos('<', ArgTypes[I]) > 0 then
      ResolveOrInstantiateInlineGeneric(ArgTypes[I], AOwnerUnitId);
  end;

  Constraints := TStringVec.Create;
  I := 1;
  while I <= Length(ConstraintStr) do
  begin
    J := I;
    while (J <= Length(ConstraintStr)) and (ConstraintStr[J] <> ',') do
      Inc(J);
    Constraints.Push(Trim(Copy(ConstraintStr, I, J - I)));
    I := J + 1;
  end;

  if (ParamNames.Count > 0) and (ArgTypes.Count <> ParamNames.Count) then
  begin
    FDiagnostics.EmitError('sema.generic-arity-mismatch', 'sema',
      FRootFileId, 0,
      'generic type ' + GenericName + ' expects ' + IntToStr(ParamNames.Count) +
      ' type argument(s), but ' + IntToStr(ArgTypes.Count) + ' provided');
    Exit;
  end;

  for I := 0 to Constraints.Count - 1 do
  begin
    if (Constraints[I] = '') or (I >= ArgTypes.Count) then
      Continue;
    if not CheckSingleConstraint(ArgTypes[I], Constraints[I]) then
      Exit;
  end;

  InstanceName := FModel.TypeAt(AInstanceTypeId - 1).Name;
  QualPrefix := GenericName + '.';
  for I := 0 to FModel.SymbolCount - 1 do
  begin
    Symbol := FModel.SymbolAt(I);
    if (Pos(QualPrefix, Symbol.Name) = 1) and
      (SameText(Symbol.Kind, 'method') or
       SameText(Symbol.Kind, 'constructor') or
       SameText(Symbol.Kind, 'destructor')) then
    begin
      MethodShortName := Copy(Symbol.Name, Length(QualPrefix) + 1, MaxInt);
      NewSymbolId := FModel.AddSymbol(
        InstanceName + '.' + MethodShortName,
        Symbol.Kind, AOwnerUnitId, AInstanceTypeId, Symbol.ByteOffset);
      FModel.SetSymbolParamCount(NewSymbolId, Symbol.ParamCount);
      FModel.SetSymbolMinParamCount(NewSymbolId, Symbol.MinParamCount);

      SubstSig := '';
      if (ParamNames.Count > 0) and (ArgTypes.Count >= ParamNames.Count) then
      begin
        Decl := nil;
        for BodyIdx := 0 to Length(FProcedureBodies) - 1 do
        begin
          if SameText(FProcedureBodies[BodyIdx].Name, GenericName + '.' + MethodShortName) then
          begin
            Decl := FProcedureBodies[BodyIdx].Decl;
            Break;
          end;
        end;
        if Decl <> nil then
          SubstSig := GetSubstitutedParamSignature(Decl, ParamNames.ToArray, ArgTypes.ToArray)
        else
        begin
          BodyIdx := Length(FPendingSignatures);
          SetLength(FPendingSignatures, BodyIdx + 1);
          FPendingSignatures[BodyIdx].SymbolId := NewSymbolId;
          FPendingSignatures[BodyIdx].GenericName := GenericName;
          FPendingSignatures[BodyIdx].MethodShortName := MethodShortName;
          FPendingSignatures[BodyIdx].OwnerUnitId := AOwnerUnitId;
          SetLength(FPendingSignatures[BodyIdx].ParamNames, ParamNames.Count);
          for BodyIdx := 0 to ParamNames.Count - 1 do
            FPendingSignatures[High(FPendingSignatures)].ParamNames[BodyIdx] := ParamNames[BodyIdx];
          SetLength(FPendingSignatures[High(FPendingSignatures)].ArgTypes, ArgTypes.Count);
          for BodyIdx := 0 to ArgTypes.Count - 1 do
            FPendingSignatures[High(FPendingSignatures)].ArgTypes[BodyIdx] := ArgTypes[BodyIdx];
        end;
      end;
      FModel.SetSymbolParamSignature(NewSymbolId, SubstSig);
    end;
  end;
  for I := 0 to FModel.SymbolCount - 1 do
  begin
    Symbol := FModel.SymbolAt(I);
    if (Pos(QualPrefix, Symbol.Name) = 1) and
      SameText(Symbol.Kind, 'field') then
    begin
      MethodShortName := Copy(Symbol.Name, Length(QualPrefix) + 1, MaxInt);
      FModel.AddSymbol(InstanceName + '.' + MethodShortName,
        'field', AOwnerUnitId, AInstanceTypeId, Symbol.ByteOffset);
      SizeVal := TypeMetaFieldIndex(GenericName, MethodShortName);
      if SizeVal >= 0 then
        FModel.AddConstValue(InstanceName + '.' + MethodShortName + '$idx', SizeVal);
      if TypeMetaFieldIsStr(GenericName, MethodShortName) then
        FModel.AddConstValue(InstanceName + '.' + MethodShortName + '$str', 1);
      if TypeMetaFieldIsPtr(GenericName, MethodShortName) then
        FModel.AddConstValue(InstanceName + '.' + MethodShortName + '$ptr', 1);
    end;
  end;
  { Copy TypeMetadata (Fields array) from generic type to instance type.
    Field symbols use unqualified names (e.g. 'FHashFunc'), so the loop above
    never matches them against QualPrefix. Without this copy, GetFieldMetaByName
    fails for the instance type and the $idx fallback also fails because the
    const values were never copied. }
  HasGenericMeta := FModel.GetTypeMetaByName(GenericName, GenericMeta);
  if HasGenericMeta then
  begin
    GenericMeta.TypeId := AInstanceTypeId;
    FModel.SetTypeMeta(AInstanceTypeId, GenericMeta);
  end;
  FModel.SetTypeParent(AInstanceTypeId,
    FModel.TypeAt(GenericTypeId - 1).ParentTypeId);
  if GenericType.GenericParent.TemplateTypeId > 0 then
  begin
    GtPos := 0;
    for I := 0 to High(GenericType.GenericParent.ArgIndices) do
      if GenericType.GenericParent.ArgIndices[I] < 0 then
      begin
        GtPos := -1;
        Break;
      end;
    if GtPos = 0 then
    begin
      SubstSig := FModel.TypeAt(GenericType.GenericParent.TemplateTypeId - 1).Name + '<';
      for I := 0 to High(GenericType.GenericParent.ArgIndices) do
      begin
        if I > 0 then
          SubstSig := SubstSig + ',';
        J := GenericType.GenericParent.ArgIndices[I];
        if (J >= 0) and (J < ArgTypes.Count) then
          SubstSig := SubstSig + ArgTypes[J]
        else
          SubstSig := SubstSig + '?';
      end;
      SubstSig := SubstSig + '>';
      GtPos := ResolveOrInstantiateInlineGeneric(SubstSig, AOwnerUnitId);
      if GtPos > 0 then
        FModel.SetTypeParent(AInstanceTypeId, GtPos);
    end;
  end;
  if (GenericType.GenericParent.TemplateTypeId <= 0) or (GtPos < 0) then
  if FModel.LookupStringConstValue(GenericType.OwnerUnitId + '.' + GenericName + '$generic_parent', SubstSig) then
  begin
    for I := 0 to ParamNames.Count - 1 do
    begin
      J := 1;
      while J <= Length(SubstSig) - Length(ParamNames[I]) + 1 do
      begin
        if SameText(Copy(SubstSig, J, Length(ParamNames[I])), ParamNames[I]) and
          ((J = 1) or not (SubstSig[J-1] in ['A'..'Z','a'..'z','0'..'9','_'])) and
          ((J + Length(ParamNames[I]) - 1 = Length(SubstSig)) or
           not (SubstSig[J + Length(ParamNames[I])] in ['A'..'Z','a'..'z','0'..'9','_'])) then
        begin
          SubstSig := Copy(SubstSig, 1, J - 1) + ArgTypes[I] +
            Copy(SubstSig, J + Length(ParamNames[I]), MaxInt);
          J := J + Length(ArgTypes[I]);
        end
        else
          Inc(J);
      end;
    end;
    GtPos := ResolveOrInstantiateInlineGeneric(SubstSig, AOwnerUnitId);
    if GtPos > 0 then
      FModel.SetTypeParent(AInstanceTypeId, GtPos);
  end;
  SizeVal := TypeMetaSize(GenericName);
  if SizeVal > 0 then
    FModel.AddConstValue(InstanceName + '$size', SizeVal)
  else
    FModel.AddConstValue(InstanceName + '$size', 8);
  SizeVal := TypeMetaVmtCount(GenericName);
  HasGenericMeta := FModel.GetTypeMetaByName(GenericName, GenericMeta);
  if (SizeVal >= 0) and HasGenericMeta then
  begin
    FModel.AddConstValue(InstanceName + '$vmt_count', SizeVal);
    for I := 0 to High(GenericMeta.VmtSlots) do
    begin
      SubstSig := GenericMeta.VmtSlots[I].FuncQualName;
      if Pos(GenericName + '.', SubstSig) = 1 then
        SubstSig := InstanceName + Copy(SubstSig, Length(GenericName) + 1, MaxInt);
      FModel.AddStringConstValue(InstanceName + '$vmt_func_' +
        IntToStr(GenericMeta.VmtSlots[I].SlotIndex), SubstSig);
      FModel.AddConstValue(InstanceName + '$vmt_slot_' +
        GenericMeta.VmtSlots[I].MethodName, GenericMeta.VmtSlots[I].SlotIndex);
    end;
  end
  else if SizeVal >= 0 then
  begin
    FModel.AddConstValue(InstanceName + '$vmt_count', SizeVal);
    for I := 0 to SizeVal - 1 do
    begin
      if FModel.LookupStringConstValue(GenericName + '$vmt_func_' + IntToStr(I), SubstSig) then
      begin
        if Pos(GenericName + '.', SubstSig) = 1 then
          SubstSig := InstanceName + Copy(SubstSig, Length(GenericName) + 1, MaxInt);
        FModel.AddStringConstValue(InstanceName + '$vmt_func_' + IntToStr(I), SubstSig);
      end;
    end;
  end
  else if TypeMetaVmtCount(InstanceName) < 0 then
    FModel.AddConstValue(InstanceName + '$vmt_count', 0);
  SubstSig := TypeMetaParentClass(GenericName);
  if SubstSig <> '' then
  begin
    if Pos('<', SubstSig) > 0 then
    begin
      for I := 0 to ParamNames.Count - 1 do
      begin
        J := 1;
        while J <= Length(SubstSig) - Length(ParamNames[I]) + 1 do
        begin
          if SameText(Copy(SubstSig, J, Length(ParamNames[I])), ParamNames[I]) and
            ((J = 1) or not (SubstSig[J-1] in ['A'..'Z','a'..'z','0'..'9','_'])) and
            ((J + Length(ParamNames[I]) - 1 = Length(SubstSig)) or
             not (SubstSig[J + Length(ParamNames[I])] in ['A'..'Z','a'..'z','0'..'9','_'])) then
          begin
            SubstSig := Copy(SubstSig, 1, J - 1) + ArgTypes[I] +
              Copy(SubstSig, J + Length(ParamNames[I]), MaxInt);
            J := J + Length(ArgTypes[I]);
          end
          else
            Inc(J);
        end;
      end;
    end;
    FModel.AddStringConstValue(InstanceName + '$parent_class', SubstSig);
  end
  else
    FModel.AddStringConstValue(InstanceName + '$parent_class',
      FModel.TypeAt(GenericTypeId - 1).Name);
  ArgTypes.Free;
  ParamNames.Free;
  Constraints.Free;
end;

function TSemanticAnalyzer.ResolveOrInstantiateInlineGeneric(
  const ASpecText: string; const AOwnerUnitId: string): LongInt;
var
  GenericName: string;
  LtPos: LongInt;
  I: LongInt;
  GenericType: TSemanticType;
  GenericTypeId: LongInt;
  NewTypeId: LongInt;
  CacheKey: string;
  CacheEntry: TGenericCacheEntry;
begin
  Result := 0;
  LtPos := Pos('<', ASpecText);
  if LtPos <= 0 then
    Exit;

  CacheKey := LowerCase(AOwnerUnitId + '#' + ASpecText);
  for I := 0 to FGenericCache.Count - 1 do
    if FGenericCache[I].Key = CacheKey then
    begin
      Result := FGenericCache[I].TypeId;
      Exit;
    end;
  CacheKey := LowerCase(ASpecText);
  for I := 0 to FGenericCache.Count - 1 do
    if (Length(FGenericCache[I].Key) > Length(CacheKey)) and
      (FGenericCache[I].Key[Length(FGenericCache[I].Key) - Length(CacheKey)] = '#') and
      (Copy(FGenericCache[I].Key, Length(FGenericCache[I].Key) - Length(CacheKey) + 1, MaxInt) = CacheKey) then
    begin
      Result := FGenericCache[I].TypeId;
      FModel.AddSymbol(ASpecText, 'type', AOwnerUnitId, Result, 0);
      CacheEntry.Key := LowerCase(AOwnerUnitId + '#' + ASpecText);
      CacheEntry.TypeId := Result;
      FGenericCache.Push(CacheEntry);
      Exit;
    end;

  GenericName := Copy(ASpecText, 1, LtPos - 1);
  GenericTypeId := 0;
  for I := 0 to FModel.TypeCount - 1 do
  begin
    GenericType := FModel.TypeAt(I);
    if SameText(GenericType.Name, GenericName) and
      (GenericType.TypeParams <> '') then
    begin
      GenericTypeId := GenericType.TypeId;
      Break;
    end;
  end;
  if GenericTypeId <= 0 then
    Exit;
  NewTypeId := FModel.AddType(ASpecText, 'declared');
  FModel.SetTypeOwner(NewTypeId, AOwnerUnitId);
  FModel.AddSymbol(ASpecText, 'type', AOwnerUnitId, NewTypeId, 0);

  CacheEntry.Key := CacheKey;
  CacheEntry.TypeId := NewTypeId;
  FGenericCache.Push(CacheEntry);

  InstantiateGenericType(NewTypeId, ASpecText, AOwnerUnitId);
  Result := NewTypeId;
end;

procedure TSemanticAnalyzer.WalkDeclarations(const ANode: TGreenNode;
  const AOwnerUnitId: string);
var
  I: LongInt;
  Child: TGreenNode;
begin
  if ANode = nil then
    Exit;
  for I := 0 to ANode.ChildCount - 1 do
  begin
    Child := ANode.ChildAt(I);
    if Child = nil then
      Continue;
    case Child.NodeKind of
      gnkVarSection:
        ProcessVarSection(Child, AOwnerUnitId);
      gnkConstSection:
        ProcessConstSection(Child, AOwnerUnitId);
      gnkTypeSection:
        ProcessTypeSection(Child, AOwnerUnitId);
      gnkProcedureDecl:
        ProcessProcedureDecl(Child, AOwnerUnitId);
      gnkFunctionDecl:
        ProcessFunctionDecl(Child, AOwnerUnitId);
      gnkInterfaceSection, gnkImplementationSection:
        WalkDeclarations(Child, AOwnerUnitId);
    end;
  end;
end;

procedure TSemanticAnalyzer.SeedDeclarations;
var
  OwnerUnitId: string;
  RootNode: TGreenNode;
begin
  if (FRootAst = nil) or not FRootAst.IsValid then
    Exit;
  OwnerUnitId := NormalizeUnitIdentity(FUnitGraph.RootName);
  RootNode := FRootAst.RootNode;
  if RootNode = nil then
    Exit;
  WalkDeclarations(RootNode, OwnerUnitId);
end;

procedure TSemanticAnalyzer.RebindExplicitClassParents;

  procedure RebindTypeSection(
    const ATypeSection: TGreenNode;
    const AOwnerUnitId: string
  );
  var
    Child: TGreenNode;
    Index: LongInt;
    Meta: TTypeMetadata;
    ParentNode: TGreenNode;
    ParentTypeId: LongInt;
    TypeChild: TGreenNode;
    TypeId: LongInt;
    TypeInfo: TSemanticType;
    TypeIndex: LongInt;
  begin
    if ATypeSection = nil then
      Exit;

    for Index := 0 to ATypeSection.ChildCount - 1 do
    begin
      Child := ATypeSection.ChildAt(Index);
      if (Child = nil) or (Child.NodeKind <> gnkTypeDecl) or
        (Child.Text = '') then
        Continue;

      TypeId := ResolveTypeIdForOwner(Child.Text, AOwnerUnitId);
      if (TypeId <= 0) or (TypeId > FModel.TypeCount) then
        Continue;

      TypeInfo := FModel.TypeAt(TypeId - 1);
      if TypeInfo.ParentTypeId > 0 then
        Continue;

      for TypeIndex := 0 to Child.ChildCount - 1 do
      begin
        TypeChild := Child.ChildAt(TypeIndex);
        if (TypeChild = nil) or (TypeChild.NodeKind <> gnkClassType) or
          SameText(TypeChild.Text, 'interface') or
          (TypeChild.ChildCount = 0) then
          Continue;

        ParentNode := TypeChild.ChildAt(0);
        if (ParentNode = nil) or (ParentNode.NodeKind <> gnkIdentifier) then
          Break;

        ParentTypeId := ResolveTypeIdForOwner(ParentNode.Text, AOwnerUnitId);
        if (ParentTypeId <= 0) or (ParentTypeId > FModel.TypeCount) then
          Break;
        if TypeMetaIsInterface(FModel.TypeAt(ParentTypeId - 1).Name) then
          Break;

        FModel.SetTypeParent(TypeId, ParentTypeId);
        if FModel.GetTypeMeta(TypeId, Meta) then
        begin
          Meta.ParentClassId := ParentTypeId;
          if Meta.ParentClassName = '' then
            Meta.ParentClassName := FModel.TypeAt(ParentTypeId - 1).Name;
          FModel.SetTypeMeta(TypeId, Meta);
        end;
        Break;
      end;
    end;
  end;

  procedure RebindInNode(
    const ANode: TGreenNode;
    const AOwnerUnitId: string
  );
  var
    Child: TGreenNode;
    Index: LongInt;
  begin
    if ANode = nil then
      Exit;

    for Index := 0 to ANode.ChildCount - 1 do
    begin
      Child := ANode.ChildAt(Index);
      if Child = nil then
        Continue;
      case Child.NodeKind of
        gnkTypeSection:
          RebindTypeSection(Child, AOwnerUnitId);
        gnkInterfaceSection, gnkImplementationSection:
          RebindInNode(Child, AOwnerUnitId);
      end;
    end;
  end;

var
  Index: LongInt;
  RootNode: TGreenNode;
begin
  if (FRootAst <> nil) and FRootAst.IsValid then
  begin
    RootNode := FRootAst.RootNode;
    if RootNode <> nil then
      RebindInNode(RootNode, NormalizeUnitIdentity(FUnitGraph.RootName));
  end;

  for Index := 0 to Length(FImportedUnitTrees) - 1 do
    RebindInNode(FImportedUnitTrees[Index].RootNode, FImportedUnitOwners[Index]);
end;

procedure TSemanticAnalyzer.WalkAssignmentStatements(const ANode: TGreenNode);
var
  I: LongInt;
  Child, RhsNode, BranchNode: TGreenNode;
  LhsSymbolId, RhsSymbolId: LongInt;
  LhsTypeId, RhsTypeId: LongInt;
  Value, CondValue: Int64;
begin
  if ANode = nil then
    Exit;
  for I := 0 to ANode.ChildCount - 1 do
  begin
    Child := ANode.ChildAt(I);
    if Child = nil then
      Continue;
    if (Child.NodeKind = gnkProcedureDecl) or
      (Child.NodeKind = gnkFunctionDecl) then
      Continue;
    if Child.NodeKind = gnkIfStatement then
    begin
      if (Child.ChildCount >= 2) and
        EvaluateIntegerConstant(Child.ChildAt(0), CondValue) then
      begin
        if CondValue <> 0 then
          BranchNode := Child.ChildAt(1)
        else if Child.ChildCount >= 3 then
          BranchNode := Child.ChildAt(2)
        else
          BranchNode := nil;
        if BranchNode <> nil then
          WalkAssignmentStatements(BranchNode);
      end
      else
        WalkAssignmentStatements(Child);
      Continue;
    end;
    if Child.NodeKind = gnkForStatement then
    begin
      UnrollAssignmentForLoop(Child);
      Continue;
    end;
    if Child.NodeKind = gnkWhileStatement then
    begin
      UnrollAssignmentWhileLoop(Child);
      Continue;
    end;
    if Child.NodeKind = gnkRepeatStatement then
    begin
      UnrollAssignmentRepeatLoop(Child);
      Continue;
    end;
    if Child.NodeKind = gnkAssignmentStatement then
    begin
      LhsSymbolId := FindSymbolByName(Child.Text);
      if LhsSymbolId = 0 then
        Continue;
      LhsTypeId := FModel.SymbolTypeId(LhsSymbolId);
      RhsNode := nil;
      if Child.ChildCount >= 2 then
        RhsNode := Child.ChildAt(1)
      else if (Child.ChildCount = 1) and
        (Child.ChildAt(0).NodeKind <> gnkIdentifier) and
        (Child.ChildAt(0).NodeKind <> gnkDotAccess) and
        (Child.ChildAt(0).NodeKind <> gnkArrayAccess) then
        RhsNode := Child.ChildAt(0);
      if RhsNode <> nil then
      begin
        if EvaluateIntegerConstant(RhsNode, Value) then
          FModel.AddVarInitValue(Child.Text, Value)
        else
          FModel.RemoveVarInitValue(Child.Text);
      end;
    end
    else
      WalkAssignmentStatements(Child);
  end;
end;

procedure TSemanticAnalyzer.UnrollAssignmentForLoop(const ANode: TGreenNode);
const
  MaxIterations = 1024;
var
  LoopVar: string;
  StartValue, EndValue, IterValue: Int64;
  Direction: string;
  BodyNode: TGreenNode;
  IterCount: LongInt;
begin
  if (ANode = nil) or (ANode.ChildCount < 4) then
    Exit;
  if ANode.ChildAt(0).NodeKind <> gnkIdentifier then
    Exit;
  LoopVar := ANode.ChildAt(0).Text;
  if not EvaluateIntegerConstant(ANode.ChildAt(1), StartValue) then
    Exit;
  if not EvaluateIntegerConstant(ANode.ChildAt(2), EndValue) then
    Exit;
  Direction := ANode.Text;
  BodyNode := ANode.ChildAt(3);
  IterCount := 0;
  IterValue := StartValue;
  if SameText(Direction, 'to') then
  begin
    while (IterValue <= EndValue) and (IterCount < MaxIterations) do
    begin
      FModel.AddVarInitValue(LoopVar, IterValue);
      WalkAssignmentStatements(BodyNode);
      Inc(IterValue);
      Inc(IterCount);
    end;
  end
  else if SameText(Direction, 'downto') then
  begin
    while (IterValue >= EndValue) and (IterCount < MaxIterations) do
    begin
      FModel.AddVarInitValue(LoopVar, IterValue);
      WalkAssignmentStatements(BodyNode);
      Dec(IterValue);
      Inc(IterCount);
    end;
  end;
end;

procedure TSemanticAnalyzer.UnrollAssignmentWhileLoop(const ANode: TGreenNode);
const
  MaxIterations = 1024;
var
  CondNode, BodyNode: TGreenNode;
  CondValue: Int64;
  IterCount: LongInt;
begin
  if (ANode = nil) or (ANode.ChildCount < 2) then
    Exit;
  CondNode := ANode.ChildAt(0);
  BodyNode := ANode.ChildAt(1);
  IterCount := 0;
  while IterCount < MaxIterations do
  begin
    if not EvaluateIntegerConstant(CondNode, CondValue) then
      Exit;
    if CondValue = 0 then
      Exit;
    WalkAssignmentStatements(BodyNode);
    Inc(IterCount);
  end;
end;

procedure TSemanticAnalyzer.UnrollAssignmentRepeatLoop(const ANode: TGreenNode);
const
  MaxIterations = 1024;
var
  BodyNode, CondNode: TGreenNode;
  CondValue: Int64;
  IterCount: LongInt;
begin
  if (ANode = nil) or (ANode.ChildCount < 2) then
    Exit;
  BodyNode := ANode.ChildAt(0);
  CondNode := ANode.ChildAt(1);
  IterCount := 0;
  while IterCount < MaxIterations do
  begin
    WalkAssignmentStatements(BodyNode);
    Inc(IterCount);
    if not EvaluateIntegerConstant(CondNode, CondValue) then
      Exit;
    if CondValue <> 0 then
      Exit;
  end;
end;

procedure TSemanticAnalyzer.CheckAssignmentTypes;
var
  RootNode: TGreenNode;
begin
  if (FRootAst = nil) or not FRootAst.IsValid then
    Exit;
  RootNode := FRootAst.RootNode;
  if RootNode = nil then
    Exit;
  WalkAssignmentStatements(RootNode);
end;

function TSemanticAnalyzer.EvaluateIntegerConstant(const ANode: TGreenNode;
  out AValue: Int64): Boolean;
var
  ArgNode: TGreenNode;
  Fact: TSemanticScalarTypeFact;
  IntrinsicName: string;
  Parsed: Int64;
  ParseCode: Word;
  Left, Right: Int64;
  Op: string;
  BodyNode, DeclNode: TGreenNode;
  ParamSnaps: TParamSnapshots;
  TypeId: LongInt;
  TypeName: string;
begin
  AValue := 0;
  if ANode = nil then
    Exit(False);
  case ANode.NodeKind of
    gnkIntegerLiteral:
      begin
        Val(ANode.Text, Parsed, ParseCode);
        if ParseCode <> 0 then
          Exit(False);
        AValue := Parsed;
        Exit(True);
      end;
    gnkIdentifier:
      begin
        if SameText(ANode.Text, 'true') then
        begin
          AValue := 1;
          Exit(True);
        end;
        if SameText(ANode.Text, 'false') then
        begin
          AValue := 0;
          Exit(True);
        end;
        if FModel.LookupConstValue(ANode.Text, Parsed) then
        begin
          AValue := Parsed;
          Exit(True);
        end;
        if FModel.LookupVarInitValue(ANode.Text, Parsed) then
        begin
          AValue := Parsed;
          Exit(True);
        end;
        if (not FNoFold) and
          LookupProcedureBody(ANode.Text, BodyNode, DeclNode) and
          (BodyNode <> nil) and
          not IsCurrentlyInlining(ANode.Text) then
        begin
          PushInlining(ANode.Text);
          ParamSnaps := nil;
          try
            WalkAssignmentStatements(BodyNode);
          finally
            PopInlining;
            RestoreCallArgs(ParamSnaps);
          end;
          if FModel.LookupVarInitValue(ANode.Text, Parsed) then
          begin
            AValue := Parsed;
            Exit(True);
          end;
        end;
        Exit(False);
      end;
    gnkFunctionCall:
      begin
        if TryGetIntrinsicExprName(ANode, IntrinsicName) then
        begin
          ArgNode := nil;
          if ANode.ChildCount >= 2 then
            ArgNode := ANode.ChildAt(1);
          if SameText(IntrinsicName, 'SizeOf') and (ArgNode <> nil) then
          begin
            TypeId := 0;
            if ArgNode.NodeKind = gnkIdentifier then
              TypeId := ResolveTypeIdForOwner(
                ArgNode.Text,
                NormalizeUnitIdentity(FCurrentProcessingUnitId)
              );
            if TypeId <= 0 then
              TypeId := InferExpressionType(ArgNode);
            if (TypeId > 0) and FModel.GetTypeScalarFact(TypeId, Fact) then
            begin
              AValue := Fact.BitWidth div 8;
              Exit(AValue > 0);
            end;
            if (TypeId > 0) and (TypeId <= FModel.TypeCount) then
            begin
              TypeName := FModel.TypeAt(TypeId - 1).Name;
              if TypeMetaSize(TypeName) > 0 then
              begin
                AValue := TypeMetaSize(TypeName) div 8;
                Exit(AValue > 0);
              end;
            end;
          end
          else if SameText(IntrinsicName, 'Length') and (ArgNode <> nil) and
            (ArgNode.NodeKind = gnkStringLiteral) then
          begin
            AValue := Length(DecodePascalStringLiteral(ArgNode.Text));
            Exit(True);
          end
          else if SameText(IntrinsicName, 'Default') and (ArgNode <> nil) then
          begin
            TypeId := 0;
            if ArgNode.NodeKind = gnkIdentifier then
              TypeId := ResolveTypeIdForOwner(
                ArgNode.Text,
                NormalizeUnitIdentity(FCurrentProcessingUnitId)
              );
            if TypeId <= 0 then
              TypeId := InferExpressionType(ArgNode);
            if (TypeId > 0) and FModel.GetTypeScalarFact(TypeId, Fact) and
              (Fact.Kind in [sskBool, sskInt]) then
            begin
              AValue := 0;
              Exit(True);
            end;
          end
          else if SameText(IntrinsicName, 'Ord') and (ArgNode <> nil) then
          begin
            if (ArgNode.NodeKind = gnkStringLiteral) and
              (Length(ArgNode.Text) = 3) and (ArgNode.Text[1] = '''') then
            begin
              AValue := Ord(ArgNode.Text[2]);
              Exit(True);
            end;
            if EvaluateIntegerConstant(ArgNode, Parsed) then
            begin
              AValue := Parsed;
              Exit(True);
            end;
          end
          else if SameText(IntrinsicName, 'Chr') and (ArgNode <> nil) and
            EvaluateIntegerConstant(ArgNode, Parsed) then
          begin
            AValue := Parsed;
            Exit(True);
          end
          else if SameText(IntrinsicName, 'Pred') and (ArgNode <> nil) and
            EvaluateIntegerConstant(ArgNode, Parsed) then
          begin
            AValue := Parsed - 1;
            Exit(True);
          end
          else if SameText(IntrinsicName, 'Succ') and (ArgNode <> nil) and
            EvaluateIntegerConstant(ArgNode, Parsed) then
          begin
            AValue := Parsed + 1;
            Exit(True);
          end;
        end;
        if LookupProcedureBody(ANode.Text, BodyNode, DeclNode) and
          (BodyNode <> nil) and
          not IsCurrentlyInlining(ANode.Text) then
        begin
          PushInlining(ANode.Text);
          ParamSnaps := BindCallArgs(DeclNode, ANode, 1);
          try
            WalkAssignmentStatements(BodyNode);
          finally
            PopInlining;
            RestoreCallArgs(ParamSnaps);
          end;
          if FModel.LookupVarInitValue(ANode.Text, Parsed) then
          begin
            AValue := Parsed;
            Exit(True);
          end;
        end;
        Exit(False);
      end;
    gnkUnaryExpression:
      begin
        if ANode.ChildCount < 1 then
          Exit(False);
        if not EvaluateIntegerConstant(ANode.ChildAt(0), Parsed) then
          Exit(False);
        Op := ANode.Text;
        if Op = '-' then
          AValue := -Parsed
        else if Op = '+' then
          AValue := Parsed
        else if SameText(Op, 'not') then
          AValue := Ord(Parsed = 0)
        else
          Exit(False);
        Exit(True);
      end;
    gnkBinaryExpression:
      begin
        if ANode.ChildCount < 2 then
          Exit(False);
        if not EvaluateIntegerConstant(ANode.ChildAt(0), Left) then
          Exit(False);
        if not EvaluateIntegerConstant(ANode.ChildAt(1), Right) then
          Exit(False);
        Op := ANode.Text;
        if Op = '+' then
          AValue := Left + Right
        else if Op = '-' then
          AValue := Left - Right
        else if Op = '*' then
          AValue := Left * Right
        else if SameText(Op, 'div') then
        begin
          if Right = 0 then
          begin
            EmitSemaError(
              'sema.division-by-zero',
              'division by zero in constant expression',
              ANode.ByteOffset
            );
            Exit(False);
          end;
          AValue := Left div Right;
        end
        else if SameText(Op, 'mod') then
        begin
          if Right = 0 then
          begin
            EmitSemaError(
              'sema.division-by-zero',
              'division by zero in constant expression',
              ANode.ByteOffset
            );
            Exit(False);
          end;
          AValue := Left mod Right;
        end
        else if Op = '=' then
          AValue := Ord(Left = Right)
        else if Op = '<>' then
          AValue := Ord(Left <> Right)
        else if Op = '<' then
          AValue := Ord(Left < Right)
        else if Op = '>' then
          AValue := Ord(Left > Right)
        else if Op = '<=' then
          AValue := Ord(Left <= Right)
        else if Op = '>=' then
          AValue := Ord(Left >= Right)
        else if SameText(Op, 'and') then
          AValue := Ord((Left <> 0) and (Right <> 0))
        else if SameText(Op, 'or') then
          AValue := Ord((Left <> 0) or (Right <> 0))
        else
          Exit(False);
        Exit(True);
      end;
  end;
  Result := False;
end;


function TSemanticAnalyzer.ArrayElementTypeNode(
  const AArrayTypeNode: TGreenNode): TGreenNode;
begin
  Result := nil;
  if (AArrayTypeNode = nil) or (AArrayTypeNode.NodeKind <> gnkArrayType) then
    Exit;
  if AArrayTypeNode.ChildCount < 1 then
    Exit;
  Result := AArrayTypeNode.ChildAt(0);
end;

function TSemanticAnalyzer.TryGetArrayTypeBounds(
  const AArrayTypeNode: TGreenNode; out ALow, AHigh, ALength: Int64): Boolean;
var
  RangeNode: TGreenNode;
begin
  ALow := 0;
  AHigh := -1;
  ALength := 0;
  if (AArrayTypeNode = nil) or (AArrayTypeNode.NodeKind <> gnkArrayType) or
    (AArrayTypeNode.ChildCount < 2) then
    Exit(False);
  RangeNode := AArrayTypeNode.ChildAt(1);
  if (RangeNode = nil) or (RangeNode.NodeKind <> gnkRangeExpression) or
    (RangeNode.ChildCount < 2) then
    Exit(False);
  if not EvaluateIntegerConstant(RangeNode.ChildAt(0), ALow) then
    Exit(False);
  if not EvaluateIntegerConstant(RangeNode.ChildAt(1), AHigh) then
    Exit(False);
  if AHigh < ALow then
    Exit(False);
  ALength := AHigh - ALow + 1;
  Result := ALength > 0;
end;

function TSemanticAnalyzer.FindArrayTypeNodeForVarDecl(
  const AVarSection: TGreenNode; const ADeclIndex: LongInt): TGreenNode;
var
  K: LongInt;
  Decl, TypeChild, NextSibling: TGreenNode;
begin
  Result := nil;
  if (AVarSection = nil) or (ADeclIndex < 0) or
    (ADeclIndex >= AVarSection.ChildCount) then
    Exit;
  Decl := AVarSection.ChildAt(ADeclIndex);
  if (Decl = nil) or (Decl.NodeKind <> gnkVarDecl) then
    Exit;
  if Decl.ChildCount > 0 then
  begin
    TypeChild := Decl.ChildAt(0);
    if (TypeChild <> nil) and (TypeChild.NodeKind = gnkArrayType) then
      Exit(TypeChild);
    if (TypeChild <> nil) and (TypeChild.Text = '') then
    begin
      for K := ADeclIndex + 1 to AVarSection.ChildCount - 1 do
      begin
        NextSibling := AVarSection.ChildAt(K);
        if (NextSibling <> nil) and (NextSibling.NodeKind <> gnkVarDecl) then
        begin
          if NextSibling.NodeKind = gnkArrayType then
            Exit(NextSibling);
          Break;
        end;
      end;
    end;
  end;
end;

procedure TSemanticAnalyzer.RegisterArrayVarMetadata(const AVarName: string;
  const AArrayTypeNode: TGreenNode; out AOperand: string);
var
  ElementNode: TGreenNode;
  LowBound, HighBound, ArrLength: Int64;
begin
  AOperand := AVarName;
  RegisterRuntimeArrVar(AVarName);

  ElementNode := ArrayElementTypeNode(AArrayTypeNode);
  if ElementNode <> nil then
  begin
    FModel.AddStringConstValue(AVarName + '$arr_elem_type',
      ElementNode.Text);
    if TypeMetaIsRecord(ElementNode.Text) then
      FModel.AddConstValue(AVarName + '$arr_elem_size',
        TypeMetaSize(ElementNode.Text));
  end;

  if TryGetArrayTypeBounds(AArrayTypeNode, LowBound, HighBound, ArrLength) then
  begin
    FModel.AddConstValue(AVarName + '$arr_static', 1);
    FModel.AddConstValue(AVarName + '$arr_low', LowBound);
    FModel.AddConstValue(AVarName + '$arr_high', HighBound);
    FModel.AddConstValue(AVarName + '$arr_len', ArrLength);
    AOperand := AVarName + #9 + 'static' + #9 + IntToStr(LowBound) +
      #9 + IntToStr(HighBound) + #9 + IntToStr(ArrLength);
  end;
end;

function TSemanticAnalyzer.EvaluateFloatConstant(const ANode: TGreenNode;
  out AValue: Double): Boolean;
var
  Parsed: Double;
  ParseCode: Word;
begin
  AValue := 0.0;
  if ANode = nil then
    Exit(False);
  case ANode.NodeKind of
    gnkRealLiteral:
      begin
        Val(ANode.Text, Parsed, ParseCode);
        if ParseCode <> 0 then
          Exit(False);
        AValue := Parsed;
        Exit(True);
      end;
    gnkIdentifier:
      begin
        { Check for known float constants like DEG_TO_RAD, RAD_TO_DEG }
        if SameText(ANode.Text, 'DEG_TO_RAD') then
        begin
          AValue := 0.01745329251994329577;
          Exit(True);
        end;
        if SameText(ANode.Text, 'RAD_TO_DEG') then
        begin
          AValue := 57.2957795130823208768;
          Exit(True);
        end;
        if SameText(ANode.Text, 'PI') then
        begin
          AValue := 3.14159265358979323846;
          Exit(True);
        end;
        Exit(False);
      end;
  else
    Exit(False);
  end;
end;

function TSemanticAnalyzer.EvaluateStringConstant(const ANode: TGreenNode;
  out AValue: string): Boolean;
var
  Op, Left, Right: string;
begin
  AValue := '';
  if ANode = nil then
    Exit(False);
  case ANode.NodeKind of
    gnkStringLiteral:
      begin
        AValue := DecodePascalStringLiteral(ANode.Text);
        Exit(True);
      end;
    gnkIdentifier:
      begin
        if FModel.LookupStringConstValue(ANode.Text, Left) then
        begin
          AValue := Left;
          Exit(True);
        end;
        Exit(False);
      end;
    gnkBinaryExpression:
      begin
        if ANode.ChildCount < 2 then
          Exit(False);
        Op := ANode.Text;
        if Op <> '+' then
          Exit(False);
        if not EvaluateStringConstant(ANode.ChildAt(0), Left) then
          Exit(False);
        if not EvaluateStringConstant(ANode.ChildAt(1), Right) then
          Exit(False);
        AValue := Left + Right;
        Exit(True);
      end;
  end;
  Result := False;
end;

function DecodePascalStringLiteral(const AText: string): string;
var
  Raw: string;
  Index: SizeInt;
begin
  Result := '';
  if Length(AText) < 2 then
    Exit;
  if (AText[1] <> '''') or (AText[Length(AText)] <> '''') then
    Exit;
  Raw := Copy(AText, 2, Length(AText) - 2);
  Index := 1;
  while Index <= Length(Raw) do
  begin
    if (Raw[Index] = '''') and (Index < Length(Raw)) and (Raw[Index + 1] = '''') then
    begin
      Result := Result + '''';
      Inc(Index, 2);
    end
    else
    begin
      Result := Result + Raw[Index];
      Inc(Index);
    end;
  end;
end;

{ === Codegen methods (extracted to np_sema_codegen.inc) === }
{$I np_sema_codegen.inc}

procedure TSemanticAnalyzer.SeedRuntimeVarDecls;
var
  RootNode: TGreenNode;
begin
  if not FNoFold then
    Exit;
  if (FRootAst = nil) or not FRootAst.IsValid then
    Exit;
  if (FRootAst.RootKindName <> 'program') and
    (FRootAst.RootKindName <> 'library') and
    (FRootAst.RootKindName <> 'package') then
    Exit;
  RootNode := FRootAst.RootNode;
  if RootNode = nil then
    Exit;
  WalkRuntimeVarDecls(RootNode);
end;

procedure TSemanticAnalyzer.SeedHaltCalls;
var
  RootNode: TGreenNode;
begin
  if (FRootAst = nil) or not FRootAst.IsValid then
    Exit;
  if (FRootAst.RootKindName <> 'program') and
    (FRootAst.RootKindName <> 'library') and
    (FRootAst.RootKindName <> 'package') then
    Exit;
  RootNode := FRootAst.RootNode;
  if RootNode = nil then
    Exit;
  WalkHaltCalls(RootNode);
  if FNoFold and not FCurrentBlockTerminated then
  begin
    EmitOwnedManagedRecordCleanupNodes;
    EmitOwnedDynArrayCleanupNodes;
    EmitOwnedStringCleanupNodes;
    FModel.AddTypedHirNode('halt-call-runtime', 'Halt', 0, 0, 'int 0' + #10);
    FCurrentBlockTerminated := True;
  end;
end;

procedure TSemanticAnalyzer.PreRegisterFunctionReturnTypes;
var
  I, J: LongInt;
  Entry: TProcedureBodyEntry;
  Child: TGreenNode;
  Folded: Int64;
begin
  for I := 0 to Length(FProcedureBodies) - 1 do
  begin
    Entry := FProcedureBodies[I];
    if (Entry.Decl = nil) or (Entry.Body = nil) then
      Continue;
    if Pos('<', Entry.Name) > 0 then
      Continue;
    for J := 0 to Entry.Decl.ChildCount - 1 do
    begin
      Child := Entry.Decl.ChildAt(J);
      if Child = nil then
        Continue;
      if (Child.NodeKind = gnkIdentifier) and
        (SameText(Child.Text, 'String') or
         SameText(Child.Text, 'AnsiString')) then
      begin
        RegisterRuntimeVar(Entry.Name);
        RegisterRuntimeStrVar(Entry.Name);
        Break;
      end;
      if (Child.NodeKind = gnkIdentifier) and
        (Child.NodeKind <> gnkBeginBlock) and
        (TypeMetaSize(Child.Text) > 0) and
        (Pos('.', Entry.Name) = 0) then
      begin
        if not TypeMetaIsRecord(Child.Text) then
          RegisterPtrReturnFunc(Entry.Name, Child.Text);
        Break;
      end;
    end;
  end;
end;

procedure TSemanticAnalyzer.SeedFunctionBodies;
var
  I, J, K: LongInt;
  Entry: TProcedureBodyEntry;
  ParamCount: LongInt;
  Child, ParamChild, TypeChild, Decl, ArrayTypeNode: TGreenNode;
  SavedTerminated: Boolean;
  ParamTypes, RetVarName, EffName, ArrOperand: string;
  IsStrParam, IsStrReturn, IsPtrReturn, IsVarP, IsRecReturn: Boolean;
  OwnedStringReturn: Boolean;
  PtrReturnClass: string;
  Folded, Value: Int64;
  WorkQueue: array of LongInt;
  NodeId, WorkCount, WorkHead: LongInt;
  Found: Boolean;
begin
  if Length(FGenericWorkQueue) < Length(FProcedureBodies) + 64 then
    SetLength(FGenericWorkQueue, Length(FProcedureBodies) + 64);
  WorkHead := 0;
  for I := 0 to Length(FProcedureBodies) - 1 do
  begin
    if (FProcedureBodies[I].Body = nil) then
      Continue;
    if Pos('<', FProcedureBodies[I].Name) > 0 then
      Continue;
    Found := False;
    for J := 0 to FGenericWorkCount - 1 do
      if FGenericWorkQueue[J] = I then begin Found := True; Break; end;
    if Found then Continue;
    if FGenericWorkCount >= Length(FGenericWorkQueue) then
      SetLength(FGenericWorkQueue, FGenericWorkCount + 64);
    FGenericWorkQueue[FGenericWorkCount] := I;
    Inc(FGenericWorkCount);
  end;

  while WorkHead < FGenericWorkCount do
  begin
    I := FGenericWorkQueue[WorkHead];
    Inc(WorkHead);
    if I < 0 then Continue;
    Entry := FProcedureBodies[I];
    if (Entry.Body = nil) or (Entry.Decl = nil) then
      Continue;
    if (Entry.Body = nil) or (Entry.Decl = nil) then
      Continue;
    FRuntimeVars.Reset;
    if HasOverload(Entry.Name) then
      EffName := MangledNameSig(Entry.Name, GetParamSignature(Entry.Decl))
    else
      EffName := Entry.Name;
    ParamCount := 0;
    ParamTypes := '';
    IsStrReturn := False;
    IsPtrReturn := False;
    IsRecReturn := False;
    OwnedStringReturn := False;
    PtrReturnClass := '';
    if Entry.Decl <> nil then
    begin
      for J := 0 to Entry.Decl.ChildCount - 1 do
      begin
        Child := Entry.Decl.ChildAt(J);
        if Child = nil then
          Continue;
        if Child.NodeKind = gnkParameterList then
        begin
          for K := 0 to Child.ChildCount - 1 do
          begin
            ParamChild := Child.ChildAt(K);
            if (ParamChild <> nil) and (ParamChild.NodeKind = gnkParameterDecl) then
            begin
              ParamTypes := ParamTypes;
              RetVarName := ParamChild.Text;
              IsVarP := ParamNameIsByRef(RetVarName);
              if IsVarP then
                RetVarName := StripParamModifier(RetVarName);
              RegisterRuntimeVar(RetVarName);
              if IsVarP then
                RegisterVarParam(RetVarName);
              IsStrParam := False;
              if ParamChild.ChildCount > 0 then
              begin
                TypeChild := ParamChild.ChildAt(0);
                if (TypeChild <> nil) and
                  (SameText(TypeChild.Text, 'String') or
                   SameText(TypeChild.Text, 'AnsiString')) then
                begin
                  IsStrParam := True;
                  RegisterRuntimeStrVar(RetVarName);
                  RegisterBorrowedRuntimeStrVar(RetVarName);
                end
                else if (TypeChild <> nil) and
                  ((TypeChild.NodeKind = gnkArrayType) or
                   ((TypeChild.Text = '') and (K + 1 < Child.ChildCount) and
                    (Child.ChildAt(K + 1) <> nil) and
                    (Child.ChildAt(K + 1).NodeKind = gnkArrayType))) then
                begin
                  RegisterRuntimeArrVar(RetVarName);
                  RegisterBorrowedRuntimeArrVar(RetVarName);
                end
                else if (TypeChild <> nil) and
                  (Length(TypeChild.Text) > 1) and (TypeChild.Text[1] = '^') then
                begin
                  RegisterClassVar(RetVarName, 'Pointer');
                  RegisterPointerVar(RetVarName, Copy(TypeChild.Text, 2,
                    Length(TypeChild.Text)));
                end
                else if (TypeChild <> nil) and
                  (TypeMetaSize(TypeChild.Text) > 0) then
                begin
                  if TypeMetaIsRecord(TypeChild.Text) then
                    RegisterRecordVar(RetVarName, TypeChild.Text)
                  else
                    RegisterClassVar(RetVarName, TypeChild.Text);
                end;
              end;
              if IsStrParam then
                ParamTypes := ParamTypes + 's'
              else if IsRuntimeArrVar(RetVarName) then
                ParamTypes := ParamTypes + 'a'
              else if (ParamChild.ChildCount > 0) and
                (ParamChild.ChildAt(0) <> nil) and
                (Length(ParamChild.ChildAt(0).Text) > 1) and
                (ParamChild.ChildAt(0).Text[1] = '^') then
                ParamTypes := ParamTypes + 'p'
              else if (ParamChild.ChildCount > 0) and
                (ParamChild.ChildAt(0) <> nil) and
                (TypeMetaSize(ParamChild.ChildAt(0).Text) > 0) then
              begin
                if TypeMetaIsRecord(ParamChild.ChildAt(0).Text) then
                  ParamTypes := ParamTypes + 'r'
                else if IsVarP then
                  ParamTypes := ParamTypes + 'v'
                else
                  ParamTypes := ParamTypes + 'p';
              end
              else if IsVarP then
                ParamTypes := ParamTypes + 'v'
              else
                ParamTypes := ParamTypes + 'i';
              Inc(ParamCount);
            end;
          end;
        end
        else if (Child.NodeKind = gnkIdentifier) and
          (Child.NodeKind <> gnkBeginBlock) and
          (SameText(Child.Text, 'String') or
           SameText(Child.Text, 'AnsiString')) then
          IsStrReturn := True
        else if (Child.NodeKind = gnkIdentifier) and
          (Child.NodeKind <> gnkBeginBlock) and
          TypeMetaIsClass(Child.Text) then
        begin
          IsPtrReturn := True;
          PtrReturnClass := Child.Text;
        end
        else if (Child.NodeKind = gnkIdentifier) and
          (Child.NodeKind <> gnkBeginBlock) and
          TypeMetaIsRecord(Child.Text) then
        begin
          IsRecReturn := True;
          PtrReturnClass := Child.Text;
        end;
      end;
    end;
    if IsPtrReturn and (Pos('.', Entry.Name) = 0) then
      RegisterPtrReturnFunc(Entry.Name, PtrReturnClass);
    OwnedStringReturn := IsRootOwnedStringReturnCandidate(Entry, IsStrReturn) and
      IsOwnedStringReturnFunc(EffName);
    if Pos('.', Entry.Name) > 0 then
    begin
      FCurrentMethodClass := Copy(Entry.Name, 1, Pos('.', Entry.Name) - 1);
      if IsStrReturn then
        FModel.AddTypedHirNode('method-body-begin', Entry.Name, 0, 0,
          IntToStr(ParamCount + 1) + ':p' + ParamTypes + ':s')
      else if IsPtrReturn then
        FModel.AddTypedHirNode('method-body-begin', Entry.Name, 0, 0,
          IntToStr(ParamCount + 1) + ':p' + ParamTypes + ':p')
      else
        FModel.AddTypedHirNode('method-body-begin', Entry.Name, 0, 0,
          IntToStr(ParamCount + 1) + ':p' + ParamTypes);
      RegisterRuntimeVar('self');
    end
    else if IsStrReturn and OwnedStringReturn then
      FModel.AddTypedHirNode('function-body-begin', EffName, 0, 0,
        IntToStr(ParamCount) + ':' + ParamTypes + ':so')
    else if IsStrReturn then
      FModel.AddTypedHirNode('function-body-begin', EffName, 0, 0,
        IntToStr(ParamCount) + ':' + ParamTypes + ':s')
    else if IsPtrReturn then
      FModel.AddTypedHirNode('function-body-begin', EffName, 0, 0,
        IntToStr(ParamCount) + ':' + ParamTypes + ':p')
    else if IsRecReturn then
    begin
      Folded := TypeMetaSize(PtrReturnClass);
      if Folded > 0 then
        FModel.AddTypedHirNode('function-body-begin', EffName, 0, 0,
          IntToStr(ParamCount) + ':' + ParamTypes + ':r' + IntToStr(Folded div 8))
      else
        FModel.AddTypedHirNode('function-body-begin', EffName, 0, 0,
          IntToStr(ParamCount) + ':' + ParamTypes);
    end
    else
      FModel.AddTypedHirNode('function-body-begin', EffName, 0, 0,
        IntToStr(ParamCount) + ':' + ParamTypes);
    if Entry.Decl <> nil then
    begin
      for J := 0 to Entry.Decl.ChildCount - 1 do
      begin
        Child := Entry.Decl.ChildAt(J);
        if (Child <> nil) and (Child.NodeKind = gnkParameterList) then
        begin
          for K := 0 to Child.ChildCount - 1 do
          begin
            ParamChild := Child.ChildAt(K);
            if (ParamChild <> nil) and (ParamChild.NodeKind = gnkParameterDecl) then
            begin
              RetVarName := ParamChild.Text;
              if ParamNameIsByRef(RetVarName) then
                RetVarName := StripParamModifier(RetVarName);
              if IsRuntimeStrVar(RetVarName) then
                FModel.AddTypedHirNode('var-decl-tstring-runtime', RetVarName,
                  0, 0, RetVarName)
              else if IsRuntimeArrVar(RetVarName) then
              begin
                if IsBorrowedRuntimeArrVar(RetVarName) then
                  FModel.AddTypedHirNode('var-decl-arr-borrowed-runtime',
                    RetVarName, 0, 0, RetVarName)
                else
                  FModel.AddTypedHirNode('var-decl-arr-runtime', RetVarName,
                    0, 0, RetVarName);
              end
              else if IsRecordVar(RetVarName) then
                FModel.AddTypedHirNode('var-decl-ptr-runtime', RetVarName,
                  0, 0, RetVarName)
              else if IsVarParam(RetVarName) then
                FModel.AddTypedHirNode('var-decl-varref-runtime', RetVarName,
                  0, 0, RetVarName)
              else
                FModel.AddTypedHirNode('var-decl-runtime', RetVarName,
                  0, 0, ParamChild.Text);
            end;
          end;
          Break;
        end;
      end;
    end;
    if Pos('.', Entry.Name) > 0 then
      RetVarName := Copy(Entry.Name, Pos('.', Entry.Name) + 1, Length(Entry.Name))
    else
      RetVarName := Entry.Name;
    RegisterRuntimeVar(RetVarName);
    if (Entry.Decl <> nil) and (Entry.Decl.NodeKind = gnkFunctionDecl) then
      FCurrentRetVarName := RetVarName
    else if Pos('.', Entry.Name) > 0 then
      FCurrentRetVarName := RetVarName
    else
      FCurrentRetVarName := '';
    FCurrentOwnedStringReturn := OwnedStringReturn;
    if IsStrReturn then
    begin
      RegisterRuntimeStrVar(RetVarName);
      if OwnedStringReturn then
        RegisterOwnedRuntimeStrVar(RetVarName);
    end;
    if IsRecReturn then
      RegisterRecordVar(RetVarName, PtrReturnClass);
    if IsStrReturn and OwnedStringReturn then
      FModel.AddTypedHirNode('var-decl-tstring-runtime', RetVarName, 0, 0,
        RetVarName)
    else if IsStrReturn then
      FModel.AddTypedHirNode('var-decl-tstring-runtime', RetVarName, 0, 0, RetVarName)
    else if IsPtrReturn then
      FModel.AddTypedHirNode('var-decl-ptr-runtime', RetVarName, 0, 0, RetVarName)
    else if IsRecReturn then
      FModel.AddTypedHirNode('var-decl-ptr-runtime', RetVarName, 0, 0, RetVarName)
    else
      FModel.AddTypedHirNode('var-decl-runtime', RetVarName, 0, 0, RetVarName);
    if Entry.Decl <> nil then
      for J := 0 to Entry.Decl.ChildCount - 1 do
      begin
        Child := Entry.Decl.ChildAt(J);
        if (Child <> nil) and (Child.NodeKind = gnkVarSection) then
        begin
          for K := 0 to Child.ChildCount - 1 do
          begin
            Decl := Child.ChildAt(K);
            if (Decl = nil) or (Decl.NodeKind <> gnkVarDecl) or
              (Decl.Text = '') then
              Continue;
            RegisterRuntimeVar(Decl.Text);
            ArrayTypeNode := FindArrayTypeNodeForVarDecl(Child, K);
            if ArrayTypeNode <> nil then
            begin
              RegisterArrayVarMetadata(Decl.Text, ArrayTypeNode, ArrOperand);
              FModel.AddTypedHirNode(
                'var-decl-arr-runtime', Decl.Text, 0, 0, ArrOperand);
            end
            else if (Decl.ChildCount > 0) and (Decl.ChildAt(0) <> nil) and
              (TypeMetaSize(Decl.ChildAt(0).Text) > 0) and
              (not TypeMetaIsRecord(Decl.ChildAt(0).Text)) then
            begin
              RegisterClassVar(Decl.Text, Decl.ChildAt(0).Text);
              FModel.AddTypedHirNode(
                'var-decl-ptr-runtime', Decl.Text, 0, 0, Decl.Text);
            end
            else if (Decl.ChildCount > 0) and (Decl.ChildAt(0) <> nil) and
              (SameText(Decl.ChildAt(0).Text, 'String') or
               SameText(Decl.ChildAt(0).Text, 'AnsiString')) then
            begin
              RegisterRuntimeStrVar(Decl.Text);
              RegisterOwnedRuntimeStrVar(Decl.Text);
              FModel.AddTypedHirNode(
                'var-decl-tstring-runtime', Decl.Text, 0, 0, Decl.Text);
            end
            else if (Decl.ChildCount > 0) and (Decl.ChildAt(0) <> nil) and
              (Length(Decl.ChildAt(0).Text) > 1) and
              (Decl.ChildAt(0).Text[1] = '^') then
            begin
              RegisterPointerVar(Decl.Text, Copy(Decl.ChildAt(0).Text, 2,
                Length(Decl.ChildAt(0).Text)));
              FModel.AddTypedHirNode(
                'var-decl-ptr-runtime', Decl.Text, 0, 0, Decl.Text);
            end
            else
              FModel.AddTypedHirNode(
                'var-decl-runtime', Decl.Text, 0, 0, Decl.Text);
          end;
        end;
      end;
    SavedTerminated := FCurrentBlockTerminated;
    FCurrentBlockTerminated := False;
    WalkHaltCalls(Entry.Body);
    if not FCurrentBlockTerminated then
    begin
      EmitOwnedManagedRecordCleanupNodes;
      EmitOwnedDynArrayCleanupNodes;
      EmitOwnedStringCleanupNodes(RetVarName);
      if IsStrReturn and OwnedStringReturn then
        FModel.AddTypedHirNode('ret-tstring-runtime', RetVarName, 0, 0,
          RetVarName)
      else if IsStrReturn then
        FModel.AddTypedHirNode('ret-tstring-runtime', RetVarName, 0, 0, RetVarName)
      else
      begin
        NodeId := FModel.AddTypedHirNode('ret-runtime', RetVarName, 0, 0,
          'var ' + RetVarName + #10);
        AttachRuntimeReturnExpr(NodeId, RetVarName);
      end;
    end;
    FModel.AddTypedHirNode('function-body-end', EffName, 0, 0, '');
    FCurrentBlockTerminated := SavedTerminated;
    FCurrentMethodClass := '';
    FCurrentRetVarName := '';
    FCurrentOwnedStringReturn := False;
  end;
end;

procedure TSemanticAnalyzer.SeedUnitLifecycleBodies;
var
  I: LongInt;
  Node: TTypedHirNode;
  SavedRetVarName: string;
  SavedOwnedReturn: Boolean;
  SavedBlockTerminated: Boolean;
  SavedMethodClass: string;
  LNormalizedUnitName: string;
  LFuncName: string;
begin
  for I := 0 to FModel.TypedHirNodeCount - 1 do
  begin
    Node := FModel.TypedHirNodeAt(I);
    if (Node.NodeKind <> hnkUnitInitRuntime) and
       (Node.NodeKind <> hnkUnitFiniRuntime) then
      Continue;
    if GreenNodeIsNil(Node.GreenNodeRef) then
      Continue;

    // Save current state
    SavedRetVarName := FCurrentRetVarName;
    SavedOwnedReturn := FCurrentOwnedStringReturn;
    SavedBlockTerminated := FCurrentBlockTerminated;
    SavedMethodClass := FCurrentMethodClass;

    // Reset for void function with no params — 全部 13 个 tracker 清零
    FRuntimeVars.Reset;
    FCurrentRetVarName := '';
    FCurrentOwnedStringReturn := False;
    FCurrentBlockTerminated := False;
    FCurrentMethodClass := '';

    // Normalize unit name: replace dots with underscores for LLVM function names
    LNormalizedUnitName := StringReplace(Node.Operand, '.', '_', True);

    if Node.NodeKind = hnkUnitInitRuntime then
    begin
      LFuncName := 'np_unit_init_' + LNormalizedUnitName;
      FModel.AddTypedHirNode('function-body-begin',
        LFuncName, 0, 0, '0:');
      WalkHaltCalls(Node.GreenNodeRef);
      if not FCurrentBlockTerminated then
      begin
        EmitOwnedManagedRecordCleanupNodes;
        EmitOwnedDynArrayCleanupNodes;
        EmitOwnedStringCleanupNodes('');
        FModel.AddTypedHirNode('ret-runtime', '0', 0, 0, 'int 0' + #10);
      end;
      FModel.AddTypedHirNode('function-body-end',
        LFuncName, 0, 0, '');
    end
    else
    begin
      LFuncName := 'np_unit_fini_' + LNormalizedUnitName;
      FModel.AddTypedHirNode('function-body-begin',
        LFuncName, 0, 0, '0:');
      WalkHaltCalls(Node.GreenNodeRef);
      if not FCurrentBlockTerminated then
      begin
        EmitOwnedManagedRecordCleanupNodes;
        EmitOwnedDynArrayCleanupNodes;
        EmitOwnedStringCleanupNodes('');
        FModel.AddTypedHirNode('ret-runtime', '0', 0, 0, 'int 0' + #10);
      end;
      FModel.AddTypedHirNode('function-body-end',
        LFuncName, 0, 0, '');
    end;

    // Restore state
    FCurrentRetVarName := SavedRetVarName;
    FCurrentOwnedStringReturn := SavedOwnedReturn;
    FCurrentBlockTerminated := SavedBlockTerminated;
    FCurrentMethodClass := SavedMethodClass;
  end;
end;

procedure TSemanticAnalyzer.SeedImportedUnitBodies;

  procedure SeedImportedCallableSymbol(
    const ANode: TGreenNode;
    const AOwnerUnitId: string;
    const AUnitScopeId: LongInt
  );
  var
    Child: TGreenNode;
    ChildIndex: LongInt;
    KindName: string;
    ParamCount: LongInt;
    ParamSignature: string;
    ScopeId: LongInt;
    Symbol: TSemanticSymbol;
    SymbolId: LongInt;
    SymbolIndex: LongInt;
    TypeId: LongInt;
  begin
    if (ANode = nil) or (Trim(AOwnerUnitId) = '') or
      (Trim(ANode.Text) = '') or (Pos('.', ANode.Text) > 0) then
      Exit;

    if ANode.NodeKind = gnkFunctionDecl then
      KindName := 'function'
    else if ANode.NodeKind = gnkProcedureDecl then
      KindName := 'procedure'
    else
      Exit;

    ParamCount := CountDeclParams(ANode);
    ParamSignature := GetParamSignature(ANode);
    for SymbolIndex := 0 to FModel.SymbolCount - 1 do
    begin
      Symbol := FModel.SymbolAt(SymbolIndex);
      if SameText(Symbol.OwnerUnitId, AOwnerUnitId) and
        SameText(Symbol.Name, ANode.Text) and
        SameText(Symbol.Kind, KindName) and
        (Symbol.ByteOffset = ANode.ByteOffset) then
        Exit;
    end;

    TypeId := 0;
    if ANode.NodeKind = gnkFunctionDecl then
      for ChildIndex := 0 to ANode.ChildCount - 1 do
      begin
        Child := ANode.ChildAt(ChildIndex);
        if (Child <> nil) and (Child.NodeKind = gnkIdentifier) then
        begin
          TypeId := ResolveTypeIdForOwner(Child.Text, AOwnerUnitId);
          Break;
        end;
      end;

    SymbolId := FModel.AddSymbol(
      ANode.Text,
      KindName,
      AOwnerUnitId,
      TypeId,
      ANode.ByteOffset
    );
    FModel.SetSymbolParamCount(SymbolId, ParamCount);
    FModel.SetSymbolMinParamCount(SymbolId, CountRequiredDeclParams(ANode));
    FModel.SetSymbolParamSignature(SymbolId, ParamSignature);

    if AUnitScopeId > 0 then
      ScopeId := AUnitScopeId
    else
      ScopeId := EnsureUnitScope(AOwnerUnitId);
    if ScopeId > 0 then
      FModel.SetSymbolScope(SymbolId, ScopeId);
  end;

  procedure RegisterBodiesInNode(
    const ANode: TGreenNode;
    const AOwnerUnitId: string
  );
  var
    ChildIdx, BodyIdx: LongInt;
    Child, BodyChild: TGreenNode;
    SavedScopeId: LongInt;
    UnitScopeId: LongInt;
  begin
    if ANode = nil then
      Exit;
    for ChildIdx := 0 to ANode.ChildCount - 1 do
    begin
      Child := ANode.ChildAt(ChildIdx);
      if Child = nil then
        Continue;
      if Child.NodeKind = gnkTypeSection then
      begin
        UnitScopeId := EnsureUnitScope(AOwnerUnitId);
        SavedScopeId := FCurrentScopeId;
        if UnitScopeId > 0 then
          FCurrentScopeId := UnitScopeId;
        try
          ProcessTypeSection(Child, AOwnerUnitId);
        finally
          FCurrentScopeId := SavedScopeId;
        end;
      end
      else if Child.NodeKind = gnkConstSection then
      begin
        UnitScopeId := EnsureUnitScope(AOwnerUnitId);
        SavedScopeId := FCurrentScopeId;
        if UnitScopeId > 0 then
          FCurrentScopeId := UnitScopeId;
        try
          ProcessConstSection(Child, AOwnerUnitId);
        finally
          FCurrentScopeId := SavedScopeId;
        end;
      end
      else if (Child.NodeKind = gnkProcedureDecl) or
        (Child.NodeKind = gnkFunctionDecl) then
      begin
        UnitScopeId := EnsureUnitScope(AOwnerUnitId);
        SavedScopeId := FCurrentScopeId;
        if UnitScopeId > 0 then
          FCurrentScopeId := UnitScopeId;
        try
          SeedImportedCallableSymbol(Child, AOwnerUnitId, UnitScopeId);
          BodyChild := nil;
          for BodyIdx := 0 to Child.ChildCount - 1 do
            if (Child.ChildAt(BodyIdx) <> nil) and
              ((Child.ChildAt(BodyIdx).NodeKind = gnkBeginBlock) or
               (Child.ChildAt(BodyIdx).NodeKind = gnkAsmBlock)) then
            begin
              BodyChild := Child.ChildAt(BodyIdx);
              Break;
            end;
          RegisterProcedureBody(Child.Text, BodyChild, Child, AOwnerUnitId);
        finally
          FCurrentScopeId := SavedScopeId;
        end;
      end
      else if Child.NodeKind = gnkInterfaceSection then
        RegisterBodiesInNode(Child, AOwnerUnitId);
      { gnkImplementationSection 跳过: 实现段声明对外部单元不可见 }
    end;
  end;

var
  OwnerUnitId: string;
  Index: LongInt;
  ResolvedUnit: TResolvedUnit;
  SourceText, Line: string;
  UnitLexer: TLexerResult;
  UnitTree: TGreenTree;
  F: Text;
  SourcePath: string;
  TmpDiag: TDiagnosticsSink;
  PP: TPreprocessor;
  PPDefines: TDefineTable;
  IncResolver: TFileIncludeResolver;
  CacheIdx: LongInt;
  DiskUnit: TDiskCachedUnit;
  Fingerprint: UInt32;
  DiskHit: Boolean;
  ResolvedTypeId: LongInt;
  Age: Int64;
  SymBefore, SymAfter, J, NextCache: LongInt;
  Sym: TSemanticSymbol;
begin
  if FUnitGraph = nil then
    Exit;
  if GDiskCache = nil then
    GDiskCache := TDiskSymbolCache.Create('.nextpas/cache');
  TmpDiag := TDiagnosticsSink.Create;
  try
    for Index := FUnitGraph.ResolvedUnitCount - 1 downto 0 do
    begin
      ResolvedUnit := FUnitGraph.ResolvedUnitAt(Index);
      if SameText(ResolvedUnit.CanonicalName, FUnitGraph.RootName) then
        Continue;
      SourcePath := ResolvedUnit.SourcePath;
      if Trim(SourcePath) = '' then
        Continue;
      if not FsExists(SourcePath) then
        Continue;

      OwnerUnitId := ResolvedUnit.UnitId;
      if OwnerUnitId = '' then
        OwnerUnitId := NormalizeUnitIdentity(ResolvedUnit.CanonicalName);

      Age := FsStat(SourcePath).ModTime;
      CacheIdx := -1;
      if SameText(ResolvedUnit.OriginClass, 'installed-source') then
        CacheIdx := FindCachedUnit(SourcePath, Age);
      if CacheIdx >= 0 then
      begin
        for J := 0 to GImportedUnitCache[CacheIdx].SymbolCount - 1 do
          with GImportedUnitCache[CacheIdx].Symbols[J] do
          begin
            { Skip cached type symbols if a type with this name already
              exists in the model (e.g. seeded in SeedBuiltinTypes). }
            if SameText(Kind, 'type') and
              (FModel.FindTypeByName(Name) > 0) then
              Continue;
            FModel.AddSymbol(Name, Kind, OwnerUnitId, TypeId, ByteOffset);
            FModel.SetSymbolParamCount(FModel.SymbolCount, ParamCount);
            FModel.SetSymbolMinParamCount(FModel.SymbolCount, MinParamCount);
            FModel.SetSymbolParamSignature(FModel.SymbolCount, ParamSignature);
            FModel.SetSymbolScope(FModel.SymbolCount, EnsureUnitScope(OwnerUnitId));
          end;
        Continue;
      end;

      { In-memory cache miss — try persistent disk cache }
      Fingerprint := ComputeSourceFingerprintFromFile(SourcePath);
      DiskHit := GDiskCache.TryLoad(OwnerUnitId, Fingerprint, DiskUnit);
      if DiskHit then
      begin
        SymBefore := FModel.SymbolCount;
        for J := 0 to DiskUnit.SymbolCount - 1 do
        begin
          if SameText(DiskUnit.Symbols[J].Kind, 'type') and
            (FModel.FindTypeByName(DiskUnit.Symbols[J].Name) > 0) then
            Continue;
          ResolvedTypeId := 0;
          if DiskUnit.Symbols[J].TypeRefName <> '' then
            ResolvedTypeId := ResolveTypeIdForOwner(
              DiskUnit.Symbols[J].TypeRefName, OwnerUnitId);
          FModel.AddSymbol(
            DiskUnit.Symbols[J].Name,
            DiskUnit.Symbols[J].Kind,
            OwnerUnitId,
            ResolvedTypeId,
            DiskUnit.Symbols[J].ByteOffset
          );
          FModel.SetSymbolParamCount(FModel.SymbolCount,
            DiskUnit.Symbols[J].ParamCount);
          FModel.SetSymbolMinParamCount(FModel.SymbolCount,
            DiskUnit.Symbols[J].MinParamCount);
          FModel.SetSymbolParamSignature(FModel.SymbolCount,
            DiskUnit.Symbols[J].ParamSignature);
          FModel.SetSymbolScope(FModel.SymbolCount, EnsureUnitScope(OwnerUnitId));
        end;
        SymAfter := FModel.SymbolCount;
        { Promote disk cache entry to in-memory cache }
        if SymAfter > SymBefore then
        begin
          if GImportedUnitCacheCount >= Length(GImportedUnitCache) then
            SetLength(GImportedUnitCache, GImportedUnitCacheCount + 16);
          NextCache := GImportedUnitCacheCount;
          Inc(GImportedUnitCacheCount);
          GImportedUnitCache[NextCache].SourcePath := SourcePath;
          GImportedUnitCache[NextCache].FileAge := Age;
          GImportedUnitCache[NextCache].SymbolCount := SymAfter - SymBefore;
          SetLength(GImportedUnitCache[NextCache].Symbols, SymAfter - SymBefore);
          for J := SymBefore to SymAfter - 1 do
          begin
            Sym := FModel.SymbolAt(J);
            with GImportedUnitCache[NextCache].Symbols[J - SymBefore] do
            begin
              Name := Sym.Name;
              Kind := Sym.Kind;
              OwnerUnitId := Sym.OwnerUnitId;
              ParamCount := Sym.ParamCount;
              MinParamCount := Sym.MinParamCount;
              ParamSignature := Sym.ParamSignature;
              TypeId := Sym.TypeId;
              TypeRefName := '';
              ByteOffset := Sym.ByteOffset;
            end;
          end;
        end;
        Continue;
      end;

      Assign(F, SourcePath);
      {$I-}
      Reset(F);
      {$I+}
      if IOResult <> 0 then
        Continue;
      SourceText := '';
      while not Eof(F) do
      begin
        ReadLn(F, Line);
        if SourceText <> '' then
          SourceText := SourceText + #10;
        SourceText := SourceText + Line;
      end;
      Close(F);
      UnitLexer := TLexerResult.Create(SourceText);
      PPDefines := TDefineTable.Create;
      PPDefines.SeedFPCDefines;
      IncResolver := TFileIncludeResolver.Create(ExtractFileDir(SourcePath));
      IncResolver.AddSearchPath(ExtractFileDir(SourcePath));
      IncResolver.AddSearchPath(
        ExtractFileDir(ExtractFileDir(SourcePath)) + DirectorySeparator + 'objpas');
      IncResolver.AddSearchPath(
        ExtractFileDir(ExtractFileDir(SourcePath)) + DirectorySeparator + 'objpas' +
        DirectorySeparator + 'sysutils');
      IncResolver.AddSearchPath(
        ExtractFileDir(ExtractFileDir(SourcePath)) + DirectorySeparator + 'inc');
      PP := TPreprocessor.Create(PPDefines, True, IncResolver);
      try
        PP.Process(UnitLexer);
        UnitLexer.Free;
        UnitLexer := PP.ToLexerResult;
      finally
        PP.Free;
      end;

      SymBefore := FModel.SymbolCount;
      UnitTree := ParseGreenTree(UnitLexer, TmpDiag, 0);
      if (UnitTree <> nil) and (UnitTree.RootNode <> nil) then
      begin
        RegisterImportedUnitTree(UnitTree, OwnerUnitId);
        RegisterBodiesInNode(UnitTree.RootNode, OwnerUnitId);
      end
      else if UnitTree <> nil then
        UnitTree.Free;
      UnitLexer.Free;
      SymAfter := FModel.SymbolCount;

      if (SymAfter > SymBefore) and
        SameText(ResolvedUnit.OriginClass, 'installed-source') then
      begin
        if GImportedUnitCacheCount >= Length(GImportedUnitCache) then
          SetLength(GImportedUnitCache, GImportedUnitCacheCount + 16);
        NextCache := GImportedUnitCacheCount;
        Inc(GImportedUnitCacheCount);
        GImportedUnitCache[NextCache].SourcePath := SourcePath;
        GImportedUnitCache[NextCache].FileAge := Age;
        GImportedUnitCache[NextCache].SymbolCount := SymAfter - SymBefore;
        SetLength(GImportedUnitCache[NextCache].Symbols, SymAfter - SymBefore);
        { Also build disk cache entry }
        DiskUnit.UnitId := OwnerUnitId;
        DiskUnit.SourcePath := SourcePath;
        DiskUnit.Fingerprint := ComputeSourceFingerprintFromFile(SourcePath);
        DiskUnit.SymbolCount := SymAfter - SymBefore;
        SetLength(DiskUnit.Symbols, SymAfter - SymBefore);
        for J := SymBefore to SymAfter - 1 do
        begin
          Sym := FModel.SymbolAt(J);
          with GImportedUnitCache[NextCache].Symbols[J - SymBefore] do
          begin
            Name := Sym.Name;
            Kind := Sym.Kind;
            OwnerUnitId := Sym.OwnerUnitId;
            ParamCount := Sym.ParamCount;
            MinParamCount := Sym.MinParamCount;
            ParamSignature := Sym.ParamSignature;
            TypeId := Sym.TypeId;
            if Sym.TypeId > 0 then
              TypeRefName := FModel.TypeAt(Sym.TypeId - 1).Name
            else
              TypeRefName := '';
            ByteOffset := Sym.ByteOffset;
          end;
          DiskUnit.Symbols[J - SymBefore].Name := Sym.Name;
          DiskUnit.Symbols[J - SymBefore].Kind := Sym.Kind;
          DiskUnit.Symbols[J - SymBefore].OwnerUnitId := OwnerUnitId;
          DiskUnit.Symbols[J - SymBefore].ParamCount := Sym.ParamCount;
          DiskUnit.Symbols[J - SymBefore].MinParamCount := Sym.MinParamCount;
          DiskUnit.Symbols[J - SymBefore].ParamSignature := Sym.ParamSignature;
          if Sym.TypeId > 0 then
            DiskUnit.Symbols[J - SymBefore].TypeRefName := FModel.TypeAt(Sym.TypeId - 1).Name
          else
            DiskUnit.Symbols[J - SymBefore].TypeRefName := '';
          DiskUnit.Symbols[J - SymBefore].ByteOffset := Sym.ByteOffset;
        end;
        GDiskCache.Save(DiskUnit);
      end;
    end;
  finally
    TmpDiag.Free;
  end;
end;

end.
