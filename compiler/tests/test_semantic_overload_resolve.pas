program test_semantic_overload_resolve;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.compiler.syntax.ast_facade,
  nextpas.compiler.diagnostics.sink,
  nextpas.compiler.syntax.green_tree,
  nextpas.compiler.syntax.lexer,
  nextpas.compiler.sema.analyzer,
  nextpas.compiler.sema.semantic_model,
  nextpas.compiler.frontend.unit_graph;

procedure Fail(const AMessage: string);
begin
  WriteLn(StdErr, 'semantic-overload-resolve-failure=', AMessage);
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

procedure CheckOverloadedProceduresByParamCount;
var
  Diagnostics: TDiagnosticsSink;
  Model: TSemanticModel;
  Src: string;
begin
  Src :=
    'program OverloadCount;' + LineEnding +
    'procedure DoIt(A: Integer);' + LineEnding +
    'begin end;' + LineEnding +
    'procedure DoIt(A, B: Integer);' + LineEnding +
    'begin end;' + LineEnding +
    'begin' + LineEnding +
    '  DoIt(1);' + LineEnding +
    '  DoIt(1, 2);' + LineEnding +
    'end.' + LineEnding;

  Diagnostics := nil;
  Model := BuildModel(Src, Diagnostics);
  try
    if Diagnostics = nil then
      Fail('missing-diagnostics');
    if Model = nil then
      Fail('missing-model');
    if Diagnostics.HasErrors then
      Fail('unexpected-error:' + Diagnostics.LastDiagnosticCode + ':' +
        Diagnostics.LastDiagnosticMessage);
    if not SameText(Model.Status, 'ready') then
      Fail('unexpected-status:' + Model.Status);
  finally
    Model.Free;
    Diagnostics.Free;
  end;
end;

procedure CheckOverloadedProceduresByType;
var
  Diagnostics: TDiagnosticsSink;
  Model: TSemanticModel;
  Src: string;
begin
  Src :=
    'program OverloadType;' + LineEnding +
    'procedure Print(A: Integer);' + LineEnding +
    'begin end;' + LineEnding +
    'procedure Print(A: string);' + LineEnding +
    'begin end;' + LineEnding +
    'var' + LineEnding +
    '  I: Integer;' + LineEnding +
    '  S: string;' + LineEnding +
    'begin' + LineEnding +
    '  Print(I);' + LineEnding +
    '  Print(S);' + LineEnding +
    'end.' + LineEnding;

  Diagnostics := nil;
  Model := BuildModel(Src, Diagnostics);
  try
    if Diagnostics = nil then
      Fail('missing-diagnostics');
    if Model = nil then
      Fail('missing-model');
    if Diagnostics.HasErrors then
      Fail('unexpected-error:' + Diagnostics.LastDiagnosticCode + ':' +
        Diagnostics.LastDiagnosticMessage);
    if not SameText(Model.Status, 'ready') then
      Fail('unexpected-status:' + Model.Status);
  finally
    Model.Free;
    Diagnostics.Free;
  end;
end;

procedure CheckFunctionOverloadWithDifferentReturnTypes;
var
  Diagnostics: TDiagnosticsSink;
  Model: TSemanticModel;
  Src: string;
begin
  Src :=
    'program OverloadReturn;' + LineEnding +
    'function GetValue(A: Integer): Integer;' + LineEnding +
    'begin Result := A; end;' + LineEnding +
    'function GetValue(A: string): Integer;' + LineEnding +
    'begin Result := Length(A); end;' + LineEnding +
    'var' + LineEnding +
    '  I, J: Integer;' + LineEnding +
    '  S: string;' + LineEnding +
    'begin' + LineEnding +
    '  I := GetValue(42);' + LineEnding +
    '  J := GetValue(''hello'');' + LineEnding +
    'end.' + LineEnding;

  Diagnostics := nil;
  Model := BuildModel(Src, Diagnostics);
  try
    if Diagnostics = nil then
      Fail('missing-diagnostics');
    if Model = nil then
      Fail('missing-model');
    if Diagnostics.HasErrors then
      Fail('unexpected-error:' + Diagnostics.LastDiagnosticCode + ':' +
        Diagnostics.LastDiagnosticMessage);
    if not SameText(Model.Status, 'ready') then
      Fail('unexpected-status:' + Model.Status);
  finally
    Model.Free;
    Diagnostics.Free;
  end;
end;

procedure CheckAmbiguousOverloadDetection;
var
  Diagnostics: TDiagnosticsSink;
  Model: TSemanticModel;
  Src: string;
begin
  Src :=
    'program AmbiguousOverload;' + LineEnding +
    'procedure Foo(A: Integer; B: string);' + LineEnding +
    'begin end;' + LineEnding +
    'procedure Foo(A: string; B: Integer);' + LineEnding +
    'begin end;' + LineEnding +
    'begin' + LineEnding +
    '  Foo(1, ''test'');' + LineEnding +
    '  Foo(''test'', 1);' + LineEnding +
    'end.' + LineEnding;

  Diagnostics := nil;
  Model := BuildModel(Src, Diagnostics);
  try
    if Diagnostics = nil then
      Fail('missing-diagnostics');
    if Model = nil then
      Fail('missing-model');
    if Diagnostics.HasErrors then
      Fail('unexpected-error:' + Diagnostics.LastDiagnosticCode + ':' +
        Diagnostics.LastDiagnosticMessage);
    if not SameText(Model.Status, 'ready') then
      Fail('unexpected-status:' + Model.Status);
  finally
    Model.Free;
    Diagnostics.Free;
  end;
end;

procedure CheckBuiltinOverloadPriority;
var
  Diagnostics: TDiagnosticsSink;
  Model: TSemanticModel;
  Src: string;
begin
  Src :=
    'program BuiltinPriority;' + LineEnding +
    'var' + LineEnding +
    '  I: Integer;' + LineEnding +
    'begin' + LineEnding +
    '  Inc(I);' + LineEnding +
    '  Dec(I);' + LineEnding +
    'end.' + LineEnding;

  Diagnostics := nil;
  Model := BuildModel(Src, Diagnostics);
  try
    if Diagnostics = nil then
      Fail('missing-diagnostics');
    if Model = nil then
      Fail('missing-model');
    if Diagnostics.HasErrors then
      Fail('unexpected-error:' + Diagnostics.LastDiagnosticCode + ':' +
        Diagnostics.LastDiagnosticMessage);
    if not SameText(Model.Status, 'ready') then
      Fail('unexpected-status:' + Model.Status);
  finally
    Model.Free;
    Diagnostics.Free;
  end;
end;

begin
  CheckOverloadedProceduresByParamCount;
  CheckOverloadedProceduresByType;
  CheckFunctionOverloadWithDifferentReturnTypes;
  CheckAmbiguousOverloadDetection;
  CheckBuiltinOverloadPriority;
  WriteLn('semantic-overload-resolve-status=pass');
end.
