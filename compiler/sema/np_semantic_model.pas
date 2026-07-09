unit np_semantic_model;

{$mode objfpc}{$H+}

interface

uses
  np_green_tree, np_hir_types,
  nextpas.core.collections.hashmap;

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

  TSemanticHirExpr = record
    ExprId: LongInt;
    Kind: TSemanticHirExprKind;
    TypeId: LongInt;
    SymbolId: LongInt;
    Children: array of LongInt;
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

  TFieldMeta = record
    Name: string;
    Index: LongInt;
    IsString: Boolean;
    IsPointer: Boolean;
    IsDynArray: Boolean;
    IsRecord: Boolean;
    TypeId: LongInt;
  end;

  TVmtSlot = record
    MethodName: string;
    SlotIndex: LongInt;
    FuncQualName: string;
  end;

  TPropertyMeta = record
    Name: string;
    ReadAccessor: string;
    WriteAccessor: string;
  end;

  TInterfaceSlotMeta = record
    InterfaceName: string;
    SlotOffset: LongInt;
  end;

  TTypeMetadata = record
    TypeId: LongInt;
    Size: Int64;
    IsRecord: Boolean;
    VmtCount: LongInt;
    ParentClassId: LongInt;
    ParentClassName: string;
    Interfaces: string;
    Fields: array of TFieldMeta;
    VmtSlots: array of TVmtSlot;
    RetPtrMethods: array of string;
    Properties: array of TPropertyMeta;
    InterfaceSlots: array of TInterfaceSlotMeta;
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

  TSemanticModel = class
  private
    FHirExprs: array of TSemanticHirExpr;
    FSymbols: array of TSemanticSymbol;
    FTypes: array of TSemanticType;
    FScopes: array of TSemanticScope;
    FTypedHirNodes: array of TTypedHirNode;
    FBindings: array of TSemanticBinding;
    FRuntimeContracts: array of TRuntimeContract;
    FForeignProcedureBindings: array of TSemanticForeignProcedureBinding;
    FLibraryRequests: array of TSemanticLibraryRequest;
    FConstValues: array of TSemanticConstValue;
    FVarInitValues: array of TSemanticVarInitValue;
    FStringConstValues: array of TSemanticStringConstValue;
    FFloatConstValues: array of TSemanticFloatConstValue;
    FTypeMetadataEntries: array of TTypeMetadata;
    FTypeScalarFacts: array of TSemanticScalarTypeFact;
    FUnitInitOrder: array of string;
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

implementation

uses
  nextpas.core.text.conv, nextpas.core.collections.vec;

type
  TStringVec = specialize TVec<string>;

constructor TSemanticModel.Create;
begin
  inherited Create;
  SetLength(FSymbols, 0);
  SetLength(FTypes, 0);
  SetLength(FScopes, 0);
  SetLength(FTypedHirNodes, 0);
  SetLength(FRuntimeContracts, 0);
  SetLength(FForeignProcedureBindings, 0);
  SetLength(FLibraryRequests, 0);
  SetLength(FConstValues, 0);
  SetLength(FVarInitValues, 0);
  SetLength(FFloatConstValues, 0);
  SetLength(FStringConstValues, 0);
  SetLength(FTypeScalarFacts, 0);
  SetLength(FHirExprs, 0);
  FRootName := '';
  FStatus := 'deferred';
  // Initialize O(1) lookup indexes
  FTypeNameIndex := specialize THashMap<string, LongInt>.Create;
  FSymbolNameIndex := specialize THashMap<string, LongInt>.Create;
  FConstNameIndex := specialize THashMap<string, LongInt>.Create;
  FTypeMetaNameIndex := specialize THashMap<string, LongInt>.Create;
end;

destructor TSemanticModel.Destroy;
begin
  FTypeNameIndex.Free;
  FSymbolNameIndex.Free;
  FConstNameIndex.Free;
  FTypeMetaNameIndex.Free;
  inherited Destroy;
end;

{$I np_semantic_model_mutation.inc}
{$I np_semantic_model_lookup.inc}
{$I np_semantic_model_accessors.inc}

end.
