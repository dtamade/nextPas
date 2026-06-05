program test_semantic_reexported_type_member_call;

{$mode objfpc}{$H+}

uses
  SysUtils,
  np_ast_facade,
  np_diagnostics_sink,
  np_green_tree,
  np_lexer,
  np_semantic_analyzer,
  np_semantic_model,
  np_unit_graph;

procedure Fail(const AMessage: string);
begin
  WriteLn(StdErr, 'semantic-reexported-type-member-call-failure=', AMessage);
  Halt(1);
end;

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

function SymbolIdByNameKindAndOwner(
  const AModel: TSemanticModel;
  const AName: string;
  const AKind: string;
  const AOwnerUnitId: string
): LongInt;
var
  Index: LongInt;
  Symbol: TSemanticSymbol;
begin
  Result := 0;
  for Index := 0 to AModel.SymbolCount - 1 do
  begin
    Symbol := AModel.SymbolAt(Index);
    if SameText(Symbol.Name, AName) and SameText(Symbol.Kind, AKind) and
      SameText(Symbol.OwnerUnitId, AOwnerUnitId) then
      Exit(Symbol.SymbolId);
  end;
end;

procedure WriteWorkerSysAndAliasUnits(
  const ASourcePath: string;
  const AErrorsPath: string
);
begin
  WriteTextFile(
    ASourcePath,
    'unit WorkerSys;' + LineEnding +
    LineEnding +
    'interface' + LineEnding +
    'type' + LineEnding +
    '  Exception = class' + LineEnding +
    '  public' + LineEnding +
    '    class function Make(AValue: Integer): Exception;' + LineEnding +
    '  end;' + LineEnding +
    LineEnding +
    'implementation' + LineEnding +
    'class function Exception.Make(AValue: Integer): Exception;' + LineEnding +
    'begin' + LineEnding +
    '  Make := nil;' + LineEnding +
    'end;' + LineEnding +
    LineEnding +
    'end.' + LineEnding
  );
  WriteTextFile(
    AErrorsPath,
    'unit ErrorsAlias;' + LineEnding +
    LineEnding +
    'interface' + LineEnding +
    'uses WorkerSys;' + LineEnding +
    'type' + LineEnding +
    '  Exception = WorkerSys.Exception;' + LineEnding +
    LineEnding +
    'implementation' + LineEnding +
    LineEnding +
    'end.' + LineEnding
  );
end;

procedure WriteRaiseWorkerSysAndAliasUnits(
  const ASourcePath: string;
  const AErrorsPath: string
);
begin
  WriteTextFile(
    ASourcePath,
    'unit WorkerSys;' + LineEnding +
    LineEnding +
    'interface' + LineEnding +
    'type' + LineEnding +
    '  Exception = class' + LineEnding +
    '  public' + LineEnding +
    '    constructor CreateFmt(const Msg: string; const Args: array of const);' +
      LineEnding +
    '  end;' + LineEnding +
    LineEnding +
    'implementation' + LineEnding +
    'constructor Exception.CreateFmt(const Msg: string; const Args: array of const);' +
      LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    LineEnding +
    'end.' + LineEnding
  );
  WriteTextFile(
    AErrorsPath,
    'unit ErrorsAlias;' + LineEnding +
    LineEnding +
    'interface' + LineEnding +
    'uses WorkerSys;' + LineEnding +
    'type' + LineEnding +
    '  Exception = WorkerSys.Exception;' + LineEnding +
    LineEnding +
    'implementation' + LineEnding +
    LineEnding +
    'end.' + LineEnding
  );
end;

function BuildRootModel(
  const ARootSourceText: string;
  const ARootName: string;
  const AResolvedUnits: array of TResolvedUnit;
  out ADiagnostics: TDiagnosticsSink;
  out AAnalyzer: TSemanticAnalyzer;
  out AAst: TAstFacade;
  out ATree: TGreenTree;
  out ALexer: TLexerResult;
  out AUnitGraph: TUnitGraph
): TSemanticModel;
var
  Index: LongInt;
begin
  Result := nil;
  ADiagnostics := TDiagnosticsSink.CreateDefault;
  ALexer := TLexerResult.Create(ARootSourceText, ADiagnostics, 1);
  ATree := ParseGreenTree(ALexer, ADiagnostics, 1);
  AAst := TAstFacade.Create(ATree);
  AUnitGraph := TUnitGraph.Create;
  AUnitGraph.SetRootName(ARootName);
  for Index := Low(AResolvedUnits) to High(AResolvedUnits) do
    AUnitGraph.AddResolvedUnit(AResolvedUnits[Index]);
  AAnalyzer := TSemanticAnalyzer.Create(AAst, AUnitGraph, ADiagnostics, 1, True);
  AAnalyzer.Analyze;
  Result := AAnalyzer.DetachModel;
end;

procedure CheckSingleMemberBinding(
  const AModel: TSemanticModel;
  const ABindingName: string;
  const AExpectedOwnerUnitId: string;
  const AExpectedTargetSymbolId: LongInt;
  const AExpectedOffset: LongInt;
  const AFailurePrefix: string
);
var
  Binding: TSemanticBinding;
  BindingCount: LongInt;
  Index: LongInt;
begin
  BindingCount := 0;
  for Index := 0 to AModel.BindingCount - 1 do
  begin
    Binding := AModel.BindingAt(Index);
    if SameText(Binding.Kind, 'member-call') and
      SameText(Binding.Name, ABindingName) then
    begin
      Inc(BindingCount);
      if Binding.TargetSymbolId <> AExpectedTargetSymbolId then
        Fail(AFailurePrefix + '-target-mismatch');
      if not SameText(Binding.OwnerUnitId, AExpectedOwnerUnitId) then
        Fail(AFailurePrefix + '-owner-mismatch:' + Binding.OwnerUnitId);
      if Binding.ByteOffset <> AExpectedOffset then
        Fail(AFailurePrefix + '-offset-mismatch:' + IntToStr(Binding.ByteOffset));
    end;
  end;
  if BindingCount = 0 then
    Fail('missing-' + AFailurePrefix + '-binding');
  if BindingCount <> 1 then
    Fail('unexpected-' + AFailurePrefix + '-binding-count:' +
      IntToStr(BindingCount));
end;

procedure CheckRootTypeReceiverMemberCallBinding;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  ErrorsPath: string;
  Lexer: TLexerResult;
  MethodSymbolId: LongInt;
  Model: TSemanticModel;
  ProjectRoot: string;
  RootSourceText: string;
  SourcePath: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
begin
  Randomize;
  ProjectRoot := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'nextpas-sema-reexported-type-member-root-' + IntToStr(Random(MaxInt));
  SourcePath := ProjectRoot + DirectorySeparator + 'workersys.pas';
  ErrorsPath := ProjectRoot + DirectorySeparator + 'errorsalias.pas';
  RootSourceText :=
    'program ReexportedTypeMemberCalls;' + LineEnding +
    'uses ErrorsAlias;' + LineEnding +
    'begin' + LineEnding +
    '  Exception.Make(1);' + LineEnding +
    'end.' + LineEnding;
  WriteWorkerSysAndAliasUnits(SourcePath, ErrorsPath);

  Diagnostics := nil;
  Lexer := nil;
  Tree := nil;
  Ast := nil;
  UnitGraph := nil;
  Analyzer := nil;
  Model := nil;
  try
    Model := BuildRootModel(
      RootSourceText,
      'ReexportedTypeMemberCalls',
      [
        BuildResolvedUnit('ReexportedTypeMemberCalls', '', ruoRootSource, '', 'program', 1),
        BuildResolvedUnit('ErrorsAlias', ErrorsPath, ruoProjectSource, '', 'unit', 2),
        BuildResolvedUnit('WorkerSys', SourcePath, ruoProjectSource, '', 'unit', 3)
      ],
      Diagnostics,
      Analyzer,
      Ast,
      Tree,
      Lexer,
      UnitGraph
    );

    if Diagnostics.HasErrors then
      Fail('unexpected-root-diagnostic:' + Diagnostics.LastDiagnosticCode + ':' +
        Diagnostics.LastDiagnosticMessage);
    if Model = nil then
      Fail('missing-root-semantic-model');
    if not SameText(Model.Status, 'ready') then
      Fail('unexpected-root-model-status:' + Model.Status);

    MethodSymbolId := SymbolIdByNameKindAndOwner(
      Model,
      'Exception.Make',
      'method',
      'workersys'
    );
    if MethodSymbolId <= 0 then
      Fail('missing-root-workersys-exception-make-symbol');

    CheckSingleMemberBinding(
      Model,
      'Make',
      'reexportedtypemembercalls',
      MethodSymbolId,
      Pos('Make(1)', RootSourceText) - 1,
      'root-member-call'
    );
  finally
    Model.Free;
    Analyzer.Free;
    UnitGraph.Free;
    Ast.Free;
    Tree.Free;
    Lexer.Free;
    Diagnostics.Free;
    DeleteFileIfExists(ErrorsPath);
    DeleteFileIfExists(SourcePath);
    RemoveDirIfExists(ProjectRoot);
  end;
end;

procedure CheckImportedUnitBodyTypeReceiverMemberCallBinding;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  ErrorsPath: string;
  HolderPath: string;
  HolderSourceText: string;
  Lexer: TLexerResult;
  MethodSymbolId: LongInt;
  Model: TSemanticModel;
  ProjectRoot: string;
  RootSourceText: string;
  SourcePath: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
begin
  Randomize;
  ProjectRoot := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'nextpas-sema-reexported-type-member-imported-body-' +
    IntToStr(Random(MaxInt));
  SourcePath := ProjectRoot + DirectorySeparator + 'workersys.pas';
  ErrorsPath := ProjectRoot + DirectorySeparator + 'errorsalias.pas';
  HolderPath := ProjectRoot + DirectorySeparator + 'holderunit.pas';
  RootSourceText :=
    'program ReexportedTypeMemberCalls;' + LineEnding +
    'uses HolderUnit;' + LineEnding +
    'begin' + LineEnding +
    'end.' + LineEnding;
  HolderSourceText :=
    'unit HolderUnit;' + LineEnding +
    LineEnding +
    'interface' + LineEnding +
    'uses ErrorsAlias;' + LineEnding +
    'type' + LineEnding +
    '  THolder = class' + LineEnding +
    '  public' + LineEnding +
    '    class procedure Probe;' + LineEnding +
    '  end;' + LineEnding +
    LineEnding +
    'implementation' + LineEnding +
    'class procedure THolder.Probe;' + LineEnding +
    'begin' + LineEnding +
    '  Exception.Make(1);' + LineEnding +
    'end;' + LineEnding +
    LineEnding +
    'end.' + LineEnding;
  WriteWorkerSysAndAliasUnits(SourcePath, ErrorsPath);
  WriteTextFile(HolderPath, HolderSourceText);

  Diagnostics := nil;
  Lexer := nil;
  Tree := nil;
  Ast := nil;
  UnitGraph := nil;
  Analyzer := nil;
  Model := nil;
  try
    Model := BuildRootModel(
      RootSourceText,
      'ReexportedTypeMemberCalls',
      [
        BuildResolvedUnit('ReexportedTypeMemberCalls', '', ruoRootSource, '', 'program', 1),
        BuildResolvedUnit('HolderUnit', HolderPath, ruoProjectSource, '', 'unit', 2),
        BuildResolvedUnit('ErrorsAlias', ErrorsPath, ruoProjectSource, '', 'unit', 3),
        BuildResolvedUnit('WorkerSys', SourcePath, ruoProjectSource, '', 'unit', 4)
      ],
      Diagnostics,
      Analyzer,
      Ast,
      Tree,
      Lexer,
      UnitGraph
    );

    if Diagnostics.HasErrors then
      Fail('unexpected-imported-body-diagnostic:' + Diagnostics.LastDiagnosticCode +
        ':' + Diagnostics.LastDiagnosticMessage);
    if Model = nil then
      Fail('missing-imported-body-semantic-model');
    if not SameText(Model.Status, 'ready') then
      Fail('unexpected-imported-body-model-status:' + Model.Status);

    MethodSymbolId := SymbolIdByNameKindAndOwner(
      Model,
      'Exception.Make',
      'method',
      'workersys'
    );
    if MethodSymbolId <= 0 then
      Fail('missing-imported-body-workersys-exception-make-symbol');

    CheckSingleMemberBinding(
      Model,
      'Make',
      'holderunit',
      MethodSymbolId,
      Pos('Make(1)', HolderSourceText) - 1,
      'imported-body-member-call'
    );
  finally
    Model.Free;
    Analyzer.Free;
    UnitGraph.Free;
    Ast.Free;
    Tree.Free;
    Lexer.Free;
    Diagnostics.Free;
    DeleteFileIfExists(HolderPath);
    DeleteFileIfExists(ErrorsPath);
    DeleteFileIfExists(SourcePath);
    RemoveDirIfExists(ProjectRoot);
  end;
end;

procedure CheckImportedUnitBodyRaiseConstructorMemberCallBinding;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  ErrorsPath: string;
  HolderPath: string;
  HolderSourceText: string;
  Lexer: TLexerResult;
  MethodSymbolId: LongInt;
  Model: TSemanticModel;
  ProjectRoot: string;
  RootSourceText: string;
  SourcePath: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
begin
  Randomize;
  ProjectRoot := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'nextpas-sema-reexported-type-member-raise-' + IntToStr(Random(MaxInt));
  SourcePath := ProjectRoot + DirectorySeparator + 'workersys.pas';
  ErrorsPath := ProjectRoot + DirectorySeparator + 'errorsalias.pas';
  HolderPath := ProjectRoot + DirectorySeparator + 'holderunit.pas';
  RootSourceText :=
    'program ReexportedTypeMemberCalls;' + LineEnding +
    'uses HolderUnit;' + LineEnding +
    'begin' + LineEnding +
    'end.' + LineEnding;
  HolderSourceText :=
    'unit HolderUnit;' + LineEnding +
    LineEnding +
    'interface' + LineEnding +
    'uses ErrorsAlias;' + LineEnding +
    'type' + LineEnding +
    '  THolder = class' + LineEnding +
    '  public' + LineEnding +
    '    class procedure Probe;' + LineEnding +
    '  end;' + LineEnding +
    LineEnding +
    'implementation' + LineEnding +
    'class procedure THolder.Probe;' + LineEnding +
    'begin' + LineEnding +
    '  raise Exception.CreateFmt(''' + 'value=%d' + ''', [1]);' + LineEnding +
    'end;' + LineEnding +
    LineEnding +
    'end.' + LineEnding;
  WriteRaiseWorkerSysAndAliasUnits(SourcePath, ErrorsPath);
  WriteTextFile(HolderPath, HolderSourceText);

  Diagnostics := nil;
  Lexer := nil;
  Tree := nil;
  Ast := nil;
  UnitGraph := nil;
  Analyzer := nil;
  Model := nil;
  try
    Model := BuildRootModel(
      RootSourceText,
      'ReexportedTypeMemberCalls',
      [
        BuildResolvedUnit('ReexportedTypeMemberCalls', '', ruoRootSource, '', 'program', 1),
        BuildResolvedUnit('HolderUnit', HolderPath, ruoProjectSource, '', 'unit', 2),
        BuildResolvedUnit('ErrorsAlias', ErrorsPath, ruoProjectSource, '', 'unit', 3),
        BuildResolvedUnit('WorkerSys', SourcePath, ruoProjectSource, '', 'unit', 4)
      ],
      Diagnostics,
      Analyzer,
      Ast,
      Tree,
      Lexer,
      UnitGraph
    );

    if Diagnostics.HasErrors then
      Fail('unexpected-imported-raise-diagnostic:' +
        Diagnostics.LastDiagnosticCode + ':' +
        Diagnostics.LastDiagnosticMessage);
    if Model = nil then
      Fail('missing-imported-raise-semantic-model');
    if not SameText(Model.Status, 'ready') then
      Fail('unexpected-imported-raise-model-status:' + Model.Status);

    MethodSymbolId := SymbolIdByNameKindAndOwner(
      Model,
      'Exception.CreateFmt',
      'constructor',
      'workersys'
    );
    if MethodSymbolId <= 0 then
      MethodSymbolId := SymbolIdByNameKindAndOwner(
        Model,
        'Exception.CreateFmt',
        'method',
        'workersys'
      );
    if MethodSymbolId <= 0 then
      Fail('missing-imported-raise-createfmt-symbol');

    CheckSingleMemberBinding(
      Model,
      'CreateFmt',
      'holderunit',
      MethodSymbolId,
      Pos('CreateFmt(''' + 'value=%d' + ''', [1])', HolderSourceText) - 1,
      'imported-raise-member-call'
    );
  finally
    Model.Free;
    Analyzer.Free;
    UnitGraph.Free;
    Ast.Free;
    Tree.Free;
    Lexer.Free;
    Diagnostics.Free;
    DeleteFileIfExists(HolderPath);
    DeleteFileIfExists(ErrorsPath);
    DeleteFileIfExists(SourcePath);
    RemoveDirIfExists(ProjectRoot);
  end;
end;

begin
  CheckRootTypeReceiverMemberCallBinding;
  CheckImportedUnitBodyTypeReceiverMemberCallBinding;
  CheckImportedUnitBodyRaiseConstructorMemberCallBinding;
end.
