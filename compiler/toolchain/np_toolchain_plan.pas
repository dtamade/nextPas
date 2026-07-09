unit np_toolchain_plan;

{$mode objfpc}{$H+}
{$UNITPATH ../backend}
{$UNITPATH ../targets}
{$UNITPATH ../diagnostics}

interface

uses
  nextpas.core.text, nextpas.core.text.conv, nextpas.core.path,
  nextpas.core.fs.util, nextpas.core.os.env,
  np_backend_plan, np_target_facts, np_toolchain_profiles,
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
    function FindRuntimeLibrary(const ATargetId: string): string;
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

{$I np_toolchain_plan_json.inc}

constructor TToolchainPlanner.Create(
  const ABackendPlan: TBackendPlan;
  const ATargetFacts: TTargetFactsView;
  const ASourcePath: string
);
begin
  inherited Create;
  FBackendPlan := ABackendPlan;
  FTargetFacts := ATargetFacts;
  FSourcePath := ASourcePath;
  FArtifactRootPath := '';
  SetLength(FProjectUnitRoots, 0);
  SetLength(FExplicitUnitRoots, 0);
  SetLength(FAdditionalAssemblyBaseNames, 0);
  FPlan := TToolchainPlan.Create;
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

function TToolchainPlanner.FindRuntimeLibrary(const ATargetId: string): string;
var
  EnvDir: string;
  RepoRoot: string;
  Candidate: string;
begin
  Result := '';
  // 1. 环境变量 NEXTPAS_RUNTIME_DIR
  EnvDir := GetEnvironmentVariable('NEXTPAS_RUNTIME_DIR');
  if EnvDir <> '' then
  begin
    Candidate := IncludeTrailingPathDelimiter(EnvDir) +
      'libnprt.a';
    if FsExists(Candidate) then
      Exit(Candidate);
  end;
  // 2. 项目根目录 build/runtime/<target>/
  RepoRoot := RepoRootPath;
  if RepoRoot <> '' then
  begin
    Candidate := IncludeTrailingPathDelimiter(RepoRoot) + 'build' +
      DirectorySeparator + 'runtime' + DirectorySeparator +
      ATargetId + DirectorySeparator + 'libnprt.a';
    if FsExists(Candidate) then
      Exit(Candidate);
  end;
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
    if not nextpas.core.text.SameText(LibraryRequest.LogicalId, 'c') or
      not nextpas.core.text.SameText(LibraryRequest.LinkageKind, 'shared') then
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
    if not nextpas.core.text.SameText(FTargetFacts.SysrootMode, 'runtime-sdk') or
      not nextpas.core.text.SameText(FTargetFacts.RuntimeRootKind, 'distribution-runtime-root') or
      (RuntimeRootPath = '') or not FsExists(LibraryPath) then
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
  { Skip FTargetFacts.UnitsDir: FPC should use its own RTL units (System,
    SysUtils, BaseUnix, etc.) instead of the bridge stubs in the runtime
    SDK directory. The stubs are only needed for nextpas resolution. }
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

  if nextpas.core.text.SameText(FBackendPlan.BackendFamily, 'llvm') then
    PlanLlvmIrOptObjectLink
  else
    PlanBootstrapNativeAssembleLink;
end;

{$I np_toolchain_plan_llvm.inc}

{$I np_toolchain_plan_bootstrap.inc}

{$I np_toolchain_plan_host.inc}

function TToolchainPlanner.DetachPlan: TToolchainPlan;
begin
  Result := FPlan;
  FPlan := nil;
end;

end.
