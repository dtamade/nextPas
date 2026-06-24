program test_unit_resolver_implementation_cycle;

{$mode objfpc}{$H+}

uses
  nextpas.core.fs,
  nextpas.core.path,
  nextpas.core.text.conv,
  np_ast_facade,
  np_diagnostics_sink,
  np_green_tree,
  np_lexer,
  np_package_manifest,
  np_source_database,
  np_target_facts,
  np_unit_resolver;

procedure WriteTextFile(const APath: string; const AText: string);
var
  F: Text;
begin
  ForceDirectories(ExtractFileDir(APath));
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

procedure RemoveDirIfExists(const APath: string);
begin
  if DirectoryExists(APath) then
    RmDir(APath);
end;

function EmptyTargetFacts: TTargetFactsView;
begin
  Result := BuildTargetFactsView(
    'test-target',
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
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  ExplicitUnitRoots: TStringArray;
  FfiPath: string;
  Lexer: TLexerResult;
  ProjectRoot: string;
  ProjectRoots: TProjectUnitRootInfoArray;
  Resolver: TUnitResolver;
  RootFileId: TSourceFileId;
  RootPath: string;
  SourceDatabase: TSourceDatabase;
  BasePath: string;
  Tree: TGreenTree;
begin
  Randomize;
  ProjectRoot := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'nextpas-resolver-impl-cycle-' + IntToStr(Random(MaxInt));
  RootPath := IncludeTrailingPathDelimiter(ProjectRoot) +
    'RootImplementationCycle.pas';
  BasePath := IncludeTrailingPathDelimiter(ProjectRoot) + 'BaseUnit.pas';
  FfiPath := IncludeTrailingPathDelimiter(ProjectRoot) + 'FfiUnit.pas';
  WriteTextFile(
    RootPath,
    'unit RootImplementationCycle;' + LineEnding +
    LineEnding +
    'interface' + LineEnding +
    LineEnding +
    'uses' + LineEnding +
    '  BaseUnit;' + LineEnding +
    LineEnding +
    'implementation' + LineEnding +
    LineEnding +
    'end.' + LineEnding
  );
  WriteTextFile(
    BasePath,
    'unit BaseUnit;' + LineEnding +
    LineEnding +
    'interface' + LineEnding +
    LineEnding +
    'implementation' + LineEnding +
    LineEnding +
    'uses' + LineEnding +
    '  FfiUnit;' + LineEnding +
    LineEnding +
    'end.' + LineEnding
  );
  WriteTextFile(
    FfiPath,
    'unit FfiUnit;' + LineEnding +
    LineEnding +
    'interface' + LineEnding +
    LineEnding +
    'uses' + LineEnding +
    '  BaseUnit;' + LineEnding +
    LineEnding +
    'implementation' + LineEnding +
    LineEnding +
    'end.' + LineEnding
  );

  SetLength(ProjectRoots, 0);
  SetLength(ExplicitUnitRoots, 0);
  Diagnostics := TDiagnosticsSink.CreateDefault;
  SourceDatabase := TSourceDatabase.Create;
  Lexer := nil;
  Tree := nil;
  Ast := nil;
  Resolver := nil;
  try
    RootFileId := SourceDatabase.RegisterRootSource(RootPath);
    Lexer := TLexerResult.Create(
      SourceDatabase.RootSourceText,
      Diagnostics,
      RootFileId
    );
    Tree := ParseGreenTree(Lexer, Diagnostics, RootFileId);
    Ast := TAstFacade.Create(Tree);
    Resolver := TUnitResolver.Create(
      SourceDatabase,
      EmptyTargetFacts,
      Diagnostics,
      RootFileId,
      ProjectRoots,
      ExplicitUnitRoots
    );
    Resolver.ResolveRoot(Ast);

    if Diagnostics.HasErrors then
      Halt(1);
    if Resolver.ResolutionStatus <> 'ready' then
      Halt(2);
    if Resolver.UnitGraph.ResolvedUnitCount <> 3 then
      Halt(3);
    if Resolver.UnitGraph.EdgeCount <> 4 then
      Halt(4);
  finally
    Resolver.Free;
    Ast.Free;
    Tree.Free;
    Lexer.Free;
    SourceDatabase.Free;
    Diagnostics.Free;
    DeleteFileIfExists(FfiPath);
    DeleteFileIfExists(BasePath);
    DeleteFileIfExists(RootPath);
    RemoveDirIfExists(ProjectRoot);
  end;
end.
