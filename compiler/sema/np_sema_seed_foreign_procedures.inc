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

{ === Declaration processing methods (extracted to np_sema_declaration.inc) === }
