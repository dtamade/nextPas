unit np_toolchain_runner;

{$mode objfpc}{$H+}

interface

uses
  Classes, Process, SysUtils, np_toolchain_plan;

type
  EToolchainRunnerError = class(Exception);

  TToolchainExecutedSidecar = record
    Kind: string;
    Path: string;
    OwnerStepId: string;
    MaterializationTiming: string;
    CleanupPolicy: string;
    Materialized: Boolean;
    CleanupStatus: string;
  end;

  TToolchainExecutedSidecarArray = array of TToolchainExecutedSidecar;

  TToolchainExecutedStep = record
    StepId: string;
    LogicalExecutable: string;
    ResolvedPath: string;
    Status: string;
    ExitCode: LongInt;
    HasExitCode: Boolean;
    Sidecars: TToolchainExecutedSidecarArray;
  end;

  TToolchainRunResult = class
  private
    FStatus: string;
    FFailureMapping: string;
    FFailureMessage: string;
    FSteps: array of TToolchainExecutedStep;
  public
    constructor Create;
    procedure AppendStep(
      const AStepId: string;
      const ALogicalExecutable: string;
      const AResolvedPath: string;
      const AStatus: string;
      const AHasExitCode: Boolean;
      const AExitCode: LongInt;
      const ASidecars: TToolchainExecutedSidecarArray
    );
    procedure MarkSuccess;
    procedure MarkFailure(
      const AFailureMapping: string;
      const AFailureMessage: string
    );
    function Status: string;
    function FailureMapping: string;
    function FailureMessage: string;
    function StepCount: LongInt;
    function StepAt(const AIndex: LongInt): TToolchainExecutedStep;
  end;

function ExecuteToolchainPlan(
  const APlan: TToolchainPlan;
  const AExecutableSearchPath: string
): TToolchainRunResult;

implementation

function IsAbsolutePath(const APath: string): Boolean;
begin
  if APath = '' then
    Exit(False);

  if APath[1] = DirectorySeparator then
    Exit(True);

  Result := (Length(APath) >= 2) and (APath[2] = ':');
end;

procedure EnsureDirectoryExists(
  const AResolvedPath: string;
  const AFailureKind: string
);
begin
  if Trim(AResolvedPath) = '' then
    Exit;

  if FileExists(AResolvedPath) and not DirectoryExists(AResolvedPath) then
    raise EToolchainRunnerError.Create(
      AFailureKind + ': ' + AResolvedPath
    );

  if DirectoryExists(AResolvedPath) then
    Exit;

  if not ForceDirectories(AResolvedPath) then
    raise EToolchainRunnerError.Create(
      AFailureKind + ': ' + AResolvedPath
    );
end;

procedure EnsureParentDirectory(
  const APath: string;
  const AFailureKind: string
);
var
  ParentPath: string;
begin
  ParentPath := ExtractFileDir(ExpandFileName(APath));
  if ParentPath <> '' then
    EnsureDirectoryExists(ParentPath, AFailureKind);
end;

procedure WriteTextFile(const APath: string; const AText: string);
var
  Stream: TFileStream;
begin
  EnsureParentDirectory(APath, 'toolchain.sidecar-parent-invalid');
  Stream := TFileStream.Create(APath, fmCreate);
  try
    if Length(AText) > 0 then
      Stream.WriteBuffer(AText[1], Length(AText));
  finally
    Stream.Free;
  end;
end;

function ResolveExecutablePath(
  const AStep: TToolInvocationStep;
  const AExecutableSearchPath: string
): string;
var
  SearchName: string;
begin
  SearchName := AStep.ExecutableRef;
  if SearchName = '' then
    SearchName := AStep.LogicalExecutable;

  if SearchName = '' then
    raise EToolchainRunnerError.Create(
      'toolchain.missing-logical-executable: ' + AStep.StepId
    );

  if IsAbsolutePath(SearchName) then
  begin
    Result := ExpandFileName(SearchName);
    if not FileExists(Result) then
      raise EToolchainRunnerError.Create(
        'toolchain.missing-executable: ' + SearchName
      );
    Exit;
  end;

  if AExecutableSearchPath <> '' then
    Result := FileSearch(SearchName, AExecutableSearchPath)
  else
    Result := FileSearch(SearchName, GetEnvironmentVariable('PATH'));

  if Result = '' then
    raise EToolchainRunnerError.Create(
      'toolchain.missing-executable: ' + SearchName
    );
end;

function BuildResponseFileText(const AStep: TToolInvocationStep): string;
var
  InputIndex: LongInt;
begin
  Result := '';
  for InputIndex := 0 to Length(AStep.Inputs) - 1 do
    if AStep.Inputs[InputIndex].Kind = 'object-file' then
      Result := Result + ExpandFileName(AStep.Inputs[InputIndex].Path) +
        LineEnding;
end;

function BuildResourceListScriptText(const AStep: TToolInvocationStep): string;
var
  InputIndex: LongInt;
begin
  Result := '';
  for InputIndex := 0 to Length(AStep.Inputs) - 1 do
    Result := Result + ExpandFileName(AStep.Inputs[InputIndex].Path) +
      LineEnding;
end;

function BuildArchiveCommandScriptText(const AStep: TToolInvocationStep): string;
var
  ArchivePath: string;
  InputIndex: LongInt;
begin
  ArchivePath := '';
  for InputIndex := 0 to Length(AStep.Outputs) - 1 do
    if AStep.Outputs[InputIndex].Kind = 'static-library' then
    begin
      ArchivePath := ExpandFileName(AStep.Outputs[InputIndex].Path);
      Break;
    end;

  Result := 'create ' + ArchivePath + LineEnding;
  for InputIndex := 0 to Length(AStep.Inputs) - 1 do
    if AStep.Inputs[InputIndex].Kind = 'object-file' then
      Result := Result + 'addmod ' +
        ExpandFileName(AStep.Inputs[InputIndex].Path) + LineEnding;
  Result := Result + 'save' + LineEnding + 'end' + LineEnding;
end;

function BuildSidecarText(
  const AStep: TToolInvocationStep;
  const ASidecar: TToolSidecarRef
): string;
begin
  if ASidecar.Kind = 'response-file' then
    Exit(BuildResponseFileText(AStep));

  if ASidecar.Kind = 'resource-list-script' then
    Exit(BuildResourceListScriptText(AStep));

  if ASidecar.Kind = 'archive-command-script' then
    Exit(BuildArchiveCommandScriptText(AStep));

  raise EToolchainRunnerError.Create(
    'toolchain.unsupported-sidecar-kind: ' + ASidecar.Kind
  );
end;

function BuildExecutedSidecars(
  const AStep: TToolInvocationStep
): TToolchainExecutedSidecarArray;
var
  SidecarIndex: LongInt;
begin
  Result := nil;
  SetLength(Result, Length(AStep.Sidecars));
  for SidecarIndex := 0 to Length(AStep.Sidecars) - 1 do
  begin
    Result[SidecarIndex].Kind := AStep.Sidecars[SidecarIndex].Kind;
    Result[SidecarIndex].Path := AStep.Sidecars[SidecarIndex].Path;
    Result[SidecarIndex].OwnerStepId := AStep.Sidecars[SidecarIndex].OwnerStepId;
    Result[SidecarIndex].MaterializationTiming :=
      AStep.Sidecars[SidecarIndex].MaterializationTiming;
    Result[SidecarIndex].CleanupPolicy := AStep.Sidecars[SidecarIndex].CleanupPolicy;
    Result[SidecarIndex].Materialized := False;
    Result[SidecarIndex].CleanupStatus := 'not-requested';
  end;
end;

procedure MaterializeSidecars(
  const AStep: TToolInvocationStep;
  var AExecutedSidecars: TToolchainExecutedSidecarArray
);
var
  SidecarIndex: LongInt;
begin
  for SidecarIndex := 0 to Length(AStep.Sidecars) - 1 do
    if AStep.Sidecars[SidecarIndex].MaterializationTiming = 'before-step-exec' then
    begin
      WriteTextFile(
        AStep.Sidecars[SidecarIndex].Path,
        BuildSidecarText(AStep, AStep.Sidecars[SidecarIndex])
      );
      AExecutedSidecars[SidecarIndex].Materialized := True;
    end;
end;

procedure FinalizeUncleanedSidecars(
  var AExecutedSidecars: TToolchainExecutedSidecarArray
);
var
  SidecarIndex: LongInt;
begin
  for SidecarIndex := 0 to Length(AExecutedSidecars) - 1 do
    if AExecutedSidecars[SidecarIndex].Materialized then
      AExecutedSidecars[SidecarIndex].CleanupStatus := 'retained';
end;

procedure CleanupSidecars(
  var AExecutedSidecars: TToolchainExecutedSidecarArray
);
var
  SidecarIndex: LongInt;
  SidecarPath: string;
begin
  for SidecarIndex := 0 to Length(AExecutedSidecars) - 1 do
  begin
    if not AExecutedSidecars[SidecarIndex].Materialized then
      Continue;

    if AExecutedSidecars[SidecarIndex].CleanupPolicy = 'delete-on-success' then
    begin
      SidecarPath := ExpandFileName(AExecutedSidecars[SidecarIndex].Path);
      DeleteFile(SidecarPath);
      if FileExists(SidecarPath) then
        AExecutedSidecars[SidecarIndex].CleanupStatus := 'retained'
      else
        AExecutedSidecars[SidecarIndex].CleanupStatus := 'deleted';
    end
    else
      AExecutedSidecars[SidecarIndex].CleanupStatus := 'retained';
  end;
end;

procedure EnsureStepDirectories(const AStep: TToolInvocationStep);
var
  OutputIndex: LongInt;
  SidecarIndex: LongInt;
begin
  if AStep.WorkingDirectory <> '' then
    EnsureDirectoryExists(
      ExpandFileName(AStep.WorkingDirectory),
      'toolchain.invalid-working-directory'
    );

  for OutputIndex := 0 to Length(AStep.Outputs) - 1 do
    EnsureParentDirectory(
      AStep.Outputs[OutputIndex].Path,
      'toolchain.invalid-output-directory'
    );

  for SidecarIndex := 0 to Length(AStep.Sidecars) - 1 do
    EnsureParentDirectory(
      AStep.Sidecars[SidecarIndex].Path,
      'toolchain.invalid-sidecar-directory'
    );
end;

function ExecuteStep(
  const AStep: TToolInvocationStep;
  const AResolvedPath: string
): LongInt;
var
  ArgIndex: LongInt;
  Proc: TProcess;
begin
  Proc := TProcess.Create(nil);
  try
    Proc.Executable := AResolvedPath;
    if AStep.WorkingDirectory <> '' then
      Proc.CurrentDirectory := ExpandFileName(AStep.WorkingDirectory);
    Proc.Options := [poWaitOnExit];
    for ArgIndex := 0 to Length(AStep.Argv) - 1 do
      Proc.Parameters.Add(AStep.Argv[ArgIndex]);
    Proc.Execute;
    Result := Proc.ExitStatus;
  finally
    Proc.Free;
  end;
end;

constructor TToolchainRunResult.Create;
begin
  inherited Create;
  FStatus := 'deferred';
  FFailureMapping := '';
  FFailureMessage := '';
  SetLength(FSteps, 0);
end;

procedure TToolchainRunResult.AppendStep(
  const AStepId: string;
  const ALogicalExecutable: string;
  const AResolvedPath: string;
  const AStatus: string;
  const AHasExitCode: Boolean;
  const AExitCode: LongInt;
  const ASidecars: TToolchainExecutedSidecarArray
);
var
  NextIndex: SizeInt;
begin
  NextIndex := Length(FSteps);
  SetLength(FSteps, NextIndex + 1);
  FSteps[NextIndex].StepId := AStepId;
  FSteps[NextIndex].LogicalExecutable := ALogicalExecutable;
  FSteps[NextIndex].ResolvedPath := AResolvedPath;
  FSteps[NextIndex].Status := AStatus;
  FSteps[NextIndex].HasExitCode := AHasExitCode;
  FSteps[NextIndex].ExitCode := AExitCode;
  FSteps[NextIndex].Sidecars := ASidecars;
end;

procedure TToolchainRunResult.MarkSuccess;
begin
  FStatus := 'success';
end;

procedure TToolchainRunResult.MarkFailure(
  const AFailureMapping: string;
  const AFailureMessage: string
);
begin
  FStatus := 'failure';
  FFailureMapping := AFailureMapping;
  FFailureMessage := AFailureMessage;
end;

function TToolchainRunResult.Status: string;
begin
  Result := FStatus;
end;

function TToolchainRunResult.FailureMapping: string;
begin
  Result := FFailureMapping;
end;

function TToolchainRunResult.FailureMessage: string;
begin
  Result := FFailureMessage;
end;

function TToolchainRunResult.StepCount: LongInt;
begin
  Result := Length(FSteps);
end;

function TToolchainRunResult.StepAt(
  const AIndex: LongInt
): TToolchainExecutedStep;
begin
  if (AIndex < 0) or (AIndex > High(FSteps)) then
  begin
    Result.StepId := '';
    Result.LogicalExecutable := '';
    Result.ResolvedPath := '';
    Result.Status := '';
    Result.ExitCode := 0;
    Result.HasExitCode := False;
    SetLength(Result.Sidecars, 0);
    Exit;
  end;

  Result := FSteps[AIndex];
end;

function ExecuteToolchainPlan(
  const APlan: TToolchainPlan;
  const AExecutableSearchPath: string
): TToolchainRunResult;
var
  ExecutedSidecars: TToolchainExecutedSidecarArray;
  ExitCodeValue: LongInt;
  ResolvedPath: string;
  Step: TToolInvocationStep;
  StepIndex: LongInt;
begin
  Result := TToolchainRunResult.Create;
  if (APlan = nil) or (APlan.Status <> 'ready') then
  begin
    Result.MarkFailure(
      'toolchain.plan-not-ready',
      'toolchain plan is not ready'
    );
    Exit;
  end;

  for StepIndex := 0 to APlan.ToolInvocationCount - 1 do
  begin
    Step := APlan.StepAt(StepIndex);
    ExecutedSidecars := BuildExecutedSidecars(Step);
    ResolvedPath := '';
    try
      EnsureStepDirectories(Step);
      MaterializeSidecars(Step, ExecutedSidecars);
      ResolvedPath := ResolveExecutablePath(Step, AExecutableSearchPath);
      ExitCodeValue := ExecuteStep(Step, ResolvedPath);
    except
      on E: Exception do
      begin
        FinalizeUncleanedSidecars(ExecutedSidecars);
        Result.AppendStep(
          Step.StepId,
          Step.LogicalExecutable,
          ResolvedPath,
          'failed',
          False,
          0,
          ExecutedSidecars
        );
        Result.MarkFailure(Step.FailureMapping, E.Message);
        Exit;
      end;
    end;

    if ExitCodeValue <> 0 then
    begin
      FinalizeUncleanedSidecars(ExecutedSidecars);
      Result.AppendStep(
        Step.StepId,
        Step.LogicalExecutable,
        ResolvedPath,
        'failed',
        True,
        ExitCodeValue,
        ExecutedSidecars
      );
      Result.MarkFailure(
        Step.FailureMapping,
        'exit code ' + IntToStr(ExitCodeValue)
      );
      Exit;
    end;

    CleanupSidecars(ExecutedSidecars);
    Result.AppendStep(
      Step.StepId,
      Step.LogicalExecutable,
      ResolvedPath,
      'success',
      True,
      ExitCodeValue,
      ExecutedSidecars
    );
  end;

  Result.MarkSuccess;
end;

end.
