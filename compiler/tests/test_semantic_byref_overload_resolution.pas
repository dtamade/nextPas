program test_semantic_byref_overload_resolution;

{$mode objfpc}{$H+}

uses
  nextpas.compiler.syntax.ast_facade,
  nextpas.compiler.diagnostics.sink,
  nextpas.compiler.syntax.green_tree,
  nextpas.compiler.syntax.lexer,
  np_semantic_analyzer,
  np_semantic_model,
  np_unit_graph;

function BuildModel(const ASource: string): TSemanticModel;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  Graph: TUnitGraph;
  Lexer: TLexerResult;
  Tree: TGreenTree;
begin
  Result := nil;
  Analyzer := nil;
  Ast := nil;
  Diagnostics := nil;
  Graph := nil;
  Lexer := nil;
  Tree := nil;
  try
    Diagnostics := TDiagnosticsSink.CreateDefault;
    Lexer := TLexerResult.Create(ASource, Diagnostics, 1);
    Tree := ParseGreenTree(Lexer, Diagnostics, 1);
    Ast := TAstFacade.Create(Tree);
    Graph := TUnitGraph.Create;
    Graph.SetRootName(Ast.DeclaredName);
    Graph.MarkReady;
    Analyzer := TSemanticAnalyzer.Create(Ast, Graph, Diagnostics, 1, True);
    Analyzer.Analyze;
    Result := Analyzer.DetachModel;
  finally
    Analyzer.Free;
    Graph.Free;
    Ast.Free;
    Tree.Free;
    Lexer.Free;
    Diagnostics.Free;
  end;
end;

var
  Model: TSemanticModel;
begin
  Model := BuildModel(
    'program byref_overload;'#10 +
    'function AtomicNotifyAll(var AValue: Int32): Integer; overload;'#10 +
    'begin'#10 +
    '  Result := 32;'#10 +
    'end;'#10 +
    'function AtomicNotifyAll(var AValue: UInt32): Integer; overload;'#10 +
    'begin'#10 +
    '  Result := 64;'#10 +
    'end;'#10 +
    'function UseNotify32(var AValue: Int32): Integer;'#10 +
    'begin'#10 +
    '  Result := AtomicNotifyAll(AValue);'#10 +
    'end;'#10 +
    'var'#10 +
    '  Value32: Int32;'#10 +
    'begin'#10 +
    '  Value32 := 0;'#10 +
    '  if UseNotify32(Value32) <> 32 then'#10 +
    '    Halt(1);'#10 +
    'end.'#10
  );
  try
    if (Model = nil) or (Model.Status <> 'ready') then
      Halt(1);
  finally
    Model.Free;
  end;
end.
