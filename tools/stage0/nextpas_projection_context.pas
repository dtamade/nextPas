unit nextpas_projection_context;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, nextpas_projection_types, nextpas_json_helpers,
  np_compilation_session, np_workspace_model, np_package_workflow,
  np_package_manifest,
  np_toolchain_profiles, target_config;

procedure ClearBuildCommandContextValue(var AContext: TBuildCommandContext);
procedure ClearSessionProjectionContextValue(var AContext: TSessionProjectionContext);
procedure ClearDiagnosticProjectionContextValue(var AContext: TDiagnosticProjectionContext);
procedure ClearSyntaxProjectionContextValue(var AContext: TSyntaxProjectionContext);
procedure ClearResolutionProjectionContextValue(var AContext: TResolutionProjectionContext);
procedure ClearSemanticProjectionContextValue(var AContext: TSemanticProjectionContext);
procedure ClearMirProjectionContextValue(var AContext: TMirProjectionContext);
procedure ClearBackendProjectionContextValue(var AContext: TBackendProjectionContext);
procedure ClearToolchainProjectionContextValue(var AContext: TToolchainProjectionContext);
procedure ClearEnvironmentProjectionContextValue(var AContext: TEnvironmentProjectionContext);
procedure ClearDoctorProjectionContextValue(var AContext: TDoctorProjectionContext);
procedure ClearQueryProjectionContextValue(var AContext: TQueryProjectionContext);
procedure ClearPackageProjectionContextValue(var AContext: TPackageProjectionContext);

procedure CaptureBuildCommandContextValue(
  var AContext: TBuildCommandContext;
  const ASourcePath: string;
  const ATargetName: string;
  const AWorkspaceModel: TWorkspaceModel
);
procedure CaptureBuildContextFromSession(
  var AContext: TBuildCommandContext;
  const Session: TCompilationSession
);
procedure CaptureSessionProjectionContextValue(
  var AContext: TSessionProjectionContext;
  const Session: TCompilationSession
);
procedure CaptureDiagnosticProjectionContextValue(
  var AContext: TDiagnosticProjectionContext;
  const Session: TCompilationSession
);
procedure CaptureSyntaxProjectionContextValue(
  var AContext: TSyntaxProjectionContext;
  const Session: TCompilationSession
);
procedure CaptureResolutionProjectionContextValue(
  var AContext: TResolutionProjectionContext;
  const Session: TCompilationSession
);
procedure CaptureSemanticProjectionContextValue(
  var AContext: TSemanticProjectionContext;
  const Session: TCompilationSession
);
procedure CaptureMirProjectionContextValue(
  var AContext: TMirProjectionContext;
  const Session: TCompilationSession
);
procedure CaptureBackendProjectionContextValue(
  var AContext: TBackendProjectionContext;
  const Session: TCompilationSession
);
procedure CaptureToolchainProjectionContextValue(
  var AContext: TToolchainProjectionContext;
  const Session: TCompilationSession
);

procedure ClearBuildCommandContext(var AState: TNextPasState);
procedure ClearSessionContext(var AState: TNextPasState);
procedure CaptureBuildCommandContext(
  var AState: TNextPasState;
  const ASourcePath: string;
  const ATargetName: string;
  const AWorkspaceModel: TWorkspaceModel
);
procedure CaptureSessionContext(
  var AState: TNextPasState;
  const Session: TCompilationSession
);

procedure CaptureToolchainProjectionFromTargetConfig(
  var AContext: TToolchainProjectionContext;
  const ATargetConfig: TTargetConfig
);
procedure CaptureEnvironmentProjectionFromTargetConfig(
  var AContext: TEnvironmentProjectionContext;
  const ATargetConfig: TTargetConfig
);
procedure CaptureDoctorProjectionFromEnvironment(
  var AContext: TDoctorProjectionContext;
  const AEnvironmentContext: TEnvironmentProjectionContext;
  const APackageContext: TPackageProjectionContext;
  const AWorkspaceRoot: string
);
procedure CapturePackageProjectionFromWorkflowTruth(
  var AContext: TPackageProjectionContext;
  const AWorkflowTruth: TPackageWorkflowTruth
);
function ResolvePackageInspectionSourcePath(
  const AWorkspaceRoot: string
): string;

implementation

function BuildJsonStringArray(const AValues: array of string): string;
var
  EntryJson: string;
  Index: LongInt;
begin
  EntryJson := '';
  for Index := 0 to Length(AValues) - 1 do
  begin
    if EntryJson <> '' then
      EntryJson := EntryJson + ',';
    EntryJson := EntryJson + JsonString(AValues[Index]);
  end;

  Result := '[' + EntryJson + ']';
end;

function BuildJsonDependencyArray(
  const AValues: array of TPackageDependencyInfo
): string;
var
  EntryFields: string;
  EntryJson: string;
  Index: LongInt;
begin
  EntryJson := '';
  for Index := 0 to Length(AValues) - 1 do
  begin
    if EntryJson <> '' then
      EntryJson := EntryJson + ',';
    EntryFields := '';
    AppendJsonField(
      EntryFields,
      'name',
      JsonString(AValues[Index].PackageName)
    );
    AppendJsonField(
      EntryFields,
      'requirement',
      JsonString(AValues[Index].Requirement)
    );
    EntryJson := EntryJson + '{' + EntryFields + '}';
  end;

  Result := '[' + EntryJson + ']';
end;

procedure ClearBuildCommandContextValue(var AContext: TBuildCommandContext);
begin
  AContext.SourcePath := '';
  AContext.TargetName := '';
  AContext.TargetConfigPath := '';
  AContext.CompilerName := '';
  AContext.ArtifactPath := '';
  AContext.WorkspaceRootPath := '';
  AContext.WorkspaceDiscoveryKind := '';
  AContext.WorkspaceDescriptorPath := '';
  AContext.PackageManifestPath := '';
  AContext.ArtifactRootPath := '';
  AContext.OutputDirPath := '';
  AContext.CompilerExitCode := 0;
  AContext.HasCompilerExitCode := False;
end;

procedure ClearSessionProjectionContextValue(var AContext: TSessionProjectionContext);
begin
  AContext.SessionId := '';
  AContext.SessionLifetime := '';
  AContext.UnitLifetime := '';
  AContext.StageLifetime := '';
  AContext.SourceLineIndexState := '';
  AContext.RootFileId := 0;
  AContext.SourceFileCount := 0;
  AContext.UnitStateCount := 0;
end;

procedure ClearDiagnosticProjectionContextValue(
  var AContext: TDiagnosticProjectionContext
);
begin
  AContext.Policy := '';
  AContext.Count := 0;
  AContext.ErrorCount := 0;
  AContext.WarningCount := 0;
  AContext.Summary := '';
  AContext.Json := '';
  AContext.Id := '';
  AContext.Code := '';
  AContext.Phase := '';
  AContext.Message := '';
  AContext.BindingId := '';
  AContext.ProfileId := '';
  AContext.StepId := '';
  AContext.LogicalExecutable := '';
  AContext.SysrootRef := '';
  AContext.ResolvedPath := '';
  AContext.PrimaryArtifactKind := '';
  AContext.PrimaryArtifactPath := '';
  AContext.ExitCode := 0;
  AContext.HasExitCode := False;
end;

procedure ClearSyntaxProjectionContextValue(var AContext: TSyntaxProjectionContext);
begin
  AContext.Status := '';
  AContext.LexerTokenCount := 0;
  AContext.GreenNodeCount := 0;
  AContext.AstRootKind := '';
  AContext.AstDeclaredName := '';
end;

procedure ClearResolutionProjectionContextValue(
  var AContext: TResolutionProjectionContext
);
begin
  AContext.Status := '';
  AContext.UnitGraphStatus := '';
  AContext.SearchPathCount := 0;
  AContext.SearchIndexStatus := '';
  AContext.IndexedSearchRootCount := 0;
  AContext.SearchIndexScanCount := 0;
  AContext.SearchPathJson := '';
  AContext.ResolvedUnitCount := 0;
  AContext.UnitGraphEdgeCount := 0;
  AContext.UnitGraphRootName := '';
end;

procedure ClearSemanticProjectionContextValue(
  var AContext: TSemanticProjectionContext
);
begin
  AContext.Status := '';
  AContext.SymbolGraphStatus := '';
  AContext.TypeGraphStatus := '';
  AContext.TypedHirStatus := '';
  AContext.SymbolCount := 0;
  AContext.TypeCount := 0;
  AContext.TypedHirNodeCount := 0;
  AContext.RuntimeContractCount := 0;
  AContext.TypedHirRootName := '';
end;

procedure ClearMirProjectionContextValue(var AContext: TMirProjectionContext);
begin
  AContext.Status := '';
  AContext.BlockCount := 0;
  AContext.OperationCount := 0;
  AContext.EntryBlock := '';
  AContext.RootName := '';
end;

procedure ClearBackendProjectionContextValue(var AContext: TBackendProjectionContext);
begin
  AContext.PlanStatus := '';
  AContext.OutputKind := '';
  AContext.PrimaryArtifactKind := '';
  AContext.PrimaryArtifactPath := '';
  AContext.ArtifactCount := 0;
  AContext.ArtifactsJson := '';
end;

procedure ClearToolchainProjectionContextValue(
  var AContext: TToolchainProjectionContext
);
begin
  AContext.HostId := '';
  AContext.ToolchainBindingId := '';
  AContext.BackendFamily := '';
  AContext.AssemblerProfileId := '';
  AContext.LinkerProfileId := '';
  AContext.ArchiverProfileId := '';
  AContext.ResourceToolProfileId := '';
  AContext.TargetObjectFormat := '';
  AContext.TargetAssemblerFlavor := '';
  AContext.TargetLinkerFlavor := '';
  AContext.TargetRuntimeLayoutKey := '';
  AContext.TargetCSymbolPrefix := '';
  AContext.TargetCLibraryNaming := '';
  AContext.TargetLlvmTriple := '';
  AContext.TargetLlvmDataLayout := '';
  AContext.SysrootMode := '';
  AContext.RuntimeSdkId := '';
  AContext.AllowHostFallback := False;
  AContext.ToolRootKind := '';
  AContext.RuntimeRootKind := '';
  AContext.ResponseFilePolicy := '';
  AContext.LinkScriptPolicy := '';
  AContext.ToolchainPlanStatus := '';
  AContext.ToolchainPlanFamily := '';
  AContext.ToolProfileRoot := '';
  AContext.LogicalLinkRequestStatus := '';
  AContext.LogicalLinkRequestOutputKind := '';
  AContext.LogicalLibraryRequestCount := 0;
  AContext.LogicalLinkRequestJson := '';
  AContext.LlvmToolchainStatus := '';
  AContext.LlvmExecutableSetId := '';
  AContext.LlvmExecutableSetJson := '';
  AContext.ToolInvocationCount := 0;
  AContext.ToolRunStatus := '';
  AContext.ToolRunStepCount := 0;
  AContext.PrimaryToolRunStatus := '';
  AContext.PrimaryToolRole := '';
  AContext.PrimaryToolProfileId := '';
  AContext.PrimaryToolStepId := '';
  AContext.PrimaryToolLogicalExecutable := '';
  AContext.PrimaryToolSysrootRef := '';
  AContext.PrimaryToolFailureMapping := '';
  AContext.ToolInvocationPlanRef := '';
  AContext.ToolInvocationPlanJson := '';
  AContext.ToolStatusEventCount := 0;
  AContext.ToolStatusEventsJson := '';
  AContext.BuildTraceRef := '';
  AContext.BuildTraceJson := '';
end;

procedure ClearEnvironmentProjectionContextValue(
  var AContext: TEnvironmentProjectionContext
);
begin
  AContext.ToolchainBindingPath := '';
  AContext.DistributionBinDir := '';
  AContext.DistributionLibDir := '';
  AContext.DistributionShareDir := '';
  AContext.RuntimeRootPath := '';
  AContext.RuntimeLibcPath := '';
  AContext.RuntimeLibcPresent := False;
  AContext.HasRuntimeLibcPresent := False;
  AContext.EnvironmentReadiness := '';
  AContext.EnvironmentStatus := '';
  AContext.RuntimeSdkStatus := '';
  AContext.ToolchainBindingStatus := '';
  AContext.DistributionStatus := '';
end;

procedure ClearDoctorFindingValue(var AFinding: TDoctorFinding);
begin
  AFinding.Code := '';
  AFinding.Severity := '';
  AFinding.Subject := '';
  AFinding.Summary := '';
  AFinding.SuggestedAction := '';
end;

procedure ClearDoctorProjectionContextValue(
  var AContext: TDoctorProjectionContext
);
begin
  AContext.Status := '';
  AContext.WorkspaceStatus := '';
  AContext.ToolchainBindingStatus := '';
  AContext.CheckCount := 0;
  AContext.FindingCount := 0;
  ClearDoctorFindingValue(AContext.FirstFinding);
  AContext.FindingsJson := '';
end;

procedure ClearQueryProjectionContextValue(var AContext: TQueryProjectionContext);
begin
  AContext.Kind := '';
  AContext.Status := '';
  AContext.AnalysisSource := '';
  AContext.ResultCount := 0;
  AContext.HasResultCount := False;
  AContext.SymbolsJson := '';
  AContext.ScopesJson := '';
  AContext.TypesJson := '';
end;

procedure ClearPackageProjectionContextValue(
  var AContext: TPackageProjectionContext
);
begin
  AContext.WorkflowStatus := '';
  AContext.ManifestStatus := '';
  AContext.LockStatus := '';
  AContext.InstallPlanStatus := '';
  AContext.ManifestPath := '';
  AContext.PackageRootPath := '';
  AContext.PackageName := '';
  AContext.LockfilePath := '';
  AContext.SourceRootCount := 0;
  AContext.HasSourceRootCount := False;
  AContext.SourceRootsJson := '';
  AContext.DependencyCount := 0;
  AContext.HasDependencyCount := False;
  AContext.DependenciesJson := '';
end;

procedure CaptureBuildCommandContextValue(
  var AContext: TBuildCommandContext;
  const ASourcePath: string;
  const ATargetName: string;
  const AWorkspaceModel: TWorkspaceModel
);
begin
  AContext.SourcePath := ASourcePath;
  AContext.TargetName := ATargetName;
  AContext.WorkspaceRootPath := AWorkspaceModel.WorkspaceRootPath;
  AContext.WorkspaceDiscoveryKind := AWorkspaceModel.DiscoveryKind;
  AContext.WorkspaceDescriptorPath := AWorkspaceModel.WorkspaceDescriptorPath;
  AContext.PackageManifestPath := AWorkspaceModel.PackageManifestPath;
  AContext.ArtifactRootPath := AWorkspaceModel.ArtifactRootPath;
  AContext.OutputDirPath := AWorkspaceModel.OutputDirPath;
end;

procedure CaptureBuildContextFromSession(
  var AContext: TBuildCommandContext;
  const Session: TCompilationSession
);
begin
  AContext.WorkspaceRootPath := Session.WorkspaceRootPath;
  AContext.WorkspaceDiscoveryKind := Session.WorkspaceDiscoveryKind;
  AContext.WorkspaceDescriptorPath := Session.WorkspaceDescriptorPath;
  AContext.PackageManifestPath := Session.PackageManifestPath;
  AContext.ArtifactRootPath := Session.ArtifactRootPath;
  AContext.OutputDirPath := Session.OutputDirPath;
end;

function ResolveRuntimeRootPath(const ATargetConfig: TTargetConfig): string;
begin
  if Trim(ATargetConfig.RuntimeSdkId) = '' then
    Exit('');

  Result := ExpandFileName(
    IncludeTrailingPathDelimiter(ATargetConfig.DistributionLibDir) +
    'nextpas' + DirectorySeparator + 'runtime' + DirectorySeparator +
    ATargetConfig.RuntimeSdkId
  );
end;

procedure CaptureToolchainProjectionFromTargetConfig(
  var AContext: TToolchainProjectionContext;
  const ATargetConfig: TTargetConfig
);
begin
  AContext.HostId := ATargetConfig.HostId;
  AContext.ToolchainBindingId := ATargetConfig.ToolchainBindingId;
  AContext.BackendFamily := ATargetConfig.BackendFamily;
  AContext.AssemblerProfileId := ATargetConfig.AssemblerProfileId;
  AContext.LinkerProfileId := ATargetConfig.LinkerProfileId;
  AContext.ArchiverProfileId := ATargetConfig.ArchiverProfileId;
  AContext.ResourceToolProfileId := ATargetConfig.ResourceToolProfileId;
  AContext.TargetObjectFormat := ATargetConfig.ObjectFormat;
  AContext.TargetAssemblerFlavor := ATargetConfig.AssemblerFlavor;
  AContext.TargetLinkerFlavor := ATargetConfig.LinkerFlavor;
  AContext.TargetRuntimeLayoutKey := ATargetConfig.RuntimeLayoutKey;
  AContext.TargetCSymbolPrefix := ATargetConfig.CSymbolPrefix;
  AContext.TargetCLibraryNaming := ATargetConfig.CLibraryNaming;
  AContext.TargetLlvmTriple := ATargetConfig.LlvmTriple;
  AContext.TargetLlvmDataLayout := ATargetConfig.LlvmDataLayout;
  AContext.SysrootMode := ATargetConfig.SysrootMode;
  AContext.RuntimeSdkId := ATargetConfig.RuntimeSdkId;
  AContext.AllowHostFallback := ATargetConfig.AllowHostFallback;
  AContext.ToolRootKind := ATargetConfig.ToolRootKind;
  AContext.RuntimeRootKind := ATargetConfig.RuntimeRootKind;
  AContext.ResponseFilePolicy := ATargetConfig.ResponseFilePolicy;
  AContext.LinkScriptPolicy := ATargetConfig.LinkScriptPolicy;
  AContext.ToolProfileRoot := ResolveToolProfileRoot(ATargetConfig.ConfigPath);
  if ATargetConfig.LlvmEnabled then
    AContext.LlvmToolchainStatus := 'enabled'
  else
    AContext.LlvmToolchainStatus := 'disabled';
  AContext.LlvmExecutableSetId := ATargetConfig.LlvmExecutableSetId;
end;

procedure CaptureEnvironmentProjectionFromTargetConfig(
  var AContext: TEnvironmentProjectionContext;
  const ATargetConfig: TTargetConfig
);
var
  DistributionReady: Boolean;
  RuntimeRootPath: string;
  ToolchainBindingReady: Boolean;
begin
  RuntimeRootPath := ResolveRuntimeRootPath(ATargetConfig);
  AContext.ToolchainBindingPath := ATargetConfig.ToolchainBindingPath;
  AContext.DistributionBinDir := ATargetConfig.DistributionBinDir;
  AContext.DistributionLibDir := ATargetConfig.DistributionLibDir;
  AContext.DistributionShareDir := ATargetConfig.DistributionShareDir;
  AContext.RuntimeRootPath := RuntimeRootPath;
  if RuntimeRootPath <> '' then
    AContext.RuntimeLibcPath := ExpandFileName(
      IncludeTrailingPathDelimiter(RuntimeRootPath) + 'libc.so'
    )
  else
    AContext.RuntimeLibcPath := '';
  AContext.HasRuntimeLibcPresent := AContext.RuntimeLibcPath <> '';
  AContext.RuntimeLibcPresent := FileExists(AContext.RuntimeLibcPath);
  ToolchainBindingReady := (AContext.ToolchainBindingPath <> '') and
    FileExists(AContext.ToolchainBindingPath);
  DistributionReady := DirectoryExists(AContext.DistributionBinDir) and
    DirectoryExists(AContext.DistributionLibDir) and
    DirectoryExists(AContext.DistributionShareDir);

  if ToolchainBindingReady then
    AContext.ToolchainBindingStatus := 'ready'
  else
    AContext.ToolchainBindingStatus := 'missing';

  if DistributionReady then
    AContext.DistributionStatus := 'ready'
  else
    AContext.DistributionStatus := 'incomplete';

  if AContext.RuntimeLibcPresent then
    AContext.RuntimeSdkStatus := 'ready'
  else
    AContext.RuntimeSdkStatus := 'missing';

  if AContext.RuntimeLibcPresent and ToolchainBindingReady and DistributionReady then
    AContext.EnvironmentStatus := 'ready'
  else
    AContext.EnvironmentStatus := 'incomplete';
  AContext.EnvironmentReadiness := AContext.EnvironmentStatus;
end;

function DoctorFindingJson(const AFinding: TDoctorFinding): string;
var
  Fields: string;
begin
  Fields := '';
  AppendJsonStringField(Fields, 'code', AFinding.Code);
  AppendJsonStringField(Fields, 'severity', AFinding.Severity);
  AppendJsonStringField(Fields, 'subject', AFinding.Subject);
  AppendJsonStringField(Fields, 'summary', AFinding.Summary);
  AppendJsonStringField(Fields, 'suggestedAction', AFinding.SuggestedAction);
  Result := '{' + Fields + '}';
end;

procedure AddDoctorFinding(
  var AContext: TDoctorProjectionContext;
  const ACode: string;
  const ASeverity: string;
  const ASubject: string;
  const ASummary: string;
  const ASuggestedAction: string
);
var
  Finding: TDoctorFinding;
begin
  Finding.Code := ACode;
  Finding.Severity := ASeverity;
  Finding.Subject := ASubject;
  Finding.Summary := ASummary;
  Finding.SuggestedAction := ASuggestedAction;

  if AContext.FirstFinding.Code = '' then
    AContext.FirstFinding := Finding;

  if AContext.FindingsJson = '' then
    AContext.FindingsJson := '[' + DoctorFindingJson(Finding)
  else
    AContext.FindingsJson := AContext.FindingsJson + ',' + DoctorFindingJson(Finding);

  Inc(AContext.FindingCount);
end;

procedure CaptureDoctorProjectionFromEnvironment(
  var AContext: TDoctorProjectionContext;
  const AEnvironmentContext: TEnvironmentProjectionContext;
  const APackageContext: TPackageProjectionContext;
  const AWorkspaceRoot: string
);
begin
  AContext.CheckCount := 3;
  AContext.FindingCount := 0;
  ClearDoctorFindingValue(AContext.FirstFinding);
  AContext.FindingsJson := '';
  if AWorkspaceRoot <> '' then
    AContext.WorkspaceStatus := 'ready'
  else
    AContext.WorkspaceStatus := 'not-provided';
  if AEnvironmentContext.ToolchainBindingStatus <> '' then
    AContext.ToolchainBindingStatus := AEnvironmentContext.ToolchainBindingStatus
  else if (AEnvironmentContext.ToolchainBindingPath <> '') and
    FileExists(AEnvironmentContext.ToolchainBindingPath) then
      AContext.ToolchainBindingStatus := 'ready'
  else
    AContext.ToolchainBindingStatus := 'missing';

  if (not AEnvironmentContext.HasRuntimeLibcPresent) or
    (not AEnvironmentContext.RuntimeLibcPresent) then
    AddDoctorFinding(
      AContext,
      'doctor.runtime-sdk-missing',
      'warning',
      'runtime-sdk:' + AEnvironmentContext.RuntimeLibcPath,
      'runtime SDK libc is missing',
      'provide lib/nextpas/runtime/linux-x86_64/libc.so or run env sync when it is available'
    );

  if AWorkspaceRoot <> '' then
  begin
    Inc(AContext.CheckCount);
    if not DirectoryExists(AWorkspaceRoot) then
    begin
      AContext.WorkspaceStatus := 'missing';
      AddDoctorFinding(
        AContext,
        'doctor.workspace-root-missing',
        'warning',
        'workspace:' + AWorkspaceRoot,
        'workspace root is missing',
        'pass an existing workspace root'
      );
    end;

    Inc(AContext.CheckCount);
    if (APackageContext.WorkflowStatus <> 'ready') or
      (APackageContext.SourceRootCount <= 0) then
      AddDoctorFinding(
        AContext,
        'doctor.package-workspace-missing',
        'warning',
        'package-workspace:' + AWorkspaceRoot,
        'package workspace truth is missing',
        'add nextpas.package.toml with at least one source root or point --workspace at a package workspace'
      );
  end;

  if AContext.FindingsJson <> '' then
    AContext.FindingsJson := AContext.FindingsJson + ']';

  if AContext.FindingCount > 0 then
    AContext.Status := 'warning'
  else
    AContext.Status := 'healthy';
end;

procedure CapturePackageProjectionFromWorkflowTruth(
  var AContext: TPackageProjectionContext;
  const AWorkflowTruth: TPackageWorkflowTruth
);
begin
  AContext.WorkflowStatus := AWorkflowTruth.Status;
  AContext.ManifestStatus := AWorkflowTruth.ManifestTruth.Status;
  AContext.LockStatus := AWorkflowTruth.LockTruth.Status;
  AContext.InstallPlanStatus := AWorkflowTruth.InstallPlanTruth.Status;
  AContext.ManifestPath := AWorkflowTruth.ManifestTruth.ManifestPath;
  AContext.PackageRootPath := AWorkflowTruth.ManifestTruth.PackageRootPath;
  AContext.PackageName := AWorkflowTruth.ManifestTruth.PackageName;
  AContext.LockfilePath := AWorkflowTruth.LockTruth.LockfilePath;
  AContext.SourceRootCount := AWorkflowTruth.PackageSourceRootCount;
  AContext.HasSourceRootCount := AWorkflowTruth.ManifestTruth.Status <> '';
  AContext.SourceRootsJson := BuildJsonStringArray(
    AWorkflowTruth.ManifestTruth.SourceRoots
  );
  AContext.DependencyCount := AWorkflowTruth.PackageDependencyCount;
  AContext.HasDependencyCount := AWorkflowTruth.ManifestTruth.Status <> '';
  AContext.DependenciesJson := BuildJsonDependencyArray(
    AWorkflowTruth.ManifestTruth.Dependencies
  );
end;

function ResolvePackageInspectionSourcePath(const AWorkspaceRoot: string): string;
var
  ManifestPath: string;
  WorkspaceDescriptorPath: string;
begin
  ManifestPath := ExpandFileName(
    IncludeTrailingPathDelimiter(AWorkspaceRoot) + 'nextpas.package.toml'
  );
  if FileExists(ManifestPath) then
    Exit(ManifestPath);

  WorkspaceDescriptorPath := ExpandFileName(
    IncludeTrailingPathDelimiter(AWorkspaceRoot) + 'nextpas.workspace.toml'
  );
  if FileExists(WorkspaceDescriptorPath) then
    Exit(WorkspaceDescriptorPath);

  Result := ExpandFileName(AWorkspaceRoot);
end;

procedure CaptureSessionProjectionContextValue(
  var AContext: TSessionProjectionContext;
  const Session: TCompilationSession
);
begin
  AContext.SessionId := Session.SessionId;
  AContext.SessionLifetime := Session.SessionLifetimeSummary;
  AContext.UnitLifetime := Session.UnitLifetimeSummary;
  AContext.StageLifetime := Session.StageLifetimeSummary;
  AContext.SourceLineIndexState := Session.SourceDatabase.LineIndexState;
  AContext.RootFileId := Session.RootFileId;
  AContext.SourceFileCount := Session.SourceFileCount;
  AContext.UnitStateCount := Session.UnitStateCount;
end;

procedure CaptureDiagnosticProjectionContextValue(
  var AContext: TDiagnosticProjectionContext;
  const Session: TCompilationSession
);
begin
  AContext.Policy := Session.DiagnosticsPolicyName;
  AContext.Count := Session.DiagnosticsCount;
  AContext.ErrorCount := Session.DiagnosticsErrorCount;
  AContext.WarningCount := Session.DiagnosticsWarningCount;
  AContext.Summary := Session.DiagnosticsSummary;
  AContext.Json := Session.DiagnosticsJson;
  AContext.Id := Session.LastDiagnosticId;
  AContext.Code := Session.LastDiagnosticCode;
  AContext.Phase := Session.LastDiagnosticPhase;
  AContext.Message := Session.LastDiagnosticMessage;
  AContext.BindingId := Session.LastDiagnosticBindingId;
  AContext.ProfileId := Session.LastDiagnosticProfileId;
  AContext.StepId := Session.LastDiagnosticStepId;
  AContext.LogicalExecutable := Session.LastDiagnosticLogicalExecutable;
  AContext.SysrootRef := Session.LastDiagnosticSysrootRef;
  AContext.ResolvedPath := Session.LastDiagnosticResolvedPath;
  AContext.PrimaryArtifactKind := Session.LastDiagnosticPrimaryArtifactKind;
  AContext.PrimaryArtifactPath := Session.LastDiagnosticPrimaryArtifactPath;
  AContext.ExitCode := Session.LastDiagnosticExitCode;
  AContext.HasExitCode := Session.HasLastDiagnosticExitCode;
end;

procedure CaptureSyntaxProjectionContextValue(
  var AContext: TSyntaxProjectionContext;
  const Session: TCompilationSession
);
begin
  AContext.Status := Session.SyntaxStatus;
  AContext.LexerTokenCount := Session.LexerTokenCount;
  AContext.GreenNodeCount := Session.GreenNodeCount;
  AContext.AstRootKind := Session.AstRootKindName;
  AContext.AstDeclaredName := Session.AstDeclaredName;
end;

procedure CaptureResolutionProjectionContextValue(
  var AContext: TResolutionProjectionContext;
  const Session: TCompilationSession
);
begin
  AContext.Status := Session.ResolutionStatus;
  AContext.UnitGraphStatus := Session.UnitGraphStatus;
  AContext.SearchPathCount := Session.SearchPathCount;
  AContext.SearchIndexStatus := Session.SearchIndexStatus;
  AContext.IndexedSearchRootCount := Session.IndexedSearchRootCount;
  AContext.SearchIndexScanCount := Session.SearchIndexScanCount;
  AContext.SearchPathJson := Session.SearchPathsJson;
  AContext.ResolvedUnitCount := Session.ResolvedUnitCount;
  AContext.UnitGraphEdgeCount := Session.UnitGraphEdgeCount;
  AContext.UnitGraphRootName := Session.UnitGraphRootName;
end;

procedure CaptureSemanticProjectionContextValue(
  var AContext: TSemanticProjectionContext;
  const Session: TCompilationSession
);
begin
  AContext.Status := Session.SemanticStatus;
  AContext.SymbolGraphStatus := Session.SymbolGraphStatus;
  AContext.TypeGraphStatus := Session.TypeGraphStatus;
  AContext.TypedHirStatus := Session.TypedHirStatus;
  AContext.SymbolCount := Session.SymbolCount;
  AContext.TypeCount := Session.TypeCount;
  AContext.TypedHirNodeCount := Session.TypedHirNodeCount;
  AContext.RuntimeContractCount := Session.RuntimeContractCount;
  AContext.TypedHirRootName := Session.TypedHirRootName;
end;

procedure CaptureMirProjectionContextValue(
  var AContext: TMirProjectionContext;
  const Session: TCompilationSession
);
begin
  AContext.Status := Session.MirStatus;
  AContext.BlockCount := Session.MirBlockCount;
  AContext.OperationCount := Session.MirOperationCount;
  AContext.EntryBlock := Session.MirEntryBlockLabel;
  AContext.RootName := Session.MirRootName;
end;

procedure CaptureBackendProjectionContextValue(
  var AContext: TBackendProjectionContext;
  const Session: TCompilationSession
);
begin
  AContext.PlanStatus := Session.BackendPlanStatus;
  AContext.OutputKind := Session.BackendOutputKind;
  AContext.PrimaryArtifactKind := Session.BackendPrimaryArtifactKind;
  AContext.PrimaryArtifactPath := Session.BackendPrimaryArtifactPath;
  AContext.ArtifactCount := Session.BackendArtifactCount;
  AContext.ArtifactsJson := Session.BackendArtifactsJson;
end;

procedure CaptureToolchainProjectionContextValue(
  var AContext: TToolchainProjectionContext;
  const Session: TCompilationSession
);
begin
  AContext.HostId := Session.HostId;
  AContext.ToolchainBindingId := Session.ToolchainBindingId;
  AContext.BackendFamily := Session.BackendFamily;
  AContext.AssemblerProfileId := Session.AssemblerProfileId;
  AContext.LinkerProfileId := Session.LinkerProfileId;
  AContext.ArchiverProfileId := Session.ArchiverProfileId;
  AContext.ResourceToolProfileId := Session.ResourceToolProfileId;
  AContext.TargetObjectFormat := Session.TargetObjectFormat;
  AContext.TargetAssemblerFlavor := Session.TargetAssemblerFlavor;
  AContext.TargetLinkerFlavor := Session.TargetLinkerFlavor;
  AContext.TargetRuntimeLayoutKey := Session.TargetRuntimeLayoutKey;
  AContext.TargetCSymbolPrefix := Session.TargetCSymbolPrefix;
  AContext.TargetCLibraryNaming := Session.TargetCLibraryNaming;
  AContext.TargetLlvmTriple := Session.TargetLlvmTriple;
  AContext.TargetLlvmDataLayout := Session.TargetLlvmDataLayout;
  AContext.SysrootMode := Session.SysrootMode;
  AContext.RuntimeSdkId := Session.RuntimeSdkId;
  AContext.AllowHostFallback := Session.AllowHostFallback;
  AContext.ToolRootKind := Session.ToolRootKind;
  AContext.RuntimeRootKind := Session.RuntimeRootKind;
  AContext.ResponseFilePolicy := Session.ResponseFilePolicy;
  AContext.LinkScriptPolicy := Session.LinkScriptPolicy;
  AContext.ToolchainPlanStatus := Session.ToolchainPlanStatus;
  AContext.ToolchainPlanFamily := Session.ToolchainPlanFamily;
  AContext.ToolProfileRoot := Session.ToolProfileRoot;
  AContext.LogicalLinkRequestStatus := Session.LogicalLinkRequestStatus;
  AContext.LogicalLinkRequestOutputKind := Session.LogicalLinkRequestOutputKind;
  AContext.LogicalLibraryRequestCount := Session.LogicalLibraryRequestCount;
  AContext.LogicalLinkRequestJson := Session.LogicalLinkRequestJson;
  AContext.LlvmToolchainStatus := Session.LlvmToolchainStatus;
  AContext.LlvmExecutableSetId := Session.LlvmExecutableSetId;
  AContext.LlvmExecutableSetJson := Session.LlvmExecutableSetJson;
  AContext.ToolInvocationCount := Session.ToolInvocationCount;
  AContext.ToolRunStatus := Session.ToolRunStatus;
  AContext.ToolRunStepCount := Session.ToolRunStepCount;
  AContext.PrimaryToolRunStatus := Session.PrimaryToolRunStatus;
  AContext.PrimaryToolRole := Session.PrimaryToolRole;
  AContext.PrimaryToolProfileId := Session.PrimaryToolProfileId;
  AContext.PrimaryToolStepId := Session.PrimaryToolStepId;
  AContext.PrimaryToolLogicalExecutable := Session.PrimaryToolLogicalExecutable;
  AContext.PrimaryToolSysrootRef := Session.PrimaryToolSysrootRef;
  AContext.PrimaryToolFailureMapping := Session.PrimaryToolFailureMapping;
  AContext.ToolInvocationPlanRef := Session.ToolInvocationPlanRef;
  AContext.ToolInvocationPlanJson := Session.ToolInvocationPlanJson;
  AContext.ToolStatusEventCount := Session.ToolStatusEventCount;
  AContext.ToolStatusEventsJson := Session.ToolStatusEventsJson;
  AContext.BuildTraceRef := Session.BuildTraceRef;
  AContext.BuildTraceJson := Session.BuildTraceJson;
end;

procedure ClearBuildCommandContext(var AState: TNextPasState);
begin
  ClearBuildCommandContextValue(AState.BuildContext);
end;

procedure ClearSessionContext(var AState: TNextPasState);
begin
  ClearSessionProjectionContextValue(AState.SessionProjection);
  ClearDiagnosticProjectionContextValue(AState.DiagnosticsProjection);
  ClearSyntaxProjectionContextValue(AState.SyntaxProjection);
  ClearResolutionProjectionContextValue(AState.ResolutionProjection);
  ClearSemanticProjectionContextValue(AState.SemanticProjection);
  ClearMirProjectionContextValue(AState.MirProjection);
  ClearBackendProjectionContextValue(AState.BackendProjection);
  ClearToolchainProjectionContextValue(AState.ToolchainProjection);
  ClearEnvironmentProjectionContextValue(AState.EnvironmentProjection);
  ClearDoctorProjectionContextValue(AState.DoctorProjection);
  ClearQueryProjectionContextValue(AState.QueryProjection);
  ClearPackageProjectionContextValue(AState.PackageProjection);
end;

procedure CaptureBuildCommandContext(var AState: TNextPasState; 
  const ASourcePath: string;
  const ATargetName: string;
  const AWorkspaceModel: TWorkspaceModel
);
begin
  CaptureBuildCommandContextValue(
    AState.BuildContext,
    ASourcePath,
    ATargetName,
    AWorkspaceModel
  );
end;

procedure CaptureSessionContext(var AState: TNextPasState; const Session: TCompilationSession);
begin
  CaptureBuildContextFromSession(AState.BuildContext, Session);
  CaptureSessionProjectionContextValue(AState.SessionProjection, Session);
  CaptureDiagnosticProjectionContextValue(AState.DiagnosticsProjection, Session);
  CaptureSyntaxProjectionContextValue(AState.SyntaxProjection, Session);
  CaptureResolutionProjectionContextValue(AState.ResolutionProjection, Session);
  CaptureSemanticProjectionContextValue(AState.SemanticProjection, Session);
  CaptureMirProjectionContextValue(AState.MirProjection, Session);
  CaptureBackendProjectionContextValue(AState.BackendProjection, Session);
  CaptureToolchainProjectionContextValue(AState.ToolchainProjection, Session);
end;

end.
