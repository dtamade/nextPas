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

    CheckOverloadBindings;

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
