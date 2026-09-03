unit nextpas.compiler.toolchain.runner;

{$mode objfpc}{$H+}
{$UNITPATH ../../core/src}

interface

uses
  nextpas.core.base,
  nextpas.core.process,
  nextpas.core.time.base,
  nextpas.core.async.cancellation,
  nextpas.core.text.conv, nextpas.core.path, nextpas.core.fs, nextpas.core.fs.util,
  nextpas.core.fs.dir, nextpas.core.fs.base,
  nextpas.core.exception,
  nextpas.core.collections.vec,
  nextpas.compiler.toolchain.plan;

type
  EToolchainRunnerError = class(ENextPasError)
  end;

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

  TToolchainExecutedStepVec = specialize TVec<TToolchainExecutedStep>;

  TToolchainRunResult = class
  private
    FStatus: string;
    FFailureMapping: string;
    FFailureMessage: string;
    FSteps: TToolchainExecutedStepVec;
  public
    constructor Create;
    destructor Destroy; override;
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

type
  TToolchainExecuteOptions = record
    Timeout: TDuration;
    MaxOutput: Int64;
    CancelToken: IAsyncCancellationToken;
    Deadline: TInstant;
    HasDeadline: Boolean;
  end;

function DefaultToolchainExecuteOptions: TToolchainExecuteOptions;

function ExecuteToolchainPlan(
  const APlan: TToolchainPlan;
  const AExecutableSearchPath: string
): TToolchainRunResult; overload;

function ExecuteToolchainPlan(
  const APlan: TToolchainPlan;
  const AExecutableSearchPath: string;
  const ADeadline: TInstant
): TToolchainRunResult; overload;

function ExecuteToolchainPlan(
  const APlan: TToolchainPlan;
  const AExecutableSearchPath: string;
  const AOptions: TToolchainExecuteOptions
): TToolchainRunResult; overload;

function ExecuteStep(
  const AStep: TToolInvocationStep;
  const AResolvedPath: string;
  const ATimeout: TDuration;
  const AMaxOutput: Int64;
  const ACancelToken: IAsyncCancellationToken
): TProcessOutput; overload;

implementation

{$I np_toolchain_runner_helpers.inc}
      if FsExists(SidecarPath) then
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
    EnsureFsIsDir(
      ExpandFileName(AStep.WorkingDirectory),
      'toolchain.invalid-working-directory'
    );

  if AStep.Outputs <> nil then
    for OutputIndex := 0 to LongInt(AStep.Outputs.Count) - 1 do
      EnsureParentDirectory(
        AStep.Outputs[SizeUInt(OutputIndex)].Path,
        'toolchain.invalid-output-directory'
      );

  if AStep.Sidecars <> nil then
    for SidecarIndex := 0 to LongInt(AStep.Sidecars.Count) - 1 do
      EnsureParentDirectory(
        AStep.Sidecars[SizeUInt(SidecarIndex)].Path,
        'toolchain.invalid-sidecar-directory'
      );
end;

procedure FsRemovesMatching(
  const ADirectory: string;
  const APattern: string
);
var
  CandidatePath: string;
  DirectoryPath: string;
  Entries: TDirEntryArray;
  I: LongInt;
  LSuffix: string;
begin
  if Trim(ADirectory) = '' then
    Exit;

  DirectoryPath := IncludeTrailingPathDelimiter(ExpandFileName(ADirectory));
  if not FsIsDir(DirectoryPath) then
    Exit;

  // APattern is like '*.o' or '*_link.res' — match by suffix after '*'
  if (Length(APattern) < 2) or (APattern[1] <> '*') then
    Exit;
  LSuffix := Copy(APattern, 2, MaxInt);

  Entries := FsReadDir(DirectoryPath);
  for I := 0 to High(Entries) do
  begin
    if Entries[I].IsDir then
      Continue;
    if (Length(Entries[I].Name) >= Length(LSuffix)) and
       SameText(Copy(Entries[I].Name, Length(Entries[I].Name) - Length(LSuffix) + 1,
         Length(LSuffix)), LSuffix) then
    begin
      CandidatePath := DirectoryPath + Entries[I].Name;
      FsRemove(CandidatePath);
    end;
  end;
end;

procedure CleanHostCompilerScratchOutputs(const AStep: TToolInvocationStep);
begin
  if not SameText(AStep.ToolRole, 'host-compiler') then
    Exit;

  FsRemovesMatching(AStep.WorkingDirectory, '*.ppu');
  FsRemovesMatching(AStep.WorkingDirectory, '*.o');
  FsRemovesMatching(AStep.WorkingDirectory, '*.s');
  FsRemovesMatching(AStep.WorkingDirectory, '*_link.res');
  FsRemovesMatching(AStep.WorkingDirectory, '*_ppas.sh');
end;

function CanSkipAssemblerStep(const AStep: TToolInvocationStep): Boolean;
var
  InputIndex: LongInt;
begin
  Result := False;
  if not SameText(AStep.ToolRole, 'assembler') then
    Exit;
  // Allow native-assemble to be skipped when input .s is missing
  // (e.g. facade units with empty implementation)

  if AStep.Inputs <> nil then
    for InputIndex := 0 to LongInt(AStep.Inputs.Count) - 1 do
      if SameText(AStep.Inputs[SizeUInt(InputIndex)].Kind, 'assembly-text') and
        (not FsExists(ExpandFileName(AStep.Inputs[SizeUInt(InputIndex)].Path))) then
        Exit(True);
end;

function DefaultToolchainExecuteOptions: TToolchainExecuteOptions;
begin
  Result.Timeout := TDuration.Zero;
  Result.MaxOutput := cProcessDefaultMaxOutput;
  Result.CancelToken := nil;
  Result.Deadline := Default(TInstant);
  Result.HasDeadline := False;
end;

function ExecuteStep(
  const AStep: TToolInvocationStep;
  const AResolvedPath: string;
  const ATimeout: TDuration;
  const AMaxOutput: Int64;
  const ACancelToken: IAsyncCancellationToken
): TProcessOutput;
var
  Args: TStringArray;
  Cmd: ICommand;
  EffectiveMaxOutput: Int64;
begin
  Args := ToolchainArgvAsArray(AStep.Argv);
  EffectiveMaxOutput := AMaxOutput;
  if EffectiveMaxOutput = 0 then
    EffectiveMaxOutput := cProcessDefaultMaxOutput;
  Cmd := Command(AResolvedPath).Args(Args).MaxOutput(EffectiveMaxOutput);
  if not ATimeout.IsZero then
    Cmd := Cmd.Timeout(ATimeout);
  if ACancelToken <> nil then
    Cmd := Cmd.CancelToken(ACancelToken);
  if AStep.WorkingDirectory <> '' then
    Cmd := Cmd.Dir(ExpandFileName(AStep.WorkingDirectory));
  Result := Cmd.Output;
end;

function ExecuteStep(
  const AStep: TToolInvocationStep;
  const AResolvedPath: string
): LongInt;
var
  LOut: TProcessOutput;
begin
  LOut := ExecuteStep(AStep, AResolvedPath, TDuration.Zero, cProcessDefaultMaxOutput, nil);
  if LOut.TimedOut then
    raise EToolchainRunnerError.Create('toolchain.step-timeout: ' + AStep.StepId);
  if LOut.Cancelled then
    raise EToolchainRunnerError.Create('toolchain.step-cancelled: ' + AStep.StepId);
  if LOut.OutputLimited then
    raise EToolchainRunnerError.Create('toolchain.step-output-limited: ' + AStep.StepId);
  Result := LOut.ExitCode;
end;

constructor TToolchainRunResult.Create;
begin
  inherited Create;
  FStatus := 'deferred';
  FFailureMapping := '';
  FFailureMessage := '';
  FSteps := TToolchainExecutedStepVec.Create;
end;

destructor TToolchainRunResult.Destroy;
begin
  FSteps.Free;
  FSteps := nil;
  inherited Destroy;
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
  Step: TToolchainExecutedStep;
begin
  if FSteps = nil then
    FSteps := TToolchainExecutedStepVec.Create;
  Step := Default(TToolchainExecutedStep);
  Step.StepId := AStepId;
  Step.LogicalExecutable := ALogicalExecutable;
  Step.ResolvedPath := AResolvedPath;
  Step.Status := AStatus;
  Step.HasExitCode := AHasExitCode;
  Step.ExitCode := AExitCode;
  Step.Sidecars := ASidecars;
  FSteps.Push(Step);
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
  if FSteps = nil then
    Exit(0);
  Result := LongInt(FSteps.Count);
end;

function TToolchainRunResult.StepAt(
  const AIndex: LongInt
): TToolchainExecutedStep;
begin
  if (FSteps = nil) or (AIndex < 0) or (AIndex >= LongInt(FSteps.Count)) then
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

  Result := FSteps[SizeUInt(AIndex)];
end;

function ExecuteToolchainPlanWithOptions(
  const APlan: TToolchainPlan;
  const AExecutableSearchPath: string;
  const AOptions: TToolchainExecuteOptions
): TToolchainRunResult; forward;

function ExecuteToolchainPlan(
  const APlan: TToolchainPlan;
  const AExecutableSearchPath: string
): TToolchainRunResult;
begin
  Result := ExecuteToolchainPlanWithOptions(APlan, AExecutableSearchPath, DefaultToolchainExecuteOptions);
end;

function ExecuteToolchainPlan(
  const APlan: TToolchainPlan;
  const AExecutableSearchPath: string;
  const ADeadline: TInstant
): TToolchainRunResult;
var
  Opts: TToolchainExecuteOptions;
begin
  Opts := DefaultToolchainExecuteOptions;
  Opts.Deadline := ADeadline;
  Opts.HasDeadline := True;
  Result := ExecuteToolchainPlanWithOptions(APlan, AExecutableSearchPath, Opts);
end;

function ExecuteToolchainPlan(
  const APlan: TToolchainPlan;
  const AExecutableSearchPath: string;
  const AOptions: TToolchainExecuteOptions
): TToolchainRunResult;
begin
  Result := ExecuteToolchainPlanWithOptions(APlan, AExecutableSearchPath, AOptions);
end;

function ExecuteToolchainPlanWithOptions(
  const APlan: TToolchainPlan;
  const AExecutableSearchPath: string;
  const AOptions: TToolchainExecuteOptions
): TToolchainRunResult;
var
  ExecutedSidecars: TToolchainExecutedSidecarArray;
  ExitCodeValue: LongInt;
  ResolvedPath: string;
  Step: TToolInvocationStep;
  StepIndex: LongInt;
  EffectiveTimeout: TDuration;
  Remaining: TDuration;
  StepOutput: TProcessOutput;
  HasOutput: Boolean;
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
    ExitCodeValue := 0;
    HasOutput := False;
    FillChar(StepOutput, SizeOf(StepOutput), 0);
    try
      if AOptions.HasDeadline then
      begin
        Remaining := AOptions.Deadline.DurationSince(TInstant.Now);
        if Remaining.IsNegative or Remaining.IsZero then
        begin
          FinalizeUncleanedSidecars(ExecutedSidecars);
          Result.AppendStep(
            Step.StepId,
            Step.LogicalExecutable,
            '',
            'failed',
            False,
            0,
            ExecutedSidecars
          );
          Result.MarkFailure('toolchain.deadline-exceeded', 'toolchain deadline exceeded before step ' + Step.StepId);
          Exit;
        end;
      end;
      if (AOptions.CancelToken <> nil) and AOptions.CancelToken.IsCancelled then
      begin
        FinalizeUncleanedSidecars(ExecutedSidecars);
        Result.AppendStep(
          Step.StepId,
          Step.LogicalExecutable,
          '',
          'failed',
          False,
          0,
          ExecutedSidecars
        );
        Result.MarkFailure('toolchain.cancelled', 'toolchain cancelled before step ' + Step.StepId);
        Exit;
      end;
      EnsureStepDirectories(Step);
      CleanHostCompilerScratchOutputs(Step);
      MaterializeSidecars(Step, ExecutedSidecars);
      if CanSkipAssemblerStep(Step) then
      begin
        CleanupSidecars(ExecutedSidecars);
        Result.AppendStep(
          Step.StepId,
          Step.LogicalExecutable,
          '',
          'success',
          False,
          0,
          ExecutedSidecars
        );
        Continue;
      end;
      ResolvedPath := ResolveExecutablePath(Step, AExecutableSearchPath);
      EffectiveTimeout := AOptions.Timeout;
      if AOptions.HasDeadline then
      begin
        Remaining := AOptions.Deadline.DurationSince(TInstant.Now);
        if Remaining.IsNegative or Remaining.IsZero then
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
          Result.MarkFailure('toolchain.deadline-exceeded', 'toolchain deadline exceeded for step ' + Step.StepId);
          Exit;
        end;
        if EffectiveTimeout.IsZero or (Remaining < EffectiveTimeout) then
          EffectiveTimeout := Remaining;
      end;
      StepOutput := ExecuteStep(Step, ResolvedPath, EffectiveTimeout, AOptions.MaxOutput, AOptions.CancelToken);
      HasOutput := True;
      if StepOutput.Cancelled then
      begin
        FinalizeUncleanedSidecars(ExecutedSidecars);
        Result.AppendStep(
          Step.StepId,
          Step.LogicalExecutable,
          ResolvedPath,
          'failed',
          True,
          StepOutput.ExitCode,
          ExecutedSidecars
        );
        Result.MarkFailure(Step.FailureMapping, 'toolchain cancelled: ' + Step.StepId);
        Exit;
      end;
      if StepOutput.TimedOut then
      begin
        FinalizeUncleanedSidecars(ExecutedSidecars);
        Result.AppendStep(
          Step.StepId,
          Step.LogicalExecutable,
          ResolvedPath,
          'failed',
          True,
          StepOutput.ExitCode,
          ExecutedSidecars
        );
        Result.MarkFailure(Step.FailureMapping, 'toolchain timeout: ' + Step.StepId);
        Exit;
      end;
      if StepOutput.OutputLimited then
      begin
        FinalizeUncleanedSidecars(ExecutedSidecars);
        Result.AppendStep(
          Step.StepId,
          Step.LogicalExecutable,
          ResolvedPath,
          'failed',
          True,
          StepOutput.ExitCode,
          ExecutedSidecars
        );
        Result.MarkFailure(Step.FailureMapping, 'toolchain output limited: ' + Step.StepId);
        Exit;
      end;
      ExitCodeValue := StepOutput.ExitCode;
    except
      on E: Exception do
      begin
        FinalizeUncleanedSidecars(ExecutedSidecars);
        if HasOutput then
          Result.AppendStep(
            Step.StepId,
            Step.LogicalExecutable,
            ResolvedPath,
            'failed',
            True,
            StepOutput.ExitCode,
            ExecutedSidecars
          )
        else
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
