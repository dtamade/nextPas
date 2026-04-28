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
  SysUtils, process, target_config, np_compilation_session, np_target_facts,
  np_toolchain_profiles, np_toolchain_runner, np_workspace_model;

const
  ExitSuccessCode = 0;
  ExitFailureCode = 1;

type
  TStringArray = array of string;

  TBuildCommandContext = record
    SourcePath: string;
    TargetName: string;
    TargetConfigPath: string;
    CompilerName: string;
    ArtifactPath: string;
    WorkspaceRootPath: string;
    WorkspaceDiscoveryKind: string;
    WorkspaceDescriptorPath: string;
    PackageManifestPath: string;
    ArtifactRootPath: string;
    OutputDirPath: string;
    CompilerExitCode: LongInt;
    HasCompilerExitCode: Boolean;
  end;

  TSessionProjectionContext = record
    SessionId: string;
    SessionLifetime: string;
    UnitLifetime: string;
    StageLifetime: string;
    SourceLineIndexState: string;
    RootFileId: LongInt;
    SourceFileCount: LongInt;
    UnitStateCount: LongInt;
  end;

  TSyntaxProjectionContext = record
    Status: string;
    LexerTokenCount: LongInt;
    GreenNodeCount: LongInt;
    AstRootKind: string;
    AstDeclaredName: string;
  end;

  TResolutionProjectionContext = record
    Status: string;
    UnitGraphStatus: string;
    SearchPathCount: LongInt;
    SearchIndexStatus: string;
    IndexedSearchRootCount: LongInt;
    SearchIndexScanCount: LongInt;
    SearchPathJson: string;
    ResolvedUnitCount: LongInt;
    UnitGraphEdgeCount: LongInt;
    UnitGraphRootName: string;
  end;

  TSemanticProjectionContext = record
    Status: string;
    SymbolGraphStatus: string;
    TypeGraphStatus: string;
    TypedHirStatus: string;
    SymbolCount: LongInt;
    TypeCount: LongInt;
    TypedHirNodeCount: LongInt;
    RuntimeContractCount: LongInt;
    TypedHirRootName: string;
  end;

  TMirProjectionContext = record
    Status: string;
    BlockCount: LongInt;
    OperationCount: LongInt;
    EntryBlock: string;
    RootName: string;
  end;

  TBackendProjectionContext = record
    PlanStatus: string;
    OutputKind: string;
    PrimaryArtifactKind: string;
    PrimaryArtifactPath: string;
    ArtifactCount: LongInt;
    ArtifactsJson: string;
  end;

  TDiagnosticProjectionContext = record
    Policy: string;
    Count: LongInt;
    ErrorCount: LongInt;
    WarningCount: LongInt;
    Summary: string;
    Json: string;
    Id: string;
    Code: string;
    Phase: string;
    Message: string;
    BindingId: string;
    ProfileId: string;
    StepId: string;
    LogicalExecutable: string;
    SysrootRef: string;
    ResolvedPath: string;
    PrimaryArtifactKind: string;
    PrimaryArtifactPath: string;
    ExitCode: LongInt;
    HasExitCode: Boolean;
  end;

  TToolchainProjectionContext = record
    HostId: string;
    ToolchainBindingId: string;
    BackendFamily: string;
    AssemblerProfileId: string;
    LinkerProfileId: string;
    ArchiverProfileId: string;
    ResourceToolProfileId: string;
    TargetObjectFormat: string;
    TargetAssemblerFlavor: string;
    TargetLinkerFlavor: string;
    TargetRuntimeLayoutKey: string;
    TargetCSymbolPrefix: string;
    TargetCLibraryNaming: string;
    TargetLlvmTriple: string;
    TargetLlvmDataLayout: string;
    SysrootMode: string;
    RuntimeSdkId: string;
    AllowHostFallback: Boolean;
    ToolRootKind: string;
    RuntimeRootKind: string;
    ResponseFilePolicy: string;
    LinkScriptPolicy: string;
    ToolchainPlanStatus: string;
    ToolchainPlanFamily: string;
    ToolProfileRoot: string;
    LogicalLinkRequestStatus: string;
    LogicalLinkRequestOutputKind: string;
    LogicalLibraryRequestCount: LongInt;
    LogicalLinkRequestJson: string;
    LlvmToolchainStatus: string;
    LlvmExecutableSetId: string;
    LlvmExecutableSetJson: string;
    ToolInvocationCount: LongInt;
    ToolRunStatus: string;
    ToolRunStepCount: LongInt;
    PrimaryToolRunStatus: string;
    PrimaryToolRole: string;
    PrimaryToolProfileId: string;
    PrimaryToolStepId: string;
    PrimaryToolLogicalExecutable: string;
    PrimaryToolSysrootRef: string;
    PrimaryToolFailureMapping: string;
    ToolInvocationPlanRef: string;
    ToolInvocationPlanJson: string;
    ToolStatusEventCount: LongInt;
    ToolStatusEventsJson: string;
    BuildTraceRef: string;
    BuildTraceJson: string;
  end;

  TEnvironmentProjectionContext = record
    ToolchainBindingPath: string;
    DistributionBinDir: string;
    DistributionLibDir: string;
    DistributionShareDir: string;
    RuntimeRootPath: string;
    RuntimeLibcPath: string;
    RuntimeLibcPresent: Boolean;
    HasRuntimeLibcPresent: Boolean;
    EnvironmentReadiness: string;
    RuntimeSdkStatus: string;
  end;

  TDoctorProjectionContext = record
    Status: string;
    CheckCount: LongInt;
    FindingCount: LongInt;
  end;

var
  ActiveCommand: string;
  ActiveSelector: string;
  ActiveBuildContext: TBuildCommandContext;
  ActiveSessionProjection: TSessionProjectionContext;
  ActiveDiagnosticsProjection: TDiagnosticProjectionContext;
  ActiveSyntaxProjection: TSyntaxProjectionContext;
  ActiveResolutionProjection: TResolutionProjectionContext;
  ActiveSemanticProjection: TSemanticProjectionContext;
  ActiveMirProjection: TMirProjectionContext;
  ActiveBackendProjection: TBackendProjectionContext;
  ActiveToolchainProjection: TToolchainProjectionContext;
  ActiveEnvironmentProjection: TEnvironmentProjectionContext;
  ActiveDoctorProjection: TDoctorProjectionContext;

function EnvelopeCommandName: string;
begin
  if ActiveCommand <> '' then
    Exit(ActiveCommand);

  Result := 'cli';
end;

function EnvelopeSelectorName: string;
begin
  if ActiveSelector <> '' then
    Exit(ActiveSelector);
  if ActiveCommand = 'build' then
    Exit('build');
  if ActiveCommand = 'test' then
    Exit('test');
  if ActiveCommand = 'env' then
    Exit('env');
  if ActiveCommand = 'doctor' then
    Exit('doctor');

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

procedure PrintUsage;
begin
  if ActiveCommand = 'build' then
  begin
    PrintBuildUsage(False);
    Exit;
  end;

  if ActiveCommand = 'test' then
  begin
    PrintTestUsage(False);
    Exit;
  end;

  if ActiveCommand = 'env' then
  begin
    PrintEnvUsage(False);
    Exit;
  end;

  if ActiveCommand = 'doctor' then
  begin
    PrintDoctorUsage(False);
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
end;

procedure PrintUsageError;
begin
  if ActiveCommand = 'build' then
  begin
    PrintBuildUsage(True);
    Exit;
  end;

  if ActiveCommand = 'test' then
  begin
    PrintTestUsage(True);
    Exit;
  end;

  if ActiveCommand = 'env' then
  begin
    PrintEnvUsage(True);
    Exit;
  end;

  if ActiveCommand = 'doctor' then
  begin
    PrintDoctorUsage(True);
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
end;

function JsonEscape(const Value: string): string;
var
  Index: SizeInt;
begin
  Result := '';
  for Index := 1 to Length(Value) do
    case Value[Index] of
      '\':
        Result := Result + '\\';
      '"':
        Result := Result + '\"';
      #10:
        Result := Result + '\n';
      #13:
        Result := Result + '\r';
      #9:
        Result := Result + '\t';
    else
      Result := Result + Value[Index];
    end;
end;

function JsonString(const Value: string): string;
begin
  Result := '"' + JsonEscape(Value) + '"';
end;

function BooleanText(const Value: Boolean): string;
begin
  if Value then
    Exit('true');

  Result := 'false';
end;

procedure AppendJsonField(
  var AFields: string;
  const AName: string;
  const AValue: string
);
begin
  if AFields <> '' then
    AFields := AFields + ',';
  AFields := AFields + JsonString(AName) + ':' + AValue;
end;

procedure AppendJsonStringField(
  var AFields: string;
  const AName: string;
  const AValue: string
);
begin
  if AValue = '' then
    Exit;

  AppendJsonField(AFields, AName, JsonString(AValue));
end;

procedure AppendJsonStringFieldWhenEnabled(
  var AFields: string;
  const AName: string;
  const AValue: string;
  const AEnabled: Boolean
);
begin
  if not AEnabled then
    Exit;

  AppendJsonField(AFields, AName, JsonString(AValue));
end;

procedure AppendJsonIntegerField(
  var AFields: string;
  const AName: string;
  const AValue: LongInt;
  const AEnabled: Boolean
);
begin
  if not AEnabled then
    Exit;

  AppendJsonField(AFields, AName, IntToStr(AValue));
end;

procedure AppendJsonBooleanField(
  var AFields: string;
  const AName: string;
  const AValue: Boolean;
  const AEnabled: Boolean
);
begin
  if not AEnabled then
    Exit;

  AppendJsonField(AFields, AName, BooleanText(AValue));
end;

procedure AppendBuildContextProjectionJsonFields(var AFields: string);
begin
  AppendJsonStringField(AFields, 'source', ActiveBuildContext.SourcePath);
  AppendJsonStringField(AFields, 'target', ActiveBuildContext.TargetName);
  AppendJsonStringField(
    AFields,
    'workspaceRoot',
    ActiveBuildContext.WorkspaceRootPath
  );
  AppendJsonStringField(
    AFields,
    'workspaceDiscoveryKind',
    ActiveBuildContext.WorkspaceDiscoveryKind
  );
  AppendJsonStringField(
    AFields,
    'workspaceDescriptorPath',
    ActiveBuildContext.WorkspaceDescriptorPath
  );
  AppendJsonStringField(
    AFields,
    'packageManifestPath',
    ActiveBuildContext.PackageManifestPath
  );
  AppendJsonStringField(
    AFields,
    'artifactRoot',
    ActiveBuildContext.ArtifactRootPath
  );
  AppendJsonStringField(AFields, 'outputDir', ActiveBuildContext.OutputDirPath);
  AppendJsonStringField(
    AFields,
    'targetConfig',
    ActiveBuildContext.TargetConfigPath
  );
  AppendJsonStringField(AFields, 'compiler', ActiveBuildContext.CompilerName);
  AppendJsonIntegerField(
    AFields,
    'compilerExit',
    ActiveBuildContext.CompilerExitCode,
    ActiveBuildContext.HasCompilerExitCode
  );
  AppendJsonStringField(AFields, 'artifact', ActiveBuildContext.ArtifactPath);
end;

procedure AppendSessionProjectionJsonFields(
  var AFields: string;
  const AHasSessionProjection: Boolean
);
begin
  AppendJsonStringField(AFields, 'sessionId', ActiveSessionProjection.SessionId);
  AppendJsonIntegerField(
    AFields,
    'rootFileId',
    ActiveSessionProjection.RootFileId,
    ActiveSessionProjection.RootFileId > 0
  );
  AppendJsonIntegerField(
    AFields,
    'sourceFileCount',
    ActiveSessionProjection.SourceFileCount,
    ActiveSessionProjection.SourceFileCount > 0
  );
  AppendJsonStringField(
    AFields,
    'sourceLineIndexState',
    ActiveSessionProjection.SourceLineIndexState
  );
  AppendJsonIntegerField(
    AFields,
    'unitStateCount',
    ActiveSessionProjection.UnitStateCount,
    ActiveSessionProjection.UnitStateCount > 0
  );
  AppendJsonIntegerField(
    AFields,
    'diagnosticCount',
    ActiveDiagnosticsProjection.Count,
    AHasSessionProjection
  );
  AppendJsonIntegerField(
    AFields,
    'diagnosticErrorCount',
    ActiveDiagnosticsProjection.ErrorCount,
    AHasSessionProjection
  );
  AppendJsonIntegerField(
    AFields,
    'diagnosticWarningCount',
    ActiveDiagnosticsProjection.WarningCount,
    AHasSessionProjection
  );
  AppendJsonStringField(
    AFields,
    'diagnosticsPolicy',
    ActiveDiagnosticsProjection.Policy
  );
  AppendJsonStringField(
    AFields,
    'sessionLifetime',
    ActiveSessionProjection.SessionLifetime
  );
  AppendJsonStringField(
    AFields,
    'unitLifetime',
    ActiveSessionProjection.UnitLifetime
  );
  AppendJsonStringField(
    AFields,
    'stageLifetime',
    ActiveSessionProjection.StageLifetime
  );
end;

procedure AppendSyntaxProjectionJsonFields(
  var AFields: string;
  const AHasSyntaxProjection: Boolean
);
begin
  AppendJsonStringField(AFields, 'syntaxStatus', ActiveSyntaxProjection.Status);
  AppendJsonIntegerField(
    AFields,
    'lexerTokenCount',
    ActiveSyntaxProjection.LexerTokenCount,
    AHasSyntaxProjection
  );
  AppendJsonIntegerField(
    AFields,
    'greenNodeCount',
    ActiveSyntaxProjection.GreenNodeCount,
    AHasSyntaxProjection
  );
  AppendJsonStringField(AFields, 'astRootKind', ActiveSyntaxProjection.AstRootKind);
  AppendJsonStringField(
    AFields,
    'astDeclaredName',
    ActiveSyntaxProjection.AstDeclaredName
  );
end;

procedure AppendResolutionProjectionJsonFields(
  var AFields: string;
  const AHasResolutionProjection: Boolean
);
begin
  AppendJsonStringField(
    AFields,
    'resolutionStatus',
    ActiveResolutionProjection.Status
  );
  AppendJsonStringField(
    AFields,
    'unitGraphStatus',
    ActiveResolutionProjection.UnitGraphStatus
  );
  AppendJsonIntegerField(
    AFields,
    'searchPathCount',
    ActiveResolutionProjection.SearchPathCount,
    AHasResolutionProjection
  );
  AppendJsonStringField(
    AFields,
    'searchIndexStatus',
    ActiveResolutionProjection.SearchIndexStatus
  );
  AppendJsonIntegerField(
    AFields,
    'indexedSearchRootCount',
    ActiveResolutionProjection.IndexedSearchRootCount,
    AHasResolutionProjection
  );
  AppendJsonIntegerField(
    AFields,
    'searchIndexScanCount',
    ActiveResolutionProjection.SearchIndexScanCount,
    AHasResolutionProjection
  );
  if ActiveResolutionProjection.SearchPathJson <> '' then
    AppendJsonField(
      AFields,
      'searchPaths',
      ActiveResolutionProjection.SearchPathJson
    );
  AppendJsonIntegerField(
    AFields,
    'resolvedUnitCount',
    ActiveResolutionProjection.ResolvedUnitCount,
    AHasResolutionProjection
  );
  AppendJsonIntegerField(
    AFields,
    'unitGraphEdgeCount',
    ActiveResolutionProjection.UnitGraphEdgeCount,
    AHasResolutionProjection
  );
  AppendJsonStringField(
    AFields,
    'unitGraphRootName',
    ActiveResolutionProjection.UnitGraphRootName
  );
end;

procedure AppendSemanticProjectionJsonFields(
  var AFields: string;
  const AHasSemanticProjection: Boolean
);
begin
  AppendJsonStringField(AFields, 'semanticStatus', ActiveSemanticProjection.Status);
  AppendJsonStringField(
    AFields,
    'symbolGraphStatus',
    ActiveSemanticProjection.SymbolGraphStatus
  );
  AppendJsonStringField(
    AFields,
    'typeGraphStatus',
    ActiveSemanticProjection.TypeGraphStatus
  );
  AppendJsonStringField(
    AFields,
    'typedHirStatus',
    ActiveSemanticProjection.TypedHirStatus
  );
  AppendJsonIntegerField(
    AFields,
    'symbolCount',
    ActiveSemanticProjection.SymbolCount,
    AHasSemanticProjection
  );
  AppendJsonIntegerField(
    AFields,
    'typeCount',
    ActiveSemanticProjection.TypeCount,
    AHasSemanticProjection
  );
  AppendJsonIntegerField(
    AFields,
    'typedHirNodeCount',
    ActiveSemanticProjection.TypedHirNodeCount,
    AHasSemanticProjection
  );
  AppendJsonIntegerField(
    AFields,
    'runtimeContractCount',
    ActiveSemanticProjection.RuntimeContractCount,
    AHasSemanticProjection
  );
  AppendJsonStringField(
    AFields,
    'typedHirRootName',
    ActiveSemanticProjection.TypedHirRootName
  );
end;

procedure AppendMirProjectionJsonFields(
  var AFields: string;
  const AHasMirProjection: Boolean
);
begin
  AppendJsonStringField(AFields, 'mirStatus', ActiveMirProjection.Status);
  AppendJsonIntegerField(
    AFields,
    'mirBlockCount',
    ActiveMirProjection.BlockCount,
    AHasMirProjection
  );
  AppendJsonIntegerField(
    AFields,
    'mirOperationCount',
    ActiveMirProjection.OperationCount,
    AHasMirProjection
  );
  AppendJsonStringField(AFields, 'mirEntryBlock', ActiveMirProjection.EntryBlock);
  AppendJsonStringField(AFields, 'mirRootName', ActiveMirProjection.RootName);
end;

procedure AppendBackendProjectionJsonFields(var AFields: string);
begin
  AppendJsonStringField(
    AFields,
    'backendPlanStatus',
    ActiveBackendProjection.PlanStatus
  );
  AppendJsonStringField(
    AFields,
    'backendOutputKind',
    ActiveBackendProjection.OutputKind
  );
  AppendJsonStringField(
    AFields,
    'backendPrimaryArtifactKind',
    ActiveBackendProjection.PrimaryArtifactKind
  );
  AppendJsonStringField(
    AFields,
    'backendPrimaryArtifactPath',
    ActiveBackendProjection.PrimaryArtifactPath
  );
  AppendJsonIntegerField(
    AFields,
    'backendArtifactCount',
    ActiveBackendProjection.ArtifactCount,
    ActiveBackendProjection.ArtifactCount > 0
  );
  if ActiveBackendProjection.ArtifactsJson <> '' then
    AppendJsonField(
      AFields,
      'backendArtifacts',
      ActiveBackendProjection.ArtifactsJson
    );
end;

procedure AppendToolchainProjectionJsonFields(
  var AFields: string;
  const AHasSessionProjection: Boolean;
  const AHasBackendProjection: Boolean
);
begin
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'hostId',
    ActiveToolchainProjection.HostId,
    AHasSessionProjection
  );
  AppendJsonStringField(
    AFields,
    'toolchainBindingId',
    ActiveToolchainProjection.ToolchainBindingId
  );
  AppendJsonStringField(
    AFields,
    'backendFamily',
    ActiveToolchainProjection.BackendFamily
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'assemblerProfileId',
    ActiveToolchainProjection.AssemblerProfileId,
    AHasSessionProjection
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'linkerProfileId',
    ActiveToolchainProjection.LinkerProfileId,
    AHasSessionProjection
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'archiverProfileId',
    ActiveToolchainProjection.ArchiverProfileId,
    AHasSessionProjection
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'resourceToolProfileId',
    ActiveToolchainProjection.ResourceToolProfileId,
    AHasSessionProjection
  );
  AppendJsonStringField(
    AFields,
    'targetObjectFormat',
    ActiveToolchainProjection.TargetObjectFormat
  );
  AppendJsonStringField(
    AFields,
    'targetAssemblerFlavor',
    ActiveToolchainProjection.TargetAssemblerFlavor
  );
  AppendJsonStringField(
    AFields,
    'targetLinkerFlavor',
    ActiveToolchainProjection.TargetLinkerFlavor
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'targetRuntimeLayoutKey',
    ActiveToolchainProjection.TargetRuntimeLayoutKey,
    AHasSessionProjection
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'targetCSymbolPrefix',
    ActiveToolchainProjection.TargetCSymbolPrefix,
    AHasSessionProjection
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'targetCLibraryNaming',
    ActiveToolchainProjection.TargetCLibraryNaming,
    AHasSessionProjection
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'targetLlvmTriple',
    ActiveToolchainProjection.TargetLlvmTriple,
    AHasSessionProjection
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'targetLlvmDataLayout',
    ActiveToolchainProjection.TargetLlvmDataLayout,
    AHasSessionProjection
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'sysrootMode',
    ActiveToolchainProjection.SysrootMode,
    AHasSessionProjection
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'runtimeSdkId',
    ActiveToolchainProjection.RuntimeSdkId,
    AHasSessionProjection
  );
  AppendJsonBooleanField(
    AFields,
    'allowHostFallback',
    ActiveToolchainProjection.AllowHostFallback,
    AHasSessionProjection
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'toolRootKind',
    ActiveToolchainProjection.ToolRootKind,
    AHasSessionProjection
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'runtimeRootKind',
    ActiveToolchainProjection.RuntimeRootKind,
    AHasSessionProjection
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'responseFilePolicy',
    ActiveToolchainProjection.ResponseFilePolicy,
    AHasSessionProjection
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'linkScriptPolicy',
    ActiveToolchainProjection.LinkScriptPolicy,
    AHasSessionProjection
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'toolchainPlanStatus',
    ActiveToolchainProjection.ToolchainPlanStatus,
    AHasSessionProjection
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'toolchainPlanFamily',
    ActiveToolchainProjection.ToolchainPlanFamily,
    AHasSessionProjection
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'toolProfileRoot',
    ActiveToolchainProjection.ToolProfileRoot,
    AHasSessionProjection
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'logicalLinkRequestStatus',
    ActiveToolchainProjection.LogicalLinkRequestStatus,
    AHasSessionProjection
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'logicalLinkRequestOutputKind',
    ActiveToolchainProjection.LogicalLinkRequestOutputKind,
    AHasSessionProjection
  );
  AppendJsonIntegerField(
    AFields,
    'logicalLibraryRequestCount',
    ActiveToolchainProjection.LogicalLibraryRequestCount,
    AHasSessionProjection
  );
  if ActiveToolchainProjection.LogicalLinkRequestJson <> '' then
    AppendJsonField(
      AFields,
      'logicalLinkRequest',
      ActiveToolchainProjection.LogicalLinkRequestJson
    );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'llvmToolchainStatus',
    ActiveToolchainProjection.LlvmToolchainStatus,
    AHasSessionProjection
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'llvmExecutableSetId',
    ActiveToolchainProjection.LlvmExecutableSetId,
    AHasSessionProjection
  );
  if ActiveToolchainProjection.LlvmExecutableSetJson <> '' then
    AppendJsonField(
      AFields,
      'llvmExecutableSet',
      ActiveToolchainProjection.LlvmExecutableSetJson
    );
  AppendJsonIntegerField(
    AFields,
    'toolInvocationCount',
    ActiveToolchainProjection.ToolInvocationCount,
    AHasBackendProjection
  );
  AppendJsonStringField(
    AFields,
    'toolRunStatus',
    ActiveToolchainProjection.ToolRunStatus
  );
  AppendJsonIntegerField(
    AFields,
    'toolRunStepCount',
    ActiveToolchainProjection.ToolRunStepCount,
    ActiveToolchainProjection.ToolRunStepCount > 0
  );
  AppendJsonStringField(
    AFields,
    'primaryToolRunStatus',
    ActiveToolchainProjection.PrimaryToolRunStatus
  );
  AppendJsonStringField(
    AFields,
    'primaryToolRole',
    ActiveToolchainProjection.PrimaryToolRole
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'primaryToolProfileId',
    ActiveToolchainProjection.PrimaryToolProfileId,
    AHasBackendProjection
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'primaryToolStepId',
    ActiveToolchainProjection.PrimaryToolStepId,
    AHasBackendProjection
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'primaryToolLogicalExecutable',
    ActiveToolchainProjection.PrimaryToolLogicalExecutable,
    AHasBackendProjection
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'primaryToolSysrootRef',
    ActiveToolchainProjection.PrimaryToolSysrootRef,
    AHasBackendProjection
  );
  AppendJsonStringFieldWhenEnabled(
    AFields,
    'primaryToolFailureMapping',
    ActiveToolchainProjection.PrimaryToolFailureMapping,
    AHasBackendProjection
  );
end;

procedure AppendEnvironmentProjectionJsonFields(var AFields: string);
begin
  AppendJsonStringField(
    AFields,
    'toolchainBindingPath',
    ActiveEnvironmentProjection.ToolchainBindingPath
  );
  AppendJsonStringField(
    AFields,
    'distributionBinDir',
    ActiveEnvironmentProjection.DistributionBinDir
  );
  AppendJsonStringField(
    AFields,
    'distributionLibDir',
    ActiveEnvironmentProjection.DistributionLibDir
  );
  AppendJsonStringField(
    AFields,
    'distributionShareDir',
    ActiveEnvironmentProjection.DistributionShareDir
  );
  AppendJsonStringField(
    AFields,
    'runtimeRoot',
    ActiveEnvironmentProjection.RuntimeRootPath
  );
  AppendJsonStringField(
    AFields,
    'runtimeLibc',
    ActiveEnvironmentProjection.RuntimeLibcPath
  );
  AppendJsonBooleanField(
    AFields,
    'runtimeLibcPresent',
    ActiveEnvironmentProjection.RuntimeLibcPresent,
    ActiveEnvironmentProjection.HasRuntimeLibcPresent
  );
  AppendJsonStringField(
    AFields,
    'environmentReadiness',
    ActiveEnvironmentProjection.EnvironmentReadiness
  );
  AppendJsonStringField(
    AFields,
    'runtimeSdkStatus',
    ActiveEnvironmentProjection.RuntimeSdkStatus
  );
end;

procedure AppendDoctorProjectionJsonFields(var AFields: string);
begin
  AppendJsonStringField(AFields, 'doctorStatus', ActiveDoctorProjection.Status);
  AppendJsonIntegerField(
    AFields,
    'doctorCheckCount',
    ActiveDoctorProjection.CheckCount,
    ActiveDoctorProjection.CheckCount > 0
  );
  AppendJsonIntegerField(
    AFields,
    'doctorFindingCount',
    ActiveDoctorProjection.FindingCount,
    ActiveDoctorProjection.CheckCount > 0
  );
end;

function BuildCommandEnvelopeJson(
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
  HasSessionProjection := ActiveSessionProjection.SessionId <> '';
  HasSyntaxProjection := ActiveSyntaxProjection.Status <> '';
  HasResolutionProjection := ActiveResolutionProjection.Status <> '';
  HasSemanticProjection := ActiveSemanticProjection.Status <> '';
  HasMirProjection := ActiveMirProjection.Status <> '';
  HasBackendProjection := ActiveBackendProjection.PlanStatus <> '';
  HasCommandToolchainProjection := HasSessionProjection or
    (ActiveToolchainProjection.HostId <> '') or
    (ActiveToolchainProjection.ToolchainBindingId <> '');
  AppendJsonStringField(ResultFields, 'selector', ASelector);
  AppendJsonStringField(ResultFields, 'status', AStatusValue);
  AppendJsonStringField(ResultFields, 'result', ABuildResult);
  AppendJsonStringField(ResultFields, 'failureKind', AFailureKind);
  AppendBuildContextProjectionJsonFields(ResultFields);
  AppendSessionProjectionJsonFields(ResultFields, HasSessionProjection);
  AppendSyntaxProjectionJsonFields(ResultFields, HasSyntaxProjection);
  AppendResolutionProjectionJsonFields(ResultFields, HasResolutionProjection);
  AppendSemanticProjectionJsonFields(ResultFields, HasSemanticProjection);
  AppendMirProjectionJsonFields(ResultFields, HasMirProjection);
  AppendBackendProjectionJsonFields(ResultFields);
  AppendToolchainProjectionJsonFields(
    ResultFields,
    HasCommandToolchainProjection,
    HasBackendProjection
  );
  AppendEnvironmentProjectionJsonFields(ResultFields);
  AppendDoctorProjectionJsonFields(ResultFields);
  AppendJsonStringField(
    ResultFields,
    'diagnosticsSummary',
    ActiveDiagnosticsProjection.Summary
  );
  AppendJsonStringField(ResultFields, 'buildResult', ABuildResult);

  AppendJsonField(EnvelopeFields, 'command', JsonString(EnvelopeCommandName));
  AppendJsonField(EnvelopeFields, 'exitCode', IntToStr(AExitCode));
  if ResultFields <> '' then
    AppendJsonField(EnvelopeFields, 'result', '{' + ResultFields + '}');
  if ActiveDiagnosticsProjection.Json <> '' then
    AppendJsonField(
      EnvelopeFields,
      'diagnostics',
      ActiveDiagnosticsProjection.Json
    )
  else
    AppendJsonField(EnvelopeFields, 'diagnostics', '[]');
  if ActiveToolchainProjection.BuildTraceRef <> '' then
    AppendJsonField(
      EnvelopeFields,
      'buildTraceRef',
      JsonString(ActiveToolchainProjection.BuildTraceRef)
    )
  else
    AppendJsonField(EnvelopeFields, 'buildTraceRef', 'null');
  if ActiveToolchainProjection.BuildTraceJson <> '' then
    AppendJsonField(
      EnvelopeFields,
      'buildTrace',
      ActiveToolchainProjection.BuildTraceJson
    );
  if ActiveToolchainProjection.ToolInvocationPlanRef <> '' then
    AppendJsonField(
      EnvelopeFields,
      'toolInvocationPlanRef',
      JsonString(ActiveToolchainProjection.ToolInvocationPlanRef)
    );
  if ActiveToolchainProjection.ToolInvocationPlanJson <> '' then
    AppendJsonField(
      EnvelopeFields,
      'toolInvocationPlan',
      ActiveToolchainProjection.ToolInvocationPlanJson
    );
  if ActiveToolchainProjection.ToolStatusEventsJson <> '' then
    AppendJsonField(
      EnvelopeFields,
      'toolStatusEvents',
      ActiveToolchainProjection.ToolStatusEventsJson
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
  const AUseStdErr: Boolean
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
    AHumanSummary
  );
  if AUseStdErr then
    WriteLn(ErrOutput, 'command-envelope=', EnvelopeJson)
  else
    WriteLn('command-envelope=', EnvelopeJson);
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
  AContext.RuntimeSdkStatus := '';
end;

procedure ClearDoctorProjectionContextValue(
  var AContext: TDoctorProjectionContext
);
begin
  AContext.Status := '';
  AContext.CheckCount := 0;
  AContext.FindingCount := 0;
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
  RuntimeRootPath: string;
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
  if AContext.RuntimeLibcPresent then
  begin
    AContext.EnvironmentReadiness := 'ready';
    AContext.RuntimeSdkStatus := 'ready';
  end
  else
  begin
    AContext.EnvironmentReadiness := 'incomplete';
    AContext.RuntimeSdkStatus := 'missing';
  end;
end;

procedure CaptureDoctorProjectionFromEnvironment(
  var AContext: TDoctorProjectionContext;
  const AEnvironmentContext: TEnvironmentProjectionContext;
  const AWorkspaceRoot: string
);
begin
  AContext.CheckCount := 3;
  AContext.FindingCount := 0;

  if (not AEnvironmentContext.HasRuntimeLibcPresent) or
    (not AEnvironmentContext.RuntimeLibcPresent) then
    Inc(AContext.FindingCount);

  if AWorkspaceRoot <> '' then
  begin
    Inc(AContext.CheckCount);
    if not DirectoryExists(AWorkspaceRoot) then
      Inc(AContext.FindingCount);
  end;

  if AContext.FindingCount > 0 then
    AContext.Status := 'warning'
  else
    AContext.Status := 'healthy';
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
  ClearBuildCommandContextValue(ActiveBuildContext);
end;

procedure ClearSessionContext;
begin
  ClearSessionProjectionContextValue(ActiveSessionProjection);
  ClearDiagnosticProjectionContextValue(ActiveDiagnosticsProjection);
  ClearSyntaxProjectionContextValue(ActiveSyntaxProjection);
  ClearResolutionProjectionContextValue(ActiveResolutionProjection);
  ClearSemanticProjectionContextValue(ActiveSemanticProjection);
  ClearMirProjectionContextValue(ActiveMirProjection);
  ClearBackendProjectionContextValue(ActiveBackendProjection);
  ClearToolchainProjectionContextValue(ActiveToolchainProjection);
  ClearEnvironmentProjectionContextValue(ActiveEnvironmentProjection);
  ClearDoctorProjectionContextValue(ActiveDoctorProjection);
end;

procedure CaptureBuildCommandContext(
  const ASourcePath: string;
  const ATargetName: string;
  const AWorkspaceModel: TWorkspaceModel
);
begin
  CaptureBuildCommandContextValue(
    ActiveBuildContext,
    ASourcePath,
    ATargetName,
    AWorkspaceModel
  );
end;

procedure CaptureSessionContext(const Session: TCompilationSession);
begin
  CaptureBuildContextFromSession(ActiveBuildContext, Session);
  CaptureSessionProjectionContextValue(ActiveSessionProjection, Session);
  CaptureDiagnosticProjectionContextValue(ActiveDiagnosticsProjection, Session);
  CaptureSyntaxProjectionContextValue(ActiveSyntaxProjection, Session);
  CaptureResolutionProjectionContextValue(ActiveResolutionProjection, Session);
  CaptureSemanticProjectionContextValue(ActiveSemanticProjection, Session);
  CaptureMirProjectionContextValue(ActiveMirProjection, Session);
  CaptureBackendProjectionContextValue(ActiveBackendProjection, Session);
  CaptureToolchainProjectionContextValue(ActiveToolchainProjection, Session);
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
    ActiveBuildContext.WorkspaceRootPath
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'workspace-discovery-kind',
    ActiveBuildContext.WorkspaceDiscoveryKind
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'workspace-descriptor-path',
    ActiveBuildContext.WorkspaceDescriptorPath
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'package-manifest-path',
    ActiveBuildContext.PackageManifestPath
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'artifact-root',
    ActiveBuildContext.ArtifactRootPath
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'output-dir',
    ActiveBuildContext.OutputDirPath
  );
end;

procedure PrintSessionIdentityProjection(const UseStdErr: Boolean);
begin
  WriteProjectionLine(
    UseStdErr,
    'session-id',
    ActiveSessionProjection.SessionId
  );
  WriteProjectionInteger(
    UseStdErr,
    'root-file-id',
    ActiveSessionProjection.RootFileId
  );
  WriteProjectionInteger(
    UseStdErr,
    'source-db-file-count',
    ActiveSessionProjection.SourceFileCount
  );
  WriteProjectionLine(
    UseStdErr,
    'source-db-line-index',
    ActiveSessionProjection.SourceLineIndexState
  );
  WriteProjectionInteger(
    UseStdErr,
    'unit-state-count',
    ActiveSessionProjection.UnitStateCount
  );
end;

procedure PrintDiagnosticsCountsProjection(const UseStdErr: Boolean);
begin
  WriteProjectionInteger(
    UseStdErr,
    'diagnostics-count',
    ActiveDiagnosticsProjection.Count
  );
  WriteProjectionInteger(
    UseStdErr,
    'diagnostics-error-count',
    ActiveDiagnosticsProjection.ErrorCount
  );
  WriteProjectionInteger(
    UseStdErr,
    'diagnostics-warning-count',
    ActiveDiagnosticsProjection.WarningCount
  );
  WriteProjectionLine(
    UseStdErr,
    'diagnostics-policy',
    ActiveDiagnosticsProjection.Policy
  );
end;

procedure PrintSyntaxProjectionFields(const UseStdErr: Boolean);
begin
  WriteProjectionLine(UseStdErr, 'syntax-status', ActiveSyntaxProjection.Status);
  WriteProjectionInteger(
    UseStdErr,
    'lexer-token-count',
    ActiveSyntaxProjection.LexerTokenCount
  );
  WriteProjectionInteger(
    UseStdErr,
    'green-node-count',
    ActiveSyntaxProjection.GreenNodeCount
  );
  WriteProjectionLine(
    UseStdErr,
    'ast-root-kind',
    ActiveSyntaxProjection.AstRootKind
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'ast-declared-name',
    ActiveSyntaxProjection.AstDeclaredName
  );
end;

procedure PrintResolutionProjectionFields(const UseStdErr: Boolean);
begin
  WriteProjectionLine(
    UseStdErr,
    'resolution-status',
    ActiveResolutionProjection.Status
  );
  WriteProjectionLine(
    UseStdErr,
    'unit-graph-status',
    ActiveResolutionProjection.UnitGraphStatus
  );
  WriteProjectionInteger(
    UseStdErr,
    'search-path-count',
    ActiveResolutionProjection.SearchPathCount
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'search-index-status',
    ActiveResolutionProjection.SearchIndexStatus
  );
  WriteProjectionInteger(
    UseStdErr,
    'indexed-search-root-count',
    ActiveResolutionProjection.IndexedSearchRootCount
  );
  WriteProjectionInteger(
    UseStdErr,
    'search-index-scan-count',
    ActiveResolutionProjection.SearchIndexScanCount
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'search-path-json',
    ActiveResolutionProjection.SearchPathJson
  );
  WriteProjectionInteger(
    UseStdErr,
    'resolved-unit-count',
    ActiveResolutionProjection.ResolvedUnitCount
  );
  WriteProjectionInteger(
    UseStdErr,
    'unit-graph-edge-count',
    ActiveResolutionProjection.UnitGraphEdgeCount
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'unit-graph-root-name',
    ActiveResolutionProjection.UnitGraphRootName
  );
end;

procedure PrintSemanticProjectionFields(const UseStdErr: Boolean);
begin
  WriteProjectionLine(
    UseStdErr,
    'semantic-status',
    ActiveSemanticProjection.Status
  );
  WriteProjectionLine(
    UseStdErr,
    'symbol-graph-status',
    ActiveSemanticProjection.SymbolGraphStatus
  );
  WriteProjectionLine(
    UseStdErr,
    'type-graph-status',
    ActiveSemanticProjection.TypeGraphStatus
  );
  WriteProjectionLine(
    UseStdErr,
    'typed-hir-status',
    ActiveSemanticProjection.TypedHirStatus
  );
  WriteProjectionInteger(
    UseStdErr,
    'symbol-count',
    ActiveSemanticProjection.SymbolCount
  );
  WriteProjectionInteger(
    UseStdErr,
    'type-count',
    ActiveSemanticProjection.TypeCount
  );
  WriteProjectionInteger(
    UseStdErr,
    'typed-hir-node-count',
    ActiveSemanticProjection.TypedHirNodeCount
  );
  WriteProjectionInteger(
    UseStdErr,
    'runtime-contract-count',
    ActiveSemanticProjection.RuntimeContractCount
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'typed-hir-root-name',
    ActiveSemanticProjection.TypedHirRootName
  );
end;

procedure PrintMirProjectionFields(const UseStdErr: Boolean);
begin
  WriteProjectionLine(UseStdErr, 'mir-status', ActiveMirProjection.Status);
  WriteProjectionInteger(
    UseStdErr,
    'mir-block-count',
    ActiveMirProjection.BlockCount
  );
  WriteProjectionInteger(
    UseStdErr,
    'mir-operation-count',
    ActiveMirProjection.OperationCount
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'mir-entry-block',
    ActiveMirProjection.EntryBlock
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'mir-root-name',
    ActiveMirProjection.RootName
  );
end;

procedure PrintBackendProjectionFields(const UseStdErr: Boolean);
begin
  WriteProjectionLine(
    UseStdErr,
    'backend-plan-status',
    ActiveBackendProjection.PlanStatus
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'backend-output-kind',
    ActiveBackendProjection.OutputKind
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'backend-primary-artifact-kind',
    ActiveBackendProjection.PrimaryArtifactKind
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'backend-primary-artifact-path',
    ActiveBackendProjection.PrimaryArtifactPath
  );
  WriteProjectionIntegerWhenEnabled(
    UseStdErr,
    'backend-artifact-count',
    ActiveBackendProjection.ArtifactCount,
    ActiveBackendProjection.ArtifactCount > 0
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'backend-artifacts',
    ActiveBackendProjection.ArtifactsJson
  );
end;

procedure PrintToolchainProjectionFields(const UseStdErr: Boolean);
begin
  WriteProjectionTextIfPresent(
    UseStdErr,
    'host-id',
    ActiveToolchainProjection.HostId
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'toolchain-binding-id',
    ActiveToolchainProjection.ToolchainBindingId
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'backend-family',
    ActiveToolchainProjection.BackendFamily
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'assembler-profile-id',
    ActiveToolchainProjection.AssemblerProfileId
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'linker-profile-id',
    ActiveToolchainProjection.LinkerProfileId
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'archiver-profile-id',
    ActiveToolchainProjection.ArchiverProfileId
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'resource-tool-profile-id',
    ActiveToolchainProjection.ResourceToolProfileId
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'target-object-format',
    ActiveToolchainProjection.TargetObjectFormat
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'target-assembler-flavor',
    ActiveToolchainProjection.TargetAssemblerFlavor
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'target-linker-flavor',
    ActiveToolchainProjection.TargetLinkerFlavor
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'target-runtime-layout-key',
    ActiveToolchainProjection.TargetRuntimeLayoutKey
  );
  WriteProjectionTextWhenEnabled(
    UseStdErr,
    'target-c-symbol-prefix',
    ActiveToolchainProjection.TargetCSymbolPrefix,
    ActiveToolchainProjection.HostId <> ''
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'target-c-library-naming',
    ActiveToolchainProjection.TargetCLibraryNaming
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'target-llvm-triple',
    ActiveToolchainProjection.TargetLlvmTriple
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'target-llvm-data-layout',
    ActiveToolchainProjection.TargetLlvmDataLayout
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'sysroot-mode',
    ActiveToolchainProjection.SysrootMode
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'runtime-sdk-id',
    ActiveToolchainProjection.RuntimeSdkId
  );
  WriteProjectionBooleanWhenEnabled(
    UseStdErr,
    'allow-host-fallback',
    ActiveToolchainProjection.AllowHostFallback,
    ActiveToolchainProjection.HostId <> ''
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'tool-root-kind',
    ActiveToolchainProjection.ToolRootKind
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'runtime-root-kind',
    ActiveToolchainProjection.RuntimeRootKind
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'response-file-policy',
    ActiveToolchainProjection.ResponseFilePolicy
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'link-script-policy',
    ActiveToolchainProjection.LinkScriptPolicy
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'toolchain-plan-status',
    ActiveToolchainProjection.ToolchainPlanStatus
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'toolchain-plan-family',
    ActiveToolchainProjection.ToolchainPlanFamily
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'tool-profile-root',
    ActiveToolchainProjection.ToolProfileRoot
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'logical-link-request-status',
    ActiveToolchainProjection.LogicalLinkRequestStatus
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'logical-link-request-output-kind',
    ActiveToolchainProjection.LogicalLinkRequestOutputKind
  );
  WriteProjectionInteger(
    UseStdErr,
    'logical-link-request-library-count',
    ActiveToolchainProjection.LogicalLibraryRequestCount
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'logical-link-request',
    ActiveToolchainProjection.LogicalLinkRequestJson
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'llvm-toolchain-status',
    ActiveToolchainProjection.LlvmToolchainStatus
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'llvm-executable-set-id',
    ActiveToolchainProjection.LlvmExecutableSetId
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'llvm-executable-set',
    ActiveToolchainProjection.LlvmExecutableSetJson
  );
  WriteProjectionInteger(
    UseStdErr,
    'tool-invocation-count',
    ActiveToolchainProjection.ToolInvocationCount
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'tool-run-status',
    ActiveToolchainProjection.ToolRunStatus
  );
  WriteProjectionIntegerWhenEnabled(
    UseStdErr,
    'tool-run-step-count',
    ActiveToolchainProjection.ToolRunStepCount,
    ActiveToolchainProjection.ToolRunStepCount > 0
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'primary-tool-run-status',
    ActiveToolchainProjection.PrimaryToolRunStatus
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'primary-tool-role',
    ActiveToolchainProjection.PrimaryToolRole
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'primary-tool-profile-id',
    ActiveToolchainProjection.PrimaryToolProfileId
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'primary-tool-step-id',
    ActiveToolchainProjection.PrimaryToolStepId
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'primary-tool-logical-executable',
    ActiveToolchainProjection.PrimaryToolLogicalExecutable
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'primary-tool-sysroot-ref',
    ActiveToolchainProjection.PrimaryToolSysrootRef
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'primary-tool-failure-mapping',
    ActiveToolchainProjection.PrimaryToolFailureMapping
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'tool-invocation-plan-ref',
    ActiveToolchainProjection.ToolInvocationPlanRef
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'tool-invocation-plan',
    ActiveToolchainProjection.ToolInvocationPlanJson
  );
  WriteProjectionIntegerWhenEnabled(
    UseStdErr,
    'tool-status-event-count',
    ActiveToolchainProjection.ToolStatusEventCount,
    ActiveToolchainProjection.ToolStatusEventCount > 0
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'tool-status-events',
    ActiveToolchainProjection.ToolStatusEventsJson
  );
end;

procedure PrintEnvironmentProjectionFields(const UseStdErr: Boolean);
begin
  WriteProjectionTextIfPresent(
    UseStdErr,
    'toolchain-binding-path',
    ActiveEnvironmentProjection.ToolchainBindingPath
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'distribution-bin-dir',
    ActiveEnvironmentProjection.DistributionBinDir
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'distribution-lib-dir',
    ActiveEnvironmentProjection.DistributionLibDir
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'distribution-share-dir',
    ActiveEnvironmentProjection.DistributionShareDir
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'runtime-root',
    ActiveEnvironmentProjection.RuntimeRootPath
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'runtime-libc',
    ActiveEnvironmentProjection.RuntimeLibcPath
  );
  WriteProjectionBooleanWhenEnabled(
    UseStdErr,
    'runtime-libc-present',
    ActiveEnvironmentProjection.RuntimeLibcPresent,
    ActiveEnvironmentProjection.HasRuntimeLibcPresent
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'environment-readiness',
    ActiveEnvironmentProjection.EnvironmentReadiness
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'runtime-sdk-status',
    ActiveEnvironmentProjection.RuntimeSdkStatus
  );
end;

procedure PrintDoctorProjectionFields(const UseStdErr: Boolean);
begin
  WriteProjectionTextIfPresent(
    UseStdErr,
    'doctor-status',
    ActiveDoctorProjection.Status
  );
  WriteProjectionIntegerWhenEnabled(
    UseStdErr,
    'doctor-check-count',
    ActiveDoctorProjection.CheckCount,
    ActiveDoctorProjection.CheckCount > 0
  );
  WriteProjectionIntegerWhenEnabled(
    UseStdErr,
    'doctor-finding-count',
    ActiveDoctorProjection.FindingCount,
    ActiveDoctorProjection.CheckCount > 0
  );
end;

procedure PrintDiagnosticsDetailProjection(const UseStdErr: Boolean);
begin
  WriteProjectionLine(
    UseStdErr,
    'diagnostics-summary',
    ActiveDiagnosticsProjection.Summary
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'diagnostic-id',
    ActiveDiagnosticsProjection.Id
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'diagnostic-code',
    ActiveDiagnosticsProjection.Code
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'diagnostic-phase',
    ActiveDiagnosticsProjection.Phase
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'diagnostic-message',
    ActiveDiagnosticsProjection.Message
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'diagnostic-binding-id',
    ActiveDiagnosticsProjection.BindingId
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'diagnostic-profile-id',
    ActiveDiagnosticsProjection.ProfileId
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'diagnostic-step-id',
    ActiveDiagnosticsProjection.StepId
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'diagnostic-logical-executable',
    ActiveDiagnosticsProjection.LogicalExecutable
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'diagnostic-sysroot-ref',
    ActiveDiagnosticsProjection.SysrootRef
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'diagnostic-resolved-path',
    ActiveDiagnosticsProjection.ResolvedPath
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'diagnostic-primary-artifact-kind',
    ActiveDiagnosticsProjection.PrimaryArtifactKind
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'diagnostic-primary-artifact-path',
    ActiveDiagnosticsProjection.PrimaryArtifactPath
  );
  WriteProjectionIntegerWhenEnabled(
    UseStdErr,
    'diagnostic-exit-code',
    ActiveDiagnosticsProjection.ExitCode,
    ActiveDiagnosticsProjection.HasExitCode
  );
end;

procedure PrintBuildTraceProjection(const UseStdErr: Boolean);
begin
  WriteProjectionTextIfPresent(
    UseStdErr,
    'build-trace-ref',
    ActiveToolchainProjection.BuildTraceRef
  );
  WriteProjectionTextIfPresent(
    UseStdErr,
    'build-trace',
    ActiveToolchainProjection.BuildTraceJson
  );
end;

procedure PrintLifecycleProjection(const UseStdErr: Boolean);
begin
  WriteProjectionLine(
    UseStdErr,
    'lifecycle-session',
    ActiveSessionProjection.SessionLifetime
  );
  WriteProjectionLine(
    UseStdErr,
    'lifecycle-unit',
    ActiveSessionProjection.UnitLifetime
  );
  WriteProjectionLine(
    UseStdErr,
    'lifecycle-stage',
    ActiveSessionProjection.StageLifetime
  );
end;

procedure PrintSessionProjection(const UseStdErr: Boolean);
begin
  PrintBuildContextProjection(UseStdErr);
  if ActiveSessionProjection.SessionId = '' then
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
  if ActiveCommand <> '' then
    WriteLn(ErrOutput, 'command=', ActiveCommand);
  WriteLn(ErrOutput, 'selector=', EnvelopeSelectorName);
  if ActiveBuildContext.TargetName <> '' then
    WriteLn(ErrOutput, 'target=', ActiveBuildContext.TargetName);
  PrintSessionProjection(True);
  WriteLn(ErrOutput, 'status=failure');
  WriteLn(ErrOutput, 'result=failure');
  WriteLn(ErrOutput, 'failure-kind=', FailureKind);
  WriteLn(ErrOutput, 'command-outcome=failure');
  PrintCommandEnvelope(
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
  ActiveBuildContext.TargetName := TargetName;
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

  ActiveBuildContext.TargetConfigPath := TargetConfig.ConfigPath;
  ActiveBuildContext.CompilerName := TargetConfig.CompilerExecutable;
  CaptureToolchainProjectionFromTargetConfig(
    ActiveToolchainProjection,
    TargetConfig
  );
  CaptureEnvironmentProjectionFromTargetConfig(
    ActiveEnvironmentProjection,
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
  ActiveBuildContext.TargetName := TargetName;
  WorkspaceRoot := '';
  if WorkspaceOverride <> '' then
  begin
    WorkspaceRoot := ExpandFileName(WorkspaceOverride);
    if not DirectoryExists(WorkspaceRoot) then
      Fail('invalid-workspace-root: ' + WorkspaceOverride, True);
    ActiveBuildContext.WorkspaceRootPath := WorkspaceRoot;
    ActiveBuildContext.WorkspaceDiscoveryKind := 'explicit-workspace-override';
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

  ActiveBuildContext.TargetConfigPath := TargetConfig.ConfigPath;
  ActiveBuildContext.CompilerName := TargetConfig.CompilerExecutable;
  CaptureToolchainProjectionFromTargetConfig(
    ActiveToolchainProjection,
    TargetConfig
  );
  CaptureEnvironmentProjectionFromTargetConfig(
    ActiveEnvironmentProjection,
    TargetConfig
  );
  CaptureDoctorProjectionFromEnvironment(
    ActiveDoctorProjection,
    ActiveEnvironmentProjection,
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
  ActiveBuildContext.SourcePath := SourcePath;
  ActiveBuildContext.TargetName := TargetName;
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

    ActiveBuildContext.TargetConfigPath := TargetConfig.ConfigPath;
    TargetFacts := BuildTargetFactsView(
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
    ActiveBuildContext.CompilerName := TargetConfig.CompilerExecutable;
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

    ActiveBuildContext.CompilerName := Session.PrimaryToolLogicalExecutable;
    RunResult := Session.ExecuteToolchain(GetEnvironmentVariable('PATH'));
    try
      if RunResult.StepCount > 0 then
      begin
        FinalToolStep := RunResult.StepAt(RunResult.StepCount - 1);
        CompilerExitCode := FinalToolStep.ExitCode;
        ActiveBuildContext.CompilerExitCode := FinalToolStep.ExitCode;
        ActiveBuildContext.HasCompilerExitCode := FinalToolStep.HasExitCode;
      end
      else
      begin
        CompilerExitCode := 0;
        ActiveBuildContext.CompilerExitCode := 0;
        ActiveBuildContext.HasCompilerExitCode := False;
      end;

      CaptureSessionContext(Session);
      if RunResult.Status <> 'success' then
      begin
        if Session.HasLastDiagnosticExitCode then
        begin
          ActiveBuildContext.CompilerExitCode := Session.LastDiagnosticExitCode;
          ActiveBuildContext.HasCompilerExitCode := True;
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

      if not ActiveBuildContext.HasCompilerExitCode then
      begin
        ActiveBuildContext.CompilerExitCode := CompilerExitCode;
        ActiveBuildContext.HasCompilerExitCode := True;
      end;
    finally
      RunResult.Free;
    end;

    if CompilerExitCode <> 0 then
    begin
      Fail(Session.PrimaryToolFailureMapping + ': compiler exit code ' + IntToStr(CompilerExitCode));
    end;

    ActiveBuildContext.ArtifactPath := Session.BackendPrimaryArtifactPath;
    WriteLn('mode=build');
    WriteLn('command=build');
    WriteLn('selector=build');
    WriteLn('source=', SourcePath);
    WriteLn('target=', TargetName);
    WriteLn('target-config=', TargetConfig.ConfigPath);
    WriteLn('compiler=', ActiveBuildContext.CompilerName);
    WriteLn('compiler-exit=', CompilerExitCode);
    WriteLn('artifact=', ActiveBuildContext.ArtifactPath);
    PrintSessionProjection(False);
    WriteLn('status=success');
    WriteLn('result=success');
    WriteLn('command-outcome=success');
    WriteLn('build-result=success');
    PrintCommandEnvelope(
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
  ActiveCommand := '';
  ActiveSelector := '';
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
  ActiveCommand := CommandName;

  if (CommandName <> 'build') and (CommandName <> 'test') and
    (CommandName <> 'env') and (CommandName <> 'doctor') then
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

    ActiveSelector := 'status';
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
    ActiveSelector := 'doctor';
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
