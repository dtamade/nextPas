unit nextpas_command_query;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, nextpas_projection_types, nextpas_command_envelope,
  nextpas_command_build, nextpas_projection_json, nextpas_projection_text,
  nextpas_projection_context,
  np_compilation_session, np_target_facts, np_workspace_model,
  target_config;

procedure RunQuerySymbols(
  var AState: TNextPasState;
  const SourcePath: string;
  const TargetName: string;
  const ToolchainBindingOverride: string;
  const WorkspaceOverride: string
);

implementation

procedure RunQuerySymbols(
  var AState: TNextPasState;
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
      ''
    );
  except
    on E: Exception do
      Fail(AState, E.Message, True);
  end;

  try
    CaptureBuildCommandContext(AState, SourcePath, TargetName, WorkspaceModel);
    SetLength(ResolvedUnitRoots, 0);

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
    AState.BuildContext.CompilerName := TargetConfig.CompilerExecutable;
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

    AState.QueryProjection.Kind := 'symbols';
    AState.QueryProjection.Status := 'success';
    AState.QueryProjection.AnalysisSource := 'compilation-session';
    AState.QueryProjection.ResultCount := Session.SymbolCount;
    AState.QueryProjection.HasResultCount := True;
    AState.QueryProjection.SymbolsJson := Session.SymbolsJson;
    AState.QueryProjection.ScopesJson := Session.ScopesJson;
    AState.QueryProjection.TypesJson := Session.TypesJson;

    WriteLn('mode=query');
    WriteLn('command=query');
    WriteLn('selector=symbols');
    WriteLn('source=', SourcePath);
    WriteLn('target=', TargetName);
    WriteLn('target-config=', TargetConfig.ConfigPath);
    WriteLn('compiler=', TargetConfig.CompilerExecutable);
    PrintSessionProjection(False, AState);
    PrintQueryProjectionFields(False, AState.QueryProjection);
    WriteLn('status=success');
    WriteLn('result=success');
    WriteLn('command-outcome=success');
    PrintCommandEnvelope(
      AState,
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

end.
