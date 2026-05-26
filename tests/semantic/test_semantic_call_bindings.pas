program test_semantic_call_bindings;

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
  WriteLn(StdErr, 'semantic-call-bindings-failure=', AMessage);
  Halt(1);
end;

function SymbolIdByNameAndKind(
  const AModel: TSemanticModel;
  const AName: string;
  const AKind: string
): LongInt;
var
  Index: LongInt;
  Symbol: TSemanticSymbol;
begin
  Result := 0;
  for Index := 0 to AModel.SymbolCount - 1 do
  begin
    Symbol := AModel.SymbolAt(Index);
    if SameText(Symbol.Name, AName) and SameText(Symbol.Kind, AKind) then
      Exit(Symbol.SymbolId);
  end;
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

function BindingTargetForName(
  const AModel: TSemanticModel;
  const AName: string
): LongInt;
var
  Binding: TSemanticBinding;
  Index: LongInt;
begin
  Result := 0;
  for Index := 0 to AModel.BindingCount - 1 do
  begin
    Binding := AModel.BindingAt(Index);
    if SameText(Binding.Kind, 'call') and SameText(Binding.Name, AName) then
      Exit(Binding.TargetSymbolId);
  end;
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

function SymbolOwnerUnitById(
  const AModel: TSemanticModel;
  const ASymbolId: LongInt
): string;
var
  Index: LongInt;
  Symbol: TSemanticSymbol;
begin
  Result := '';
  for Index := 0 to AModel.SymbolCount - 1 do
  begin
    Symbol := AModel.SymbolAt(Index);
    if Symbol.SymbolId = ASymbolId then
      Exit(Symbol.OwnerUnitId);
  end;
end;

procedure CheckImportedUnitCallBinding;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Binding: TSemanticBinding;
  BindingTarget: LongInt;
  Diagnostics: TDiagnosticsSink;
  Index: LongInt;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  ProjectRoot: string;
  RootSourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
  UnitPath: string;
begin
  ProjectRoot := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'nextpas-semantic-imported-call-' + IntToStr(Random(MaxInt));
  UnitPath := ProjectRoot + DirectorySeparator + 'helper.pas';
  RootSourceText :=
    'program ImportedCalls;' + LineEnding +
    'uses Helper;' + LineEnding +
    'type' + LineEnding +
    '  THolder = record' + LineEnding +
    '    Help: Integer;' + LineEnding +
    '  end;' + LineEnding +
    'var' + LineEnding +
    '  Holder: THolder;' + LineEnding +
    'begin' + LineEnding +
    '  Help;' + LineEnding +
    '  Holder.Help := 1;' + LineEnding +
    '  Holder.Help;' + LineEnding +
    '  Holder.Help();' + LineEnding +
    'end.' + LineEnding;
  WriteTextFile(
    UnitPath,
    'unit Helper;' + LineEnding +
    LineEnding +
    'interface' + LineEnding +
    'procedure Help;' + LineEnding +
    LineEnding +
    'implementation' + LineEnding +
    'procedure Help;' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    LineEnding +
    'end.' + LineEnding
  );

  Diagnostics := TDiagnosticsSink.CreateDefault;
  Lexer := TLexerResult.Create(RootSourceText, Diagnostics, 1);
  Tree := ParseGreenTree(Lexer, Diagnostics, 1);
  Ast := TAstFacade.Create(Tree);
  UnitGraph := TUnitGraph.Create;
  Analyzer := nil;
  Model := nil;
  try
    UnitGraph.SetRootName(Ast.DeclaredName);
    UnitGraph.AddResolvedUnit(
      BuildResolvedUnit('ImportedCalls', '', ruoRootSource, '', 'program', 1)
    );
    UnitGraph.AddResolvedUnit(
      BuildResolvedUnit('Helper', UnitPath, ruoProjectSource, '', 'unit', 2)
    );
    Analyzer := TSemanticAnalyzer.Create(Ast, UnitGraph, Diagnostics, 1, True);
    Analyzer.Analyze;
    Model := Analyzer.DetachModel;
    if Diagnostics.HasErrors then
      Fail('unexpected-imported-call-diagnostics');
    if Model = nil then
      Fail('missing-imported-call-semantic-model');
    if Model.BindingCount <> 1 then
      Fail('unexpected-imported-call-binding-count:' +
        IntToStr(Model.BindingCount));

    BindingTarget := 0;
    for Index := 0 to Model.BindingCount - 1 do
    begin
      Binding := Model.BindingAt(Index);
      if SameText(Binding.Kind, 'call') and
        SameText(Binding.Name, 'Help') then
      begin
        if BindingTarget <> 0 then
          Fail('duplicate-imported-call-binding');
        BindingTarget := Binding.TargetSymbolId;
      end;
    end;

    if BindingTarget <= 0 then
      Fail('missing-imported-call-binding');
    if not SameText(SymbolOwnerUnitById(Model, BindingTarget), 'helper') then
      Fail('imported-call-binding-target-owner-mismatch');
  finally
    Model.Free;
    Analyzer.Free;
    UnitGraph.Free;
    Ast.Free;
    Tree.Free;
    Lexer.Free;
    Diagnostics.Free;
  end;
end;

procedure CheckImportedClassMemberCallBinding;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Binding: TSemanticBinding;
  BindingCount: LongInt;
  Diagnostics: TDiagnosticsSink;
  Index: LongInt;
  Lexer: TLexerResult;
  MethodSymbolId: LongInt;
  Model: TSemanticModel;
  ProjectRoot: string;
  RootSourceText: string;
  Tree: TGreenTree;
  TypeSymbolId: LongInt;
  UnitGraph: TUnitGraph;
  UnitPath: string;
begin
  ProjectRoot := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'nextpas-semantic-imported-member-call-' + IntToStr(Random(MaxInt));
  UnitPath := ProjectRoot + DirectorySeparator + 'worker.pas';
  RootSourceText :=
    'program ImportedMemberCalls;' + LineEnding +
    'uses Worker;' + LineEnding +
    'var' + LineEnding +
    '  Worker: TWorker;' + LineEnding +
    'begin' + LineEnding +
    '  Halt(Worker.Add(1, 2));' + LineEnding +
    'end.' + LineEnding;
  WriteTextFile(
    UnitPath,
    'unit Worker;' + LineEnding +
    LineEnding +
    'interface' + LineEnding +
    'type' + LineEnding +
    '  TWorker = class' + LineEnding +
    '    function Add(A, B: Integer): Integer;' + LineEnding +
    '  end;' + LineEnding +
    LineEnding +
    'implementation' + LineEnding +
    'function TWorker.Add(A, B: Integer): Integer;' + LineEnding +
    'begin' + LineEnding +
    '  Add := A + B;' + LineEnding +
    'end;' + LineEnding +
    LineEnding +
    'end.' + LineEnding
  );

  Diagnostics := TDiagnosticsSink.CreateDefault;
  Lexer := TLexerResult.Create(RootSourceText, Diagnostics, 1);
  Tree := ParseGreenTree(Lexer, Diagnostics, 1);
  Ast := TAstFacade.Create(Tree);
  UnitGraph := TUnitGraph.Create;
  Analyzer := nil;
  Model := nil;
  try
    UnitGraph.SetRootName(Ast.DeclaredName);
    UnitGraph.AddResolvedUnit(
      BuildResolvedUnit('ImportedMemberCalls', '', ruoRootSource, '', 'program', 1)
    );
    UnitGraph.AddResolvedUnit(
      BuildResolvedUnit('Worker', UnitPath, ruoProjectSource, '', 'unit', 2)
    );
    Analyzer := TSemanticAnalyzer.Create(Ast, UnitGraph, Diagnostics, 1, True);
    Analyzer.Analyze;
    Model := Analyzer.DetachModel;
    if Diagnostics.HasErrors then
      Fail('unexpected-imported-member-call-diagnostics');
    if Model = nil then
      Fail('missing-imported-member-call-semantic-model');

    TypeSymbolId := SymbolIdByNameAndKind(Model, 'TWorker', 'type');
    if TypeSymbolId <= 0 then
      Fail('missing-imported-member-call-type-symbol');
    if not SameText(SymbolOwnerUnitById(Model, TypeSymbolId), 'worker') then
      Fail('imported-member-call-type-owner-mismatch');

    MethodSymbolId := SymbolIdByNameAndKind(Model, 'TWorker.Add', 'method');
    if MethodSymbolId <= 0 then
      Fail('missing-imported-member-call-method-symbol');
    if not SameText(SymbolOwnerUnitById(Model, MethodSymbolId), 'worker') then
      Fail('imported-member-call-method-owner-mismatch');

    BindingCount := 0;
    for Index := 0 to Model.BindingCount - 1 do
    begin
      Binding := Model.BindingAt(Index);
      if SameText(Binding.Kind, 'member-call') and
        SameText(Binding.Name, 'Add') then
      begin
        Inc(BindingCount);
        if Binding.TargetSymbolId <> MethodSymbolId then
          Fail('imported-member-call-target-mismatch');
        if Binding.ByteOffset <> Pos('Add(1, 2)', RootSourceText) - 1 then
          Fail('imported-member-call-offset-mismatch:' +
            IntToStr(Binding.ByteOffset));
      end;
    end;
    if BindingCount = 0 then
      Fail('missing-imported-member-call-binding');
    if BindingCount <> 1 then
      Fail('unexpected-imported-member-call-binding-count:' +
        IntToStr(BindingCount));
  finally
    Model.Free;
    Analyzer.Free;
    UnitGraph.Free;
    Ast.Free;
    Tree.Free;
    Lexer.Free;
    Diagnostics.Free;
  end;
end;

procedure CheckOwnerAwareImportedClassMemberCallBinding;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Binding: TSemanticBinding;
  BindingCount: LongInt;
  Diagnostics: TDiagnosticsSink;
  ImportedMethodSymbolId: LongInt;
  Index: LongInt;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  ProjectRoot: string;
  RootMethodSymbolId: LongInt;
  RootSourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
  UnitPath: string;
begin
  ProjectRoot := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'nextpas-semantic-owner-aware-member-call-' + IntToStr(Random(MaxInt));
  UnitPath := ProjectRoot + DirectorySeparator + 'worker.pas';
  RootSourceText :=
    'program OwnerAwareMemberCalls;' + LineEnding +
    'uses Worker;' + LineEnding +
    'type' + LineEnding +
    '  TWorker = class' + LineEnding +
    '    function Add(A, B: Integer): Integer;' + LineEnding +
    '  end;' + LineEnding +
    'function TWorker.Add(A, B: Integer): Integer;' + LineEnding +
    'begin' + LineEnding +
    '  Add := A + B;' + LineEnding +
    'end;' + LineEnding +
    'var' + LineEnding +
    '  Worker: TWorker;' + LineEnding +
    'begin' + LineEnding +
    '  Halt(Worker.Add(1, 2));' + LineEnding +
    'end.' + LineEnding;
  WriteTextFile(
    UnitPath,
    'unit Worker;' + LineEnding +
    LineEnding +
    'interface' + LineEnding +
    'type' + LineEnding +
    '  TWorker = class' + LineEnding +
    '    function Add(A, B: Integer): Integer;' + LineEnding +
    '  end;' + LineEnding +
    LineEnding +
    'implementation' + LineEnding +
    'function TWorker.Add(A, B: Integer): Integer;' + LineEnding +
    'begin' + LineEnding +
    '  Add := A - B;' + LineEnding +
    'end;' + LineEnding +
    LineEnding +
    'end.' + LineEnding
  );

  Diagnostics := TDiagnosticsSink.CreateDefault;
  Lexer := TLexerResult.Create(RootSourceText, Diagnostics, 1);
  Tree := ParseGreenTree(Lexer, Diagnostics, 1);
  Ast := TAstFacade.Create(Tree);
  UnitGraph := TUnitGraph.Create;
  Analyzer := nil;
  Model := nil;
  try
    UnitGraph.SetRootName(Ast.DeclaredName);
    UnitGraph.AddResolvedUnit(
      BuildResolvedUnit('OwnerAwareMemberCalls', '', ruoRootSource, '', 'program', 1)
    );
    UnitGraph.AddResolvedUnit(
      BuildResolvedUnit('Worker', UnitPath, ruoProjectSource, '', 'unit', 2)
    );
    Analyzer := TSemanticAnalyzer.Create(Ast, UnitGraph, Diagnostics, 1, True);
    Analyzer.Analyze;
    Model := Analyzer.DetachModel;
    if Diagnostics.HasErrors then
      Fail('unexpected-owner-aware-member-call-diagnostics');
    if Model = nil then
      Fail('missing-owner-aware-member-call-semantic-model');

    RootMethodSymbolId := SymbolIdByNameKindAndOwner(
      Model,
      'TWorker.Add',
      'method',
      'ownerawaremembercalls'
    );
    if RootMethodSymbolId <= 0 then
      Fail('missing-owner-aware-root-member-call-method-symbol');
    ImportedMethodSymbolId := SymbolIdByNameKindAndOwner(
      Model,
      'TWorker.Add',
      'method',
      'worker'
    );
    if ImportedMethodSymbolId <= 0 then
      Fail('missing-owner-aware-imported-member-call-method-symbol');
    if ImportedMethodSymbolId = RootMethodSymbolId then
      Fail('owner-aware-member-call-method-symbols-not-distinct');

    BindingCount := 0;
    for Index := 0 to Model.BindingCount - 1 do
    begin
      Binding := Model.BindingAt(Index);
      if SameText(Binding.Kind, 'member-call') and
        SameText(Binding.Name, 'Add') then
      begin
        Inc(BindingCount);
        if Binding.TargetSymbolId = ImportedMethodSymbolId then
          Fail('owner-aware-member-call-bound-imported-method');
        if Binding.TargetSymbolId <> RootMethodSymbolId then
          Fail('owner-aware-member-call-target-mismatch');
        if Binding.ByteOffset <> Pos('Add(1, 2)', RootSourceText) - 1 then
          Fail('owner-aware-member-call-offset-mismatch:' +
            IntToStr(Binding.ByteOffset));
      end;
    end;
    if BindingCount = 0 then
      Fail('missing-owner-aware-member-call-binding');
    if BindingCount <> 1 then
      Fail('unexpected-owner-aware-member-call-binding-count:' +
        IntToStr(BindingCount));
  finally
    Model.Free;
    Analyzer.Free;
    UnitGraph.Free;
    Ast.Free;
    Tree.Free;
    Lexer.Free;
    Diagnostics.Free;
  end;
end;

procedure CheckOverloadBindings;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Binding: TSemanticBinding;
  Diagnostics: TDiagnosticsSink;
  Index: LongInt;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  ProcedureZeroSymbolId: LongInt;
  ProcedureOneSymbolId: LongInt;
  SourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
  ZeroArgBindingTarget: LongInt;
  OneArgBindingTarget: LongInt;
begin
  SourceText :=
    'program OverloadedCalls;' + LineEnding +
    'procedure Pick;' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'procedure Pick(Value: Integer);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    '  Pick;' + LineEnding +
    '  Pick(1);' + LineEnding +
    'end.' + LineEnding;

  Diagnostics := TDiagnosticsSink.CreateDefault;
  Lexer := TLexerResult.Create(SourceText, Diagnostics, 1);
  Tree := ParseGreenTree(Lexer, Diagnostics, 1);
  Ast := TAstFacade.Create(Tree);
  UnitGraph := TUnitGraph.Create;
  Analyzer := nil;
  Model := nil;
  try
    UnitGraph.SetRootName(Ast.DeclaredName);
    Analyzer := TSemanticAnalyzer.Create(Ast, UnitGraph, Diagnostics, 1, True);
    Analyzer.Analyze;
    Model := Analyzer.DetachModel;
    if Diagnostics.HasErrors then
      Fail('unexpected-overload-diagnostics');
    if Model = nil then
      Fail('missing-overload-semantic-model');
    if Model.BindingCount <> 2 then
      Fail('unexpected-overload-binding-count:' + IntToStr(Model.BindingCount));

    ProcedureZeroSymbolId := 0;
    ProcedureOneSymbolId := 0;
    for Index := 0 to Model.SymbolCount - 1 do
    begin
      if SameText(Model.SymbolAt(Index).Name, 'Pick') and
        SameText(Model.SymbolAt(Index).Kind, 'procedure') then
      begin
        if Model.SymbolAt(Index).ParamCount = 0 then
          ProcedureZeroSymbolId := Model.SymbolAt(Index).SymbolId
        else if Model.SymbolAt(Index).ParamCount = 1 then
          ProcedureOneSymbolId := Model.SymbolAt(Index).SymbolId;
      end;
    end;
    if ProcedureZeroSymbolId <= 0 then
      Fail('missing-zero-arg-overload-symbol');
    if ProcedureOneSymbolId <= 0 then
      Fail('missing-one-arg-overload-symbol');

    ZeroArgBindingTarget := 0;
    OneArgBindingTarget := 0;
    for Index := 0 to Model.BindingCount - 1 do
    begin
      Binding := Model.BindingAt(Index);
      if not SameText(Binding.Kind, 'call') then
        Continue;
      if Pos('Pick;', Copy(SourceText, Binding.ByteOffset + 1, 5)) = 1 then
        ZeroArgBindingTarget := Binding.TargetSymbolId
      else if Pos('Pick(1)', Copy(SourceText, Binding.ByteOffset + 1, 7)) = 1 then
        OneArgBindingTarget := Binding.TargetSymbolId;
    end;

    if ZeroArgBindingTarget <> ProcedureZeroSymbolId then
      Fail('zero-arg-overload-binding-target-mismatch');
    if OneArgBindingTarget <> ProcedureOneSymbolId then
      Fail('one-arg-overload-binding-target-mismatch');
  finally
    Model.Free;
    Analyzer.Free;
    UnitGraph.Free;
    Ast.Free;
    Tree.Free;
    Lexer.Free;
    Diagnostics.Free;
  end;
end;

procedure CheckClassMemberCallBinding;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Binding: TSemanticBinding;
  Diagnostics: TDiagnosticsSink;
  Index: LongInt;
  Lexer: TLexerResult;
  MemberBindingCount: LongInt;
  MethodSymbolId: LongInt;
  Model: TSemanticModel;
  AddBindingCount: LongInt;
  AddOffset: LongInt;
  AddSymbolId: LongInt;
  CreateBindingCount: LongInt;
  CreateOffset: LongInt;
  CreateSymbolId: LongInt;
  SetValueBindingCount: LongInt;
  SetValueOffset: LongInt;
  SelfSetValueBindingCount: LongInt;
  SelfSetValueOffset: LongInt;
  SetValueSymbolId: LongInt;
  SourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
begin
  SourceText :=
    'program ClassMemberCalls;' + LineEnding +
    'type' + LineEnding +
    '  TWorker = class' + LineEnding +
    '    constructor Create(Value: Integer);' + LineEnding +
    '    procedure Run;' + LineEnding +
    '    procedure SetValue(Value: Integer);' + LineEnding +
    '    function Add(A, B: Integer): Integer;' + LineEnding +
    '  end;' + LineEnding +
    'constructor TWorker.Create(Value: Integer);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'procedure TWorker.Run;' + LineEnding +
    'begin' + LineEnding +
    '  Self.SetValue(9);' + LineEnding +
    'end;' + LineEnding +
    'procedure TWorker.SetValue(Value: Integer);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'function TWorker.Add(A, B: Integer): Integer;' + LineEnding +
    'begin' + LineEnding +
    '  Add := A + B;' + LineEnding +
    'end;' + LineEnding +
    'var' + LineEnding +
    '  Worker: TWorker;' + LineEnding +
    'begin' + LineEnding +
    '  Worker := TWorker.Create(42);' + LineEnding +
    '  Worker.Run;' + LineEnding +
    '  Worker.Run();' + LineEnding +
    '  Worker.SetValue(7);' + LineEnding +
    '  Worker.SetValue;' + LineEnding +
    '  Halt(Worker.Add(1, 2));' + LineEnding +
    'end.' + LineEnding;

  Diagnostics := TDiagnosticsSink.CreateDefault;
  Lexer := TLexerResult.Create(SourceText, Diagnostics, 1);
  Tree := ParseGreenTree(Lexer, Diagnostics, 1);
  Ast := TAstFacade.Create(Tree);
  UnitGraph := TUnitGraph.Create;
  Analyzer := nil;
  Model := nil;
  try
    UnitGraph.SetRootName(Ast.DeclaredName);
    Analyzer := TSemanticAnalyzer.Create(Ast, UnitGraph, Diagnostics, 1, True);
    Analyzer.Analyze;
    Model := Analyzer.DetachModel;
    if Diagnostics.HasErrors then
      Fail('unexpected-member-call-diagnostics');
    if Model = nil then
      Fail('missing-member-call-semantic-model');

    MethodSymbolId := SymbolIdByNameAndKind(Model, 'TWorker.Run', 'method');
    if MethodSymbolId <= 0 then
      Fail('missing-member-call-method-symbol');
    SetValueSymbolId := SymbolIdByNameAndKind(
      Model,
      'TWorker.SetValue',
      'method'
    );
    if SetValueSymbolId <= 0 then
      Fail('missing-member-call-argument-method-symbol');
    AddSymbolId := SymbolIdByNameAndKind(Model, 'TWorker.Add', 'method');
    if AddSymbolId <= 0 then
      Fail('missing-member-function-expression-method-symbol');
    CreateSymbolId := SymbolIdByNameAndKind(Model, 'TWorker.Create', 'method');
    if CreateSymbolId <= 0 then
      Fail('missing-member-constructor-method-symbol');

    MemberBindingCount := 0;
    AddBindingCount := 0;
    AddOffset := Pos('Add(1, 2)', SourceText) - 1;
    CreateBindingCount := 0;
    CreateOffset := Pos('Create(42)', SourceText) - 1;
    SetValueBindingCount := 0;
    SetValueOffset := Pos('SetValue(7)', SourceText) - 1;
    SelfSetValueBindingCount := 0;
    SelfSetValueOffset := Pos('SetValue(9)', SourceText) - 1;
    for Index := 0 to Model.BindingCount - 1 do
    begin
      Binding := Model.BindingAt(Index);
      if SameText(Binding.Kind, 'member-call') and
        SameText(Binding.Name, 'Run') then
      begin
        Inc(MemberBindingCount);
        if Binding.TargetSymbolId <> MethodSymbolId then
          Fail('member-call-binding-target-mismatch');
      end
      else if SameText(Binding.Kind, 'member-call') and
        SameText(Binding.Name, 'SetValue') then
      begin
        Inc(SetValueBindingCount);
        if Binding.TargetSymbolId <> SetValueSymbolId then
          Fail('member-call-argument-binding-target-mismatch');
        if Binding.ByteOffset = SelfSetValueOffset then
          Inc(SelfSetValueBindingCount)
        else if Binding.ByteOffset <> SetValueOffset then
          Fail('member-call-argument-binding-offset-mismatch:' +
            IntToStr(Binding.ByteOffset));
      end
      else if SameText(Binding.Kind, 'member-call') and
        SameText(Binding.Name, 'Add') then
      begin
        Inc(AddBindingCount);
        if Binding.TargetSymbolId <> AddSymbolId then
          Fail('member-function-expression-binding-target-mismatch');
        if Binding.ByteOffset <> AddOffset then
          Fail('member-function-expression-binding-offset-mismatch:' +
            IntToStr(Binding.ByteOffset));
      end
      else if SameText(Binding.Kind, 'member-call') and
        SameText(Binding.Name, 'Create') then
      begin
        Inc(CreateBindingCount);
        if Binding.TargetSymbolId <> CreateSymbolId then
          Fail('member-constructor-binding-target-mismatch');
        if Binding.ByteOffset <> CreateOffset then
          Fail('member-constructor-binding-offset-mismatch:' +
            IntToStr(Binding.ByteOffset));
      end;
    end;
    if MemberBindingCount = 0 then
      Fail('missing-member-call-binding');
    if MemberBindingCount <> 2 then
      Fail('unexpected-member-call-binding-count:' +
        IntToStr(MemberBindingCount));
    if SetValueBindingCount = 0 then
      Fail('missing-member-call-argument-binding');
    if SetValueBindingCount <> 2 then
      Fail('unexpected-member-call-argument-binding-count:' +
        IntToStr(SetValueBindingCount));
    if SelfSetValueBindingCount <> 1 then
      Fail('missing-self-member-call-binding');
    if AddBindingCount = 0 then
      Fail('missing-member-function-expression-binding');
    if AddBindingCount <> 1 then
      Fail('unexpected-member-function-expression-binding-count:' +
        IntToStr(AddBindingCount));
    if CreateBindingCount = 0 then
      Fail('missing-member-constructor-binding');
    if CreateBindingCount <> 1 then
      Fail('unexpected-member-constructor-binding-count:' +
        IntToStr(CreateBindingCount));
  finally
    Model.Free;
    Analyzer.Free;
    UnitGraph.Free;
    Ast.Free;
    Tree.Free;
    Lexer.Free;
    Diagnostics.Free;
  end;
end;

var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  FunctionSymbolId: LongInt;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  ProcedureSymbolId: LongInt;
  SourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
begin
  SourceText :=
    'program BoundCalls;' + LineEnding +
    'procedure Touch;' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'function Add(A, B: Integer): Integer;' + LineEnding +
    'begin' + LineEnding +
    '  Add := A + B;' + LineEnding +
    'end;' + LineEnding +
    'var' + LineEnding +
    '  Value: Integer;' + LineEnding +
    'begin' + LineEnding +
    '  Touch;' + LineEnding +
    '  Value := Add(1, 2);' + LineEnding +
    'end.' + LineEnding;

  Diagnostics := TDiagnosticsSink.CreateDefault;
  Lexer := TLexerResult.Create(SourceText, Diagnostics, 1);
  Tree := ParseGreenTree(Lexer, Diagnostics, 1);
  Ast := TAstFacade.Create(Tree);
  UnitGraph := TUnitGraph.Create;
  Analyzer := nil;
  Model := nil;
  try
    UnitGraph.SetRootName(Ast.DeclaredName);
    Analyzer := TSemanticAnalyzer.Create(Ast, UnitGraph, Diagnostics, 1, True);
    Analyzer.Analyze;
    Model := Analyzer.DetachModel;
    if Diagnostics.HasErrors then
      Fail('unexpected-diagnostics');
    if Model = nil then
      Fail('missing-semantic-model');
    if Model.BindingCount <> 2 then
      Fail('unexpected-binding-count:' + IntToStr(Model.BindingCount));

    ProcedureSymbolId := SymbolIdByNameAndKind(Model, 'Touch', 'procedure');
    if ProcedureSymbolId <= 0 then
      Fail('missing-procedure-symbol');
    if BindingTargetForName(Model, 'Touch') <> ProcedureSymbolId then
      Fail('procedure-call-binding-target-mismatch');

    FunctionSymbolId := SymbolIdByNameAndKind(Model, 'Add', 'function');
    if FunctionSymbolId <= 0 then
      Fail('missing-function-symbol');
    if BindingTargetForName(Model, 'Add') <> FunctionSymbolId then
      Fail('function-call-binding-target-mismatch');

    CheckImportedUnitCallBinding;
    CheckImportedClassMemberCallBinding;
    CheckOwnerAwareImportedClassMemberCallBinding;
    CheckOverloadBindings;
    CheckClassMemberCallBinding;

    WriteLn('semantic-call-bindings-status=pass');
  finally
    Model.Free;
    Analyzer.Free;
    UnitGraph.Free;
    Ast.Free;
    Tree.Free;
    Lexer.Free;
    Diagnostics.Free;
  end;
end.
