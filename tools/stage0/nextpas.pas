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
  nextpas_projection_json, nextpas_projection_text, nextpas_projection_context,
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
  PrintSessionProjection(True, State);
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
  PrintBuildContextProjection(False, State.BuildContext);
  PrintToolchainProjectionFields(False, State.ToolchainProjection);
  PrintEnvironmentProjectionFields(False, State.EnvironmentProjection);
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
  PrintBuildContextProjection(False, State.BuildContext);
  PrintToolchainProjectionFields(False, State.ToolchainProjection);
  PrintEnvironmentProjectionFields(False, State.EnvironmentProjection);
  PrintDoctorProjectionFields(False, State.DoctorProjection);
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
    CaptureBuildCommandContext(State, '', TargetName, WorkspaceModel);

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
    PrintBuildContextProjection(False, State.BuildContext);
    PrintToolchainProjectionFields(False, State.ToolchainProjection);
    PrintPackageProjectionFields(False, State.PackageProjection);
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
    CaptureBuildCommandContext(State, SourcePath, TargetName, WorkspaceModel);
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
    CaptureSessionContext(State, Session);
    Session.AnalyzeSyntax;
    CaptureSessionContext(State, Session);
    if Session.HasSyntaxErrors then
      Fail('syntax-analysis-failed');
    Session.ResolveUnits;
    CaptureSessionContext(State, Session);
    if Session.HasResolutionErrors then
      Fail('unit-resolution-failed');
    Session.AnalyzeSemantics;
    CaptureSessionContext(State, Session);
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
    PrintSessionProjection(False, State);
    PrintQueryProjectionFields(False, State.QueryProjection);
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
    CaptureBuildCommandContext(State, SourcePath, TargetName, WorkspaceModel);
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
    CaptureSessionContext(State, Session);
    Session.AnalyzeSyntax;
    CaptureSessionContext(State, Session);
    if Session.HasSyntaxErrors then
      Fail('syntax-analysis-failed');
    Session.ResolveUnits;
    CaptureSessionContext(State, Session);
    if Session.HasResolutionErrors then
      Fail('unit-resolution-failed');
    Session.AnalyzeSemantics;
    CaptureSessionContext(State, Session);
    if Session.HasSemanticErrors then
      Fail('semantic-analysis-failed');
    Session.LowerToMir;
    CaptureSessionContext(State, Session);
    if Session.HasMirErrors then
      Fail('mir-lowering-failed');
    Session.PlanBackend;
    CaptureSessionContext(State, Session);
    if Session.HasBackendErrors then
      Fail('backend-planning-failed');
    Session.PlanToolchain;
    CaptureSessionContext(State, Session);
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

      CaptureSessionContext(State, Session);
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
    PrintSessionProjection(False, State);
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
  ClearBuildCommandContext(State);
  ClearSessionContext(State);

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
