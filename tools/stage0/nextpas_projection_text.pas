unit nextpas_projection_text;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, nextpas_projection_types, nextpas_json_helpers;

procedure WriteProjectionLine(
  const UseStdErr: Boolean;
  const AName: string;
  const AValue: string
);
procedure WriteProjectionTextWhenEnabled(
  const UseStdErr: Boolean;
  const AName: string;
  const AValue: string;
  const AEnabled: Boolean
);
procedure WriteProjectionTextIfPresent(
  const UseStdErr: Boolean;
  const AName: string;
  const AValue: string
);
procedure WriteProjectionIntegerWhenEnabled(
  const UseStdErr: Boolean;
  const AName: string;
  const AValue: LongInt;
  const AEnabled: Boolean
);
procedure WriteProjectionInteger(
  const UseStdErr: Boolean;
  const AName: string;
  const AValue: LongInt
);
procedure WriteProjectionBooleanWhenEnabled(
  const UseStdErr: Boolean;
  const AName: string;
  const AValue: Boolean;
  const AEnabled: Boolean
);

procedure PrintBuildContextProjection(
  const UseStdErr: Boolean;
  const AContext: TBuildCommandContext
);
procedure PrintSessionIdentityProjection(
  const UseStdErr: Boolean;
  const ASession: TSessionProjectionContext
);
procedure PrintDiagnosticsCountsProjection(
  const UseStdErr: Boolean;
  const ADiagnostics: TDiagnosticProjectionContext
);
procedure PrintSyntaxProjectionFields(
  const UseStdErr: Boolean;
  const AContext: TSyntaxProjectionContext
);
procedure PrintResolutionProjectionFields(
  const UseStdErr: Boolean;
  const AContext: TResolutionProjectionContext
);
procedure PrintSemanticProjectionFields(
  const UseStdErr: Boolean;
  const AContext: TSemanticProjectionContext
);
procedure PrintMirProjectionFields(
  const UseStdErr: Boolean;
  const AContext: TMirProjectionContext
);
procedure PrintBackendProjectionFields(
  const UseStdErr: Boolean;
  const AContext: TBackendProjectionContext
);
procedure PrintToolchainProjectionFields(
  const UseStdErr: Boolean;
  const AContext: TToolchainProjectionContext
);
procedure PrintEnvironmentProjectionFields(
  const UseStdErr: Boolean;
  const AContext: TEnvironmentProjectionContext
);
procedure PrintDoctorProjectionFields(
  const UseStdErr: Boolean;
  const AContext: TDoctorProjectionContext
);
procedure PrintQueryProjectionFields(
  const UseStdErr: Boolean;
  const AContext: TQueryProjectionContext
);
procedure PrintPackageProjectionFields(
  const UseStdErr: Boolean;
  const AContext: TPackageProjectionContext
);
procedure PrintDiagnosticsDetailProjection(
  const UseStdErr: Boolean;
  const ADiagnostics: TDiagnosticProjectionContext
);
procedure PrintBuildTraceProjection(
  const UseStdErr: Boolean;
  const AToolchain: TToolchainProjectionContext
);
procedure PrintLifecycleProjection(
  const UseStdErr: Boolean;
  const ASession: TSessionProjectionContext
);
procedure PrintSessionProjection(
  const UseStdErr: Boolean;
  const AState: TNextPasState
);

implementation

procedure WriteProjectionLine(
  const UseStdErr: Boolean;
  const AName: string;
  const AValue: string
);
begin
  if UseStdErr then
    WriteLn(ErrOutput, AName, '=', AValue)
  else
    WriteLn(AName, '=', AValue);
end;

procedure WriteProjectionTextWhenEnabled(
  const UseStdErr: Boolean;
  const AName: string;
  const AValue: string;
  const AEnabled: Boolean
);
begin
  if not AEnabled then
    Exit;

  WriteProjectionLine(UseStdErr, AName, AValue);
end;

procedure WriteProjectionTextIfPresent(
  const UseStdErr: Boolean;
  const AName: string;
  const AValue: string
);
begin
  WriteProjectionTextWhenEnabled(UseStdErr, AName, AValue, AValue <> '');
end;

procedure WriteProjectionIntegerWhenEnabled(
  const UseStdErr: Boolean;
  const AName: string;
  const AValue: LongInt;
  const AEnabled: Boolean
);
begin
  if not AEnabled then
    Exit;

  WriteProjectionLine(UseStdErr, AName, IntToStr(AValue));
end;

procedure WriteProjectionInteger(
  const UseStdErr: Boolean;
  const AName: string;
  const AValue: LongInt
);
begin
  WriteProjectionIntegerWhenEnabled(UseStdErr, AName, AValue, True);
end;

procedure WriteProjectionBooleanWhenEnabled(
  const UseStdErr: Boolean;
  const AName: string;
  const AValue: Boolean;
  const AEnabled: Boolean
);
begin
  if not AEnabled then
    Exit;

  WriteProjectionLine(UseStdErr, AName, BooleanText(AValue));
end;
procedure PrintBuildContextProjection(const UseStdErr: Boolean; const AContext: TBuildCommandContext);
begin
  WriteProjectionTextIfPresent(
    UseStdErr,
    'workspace-root',
    AContext.WorkspaceRootPath
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'workspace-discovery-kind',
    AContext.WorkspaceDiscoveryKind
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'workspace-descriptor-path',
    AContext.WorkspaceDescriptorPath
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'package-manifest-path',
    AContext.PackageManifestPath
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'artifact-root',
    AContext.ArtifactRootPath
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'output-dir',
    AContext.OutputDirPath
  );
end;
procedure PrintSessionIdentityProjection(const UseStdErr: Boolean; const ASession: TSessionProjectionContext);
begin
  WriteProjectionLine(
    UseStdErr,
    'session-id',
    ASession.SessionId
  );
  WriteProjectionInteger(
    UseStdErr,
    'root-file-id',
    ASession.RootFileId
  );
  WriteProjectionInteger(
    UseStdErr,
    'source-db-file-count',
    ASession.SourceFileCount
  );
  WriteProjectionLine(
    UseStdErr,
    'source-db-line-index',
    ASession.SourceLineIndexState
  );
  WriteProjectionInteger(
    UseStdErr,
    'unit-state-count',
    ASession.UnitStateCount
  );
end;
procedure PrintDiagnosticsCountsProjection(const UseStdErr: Boolean; const ADiagnostics: TDiagnosticProjectionContext);
begin
  WriteProjectionInteger(
    UseStdErr,
    'diagnostics-count',
    ADiagnostics.Count
  );
  WriteProjectionInteger(
    UseStdErr,
    'diagnostics-error-count',
    ADiagnostics.ErrorCount
  );
  WriteProjectionInteger(
    UseStdErr,
    'diagnostics-warning-count',
    ADiagnostics.WarningCount
  );
  WriteProjectionLine(
    UseStdErr,
    'diagnostics-policy',
    ADiagnostics.Policy
  );
end;
procedure PrintSyntaxProjectionFields(const UseStdErr: Boolean; const AContext: TSyntaxProjectionContext);
begin
  WriteProjectionLine(UseStdErr, 'syntax-status', AContext.Status);
  WriteProjectionInteger(
    UseStdErr,
    'lexer-token-count',
    AContext.LexerTokenCount
  );
  WriteProjectionInteger(
    UseStdErr,
    'green-node-count',
    AContext.GreenNodeCount
  );
  WriteProjectionLine(
    UseStdErr,
    'ast-root-kind',
    AContext.AstRootKind
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'ast-declared-name',
    AContext.AstDeclaredName
  );
end;
procedure PrintResolutionProjectionFields(const UseStdErr: Boolean; const AContext: TResolutionProjectionContext);
begin
  WriteProjectionLine(
    UseStdErr,
    'resolution-status',
    AContext.Status
  );
  WriteProjectionLine(
    UseStdErr,
    'unit-graph-status',
    AContext.UnitGraphStatus
  );
  WriteProjectionInteger(
    UseStdErr,
    'search-path-count',
    AContext.SearchPathCount
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'search-index-status',
    AContext.SearchIndexStatus
  );
  WriteProjectionInteger(
    UseStdErr,
    'indexed-search-root-count',
    AContext.IndexedSearchRootCount
  );
  WriteProjectionInteger(
    UseStdErr,
    'search-index-scan-count',
    AContext.SearchIndexScanCount
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'search-path-json',
    AContext.SearchPathJson
  );
  WriteProjectionInteger(
    UseStdErr,
    'resolved-unit-count',
    AContext.ResolvedUnitCount
  );
  WriteProjectionInteger(
    UseStdErr,
    'unit-graph-edge-count',
    AContext.UnitGraphEdgeCount
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'unit-graph-root-name',
    AContext.UnitGraphRootName
  );
end;
procedure PrintSemanticProjectionFields(const UseStdErr: Boolean; const AContext: TSemanticProjectionContext);
begin
  WriteProjectionLine(
    UseStdErr,
    'semantic-status',
    AContext.Status
  );
  WriteProjectionLine(
    UseStdErr,
    'symbol-graph-status',
    AContext.SymbolGraphStatus
  );
  WriteProjectionLine(
    UseStdErr,
    'type-graph-status',
    AContext.TypeGraphStatus
  );
  WriteProjectionLine(
    UseStdErr,
    'typed-hir-status',
    AContext.TypedHirStatus
  );
  WriteProjectionInteger(
    UseStdErr,
    'symbol-count',
    AContext.SymbolCount
  );
  WriteProjectionInteger(
    UseStdErr,
    'type-count',
    AContext.TypeCount
  );
  WriteProjectionInteger(
    UseStdErr,
    'typed-hir-node-count',
    AContext.TypedHirNodeCount
  );
  WriteProjectionInteger(
    UseStdErr,
    'runtime-contract-count',
    AContext.RuntimeContractCount
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'typed-hir-root-name',
    AContext.TypedHirRootName
  );
end;
procedure PrintMirProjectionFields(const UseStdErr: Boolean; const AContext: TMirProjectionContext);
begin
  WriteProjectionLine(UseStdErr, 'mir-status', AContext.Status);
  WriteProjectionInteger(
    UseStdErr,
    'mir-block-count',
    AContext.BlockCount
  );
  WriteProjectionInteger(
    UseStdErr,
    'mir-operation-count',
    AContext.OperationCount
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'mir-entry-block',
    AContext.EntryBlock
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'mir-root-name',
    AContext.RootName
  );
end;
procedure PrintBackendProjectionFields(const UseStdErr: Boolean; const AContext: TBackendProjectionContext);
begin
  WriteProjectionLine(
    UseStdErr,
    'backend-plan-status',
    AContext.PlanStatus
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'backend-output-kind',
    AContext.OutputKind
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'backend-primary-artifact-kind',
    AContext.PrimaryArtifactKind
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'backend-primary-artifact-path',
    AContext.PrimaryArtifactPath
  );
  WriteProjectionIntegerWhenEnabled(
    UseStdErr,
    'backend-artifact-count',
    AContext.ArtifactCount,
    AContext.ArtifactCount > 0
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'backend-artifacts',
    AContext.ArtifactsJson
  );
end;
procedure PrintToolchainProjectionFields(const UseStdErr: Boolean; const AContext: TToolchainProjectionContext);
begin
  WriteProjectionTextIfPresent(
    UseStdErr,
    'host-id',
    AContext.HostId
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'toolchain-binding-id',
    AContext.ToolchainBindingId
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'backend-family',
    AContext.BackendFamily
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'assembler-profile-id',
    AContext.AssemblerProfileId
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'linker-profile-id',
    AContext.LinkerProfileId
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'archiver-profile-id',
    AContext.ArchiverProfileId
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'resource-tool-profile-id',
    AContext.ResourceToolProfileId
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'target-object-format',
    AContext.TargetObjectFormat
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'target-assembler-flavor',
    AContext.TargetAssemblerFlavor
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'target-linker-flavor',
    AContext.TargetLinkerFlavor
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'target-runtime-layout-key',
    AContext.TargetRuntimeLayoutKey
  );
  WriteProjectionTextWhenEnabled(
    UseStdErr,
    'target-c-symbol-prefix',
    AContext.TargetCSymbolPrefix,
    AContext.HostId <> ''
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'target-c-library-naming',
    AContext.TargetCLibraryNaming
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'target-llvm-triple',
    AContext.TargetLlvmTriple
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'target-llvm-data-layout',
    AContext.TargetLlvmDataLayout
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'sysroot-mode',
    AContext.SysrootMode
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'runtime-sdk-id',
    AContext.RuntimeSdkId
  );
  WriteProjectionBooleanWhenEnabled(
    UseStdErr,
    'allow-host-fallback',
    AContext.AllowHostFallback,
    AContext.HostId <> ''
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'tool-root-kind',
    AContext.ToolRootKind
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'runtime-root-kind',
    AContext.RuntimeRootKind
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'response-file-policy',
    AContext.ResponseFilePolicy
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'link-script-policy',
    AContext.LinkScriptPolicy
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'toolchain-plan-status',
    AContext.ToolchainPlanStatus
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'toolchain-plan-family',
    AContext.ToolchainPlanFamily
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'tool-profile-root',
    AContext.ToolProfileRoot
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'logical-link-request-status',
    AContext.LogicalLinkRequestStatus
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'logical-link-request-output-kind',
    AContext.LogicalLinkRequestOutputKind
  );
  WriteProjectionInteger(
    UseStdErr,
    'logical-link-request-library-count',
    AContext.LogicalLibraryRequestCount
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'logical-link-request',
    AContext.LogicalLinkRequestJson
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'llvm-toolchain-status',
    AContext.LlvmToolchainStatus
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'llvm-executable-set-id',
    AContext.LlvmExecutableSetId
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'llvm-executable-set',
    AContext.LlvmExecutableSetJson
  );
  WriteProjectionInteger(
    UseStdErr,
    'tool-invocation-count',
    AContext.ToolInvocationCount
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'tool-run-status',
    AContext.ToolRunStatus
  );
  WriteProjectionIntegerWhenEnabled(
    UseStdErr,
    'tool-run-step-count',
    AContext.ToolRunStepCount,
    AContext.ToolRunStepCount > 0
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'primary-tool-run-status',
    AContext.PrimaryToolRunStatus
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'primary-tool-role',
    AContext.PrimaryToolRole
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'primary-tool-profile-id',
    AContext.PrimaryToolProfileId
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'primary-tool-step-id',
    AContext.PrimaryToolStepId
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'primary-tool-logical-executable',
    AContext.PrimaryToolLogicalExecutable
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'primary-tool-sysroot-ref',
    AContext.PrimaryToolSysrootRef
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'primary-tool-failure-mapping',
    AContext.PrimaryToolFailureMapping
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'tool-invocation-plan-ref',
    AContext.ToolInvocationPlanRef
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'tool-invocation-plan',
    AContext.ToolInvocationPlanJson
  );
  WriteProjectionIntegerWhenEnabled(
    UseStdErr,
    'tool-status-event-count',
    AContext.ToolStatusEventCount,
    AContext.ToolStatusEventCount > 0
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'tool-status-events',
    AContext.ToolStatusEventsJson
  );
end;
procedure PrintEnvironmentProjectionFields(const UseStdErr: Boolean; const AContext: TEnvironmentProjectionContext);
begin
  WriteProjectionTextIfPresent(
    UseStdErr,
    'env-selection-path',
    AContext.SelectionPath
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'env-selection-status',
    AContext.SelectionStatus
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'env-selection-target',
    AContext.SelectionTarget
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'env-selection-toolchain-binding-id',
    AContext.SelectionToolchainBindingId
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'env-resolution-path',
    AContext.ResolutionPath
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'env-resolution-status',
    AContext.ResolutionStatus
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'env-sync-change',
    AContext.SyncChange
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'toolchain-binding-path',
    AContext.ToolchainBindingPath
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'distribution-bin-dir',
    AContext.DistributionBinDir
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'distribution-lib-dir',
    AContext.DistributionLibDir
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'distribution-share-dir',
    AContext.DistributionShareDir
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'runtime-root',
    AContext.RuntimeRootPath
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'runtime-libc',
    AContext.RuntimeLibcPath
  );
  WriteProjectionBooleanWhenEnabled(
    UseStdErr,
    'runtime-libc-present',
    AContext.RuntimeLibcPresent,
    AContext.HasRuntimeLibcPresent
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'environment-readiness',
    AContext.EnvironmentReadiness
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'environment-status',
    AContext.EnvironmentStatus
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'runtime-sdk-status',
    AContext.RuntimeSdkStatus
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'toolchain-binding-status',
    AContext.ToolchainBindingStatus
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'distribution-status',
    AContext.DistributionStatus
  );
end;
procedure PrintDoctorProjectionFields(const UseStdErr: Boolean; const AContext: TDoctorProjectionContext);
begin
  WriteProjectionTextIfPresent(
    UseStdErr,
    'doctor-workspace-status',
    AContext.WorkspaceStatus
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'doctor-toolchain-binding-status',
    AContext.ToolchainBindingStatus
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'doctor-status',
    AContext.Status
  );
  WriteProjectionIntegerWhenEnabled(
    UseStdErr,
    'doctor-check-count',
    AContext.CheckCount,
    AContext.CheckCount > 0
  );
  WriteProjectionIntegerWhenEnabled(
    UseStdErr,
    'doctor-finding-count',
    AContext.FindingCount,
    AContext.CheckCount > 0
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'doctor-finding-code',
    AContext.FirstFinding.Code
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'doctor-finding-severity',
    AContext.FirstFinding.Severity
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'doctor-finding-subject',
    AContext.FirstFinding.Subject
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'doctor-finding-summary',
    AContext.FirstFinding.Summary
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'doctor-finding-suggested-action',
    AContext.FirstFinding.SuggestedAction
  );
end;
procedure PrintQueryProjectionFields(const UseStdErr: Boolean; const AContext: TQueryProjectionContext);
begin
  WriteProjectionTextIfPresent(
    UseStdErr,
    'query-kind',
    AContext.Kind
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'query-status',
    AContext.Status
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'analysis-source',
    AContext.AnalysisSource
  );
  WriteProjectionIntegerWhenEnabled(
    UseStdErr,
    'query-result-count',
    AContext.ResultCount,
    AContext.HasResultCount
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'query-symbols',
    AContext.SymbolsJson
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'query-scopes',
    AContext.ScopesJson
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'query-types',
    AContext.TypesJson
  );
end;
procedure PrintPackageProjectionFields(const UseStdErr: Boolean; const AContext: TPackageProjectionContext);
begin
  WriteProjectionTextIfPresent(
    UseStdErr,
    'package-workflow-status',
    AContext.WorkflowStatus
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'package-manifest-status',
    AContext.ManifestStatus
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'package-lock-status',
    AContext.LockStatus
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'package-install-plan-status',
    AContext.InstallPlanStatus
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'package-install-plan-blocker-code',
    AContext.InstallPlanBlockerCode
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'package-install-plan-blocker-message',
    AContext.InstallPlanBlockerMessage
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'package-workflow-manifest-path',
    AContext.ManifestPath
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'package-root-path',
    AContext.PackageRootPath
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'package-name',
    AContext.PackageName
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'package-lockfile-path',
    AContext.LockfilePath
  );
  WriteProjectionIntegerWhenEnabled(
    UseStdErr,
    'package-source-root-count',
    AContext.SourceRootCount,
    AContext.HasSourceRootCount
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'package-source-roots',
    AContext.SourceRootsJson
  );
  WriteProjectionIntegerWhenEnabled(
    UseStdErr,
    'package-dependency-count',
    AContext.DependencyCount,
    AContext.HasDependencyCount
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'package-dependencies',
    AContext.DependenciesJson
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'package-dependency-validation-status',
    AContext.DependencyValidationStatus
  );
  WriteProjectionIntegerWhenEnabled(
    UseStdErr,
    'package-dependency-issue-count',
    AContext.DependencyIssueCount,
    AContext.HasDependencyIssueCount
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'package-dependency-issues',
    AContext.DependencyIssuesJson
  );
end;
procedure PrintDiagnosticsDetailProjection(const UseStdErr: Boolean; const ADiagnostics: TDiagnosticProjectionContext);
begin
  WriteProjectionLine(
    UseStdErr,
    'diagnostics-summary',
    ADiagnostics.Summary
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'diagnostic-id',
    ADiagnostics.Id
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'diagnostic-code',
    ADiagnostics.Code
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'diagnostic-phase',
    ADiagnostics.Phase
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'diagnostic-message',
    ADiagnostics.Message
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'diagnostic-binding-id',
    ADiagnostics.BindingId
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'diagnostic-profile-id',
    ADiagnostics.ProfileId
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'diagnostic-step-id',
    ADiagnostics.StepId
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'diagnostic-logical-executable',
    ADiagnostics.LogicalExecutable
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'diagnostic-sysroot-ref',
    ADiagnostics.SysrootRef
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'diagnostic-resolved-path',
    ADiagnostics.ResolvedPath
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'diagnostic-primary-artifact-kind',
    ADiagnostics.PrimaryArtifactKind
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'diagnostic-primary-artifact-path',
    ADiagnostics.PrimaryArtifactPath
  );
  WriteProjectionIntegerWhenEnabled(
    UseStdErr,
    'diagnostic-exit-code',
    ADiagnostics.ExitCode,
    ADiagnostics.HasExitCode
  );
end;
procedure PrintBuildTraceProjection(const UseStdErr: Boolean; const AToolchain: TToolchainProjectionContext);
begin
  WriteProjectionTextIfPresent(
    UseStdErr,
    'build-trace-ref',
    AToolchain.BuildTraceRef
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'build-trace',
    AToolchain.BuildTraceJson
  );
end;
procedure PrintLifecycleProjection(const UseStdErr: Boolean; const ASession: TSessionProjectionContext);
begin
  WriteProjectionLine(
    UseStdErr,
    'lifecycle-session',
    ASession.SessionLifetime
  );
  WriteProjectionLine(
    UseStdErr,
    'lifecycle-unit',
    ASession.UnitLifetime
  );
  WriteProjectionLine(
    UseStdErr,
    'lifecycle-stage',
    ASession.StageLifetime
  );
end;

procedure PrintSessionProjection(const UseStdErr: Boolean; const AState: TNextPasState);
begin
  PrintBuildContextProjection(UseStdErr, AState.BuildContext);
  if AState.SessionProjection.SessionId = '' then
    Exit;

  PrintSessionIdentityProjection(UseStdErr, AState.SessionProjection);
  PrintDiagnosticsCountsProjection(UseStdErr, AState.DiagnosticsProjection);
  PrintSyntaxProjectionFields(UseStdErr, AState.SyntaxProjection);
  PrintResolutionProjectionFields(UseStdErr, AState.ResolutionProjection);
  PrintSemanticProjectionFields(UseStdErr, AState.SemanticProjection);
  PrintMirProjectionFields(UseStdErr, AState.MirProjection);
  PrintBackendProjectionFields(UseStdErr, AState.BackendProjection);
  PrintToolchainProjectionFields(UseStdErr, AState.ToolchainProjection);
  PrintDiagnosticsDetailProjection(UseStdErr, AState.DiagnosticsProjection);
  PrintBuildTraceProjection(UseStdErr, AState.ToolchainProjection);
  PrintLifecycleProjection(UseStdErr, AState.SessionProjection);
end;

end.
