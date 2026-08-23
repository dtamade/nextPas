unit np_toolchain_plan;

{$mode objfpc}{$H+}
{$UNITPATH ../backend}
{$UNITPATH ../targets}
{$UNITPATH ../diagnostics}
{$UNITPATH ../../core/src}

interface

uses
  nextpas.core.text, nextpas.core.text.conv, nextpas.core.path,
  nextpas.core.fs.util, nextpas.core.os.env,
  nextpas.core.collections.vec,
  np_backend_plan, nextpas.compiler.targets.facts, np_toolchain_profiles,
  nextpas.compiler.diagnostics.json_helpers;

type
  TToolArtifactRef = record
    Kind: string;
    Path: string;
  end;

  TToolSidecarRef = record
    Kind: string;
    Path: string;
    OwnerStepId: string;
    MaterializationTiming: string;
    CleanupPolicy: string;
  end;

  TToolEnvDelta = record
    Name: string;
    Value: string;
  end;

  TLogicalLibraryRequest = record
    LogicalId: string;
    LinkageKind: string;
    Strength: string;
  end;

  TToolArtifactRefVec = specialize TVec<TToolArtifactRef>;
  TToolSidecarRefVec = specialize TVec<TToolSidecarRef>;
  TToolEnvDeltaVec = specialize TVec<TToolEnvDelta>;
  TToolchainStringVec = specialize TVec<string>;
  TLogicalLibraryRequestVec = specialize TVec<TLogicalLibraryRequest>;

  TToolInvocationStep = record
    StepId: string;
    ToolRole: string;
    ProfileId: string;
    SysrootRef: string;
    LogicalExecutable: string;
    ExecutableRef: string;
    WorkingDirectory: string;
    FailureMapping: string;
    Argv: TToolchainStringVec;
    EnvDelta: TToolEnvDeltaVec;
    Inputs: TToolArtifactRefVec;
    Outputs: TToolArtifactRefVec;
    Sidecars: TToolSidecarRefVec;
  end;
  PToolInvocationStep = ^TToolInvocationStep;
  TToolInvocationStepVec = specialize TVec<TToolInvocationStep>;

  TLogicalLinkRequest = record
    RequestKind: string;
    Status: string;
    BindingId: string;
    TargetId: string;
    LinkerProfileId: string;
    OutputKind: string;
    PrimaryArtifactPath: string;
    ObjectInputs: TToolArtifactRefVec;
    LibraryRequests: TLogicalLibraryRequestVec;
    OrderedSymbols: TToolchainStringVec;
  end;

  TLlvmExecutableContract = record
    ContractKind: string;
    Status: string;
    Enabled: Boolean;
    ExecutableSetId: string;
    ToolRootKind: string;
    ClangDriver: string;
    Llc: string;
    Opt: string;
    Lld: string;
    LlvmAr: string;
    SuffixPolicy: string;
    VersionContract: string;
  end;

  TToolchainPlan = class
  private
    FStatus: string;
    FFailureCode: string;
    FFailureMessage: string;
    FPlanFamily: string;
    FToolProfileRoot: string;
    FToolRole: string;
    FProfileId: string;
    FBindingId: string;
    FHostId: string;
    FTargetId: string;
    FSysrootRef: string;
    FSteps: TToolInvocationStepVec;
    FLogicalLinkRequest: TLogicalLinkRequest;
    FLlvmExecutableContract: TLlvmExecutableContract;
  public
    constructor Create;
    destructor Destroy; override;
    procedure SetPlanFamily(const AValue: string);
    procedure SetToolProfileRoot(const AValue: string);
    procedure SetContext(
      const AToolRole: string;
      const AProfileId: string;
      const ABindingId: string;
      const AHostId: string;
      const ATargetId: string;
      const ASysrootRef: string
    );
    function AddStep(
      const AStepId: string;
      const ALogicalExecutable: string;
      const AExecutableRef: string;
      const AWorkingDirectory: string;
      const AFailureMapping: string
    ): LongInt;
    procedure SetStepContext(
      const AStepIndex: LongInt;
      const AToolRole: string;
      const AProfileId: string;
      const ASysrootRef: string
    );
    procedure AddStepArg(const AStepIndex: LongInt; const AValue: string);
    procedure AddStepInput(
      const AStepIndex: LongInt;
      const AKind: string;
      const APath: string
    );
    procedure AddStepOutput(
      const AStepIndex: LongInt;
      const AKind: string;
      const APath: string
    );
    procedure AddStepSidecar(
      const AStepIndex: LongInt;
      const AKind: string;
      const APath: string;
      const AOwnerStepId: string;
      const AMaterializationTiming: string;
      const ACleanupPolicy: string
    );
    procedure ConfigureLogicalLinkRequest(
      const AStatus: string;
      const ABindingId: string;
      const ATargetId: string;
      const ALinkerProfileId: string;
      const AOutputKind: string;
      const APrimaryArtifactPath: string
    );
    procedure AddLogicalObjectInput(const APath: string);
    procedure AddLogicalLibraryRequest(
      const ALogicalId: string;
      const ALinkageKind: string;
      const AStrength: string
    );
    procedure SetLlvmExecutableContract(
      const AStatus: string;
      const AEnabled: Boolean;
      const AExecutableSet: TLlvmExecutableSet
    );
    procedure MarkReady;
    procedure MarkFailure(const ACode: string; const AMessage: string);
    function Status: string;
    function FailureCode: string;
    function FailureMessage: string;
    function PlanFamily: string;
    function ToolProfileRoot: string;
    function ToolInvocationCount: LongInt;
    function StepAt(const AIndex: LongInt): TToolInvocationStep;
    function PrimaryToolRole: string;
    function PrimaryToolProfileId: string;
    function PrimaryToolStepId: string;
    function PrimaryToolLogicalExecutable: string;
    function PrimaryToolExecutableRef: string;
    function PrimaryToolSysrootRef: string;
    function PrimaryToolFailureMapping: string;
    function PrimaryToolArgCount: LongInt;
    function PrimaryToolArgValue(const AIndex: LongInt): string;
    function PrimaryToolWorkingDirectory: string;
    function LogicalLinkRequestStatus: string;
    function LogicalLinkRequestOutputKind: string;
    function LogicalLibraryRequestCount: LongInt;
    function LlvmToolchainStatus: string;
    function LlvmExecutableSetId: string;
    function ToolInvocationPlanJson(
      const APlanId: string;
      const AResolvedPath: string
    ): string;
    function LogicalLinkRequestJson: string;
    function LlvmExecutableSetJson: string;
  end;

  TToolchainPlanner = class
  private
    FBackendPlan: TBackendPlan;
    FPlan: TToolchainPlan;
    FSourcePath: string;
    FArtifactRootPath: string;
    FProjectUnitRoots: TToolchainStringVec;
    FExplicitUnitRoots: TToolchainStringVec;
    FAdditionalAssemblyBaseNames: TToolchainStringVec;
    FTargetFacts: TTargetFactsView;
    function BuildSysrootRef: string;
    function PrimaryArtifactPathOrDefault: string;
    function HostCompilerScratchRootPath: string;
    function ToolProfileRootPath: string;
    function RepoRootPath: string;
    function DistributionRuntimeRootPath: string;
    function FindRuntimeLibrary(const ATargetId: string): string;
    function ResolveDirectLinkLibraries(
      out ARuntimeRootPath: string;
      out ASharedLibraryPath: string;
      out AHasResolvedLibrary: Boolean
    ): Boolean;
    function PrepareLlvmContract: Boolean;
    procedure AppendBackendLogicalLibraryRequests;
    procedure AppendDirectLinkLibraryArgs(const AStepIndex: LongInt);
    procedure AppendUnitSearchRoots(
      const AStepIndex: LongInt;
      const AUnitsFlag: string
    );
    procedure PreparePlanContext(
      const APlanFamily: string;
      const AToolRole: string;
      const AProfileId: string
    );
  public
    constructor Create(
      const ABackendPlan: TBackendPlan;
      const ATargetFacts: TTargetFactsView;
      const ASourcePath: string
    ); overload;
    constructor Create(
      const ABackendPlan: TBackendPlan;
      const ATargetFacts: TTargetFactsView;
      const ASourcePath: string;
      const AArtifactRootPath: string;
      const AProjectUnitRoots: TStringArray;
      const AExplicitUnitRoots: TStringArray;
      const AAdditionalAssemblyBaseNames: TStringArray
    ); overload;
    destructor Destroy; override;
    procedure PlanFromBackend;
    procedure PlanBootstrapNativeAssembleLink;
    procedure PlanLlvmIrOptObjectLink;
    procedure PlanBootstrapHostCompiler;
    procedure PlanNativeAssembleLink(
      const AAssemblyPath: string;
      const AObjectPath: string;
      const AOutputPath: string
    );
    procedure PlanResourceCompile(
      const AResourcePath: string;
      const ABinaryResourcePath: string;
      const AObjectPath: string
    );
    procedure PlanArchiveBuild(
      const AArchivePath: string;
      const AObjectPaths: array of string
    );
    function DetachPlan: TToolchainPlan;
  end;

procedure ClearToolInvocationStepView(out AStep: TToolInvocationStep);
function ToolchainArgvAsArray(const AArgv: TToolchainStringVec): TStringArray;
function BuildToolArtifactVecJson(const AValues: TToolArtifactRefVec): string;

implementation

{$I np_toolchain_plan_core.inc}

{$I np_toolchain_plan_json.inc}

{$I np_toolchain_plan_planner.inc}

{$I np_toolchain_plan_llvm.inc}

{$I np_toolchain_plan_bootstrap.inc}

{$I np_toolchain_plan_host.inc}

function TToolchainPlanner.DetachPlan: TToolchainPlan;
begin
  Result := FPlan;
  FPlan := nil;
end;

end.
