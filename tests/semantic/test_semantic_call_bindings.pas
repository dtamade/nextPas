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

function SymbolIdByNameKindOwnerAndParam(
  const AModel: TSemanticModel;
  const AName: string;
  const AKind: string;
  const AOwnerUnitId: string;
  const AParamCount: LongInt
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
      SameText(Symbol.OwnerUnitId, AOwnerUnitId) and
      (Symbol.ParamCount = AParamCount) then
      Exit(Symbol.SymbolId);
  end;
end;

function SymbolIdByNameKindOwnerAndSignature(
  const AModel: TSemanticModel;
  const AName: string;
  const AKind: string;
  const AOwnerUnitId: string;
  const AParamCount: LongInt;
  const AParamSignature: string
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
      SameText(Symbol.OwnerUnitId, AOwnerUnitId) and
      (Symbol.ParamCount = AParamCount) and
      SameText(Symbol.ParamSignature, AParamSignature) then
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

procedure CheckInheritedClassMemberCallBinding;
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
  RootSourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
begin
  RootSourceText :=
    'program InheritedMemberCalls;' + LineEnding +
    'type' + LineEnding +
    '  TBase = class' + LineEnding +
    '    procedure Touch;' + LineEnding +
    '  end;' + LineEnding +
    '  TChild = class(TBase)' + LineEnding +
    '  end;' + LineEnding +
    'procedure TBase.Touch;' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'var' + LineEnding +
    '  Worker: TChild;' + LineEnding +
    'begin' + LineEnding +
    '  Worker.Touch;' + LineEnding +
    'end.' + LineEnding;

  Diagnostics := TDiagnosticsSink.CreateDefault;
  Lexer := TLexerResult.Create(RootSourceText, Diagnostics, 1);
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
      Fail('unexpected-inherited-member-call-diagnostics');
    if Model = nil then
      Fail('missing-inherited-member-call-semantic-model');

    MethodSymbolId := SymbolIdByNameKindAndOwner(
      Model,
      'TBase.Touch',
      'method',
      'inheritedmembercalls'
    );
    if MethodSymbolId <= 0 then
      Fail('missing-inherited-member-call-method-symbol');

    BindingCount := 0;
    for Index := 0 to Model.BindingCount - 1 do
    begin
      Binding := Model.BindingAt(Index);
      if SameText(Binding.Kind, 'member-call') and
        SameText(Binding.Name, 'Touch') then
      begin
        Inc(BindingCount);
        if Binding.TargetSymbolId <> MethodSymbolId then
          Fail('inherited-member-call-target-mismatch');
        if Binding.ByteOffset <> Pos('Worker.Touch', RootSourceText) +
          Length('Worker.') - 1 then
          Fail('inherited-member-call-offset-mismatch:' +
            IntToStr(Binding.ByteOffset));
      end;
    end;
    if BindingCount = 0 then
      Fail('missing-inherited-member-call-binding');
    if BindingCount <> 1 then
      Fail('unexpected-inherited-member-call-binding-count:' +
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

procedure CheckMemberOverloadBindingTargets;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Binding: TSemanticBinding;
  BindingCount: LongInt;
  Diagnostics: TDiagnosticsSink;
  Index: LongInt;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  OneArgOffset: LongInt;
  OneArgSymbolId: LongInt;
  SourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
  ZeroArgOffset: LongInt;
  ZeroArgSymbolId: LongInt;
begin
  SourceText :=
    'program MemberOverloadCalls;' + LineEnding +
    'type' + LineEnding +
    '  TWorker = class' + LineEnding +
    '    procedure Pick;' + LineEnding +
    '    procedure Pick(Value: Integer);' + LineEnding +
    '  end;' + LineEnding +
    'procedure TWorker.Pick;' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'procedure TWorker.Pick(Value: Integer);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'var' + LineEnding +
    '  Worker: TWorker;' + LineEnding +
    'begin' + LineEnding +
    '  Worker.Pick;' + LineEnding +
    '  Worker.Pick(1);' + LineEnding +
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
      Fail('unexpected-member-overload-diagnostics');
    if Model = nil then
      Fail('missing-member-overload-semantic-model');

    ZeroArgSymbolId := SymbolIdByNameKindOwnerAndParam(
      Model,
      'TWorker.Pick',
      'method',
      'memberoverloadcalls',
      0
    );
    OneArgSymbolId := SymbolIdByNameKindOwnerAndParam(
      Model,
      'TWorker.Pick',
      'method',
      'memberoverloadcalls',
      1
    );
    if ZeroArgSymbolId <= 0 then
      Fail('missing-zero-arg-member-overload-symbol');
    if OneArgSymbolId <= 0 then
      Fail('missing-one-arg-member-overload-symbol');

    ZeroArgOffset := Pos('  Worker.Pick;', SourceText) +
      Length('  Worker.') - 1;
    OneArgOffset := Pos('  Worker.Pick(1)', SourceText) +
      Length('  Worker.') - 1;
    BindingCount := 0;
    for Index := 0 to Model.BindingCount - 1 do
    begin
      Binding := Model.BindingAt(Index);
      if SameText(Binding.Kind, 'member-call') and
        SameText(Binding.Name, 'Pick') then
      begin
        Inc(BindingCount);
        if Binding.ByteOffset = ZeroArgOffset then
        begin
          if Binding.TargetSymbolId <> ZeroArgSymbolId then
            Fail('zero-arg-member-overload-target-mismatch');
        end
        else if Binding.ByteOffset = OneArgOffset then
        begin
          if Binding.TargetSymbolId <> OneArgSymbolId then
            Fail('one-arg-member-overload-target-mismatch');
        end
        else
          Fail('unexpected-member-overload-binding-offset:' +
            IntToStr(Binding.ByteOffset));
      end;
    end;

    if BindingCount = 0 then
      Fail('missing-member-overload-bindings');
    if BindingCount <> 2 then
      Fail('unexpected-member-overload-binding-count:' +
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

procedure CheckMemberTypedOverloadBindingTargets;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Binding: TSemanticBinding;
  BindingCount: LongInt;
  BooleanOffset: LongInt;
  BooleanSymbolId: LongInt;
  Diagnostics: TDiagnosticsSink;
  Index: LongInt;
  IntegerOffset: LongInt;
  IntegerSymbolId: LongInt;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  SourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
begin
  SourceText :=
    'program MemberTypedOverloadCalls;' + LineEnding +
    'type' + LineEnding +
    '  TWorker = class' + LineEnding +
    '    procedure Pick(Value: Integer);' + LineEnding +
    '    procedure Pick(Value: Boolean);' + LineEnding +
    '  end;' + LineEnding +
    'procedure TWorker.Pick(Value: Integer);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'procedure TWorker.Pick(Value: Boolean);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'var' + LineEnding +
    '  Worker: TWorker;' + LineEnding +
    'begin' + LineEnding +
    '  Worker.Pick(1);' + LineEnding +
    '  Worker.Pick(1 = 1);' + LineEnding +
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
      Fail('unexpected-member-typed-overload-diagnostics');
    if Model = nil then
      Fail('missing-member-typed-overload-semantic-model');

    IntegerSymbolId := SymbolIdByNameKindOwnerAndSignature(
      Model,
      'TWorker.Pick',
      'method',
      'membertypedoverloadcalls',
      1,
      'i'
    );
    BooleanSymbolId := SymbolIdByNameKindOwnerAndSignature(
      Model,
      'TWorker.Pick',
      'method',
      'membertypedoverloadcalls',
      1,
      'b'
    );
    if IntegerSymbolId <= 0 then
      Fail('missing-integer-member-overload-symbol');
    if BooleanSymbolId <= 0 then
      Fail('missing-boolean-member-overload-symbol');

    IntegerOffset := Pos('  Worker.Pick(1);', SourceText) +
      Length('  Worker.') - 1;
    BooleanOffset := Pos('  Worker.Pick(1 = 1);', SourceText) +
      Length('  Worker.') - 1;
    BindingCount := 0;
    for Index := 0 to Model.BindingCount - 1 do
    begin
      Binding := Model.BindingAt(Index);
      if SameText(Binding.Kind, 'member-call') and
        SameText(Binding.Name, 'Pick') then
      begin
        if (Binding.ByteOffset <> IntegerOffset) and
          (Binding.ByteOffset <> BooleanOffset) then
          Continue;
        Inc(BindingCount);
        if Binding.ByteOffset = IntegerOffset then
        begin
          if Binding.TargetSymbolId <> IntegerSymbolId then
            Fail('integer-member-overload-target-mismatch');
        end
        else if Binding.ByteOffset = BooleanOffset then
        begin
          if Binding.TargetSymbolId <> BooleanSymbolId then
            Fail('boolean-member-overload-target-mismatch');
        end;
      end;
    end;

    if BindingCount = 0 then
      Fail('missing-member-typed-overload-bindings');
    if BindingCount <> 2 then
      Fail('unexpected-member-typed-overload-binding-count:' +
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

procedure CheckAmbiguousMemberOverloadDiagnostic;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  SourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
begin
  SourceText :=
    'program AmbiguousMemberOverloadCalls;' + LineEnding +
    'type' + LineEnding +
    '  TWorker = class' + LineEnding +
    '    procedure Pick(Value: Integer);' + LineEnding +
    '    procedure Pick(Value: LongInt);' + LineEnding +
    '  end;' + LineEnding +
    'procedure TWorker.Pick(Value: Integer);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'procedure TWorker.Pick(Value: LongInt);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'var' + LineEnding +
    '  Worker: TWorker;' + LineEnding +
    'begin' + LineEnding +
    '  Worker.Pick(1);' + LineEnding +
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
    if not Diagnostics.HasErrors then
      Fail('missing-ambiguous-member-overload-diagnostic');
    if not SameText(Diagnostics.LastDiagnosticCode, 'sema.ambiguous-overload') then
      Fail('unexpected-ambiguous-member-overload-diagnostic-code:' +
        Diagnostics.LastDiagnosticCode);
    if not SameText(Diagnostics.LastDiagnosticPhase, 'sema') then
      Fail('unexpected-ambiguous-member-overload-diagnostic-phase:' +
        Diagnostics.LastDiagnosticPhase);
    if Pos('Pick', Diagnostics.LastDiagnosticMessage) <= 0 then
      Fail('ambiguous-member-overload-diagnostic-missing-name');
    if Model = nil then
      Fail('missing-ambiguous-member-overload-semantic-model');
    if not SameText(Model.Status, 'failure') then
      Fail('unexpected-ambiguous-member-overload-model-status:' +
        Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-ambiguous-member-overload-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckMemberNoMatchingOverloadDiagnostic;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  SourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
begin
  SourceText :=
    'program MemberNoMatchingOverloadCalls;' + LineEnding +
    'type' + LineEnding +
    '  TWorker = class' + LineEnding +
    '    procedure Pick(Value: Integer);' + LineEnding +
    '    procedure Pick(Value: AnsiString);' + LineEnding +
    '  end;' + LineEnding +
    'procedure TWorker.Pick(Value: Integer);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'procedure TWorker.Pick(Value: AnsiString);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'var' + LineEnding +
    '  Worker: TWorker;' + LineEnding +
    'begin' + LineEnding +
    '  Worker.Pick(True);' + LineEnding +
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
    if not Diagnostics.HasErrors then
      Fail('missing-member-no-matching-overload-diagnostic');
    if not SameText(Diagnostics.LastDiagnosticCode, 'sema.no-matching-overload') then
      Fail('unexpected-member-no-matching-overload-diagnostic-code:' +
        Diagnostics.LastDiagnosticCode);
    if not SameText(Diagnostics.LastDiagnosticPhase, 'sema') then
      Fail('unexpected-member-no-matching-overload-diagnostic-phase:' +
        Diagnostics.LastDiagnosticPhase);
    if Pos('Pick', Diagnostics.LastDiagnosticMessage) <= 0 then
      Fail('member-no-matching-overload-diagnostic-missing-name');
    if Model = nil then
      Fail('missing-member-no-matching-overload-semantic-model');
    if not SameText(Model.Status, 'failure') then
      Fail('unexpected-member-no-matching-overload-model-status:' +
        Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-member-no-matching-overload-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckInheritedMemberNoMatchingOverloadDiagnostic;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  SourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
begin
  SourceText :=
    'program InheritedMemberNoMatchingOverloadCalls;' + LineEnding +
    'type' + LineEnding +
    '  TBase = class' + LineEnding +
    '    procedure Pick(Value: Integer);' + LineEnding +
    '    procedure Pick(Value: AnsiString);' + LineEnding +
    '  end;' + LineEnding +
    '  TWorker = class(TBase)' + LineEnding +
    '  end;' + LineEnding +
    'procedure TBase.Pick(Value: Integer);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'procedure TBase.Pick(Value: AnsiString);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'var' + LineEnding +
    '  Worker: TWorker;' + LineEnding +
    'begin' + LineEnding +
    '  Worker.Pick(True);' + LineEnding +
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
    if not Diagnostics.HasErrors then
      Fail('missing-inherited-member-no-matching-overload-diagnostic');
    if not SameText(
      Diagnostics.LastDiagnosticCode,
      'sema.no-matching-overload'
    ) then
      Fail('unexpected-inherited-member-no-matching-overload-diagnostic-code:' +
        Diagnostics.LastDiagnosticCode);
    if not SameText(Diagnostics.LastDiagnosticPhase, 'sema') then
      Fail('unexpected-inherited-member-no-matching-overload-diagnostic-phase:' +
        Diagnostics.LastDiagnosticPhase);
    if Pos('Pick', Diagnostics.LastDiagnosticMessage) <= 0 then
      Fail('inherited-member-no-matching-overload-diagnostic-missing-name');
    if Model = nil then
      Fail('missing-inherited-member-no-matching-overload-semantic-model');
    if not SameText(Model.Status, 'failure') then
      Fail('unexpected-inherited-member-no-matching-overload-model-status:' +
        Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-inherited-member-no-matching-overload-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckUnknownMemberDiagnostic;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  SourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
begin
  SourceText :=
    'program UnknownMemberCalls;' + LineEnding +
    'type' + LineEnding +
    '  TWorker = class' + LineEnding +
    '    procedure Run;' + LineEnding +
    '  end;' + LineEnding +
    'procedure TWorker.Run;' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'var' + LineEnding +
    '  Worker: TWorker;' + LineEnding +
    'begin' + LineEnding +
    '  Worker.Missing(1);' + LineEnding +
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
    if not Diagnostics.HasErrors then
      Fail('missing-unknown-member-diagnostic');
    if not SameText(Diagnostics.LastDiagnosticCode, 'sema.unknown-member') then
      Fail('unexpected-unknown-member-diagnostic-code:' +
        Diagnostics.LastDiagnosticCode);
    if not SameText(Diagnostics.LastDiagnosticPhase, 'sema') then
      Fail('unexpected-unknown-member-diagnostic-phase:' +
        Diagnostics.LastDiagnosticPhase);
    if Pos('Missing', Diagnostics.LastDiagnosticMessage) <= 0 then
      Fail('unknown-member-diagnostic-missing-name');
    if Model = nil then
      Fail('missing-unknown-member-semantic-model');
    if not SameText(Model.Status, 'failure') then
      Fail('unexpected-unknown-member-model-status:' + Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-unknown-member-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckKnownFieldMemberCallDiagnostic;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  SourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
begin
  SourceText :=
    'program KnownFieldMemberCall;' + LineEnding +
    'type' + LineEnding +
    '  TWorker = class' + LineEnding +
    '    Value: Integer;' + LineEnding +
    '  end;' + LineEnding +
    'var' + LineEnding +
    '  Worker: TWorker;' + LineEnding +
    'begin' + LineEnding +
    '  Worker.Value(1);' + LineEnding +
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
    if not Diagnostics.HasErrors then
      Fail('missing-known-field-member-call-diagnostic');
    if not SameText(Diagnostics.LastDiagnosticCode, 'sema.invalid-call-shape') then
      Fail('unexpected-known-field-member-call-diagnostic-code:' +
        Diagnostics.LastDiagnosticCode);
    if not SameText(Diagnostics.LastDiagnosticPhase, 'sema') then
      Fail('unexpected-known-field-member-call-diagnostic-phase:' +
        Diagnostics.LastDiagnosticPhase);
    if Pos('Value', Diagnostics.LastDiagnosticMessage) <= 0 then
      Fail('known-field-member-call-diagnostic-missing-name');
    if Model = nil then
      Fail('missing-known-field-member-call-semantic-model');
    if not SameText(Model.Status, 'failure') then
      Fail('unexpected-known-field-member-call-model-status:' + Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-known-field-member-call-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckKnownPropertyMemberCallDiagnostic;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  SourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
begin
  SourceText :=
    'program KnownPropertyMemberCall;' + LineEnding +
    'type' + LineEnding +
    '  TWorker = class' + LineEnding +
    '  private' + LineEnding +
    '    FValue: Integer;' + LineEnding +
    '  public' + LineEnding +
    '    property Value: Integer read FValue write FValue;' + LineEnding +
    '  end;' + LineEnding +
    'var' + LineEnding +
    '  Worker: TWorker;' + LineEnding +
    'begin' + LineEnding +
    '  Worker.Value(1);' + LineEnding +
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
    if not Diagnostics.HasErrors then
      Fail('missing-known-property-member-call-diagnostic');
    if not SameText(Diagnostics.LastDiagnosticCode, 'sema.invalid-call-shape') then
      Fail('unexpected-known-property-member-call-diagnostic-code:' +
        Diagnostics.LastDiagnosticCode);
    if not SameText(Diagnostics.LastDiagnosticPhase, 'sema') then
      Fail('unexpected-known-property-member-call-diagnostic-phase:' +
        Diagnostics.LastDiagnosticPhase);
    if Pos('Value', Diagnostics.LastDiagnosticMessage) <= 0 then
      Fail('known-property-member-call-diagnostic-missing-name');
    if Model = nil then
      Fail('missing-known-property-member-call-semantic-model');
    if not SameText(Model.Status, 'failure') then
      Fail('unexpected-known-property-member-call-model-status:' + Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-known-property-member-call-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckInheritedKnownFieldMemberCallDiagnostic;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  SourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
begin
  SourceText :=
    'program InheritedKnownFieldMemberCall;' + LineEnding +
    'type' + LineEnding +
    '  TBaseWorker = class' + LineEnding +
    '    Value: Integer;' + LineEnding +
    '  end;' + LineEnding +
    '  TWorker = class(TBaseWorker)' + LineEnding +
    '  end;' + LineEnding +
    'var' + LineEnding +
    '  Worker: TWorker;' + LineEnding +
    'begin' + LineEnding +
    '  Worker.Value(1);' + LineEnding +
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
    if not Diagnostics.HasErrors then
      Fail('missing-inherited-known-field-member-call-diagnostic');
    if not SameText(Diagnostics.LastDiagnosticCode, 'sema.invalid-call-shape') then
      Fail('unexpected-inherited-known-field-member-call-diagnostic-code:' +
        Diagnostics.LastDiagnosticCode);
    if not SameText(Diagnostics.LastDiagnosticPhase, 'sema') then
      Fail('unexpected-inherited-known-field-member-call-diagnostic-phase:' +
        Diagnostics.LastDiagnosticPhase);
    if Pos('Value', Diagnostics.LastDiagnosticMessage) <= 0 then
      Fail('inherited-known-field-member-call-diagnostic-missing-name');
    if Model = nil then
      Fail('missing-inherited-known-field-member-call-semantic-model');
    if not SameText(Model.Status, 'failure') then
      Fail('unexpected-inherited-known-field-member-call-model-status:' +
        Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-inherited-known-field-member-call-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckInheritedKnownPropertyMemberCallDiagnostic;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  SourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
begin
  SourceText :=
    'program InheritedKnownPropertyMemberCall;' + LineEnding +
    'type' + LineEnding +
    '  TBaseWorker = class' + LineEnding +
    '  private' + LineEnding +
    '    FValue: Integer;' + LineEnding +
    '  public' + LineEnding +
    '    property Value: Integer read FValue write FValue;' + LineEnding +
    '  end;' + LineEnding +
    '  TWorker = class(TBaseWorker)' + LineEnding +
    '  end;' + LineEnding +
    'var' + LineEnding +
    '  Worker: TWorker;' + LineEnding +
    'begin' + LineEnding +
    '  Worker.Value(1);' + LineEnding +
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
    if not Diagnostics.HasErrors then
      Fail('missing-inherited-known-property-member-call-diagnostic');
    if not SameText(Diagnostics.LastDiagnosticCode, 'sema.invalid-call-shape') then
      Fail('unexpected-inherited-known-property-member-call-diagnostic-code:' +
        Diagnostics.LastDiagnosticCode);
    if not SameText(Diagnostics.LastDiagnosticPhase, 'sema') then
      Fail('unexpected-inherited-known-property-member-call-diagnostic-phase:' +
        Diagnostics.LastDiagnosticPhase);
    if Pos('Value', Diagnostics.LastDiagnosticMessage) <= 0 then
      Fail('inherited-known-property-member-call-diagnostic-missing-name');
    if Model = nil then
      Fail('missing-inherited-known-property-member-call-semantic-model');
    if not SameText(Model.Status, 'failure') then
      Fail('unexpected-inherited-known-property-member-call-model-status:' +
        Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-inherited-known-property-member-call-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckSystemObjectFreeMemberCallStaysDeferred;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  SourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
begin
  SourceText :=
    'program SystemObjectMemberCall;' + LineEnding +
    'type' + LineEnding +
    '  TWorker = class' + LineEnding +
    '  end;' + LineEnding +
    'var' + LineEnding +
    '  Worker: TWorker;' + LineEnding +
    'begin' + LineEnding +
    '  Worker.Free;' + LineEnding +
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
      Fail('unexpected-system-object-free-diagnostic:' +
        Diagnostics.LastDiagnosticCode);
    if Model = nil then
      Fail('missing-system-object-free-semantic-model');
    if not SameText(Model.Status, 'ready') then
      Fail('unexpected-system-object-free-model-status:' + Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-system-object-free-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckSourceBackedSystemObjectFreeMemberCallBinding;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Binding: TSemanticBinding;
  Diagnostics: TDiagnosticsSink;
  FreeBindingCount: LongInt;
  FreeSymbolId: LongInt;
  Index: LongInt;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  SourceText: string;
  SystemPath: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
begin
  SystemPath := ExpandFileName('units/linux-x86_64/System.pas');
  SourceText :=
    'program SourceBackedSystemObjectMemberCall;' + LineEnding +
    'uses System;' + LineEnding +
    'type' + LineEnding +
    '  TWorker = class' + LineEnding +
    '  end;' + LineEnding +
    'var' + LineEnding +
    '  Worker: TWorker;' + LineEnding +
    'begin' + LineEnding +
    '  Worker.Free;' + LineEnding +
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
    UnitGraph.AddResolvedUnit(
      BuildResolvedUnit(
        Ast.DeclaredName,
        '',
        ruoRootSource,
        'linux-x86_64',
        'program',
        1
      )
    );
    UnitGraph.AddResolvedUnit(
      BuildResolvedUnit(
        'System',
        SystemPath,
        ruoInstalledSource,
        'linux-x86_64',
        'unit',
        2
      )
    );
    Analyzer := TSemanticAnalyzer.Create(Ast, UnitGraph, Diagnostics, 1, True);
    Analyzer.Analyze;
    Model := Analyzer.DetachModel;
    if Diagnostics.HasErrors then
      Fail('unexpected-source-backed-system-free-diagnostic:' +
        Diagnostics.LastDiagnosticCode);
    if Model = nil then
      Fail('missing-source-backed-system-free-semantic-model');
    if not SameText(Model.Status, 'ready') then
      Fail('unexpected-source-backed-system-free-model-status:' + Model.Status);

    FreeSymbolId := SymbolIdByNameKindAndOwner(
      Model,
      'TObject.Free',
      'method',
      'system'
    );
    if FreeSymbolId <= 0 then
      Fail('missing-source-backed-system-free-method-symbol');

    FreeBindingCount := 0;
    for Index := 0 to Model.BindingCount - 1 do
    begin
      Binding := Model.BindingAt(Index);
      if SameText(Binding.Kind, 'member-call') and
        SameText(Binding.Name, 'Free') then
      begin
        Inc(FreeBindingCount);
        if Binding.TargetSymbolId <> FreeSymbolId then
          Fail('source-backed-system-free-binding-target-mismatch');
        if Binding.ByteOffset <> Pos('Free', SourceText) - 1 then
          Fail('source-backed-system-free-binding-offset-mismatch:' +
            IntToStr(Binding.ByteOffset));
      end;
    end;
    if FreeBindingCount = 0 then
      Fail('missing-source-backed-system-free-binding');
    if FreeBindingCount <> 1 then
      Fail('unexpected-source-backed-system-free-binding-count:' +
        IntToStr(FreeBindingCount));
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

procedure CheckImplicitSystemObjectFreeLowersToInheritedDestroy;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  DestroyCallCount: LongInt;
  Diagnostics: TDiagnosticsSink;
  HirNode: TTypedHirNode;
  Index: LongInt;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  ObjectFreeContractCount: LongInt;
  SourceText: string;
  SystemPath: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
begin
  SystemPath := ExpandFileName('units/linux-x86_64/System.pas');
  SourceText :=
    'program ImplicitSystemObjectFreeLowering;' + LineEnding +
    'type' + LineEnding +
    '  TWorker = class' + LineEnding +
    '  end;' + LineEnding +
    'var' + LineEnding +
    '  Worker: TWorker;' + LineEnding +
    'begin' + LineEnding +
    '  Worker.Free;' + LineEnding +
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
    UnitGraph.AddResolvedUnit(
      BuildResolvedUnit(
        Ast.DeclaredName,
        '',
        ruoRootSource,
        'linux-x86_64',
        'program',
        1
      )
    );
    UnitGraph.AddResolvedUnit(
      BuildResolvedUnit(
        'System',
        SystemPath,
        ruoImplicitRuntime,
        'linux-x86_64',
        'unit',
        2
      )
    );
    Analyzer := TSemanticAnalyzer.Create(Ast, UnitGraph, Diagnostics, 1, True);
    Analyzer.Analyze;
    Model := Analyzer.DetachModel;
    if Diagnostics.HasErrors then
      Fail('unexpected-implicit-system-free-lowering-diagnostic:' +
        Diagnostics.LastDiagnosticCode);
    if Model = nil then
      Fail('missing-implicit-system-free-lowering-semantic-model');
    if not SameText(Model.Status, 'ready') then
      Fail('unexpected-implicit-system-free-lowering-model-status:' +
        Model.Status);

    DestroyCallCount := 0;
    ObjectFreeContractCount := 0;
    for Index := 0 to Model.TypedHirNodeCount - 1 do
    begin
      HirNode := Model.TypedHirNodeAt(Index);
      if SameText(HirNode.Kind, 'call-runtime') and
        SameText(HirNode.DisplayName, 'TObject.Destroy') then
      begin
        Inc(DestroyCallCount);
        if Pos('TObject.Destroy' + #9 + 'var Worker', HirNode.Operand) <> 1 then
          Fail('implicit-system-free-destroy-operand-mismatch:' +
            HirNode.Operand);
      end
      else if SameText(HirNode.Kind, 'call-runtime') and
        SameText(HirNode.DisplayName, 'TWorker.Destroy') then
        Fail('implicit-system-free-lowered-to-missing-worker-destroy');
      if SameText(HirNode.Kind, 'object-free-runtime') and
        SameText(HirNode.DisplayName, 'np.system.object_free') then
      begin
        Inc(ObjectFreeContractCount);
        if Pos('var Worker' + #10, HirNode.Operand) <> 1 then
          Fail('implicit-system-free-contract-receiver-mismatch:' +
            HirNode.Operand);
        if Pos('destroy TObject.Destroy' + #10, HirNode.Operand) = 0 then
          Fail('implicit-system-free-contract-destroy-mismatch:' +
            HirNode.Operand);
        if Pos('nil-guard true' + #10, HirNode.Operand) = 0 then
          Fail('implicit-system-free-contract-missing-nil-guard:' +
            HirNode.Operand);
        if Pos('heap-release true' + #10, HirNode.Operand) = 0 then
          Fail('implicit-system-free-contract-missing-heap-release:' +
            HirNode.Operand);
      end;
    end;
    if DestroyCallCount = 0 then
      Fail('missing-implicit-system-free-inherited-destroy-lowering');
    if DestroyCallCount <> 1 then
      Fail('unexpected-implicit-system-free-destroy-call-count:' +
        IntToStr(DestroyCallCount));
    if ObjectFreeContractCount = 0 then
      Fail('missing-implicit-system-free-runtime-contract');
    if ObjectFreeContractCount <> 1 then
      Fail('unexpected-implicit-system-free-contract-count:' +
        IntToStr(ObjectFreeContractCount));
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

procedure CheckSpecializedGenericMemberCallStaysDeferred;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  SourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
begin
  SourceText :=
    'program SpecializedGenericMemberCall;' + LineEnding +
    '{$mode objfpc}{$H+}' + LineEnding +
    'type' + LineEnding +
    '  generic TBox<T> = class' + LineEnding +
    '    procedure Put(const Value: T);' + LineEnding +
    '  end;' + LineEnding +
    'procedure TBox.Put(const Value: T);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'type' + LineEnding +
    '  TIntegerBox = specialize TBox<Integer>;' + LineEnding +
    'var' + LineEnding +
    '  Box: TIntegerBox;' + LineEnding +
    'begin' + LineEnding +
    '  Box.Put(1);' + LineEnding +
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
      Fail('unexpected-specialized-generic-member-call-diagnostic:' +
        Diagnostics.LastDiagnosticCode);
    if Model = nil then
      Fail('missing-specialized-generic-member-call-semantic-model');
    if not SameText(Model.Status, 'ready') then
      Fail('unexpected-specialized-generic-member-call-model-status:' +
        Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-specialized-generic-member-call-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckBareTypedOverloadBindingTargets;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Binding: TSemanticBinding;
  BindingCount: LongInt;
  BooleanOffset: LongInt;
  BooleanSymbolId: LongInt;
  Diagnostics: TDiagnosticsSink;
  Index: LongInt;
  IntegerOffset: LongInt;
  IntegerSymbolId: LongInt;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  SourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
begin
  SourceText :=
    'program BareTypedOverloadCalls;' + LineEnding +
    'procedure Pick(Value: Integer);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'procedure Pick(Value: Boolean);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    '  Pick(1);' + LineEnding +
    '  Pick(1 = 1);' + LineEnding +
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
      Fail('unexpected-bare-typed-overload-diagnostics');
    if Model = nil then
      Fail('missing-bare-typed-overload-semantic-model');

    IntegerSymbolId := SymbolIdByNameKindOwnerAndSignature(
      Model,
      'Pick',
      'procedure',
      'baretypedoverloadcalls',
      1,
      'i'
    );
    BooleanSymbolId := SymbolIdByNameKindOwnerAndSignature(
      Model,
      'Pick',
      'procedure',
      'baretypedoverloadcalls',
      1,
      'b'
    );
    if IntegerSymbolId <= 0 then
      Fail('missing-integer-bare-overload-symbol');
    if BooleanSymbolId <= 0 then
      Fail('missing-boolean-bare-overload-symbol');

    IntegerOffset := Pos('  Pick(1);', SourceText) + Length('  ') - 1;
    BooleanOffset := Pos('  Pick(1 = 1);', SourceText) + Length('  ') - 1;
    BindingCount := 0;
    for Index := 0 to Model.BindingCount - 1 do
    begin
      Binding := Model.BindingAt(Index);
      if SameText(Binding.Kind, 'call') and SameText(Binding.Name, 'Pick') then
      begin
        if (Binding.ByteOffset <> IntegerOffset) and
          (Binding.ByteOffset <> BooleanOffset) then
          Continue;
        Inc(BindingCount);
        if Binding.ByteOffset = IntegerOffset then
        begin
          if Binding.TargetSymbolId <> IntegerSymbolId then
            Fail('integer-bare-overload-target-mismatch');
        end
        else if Binding.ByteOffset = BooleanOffset then
        begin
          if Binding.TargetSymbolId <> BooleanSymbolId then
            Fail('boolean-bare-overload-target-mismatch');
        end;
      end;
    end;

    if BindingCount = 0 then
      Fail('missing-bare-typed-overload-bindings');
    if BindingCount <> 2 then
      Fail('unexpected-bare-typed-overload-binding-count:' +
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

procedure CheckAmbiguousImportedBareOverloadDiagnostic;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  HelperAPath: string;
  HelperBPath: string;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  ProjectRoot: string;
  RootSourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
begin
  ProjectRoot := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'nextpas-semantic-ambiguous-overload-' + IntToStr(Random(MaxInt));
  HelperAPath := ProjectRoot + DirectorySeparator + 'helpera.pas';
  HelperBPath := ProjectRoot + DirectorySeparator + 'helperb.pas';
  RootSourceText :=
    'program AmbiguousBareOverloadCalls;' + LineEnding +
    'uses HelperA, HelperB;' + LineEnding +
    'begin' + LineEnding +
    '  Pick(1);' + LineEnding +
    'end.' + LineEnding;
  WriteTextFile(
    HelperAPath,
    'unit HelperA;' + LineEnding +
    LineEnding +
    'interface' + LineEnding +
    'procedure Pick(Value: Integer);' + LineEnding +
    LineEnding +
    'implementation' + LineEnding +
    'procedure Pick(Value: Integer);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    LineEnding +
    'end.' + LineEnding
  );
  WriteTextFile(
    HelperBPath,
    'unit HelperB;' + LineEnding +
    LineEnding +
    'interface' + LineEnding +
    'procedure Pick(Value: Integer);' + LineEnding +
    LineEnding +
    'implementation' + LineEnding +
    'procedure Pick(Value: Integer);' + LineEnding +
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
      BuildResolvedUnit(
        'AmbiguousBareOverloadCalls',
        '',
        ruoRootSource,
        '',
        'program',
        1
      )
    );
    UnitGraph.AddResolvedUnit(
      BuildResolvedUnit('HelperA', HelperAPath, ruoProjectSource, '', 'unit', 2)
    );
    UnitGraph.AddResolvedUnit(
      BuildResolvedUnit('HelperB', HelperBPath, ruoProjectSource, '', 'unit', 3)
    );
    Analyzer := TSemanticAnalyzer.Create(Ast, UnitGraph, Diagnostics, 1, True);
    Analyzer.Analyze;
    Model := Analyzer.DetachModel;
    if not Diagnostics.HasErrors then
      Fail('missing-ambiguous-overload-diagnostic');
    if not SameText(Diagnostics.LastDiagnosticCode, 'sema.ambiguous-overload') then
      Fail('unexpected-ambiguous-overload-diagnostic-code:' +
        Diagnostics.LastDiagnosticCode);
    if not SameText(Diagnostics.LastDiagnosticPhase, 'sema') then
      Fail('unexpected-ambiguous-overload-diagnostic-phase:' +
        Diagnostics.LastDiagnosticPhase);
    if Pos('Pick', Diagnostics.LastDiagnosticMessage) <= 0 then
      Fail('ambiguous-overload-diagnostic-missing-name');
    if Model = nil then
      Fail('missing-ambiguous-overload-semantic-model');
    if not SameText(Model.Status, 'failure') then
      Fail('unexpected-ambiguous-overload-model-status:' + Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-ambiguous-overload-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckImportedNoMatchingOverloadDiagnostic;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  HelperAPath: string;
  HelperBPath: string;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  ProjectRoot: string;
  RootSourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
begin
  ProjectRoot := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'nextpas-semantic-imported-no-matching-overload-' +
    IntToStr(Random(MaxInt));
  HelperAPath := ProjectRoot + DirectorySeparator + 'helpera.pas';
  HelperBPath := ProjectRoot + DirectorySeparator + 'helperb.pas';
  RootSourceText :=
    'program ImportedNoMatchingOverloadCalls;' + LineEnding +
    'uses HelperA, HelperB;' + LineEnding +
    'begin' + LineEnding +
    '  Pick(True);' + LineEnding +
    'end.' + LineEnding;
  WriteTextFile(
    HelperAPath,
    'unit HelperA;' + LineEnding +
    LineEnding +
    'interface' + LineEnding +
    'procedure Pick(Value: Integer);' + LineEnding +
    LineEnding +
    'implementation' + LineEnding +
    'procedure Pick(Value: Integer);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    LineEnding +
    'end.' + LineEnding
  );
  WriteTextFile(
    HelperBPath,
    'unit HelperB;' + LineEnding +
    LineEnding +
    'interface' + LineEnding +
    'procedure Pick(Value: AnsiString);' + LineEnding +
    LineEnding +
    'implementation' + LineEnding +
    'procedure Pick(Value: AnsiString);' + LineEnding +
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
      BuildResolvedUnit(
        'ImportedNoMatchingOverloadCalls',
        '',
        ruoRootSource,
        '',
        'program',
        1
      )
    );
    UnitGraph.AddResolvedUnit(
      BuildResolvedUnit('HelperA', HelperAPath, ruoProjectSource, '', 'unit', 2)
    );
    UnitGraph.AddResolvedUnit(
      BuildResolvedUnit('HelperB', HelperBPath, ruoProjectSource, '', 'unit', 3)
    );
    Analyzer := TSemanticAnalyzer.Create(Ast, UnitGraph, Diagnostics, 1, True);
    Analyzer.Analyze;
    Model := Analyzer.DetachModel;
    if not Diagnostics.HasErrors then
      Fail('missing-imported-no-matching-overload-diagnostic');
    if not SameText(
      Diagnostics.LastDiagnosticCode,
      'sema.no-matching-overload'
    ) then
      Fail('unexpected-imported-no-matching-overload-diagnostic-code:' +
        Diagnostics.LastDiagnosticCode);
    if not SameText(Diagnostics.LastDiagnosticPhase, 'sema') then
      Fail('unexpected-imported-no-matching-overload-diagnostic-phase:' +
        Diagnostics.LastDiagnosticPhase);
    if Pos('Pick', Diagnostics.LastDiagnosticMessage) <= 0 then
      Fail('imported-no-matching-overload-diagnostic-missing-name');
    if Model = nil then
      Fail('missing-imported-no-matching-overload-semantic-model');
    if not SameText(Model.Status, 'failure') then
      Fail('unexpected-imported-no-matching-overload-model-status:' +
        Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-imported-no-matching-overload-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckImportedFunctionResultNoMatchingOverloadDiagnostic;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  HelperAPath: string;
  HelperBPath: string;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  ProjectRoot: string;
  RootSourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
begin
  ProjectRoot := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'nextpas-semantic-imported-function-result-no-matching-overload-' +
    IntToStr(Random(MaxInt));
  HelperAPath := ProjectRoot + DirectorySeparator + 'helpera.pas';
  HelperBPath := ProjectRoot + DirectorySeparator + 'helperb.pas';
  RootSourceText :=
    'program ImportedFunctionResultNoMatchingOverloadCalls;' + LineEnding +
    'uses HelperA, HelperB;' + LineEnding +
    'function Flag: Boolean;' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    '  Pick(Flag);' + LineEnding +
    'end.' + LineEnding;
  WriteTextFile(
    HelperAPath,
    'unit HelperA;' + LineEnding +
    LineEnding +
    'interface' + LineEnding +
    'procedure Pick(Value: Integer);' + LineEnding +
    LineEnding +
    'implementation' + LineEnding +
    'procedure Pick(Value: Integer);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    LineEnding +
    'end.' + LineEnding
  );
  WriteTextFile(
    HelperBPath,
    'unit HelperB;' + LineEnding +
    LineEnding +
    'interface' + LineEnding +
    'procedure Pick(Value: AnsiString);' + LineEnding +
    LineEnding +
    'implementation' + LineEnding +
    'procedure Pick(Value: AnsiString);' + LineEnding +
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
      BuildResolvedUnit(
        'ImportedFunctionResultNoMatchingOverloadCalls',
        '',
        ruoRootSource,
        '',
        'program',
        1
      )
    );
    UnitGraph.AddResolvedUnit(
      BuildResolvedUnit('HelperA', HelperAPath, ruoProjectSource, '', 'unit', 2)
    );
    UnitGraph.AddResolvedUnit(
      BuildResolvedUnit('HelperB', HelperBPath, ruoProjectSource, '', 'unit', 3)
    );
    Analyzer := TSemanticAnalyzer.Create(Ast, UnitGraph, Diagnostics, 1, True);
    Analyzer.Analyze;
    Model := Analyzer.DetachModel;
    if not Diagnostics.HasErrors then
      Fail('missing-imported-function-result-no-matching-overload-diagnostic');
    if not SameText(
      Diagnostics.LastDiagnosticCode,
      'sema.no-matching-overload'
    ) then
      Fail('unexpected-imported-function-result-no-matching-overload-diagnostic-code:' +
        Diagnostics.LastDiagnosticCode);
    if not SameText(Diagnostics.LastDiagnosticPhase, 'sema') then
      Fail('unexpected-imported-function-result-no-matching-overload-diagnostic-phase:' +
        Diagnostics.LastDiagnosticPhase);
    if Pos('Pick', Diagnostics.LastDiagnosticMessage) <= 0 then
      Fail('imported-function-result-no-matching-overload-diagnostic-missing-name');
    if Model = nil then
      Fail('missing-imported-function-result-no-matching-overload-semantic-model');
    if not SameText(Model.Status, 'failure') then
      Fail('unexpected-imported-function-result-no-matching-overload-model-status:' +
        Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-imported-function-result-no-matching-overload-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckInstalledSourceAmbiguousOverloadStaysDeferred;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  HelperAPath: string;
  HelperBPath: string;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  ProjectRoot: string;
  RootSourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
begin
  ProjectRoot := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'nextpas-semantic-installed-imported-ambiguous-overload-' +
    IntToStr(Random(MaxInt));
  HelperAPath := ProjectRoot + DirectorySeparator + 'helpera.pas';
  HelperBPath := ProjectRoot + DirectorySeparator + 'helperb.pas';
  RootSourceText :=
    'program InstalledImportedAmbiguousOverloadCalls;' + LineEnding +
    'uses HelperA, HelperB;' + LineEnding +
    'begin' + LineEnding +
    '  Pick(1);' + LineEnding +
    'end.' + LineEnding;
  WriteTextFile(
    HelperAPath,
    'unit HelperA;' + LineEnding +
    LineEnding +
    'interface' + LineEnding +
    'procedure Pick(Value: Integer);' + LineEnding +
    LineEnding +
    'implementation' + LineEnding +
    'procedure Pick(Value: Integer);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    LineEnding +
    'end.' + LineEnding
  );
  WriteTextFile(
    HelperBPath,
    'unit HelperB;' + LineEnding +
    LineEnding +
    'interface' + LineEnding +
    'procedure Pick(Value: Integer);' + LineEnding +
    LineEnding +
    'implementation' + LineEnding +
    'procedure Pick(Value: Integer);' + LineEnding +
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
      BuildResolvedUnit(
        'InstalledImportedAmbiguousOverloadCalls',
        '',
        ruoRootSource,
        '',
        'program',
        1
      )
    );
    UnitGraph.AddResolvedUnit(
      BuildResolvedUnit('HelperA', HelperAPath, ruoInstalledSource, '', 'unit', 2)
    );
    UnitGraph.AddResolvedUnit(
      BuildResolvedUnit('HelperB', HelperBPath, ruoInstalledSource, '', 'unit', 3)
    );
    Analyzer := TSemanticAnalyzer.Create(Ast, UnitGraph, Diagnostics, 1, True);
    Analyzer.Analyze;
    Model := Analyzer.DetachModel;
    if Diagnostics.HasErrors then
      Fail('unexpected-installed-imported-ambiguous-overload-diagnostic:' +
        Diagnostics.LastDiagnosticCode);
    if Model = nil then
      Fail('missing-installed-imported-ambiguous-overload-semantic-model');
    if not SameText(Model.Status, 'ready') then
      Fail('unexpected-installed-imported-ambiguous-overload-model-status:' +
        Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-installed-imported-ambiguous-overload-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckInstalledSourceNoMatchingOverloadStaysDeferred;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  HelperAPath: string;
  HelperBPath: string;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  ProjectRoot: string;
  RootSourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
begin
  ProjectRoot := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'nextpas-semantic-installed-imported-no-matching-overload-' +
    IntToStr(Random(MaxInt));
  HelperAPath := ProjectRoot + DirectorySeparator + 'helpera.pas';
  HelperBPath := ProjectRoot + DirectorySeparator + 'helperb.pas';
  RootSourceText :=
    'program InstalledImportedNoMatchingOverloadCalls;' + LineEnding +
    'uses HelperA, HelperB;' + LineEnding +
    'begin' + LineEnding +
    '  Pick(True);' + LineEnding +
    'end.' + LineEnding;
  WriteTextFile(
    HelperAPath,
    'unit HelperA;' + LineEnding +
    LineEnding +
    'interface' + LineEnding +
    'procedure Pick(Value: Integer);' + LineEnding +
    LineEnding +
    'implementation' + LineEnding +
    'procedure Pick(Value: Integer);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    LineEnding +
    'end.' + LineEnding
  );
  WriteTextFile(
    HelperBPath,
    'unit HelperB;' + LineEnding +
    LineEnding +
    'interface' + LineEnding +
    'procedure Pick(Value: AnsiString);' + LineEnding +
    LineEnding +
    'implementation' + LineEnding +
    'procedure Pick(Value: AnsiString);' + LineEnding +
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
      BuildResolvedUnit(
        'InstalledImportedNoMatchingOverloadCalls',
        '',
        ruoRootSource,
        '',
        'program',
        1
      )
    );
    UnitGraph.AddResolvedUnit(
      BuildResolvedUnit('HelperA', HelperAPath, ruoInstalledSource, '', 'unit', 2)
    );
    UnitGraph.AddResolvedUnit(
      BuildResolvedUnit('HelperB', HelperBPath, ruoInstalledSource, '', 'unit', 3)
    );
    Analyzer := TSemanticAnalyzer.Create(Ast, UnitGraph, Diagnostics, 1, True);
    Analyzer.Analyze;
    Model := Analyzer.DetachModel;
    if Diagnostics.HasErrors then
      Fail('unexpected-installed-imported-no-matching-overload-diagnostic:' +
        Diagnostics.LastDiagnosticCode);
    if Model = nil then
      Fail('missing-installed-imported-no-matching-overload-semantic-model');
    if not SameText(Model.Status, 'ready') then
      Fail('unexpected-installed-imported-no-matching-overload-model-status:' +
        Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-installed-imported-no-matching-overload-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckImportedWrongArgumentCountDiagnostic;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  HelperPath: string;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  ProjectRoot: string;
  RootSourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
begin
  ProjectRoot := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'nextpas-semantic-imported-wrong-argument-count-' +
    IntToStr(Random(MaxInt));
  HelperPath := ProjectRoot + DirectorySeparator + 'helper.pas';
  RootSourceText :=
    'program ImportedWrongArgumentCountCalls;' + LineEnding +
    'uses Helper;' + LineEnding +
    'begin' + LineEnding +
    '  Pick;' + LineEnding +
    'end.' + LineEnding;
  WriteTextFile(
    HelperPath,
    'unit Helper;' + LineEnding +
    LineEnding +
    'interface' + LineEnding +
    'procedure Pick(Value: Integer);' + LineEnding +
    LineEnding +
    'implementation' + LineEnding +
    'procedure Pick(Value: Integer);' + LineEnding +
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
      BuildResolvedUnit(
        'ImportedWrongArgumentCountCalls',
        '',
        ruoRootSource,
        '',
        'program',
        1
      )
    );
    UnitGraph.AddResolvedUnit(
      BuildResolvedUnit('Helper', HelperPath, ruoProjectSource, '', 'unit', 2)
    );
    Analyzer := TSemanticAnalyzer.Create(Ast, UnitGraph, Diagnostics, 1, True);
    Analyzer.Analyze;
    Model := Analyzer.DetachModel;
    if not Diagnostics.HasErrors then
      Fail('missing-imported-wrong-argument-count-diagnostic');
    if not SameText(
      Diagnostics.LastDiagnosticCode,
      'sema.wrong-argument-count'
    ) then
      Fail('unexpected-imported-wrong-argument-count-diagnostic-code:' +
        Diagnostics.LastDiagnosticCode);
    if not SameText(Diagnostics.LastDiagnosticPhase, 'sema') then
      Fail('unexpected-imported-wrong-argument-count-diagnostic-phase:' +
        Diagnostics.LastDiagnosticPhase);
    if Pos('Pick', Diagnostics.LastDiagnosticMessage) <= 0 then
      Fail('imported-wrong-argument-count-diagnostic-missing-name');
    if Model = nil then
      Fail('missing-imported-wrong-argument-count-semantic-model');
    if not SameText(Model.Status, 'failure') then
      Fail('unexpected-imported-wrong-argument-count-model-status:' +
        Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-imported-wrong-argument-count-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckInstalledSourceWrongArgumentCountStaysDeferred;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  HelperPath: string;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  ProjectRoot: string;
  RootSourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
begin
  ProjectRoot := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'nextpas-semantic-installed-imported-wrong-argument-count-' +
    IntToStr(Random(MaxInt));
  HelperPath := ProjectRoot + DirectorySeparator + 'helper.pas';
  RootSourceText :=
    'program InstalledImportedWrongArgumentCountCalls;' + LineEnding +
    'uses Helper;' + LineEnding +
    'begin' + LineEnding +
    '  Pick;' + LineEnding +
    'end.' + LineEnding;
  WriteTextFile(
    HelperPath,
    'unit Helper;' + LineEnding +
    LineEnding +
    'interface' + LineEnding +
    'procedure Pick(Value: Integer);' + LineEnding +
    LineEnding +
    'implementation' + LineEnding +
    'procedure Pick(Value: Integer);' + LineEnding +
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
      BuildResolvedUnit(
        'InstalledImportedWrongArgumentCountCalls',
        '',
        ruoRootSource,
        '',
        'program',
        1
      )
    );
    UnitGraph.AddResolvedUnit(
      BuildResolvedUnit('Helper', HelperPath, ruoInstalledSource, '', 'unit', 2)
    );
    Analyzer := TSemanticAnalyzer.Create(Ast, UnitGraph, Diagnostics, 1, True);
    Analyzer.Analyze;
    Model := Analyzer.DetachModel;
    if Diagnostics.HasErrors then
      Fail('unexpected-installed-imported-wrong-argument-count-diagnostic:' +
        Diagnostics.LastDiagnosticCode);
    if Model = nil then
      Fail('missing-installed-imported-wrong-argument-count-semantic-model');
    if not SameText(Model.Status, 'ready') then
      Fail('unexpected-installed-imported-wrong-argument-count-model-status:' +
        Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-installed-imported-wrong-argument-count-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckImportedCallTypeMismatchDiagnostic;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  HelperPath: string;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  ProjectRoot: string;
  RootSourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
begin
  ProjectRoot := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'nextpas-semantic-imported-call-type-mismatch-' +
    IntToStr(Random(MaxInt));
  HelperPath := ProjectRoot + DirectorySeparator + 'helper.pas';
  RootSourceText :=
    'program ImportedCallTypeMismatchCalls;' + LineEnding +
    'uses Helper;' + LineEnding +
    'begin' + LineEnding +
    '  Pick(True);' + LineEnding +
    'end.' + LineEnding;
  WriteTextFile(
    HelperPath,
    'unit Helper;' + LineEnding +
    LineEnding +
    'interface' + LineEnding +
    'procedure Pick(Value: Integer);' + LineEnding +
    LineEnding +
    'implementation' + LineEnding +
    'procedure Pick(Value: Integer);' + LineEnding +
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
      BuildResolvedUnit(
        'ImportedCallTypeMismatchCalls',
        '',
        ruoRootSource,
        '',
        'program',
        1
      )
    );
    UnitGraph.AddResolvedUnit(
      BuildResolvedUnit('Helper', HelperPath, ruoProjectSource, '', 'unit', 2)
    );
    Analyzer := TSemanticAnalyzer.Create(Ast, UnitGraph, Diagnostics, 1, True);
    Analyzer.Analyze;
    Model := Analyzer.DetachModel;
    if not Diagnostics.HasErrors then
      Fail('missing-imported-call-type-mismatch-diagnostic');
    if not SameText(Diagnostics.LastDiagnosticCode, 'sema.type-mismatch') then
      Fail('unexpected-imported-call-type-mismatch-diagnostic-code:' +
        Diagnostics.LastDiagnosticCode);
    if not SameText(Diagnostics.LastDiagnosticPhase, 'sema') then
      Fail('unexpected-imported-call-type-mismatch-diagnostic-phase:' +
        Diagnostics.LastDiagnosticPhase);
    if Pos('Pick', Diagnostics.LastDiagnosticMessage) <= 0 then
      Fail('imported-call-type-mismatch-diagnostic-missing-name');
    if Model = nil then
      Fail('missing-imported-call-type-mismatch-semantic-model');
    if not SameText(Model.Status, 'failure') then
      Fail('unexpected-imported-call-type-mismatch-model-status:' +
        Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-imported-call-type-mismatch-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckInstalledSourceCallTypeMismatchStaysDeferred;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  HelperPath: string;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  ProjectRoot: string;
  RootSourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
begin
  ProjectRoot := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'nextpas-semantic-installed-imported-call-type-mismatch-' +
    IntToStr(Random(MaxInt));
  HelperPath := ProjectRoot + DirectorySeparator + 'helper.pas';
  RootSourceText :=
    'program InstalledImportedCallTypeMismatchCalls;' + LineEnding +
    'uses Helper;' + LineEnding +
    'begin' + LineEnding +
    '  Pick(True);' + LineEnding +
    'end.' + LineEnding;
  WriteTextFile(
    HelperPath,
    'unit Helper;' + LineEnding +
    LineEnding +
    'interface' + LineEnding +
    'procedure Pick(Value: Integer);' + LineEnding +
    LineEnding +
    'implementation' + LineEnding +
    'procedure Pick(Value: Integer);' + LineEnding +
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
      BuildResolvedUnit(
        'InstalledImportedCallTypeMismatchCalls',
        '',
        ruoRootSource,
        '',
        'program',
        1
      )
    );
    UnitGraph.AddResolvedUnit(
      BuildResolvedUnit('Helper', HelperPath, ruoInstalledSource, '', 'unit', 2)
    );
    Analyzer := TSemanticAnalyzer.Create(Ast, UnitGraph, Diagnostics, 1, True);
    Analyzer.Analyze;
    Model := Analyzer.DetachModel;
    if Diagnostics.HasErrors then
      Fail('unexpected-installed-imported-call-type-mismatch-diagnostic:' +
        Diagnostics.LastDiagnosticCode);
    if Model = nil then
      Fail('missing-installed-imported-call-type-mismatch-semantic-model');
    if not SameText(Model.Status, 'ready') then
      Fail('unexpected-installed-imported-call-type-mismatch-model-status:' +
        Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-installed-imported-call-type-mismatch-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckImportedFunctionResultCallTypeMismatchDiagnostic;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  HelperPath: string;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  ProjectRoot: string;
  RootSourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
begin
  ProjectRoot := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'nextpas-semantic-imported-function-result-type-mismatch-' +
    IntToStr(Random(MaxInt));
  HelperPath := ProjectRoot + DirectorySeparator + 'helper.pas';
  RootSourceText :=
    'program ImportedFunctionResultTypeMismatchCalls;' + LineEnding +
    'uses Helper;' + LineEnding +
    'function Flag: Boolean;' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    '  Pick(Flag);' + LineEnding +
    'end.' + LineEnding;
  WriteTextFile(
    HelperPath,
    'unit Helper;' + LineEnding +
    LineEnding +
    'interface' + LineEnding +
    'procedure Pick(Value: Integer);' + LineEnding +
    LineEnding +
    'implementation' + LineEnding +
    'procedure Pick(Value: Integer);' + LineEnding +
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
      BuildResolvedUnit(
        'ImportedFunctionResultTypeMismatchCalls',
        '',
        ruoRootSource,
        '',
        'program',
        1
      )
    );
    UnitGraph.AddResolvedUnit(
      BuildResolvedUnit('Helper', HelperPath, ruoProjectSource, '', 'unit', 2)
    );
    Analyzer := TSemanticAnalyzer.Create(Ast, UnitGraph, Diagnostics, 1, True);
    Analyzer.Analyze;
    Model := Analyzer.DetachModel;
    if not Diagnostics.HasErrors then
      Fail('missing-imported-function-result-type-mismatch-diagnostic');
    if not SameText(Diagnostics.LastDiagnosticCode, 'sema.type-mismatch') then
      Fail('unexpected-imported-function-result-type-mismatch-diagnostic-code:' +
        Diagnostics.LastDiagnosticCode);
    if not SameText(Diagnostics.LastDiagnosticPhase, 'sema') then
      Fail('unexpected-imported-function-result-type-mismatch-diagnostic-phase:' +
        Diagnostics.LastDiagnosticPhase);
    if Pos('Pick', Diagnostics.LastDiagnosticMessage) <= 0 then
      Fail('imported-function-result-type-mismatch-diagnostic-missing-name');
    if Model = nil then
      Fail('missing-imported-function-result-type-mismatch-semantic-model');
    if not SameText(Model.Status, 'failure') then
      Fail('unexpected-imported-function-result-type-mismatch-model-status:' +
        Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-imported-function-result-type-mismatch-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckInstalledSourceFunctionResultCallTypeMismatchStaysDeferred;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  HelperPath: string;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  ProjectRoot: string;
  RootSourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
begin
  ProjectRoot := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'nextpas-semantic-installed-imported-function-result-type-mismatch-' +
    IntToStr(Random(MaxInt));
  HelperPath := ProjectRoot + DirectorySeparator + 'helper.pas';
  RootSourceText :=
    'program InstalledImportedFunctionResultTypeMismatchCalls;' + LineEnding +
    'uses Helper;' + LineEnding +
    'function Flag: Boolean;' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    '  Pick(Flag);' + LineEnding +
    'end.' + LineEnding;
  WriteTextFile(
    HelperPath,
    'unit Helper;' + LineEnding +
    LineEnding +
    'interface' + LineEnding +
    'procedure Pick(Value: Integer);' + LineEnding +
    LineEnding +
    'implementation' + LineEnding +
    'procedure Pick(Value: Integer);' + LineEnding +
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
      BuildResolvedUnit(
        'InstalledImportedFunctionResultTypeMismatchCalls',
        '',
        ruoRootSource,
        '',
        'program',
        1
      )
    );
    UnitGraph.AddResolvedUnit(
      BuildResolvedUnit('Helper', HelperPath, ruoInstalledSource, '', 'unit', 2)
    );
    Analyzer := TSemanticAnalyzer.Create(Ast, UnitGraph, Diagnostics, 1, True);
    Analyzer.Analyze;
    Model := Analyzer.DetachModel;
    if Diagnostics.HasErrors then
      Fail('unexpected-installed-imported-function-result-type-mismatch-diagnostic:' +
        Diagnostics.LastDiagnosticCode);
    if Model = nil then
      Fail('missing-installed-imported-function-result-type-mismatch-semantic-model');
    if not SameText(Model.Status, 'ready') then
      Fail('unexpected-installed-imported-function-result-type-mismatch-model-status:' +
        Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-installed-imported-function-result-type-mismatch-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckImportedMemberCallTypeMismatchDiagnostic;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  ProjectRoot: string;
  RootSourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
  UnitPath: string;
begin
  ProjectRoot := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'nextpas-semantic-imported-member-type-mismatch-' +
    IntToStr(Random(MaxInt));
  UnitPath := ProjectRoot + DirectorySeparator + 'worker.pas';
  RootSourceText :=
    'program ImportedMemberTypeMismatchCalls;' + LineEnding +
    'uses Worker;' + LineEnding +
    'var' + LineEnding +
    '  Worker: TWorker;' + LineEnding +
    'begin' + LineEnding +
    '  Worker.Pick(True);' + LineEnding +
    'end.' + LineEnding;
  WriteTextFile(
    UnitPath,
    'unit Worker;' + LineEnding +
    LineEnding +
    'interface' + LineEnding +
    'type' + LineEnding +
    '  TWorker = class' + LineEnding +
    '    procedure Pick(Value: Integer);' + LineEnding +
    '  end;' + LineEnding +
    LineEnding +
    'implementation' + LineEnding +
    'procedure TWorker.Pick(Value: Integer);' + LineEnding +
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
      BuildResolvedUnit(
        'ImportedMemberTypeMismatchCalls',
        '',
        ruoRootSource,
        '',
        'program',
        1
      )
    );
    UnitGraph.AddResolvedUnit(
      BuildResolvedUnit('Worker', UnitPath, ruoProjectSource, '', 'unit', 2)
    );
    Analyzer := TSemanticAnalyzer.Create(Ast, UnitGraph, Diagnostics, 1, True);
    Analyzer.Analyze;
    Model := Analyzer.DetachModel;
    if not Diagnostics.HasErrors then
      Fail('missing-imported-member-call-type-mismatch-diagnostic');
    if not SameText(Diagnostics.LastDiagnosticCode, 'sema.type-mismatch') then
      Fail('unexpected-imported-member-call-type-mismatch-diagnostic-code:' +
        Diagnostics.LastDiagnosticCode);
    if not SameText(Diagnostics.LastDiagnosticPhase, 'sema') then
      Fail('unexpected-imported-member-call-type-mismatch-diagnostic-phase:' +
        Diagnostics.LastDiagnosticPhase);
    if Pos('Pick', Diagnostics.LastDiagnosticMessage) <= 0 then
      Fail('imported-member-call-type-mismatch-diagnostic-missing-name');
    if Model = nil then
      Fail('missing-imported-member-call-type-mismatch-semantic-model');
    if not SameText(Model.Status, 'failure') then
      Fail('unexpected-imported-member-call-type-mismatch-model-status:' +
        Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-imported-member-call-type-mismatch-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckImportedMemberNoMatchingOverloadDiagnostic;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  ProjectRoot: string;
  RootSourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
  UnitPath: string;
begin
  ProjectRoot := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'nextpas-semantic-imported-member-no-matching-overload-' +
    IntToStr(Random(MaxInt));
  UnitPath := ProjectRoot + DirectorySeparator + 'worker.pas';
  RootSourceText :=
    'program ImportedMemberNoMatchingOverloadCalls;' + LineEnding +
    'uses Worker;' + LineEnding +
    'var' + LineEnding +
    '  Worker: TWorker;' + LineEnding +
    'begin' + LineEnding +
    '  Worker.Pick(True);' + LineEnding +
    'end.' + LineEnding;
  WriteTextFile(
    UnitPath,
    'unit Worker;' + LineEnding +
    LineEnding +
    'interface' + LineEnding +
    'type' + LineEnding +
    '  TWorker = class' + LineEnding +
    '    procedure Pick(Value: Integer);' + LineEnding +
    '    procedure Pick(Value: AnsiString);' + LineEnding +
    '  end;' + LineEnding +
    LineEnding +
    'implementation' + LineEnding +
    'procedure TWorker.Pick(Value: Integer);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'procedure TWorker.Pick(Value: AnsiString);' + LineEnding +
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
      BuildResolvedUnit(
        'ImportedMemberNoMatchingOverloadCalls',
        '',
        ruoRootSource,
        '',
        'program',
        1
      )
    );
    UnitGraph.AddResolvedUnit(
      BuildResolvedUnit('Worker', UnitPath, ruoProjectSource, '', 'unit', 2)
    );
    Analyzer := TSemanticAnalyzer.Create(Ast, UnitGraph, Diagnostics, 1, True);
    Analyzer.Analyze;
    Model := Analyzer.DetachModel;
    if not Diagnostics.HasErrors then
      Fail('missing-imported-member-no-matching-overload-diagnostic');
    if not SameText(
      Diagnostics.LastDiagnosticCode,
      'sema.no-matching-overload'
    ) then
      Fail('unexpected-imported-member-no-matching-overload-diagnostic-code:' +
        Diagnostics.LastDiagnosticCode);
    if not SameText(Diagnostics.LastDiagnosticPhase, 'sema') then
      Fail('unexpected-imported-member-no-matching-overload-diagnostic-phase:' +
        Diagnostics.LastDiagnosticPhase);
    if Pos('Pick', Diagnostics.LastDiagnosticMessage) <= 0 then
      Fail('imported-member-no-matching-overload-diagnostic-missing-name');
    if Model = nil then
      Fail('missing-imported-member-no-matching-overload-semantic-model');
    if not SameText(Model.Status, 'failure') then
      Fail('unexpected-imported-member-no-matching-overload-model-status:' +
        Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-imported-member-no-matching-overload-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckImportedInheritedMemberNoMatchingOverloadDiagnostic;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  ProjectRoot: string;
  RootSourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
  UnitPath: string;
begin
  ProjectRoot := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'nextpas-semantic-imported-inherited-member-no-matching-overload-' +
    IntToStr(Random(MaxInt));
  UnitPath := ProjectRoot + DirectorySeparator + 'worker.pas';
  RootSourceText :=
    'program ImportedInheritedMemberNoMatchingOverloadCalls;' + LineEnding +
    'uses Worker;' + LineEnding +
    'var' + LineEnding +
    '  Worker: TWorker;' + LineEnding +
    'begin' + LineEnding +
    '  Worker.Pick(True);' + LineEnding +
    'end.' + LineEnding;
  WriteTextFile(
    UnitPath,
    'unit Worker;' + LineEnding +
    LineEnding +
    'interface' + LineEnding +
    'type' + LineEnding +
    '  TBase = class' + LineEnding +
    '    procedure Pick(Value: Integer);' + LineEnding +
    '    procedure Pick(Value: AnsiString);' + LineEnding +
    '  end;' + LineEnding +
    '  TWorker = class(TBase)' + LineEnding +
    '  end;' + LineEnding +
    LineEnding +
    'implementation' + LineEnding +
    'procedure TBase.Pick(Value: Integer);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'procedure TBase.Pick(Value: AnsiString);' + LineEnding +
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
      BuildResolvedUnit(
        'ImportedInheritedMemberNoMatchingOverloadCalls',
        '',
        ruoRootSource,
        '',
        'program',
        1
      )
    );
    UnitGraph.AddResolvedUnit(
      BuildResolvedUnit('Worker', UnitPath, ruoProjectSource, '', 'unit', 2)
    );
    Analyzer := TSemanticAnalyzer.Create(Ast, UnitGraph, Diagnostics, 1, True);
    Analyzer.Analyze;
    Model := Analyzer.DetachModel;
    if not Diagnostics.HasErrors then
      Fail('missing-imported-inherited-member-no-matching-overload-diagnostic');
    if not SameText(
      Diagnostics.LastDiagnosticCode,
      'sema.no-matching-overload'
    ) then
      Fail('unexpected-imported-inherited-member-no-matching-overload-diagnostic-code:' +
        Diagnostics.LastDiagnosticCode);
    if not SameText(Diagnostics.LastDiagnosticPhase, 'sema') then
      Fail('unexpected-imported-inherited-member-no-matching-overload-diagnostic-phase:' +
        Diagnostics.LastDiagnosticPhase);
    if Pos('Pick', Diagnostics.LastDiagnosticMessage) <= 0 then
      Fail('imported-inherited-member-no-matching-overload-diagnostic-missing-name');
    if Model = nil then
      Fail('missing-imported-inherited-member-no-matching-overload-semantic-model');
    if not SameText(Model.Status, 'failure') then
      Fail('unexpected-imported-inherited-member-no-matching-overload-model-status:' +
        Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-imported-inherited-member-no-matching-overload-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckImportedInheritedMemberAmbiguousOverloadDiagnostic;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  ProjectRoot: string;
  RootSourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
  UnitPath: string;
begin
  ProjectRoot := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'nextpas-semantic-imported-inherited-member-ambiguous-overload-' +
    IntToStr(Random(MaxInt));
  UnitPath := ProjectRoot + DirectorySeparator + 'worker.pas';
  RootSourceText :=
    'program ImportedInheritedMemberAmbiguousOverloadCalls;' + LineEnding +
    'uses Worker;' + LineEnding +
    'var' + LineEnding +
    '  Worker: TWorker;' + LineEnding +
    'begin' + LineEnding +
    '  Worker.Pick(1);' + LineEnding +
    'end.' + LineEnding;
  WriteTextFile(
    UnitPath,
    'unit Worker;' + LineEnding +
    LineEnding +
    'interface' + LineEnding +
    'type' + LineEnding +
    '  TBase = class' + LineEnding +
    '    procedure Pick(Value: Integer);' + LineEnding +
    '    procedure Pick(Value: LongInt);' + LineEnding +
    '  end;' + LineEnding +
    '  TWorker = class(TBase)' + LineEnding +
    '  end;' + LineEnding +
    LineEnding +
    'implementation' + LineEnding +
    'procedure TBase.Pick(Value: Integer);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'procedure TBase.Pick(Value: LongInt);' + LineEnding +
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
      BuildResolvedUnit(
        'ImportedInheritedMemberAmbiguousOverloadCalls',
        '',
        ruoRootSource,
        '',
        'program',
        1
      )
    );
    UnitGraph.AddResolvedUnit(
      BuildResolvedUnit('Worker', UnitPath, ruoProjectSource, '', 'unit', 2)
    );
    Analyzer := TSemanticAnalyzer.Create(Ast, UnitGraph, Diagnostics, 1, True);
    Analyzer.Analyze;
    Model := Analyzer.DetachModel;
    if not Diagnostics.HasErrors then
      Fail('missing-imported-inherited-member-ambiguous-overload-diagnostic');
    if not SameText(
      Diagnostics.LastDiagnosticCode,
      'sema.ambiguous-overload'
    ) then
      Fail('unexpected-imported-inherited-member-ambiguous-overload-diagnostic-code:' +
        Diagnostics.LastDiagnosticCode);
    if not SameText(Diagnostics.LastDiagnosticPhase, 'sema') then
      Fail('unexpected-imported-inherited-member-ambiguous-overload-diagnostic-phase:' +
        Diagnostics.LastDiagnosticPhase);
    if Pos('Pick', Diagnostics.LastDiagnosticMessage) <= 0 then
      Fail('imported-inherited-member-ambiguous-overload-diagnostic-missing-name');
    if Model = nil then
      Fail('missing-imported-inherited-member-ambiguous-overload-semantic-model');
    if not SameText(Model.Status, 'failure') then
      Fail('unexpected-imported-inherited-member-ambiguous-overload-model-status:' +
        Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-imported-inherited-member-ambiguous-overload-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckImportedInheritedMemberFunctionResultNoMatchingOverloadDiagnostic;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  ProjectRoot: string;
  RootSourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
  UnitPath: string;
begin
  ProjectRoot := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'nextpas-semantic-imported-inherited-member-function-result-no-matching-overload-' +
    IntToStr(Random(MaxInt));
  UnitPath := ProjectRoot + DirectorySeparator + 'worker.pas';
  RootSourceText :=
    'program ImportedInheritedMemberFunctionResultNoMatchingOverloadCalls;' + LineEnding +
    'uses Worker;' + LineEnding +
    'var' + LineEnding +
    '  Worker: TWorker;' + LineEnding +
    'function Flag: Boolean;' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    '  Worker.Pick(Flag);' + LineEnding +
    'end.' + LineEnding;
  WriteTextFile(
    UnitPath,
    'unit Worker;' + LineEnding +
    LineEnding +
    'interface' + LineEnding +
    'type' + LineEnding +
    '  TBase = class' + LineEnding +
    '    procedure Pick(Value: Integer);' + LineEnding +
    '    procedure Pick(Value: AnsiString);' + LineEnding +
    '  end;' + LineEnding +
    '  TWorker = class(TBase)' + LineEnding +
    '  end;' + LineEnding +
    LineEnding +
    'implementation' + LineEnding +
    'procedure TBase.Pick(Value: Integer);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'procedure TBase.Pick(Value: AnsiString);' + LineEnding +
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
      BuildResolvedUnit(
        'ImportedInheritedMemberFunctionResultNoMatchingOverloadCalls',
        '',
        ruoRootSource,
        '',
        'program',
        1
      )
    );
    UnitGraph.AddResolvedUnit(
      BuildResolvedUnit('Worker', UnitPath, ruoProjectSource, '', 'unit', 2)
    );
    Analyzer := TSemanticAnalyzer.Create(Ast, UnitGraph, Diagnostics, 1, True);
    Analyzer.Analyze;
    Model := Analyzer.DetachModel;
    if not Diagnostics.HasErrors then
      Fail('missing-imported-inherited-member-function-result-no-matching-overload-diagnostic');
    if not SameText(
      Diagnostics.LastDiagnosticCode,
      'sema.no-matching-overload'
    ) then
      Fail('unexpected-imported-inherited-member-function-result-no-matching-overload-diagnostic-code:' +
        Diagnostics.LastDiagnosticCode);
    if not SameText(Diagnostics.LastDiagnosticPhase, 'sema') then
      Fail('unexpected-imported-inherited-member-function-result-no-matching-overload-diagnostic-phase:' +
        Diagnostics.LastDiagnosticPhase);
    if Pos('Pick', Diagnostics.LastDiagnosticMessage) <= 0 then
      Fail('imported-inherited-member-function-result-no-matching-overload-diagnostic-missing-name');
    if Model = nil then
      Fail('missing-imported-inherited-member-function-result-no-matching-overload-semantic-model');
    if not SameText(Model.Status, 'failure') then
      Fail('unexpected-imported-inherited-member-function-result-no-matching-overload-model-status:' +
        Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-imported-inherited-member-function-result-no-matching-overload-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckImportedInheritedMemberFunctionResultAmbiguousOverloadDiagnostic;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  ProjectRoot: string;
  RootSourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
  UnitPath: string;
begin
  ProjectRoot := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'nextpas-semantic-imported-inherited-member-function-result-ambiguous-overload-' +
    IntToStr(Random(MaxInt));
  UnitPath := ProjectRoot + DirectorySeparator + 'worker.pas';
  RootSourceText :=
    'program ImportedInheritedMemberFunctionResultAmbiguousOverloadCalls;' + LineEnding +
    'uses Worker;' + LineEnding +
    'var' + LineEnding +
    '  Worker: TWorker;' + LineEnding +
    'function Count: Integer;' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    '  Worker.Pick(Count);' + LineEnding +
    'end.' + LineEnding;
  WriteTextFile(
    UnitPath,
    'unit Worker;' + LineEnding +
    LineEnding +
    'interface' + LineEnding +
    'type' + LineEnding +
    '  TBase = class' + LineEnding +
    '    procedure Pick(Value: Integer);' + LineEnding +
    '    procedure Pick(Value: LongInt);' + LineEnding +
    '  end;' + LineEnding +
    '  TWorker = class(TBase)' + LineEnding +
    '  end;' + LineEnding +
    LineEnding +
    'implementation' + LineEnding +
    'procedure TBase.Pick(Value: Integer);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'procedure TBase.Pick(Value: LongInt);' + LineEnding +
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
      BuildResolvedUnit(
        'ImportedInheritedMemberFunctionResultAmbiguousOverloadCalls',
        '',
        ruoRootSource,
        '',
        'program',
        1
      )
    );
    UnitGraph.AddResolvedUnit(
      BuildResolvedUnit('Worker', UnitPath, ruoProjectSource, '', 'unit', 2)
    );
    Analyzer := TSemanticAnalyzer.Create(Ast, UnitGraph, Diagnostics, 1, True);
    Analyzer.Analyze;
    Model := Analyzer.DetachModel;
    if not Diagnostics.HasErrors then
      Fail('missing-imported-inherited-member-function-result-ambiguous-overload-diagnostic');
    if not SameText(
      Diagnostics.LastDiagnosticCode,
      'sema.ambiguous-overload'
    ) then
      Fail('unexpected-imported-inherited-member-function-result-ambiguous-overload-diagnostic-code:' +
        Diagnostics.LastDiagnosticCode);
    if not SameText(Diagnostics.LastDiagnosticPhase, 'sema') then
      Fail('unexpected-imported-inherited-member-function-result-ambiguous-overload-diagnostic-phase:' +
        Diagnostics.LastDiagnosticPhase);
    if Pos('Pick', Diagnostics.LastDiagnosticMessage) <= 0 then
      Fail('imported-inherited-member-function-result-ambiguous-overload-diagnostic-missing-name');
    if Model = nil then
      Fail('missing-imported-inherited-member-function-result-ambiguous-overload-semantic-model');
    if not SameText(Model.Status, 'failure') then
      Fail('unexpected-imported-inherited-member-function-result-ambiguous-overload-model-status:' +
        Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-imported-inherited-member-function-result-ambiguous-overload-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckImportedInheritedMemberWrongArgumentCountDiagnostic;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  ProjectRoot: string;
  RootSourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
  UnitPath: string;
begin
  ProjectRoot := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'nextpas-semantic-imported-inherited-member-wrong-argument-count-' +
    IntToStr(Random(MaxInt));
  UnitPath := ProjectRoot + DirectorySeparator + 'worker.pas';
  RootSourceText :=
    'program ImportedInheritedMemberWrongArgumentCountCalls;' + LineEnding +
    'uses Worker;' + LineEnding +
    'var' + LineEnding +
    '  Worker: TWorker;' + LineEnding +
    'begin' + LineEnding +
    '  Worker.Pick(1, 2);' + LineEnding +
    'end.' + LineEnding;
  WriteTextFile(
    UnitPath,
    'unit Worker;' + LineEnding +
    LineEnding +
    'interface' + LineEnding +
    'type' + LineEnding +
    '  TBase = class' + LineEnding +
    '    procedure Pick(Value: Integer);' + LineEnding +
    '  end;' + LineEnding +
    '  TWorker = class(TBase)' + LineEnding +
    '  end;' + LineEnding +
    LineEnding +
    'implementation' + LineEnding +
    'procedure TBase.Pick(Value: Integer);' + LineEnding +
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
      BuildResolvedUnit(
        'ImportedInheritedMemberWrongArgumentCountCalls',
        '',
        ruoRootSource,
        '',
        'program',
        1
      )
    );
    UnitGraph.AddResolvedUnit(
      BuildResolvedUnit('Worker', UnitPath, ruoProjectSource, '', 'unit', 2)
    );
    Analyzer := TSemanticAnalyzer.Create(Ast, UnitGraph, Diagnostics, 1, True);
    Analyzer.Analyze;
    Model := Analyzer.DetachModel;
    if not Diagnostics.HasErrors then
      Fail('missing-imported-inherited-member-wrong-argument-count-diagnostic');
    if not SameText(
      Diagnostics.LastDiagnosticCode,
      'sema.wrong-argument-count'
    ) then
      Fail('unexpected-imported-inherited-member-wrong-argument-count-diagnostic-code:' +
        Diagnostics.LastDiagnosticCode);
    if not SameText(Diagnostics.LastDiagnosticPhase, 'sema') then
      Fail('unexpected-imported-inherited-member-wrong-argument-count-diagnostic-phase:' +
        Diagnostics.LastDiagnosticPhase);
    if Pos('Pick', Diagnostics.LastDiagnosticMessage) <= 0 then
      Fail('imported-inherited-member-wrong-argument-count-diagnostic-missing-name');
    if Model = nil then
      Fail('missing-imported-inherited-member-wrong-argument-count-semantic-model');
    if not SameText(Model.Status, 'failure') then
      Fail('unexpected-imported-inherited-member-wrong-argument-count-model-status:' +
        Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-imported-inherited-member-wrong-argument-count-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckImportedInheritedMemberCallTypeMismatchDiagnostic;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  ProjectRoot: string;
  RootSourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
  UnitPath: string;
begin
  ProjectRoot := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'nextpas-semantic-imported-inherited-member-type-mismatch-' +
    IntToStr(Random(MaxInt));
  UnitPath := ProjectRoot + DirectorySeparator + 'worker.pas';
  RootSourceText :=
    'program ImportedInheritedMemberTypeMismatchCalls;' + LineEnding +
    'uses Worker;' + LineEnding +
    'var' + LineEnding +
    '  Worker: TWorker;' + LineEnding +
    'begin' + LineEnding +
    '  Worker.Pick(True);' + LineEnding +
    'end.' + LineEnding;
  WriteTextFile(
    UnitPath,
    'unit Worker;' + LineEnding +
    LineEnding +
    'interface' + LineEnding +
    'type' + LineEnding +
    '  TBase = class' + LineEnding +
    '    procedure Pick(Value: Integer);' + LineEnding +
    '  end;' + LineEnding +
    '  TWorker = class(TBase)' + LineEnding +
    '  end;' + LineEnding +
    LineEnding +
    'implementation' + LineEnding +
    'procedure TBase.Pick(Value: Integer);' + LineEnding +
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
      BuildResolvedUnit(
        'ImportedInheritedMemberTypeMismatchCalls',
        '',
        ruoRootSource,
        '',
        'program',
        1
      )
    );
    UnitGraph.AddResolvedUnit(
      BuildResolvedUnit('Worker', UnitPath, ruoProjectSource, '', 'unit', 2)
    );
    Analyzer := TSemanticAnalyzer.Create(Ast, UnitGraph, Diagnostics, 1, True);
    Analyzer.Analyze;
    Model := Analyzer.DetachModel;
    if not Diagnostics.HasErrors then
      Fail('missing-imported-inherited-member-type-mismatch-diagnostic');
    if not SameText(
      Diagnostics.LastDiagnosticCode,
      'sema.type-mismatch'
    ) then
      Fail('unexpected-imported-inherited-member-type-mismatch-diagnostic-code:' +
        Diagnostics.LastDiagnosticCode);
    if not SameText(Diagnostics.LastDiagnosticPhase, 'sema') then
      Fail('unexpected-imported-inherited-member-type-mismatch-diagnostic-phase:' +
        Diagnostics.LastDiagnosticPhase);
    if Pos('Pick', Diagnostics.LastDiagnosticMessage) <= 0 then
      Fail('imported-inherited-member-type-mismatch-diagnostic-missing-name');
    if Model = nil then
      Fail('missing-imported-inherited-member-type-mismatch-semantic-model');
    if not SameText(Model.Status, 'failure') then
      Fail('unexpected-imported-inherited-member-type-mismatch-model-status:' +
        Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-imported-inherited-member-type-mismatch-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckImportedInheritedUnknownMemberDiagnostic;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  ProjectRoot: string;
  RootSourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
  UnitPath: string;
begin
  ProjectRoot := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'nextpas-semantic-imported-inherited-unknown-member-' +
    IntToStr(Random(MaxInt));
  UnitPath := ProjectRoot + DirectorySeparator + 'worker.pas';
  RootSourceText :=
    'program ImportedInheritedUnknownMemberCalls;' + LineEnding +
    'uses Worker;' + LineEnding +
    'var' + LineEnding +
    '  Worker: TWorker;' + LineEnding +
    'begin' + LineEnding +
    '  Worker.Missing(1);' + LineEnding +
    'end.' + LineEnding;
  WriteTextFile(
    UnitPath,
    'unit Worker;' + LineEnding +
    LineEnding +
    'interface' + LineEnding +
    'type' + LineEnding +
    '  TBase = class' + LineEnding +
    '    procedure Run;' + LineEnding +
    '  end;' + LineEnding +
    '  TWorker = class(TBase)' + LineEnding +
    '  end;' + LineEnding +
    LineEnding +
    'implementation' + LineEnding +
    'procedure TBase.Run;' + LineEnding +
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
      BuildResolvedUnit(
        'ImportedInheritedUnknownMemberCalls',
        '',
        ruoRootSource,
        '',
        'program',
        1
      )
    );
    UnitGraph.AddResolvedUnit(
      BuildResolvedUnit('Worker', UnitPath, ruoProjectSource, '', 'unit', 2)
    );
    Analyzer := TSemanticAnalyzer.Create(Ast, UnitGraph, Diagnostics, 1, True);
    Analyzer.Analyze;
    Model := Analyzer.DetachModel;
    if not Diagnostics.HasErrors then
      Fail('missing-imported-inherited-unknown-member-diagnostic');
    if not SameText(Diagnostics.LastDiagnosticCode, 'sema.unknown-member') then
      Fail('unexpected-imported-inherited-unknown-member-diagnostic-code:' +
        Diagnostics.LastDiagnosticCode);
    if not SameText(Diagnostics.LastDiagnosticPhase, 'sema') then
      Fail('unexpected-imported-inherited-unknown-member-diagnostic-phase:' +
        Diagnostics.LastDiagnosticPhase);
    if Pos('Missing', Diagnostics.LastDiagnosticMessage) <= 0 then
      Fail('imported-inherited-unknown-member-diagnostic-missing-name');
    if Model = nil then
      Fail('missing-imported-inherited-unknown-member-semantic-model');
    if not SameText(Model.Status, 'failure') then
      Fail('unexpected-imported-inherited-unknown-member-model-status:' +
        Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-imported-inherited-unknown-member-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckInstalledSourceInheritedUnknownMemberStaysDeferred;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  ProjectRoot: string;
  RootSourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
  UnitPath: string;
begin
  ProjectRoot := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'nextpas-semantic-installed-imported-inherited-unknown-member-' +
    IntToStr(Random(MaxInt));
  UnitPath := ProjectRoot + DirectorySeparator + 'worker.pas';
  RootSourceText :=
    'program InstalledImportedInheritedUnknownMemberCalls;' + LineEnding +
    'uses Worker;' + LineEnding +
    'var' + LineEnding +
    '  Worker: TWorker;' + LineEnding +
    'begin' + LineEnding +
    '  Worker.Missing(1);' + LineEnding +
    'end.' + LineEnding;
  WriteTextFile(
    UnitPath,
    'unit Worker;' + LineEnding +
    LineEnding +
    'interface' + LineEnding +
    'type' + LineEnding +
    '  TBase = class' + LineEnding +
    '    procedure Run;' + LineEnding +
    '  end;' + LineEnding +
    '  TWorker = class(TBase)' + LineEnding +
    '  end;' + LineEnding +
    LineEnding +
    'implementation' + LineEnding +
    'procedure TBase.Run;' + LineEnding +
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
      BuildResolvedUnit(
        'InstalledImportedInheritedUnknownMemberCalls',
        '',
        ruoRootSource,
        '',
        'program',
        1
      )
    );
    UnitGraph.AddResolvedUnit(
      BuildResolvedUnit('Worker', UnitPath, ruoInstalledSource, '', 'unit', 2)
    );
    Analyzer := TSemanticAnalyzer.Create(Ast, UnitGraph, Diagnostics, 1, True);
    Analyzer.Analyze;
    Model := Analyzer.DetachModel;
    if Diagnostics.HasErrors then
      Fail('unexpected-installed-imported-inherited-unknown-member-diagnostic:' +
        Diagnostics.LastDiagnosticCode);
    if Model = nil then
      Fail('missing-installed-imported-inherited-unknown-member-semantic-model');
    if not SameText(Model.Status, 'ready') then
      Fail('unexpected-installed-imported-inherited-unknown-member-model-status:' +
        Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-installed-imported-inherited-unknown-member-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckImportedMemberWrongArgumentCountDiagnostic;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  ProjectRoot: string;
  RootSourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
  UnitPath: string;
begin
  ProjectRoot := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'nextpas-semantic-imported-member-wrong-argument-count-' +
    IntToStr(Random(MaxInt));
  UnitPath := ProjectRoot + DirectorySeparator + 'worker.pas';
  RootSourceText :=
    'program ImportedMemberWrongArgumentCountCalls;' + LineEnding +
    'uses Worker;' + LineEnding +
    'var' + LineEnding +
    '  Worker: TWorker;' + LineEnding +
    'begin' + LineEnding +
    '  Worker.Pick(1, 2);' + LineEnding +
    'end.' + LineEnding;
  WriteTextFile(
    UnitPath,
    'unit Worker;' + LineEnding +
    LineEnding +
    'interface' + LineEnding +
    'type' + LineEnding +
    '  TWorker = class' + LineEnding +
    '    procedure Pick(Value: Integer);' + LineEnding +
    '  end;' + LineEnding +
    LineEnding +
    'implementation' + LineEnding +
    'procedure TWorker.Pick(Value: Integer);' + LineEnding +
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
      BuildResolvedUnit(
        'ImportedMemberWrongArgumentCountCalls',
        '',
        ruoRootSource,
        '',
        'program',
        1
      )
    );
    UnitGraph.AddResolvedUnit(
      BuildResolvedUnit('Worker', UnitPath, ruoProjectSource, '', 'unit', 2)
    );
    Analyzer := TSemanticAnalyzer.Create(Ast, UnitGraph, Diagnostics, 1, True);
    Analyzer.Analyze;
    Model := Analyzer.DetachModel;
    if not Diagnostics.HasErrors then
      Fail('missing-imported-member-wrong-argument-count-diagnostic');
    if not SameText(
      Diagnostics.LastDiagnosticCode,
      'sema.wrong-argument-count'
    ) then
      Fail('unexpected-imported-member-wrong-argument-count-diagnostic-code:' +
        Diagnostics.LastDiagnosticCode);
    if not SameText(Diagnostics.LastDiagnosticPhase, 'sema') then
      Fail('unexpected-imported-member-wrong-argument-count-diagnostic-phase:' +
        Diagnostics.LastDiagnosticPhase);
    if Pos('Pick', Diagnostics.LastDiagnosticMessage) <= 0 then
      Fail('imported-member-wrong-argument-count-diagnostic-missing-name');
    if Model = nil then
      Fail('missing-imported-member-wrong-argument-count-semantic-model');
    if not SameText(Model.Status, 'failure') then
      Fail('unexpected-imported-member-wrong-argument-count-model-status:' +
        Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-imported-member-wrong-argument-count-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckImportedUnknownMemberDiagnostic;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  ProjectRoot: string;
  RootSourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
  UnitPath: string;
begin
  ProjectRoot := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'nextpas-semantic-imported-unknown-member-' +
    IntToStr(Random(MaxInt));
  UnitPath := ProjectRoot + DirectorySeparator + 'worker.pas';
  RootSourceText :=
    'program ImportedUnknownMemberCalls;' + LineEnding +
    'uses Worker;' + LineEnding +
    'var' + LineEnding +
    '  Worker: TWorker;' + LineEnding +
    'begin' + LineEnding +
    '  Worker.Missing(1);' + LineEnding +
    'end.' + LineEnding;
  WriteTextFile(
    UnitPath,
    'unit Worker;' + LineEnding +
    LineEnding +
    'interface' + LineEnding +
    'type' + LineEnding +
    '  TWorker = class' + LineEnding +
    '    procedure Run;' + LineEnding +
    '  end;' + LineEnding +
    LineEnding +
    'implementation' + LineEnding +
    'procedure TWorker.Run;' + LineEnding +
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
      BuildResolvedUnit(
        'ImportedUnknownMemberCalls',
        '',
        ruoRootSource,
        '',
        'program',
        1
      )
    );
    UnitGraph.AddResolvedUnit(
      BuildResolvedUnit('Worker', UnitPath, ruoProjectSource, '', 'unit', 2)
    );
    Analyzer := TSemanticAnalyzer.Create(Ast, UnitGraph, Diagnostics, 1, True);
    Analyzer.Analyze;
    Model := Analyzer.DetachModel;
    if not Diagnostics.HasErrors then
      Fail('missing-imported-unknown-member-diagnostic');
    if not SameText(Diagnostics.LastDiagnosticCode, 'sema.unknown-member') then
      Fail('unexpected-imported-unknown-member-diagnostic-code:' +
        Diagnostics.LastDiagnosticCode);
    if not SameText(Diagnostics.LastDiagnosticPhase, 'sema') then
      Fail('unexpected-imported-unknown-member-diagnostic-phase:' +
        Diagnostics.LastDiagnosticPhase);
    if Pos('Missing', Diagnostics.LastDiagnosticMessage) <= 0 then
      Fail('imported-unknown-member-diagnostic-missing-name');
    if Model = nil then
      Fail('missing-imported-unknown-member-semantic-model');
    if not SameText(Model.Status, 'failure') then
      Fail('unexpected-imported-unknown-member-model-status:' +
        Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-imported-unknown-member-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckInstalledSourceUnknownMemberStaysDeferred;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  ProjectRoot: string;
  RootSourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
  UnitPath: string;
begin
  ProjectRoot := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'nextpas-semantic-installed-unknown-member-' +
    IntToStr(Random(MaxInt));
  UnitPath := ProjectRoot + DirectorySeparator + 'worker.pas';
  RootSourceText :=
    'program InstalledUnknownMemberCalls;' + LineEnding +
    'uses Worker;' + LineEnding +
    'var' + LineEnding +
    '  Worker: TWorker;' + LineEnding +
    'begin' + LineEnding +
    '  Worker.Missing(1);' + LineEnding +
    'end.' + LineEnding;
  WriteTextFile(
    UnitPath,
    'unit Worker;' + LineEnding +
    LineEnding +
    'interface' + LineEnding +
    'type' + LineEnding +
    '  TWorker = class' + LineEnding +
    '    procedure Run;' + LineEnding +
    '  end;' + LineEnding +
    LineEnding +
    'implementation' + LineEnding +
    'procedure TWorker.Run;' + LineEnding +
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
      BuildResolvedUnit(
        'InstalledUnknownMemberCalls',
        '',
        ruoRootSource,
        '',
        'program',
        1
      )
    );
    UnitGraph.AddResolvedUnit(
      BuildResolvedUnit('Worker', UnitPath, ruoInstalledSource, '', 'unit', 2)
    );
    Analyzer := TSemanticAnalyzer.Create(Ast, UnitGraph, Diagnostics, 1, True);
    Analyzer.Analyze;
    Model := Analyzer.DetachModel;
    if Diagnostics.HasErrors then
      Fail('unexpected-installed-unknown-member-diagnostic:' +
        Diagnostics.LastDiagnosticCode);
    if Model = nil then
      Fail('missing-installed-unknown-member-semantic-model');
    if not SameText(Model.Status, 'ready') then
      Fail('unexpected-installed-unknown-member-model-status:' +
        Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-installed-unknown-member-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckInstalledSourceMemberCallTypeMismatchStaysDeferred;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  ProjectRoot: string;
  RootSourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
  UnitPath: string;
begin
  ProjectRoot := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'nextpas-semantic-installed-imported-member-type-mismatch-' +
    IntToStr(Random(MaxInt));
  UnitPath := ProjectRoot + DirectorySeparator + 'worker.pas';
  RootSourceText :=
    'program InstalledImportedMemberTypeMismatchCalls;' + LineEnding +
    'uses Worker;' + LineEnding +
    'var' + LineEnding +
    '  Worker: TWorker;' + LineEnding +
    'begin' + LineEnding +
    '  Worker.Pick(True);' + LineEnding +
    'end.' + LineEnding;
  WriteTextFile(
    UnitPath,
    'unit Worker;' + LineEnding +
    LineEnding +
    'interface' + LineEnding +
    'type' + LineEnding +
    '  TWorker = class' + LineEnding +
    '    procedure Pick(Value: Integer);' + LineEnding +
    '  end;' + LineEnding +
    LineEnding +
    'implementation' + LineEnding +
    'procedure TWorker.Pick(Value: Integer);' + LineEnding +
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
      BuildResolvedUnit(
        'InstalledImportedMemberTypeMismatchCalls',
        '',
        ruoRootSource,
        '',
        'program',
        1
      )
    );
    UnitGraph.AddResolvedUnit(
      BuildResolvedUnit('Worker', UnitPath, ruoInstalledSource, '', 'unit', 2)
    );
    Analyzer := TSemanticAnalyzer.Create(Ast, UnitGraph, Diagnostics, 1, True);
    Analyzer.Analyze;
    Model := Analyzer.DetachModel;
    if Diagnostics.HasErrors then
      Fail('unexpected-installed-imported-member-call-type-mismatch-diagnostic:' +
        Diagnostics.LastDiagnosticCode);
    if Model = nil then
      Fail('missing-installed-imported-member-call-type-mismatch-semantic-model');
    if not SameText(Model.Status, 'ready') then
      Fail('unexpected-installed-imported-member-call-type-mismatch-model-status:' +
        Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-installed-imported-member-call-type-mismatch-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckInstalledSourceMemberNoMatchingOverloadStaysDeferred;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  ProjectRoot: string;
  RootSourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
  UnitPath: string;
begin
  ProjectRoot := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'nextpas-semantic-installed-imported-member-no-matching-overload-' +
    IntToStr(Random(MaxInt));
  UnitPath := ProjectRoot + DirectorySeparator + 'worker.pas';
  RootSourceText :=
    'program InstalledImportedMemberNoMatchingOverloadCalls;' + LineEnding +
    'uses Worker;' + LineEnding +
    'var' + LineEnding +
    '  Worker: TWorker;' + LineEnding +
    'begin' + LineEnding +
    '  Worker.Pick(True);' + LineEnding +
    'end.' + LineEnding;
  WriteTextFile(
    UnitPath,
    'unit Worker;' + LineEnding +
    LineEnding +
    'interface' + LineEnding +
    'type' + LineEnding +
    '  TWorker = class' + LineEnding +
    '    procedure Pick(Value: Integer);' + LineEnding +
    '    procedure Pick(Value: AnsiString);' + LineEnding +
    '  end;' + LineEnding +
    LineEnding +
    'implementation' + LineEnding +
    'procedure TWorker.Pick(Value: Integer);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'procedure TWorker.Pick(Value: AnsiString);' + LineEnding +
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
      BuildResolvedUnit(
        'InstalledImportedMemberNoMatchingOverloadCalls',
        '',
        ruoRootSource,
        '',
        'program',
        1
      )
    );
    UnitGraph.AddResolvedUnit(
      BuildResolvedUnit('Worker', UnitPath, ruoInstalledSource, '', 'unit', 2)
    );
    Analyzer := TSemanticAnalyzer.Create(Ast, UnitGraph, Diagnostics, 1, True);
    Analyzer.Analyze;
    Model := Analyzer.DetachModel;
    if Diagnostics.HasErrors then
      Fail('unexpected-installed-imported-member-no-matching-overload-diagnostic:' +
        Diagnostics.LastDiagnosticCode);
    if Model = nil then
      Fail('missing-installed-imported-member-no-matching-overload-semantic-model');
    if not SameText(Model.Status, 'ready') then
      Fail('unexpected-installed-imported-member-no-matching-overload-model-status:' +
        Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-installed-imported-member-no-matching-overload-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckInstalledSourceInheritedMemberNoMatchingOverloadStaysDeferred;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  ProjectRoot: string;
  RootSourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
  UnitPath: string;
begin
  ProjectRoot := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'nextpas-semantic-installed-imported-inherited-member-no-matching-overload-' +
    IntToStr(Random(MaxInt));
  UnitPath := ProjectRoot + DirectorySeparator + 'worker.pas';
  RootSourceText :=
    'program InstalledImportedInheritedMemberNoMatchingOverloadCalls;' + LineEnding +
    'uses Worker;' + LineEnding +
    'var' + LineEnding +
    '  Worker: TWorker;' + LineEnding +
    'begin' + LineEnding +
    '  Worker.Pick(True);' + LineEnding +
    'end.' + LineEnding;
  WriteTextFile(
    UnitPath,
    'unit Worker;' + LineEnding +
    LineEnding +
    'interface' + LineEnding +
    'type' + LineEnding +
    '  TBase = class' + LineEnding +
    '    procedure Pick(Value: Integer);' + LineEnding +
    '    procedure Pick(Value: AnsiString);' + LineEnding +
    '  end;' + LineEnding +
    '  TWorker = class(TBase)' + LineEnding +
    '  end;' + LineEnding +
    LineEnding +
    'implementation' + LineEnding +
    'procedure TBase.Pick(Value: Integer);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'procedure TBase.Pick(Value: AnsiString);' + LineEnding +
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
      BuildResolvedUnit(
        'InstalledImportedInheritedMemberNoMatchingOverloadCalls',
        '',
        ruoRootSource,
        '',
        'program',
        1
      )
    );
    UnitGraph.AddResolvedUnit(
      BuildResolvedUnit('Worker', UnitPath, ruoInstalledSource, '', 'unit', 2)
    );
    Analyzer := TSemanticAnalyzer.Create(Ast, UnitGraph, Diagnostics, 1, True);
    Analyzer.Analyze;
    Model := Analyzer.DetachModel;
    if Diagnostics.HasErrors then
      Fail('unexpected-installed-imported-inherited-member-no-matching-overload-diagnostic:' +
        Diagnostics.LastDiagnosticCode);
    if Model = nil then
      Fail('missing-installed-imported-inherited-member-no-matching-overload-semantic-model');
    if not SameText(Model.Status, 'ready') then
      Fail('unexpected-installed-imported-inherited-member-no-matching-overload-model-status:' +
        Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-installed-imported-inherited-member-no-matching-overload-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckImportedMemberFunctionResultCallTypeMismatchDiagnostic;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  ProjectRoot: string;
  RootSourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
  UnitPath: string;
begin
  ProjectRoot := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'nextpas-semantic-imported-member-function-result-type-mismatch-' +
    IntToStr(Random(MaxInt));
  UnitPath := ProjectRoot + DirectorySeparator + 'worker.pas';
  RootSourceText :=
    'program ImportedMemberFunctionResultTypeMismatchCalls;' + LineEnding +
    'uses Worker;' + LineEnding +
    'var' + LineEnding +
    '  Worker: TWorker;' + LineEnding +
    'function Flag: Boolean;' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    '  Worker.Pick(Flag);' + LineEnding +
    'end.' + LineEnding;
  WriteTextFile(
    UnitPath,
    'unit Worker;' + LineEnding +
    LineEnding +
    'interface' + LineEnding +
    'type' + LineEnding +
    '  TWorker = class' + LineEnding +
    '    procedure Pick(Value: Integer);' + LineEnding +
    '  end;' + LineEnding +
    LineEnding +
    'implementation' + LineEnding +
    'procedure TWorker.Pick(Value: Integer);' + LineEnding +
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
      BuildResolvedUnit(
        'ImportedMemberFunctionResultTypeMismatchCalls',
        '',
        ruoRootSource,
        '',
        'program',
        1
      )
    );
    UnitGraph.AddResolvedUnit(
      BuildResolvedUnit('Worker', UnitPath, ruoProjectSource, '', 'unit', 2)
    );
    Analyzer := TSemanticAnalyzer.Create(Ast, UnitGraph, Diagnostics, 1, True);
    Analyzer.Analyze;
    Model := Analyzer.DetachModel;
    if not Diagnostics.HasErrors then
      Fail('missing-imported-member-function-result-type-mismatch-diagnostic');
    if not SameText(Diagnostics.LastDiagnosticCode, 'sema.type-mismatch') then
      Fail('unexpected-imported-member-function-result-type-mismatch-diagnostic-code:' +
        Diagnostics.LastDiagnosticCode);
    if not SameText(Diagnostics.LastDiagnosticPhase, 'sema') then
      Fail('unexpected-imported-member-function-result-type-mismatch-diagnostic-phase:' +
        Diagnostics.LastDiagnosticPhase);
    if Pos('Pick', Diagnostics.LastDiagnosticMessage) <= 0 then
      Fail('imported-member-function-result-type-mismatch-diagnostic-missing-name');
    if Model = nil then
      Fail('missing-imported-member-function-result-type-mismatch-semantic-model');
    if not SameText(Model.Status, 'failure') then
      Fail('unexpected-imported-member-function-result-type-mismatch-model-status:' +
        Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-imported-member-function-result-type-mismatch-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckImportedInheritedMemberFunctionResultCallTypeMismatchDiagnostic;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  ProjectRoot: string;
  RootSourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
  UnitPath: string;
begin
  ProjectRoot := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'nextpas-semantic-imported-inherited-member-function-result-type-mismatch-' +
    IntToStr(Random(MaxInt));
  UnitPath := ProjectRoot + DirectorySeparator + 'worker.pas';
  RootSourceText :=
    'program ImportedInheritedMemberFunctionResultTypeMismatchCalls;' + LineEnding +
    'uses Worker;' + LineEnding +
    'var' + LineEnding +
    '  Worker: TWorker;' + LineEnding +
    'function Flag: Boolean;' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    '  Worker.Pick(Flag);' + LineEnding +
    'end.' + LineEnding;
  WriteTextFile(
    UnitPath,
    'unit Worker;' + LineEnding +
    LineEnding +
    'interface' + LineEnding +
    'type' + LineEnding +
    '  TBase = class' + LineEnding +
    '    procedure Pick(Value: Integer);' + LineEnding +
    '  end;' + LineEnding +
    '  TWorker = class(TBase)' + LineEnding +
    '  end;' + LineEnding +
    LineEnding +
    'implementation' + LineEnding +
    'procedure TBase.Pick(Value: Integer);' + LineEnding +
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
      BuildResolvedUnit(
        'ImportedInheritedMemberFunctionResultTypeMismatchCalls',
        '',
        ruoRootSource,
        '',
        'program',
        1
      )
    );
    UnitGraph.AddResolvedUnit(
      BuildResolvedUnit('Worker', UnitPath, ruoProjectSource, '', 'unit', 2)
    );
    Analyzer := TSemanticAnalyzer.Create(Ast, UnitGraph, Diagnostics, 1, True);
    Analyzer.Analyze;
    Model := Analyzer.DetachModel;
    if not Diagnostics.HasErrors then
      Fail('missing-imported-inherited-member-function-result-type-mismatch-diagnostic');
    if not SameText(Diagnostics.LastDiagnosticCode, 'sema.type-mismatch') then
      Fail('unexpected-imported-inherited-member-function-result-type-mismatch-diagnostic-code:' +
        Diagnostics.LastDiagnosticCode);
    if not SameText(Diagnostics.LastDiagnosticPhase, 'sema') then
      Fail('unexpected-imported-inherited-member-function-result-type-mismatch-diagnostic-phase:' +
        Diagnostics.LastDiagnosticPhase);
    if Pos('Pick', Diagnostics.LastDiagnosticMessage) <= 0 then
      Fail('imported-inherited-member-function-result-type-mismatch-diagnostic-missing-name');
    if Model = nil then
      Fail('missing-imported-inherited-member-function-result-type-mismatch-semantic-model');
    if not SameText(Model.Status, 'failure') then
      Fail('unexpected-imported-inherited-member-function-result-type-mismatch-model-status:' +
        Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-imported-inherited-member-function-result-type-mismatch-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckInstalledSourceInheritedMemberAmbiguousOverloadStaysDeferred;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  ProjectRoot: string;
  RootSourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
  UnitPath: string;
begin
  ProjectRoot := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'nextpas-semantic-installed-imported-inherited-member-ambiguous-overload-' +
    IntToStr(Random(MaxInt));
  UnitPath := ProjectRoot + DirectorySeparator + 'worker.pas';
  RootSourceText :=
    'program InstalledImportedInheritedMemberAmbiguousOverloadCalls;' + LineEnding +
    'uses Worker;' + LineEnding +
    'var' + LineEnding +
    '  Worker: TWorker;' + LineEnding +
    'begin' + LineEnding +
    '  Worker.Pick(1);' + LineEnding +
    'end.' + LineEnding;
  WriteTextFile(
    UnitPath,
    'unit Worker;' + LineEnding +
    LineEnding +
    'interface' + LineEnding +
    'type' + LineEnding +
    '  TBase = class' + LineEnding +
    '    procedure Pick(Value: Integer);' + LineEnding +
    '    procedure Pick(Value: LongInt);' + LineEnding +
    '  end;' + LineEnding +
    '  TWorker = class(TBase)' + LineEnding +
    '  end;' + LineEnding +
    LineEnding +
    'implementation' + LineEnding +
    'procedure TBase.Pick(Value: Integer);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'procedure TBase.Pick(Value: LongInt);' + LineEnding +
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
      BuildResolvedUnit(
        'InstalledImportedInheritedMemberAmbiguousOverloadCalls',
        '',
        ruoRootSource,
        '',
        'program',
        1
      )
    );
    UnitGraph.AddResolvedUnit(
      BuildResolvedUnit('Worker', UnitPath, ruoInstalledSource, '', 'unit', 2)
    );
    Analyzer := TSemanticAnalyzer.Create(Ast, UnitGraph, Diagnostics, 1, True);
    Analyzer.Analyze;
    Model := Analyzer.DetachModel;
    if Diagnostics.HasErrors then
      Fail('unexpected-installed-imported-inherited-member-ambiguous-overload-diagnostic:' +
        Diagnostics.LastDiagnosticCode);
    if Model = nil then
      Fail('missing-installed-imported-inherited-member-ambiguous-overload-semantic-model');
    if not SameText(Model.Status, 'ready') then
      Fail('unexpected-installed-imported-inherited-member-ambiguous-overload-model-status:' +
        Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-installed-imported-inherited-member-ambiguous-overload-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckInstalledSourceInheritedMemberWrongArgumentCountStaysDeferred;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  ProjectRoot: string;
  RootSourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
  UnitPath: string;
begin
  ProjectRoot := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'nextpas-semantic-installed-imported-inherited-member-wrong-argument-count-' +
    IntToStr(Random(MaxInt));
  UnitPath := ProjectRoot + DirectorySeparator + 'worker.pas';
  RootSourceText :=
    'program InstalledImportedInheritedMemberWrongArgumentCountCalls;' + LineEnding +
    'uses Worker;' + LineEnding +
    'var' + LineEnding +
    '  Worker: TWorker;' + LineEnding +
    'begin' + LineEnding +
    '  Worker.Pick(1, 2);' + LineEnding +
    'end.' + LineEnding;
  WriteTextFile(
    UnitPath,
    'unit Worker;' + LineEnding +
    LineEnding +
    'interface' + LineEnding +
    'type' + LineEnding +
    '  TBase = class' + LineEnding +
    '    procedure Pick(Value: Integer);' + LineEnding +
    '  end;' + LineEnding +
    '  TWorker = class(TBase)' + LineEnding +
    '  end;' + LineEnding +
    LineEnding +
    'implementation' + LineEnding +
    'procedure TBase.Pick(Value: Integer);' + LineEnding +
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
      BuildResolvedUnit(
        'InstalledImportedInheritedMemberWrongArgumentCountCalls',
        '',
        ruoRootSource,
        '',
        'program',
        1
      )
    );
    UnitGraph.AddResolvedUnit(
      BuildResolvedUnit('Worker', UnitPath, ruoInstalledSource, '', 'unit', 2)
    );
    Analyzer := TSemanticAnalyzer.Create(Ast, UnitGraph, Diagnostics, 1, True);
    Analyzer.Analyze;
    Model := Analyzer.DetachModel;
    if Diagnostics.HasErrors then
      Fail('unexpected-installed-imported-inherited-member-wrong-argument-count-diagnostic:' +
        Diagnostics.LastDiagnosticCode);
    if Model = nil then
      Fail('missing-installed-imported-inherited-member-wrong-argument-count-semantic-model');
    if not SameText(Model.Status, 'ready') then
      Fail('unexpected-installed-imported-inherited-member-wrong-argument-count-model-status:' +
        Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-installed-imported-inherited-member-wrong-argument-count-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckInstalledSourceInheritedMemberCallTypeMismatchStaysDeferred;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  ProjectRoot: string;
  RootSourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
  UnitPath: string;
begin
  ProjectRoot := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'nextpas-semantic-installed-imported-inherited-member-type-mismatch-' +
    IntToStr(Random(MaxInt));
  UnitPath := ProjectRoot + DirectorySeparator + 'worker.pas';
  RootSourceText :=
    'program InstalledImportedInheritedMemberTypeMismatchCalls;' + LineEnding +
    'uses Worker;' + LineEnding +
    'var' + LineEnding +
    '  Worker: TWorker;' + LineEnding +
    'begin' + LineEnding +
    '  Worker.Pick(True);' + LineEnding +
    'end.' + LineEnding;
  WriteTextFile(
    UnitPath,
    'unit Worker;' + LineEnding +
    LineEnding +
    'interface' + LineEnding +
    'type' + LineEnding +
    '  TBase = class' + LineEnding +
    '    procedure Pick(Value: Integer);' + LineEnding +
    '  end;' + LineEnding +
    '  TWorker = class(TBase)' + LineEnding +
    '  end;' + LineEnding +
    LineEnding +
    'implementation' + LineEnding +
    'procedure TBase.Pick(Value: Integer);' + LineEnding +
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
      BuildResolvedUnit(
        'InstalledImportedInheritedMemberTypeMismatchCalls',
        '',
        ruoRootSource,
        '',
        'program',
        1
      )
    );
    UnitGraph.AddResolvedUnit(
      BuildResolvedUnit('Worker', UnitPath, ruoInstalledSource, '', 'unit', 2)
    );
    Analyzer := TSemanticAnalyzer.Create(Ast, UnitGraph, Diagnostics, 1, True);
    Analyzer.Analyze;
    Model := Analyzer.DetachModel;
    if Diagnostics.HasErrors then
      Fail('unexpected-installed-imported-inherited-member-type-mismatch-diagnostic:' +
        Diagnostics.LastDiagnosticCode);
    if Model = nil then
      Fail('missing-installed-imported-inherited-member-type-mismatch-semantic-model');
    if not SameText(Model.Status, 'ready') then
      Fail('unexpected-installed-imported-inherited-member-type-mismatch-model-status:' +
        Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-installed-imported-inherited-member-type-mismatch-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckInstalledSourceMemberWrongArgumentCountStaysDeferred;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  ProjectRoot: string;
  RootSourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
  UnitPath: string;
begin
  ProjectRoot := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'nextpas-semantic-installed-imported-member-wrong-argument-count-' +
    IntToStr(Random(MaxInt));
  UnitPath := ProjectRoot + DirectorySeparator + 'worker.pas';
  RootSourceText :=
    'program InstalledImportedMemberWrongArgumentCountCalls;' + LineEnding +
    'uses Worker;' + LineEnding +
    'var' + LineEnding +
    '  Worker: TWorker;' + LineEnding +
    'begin' + LineEnding +
    '  Worker.Pick(1, 2);' + LineEnding +
    'end.' + LineEnding;
  WriteTextFile(
    UnitPath,
    'unit Worker;' + LineEnding +
    LineEnding +
    'interface' + LineEnding +
    'type' + LineEnding +
    '  TWorker = class' + LineEnding +
    '    procedure Pick(Value: Integer);' + LineEnding +
    '  end;' + LineEnding +
    LineEnding +
    'implementation' + LineEnding +
    'procedure TWorker.Pick(Value: Integer);' + LineEnding +
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
      BuildResolvedUnit(
        'InstalledImportedMemberWrongArgumentCountCalls',
        '',
        ruoRootSource,
        '',
        'program',
        1
      )
    );
    UnitGraph.AddResolvedUnit(
      BuildResolvedUnit('Worker', UnitPath, ruoInstalledSource, '', 'unit', 2)
    );
    Analyzer := TSemanticAnalyzer.Create(Ast, UnitGraph, Diagnostics, 1, True);
    Analyzer.Analyze;
    Model := Analyzer.DetachModel;
    if Diagnostics.HasErrors then
      Fail('unexpected-installed-imported-member-wrong-argument-count-diagnostic:' +
        Diagnostics.LastDiagnosticCode);
    if Model = nil then
      Fail('missing-installed-imported-member-wrong-argument-count-semantic-model');
    if not SameText(Model.Status, 'ready') then
      Fail('unexpected-installed-imported-member-wrong-argument-count-model-status:' +
        Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-installed-imported-member-wrong-argument-count-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckInstalledSourceInheritedMemberFunctionResultCallTypeMismatchStaysDeferred;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  ProjectRoot: string;
  RootSourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
  UnitPath: string;
begin
  ProjectRoot := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'nextpas-semantic-installed-imported-inherited-member-function-result-type-mismatch-' +
    IntToStr(Random(MaxInt));
  UnitPath := ProjectRoot + DirectorySeparator + 'worker.pas';
  RootSourceText :=
    'program InstalledImportedInheritedMemberFunctionResultTypeMismatchCalls;' + LineEnding +
    'uses Worker;' + LineEnding +
    'var' + LineEnding +
    '  Worker: TWorker;' + LineEnding +
    'function Flag: Boolean;' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    '  Worker.Pick(Flag);' + LineEnding +
    'end.' + LineEnding;
  WriteTextFile(
    UnitPath,
    'unit Worker;' + LineEnding +
    LineEnding +
    'interface' + LineEnding +
    'type' + LineEnding +
    '  TBase = class' + LineEnding +
    '    procedure Pick(Value: Integer);' + LineEnding +
    '  end;' + LineEnding +
    '  TWorker = class(TBase)' + LineEnding +
    '  end;' + LineEnding +
    LineEnding +
    'implementation' + LineEnding +
    'procedure TBase.Pick(Value: Integer);' + LineEnding +
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
      BuildResolvedUnit(
        'InstalledImportedInheritedMemberFunctionResultTypeMismatchCalls',
        '',
        ruoRootSource,
        '',
        'program',
        1
      )
    );
    UnitGraph.AddResolvedUnit(
      BuildResolvedUnit('Worker', UnitPath, ruoInstalledSource, '', 'unit', 2)
    );
    Analyzer := TSemanticAnalyzer.Create(Ast, UnitGraph, Diagnostics, 1, True);
    Analyzer.Analyze;
    Model := Analyzer.DetachModel;
    if Diagnostics.HasErrors then
      Fail('unexpected-installed-imported-inherited-member-function-result-type-mismatch-diagnostic:' +
        Diagnostics.LastDiagnosticCode);
    if Model = nil then
      Fail('missing-installed-imported-inherited-member-function-result-type-mismatch-semantic-model');
    if not SameText(Model.Status, 'ready') then
      Fail('unexpected-installed-imported-inherited-member-function-result-type-mismatch-model-status:' +
        Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-installed-imported-inherited-member-function-result-type-mismatch-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckInstalledSourceInheritedMemberFunctionResultNoMatchingOverloadStaysDeferred;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  ProjectRoot: string;
  RootSourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
  UnitPath: string;
begin
  ProjectRoot := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'nextpas-semantic-installed-imported-inherited-member-function-result-no-matching-overload-' +
    IntToStr(Random(MaxInt));
  UnitPath := ProjectRoot + DirectorySeparator + 'worker.pas';
  RootSourceText :=
    'program InstalledImportedInheritedMemberFunctionResultNoMatchingOverloadCalls;' + LineEnding +
    'uses Worker;' + LineEnding +
    'var' + LineEnding +
    '  Worker: TWorker;' + LineEnding +
    'function Flag: Boolean;' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    '  Worker.Pick(Flag);' + LineEnding +
    'end.' + LineEnding;
  WriteTextFile(
    UnitPath,
    'unit Worker;' + LineEnding +
    LineEnding +
    'interface' + LineEnding +
    'type' + LineEnding +
    '  TBase = class' + LineEnding +
    '    procedure Pick(Value: Integer);' + LineEnding +
    '    procedure Pick(Value: AnsiString);' + LineEnding +
    '  end;' + LineEnding +
    '  TWorker = class(TBase)' + LineEnding +
    '  end;' + LineEnding +
    LineEnding +
    'implementation' + LineEnding +
    'procedure TBase.Pick(Value: Integer);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'procedure TBase.Pick(Value: AnsiString);' + LineEnding +
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
      BuildResolvedUnit(
        'InstalledImportedInheritedMemberFunctionResultNoMatchingOverloadCalls',
        '',
        ruoRootSource,
        '',
        'program',
        1
      )
    );
    UnitGraph.AddResolvedUnit(
      BuildResolvedUnit('Worker', UnitPath, ruoInstalledSource, '', 'unit', 2)
    );
    Analyzer := TSemanticAnalyzer.Create(Ast, UnitGraph, Diagnostics, 1, True);
    Analyzer.Analyze;
    Model := Analyzer.DetachModel;
    if Diagnostics.HasErrors then
      Fail('unexpected-installed-imported-inherited-member-function-result-no-matching-overload-diagnostic:' +
        Diagnostics.LastDiagnosticCode);
    if Model = nil then
      Fail('missing-installed-imported-inherited-member-function-result-no-matching-overload-semantic-model');
    if not SameText(Model.Status, 'ready') then
      Fail('unexpected-installed-imported-inherited-member-function-result-no-matching-overload-model-status:' +
        Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-installed-imported-inherited-member-function-result-no-matching-overload-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckBareNoMatchingOverloadDiagnostic;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  SourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
begin
  SourceText :=
    'program BareNoMatchingOverloadCalls;' + LineEnding +
    'procedure Pick(Value: Integer);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'procedure Pick(Value: AnsiString);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    '  Pick(True);' + LineEnding +
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
    if not Diagnostics.HasErrors then
      Fail('missing-bare-no-matching-overload-diagnostic');
    if not SameText(Diagnostics.LastDiagnosticCode, 'sema.no-matching-overload') then
      Fail('unexpected-bare-no-matching-overload-diagnostic-code:' +
        Diagnostics.LastDiagnosticCode);
    if not SameText(Diagnostics.LastDiagnosticPhase, 'sema') then
      Fail('unexpected-bare-no-matching-overload-diagnostic-phase:' +
        Diagnostics.LastDiagnosticPhase);
    if Pos('Pick', Diagnostics.LastDiagnosticMessage) <= 0 then
      Fail('bare-no-matching-overload-diagnostic-missing-name');
    if Model = nil then
      Fail('missing-bare-no-matching-overload-semantic-model');
    if not SameText(Model.Status, 'failure') then
      Fail('unexpected-bare-no-matching-overload-model-status:' +
        Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-bare-no-matching-overload-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckBareWrongArgumentCountDiagnostic;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  SourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
begin
  SourceText :=
    'program WrongArgumentCountCalls;' + LineEnding +
    'procedure Pick;' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'procedure Pick(Value: Integer);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    '  Pick(1, 2);' + LineEnding +
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
    if not Diagnostics.HasErrors then
      Fail('missing-bare-wrong-argument-count-diagnostic');
    if not SameText(Diagnostics.LastDiagnosticCode, 'sema.wrong-argument-count') then
      Fail('unexpected-bare-wrong-argument-count-diagnostic-code:' +
        Diagnostics.LastDiagnosticCode);
    if not SameText(Diagnostics.LastDiagnosticPhase, 'sema') then
      Fail('unexpected-bare-wrong-argument-count-diagnostic-phase:' +
        Diagnostics.LastDiagnosticPhase);
    if Pos('Pick', Diagnostics.LastDiagnosticMessage) <= 0 then
      Fail('bare-wrong-argument-count-diagnostic-missing-name');
    if Model = nil then
      Fail('missing-bare-wrong-argument-count-semantic-model');
    if not SameText(Model.Status, 'failure') then
      Fail('unexpected-bare-wrong-argument-count-model-status:' +
        Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-bare-wrong-argument-count-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckBareDefaultParameterCallBindings;
var
  AddBindingCount: LongInt;
  AddSymbolId: LongInt;
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Binding: TSemanticBinding;
  Diagnostics: TDiagnosticsSink;
  Index: LongInt;
  Lexer: TLexerResult;
  LogBindingCount: LongInt;
  LogSymbolId: LongInt;
  Model: TSemanticModel;
  SourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
begin
  SourceText :=
    'program DefaultParameterCalls;' + LineEnding +
    'function Add(A: Integer; B: Integer = 0; C: Integer = 0): Integer;' +
      LineEnding +
    'begin' + LineEnding +
    '  Add := A + B + C;' + LineEnding +
    'end;' + LineEnding +
    'procedure Log(const Msg: string; Level: Integer = 0);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'var' + LineEnding +
    '  X: Integer;' + LineEnding +
    'begin' + LineEnding +
    '  X := Add(1);' + LineEnding +
    '  X := Add(1, 2);' + LineEnding +
    '  X := Add(1, 2, 3);' + LineEnding +
    '  Log(''hello'');' + LineEnding +
    '  Log(''world'', 1);' + LineEnding +
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
      Fail('unexpected-default-parameter-diagnostics');
    if Model = nil then
      Fail('missing-default-parameter-semantic-model');

    AddSymbolId := SymbolIdByNameAndKind(Model, 'Add', 'function');
    if AddSymbolId <= 0 then
      Fail('missing-default-parameter-add-symbol');
    LogSymbolId := SymbolIdByNameAndKind(Model, 'Log', 'procedure');
    if LogSymbolId <= 0 then
      Fail('missing-default-parameter-log-symbol');

    AddBindingCount := 0;
    LogBindingCount := 0;
    for Index := 0 to Model.BindingCount - 1 do
    begin
      Binding := Model.BindingAt(Index);
      if SameText(Binding.Kind, 'call') and SameText(Binding.Name, 'Add') then
      begin
        Inc(AddBindingCount);
        if Binding.TargetSymbolId <> AddSymbolId then
          Fail('default-parameter-add-target-mismatch');
      end
      else if SameText(Binding.Kind, 'call') and
        SameText(Binding.Name, 'Log') then
      begin
        Inc(LogBindingCount);
        if Binding.TargetSymbolId <> LogSymbolId then
          Fail('default-parameter-log-target-mismatch');
      end;
    end;

    if AddBindingCount <> 3 then
      Fail('unexpected-default-parameter-add-binding-count:' +
        IntToStr(AddBindingCount));
    if LogBindingCount <> 2 then
      Fail('unexpected-default-parameter-log-binding-count:' +
        IntToStr(LogBindingCount));
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

procedure CheckMemberWrongArgumentCountDiagnostic;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  SourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
begin
  SourceText :=
    'program MemberWrongArgumentCountCalls;' + LineEnding +
    'type' + LineEnding +
    '  TWorker = class' + LineEnding +
    '    procedure Pick(Value: Integer);' + LineEnding +
    '  end;' + LineEnding +
    'procedure TWorker.Pick(Value: Integer);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'var' + LineEnding +
    '  Worker: TWorker;' + LineEnding +
    'begin' + LineEnding +
    '  Worker.Pick(1, 2);' + LineEnding +
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
    if not Diagnostics.HasErrors then
      Fail('missing-member-wrong-argument-count-diagnostic');
    if not SameText(Diagnostics.LastDiagnosticCode, 'sema.wrong-argument-count') then
      Fail('unexpected-member-wrong-argument-count-diagnostic-code:' +
        Diagnostics.LastDiagnosticCode);
    if not SameText(Diagnostics.LastDiagnosticPhase, 'sema') then
      Fail('unexpected-member-wrong-argument-count-diagnostic-phase:' +
        Diagnostics.LastDiagnosticPhase);
    if Pos('Pick', Diagnostics.LastDiagnosticMessage) <= 0 then
      Fail('member-wrong-argument-count-diagnostic-missing-name');
    if Model = nil then
      Fail('missing-member-wrong-argument-count-semantic-model');
    if not SameText(Model.Status, 'failure') then
      Fail('unexpected-member-wrong-argument-count-model-status:' +
        Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-member-wrong-argument-count-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckBareCallTypeMismatchDiagnostic;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  SourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
begin
  SourceText :=
    'program BareCallTypeMismatchCalls;' + LineEnding +
    'procedure Pick(Value: Integer);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    '  Pick(True);' + LineEnding +
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
    if not Diagnostics.HasErrors then
      Fail('missing-bare-call-type-mismatch-diagnostic');
    if not SameText(Diagnostics.LastDiagnosticCode, 'sema.type-mismatch') then
      Fail('unexpected-bare-call-type-mismatch-diagnostic-code:' +
        Diagnostics.LastDiagnosticCode);
    if not SameText(Diagnostics.LastDiagnosticPhase, 'sema') then
      Fail('unexpected-bare-call-type-mismatch-diagnostic-phase:' +
        Diagnostics.LastDiagnosticPhase);
    if Pos('Pick', Diagnostics.LastDiagnosticMessage) <= 0 then
      Fail('bare-call-type-mismatch-diagnostic-missing-name');
    if Model = nil then
      Fail('missing-bare-call-type-mismatch-semantic-model');
    if not SameText(Model.Status, 'failure') then
      Fail('unexpected-bare-call-type-mismatch-model-status:' +
        Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-bare-call-type-mismatch-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckMemberCallTypeMismatchDiagnostic;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  SourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
begin
  SourceText :=
    'program MemberCallTypeMismatchCalls;' + LineEnding +
    'type' + LineEnding +
    '  TWorker = class' + LineEnding +
    '    procedure Pick(Value: Integer);' + LineEnding +
    '  end;' + LineEnding +
    'procedure TWorker.Pick(Value: Integer);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'var' + LineEnding +
    '  Worker: TWorker;' + LineEnding +
    'begin' + LineEnding +
    '  Worker.Pick(True);' + LineEnding +
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
    if not Diagnostics.HasErrors then
      Fail('missing-member-call-type-mismatch-diagnostic');
    if not SameText(Diagnostics.LastDiagnosticCode, 'sema.type-mismatch') then
      Fail('unexpected-member-call-type-mismatch-diagnostic-code:' +
        Diagnostics.LastDiagnosticCode);
    if not SameText(Diagnostics.LastDiagnosticPhase, 'sema') then
      Fail('unexpected-member-call-type-mismatch-diagnostic-phase:' +
        Diagnostics.LastDiagnosticPhase);
    if Pos('Pick', Diagnostics.LastDiagnosticMessage) <= 0 then
      Fail('member-call-type-mismatch-diagnostic-missing-name');
    if Model = nil then
      Fail('missing-member-call-type-mismatch-semantic-model');
    if not SameText(Model.Status, 'failure') then
      Fail('unexpected-member-call-type-mismatch-model-status:' +
        Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-member-call-type-mismatch-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckBareVariableCallTypeMismatchDiagnostic;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  SourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
begin
  SourceText :=
    'program BareVariableCallTypeMismatchCalls;' + LineEnding +
    'procedure Pick(Value: Integer);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'var' + LineEnding +
    '  Flag: Boolean;' + LineEnding +
    'begin' + LineEnding +
    '  Pick(Flag);' + LineEnding +
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
    if not Diagnostics.HasErrors then
      Fail('missing-bare-variable-call-type-mismatch-diagnostic');
    if not SameText(Diagnostics.LastDiagnosticCode, 'sema.type-mismatch') then
      Fail('unexpected-bare-variable-call-type-mismatch-diagnostic-code:' +
        Diagnostics.LastDiagnosticCode);
    if not SameText(Diagnostics.LastDiagnosticPhase, 'sema') then
      Fail('unexpected-bare-variable-call-type-mismatch-diagnostic-phase:' +
        Diagnostics.LastDiagnosticPhase);
    if Pos('Pick', Diagnostics.LastDiagnosticMessage) <= 0 then
      Fail('bare-variable-call-type-mismatch-diagnostic-missing-name');
    if Model = nil then
      Fail('missing-bare-variable-call-type-mismatch-semantic-model');
    if not SameText(Model.Status, 'failure') then
      Fail('unexpected-bare-variable-call-type-mismatch-model-status:' +
        Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-bare-variable-call-type-mismatch-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckMemberVariableCallTypeMismatchDiagnostic;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  SourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
begin
  SourceText :=
    'program MemberVariableCallTypeMismatchCalls;' + LineEnding +
    'type' + LineEnding +
    '  TWorker = class' + LineEnding +
    '    procedure Pick(Value: Integer);' + LineEnding +
    '  end;' + LineEnding +
    'procedure TWorker.Pick(Value: Integer);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'var' + LineEnding +
    '  Worker: TWorker;' + LineEnding +
    '  Flag: Boolean;' + LineEnding +
    'begin' + LineEnding +
    '  Worker.Pick(Flag);' + LineEnding +
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
    if not Diagnostics.HasErrors then
      Fail('missing-member-variable-call-type-mismatch-diagnostic');
    if not SameText(Diagnostics.LastDiagnosticCode, 'sema.type-mismatch') then
      Fail('unexpected-member-variable-call-type-mismatch-diagnostic-code:' +
        Diagnostics.LastDiagnosticCode);
    if not SameText(Diagnostics.LastDiagnosticPhase, 'sema') then
      Fail('unexpected-member-variable-call-type-mismatch-diagnostic-phase:' +
        Diagnostics.LastDiagnosticPhase);
    if Pos('Pick', Diagnostics.LastDiagnosticMessage) <= 0 then
      Fail('member-variable-call-type-mismatch-diagnostic-missing-name');
    if Model = nil then
      Fail('missing-member-variable-call-type-mismatch-semantic-model');
    if not SameText(Model.Status, 'failure') then
      Fail('unexpected-member-variable-call-type-mismatch-model-status:' +
        Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-member-variable-call-type-mismatch-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckBareParameterCallTypeMismatchDiagnostic;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  SourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
begin
  SourceText :=
    'program BareParameterCallTypeMismatchCalls;' + LineEnding +
    'procedure Pick(Value: Integer);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'procedure Run(Flag: Boolean);' + LineEnding +
    'begin' + LineEnding +
    '  Pick(Flag);' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
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
    if not Diagnostics.HasErrors then
      Fail('missing-bare-parameter-call-type-mismatch-diagnostic');
    if not SameText(Diagnostics.LastDiagnosticCode, 'sema.type-mismatch') then
      Fail('unexpected-bare-parameter-call-type-mismatch-diagnostic-code:' +
        Diagnostics.LastDiagnosticCode);
    if not SameText(Diagnostics.LastDiagnosticPhase, 'sema') then
      Fail('unexpected-bare-parameter-call-type-mismatch-diagnostic-phase:' +
        Diagnostics.LastDiagnosticPhase);
    if Pos('Pick', Diagnostics.LastDiagnosticMessage) <= 0 then
      Fail('bare-parameter-call-type-mismatch-diagnostic-missing-name');
    if Model = nil then
      Fail('missing-bare-parameter-call-type-mismatch-semantic-model');
    if not SameText(Model.Status, 'failure') then
      Fail('unexpected-bare-parameter-call-type-mismatch-model-status:' +
        Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-bare-parameter-call-type-mismatch-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckBareUnknownCallableDiagnostic;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  SourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
begin
  SourceText :=
    'program BareUnknownCallableCalls;' + LineEnding +
    'begin' + LineEnding +
    '  MissingThing(1);' + LineEnding +
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
    if not Diagnostics.HasErrors then
      Fail('missing-bare-unknown-callable-diagnostic');
    if not SameText(Diagnostics.LastDiagnosticCode, 'sema.unknown-callable') then
      Fail('unexpected-bare-unknown-callable-diagnostic-code:' +
        Diagnostics.LastDiagnosticCode);
    if not SameText(Diagnostics.LastDiagnosticPhase, 'sema') then
      Fail('unexpected-bare-unknown-callable-diagnostic-phase:' +
        Diagnostics.LastDiagnosticPhase);
    if Pos('MissingThing', Diagnostics.LastDiagnosticMessage) <= 0 then
      Fail('bare-unknown-callable-diagnostic-missing-name');
    if Model = nil then
      Fail('missing-bare-unknown-callable-semantic-model');
    if not SameText(Model.Status, 'failure') then
      Fail('unexpected-bare-unknown-callable-model-status:' +
        Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-bare-unknown-callable-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckInstalledSourceUnknownCallableStaysDeferred;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  HelperPath: string;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  ProjectRoot: string;
  RootSourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
begin
  ProjectRoot := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'nextpas-semantic-installed-imported-unknown-callable-' +
    IntToStr(Random(MaxInt));
  HelperPath := ProjectRoot + DirectorySeparator + 'helper.pas';
  RootSourceText :=
    'program InstalledImportedUnknownCallableCalls;' + LineEnding +
    'uses Helper;' + LineEnding +
    'begin' + LineEnding +
    '  MissingThing(1);' + LineEnding +
    'end.' + LineEnding;
  WriteTextFile(
    HelperPath,
    'unit Helper;' + LineEnding +
    LineEnding +
    'interface' + LineEnding +
    LineEnding +
    'implementation' + LineEnding +
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
      BuildResolvedUnit(
        'InstalledImportedUnknownCallableCalls',
        '',
        ruoRootSource,
        '',
        'program',
        1
      )
    );
    UnitGraph.AddResolvedUnit(
      BuildResolvedUnit('Helper', HelperPath, ruoInstalledSource, '', 'unit', 2)
    );
    Analyzer := TSemanticAnalyzer.Create(Ast, UnitGraph, Diagnostics, 1, True);
    Analyzer.Analyze;
    Model := Analyzer.DetachModel;
    if Diagnostics.HasErrors then
      Fail('unexpected-installed-imported-unknown-callable-diagnostic:' +
        Diagnostics.LastDiagnosticCode);
    if Model = nil then
      Fail('missing-installed-imported-unknown-callable-semantic-model');
    if not SameText(Model.Status, 'ready') then
      Fail('unexpected-installed-imported-unknown-callable-model-status:' +
        Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-installed-imported-unknown-callable-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckInstalledSourceInheritedMemberFunctionResultAmbiguousOverloadStaysDeferred;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  ProjectRoot: string;
  RootSourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
  UnitPath: string;
begin
  ProjectRoot := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'nextpas-semantic-installed-imported-inherited-member-function-result-ambiguous-overload-' +
    IntToStr(Random(MaxInt));
  UnitPath := ProjectRoot + DirectorySeparator + 'worker.pas';
  RootSourceText :=
    'program InstalledImportedInheritedMemberFunctionResultAmbiguousOverloadCalls;' + LineEnding +
    'uses Worker;' + LineEnding +
    'var' + LineEnding +
    '  Worker: TWorker;' + LineEnding +
    'function Count: Integer;' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    '  Worker.Pick(Count);' + LineEnding +
    'end.' + LineEnding;
  WriteTextFile(
    UnitPath,
    'unit Worker;' + LineEnding +
    LineEnding +
    'interface' + LineEnding +
    'type' + LineEnding +
    '  TBase = class' + LineEnding +
    '    procedure Pick(Value: Integer);' + LineEnding +
    '    procedure Pick(Value: LongInt);' + LineEnding +
    '  end;' + LineEnding +
    '  TWorker = class(TBase)' + LineEnding +
    '  end;' + LineEnding +
    LineEnding +
    'implementation' + LineEnding +
    'procedure TBase.Pick(Value: Integer);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'procedure TBase.Pick(Value: LongInt);' + LineEnding +
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
      BuildResolvedUnit(
        'InstalledImportedInheritedMemberFunctionResultAmbiguousOverloadCalls',
        '',
        ruoRootSource,
        '',
        'program',
        1
      )
    );
    UnitGraph.AddResolvedUnit(
      BuildResolvedUnit('Worker', UnitPath, ruoInstalledSource, '', 'unit', 2)
    );
    Analyzer := TSemanticAnalyzer.Create(Ast, UnitGraph, Diagnostics, 1, True);
    Analyzer.Analyze;
    Model := Analyzer.DetachModel;
    if Diagnostics.HasErrors then
      Fail('unexpected-installed-imported-inherited-member-function-result-ambiguous-overload-diagnostic:' +
        Diagnostics.LastDiagnosticCode);
    if Model = nil then
      Fail('missing-installed-imported-inherited-member-function-result-ambiguous-overload-semantic-model');
    if not SameText(Model.Status, 'ready') then
      Fail('unexpected-installed-imported-inherited-member-function-result-ambiguous-overload-model-status:' +
        Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-installed-imported-inherited-member-function-result-ambiguous-overload-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckImplicitSelfBareMethodCallBinding;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Binding: TSemanticBinding;
  Diagnostics: TDiagnosticsSink;
  Index: LongInt;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  SourceText: string;
  TouchBindingCount: LongInt;
  TouchSymbolId: LongInt;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
begin
  SourceText :=
    'program ImplicitSelfBareMethodCallBinding;' + LineEnding +
    'type' + LineEnding +
    '  TWorker = class' + LineEnding +
    '    procedure Run;' + LineEnding +
    '    procedure Touch;' + LineEnding +
    '  end;' + LineEnding +
    'procedure TWorker.Touch;' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'procedure TWorker.Run;' + LineEnding +
    'begin' + LineEnding +
    '  Touch;' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
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
      Fail('unexpected-implicit-self-bare-method-call-binding-diagnostic:' +
        Diagnostics.LastDiagnosticCode);
    if Model = nil then
      Fail('missing-implicit-self-bare-method-call-binding-model');
    if not SameText(Model.Status, 'ready') then
      Fail('unexpected-implicit-self-bare-method-call-binding-model-status:' +
        Model.Status);
    TouchSymbolId := SymbolIdByNameAndKind(Model, 'TWorker.Touch', 'method');
    if TouchSymbolId <= 0 then
      Fail('missing-implicit-self-bare-method-call-target-symbol');
    TouchBindingCount := 0;
    for Index := 0 to Model.BindingCount - 1 do
    begin
      Binding := Model.BindingAt(Index);
      if SameText(Binding.Kind, 'member-call') and
        SameText(Binding.Name, 'Touch') then
      begin
        Inc(TouchBindingCount);
        if Binding.TargetSymbolId <> TouchSymbolId then
          Fail('implicit-self-bare-method-call-target-mismatch');
      end;
    end;
    if TouchBindingCount = 0 then
      Fail('missing-implicit-self-bare-method-call-binding');
    if TouchBindingCount <> 1 then
      Fail('unexpected-implicit-self-bare-method-call-binding-count:' +
        IntToStr(TouchBindingCount));
    if Model.BindingCount <> 1 then
      Fail('unexpected-implicit-self-bare-method-call-model-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckImplicitSelfBareMethodUnknownMemberDiagnostic;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  SourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
begin
  SourceText :=
    'program ImplicitSelfBareMethodUnknownMember;' + LineEnding +
    'type' + LineEnding +
    '  TWorker = class' + LineEnding +
    '    procedure Run;' + LineEnding +
    '  end;' + LineEnding +
    'procedure TWorker.Run;' + LineEnding +
    'begin' + LineEnding +
    '  Missing;' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
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
    if not Diagnostics.HasErrors then
      Fail('missing-implicit-self-bare-method-unknown-member-diagnostic');
    if not SameText(Diagnostics.LastDiagnosticCode, 'sema.unknown-member') then
      Fail('unexpected-implicit-self-bare-method-unknown-member-diagnostic-code:' +
        Diagnostics.LastDiagnosticCode);
    if not SameText(Diagnostics.LastDiagnosticPhase, 'sema') then
      Fail('unexpected-implicit-self-bare-method-unknown-member-diagnostic-phase:' +
        Diagnostics.LastDiagnosticPhase);
    if Pos('Missing', Diagnostics.LastDiagnosticMessage) <= 0 then
      Fail('implicit-self-bare-method-unknown-member-diagnostic-missing-name');
    if Model = nil then
      Fail('missing-implicit-self-bare-method-unknown-member-model');
    if not SameText(Model.Status, 'failure') then
      Fail('unexpected-implicit-self-bare-method-unknown-member-model-status:' +
        Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-implicit-self-bare-method-unknown-member-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckInheritedImplicitSelfBareMethodCallBinding;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Binding: TSemanticBinding;
  Diagnostics: TDiagnosticsSink;
  Index: LongInt;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  SourceText: string;
  TouchBindingCount: LongInt;
  TouchOffset: LongInt;
  TouchSymbolId: LongInt;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
begin
  SourceText :=
    'program InheritedImplicitSelfBareMethodCallBinding;' + LineEnding +
    'type' + LineEnding +
    '  TBaseWorker = class' + LineEnding +
    '    procedure Touch;' + LineEnding +
    '  end;' + LineEnding +
    '  TWorker = class(TBaseWorker)' + LineEnding +
    '    procedure Run;' + LineEnding +
    '  end;' + LineEnding +
    'procedure TBaseWorker.Touch;' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'procedure TWorker.Run;' + LineEnding +
    'begin' + LineEnding +
    '  Touch;' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
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
      Fail('unexpected-inherited-implicit-self-bare-method-call-diagnostic:' +
        Diagnostics.LastDiagnosticCode);
    if Model = nil then
      Fail('missing-inherited-implicit-self-bare-method-call-model');
    if not SameText(Model.Status, 'ready') then
      Fail('unexpected-inherited-implicit-self-bare-method-call-model-status:' +
        Model.Status);
    TouchSymbolId := SymbolIdByNameAndKind(
      Model,
      'TBaseWorker.Touch',
      'method'
    );
    if TouchSymbolId <= 0 then
      Fail('missing-inherited-implicit-self-bare-method-call-target-symbol');
    TouchOffset := Pos('  Touch;', SourceText) + Length('  ') - 1;
    TouchBindingCount := 0;
    for Index := 0 to Model.BindingCount - 1 do
    begin
      Binding := Model.BindingAt(Index);
      if SameText(Binding.Kind, 'member-call') and
        SameText(Binding.Name, 'Touch') then
      begin
        Inc(TouchBindingCount);
        if Binding.TargetSymbolId <> TouchSymbolId then
          Fail('inherited-implicit-self-bare-method-call-target-mismatch');
        if Binding.ByteOffset <> TouchOffset then
          Fail('inherited-implicit-self-bare-method-call-offset-mismatch:' +
            IntToStr(Binding.ByteOffset));
      end;
    end;
    if TouchBindingCount = 0 then
      Fail('missing-inherited-implicit-self-bare-method-call-binding');
    if TouchBindingCount <> 1 then
      Fail('unexpected-inherited-implicit-self-bare-method-call-binding-count:' +
        IntToStr(TouchBindingCount));
    if Model.BindingCount <> 1 then
      Fail('unexpected-inherited-implicit-self-bare-method-call-model-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckInheritedImplicitSelfBareMethodCallArgumentBinding;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Binding: TSemanticBinding;
  Diagnostics: TDiagnosticsSink;
  Index: LongInt;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  SourceText: string;
  TouchBindingCount: LongInt;
  TouchOffset: LongInt;
  TouchSymbolId: LongInt;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
begin
  SourceText :=
    'program InheritedImplicitSelfBareMethodCallArgumentBinding;' + LineEnding +
    'type' + LineEnding +
    '  TBaseWorker = class' + LineEnding +
    '    procedure Touch(Value: Integer);' + LineEnding +
    '  end;' + LineEnding +
    '  TWorker = class(TBaseWorker)' + LineEnding +
    '    procedure Run;' + LineEnding +
    '  end;' + LineEnding +
    'procedure TBaseWorker.Touch(Value: Integer);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'procedure TWorker.Run;' + LineEnding +
    'begin' + LineEnding +
    '  Touch(7);' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
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
      Fail('unexpected-inherited-implicit-self-bare-method-call-argument-diagnostic:' +
        Diagnostics.LastDiagnosticCode);
    if Model = nil then
      Fail('missing-inherited-implicit-self-bare-method-call-argument-model');
    if not SameText(Model.Status, 'ready') then
      Fail('unexpected-inherited-implicit-self-bare-method-call-argument-model-status:' +
        Model.Status);
    TouchSymbolId := SymbolIdByNameKindOwnerAndSignature(
      Model,
      'TBaseWorker.Touch',
      'method',
      'inheritedimplicitselfbaremethodcallargumentbinding',
      1,
      'i'
    );
    if TouchSymbolId <= 0 then
      Fail('missing-inherited-implicit-self-bare-method-call-argument-target-symbol');
    TouchOffset := Pos('Touch(7)', SourceText) - 1;
    TouchBindingCount := 0;
    for Index := 0 to Model.BindingCount - 1 do
    begin
      Binding := Model.BindingAt(Index);
      if SameText(Binding.Kind, 'member-call') and
        SameText(Binding.Name, 'Touch') then
      begin
        Inc(TouchBindingCount);
        if Binding.TargetSymbolId <> TouchSymbolId then
          Fail('inherited-implicit-self-bare-method-call-argument-target-mismatch');
        if Binding.ByteOffset <> TouchOffset then
          Fail('inherited-implicit-self-bare-method-call-argument-offset-mismatch:' +
            IntToStr(Binding.ByteOffset));
      end;
    end;
    if TouchBindingCount = 0 then
      Fail('missing-inherited-implicit-self-bare-method-call-argument-binding');
    if TouchBindingCount <> 1 then
      Fail('unexpected-inherited-implicit-self-bare-method-call-argument-binding-count:' +
        IntToStr(TouchBindingCount));
    if Model.BindingCount <> 1 then
      Fail('unexpected-inherited-implicit-self-bare-method-call-argument-model-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckInheritedImplicitSelfBareMethodCallArgumentTypeMismatchDiagnostic;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  SourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
begin
  SourceText :=
    'program InheritedImplicitSelfBareMethodCallArgumentTypeMismatch;' + LineEnding +
    'type' + LineEnding +
    '  TBaseWorker = class' + LineEnding +
    '    procedure Touch(Value: Integer);' + LineEnding +
    '  end;' + LineEnding +
    '  TWorker = class(TBaseWorker)' + LineEnding +
    '    procedure Run;' + LineEnding +
    '  end;' + LineEnding +
    'procedure TBaseWorker.Touch(Value: Integer);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'procedure TWorker.Run;' + LineEnding +
    'begin' + LineEnding +
    '  Touch(True);' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
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
    if not Diagnostics.HasErrors then
      Fail('missing-inherited-implicit-self-bare-method-call-argument-type-mismatch-diagnostic');
    if not SameText(Diagnostics.LastDiagnosticCode, 'sema.type-mismatch') then
      Fail('unexpected-inherited-implicit-self-bare-method-call-argument-type-mismatch-diagnostic-code:' +
        Diagnostics.LastDiagnosticCode);
    if not SameText(Diagnostics.LastDiagnosticPhase, 'sema') then
      Fail('unexpected-inherited-implicit-self-bare-method-call-argument-type-mismatch-diagnostic-phase:' +
        Diagnostics.LastDiagnosticPhase);
    if Pos('Touch', Diagnostics.LastDiagnosticMessage) <= 0 then
      Fail('inherited-implicit-self-bare-method-call-argument-type-mismatch-diagnostic-missing-name');
    if Model = nil then
      Fail('missing-inherited-implicit-self-bare-method-call-argument-type-mismatch-model');
    if not SameText(Model.Status, 'failure') then
      Fail('unexpected-inherited-implicit-self-bare-method-call-argument-type-mismatch-model-status:' +
        Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-inherited-implicit-self-bare-method-call-argument-type-mismatch-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckImplicitSelfBareMethodCallArgumentTypeMismatchDiagnostic;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  SourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
begin
  SourceText :=
    'program ImplicitSelfBareMethodCallArgumentTypeMismatch;' + LineEnding +
    'type' + LineEnding +
    '  TWorker = class' + LineEnding +
    '    procedure Pick(Value: Integer);' + LineEnding +
    '    procedure Run;' + LineEnding +
    '  end;' + LineEnding +
    'procedure TWorker.Pick(Value: Integer);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'procedure TWorker.Run;' + LineEnding +
    'begin' + LineEnding +
    '  Pick(True);' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
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
    if not Diagnostics.HasErrors then
      Fail('missing-implicit-self-bare-method-call-argument-type-mismatch-diagnostic');
    if not SameText(Diagnostics.LastDiagnosticCode, 'sema.type-mismatch') then
      Fail('unexpected-implicit-self-bare-method-call-argument-type-mismatch-diagnostic-code:' +
        Diagnostics.LastDiagnosticCode);
    if not SameText(Diagnostics.LastDiagnosticPhase, 'sema') then
      Fail('unexpected-implicit-self-bare-method-call-argument-type-mismatch-diagnostic-phase:' +
        Diagnostics.LastDiagnosticPhase);
    if Pos('Pick', Diagnostics.LastDiagnosticMessage) <= 0 then
      Fail('implicit-self-bare-method-call-argument-type-mismatch-diagnostic-missing-name');
    if Model = nil then
      Fail('missing-implicit-self-bare-method-call-argument-type-mismatch-model');
    if not SameText(Model.Status, 'failure') then
      Fail('unexpected-implicit-self-bare-method-call-argument-type-mismatch-model-status:' +
        Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-implicit-self-bare-method-call-argument-type-mismatch-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckImplicitSelfBareMethodCallWrongArgumentCountDiagnostic;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  SourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
begin
  SourceText :=
    'program ImplicitSelfBareMethodCallWrongArgumentCount;' + LineEnding +
    'type' + LineEnding +
    '  TWorker = class' + LineEnding +
    '    procedure Pick(Value: Integer);' + LineEnding +
    '    procedure Run;' + LineEnding +
    '  end;' + LineEnding +
    'procedure TWorker.Pick(Value: Integer);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'procedure TWorker.Run;' + LineEnding +
    'begin' + LineEnding +
    '  Pick;' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
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
    if not Diagnostics.HasErrors then
      Fail('missing-implicit-self-bare-method-call-wrong-argument-count-diagnostic');
    if not SameText(Diagnostics.LastDiagnosticCode, 'sema.wrong-argument-count') then
      Fail('unexpected-implicit-self-bare-method-call-wrong-argument-count-diagnostic-code:' +
        Diagnostics.LastDiagnosticCode);
    if not SameText(Diagnostics.LastDiagnosticPhase, 'sema') then
      Fail('unexpected-implicit-self-bare-method-call-wrong-argument-count-diagnostic-phase:' +
        Diagnostics.LastDiagnosticPhase);
    if Pos('Pick', Diagnostics.LastDiagnosticMessage) <= 0 then
      Fail('implicit-self-bare-method-call-wrong-argument-count-diagnostic-missing-name');
    if Model = nil then
      Fail('missing-implicit-self-bare-method-call-wrong-argument-count-model');
    if not SameText(Model.Status, 'failure') then
      Fail('unexpected-implicit-self-bare-method-call-wrong-argument-count-model-status:' +
        Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-implicit-self-bare-method-call-wrong-argument-count-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckImplicitSelfBareMethodCallNoMatchingOverloadDiagnostic;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  SourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
begin
  SourceText :=
    'program ImplicitSelfBareMethodCallNoMatchingOverload;' + LineEnding +
    'type' + LineEnding +
    '  TWorker = class' + LineEnding +
    '    procedure Pick(Value: Integer);' + LineEnding +
    '    procedure Pick(Value: AnsiString);' + LineEnding +
    '    procedure Run;' + LineEnding +
    '  end;' + LineEnding +
    'procedure TWorker.Pick(Value: Integer);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'procedure TWorker.Pick(Value: AnsiString);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'procedure TWorker.Run;' + LineEnding +
    'begin' + LineEnding +
    '  Pick(True);' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
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
    if not Diagnostics.HasErrors then
      Fail('missing-implicit-self-bare-method-call-no-matching-overload-diagnostic');
    if not SameText(Diagnostics.LastDiagnosticCode, 'sema.no-matching-overload') then
      Fail('unexpected-implicit-self-bare-method-call-no-matching-overload-diagnostic-code:' +
        Diagnostics.LastDiagnosticCode);
    if not SameText(Diagnostics.LastDiagnosticPhase, 'sema') then
      Fail('unexpected-implicit-self-bare-method-call-no-matching-overload-diagnostic-phase:' +
        Diagnostics.LastDiagnosticPhase);
    if Pos('Pick', Diagnostics.LastDiagnosticMessage) <= 0 then
      Fail('implicit-self-bare-method-call-no-matching-overload-diagnostic-missing-name');
    if Model = nil then
      Fail('missing-implicit-self-bare-method-call-no-matching-overload-model');
    if not SameText(Model.Status, 'failure') then
      Fail('unexpected-implicit-self-bare-method-call-no-matching-overload-model-status:' +
        Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-implicit-self-bare-method-call-no-matching-overload-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckImplicitSelfBareMethodCallAmbiguousOverloadDiagnostic;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  SourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
begin
  SourceText :=
    'program ImplicitSelfBareMethodCallAmbiguousOverload;' + LineEnding +
    'type' + LineEnding +
    '  TWorker = class' + LineEnding +
    '    procedure Pick(Value: Integer);' + LineEnding +
    '    procedure Pick(Value: LongInt);' + LineEnding +
    '    procedure Run;' + LineEnding +
    '  end;' + LineEnding +
    'procedure TWorker.Pick(Value: Integer);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'procedure TWorker.Pick(Value: LongInt);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'procedure TWorker.Run;' + LineEnding +
    'begin' + LineEnding +
    '  Pick(1);' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
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
    if not Diagnostics.HasErrors then
      Fail('missing-implicit-self-bare-method-call-ambiguous-overload-diagnostic');
    if not SameText(Diagnostics.LastDiagnosticCode, 'sema.ambiguous-overload') then
      Fail('unexpected-implicit-self-bare-method-call-ambiguous-overload-diagnostic-code:' +
        Diagnostics.LastDiagnosticCode);
    if not SameText(Diagnostics.LastDiagnosticPhase, 'sema') then
      Fail('unexpected-implicit-self-bare-method-call-ambiguous-overload-diagnostic-phase:' +
        Diagnostics.LastDiagnosticPhase);
    if Pos('Pick', Diagnostics.LastDiagnosticMessage) <= 0 then
      Fail('implicit-self-bare-method-call-ambiguous-overload-diagnostic-missing-name');
    if Model = nil then
      Fail('missing-implicit-self-bare-method-call-ambiguous-overload-model');
    if not SameText(Model.Status, 'failure') then
      Fail('unexpected-implicit-self-bare-method-call-ambiguous-overload-model-status:' +
        Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-implicit-self-bare-method-call-ambiguous-overload-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckInheritedImplicitSelfBareMethodCallWrongArgumentCountDiagnostic;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  SourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
begin
  SourceText :=
    'program InheritedImplicitSelfBareMethodCallWrongArgumentCount;' + LineEnding +
    'type' + LineEnding +
    '  TBaseWorker = class' + LineEnding +
    '    procedure Touch(Value: Integer);' + LineEnding +
    '  end;' + LineEnding +
    '  TWorker = class(TBaseWorker)' + LineEnding +
    '    procedure Run;' + LineEnding +
    '  end;' + LineEnding +
    'procedure TBaseWorker.Touch(Value: Integer);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'procedure TWorker.Run;' + LineEnding +
    'begin' + LineEnding +
    '  Touch;' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
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
    if not Diagnostics.HasErrors then
      Fail('missing-inherited-implicit-self-bare-method-call-wrong-argument-count-diagnostic');
    if not SameText(Diagnostics.LastDiagnosticCode, 'sema.wrong-argument-count') then
      Fail('unexpected-inherited-implicit-self-bare-method-call-wrong-argument-count-diagnostic-code:' +
        Diagnostics.LastDiagnosticCode);
    if not SameText(Diagnostics.LastDiagnosticPhase, 'sema') then
      Fail('unexpected-inherited-implicit-self-bare-method-call-wrong-argument-count-diagnostic-phase:' +
        Diagnostics.LastDiagnosticPhase);
    if Pos('Touch', Diagnostics.LastDiagnosticMessage) <= 0 then
      Fail('inherited-implicit-self-bare-method-call-wrong-argument-count-diagnostic-missing-name');
    if Model = nil then
      Fail('missing-inherited-implicit-self-bare-method-call-wrong-argument-count-model');
    if not SameText(Model.Status, 'failure') then
      Fail('unexpected-inherited-implicit-self-bare-method-call-wrong-argument-count-model-status:' +
        Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-inherited-implicit-self-bare-method-call-wrong-argument-count-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckInheritedImplicitSelfBareMethodCallNoMatchingOverloadDiagnostic;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  SourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
begin
  SourceText :=
    'program InheritedImplicitSelfBareMethodCallNoMatchingOverload;' + LineEnding +
    'type' + LineEnding +
    '  TBaseWorker = class' + LineEnding +
    '    procedure Touch(Value: Integer);' + LineEnding +
    '    procedure Touch(Value: AnsiString);' + LineEnding +
    '  end;' + LineEnding +
    '  TWorker = class(TBaseWorker)' + LineEnding +
    '    procedure Run;' + LineEnding +
    '  end;' + LineEnding +
    'procedure TBaseWorker.Touch(Value: Integer);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'procedure TBaseWorker.Touch(Value: AnsiString);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'procedure TWorker.Run;' + LineEnding +
    'begin' + LineEnding +
    '  Touch(True);' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
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
    if not Diagnostics.HasErrors then
      Fail('missing-inherited-implicit-self-bare-method-call-no-matching-overload-diagnostic');
    if not SameText(Diagnostics.LastDiagnosticCode, 'sema.no-matching-overload') then
      Fail('unexpected-inherited-implicit-self-bare-method-call-no-matching-overload-diagnostic-code:' +
        Diagnostics.LastDiagnosticCode);
    if not SameText(Diagnostics.LastDiagnosticPhase, 'sema') then
      Fail('unexpected-inherited-implicit-self-bare-method-call-no-matching-overload-diagnostic-phase:' +
        Diagnostics.LastDiagnosticPhase);
    if Pos('Touch', Diagnostics.LastDiagnosticMessage) <= 0 then
      Fail('inherited-implicit-self-bare-method-call-no-matching-overload-diagnostic-missing-name');
    if Model = nil then
      Fail('missing-inherited-implicit-self-bare-method-call-no-matching-overload-model');
    if not SameText(Model.Status, 'failure') then
      Fail('unexpected-inherited-implicit-self-bare-method-call-no-matching-overload-model-status:' +
        Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-inherited-implicit-self-bare-method-call-no-matching-overload-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckInheritedImplicitSelfBareMethodCallAmbiguousOverloadDiagnostic;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  SourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
begin
  SourceText :=
    'program InheritedImplicitSelfBareMethodCallAmbiguousOverload;' + LineEnding +
    'type' + LineEnding +
    '  TBaseWorker = class' + LineEnding +
    '    procedure Touch(Value: Integer);' + LineEnding +
    '    procedure Touch(Value: LongInt);' + LineEnding +
    '  end;' + LineEnding +
    '  TWorker = class(TBaseWorker)' + LineEnding +
    '    procedure Run;' + LineEnding +
    '  end;' + LineEnding +
    'procedure TBaseWorker.Touch(Value: Integer);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'procedure TBaseWorker.Touch(Value: LongInt);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'procedure TWorker.Run;' + LineEnding +
    'begin' + LineEnding +
    '  Touch(1);' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
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
    if not Diagnostics.HasErrors then
      Fail('missing-inherited-implicit-self-bare-method-call-ambiguous-overload-diagnostic');
    if not SameText(Diagnostics.LastDiagnosticCode, 'sema.ambiguous-overload') then
      Fail('unexpected-inherited-implicit-self-bare-method-call-ambiguous-overload-diagnostic-code:' +
        Diagnostics.LastDiagnosticCode);
    if not SameText(Diagnostics.LastDiagnosticPhase, 'sema') then
      Fail('unexpected-inherited-implicit-self-bare-method-call-ambiguous-overload-diagnostic-phase:' +
        Diagnostics.LastDiagnosticPhase);
    if Pos('Touch', Diagnostics.LastDiagnosticMessage) <= 0 then
      Fail('inherited-implicit-self-bare-method-call-ambiguous-overload-diagnostic-missing-name');
    if Model = nil then
      Fail('missing-inherited-implicit-self-bare-method-call-ambiguous-overload-model');
    if not SameText(Model.Status, 'failure') then
      Fail('unexpected-inherited-implicit-self-bare-method-call-ambiguous-overload-model-status:' +
        Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-inherited-implicit-self-bare-method-call-ambiguous-overload-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckMemberParameterCallTypeMismatchDiagnostic;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  SourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
begin
  SourceText :=
    'program MemberParameterCallTypeMismatchCalls;' + LineEnding +
    'type' + LineEnding +
    '  TWorker = class' + LineEnding +
    '    procedure Pick(Value: Integer);' + LineEnding +
    '    procedure Run(Flag: Boolean);' + LineEnding +
    '  end;' + LineEnding +
    'procedure TWorker.Pick(Value: Integer);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'procedure TWorker.Run(Flag: Boolean);' + LineEnding +
    'begin' + LineEnding +
    '  Self.Pick(Flag);' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
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
    if not Diagnostics.HasErrors then
      Fail('missing-member-parameter-call-type-mismatch-diagnostic');
    if not SameText(Diagnostics.LastDiagnosticCode, 'sema.type-mismatch') then
      Fail('unexpected-member-parameter-call-type-mismatch-diagnostic-code:' +
        Diagnostics.LastDiagnosticCode);
    if not SameText(Diagnostics.LastDiagnosticPhase, 'sema') then
      Fail('unexpected-member-parameter-call-type-mismatch-diagnostic-phase:' +
        Diagnostics.LastDiagnosticPhase);
    if Pos('Pick', Diagnostics.LastDiagnosticMessage) <= 0 then
      Fail('member-parameter-call-type-mismatch-diagnostic-missing-name');
    if Model = nil then
      Fail('missing-member-parameter-call-type-mismatch-semantic-model');
    if not SameText(Model.Status, 'failure') then
      Fail('unexpected-member-parameter-call-type-mismatch-model-status:' +
        Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-member-parameter-call-type-mismatch-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckBareFunctionResultTypeMismatchDiagnostic;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  SourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
begin
  SourceText :=
    'program BareFunctionResultTypeMismatchCalls;' + LineEnding +
    'procedure Pick(Value: Integer);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'function Flag: Boolean;' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    '  Pick(Flag);' + LineEnding +
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
    if not Diagnostics.HasErrors then
      Fail('missing-bare-function-result-type-mismatch-diagnostic');
    if not SameText(Diagnostics.LastDiagnosticCode, 'sema.type-mismatch') then
      Fail('unexpected-bare-function-result-type-mismatch-diagnostic-code:' +
        Diagnostics.LastDiagnosticCode);
    if not SameText(Diagnostics.LastDiagnosticPhase, 'sema') then
      Fail('unexpected-bare-function-result-type-mismatch-diagnostic-phase:' +
        Diagnostics.LastDiagnosticPhase);
    if Pos('Pick', Diagnostics.LastDiagnosticMessage) <= 0 then
      Fail('bare-function-result-type-mismatch-diagnostic-missing-name');
    if Model = nil then
      Fail('missing-bare-function-result-type-mismatch-semantic-model');
    if not SameText(Model.Status, 'failure') then
      Fail('unexpected-bare-function-result-type-mismatch-model-status:' +
        Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-bare-function-result-type-mismatch-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckMemberFunctionResultTypeMismatchDiagnostic;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  SourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
begin
  SourceText :=
    'program MemberFunctionResultTypeMismatchCalls;' + LineEnding +
    'type' + LineEnding +
    '  TWorker = class' + LineEnding +
    '    procedure Pick(Value: Integer);' + LineEnding +
    '    procedure Run;' + LineEnding +
    '  end;' + LineEnding +
    'procedure TWorker.Pick(Value: Integer);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'function Flag: Boolean;' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'procedure TWorker.Run;' + LineEnding +
    'begin' + LineEnding +
    '  Self.Pick(Flag);' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
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
    if not Diagnostics.HasErrors then
      Fail('missing-member-function-result-type-mismatch-diagnostic');
    if not SameText(Diagnostics.LastDiagnosticCode, 'sema.type-mismatch') then
      Fail('unexpected-member-function-result-type-mismatch-diagnostic-code:' +
        Diagnostics.LastDiagnosticCode);
    if not SameText(Diagnostics.LastDiagnosticPhase, 'sema') then
      Fail('unexpected-member-function-result-type-mismatch-diagnostic-phase:' +
        Diagnostics.LastDiagnosticPhase);
    if Pos('Pick', Diagnostics.LastDiagnosticMessage) <= 0 then
      Fail('member-function-result-type-mismatch-diagnostic-missing-name');
    if Model = nil then
      Fail('missing-member-function-result-type-mismatch-semantic-model');
    if not SameText(Model.Status, 'failure') then
      Fail('unexpected-member-function-result-type-mismatch-model-status:' +
        Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-member-function-result-type-mismatch-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckImplicitSelfBareMethodFunctionResultTypeMismatchDiagnostic;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  SourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
begin
  SourceText :=
    'program ImplicitSelfBareMethodFunctionResultTypeMismatchCalls;' + LineEnding +
    'type' + LineEnding +
    '  TWorker = class' + LineEnding +
    '    procedure Pick(Value: Integer);' + LineEnding +
    '    procedure Run;' + LineEnding +
    '  end;' + LineEnding +
    'procedure TWorker.Pick(Value: Integer);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'function Flag: Boolean;' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'procedure TWorker.Run;' + LineEnding +
    'begin' + LineEnding +
    '  Pick(Flag);' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
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
    if not Diagnostics.HasErrors then
      Fail('missing-implicit-self-bare-method-function-result-type-mismatch-diagnostic');
    if not SameText(Diagnostics.LastDiagnosticCode, 'sema.type-mismatch') then
      Fail('unexpected-implicit-self-bare-method-function-result-type-mismatch-diagnostic-code:' +
        Diagnostics.LastDiagnosticCode);
    if not SameText(Diagnostics.LastDiagnosticPhase, 'sema') then
      Fail('unexpected-implicit-self-bare-method-function-result-type-mismatch-diagnostic-phase:' +
        Diagnostics.LastDiagnosticPhase);
    if Pos('Pick', Diagnostics.LastDiagnosticMessage) <= 0 then
      Fail('implicit-self-bare-method-function-result-type-mismatch-diagnostic-missing-name');
    if Model = nil then
      Fail('missing-implicit-self-bare-method-function-result-type-mismatch-semantic-model');
    if not SameText(Model.Status, 'failure') then
      Fail('unexpected-implicit-self-bare-method-function-result-type-mismatch-model-status:' +
        Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-implicit-self-bare-method-function-result-type-mismatch-binding-count:' +
        IntToStr(Model.BindingCount));
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

procedure CheckInheritedImplicitSelfBareMethodFunctionResultTypeMismatchDiagnostic;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  SourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
begin
  SourceText :=
    'program InheritedImplicitSelfBareMethodFunctionResultTypeMismatchCalls;' + LineEnding +
    'type' + LineEnding +
    '  TBaseWorker = class' + LineEnding +
    '    procedure Touch(Value: Integer);' + LineEnding +
    '  end;' + LineEnding +
    '  TWorker = class(TBaseWorker)' + LineEnding +
    '    procedure Run;' + LineEnding +
    '  end;' + LineEnding +
    'procedure TBaseWorker.Touch(Value: Integer);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'function Flag: Boolean;' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'procedure TWorker.Run;' + LineEnding +
    'begin' + LineEnding +
    '  Touch(Flag);' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
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
    if not Diagnostics.HasErrors then
      Fail('missing-inherited-implicit-self-bare-method-function-result-type-mismatch-diagnostic');
    if not SameText(Diagnostics.LastDiagnosticCode, 'sema.type-mismatch') then
      Fail('unexpected-inherited-implicit-self-bare-method-function-result-type-mismatch-diagnostic-code:' +
        Diagnostics.LastDiagnosticCode);
    if not SameText(Diagnostics.LastDiagnosticPhase, 'sema') then
      Fail('unexpected-inherited-implicit-self-bare-method-function-result-type-mismatch-diagnostic-phase:' +
        Diagnostics.LastDiagnosticPhase);
    if Pos('Touch', Diagnostics.LastDiagnosticMessage) <= 0 then
      Fail('inherited-implicit-self-bare-method-function-result-type-mismatch-diagnostic-missing-name');
    if Model = nil then
      Fail('missing-inherited-implicit-self-bare-method-function-result-type-mismatch-semantic-model');
    if not SameText(Model.Status, 'failure') then
      Fail('unexpected-inherited-implicit-self-bare-method-function-result-type-mismatch-model-status:' +
        Model.Status);
    if Model.BindingCount <> 0 then
      Fail('unexpected-inherited-implicit-self-bare-method-function-result-type-mismatch-binding-count:' +
        IntToStr(Model.BindingCount));
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
    CheckInheritedClassMemberCallBinding;
    CheckMemberOverloadBindingTargets;
    CheckMemberTypedOverloadBindingTargets;
    CheckAmbiguousMemberOverloadDiagnostic;
    CheckMemberNoMatchingOverloadDiagnostic;
    CheckInheritedMemberNoMatchingOverloadDiagnostic;
    CheckUnknownMemberDiagnostic;
    CheckKnownFieldMemberCallDiagnostic;
    CheckKnownPropertyMemberCallDiagnostic;
    CheckInheritedKnownFieldMemberCallDiagnostic;
    CheckInheritedKnownPropertyMemberCallDiagnostic;
    CheckSystemObjectFreeMemberCallStaysDeferred;
    CheckSourceBackedSystemObjectFreeMemberCallBinding;
    CheckImplicitSystemObjectFreeLowersToInheritedDestroy;
    CheckSpecializedGenericMemberCallStaysDeferred;
    CheckOverloadBindings;
    CheckBareTypedOverloadBindingTargets;
    CheckAmbiguousImportedBareOverloadDiagnostic;
    CheckImportedNoMatchingOverloadDiagnostic;
    CheckImportedFunctionResultNoMatchingOverloadDiagnostic;
    CheckInstalledSourceAmbiguousOverloadStaysDeferred;
    CheckInstalledSourceNoMatchingOverloadStaysDeferred;
    CheckImportedWrongArgumentCountDiagnostic;
    CheckInstalledSourceWrongArgumentCountStaysDeferred;
    CheckImportedCallTypeMismatchDiagnostic;
    CheckInstalledSourceCallTypeMismatchStaysDeferred;
    CheckImportedFunctionResultCallTypeMismatchDiagnostic;
    CheckInstalledSourceFunctionResultCallTypeMismatchStaysDeferred;
    CheckImportedUnknownMemberDiagnostic;
    CheckInstalledSourceUnknownMemberStaysDeferred;
    CheckImportedInheritedUnknownMemberDiagnostic;
    CheckImportedInheritedMemberAmbiguousOverloadDiagnostic;
    CheckImportedInheritedMemberFunctionResultNoMatchingOverloadDiagnostic;
    CheckImportedInheritedMemberFunctionResultAmbiguousOverloadDiagnostic;
    CheckImportedInheritedMemberWrongArgumentCountDiagnostic;
    CheckImportedInheritedMemberCallTypeMismatchDiagnostic;
    CheckImportedInheritedMemberNoMatchingOverloadDiagnostic;
    CheckImportedMemberWrongArgumentCountDiagnostic;
    CheckImportedMemberNoMatchingOverloadDiagnostic;
    CheckImportedMemberCallTypeMismatchDiagnostic;
    CheckInstalledSourceInheritedMemberAmbiguousOverloadStaysDeferred;
    CheckInstalledSourceInheritedUnknownMemberStaysDeferred;
    CheckInstalledSourceInheritedMemberWrongArgumentCountStaysDeferred;
    CheckInstalledSourceInheritedMemberCallTypeMismatchStaysDeferred;
    CheckInstalledSourceMemberWrongArgumentCountStaysDeferred;
    CheckInstalledSourceMemberNoMatchingOverloadStaysDeferred;
    CheckInstalledSourceInheritedMemberNoMatchingOverloadStaysDeferred;
    CheckInstalledSourceMemberCallTypeMismatchStaysDeferred;
    CheckImportedMemberFunctionResultCallTypeMismatchDiagnostic;
    CheckImportedInheritedMemberFunctionResultCallTypeMismatchDiagnostic;
    CheckInstalledSourceInheritedMemberFunctionResultCallTypeMismatchStaysDeferred;
    CheckInstalledSourceInheritedMemberFunctionResultNoMatchingOverloadStaysDeferred;
    CheckInstalledSourceInheritedMemberFunctionResultAmbiguousOverloadStaysDeferred;
    CheckBareNoMatchingOverloadDiagnostic;
    CheckBareWrongArgumentCountDiagnostic;
    CheckBareDefaultParameterCallBindings;
    CheckMemberWrongArgumentCountDiagnostic;
    CheckBareCallTypeMismatchDiagnostic;
    CheckMemberCallTypeMismatchDiagnostic;
    CheckBareVariableCallTypeMismatchDiagnostic;
    CheckMemberVariableCallTypeMismatchDiagnostic;
    CheckBareParameterCallTypeMismatchDiagnostic;
    CheckBareUnknownCallableDiagnostic;
    CheckInstalledSourceUnknownCallableStaysDeferred;
    CheckImplicitSelfBareMethodCallBinding;
    CheckImplicitSelfBareMethodUnknownMemberDiagnostic;
    CheckInheritedImplicitSelfBareMethodCallBinding;
    CheckInheritedImplicitSelfBareMethodCallArgumentBinding;
    CheckImplicitSelfBareMethodCallArgumentTypeMismatchDiagnostic;
    CheckImplicitSelfBareMethodCallWrongArgumentCountDiagnostic;
    CheckImplicitSelfBareMethodCallNoMatchingOverloadDiagnostic;
    CheckImplicitSelfBareMethodCallAmbiguousOverloadDiagnostic;
    CheckInheritedImplicitSelfBareMethodCallArgumentTypeMismatchDiagnostic;
    CheckInheritedImplicitSelfBareMethodCallWrongArgumentCountDiagnostic;
    CheckInheritedImplicitSelfBareMethodCallNoMatchingOverloadDiagnostic;
    CheckInheritedImplicitSelfBareMethodCallAmbiguousOverloadDiagnostic;
    CheckMemberParameterCallTypeMismatchDiagnostic;
    CheckBareFunctionResultTypeMismatchDiagnostic;
    CheckMemberFunctionResultTypeMismatchDiagnostic;
    CheckImplicitSelfBareMethodFunctionResultTypeMismatchDiagnostic;
    CheckInheritedImplicitSelfBareMethodFunctionResultTypeMismatchDiagnostic;
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
