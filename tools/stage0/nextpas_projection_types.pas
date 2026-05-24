unit nextpas_projection_types;

{$mode objfpc}{$H+}

interface

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
    SelectionPath: string;
    SelectionStatus: string;
    SelectionTarget: string;
    SelectionToolchainBindingId: string;
    ResolutionPath: string;
    ResolutionStatus: string;
    SyncChange: string;
    ToolchainBindingPath: string;
    DistributionBinDir: string;
    DistributionLibDir: string;
    DistributionShareDir: string;
    RuntimeRootPath: string;
    RuntimeLibcPath: string;
    RuntimeLibcPresent: Boolean;
    HasRuntimeLibcPresent: Boolean;
    EnvironmentReadiness: string;
    EnvironmentStatus: string;
    RuntimeSdkStatus: string;
    ToolchainBindingStatus: string;
    DistributionStatus: string;
  end;

  TDoctorFinding = record
    Code: string;
    Severity: string;
    Subject: string;
    Summary: string;
    SuggestedAction: string;
  end;

  TDoctorProjectionContext = record
    Status: string;
    WorkspaceStatus: string;
    ToolchainBindingStatus: string;
    CheckCount: LongInt;
    FindingCount: LongInt;
    FirstFinding: TDoctorFinding;
    FindingsJson: string;
  end;

  TQueryProjectionContext = record
    Kind: string;
    Status: string;
    AnalysisSource: string;
    ResultCount: LongInt;
    HasResultCount: Boolean;
    SymbolsJson: string;
    ScopesJson: string;
    TypesJson: string;
  end;

  TPackageProjectionContext = record
    WorkflowStatus: string;
    ManifestStatus: string;
    LockStatus: string;
    InstallPlanStatus: string;
    InstallPlanBlockerCode: string;
    InstallPlanBlockerMessage: string;
    ManifestPath: string;
    PackageRootPath: string;
    PackageName: string;
    LockfilePath: string;
    SourceRootCount: LongInt;
    HasSourceRootCount: Boolean;
    SourceRootsJson: string;
    DependencyCount: LongInt;
    HasDependencyCount: Boolean;
    DependenciesJson: string;
    DependencyValidationStatus: string;
    DependencyIssueCount: LongInt;
    HasDependencyIssueCount: Boolean;
    DependencyIssuesJson: string;
  end;

  TNextPasState = record
    CommandName: string;
    SelectorName: string;
    BuildContext: TBuildCommandContext;
    SessionProjection: TSessionProjectionContext;
    DiagnosticsProjection: TDiagnosticProjectionContext;
    SyntaxProjection: TSyntaxProjectionContext;
    ResolutionProjection: TResolutionProjectionContext;
    SemanticProjection: TSemanticProjectionContext;
    MirProjection: TMirProjectionContext;
    BackendProjection: TBackendProjectionContext;
    ToolchainProjection: TToolchainProjectionContext;
    EnvironmentProjection: TEnvironmentProjectionContext;
    DoctorProjection: TDoctorProjectionContext;
    QueryProjection: TQueryProjectionContext;
    PackageProjection: TPackageProjectionContext;
  end;

implementation

end.
