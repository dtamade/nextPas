unit nextpas_projection_json;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, nextpas_projection_types, nextpas_json_helpers;

procedure AppendBuildContextProjectionJsonFields(
  var AFields: string;
  const AContext: TBuildCommandContext
);
procedure AppendSessionProjectionJsonFields(
  var AFields: string;
  const ASession: TSessionProjectionContext;
  const ADiagnostics: TDiagnosticProjectionContext;
  const AHasSession: Boolean
);
procedure AppendSyntaxProjectionJsonFields(
  var AFields: string;
  const AContext: TSyntaxProjectionContext;
  const AHasSyntax: Boolean
);
procedure AppendResolutionProjectionJsonFields(
  var AFields: string;
  const AContext: TResolutionProjectionContext;
  const AHasResolution: Boolean
);
procedure AppendSemanticProjectionJsonFields(
  var AFields: string;
  const AContext: TSemanticProjectionContext;
  const AHasSemantic: Boolean
);
procedure AppendMirProjectionJsonFields(
  var AFields: string;
  const AContext: TMirProjectionContext;
  const AHasMir: Boolean
);
procedure AppendBackendProjectionJsonFields(
  var AFields: string;
  const AContext: TBackendProjectionContext
);
procedure AppendToolchainProjectionJsonFields(
  var AFields: string;
  const AContext: TToolchainProjectionContext;
  const AHasSession: Boolean;
  const AHasBackend: Boolean
);
procedure AppendEnvironmentProjectionJsonFields(
  var AFields: string;
  const AContext: TEnvironmentProjectionContext
);
procedure AppendDoctorProjectionJsonFields(
  var AFields: string;
  const AContext: TDoctorProjectionContext
);
procedure AppendQueryProjectionJsonFields(
  var AFields: string;
  const AContext: TQueryProjectionContext
);
procedure AppendPackageProjectionJsonFields(
  var AFields: string;
  const AContext: TPackageProjectionContext
);

function BuildCommandEnvelopeJson(
  const AState: TNextPasState;
  const AExitCode: LongInt;
  const ASelector: string;
  const AStatusValue: string;
  const ABuildResult: string;
  const AFailureKind: string;
  const AHumanSummary: string
): string;

procedure PrintCommandEnvelope(
  const AState: TNextPasState;
  const AExitCode: LongInt;
  const ASelector: string;
  const AStatusValue: string;
  const ABuildResult: string;
  const AFailureKind: string;
  const AHumanSummary: string;
  const AUseStdErr: Boolean
);

implementation

procedure AppendBuildContextProjectionJsonFields(
  var AFields: string;
  const AContext: TBuildCommandContext
);
begin
  AppendJsonStringField(AFields, 'source', AContext.SourcePath);
  AppendJsonStringField(AFields, 'target', AContext.TargetName);
  AppendJsonStringField(AFields, 'workspaceRoot', AContext.WorkspaceRootPath);
  AppendJsonStringField(
    AFields,
    'workspaceDiscoveryKind',
    AContext.WorkspaceDiscoveryKind
  );
  AppendJsonStringField(
    AFields,
    'workspaceDescriptorPath',
    AContext.WorkspaceDescriptorPath
  );
  AppendJsonStringField(
    AFields,
    'packageManifestPath',
    AContext.PackageManifestPath
  );
  AppendJsonStringField(AFields, 'artifactRoot', AContext.ArtifactRootPath);
  AppendJsonStringField(AFields, 'outputDir', AContext.OutputDirPath);
  AppendJsonStringField(AFields, 'targetConfig', AContext.TargetConfigPath);
  AppendJsonStringField(AFields, 'compiler', AContext.CompilerName);
  AppendJsonIntegerField(
    AFields,
    'compilerExit',
    AContext.CompilerExitCode,
    AContext.HasCompilerExitCode
  );
  AppendJsonStringField(AFields, 'artifact', AContext.ArtifactPath);
end;

procedure AppendSessionProjectionJsonFields(
  var AFields: string;
  const ASession: TSessionProjectionContext;
  const ADiagnostics: TDiagnosticProjectionContext;
  const AHasSession: Boolean
);
begin
  AppendJsonStringField(AFields, 'sessionId', ASession.SessionId);
  AppendJsonIntegerField(
    AFields,
    'rootFileId',
    ASession.RootFileId,
    ASession.RootFileId > 0
  );
  AppendJsonIntegerField(
    AFields,
    'sourceFileCount',
    ASession.SourceFileCount,
    ASession.SourceFileCount > 0
  );
  AppendJsonStringField(
    AFields,
    'sourceLineIndexState',
    ASession.SourceLineIndexState
  );
  AppendJsonIntegerField(
    AFields,
    'unitStateCount',
    ASession.UnitStateCount,
    ASession.UnitStateCount > 0
  );
  AppendJsonIntegerField(
    AFields,
    'diagnosticCount',
    ADiagnostics.Count,
    AHasSession
  );
  AppendJsonIntegerField(
    AFields,
    'diagnosticErrorCount',
    ADiagnostics.ErrorCount,
    AHasSession
  );
  AppendJsonIntegerField(
    AFields,
    'diagnosticWarningCount',
    ADiagnostics.WarningCount,
    AHasSession
  );
  AppendJsonStringField(AFields, 'diagnosticsPolicy', ADiagnostics.Policy);
  AppendJsonStringField(AFields, 'sessionLifetime', ASession.SessionLifetime);
  AppendJsonStringField(AFields, 'unitLifetime', ASession.UnitLifetime);
  AppendJsonStringField(AFields, 'stageLifetime', ASession.StageLifetime);
end;

procedure AppendSyntaxProjectionJsonFields(
  var AFields: string;
  const AContext: TSyntaxProjectionContext;
  const AHasSyntax: Boolean
);
begin
  AppendJsonStringField(AFields, 'syntaxStatus', AContext.Status);
  AppendJsonIntegerField(
    AFields,
    'lexerTokenCount',
    AContext.LexerTokenCount,
    AHasSyntax
  );
  AppendJsonIntegerField(
    AFields,
    'greenNodeCount',
    AContext.GreenNodeCount,
    AHasSyntax
  );
  AppendJsonStringField(AFields, 'astRootKind', AContext.AstRootKind);
  AppendJsonStringField(AFields, 'astDeclaredName', AContext.AstDeclaredName);
end;

procedure AppendResolutionProjectionJsonFields(
  var AFields: string;
  const AContext: TResolutionProjectionContext;
  const AHasResolution: Boolean
);
begin
  AppendJsonStringField(AFields, 'resolutionStatus', AContext.Status);
  AppendJsonStringField(AFields, 'unitGraphStatus', AContext.UnitGraphStatus);
  AppendJsonIntegerField(
    AFields,
    'searchPathCount',
    AContext.SearchPathCount,
    AHasResolution
  );
  AppendJsonStringField(AFields, 'searchIndexStatus', AContext.SearchIndexStatus);
  AppendJsonIntegerField(
    AFields,
    'indexedSearchRootCount',
    AContext.IndexedSearchRootCount,
    AHasResolution
  );
  AppendJsonIntegerField(
    AFields,
    'searchIndexScanCount',
    AContext.SearchIndexScanCount,
    AHasResolution
  );
  if AContext.SearchPathJson <> '' then
    AppendJsonField(AFields, 'searchPaths', AContext.SearchPathJson);
  AppendJsonIntegerField(
    AFields,
    'resolvedUnitCount',
    AContext.ResolvedUnitCount,
    AHasResolution
  );
  AppendJsonIntegerField(
    AFields,
    'unitGraphEdgeCount',
    AContext.UnitGraphEdgeCount,
    AHasResolution
  );
  AppendJsonStringField(AFields, 'unitGraphRootName', AContext.UnitGraphRootName);
end;

procedure AppendSemanticProjectionJsonFields(
  var AFields: string;
  const AContext: TSemanticProjectionContext;
  const AHasSemantic: Boolean
);
begin
  AppendJsonStringField(AFields, 'semanticStatus', AContext.Status);
  AppendJsonStringField(AFields, 'symbolGraphStatus', AContext.SymbolGraphStatus);
  AppendJsonStringField(AFields, 'typeGraphStatus', AContext.TypeGraphStatus);
  AppendJsonStringField(AFields, 'typedHirStatus', AContext.TypedHirStatus);
  AppendJsonIntegerField(AFields, 'symbolCount', AContext.SymbolCount, AHasSemantic);
  AppendJsonIntegerField(AFields, 'typeCount', AContext.TypeCount, AHasSemantic);
  AppendJsonIntegerField(
    AFields,
    'typedHirNodeCount',
    AContext.TypedHirNodeCount,
    AHasSemantic
  );
  AppendJsonIntegerField(
    AFields,
    'runtimeContractCount',
    AContext.RuntimeContractCount,
    AHasSemantic
  );
  AppendJsonStringField(AFields, 'typedHirRootName', AContext.TypedHirRootName);
end;

procedure AppendMirProjectionJsonFields(
  var AFields: string;
  const AContext: TMirProjectionContext;
  const AHasMir: Boolean
);
begin
  AppendJsonStringField(AFields, 'mirStatus', AContext.Status);
  AppendJsonIntegerField(AFields, 'mirBlockCount', AContext.BlockCount, AHasMir);
  AppendJsonIntegerField(
    AFields,
    'mirOperationCount',
    AContext.OperationCount,
    AHasMir
  );
  AppendJsonStringField(AFields, 'mirEntryBlock', AContext.EntryBlock);
  AppendJsonStringField(AFields, 'mirRootName', AContext.RootName);
end;

procedure AppendBackendProjectionJsonFields(
  var AFields: string;
  const AContext: TBackendProjectionContext
);
begin
  AppendJsonStringField(AFields, 'backendPlanStatus', AContext.PlanStatus);
  AppendJsonStringField(AFields, 'backendOutputKind', AContext.OutputKind);
  AppendJsonStringField(
    AFields,
    'backendPrimaryArtifactKind',
    AContext.PrimaryArtifactKind
  );
  AppendJsonStringField(
    AFields,
    'backendPrimaryArtifactPath',
    AContext.PrimaryArtifactPath
  );
  AppendJsonIntegerField(
    AFields,
    'backendArtifactCount',
    AContext.ArtifactCount,
    AContext.ArtifactCount > 0
  );
  if AContext.ArtifactsJson <> '' then
    AppendJsonField(AFields, 'backendArtifacts', AContext.ArtifactsJson);
end;

procedure AppendToolchainProjectionJsonFields(
  var AFields: string;
  const AContext: TToolchainProjectionContext;
  const AHasSession: Boolean;
  const AHasBackend: Boolean
);
begin
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'hostId',
    AContext.HostId,
    AHasSession
  );
  AppendJsonStringField(
    AFields,
    'toolchainBindingId',
    AContext.ToolchainBindingId
  );
  AppendJsonStringField(AFields, 'backendFamily', AContext.BackendFamily);
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'assemblerProfileId',
    AContext.AssemblerProfileId,
    AHasSession
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'linkerProfileId',
    AContext.LinkerProfileId,
    AHasSession
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'archiverProfileId',
    AContext.ArchiverProfileId,
    AHasSession
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'resourceToolProfileId',
    AContext.ResourceToolProfileId,
    AHasSession
  );
  AppendJsonStringField(AFields, 'targetObjectFormat', AContext.TargetObjectFormat);
  AppendJsonStringField(
    AFields,
    'targetAssemblerFlavor',
    AContext.TargetAssemblerFlavor
  );
  AppendJsonStringField(
    AFields,
    'targetLinkerFlavor',
    AContext.TargetLinkerFlavor
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'targetRuntimeLayoutKey',
    AContext.TargetRuntimeLayoutKey,
    AHasSession
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'targetCSymbolPrefix',
    AContext.TargetCSymbolPrefix,
    AHasSession
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'targetCLibraryNaming',
    AContext.TargetCLibraryNaming,
    AHasSession
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'targetLlvmTriple',
    AContext.TargetLlvmTriple,
    AHasSession
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'targetLlvmDataLayout',
    AContext.TargetLlvmDataLayout,
    AHasSession
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'sysrootMode',
    AContext.SysrootMode,
    AHasSession
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'runtimeSdkId',
    AContext.RuntimeSdkId,
    AHasSession
  );
  AppendJsonBooleanField(
    AFields,
    'allowHostFallback',
    AContext.AllowHostFallback,
    AHasSession
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'toolRootKind',
    AContext.ToolRootKind,
    AHasSession
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'runtimeRootKind',
    AContext.RuntimeRootKind,
    AHasSession
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'responseFilePolicy',
    AContext.ResponseFilePolicy,
    AHasSession
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'linkScriptPolicy',
    AContext.LinkScriptPolicy,
    AHasSession
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'toolchainPlanStatus',
    AContext.ToolchainPlanStatus,
    AHasSession
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'toolchainPlanFamily',
    AContext.ToolchainPlanFamily,
    AHasSession
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'toolProfileRoot',
    AContext.ToolProfileRoot,
    AHasSession
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'logicalLinkRequestStatus',
    AContext.LogicalLinkRequestStatus,
    AHasSession
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'logicalLinkRequestOutputKind',
    AContext.LogicalLinkRequestOutputKind,
    AHasSession
  );
  AppendJsonIntegerField(
    AFields,
    'logicalLibraryRequestCount',
    AContext.LogicalLibraryRequestCount,
    AHasSession
  );
  if AContext.LogicalLinkRequestJson <> '' then
    AppendJsonField(AFields, 'logicalLinkRequest', AContext.LogicalLinkRequestJson);
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'llvmToolchainStatus',
    AContext.LlvmToolchainStatus,
    AHasSession
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'llvmExecutableSetId',
    AContext.LlvmExecutableSetId,
    AHasSession
  );
  if AContext.LlvmExecutableSetJson <> '' then
    AppendJsonField(AFields, 'llvmExecutableSet', AContext.LlvmExecutableSetJson);
  AppendJsonIntegerField(
    AFields,
    'toolInvocationCount',
    AContext.ToolInvocationCount,
    AHasBackend
  );
  AppendJsonStringField(AFields, 'toolRunStatus', AContext.ToolRunStatus);
  AppendJsonIntegerField(
    AFields,
    'toolRunStepCount',
    AContext.ToolRunStepCount,
    AContext.ToolRunStepCount > 0
  );
  AppendJsonStringField(
    AFields,
    'primaryToolRunStatus',
    AContext.PrimaryToolRunStatus
  );
  AppendJsonStringField(AFields, 'primaryToolRole', AContext.PrimaryToolRole);
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'primaryToolProfileId',
    AContext.PrimaryToolProfileId,
    AHasBackend
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'primaryToolStepId',
    AContext.PrimaryToolStepId,
    AHasBackend
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'primaryToolLogicalExecutable',
    AContext.PrimaryToolLogicalExecutable,
    AHasBackend
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'primaryToolSysrootRef',
    AContext.PrimaryToolSysrootRef,
    AHasBackend
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'primaryToolFailureMapping',
    AContext.PrimaryToolFailureMapping,
    AHasBackend
  );
end;

procedure AppendEnvironmentProjectionJsonFields(
  var AFields: string;
  const AContext: TEnvironmentProjectionContext
);
begin
  AppendJsonStringField(
    AFields,
    'toolchainBindingPath',
    AContext.ToolchainBindingPath
  );
  AppendJsonStringField(AFields, 'distributionBinDir', AContext.DistributionBinDir);
  AppendJsonStringField(AFields, 'distributionLibDir', AContext.DistributionLibDir);
  AppendJsonStringField(
    AFields,
    'distributionShareDir',
    AContext.DistributionShareDir
  );
  AppendJsonStringField(AFields, 'runtimeRoot', AContext.RuntimeRootPath);
  AppendJsonStringField(AFields, 'runtimeLibc', AContext.RuntimeLibcPath);
  AppendJsonBooleanField(
    AFields,
    'runtimeLibcPresent',
    AContext.RuntimeLibcPresent,
    AContext.HasRuntimeLibcPresent
  );
  AppendJsonStringField(
    AFields,
    'environmentReadiness',
    AContext.EnvironmentReadiness
  );
  AppendJsonStringField(AFields, 'environmentStatus', AContext.EnvironmentStatus);
  AppendJsonStringField(AFields, 'runtimeSdkStatus', AContext.RuntimeSdkStatus);
  AppendJsonStringField(
    AFields,
    'toolchainBindingStatus',
    AContext.ToolchainBindingStatus
  );
  AppendJsonStringField(AFields, 'distributionStatus', AContext.DistributionStatus);
end;

procedure AppendDoctorProjectionJsonFields(
  var AFields: string;
  const AContext: TDoctorProjectionContext
);
begin
  AppendJsonStringField(
    AFields,
    'doctorWorkspaceStatus',
    AContext.WorkspaceStatus
  );
  AppendJsonStringField(
    AFields,
    'doctorToolchainBindingStatus',
    AContext.ToolchainBindingStatus
  );
  AppendJsonStringField(AFields, 'doctorStatus', AContext.Status);
  AppendJsonIntegerField(
    AFields,
    'doctorCheckCount',
    AContext.CheckCount,
    AContext.CheckCount > 0
  );
  AppendJsonIntegerField(
    AFields,
    'doctorFindingCount',
    AContext.FindingCount,
    AContext.CheckCount > 0
  );
  if AContext.FindingsJson <> '' then
    AppendJsonField(AFields, 'doctorFindings', AContext.FindingsJson);
end;

procedure AppendQueryProjectionJsonFields(
  var AFields: string;
  const AContext: TQueryProjectionContext
);
begin
  AppendJsonStringField(AFields, 'queryKind', AContext.Kind);
  AppendJsonStringField(AFields, 'queryStatus', AContext.Status);
  AppendJsonStringField(AFields, 'analysisSource', AContext.AnalysisSource);
  AppendJsonIntegerField(
    AFields,
    'queryResultCount',
    AContext.ResultCount,
    AContext.HasResultCount
  );
  if AContext.SymbolsJson <> '' then
    AppendJsonField(AFields, 'querySymbols', AContext.SymbolsJson);
  if AContext.ScopesJson <> '' then
    AppendJsonField(AFields, 'queryScopes', AContext.ScopesJson);
  if AContext.TypesJson <> '' then
    AppendJsonField(AFields, 'queryTypes', AContext.TypesJson);
end;

procedure AppendPackageProjectionJsonFields(
  var AFields: string;
  const AContext: TPackageProjectionContext
);
begin
  AppendJsonStringField(
    AFields,
    'packageWorkflowStatus',
    AContext.WorkflowStatus
  );
  AppendJsonStringField(
    AFields,
    'packageManifestStatus',
    AContext.ManifestStatus
  );
  AppendJsonStringField(AFields, 'packageLockStatus', AContext.LockStatus);
  AppendJsonStringField(
    AFields,
    'packageInstallPlanStatus',
    AContext.InstallPlanStatus
  );
  AppendJsonStringField(
    AFields,
    'packageWorkflowManifestPath',
    AContext.ManifestPath
  );
  AppendJsonStringField(AFields, 'packageRootPath', AContext.PackageRootPath);
  AppendJsonStringField(AFields, 'packageName', AContext.PackageName);
  AppendJsonStringField(AFields, 'packageLockfilePath', AContext.LockfilePath);
  AppendJsonIntegerField(
    AFields,
    'packageSourceRootCount',
    AContext.SourceRootCount,
    AContext.HasSourceRootCount
  );
  if AContext.SourceRootsJson <> '' then
    AppendJsonField(AFields, 'packageSourceRoots', AContext.SourceRootsJson);
  AppendJsonIntegerField(
    AFields,
    'packageDependencyCount',
    AContext.DependencyCount,
    AContext.HasDependencyCount
  );
  if AContext.DependenciesJson <> '' then
    AppendJsonField(AFields, 'packageDependencies', AContext.DependenciesJson);
end;

function BuildCommandEnvelopeJson(
  const AState: TNextPasState;
  const AExitCode: LongInt;
  const ASelector: string;
  const AStatusValue: string;
  const ABuildResult: string;
  const AFailureKind: string;
  const AHumanSummary: string
): string;
var
  EnvelopeFields: string;
  HasCommandToolchainProjection: Boolean;
  HasBackendProjection: Boolean;
  HasMirProjection: Boolean;
  HasResolutionProjection: Boolean;
  HasSemanticProjection: Boolean;
  HasSessionProjection: Boolean;
  HasSyntaxProjection: Boolean;
  ResultFields: string;
begin
  EnvelopeFields := '';
  ResultFields := '';
  HasSessionProjection := AState.SessionProjection.SessionId <> '';
  HasSyntaxProjection := AState.SyntaxProjection.Status <> '';
  HasResolutionProjection := AState.ResolutionProjection.Status <> '';
  HasSemanticProjection := AState.SemanticProjection.Status <> '';
  HasMirProjection := AState.MirProjection.Status <> '';
  HasBackendProjection := AState.BackendProjection.PlanStatus <> '';
  HasCommandToolchainProjection := HasSessionProjection or
    (AState.ToolchainProjection.HostId <> '') or
    (AState.ToolchainProjection.ToolchainBindingId <> '');
  AppendJsonStringField(ResultFields, 'selector', ASelector);
  AppendJsonStringField(ResultFields, 'status', AStatusValue);
  AppendJsonStringField(ResultFields, 'result', ABuildResult);
  AppendJsonStringField(ResultFields, 'failureKind', AFailureKind);
  AppendBuildContextProjectionJsonFields(ResultFields, AState.BuildContext);
  AppendSessionProjectionJsonFields(
    ResultFields,
    AState.SessionProjection,
    AState.DiagnosticsProjection,
    HasSessionProjection
  );
  AppendSyntaxProjectionJsonFields(
    ResultFields,
    AState.SyntaxProjection,
    HasSyntaxProjection
  );
  AppendResolutionProjectionJsonFields(
    ResultFields,
    AState.ResolutionProjection,
    HasResolutionProjection
  );
  AppendSemanticProjectionJsonFields(
    ResultFields,
    AState.SemanticProjection,
    HasSemanticProjection
  );
  AppendMirProjectionJsonFields(ResultFields, AState.MirProjection, HasMirProjection);
  AppendBackendProjectionJsonFields(ResultFields, AState.BackendProjection);
  AppendToolchainProjectionJsonFields(
    ResultFields,
    AState.ToolchainProjection,
    HasCommandToolchainProjection,
    HasBackendProjection
  );
  AppendEnvironmentProjectionJsonFields(ResultFields, AState.EnvironmentProjection);
  AppendDoctorProjectionJsonFields(ResultFields, AState.DoctorProjection);
  AppendQueryProjectionJsonFields(ResultFields, AState.QueryProjection);
  AppendPackageProjectionJsonFields(ResultFields, AState.PackageProjection);
  AppendJsonStringField(
    ResultFields,
    'diagnosticsSummary',
    AState.DiagnosticsProjection.Summary
  );
  AppendJsonStringField(ResultFields, 'buildResult', ABuildResult);

  if AState.CommandName <> '' then
    AppendJsonField(EnvelopeFields, 'command', JsonString(AState.CommandName))
  else
    AppendJsonField(EnvelopeFields, 'command', JsonString('cli'));
  AppendJsonField(EnvelopeFields, 'exitCode', IntToStr(AExitCode));
  if ResultFields <> '' then
    AppendJsonField(EnvelopeFields, 'result', '{' + ResultFields + '}');
  if AState.DiagnosticsProjection.Json <> '' then
    AppendJsonField(
      EnvelopeFields,
      'diagnostics',
      AState.DiagnosticsProjection.Json
    )
  else
    AppendJsonField(EnvelopeFields, 'diagnostics', '[]');
  if AState.ToolchainProjection.BuildTraceRef <> '' then
    AppendJsonField(
      EnvelopeFields,
      'buildTraceRef',
      JsonString(AState.ToolchainProjection.BuildTraceRef)
    )
  else
    AppendJsonField(EnvelopeFields, 'buildTraceRef', 'null');
  if AState.ToolchainProjection.BuildTraceJson <> '' then
    AppendJsonField(
      EnvelopeFields,
      'buildTrace',
      AState.ToolchainProjection.BuildTraceJson
    );
  if AState.ToolchainProjection.ToolInvocationPlanRef <> '' then
    AppendJsonField(
      EnvelopeFields,
      'toolInvocationPlanRef',
      JsonString(AState.ToolchainProjection.ToolInvocationPlanRef)
    );
  if AState.ToolchainProjection.ToolInvocationPlanJson <> '' then
    AppendJsonField(
      EnvelopeFields,
      'toolInvocationPlan',
      AState.ToolchainProjection.ToolInvocationPlanJson
    );
  if AState.ToolchainProjection.ToolStatusEventsJson <> '' then
    AppendJsonField(
      EnvelopeFields,
      'toolStatusEvents',
      AState.ToolchainProjection.ToolStatusEventsJson
    );
  AppendJsonField(EnvelopeFields, 'humanSummary', JsonString(AHumanSummary));
  Result := '{' + EnvelopeFields + '}';
end;

procedure PrintCommandEnvelope(
  const AState: TNextPasState;
  const AExitCode: LongInt;
  const ASelector: string;
  const AStatusValue: string;
  const ABuildResult: string;
  const AFailureKind: string;
  const AHumanSummary: string;
  const AUseStdErr: Boolean
);
var
  EnvelopeJson: string;
begin
  EnvelopeJson := BuildCommandEnvelopeJson(
    AState,
    AExitCode,
    ASelector,
    AStatusValue,
    ABuildResult,
    AFailureKind,
    AHumanSummary
  );
  if AUseStdErr then
    WriteLn(ErrOutput, 'command-envelope=', EnvelopeJson)
  else
    WriteLn('command-envelope=', EnvelopeJson);
end;

end.
