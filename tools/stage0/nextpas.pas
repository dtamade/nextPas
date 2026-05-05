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
  nextpas_command_envelope, nextpas_command_build,
  np_compilation_session, np_target_facts,
  np_package_workflow, np_toolchain_profiles, np_toolchain_runner,
  np_workspace_model;

var
  State: TNextPasState;

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
  if AWorkspaceOverride <> '' then
    WorkspaceRoot := ExpandFileName(AWorkspaceOverride)
  else
    WorkspaceRoot := ExpandFileName(GetCurrentDir);
  if not DirectoryExists(WorkspaceRoot) then
  begin
    if AWorkspaceOverride <> '' then
      Fail(State, 'invalid-workspace-root: ' + AWorkspaceOverride, True);
    Fail(State, 'invalid-workspace-root: ' + WorkspaceRoot, True);
  end;

  HarnessScriptPath := ExpandFileName(
    IncludeTrailingPathDelimiter(WorkspaceRoot) + 'tests' +
    DirectorySeparator + 'run_all_tests.sh'
  );
  if not FileExists(HarnessScriptPath) then
    Fail(State, 'missing-harness-script: ' + HarnessScriptPath, True);

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
      Fail(State, E.Message);
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
      Fail(State, 'invalid-workspace-root: ' + WorkspaceOverride, True);
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
      Fail(State, E.Message);
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
    Fail(State, 'missing-required-option: --workspace', True);

  WorkspaceRoot := ExpandFileName(WorkspaceOverride);
  if not DirectoryExists(WorkspaceRoot) then
    Fail(State, 'invalid-workspace-root: ' + WorkspaceOverride, True);

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
        Fail(State, E.Message);
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
    Fail(State, 'missing-source: ' + SourcePath);

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
      Fail(State, E.Message, True);
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
        Fail(State, E.Message);
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
      Fail(State, 'syntax-analysis-failed');
    Session.ResolveUnits;
    CaptureSessionContext(State, Session);
    if Session.HasResolutionErrors then
      Fail(State, 'unit-resolution-failed');
    Session.AnalyzeSemantics;
    CaptureSessionContext(State, Session);
    if Session.HasSemanticErrors then
      Fail(State, 'semantic-analysis-failed');

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
    Fail(State, 'invalid-arguments', True);

  if (ParamCount = 1) and ((ParamStr(1) = '--help') or (ParamStr(1) = '-h')) then
  begin
    PrintUsage(State.CommandName);
    Halt(ExitSuccessCode);
  end;

  CommandName := ParamStr(1);
  State.CommandName := CommandName;

  if (CommandName <> 'build') and (CommandName <> 'test') and
    (CommandName <> 'env') and (CommandName <> 'doctor') and
    (CommandName <> 'query') and (CommandName <> 'pkg') then
    Fail(State, 'unsupported-command: ' + CommandName);

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
          Fail(State, 'invalid-arguments', True);
        ListGroups := True;
      end
      else if OptionName = '--filter' then
      begin
        if ListGroups or (TestFilterName <> '') then
          Fail(State, 'invalid-arguments', True);
        if Index = ParamCount then
          Fail(State, 'invalid-arguments', True);
        Inc(Index);
        TestFilterName := ParamStr(Index);
      end
      else if OptionName = '--workspace' then
      begin
        if WorkspaceOverride <> '' then
          Fail(State, 'duplicate-option: --workspace', True);
        if Index = ParamCount then
          Fail(State, 'invalid-arguments', True);
        Inc(Index);
        WorkspaceOverride := ParamStr(Index);
      end
      else
        Fail(State, 'unknown-option: ' + OptionName, True);

      Inc(Index);
    end;

    if not ListGroups and (TestFilterName = '') then
      Fail(State, 'invalid-arguments', True);

    RunTest(ListGroups, TestFilterName, WorkspaceOverride);
  end;

  if CommandName = 'env' then
  begin
    if ParamCount < 3 then
      Fail(State, 'invalid-arguments', True);
    if ParamStr(2) <> 'status' then
      Fail(State, 'invalid-arguments', True);

    State.SelectorName := 'status';
    TargetName := '';
    ToolchainBindingOverride := '';
    Index := 3;
    while Index <= ParamCount do
    begin
      OptionName := ParamStr(Index);
      if (OptionName <> '--target') and
        (OptionName <> '--toolchain-binding') then
        Fail(State, 'unknown-option: ' + OptionName, True);
      if Index = ParamCount then
        Fail(State, 'invalid-arguments', True);
      Inc(Index);
      if OptionName = '--target' then
      begin
        if TargetName <> '' then
          Fail(State, 'duplicate-option: --target', True);
        TargetName := ParamStr(Index);
      end
      else
      begin
        if ToolchainBindingOverride <> '' then
          Fail(State, 'duplicate-option: --toolchain-binding', True);
        ToolchainBindingOverride := ParamStr(Index);
      end;
      Inc(Index);
    end;

    if TargetName = '' then
      Fail(State, 'missing-required-option: --target', True);

    RunEnvStatus(TargetName, ToolchainBindingOverride);
    Halt(ExitSuccessCode);
  end;

  if CommandName = 'doctor' then
  begin
    State.SelectorName := 'doctor';
    if ParamCount < 2 then
      Fail(State, 'invalid-arguments', True);

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
        Fail(State, 'unknown-option: ' + OptionName, True);
      if Index = ParamCount then
        Fail(State, 'invalid-arguments', True);
      Inc(Index);
      if OptionName = '--target' then
      begin
        if TargetName <> '' then
          Fail(State, 'duplicate-option: --target', True);
        TargetName := ParamStr(Index);
      end
      else if OptionName = '--toolchain-binding' then
      begin
        if ToolchainBindingOverride <> '' then
          Fail(State, 'duplicate-option: --toolchain-binding', True);
        ToolchainBindingOverride := ParamStr(Index);
      end
      else
      begin
        if WorkspaceOverride <> '' then
          Fail(State, 'duplicate-option: --workspace', True);
        WorkspaceOverride := ParamStr(Index);
      end;
      Inc(Index);
    end;

    if TargetName = '' then
      Fail(State, 'missing-required-option: --target', True);

    RunDoctor(TargetName, ToolchainBindingOverride, WorkspaceOverride);
    Halt(ExitSuccessCode);
  end;

  if CommandName = 'query' then
  begin
    State.SelectorName := 'query';
    if ParamCount < 3 then
      Fail(State, 'invalid-arguments', True);
    if ParamStr(2) <> 'symbols' then
      Fail(State, 'invalid-arguments', True);

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
        Fail(State, 'unknown-option: ' + OptionName, True);
      if Index = ParamCount then
        Fail(State, 'invalid-arguments', True);
      Inc(Index);
      if OptionName = '--target' then
      begin
        if TargetName <> '' then
          Fail(State, 'duplicate-option: --target', True);
        TargetName := ParamStr(Index);
      end
      else if OptionName = '--toolchain-binding' then
      begin
        if ToolchainBindingOverride <> '' then
          Fail(State, 'duplicate-option: --toolchain-binding', True);
        ToolchainBindingOverride := ParamStr(Index);
      end
      else
      begin
        if WorkspaceOverride <> '' then
          Fail(State, 'duplicate-option: --workspace', True);
        WorkspaceOverride := ParamStr(Index);
      end;
      Inc(Index);
    end;

    if TargetName = '' then
      Fail(State, 'missing-required-option: --target', True);

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
      Fail(State, 'invalid-arguments', True);
    if ParamStr(2) <> 'inspect' then
      Fail(State, 'invalid-arguments', True);

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
        Fail(State, 'unknown-option: ' + OptionName, True);
      if Index = ParamCount then
        Fail(State, 'invalid-arguments', True);
      Inc(Index);
      if OptionName = '--target' then
      begin
        if TargetName <> '' then
          Fail(State, 'duplicate-option: --target', True);
        TargetName := ParamStr(Index);
      end
      else if OptionName = '--toolchain-binding' then
      begin
        if ToolchainBindingOverride <> '' then
          Fail(State, 'duplicate-option: --toolchain-binding', True);
        ToolchainBindingOverride := ParamStr(Index);
      end
      else
      begin
        if WorkspaceOverride <> '' then
          Fail(State, 'duplicate-option: --workspace', True);
        WorkspaceOverride := ParamStr(Index);
      end;
      Inc(Index);
    end;

    if TargetName = '' then
      Fail(State, 'missing-required-option: --target', True);

    RunPkgInspect(TargetName, ToolchainBindingOverride, WorkspaceOverride);
    Halt(ExitSuccessCode);
  end;

  if ParamCount < 4 then
    Fail(State, 'invalid-arguments', True);

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
        Fail(State, 'invalid-arguments', True);
      Inc(Index);

      if OptionName = '--target' then
      begin
        if TargetName <> '' then
          Fail(State, 'duplicate-option: --target', True);
        TargetName := ParamStr(Index);
      end
      else if OptionName = '--toolchain-binding' then
      begin
        if ToolchainBindingOverride <> '' then
          Fail(State, 'duplicate-option: --toolchain-binding', True);
        ToolchainBindingOverride := ParamStr(Index);
      end
      else if OptionName = '--workspace' then
      begin
        if WorkspaceOverride <> '' then
          Fail(State, 'duplicate-option: --workspace', True);
        WorkspaceOverride := ParamStr(Index);
      end
      else if OptionName = '--out-dir' then
      begin
        if OutDirOverride <> '' then
          Fail(State, 'duplicate-option: --out-dir', True);
        OutDirOverride := ParamStr(Index);
      end
      else
      begin
        SetLength(UnitRootOverrides, Length(UnitRootOverrides) + 1);
        UnitRootOverrides[Length(UnitRootOverrides) - 1] := ParamStr(Index);
      end;
    end
    else
      Fail(State, 'unknown-option: ' + OptionName, True);

    Inc(Index);
  end;

  if TargetName = '' then
    Fail(State, 'missing-required-option: --target', True);

  RunBuild(
    State,
    SourcePath,
    TargetName,
    ToolchainBindingOverride,
    WorkspaceOverride,
    UnitRootOverrides,
    OutDirOverride
  );
end.
