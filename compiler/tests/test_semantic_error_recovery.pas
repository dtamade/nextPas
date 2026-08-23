program test_semantic_error_recovery;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.compiler.syntax.ast_facade,
  nextpas.compiler.diagnostics.sink,
  nextpas.compiler.syntax.green_tree,
  nextpas.compiler.syntax.lexer,
  np_semantic_analyzer,
  np_semantic_model,
  np_unit_graph;

procedure Fail(const AMessage: string);
begin
  WriteLn(StdErr, 'semantic-error-recovery-failure=', AMessage);
  Halt(1);
end;

function BuildModel(const ASource: string; out ADiagnostics: TDiagnosticsSink
): TSemanticModel;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Graph: TUnitGraph;
  Lexer: TLexerResult;
  Tree: TGreenTree;
begin
  Result := nil;
  Analyzer := nil;
  Ast := nil;
  Graph := nil;
  Lexer := nil;
  Tree := nil;
  ADiagnostics := nil;
  try
    ADiagnostics := TDiagnosticsSink.CreateDefault;
    Lexer := TLexerResult.Create(ASource, ADiagnostics, 1);
    Tree := ParseGreenTree(Lexer, ADiagnostics, 1);
    Ast := TAstFacade.Create(Tree);
    Graph := TUnitGraph.Create;
    Graph.SetRootName(Ast.DeclaredName);
    Graph.MarkReady;
    Analyzer := TSemanticAnalyzer.Create(Ast, Graph, ADiagnostics, 1, True);
    Analyzer.Analyze;
    Result := Analyzer.DetachModel;
  finally
    Analyzer.Free;
    Graph.Free;
    Ast.Free;
    Tree.Free;
    Lexer.Free;
  end;
end;

{ Missing semicolon should produce error but not crash }
procedure CheckMissingSemicolon;
var
  Diagnostics: TDiagnosticsSink;
  Model: TSemanticModel;
  Src: string;
begin
  Src :=
    'program MissingSemi;' + LineEnding +
    'var A: Integer' + LineEnding +  { missing ; }
    'begin' + LineEnding +
    'end.' + LineEnding;

  Diagnostics := nil;
  Model := BuildModel(Src, Diagnostics);
  try
    if Diagnostics = nil then
      Fail('missing-diagnostics');
    { Should have errors but should not crash }
    if not Diagnostics.HasErrors then
      Fail('expected-error-for-missing-semicolon');
    { Model should still be produced (error recovery) }
    if Model = nil then
      Fail('missing-model-after-error');
  finally
    Model.Free;
    Diagnostics.Free;
  end;
end;

{ Unknown type should produce error but not crash }
procedure CheckUnknownType;
var
  Diagnostics: TDiagnosticsSink;
  Model: TSemanticModel;
  Src: string;
begin
  Src :=
    'program UnknownType;' + LineEnding +
    'var X: NoSuchType;' + LineEnding +
    'begin' + LineEnding +
    'end.' + LineEnding;

  Diagnostics := nil;
  Model := BuildModel(Src, Diagnostics);
  try
    if Diagnostics = nil then
      Fail('missing-diagnostics');
    if not Diagnostics.HasErrors then
      Fail('expected-error-for-unknown-type');
    if Model = nil then
      Fail('missing-model-after-error');
  finally
    Model.Free;
    Diagnostics.Free;
  end;
end;

{ Unknown variable reference should produce error }
procedure CheckUnknownVariable;
var
  Diagnostics: TDiagnosticsSink;
  Model: TSemanticModel;
  Src: string;
begin
  Src :=
    'program UnknownVar;' + LineEnding +
    'begin' + LineEnding +
    '  NoSuchVar := 1;' + LineEnding +
    'end.' + LineEnding;

  Diagnostics := nil;
  Model := BuildModel(Src, Diagnostics);
  try
    if Diagnostics = nil then
      Fail('missing-diagnostics');
    if not Diagnostics.HasErrors then
      Fail('expected-error-for-unknown-var');
  finally
    Model.Free;
    Diagnostics.Free;
  end;
end;

{ Type mismatch in assignment should produce error }
procedure CheckTypeMismatch;
var
  Diagnostics: TDiagnosticsSink;
  Model: TSemanticModel;
  Src: string;
begin
  Src :=
    'program TypeMismatch;' + LineEnding +
    'var I: Integer;' + LineEnding +
    'begin' + LineEnding +
    '  I := ''not an integer'';' + LineEnding +
    'end.' + LineEnding;

  Diagnostics := nil;
  Model := BuildModel(Src, Diagnostics);
  try
    if Diagnostics = nil then
      Fail('missing-diagnostics');
    if not Diagnostics.HasErrors then
      Fail('expected-error-for-type-mismatch');
  finally
    Model.Free;
    Diagnostics.Free;
  end;
end;

{ Duplicate identifier should produce error }
procedure CheckDuplicateIdentifier;
var
  Diagnostics: TDiagnosticsSink;
  Model: TSemanticModel;
  Src: string;
begin
  Src :=
    'program DupId;' + LineEnding +
    'var X: Integer;' + LineEnding +
    'var X: string;' + LineEnding +  { duplicate }
    'begin' + LineEnding +
    'end.' + LineEnding;

  Diagnostics := nil;
  Model := BuildModel(Src, Diagnostics);
  try
    if Diagnostics = nil then
      Fail('missing-diagnostics');
    if not Diagnostics.HasErrors then
      Fail('expected-error-for-duplicate-identifier');
  finally
    Model.Free;
    Diagnostics.Free;
  end;
end;

begin
  CheckMissingSemicolon;
  CheckUnknownType;
  CheckUnknownVariable;
  CheckTypeMismatch;
  CheckDuplicateIdentifier;
  WriteLn('semantic-error-recovery-status=pass');
end.
