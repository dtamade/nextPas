program test_hir_string_call_argument_ownership_contract;

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

const
  DirectOwnedArgumentSource =
    'program test;' + LineEnding +
    'function MakeText: string;' + LineEnding +
    'var Suffix: string;' + LineEnding +
    'begin' + LineEnding +
    '  Suffix := ''tail'';' + LineEnding +
    '  MakeText := ''head'' + Suffix;' + LineEnding +
    'end;' + LineEnding +
    'procedure Take(P: string);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    '  Take(MakeText());' + LineEnding +
    'end.';

  MultiOwnedArgumentSource =
    'program test;' + LineEnding +
    'function MakeA: string;' + LineEnding +
    'begin' + LineEnding +
    '  MakeA := IntToStr(41);' + LineEnding +
    'end;' + LineEnding +
    'function MakeB: string;' + LineEnding +
    'begin' + LineEnding +
    '  MakeB := IntToStr(1);' + LineEnding +
    'end;' + LineEnding +
    'procedure Take2(A, B: string);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    '  Take2(MakeA(), MakeB());' + LineEnding +
    'end.';

  NestedOwnedArgumentSource =
    'program test;' + LineEnding +
    'function MakeText: string;' + LineEnding +
    'begin' + LineEnding +
    '  MakeText := IntToStr(42);' + LineEnding +
    'end;' + LineEnding +
    'function Wrap(P: string): string;' + LineEnding +
    'begin' + LineEnding +
    '  Wrap := P + ''!'';' + LineEnding +
    'end;' + LineEnding +
    'var S: string;' + LineEnding +
    'begin' + LineEnding +
    '  S := Wrap(MakeText());' + LineEnding +
    'end.';

  FieldOwnedArgumentSource =
    'program test;' + LineEnding +
    'type TStringBox = class' + LineEnding +
    '  Text: string;' + LineEnding +
    'end;' + LineEnding +
    'function MakeText: string;' + LineEnding +
    'begin' + LineEnding +
    '  MakeText := ''field'';' + LineEnding +
    'end;' + LineEnding +
    'var Box: TStringBox;' + LineEnding +
    'begin' + LineEnding +
    '  Box.Text := MakeText();' + LineEnding +
    'end.';

  VarParamOwnedArgumentSource =
    'program test;' + LineEnding +
    'function MakeText: string;' + LineEnding +
    'begin' + LineEnding +
    '  MakeText := ''var'';' + LineEnding +
    'end;' + LineEnding +
    'procedure TakeVar(var P: string);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    '  TakeVar(MakeText());' + LineEnding +
    'end.';

  OutParamOwnedArgumentSource =
    'program test;' + LineEnding +
    'function MakeText: string;' + LineEnding +
    'begin' + LineEnding +
    '  MakeText := ''out'';' + LineEnding +
    'end;' + LineEnding +
    'procedure TakeOut(out P: string);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    '  TakeOut(MakeText());' + LineEnding +
    'end.';

  ConcatLeftOwnedArgumentSource =
    'program test;' + LineEnding +
    'function MakeText: string;' + LineEnding +
    'begin' + LineEnding +
    '  MakeText := ''left'';' + LineEnding +
    'end;' + LineEnding +
    'var S: string;' + LineEnding +
    'begin' + LineEnding +
    '  S := MakeText() + ''x'';' + LineEnding +
    'end.';

  ConcatRightOwnedArgumentSource =
    'program test;' + LineEnding +
    'function MakeText: string;' + LineEnding +
    'begin' + LineEnding +
    '  MakeText := ''right'';' + LineEnding +
    'end;' + LineEnding +
    'var S: string;' + LineEnding +
    'begin' + LineEnding +
    '  S := ''x'' + MakeText();' + LineEnding +
    'end.';

  CompareOwnedArgumentSource =
    'program test;' + LineEnding +
    'function MakeText: string;' + LineEnding +
    'begin' + LineEnding +
    '  MakeText := ''x'';' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    '  if MakeText() = ''x'' then' + LineEnding +
    '    Halt(0);' + LineEnding +
    'end.';

  WriteLnOwnedArgumentSource =
    'program test;' + LineEnding +
    'function MakeText: string;' + LineEnding +
    'begin' + LineEnding +
    '  MakeText := ''write'';' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    '  WriteLn(MakeText());' + LineEnding +
    'end.';

  VirtualOwnedArgumentSource =
    'program test;' + LineEnding +
    'type TBase = class' + LineEnding +
    '  function MakeText: string; virtual;' + LineEnding +
    'end;' + LineEnding +
    'function TBase.MakeText: string;' + LineEnding +
    'begin' + LineEnding +
    '  MakeText := ''virtual'';' + LineEnding +
    'end;' + LineEnding +
    'procedure Take(P: string);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'var B: TBase;' + LineEnding +
    'begin' + LineEnding +
    '  Take(B.MakeText());' + LineEnding +
    'end.';

  InterfaceOwnedArgumentSource =
    'program test;' + LineEnding +
    'type ITextMaker = interface' + LineEnding +
    '  function MakeText: string;' + LineEnding +
    'end;' + LineEnding +
    'type TTextMaker = class(TInterfacedObject, ITextMaker)' + LineEnding +
    '  function MakeText: string;' + LineEnding +
    'end;' + LineEnding +
    'function TTextMaker.MakeText: string;' + LineEnding +
    'begin' + LineEnding +
    '  MakeText := ''interface'';' + LineEnding +
    'end;' + LineEnding +
    'procedure Take(P: string);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'var M: ITextMaker;' + LineEnding +
    'begin' + LineEnding +
    '  Take(M.MakeText());' + LineEnding +
    'end.';

  ExternalOwnedArgumentSource =
    'program test;' + LineEnding +
    'function MakeText: string; external name ''make_text'';' + LineEnding +
    'procedure Take(P: string);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    '  Take(MakeText());' + LineEnding +
    'end.';

procedure Fail(const AMessage: string);
begin
  WriteLn('hir-string-call-argument-ownership-contract-failure=', AMessage);
  Halt(1);
end;

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

function AnalyzeSourceHasAnyError(
  const ASource: string; const ACodeA, ACodeB: string): Boolean;
var
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  Tree: TGreenTree;
  Ast: TAstFacade;
  Graph: TUnitGraph;
  Analyzer: TSemanticAnalyzer;
  Code: string;
begin
  Result := False;
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
    if Diagnostics.HasErrors then
    begin
      Code := Diagnostics.LastDiagnosticCode;
      Result := SameText(Code, ACodeA) or SameText(Code, ACodeB);
    end;
  finally
    Analyzer.Free;
    Graph.Free;
    Ast.Free;
    Tree.Free;
    Lexer.Free;
    Diagnostics.Free;
  end;
end;

function FindFirstNodeByKind(const AModel: TSemanticModel;
  const AKind: string; out ANode: TTypedHirNode): Boolean;
var
  I: LongInt;
begin
  for I := 0 to AModel.TypedHirNodeCount - 1 do
  begin
    ANode := AModel.TypedHirNodeAt(I);
    if ANode.Kind = AKind then
      Exit(True);
  end;
  Result := False;
end;

function FindFirstNodeByKindAndDisplayName(const AModel: TSemanticModel;
  const AKind, ADisplayName: string; out ANode: TTypedHirNode): Boolean;
var
  I: LongInt;
begin
  for I := 0 to AModel.TypedHirNodeCount - 1 do
  begin
    ANode := AModel.TypedHirNodeAt(I);
    if (ANode.Kind = AKind) and SameText(ANode.DisplayName, ADisplayName) then
      Exit(True);
  end;
  Result := False;
end;

function FindNodeIndexByKindAndDisplayName(const AModel: TSemanticModel;
  const AKind, ADisplayName: string): LongInt;
var
  I: LongInt;
  Node: TTypedHirNode;
begin
  Result := -1;
  for I := 0 to AModel.TypedHirNodeCount - 1 do
  begin
    Node := AModel.TypedHirNodeAt(I);
    if (Node.Kind = AKind) and SameText(Node.DisplayName, ADisplayName) then
      Exit(I);
  end;
end;

procedure RequireAnalyzeDeferredError(const ASource, AMessage: string);
const
  C6H4Code = 'sema.c6h4-owned-string-return-deferred-consumer';
  C6H5Code = 'sema.c6h5-owned-string-temp-unsupported-consumer';
begin
  if not AnalyzeSourceHasAnyError(ASource, C6H4Code, C6H5Code) then
    Fail(AMessage);
end;

procedure AssertDeferredConsumersFailClosed;
begin
  RequireAnalyzeDeferredError(FieldOwnedArgumentSource,
    'field-owned-string-temp-consumer-must-fail-closed');
  RequireAnalyzeDeferredError(VarParamOwnedArgumentSource,
    'var-param-owned-string-temp-consumer-must-fail-closed');
  RequireAnalyzeDeferredError(OutParamOwnedArgumentSource,
    'out-param-owned-string-temp-consumer-must-fail-closed');
  RequireAnalyzeDeferredError(ConcatLeftOwnedArgumentSource,
    'concat-left-owned-string-temp-consumer-must-fail-closed');
  RequireAnalyzeDeferredError(ConcatRightOwnedArgumentSource,
    'concat-right-owned-string-temp-consumer-must-fail-closed');
  RequireAnalyzeDeferredError(CompareOwnedArgumentSource,
    'compare-owned-string-temp-consumer-must-fail-closed');
  RequireAnalyzeDeferredError(VirtualOwnedArgumentSource,
    'virtual-owned-string-temp-consumer-must-fail-closed');
  RequireAnalyzeDeferredError(InterfaceOwnedArgumentSource,
    'interface-owned-string-temp-consumer-must-fail-closed');
  RequireAnalyzeDeferredError(ExternalOwnedArgumentSource,
    'external-owned-string-temp-consumer-must-fail-closed');
end;

procedure AssertDirectArgumentTempOwnershipNodes;
var
  Model: TSemanticModel;
  Node: TTypedHirNode;
begin
  Model := BuildModel(DirectOwnedArgumentSource);
  try
    if Model = nil then
      Fail('direct-owned-argument-model-nil');
    if not FindFirstNodeByKindAndDisplayName(Model,
      'string-temp-owned-runtime', 'MakeText', Node) then
      Fail('missing-string-temp-owned-runtime');
    if Pos('ptr', Node.Operand) = 0 then
      Fail('string-temp-owned-runtime-missing-ptr-field');
    if Pos('len', Node.Operand) = 0 then
      Fail('string-temp-owned-runtime-missing-len-field');
    if Pos('owner', Node.Operand) = 0 then
      Fail('string-temp-owned-runtime-missing-owner-field');
    if Pos('alloc_size', Node.Operand) = 0 then
      Fail('string-temp-owned-runtime-missing-alloc-size-field');
    if not FindFirstNodeByKindAndDisplayName(Model,
      'string-temp-borrow-arg-runtime', 'Take', Node) then
      Fail('missing-string-temp-borrow-arg-runtime');
    if Pos('owner', Node.Operand) <> 0 then
      Fail('borrowed-string-param-must-not-pass-owner');
    if Pos('alloc_size', Node.Operand) <> 0 then
      Fail('borrowed-string-param-must-not-pass-alloc-size');
    if not FindFirstNodeByKindAndDisplayName(Model,
      'string-temp-release-runtime', 'MakeText', Node) then
      Fail('missing-string-temp-release-runtime');
  finally
    Model.Free;
  end;
end;

procedure AssertReverseReleaseOrder;
var
  Model: TSemanticModel;
  MakeAIndex, MakeBIndex, ReleaseAIndex, ReleaseBIndex: LongInt;
begin
  Model := BuildModel(MultiOwnedArgumentSource);
  try
    if Model = nil then
      Fail('multi-owned-argument-model-nil');
    MakeAIndex := FindNodeIndexByKindAndDisplayName(Model,
      'string-temp-owned-runtime', 'MakeA');
    MakeBIndex := FindNodeIndexByKindAndDisplayName(Model,
      'string-temp-owned-runtime', 'MakeB');
    ReleaseAIndex := FindNodeIndexByKindAndDisplayName(Model,
      'string-temp-release-runtime', 'MakeA');
    ReleaseBIndex := FindNodeIndexByKindAndDisplayName(Model,
      'string-temp-release-runtime', 'MakeB');
    if MakeAIndex < 0 then
      Fail('missing-makea-string-temp-owned-runtime');
    if MakeBIndex < 0 then
      Fail('missing-makeb-string-temp-owned-runtime');
    if ReleaseAIndex < 0 then
      Fail('missing-makea-string-temp-release-runtime');
    if ReleaseBIndex < 0 then
      Fail('missing-makeb-string-temp-release-runtime');
    if MakeAIndex >= MakeBIndex then
      Fail('owned-string-temp-creation-order-must-follow-argument-order');
    if ReleaseBIndex >= ReleaseAIndex then
      Fail('owned-string-temp-release-order-must-be-reverse-creation');
    if ReleaseBIndex <= MakeBIndex then
      Fail('owned-string-temp-release-must-follow-enclosing-call');
  finally
    Model.Free;
  end;
end;

procedure AssertNestedArgumentTempOwnershipNodes;
var
  Model: TSemanticModel;
  Node: TTypedHirNode;
  InnerReleaseIndex, OuterAssignIndex: LongInt;
begin
  Model := BuildModel(NestedOwnedArgumentSource);
  try
    if Model = nil then
      Fail('nested-owned-argument-model-nil');
    if not FindFirstNodeByKindAndDisplayName(Model,
      'string-temp-owned-runtime', 'MakeText', Node) then
      Fail('missing-nested-string-temp-owned-runtime');
    if not FindFirstNodeByKindAndDisplayName(Model,
      'string-temp-borrow-arg-runtime', 'Wrap', Node) then
      Fail('missing-nested-string-temp-borrow-arg-runtime');
    InnerReleaseIndex := FindNodeIndexByKindAndDisplayName(Model,
      'string-temp-release-runtime', 'MakeText');
    OuterAssignIndex := FindNodeIndexByKindAndDisplayName(Model,
      'assign-str-owned-call-runtime', 'S');
    if InnerReleaseIndex < 0 then
      Fail('missing-nested-string-temp-release-runtime');
    if OuterAssignIndex < 0 then
      Fail('missing-outer-owned-return-assignment-runtime');
    if InnerReleaseIndex <= OuterAssignIndex then
      Fail('inner-temp-release-must-follow-wrap-call-materialization');
  finally
    Model.Free;
  end;
end;

procedure AssertWriteLnArgumentTempOwnershipNodes;
var
  Model: TSemanticModel;
  Node: TTypedHirNode;
  OwnedIndex, WriteIndex, ReleaseIndex: LongInt;
begin
  Model := BuildModel(WriteLnOwnedArgumentSource);
  try
    if Model = nil then
      Fail('writeln-owned-argument-model-nil');
    if not FindFirstNodeByKindAndDisplayName(Model,
      'string-temp-owned-runtime', 'MakeText', Node) then
      Fail('missing-writeln-string-temp-owned-runtime');
    if Pos('ptr', Node.Operand) = 0 then
      Fail('writeln-string-temp-owned-runtime-missing-ptr-field');
    if Pos('len', Node.Operand) = 0 then
      Fail('writeln-string-temp-owned-runtime-missing-len-field');
    if Pos('owner', Node.Operand) = 0 then
      Fail('writeln-string-temp-owned-runtime-missing-owner-field');
    if Pos('alloc_size', Node.Operand) = 0 then
      Fail('writeln-string-temp-owned-runtime-missing-alloc-size-field');
    if not FindFirstNodeByKindAndDisplayName(Model,
      'write-str-var-runtime', 'Write', Node) then
      Fail('missing-writeln-string-temp-write-runtime');
    if Pos('owner', Node.Operand) <> 0 then
      Fail('writeln-string-writer-must-not-receive-owner');
    if Pos('alloc_size', Node.Operand) <> 0 then
      Fail('writeln-string-writer-must-not-receive-alloc-size');
    if not FindFirstNodeByKindAndDisplayName(Model,
      'string-temp-release-runtime', 'MakeText', Node) then
      Fail('missing-writeln-string-temp-release-runtime');

    OwnedIndex := FindNodeIndexByKindAndDisplayName(Model,
      'string-temp-owned-runtime', 'MakeText');
    WriteIndex := FindNodeIndexByKindAndDisplayName(Model,
      'write-str-var-runtime', 'Write');
    ReleaseIndex := FindNodeIndexByKindAndDisplayName(Model,
      'string-temp-release-runtime', 'MakeText');
    if (OwnedIndex < 0) or (WriteIndex < 0) or (ReleaseIndex < 0) then
      Fail('missing-writeln-string-temp-order-node');
    if OwnedIndex >= WriteIndex then
      Fail('writeln-string-temp-owned-must-precede-write');
    if WriteIndex >= ReleaseIndex then
      Fail('writeln-string-temp-release-must-follow-write');
  finally
    Model.Free;
  end;
end;

begin
  AssertDirectArgumentTempOwnershipNodes;
  AssertReverseReleaseOrder;
  AssertNestedArgumentTempOwnershipNodes;
  AssertWriteLnArgumentTempOwnershipNodes;
  AssertDeferredConsumersFailClosed;
  WriteLn('hir-string-call-argument-ownership-contract-status=pass');
end.
