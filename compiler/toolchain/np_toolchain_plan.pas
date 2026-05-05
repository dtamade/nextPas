unit np_toolchain_plan;

{$mode objfpc}{$H+}
{$UNITPATH ../backend}
{$UNITPATH ../targets}

interface

uses
  SysUtils, np_backend_plan, np_target_facts, np_toolchain_profiles,
  nextpas_json_helpers;

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

  TToolInvocationStep = record
    StepId: string;
    ToolRole: string;
    ProfileId: string;
    SysrootRef: string;
    LogicalExecutable: string;
    ExecutableRef: string;
    WorkingDirectory: string;
    FailureMapping: string;
    Argv: array of string;
    EnvDelta: array of TToolEnvDelta;
    Inputs: array of TToolArtifactRef;
    Outputs: array of TToolArtifactRef;
    Sidecars: array of TToolSidecarRef;
  end;

  TLogicalLibraryRequest = record
    LogicalId: string;
    LinkageKind: string;
    Strength: string;
  end;

  TLogicalLinkRequest = record
    RequestKind: string;
    Status: string;
    BindingId: string;
    TargetId: string;
    LinkerProfileId: string;
    OutputKind: string;
    PrimaryArtifactPath: string;
    ObjectInputs: array of TToolArtifactRef;
    LibraryRequests: array of TLogicalLibraryRequest;
    OrderedSymbols: TStringArray;
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
    FSteps: array of TToolInvocationStep;
    FLogicalLinkRequest: TLogicalLinkRequest;
    FLlvmExecutableContract: TLlvmExecutableContract;
  public
    constructor Create;
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
    FProjectUnitRoots: TStringArray;
    FExplicitUnitRoots: TStringArray;
    FAdditionalAssemblyBaseNames: TStringArray;
    FTargetFacts: TTargetFactsView;
    function BuildSysrootRef: string;
    function PrimaryArtifactPathOrDefault: string;
    function HostCompilerScratchRootPath: string;
    function ToolProfileRootPath: string;
    function RepoRootPath: string;
    function DistributionRuntimeRootPath: string;
    function ResolveDirectLinkLibraries(
      out ARuntimeRootPath: string;
      out ASharedLibraryPath: string;
      out AHasResolvedLibrary: Boolean
    ): Boolean;
    function PrepareLlvmContract: Boolean;
    procedure AppendBackendLogicalLibraryRequests;
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

implementation

function BuildStringArrayJson(const AValues: array of string): string;
var
  Index: SizeInt;
begin
  Result := '';
  for Index := 0 to High(AValues) do
  begin
    if Result <> '' then
      Result := Result + ',';
    Result := Result + JsonString(AValues[Index]);
  end;
  Result := '[' + Result + ']';
end;

function BuildToolArtifactArrayJson(const AValues: array of TToolArtifactRef): string;
var
  EntryFields: string;
  Index: SizeInt;
begin
  Result := '';
  for Index := 0 to High(AValues) do
  begin
    if Result <> '' then
      Result := Result + ',';
    EntryFields := '';
    AppendJsonField(EntryFields, 'kind', JsonString(AValues[Index].Kind));
    AppendJsonField(EntryFields, 'path', JsonString(AValues[Index].Path));
    Result := Result + '{' + EntryFields + '}';
  end;
  Result := '[' + Result + ']';
end;

function BuildToolSidecarArrayJson(const AValues: array of TToolSidecarRef): string;
var
  EntryFields: string;
  Index: SizeInt;
begin
  Result := '';
  for Index := 0 to High(AValues) do
  begin
    if Result <> '' then
      Result := Result + ',';
    EntryFields := '';
    AppendJsonField(EntryFields, 'kind', JsonString(AValues[Index].Kind));
    AppendJsonField(EntryFields, 'path', JsonString(AValues[Index].Path));
    AppendJsonField(EntryFields, 'ownerStepId', JsonString(AValues[Index].OwnerStepId));
    AppendJsonField(
      EntryFields,
      'materializationTiming',
      JsonString(AValues[Index].MaterializationTiming)
    );
    AppendJsonField(EntryFields, 'cleanupPolicy', JsonString(AValues[Index].CleanupPolicy));
    Result := Result + '{' + EntryFields + '}';
  end;
  Result := '[' + Result + ']';
end;

function BuildLogicalLibraryRequestJson(
  const AValues: array of TLogicalLibraryRequest
): string;
var
  EntryFields: string;
  Index: SizeInt;
begin
  Result := '';
  for Index := 0 to High(AValues) do
  begin
    if Result <> '' then
      Result := Result + ',';
    EntryFields := '';
    AppendJsonField(EntryFields, 'logicalId', JsonString(AValues[Index].LogicalId));
    AppendJsonField(EntryFields, 'linkageKind', JsonString(AValues[Index].LinkageKind));
    AppendJsonField(EntryFields, 'strength', JsonString(AValues[Index].Strength));
    Result := Result + '{' + EntryFields + '}';
  end;
  Result := '[' + Result + ']';
end;

constructor TToolchainPlan.Create;
begin
  inherited Create;
  FStatus := 'deferred';
  FFailureCode := '';
  FFailureMessage := '';
  FPlanFamily := '';
  FToolProfileRoot := '';
  FToolRole := '';
  FProfileId := '';
  FBindingId := '';
  FHostId := '';
  FTargetId := '';
  FSysrootRef := '';
  SetLength(FSteps, 0);
  FLogicalLinkRequest.RequestKind := 'logical-link-request';
  FLogicalLinkRequest.Status := 'deferred';
  SetLength(FLogicalLinkRequest.ObjectInputs, 0);
  SetLength(FLogicalLinkRequest.LibraryRequests, 0);
  SetLength(FLogicalLinkRequest.OrderedSymbols, 0);
  FLlvmExecutableContract.ContractKind := 'llvm-executable-set';
  FLlvmExecutableContract.Status := 'deferred';
  FLlvmExecutableContract.Enabled := False;
end;

procedure TToolchainPlan.SetPlanFamily(const AValue: string);
begin
  FPlanFamily := AValue;
end;

procedure TToolchainPlan.SetToolProfileRoot(const AValue: string);
begin
  FToolProfileRoot := AValue;
end;

procedure TToolchainPlan.SetContext(
  const AToolRole: string;
  const AProfileId: string;
  const ABindingId: string;
  const AHostId: string;
  const ATargetId: string;
  const ASysrootRef: string
);
begin
  FToolRole := AToolRole;
  FProfileId := AProfileId;
  FBindingId := ABindingId;
  FHostId := AHostId;
  FTargetId := ATargetId;
  FSysrootRef := ASysrootRef;
end;

function TToolchainPlan.AddStep(
  const AStepId: string;
  const ALogicalExecutable: string;
  const AExecutableRef: string;
  const AWorkingDirectory: string;
  const AFailureMapping: string
): LongInt;
var
  NextIndex: SizeInt;
begin
  NextIndex := Length(FSteps);
  SetLength(FSteps, NextIndex + 1);
  FSteps[NextIndex].StepId := AStepId;
  FSteps[NextIndex].ToolRole := FToolRole;
  FSteps[NextIndex].ProfileId := FProfileId;
  FSteps[NextIndex].SysrootRef := FSysrootRef;
  FSteps[NextIndex].LogicalExecutable := ALogicalExecutable;
  FSteps[NextIndex].ExecutableRef := AExecutableRef;
  FSteps[NextIndex].WorkingDirectory := AWorkingDirectory;
  FSteps[NextIndex].FailureMapping := AFailureMapping;
  SetLength(FSteps[NextIndex].Argv, 0);
  SetLength(FSteps[NextIndex].EnvDelta, 0);
  SetLength(FSteps[NextIndex].Inputs, 0);
  SetLength(FSteps[NextIndex].Outputs, 0);
  SetLength(FSteps[NextIndex].Sidecars, 0);
  Result := NextIndex;
end;

procedure TToolchainPlan.SetStepContext(
  const AStepIndex: LongInt;
  const AToolRole: string;
  const AProfileId: string;
  const ASysrootRef: string
);
begin
  if (AStepIndex < 0) or (AStepIndex > High(FSteps)) then
    Exit;

  FSteps[AStepIndex].ToolRole := AToolRole;
  FSteps[AStepIndex].ProfileId := AProfileId;
  FSteps[AStepIndex].SysrootRef := ASysrootRef;
end;

procedure TToolchainPlan.AddStepArg(const AStepIndex: LongInt; const AValue: string);
var
  NextIndex: SizeInt;
begin
  if (AStepIndex < 0) or (AStepIndex > High(FSteps)) then
    Exit;
  NextIndex := Length(FSteps[AStepIndex].Argv);
  SetLength(FSteps[AStepIndex].Argv, NextIndex + 1);
  FSteps[AStepIndex].Argv[NextIndex] := AValue;
end;

procedure TToolchainPlan.AddStepInput(
  const AStepIndex: LongInt;
  const AKind: string;
  const APath: string
);
var
  NextIndex: SizeInt;
begin
  if (AStepIndex < 0) or (AStepIndex > High(FSteps)) then
    Exit;
  NextIndex := Length(FSteps[AStepIndex].Inputs);
  SetLength(FSteps[AStepIndex].Inputs, NextIndex + 1);
  FSteps[AStepIndex].Inputs[NextIndex].Kind := AKind;
  FSteps[AStepIndex].Inputs[NextIndex].Path := APath;
end;

procedure TToolchainPlan.AddStepOutput(
  const AStepIndex: LongInt;
  const AKind: string;
  const APath: string
);
var
  NextIndex: SizeInt;
begin
  if (AStepIndex < 0) or (AStepIndex > High(FSteps)) then
    Exit;
  NextIndex := Length(FSteps[AStepIndex].Outputs);
  SetLength(FSteps[AStepIndex].Outputs, NextIndex + 1);
  FSteps[AStepIndex].Outputs[NextIndex].Kind := AKind;
  FSteps[AStepIndex].Outputs[NextIndex].Path := APath;
end;

procedure TToolchainPlan.AddStepSidecar(
  const AStepIndex: LongInt;
  const AKind: string;
  const APath: string;
  const AOwnerStepId: string;
  const AMaterializationTiming: string;
  const ACleanupPolicy: string
);
var
  NextIndex: SizeInt;
begin
  if (AStepIndex < 0) or (AStepIndex > High(FSteps)) then
    Exit;
  NextIndex := Length(FSteps[AStepIndex].Sidecars);
  SetLength(FSteps[AStepIndex].Sidecars, NextIndex + 1);
  FSteps[AStepIndex].Sidecars[NextIndex].Kind := AKind;
  FSteps[AStepIndex].Sidecars[NextIndex].Path := APath;
  FSteps[AStepIndex].Sidecars[NextIndex].OwnerStepId := AOwnerStepId;
  FSteps[AStepIndex].Sidecars[NextIndex].MaterializationTiming := AMaterializationTiming;
  FSteps[AStepIndex].Sidecars[NextIndex].CleanupPolicy := ACleanupPolicy;
end;

procedure TToolchainPlan.ConfigureLogicalLinkRequest(
  const AStatus: string;
  const ABindingId: string;
  const ATargetId: string;
  const ALinkerProfileId: string;
  const AOutputKind: string;
  const APrimaryArtifactPath: string
);
begin
  FLogicalLinkRequest.RequestKind := 'logical-link-request';
  FLogicalLinkRequest.Status := AStatus;
  FLogicalLinkRequest.BindingId := ABindingId;
  FLogicalLinkRequest.TargetId := ATargetId;
  FLogicalLinkRequest.LinkerProfileId := ALinkerProfileId;
  FLogicalLinkRequest.OutputKind := AOutputKind;
  FLogicalLinkRequest.PrimaryArtifactPath := APrimaryArtifactPath;
  SetLength(FLogicalLinkRequest.ObjectInputs, 0);
  SetLength(FLogicalLinkRequest.LibraryRequests, 0);
  SetLength(FLogicalLinkRequest.OrderedSymbols, 0);
end;

procedure TToolchainPlan.AddLogicalObjectInput(const APath: string);
var
  NextIndex: SizeInt;
begin
  NextIndex := Length(FLogicalLinkRequest.ObjectInputs);
  SetLength(FLogicalLinkRequest.ObjectInputs, NextIndex + 1);
  FLogicalLinkRequest.ObjectInputs[NextIndex].Kind := 'object-file';
  FLogicalLinkRequest.ObjectInputs[NextIndex].Path := APath;
end;

procedure TToolchainPlan.AddLogicalLibraryRequest(
  const ALogicalId: string;
  const ALinkageKind: string;
  const AStrength: string
);
var
  NextIndex: SizeInt;
begin
  NextIndex := Length(FLogicalLinkRequest.LibraryRequests);
  SetLength(FLogicalLinkRequest.LibraryRequests, NextIndex + 1);
  FLogicalLinkRequest.LibraryRequests[NextIndex].LogicalId := ALogicalId;
  FLogicalLinkRequest.LibraryRequests[NextIndex].LinkageKind := ALinkageKind;
  FLogicalLinkRequest.LibraryRequests[NextIndex].Strength := AStrength;
end;

procedure TToolchainPlan.SetLlvmExecutableContract(
  const AStatus: string;
  const AEnabled: Boolean;
  const AExecutableSet: TLlvmExecutableSet
);
begin
  FLlvmExecutableContract.ContractKind := 'llvm-executable-set';
  FLlvmExecutableContract.Status := AStatus;
  FLlvmExecutableContract.Enabled := AEnabled;
  FLlvmExecutableContract.ExecutableSetId := AExecutableSet.Id;
  FLlvmExecutableContract.ToolRootKind := AExecutableSet.ToolRootKind;
  FLlvmExecutableContract.ClangDriver := AExecutableSet.ClangDriver;
  FLlvmExecutableContract.Llc := AExecutableSet.Llc;
  FLlvmExecutableContract.Opt := AExecutableSet.Opt;
  FLlvmExecutableContract.Lld := AExecutableSet.Lld;
  FLlvmExecutableContract.LlvmAr := AExecutableSet.LlvmAr;
  FLlvmExecutableContract.SuffixPolicy := AExecutableSet.SuffixPolicy;
  FLlvmExecutableContract.VersionContract := AExecutableSet.VersionContract;
end;

procedure TToolchainPlan.MarkReady;
begin
  if FStatus = 'failure' then
    Exit;
  FStatus := 'ready';
end;

procedure TToolchainPlan.MarkFailure(const ACode: string; const AMessage: string);
begin
  FStatus := 'failure';
  FFailureCode := ACode;
  FFailureMessage := AMessage;
end;

function TToolchainPlan.Status: string;
begin
  Result := FStatus;
end;

function TToolchainPlan.FailureCode: string;
begin
  Result := FFailureCode;
end;

function TToolchainPlan.FailureMessage: string;
begin
  Result := FFailureMessage;
end;

function TToolchainPlan.PlanFamily: string;
begin
  Result := FPlanFamily;
end;

function TToolchainPlan.ToolProfileRoot: string;
begin
  Result := FToolProfileRoot;
end;

function TToolchainPlan.ToolInvocationCount: LongInt;
begin
  Result := Length(FSteps);
end;

function TToolchainPlan.StepAt(const AIndex: LongInt): TToolInvocationStep;
begin
  if (AIndex < 0) or (AIndex > High(FSteps)) then
  begin
    Result.StepId := '';
    Result.LogicalExecutable := '';
    Result.ExecutableRef := '';
    Result.WorkingDirectory := '';
    Result.FailureMapping := '';
    SetLength(Result.Argv, 0);
    SetLength(Result.EnvDelta, 0);
    SetLength(Result.Inputs, 0);
    SetLength(Result.Outputs, 0);
    SetLength(Result.Sidecars, 0);
    Exit;
  end;

  Result := FSteps[AIndex];
end;

function TToolchainPlan.PrimaryToolRole: string;
begin
  Result := FToolRole;
end;

function TToolchainPlan.PrimaryToolProfileId: string;
begin
  Result := FProfileId;
end;

function TToolchainPlan.PrimaryToolStepId: string;
begin
  if Length(FSteps) = 0 then
    Exit('');
  Result := FSteps[0].StepId;
end;

function TToolchainPlan.PrimaryToolLogicalExecutable: string;
begin
  if Length(FSteps) = 0 then
    Exit('');
  Result := FSteps[0].LogicalExecutable;
end;

function TToolchainPlan.PrimaryToolExecutableRef: string;
begin
  if Length(FSteps) = 0 then
    Exit('');
  Result := FSteps[0].ExecutableRef;
end;

function TToolchainPlan.PrimaryToolSysrootRef: string;
begin
  Result := FSysrootRef;
end;

function TToolchainPlan.PrimaryToolFailureMapping: string;
begin
  if Length(FSteps) = 0 then
    Exit('');
  Result := FSteps[0].FailureMapping;
end;

function TToolchainPlan.PrimaryToolArgCount: LongInt;
begin
  if Length(FSteps) = 0 then
    Exit(0);
  Result := Length(FSteps[0].Argv);
end;

function TToolchainPlan.PrimaryToolArgValue(const AIndex: LongInt): string;
begin
  if (Length(FSteps) = 0) or (AIndex < 0) or (AIndex > High(FSteps[0].Argv)) then
    Exit('');
  Result := FSteps[0].Argv[AIndex];
end;

function TToolchainPlan.PrimaryToolWorkingDirectory: string;
begin
  if Length(FSteps) = 0 then
    Exit('');
  Result := FSteps[0].WorkingDirectory;
end;

function TToolchainPlan.LogicalLinkRequestStatus: string;
begin
  Result := FLogicalLinkRequest.Status;
end;

function TToolchainPlan.LogicalLinkRequestOutputKind: string;
begin
  Result := FLogicalLinkRequest.OutputKind;
end;

function TToolchainPlan.LogicalLibraryRequestCount: LongInt;
begin
  Result := Length(FLogicalLinkRequest.LibraryRequests);
end;

function TToolchainPlan.LlvmToolchainStatus: string;
begin
  Result := FLlvmExecutableContract.Status;
end;

function TToolchainPlan.LlvmExecutableSetId: string;
begin
  Result := FLlvmExecutableContract.ExecutableSetId;
end;

function TToolchainPlan.ToolInvocationPlanJson(
  const APlanId: string;
  const AResolvedPath: string
): string;
var
  StepFields: string;
  PlanFields: string;
  StepJson: string;
  StepResolvedPath: string;
  StepIndex: SizeInt;
begin
  if Length(FSteps) = 0 then
    Exit('');

  StepJson := '';
  for StepIndex := 0 to High(FSteps) do
  begin
    if StepJson <> '' then
      StepJson := StepJson + ',';

    StepFields := '';
    AppendJsonField(StepFields, 'stepId', JsonString(FSteps[StepIndex].StepId));
    AppendJsonField(
      StepFields,
      'logicalExecutable',
      JsonString(FSteps[StepIndex].LogicalExecutable)
    );
    if (StepIndex = 0) and (AResolvedPath <> '') then
      StepResolvedPath := AResolvedPath
    else
      StepResolvedPath := FSteps[StepIndex].ExecutableRef;
    if StepResolvedPath <> '' then
      AppendJsonField(StepFields, 'resolvedPath', JsonString(StepResolvedPath));
    AppendJsonField(StepFields, 'argv', BuildStringArrayJson(FSteps[StepIndex].Argv));
    AppendJsonField(
      StepFields,
      'workingDirectory',
      JsonString(FSteps[StepIndex].WorkingDirectory)
    );
    AppendJsonField(
      StepFields,
      'inputs',
      BuildToolArtifactArrayJson(FSteps[StepIndex].Inputs)
    );
    AppendJsonField(
      StepFields,
      'outputs',
      BuildToolArtifactArrayJson(FSteps[StepIndex].Outputs)
    );
    AppendJsonField(
      StepFields,
      'sidecars',
      BuildToolSidecarArrayJson(FSteps[StepIndex].Sidecars)
    );
    AppendJsonField(
      StepFields,
      'failureMapping',
      JsonString(FSteps[StepIndex].FailureMapping)
    );
    StepJson := StepJson + '{' + StepFields + '}';
  end;

  PlanFields := '';
  AppendJsonField(PlanFields, 'planKind', JsonString('tool-invocation'));
  if APlanId <> '' then
    AppendJsonField(PlanFields, 'planId', JsonString(APlanId));
  AppendJsonField(PlanFields, 'planFamily', JsonString(FPlanFamily));
  AppendJsonField(PlanFields, 'toolRole', JsonString(FToolRole));
  AppendJsonField(PlanFields, 'bindingId', JsonString(FBindingId));
  AppendJsonField(PlanFields, 'profileId', JsonString(FProfileId));
  AppendJsonField(PlanFields, 'hostId', JsonString(FHostId));
  AppendJsonField(PlanFields, 'targetId', JsonString(FTargetId));
  AppendJsonField(PlanFields, 'sysrootRef', JsonString(FSysrootRef));
  AppendJsonField(PlanFields, 'steps', '[' + StepJson + ']');
  Result := '{' + PlanFields + '}';
end;

function TToolchainPlan.LogicalLinkRequestJson: string;
var
  Fields: string;
begin
  Fields := '';
  AppendJsonField(Fields, 'requestKind', JsonString(FLogicalLinkRequest.RequestKind));
  AppendJsonField(Fields, 'status', JsonString(FLogicalLinkRequest.Status));
  AppendJsonField(Fields, 'bindingId', JsonString(FLogicalLinkRequest.BindingId));
  AppendJsonField(Fields, 'targetId', JsonString(FLogicalLinkRequest.TargetId));
  AppendJsonField(
    Fields,
    'linkerProfileId',
    JsonString(FLogicalLinkRequest.LinkerProfileId)
  );
  AppendJsonField(Fields, 'outputKind', JsonString(FLogicalLinkRequest.OutputKind));
  AppendJsonField(
    Fields,
    'primaryArtifactPath',
    JsonString(FLogicalLinkRequest.PrimaryArtifactPath)
  );
  AppendJsonField(
    Fields,
    'objectInputs',
    BuildToolArtifactArrayJson(FLogicalLinkRequest.ObjectInputs)
  );
  AppendJsonField(
    Fields,
    'libraryRequests',
    BuildLogicalLibraryRequestJson(FLogicalLinkRequest.LibraryRequests)
  );
  AppendJsonField(
    Fields,
    'orderedSymbols',
    BuildStringArrayJson(FLogicalLinkRequest.OrderedSymbols)
  );
  Result := '{' + Fields + '}';
end;

function TToolchainPlan.LlvmExecutableSetJson: string;
var
  Fields: string;
begin
  Fields := '';
  AppendJsonField(Fields, 'contractKind', JsonString(FLlvmExecutableContract.ContractKind));
  AppendJsonField(Fields, 'status', JsonString(FLlvmExecutableContract.Status));
  if FLlvmExecutableContract.Enabled then
    AppendJsonField(Fields, 'enabled', 'true')
  else
    AppendJsonField(Fields, 'enabled', 'false');
  AppendJsonField(
    Fields,
    'executableSetId',
    JsonString(FLlvmExecutableContract.ExecutableSetId)
  );
  AppendJsonField(
    Fields,
    'toolRootKind',
    JsonString(FLlvmExecutableContract.ToolRootKind)
  );
  AppendJsonField(
    Fields,
    'clangDriver',
    JsonString(FLlvmExecutableContract.ClangDriver)
  );
  AppendJsonField(Fields, 'llc', JsonString(FLlvmExecutableContract.Llc));
  AppendJsonField(Fields, 'opt', JsonString(FLlvmExecutableContract.Opt));
  AppendJsonField(Fields, 'lld', JsonString(FLlvmExecutableContract.Lld));
  AppendJsonField(Fields, 'llvmAr', JsonString(FLlvmExecutableContract.LlvmAr));
  AppendJsonField(
    Fields,
    'suffixPolicy',
    JsonString(FLlvmExecutableContract.SuffixPolicy)
  );
  AppendJsonField(
    Fields,
    'versionContract',
    JsonString(FLlvmExecutableContract.VersionContract)
  );
  Result := '{' + Fields + '}';
end;

constructor TToolchainPlanner.Create(
  const ABackendPlan: TBackendPlan;
  const ATargetFacts: TTargetFactsView;
  const ASourcePath: string
);
var
  EmptyAssemblyBaseNames: TStringArray;
  EmptyRoots: TStringArray;
begin
  SetLength(EmptyAssemblyBaseNames, 0);
  SetLength(EmptyRoots, 0);
  Create(
    ABackendPlan,
    ATargetFacts,
    ASourcePath,
    '',
    EmptyRoots,
    EmptyRoots,
    EmptyAssemblyBaseNames
  );
end;

constructor TToolchainPlanner.Create(
  const ABackendPlan: TBackendPlan;
  const ATargetFacts: TTargetFactsView;
  const ASourcePath: string;
  const AArtifactRootPath: string;
  const AProjectUnitRoots: TStringArray;
  const AExplicitUnitRoots: TStringArray;
  const AAdditionalAssemblyBaseNames: TStringArray
);
begin
  inherited Create;
  FBackendPlan := ABackendPlan;
  FTargetFacts := ATargetFacts;
  FSourcePath := ASourcePath;
  FArtifactRootPath := AArtifactRootPath;
  FProjectUnitRoots := AProjectUnitRoots;
  FExplicitUnitRoots := AExplicitUnitRoots;
  FAdditionalAssemblyBaseNames := AAdditionalAssemblyBaseNames;
  FPlan := TToolchainPlan.Create;
end;

destructor TToolchainPlanner.Destroy;
begin
  FPlan.Free;
  inherited Destroy;
end;

function TToolchainPlanner.BuildSysrootRef: string;
begin
  if (FTargetFacts.SysrootMode = '') or (FTargetFacts.RuntimeSdkId = '') then
    Exit('');
  Result := FTargetFacts.SysrootMode + ':' + FTargetFacts.RuntimeSdkId;
end;

function TToolchainPlanner.PrimaryArtifactPathOrDefault: string;
begin
  if (FBackendPlan <> nil) and (FBackendPlan.PrimaryArtifactPath <> '') then
    Exit(FBackendPlan.PrimaryArtifactPath);
  Result := ChangeFileExt(FSourcePath, '');
end;

function TToolchainPlanner.HostCompilerScratchRootPath: string;
begin
  if Trim(FArtifactRootPath) = '' then
    Exit(ExtractFileDir(ExpandFileName(FSourcePath)));

  Result := ExpandFileName(
    IncludeTrailingPathDelimiter(FArtifactRootPath) + 'cache' +
    DirectorySeparator + 'host-fpc' + DirectorySeparator + FTargetFacts.TargetId
  );
end;

function TToolchainPlanner.ToolProfileRootPath: string;
begin
  Result := ResolveToolProfileRoot(FTargetFacts.ConfigPath);
end;

function TToolchainPlanner.RepoRootPath: string;
begin
  if Trim(FTargetFacts.ConfigPath) = '' then
    Exit('');

  Result := ExpandFileName(
    IncludeTrailingPathDelimiter(ExtractFileDir(FTargetFacts.ConfigPath)) + '..' +
    DirectorySeparator + '..'
  );
end;

function TToolchainPlanner.DistributionRuntimeRootPath: string;
begin
  if Trim(FTargetFacts.RuntimeSdkId) = '' then
    Exit('');

  Result := ExpandFileName(
    IncludeTrailingPathDelimiter(RepoRootPath) + 'lib' + DirectorySeparator +
    'nextpas' + DirectorySeparator + 'runtime' + DirectorySeparator +
    FTargetFacts.RuntimeSdkId
  );
end;

function TToolchainPlanner.ResolveDirectLinkLibraries(
  out ARuntimeRootPath: string;
  out ASharedLibraryPath: string;
  out AHasResolvedLibrary: Boolean
): Boolean;
var
  Index: LongInt;
  LibraryPath: string;
  LibraryRequest: TBackendLogicalLibraryRequest;
  RuntimeRootPath: string;
begin
  ARuntimeRootPath := '';
  ASharedLibraryPath := '';
  AHasResolvedLibrary := False;

  if FBackendPlan = nil then
    Exit(True);

  RuntimeRootPath := DistributionRuntimeRootPath;
  for Index := 0 to FBackendPlan.LogicalLibraryRequestCount - 1 do
  begin
    LibraryRequest := FBackendPlan.LogicalLibraryRequestAt(Index);
    if not SameText(LibraryRequest.LogicalId, 'c') or
      not SameText(LibraryRequest.LinkageKind, 'shared') then
    begin
      FPlan.MarkFailure(
        'toolchain.import-library-resolution-failed',
        'unsupported direct-link logical library request: logicalId=' +
        LibraryRequest.LogicalId + ' linkageKind=' + LibraryRequest.LinkageKind +
        ' strength=' + LibraryRequest.Strength + ' targetId=' +
        FTargetFacts.TargetId
      );
      Exit(False);
    end;

    LibraryPath := IncludeTrailingPathDelimiter(RuntimeRootPath) + 'libc.so';
    if not SameText(FTargetFacts.SysrootMode, 'runtime-sdk') or
      not SameText(FTargetFacts.RuntimeRootKind, 'distribution-runtime-root') or
      (RuntimeRootPath = '') or not FileExists(LibraryPath) then
    begin
      FPlan.MarkFailure(
        'toolchain.c-library-not-found',
        'logicalId=' + LibraryRequest.LogicalId + ' targetId=' +
        FTargetFacts.TargetId + ' runtimeSdkId=' + FTargetFacts.RuntimeSdkId +
        ' runtimeRootKind=' + FTargetFacts.RuntimeRootKind + ' runtimeRoot=' +
        RuntimeRootPath + ' libraryPath=' + LibraryPath
      );
      Exit(False);
    end;

    ARuntimeRootPath := RuntimeRootPath;
    ASharedLibraryPath := LibraryPath;
    AHasResolvedLibrary := True;
  end;

  Result := True;
end;

procedure TToolchainPlanner.AppendUnitSearchRoots(
  const AStepIndex: LongInt;
  const AUnitsFlag: string
);
var
  AddedRoots: TStringArray;
  CandidateRoot: string;
  Index: LongInt;
  NextIndex: SizeInt;

  procedure AddUniqueRoot(const ARootPath: string);
  var
    SearchIndex: LongInt;
  begin
    if Trim(ARootPath) = '' then
      Exit;

    CandidateRoot := ExpandFileName(ARootPath);
    for SearchIndex := 0 to Length(AddedRoots) - 1 do
      if AddedRoots[SearchIndex] = CandidateRoot then
        Exit;

    NextIndex := Length(AddedRoots);
    SetLength(AddedRoots, NextIndex + 1);
    AddedRoots[NextIndex] := CandidateRoot;
    FPlan.AddStepArg(AStepIndex, AUnitsFlag + CandidateRoot);
  end;
begin
  SetLength(AddedRoots, 0);
  AddUniqueRoot(ExtractFileDir(ExpandFileName(FSourcePath)));
  for Index := 0 to Length(FProjectUnitRoots) - 1 do
    AddUniqueRoot(FProjectUnitRoots[Index]);
  for Index := 0 to Length(FExplicitUnitRoots) - 1 do
    AddUniqueRoot(FExplicitUnitRoots[Index]);
  AddUniqueRoot(FTargetFacts.UnitsDir);
end;

function TToolchainPlanner.PrepareLlvmContract: Boolean;
var
  ExecutableSet: TLlvmExecutableSet;
begin
  if FTargetFacts.LlvmExecutableSetId = '' then
  begin
    if FTargetFacts.LlvmEnabled then
    begin
      ExecutableSet.Id := '';
      ExecutableSet.ToolRootKind := '';
      ExecutableSet.ClangDriver := '';
      ExecutableSet.Llc := '';
      ExecutableSet.Opt := '';
      ExecutableSet.Lld := '';
      ExecutableSet.LlvmAr := '';
      ExecutableSet.SuffixPolicy := '';
      ExecutableSet.VersionContract := '';
      FPlan.SetLlvmExecutableContract('failure', True, ExecutableSet);
      FPlan.MarkFailure(
        'backend.llvm-toolchain-missing',
        'missing llvm executable set id'
      );
      Exit(False);
    end;
    Result := True;
    Exit;
  end;

  if FTargetFacts.LlvmEnabled and (FTargetFacts.LlvmTriple = '') then
  begin
    ExecutableSet.Id := FTargetFacts.LlvmExecutableSetId;
    ExecutableSet.ToolRootKind := '';
    ExecutableSet.ClangDriver := '';
    ExecutableSet.Llc := '';
    ExecutableSet.Opt := '';
    ExecutableSet.Lld := '';
    ExecutableSet.LlvmAr := '';
    ExecutableSet.SuffixPolicy := '';
    ExecutableSet.VersionContract := '';
    FPlan.SetLlvmExecutableContract('failure', True, ExecutableSet);
    FPlan.MarkFailure(
      'backend.llvm-target-profile-missing',
      'missing llvm target triple'
    );
    Exit(False);
  end;

  if FTargetFacts.LlvmEnabled and (FTargetFacts.LlvmDataLayout = '') then
  begin
    ExecutableSet.Id := FTargetFacts.LlvmExecutableSetId;
    ExecutableSet.ToolRootKind := '';
    ExecutableSet.ClangDriver := '';
    ExecutableSet.Llc := '';
    ExecutableSet.Opt := '';
    ExecutableSet.Lld := '';
    ExecutableSet.LlvmAr := '';
    ExecutableSet.SuffixPolicy := '';
    ExecutableSet.VersionContract := '';
    FPlan.SetLlvmExecutableContract('failure', True, ExecutableSet);
    FPlan.MarkFailure(
      'backend.llvm-data-layout-missing',
      'missing llvm data layout'
    );
    Exit(False);
  end;

  try
    ExecutableSet := LoadLlvmExecutableSet(
      ToolProfileRootPath,
      FTargetFacts.LlvmExecutableSetId
    );
  except
    on E: EToolProfileError do
    begin
      ExecutableSet.Id := FTargetFacts.LlvmExecutableSetId;
      ExecutableSet.ToolRootKind := '';
      ExecutableSet.ClangDriver := '';
      ExecutableSet.Llc := '';
      ExecutableSet.Opt := '';
      ExecutableSet.Lld := '';
      ExecutableSet.LlvmAr := '';
      ExecutableSet.SuffixPolicy := '';
      ExecutableSet.VersionContract := '';
      FPlan.SetLlvmExecutableContract(
        'failure',
        FTargetFacts.LlvmEnabled,
        ExecutableSet
      );
      FPlan.MarkFailure('backend.llvm-toolchain-missing', E.Message);
      Exit(False);
    end;
  end;

  if FTargetFacts.LlvmEnabled then
    FPlan.SetLlvmExecutableContract('ready', True, ExecutableSet)
  else
    FPlan.SetLlvmExecutableContract('disabled', False, ExecutableSet);
  Result := True;
end;

procedure TToolchainPlanner.PreparePlanContext(
  const APlanFamily: string;
  const AToolRole: string;
  const AProfileId: string
);
begin
  FPlan.SetPlanFamily(APlanFamily);
  FPlan.SetToolProfileRoot(ToolProfileRootPath);
  FPlan.SetContext(
    AToolRole,
    AProfileId,
    FTargetFacts.ToolchainBindingId,
    FTargetFacts.HostId,
    FTargetFacts.TargetId,
    BuildSysrootRef
  );
  FPlan.ConfigureLogicalLinkRequest(
    'ready',
    FTargetFacts.ToolchainBindingId,
    FTargetFacts.TargetId,
    FTargetFacts.LinkerProfileId,
    'executable',
    PrimaryArtifactPathOrDefault
  );
end;

procedure TToolchainPlanner.AppendBackendLogicalLibraryRequests;
var
  Index: LongInt;
  LibraryRequest: TBackendLogicalLibraryRequest;
begin
  if FBackendPlan = nil then
    Exit;

  for Index := 0 to FBackendPlan.LogicalLibraryRequestCount - 1 do
  begin
    LibraryRequest := FBackendPlan.LogicalLibraryRequestAt(Index);
    FPlan.AddLogicalLibraryRequest(
      LibraryRequest.LogicalId,
      LibraryRequest.LinkageKind,
      LibraryRequest.Strength
    );
  end;
end;

procedure TToolchainPlanner.PlanFromBackend;
begin
  if (FBackendPlan = nil) or (FBackendPlan.Status <> 'ready') then
  begin
    FPlan.MarkFailure(
      'toolchain.backend-plan-missing',
      'backend plan is not ready'
    );
    Exit;
  end;

  if SameText(FBackendPlan.BackendFamily, 'llvm') then
    PlanLlvmIrOptObjectLink
  else
    PlanBootstrapNativeAssembleLink;
end;

procedure TToolchainPlanner.PlanLlvmIrOptObjectLink;
var
  ArtifactPath: string;
  BackendCacheRoot: string;
  BitcodeArtifactPath: string;
  ExecutableSet: TLlvmExecutableSet;
  HasResolvedLibrary: Boolean;
  IrArtifactPath: string;
  LinkStep: LongInt;
  LinkerProfile: TLinkerProfile;
  LlvmStep: LongInt;
  ObjectArtifactPath: string;
  OutputKindValue: string;
  PrimaryArtifactKindValue: string;
  RuntimeRootPath: string;
  SharedLibraryPath: string;
begin
  try
    LinkerProfile := LoadLinkerProfile(
      ToolProfileRootPath,
      FTargetFacts.LinkerProfileId
    );
  except
    on E: EToolProfileError do
    begin
      FPlan.MarkFailure('toolchain.profile-metadata-missing', E.Message);
      Exit;
    end;
  end;

  if not PrepareLlvmContract then
    Exit;

  try
    ExecutableSet := LoadLlvmExecutableSet(
      ToolProfileRootPath,
      FTargetFacts.LlvmExecutableSetId
    );
  except
    on E: EToolProfileError do
    begin
      FPlan.MarkFailure('backend.llvm-toolchain-missing', E.Message);
      Exit;
    end;
  end;

  ArtifactPath := PrimaryArtifactPathOrDefault;
  IrArtifactPath := FBackendPlan.ArtifactPathByKind('llvm-ir');
  BitcodeArtifactPath := FBackendPlan.ArtifactPathByKind('llvm-bitcode');
  ObjectArtifactPath := FBackendPlan.ArtifactPathByKind('object-file');
  if (IrArtifactPath = '') or (BitcodeArtifactPath = '') or
    (ObjectArtifactPath = '') then
  begin
    FPlan.MarkFailure(
      'toolchain.backend-artifact-missing',
      'backend plan is missing llvm/object artifacts'
    );
    Exit;
  end;

  BackendCacheRoot := ExtractFileDir(ExpandFileName(IrArtifactPath));
  if BackendCacheRoot = '' then
  begin
    FPlan.MarkFailure(
      'toolchain.backend-artifact-missing',
      'backend llvm ir artifact has no parent directory'
    );
    Exit;
  end;

  PreparePlanContext(
    'llvm-ir-opt-llc-link',
    'llvm-backend',
    ExecutableSet.Id
  );
  OutputKindValue := 'executable';
  if (FBackendPlan <> nil) and (FBackendPlan.OutputKind <> '') then
    OutputKindValue := FBackendPlan.OutputKind;
  FPlan.ConfigureLogicalLinkRequest(
    'ready',
    FTargetFacts.ToolchainBindingId,
    FTargetFacts.TargetId,
    LinkerProfile.Id,
    OutputKindValue,
    ArtifactPath
  );
  FPlan.AddLogicalObjectInput(ObjectArtifactPath);
  AppendBackendLogicalLibraryRequests;
  if not ResolveDirectLinkLibraries(
    RuntimeRootPath,
    SharedLibraryPath,
    HasResolvedLibrary
  ) then
    Exit;

  LlvmStep := FPlan.AddStep(
    'llvm-opt-bitcode',
    ExecutableSet.Opt,
    ExecutableSet.Opt,
    BackendCacheRoot,
    'toolchain.llvm-opt-exec-failed'
  );
  FPlan.SetStepContext(
    LlvmStep,
    'llvm-opt',
    ExecutableSet.Id,
    BuildSysrootRef
  );
  FPlan.AddStepArg(LlvmStep, '-o');
  FPlan.AddStepArg(LlvmStep, ExpandFileName(BitcodeArtifactPath));
  FPlan.AddStepArg(LlvmStep, ExpandFileName(IrArtifactPath));
  FPlan.AddStepInput(
    LlvmStep,
    'llvm-ir',
    ExpandFileName(IrArtifactPath)
  );
  FPlan.AddStepOutput(
    LlvmStep,
    'llvm-bitcode',
    ExpandFileName(BitcodeArtifactPath)
  );

  LlvmStep := FPlan.AddStep(
    'llvm-llc-object',
    ExecutableSet.Llc,
    ExecutableSet.Llc,
    BackendCacheRoot,
    'toolchain.llvm-llc-exec-failed'
  );
  FPlan.SetStepContext(
    LlvmStep,
    'llvm-codegen',
    ExecutableSet.Id,
    BuildSysrootRef
  );
  FPlan.AddStepArg(LlvmStep, '-filetype=obj');
  if FTargetFacts.LlvmTriple <> '' then
    FPlan.AddStepArg(
      LlvmStep,
      '-mtriple=' + FTargetFacts.LlvmTriple
    );
  FPlan.AddStepArg(LlvmStep, '-o');
  FPlan.AddStepArg(LlvmStep, ExpandFileName(ObjectArtifactPath));
  FPlan.AddStepArg(LlvmStep, ExpandFileName(BitcodeArtifactPath));
  FPlan.AddStepInput(
    LlvmStep,
    'llvm-bitcode',
    ExpandFileName(BitcodeArtifactPath)
  );
  FPlan.AddStepOutput(
    LlvmStep,
    'object-file',
    ExpandFileName(ObjectArtifactPath)
  );

  LinkStep := FPlan.AddStep(
    'llvm-link',
    ExecutableSet.Lld,
    ExecutableSet.Lld,
    ExtractFileDir(ExpandFileName(ArtifactPath)),
    'toolchain.linker-exec-failed'
  );
  FPlan.SetStepContext(
    LinkStep,
    'linker',
    LinkerProfile.Id,
    BuildSysrootRef
  );
  FPlan.AddStepArg(LinkStep, '-o');
  FPlan.AddStepArg(LinkStep, ExpandFileName(ArtifactPath));
  FPlan.AddStepArg(LinkStep, ExpandFileName(ObjectArtifactPath));
  if HasResolvedLibrary then
  begin
    FPlan.AddStepArg(
      LinkStep,
      LinkerProfile.LibrarySearchFlag + ExpandFileName(RuntimeRootPath)
    );
    FPlan.AddStepArg(LinkStep, '-lc');
  end;
  FPlan.AddStepInput(
    LinkStep,
    'object-file',
    ExpandFileName(ObjectArtifactPath)
  );
  if HasResolvedLibrary then
  begin
    FPlan.AddStepInput(
      LinkStep,
      'runtime-library-root',
      ExpandFileName(RuntimeRootPath)
    );
    FPlan.AddStepInput(
      LinkStep,
      'shared-library',
      ExpandFileName(SharedLibraryPath)
    );
  end;
  PrimaryArtifactKindValue := 'executable';
  if (FBackendPlan <> nil) and (FBackendPlan.PrimaryArtifactKind <> '') then
    PrimaryArtifactKindValue := FBackendPlan.PrimaryArtifactKind;
  FPlan.AddStepOutput(
    LinkStep,
    PrimaryArtifactKindValue,
    ExpandFileName(ArtifactPath)
  );
  FPlan.MarkReady;
end;

procedure TToolchainPlanner.PlanBootstrapNativeAssembleLink;
var
  AdditionalAssemblyPath: string;
  AdditionalAssembleStep: LongInt;
  AdditionalBaseName: string;
  AdditionalObjectPath: string;
  ArtifactPath: string;
  AssemblerExecutable: string;
  AssemblerProfile: TAssemblerProfile;
  AssemblyArtifactPath: string;
  BackendCacheRoot: string;
  EmitAsmStep: LongInt;
  HostCompiler: THostCompilerProfile;
  Index: LongInt;
  LinkerExecutable: string;
  LinkerProfile: TLinkerProfile;
  LinkerScriptPath: string;
  ObjectArtifactPath: string;
  OutputKindValue: string;
  PrimaryArtifactKindValue: string;
  StepIndex: LongInt;
begin
  try
    HostCompiler := LoadHostCompilerProfile(
      ToolProfileRootPath,
      FTargetFacts.HostCompilerProfileId
    );
    AssemblerProfile := LoadAssemblerProfile(
      ToolProfileRootPath,
      FTargetFacts.AssemblerProfileId
    );
    LinkerProfile := LoadLinkerProfile(
      ToolProfileRootPath,
      FTargetFacts.LinkerProfileId
    );
  except
    on E: EToolProfileError do
    begin
      FPlan.MarkFailure('toolchain.profile-metadata-missing', E.Message);
      Exit;
    end;
  end;

  if not PrepareLlvmContract then
    Exit;

  ArtifactPath := PrimaryArtifactPathOrDefault;
  AssemblyArtifactPath := FBackendPlan.ArtifactPathByKind('assembly-text');
  ObjectArtifactPath := FBackendPlan.ArtifactPathByKind('object-file');
  if (AssemblyArtifactPath = '') or (ObjectArtifactPath = '') then
  begin
    FPlan.MarkFailure(
      'toolchain.backend-artifact-missing',
      'backend plan is missing assembly/object artifacts'
    );
    Exit;
  end;

  BackendCacheRoot := ExtractFileDir(ExpandFileName(AssemblyArtifactPath));
  if BackendCacheRoot = '' then
  begin
    FPlan.MarkFailure(
      'toolchain.backend-artifact-missing',
      'backend assembly artifact has no parent directory'
    );
    Exit;
  end;

  LinkerScriptPath := IncludeTrailingPathDelimiter(BackendCacheRoot) +
    ChangeFileExt(ExtractFileName(AssemblyArtifactPath), '') + '_link.res';
  PreparePlanContext(
    'bootstrap-native-assemble-link',
    'host-compiler',
    HostCompiler.Id
  );
  OutputKindValue := 'executable';
  if (FBackendPlan <> nil) and (FBackendPlan.OutputKind <> '') then
    OutputKindValue := FBackendPlan.OutputKind;
  FPlan.ConfigureLogicalLinkRequest(
    'ready',
    FTargetFacts.ToolchainBindingId,
    FTargetFacts.TargetId,
    LinkerProfile.Id,
    OutputKindValue,
    ArtifactPath
  );
  FPlan.AddLogicalObjectInput(ObjectArtifactPath);
  AppendBackendLogicalLibraryRequests;

  EmitAsmStep := FPlan.AddStep(
    'host-fpc-emit-asm',
    FirstStringOrDefault(HostCompiler.DriverCandidates, FTargetFacts.CompilerExecutable),
    FTargetFacts.CompilerExecutable,
    BackendCacheRoot,
    'toolchain.host-compiler-exec-failed'
  );
  FPlan.AddStepArg(EmitAsmStep, '-st');
  FPlan.AddStepArg(EmitAsmStep, '-Aas');
  FPlan.AddStepArg(
    EmitAsmStep,
    '-FE' + ExpandFileName(BackendCacheRoot)
  );
  FPlan.AddStepArg(
    EmitAsmStep,
    '-FU' + ExpandFileName(BackendCacheRoot)
  );
  AppendUnitSearchRoots(EmitAsmStep, HostCompiler.UnitsFlag);
  FPlan.AddStepArg(EmitAsmStep, ExpandFileName(FSourcePath));
  FPlan.AddStepInput(
    EmitAsmStep,
    'pascal-source',
    ExpandFileName(FSourcePath)
  );
  FPlan.AddStepOutput(
    EmitAsmStep,
    'assembly-text',
    ExpandFileName(AssemblyArtifactPath)
  );
  FPlan.AddStepOutput(
    EmitAsmStep,
    'linker-script',
    ExpandFileName(LinkerScriptPath)
  );
  for Index := 0 to Length(FAdditionalAssemblyBaseNames) - 1 do
  begin
    AdditionalBaseName := ChangeFileExt(
      ExtractFileName(FAdditionalAssemblyBaseNames[Index]),
      ''
    );
    if Trim(AdditionalBaseName) = '' then
      Continue;
    if SameText(AdditionalBaseName, ChangeFileExt(ExtractFileName(FSourcePath), '')) then
      Continue;
    AdditionalAssemblyPath := IncludeTrailingPathDelimiter(BackendCacheRoot) +
      AdditionalBaseName + '.s';
    FPlan.AddStepOutput(
      EmitAsmStep,
      'assembly-text',
      ExpandFileName(AdditionalAssemblyPath)
    );
  end;

  AssemblerExecutable := FirstStringOrDefault(AssemblerProfile.DriverCandidates, 'as');
  StepIndex := FPlan.AddStep(
    'native-assemble',
    AssemblerExecutable,
    AssemblerExecutable,
    BackendCacheRoot,
    'toolchain.assembler-exec-failed'
  );
  FPlan.SetStepContext(
    StepIndex,
    'assembler',
    AssemblerProfile.Id,
    BuildSysrootRef
  );
  FPlan.AddStepArg(StepIndex, '--64');
  FPlan.AddStepArg(StepIndex, '-o');
  FPlan.AddStepArg(StepIndex, ExpandFileName(ObjectArtifactPath));
  FPlan.AddStepArg(StepIndex, ExpandFileName(AssemblyArtifactPath));
  FPlan.AddStepInput(
    StepIndex,
    'assembly-text',
    ExpandFileName(AssemblyArtifactPath)
  );
  FPlan.AddStepOutput(
    StepIndex,
    'object-file',
    ExpandFileName(ObjectArtifactPath)
  );
  for Index := 0 to Length(FAdditionalAssemblyBaseNames) - 1 do
  begin
    AdditionalBaseName := ChangeFileExt(
      ExtractFileName(FAdditionalAssemblyBaseNames[Index]),
      ''
    );
    if Trim(AdditionalBaseName) = '' then
      Continue;
    if SameText(AdditionalBaseName, ChangeFileExt(ExtractFileName(FSourcePath), '')) then
      Continue;
    AdditionalAssemblyPath := IncludeTrailingPathDelimiter(BackendCacheRoot) +
      AdditionalBaseName + '.s';
    AdditionalObjectPath := IncludeTrailingPathDelimiter(BackendCacheRoot) +
      AdditionalBaseName + '.o';
    AdditionalAssembleStep := FPlan.AddStep(
      'native-assemble-' + LowerCase(AdditionalBaseName),
      AssemblerExecutable,
      AssemblerExecutable,
      BackendCacheRoot,
      'toolchain.assembler-exec-failed'
    );
    FPlan.SetStepContext(
      AdditionalAssembleStep,
      'assembler',
      AssemblerProfile.Id,
      BuildSysrootRef
    );
    FPlan.AddStepArg(AdditionalAssembleStep, '--64');
    FPlan.AddStepArg(AdditionalAssembleStep, '-o');
    FPlan.AddStepArg(
      AdditionalAssembleStep,
      ExpandFileName(AdditionalObjectPath)
    );
    FPlan.AddStepArg(
      AdditionalAssembleStep,
      ExpandFileName(AdditionalAssemblyPath)
    );
    FPlan.AddStepInput(
      AdditionalAssembleStep,
      'assembly-text',
      ExpandFileName(AdditionalAssemblyPath)
    );
    FPlan.AddStepOutput(
      AdditionalAssembleStep,
      'object-file',
      ExpandFileName(AdditionalObjectPath)
    );
  end;

  LinkerExecutable := FirstStringOrDefault(LinkerProfile.DriverCandidates, 'ld');
  if SameText(LinkerProfile.ToolFlavor, 'gnu-ld') then
    LinkerExecutable := 'ld.bfd';
  StepIndex := FPlan.AddStep(
    'native-link',
    LinkerExecutable,
    LinkerExecutable,
    BackendCacheRoot,
    'toolchain.linker-exec-failed'
  );
  FPlan.SetStepContext(
    StepIndex,
    'linker',
    LinkerProfile.Id,
    BuildSysrootRef
  );
  FPlan.AddStepArg(StepIndex, '-b');
  FPlan.AddStepArg(StepIndex, 'elf64-x86-64');
  FPlan.AddStepArg(StepIndex, '-m');
  FPlan.AddStepArg(StepIndex, 'elf_x86_64');
  FPlan.AddStepArg(StepIndex, '-s');
  FPlan.AddStepArg(StepIndex, '-L.');
  FPlan.AddStepArg(StepIndex, '-o');
  FPlan.AddStepArg(StepIndex, ExpandFileName(ArtifactPath));
  FPlan.AddStepArg(StepIndex, '-T');
  FPlan.AddStepArg(StepIndex, ExpandFileName(LinkerScriptPath));
  FPlan.AddStepArg(StepIndex, '-e');
  FPlan.AddStepArg(StepIndex, '_start');
  FPlan.AddStepInput(
    StepIndex,
    'object-file',
    ExpandFileName(ObjectArtifactPath)
  );
  FPlan.AddStepInput(
    StepIndex,
    'linker-script',
    ExpandFileName(LinkerScriptPath)
  );
  PrimaryArtifactKindValue := 'executable';
  if (FBackendPlan <> nil) and (FBackendPlan.PrimaryArtifactKind <> '') then
    PrimaryArtifactKindValue := FBackendPlan.PrimaryArtifactKind;
  FPlan.AddStepOutput(
    StepIndex,
    PrimaryArtifactKindValue,
    ExpandFileName(ArtifactPath)
  );
  FPlan.MarkReady;
end;

procedure TToolchainPlanner.PlanBootstrapHostCompiler;
var
  ArtifactPath: string;
  HostCompiler: THostCompilerProfile;
  ObjectArtifactPath: string;
  OutputKindValue: string;
  PrimaryArtifactKindValue: string;
  OutputDirectory: string;
  ScratchRoot: string;
  StepIndex: LongInt;
begin
  try
    HostCompiler := LoadHostCompilerProfile(
      ToolProfileRootPath,
      FTargetFacts.HostCompilerProfileId
    );
  except
    on E: EToolProfileError do
    begin
      FPlan.MarkFailure('toolchain.profile-metadata-missing', E.Message);
      Exit;
    end;
  end;

  if not PrepareLlvmContract then
    Exit;

  ArtifactPath := PrimaryArtifactPathOrDefault;
  OutputDirectory := ExtractFileDir(ArtifactPath);
  ScratchRoot := HostCompilerScratchRootPath;
  PreparePlanContext(
    'bootstrap-host-compiler',
    'host-compiler',
    HostCompiler.Id
  );
  OutputKindValue := 'executable';
  if (FBackendPlan <> nil) and (FBackendPlan.OutputKind <> '') then
    OutputKindValue := FBackendPlan.OutputKind;
  FPlan.ConfigureLogicalLinkRequest(
    'ready',
    FTargetFacts.ToolchainBindingId,
    FTargetFacts.TargetId,
    FTargetFacts.LinkerProfileId,
    OutputKindValue,
    ArtifactPath
  );
  ObjectArtifactPath := '';
  if FBackendPlan <> nil then
    ObjectArtifactPath := FBackendPlan.ArtifactPathByKind('object-file');
  if ObjectArtifactPath <> '' then
    FPlan.AddLogicalObjectInput(ObjectArtifactPath);
  AppendBackendLogicalLibraryRequests;
  StepIndex := FPlan.AddStep(
    'host-fpc-compile',
    FirstStringOrDefault(HostCompiler.DriverCandidates, FTargetFacts.CompilerExecutable),
    FTargetFacts.CompilerExecutable,
    ScratchRoot,
    'toolchain.host-compiler-exec-failed'
  );
  if OutputDirectory <> '' then
    FPlan.AddStepArg(
      StepIndex,
      '-FE' + ExpandFileName(OutputDirectory)
    );
  FPlan.AddStepArg(
    StepIndex,
    '-FU' + ExpandFileName(ScratchRoot)
  );
  AppendUnitSearchRoots(StepIndex, HostCompiler.UnitsFlag);
  FPlan.AddStepArg(StepIndex, ExpandFileName(FSourcePath));
  FPlan.AddStepInput(
    StepIndex,
    'pascal-source',
    ExpandFileName(FSourcePath)
  );
  PrimaryArtifactKindValue := 'executable';
  if (FBackendPlan <> nil) and (FBackendPlan.PrimaryArtifactKind <> '') then
    PrimaryArtifactKindValue := FBackendPlan.PrimaryArtifactKind;
  FPlan.AddStepOutput(
    StepIndex,
    PrimaryArtifactKindValue,
    ArtifactPath
  );
  FPlan.MarkReady;
end;

procedure TToolchainPlanner.PlanNativeAssembleLink(
  const AAssemblyPath: string;
  const AObjectPath: string;
  const AOutputPath: string
);
var
  AssemblerProfile: TAssemblerProfile;
  HasResolvedLibrary: Boolean;
  LinkerProfile: TLinkerProfile;
  AssembleStep: LongInt;
  LinkStep: LongInt;
  ResponseFilePath: string;
  RuntimeRootPath: string;
  SharedLibraryPath: string;
begin
  try
    AssemblerProfile := LoadAssemblerProfile(
      ToolProfileRootPath,
      FTargetFacts.AssemblerProfileId
    );
    LinkerProfile := LoadLinkerProfile(
      ToolProfileRootPath,
      FTargetFacts.LinkerProfileId
    );
  except
    on E: EToolProfileError do
    begin
      FPlan.MarkFailure('toolchain.profile-metadata-missing', E.Message);
      Exit;
    end;
  end;

  if not PrepareLlvmContract then
    Exit;

  PreparePlanContext('native-assemble-link', 'native-build', LinkerProfile.Id);
  FPlan.ConfigureLogicalLinkRequest(
    'ready',
    FTargetFacts.ToolchainBindingId,
    FTargetFacts.TargetId,
    LinkerProfile.Id,
    'executable',
    AOutputPath
  );
  FPlan.AddLogicalObjectInput(AObjectPath);
  AppendBackendLogicalLibraryRequests;
  if not ResolveDirectLinkLibraries(
    RuntimeRootPath,
    SharedLibraryPath,
    HasResolvedLibrary
  ) then
    Exit;

  AssembleStep := FPlan.AddStep(
    'native-assemble',
    FirstStringOrDefault(AssemblerProfile.DriverCandidates, 'as'),
    FirstStringOrDefault(AssemblerProfile.DriverCandidates, 'as'),
    ExtractFileDir(ExpandFileName(AAssemblyPath)),
    'toolchain.assembler-exec-failed'
  );
  FPlan.SetStepContext(
    AssembleStep,
    'assembler',
    AssemblerProfile.Id,
    BuildSysrootRef
  );
  FPlan.AddStepArg(AssembleStep, '-o');
  FPlan.AddStepArg(AssembleStep, ExpandFileName(AObjectPath));
  FPlan.AddStepArg(AssembleStep, ExpandFileName(AAssemblyPath));
  FPlan.AddStepInput(AssembleStep, 'assembly-text', AAssemblyPath);
  FPlan.AddStepOutput(AssembleStep, 'object-file', AObjectPath);

  LinkStep := FPlan.AddStep(
    'native-link',
    FirstStringOrDefault(LinkerProfile.DriverCandidates, 'ld'),
    FirstStringOrDefault(LinkerProfile.DriverCandidates, 'ld'),
    ExtractFileDir(ExpandFileName(AOutputPath)),
    'toolchain.linker-exec-failed'
  );
  FPlan.SetStepContext(
    LinkStep,
    'linker',
    LinkerProfile.Id,
    BuildSysrootRef
  );
  ResponseFilePath := AOutputPath + '.rsp';
  FPlan.AddStepArg(LinkStep, '-o');
  FPlan.AddStepArg(LinkStep, ExpandFileName(AOutputPath));
  FPlan.AddStepArg(LinkStep, '@' + ResponseFilePath);
  if HasResolvedLibrary then
  begin
    FPlan.AddStepArg(
      LinkStep,
      LinkerProfile.LibrarySearchFlag + ExpandFileName(RuntimeRootPath)
    );
    FPlan.AddStepArg(LinkStep, '-lc');
  end;
  FPlan.AddStepInput(LinkStep, 'object-file', AObjectPath);
  if HasResolvedLibrary then
  begin
    FPlan.AddStepInput(
      LinkStep,
      'runtime-library-root',
      ExpandFileName(RuntimeRootPath)
    );
    FPlan.AddStepInput(
      LinkStep,
      'shared-library',
      ExpandFileName(SharedLibraryPath)
    );
  end;
  FPlan.AddStepOutput(LinkStep, 'executable', AOutputPath);
  FPlan.AddStepSidecar(
    LinkStep,
    'response-file',
    ResponseFilePath,
    'native-link',
    'before-step-exec',
    'delete-on-success'
  );
  FPlan.MarkReady;
end;

procedure TToolchainPlanner.PlanResourceCompile(
  const AResourcePath: string;
  const ABinaryResourcePath: string;
  const AObjectPath: string
);
var
  ListScriptPath: string;
  RcStep: LongInt;
  ResourceProfile: TResourceToolProfile;
  ResStep: LongInt;
begin
  try
    ResourceProfile := LoadResourceToolProfile(
      ToolProfileRootPath,
      FTargetFacts.ResourceToolProfileId
    );
  except
    on E: EToolProfileError do
    begin
      FPlan.MarkFailure('toolchain.profile-metadata-missing', E.Message);
      Exit;
    end;
  end;

  if ResourceProfile.PipelineKind = 'disabled' then
  begin
    FPlan.MarkFailure(
      'toolchain.resource-profile-disabled',
      'resource pipeline is disabled'
    );
    Exit;
  end;

  if not PrepareLlvmContract then
    Exit;

  PreparePlanContext('resource-compile', 'resource-compiler', ResourceProfile.Id);
  RcStep := FPlan.AddStep(
    'rc-to-res',
    FirstStringOrDefault(ResourceProfile.RcDriverCandidates, 'windres'),
    FirstStringOrDefault(ResourceProfile.RcDriverCandidates, 'windres'),
    ExtractFileDir(ExpandFileName(AResourcePath)),
    'toolchain.resource-exec-failed'
  );
  FPlan.AddStepArg(RcStep, '-O');
  FPlan.AddStepArg(RcStep, 'res');
  FPlan.AddStepArg(RcStep, '-o');
  FPlan.AddStepArg(RcStep, ExpandFileName(ABinaryResourcePath));
  FPlan.AddStepArg(RcStep, ExpandFileName(AResourcePath));
  FPlan.AddStepInput(RcStep, 'resource-script', AResourcePath);
  FPlan.AddStepOutput(
    RcStep,
    ResourceProfile.IntermediateAssetKind,
    ABinaryResourcePath
  );

  ResStep := FPlan.AddStep(
    'res-to-obj',
    FirstStringOrDefault(ResourceProfile.ResDriverCandidates, 'fpcres'),
    FirstStringOrDefault(ResourceProfile.ResDriverCandidates, 'fpcres'),
    ExtractFileDir(ExpandFileName(AObjectPath)),
    'toolchain.resource-exec-failed'
  );
  ListScriptPath := AObjectPath + '.reslst';
  FPlan.AddStepArg(ResStep, '@' + ListScriptPath);
  FPlan.AddStepArg(ResStep, '-o');
  FPlan.AddStepArg(ResStep, ExpandFileName(AObjectPath));
  FPlan.AddStepArg(ResStep, ExpandFileName(ABinaryResourcePath));
  FPlan.AddStepInput(ResStep, ResourceProfile.IntermediateAssetKind, ABinaryResourcePath);
  FPlan.AddStepOutput(ResStep, 'resource-object', AObjectPath);
  FPlan.AddStepSidecar(
    ResStep,
    'resource-list-script',
    ListScriptPath,
    'res-to-obj',
    'before-step-exec',
    'delete-on-success'
  );
  FPlan.MarkReady;
end;

procedure TToolchainPlanner.PlanArchiveBuild(
  const AArchivePath: string;
  const AObjectPaths: array of string
);
var
  ArchiveScriptPath: string;
  ArchiverProfile: TArchiverProfile;
  CreateStep: LongInt;
  Index: SizeInt;
  IndexStep: LongInt;
begin
  try
    ArchiverProfile := LoadArchiverProfile(
      ToolProfileRootPath,
      FTargetFacts.ArchiverProfileId
    );
  except
    on E: EToolProfileError do
    begin
      FPlan.MarkFailure('toolchain.profile-metadata-missing', E.Message);
      Exit;
    end;
  end;

  if not PrepareLlvmContract then
    Exit;

  PreparePlanContext('archive-build', 'archiver', ArchiverProfile.Id);
  CreateStep := FPlan.AddStep(
    'archive-create',
    FirstStringOrDefault(ArchiverProfile.DriverCandidates, 'ar'),
    FirstStringOrDefault(ArchiverProfile.DriverCandidates, 'ar'),
    ExtractFileDir(ExpandFileName(AArchivePath)),
    'toolchain.archiver-exec-failed'
  );
  ArchiveScriptPath := AArchivePath + '.mri';
  FPlan.AddStepArg(CreateStep, '-M');
  FPlan.AddStepArg(CreateStep, '@' + ArchiveScriptPath);
  for Index := 0 to High(AObjectPaths) do
    FPlan.AddStepInput(CreateStep, 'object-file', AObjectPaths[Index]);
  FPlan.AddStepOutput(CreateStep, 'static-library', AArchivePath);
  FPlan.AddStepSidecar(
    CreateStep,
    'archive-command-script',
    ArchiveScriptPath,
    'archive-create',
    'before-step-exec',
    'delete-on-success'
  );

  IndexStep := FPlan.AddStep(
    'archive-index',
    FirstStringOrDefault(ArchiverProfile.DriverCandidates, 'ar'),
    FirstStringOrDefault(ArchiverProfile.DriverCandidates, 'ar'),
    ExtractFileDir(ExpandFileName(AArchivePath)),
    'toolchain.archiver-exec-failed'
  );
  FPlan.AddStepArg(IndexStep, 's');
  FPlan.AddStepArg(IndexStep, ExpandFileName(AArchivePath));
  FPlan.AddStepInput(IndexStep, 'static-library', AArchivePath);
  FPlan.AddStepOutput(IndexStep, 'static-library', AArchivePath);
  FPlan.MarkReady;
end;

function TToolchainPlanner.DetachPlan: TToolchainPlan;
begin
  Result := FPlan;
  FPlan := nil;
end;

end.
