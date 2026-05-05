program nextpas;

{$mode objfpc}{$H+}
{$UNITPATH ../../compiler/backend}
{$UNITPATH ../../compiler/frontend}
{$UNITPATH ../../compiler/diagnostics}
{$UNITPATH ../../compiler/ir}
{$UNITPATH ../../compiler/sema}
{$UNITPATH ../../compiler/syntax}
{$UNITPATH ../../compiler/toolchain}
{$UNITPATH ../../compiler/targets}

uses
  SysUtils, process, target_config, nextpas_json_helpers, nextpas_projection_types,
  nextpas_projection_json,
  np_compilation_session, np_target_facts,
  np_package_workflow, np_toolchain_profiles, np_toolchain_runner,
  np_workspace_model;

const
  ExitSuccessCode = 0;
  ExitFailureCode = 1;

var
  State: TNextPasState;

function EnvelopeCommandName: string;
begin
  if State.CommandName <> '' then
    Exit(State.CommandName);

  Result := 'cli';
end;

function EnvelopeSelectorName: string;
begin
  if State.SelectorName <> '' then
    Exit(State.SelectorName);
  if State.CommandName = 'build' then
    Exit('build');
  if State.CommandName = 'test' then
    Exit('test');
  if State.CommandName = 'env' then
    Exit('env');
  if State.CommandName = 'doctor' then
    Exit('doctor');
  if State.CommandName = 'query' then
    Exit('query');
  if State.CommandName = 'pkg' then
    Exit('pkg');

  Result := 'cli';
end;

function FailureKindFromMessage(const Message: string): string;
var
  SeparatorPosition: SizeInt;
begin
  SeparatorPosition := Pos(':', Message);
  if SeparatorPosition > 1 then
    Exit(Copy(Message, 1, SeparatorPosition - 1));

  Result := Message;
end;

procedure WriteUsageLine(const UseStdErr: Boolean; const Value: string);
begin
  if UseStdErr then
    WriteLn(ErrOutput, Value)
  else
    WriteLn(Value);
end;

procedure PrintBuildUsage(const UseStdErr: Boolean);
begin
  WriteUsageLine(UseStdErr, 'Usage:');
  WriteUsageLine(
    UseStdErr,
    '  nextpas build <source> --target linux-x86_64 ' +
    '[--toolchain-binding <id>] [--workspace <root>] ' +
    '[--unit-root <dir>]... [--out-dir <dir>]'
  );
end;

procedure PrintTestUsage(const UseStdErr: Boolean);
begin
  WriteUsageLine(UseStdErr, 'Usage:');
  WriteUsageLine(
    UseStdErr,
    '  nextpas test --list-groups [--workspace <root>]'
  );
  WriteUsageLine(
    UseStdErr,
    '  nextpas test --filter <group> [--workspace <root>]'
  );
end;

procedure PrintEnvUsage(const UseStdErr: Boolean);
begin
  WriteUsageLine(UseStdErr, 'Usage:');
  WriteUsageLine(
    UseStdErr,
    '  nextpas env status --target linux-x86_64 [--toolchain-binding <id>]'
  );
end;

procedure PrintDoctorUsage(const UseStdErr: Boolean);
begin
  WriteUsageLine(UseStdErr, 'Usage:');
  WriteUsageLine(
    UseStdErr,
    '  nextpas doctor --target linux-x86_64 ' +
    '[--toolchain-binding <id>] [--workspace <root>]'
  );
end;

procedure PrintQueryUsage(const UseStdErr: Boolean);
begin
  WriteUsageLine(UseStdErr, 'Usage:');
  WriteUsageLine(
    UseStdErr,
    '  nextpas query symbols <source> --target linux-x86_64 ' +
    '[--toolchain-binding <id>] [--workspace <root>]'
  );
end;

procedure PrintPkgUsage(const UseStdErr: Boolean);
begin
  WriteUsageLine(UseStdErr, 'Usage:');
  WriteUsageLine(
    UseStdErr,
    '  nextpas pkg inspect --workspace <root> --target linux-x86_64 ' +
    '[--toolchain-binding <id>]'
  );
end;

procedure PrintUsage;
begin
  if State.CommandName = 'build' then
  begin
    PrintBuildUsage(False);
    Exit;
  end;

  if State.CommandName = 'test' then
  begin
    PrintTestUsage(False);
    Exit;
  end;

  if State.CommandName = 'env' then
  begin
    PrintEnvUsage(False);
    Exit;
  end;

  if State.CommandName = 'doctor' then
  begin
    PrintDoctorUsage(False);
    Exit;
  end;

  if State.CommandName = 'query' then
  begin
    PrintQueryUsage(False);
    Exit;
  end;

  if State.CommandName = 'pkg' then
  begin
    PrintPkgUsage(False);
    Exit;
  end;

  WriteUsageLine(False, 'Usage:');
  WriteUsageLine(
    False,
    '  nextpas build <source> --target linux-x86_64 ' +
    '[--toolchain-binding <id>] [--workspace <root>] ' +
    '[--unit-root <dir>]... [--out-dir <dir>]'
  );
  WriteUsageLine(
    False,
    '  nextpas test --list-groups [--workspace <root>]'
  );
  WriteUsageLine(
    False,
    '  nextpas test --filter <group> [--workspace <root>]'
  );
  WriteUsageLine(
    False,
    '  nextpas env status --target linux-x86_64 [--toolchain-binding <id>]'
  );
  WriteUsageLine(
    False,
    '  nextpas doctor --target linux-x86_64 ' +
    '[--toolchain-binding <id>] [--workspace <root>]'
  );
  WriteUsageLine(
    False,
    '  nextpas query symbols <source> --target linux-x86_64 ' +
    '[--toolchain-binding <id>] [--workspace <root>]'
  );
  WriteUsageLine(
    False,
    '  nextpas pkg inspect --workspace <root> --target linux-x86_64 ' +
    '[--toolchain-binding <id>]'
  );
end;

procedure PrintUsageError;
begin
  if State.CommandName = 'build' then
  begin
    PrintBuildUsage(True);
    Exit;
  end;

  if State.CommandName = 'test' then
  begin
    PrintTestUsage(True);
    Exit;
  end;

  if State.CommandName = 'env' then
  begin
    PrintEnvUsage(True);
    Exit;
  end;

  if State.CommandName = 'doctor' then
  begin
    PrintDoctorUsage(True);
    Exit;
  end;

  if State.CommandName = 'query' then
  begin
    PrintQueryUsage(True);
    Exit;
  end;

  if State.CommandName = 'pkg' then
  begin
    PrintPkgUsage(True);
    Exit;
  end;

  WriteUsageLine(True, 'Usage:');
  WriteUsageLine(
    True,
    '  nextpas build <source> --target linux-x86_64 ' +
    '[--toolchain-binding <id>] [--workspace <root>] ' +
    '[--unit-root <dir>]... [--out-dir <dir>]'
  );
  WriteUsageLine(
    True,
    '  nextpas test --list-groups [--workspace <root>]'
  );
  WriteUsageLine(
    True,
    '  nextpas test --filter <group> [--workspace <root>]'
  );
  WriteUsageLine(
    True,
    '  nextpas env status --target linux-x86_64 [--toolchain-binding <id>]'
  );
  WriteUsageLine(
    True,
    '  nextpas doctor --target linux-x86_64 ' +
    '[--toolchain-binding <id>] [--workspace <root>]'
  );
  WriteUsageLine(
    True,
    '  nextpas query symbols <source> --target linux-x86_64 ' +
    '[--toolchain-binding <id>] [--workspace <root>]'
  );
  WriteUsageLine(
    True,
    '  nextpas pkg inspect --workspace <root> --target linux-x86_64 ' +
    '[--toolchain-binding <id>]'
  );
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

procedure ClearBuildCommandContext;
begin
  ClearBuildCommandContextValue(State.BuildContext);
end;

procedure ClearSessionContext;
begin
  ClearSessionProjectionContextValue(State.SessionProjection);
  ClearDiagnosticProjectionContextValue(State.DiagnosticsProjection);
  ClearSyntaxProjectionContextValue(State.SyntaxProjection);
  ClearResolutionProjectionContextValue(State.ResolutionProjection);
  ClearSemanticProjectionContextValue(State.SemanticProjection);
  ClearMirProjectionContextValue(State.MirProjection);
  ClearBackendProjectionContextValue(State.BackendProjection);
  ClearToolchainProjectionContextValue(State.ToolchainProjection);
  ClearEnvironmentProjectionContextValue(State.EnvironmentProjection);
  ClearDoctorProjectionContextValue(State.DoctorProjection);
  ClearQueryProjectionContextValue(State.QueryProjection);
  ClearPackageProjectionContextValue(State.PackageProjection);
end;

procedure CaptureBuildCommandContext(
  const ASourcePath: string;
  const ATargetName: string;
  const AWorkspaceModel: TWorkspaceModel
);
begin
  CaptureBuildCommandContextValue(
    State.BuildContext,
    ASourcePath,
    ATargetName,
    AWorkspaceModel
  );
end;

procedure CaptureSessionContext(const Session: TCompilationSession);
begin
  CaptureBuildContextFromSession(State.BuildContext, Session);
  CaptureSessionProjectionContextValue(State.SessionProjection, Session);
  CaptureDiagnosticProjectionContextValue(State.DiagnosticsProjection, Session);
  CaptureSyntaxProjectionContextValue(State.SyntaxProjection, Session);
  CaptureResolutionProjectionContextValue(State.ResolutionProjection, Session);
  CaptureSemanticProjectionContextValue(State.SemanticProjection, Session);
  CaptureMirProjectionContextValue(State.MirProjection, Session);
  CaptureBackendProjectionContextValue(State.BackendProjection, Session);
  CaptureToolchainProjectionContextValue(State.ToolchainProjection, Session);
end;

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

procedure PrintBuildContextProjection(const UseStdErr: Boolean);
begin
  WriteProjectionTextIfPresent(
    UseStdErr,
    'workspace-root',
    State.BuildContext.WorkspaceRootPath
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'workspace-discovery-kind',
    State.BuildContext.WorkspaceDiscoveryKind
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'workspace-descriptor-path',
    State.BuildContext.WorkspaceDescriptorPath
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'package-manifest-path',
    State.BuildContext.PackageManifestPath
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'artifact-root',
    State.BuildContext.ArtifactRootPath
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'output-dir',
    State.BuildContext.OutputDirPath
  );
end;

procedure PrintSessionIdentityProjection(const UseStdErr: Boolean);
begin
  WriteProjectionLine(
    UseStdErr,
    'session-id',
    State.SessionProjection.SessionId
  );
  WriteProjectionInteger(
    UseStdErr,
    'root-file-id',
    State.SessionProjection.RootFileId
  );
  WriteProjectionInteger(
    UseStdErr,
    'source-db-file-count',
    State.SessionProjection.SourceFileCount
  );
  WriteProjectionLine(
    UseStdErr,
    'source-db-line-index',
    State.SessionProjection.SourceLineIndexState
  );
  WriteProjectionInteger(
    UseStdErr,
    'unit-state-count',
    State.SessionProjection.UnitStateCount
  );
end;

procedure PrintDiagnosticsCountsProjection(const UseStdErr: Boolean);
begin
  WriteProjectionInteger(
    UseStdErr,
    'diagnostics-count',
    State.DiagnosticsProjection.Count
  );
  WriteProjectionInteger(
    UseStdErr,
    'diagnostics-error-count',
    State.DiagnosticsProjection.ErrorCount
  );
  WriteProjectionInteger(
    UseStdErr,
    'diagnostics-warning-count',
    State.DiagnosticsProjection.WarningCount
  );
  WriteProjectionLine(
    UseStdErr,
    'diagnostics-policy',
    State.DiagnosticsProjection.Policy
  );
end;

procedure PrintSyntaxProjectionFields(const UseStdErr: Boolean);
begin
  WriteProjectionLine(UseStdErr, 'syntax-status', State.SyntaxProjection.Status);
  WriteProjectionInteger(
    UseStdErr,
    'lexer-token-count',
    State.SyntaxProjection.LexerTokenCount
  );
  WriteProjectionInteger(
    UseStdErr,
    'green-node-count',
    State.SyntaxProjection.GreenNodeCount
  );
  WriteProjectionLine(
    UseStdErr,
    'ast-root-kind',
    State.SyntaxProjection.AstRootKind
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'ast-declared-name',
    State.SyntaxProjection.AstDeclaredName
  );
end;

procedure PrintResolutionProjectionFields(const UseStdErr: Boolean);
begin
  WriteProjectionLine(
    UseStdErr,
    'resolution-status',
    State.ResolutionProjection.Status
  );
  WriteProjectionLine(
    UseStdErr,
    'unit-graph-status',
    State.ResolutionProjection.UnitGraphStatus
  );
  WriteProjectionInteger(
    UseStdErr,
    'search-path-count',
    State.ResolutionProjection.SearchPathCount
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'search-index-status',
    State.ResolutionProjection.SearchIndexStatus
  );
  WriteProjectionInteger(
    UseStdErr,
    'indexed-search-root-count',
    State.ResolutionProjection.IndexedSearchRootCount
  );
  WriteProjectionInteger(
    UseStdErr,
    'search-index-scan-count',
    State.ResolutionProjection.SearchIndexScanCount
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'search-path-json',
    State.ResolutionProjection.SearchPathJson
  );
  WriteProjectionInteger(
    UseStdErr,
    'resolved-unit-count',
    State.ResolutionProjection.ResolvedUnitCount
  );
  WriteProjectionInteger(
    UseStdErr,
    'unit-graph-edge-count',
    State.ResolutionProjection.UnitGraphEdgeCount
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'unit-graph-root-name',
    State.ResolutionProjection.UnitGraphRootName
  );
end;

procedure PrintSemanticProjectionFields(const UseStdErr: Boolean);
begin
  WriteProjectionLine(
    UseStdErr,
    'semantic-status',
    State.SemanticProjection.Status
  );
  WriteProjectionLine(
    UseStdErr,
    'symbol-graph-status',
    State.SemanticProjection.SymbolGraphStatus
  );
  WriteProjectionLine(
    UseStdErr,
    'type-graph-status',
    State.SemanticProjection.TypeGraphStatus
  );
  WriteProjectionLine(
    UseStdErr,
    'typed-hir-status',
    State.SemanticProjection.TypedHirStatus
  );
  WriteProjectionInteger(
    UseStdErr,
    'symbol-count',
    State.SemanticProjection.SymbolCount
  );
  WriteProjectionInteger(
    UseStdErr,
    'type-count',
    State.SemanticProjection.TypeCount
  );
  WriteProjectionInteger(
    UseStdErr,
    'typed-hir-node-count',
    State.SemanticProjection.TypedHirNodeCount
  );
  WriteProjectionInteger(
    UseStdErr,
    'runtime-contract-count',
    State.SemanticProjection.RuntimeContractCount
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'typed-hir-root-name',
    State.SemanticProjection.TypedHirRootName
  );
end;

procedure PrintMirProjectionFields(const UseStdErr: Boolean);
begin
  WriteProjectionLine(UseStdErr, 'mir-status', State.MirProjection.Status);
  WriteProjectionInteger(
    UseStdErr,
    'mir-block-count',
    State.MirProjection.BlockCount
  );
  WriteProjectionInteger(
    UseStdErr,
    'mir-operation-count',
    State.MirProjection.OperationCount
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'mir-entry-block',
    State.MirProjection.EntryBlock
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'mir-root-name',
    State.MirProjection.RootName
  );
end;

procedure PrintBackendProjectionFields(const UseStdErr: Boolean);
begin
  WriteProjectionLine(
    UseStdErr,
    'backend-plan-status',
    State.BackendProjection.PlanStatus
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'backend-output-kind',
    State.BackendProjection.OutputKind
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'backend-primary-artifact-kind',
    State.BackendProjection.PrimaryArtifactKind
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'backend-primary-artifact-path',
    State.BackendProjection.PrimaryArtifactPath
  );
  WriteProjectionIntegerWhenEnabled(
    UseStdErr,
    'backend-artifact-count',
    State.BackendProjection.ArtifactCount,
    State.BackendProjection.ArtifactCount > 0
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'backend-artifacts',
    State.BackendProjection.ArtifactsJson
  );
end;

procedure PrintToolchainProjectionFields(const UseStdErr: Boolean);
begin
  WriteProjectionTextIfPresent(
    UseStdErr,
    'host-id',
    State.ToolchainProjection.HostId
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'toolchain-binding-id',
    State.ToolchainProjection.ToolchainBindingId
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'backend-family',
    State.ToolchainProjection.BackendFamily
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'assembler-profile-id',
    State.ToolchainProjection.AssemblerProfileId
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'linker-profile-id',
    State.ToolchainProjection.LinkerProfileId
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'archiver-profile-id',
    State.ToolchainProjection.ArchiverProfileId
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'resource-tool-profile-id',
    State.ToolchainProjection.ResourceToolProfileId
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'target-object-format',
    State.ToolchainProjection.TargetObjectFormat
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'target-assembler-flavor',
    State.ToolchainProjection.TargetAssemblerFlavor
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'target-linker-flavor',
    State.ToolchainProjection.TargetLinkerFlavor
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'target-runtime-layout-key',
    State.ToolchainProjection.TargetRuntimeLayoutKey
  );
  WriteProjectionTextWhenEnabled(
    UseStdErr,
    'target-c-symbol-prefix',
    State.ToolchainProjection.TargetCSymbolPrefix,
    State.ToolchainProjection.HostId <> ''
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'target-c-library-naming',
    State.ToolchainProjection.TargetCLibraryNaming
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'target-llvm-triple',
    State.ToolchainProjection.TargetLlvmTriple
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'target-llvm-data-layout',
    State.ToolchainProjection.TargetLlvmDataLayout
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'sysroot-mode',
    State.ToolchainProjection.SysrootMode
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'runtime-sdk-id',
    State.ToolchainProjection.RuntimeSdkId
  );
  WriteProjectionBooleanWhenEnabled(
    UseStdErr,
    'allow-host-fallback',
    State.ToolchainProjection.AllowHostFallback,
    State.ToolchainProjection.HostId <> ''
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'tool-root-kind',
    State.ToolchainProjection.ToolRootKind
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'runtime-root-kind',
    State.ToolchainProjection.RuntimeRootKind
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'response-file-policy',
    State.ToolchainProjection.ResponseFilePolicy
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'link-script-policy',
    State.ToolchainProjection.LinkScriptPolicy
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'toolchain-plan-status',
    State.ToolchainProjection.ToolchainPlanStatus
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'toolchain-plan-family',
    State.ToolchainProjection.ToolchainPlanFamily
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'tool-profile-root',
    State.ToolchainProjection.ToolProfileRoot
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'logical-link-request-status',
    State.ToolchainProjection.LogicalLinkRequestStatus
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'logical-link-request-output-kind',
    State.ToolchainProjection.LogicalLinkRequestOutputKind
  );
  WriteProjectionInteger(
    UseStdErr,
    'logical-link-request-library-count',
    State.ToolchainProjection.LogicalLibraryRequestCount
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'logical-link-request',
    State.ToolchainProjection.LogicalLinkRequestJson
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'llvm-toolchain-status',
    State.ToolchainProjection.LlvmToolchainStatus
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'llvm-executable-set-id',
    State.ToolchainProjection.LlvmExecutableSetId
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'llvm-executable-set',
    State.ToolchainProjection.LlvmExecutableSetJson
  );
  WriteProjectionInteger(
    UseStdErr,
    'tool-invocation-count',
    State.ToolchainProjection.ToolInvocationCount
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'tool-run-status',
    State.ToolchainProjection.ToolRunStatus
  );
  WriteProjectionIntegerWhenEnabled(
    UseStdErr,
    'tool-run-step-count',
    State.ToolchainProjection.ToolRunStepCount,
    State.ToolchainProjection.ToolRunStepCount > 0
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'primary-tool-run-status',
    State.ToolchainProjection.PrimaryToolRunStatus
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'primary-tool-role',
    State.ToolchainProjection.PrimaryToolRole
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'primary-tool-profile-id',
    State.ToolchainProjection.PrimaryToolProfileId
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'primary-tool-step-id',
    State.ToolchainProjection.PrimaryToolStepId
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'primary-tool-logical-executable',
    State.ToolchainProjection.PrimaryToolLogicalExecutable
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'primary-tool-sysroot-ref',
    State.ToolchainProjection.PrimaryToolSysrootRef
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'primary-tool-failure-mapping',
    State.ToolchainProjection.PrimaryToolFailureMapping
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'tool-invocation-plan-ref',
    State.ToolchainProjection.ToolInvocationPlanRef
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'tool-invocation-plan',
    State.ToolchainProjection.ToolInvocationPlanJson
  );
  WriteProjectionIntegerWhenEnabled(
    UseStdErr,
    'tool-status-event-count',
    State.ToolchainProjection.ToolStatusEventCount,
    State.ToolchainProjection.ToolStatusEventCount > 0
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'tool-status-events',
    State.ToolchainProjection.ToolStatusEventsJson
  );
end;

procedure PrintEnvironmentProjectionFields(const UseStdErr: Boolean);
begin
  WriteProjectionTextIfPresent(
    UseStdErr,
    'toolchain-binding-path',
    State.EnvironmentProjection.ToolchainBindingPath
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'distribution-bin-dir',
    State.EnvironmentProjection.DistributionBinDir
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'distribution-lib-dir',
    State.EnvironmentProjection.DistributionLibDir
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'distribution-share-dir',
    State.EnvironmentProjection.DistributionShareDir
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'runtime-root',
    State.EnvironmentProjection.RuntimeRootPath
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'runtime-libc',
    State.EnvironmentProjection.RuntimeLibcPath
  );
  WriteProjectionBooleanWhenEnabled(
    UseStdErr,
    'runtime-libc-present',
    State.EnvironmentProjection.RuntimeLibcPresent,
    State.EnvironmentProjection.HasRuntimeLibcPresent
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'environment-readiness',
    State.EnvironmentProjection.EnvironmentReadiness
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'environment-status',
    State.EnvironmentProjection.EnvironmentStatus
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'runtime-sdk-status',
    State.EnvironmentProjection.RuntimeSdkStatus
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'toolchain-binding-status',
    State.EnvironmentProjection.ToolchainBindingStatus
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'distribution-status',
    State.EnvironmentProjection.DistributionStatus
  );
end;

procedure PrintDoctorProjectionFields(const UseStdErr: Boolean);
begin
  WriteProjectionTextIfPresent(
    UseStdErr,
    'doctor-workspace-status',
    State.DoctorProjection.WorkspaceStatus
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'doctor-toolchain-binding-status',
    State.DoctorProjection.ToolchainBindingStatus
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'doctor-status',
    State.DoctorProjection.Status
  );
  WriteProjectionIntegerWhenEnabled(
    UseStdErr,
    'doctor-check-count',
    State.DoctorProjection.CheckCount,
    State.DoctorProjection.CheckCount > 0
  );
  WriteProjectionIntegerWhenEnabled(
    UseStdErr,
    'doctor-finding-count',
    State.DoctorProjection.FindingCount,
    State.DoctorProjection.CheckCount > 0
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'doctor-finding-code',
    State.DoctorProjection.FirstFinding.Code
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'doctor-finding-severity',
    State.DoctorProjection.FirstFinding.Severity
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'doctor-finding-subject',
    State.DoctorProjection.FirstFinding.Subject
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'doctor-finding-summary',
    State.DoctorProjection.FirstFinding.Summary
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'doctor-finding-suggested-action',
    State.DoctorProjection.FirstFinding.SuggestedAction
  );
end;

procedure PrintQueryProjectionFields(const UseStdErr: Boolean);
begin
  WriteProjectionTextIfPresent(
    UseStdErr,
    'query-kind',
    State.QueryProjection.Kind
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'query-status',
    State.QueryProjection.Status
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'analysis-source',
    State.QueryProjection.AnalysisSource
  );
  WriteProjectionIntegerWhenEnabled(
    UseStdErr,
    'query-result-count',
    State.QueryProjection.ResultCount,
    State.QueryProjection.HasResultCount
  );
end;

procedure PrintPackageProjectionFields(const UseStdErr: Boolean);
begin
  WriteProjectionTextIfPresent(
    UseStdErr,
    'package-workflow-status',
    State.PackageProjection.WorkflowStatus
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'package-manifest-status',
    State.PackageProjection.ManifestStatus
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'package-lock-status',
    State.PackageProjection.LockStatus
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'package-install-plan-status',
    State.PackageProjection.InstallPlanStatus
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'package-root-path',
    State.PackageProjection.PackageRootPath
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'package-name',
    State.PackageProjection.PackageName
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'package-lockfile-path',
    State.PackageProjection.LockfilePath
  );
  WriteProjectionIntegerWhenEnabled(
    UseStdErr,
    'package-source-root-count',
    State.PackageProjection.SourceRootCount,
    State.PackageProjection.HasSourceRootCount
  );
end;

procedure PrintDiagnosticsDetailProjection(const UseStdErr: Boolean);
begin
  WriteProjectionLine(
    UseStdErr,
    'diagnostics-summary',
    State.DiagnosticsProjection.Summary
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'diagnostic-id',
    State.DiagnosticsProjection.Id
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'diagnostic-code',
    State.DiagnosticsProjection.Code
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'diagnostic-phase',
    State.DiagnosticsProjection.Phase
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'diagnostic-message',
    State.DiagnosticsProjection.Message
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'diagnostic-binding-id',
    State.DiagnosticsProjection.BindingId
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'diagnostic-profile-id',
    State.DiagnosticsProjection.ProfileId
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'diagnostic-step-id',
    State.DiagnosticsProjection.StepId
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'diagnostic-logical-executable',
    State.DiagnosticsProjection.LogicalExecutable
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'diagnostic-sysroot-ref',
    State.DiagnosticsProjection.SysrootRef
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'diagnostic-resolved-path',
    State.DiagnosticsProjection.ResolvedPath
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'diagnostic-primary-artifact-kind',
    State.DiagnosticsProjection.PrimaryArtifactKind
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'diagnostic-primary-artifact-path',
    State.DiagnosticsProjection.PrimaryArtifactPath
  );
  WriteProjectionIntegerWhenEnabled(
    UseStdErr,
    'diagnostic-exit-code',
    State.DiagnosticsProjection.ExitCode,
    State.DiagnosticsProjection.HasExitCode
  );
end;

procedure PrintBuildTraceProjection(const UseStdErr: Boolean);
begin
  WriteProjectionTextIfPresent(
    UseStdErr,
    'build-trace-ref',
    State.ToolchainProjection.BuildTraceRef
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'build-trace',
    State.ToolchainProjection.BuildTraceJson
  );
end;

procedure PrintLifecycleProjection(const UseStdErr: Boolean);
begin
  WriteProjectionLine(
    UseStdErr,
    'lifecycle-session',
    State.SessionProjection.SessionLifetime
  );
  WriteProjectionLine(
    UseStdErr,
    'lifecycle-unit',
    State.SessionProjection.UnitLifetime
  );
  WriteProjectionLine(
    UseStdErr,
    'lifecycle-stage',
    State.SessionProjection.StageLifetime
  );
end;

procedure PrintSessionProjection(const UseStdErr: Boolean);
begin
  PrintBuildContextProjection(UseStdErr);
  if State.SessionProjection.SessionId = '' then
    Exit;

  PrintSessionIdentityProjection(UseStdErr);
  PrintDiagnosticsCountsProjection(UseStdErr);
  PrintSyntaxProjectionFields(UseStdErr);
  PrintResolutionProjectionFields(UseStdErr);
  PrintSemanticProjectionFields(UseStdErr);
  PrintMirProjectionFields(UseStdErr);
  PrintBackendProjectionFields(UseStdErr);
  PrintToolchainProjectionFields(UseStdErr);
  PrintDiagnosticsDetailProjection(UseStdErr);
  PrintBuildTraceProjection(UseStdErr);
  PrintLifecycleProjection(UseStdErr);
end;

procedure Fail(const Message: string; ShowUsage: Boolean = False);
var
  FailureKind: string;
begin
  FailureKind := FailureKindFromMessage(Message);
  if State.CommandName <> '' then
    WriteLn(ErrOutput, 'command=', State.CommandName);
  WriteLn(ErrOutput, 'selector=', EnvelopeSelectorName);
  if State.BuildContext.TargetName <> '' then
    WriteLn(ErrOutput, 'target=', State.BuildContext.TargetName);
  PrintSessionProjection(True);
  WriteLn(ErrOutput, 'status=failure');
  WriteLn(ErrOutput, 'result=failure');
  WriteLn(ErrOutput, 'failure-kind=', FailureKind);
  WriteLn(ErrOutput, 'command-outcome=failure');
  PrintCommandEnvelope(
    State,
    ExitFailureCode,
    EnvelopeSelectorName,
    'failure',
    'failure',
    FailureKind,
    Message,
    True
  );
  WriteLn(ErrOutput, 'human-summary=', Message);
  WriteLn(ErrOutput, Message);
  if ShowUsage then
    PrintUsageError;
  Halt(ExitFailureCode);
end;

procedure AppendString(var AValues: TStringArray; const AValue: string);
var
  NextIndex: SizeInt;
begin
  NextIndex := Length(AValues);
  SetLength(AValues, NextIndex + 1);
  AValues[NextIndex] := AValue;
end;

function IsAbsolutePath(const APath: string): Boolean;
begin
  if APath = '' then
    Exit(False);

  if APath[1] = DirectorySeparator then
    Exit(True);

  Result := (Length(APath) >= 2) and (APath[2] = ':');
end;

function ResolveCliPath(const APath: string): string;
begin
  Result := ExpandFileName(APath);
end;

function ResolveWorkspaceRelativePath(
  const AWorkspaceRoot: string;
  const APath: string
): string;
begin
  if IsAbsolutePath(APath) then
    Exit(ExpandFileName(APath));

  Result := ExpandFileName(
    IncludeTrailingPathDelimiter(AWorkspaceRoot) + APath
  );
end;

function ResolveExplicitUnitRoots(
  const AWorkspaceRoot: string;
  const ARawUnitRoots: TStringArray
): TStringArray;
var
  Index: LongInt;
  ResolvedRoot: string;
begin
  Result := nil;
  SetLength(Result, 0);
  for Index := 0 to Length(ARawUnitRoots) - 1 do
  begin
    ResolvedRoot := ResolveWorkspaceRelativePath(
      AWorkspaceRoot,
      ARawUnitRoots[Index]
    );
    if not DirectoryExists(ResolvedRoot) then
      Fail('invalid-unit-root: ' + ARawUnitRoots[Index], True);
    AppendString(Result, ResolvedRoot);
  end;
end;

procedure EnsureDirectoryExists(
  const ARawPath: string;
  const AResolvedPath: string;
  const AFailureKind: string
);
begin
  if FileExists(AResolvedPath) and not DirectoryExists(AResolvedPath) then
    Fail(AFailureKind + ': ' + ARawPath, True);

  if DirectoryExists(AResolvedPath) then
    Exit;

  if not ForceDirectories(AResolvedPath) then
    Fail(AFailureKind + ': ' + ARawPath, True);
end;

function ResolveTestWorkspaceRoot(const AWorkspaceOverride: string): string;
begin
  if AWorkspaceOverride <> '' then
    Exit(ExpandFileName(AWorkspaceOverride));

  Result := ExpandFileName(GetCurrentDir);
end;

procedure RunTest(
  const AListGroups: Boolean;
  const AFilterName: string;
  const AWorkspaceOverride: string
);
var
  ExitCode: LongInt;
  HarnessScriptPath: string;
  Proc: TProcess;
  WorkspaceRoot: string;
begin
  WorkspaceRoot := ResolveTestWorkspaceRoot(AWorkspaceOverride);
  if not DirectoryExists(WorkspaceRoot) then
  begin
    if AWorkspaceOverride <> '' then
      Fail('invalid-workspace-root: ' + AWorkspaceOverride, True);
    Fail('invalid-workspace-root: ' + WorkspaceRoot, True);
  end;

  HarnessScriptPath := ExpandFileName(
    IncludeTrailingPathDelimiter(WorkspaceRoot) + 'tests' +
    DirectorySeparator + 'run_all_tests.sh'
  );
  if not FileExists(HarnessScriptPath) then
    Fail('missing-harness-script: ' + HarnessScriptPath, True);

  Proc := TProcess.Create(nil);
  try
    Proc.Executable := '/usr/bin/env';
    Proc.CurrentDirectory := WorkspaceRoot;
    Proc.Options := [poWaitOnExit];
    Proc.Parameters.Add('NEXTPAS_STAGE0=' + ExpandFileName(ParamStr(0)));
    Proc.Parameters.Add('NEXTPAS_WORKSPACE_ROOT=' + WorkspaceRoot);
    Proc.Parameters.Add('NEXTPAS_REPO_ROOT=' + WorkspaceRoot);
    Proc.Parameters.Add(HarnessScriptPath);
    if AListGroups then
      Proc.Parameters.Add('--list-groups')
    else
    begin
      Proc.Parameters.Add('--filter');
      Proc.Parameters.Add(AFilterName);
    end;
    Proc.Execute;
    ExitCode := Proc.ExitStatus;
  finally
    Proc.Free;
  end;

  Halt(ExitCode);
end;

procedure RunEnvStatus(
  const TargetName: string;
  const ToolchainBindingOverride: string
);
var
  TargetConfig: TTargetConfig;
begin
  State.BuildContext.TargetName := TargetName;
  try
    TargetConfig := LoadTargetConfig(
      TargetName,
      ParamStr(0),
      ToolchainBindingOverride
    );
  except
    on E: ETargetConfigError do
      Fail(E.Message);
  end;

  State.BuildContext.TargetConfigPath := TargetConfig.ConfigPath;
  State.BuildContext.CompilerName := TargetConfig.CompilerExecutable;
  CaptureToolchainProjectionFromTargetConfig(
    State.ToolchainProjection,
    TargetConfig
  );
  CaptureEnvironmentProjectionFromTargetConfig(
    State.EnvironmentProjection,
    TargetConfig
  );

  WriteLn('mode=env');
  WriteLn('command=env');
  WriteLn('selector=status');
  WriteLn('target=', TargetName);
  WriteLn('target-config=', TargetConfig.ConfigPath);
  WriteLn('compiler=', TargetConfig.CompilerExecutable);
  PrintBuildContextProjection(False);
  PrintToolchainProjectionFields(False);
  PrintEnvironmentProjectionFields(False);
  WriteLn('status=success');
  WriteLn('result=success');
  WriteLn('command-outcome=success');
  PrintCommandEnvelope(
    State,
    ExitSuccessCode,
    'status',
    'success',
    'success',
    '',
    'environment status captured',
    False
  );
  WriteLn('human-summary=environment status captured');
end;

procedure RunDoctor(
  const TargetName: string;
  const ToolchainBindingOverride: string;
  const WorkspaceOverride: string
);
var
  TargetConfig: TTargetConfig;
  WorkspaceRoot: string;
begin
  State.BuildContext.TargetName := TargetName;
  WorkspaceRoot := '';
  if WorkspaceOverride <> '' then
  begin
    WorkspaceRoot := ExpandFileName(WorkspaceOverride);
    if not DirectoryExists(WorkspaceRoot) then
      Fail('invalid-workspace-root: ' + WorkspaceOverride, True);
    State.BuildContext.WorkspaceRootPath := WorkspaceRoot;
    State.BuildContext.WorkspaceDiscoveryKind := 'explicit-workspace-override';
  end;

  try
    TargetConfig := LoadTargetConfig(
      TargetName,
      ParamStr(0),
      ToolchainBindingOverride
    );
  except
    on E: ETargetConfigError do
      Fail(E.Message);
  end;

  State.BuildContext.TargetConfigPath := TargetConfig.ConfigPath;
  State.BuildContext.CompilerName := TargetConfig.CompilerExecutable;
  CaptureToolchainProjectionFromTargetConfig(
    State.ToolchainProjection,
    TargetConfig
  );
  CaptureEnvironmentProjectionFromTargetConfig(
    State.EnvironmentProjection,
    TargetConfig
  );
  CaptureDoctorProjectionFromEnvironment(
    State.DoctorProjection,
    State.EnvironmentProjection,
    WorkspaceRoot
  );

  WriteLn('mode=doctor');
  WriteLn('command=doctor');
  WriteLn('selector=doctor');
  WriteLn('target=', TargetName);
  WriteLn('target-config=', TargetConfig.ConfigPath);
  WriteLn('compiler=', TargetConfig.CompilerExecutable);
  PrintBuildContextProjection(False);
  PrintToolchainProjectionFields(False);
  PrintEnvironmentProjectionFields(False);
  PrintDoctorProjectionFields(False);
  WriteLn('status=success');
  WriteLn('result=success');
  WriteLn('command-outcome=success');
  PrintCommandEnvelope(
    State,
    ExitSuccessCode,
    'doctor',
    'success',
    'success',
    '',
    'doctor inspection completed',
    False
  );
  WriteLn('human-summary=doctor inspection completed');
end;

procedure RunPkgInspect(
  const TargetName: string;
  const ToolchainBindingOverride: string;
  const WorkspaceOverride: string
);
var
  InspectionSourcePath: string;
  TargetConfig: TTargetConfig;
  WorkflowTruth: TPackageWorkflowTruth;
  WorkspaceModel: TWorkspaceModel;
  WorkspaceRoot: string;
begin
  State.BuildContext.TargetName := TargetName;
  if WorkspaceOverride = '' then
    Fail('missing-required-option: --workspace', True);

  WorkspaceRoot := ExpandFileName(WorkspaceOverride);
  if not DirectoryExists(WorkspaceRoot) then
    Fail('invalid-workspace-root: ' + WorkspaceOverride, True);

  InspectionSourcePath := ResolvePackageInspectionSourcePath(WorkspaceRoot);
  WorkspaceModel := nil;
  try
    WorkspaceModel := ResolveWorkspaceModel(
      InspectionSourcePath,
      WorkspaceRoot,
      TargetName,
      ''
    );
    CaptureBuildCommandContext('', TargetName, WorkspaceModel);

    try
      TargetConfig := LoadTargetConfig(
        TargetName,
        ParamStr(0),
        ToolchainBindingOverride
      );
    except
      on E: ETargetConfigError do
        Fail(E.Message);
    end;

    State.BuildContext.TargetConfigPath := TargetConfig.ConfigPath;
    State.BuildContext.CompilerName := TargetConfig.CompilerExecutable;
    CaptureToolchainProjectionFromTargetConfig(
      State.ToolchainProjection,
      TargetConfig
    );
    WorkflowTruth := BuildPackageWorkflowTruthFromWorkspaceModel(WorkspaceModel);
    CapturePackageProjectionFromWorkflowTruth(
      State.PackageProjection,
      WorkflowTruth
    );

    WriteLn('mode=pkg');
    WriteLn('command=pkg');
    WriteLn('selector=inspect');
    WriteLn('target=', TargetName);
    WriteLn('target-config=', TargetConfig.ConfigPath);
    WriteLn('compiler=', TargetConfig.CompilerExecutable);
    PrintBuildContextProjection(False);
    PrintToolchainProjectionFields(False);
    PrintPackageProjectionFields(False);
    WriteLn('status=success');
    WriteLn('result=success');
    WriteLn('command-outcome=success');
    PrintCommandEnvelope(
      State,
      ExitSuccessCode,
      'inspect',
      'success',
      'success',
      '',
      'package inspection completed',
      False
    );
    WriteLn('human-summary=package inspection completed');
  finally
    WorkspaceModel.Free;
  end;
end;

function TargetFactsFromConfig(const TargetConfig: TTargetConfig): TTargetFactsView;
begin
  Result := BuildTargetFactsView(
    TargetConfig.TargetId,
    TargetConfig.ConfigPath,
    TargetConfig.HostId,
    TargetConfig.HostOS,
    TargetConfig.HostCPU,
    TargetConfig.CompilerExecutable,
    TargetConfig.UnitsDir,
    TargetConfig.ObjectFormat,
    TargetConfig.AssemblerFlavor,
    TargetConfig.LinkerFlavor,
    TargetConfig.RuntimeLayoutKey,
    TargetConfig.CSymbolPrefix,
    TargetConfig.CLibraryNaming,
    TargetConfig.LlvmTriple,
    TargetConfig.LlvmDataLayout,
    TargetConfig.ToolchainBindingId,
    TargetConfig.HostCompilerProfileId,
    TargetConfig.BackendFamily,
    TargetConfig.AssemblerProfileId,
    TargetConfig.LinkerProfileId,
    TargetConfig.ArchiverProfileId,
    TargetConfig.ResourceToolProfileId,
    TargetConfig.SysrootMode,
    TargetConfig.RuntimeSdkId,
    TargetConfig.AllowHostFallback,
    TargetConfig.ToolRootKind,
    TargetConfig.RuntimeRootKind,
    TargetConfig.ResponseFilePolicy,
    TargetConfig.LinkScriptPolicy,
    TargetConfig.LlvmEnabled,
    TargetConfig.LlvmExecutableSetId
  );
end;

procedure RunQuerySymbols(
  const SourcePath: string;
  const TargetName: string;
  const ToolchainBindingOverride: string;
  const WorkspaceOverride: string
);
var
  Options: TCompilationOptions;
  ResolvedSourcePath: string;
  ResolvedUnitRoots: TStringArray;
  Session: TCompilationSession;
  TargetConfig: TTargetConfig;
  TargetFacts: TTargetFactsView;
  WorkspaceModel: TWorkspaceModel;
begin
  State.BuildContext.SourcePath := SourcePath;
  State.BuildContext.TargetName := TargetName;
  WorkspaceModel := nil;
  Session := nil;

  if not FileExists(SourcePath) then
    Fail('missing-source: ' + SourcePath);

  ResolvedSourcePath := ExpandFileName(SourcePath);
  try
    WorkspaceModel := ResolveWorkspaceModel(
      ResolvedSourcePath,
      WorkspaceOverride,
      TargetName,
      ''
    );
  except
    on E: Exception do
      Fail(E.Message, True);
  end;

  try
    CaptureBuildCommandContext(SourcePath, TargetName, WorkspaceModel);
    SetLength(ResolvedUnitRoots, 0);

    try
      TargetConfig := LoadTargetConfig(
        TargetName,
        ParamStr(0),
        ToolchainBindingOverride
      );
    except
      on E: ETargetConfigError do
        Fail(E.Message);
    end;

    State.BuildContext.TargetConfigPath := TargetConfig.ConfigPath;
    State.BuildContext.CompilerName := TargetConfig.CompilerExecutable;
    TargetFacts := TargetFactsFromConfig(TargetConfig);

    Options.CommandName := 'query';
    Options.BuildContext.RequestedSourcePath := SourcePath;
    Options.BuildContext.ResolvedSourcePath := ResolvedSourcePath;
    Options.BuildContext.RequestedTargetId := TargetFacts.TargetId;
    Options.BuildContext.WorkspaceRootPath := WorkspaceModel.WorkspaceRootPath;
    Options.BuildContext.WorkspaceDiscoveryKind := WorkspaceModel.DiscoveryKind;
    Options.BuildContext.WorkspaceDescriptorPath :=
      WorkspaceModel.WorkspaceDescriptorPath;
    Options.BuildContext.PackageManifestPath := WorkspaceModel.PackageManifestPath;
    Options.BuildContext.ArtifactRootPath := WorkspaceModel.ArtifactRootPath;
    Options.BuildContext.OutputDirPath := WorkspaceModel.OutputDirPath;
    Options.WorkspaceModel := WorkspaceModel;
    Options.ExplicitUnitRoots := ResolvedUnitRoots;

    Session := TCompilationSession.CreateBuildSession(Options, TargetFacts);
    WorkspaceModel := nil;
    CaptureSessionContext(Session);
    Session.AnalyzeSyntax;
    CaptureSessionContext(Session);
    if Session.HasSyntaxErrors then
      Fail('syntax-analysis-failed');
    Session.ResolveUnits;
    CaptureSessionContext(Session);
    if Session.HasResolutionErrors then
      Fail('unit-resolution-failed');
    Session.AnalyzeSemantics;
    CaptureSessionContext(Session);
    if Session.HasSemanticErrors then
      Fail('semantic-analysis-failed');

    State.QueryProjection.Kind := 'symbols';
    State.QueryProjection.Status := 'success';
    State.QueryProjection.AnalysisSource := 'compilation-session';
    State.QueryProjection.ResultCount := Session.SymbolCount;
    State.QueryProjection.HasResultCount := True;

    WriteLn('mode=query');
    WriteLn('command=query');
    WriteLn('selector=symbols');
    WriteLn('source=', SourcePath);
    WriteLn('target=', TargetName);
    WriteLn('target-config=', TargetConfig.ConfigPath);
    WriteLn('compiler=', TargetConfig.CompilerExecutable);
    PrintSessionProjection(False);
    PrintQueryProjectionFields(False);
    WriteLn('status=success');
    WriteLn('result=success');
    WriteLn('command-outcome=success');
    PrintCommandEnvelope(
      State,
      ExitSuccessCode,
      'symbols',
      'success',
      'success',
      '',
      'query symbols completed',
      False
    );
    WriteLn('human-summary=query symbols completed');
  finally
    Session.Free;
    WorkspaceModel.Free;
  end;
end;

procedure RunBuild(
  const SourcePath: string;
  const TargetName: string;
  const ToolchainBindingOverride: string;
  const WorkspaceOverride: string;
  const UnitRootOverrides: TStringArray;
  const OutDirOverride: string
);
var
  CompilerExitCode: LongInt;
  FinalToolStep: TToolchainExecutedStep;
  Options: TCompilationOptions;
  ResolvedSourcePath: string;
  ResolvedUnitRoots: TStringArray;
  RunResult: TToolchainRunResult;
  Session: TCompilationSession;
  TargetConfig: TTargetConfig;
  TargetFacts: TTargetFactsView;
  WorkspaceModel: TWorkspaceModel;
begin
  State.BuildContext.SourcePath := SourcePath;
  State.BuildContext.TargetName := TargetName;
  WorkspaceModel := nil;
  Session := nil;

  if not FileExists(SourcePath) then
    Fail('missing-source: ' + SourcePath);

  ResolvedSourcePath := ExpandFileName(SourcePath);
  try
    WorkspaceModel := ResolveWorkspaceModel(
      ResolvedSourcePath,
      WorkspaceOverride,
      TargetName,
      OutDirOverride
    );
  except
    on E: Exception do
      Fail(E.Message, True);
  end;
  try
    CaptureBuildCommandContext(SourcePath, TargetName, WorkspaceModel);
    ResolvedUnitRoots := ResolveExplicitUnitRoots(
      WorkspaceModel.WorkspaceRootPath,
      UnitRootOverrides
    );
    EnsureDirectoryExists(
      WorkspaceModel.ArtifactRootPath,
      WorkspaceModel.ArtifactRootPath,
      'invalid-artifact-root'
    );
    EnsureDirectoryExists(
      WorkspaceModel.OutputDirPath,
      WorkspaceModel.OutputDirPath,
      'invalid-out-dir'
    );

    try
      TargetConfig := LoadTargetConfig(
        TargetName,
        ParamStr(0),
        ToolchainBindingOverride
      );
    except
      on E: ETargetConfigError do
        Fail(E.Message);
    end;

    State.BuildContext.TargetConfigPath := TargetConfig.ConfigPath;
    TargetFacts := TargetFactsFromConfig(TargetConfig);
    State.BuildContext.CompilerName := TargetConfig.CompilerExecutable;
    Options.CommandName := 'build';
    Options.BuildContext.RequestedSourcePath := SourcePath;
    Options.BuildContext.ResolvedSourcePath := ResolvedSourcePath;
    Options.BuildContext.RequestedTargetId := TargetFacts.TargetId;
    Options.BuildContext.WorkspaceRootPath := WorkspaceModel.WorkspaceRootPath;
    Options.BuildContext.WorkspaceDiscoveryKind := WorkspaceModel.DiscoveryKind;
    Options.BuildContext.WorkspaceDescriptorPath :=
      WorkspaceModel.WorkspaceDescriptorPath;
    Options.BuildContext.PackageManifestPath := WorkspaceModel.PackageManifestPath;
    Options.WorkspaceModel := WorkspaceModel;
    Options.ExplicitUnitRoots := ResolvedUnitRoots;
    Options.BuildContext.ArtifactRootPath := WorkspaceModel.ArtifactRootPath;
    Options.BuildContext.OutputDirPath := WorkspaceModel.OutputDirPath;
    Session := TCompilationSession.CreateBuildSession(Options, TargetFacts);
    WorkspaceModel := nil;
    CaptureSessionContext(Session);
    Session.AnalyzeSyntax;
    CaptureSessionContext(Session);
    if Session.HasSyntaxErrors then
      Fail('syntax-analysis-failed');
    Session.ResolveUnits;
    CaptureSessionContext(Session);
    if Session.HasResolutionErrors then
      Fail('unit-resolution-failed');
    Session.AnalyzeSemantics;
    CaptureSessionContext(Session);
    if Session.HasSemanticErrors then
      Fail('semantic-analysis-failed');
    Session.LowerToMir;
    CaptureSessionContext(Session);
    if Session.HasMirErrors then
      Fail('mir-lowering-failed');
    Session.PlanBackend;
    CaptureSessionContext(Session);
    if Session.HasBackendErrors then
      Fail('backend-planning-failed');
    Session.PlanToolchain;
    CaptureSessionContext(Session);
    if Session.HasToolchainErrors then
      Fail('toolchain-planning-failed');

    State.BuildContext.CompilerName := Session.PrimaryToolLogicalExecutable;
    RunResult := Session.ExecuteToolchain(GetEnvironmentVariable('PATH'));
    try
      if RunResult.StepCount > 0 then
      begin
        FinalToolStep := RunResult.StepAt(RunResult.StepCount - 1);
        CompilerExitCode := FinalToolStep.ExitCode;
        State.BuildContext.CompilerExitCode := FinalToolStep.ExitCode;
        State.BuildContext.HasCompilerExitCode := FinalToolStep.HasExitCode;
      end
      else
      begin
        CompilerExitCode := 0;
        State.BuildContext.CompilerExitCode := 0;
        State.BuildContext.HasCompilerExitCode := False;
      end;

      CaptureSessionContext(Session);
      if RunResult.Status <> 'success' then
      begin
        if Session.HasLastDiagnosticExitCode then
        begin
          State.BuildContext.CompilerExitCode := Session.LastDiagnosticExitCode;
          State.BuildContext.HasCompilerExitCode := True;
        end;
        if Session.LastDiagnosticCode <> '' then
          Fail(
            Session.LastDiagnosticCode + ': ' + Session.LastDiagnosticMessage
          )
        else
          Fail(
            Session.PrimaryToolFailureMapping + ': ' + Session.LastDiagnosticMessage
          );
      end;

      if not State.BuildContext.HasCompilerExitCode then
      begin
        State.BuildContext.CompilerExitCode := CompilerExitCode;
        State.BuildContext.HasCompilerExitCode := True;
      end;
    finally
      RunResult.Free;
    end;

    if CompilerExitCode <> 0 then
    begin
      Fail(Session.PrimaryToolFailureMapping + ': compiler exit code ' + IntToStr(CompilerExitCode));
    end;

    State.BuildContext.ArtifactPath := Session.BackendPrimaryArtifactPath;
    WriteLn('mode=build');
    WriteLn('command=build');
    WriteLn('selector=build');
    WriteLn('source=', SourcePath);
    WriteLn('target=', TargetName);
    WriteLn('target-config=', TargetConfig.ConfigPath);
    WriteLn('compiler=', State.BuildContext.CompilerName);
    WriteLn('compiler-exit=', CompilerExitCode);
    WriteLn('artifact=', State.BuildContext.ArtifactPath);
    PrintSessionProjection(False);
    WriteLn('status=success');
    WriteLn('result=success');
    WriteLn('command-outcome=success');
    WriteLn('build-result=success');
    PrintCommandEnvelope(
      State,
      ExitSuccessCode,
      'build',
      'success',
      'success',
      '',
      'build succeeded',
      False
    );
    WriteLn('human-summary=build succeeded');
  finally
    Session.Free;
    WorkspaceModel.Free;
  end;
end;

var
  CommandName: string;
  Index: LongInt;
  ListGroups: Boolean;
  SourcePath: string;
  TargetName: string;
  TestFilterName: string;
  ToolchainBindingOverride: string;
  UnitRootOverrides: TStringArray;
  WorkspaceOverride: string;
  OutDirOverride: string;
  OptionName: string;
begin
  State.CommandName := '';
  State.SelectorName := '';
  ClearBuildCommandContext;
  ClearSessionContext;

  if ParamCount = 0 then
    Fail('invalid-arguments', True);

  if (ParamCount = 1) and ((ParamStr(1) = '--help') or (ParamStr(1) = '-h')) then
  begin
    PrintUsage;
    Halt(ExitSuccessCode);
  end;

  CommandName := ParamStr(1);
  State.CommandName := CommandName;

  if (CommandName <> 'build') and (CommandName <> 'test') and
    (CommandName <> 'env') and (CommandName <> 'doctor') and
    (CommandName <> 'query') and (CommandName <> 'pkg') then
    Fail('unsupported-command: ' + CommandName);

  if CommandName = 'test' then
  begin
    ListGroups := False;
    TestFilterName := '';
    WorkspaceOverride := '';
    Index := 2;
    while Index <= ParamCount do
    begin
      OptionName := ParamStr(Index);
      if OptionName = '--list-groups' then
      begin
        if ListGroups or (TestFilterName <> '') then
          Fail('invalid-arguments', True);
        ListGroups := True;
      end
      else if OptionName = '--filter' then
      begin
        if ListGroups or (TestFilterName <> '') then
          Fail('invalid-arguments', True);
        if Index = ParamCount then
          Fail('invalid-arguments', True);
        Inc(Index);
        TestFilterName := ParamStr(Index);
      end
      else if OptionName = '--workspace' then
      begin
        if WorkspaceOverride <> '' then
          Fail('duplicate-option: --workspace', True);
        if Index = ParamCount then
          Fail('invalid-arguments', True);
        Inc(Index);
        WorkspaceOverride := ParamStr(Index);
      end
      else
        Fail('unknown-option: ' + OptionName, True);

      Inc(Index);
    end;

    if not ListGroups and (TestFilterName = '') then
      Fail('invalid-arguments', True);

    RunTest(ListGroups, TestFilterName, WorkspaceOverride);
  end;

  if CommandName = 'env' then
  begin
    if ParamCount < 3 then
      Fail('invalid-arguments', True);
    if ParamStr(2) <> 'status' then
      Fail('invalid-arguments', True);

    State.SelectorName := 'status';
    TargetName := '';
    ToolchainBindingOverride := '';
    Index := 3;
    while Index <= ParamCount do
    begin
      OptionName := ParamStr(Index);
      if (OptionName <> '--target') and
        (OptionName <> '--toolchain-binding') then
        Fail('unknown-option: ' + OptionName, True);
      if Index = ParamCount then
        Fail('invalid-arguments', True);
      Inc(Index);
      if OptionName = '--target' then
      begin
        if TargetName <> '' then
          Fail('duplicate-option: --target', True);
        TargetName := ParamStr(Index);
      end
      else
      begin
        if ToolchainBindingOverride <> '' then
          Fail('duplicate-option: --toolchain-binding', True);
        ToolchainBindingOverride := ParamStr(Index);
      end;
      Inc(Index);
    end;

    if TargetName = '' then
      Fail('missing-required-option: --target', True);

    RunEnvStatus(TargetName, ToolchainBindingOverride);
    Halt(ExitSuccessCode);
  end;

  if CommandName = 'doctor' then
  begin
    State.SelectorName := 'doctor';
    if ParamCount < 2 then
      Fail('invalid-arguments', True);

    TargetName := '';
    ToolchainBindingOverride := '';
    WorkspaceOverride := '';
    Index := 2;
    while Index <= ParamCount do
    begin
      OptionName := ParamStr(Index);
      if (OptionName <> '--target') and
        (OptionName <> '--toolchain-binding') and
        (OptionName <> '--workspace') then
        Fail('unknown-option: ' + OptionName, True);
      if Index = ParamCount then
        Fail('invalid-arguments', True);
      Inc(Index);
      if OptionName = '--target' then
      begin
        if TargetName <> '' then
          Fail('duplicate-option: --target', True);
        TargetName := ParamStr(Index);
      end
      else if OptionName = '--toolchain-binding' then
      begin
        if ToolchainBindingOverride <> '' then
          Fail('duplicate-option: --toolchain-binding', True);
        ToolchainBindingOverride := ParamStr(Index);
      end
      else
      begin
        if WorkspaceOverride <> '' then
          Fail('duplicate-option: --workspace', True);
        WorkspaceOverride := ParamStr(Index);
      end;
      Inc(Index);
    end;

    if TargetName = '' then
      Fail('missing-required-option: --target', True);

    RunDoctor(TargetName, ToolchainBindingOverride, WorkspaceOverride);
    Halt(ExitSuccessCode);
  end;

  if CommandName = 'query' then
  begin
    State.SelectorName := 'query';
    if ParamCount < 3 then
      Fail('invalid-arguments', True);
    if ParamStr(2) <> 'symbols' then
      Fail('invalid-arguments', True);

    State.SelectorName := 'symbols';
    SourcePath := ParamStr(3);
    TargetName := '';
    ToolchainBindingOverride := '';
    WorkspaceOverride := '';
    Index := 4;
    while Index <= ParamCount do
    begin
      OptionName := ParamStr(Index);
      if (OptionName <> '--target') and
        (OptionName <> '--toolchain-binding') and
        (OptionName <> '--workspace') then
        Fail('unknown-option: ' + OptionName, True);
      if Index = ParamCount then
        Fail('invalid-arguments', True);
      Inc(Index);
      if OptionName = '--target' then
      begin
        if TargetName <> '' then
          Fail('duplicate-option: --target', True);
        TargetName := ParamStr(Index);
      end
      else if OptionName = '--toolchain-binding' then
      begin
        if ToolchainBindingOverride <> '' then
          Fail('duplicate-option: --toolchain-binding', True);
        ToolchainBindingOverride := ParamStr(Index);
      end
      else
      begin
        if WorkspaceOverride <> '' then
          Fail('duplicate-option: --workspace', True);
        WorkspaceOverride := ParamStr(Index);
      end;
      Inc(Index);
    end;

    if TargetName = '' then
      Fail('missing-required-option: --target', True);

    RunQuerySymbols(
      SourcePath,
      TargetName,
      ToolchainBindingOverride,
      WorkspaceOverride
    );
    Halt(ExitSuccessCode);
  end;

  if CommandName = 'pkg' then
  begin
    State.SelectorName := 'pkg';
    if ParamCount < 3 then
      Fail('invalid-arguments', True);
    if ParamStr(2) <> 'inspect' then
      Fail('invalid-arguments', True);

    State.SelectorName := 'inspect';
    TargetName := '';
    ToolchainBindingOverride := '';
    WorkspaceOverride := '';
    Index := 3;
    while Index <= ParamCount do
    begin
      OptionName := ParamStr(Index);
      if (OptionName <> '--target') and
        (OptionName <> '--toolchain-binding') and
        (OptionName <> '--workspace') then
        Fail('unknown-option: ' + OptionName, True);
      if Index = ParamCount then
        Fail('invalid-arguments', True);
      Inc(Index);
      if OptionName = '--target' then
      begin
        if TargetName <> '' then
          Fail('duplicate-option: --target', True);
        TargetName := ParamStr(Index);
      end
      else if OptionName = '--toolchain-binding' then
      begin
        if ToolchainBindingOverride <> '' then
          Fail('duplicate-option: --toolchain-binding', True);
        ToolchainBindingOverride := ParamStr(Index);
      end
      else
      begin
        if WorkspaceOverride <> '' then
          Fail('duplicate-option: --workspace', True);
        WorkspaceOverride := ParamStr(Index);
      end;
      Inc(Index);
    end;

    if TargetName = '' then
      Fail('missing-required-option: --target', True);

    RunPkgInspect(TargetName, ToolchainBindingOverride, WorkspaceOverride);
    Halt(ExitSuccessCode);
  end;

  if ParamCount < 4 then
    Fail('invalid-arguments', True);

  SourcePath := ParamStr(2);
  TargetName := '';
  ToolchainBindingOverride := '';
  WorkspaceOverride := '';
  OutDirOverride := '';
  SetLength(UnitRootOverrides, 0);

  Index := 3;
  while Index <= ParamCount do
  begin
    OptionName := ParamStr(Index);
    if (OptionName = '--target') or
      (OptionName = '--toolchain-binding') or
      (OptionName = '--workspace') or
      (OptionName = '--unit-root') or
      (OptionName = '--out-dir') then
    begin
      if Index = ParamCount then
        Fail('invalid-arguments', True);
      Inc(Index);

      if OptionName = '--target' then
      begin
        if TargetName <> '' then
          Fail('duplicate-option: --target', True);
        TargetName := ParamStr(Index);
      end
      else if OptionName = '--toolchain-binding' then
      begin
        if ToolchainBindingOverride <> '' then
          Fail('duplicate-option: --toolchain-binding', True);
        ToolchainBindingOverride := ParamStr(Index);
      end
      else if OptionName = '--workspace' then
      begin
        if WorkspaceOverride <> '' then
          Fail('duplicate-option: --workspace', True);
        WorkspaceOverride := ParamStr(Index);
      end
      else if OptionName = '--out-dir' then
      begin
        if OutDirOverride <> '' then
          Fail('duplicate-option: --out-dir', True);
        OutDirOverride := ParamStr(Index);
      end
      else
        AppendString(UnitRootOverrides, ParamStr(Index));
    end
    else
      Fail('unknown-option: ' + OptionName, True);

    Inc(Index);
  end;

  if TargetName = '' then
    Fail('missing-required-option: --target', True);

  RunBuild(
    SourcePath,
    TargetName,
    ToolchainBindingOverride,
    WorkspaceOverride,
    UnitRootOverrides,
    OutDirOverride
  );
end.
