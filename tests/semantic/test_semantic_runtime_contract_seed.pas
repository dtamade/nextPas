program test_semantic_runtime_contract_seed;

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
  WriteLn(StdErr, 'semantic-runtime-contract-seed-failure=', AMessage);
  Halt(1);
end;

function BuildModel(const ASource: string; const ARootName: string
): TSemanticModel;
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
    Graph.SetRootName(ARootName);
    Graph.MarkReady;
    Analyzer := TSemanticAnalyzer.Create(Ast, Graph, Diagnostics, 1, True);
    Analyzer.Analyze;
    if Diagnostics.HasErrors then
      Fail('unexpected-diagnostics');
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

function RuntimeContractNodeCount(const AModel: TSemanticModel;
  const AContractName: string): LongInt;
var
  Index: LongInt;
  Node: TTypedHirNode;
begin
  Result := 0;
  for Index := 0 to AModel.TypedHirNodeCount - 1 do
  begin
    Node := AModel.TypedHirNodeAt(Index);
    if (Node.Kind = 'runtime-contract') and
      SameText(Node.DisplayName, AContractName) then
      Inc(Result);
  end;
end;

procedure AssertRuntimeContractAt(const AModel: TSemanticModel;
  const AIndex: LongInt; const AExpectedName: string);
var
  Contract: TRuntimeContract;
begin
  Contract := AModel.RuntimeContractAt(AIndex);
  if Contract.ContractId <> AIndex + 1 then
    Fail('runtime-contract-id-mismatch:' + IntToStr(AIndex));
  if not SameText(Contract.Name, AExpectedName) then
    Fail('runtime-contract-name-mismatch:' + IntToStr(AIndex) + ':' +
      Contract.Name);
  if RuntimeContractNodeCount(AModel, AExpectedName) <> 1 then
    Fail('runtime-contract-node-count-mismatch:' + AExpectedName);
end;

procedure CheckProgramSeedsProcessContracts;
var
  Model: TSemanticModel;
begin
  Model := BuildModel(
    'program ContractSeed;' + LineEnding +
    'begin' + LineEnding +
    'end.' + LineEnding,
    'ContractSeed'
  );
  try
    if Model = nil then
      Fail('program-model-nil');
    if Model.Status <> 'ready' then
      Fail('program-model-not-ready:' + Model.Status);
    if Model.RuntimeContractCount <> 2 then
      Fail('program-runtime-contract-count:' +
        IntToStr(Model.RuntimeContractCount));

    AssertRuntimeContractAt(Model, 0, 'np.system.process_init');
    AssertRuntimeContractAt(Model, 1, 'np.system.process_fini');

    if RuntimeContractNodeCount(Model, 'np.system.unit_init') <> 0 then
      Fail('program-must-not-seed-unit-init');
    if RuntimeContractNodeCount(Model, 'np.system.unit_fini') <> 0 then
      Fail('program-must-not-seed-unit-fini');
  finally
    Model.Free;
  end;
end;

procedure CheckUnitDoesNotSeedProcessContracts;
var
  Model: TSemanticModel;
begin
  Model := BuildModel(
    'unit ContractSeedUnit;' + LineEnding +
    'interface' + LineEnding +
    'implementation' + LineEnding +
    'end.' + LineEnding,
    'ContractSeedUnit'
  );
  try
    if Model = nil then
      Fail('unit-model-nil');
    if Model.Status <> 'ready' then
      Fail('unit-model-not-ready:' + Model.Status);
    if Model.RuntimeContractCount <> 0 then
      Fail('unit-runtime-contract-count:' +
        IntToStr(Model.RuntimeContractCount));
    if RuntimeContractNodeCount(Model, 'np.system.process_init') <> 0 then
      Fail('unit-must-not-seed-process-init');
    if RuntimeContractNodeCount(Model, 'np.system.process_fini') <> 0 then
      Fail('unit-must-not-seed-process-fini');
  finally
    Model.Free;
  end;
end;

begin
  CheckProgramSeedsProcessContracts;
  CheckUnitDoesNotSeedProcessContracts;
  WriteLn('semantic-runtime-contract-seed-status=pass');
end.
