type
  TStringVec = specialize TVec<string>;
  TLongIntVec = specialize TVec<LongInt>;

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
    { Nested product tables owned by pending-signature entry (scratch/default heap). }
    ParamNames: TStringVec;
    ArgTypes: TStringVec;
  end;
  PPendingSignatureEntry = ^TPendingSignatureEntry;
  TPendingSignatureVec = specialize TVec<TPendingSignatureEntry>;

  TSemanticAnalyzer = class
  private
    FRootAst: TAstFacade;
    FUnitGraph: TUnitGraph;
    FDiagnostics: TDiagnosticsSink;
    FRootFileId: TSourceFileId;
    FNoFold: Boolean;
    { True while SeedFunctionBodies fixed-point is running (mid-seed register). }
    FSeedingBodiesActive: Boolean;
    { Optional scratch IAllocator for working TVecs / imported unit trees. }
    FAllocator: IAllocator;
    FModel: TSemanticModel;
    { Procedure body table on FAllocator when present; contexts borrow. }
    FProcedureBodies: TProcedureBodyVec;
    { Case-insensitive name → first FProcedureBodies index; same-name overloads
      chained via FProcedureBodyNameNext (parallel to bodies). Types match
      TSemaOverloadContext.BodyName* so LookupCallBinding can use O(overloads). }
    FProcedureBodyNameFirst: TProcedureBodyNameFirstMap;
    FProcedureBodyNameNext: TProcedureBodyNameNextVec;
    { Reusable ASCII-fold buffer for body-name lookups. Owned by this
      instance and never aliased out (map Put stores key aliases, so only
      read-only TryGetValue may receive it); unique-buffer SetLength does
      no heap work once warmed. }
    FBodyLookupScratch: string;
    { Scratch work tables on FAllocator when present. }
    FCompilerProcNames: TStringVec;
    FGenericWorkQueue: TLongIntVec;
    FGenericRetrySpecs: TStringVec;
    FGenericCache: TGenericCacheVec;
    FPendingSignatures: TPendingSignatureVec;
    { Instance name of the generic being instantiated while its cloned method
      bodies are encoded; lets TypeMetaSize resolve template type params (T)
      through InstanceName.$generic_arg_<Param> consts. Empty outside
      InstantiateGenericType-driven encoding. }
    FCurrentGenericInstance: string;
    FInliningStack: TStringVec;
    { except-handler 变量名 (on E: C do …)，由 LowerRuntimeTryExceptStatement
      注册；EncodeCallStatementArgs 据此把 E.Message 编码为 tstring 字段
      加载而非残余 `var E.Message` 整数槽 (支配性违规挂账根因)。 }
    FExceptionHandlerVars: TStringVec;
    { EncodeExceptionMemberStrTemp 命中时置位：该调用的参数含异常成员
      tstring 临时物化，必须走 operand-blob 路径，跳过结构化 ExprId
      附加（否则 E.Message 被降成 @Cls.Member 属性 getter 残余调用）。 }
    FLastCallArgsUsedExcMember: Boolean;
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
    { SeedCallBindingsInNode visit counter (progress heartbeat only). }
    FSeedCallVisitCount: LongInt;
    { Imported unit trees/owners on FAllocator when present; contexts borrow. }
    FImportedUnitTrees: TSemaImportedTreeVec;
    FImportedUnitOwners: TSemaImportedOwnerVec;
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
    function EmitPlainStringConcatWriteTemp(
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
    function EncodePosConcatOperand(const ANode: TGreenNode): string;
    function EncodeCallStatementArgs(
      const ACallName: string; const ACallNode, ADeclNode: TGreenNode): string;
    function TryPointerFieldAccess(const ALocalNode: TGreenNode;
      out APointerName, APointeeTypeName, AFieldName: string;
      out AFieldIndex: Int64): Boolean;
    function TryByRefFieldAddressBlob(const ALocalNode: TGreenNode;
      out ABlob: string): Boolean;
    function IsExceptionHandlerVar(const AName: string): Boolean;
    function EncodeExceptionMemberStrTemp(const ABaseName,
      AMemberName: string; out ATempName: string): Boolean;
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
    // === overload resolution group (→ nextpas.compiler.sema.overload.pas) ===
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
    { Define-side EffName for call/sret sites: bare when unique, else
      MangledNameSig(Name, GetParamSignature(Decl)). AArgCount >= 0 selects
      the overload whose decl accepts that arity instead of the first
      registered body (value-position residual calls pass raw operands). }
    function EffectiveRuntimeCalleeName(const AName: string;
      const ADecl: TGreenNode; const AArgCount: LongInt = -1): string;
    { 解析 ";external:lib:sym" 声明文本并注册 foreign binding（secret 去重）；
      body-less 的 external 纯声明也注册，供 EffectiveRuntimeCalleeName 查表。 }
    function TryRegisterForeignProcedureBinding(const AText: string;
      const ASymbolId: LongInt): Boolean;
    function HasOverload(const AName: string): Boolean;
    function FirstBodyIndexForNameLocal(const AName: string): LongInt;
    function NextBodyIndexForNameLocal(const APrevIndex: LongInt): LongInt;
    procedure IndexProcedureBodyName(const AName: string; const AIndex: LongInt);
    { ASCII-fold AName into FBodyLookupScratch (same range as
      nextpas.core.text.utils.LowerCase's table: 'A'..'Z' only). }
    procedure FoldBodyNameIntoScratch(const AName: string);
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
    function ResolveSpecializedClassMethodCall(const ACallee: string): string;
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
    function TypeMetaIsDynArrayType(const ATypeName: string): Boolean;
    function TypeMetaIsRecord(const ATypeName: string): Boolean;
    function TypeMetaIsPointer(const ATypeName: string): Boolean;
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
    { Empty subclass / type-alias class-new: Class.Create → nearest body name. }
    function ResolveClassMethodCalleeName(const AClassName,
      AMethodName: string): string;
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
    { 跨单元常量别名 seed 时序补登: 所有单元 seed 完后对未登记值的
      const decl 重解析 (PLATFORM_FS_SHORT_READ_ERROR = PLATFORM_ERR_IO,
      另一单元的基常量此时已登记)。 }
    procedure FinalizeConstSections;
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
    procedure FixupInterfaceParentImt;
    procedure FixupAliasMethodSymbols;
    function ResolveRecordAliasTypeName(const ATypeName: string): string;
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
    procedure WalkHaltCalls(const ANode: TGreenNode; Depth: LongInt = 0);
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
    { 统一构造 HIR 降级上下文：数据成员与回调全量接线。
      所有 TSemaHirLoweringContext 必须经此填充——先清零再接线，
      保证漏接回调为 nil（Assigned 可守卫）而非栈垃圾。 }
    procedure FillHirLoweringContext(out ACtx: TSemaHirLoweringContext);
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
    function IsCharValueOperand(const ANode: TGreenNode): Boolean;
    procedure LowerRuntimeTryFinallyStatement(const ANode: TGreenNode);
    procedure LowerRuntimeTryExceptStatement(const ANode: TGreenNode);
    procedure UnrollHaltForLoop(const ANode: TGreenNode);
    procedure UnrollHaltWhileLoop(const ANode: TGreenNode);
    procedure UnrollHaltRepeatLoop(const ANode: TGreenNode);
    procedure SeedRuntimeVarDecls;
    procedure WalkRuntimeVarDecls(const ANode: TGreenNode);
    procedure SeedHaltCalls;
    procedure PreRegisterFunctionReturnTypes;
    procedure MarkClassMethodCohort(const AClassName: string);
    procedure MarkProcedureBodyNeededByName(const AName: string);
    procedure MarkBodiesFromTypedHirCalls;
    procedure MarkInterfaceImplementorMethods(const ARootOwnerUnitId: string);
    procedure CollectReachableBodyRoots;
    procedure SeedFunctionBodies;
    procedure SeedUnitLifecycleBodies;
    procedure SeedImportedUnitBodies;
    procedure SemaTrace(const AMsg: string);
  public
    constructor Create(
      const ARootAst: TAstFacade;
      const AUnitGraph: TUnitGraph;
      const ADiagnostics: TDiagnosticsSink;
      const ARootFileId: TSourceFileId;
      const ANoFold: Boolean;
      const AAllocator: IAllocator = nil
    );
    destructor Destroy; override;
    procedure Analyze;
    function DetachModel: TSemanticModel;
    function Status: string;
  end;
