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
  np_sema_type_check, np_hir_lowering, np_sema_runtime_vars,
  np_sema_string_ownership,
  nextpas.core.mem.intf,
  nextpas.core.collections.vec,
  nextpas.core.collections.hashmap;

{$I np_sema_analyzer_types.inc}

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
  TCachedSymbolEntryVec = specialize TVec<TCachedSymbolEntry>;

  TCachedUnitSymbols = record
    SourcePath: string;
    FileAge: Int64;
    Symbols: TCachedSymbolEntryVec;
  end;
  PCachedUnitSymbols = ^TCachedUnitSymbols;
  TCachedUnitSymbolsVec = specialize TVec<TCachedUnitSymbols>;

var
  GImportedUnitCache: TCachedUnitSymbolsVec = nil;
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

function OwnershipBridge_EffectiveRuntimeCalleeName(const ACtx: Pointer;
  const AName: string): string;
begin
  Result := TSemanticAnalyzer(ACtx).EffectiveRuntimeCalleeName(AName, nil);
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
  Ctx.EffectiveRuntimeCalleeName := @OwnershipBridge_EffectiveRuntimeCalleeName;
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

procedure EnsureImportedUnitCache;
begin
  if GImportedUnitCache = nil then
    GImportedUnitCache := TCachedUnitSymbolsVec.Create;
end;

function FindCachedUnit(const APath: string; AAge: Int64): LongInt;
var
  I: LongInt;
begin
  Result := -1;
  if GImportedUnitCache = nil then
    Exit;
  for I := 0 to LongInt(GImportedUnitCache.Count) - 1 do
    if SameText(GImportedUnitCache[I].SourcePath, APath) and
      (GImportedUnitCache[I].FileAge = AAge) then
      Exit(I);
end;

function AppendImportedUnitCacheEntry(
  const ASourcePath: string;
  const AAge: Int64;
  const ASymbolCount: LongInt
): PCachedUnitSymbols;
var
  Entry: TCachedUnitSymbols;
begin
  EnsureImportedUnitCache;
  Entry := Default(TCachedUnitSymbols);
  Entry.SourcePath := ASourcePath;
  Entry.FileAge := AAge;
  if ASymbolCount > 0 then
    Entry.Symbols := TCachedSymbolEntryVec.Create(SizeUInt(ASymbolCount))
  else
    Entry.Symbols := TCachedSymbolEntryVec.Create;
  GImportedUnitCache.Push(Entry);
  Result := GImportedUnitCache.GetPtr(GImportedUnitCache.Count - 1);
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

{ Strips every modifier prefix the parser can emit (var:/out:/constref:, see
  ParseParameterList) — not just the by-ref ones. constref params already get a
  ptr ABI like plain record params, so they only need the clean name; leaving
  the prefix on made the body reference (aLeaf0) miss its registration and
  residual-call @aLeaf0(). }
function StripParamModifier(const AName: string): string;
begin
  Result := AName;
  if ParamNameIsByRef(AName) then
    Result := Copy(AName, 5, Length(AName))
  else if Pos('constref:', AName) = 1 then
    Result := Copy(AName, 10, Length(AName));
end;

constructor TSemanticAnalyzer.Create(
  const ARootAst: TAstFacade;
  const AUnitGraph: TUnitGraph;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId;
  const ANoFold: Boolean;
  const AAllocator: IAllocator
);
begin
  inherited Create;
  FRootAst := ARootAst;
  FUnitGraph := AUnitGraph;
  FDiagnostics := ADiagnostics;
  FRootFileId := ARootFileId;
  FNoFold := ANoFold;
  FSeedingBodiesActive := False;
  FAllocator := AAllocator;
  FModel := TSemanticModel.Create;
  FBlockLabelCounter := 0;
  FCurrentScopeId := 0;
  FProcedureBodyNameFirst := nil;
  FProcedureBodyNameNext := nil;
  FSeedCallVisitCount := 0;
  if FAllocator <> nil then
  begin
    FBreakLabels := specialize TVec<string>.Create(0, FAllocator);
    FContinueLabels := specialize TVec<string>.Create(0, FAllocator);
    FInliningStack := specialize TVec<string>.Create(0, FAllocator);
    FGenericCache := specialize TVec<TGenericCacheEntry>.Create(0, FAllocator);
    FCompilerProcNames := specialize TVec<string>.Create(0, FAllocator);
    FGenericWorkQueue := specialize TVec<LongInt>.Create(0, FAllocator);
    FPendingSignatures := TPendingSignatureVec.Create(0, FAllocator);
    FProcedureBodies := TProcedureBodyVec.Create(0, FAllocator);
    FProcedureBodyNameNext := TProcedureBodyNameNextVec.Create(0, FAllocator);
    FImportedUnitOwners := TSemaImportedOwnerVec.Create(0, FAllocator);
    FImportedUnitTrees := TSemaImportedTreeVec.Create(0, FAllocator);
  end
  else
  begin
    FBreakLabels := specialize TVec<string>.Create;
    FContinueLabels := specialize TVec<string>.Create;
    { FVarParamNames now managed by FRuntimeVars }
    FInliningStack := specialize TVec<string>.Create;
    FGenericCache := specialize TVec<TGenericCacheEntry>.Create;
    FCompilerProcNames := specialize TVec<string>.Create;
    FGenericWorkQueue := specialize TVec<LongInt>.Create;
    FPendingSignatures := TPendingSignatureVec.Create;
    FProcedureBodies := TProcedureBodyVec.Create;
    FProcedureBodyNameNext := TProcedureBodyNameNextVec.Create;
    FImportedUnitOwners := TSemaImportedOwnerVec.Create;
    FImportedUnitTrees := TSemaImportedTreeVec.Create;
  end;
  FProcedureBodyNameFirst := TProcedureBodyNameFirstMap.Create;
  FBuiltinRegistry := TBuiltinRegistry.Create;
  FRuntimeVars := TSemaRuntimeVarRegistry.Create(FAllocator);
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
  DeclCandidateCount: LongInt;
  DeclCandidateId: LongInt;
  DeclSymbolId: LongInt;
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
