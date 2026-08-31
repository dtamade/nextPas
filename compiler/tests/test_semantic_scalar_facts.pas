program test_semantic_scalar_facts;

{$mode objfpc}{$H+}

uses
  nextpas.compiler.syntax.ast_facade,
  nextpas.compiler.diagnostics.sink,
  nextpas.compiler.syntax.green_tree,
  nextpas.compiler.syntax.lexer,
  nextpas.compiler.sema.analyzer,
  nextpas.compiler.sema.semantic_model,
  nextpas.compiler.frontend.unit_graph;

function BuildModel(const ASource: string): TSemanticModel;
var
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  Tree: TGreenTree;
  Ast: TAstFacade;
  Graph: TUnitGraph;
  Analyzer: TSemanticAnalyzer;
begin
  Result := nil;
  Diagnostics := TDiagnosticsSink.CreateDefault;
  Lexer := nil;
  Tree := nil;
  Ast := nil;
  Graph := nil;
  Analyzer := nil;
  try
    Lexer := TLexerResult.Create(ASource, Diagnostics, 1);
    Tree := ParseGreenTree(Lexer, Diagnostics, 1);
    Ast := TAstFacade.Create(Tree);
    Graph := TUnitGraph.Create;
    Graph.SetRootName('test');
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

procedure AssertScalarFact(const AModel: TSemanticModel;
  const ATypeName: string; const AExpectedKind: TSemanticScalarKind;
  const AExpectedBitWidth: LongInt; const AExpectedSigned: Boolean;
  const ABaseCode: LongInt);
var
  TypeId: LongInt;
  Fact: TSemanticScalarTypeFact;
begin
  TypeId := AModel.FindTypeByName(ATypeName);
  if TypeId <= 0 then
    Halt(ABaseCode);
  if not AModel.GetTypeScalarFact(TypeId, Fact) then
    Halt(ABaseCode + 1);
  if Fact.TypeId <> TypeId then
    Halt(ABaseCode + 2);
  if Fact.Kind <> AExpectedKind then
    Halt(ABaseCode + 3);
  if Fact.BitWidth <> AExpectedBitWidth then
    Halt(ABaseCode + 4);
  if Fact.Signed <> AExpectedSigned then
    Halt(ABaseCode + 5);
end;

procedure AssertTypeExists(const AModel: TSemanticModel;
  const ATypeName: string; const ABaseCode: LongInt);
begin
  if AModel.FindTypeByName(ATypeName) <= 0 then
    Halt(ABaseCode);
end;

var
  Model: TSemanticModel;
  Fact: TSemanticScalarTypeFact;
begin
  Model := BuildModel(
    'program test;'#10 +
    'begin'#10 +
    'end.'#10
  );
  try
    if Model = nil then
      Halt(1);
    if Model.Status <> 'ready' then
      Halt(2);

    AssertScalarFact(Model, 'Boolean', sskBool, 1, False, 10);
    AssertScalarFact(Model, 'Char', sskInt, 8, False, 20);
    AssertScalarFact(Model, 'Byte', sskInt, 8, False, 30);
    AssertScalarFact(Model, 'Word', sskInt, 16, False, 40);
    AssertScalarFact(Model, 'Integer', sskInt, 32, True, 50);
    AssertScalarFact(Model, 'LongInt', sskInt, 32, True, 60);
    AssertScalarFact(Model, 'LongWord', sskInt, 32, False, 70);
    AssertScalarFact(Model, 'Cardinal', sskInt, 32, False, 80);
    AssertScalarFact(Model, 'Int64', sskInt, 64, True, 90);
    AssertScalarFact(Model, 'QWord', sskInt, 64, False, 100);
    AssertScalarFact(Model, 'Single', sskFloat, 32, False, 110);
    AssertScalarFact(Model, 'Double', sskFloat, 64, False, 120);
    AssertScalarFact(Model, 'Pointer', sskPointer, 64, False, 130);
    AssertScalarFact(Model, 'ShortInt', sskInt, 8, True, 140);
    AssertScalarFact(Model, 'SmallInt', sskInt, 16, True, 150);
    AssertScalarFact(Model, 'Int32', sskInt, 32, True, 160);
    AssertScalarFact(Model, 'UInt32', sskInt, 32, False, 170);
    AssertScalarFact(Model, 'UInt64', sskInt, 64, False, 180);
    AssertScalarFact(Model, 'WideChar', sskInt, 16, False, 190);
    AssertScalarFact(Model, 'PByte', sskPointer, 64, False, 200);
    AssertScalarFact(Model, 'PWord', sskPointer, 64, False, 210);
    AssertScalarFact(Model, 'PInt32', sskPointer, 64, False, 220);
    AssertScalarFact(Model, 'PInt16', sskPointer, 64, False, 230);
    AssertScalarFact(Model, 'PChar', sskPointer, 64, False, 240);
    AssertScalarFact(Model, 'PAnsiChar', sskPointer, 64, False, 250);
    AssertTypeExists(Model, 'RawByteString', 260);

    if Model.GetTypeScalarFact(9999, Fact) then
      Halt(270);
  finally
    Model.Free;
  end;
end.
