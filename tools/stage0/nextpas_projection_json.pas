unit nextpas_projection_json;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, nextpas_json_helpers, nextpas_projection_types;

procedure AppendBuildContextProjectionJsonFields(
  var AFields: string;
  const AContext: TBuildCommandContext
);
procedure AppendSessionProjectionJsonFields(
  var AFields: string;
  const ASession: TSessionProjectionContext;
  const ADiagnostics: TDiagnosticProjectionContext;
  const AHasSessionProjection: Boolean
);
procedure AppendSyntaxProjectionJsonFields(
  var AFields: string;
  const ASyntax: TSyntaxProjectionContext;
  const AHasSyntaxProjection: Boolean
);
procedure AppendResolutionProjectionJsonFields(
  var AFields: string;
  const AResolution: TResolutionProjectionContext;
  const AHasResolutionProjection: Boolean
);
procedure AppendSemanticProjectionJsonFields(
  var AFields: string;
  const ASemantic: TSemanticProjectionContext;
  const AHasSemanticProjection: Boolean
);
procedure AppendMirProjectionJsonFields(
  var AFields: string;
  const AMir: TMirProjectionContext;
  const AHasMirProjection: Boolean
);
procedure AppendBackendProjectionJsonFields(
  var AFields: string;
  const ABackend: TBackendProjectionContext
);
procedure AppendToolchainProjectionJsonFields(
  var AFields: string;
  const AToolchain: TToolchainProjectionContext;
  const AHasSessionProjection: Boolean;
  const AHasBackendProjection: Boolean
);
procedure AppendEnvironmentProjectionJsonFields(
  var AFields: string;
  const AEnvironment: TEnvironmentProjectionContext
);
procedure AppendDoctorProjectionJsonFields(
  var AFields: string;
  const ADoctor: TDoctorProjectionContext
);
procedure AppendQueryProjectionJsonFields(
  var AFields: string;
  const AQuery: TQueryProjectionContext
);
procedure AppendPackageProjectionJsonFields(
  var AFields: string;
  const APackage: TPackageProjectionContext
);
function BuildCommandEnvelopeJson(
  const AExitCode: LongInt;
  const ASelector: string;
  const AStatusValue: string;
  const ABuildResult: string;
  const AFailureKind: string;
  const AHumanSummary: string;
  const ACommandName: string;
  const ABuildContext: TBuildCommandContext;
  const ASessionProjection: TSessionProjectionContext;
  const ADiagnosticsProjection: TDiagnosticProjectionContext;
  const ASyntaxProjection: TSyntaxProjectionContext;
  const AResolutionProjection: TResolutionProjectionContext;
  const ASemanticProjection: TSemanticProjectionContext;
  const AMirProjection: TMirProjectionContext;
  const ABackendProjection: TBackendProjectionContext;
  const AToolchainProjection: TToolchainProjectionContext;
  const AEnvironmentProjection: TEnvironmentProjectionContext;
  const ADoctorProjection: TDoctorProjectionContext;
  const AQueryProjection: TQueryProjectionContext;
  const APackageProjection: TPackageProjectionContext
): string;
procedure PrintCommandEnvelope(
  const AExitCode: LongInt;
  const ASelector: string;
  const AStatusValue: string;
  const ABuildResult: string;
  const AFailureKind: string;
  const AHumanSummary: string;
  const AUseStdErr: Boolean;
  const ACommandName: string;
  const ABuildContext: TBuildCommandContext;
  const ASessionProjection: TSessionProjectionContext;
  const ADiagnosticsProjection: TDiagnosticProjectionContext;
  const ASyntaxProjection: TSyntaxProjectionContext;
  const AResolutionProjection: TResolutionProjectionContext;
  const ASemanticProjection: TSemanticProjectionContext;
  const AMirProjection: TMirProjectionContext;
  const ABackendProjection: TBackendProjectionContext;
  const AToolchainProjection: TToolchainProjectionContext;
  const AEnvironmentProjection: TEnvironmentProjectionContext;
  const ADoctorProjection: TDoctorProjectionContext;
  const AQueryProjection: TQueryProjectionContext;
  const APackageProjection: TPackageProjectionContext
);

implementation

procedure AppendBuildContextProjectionJsonFields(
  var AFields: string;
  const AContext: TBuildCommandContext
);
begin
  AppendJsonStringField(AFields, 'source', AContext.SourcePath);
  AppendJsonStringField(AFields, 'target', AContext.TargetName);
  AppendJsonStringField(
    AFields,
    'workspaceRoot',
    AContext.WorkspaceRootPath
  );
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
  AppendJsonStringField(
    AFields,
    'artifactRoot',
    AContext.ArtifactRootPath
  );
  AppendJsonStringField(AFields, 'outputDir', AContext.OutputDirPath);
  AppendJsonStringField(
    AFields,
    'targetConfig',
    AContext.TargetConfigPath
  );
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
  const AHasSessionProjection: Boolean
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
    AHasSessionProjection
  );
  AppendJsonIntegerField(
    AFields,
    'diagnosticErrorCount',
    ADiagnostics.ErrorCount,
    AHasSessionProjection
  );
  AppendJsonIntegerField(
    AFields,
    'diagnosticWarningCount',
    ADiagnostics.WarningCount,
    AHasSessionProjection
  );
  AppendJsonStringField(
    AFields,
    'diagnosticsPolicy',
    ADiagnostics.Policy
  );
  AppendJsonStringField(
    AFields,
    'sessionLifetime',
    ASession.SessionLifetime
  );
  AppendJsonStringField(
    AFields,
    'unitLifetime',
    ASession.UnitLifetime
  );
  AppendJsonStringField(
    AFields,
    'stageLifetime',
    ASession.StageLifetime
  );
end;

procedure AppendSyntaxProjectionJsonFields(
  var AFields: string;
  const ASyntax: TSyntaxProjectionContext;
  const AHasSyntaxProjection: Boolean
);
begin
  AppendJsonStringField(AFields, 'syntaxStatus', ASyntax.Status);
  AppendJsonIntegerField(
    AFields,
    'lexerTokenCount',
    ASyntax.LexerTokenCount,
    AHasSyntaxProjection
  );
  AppendJsonIntegerField(
    AFields,
    'greenNodeCount',
    ASyntax.GreenNodeCount,
    AHasSyntaxProjection
  );
  AppendJsonStringField(AFields, 'astRootKind', ASyntax.AstRootKind);
  AppendJsonStringField(
    AFields,
    'astDeclaredName',
    ASyntax.AstDeclaredName
  );
end;

procedure AppendResolutionProjectionJsonFields(
  var AFields: string;
  const AResolution: TResolutionProjectionContext;
  const AHasResolutionProjection: Boolean
);
begin
  AppendJsonStringField(
    AFields,
    'resolutionStatus',
    AResolution.Status
  );
  AppendJsonStringField(
    AFields,
    'unitGraphStatus',
    AResolution.UnitGraphStatus
  );
  AppendJsonIntegerField(
    AFields,
    'searchPathCount',
    AResolution.SearchPathCount,
    AHasResolutionProjection
  );
  AppendJsonStringField(
    AFields,
    'searchIndexStatus',
    AResolution.SearchIndexStatus
  );
  AppendJsonIntegerField(
    AFields,
    'indexedSearchRootCount',
    AResolution.IndexedSearchRootCount,
    AHasResolutionProjection
  );
  AppendJsonIntegerField(
    AFields,
    'searchIndexScanCount',
    AResolution.SearchIndexScanCount,
    AHasResolutionProjection
  );
  if AResolution.SearchPathJson <> '' then
    AppendJsonField(
      AFields,
      'searchPaths',
      AResolution.SearchPathJson
    );
  AppendJsonIntegerField(
    AFields,
    'resolvedUnitCount',
    AResolution.ResolvedUnitCount,
    AHasResolutionProjection
  );
  AppendJsonIntegerField(
    AFields,
    'unitGraphEdgeCount',
    AResolution.UnitGraphEdgeCount,
    AHasResolutionProjection
  );
  AppendJsonStringField(
    AFields,
    'unitGraphRootName',
    AResolution.UnitGraphRootName
  );
end;

procedure AppendSemanticProjectionJsonFields(
  var AFields: string;
  const ASemantic: TSemanticProjectionContext;
  const AHasSemanticProjection: Boolean
);
begin
  AppendJsonStringField(AFields, 'semanticStatus', ASemantic.Status);
  AppendJsonStringField(
    AFields,
    'symbolGraphStatus',
    ASemantic.SymbolGraphStatus
  );
  AppendJsonStringField(
    AFields,
    'typeGraphStatus',
    ASemantic.TypeGraphStatus
  );
  AppendJsonStringField(
    AFields,
    'typedHirStatus',
    ASemantic.TypedHirStatus
  );
  AppendJsonIntegerField(
    AFields,
    'symbolCount',
    ASemantic.SymbolCount,
    AHasSemanticProjection
  );
  AppendJsonIntegerField(
    AFields,
    'typeCount',
    ASemantic.TypeCount,
    AHasSemanticProjection
  );
  AppendJsonIntegerField(
    AFields,
    'typedHirNodeCount',
    ASemantic.TypedHirNodeCount,
    AHasSemanticProjection
  );
  AppendJsonIntegerField(
    AFields,
    'runtimeContractCount',
    ASemantic.RuntimeContractCount,
    AHasSemanticProjection
  );
  AppendJsonStringField(
    AFields,
    'typedHirRootName',
    ASemantic.TypedHirRootName
  );
end;

procedure AppendMirProjectionJsonFields(
  var AFields: string;
  const AMir: TMirProjectionContext;
  const AHasMirProjection: Boolean
);
begin
  AppendJsonStringField(AFields, 'mirStatus', AMir.Status);
  AppendJsonIntegerField(
    AFields,
    'mirBlockCount',
    AMir.BlockCount,
    AHasMirProjection
  );
  AppendJsonIntegerField(
    AFields,
    'mirOperationCount',
    AMir.OperationCount,
    AHasMirProjection
  );
  AppendJsonStringField(AFields, 'mirEntryBlock', AMir.EntryBlock);
  AppendJsonStringField(AFields, 'mirRootName', AMir.RootName);
end;

procedure AppendBackendProjectionJsonFields(
  var AFields: string;
  const ABackend: TBackendProjectionContext
);
begin
  AppendJsonStringField(
    AFields,
    'backendPlanStatus',
    ABackend.PlanStatus
  );
  AppendJsonStringField(
    AFields,
    'backendOutputKind',
    ABackend.OutputKind
  );
  AppendJsonStringField(
    AFields,
    'backendPrimaryArtifactKind',
    ABackend.PrimaryArtifactKind
  );
  AppendJsonStringField(
    AFields,
    'backendPrimaryArtifactPath',
    ABackend.PrimaryArtifactPath
  );
  AppendJsonIntegerField(
    AFields,
    'backendArtifactCount',
    ABackend.ArtifactCount,
    ABackend.ArtifactCount > 0
  );
  if ABackend.ArtifactsJson <> '' then
    AppendJsonField(
      AFields,
      'backendArtifacts',
      ABackend.ArtifactsJson
    );
end;

procedure AppendToolchainProjectionJsonFields(
  var AFields: string;
  const AToolchain: TToolchainProjectionContext;
  const AHasSessionProjection: Boolean;
  const AHasBackendProjection: Boolean
);
begin
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'hostId',
    AToolchain.HostId,
    AHasSessionProjection
  );
  AppendJsonStringField(
    AFields,
    'toolchainBindingId',
    AToolchain.ToolchainBindingId
  );
  AppendJsonStringField(
    AFields,
    'backendFamily',
    AToolchain.BackendFamily
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'assemblerProfileId',
    AToolchain.AssemblerProfileId,
    AHasSessionProjection
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'linkerProfileId',
    AToolchain.LinkerProfileId,
    AHasSessionProjection
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'archiverProfileId',
    AToolchain.ArchiverProfileId,
    AHasSessionProjection
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'resourceToolProfileId',
    AToolchain.ResourceToolProfileId,
    AHasSessionProjection
  );
  AppendJsonStringField(
    AFields,
    'targetObjectFormat',
    AToolchain.TargetObjectFormat
  );
  AppendJsonStringField(
    AFields,
    'targetAssemblerFlavor',
    AToolchain.TargetAssemblerFlavor
  );
  AppendJsonStringField(
    AFields,
    'targetLinkerFlavor',
    AToolchain.TargetLinkerFlavor
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'targetRuntimeLayoutKey',
    AToolchain.TargetRuntimeLayoutKey,
    AHasSessionProjection
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'targetCSymbolPrefix',
    AToolchain.TargetCSymbolPrefix,
    AHasSessionProjection
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'targetCLibraryNaming',
    AToolchain.TargetCLibraryNaming,
    AHasSessionProjection
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'targetLlvmTriple',
    AToolchain.TargetLlvmTriple,
    AHasSessionProjection
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'targetLlvmDataLayout',
    AToolchain.TargetLlvmDataLayout,
    AHasSessionProjection
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'sysrootMode',
    AToolchain.SysrootMode,
    AHasSessionProjection
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'runtimeSdkId',
    AToolchain.RuntimeSdkId,
    AHasSessionProjection
  );
  AppendJsonBooleanField(
    AFields,
    'allowHostFallback',
    AToolchain.AllowHostFallback,
    AHasSessionProjection
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'toolRootKind',
    AToolchain.ToolRootKind,
    AHasSessionProjection
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'runtimeRootKind',
    AToolchain.RuntimeRootKind,
    AHasSessionProjection
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'responseFilePolicy',
    AToolchain.ResponseFilePolicy,
    AHasSessionProjection
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'linkScriptPolicy',
    AToolchain.LinkScriptPolicy,
    AHasSessionProjection
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'toolchainPlanStatus',
    AToolchain.ToolchainPlanStatus,
    AHasSessionProjection
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'toolchainPlanFamily',
    AToolchain.ToolchainPlanFamily,
    AHasSessionProjection
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'toolProfileRoot',
    AToolchain.ToolProfileRoot,
    AHasSessionProjection
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'logicalLinkRequestStatus',
    AToolchain.LogicalLinkRequestStatus,
    AHasSessionProjection
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'logicalLinkRequestOutputKind',
    AToolchain.LogicalLinkRequestOutputKind,
    AHasSessionProjection
  );
  AppendJsonIntegerField(
    AFields,
    'logicalLibraryRequestCount',
    AToolchain.LogicalLibraryRequestCount,
    AHasSessionProjection
  );
  if AToolchain.LogicalLinkRequestJson <> '' then
    AppendJsonField(
      AFields,
      'logicalLinkRequest',
      AToolchain.LogicalLinkRequestJson
    );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'llvmToolchainStatus',
    AToolchain.LlvmToolchainStatus,
    AHasSessionProjection
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'llvmExecutableSetId',
    AToolchain.LlvmExecutableSetId,
    AHasSessionProjection
  );
  if AToolchain.LlvmExecutableSetJson <> '' then
    AppendJsonField(
      AFields,
      'llvmExecutableSet',
      AToolchain.LlvmExecutableSetJson
    );
  AppendJsonIntegerField(
    AFields,
    'toolInvocationCount',
    AToolchain.ToolInvocationCount,
    AHasBackendProjection
  );
  AppendJsonStringField(
    AFields,
    'toolRunStatus',
    AToolchain.ToolRunStatus
  );
  AppendJsonIntegerField(
    AFields,
    'toolRunStepCount',
    AToolchain.ToolRunStepCount,
    AToolchain.ToolRunStepCount > 0
  );
  AppendJsonStringField(
    AFields,
    'primaryToolRunStatus',
    AToolchain.PrimaryToolRunStatus
  );
  AppendJsonStringField(
    AFields,
    'primaryToolRole',
    AToolchain.PrimaryToolRole
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'primaryToolProfileId',
    AToolchain.PrimaryToolProfileId,
    AHasBackendProjection
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'primaryToolStepId',
    AToolchain.PrimaryToolStepId,
    AHasBackendProjection
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'primaryToolLogicalExecutable',
    AToolchain.PrimaryToolLogicalExecutable,
    AHasBackendProjection
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'primaryToolSysrootRef',
    AToolchain.PrimaryToolSysrootRef,
    AHasBackendProjection
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'primaryToolFailureMapping',
    AToolchain.PrimaryToolFailureMapping,
    AHasBackendProjection
  );
end;

procedure AppendEnvironmentProjectionJsonFields(
  var AFields: string;
  const AEnvironment: TEnvironmentProjectionContext
);
begin
  AppendJsonStringField(
    AFields,
    'toolchainBindingPath',
    AEnvironment.ToolchainBindingPath
  );
  AppendJsonStringField(
    AFields,
    'distributionBinDir',
    AEnvironment.DistributionBinDir
  );
  AppendJsonStringField(
    AFields,
    'distributionLibDir',
    AEnvironment.DistributionLibDir
  );
  AppendJsonStringField(
    AFields,
    'distributionShareDir',
    AEnvironment.DistributionShareDir
  );
  AppendJsonStringField(
    AFields,
    'runtimeRoot',
    AEnvironment.RuntimeRootPath
  );
  AppendJsonStringField(
    AFields,
    'runtimeLibc',
    AEnvironment.RuntimeLibcPath
  );
  AppendJsonBooleanField(
    AFields,
    'runtimeLibcPresent',
    AEnvironment.RuntimeLibcPresent,
    AEnvironment.HasRuntimeLibcPresent
  );
  AppendJsonStringField(
    AFields,
    'environmentReadiness',
    AEnvironment.EnvironmentReadiness
  );
  AppendJsonStringField(
    AFields,
    'environmentStatus',
    AEnvironment.EnvironmentStatus
  );
  AppendJsonStringField(
    AFields,
    'runtimeSdkStatus',
    AEnvironment.RuntimeSdkStatus
  );
  AppendJsonStringField(
    AFields,
    'toolchainBindingStatus',
    AEnvironment.ToolchainBindingStatus
  );
  AppendJsonStringField(
    AFields,
    'distributionStatus',
    AEnvironment.DistributionStatus
  );
end;

procedure AppendDoctorProjectionJsonFields(
  var AFields: string;
  const ADoctor: TDoctorProjectionContext
);
begin
  AppendJsonStringField(
    AFields,
    'doctorWorkspaceStatus',
    ADoctor.WorkspaceStatus
  );
  AppendJsonStringField(
    AFields,
    'doctorToolchainBindingStatus',
    ADoctor.ToolchainBindingStatus
  );
  AppendJsonStringField(AFields, 'doctorStatus', ADoctor.Status);
  AppendJsonIntegerField(
    AFields,
    'doctorCheckCount',
    ADoctor.CheckCount,
    ADoctor.CheckCount > 0
  );
  AppendJsonIntegerField(
    AFields,
    'doctorFindingCount',
    ADoctor.FindingCount,
    ADoctor.CheckCount > 0
  );
  if ADoctor.FindingsJson <> '' then
    AppendJsonField(
      AFields,
      'doctorFindings',
      ADoctor.FindingsJson
    );
end;

procedure AppendQueryProjectionJsonFields(
  var AFields: string;
  const AQuery: TQueryProjectionContext
);
begin
  AppendJsonStringField(AFields, 'queryKind', AQuery.Kind);
  AppendJsonStringField(AFields, 'queryStatus', AQuery.Status);
  AppendJsonStringField(
    AFields,
    'analysisSource',
    AQuery.AnalysisSource
  );
  AppendJsonIntegerField(
    AFields,
    'queryResultCount',
    AQuery.ResultCount,
    AQuery.HasResultCount
  );
end;

procedure AppendPackageProjectionJsonFields(
  var AFields: string;
  const APackage: TPackageProjectionContext
);
begin
  AppendJsonStringField(
    AFields,
    'packageWorkflowStatus',
    APackage.WorkflowStatus
  );
  AppendJsonStringField(
    AFields,
    'packageManifestStatus',
    APackage.ManifestStatus
  );
  AppendJsonStringField(
    AFields,
    'packageLockStatus',
    APackage.LockStatus
  );
  AppendJsonStringField(
    AFields,
    'packageInstallPlanStatus',
    APackage.InstallPlanStatus
  );
  AppendJsonStringField(
    AFields,
    'packageRootPath',
    APackage.PackageRootPath
  );
  AppendJsonStringField(
    AFields,
    'packageName',
    APackage.PackageName
  );
  AppendJsonStringField(
    AFields,
    'packageLockfilePath',
    APackage.LockfilePath
  );
  AppendJsonIntegerField(
    AFields,
    'packageSourceRootCount',
    APackage.SourceRootCount,
    APackage.HasSourceRootCount
  );
end;

function BuildCommandEnvelopeJson(
  const AExitCode: LongInt;
  const ASelector: string;
  const AStatusValue: string;
  const ABuildResult: string;
  const AFailureKind: string;
  const AHumanSummary: string;
  const ACommandName: string;
  const ABuildContext: TBuildCommandContext;
  const ASessionProjection: TSessionProjectionContext;
  const ADiagnosticsProjection: TDiagnosticProjectionContext;
  const ASyntaxProjection: TSyntaxProjectionContext;
  const AResolutionProjection: TResolutionProjectionContext;
  const ASemanticProjection: TSemanticProjectionContext;
  const AMirProjection: TMirProjectionContext;
  const ABackendProjection: TBackendProjectionContext;
  const AToolchainProjection: TToolchainProjectionContext;
  const AEnvironmentProjection: TEnvironmentProjectionContext;
  const ADoctorProjection: TDoctorProjectionContext;
  const AQueryProjection: TQueryProjectionContext;
  const APackageProjection: TPackageProjectionContext
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
  HasSessionProjection := ASessionProjection.SessionId <> '';
  HasSyntaxProjection := ASyntaxProjection.Status <> '';
  HasResolutionProjection := AResolutionProjection.Status <> '';
  HasSemanticProjection := ASemanticProjection.Status <> '';
  HasMirProjection := AMirProjection.Status <> '';
  HasBackendProjection := ABackendProjection.PlanStatus <> '';
  HasCommandToolchainProjection := HasSessionProjection or
    (AToolchainProjection.HostId <> '') or
    (AToolchainProjection.ToolchainBindingId <> '');
  AppendJsonStringField(ResultFields, 'selector', ASelector);
  AppendJsonStringField(ResultFields, 'status', AStatusValue);
  AppendJsonStringField(ResultFields, 'result', ABuildResult);
  AppendJsonStringField(ResultFields, 'failureKind', AFailureKind);
  AppendBuildContextProjectionJsonFields(ResultFields, ABuildContext);
  AppendSessionProjectionJsonFields(
    ResultFields,
    ASessionProjection,
    ADiagnosticsProjection,
    HasSessionProjection
  );
  AppendSyntaxProjectionJsonFields(ResultFields, ASyntaxProjection, HasSyntaxProjection);
  AppendResolutionProjectionJsonFields(
    ResultFields,
    AResolutionProjection,
    HasResolutionProjection
  );
  AppendSemanticProjectionJsonFields(
    ResultFields,
    ASemanticProjection,
    HasSemanticProjection
  );
  AppendMirProjectionJsonFields(ResultFields, AMirProjection, HasMirProjection);
  AppendBackendProjectionJsonFields(ResultFields, ABackendProjection);
  AppendToolchainProjectionJsonFields(
    ResultFields,
    AToolchainProjection,
    HasCommandToolchainProjection,
    HasBackendProjection
  );
  AppendEnvironmentProjectionJsonFields(ResultFields, AEnvironmentProjection);
  AppendDoctorProjectionJsonFields(ResultFields, ADoctorProjection);
  AppendQueryProjectionJsonFields(ResultFields, AQueryProjection);
  AppendPackageProjectionJsonFields(ResultFields, APackageProjection);
  AppendJsonStringField(
    ResultFields,
    'diagnosticsSummary',
    ADiagnosticsProjection.Summary
  );
  AppendJsonStringField(ResultFields, 'buildResult', ABuildResult);

  AppendJsonField(EnvelopeFields, 'command', JsonString(ACommandName));
  AppendJsonField(EnvelopeFields, 'exitCode', IntToStr(AExitCode));
  if ResultFields <> '' then
    AppendJsonField(EnvelopeFields, 'result', '{' + ResultFields + '}');
  if ADiagnosticsProjection.Json <> '' then
    AppendJsonField(
      EnvelopeFields,
      'diagnostics',
      ADiagnosticsProjection.Json
    )
  else
    AppendJsonField(EnvelopeFields, 'diagnostics', '[]');
  if AToolchainProjection.BuildTraceRef <> '' then
    AppendJsonField(
      EnvelopeFields,
      'buildTraceRef',
      JsonString(AToolchainProjection.BuildTraceRef)
    )
  else
    AppendJsonField(EnvelopeFields, 'buildTraceRef', 'null');
  if AToolchainProjection.BuildTraceJson <> '' then
    AppendJsonField(
      EnvelopeFields,
      'buildTrace',
      AToolchainProjection.BuildTraceJson
    );
  if AToolchainProjection.ToolInvocationPlanRef <> '' then
    AppendJsonField(
      EnvelopeFields,
      'toolInvocationPlanRef',
      JsonString(AToolchainProjection.ToolInvocationPlanRef)
    );
  if AToolchainProjection.ToolInvocationPlanJson <> '' then
    AppendJsonField(
      EnvelopeFields,
      'toolInvocationPlan',
      AToolchainProjection.ToolInvocationPlanJson
    );
  if AToolchainProjection.ToolStatusEventsJson <> '' then
    AppendJsonField(
      EnvelopeFields,
      'toolStatusEvents',
      AToolchainProjection.ToolStatusEventsJson
    );
  AppendJsonField(EnvelopeFields, 'humanSummary', JsonString(AHumanSummary));
  Result := '{' + EnvelopeFields + '}';
end;

procedure PrintCommandEnvelope(
  const AExitCode: LongInt;
  const ASelector: string;
  const AStatusValue: string;
  const ABuildResult: string;
  const AFailureKind: string;
  const AHumanSummary: string;
  const AUseStdErr: Boolean;
  const ACommandName: string;
  const ABuildContext: TBuildCommandContext;
  const ASessionProjection: TSessionProjectionContext;
  const ADiagnosticsProjection: TDiagnosticProjectionContext;
  const ASyntaxProjection: TSyntaxProjectionContext;
  const AResolutionProjection: TResolutionProjectionContext;
  const ASemanticProjection: TSemanticProjectionContext;
  const AMirProjection: TMirProjectionContext;
  const ABackendProjection: TBackendProjectionContext;
  const AToolchainProjection: TToolchainProjectionContext;
  const AEnvironmentProjection: TEnvironmentProjectionContext;
  const ADoctorProjection: TDoctorProjectionContext;
  const AQueryProjection: TQueryProjectionContext;
  const APackageProjection: TPackageProjectionContext
);
var
  EnvelopeJson: string;
begin
  EnvelopeJson := BuildCommandEnvelopeJson(
    AExitCode,
    ASelector,
    AStatusValue,
    ABuildResult,
    AFailureKind,
    AHumanSummary,
    ACommandName,
    ABuildContext,
    ASessionProjection,
    ADiagnosticsProjection,
    ASyntaxProjection,
    AResolutionProjection,
    ASemanticProjection,
    AMirProjection,
    ABackendProjection,
    AToolchainProjection,
    AEnvironmentProjection,
    ADoctorProjection,
    AQueryProjection,
    APackageProjection
  );
  if AUseStdErr then
    WriteLn(ErrOutput, 'command-envelope=', EnvelopeJson)
  else
    WriteLn('command-envelope=', EnvelopeJson);
end;

end.
