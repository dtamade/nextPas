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
    procedure EmitClassVarFreeCleanupNodes;
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
    { 核心实现：同时产出 Blob 和 ExprId，避免从 Blob 解析 ExprId }
    function EncodeRuntimeIntExprFoldCore(const ANode: TGreenNode;
      out ABlob: string; out AExprId: LongInt): Boolean;
    function EncodeRuntimeIntExprFold(const ANode: TGreenNode;
      out ABlob: string): Boolean;
    { 带 ExprId 输出的重载：结构化表达式时返回 ExprId > 0 }
    function EncodeRuntimeIntExprFold(const ANode: TGreenNode;
      out ABlob: string; out AExprId: LongInt): Boolean;
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
  nextpas.core.system.contracts, np_symbol_cache, np_diagnostics_enhanced;

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

{$I np_sema_string_ownership_helpers.inc}
{$I np_sema_param_handling.inc}
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

{$I np_sema_overload_analysis.inc}
{$I np_sema_type_metadata.inc}
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
{$I np_sema_call_binding.inc}
{$I np_sema_seed_call_bindings.inc}
{$I np_sema_seeding.inc}
{$I np_sema_seed_imported_unit_bodies.inc}
