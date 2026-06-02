unit np_semantic_model;

{$mode objfpc}{$H+}

interface

uses
  np_green_tree, np_hir_types;

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
  end;

  TSemanticConstValue = record
    Name: string;
    Value: Int64;
  end;

  TSemanticVarInitValue = record
    Name: string;
    Value: Int64;
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
    FTypeMetadataEntries: array of TTypeMetadata;
    FTypeScalarFacts: array of TSemanticScalarTypeFact;
    FRootName: string;
    FStatus: string;
    function FindTypeScalarFactIndex(const ATypeId: LongInt): LongInt;
  public
    constructor Create;
    function AddSymbol(
      const AName: string;
      const AKind: string;
      const AOwnerUnitId: string;
      const ATypeId: LongInt;
      const AByteOffset: LongInt
    ): LongInt;
    function AddType(const AName: string; const AKind: string): LongInt;
    procedure SetTypeScalarFact(const ATypeId: LongInt;
      const AKind: TSemanticScalarKind; const ABitWidth: LongInt;
      const ASigned: Boolean);
    function GetTypeScalarFact(const ATypeId: LongInt;
      out AFact: TSemanticScalarTypeFact): Boolean;
    function TypeHasScalarFact(const ATypeId: LongInt): Boolean;
    procedure SetTypeOwner(const ATypeId: LongInt; const AOwnerUnitId: string);
    procedure SetTypeParent(const ATypeId: LongInt; const AParentTypeId: LongInt);
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
    procedure SetSymbolParamCount(const ASymbolId: LongInt; const ACount: LongInt);
    procedure SetSymbolMinParamCount(const ASymbolId: LongInt; const ACount: LongInt);
    procedure SetSymbolVisibility(const ASymbolId: LongInt; const AVisibility: string);
    procedure SetSymbolParamSignature(const ASymbolId: LongInt;
      const ASignature: string);
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
      const ALiteralStr: string;
      const AOp: string;
      const ASourceOffset: LongInt;
      const AValueClass: TSemanticHirValueClass
    ): LongInt;
    procedure SetTypedHirNodeExprId(const AHirNodeId: LongInt;
      const AExprId: LongInt);
    procedure SetTypedHirNodeTargetExprId(const AHirNodeId: LongInt;
      const AExprId: LongInt);
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
    procedure SetRootName(const AName: string);
    function RootName: string;
    procedure MarkReady;
    procedure MarkFailure;
    function Status: string;
  end;

implementation

uses
  SysUtils;

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
  SetLength(FStringConstValues, 0);
  SetLength(FTypeScalarFacts, 0);
  SetLength(FHirExprs, 0);
  FRootName := '';
  FStatus := 'deferred';
end;

function TSemanticModel.FindTypeScalarFactIndex(
  const ATypeId: LongInt
): LongInt;
var
  I: LongInt;
begin
  for I := 0 to Length(FTypeScalarFacts) - 1 do
    if FTypeScalarFacts[I].TypeId = ATypeId then
      Exit(I);
  Result := -1;
end;

function TSemanticModel.AddSymbol(
  const AName: string;
  const AKind: string;
  const AOwnerUnitId: string;
  const ATypeId: LongInt;
  const AByteOffset: LongInt
): LongInt;
var
  NextIndex: SizeInt;
begin
  NextIndex := Length(FSymbols);
  SetLength(FSymbols, NextIndex + 1);
  FSymbols[NextIndex].SymbolId := NextIndex + 1;
  FSymbols[NextIndex].Name := AName;
  FSymbols[NextIndex].Kind := AKind;
  FSymbols[NextIndex].OwnerUnitId := AOwnerUnitId;
  FSymbols[NextIndex].ScopeId := 0;
  FSymbols[NextIndex].TypeId := ATypeId;
  FSymbols[NextIndex].ParamCount := -1;
  FSymbols[NextIndex].ParamSignature := '';
  FSymbols[NextIndex].ByteOffset := AByteOffset;
  Result := FSymbols[NextIndex].SymbolId;
end;

function TSemanticModel.AddType(
  const AName: string;
  const AKind: string
): LongInt;
var
  NextIndex: SizeInt;
begin
  NextIndex := Length(FTypes);
  SetLength(FTypes, NextIndex + 1);
  FTypes[NextIndex].TypeId := NextIndex + 1;
  FTypes[NextIndex].Name := AName;
  FTypes[NextIndex].Kind := AKind;
  FTypes[NextIndex].ParentTypeId := 0;
  Result := FTypes[NextIndex].TypeId;
end;

procedure TSemanticModel.SetTypeScalarFact(const ATypeId: LongInt;
  const AKind: TSemanticScalarKind; const ABitWidth: LongInt;
  const ASigned: Boolean);
var
  Idx: LongInt;
begin
  if (ATypeId <= 0) or (ATypeId > Length(FTypes)) then
    Exit;
  if AKind = sskNone then
    Exit;
  if ABitWidth <= 0 then
    Exit;

  Idx := FindTypeScalarFactIndex(ATypeId);
  if Idx < 0 then
  begin
    Idx := Length(FTypeScalarFacts);
    SetLength(FTypeScalarFacts, Idx + 1);
  end;

  FTypeScalarFacts[Idx].TypeId := ATypeId;
  FTypeScalarFacts[Idx].Kind := AKind;
  FTypeScalarFacts[Idx].BitWidth := ABitWidth;
  FTypeScalarFacts[Idx].Signed := ASigned;
end;

function TSemanticModel.GetTypeScalarFact(const ATypeId: LongInt;
  out AFact: TSemanticScalarTypeFact): Boolean;
var
  Idx: LongInt;
begin
  AFact.TypeId := 0;
  AFact.Kind := sskNone;
  AFact.BitWidth := 0;
  AFact.Signed := False;

  Idx := FindTypeScalarFactIndex(ATypeId);
  if Idx < 0 then
    Exit(False);

  AFact := FTypeScalarFacts[Idx];
  Result := True;
end;

function TSemanticModel.TypeHasScalarFact(const ATypeId: LongInt): Boolean;
var
  Fact: TSemanticScalarTypeFact;
begin
  Result := GetTypeScalarFact(ATypeId, Fact);
end;

procedure TSemanticModel.SetTypeOwner(const ATypeId: LongInt;
  const AOwnerUnitId: string);
var
  Idx: LongInt;
begin
  Idx := ATypeId - 1;
  if (Idx >= 0) and (Idx < Length(FTypes)) then
    FTypes[Idx].OwnerUnitId := AOwnerUnitId;
end;

procedure TSemanticModel.SetTypeParent(const ATypeId: LongInt;
  const AParentTypeId: LongInt);
var
  Idx: LongInt;
begin
  Idx := ATypeId - 1;
  if (Idx >= 0) and (Idx < Length(FTypes)) then
    FTypes[Idx].ParentTypeId := AParentTypeId;
end;

procedure TSemanticModel.SetTypeGenericParent(const ATypeId: LongInt;
  const ATemplateTypeId: LongInt; const AArgIndices: array of LongInt);
var
  Idx, I: LongInt;
begin
  Idx := ATypeId - 1;
  if (Idx >= 0) and (Idx < Length(FTypes)) then
  begin
    FTypes[Idx].GenericParent.TemplateTypeId := ATemplateTypeId;
    SetLength(FTypes[Idx].GenericParent.ArgIndices, Length(AArgIndices));
    for I := 0 to High(AArgIndices) do
      FTypes[Idx].GenericParent.ArgIndices[I] := AArgIndices[I];
  end;
end;

procedure TSemanticModel.SetTypeParams(const ATypeId: LongInt;
  const AParamListNode: TGreenNode);
var
  Idx, I, ColonPos: LongInt;
  Params, Constraints, ParamText, ParamName, Constraint: string;
begin
  Idx := ATypeId - 1;
  if (Idx < 0) or (Idx >= Length(FTypes)) then
    Exit;
  if AParamListNode = nil then
    Exit;
  Params := '';
  Constraints := '';
  for I := 0 to AParamListNode.ChildCount - 1 do
  begin
    if (AParamListNode.ChildAt(I) <> nil) and
      (AParamListNode.ChildAt(I).NodeKind = gnkIdentifier) then
    begin
      ParamText := AParamListNode.ChildAt(I).Text;
      ColonPos := Pos(':', ParamText);
      if ColonPos > 0 then
      begin
        ParamName := Copy(ParamText, 1, ColonPos - 1);
        Constraint := Copy(ParamText, ColonPos + 1, MaxInt);
      end
      else
      begin
        ParamName := ParamText;
        Constraint := '';
      end;
      if Params <> '' then
      begin
        Params := Params + ',';
        Constraints := Constraints + ',';
      end;
      Params := Params + ParamName;
      Constraints := Constraints + Constraint;
    end;
  end;
  FTypes[Idx].TypeParams := Params;
  FTypes[Idx].TypeConstraints := Constraints;
end;

procedure TSemanticModel.SetTypeInstantiatedFrom(const ATypeId: LongInt;
  const AFromTypeId: LongInt);
var
  Idx: LongInt;
begin
  Idx := ATypeId - 1;
  if (Idx >= 0) and (Idx < Length(FTypes)) then
    FTypes[Idx].InstantiatedFrom := AFromTypeId;
end;

procedure TSemanticModel.AppendTypeConstraint(const ATypeId: LongInt;
  const AParamName: string; const AConstraint: string);
var
  Idx, ParamIdx, CommaCount: LongInt;
  Params: string;
  Parts: array of string;
  I, J: LongInt;
begin
  Idx := ATypeId - 1;
  if (Idx < 0) or (Idx >= Length(FTypes)) then
    Exit;
  Params := FTypes[Idx].TypeParams;
  ParamIdx := -1;
  CommaCount := 0;
  I := 1;
  while I <= Length(Params) do
  begin
    J := I;
    while (J <= Length(Params)) and (Params[J] <> ',') do
      Inc(J);
    if SameText(Trim(Copy(Params, I, J - I)), AParamName) then
    begin
      ParamIdx := CommaCount;
      Break;
    end;
    Inc(CommaCount);
    I := J + 1;
  end;
  if ParamIdx < 0 then
    Exit;
  SetLength(Parts, 0);
  I := 1;
  while I <= Length(FTypes[Idx].TypeConstraints) do
  begin
    J := I;
    while (J <= Length(FTypes[Idx].TypeConstraints)) and
      (FTypes[Idx].TypeConstraints[J] <> ',') do
      Inc(J);
    SetLength(Parts, Length(Parts) + 1);
    Parts[High(Parts)] := Copy(FTypes[Idx].TypeConstraints, I, J - I);
    I := J + 1;
  end;
  while Length(Parts) <= ParamIdx do
  begin
    SetLength(Parts, Length(Parts) + 1);
    Parts[High(Parts)] := '';
  end;
  Parts[ParamIdx] := AConstraint;
  FTypes[Idx].TypeConstraints := '';
  for I := 0 to High(Parts) do
  begin
    if I > 0 then
      FTypes[Idx].TypeConstraints := FTypes[Idx].TypeConstraints + ',';
    FTypes[Idx].TypeConstraints := FTypes[Idx].TypeConstraints + Parts[I];
  end;
end;

function TSemanticModel.IsTypeDescendantOf(const ATypeId: LongInt;
  const AAncestorTypeId: LongInt): Boolean;
var
  Current, Idx: LongInt;
  Depth: LongInt;
begin
  if ATypeId = AAncestorTypeId then
    Exit(True);
  Current := ATypeId;
  Depth := 0;
  while (Current > 0) and (Depth < 32) do
  begin
    Idx := Current - 1;
    if (Idx < 0) or (Idx >= Length(FTypes)) then
      Exit(False);
    Current := FTypes[Idx].ParentTypeId;
    if Current = AAncestorTypeId then
      Exit(True);
    Inc(Depth);
  end;
  Result := False;
end;

function TSemanticModel.AddScope(const AKind: TScopeKind;
  const AName: string; const AParentScopeId: LongInt): LongInt;
var
  NextIndex: SizeInt;
begin
  NextIndex := Length(FScopes);
  SetLength(FScopes, NextIndex + 1);
  FScopes[NextIndex].ScopeId := NextIndex + 1;
  FScopes[NextIndex].Kind := AKind;
  FScopes[NextIndex].Name := AName;
  FScopes[NextIndex].ParentScopeId := AParentScopeId;
  Result := FScopes[NextIndex].ScopeId;
end;

function TSemanticModel.ScopeCount: LongInt;
begin
  Result := Length(FScopes);
end;

procedure TSemanticModel.SetSymbolScope(const ASymbolId: LongInt;
  const AScopeId: LongInt);
var
  Idx: LongInt;
begin
  Idx := ASymbolId - 1;
  if (Idx >= 0) and (Idx < Length(FSymbols)) then
    FSymbols[Idx].ScopeId := AScopeId;
end;

procedure TSemanticModel.SetSymbolParamCount(const ASymbolId: LongInt;
  const ACount: LongInt);
var
  Idx: LongInt;
begin
  Idx := ASymbolId - 1;
  if (Idx >= 0) and (Idx < Length(FSymbols)) then
    FSymbols[Idx].ParamCount := ACount;
end;

procedure TSemanticModel.SetSymbolMinParamCount(const ASymbolId: LongInt;
  const ACount: LongInt);
var
  Idx: LongInt;
begin
  Idx := ASymbolId - 1;
  if (Idx >= 0) and (Idx < Length(FSymbols)) then
    FSymbols[Idx].MinParamCount := ACount;
end;

procedure TSemanticModel.SetSymbolVisibility(const ASymbolId: LongInt;
  const AVisibility: string);
var
  Idx: LongInt;
begin
  Idx := ASymbolId - 1;
  if (Idx >= 0) and (Idx < Length(FSymbols)) then
    FSymbols[Idx].Visibility := AVisibility;
end;

procedure TSemanticModel.SetSymbolParamSignature(const ASymbolId: LongInt;
  const ASignature: string);
var
  Idx: LongInt;
begin
  Idx := ASymbolId - 1;
  if (Idx >= 0) and (Idx < Length(FSymbols)) then
    FSymbols[Idx].ParamSignature := ASignature;
end;

function TSemanticModel.FindSymbolInScope(const AName: string;
  const AScopeId: LongInt): LongInt;
var
  I: LongInt;
begin
  for I := 0 to Length(FSymbols) - 1 do
    if (FSymbols[I].ScopeId = AScopeId) and
      SameText(FSymbols[I].Name, AName) then
      Exit(FSymbols[I].SymbolId);
  Result := 0;
end;

function TSemanticModel.LookupSymbol(const AName: string;
  const AStartScopeId: LongInt): LongInt;
var
  CurrentScope: LongInt;
  Idx: LongInt;
begin
  CurrentScope := AStartScopeId;
  while CurrentScope > 0 do
  begin
    Result := FindSymbolInScope(AName, CurrentScope);
    if Result > 0 then
      Exit;
    Idx := CurrentScope - 1;
    if (Idx >= 0) and (Idx < Length(FScopes)) then
      CurrentScope := FScopes[Idx].ParentScopeId
    else
      CurrentScope := 0;
  end;
  for Idx := 0 to Length(FSymbols) - 1 do
    if (FSymbols[Idx].ScopeId = 0) and
      SameText(FSymbols[Idx].Name, AName) then
      Exit(FSymbols[Idx].SymbolId);
  Result := 0;
end;

function TSemanticModel.LookupSymbolWithImports(const AName: string;
  const AStartScopeId: LongInt): LongInt;
var
  Idx: LongInt;
begin
  Result := LookupSymbol(AName, AStartScopeId);
  if Result > 0 then
    Exit;
  for Idx := 0 to Length(FScopes) - 1 do
    if (FScopes[Idx].Kind = skUnit) and (FScopes[Idx].ParentScopeId = 1) then
    begin
      Result := FindSymbolInScope(AName, FScopes[Idx].ScopeId);
      if Result > 0 then
        Exit;
    end;
end;

function TSemanticModel.ScopeAt(const AIndex: LongInt): TSemanticScope;
begin
  if (AIndex >= 0) and (AIndex < Length(FScopes)) then
    Result := FScopes[AIndex]
  else
  begin
    Result.ScopeId := 0;
    Result.Kind := skCompilation;
    Result.Name := '';
    Result.ParentScopeId := 0;
  end;
end;

function TSemanticModel.AddTypedHirNode(
  const AKind: string;
  const ADisplayName: string;
  const ASymbolId: LongInt;
  const ATypeId: LongInt;
  const AOperand: string
): LongInt;
var
  NextIndex: SizeInt;
begin
  NextIndex := Length(FTypedHirNodes);
  SetLength(FTypedHirNodes, NextIndex + 1);
  FTypedHirNodes[NextIndex].HirNodeId := NextIndex + 1;
  FTypedHirNodes[NextIndex].Kind := AKind;
  FTypedHirNodes[NextIndex].NodeKind := ParseHirNodeKind(AKind);
  FTypedHirNodes[NextIndex].DisplayName := ADisplayName;
  FTypedHirNodes[NextIndex].SymbolId := ASymbolId;
  FTypedHirNodes[NextIndex].TypeId := ATypeId;
  FTypedHirNodes[NextIndex].Operand := AOperand;
  FTypedHirNodes[NextIndex].ExprId := 0;
  FTypedHirNodes[NextIndex].TargetExprId := 0;
  Result := FTypedHirNodes[NextIndex].HirNodeId;
end;

function TSemanticModel.AddHirExpr(
  const AKind: TSemanticHirExprKind;
  const ATypeId: LongInt;
  const ASymbolId: LongInt;
  const AChildren: array of LongInt;
  const ALiteralInt: Int64;
  const ALiteralStr: string;
  const AOp: string;
  const ASourceOffset: LongInt;
  const AValueClass: TSemanticHirValueClass
): LongInt;
var
  NextIndex: SizeInt;
  I: LongInt;
begin
  NextIndex := Length(FHirExprs);
  SetLength(FHirExprs, NextIndex + 1);
  FHirExprs[NextIndex].ExprId := NextIndex + 1;
  FHirExprs[NextIndex].Kind := AKind;
  FHirExprs[NextIndex].TypeId := ATypeId;
  FHirExprs[NextIndex].SymbolId := ASymbolId;
  SetLength(FHirExprs[NextIndex].Children, Length(AChildren));
  for I := 0 to High(AChildren) do
    FHirExprs[NextIndex].Children[I] := AChildren[I];
  FHirExprs[NextIndex].LiteralInt := ALiteralInt;
  FHirExprs[NextIndex].LiteralStr := ALiteralStr;
  FHirExprs[NextIndex].Op := AOp;
  FHirExprs[NextIndex].SourceOffset := ASourceOffset;
  FHirExprs[NextIndex].ValueClass := AValueClass;
  Result := FHirExprs[NextIndex].ExprId;
end;

procedure TSemanticModel.SetTypedHirNodeExprId(const AHirNodeId: LongInt;
  const AExprId: LongInt);
var
  Idx: LongInt;
begin
  Idx := AHirNodeId - 1;
  if (Idx < 0) or (Idx >= Length(FTypedHirNodes)) then
    Exit;
  if (AExprId < 0) or (AExprId > Length(FHirExprs)) then
    Exit;
  FTypedHirNodes[Idx].ExprId := AExprId;
end;

procedure TSemanticModel.SetTypedHirNodeTargetExprId(
  const AHirNodeId: LongInt; const AExprId: LongInt);
var
  Idx: LongInt;
begin
  Idx := AHirNodeId - 1;
  if (Idx < 0) or (Idx >= Length(FTypedHirNodes)) then
    Exit;
  if (AExprId < 0) or (AExprId > Length(FHirExprs)) then
    Exit;
  FTypedHirNodes[Idx].TargetExprId := AExprId;
end;

function TSemanticModel.AddBinding(
  const AKind: string;
  const AName: string;
  const AOwnerUnitId: string;
  const AByteOffset: LongInt;
  const ATargetSymbolId: LongInt
): LongInt;
var
  NextIndex: SizeInt;
begin
  NextIndex := Length(FBindings);
  SetLength(FBindings, NextIndex + 1);
  FBindings[NextIndex].BindingId := NextIndex + 1;
  FBindings[NextIndex].Kind := AKind;
  FBindings[NextIndex].Name := AName;
  FBindings[NextIndex].OwnerUnitId := AOwnerUnitId;
  FBindings[NextIndex].ByteOffset := AByteOffset;
  FBindings[NextIndex].TargetSymbolId := ATargetSymbolId;
  Result := FBindings[NextIndex].BindingId;
end;

function TSemanticModel.AddRuntimeContract(const AName: string): LongInt;
var
  NextIndex: SizeInt;
begin
  NextIndex := Length(FRuntimeContracts);
  SetLength(FRuntimeContracts, NextIndex + 1);
  FRuntimeContracts[NextIndex].ContractId := NextIndex + 1;
  FRuntimeContracts[NextIndex].Name := AName;
  Result := FRuntimeContracts[NextIndex].ContractId;
end;

function TSemanticModel.AddForeignProcedureBinding(
  const APascalName: string;
  const ACallingConvention: string;
  const ALibraryId: string;
  const AExternalSymbolName: string;
  const ASymbolId: LongInt
): LongInt;
var
  NextIndex: SizeInt;
begin
  NextIndex := Length(FForeignProcedureBindings);
  SetLength(FForeignProcedureBindings, NextIndex + 1);
  FForeignProcedureBindings[NextIndex].BindingId := NextIndex + 1;
  FForeignProcedureBindings[NextIndex].PascalName := APascalName;
  FForeignProcedureBindings[NextIndex].CallingConvention := ACallingConvention;
  FForeignProcedureBindings[NextIndex].LibraryId := ALibraryId;
  FForeignProcedureBindings[NextIndex].ExternalSymbolName := AExternalSymbolName;
  FForeignProcedureBindings[NextIndex].SymbolId := ASymbolId;
  Result := FForeignProcedureBindings[NextIndex].BindingId;
end;

function TSemanticModel.AddLibraryRequest(
  const ALogicalId: string;
  const ALinkageKind: string;
  const AStrength: string
): LongInt;
var
  Index: LongInt;
  NextIndex: SizeInt;
begin
  for Index := 0 to Length(FLibraryRequests) - 1 do
    if SameText(FLibraryRequests[Index].LogicalId, ALogicalId) and
      SameText(FLibraryRequests[Index].LinkageKind, ALinkageKind) and
      SameText(FLibraryRequests[Index].Strength, AStrength) then
      Exit(FLibraryRequests[Index].RequestId);

  NextIndex := Length(FLibraryRequests);
  SetLength(FLibraryRequests, NextIndex + 1);
  FLibraryRequests[NextIndex].RequestId := NextIndex + 1;
  FLibraryRequests[NextIndex].LogicalId := ALogicalId;
  FLibraryRequests[NextIndex].LinkageKind := ALinkageKind;
  FLibraryRequests[NextIndex].Strength := AStrength;
  Result := FLibraryRequests[NextIndex].RequestId;
end;

function TSemanticModel.SymbolCount: LongInt;
begin
  Result := Length(FSymbols);
end;

function TSemanticModel.SymbolAt(const AIndex: LongInt): TSemanticSymbol;
begin
  if (AIndex < 0) or (AIndex >= Length(FSymbols)) then
  begin
    Result.SymbolId := 0;
    Result.Name := '';
    Result.Kind := '';
    Result.OwnerUnitId := '';
    Result.TypeId := 0;
    Result.ParamCount := -1;
    Result.ParamSignature := '';
    Result.ByteOffset := 0;
    Exit;
  end;
  Result := FSymbols[AIndex];
end;

function TSemanticModel.FindTypeByName(const AName: string): LongInt;
var
  Index: LongInt;
begin
  for Index := 0 to Length(FTypes) - 1 do
    if SameText(FTypes[Index].Name, AName) then
      Exit(FTypes[Index].TypeId);
  Result := 0;
end;

function TSemanticModel.FindSymbolByName(const AName: string): LongInt;
var
  Index: LongInt;
begin
  for Index := 0 to Length(FSymbols) - 1 do
    if SameText(FSymbols[Index].Name, AName) then
      Exit(FSymbols[Index].SymbolId);
  Result := 0;
end;

function TSemanticModel.SymbolTypeId(const ASymbolId: LongInt): LongInt;
var
  Index: LongInt;
begin
  for Index := 0 to Length(FSymbols) - 1 do
    if FSymbols[Index].SymbolId = ASymbolId then
      Exit(FSymbols[Index].TypeId);
  Result := 0;
end;

function TSemanticModel.TypeCount: LongInt;
begin
  Result := Length(FTypes);
end;

function TSemanticModel.TypeAt(const AIndex: LongInt): TSemanticType;
begin
  if (AIndex >= 0) and (AIndex < Length(FTypes)) then
    Result := FTypes[AIndex]
  else
  begin
    Result.TypeId := 0;
    Result.Name := '';
    Result.Kind := '';
  end;
end;

function TSemanticModel.TypedHirNodeCount: LongInt;
begin
  Result := Length(FTypedHirNodes);
end;

function TSemanticModel.TypedHirNodeAt(const AIndex: LongInt): TTypedHirNode;
begin
  if (AIndex < 0) or (AIndex >= Length(FTypedHirNodes)) then
  begin
    Result.HirNodeId := 0;
    Result.Kind := '';
    Result.DisplayName := '';
    Result.SymbolId := 0;
    Result.TypeId := 0;
    Result.Operand := '';
    Result.ExprId := 0;
    Result.TargetExprId := 0;
    Exit;
  end;

  Result := FTypedHirNodes[AIndex];
end;

function TSemanticModel.HirExprCount: LongInt;
begin
  Result := Length(FHirExprs);
end;

function TSemanticModel.HirExprAt(const AIndex: LongInt): TSemanticHirExpr;
begin
  if (AIndex < 0) or (AIndex >= Length(FHirExprs)) then
  begin
    Result.ExprId := 0;
    Result.Kind := shekInvalid;
    Result.TypeId := 0;
    Result.SymbolId := 0;
    SetLength(Result.Children, 0);
    Result.LiteralInt := 0;
    Result.LiteralStr := '';
    Result.Op := '';
    Result.SourceOffset := 0;
    Result.ValueClass := shvcNone;
    Exit;
  end;

  Result := FHirExprs[AIndex];
end;

function TSemanticModel.BindingCount: LongInt;
begin
  Result := Length(FBindings);
end;

function TSemanticModel.BindingAt(const AIndex: LongInt): TSemanticBinding;
begin
  if (AIndex < 0) or (AIndex >= Length(FBindings)) then
  begin
    Result.BindingId := 0;
    Result.Kind := '';
    Result.Name := '';
    Result.OwnerUnitId := '';
    Result.ByteOffset := 0;
    Result.TargetSymbolId := 0;
    Exit;
  end;

  Result := FBindings[AIndex];
end;

function TSemanticModel.RuntimeContractCount: LongInt;
begin
  Result := Length(FRuntimeContracts);
end;

function TSemanticModel.ForeignProcedureBindingCount: LongInt;
begin
  Result := Length(FForeignProcedureBindings);
end;

function TSemanticModel.ForeignProcedureBindingAt(
  const AIndex: LongInt
): TSemanticForeignProcedureBinding;
begin
  if (AIndex < 0) or (AIndex >= Length(FForeignProcedureBindings)) then
  begin
    Result.BindingId := 0;
    Result.PascalName := '';
    Result.CallingConvention := '';
    Result.LibraryId := '';
    Result.ExternalSymbolName := '';
    Result.SymbolId := 0;
    Exit;
  end;

  Result := FForeignProcedureBindings[AIndex];
end;

function TSemanticModel.LibraryRequestCount: LongInt;
begin
  Result := Length(FLibraryRequests);
end;

function TSemanticModel.LibraryRequestAt(
  const AIndex: LongInt
): TSemanticLibraryRequest;
begin
  if (AIndex < 0) or (AIndex >= Length(FLibraryRequests)) then
  begin
    Result.RequestId := 0;
    Result.LogicalId := '';
    Result.LinkageKind := '';
    Result.Strength := '';
    Exit;
  end;

  Result := FLibraryRequests[AIndex];
end;

procedure TSemanticModel.AddConstValue(const AName: string; const AValue: Int64);
var
  Index: LongInt;
  NextIndex: SizeInt;
begin
  for Index := 0 to Length(FConstValues) - 1 do
    if SameText(FConstValues[Index].Name, AName) then
    begin
      FConstValues[Index].Value := AValue;
      Exit;
    end;
  NextIndex := Length(FConstValues);
  SetLength(FConstValues, NextIndex + 1);
  FConstValues[NextIndex].Name := AName;
  FConstValues[NextIndex].Value := AValue;
end;

function TSemanticModel.LookupConstValue(const AName: string;
  out AValue: Int64): Boolean;
var
  Index: LongInt;
begin
  AValue := 0;
  for Index := 0 to Length(FConstValues) - 1 do
    if SameText(FConstValues[Index].Name, AName) then
    begin
      AValue := FConstValues[Index].Value;
      Exit(True);
    end;
  Result := False;
end;

function TSemanticModel.ConstValueCount: LongInt;
begin
  Result := Length(FConstValues);
end;

function TSemanticModel.ConstValueNameAt(AIndex: LongInt): string;
begin
  if (AIndex >= 0) and (AIndex < Length(FConstValues)) then
    Result := FConstValues[AIndex].Name
  else
    Result := '';
end;

function TSemanticModel.ConstValueAt(AIndex: LongInt): Int64;
begin
  if (AIndex >= 0) and (AIndex < Length(FConstValues)) then
    Result := FConstValues[AIndex].Value
  else
    Result := 0;
end;

procedure TSemanticModel.AddVarInitValue(const AName: string; const AValue: Int64);
var
  Index: LongInt;
  NextIndex: SizeInt;
begin
  for Index := 0 to Length(FVarInitValues) - 1 do
    if SameText(FVarInitValues[Index].Name, AName) then
    begin
      FVarInitValues[Index].Value := AValue;
      Exit;
    end;
  NextIndex := Length(FVarInitValues);
  SetLength(FVarInitValues, NextIndex + 1);
  FVarInitValues[NextIndex].Name := AName;
  FVarInitValues[NextIndex].Value := AValue;
end;

procedure TSemanticModel.RemoveVarInitValue(const AName: string);
var
  Index, Last: LongInt;
begin
  Last := Length(FVarInitValues) - 1;
  for Index := 0 to Last do
    if SameText(FVarInitValues[Index].Name, AName) then
    begin
      if Index < Last then
        FVarInitValues[Index] := FVarInitValues[Last];
      SetLength(FVarInitValues, Last);
      Exit;
    end;
end;

function TSemanticModel.LookupVarInitValue(const AName: string;
  out AValue: Int64): Boolean;
var
  Index: LongInt;
begin
  AValue := 0;
  for Index := 0 to Length(FVarInitValues) - 1 do
    if SameText(FVarInitValues[Index].Name, AName) then
    begin
      AValue := FVarInitValues[Index].Value;
      Exit(True);
    end;
  Result := False;
end;

function TSemanticModel.HasVarInitValue(const AName: string): Boolean;
var
  Index: LongInt;
begin
  for Index := 0 to Length(FVarInitValues) - 1 do
    if SameText(FVarInitValues[Index].Name, AName) then
      Exit(True);
  Result := False;
end;

procedure TSemanticModel.SetTypeMeta(const ATypeId: LongInt;
  const AMeta: TTypeMetadata);
var
  I: LongInt;
begin
  for I := 0 to Length(FTypeMetadataEntries) - 1 do
    if FTypeMetadataEntries[I].TypeId = ATypeId then
    begin
      FTypeMetadataEntries[I] := AMeta;
      FTypeMetadataEntries[I].TypeId := ATypeId;
      Exit;
    end;
  SetLength(FTypeMetadataEntries, Length(FTypeMetadataEntries) + 1);
  FTypeMetadataEntries[High(FTypeMetadataEntries)] := AMeta;
  FTypeMetadataEntries[High(FTypeMetadataEntries)].TypeId := ATypeId;
end;

function TSemanticModel.GetTypeMeta(const ATypeId: LongInt;
  out AMeta: TTypeMetadata): Boolean;
var
  I: LongInt;
begin
  Result := False;
  for I := 0 to Length(FTypeMetadataEntries) - 1 do
    if FTypeMetadataEntries[I].TypeId = ATypeId then
    begin
      AMeta := FTypeMetadataEntries[I];
      Exit(True);
    end;
end;

function TSemanticModel.GetTypeMetaByName(const ATypeName: string;
  out AMeta: TTypeMetadata): Boolean;
var
  I: LongInt;
begin
  Result := False;
  for I := 0 to Length(FTypeMetadataEntries) - 1 do
    if SameText(FTypes[FTypeMetadataEntries[I].TypeId - 1].Name, ATypeName) then
    begin
      AMeta := FTypeMetadataEntries[I];
      Exit(True);
    end;
end;

function TSemanticModel.GetFieldMetaByName(const ATypeId: LongInt;
  const AFieldName: string; out AField: TFieldMeta): Boolean;
var
  I, J: LongInt;
begin
  Result := False;
  for I := 0 to Length(FTypeMetadataEntries) - 1 do
    if FTypeMetadataEntries[I].TypeId = ATypeId then
    begin
      for J := 0 to Length(FTypeMetadataEntries[I].Fields) - 1 do
        if SameText(FTypeMetadataEntries[I].Fields[J].Name, AFieldName) then
        begin
          AField := FTypeMetadataEntries[I].Fields[J];
          Exit(True);
        end;
      Exit;
    end;
end;

function TSemanticModel.GetVmtSlotByName(const ATypeId: LongInt;
  const AMethodName: string; out ASlot: TVmtSlot): Boolean;
var
  I, J: LongInt;
begin
  Result := False;
  for I := 0 to Length(FTypeMetadataEntries) - 1 do
    if FTypeMetadataEntries[I].TypeId = ATypeId then
    begin
      for J := 0 to Length(FTypeMetadataEntries[I].VmtSlots) - 1 do
        if SameText(FTypeMetadataEntries[I].VmtSlots[J].MethodName, AMethodName) then
        begin
          ASlot := FTypeMetadataEntries[I].VmtSlots[J];
          Exit(True);
        end;
      Exit;
    end;
end;

procedure TSemanticModel.AddStringConstValue(const AName: string; const AValue: string);
var
  Index: LongInt;
  NextIndex: SizeInt;
begin
  for Index := 0 to Length(FStringConstValues) - 1 do
    if SameText(FStringConstValues[Index].Name, AName) then
    begin
      FStringConstValues[Index].Value := AValue;
      Exit;
    end;
  NextIndex := Length(FStringConstValues);
  SetLength(FStringConstValues, NextIndex + 1);
  FStringConstValues[NextIndex].Name := AName;
  FStringConstValues[NextIndex].Value := AValue;
end;

function TSemanticModel.LookupStringConstValue(const AName: string;
  out AValue: string): Boolean;
var
  Index: LongInt;
begin
  AValue := '';
  for Index := 0 to Length(FStringConstValues) - 1 do
    if SameText(FStringConstValues[Index].Name, AName) then
    begin
      AValue := FStringConstValues[Index].Value;
      Exit(True);
    end;
  Result := False;
end;

procedure TSemanticModel.SetRootName(const AName: string);
begin
  FRootName := AName;
end;

function TSemanticModel.RootName: string;
begin
  Result := FRootName;
end;

procedure TSemanticModel.MarkReady;
begin
  FStatus := 'ready';
end;

procedure TSemanticModel.MarkFailure;
begin
  FStatus := 'failure';
end;

function TSemanticModel.Status: string;
begin
  Result := FStatus;
end;

end.
