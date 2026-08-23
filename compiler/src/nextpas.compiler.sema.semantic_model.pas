unit nextpas.compiler.sema.semantic_model;

{$mode objfpc}{$H+}
{$UNITPATH ../../core/src}

interface

uses
  nextpas.compiler.syntax.green_tree, nextpas.compiler.ir.hir.types,
  nextpas.core.collections.hashmap,
  nextpas.core.collections.vec,
  nextpas.compiler.sema.field_meta_vec,
  nextpas.compiler.sema.vmt_slot_vec,
  nextpas.compiler.sema.property_meta_vec,
  nextpas.compiler.sema.interface_slot_vec;

type
  TSemanticHirValueClass = (
    shvcNone,
    shvcScalar,
    shvcAddress,
    shvcStringPair,
    shvcVoid
  );

  TSemanticScalarKind = (
    sskNone,
    sskBool,
    sskInt,
    sskFloat,
    sskPointer
  );

  TSemanticScalarTypeFact = record
    TypeId: LongInt;
    Kind: TSemanticScalarKind;
    BitWidth: LongInt;
    Signed: Boolean;
  end;

  TSemanticHirExprKind = (
    shekInvalid,
    shekIntLiteral,
    shekStringLiteral,
    shekNilLiteral,
    shekSymbolValue,
    shekSymbolAddress,
    shekCast,
    shekUnaryOp,
    shekBinaryOp,
    shekCompareOp,
    shekCall,
    shekVirtualCall,
    shekInterfaceCall,
    shekDeref,
    shekAddressOf,
    shekField,
    shekArrayElem,
    shekArrayBuffer,
    shekStringChar,
    shekIntrinsic
  );

  { Nested product table owned by HirExpr entry (default heap). }
  TSemanticHirChildVec = specialize TVec<LongInt>;

  TSemanticHirExpr = record
    ExprId: LongInt;
    Kind: TSemanticHirExprKind;
    TypeId: LongInt;
    SymbolId: LongInt;
    Children: TSemanticHirChildVec;
    LiteralInt: Int64;
    LiteralFloat: Double;
    LiteralStr: string;
    Op: string;
    SourceOffset: LongInt;
    ValueClass: TSemanticHirValueClass;
  end;

  TSemanticSymbol = record
    SymbolId: LongInt;
    Name: string;
    Kind: string;
    OwnerUnitId: string;
    ScopeId: LongInt;
    TypeId: LongInt;
    ParamCount: LongInt;
    MinParamCount: LongInt;
    ParamSignature: string;
    Visibility: string;
    ByteOffset: LongInt;
    ReturnTypeId: LongInt;
    { Same lowercased Name chain (SymbolId, 0=end). FSymbolNameIndex points
      at the newest head; walk NextSameNameId for all overloads O(k). }
    NextSameNameId: LongInt;
  end;

  TGenericParentRef = record
    TemplateTypeId: LongInt;
    ArgIndices: array of LongInt;
  end;

  TSemanticType = record
    TypeId: LongInt;
    Name: string;
    Kind: string;
    OwnerUnitId: string;
    ParentTypeId: LongInt;
    TypeParams: string;
    TypeConstraints: string;
    InstantiatedFrom: LongInt;
    GenericParent: TGenericParentRef;
  end;

  TTypedHirNode = record
    HirNodeId: LongInt;
    Kind: string;
    NodeKind: THirNodeKind;
    DisplayName: string;
    SymbolId: LongInt;
    TypeId: LongInt;
    Operand: string;
    ExprId: LongInt;
    TargetExprId: LongInt;
    GreenNodeRef: TGreenNode;  // optional: green tree node for unit init/fini body
    IsThreadVar: Boolean;   // true for threadvar declarations
  end;

  TSemanticBinding = record
    BindingId: LongInt;
    Kind: string;
    Name: string;
    OwnerUnitId: string;
    ByteOffset: LongInt;
    TargetSymbolId: LongInt;
  end;

  TRuntimeContract = record
    ContractId: LongInt;
    Name: string;
  end;

  TSemanticForeignProcedureBinding = record
    BindingId: LongInt;
    PascalName: string;
    CallingConvention: string;
    LibraryId: string;
    ExternalSymbolName: string;
    SymbolId: LongInt;
  end;

  TSemanticLibraryRequest = record
    RequestId: LongInt;
    LogicalId: string;
    LinkageKind: string;
    Strength: string;
  end;

  { Re-export from satellite units (keeps nested TVec specializes out of this .o). }
  TFieldMeta = nextpas.compiler.sema.field_meta_vec.TFieldMeta;
  TSemanticFieldMetaVec = nextpas.compiler.sema.field_meta_vec.TSemanticFieldMetaVec;
  TVmtSlot = nextpas.compiler.sema.vmt_slot_vec.TVmtSlot;
  TSemanticVmtSlotVec = nextpas.compiler.sema.vmt_slot_vec.TSemanticVmtSlotVec;
  TPropertyMeta = nextpas.compiler.sema.property_meta_vec.TPropertyMeta;
  TSemanticPropertyMetaVec = nextpas.compiler.sema.property_meta_vec.TSemanticPropertyMetaVec;
  TInterfaceSlotMeta = nextpas.compiler.sema.interface_slot_vec.TInterfaceSlotMeta;
  TSemanticInterfaceSlotMetaVec =
    nextpas.compiler.sema.interface_slot_vec.TSemanticInterfaceSlotMetaVec;

  { Shared string product table; also used by nested RetPtrMethods (no extra
    specialize — reuses this unit's TVec<string>). }
  TSemanticStringVec = specialize TVec<string>;

  TTypeMetadata = record
    TypeId: LongInt;
    Size: Int64;
    IsRecord: Boolean;
    VmtCount: LongInt;
    ParentClassId: LongInt;
    ParentClassName: string;
    Interfaces: string;
    Fields: TSemanticFieldMetaVec;
    VmtSlots: TSemanticVmtSlotVec;
    RetPtrMethods: TSemanticStringVec;
    Properties: TSemanticPropertyMetaVec;
    InterfaceSlots: TSemanticInterfaceSlotMetaVec;
    ArrElemSize: Int64;
    ArrElemType: string;
    ArrLowBound: Int64;
    ArrHighBound: Int64;
    ArrLength: Int64;
    IsStaticArray: Boolean;
    AliasTargetTypeId: LongInt;
  end;

  TSemanticConstValue = record
    Name: string;
    Value: Int64;
  end;

  TSemanticVarInitValue = record
    Name: string;
    Value: Int64;
  end;

  TSemanticFloatConstValue = record
    Name: string;
    Value: Double;
  end;

  TSemanticStringConstValue = record
    Name: string;
    Value: string;
  end;

  TScopeKind = (
    skCompilation,
    skUnit,
    skInterface,
    skImplementation,
    skCallable,
    skRecord,
    skClass,
    skBlock
  );

  TSemanticScope = record
    ScopeId: LongInt;
    Kind: TScopeKind;
    Name: string;
    ParentScopeId: LongInt;
  end;

  TSemanticHirExprVec = specialize TVec<TSemanticHirExpr>;
  TSemanticSymbolVec = specialize TVec<TSemanticSymbol>;
  TSemanticTypeVec = specialize TVec<TSemanticType>;
  TSemanticScopeVec = specialize TVec<TSemanticScope>;
  TTypedHirNodeVec = specialize TVec<TTypedHirNode>;
  TSemanticBindingVec = specialize TVec<TSemanticBinding>;
  TRuntimeContractVec = specialize TVec<TRuntimeContract>;
  TSemanticForeignProcedureBindingVec = specialize TVec<TSemanticForeignProcedureBinding>;
  TSemanticLibraryRequestVec = specialize TVec<TSemanticLibraryRequest>;
  TSemanticConstValueVec = specialize TVec<TSemanticConstValue>;
  TSemanticVarInitValueVec = specialize TVec<TSemanticVarInitValue>;
  TSemanticStringConstValueVec = specialize TVec<TSemanticStringConstValue>;
  TSemanticFloatConstValueVec = specialize TVec<TSemanticFloatConstValue>;
  TTypeMetadataVec = specialize TVec<TTypeMetadata>;
  TSemanticScalarTypeFactVec = specialize TVec<TSemanticScalarTypeFact>;

  TSemanticModel = class
  private
    FHirExprs: TSemanticHirExprVec;
    FSymbols: TSemanticSymbolVec;
    FTypes: TSemanticTypeVec;
    FScopes: TSemanticScopeVec;
    FTypedHirNodes: TTypedHirNodeVec;
    FBindings: TSemanticBindingVec;
    FRuntimeContracts: TRuntimeContractVec;
    FForeignProcedureBindings: TSemanticForeignProcedureBindingVec;
    FLibraryRequests: TSemanticLibraryRequestVec;
    FConstValues: TSemanticConstValueVec;
    FVarInitValues: TSemanticVarInitValueVec;
    FStringConstValues: TSemanticStringConstValueVec;
    FFloatConstValues: TSemanticFloatConstValueVec;
    FTypeMetadataEntries: TTypeMetadataVec;
    FTypeScalarFacts: TSemanticScalarTypeFactVec;
    FUnitInitOrder: TSemanticStringVec;
    FRootName: string;
    FStatus: string;
    // O(1) lookup indexes via THashMap (case-insensitive keys)
    FTypeNameIndex: specialize THashMap<string, LongInt>;
    FSymbolNameIndex: specialize THashMap<string, LongInt>;
    FConstNameIndex: specialize THashMap<string, LongInt>;
    FTypeMetaNameIndex: specialize THashMap<string, LongInt>;
    function FindTypeScalarFactIndex(const ATypeId: LongInt): LongInt;
  public
    constructor Create;
    destructor Destroy; override;
    function AddSymbol(
      const AName: string;
      const AKind: string;
      const AOwnerUnitId: string;
      const ATypeId: LongInt;
      const AByteOffset: LongInt
    ): LongInt;
    function AddType(const AName: string; const AKind: string): LongInt;
    procedure SetTypeKind(const ATypeId: LongInt; const AKind: string);
    procedure SetTypeScalarFact(const ATypeId: LongInt;
      const AKind: TSemanticScalarKind; const ABitWidth: LongInt;
      const ASigned: Boolean);
    function GetTypeScalarFact(const ATypeId: LongInt;
      out AFact: TSemanticScalarTypeFact): Boolean;
    function TypeHasScalarFact(const ATypeId: LongInt): Boolean;
    procedure SetTypeOwner(const ATypeId: LongInt; const AOwnerUnitId: string);
    procedure SetTypeParent(const ATypeId: LongInt; const AParentTypeId: LongInt);
    procedure SetTypeAliasTarget(const ATypeId: LongInt; const ATargetTypeId: LongInt);
    procedure SetTypeGenericParent(const ATypeId: LongInt;
      const ATemplateTypeId: LongInt; const AArgIndices: array of LongInt);
    procedure SetTypeParams(const ATypeId: LongInt; const AParamListNode: TGreenNode);
    procedure SetTypeInstantiatedFrom(const ATypeId: LongInt; const AFromTypeId: LongInt);
    procedure AppendTypeConstraint(const ATypeId: LongInt;
      const AParamName: string; const AConstraint: string);
    function IsTypeDescendantOf(const ATypeId: LongInt;
      const AAncestorTypeId: LongInt): Boolean;
    function AddScope(const AKind: TScopeKind; const AName: string;
      const AParentScopeId: LongInt): LongInt;
    procedure SetSymbolScope(const ASymbolId: LongInt; const AScopeId: LongInt);
    procedure SetSymbolTypeId(const ASymbolId: LongInt; const ATypeId: LongInt);
    procedure SetSymbolParamCount(const ASymbolId: LongInt; const ACount: LongInt);
    procedure SetSymbolMinParamCount(const ASymbolId: LongInt; const ACount: LongInt);
    procedure SetSymbolVisibility(const ASymbolId: LongInt; const AVisibility: string);
    procedure SetSymbolParamSignature(const ASymbolId: LongInt;
      const ASignature: string);
    procedure SetSymbolReturnTypeId(const ASymbolId: LongInt;
      const AReturnTypeId: LongInt);
    function FindSymbolInScope(const AName: string;
      const AScopeId: LongInt): LongInt;
    function LookupSymbol(const AName: string;
      const AStartScopeId: LongInt): LongInt;
    function LookupSymbolWithImports(const AName: string;
      const AStartScopeId: LongInt): LongInt;
    function ScopeCount: LongInt;
    function ScopeAt(const AIndex: LongInt): TSemanticScope;
    function AddTypedHirNode(
      const AKind: string;
      const ADisplayName: string;
      const ASymbolId: LongInt;
      const ATypeId: LongInt;
      const AOperand: string
    ): LongInt;
    function AddHirExpr(
      const AKind: TSemanticHirExprKind;
      const ATypeId: LongInt;
      const ASymbolId: LongInt;
      const AChildren: array of LongInt;
      const ALiteralInt: Int64;
      const ALiteralFloat: Double;
      const ALiteralStr: string;
      const AOp: string;
      const ASourceOffset: LongInt;
      const AValueClass: TSemanticHirValueClass
    ): LongInt;
    procedure SetTypedHirNodeExprId(const AHirNodeId: LongInt;
      const AExprId: LongInt);
    procedure SetTypedHirNodeTargetExprId(const AHirNodeId: LongInt;
      const AExprId: LongInt);
    procedure SetTypedHirNodeGreenRef(const AHirNodeId: LongInt;
      const AGreenNode: TGreenNode);
    procedure SetTypedHirNodeIsThreadVar(const AHirNodeId: LongInt;
      const AIsThreadVar: Boolean);
    function AddBinding(
      const AKind: string;
      const AName: string;
      const AOwnerUnitId: string;
      const AByteOffset: LongInt;
      const ATargetSymbolId: LongInt
    ): LongInt;
    function AddRuntimeContract(const AName: string): LongInt;
    function AddForeignProcedureBinding(
      const APascalName: string;
      const ACallingConvention: string;
      const ALibraryId: string;
      const AExternalSymbolName: string;
      const ASymbolId: LongInt
    ): LongInt;
    function AddLibraryRequest(
      const ALogicalId: string;
      const ALinkageKind: string;
      const AStrength: string
    ): LongInt;
    function SymbolCount: LongInt;
    function SymbolAt(const AIndex: LongInt): TSemanticSymbol;
    function FindTypeByName(const AName: string): LongInt;
    function FindSymbolByName(const AName: string): LongInt;
    { First (newest) SymbolId for AName, or 0. Walk with NextSymbolIdSameName. }
    function FirstSymbolIdByName(const AName: string): LongInt;
    function NextSymbolIdSameName(const ASymbolId: LongInt): LongInt;
    function SymbolTypeId(const ASymbolId: LongInt): LongInt;
    function TypeCount: LongInt;
    function TypeAt(const AIndex: LongInt): TSemanticType;
    function TypedHirNodeCount: LongInt;
    function TypedHirNodeAt(const AIndex: LongInt): TTypedHirNode;
    function HirExprCount: LongInt;
    function HirExprAt(const AIndex: LongInt): TSemanticHirExpr;
    function BindingCount: LongInt;
    function BindingAt(const AIndex: LongInt): TSemanticBinding;
    function RuntimeContractCount: LongInt;
    function RuntimeContractAt(const AIndex: LongInt): TRuntimeContract;
    function ForeignProcedureBindingCount: LongInt;
    function ForeignProcedureBindingAt(
      const AIndex: LongInt
    ): TSemanticForeignProcedureBinding;
    function LibraryRequestCount: LongInt;
    function LibraryRequestAt(const AIndex: LongInt): TSemanticLibraryRequest;
    procedure AddConstValue(const AName: string; const AValue: Int64);
    function LookupConstValue(const AName: string;
      out AValue: Int64): Boolean;
    function ConstValueCount: LongInt;
    function ConstValueNameAt(AIndex: LongInt): string;
    function ConstValueAt(AIndex: LongInt): Int64;
    procedure AddVarInitValue(const AName: string; const AValue: Int64);
    procedure RemoveVarInitValue(const AName: string);
    function LookupVarInitValue(const AName: string;
      out AValue: Int64): Boolean;
    function HasVarInitValue(const AName: string): Boolean;
    procedure SetTypeMeta(const ATypeId: LongInt; const AMeta: TTypeMetadata);
    function GetTypeMeta(const ATypeId: LongInt;
      out AMeta: TTypeMetadata): Boolean;
    function GetTypeMetaByName(const ATypeName: string;
      out AMeta: TTypeMetadata): Boolean;
    function GetFieldMetaByName(const ATypeId: LongInt;
      const AFieldName: string; out AField: TFieldMeta): Boolean;
    function GetVmtSlotByName(const ATypeId: LongInt;
      const AMethodName: string; out ASlot: TVmtSlot): Boolean;
    procedure AddStringConstValue(const AName: string; const AValue: string);
    function LookupStringConstValue(const AName: string;
      out AValue: string): Boolean;
    procedure AddFloatConstValue(const AName: string; const AValue: Double);
    function LookupFloatConstValue(const AName: string;
      out AValue: Double): Boolean;
    procedure SetRootName(const AName: string);
    function RootName: string;
    procedure SetUnitInitOrder(const AOrder: array of string);
    function UnitInitOrderCount: LongInt;
    function UnitInitOrderAt(const AIndex: LongInt): string;
    procedure MarkReady;
    procedure MarkFailure;
    function Status: string;
  end;

{ Nil-safe child count for entry-owned TSemanticHirChildVec. }
function SemanticHirChildCount(const AChildren: TSemanticHirChildVec): LongInt; inline;

implementation

uses
  nextpas.core.text.conv;

type
  TStringVec = TSemanticStringVec;
  PSemanticType = ^TSemanticType;
  PSemanticScalarTypeFact = ^TSemanticScalarTypeFact;
  PTypeMetadata = ^TTypeMetadata;

constructor TSemanticModel.Create;
begin
  inherited Create;
  FHirExprs := TSemanticHirExprVec.Create;
  FSymbols := TSemanticSymbolVec.Create;
  FTypes := TSemanticTypeVec.Create;
  FScopes := TSemanticScopeVec.Create;
  FTypedHirNodes := TTypedHirNodeVec.Create;
  FBindings := TSemanticBindingVec.Create;
  FRuntimeContracts := TRuntimeContractVec.Create;
  FForeignProcedureBindings := TSemanticForeignProcedureBindingVec.Create;
  FLibraryRequests := TSemanticLibraryRequestVec.Create;
  FConstValues := TSemanticConstValueVec.Create;
  FVarInitValues := TSemanticVarInitValueVec.Create;
  FStringConstValues := TSemanticStringConstValueVec.Create;
  FFloatConstValues := TSemanticFloatConstValueVec.Create;
  FTypeMetadataEntries := TTypeMetadataVec.Create;
  FTypeScalarFacts := TSemanticScalarTypeFactVec.Create;
  FUnitInitOrder := TSemanticStringVec.Create;
  FRootName := '';
  FStatus := 'deferred';
  FTypeNameIndex := specialize THashMap<string, LongInt>.Create;
  FSymbolNameIndex := specialize THashMap<string, LongInt>.Create;
  FConstNameIndex := specialize THashMap<string, LongInt>.Create;
  FTypeMetaNameIndex := specialize THashMap<string, LongInt>.Create;
end;

destructor TSemanticModel.Destroy;
var
  I: SizeInt;
  Meta: PTypeMetadata;
begin
  FTypeNameIndex.Free;
  FSymbolNameIndex.Free;
  FConstNameIndex.Free;
  FTypeMetaNameIndex.Free;
  FUnitInitOrder.Free;
  FUnitInitOrder := nil;
  FTypeScalarFacts.Free;
  FTypeScalarFacts := nil;
  if FTypeMetadataEntries <> nil then
  begin
    for I := 0 to SizeInt(FTypeMetadataEntries.Count) - 1 do
    begin
      Meta := FTypeMetadataEntries.GetPtr(SizeUInt(I));
      Meta^.Fields.Free;
      Meta^.Fields := nil;
      Meta^.VmtSlots.Free;
      Meta^.VmtSlots := nil;
      Meta^.RetPtrMethods.Free;
      Meta^.RetPtrMethods := nil;
      Meta^.Properties.Free;
      Meta^.Properties := nil;
      Meta^.InterfaceSlots.Free;
      Meta^.InterfaceSlots := nil;
    end;
  end;
  FTypeMetadataEntries.Free;
  FTypeMetadataEntries := nil;
  FFloatConstValues.Free;
  FFloatConstValues := nil;
  FStringConstValues.Free;
  FStringConstValues := nil;
  FVarInitValues.Free;
  FVarInitValues := nil;
  FConstValues.Free;
  FConstValues := nil;
  FLibraryRequests.Free;
  FLibraryRequests := nil;
  FForeignProcedureBindings.Free;
  FForeignProcedureBindings := nil;
  FRuntimeContracts.Free;
  FRuntimeContracts := nil;
  FBindings.Free;
  FBindings := nil;
  FTypedHirNodes.Free;
  FTypedHirNodes := nil;
  FScopes.Free;
  FScopes := nil;
  FTypes.Free;
  FTypes := nil;
  FSymbols.Free;
  FSymbols := nil;
  if FHirExprs <> nil then
  begin
    for I := 0 to SizeInt(FHirExprs.Count) - 1 do
    begin
      FHirExprs.GetPtr(SizeUInt(I))^.Children.Free;
      FHirExprs.GetPtr(SizeUInt(I))^.Children := nil;
    end;
  end;
  FHirExprs.Free;
  FHirExprs := nil;
  inherited Destroy;
end;

function SemanticHirChildCount(const AChildren: TSemanticHirChildVec): LongInt;
begin
  if AChildren = nil then
    Result := 0
  else
    Result := LongInt(AChildren.Count);
end;

{$I np_semantic_model_mutation.inc}
{$I np_semantic_model_lookup.inc}
{$I np_semantic_model_accessors.inc}

end.
