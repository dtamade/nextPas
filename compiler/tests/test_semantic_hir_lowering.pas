program test_semantic_hir_lowering;

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
  WriteLn(StdErr, 'semantic-hir-lowering-failure=', AMessage);
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

procedure CheckSimpleProcedureBody;
var
  Diagnostics: TDiagnosticsSink;
  Model: TSemanticModel;
  Src: string;
begin
  Src :=
    'program SimpleProc;' + LineEnding +
    'procedure P;' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    '  P;' + LineEnding +
    'end.' + LineEnding;

  Diagnostics := nil;
  Model := BuildModel(Src, Diagnostics);
  try
    if Diagnostics = nil then
      Fail('missing-diagnostics');
    if Model = nil then
      Fail('missing-model');
    if Diagnostics.HasErrors then
      Fail('unexpected-error:' + Diagnostics.LastDiagnosticCode);
    if not SameText(Model.Status, 'ready') then
      Fail('unexpected-status:' + Model.Status);
  finally
    Model.Free;
    Diagnostics.Free;
  end;
end;

procedure CheckFunctionWithReturn;
var
  Diagnostics: TDiagnosticsSink;
  Model: TSemanticModel;
  Src: string;
begin
  Src :=
    'program FuncReturn;' + LineEnding +
    'function F: Integer;' + LineEnding +
    'begin' + LineEnding +
    '  Result := 42;' + LineEnding +
    'end;' + LineEnding +
    'var X: Integer;' + LineEnding +
    'begin' + LineEnding +
    '  X := F;' + LineEnding +
    'end.' + LineEnding;

  Diagnostics := nil;
  Model := BuildModel(Src, Diagnostics);
  try
    if Diagnostics = nil then
      Fail('missing-diagnostics');
    if Model = nil then
      Fail('missing-model');
    if Diagnostics.HasErrors then
      Fail('unexpected-error:' + Diagnostics.LastDiagnosticCode);
    if not SameText(Model.Status, 'ready') then
      Fail('unexpected-status:' + Model.Status);
  finally
    Model.Free;
    Diagnostics.Free;
  end;
end;

procedure CheckVarDeclWithInit;
var
  Diagnostics: TDiagnosticsSink;
  Model: TSemanticModel;
  Src: string;
begin
  Src :=
    'program VarInit;' + LineEnding +
    'var' + LineEnding +
    '  A: Integer = 10;' + LineEnding +
    'begin' + LineEnding +
    'end.' + LineEnding;

  Diagnostics := nil;
  Model := BuildModel(Src, Diagnostics);
  try
    if Diagnostics = nil then
      Fail('missing-diagnostics');
    if Model = nil then
      Fail('missing-model');
    if Diagnostics.HasErrors then
      Fail('unexpected-error:' + Diagnostics.LastDiagnosticCode);
    if not SameText(Model.Status, 'ready') then
      Fail('unexpected-status:' + Model.Status);
  finally
    Model.Free;
    Diagnostics.Free;
  end;
end;

procedure CheckIfStatement;
var
  Diagnostics: TDiagnosticsSink;
  Model: TSemanticModel;
  Src: string;
begin
  Src :=
    'program IfStmt;' + LineEnding +
    'var A, B: Integer;' + LineEnding +
    'begin' + LineEnding +
    '  if A > B then' + LineEnding +
    '    A := 1' + LineEnding +
    '  else' + LineEnding +
    '    A := 2;' + LineEnding +
    'end.' + LineEnding;

  Diagnostics := nil;
  Model := BuildModel(Src, Diagnostics);
  try
    if Diagnostics = nil then
      Fail('missing-diagnostics');
    if Model = nil then
      Fail('missing-model');
    if Diagnostics.HasErrors then
      Fail('unexpected-error:' + Diagnostics.LastDiagnosticCode);
    if not SameText(Model.Status, 'ready') then
      Fail('unexpected-status:' + Model.Status);
  finally
    Model.Free;
    Diagnostics.Free;
  end;
end;

procedure CheckWhileLoop;
var
  Diagnostics: TDiagnosticsSink;
  Model: TSemanticModel;
  Src: string;
begin
  Src :=
    'program WhileLoop;' + LineEnding +
    'var I: Integer;' + LineEnding +
    'begin' + LineEnding +
    '  while I < 10 do' + LineEnding +
    '    I := I + 1;' + LineEnding +
    'end.' + LineEnding;

  Diagnostics := nil;
  Model := BuildModel(Src, Diagnostics);
  try
    if Diagnostics = nil then
      Fail('missing-diagnostics');
    if Model = nil then
      Fail('missing-model');
    if Diagnostics.HasErrors then
      Fail('unexpected-error:' + Diagnostics.LastDiagnosticCode);
    if not SameText(Model.Status, 'ready') then
      Fail('unexpected-status:' + Model.Status);
  finally
    Model.Free;
    Diagnostics.Free;
  end;
end;

procedure CheckForLoop;
var
  Diagnostics: TDiagnosticsSink;
  Model: TSemanticModel;
  Src: string;
begin
  Src :=
    'program ForLoop;' + LineEnding +
    'var I: Integer;' + LineEnding +
    'begin' + LineEnding +
    '  for I := 1 to 10 do' + LineEnding +
    '    WriteLn(I);' + LineEnding +
    'end.' + LineEnding;

  Diagnostics := nil;
  Model := BuildModel(Src, Diagnostics);
  try
    if Diagnostics = nil then
      Fail('missing-diagnostics');
    if Model = nil then
      Fail('missing-model');
    if Diagnostics.HasErrors then
      Fail('unexpected-error:' + Diagnostics.LastDiagnosticCode);
    if not SameText(Model.Status, 'ready') then
      Fail('unexpected-status:' + Model.Status);
  finally
    Model.Free;
    Diagnostics.Free;
  end;
end;

procedure CheckStringConcat;
var
  Diagnostics: TDiagnosticsSink;
  Model: TSemanticModel;
  Src: string;
begin
  Src :=
    'program StrConcat;' + LineEnding +
    'var S: string;' + LineEnding +
    'begin' + LineEnding +
    '  S := ''Hello '' + ''World'';' + LineEnding +
    'end.' + LineEnding;

  Diagnostics := nil;
  Model := BuildModel(Src, Diagnostics);
  try
    if Diagnostics = nil then
      Fail('missing-diagnostics');
    if Model = nil then
      Fail('missing-model');
    if Diagnostics.HasErrors then
      Fail('unexpected-error:' + Diagnostics.LastDiagnosticCode);
    if not SameText(Model.Status, 'ready') then
      Fail('unexpected-status:' + Model.Status);
  finally
    Model.Free;
    Diagnostics.Free;
  end;
end;

begin
  CheckSimpleProcedureBody;
  CheckFunctionWithReturn;
  CheckVarDeclWithInit;
  CheckIfStatement;
  CheckWhileLoop;
  CheckForLoop;
  CheckStringConcat;
  WriteLn('semantic-hir-lowering-status=pass');
end.
