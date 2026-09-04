program test_semantic_expr_type_infer;

{$mode objfpc}{$H+}

uses
  nextpas.core.text.conv,
  nextpas.compiler.syntax.ast_facade,
  nextpas.compiler.diagnostics.sink,
  nextpas.compiler.syntax.green_tree,
  nextpas.compiler.syntax.lexer,
  nextpas.compiler.sema.analyzer,
  nextpas.compiler.sema.semantic_model,
  nextpas.compiler.frontend.unit_graph;

procedure Fail(const AMessage: string);
begin
  WriteLn(StdErr, 'semantic-expr-type-infer-failure=', AMessage);
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

procedure CheckAddExprType;
var
  Diagnostics: TDiagnosticsSink;
  Model: TSemanticModel;
  Src: string;
begin
  Src :=
    'program AddExpr;' + LineEnding +
    'var' + LineEnding +
    '  A, B, C: Integer;' + LineEnding +
    'begin' + LineEnding +
    '  C := A + B;' + LineEnding +
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

procedure CheckNegExprType;
var
  Diagnostics: TDiagnosticsSink;
  Model: TSemanticModel;
  Src: string;
begin
  Src :=
    'program NegExpr;' + LineEnding +
    'var' + LineEnding +
    '  A, B: Integer;' + LineEnding +
    'begin' + LineEnding +
    '  B := -A;' + LineEnding +
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

procedure CheckNotExprType;
var
  Diagnostics: TDiagnosticsSink;
  Model: TSemanticModel;
  Src: string;
begin
  Src :=
    'program NotExpr;' + LineEnding +
    'var' + LineEnding +
    '  A: Boolean;' + LineEnding +
    '  B: Integer;' + LineEnding +
    'begin' + LineEnding +
    '  A := not True;' + LineEnding +
    '  B := not 0;' + LineEnding +
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

procedure CheckMulExprType;
var
  Diagnostics: TDiagnosticsSink;
  Model: TSemanticModel;
  Src: string;
begin
  Src :=
    'program MulExpr;' + LineEnding +
    'var' + LineEnding +
    '  A, B, C: Integer;' + LineEnding +
    '  D: Double;' + LineEnding +
    'begin' + LineEnding +
    '  C := A * B;' + LineEnding +
    '  D := A * 3.14;' + LineEnding +
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

procedure CheckCallExprType;
var
  Diagnostics: TDiagnosticsSink;
  Model: TSemanticModel;
  Src: string;
begin
  Src :=
    'program CallExpr;' + LineEnding +
    'function DoubleIt(X: Integer): Integer;' + LineEnding +
    'begin' + LineEnding +
    '  Result := X * 2;' + LineEnding +
    'end;' + LineEnding +
    'var' + LineEnding +
    '  A, B: Integer;' + LineEnding +
    'begin' + LineEnding +
    '  B := DoubleIt(A);' + LineEnding +
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

procedure CheckComplexNestedExpr;
var
  Diagnostics: TDiagnosticsSink;
  Model: TSemanticModel;
  Src: string;
begin
  Src :=
    'program NestedExpr;' + LineEnding +
    'var' + LineEnding +
    '  A, B, C, D: Integer;' + LineEnding +
    'begin' + LineEnding +
    '  D := (A + B) * C - (A div 2);' + LineEnding +
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
  CheckAddExprType;
  CheckNegExprType;
  CheckNotExprType;
  CheckMulExprType;
  CheckCallExprType;
  CheckComplexNestedExpr;
  WriteLn('semantic-expr-type-infer-status=pass');
end.
