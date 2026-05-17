unit nextpas_command_build;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, nextpas_projection_types, nextpas_command_envelope,
  nextpas_projection_json, nextpas_projection_text, nextpas_projection_context,
  np_compilation_session, np_target_facts, np_workspace_model,
  np_toolchain_runner, target_config;

function TargetFactsFromConfig(const TargetConfig: TTargetConfig): TTargetFactsView;
procedure RunBuild(
  var AState: TNextPasState;
  const SourcePath: string;
  const TargetName: string;
  const ToolchainBindingOverride: string;
  const WorkspaceOverride: string;
  const UnitRootOverrides: TStringArray;
  const OutDirOverride: string;
  const NoFold: Boolean
);

implementation

uses
  nextpas_json_helpers;

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

procedure RunBuild(
  var AState: TNextPasState;
  const SourcePath: string;
  const TargetName: string;
  const ToolchainBindingOverride: string;
  const WorkspaceOverride: string;
  const UnitRootOverrides: TStringArray;
  const OutDirOverride: string;
  const NoFold: Boolean
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
        Fail(AState, 'invalid-unit-root: ' + ARawUnitRoots[Index], True);
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
      Fail(AState, AFailureKind + ': ' + ARawPath, True);

    if DirectoryExists(AResolvedPath) then
      Exit;

    if not ForceDirectories(AResolvedPath) then
      Fail(AState, AFailureKind + ': ' + ARawPath, True);
  end;

begin
  AState.BuildContext.SourcePath := SourcePath;
  AState.BuildContext.TargetName := TargetName;
  WorkspaceModel := nil;
  Session := nil;

  if not FileExists(SourcePath) then
    Fail(AState, 'missing-source: ' + SourcePath);

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
      Fail(AState, E.Message, True);
  end;
  try
    CaptureBuildCommandContext(AState, SourcePath, TargetName, WorkspaceModel);
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
        Fail(AState, E.Message);
    end;

    AState.BuildContext.TargetConfigPath := TargetConfig.ConfigPath;
    TargetFacts := TargetFactsFromConfig(TargetConfig);
    AState.BuildContext.CompilerName := TargetConfig.CompilerExecutable;
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
    Options.NoFold := NoFold;
    Options.BuildContext.ArtifactRootPath := WorkspaceModel.ArtifactRootPath;
    Options.BuildContext.OutputDirPath := WorkspaceModel.OutputDirPath;
    Session := TCompilationSession.CreateBuildSession(Options, TargetFacts);
    WorkspaceModel := nil;
    CaptureSessionContext(AState, Session);
    Session.AnalyzeSyntax;
    CaptureSessionContext(AState, Session);
    if Session.HasSyntaxErrors then
      Fail(AState, 'syntax-analysis-failed');
    Session.ResolveUnits;
    CaptureSessionContext(AState, Session);
    if Session.HasResolutionErrors then
      Fail(AState, 'unit-resolution-failed');
    Session.AnalyzeSemantics;
    CaptureSessionContext(AState, Session);
    if Session.HasSemanticErrors then
      Fail(AState, 'semantic-analysis-failed');
    Session.LowerToMir;
    CaptureSessionContext(AState, Session);
    if Session.HasMirErrors then
      Fail(AState, 'mir-lowering-failed');
    Session.PlanBackend;
    CaptureSessionContext(AState, Session);
    if Session.HasBackendErrors then
      Fail(AState, 'backend-planning-failed');
    Session.PlanToolchain;
    CaptureSessionContext(AState, Session);
    if Session.HasToolchainErrors then
      Fail(AState, 'toolchain-planning-failed');

    AState.BuildContext.CompilerName := Session.PrimaryToolLogicalExecutable;
    RunResult := Session.ExecuteToolchain(GetEnvironmentVariable('PATH'));
    try
      if RunResult.StepCount > 0 then
      begin
        FinalToolStep := RunResult.StepAt(RunResult.StepCount - 1);
        CompilerExitCode := FinalToolStep.ExitCode;
        AState.BuildContext.CompilerExitCode := FinalToolStep.ExitCode;
        AState.BuildContext.HasCompilerExitCode := FinalToolStep.HasExitCode;
      end
      else
      begin
        CompilerExitCode := 0;
        AState.BuildContext.CompilerExitCode := 0;
        AState.BuildContext.HasCompilerExitCode := False;
      end;

      CaptureSessionContext(AState, Session);
      if RunResult.Status <> 'success' then
      begin
        if Session.HasLastDiagnosticExitCode then
        begin
          AState.BuildContext.CompilerExitCode := Session.LastDiagnosticExitCode;
          AState.BuildContext.HasCompilerExitCode := True;
        end;
        if Session.LastDiagnosticCode <> '' then
          Fail(
            AState,
            Session.LastDiagnosticCode + ': ' + Session.LastDiagnosticMessage
          )
        else
          Fail(
            AState,
            Session.PrimaryToolFailureMapping + ': ' + Session.LastDiagnosticMessage
          );
      end;

      if not AState.BuildContext.HasCompilerExitCode then
      begin
        AState.BuildContext.CompilerExitCode := CompilerExitCode;
        AState.BuildContext.HasCompilerExitCode := True;
      end;
    finally
      RunResult.Free;
    end;

    if CompilerExitCode <> 0 then
    begin
      Fail(AState, Session.PrimaryToolFailureMapping + ': compiler exit code ' + IntToStr(CompilerExitCode));
    end;

    AState.BuildContext.ArtifactPath := Session.BackendPrimaryArtifactPath;
    WriteLn('mode=build');
    WriteLn('command=build');
    WriteLn('selector=build');
    WriteLn('source=', SourcePath);
    WriteLn('target=', TargetName);
    WriteLn('target-config=', TargetConfig.ConfigPath);
    WriteLn('compiler=', AState.BuildContext.CompilerName);
    WriteLn('compiler-exit=', CompilerExitCode);
    WriteLn('artifact=', AState.BuildContext.ArtifactPath);
    PrintSessionProjection(False, AState);
    WriteLn('status=success');
    WriteLn('result=success');
    WriteLn('command-outcome=success');
    WriteLn('build-result=success');
    PrintCommandEnvelope(
      AState,
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

end.
