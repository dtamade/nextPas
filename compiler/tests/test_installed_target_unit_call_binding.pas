program test_installed_target_unit_call_binding;

{$mode objfpc}{$H+}

uses
  nextpas.core.fs,
  nextpas.core.path,
  nextpas.core.text.conv,
  np_compilation_session,
  np_target_facts,
  np_workspace_model;

procedure Fail(const AMessage: string);
begin
  WriteLn(StdErr, 'installed-target-unit-call-binding-failure=', AMessage);
  Halt(1);
end;

procedure WriteTextFile(const APath: string; const AText: string);
var
  F: Text;
begin
  Assign(F, APath);
  Rewrite(F);
  try
    Write(F, AText);
  finally
    Close(F);
  end;
end;

procedure DeleteFileIfExists(const APath: string);
begin
  if FileExists(APath) then
    DeleteFile(APath);
end;

function TargetFactsWithUnitsDir(const AUnitsDir: string): TTargetFactsView;
begin
  Result := BuildTargetFactsView(
    'linux-x86_64',
    '',
    '',
    '',
    '',
    '',
    AUnitsDir,
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    False,
    '',
    '',
    '',
    '',
    False,
    ''
  );
end;

var
  ExplicitUnitRoots: TStringArray;
  Options: TCompilationOptions;
  RootPath: string;
  RootSourceText: string;
  Session: TCompilationSession;
  UnitsDir: string;
  WorkspaceModel: TWorkspaceModel;
begin
  Randomize;
  RootPath := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'nextpas-installed-target-unit-binding-' + IntToStr(Random(MaxInt)) + '.pas';
  RootSourceText :=
    'program InstalledTrimCalls;' + LineEnding +
    '{$mode objfpc}{$H+}' + LineEnding +
    'uses SysUtils;' + LineEnding +
    'begin' + LineEnding +
    '  if Trim(''  x  '') <> ''x'' then Halt(1);' + LineEnding +
    'end.' + LineEnding;
  UnitsDir := ExpandFileName('units/linux-x86_64');
  if not DirectoryExists(UnitsDir) then
    Fail('missing-units-dir:' + UnitsDir);
  WriteTextFile(RootPath, RootSourceText);

  SetLength(ExplicitUnitRoots, 0);
  WorkspaceModel := nil;
  Session := nil;
  try
    WorkspaceModel := ResolveWorkspaceModel(
      ExpandFileName(RootPath),
      ExpandFileName('.'),
      'linux-x86_64',
      ''
    );
    Options.CommandName := 'build';
    Options.BuildContext.RequestedSourcePath := RootPath;
    Options.BuildContext.ResolvedSourcePath := ExpandFileName(RootPath);
    Options.BuildContext.RequestedTargetId := 'linux-x86_64';
    Options.BuildContext.WorkspaceRootPath := WorkspaceModel.WorkspaceRootPath;
    Options.BuildContext.WorkspaceDiscoveryKind := WorkspaceModel.DiscoveryKind;
    Options.BuildContext.WorkspaceDescriptorPath :=
      WorkspaceModel.WorkspaceDescriptorPath;
    Options.BuildContext.PackageManifestPath := WorkspaceModel.PackageManifestPath;
    Options.BuildContext.ArtifactRootPath := WorkspaceModel.ArtifactRootPath;
    Options.BuildContext.OutputDirPath := WorkspaceModel.OutputDirPath;
    Options.WorkspaceModel := WorkspaceModel;
    Options.ExplicitUnitRoots := ExplicitUnitRoots;
    Options.NoFold := False;

    Session := TCompilationSession.CreateBuildSession(
      Options,
      TargetFactsWithUnitsDir(UnitsDir)
    );
    WorkspaceModel := nil;

    Session.AnalyzeSyntax;
    if Session.HasSyntaxErrors then
      Fail('unexpected-syntax-diagnostic:' + Session.LastDiagnosticCode + ':' +
        Session.LastDiagnosticMessage);
    Session.ResolveUnits;
    if Session.HasResolutionErrors then
      Fail('unexpected-resolution-diagnostic:' + Session.LastDiagnosticCode + ':' +
        Session.LastDiagnosticMessage);
    if Session.ResolvedUnitCount <> 3 then
      Fail('unexpected-resolved-unit-count:' + IntToStr(Session.ResolvedUnitCount));
    Session.AnalyzeSemantics;
    if Session.HasSemanticErrors then
      Fail('unexpected-semantic-diagnostic:' + Session.LastDiagnosticCode + ':' +
        Session.LastDiagnosticMessage);
    if Session.SemanticStatus <> 'ready' then
      Fail('unexpected-semantic-status:' + Session.SemanticStatus);
  finally
    Session.Free;
    WorkspaceModel.Free;
    DeleteFileIfExists(RootPath);
  end;
end.
