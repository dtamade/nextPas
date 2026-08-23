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

procedure TSemanticAnalyzer.SemaTrace(const AMsg: string);
var
  F: Text;
begin
  { Keep phase breadcrumbs cheap: one open/append/close is fine at phase
    boundaries, but never call this from hot AST walks. }
  Assign(F, '/tmp/nextpas-sema.progress');
  {$I-}
  Append(F);
  if IOResult <> 0 then
  begin
    Rewrite(F);
    if IOResult <> 0 then
    begin
      WriteLn(StdErr, '[sema] ', AMsg);
      Exit;
    end;
  end;
  WriteLn(F, AMsg);
  Close(F);
  {$I+}
  WriteLn(StdErr, '[sema] ', AMsg);
end;

procedure TSemanticAnalyzer.Analyze;
var
  DuplicateName: string;
begin
  SemaTrace('Analyze begin nofold=' + BoolToStr(FNoFold));
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
  SemaTrace('SeedImportedUnitBodies...');
  SeedImportedUnitBodies;
  SemaTrace('SeedImportedUnitBodies done bodies=' +
    IntToStr(LongInt(FProcedureBodies.Count)) + ' symbols=' +
    IntToStr(FModel.SymbolCount));
  SeedCachedTypeGaps;
  SemaTrace('SeedDeclarations...');
  SeedDeclarations;
  { seed 倒序令子接口先处理,父 IMT 继承缺失;必须在 ivcall 编码(SeedHaltCalls)
    之前补齐父 slots,否则 IHasher.Write 类调用 fallthrough 直呼未定义符号。 }
  FixupInterfaceParentImt;
  { record 类型别名返回形态常量后置补齐(TStringBuilder.ToString i64 假形态
    根因): 必须在调用绑定(SeedCallBindings)之前完成。 }
  FixupAliasMethodSymbols;
  { 跨单元常量别名 seed 时序: fs.pas 的 const 段处理时 error.pas 的基常量
    未登记 → 别名常量没进表 → 引用处 residual。所有单元 seed 完后补登
    (PLATFORM_FS_SHORT_READ_ERROR 3 uses)。 }
  FinalizeConstSections;
  RebindExplicitClassParents;
  CompletePendingSignatures;
  AssignScopesToSymbols;
  SemaTrace('SeedCallBindings...');
  FSeedCallVisitCount := 0;
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
  FGenericWorkQueue.Clear;
  FGenericWorkQueue.EnsureCapacity(64);
  SemaTrace('SeedHaltCalls...');
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
    SemaTrace('SeedFunctionBodies...');
    PhaseBegin('seed');
    try
      SeedFunctionBodies;
    finally
      PhaseEnd('seed');
    end;
    SemaTrace('SeedUnitLifecycleBodies...');
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
  SemaTrace('Analyze end status=' + FModel.Status);
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
  Result := nextpas.compiler.sema.overload.ResolveTypeId(Ctx, ATypeName);
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
  Result := nextpas.compiler.sema.overload.ResolveTypeIdForOwner(Ctx, ATypeName, APreferredOwnerUnitId, AAllowDirectImportSearch);
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
