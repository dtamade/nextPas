program test_unit_root_implicit_system;

{$mode objfpc}{$H+}

uses
  nextpas.core.base,
  nextpas.core.fs,
  nextpas.core.path,
  nextpas.core.text.conv,
  np_compilation_session,
  nextpas.compiler.targets.facts,
  np_workspace_model;

procedure Fail(const AMessage: string);
begin
  WriteLn(StdErr, 'unit-root-implicit-system-failure=', AMessage);
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
    '',
    'O2'
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
  RootPath := IncludeTrailingPathDelimiter(GetTempDir) +
    'nextpas-unit-root-implicit-system-' + IntToStr(Random(MaxInt)) + '.pas';
  RootSourceText :=
    'unit UnitRootImplicitSystem;' + LineEnding +
    LineEnding +
    'interface' + LineEnding +
    'function FirstByteOf(const AValue: UnicodeString): Byte;' + LineEnding +
    LineEnding +
    'implementation' + LineEnding +
    'function FirstByteOf(const AValue: UnicodeString): Byte;' + LineEnding +
    'begin' + LineEnding +
    '  if Length(AValue) = 0 then Exit(0);' + LineEnding +
    '  Result := PByte(@AValue[1])^;' + LineEnding +
    'end;' + LineEnding +
    LineEnding +
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
    Options.CommandName := 'query';
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
    if Session.ResolvedUnitCount <> 2 then
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
