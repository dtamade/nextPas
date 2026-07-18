function TCompilationSession.SyntaxStatus: string;
begin
  Result := FSyntaxStatus;
end;

function TCompilationSession.ResolutionStatus: string;
begin
  Result := FResolutionStatus;
end;

function TCompilationSession.UnitGraphStatus: string;
begin
  if FUnitGraph = nil then
    Exit('deferred');

  Result := FUnitGraph.Status;
end;

function TCompilationSession.SemanticStatus: string;
begin
  Result := FSemanticStatus;
end;

function TCompilationSession.SymbolGraphStatus: string;
begin
  if FSemanticStatus = 'ready' then
    Exit('ready');
  if FSemanticStatus = 'failure' then
    Exit('failure');

  Result := 'deferred';
end;

function TCompilationSession.TypeGraphStatus: string;
begin
  Result := SymbolGraphStatus;
end;

function TCompilationSession.TypedHirStatus: string;
begin
  Result := SymbolGraphStatus;
end;

function TCompilationSession.MirStatus: string;
begin
  Result := FMirStatus;
end;

function TCompilationSession.MirModule: TMirModule;
begin
  Result := FMirModule;
end;

function TCompilationSession.PhaseStatusOf(const AStatus: string): TPhaseStatus;
begin
  Result := StringToPhaseStatus(AStatus);
end;

function TCompilationSession.BackendPlanStatus: string;
begin
  Result := FBackendStatus;
end;

function TCompilationSession.ToolchainPlanStatus: string;
begin
  Result := FToolchainStatus;
end;

function TCompilationSession.WorkspaceRootPath: string;
begin
  if FOptions.WorkspaceModel <> nil then
    Exit(FOptions.WorkspaceModel.WorkspaceRootPath);

  Result := FOptions.BuildContext.WorkspaceRootPath;
end;

function TCompilationSession.WorkspaceDiscoveryKind: string;
begin
  if FOptions.WorkspaceModel <> nil then
    Exit(FOptions.WorkspaceModel.DiscoveryKind);

  Result := FOptions.BuildContext.WorkspaceDiscoveryKind;
end;

function TCompilationSession.WorkspaceDescriptorPath: string;
begin
  if FOptions.WorkspaceModel <> nil then
    Exit(FOptions.WorkspaceModel.WorkspaceDescriptorPath);

  Result := FOptions.BuildContext.WorkspaceDescriptorPath;
end;

function TCompilationSession.PackageManifestPath: string;
begin
  if FOptions.WorkspaceModel <> nil then
    Exit(FOptions.WorkspaceModel.PackageManifestPath);

  Result := FOptions.BuildContext.PackageManifestPath;
end;

function TCompilationSession.ArtifactRootPath: string;
begin
  if FOptions.WorkspaceModel <> nil then
    Exit(FOptions.WorkspaceModel.ArtifactRootPath);

  Result := FOptions.BuildContext.ArtifactRootPath;
end;

function TCompilationSession.OutputDirPath: string;
begin
  if FOptions.WorkspaceModel <> nil then
    Exit(FOptions.WorkspaceModel.OutputDirPath);

  Result := FOptions.BuildContext.OutputDirPath;
end;

function TCompilationSession.LexerTokenCount: LongInt;
begin
  if FLexerResult = nil then
    Exit(0);

  Result := FLexerResult.TokenCount;
end;

function TCompilationSession.GreenNodeCount: LongInt;
begin
  if FGreenTree = nil then
    Exit(0);

  Result := FGreenTree.NodeCount;
end;

function TCompilationSession.AstRootKindName: string;
begin
  if FAstFacade = nil then
    Exit('unknown');

  Result := FAstFacade.RootKindName;
end;

function TCompilationSession.AstDeclaredName: string;
begin
  if FAstFacade = nil then
    Exit('');

  Result := FAstFacade.DeclaredName;
end;

function TCompilationSession.HasSyntaxErrors: Boolean;
begin
  Result := FDiagnosticsSink.HasErrors;
end;

function TCompilationSession.HasResolutionErrors: Boolean;
begin
  Result := FResolutionStatus = 'failure';
end;

function TCompilationSession.HasSemanticErrors: Boolean;
begin
  Result := FSemanticStatus = 'failure';
end;

function TCompilationSession.HasMirErrors: Boolean;
begin
  Result := FMirStatus = 'failure';
end;

function TCompilationSession.HasBackendErrors: Boolean;
begin
  Result := FBackendStatus = 'failure';
end;

function TCompilationSession.HasToolchainErrors: Boolean;
begin
  Result := FToolchainStatus = 'failure';
end;

function TCompilationSession.SearchPathCount: LongInt;
begin
  if FSearchPathSet = nil then
    Exit(0);

  Result := FSearchPathSet.Count;
end;

function TCompilationSession.SearchIndexStatus: string;
begin
  Result := FSearchIndexStatus;
end;

function TCompilationSession.IndexedSearchRootCount: LongInt;
begin
  Result := FIndexedSearchRootCount;
end;

function TCompilationSession.SearchIndexScanCount: LongInt;
begin
  Result := FSearchIndexScanCount;
end;

function TCompilationSession.SearchPathsJson: string;
var
  Entry: TSearchPathEntry;
  EntryFields: string;
  Index: LongInt;
begin
  if FSearchPathSet = nil then
    Exit('[]');

  Result := '[';
  for Index := 0 to LongInt(FSearchPathSet.Count) - 1 do
  begin
    if Index > 0 then
      Result := Result + ',';

    Entry := FSearchPathSet.EntryAt(Index);
    EntryFields := '';
    AppendJsonField(EntryFields, 'scopeName', JsonString(Entry.ScopeName));
    AppendJsonField(
      EntryFields,
      'provenanceKind',
      JsonString(Entry.ProvenanceKind)
    );
    AppendJsonField(EntryFields, 'packageName', JsonString(Entry.PackageName));
    AppendJsonField(
      EntryFields,
      'manifestPath',
      JsonString(Entry.ManifestPath)
    );
    AppendJsonField(
      EntryFields,
      'workspaceMemberPath',
      JsonString(Entry.WorkspaceMemberPath)
    );
    AppendJsonField(EntryFields, 'rootPath', JsonString(Entry.RootPath));
    Result := Result + '{' + EntryFields + '}';
  end;
  Result := Result + ']';
end;

function TCompilationSession.ResolvedUnitCount: LongInt;
begin
  if FUnitGraph = nil then
    Exit(0);

  Result := FUnitGraph.ResolvedUnitCount;
end;

function TCompilationSession.UnitGraphEdgeCount: LongInt;
begin
  if FUnitGraph = nil then
    Exit(0);

  Result := FUnitGraph.EdgeCount;
end;

function TCompilationSession.UnitGraphRootName: string;
begin
  if FUnitGraph = nil then
    Exit('');

  Result := FUnitGraph.RootName;
end;

function TCompilationSession.SymbolCount: LongInt;
begin
  if FSemanticModel = nil then
    Exit(0);

  Result := FSemanticModel.SymbolCount;
end;

function SemanticScopeKindName(const AKind: TScopeKind): string;
begin
  case AKind of
    skCompilation:
      Result := 'compilation';
    skUnit:
      Result := 'unit';
    skInterface:
      Result := 'interface';
    skImplementation:
      Result := 'implementation';
    skCallable:
      Result := 'callable';
    skRecord:
      Result := 'record';
    skClass:
      Result := 'class';
    skBlock:
      Result := 'block';
  end;
end;

function TCompilationSession.SymbolsJson: string;
var
  Fields: string;
  Index: LongInt;
  Scope: TSemanticScope;
  Symbol: TSemanticSymbol;
  SymbolType: TSemanticType;
  UnitInfo: TResolvedUnit;
begin
  if FSemanticModel = nil then
    Exit('[]');

  Result := '[';
  for Index := 0 to FSemanticModel.SymbolCount - 1 do
  begin
    if Index > 0 then
      Result := Result + ',';

    Symbol := FSemanticModel.SymbolAt(Index);
    Fields := '';
    AppendJsonIntegerField(Fields, 'symbolId', Symbol.SymbolId, True);
    AppendJsonStringField(Fields, 'name', Symbol.Name);
    AppendJsonStringField(Fields, 'kind', Symbol.Kind);
    AppendJsonStringField(Fields, 'ownerUnitId', Symbol.OwnerUnitId);
    if (FUnitGraph <> nil) and
      FUnitGraph.FindUnit(Symbol.OwnerUnitId, UnitInfo) then
      AppendJsonStringField(Fields, 'ownerUnitName', UnitInfo.CanonicalName);
    AppendJsonIntegerField(Fields, 'scopeId', Symbol.ScopeId, True);
    if Symbol.ScopeId > 0 then
    begin
      Scope := FSemanticModel.ScopeAt(Symbol.ScopeId - 1);
      if Scope.ScopeId > 0 then
      begin
        AppendJsonStringField(
          Fields,
          'scopeKind',
          SemanticScopeKindName(Scope.Kind)
        );
        AppendJsonStringField(Fields, 'scopeName', Scope.Name);
        AppendJsonIntegerField(
          Fields,
          'scopeParentId',
          Scope.ParentScopeId,
          Scope.ParentScopeId > 0
        );
      end;
    end;
    AppendJsonIntegerField(Fields, 'typeId', Symbol.TypeId, True);
    if Symbol.TypeId > 0 then
    begin
      SymbolType := FSemanticModel.TypeAt(Symbol.TypeId - 1);
      if SymbolType.TypeId > 0 then
      begin
        AppendJsonStringField(Fields, 'typeName', SymbolType.Name);
        AppendJsonStringField(Fields, 'typeKind', SymbolType.Kind);
        AppendJsonIntegerField(
          Fields,
          'typeParentId',
          SymbolType.ParentTypeId,
          SymbolType.ParentTypeId > 0
        );
      end;
    end;
    AppendJsonIntegerField(
      Fields,
      'paramCount',
      Symbol.ParamCount,
      Symbol.ParamCount >= 0
    );
    if Symbol.ParamSignature <> '' then
      AppendJsonStringField(Fields, 'paramSignature', Symbol.ParamSignature);
    AppendJsonIntegerField(Fields, 'byteOffset', Symbol.ByteOffset, True);

    Result := Result + '{' + Fields + '}';
  end;
  Result := Result + ']';
end;

function TCompilationSession.BindingsJson: string;
var
  Binding: TSemanticBinding;
  Fields: string;
  Index: LongInt;
begin
  if FSemanticModel = nil then
    Exit('[]');

  Result := '[';
  for Index := 0 to FSemanticModel.BindingCount - 1 do
  begin
    if Index > 0 then
      Result := Result + ',';

    Binding := FSemanticModel.BindingAt(Index);
    Fields := '';
    AppendJsonIntegerField(Fields, 'bindingId', Binding.BindingId, True);
    AppendJsonStringField(Fields, 'kind', Binding.Kind);
    AppendJsonStringField(Fields, 'name', Binding.Name);
    AppendJsonStringField(Fields, 'ownerUnitId', Binding.OwnerUnitId);
    AppendJsonIntegerField(Fields, 'byteOffset', Binding.ByteOffset, True);
    AppendJsonIntegerField(
      Fields,
      'targetSymbolId',
      Binding.TargetSymbolId,
      True
    );

    Result := Result + '{' + Fields + '}';
  end;
  Result := Result + ']';
end;

function TCompilationSession.DefinitionsJson: string;
var
  Binding: TSemanticBinding;
  EntryJson: string;
  Fields: string;
  Index: LongInt;
  TargetSymbol: TSemanticSymbol;
  TargetUnit: TResolvedUnit;
begin
  if FSemanticModel = nil then
    Exit('[]');

  EntryJson := '';
  for Index := 0 to FSemanticModel.BindingCount - 1 do
  begin
    Binding := FSemanticModel.BindingAt(Index);
    if (Binding.TargetSymbolId <= 0) or
      (Binding.TargetSymbolId > FSemanticModel.SymbolCount) then
      Continue;

    TargetSymbol := FSemanticModel.SymbolAt(Binding.TargetSymbolId - 1);
    if TargetSymbol.SymbolId <> Binding.TargetSymbolId then
      Continue;

    if EntryJson <> '' then
      EntryJson := EntryJson + ',';

    Fields := '';
    AppendJsonIntegerField(Fields, 'bindingId', Binding.BindingId, True);
    AppendJsonStringField(Fields, 'bindingKind', Binding.Kind);
    AppendJsonStringField(Fields, 'bindingName', Binding.Name);
    AppendJsonStringField(Fields, 'bindingOwnerUnitId', Binding.OwnerUnitId);
    AppendJsonIntegerField(
      Fields,
      'bindingByteOffset',
      Binding.ByteOffset,
      True
    );
    AppendJsonIntegerField(
      Fields,
      'targetSymbolId',
      Binding.TargetSymbolId,
      True
    );
    AppendJsonStringField(Fields, 'targetName', TargetSymbol.Name);
    AppendJsonStringField(Fields, 'targetKind', TargetSymbol.Kind);
    AppendJsonIntegerField(
      Fields,
      'targetParamCount',
      TargetSymbol.ParamCount,
      TargetSymbol.ParamCount >= 0
    );
    if TargetSymbol.ParamSignature <> '' then
      AppendJsonStringField(
        Fields,
        'targetParamSignature',
        TargetSymbol.ParamSignature
      );
    AppendJsonStringField(
      Fields,
      'targetOwnerUnitId',
      TargetSymbol.OwnerUnitId
    );
    if (FUnitGraph <> nil) and
      FUnitGraph.FindUnit(TargetSymbol.OwnerUnitId, TargetUnit) then
    begin
      AppendJsonStringField(
        Fields,
        'targetOwnerUnitName',
        TargetUnit.CanonicalName
      );
      AppendJsonStringField(Fields, 'targetSourcePath', TargetUnit.SourcePath);
    end;
    AppendJsonIntegerField(
      Fields,
      'targetByteOffset',
      TargetSymbol.ByteOffset,
      True
    );

    EntryJson := EntryJson + '{' + Fields + '}';
  end;

  Result := '[' + EntryJson + ']';
end;

function TCompilationSession.ScopeCount: LongInt;
begin
  if FSemanticModel = nil then
    Exit(0);

  Result := FSemanticModel.ScopeCount;
end;

function TCompilationSession.ScopesJson: string;
var
  Fields: string;
  Index: LongInt;
  Scope: TSemanticScope;
begin
  if FSemanticModel = nil then
    Exit('[]');

  Result := '[';
  for Index := 0 to FSemanticModel.ScopeCount - 1 do
  begin
    if Index > 0 then
      Result := Result + ',';

    Scope := FSemanticModel.ScopeAt(Index);
    Fields := '';
    AppendJsonIntegerField(Fields, 'scopeId', Scope.ScopeId, True);
    AppendJsonStringField(Fields, 'kind', SemanticScopeKindName(Scope.Kind));
    AppendJsonStringField(Fields, 'name', Scope.Name);
    AppendJsonIntegerField(
      Fields,
      'parentScopeId',
      Scope.ParentScopeId,
      Scope.ParentScopeId > 0
    );

    Result := Result + '{' + Fields + '}';
  end;
  Result := Result + ']';
end;

function TCompilationSession.TypeCount: LongInt;
begin
  if FSemanticModel = nil then
    Exit(0);

  Result := FSemanticModel.TypeCount;
end;

function TCompilationSession.TypesJson: string;
var
  Fields: string;
  Index: LongInt;
  SymbolType: TSemanticType;
begin
  if FSemanticModel = nil then
    Exit('[]');

  Result := '[';
  for Index := 0 to FSemanticModel.TypeCount - 1 do
  begin
    if Index > 0 then
      Result := Result + ',';

    SymbolType := FSemanticModel.TypeAt(Index);
    Fields := '';
    AppendJsonIntegerField(Fields, 'typeId', SymbolType.TypeId, True);
    AppendJsonStringField(Fields, 'name', SymbolType.Name);
    AppendJsonStringField(Fields, 'kind', SymbolType.Kind);
    AppendJsonIntegerField(
      Fields,
      'parentTypeId',
      SymbolType.ParentTypeId,
      SymbolType.ParentTypeId > 0
    );

    Result := Result + '{' + Fields + '}';
  end;
  Result := Result + ']';
end;

function TCompilationSession.TypedHirNodeCount: LongInt;
begin
  if FSemanticModel = nil then
    Exit(0);

  Result := FSemanticModel.TypedHirNodeCount;
end;

function TCompilationSession.RuntimeContractCount: LongInt;
begin
  if FSemanticModel = nil then
    Exit(0);

  Result := FSemanticModel.RuntimeContractCount;
end;

function TCompilationSession.TypedHirRootName: string;
begin
  if FSemanticModel = nil then
    Exit('');

  Result := FSemanticModel.RootName;
end;

function TCompilationSession.MirBlockCount: LongInt;
begin
  Result := 0;
end;

function TCompilationSession.MirOperationCount: LongInt;
begin
  Result := 0;
end;

function TCompilationSession.MirEntryBlockLabel: string;
begin
  Result := '';
end;

function TCompilationSession.MirRootName: string;
begin
  if FSemanticModel = nil then
    Exit('');
  Result := FSemanticModel.RootName;
end;

function TCompilationSession.BackendOutputKind: string;
begin
  if FBackendPlan = nil then
    Exit('');

  Result := FBackendPlan.OutputKind;
end;

function TCompilationSession.BackendPrimaryArtifactKind: string;
begin
  if FBackendPlan = nil then
    Exit('');

  Result := FBackendPlan.PrimaryArtifactKind;
end;

function TCompilationSession.BackendPrimaryArtifactPath: string;
begin
  if FBackendPlan = nil then
    Exit('');

  Result := FBackendPlan.PrimaryArtifactPath;
end;

function TCompilationSession.BackendArtifactCount: LongInt;
begin
  if FBackendPlan = nil then
    Exit(0);

  Result := FBackendPlan.ArtifactCount;
end;

function TCompilationSession.BackendArtifactsJson: string;
begin
  if FBackendPlan = nil then
    Exit('');

  Result := FBackendPlan.ArtifactsJson;
end;

function TCompilationSession.HostId: string;
begin
  if FBackendPlan <> nil then
    Exit(FBackendPlan.HostId);

  Result := FTargetFacts.HostId;
end;

function TCompilationSession.ToolchainBindingId: string;
begin
  if FBackendPlan <> nil then
    Exit(FBackendPlan.ToolchainBindingId);

  Result := FTargetFacts.ToolchainBindingId;
end;

function TCompilationSession.BackendFamily: string;
begin
  if FBackendPlan <> nil then
    Exit(FBackendPlan.BackendFamily);

  Result := FTargetFacts.BackendFamily;
end;

function TCompilationSession.AssemblerProfileId: string;
begin
  if FBackendPlan <> nil then
    Exit(FBackendPlan.AssemblerProfileId);

  Result := FTargetFacts.AssemblerProfileId;
end;

function TCompilationSession.LinkerProfileId: string;
begin
  if FBackendPlan <> nil then
    Exit(FBackendPlan.LinkerProfileId);

  Result := FTargetFacts.LinkerProfileId;
end;

function TCompilationSession.ArchiverProfileId: string;
begin
  if FBackendPlan <> nil then
    Exit(FBackendPlan.ArchiverProfileId);

  Result := FTargetFacts.ArchiverProfileId;
end;

function TCompilationSession.ResourceToolProfileId: string;
begin
  if FBackendPlan <> nil then
    Exit(FBackendPlan.ResourceToolProfileId);

  Result := FTargetFacts.ResourceToolProfileId;
end;

function TCompilationSession.TargetObjectFormat: string;
begin
  if FBackendPlan <> nil then
    Exit(FBackendPlan.ObjectFormat);

  Result := FTargetFacts.ObjectFormat;
end;

function TCompilationSession.TargetAssemblerFlavor: string;
begin
  if FBackendPlan <> nil then
    Exit(FBackendPlan.AssemblerFlavor);

  Result := FTargetFacts.AssemblerFlavor;
end;

function TCompilationSession.TargetLinkerFlavor: string;
begin
  if FBackendPlan <> nil then
    Exit(FBackendPlan.LinkerFlavor);

  Result := FTargetFacts.LinkerFlavor;
end;

function TCompilationSession.TargetRuntimeLayoutKey: string;
begin
  if FBackendPlan <> nil then
    Exit(FBackendPlan.RuntimeLayoutKey);

  Result := FTargetFacts.RuntimeLayoutKey;
end;

function TCompilationSession.TargetCSymbolPrefix: string;
begin
  if FBackendPlan <> nil then
    Exit(FBackendPlan.TargetCSymbolPrefix);

  Result := FTargetFacts.CSymbolPrefix;
end;

function TCompilationSession.TargetCLibraryNaming: string;
begin
  if FBackendPlan <> nil then
    Exit(FBackendPlan.TargetCLibraryNaming);

  Result := FTargetFacts.CLibraryNaming;
end;

function TCompilationSession.TargetLlvmTriple: string;
begin
  if FBackendPlan <> nil then
    Exit(FBackendPlan.LlvmTriple);

  Result := FTargetFacts.LlvmTriple;
end;

function TCompilationSession.TargetLlvmDataLayout: string;
begin
  if FBackendPlan <> nil then
    Exit(FBackendPlan.LlvmDataLayout);

  Result := FTargetFacts.LlvmDataLayout;
end;

function TCompilationSession.SysrootMode: string;
begin
  if FBackendPlan <> nil then
    Exit(FBackendPlan.SysrootMode);

  Result := FTargetFacts.SysrootMode;
end;

function TCompilationSession.RuntimeSdkId: string;
begin
  if FBackendPlan <> nil then
    Exit(FBackendPlan.RuntimeSdkId);

  Result := FTargetFacts.RuntimeSdkId;
end;

function TCompilationSession.AllowHostFallback: Boolean;
begin
  if FBackendPlan <> nil then
    Exit(FBackendPlan.AllowHostFallback);

  Result := FTargetFacts.AllowHostFallback;
end;

function TCompilationSession.ToolRootKind: string;
begin
  if FBackendPlan <> nil then
    Exit(FBackendPlan.ToolRootKind);

  Result := FTargetFacts.ToolRootKind;
end;

function TCompilationSession.RuntimeRootKind: string;
begin
  if FBackendPlan <> nil then
    Exit(FBackendPlan.RuntimeRootKind);

  Result := FTargetFacts.RuntimeRootKind;
end;

function TCompilationSession.ResponseFilePolicy: string;
begin
  if FBackendPlan <> nil then
    Exit(FBackendPlan.ResponseFilePolicy);

  Result := FTargetFacts.ResponseFilePolicy;
end;

function TCompilationSession.LinkScriptPolicy: string;
begin
  if FBackendPlan <> nil then
    Exit(FBackendPlan.LinkScriptPolicy);

  Result := FTargetFacts.LinkScriptPolicy;
end;

function TCompilationSession.ToolchainPlanFamily: string;
begin
  if FToolchainPlan = nil then
    Exit('');

  Result := FToolchainPlan.PlanFamily;
end;

function TCompilationSession.ToolProfileRoot: string;
begin
  if FToolchainPlan = nil then
    Exit('');

  Result := FToolchainPlan.ToolProfileRoot;
end;

function TCompilationSession.LogicalLinkRequestStatus: string;
begin
  if FToolchainPlan = nil then
    Exit('deferred');

  Result := FToolchainPlan.LogicalLinkRequestStatus;
end;

function TCompilationSession.LogicalLinkRequestOutputKind: string;
begin
  if FToolchainPlan = nil then
    Exit('');

  Result := FToolchainPlan.LogicalLinkRequestOutputKind;
end;

function TCompilationSession.LogicalLibraryRequestCount: LongInt;
begin
  if FToolchainPlan = nil then
    Exit(0);

  Result := FToolchainPlan.LogicalLibraryRequestCount;
end;

function TCompilationSession.LogicalLinkRequestJson: string;
begin
  if FToolchainPlan = nil then
    Exit('');

  Result := FToolchainPlan.LogicalLinkRequestJson;
end;

function TCompilationSession.LlvmToolchainStatus: string;
begin
  if FToolchainPlan = nil then
  begin
    if FTargetFacts.LlvmEnabled then
      Exit('deferred');
    Exit('disabled');
  end;

  Result := FToolchainPlan.LlvmToolchainStatus;
end;

function TCompilationSession.LlvmExecutableSetId: string;
begin
  if FToolchainPlan <> nil then
    Exit(FToolchainPlan.LlvmExecutableSetId);

  Result := FTargetFacts.LlvmExecutableSetId;
end;

function TCompilationSession.LlvmExecutableSetJson: string;
begin
  if FToolchainPlan = nil then
    Exit('');

  Result := FToolchainPlan.LlvmExecutableSetJson;
end;

function TCompilationSession.PrimaryToolProfileId: string;
begin
  if FToolchainPlan = nil then
    Exit(FTargetFacts.HostCompilerProfileId);

  Result := FToolchainPlan.PrimaryToolProfileId;
end;

function TCompilationSession.PrimaryToolStepId: string;
begin
  if FToolchainPlan = nil then
    Exit('');

  Result := FToolchainPlan.PrimaryToolStepId;
end;

function TCompilationSession.PrimaryToolLogicalExecutable: string;
begin
  if FToolchainPlan = nil then
    Exit('');

  Result := FToolchainPlan.PrimaryToolLogicalExecutable;
end;

function TCompilationSession.PrimaryToolSysrootRef: string;
begin
  if FToolchainPlan = nil then
    Exit('');

  Result := FToolchainPlan.PrimaryToolSysrootRef;
end;

function TCompilationSession.PrimaryToolFailureMapping: string;
begin
  if FToolchainPlan = nil then
    Exit('');

  Result := FToolchainPlan.PrimaryToolFailureMapping;
end;

function TCompilationSession.PrimaryToolWorkingDirectory: string;
begin
  if FToolchainPlan = nil then
    Exit('');

  Result := FToolchainPlan.PrimaryToolWorkingDirectory;
end;

function TCompilationSession.PrimaryToolArgCount: LongInt;
begin
  if FToolchainPlan = nil then
    Exit(0);

  Result := FToolchainPlan.PrimaryToolArgCount;
end;

function TCompilationSession.PrimaryToolArgValue(const AIndex: LongInt): string;
begin
  if FToolchainPlan = nil then
    Exit('');

  Result := FToolchainPlan.PrimaryToolArgValue(AIndex);
end;

function TCompilationSession.ToolInvocationCount: LongInt;
begin
  if FToolchainPlan = nil then
    Exit(0);

  Result := FToolchainPlan.ToolInvocationCount;
end;

function TCompilationSession.ToolRunStatus: string;
begin
  Result := FToolRunStatus;
end;

function TCompilationSession.ToolRunStepCount: LongInt;
begin
  Result := FToolRunStepCount;
end;

function TCompilationSession.PrimaryToolRunStatus: string;
begin
  Result := FPrimaryToolRunStatus;
end;

function TCompilationSession.PrimaryToolRole: string;
begin
  if FToolchainPlan = nil then
    Exit('');

  Result := FToolchainPlan.PrimaryToolRole;
end;

function TCompilationSession.SourceFileCount: LongInt;
begin
  Result := FSourceDatabase.FileCount;
end;

function TCompilationSession.DiagnosticsCount: LongInt;
begin
  Result := FDiagnosticsSink.TotalCount;
end;

function TCompilationSession.DiagnosticsErrorCount: LongInt;
begin
  Result := FDiagnosticsSink.ErrorCount;
end;

function TCompilationSession.DiagnosticsWarningCount: LongInt;
begin
  Result := FDiagnosticsSink.WarningCount;
end;

function TCompilationSession.DiagnosticsPolicyName: string;
begin
  Result := FDiagnosticsSink.PolicyName;
end;

function TCompilationSession.DiagnosticsJson: string;
begin
  Result := FDiagnosticsSink.DiagnosticsJson;
end;

function TCompilationSession.DiagnosticsSummary: string;
begin
  Result := FDiagnosticsSink.Summary;
end;

function TCompilationSession.ToolStatusEventCount: LongInt;
begin
  if FToolStatusEvents = nil then
    Exit(0);
  Result := LongInt(FToolStatusEvents.Count);
end;

function TCompilationSession.ToolStatusEventsJson: string;
var
  EventFields: string;
  Index: SizeInt;
  Event: ^TToolStatusEventRecord;
begin
  if (FToolStatusEvents = nil) or (FToolStatusEvents.Count = 0) then
    Exit('');

  Result := '[';
  for Index := 0 to SizeInt(FToolStatusEvents.Count) - 1 do
  begin
    if Index > 0 then
      Result := Result + ',';

    Event := FToolStatusEvents.GetPtr(SizeUInt(Index));
    EventFields := '';
    AppendJsonField(
      EventFields,
      'eventKind',
      JsonString(Event^.EventKind)
    );
    AppendJsonField(EventFields, 'sessionId', JsonString(FSessionId));
    AppendJsonField(EventFields, 'planId', JsonString(BuildTracePlanId));
    AppendJsonField(EventFields, 'bindingId', JsonString(ToolchainBindingId));
    AppendJsonField(EventFields, 'hostId', JsonString(HostId));
    AppendJsonField(EventFields, 'targetId', JsonString(FTargetFacts.TargetId));
    AppendJsonField(
      EventFields,
      'profileId',
      JsonString(Event^.ProfileId)
    );
    AppendJsonField(
      EventFields,
      'stepId',
      JsonString(Event^.StepId)
    );
    AppendJsonField(
      EventFields,
      'toolRole',
      JsonString(Event^.ToolRole)
    );
    AppendJsonField(
      EventFields,
      'logicalExecutable',
      JsonString(Event^.LogicalExecutable)
    );
    AppendJsonField(
      EventFields,
      'sysrootRef',
      JsonString(Event^.SysrootRef)
    );
    if Event^.ResolvedPath <> '' then
      AppendJsonField(
        EventFields,
        'resolvedPath',
        JsonString(Event^.ResolvedPath)
      );
    if Event^.Status <> '' then
      AppendJsonField(
        EventFields,
        'status',
        JsonString(Event^.Status)
      );
    if Event^.ResultValue <> '' then
      AppendJsonField(
        EventFields,
        'result',
        JsonString(Event^.ResultValue)
      );
    if Event^.HasExitCode then
      AppendJsonField(
        EventFields,
        'exitCode',
        IntToStr(Event^.ExitCode)
      );
    if Event^.Summary <> '' then
      AppendJsonField(
        EventFields,
        'summary',
        JsonString(Event^.Summary)
      );
    Result := Result + '{' + EventFields + '}';
  end;
  Result := Result + ']';
end;

function TCompilationSession.ToolInvocationPlanRef: string;
begin
  if (FToolchainPlan = nil) or (FToolchainPlan.ToolInvocationCount = 0) then
    Exit('');

  Result := BuildTracePlanId;
end;

function TCompilationSession.ToolInvocationPlanJson: string;
begin
  if (FToolchainPlan = nil) or (FToolchainPlan.ToolInvocationCount = 0) then
    Exit('');

  Result := FToolchainPlan.ToolInvocationPlanJson(
    ToolInvocationPlanRef,
    PrimaryToolResolvedPath
  );
end;

function TCompilationSession.LastDiagnosticId: string;
begin
  Result := FDiagnosticsSink.LastDiagnosticId;
end;

function TCompilationSession.LastDiagnosticCode: string;
begin
  Result := FDiagnosticsSink.LastDiagnosticCode;
end;

function TCompilationSession.LastDiagnosticPhase: string;
begin
  Result := FDiagnosticsSink.LastDiagnosticPhase;
end;

function TCompilationSession.LastDiagnosticMessage: string;
begin
  Result := FDiagnosticsSink.LastDiagnosticMessage;
end;

function TCompilationSession.LastDiagnosticBindingId: string;
begin
  Result := FDiagnosticsSink.LastDiagnosticBindingId;
end;

function TCompilationSession.LastDiagnosticProfileId: string;
begin
  Result := FDiagnosticsSink.LastDiagnosticProfileId;
end;

function TCompilationSession.LastDiagnosticStepId: string;
begin
  Result := FDiagnosticsSink.LastDiagnosticStepId;
end;

function TCompilationSession.LastDiagnosticLogicalExecutable: string;
begin
  Result := FDiagnosticsSink.LastDiagnosticLogicalExecutable;
end;

function TCompilationSession.LastDiagnosticSysrootRef: string;
begin
  Result := FDiagnosticsSink.LastDiagnosticSysrootRef;
end;

function TCompilationSession.LastDiagnosticResolvedPath: string;
begin
  Result := FDiagnosticsSink.LastDiagnosticResolvedPath;
end;

function TCompilationSession.LastDiagnosticPrimaryArtifactKind: string;
begin
  Result := FDiagnosticsSink.LastDiagnosticPrimaryArtifactKind;
end;

function TCompilationSession.LastDiagnosticPrimaryArtifactPath: string;
begin
  Result := FDiagnosticsSink.LastDiagnosticPrimaryArtifactPath;
end;

function TCompilationSession.LastDiagnosticExitCode: LongInt;
begin
  Result := FDiagnosticsSink.LastDiagnosticExitCode;
end;

function TCompilationSession.HasLastDiagnosticExitCode: Boolean;
begin
  Result := FDiagnosticsSink.HasLastDiagnosticExitCode;
end;

function TCompilationSession.BuildTraceRef: string;
begin
  Result := FBuildTraceRef;
end;

function TCompilationSession.BuildTraceJson: string;
begin
  Result := FBuildTraceJson;
end;

function TCompilationSession.SessionLifetimeSummary: string;
begin
  Result := 'source-db,target-facts,diagnostics-sink,compilation-options';
end;

function TCompilationSession.UnitLifetimeSummary: string;
begin
  Result := 'root-input-state';
end;

function TCompilationSession.StageLifetimeSummary: string;
begin
  Result :=
    'syntax:' + FSyntaxStatus +
    ',resolution:' + FResolutionStatus +
    ',sema:' + FSemanticStatus +
    ',ir:' + FMirStatus +
    ',backend:' + FBackendStatus +
    ',toolchain:' + FToolchainStatus;
end;

