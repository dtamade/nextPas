program test_hir_string_length_ownership_contract;

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
  DirectLengthOwnedTempSource =
    'program test;' + LineEnding +
    'function MakeText: string;' + LineEnding +
    'begin' + LineEnding +
    '  MakeText := IntToStr(42) + ''tail'';' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    '  Halt(Length(MakeText()) + 36);' + LineEnding +
    'end.';

  RepeatedLengthOwnedTempSource =
    'program test;' + LineEnding +
    'function MakeA: string;' + LineEnding +
    'begin' + LineEnding +
    '  MakeA := IntToStr(41);' + LineEnding +
    'end;' + LineEnding +
    'function MakeB: string;' + LineEnding +
    'begin' + LineEnding +
    '  MakeB := IntToStr(1);' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    '  Halt(Length(MakeA()) + Length(MakeB()) + 39);' + LineEnding +
    'end.';

  ConcatLengthOwnedTempSource =
    'program test;' + LineEnding +
    'function MakeText: string;' + LineEnding +
    'begin' + LineEnding +
    '  MakeText := ''xy'';' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    '  Halt(Length(MakeText() + ''z'') + 39);' + LineEnding +
    'end.';

  CopyOwnedTempSource =
    'program test;' + LineEnding +
    'function MakeText: string;' + LineEnding +
    'begin' + LineEnding +
    '  MakeText := IntToStr(42) + ''tail'';' + LineEnding +
    'end;' + LineEnding +
    'var S: string;' + LineEnding +
    'begin' + LineEnding +
    '  S := Copy(MakeText(), 2, 2);' + LineEnding +
    'end.';

procedure Fail(const AMessage: string);
begin
  WriteLn('hir-string-length-ownership-contract-failure=', AMessage);
  Halt(1);
end;

function BuildModel(const ASource, ARedPrefix: string): TSemanticModel;
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
    if Diagnostics.HasErrors then
      Fail(ARedPrefix + ':' + Diagnostics.LastDiagnosticCode);
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

function FindNodeIndexByKindAndDisplayNamePrefix(const AModel: TSemanticModel;
  const AKind, ADisplayNamePrefix: string): LongInt;
var
  I: LongInt;
  Node: TTypedHirNode;
begin
  Result := -1;
  for I := 0 to AModel.TypedHirNodeCount - 1 do
  begin
    Node := AModel.TypedHirNodeAt(I);
    if (Node.Kind = AKind) and
      SameText(Copy(Node.DisplayName, 1, Length(ADisplayNamePrefix)),
        ADisplayNamePrefix) then
      Exit(I);
  end;
end;

function FindNodeByKindAndDisplayName(const AModel: TSemanticModel;
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

procedure AssertDirectLengthTempOwnershipNodes;
var
  Model: TSemanticModel;
  Node: TTypedHirNode;
  OwnedIndex, LengthIndex, ReleaseIndex: LongInt;
begin
  Model := BuildModel(DirectLengthOwnedTempSource,
    'missing-owned-string-length-hir');
  try
    if not FindNodeByKindAndDisplayName(Model,
      'string-temp-owned-runtime', 'MakeText', Node) then
      Fail('missing-length-string-temp-owned-runtime');
    if Pos('ptr', Node.Operand) = 0 then
      Fail('length-owned-temp-missing-ptr');
    if Pos('len', Node.Operand) = 0 then
      Fail('length-owned-temp-missing-len');
    if Pos('owner', Node.Operand) = 0 then
      Fail('length-owned-temp-missing-owner');
    if Pos('alloc_size', Node.Operand) = 0 then
      Fail('length-owned-temp-missing-alloc-size');
    if not FindNodeByKindAndDisplayName(Model,
      'string-temp-length-runtime', 'MakeText', Node) then
      Fail('missing-string-temp-length-runtime');
    if Pos('owner', Node.Operand) <> 0 then
      Fail('length-consumer-must-not-receive-owner');
    if Pos('alloc_size', Node.Operand) <> 0 then
      Fail('length-consumer-must-not-receive-alloc-size');
    if not FindNodeByKindAndDisplayName(Model,
      'string-temp-release-runtime', 'MakeText', Node) then
      Fail('missing-length-string-temp-release-runtime');

    OwnedIndex := FindNodeIndexByKindAndDisplayName(Model,
      'string-temp-owned-runtime', 'MakeText');
    LengthIndex := FindNodeIndexByKindAndDisplayName(Model,
      'string-temp-length-runtime', 'MakeText');
    ReleaseIndex := FindNodeIndexByKindAndDisplayName(Model,
      'string-temp-release-runtime', 'MakeText');
    if (OwnedIndex < 0) or (LengthIndex < 0) or (ReleaseIndex < 0) then
      Fail('missing-length-temp-order-node');
    if OwnedIndex >= LengthIndex then
      Fail('length-temp-owned-must-precede-length');
    if LengthIndex >= ReleaseIndex then
      Fail('length-temp-release-must-follow-length');
  finally
    Model.Free;
  end;
end;

procedure AssertRepeatedLengthOrder;
var
  Model: TSemanticModel;
  OwnedA, LenA, ReleaseA, OwnedB, LenB, ReleaseB: LongInt;
begin
  Model := BuildModel(RepeatedLengthOwnedTempSource,
    'missing-repeated-owned-string-length-hir');
  try
    OwnedA := FindNodeIndexByKindAndDisplayName(Model,
      'string-temp-owned-runtime', 'MakeA');
    LenA := FindNodeIndexByKindAndDisplayName(Model,
      'string-temp-length-runtime', 'MakeA');
    ReleaseA := FindNodeIndexByKindAndDisplayName(Model,
      'string-temp-release-runtime', 'MakeA');
    OwnedB := FindNodeIndexByKindAndDisplayName(Model,
      'string-temp-owned-runtime', 'MakeB');
    LenB := FindNodeIndexByKindAndDisplayName(Model,
      'string-temp-length-runtime', 'MakeB');
    ReleaseB := FindNodeIndexByKindAndDisplayName(Model,
      'string-temp-release-runtime', 'MakeB');
    if (OwnedA < 0) or (LenA < 0) or (ReleaseA < 0) or
      (OwnedB < 0) or (LenB < 0) or (ReleaseB < 0) then
      Fail('missing-repeated-length-temp-node');
    if not ((OwnedA < LenA) and (LenA < ReleaseA) and
      (ReleaseA < OwnedB) and (OwnedB < LenB) and (LenB < ReleaseB)) then
      Fail('repeated-length-temp-release-order');
  finally
    Model.Free;
  end;
end;

procedure AssertConcatLengthTempOwnershipNodes;
var
  Model: TSemanticModel;
  OwnedIndex, ConcatIndex, LengthIndex, ConcatReleaseIndex,
    SourceReleaseIndex: LongInt;
begin
  Model := BuildModel(ConcatLengthOwnedTempSource,
    'missing-owned-string-concat-length-hir');
  try
    OwnedIndex := FindNodeIndexByKindAndDisplayName(Model,
      'string-temp-owned-runtime', 'MakeText');
    ConcatIndex := FindNodeIndexByKindAndDisplayNamePrefix(Model,
      'assign-str-owned-concat-runtime', '$str_len_cat_tmp_');
    LengthIndex := FindNodeIndexByKindAndDisplayNamePrefix(Model,
      'string-temp-length-runtime', '$str_len_cat_tmp_');
    ConcatReleaseIndex := FindNodeIndexByKindAndDisplayNamePrefix(Model,
      'string-temp-release-runtime', '$str_len_cat_tmp_');
    SourceReleaseIndex := FindNodeIndexByKindAndDisplayName(Model,
      'string-temp-release-runtime', 'MakeText');
    if (OwnedIndex < 0) or (ConcatIndex < 0) or (LengthIndex < 0) or
      (ConcatReleaseIndex < 0) or (SourceReleaseIndex < 0) then
      Fail('missing-concat-length-temp-order-node');
    if not ((OwnedIndex < ConcatIndex) and (ConcatIndex < LengthIndex) and
      (LengthIndex < ConcatReleaseIndex) and
      (ConcatReleaseIndex < SourceReleaseIndex)) then
      Fail('concat-length-temp-release-order');
  finally
    Model.Free;
  end;
end;

procedure AssertCopyOwnedTempOwnershipNodes;
var
  Model: TSemanticModel;
  Node: TTypedHirNode;
  OwnedIndex, CopyIndex, ReleaseIndex: LongInt;
begin
  Model := BuildModel(CopyOwnedTempSource,
    'missing-owned-string-copy-hir');
  try
    if not FindNodeByKindAndDisplayName(Model,
      'string-temp-owned-runtime', 'MakeText', Node) then
      Fail('missing-copy-string-temp-owned-runtime');
    if Pos('ptr', Node.Operand) = 0 then
      Fail('copy-owned-temp-missing-ptr');
    if Pos('len', Node.Operand) = 0 then
      Fail('copy-owned-temp-missing-len');
    if Pos('owner', Node.Operand) = 0 then
      Fail('copy-owned-temp-missing-owner');
    if Pos('alloc_size', Node.Operand) = 0 then
      Fail('copy-owned-temp-missing-alloc-size');
    if not FindNodeByKindAndDisplayName(Model,
      'copy-str-owned-runtime', 'S', Node) then
      Fail('missing-copy-str-owned-runtime');
    if Pos('owner', Node.Operand) <> 0 then
      Fail('copy-consumer-must-not-receive-owner');
    if Pos('alloc_size', Node.Operand) <> 0 then
      Fail('copy-consumer-must-not-receive-alloc-size');
    if not FindNodeByKindAndDisplayName(Model,
      'string-temp-release-runtime', 'MakeText', Node) then
      Fail('missing-copy-string-temp-release-runtime');

    OwnedIndex := FindNodeIndexByKindAndDisplayName(Model,
      'string-temp-owned-runtime', 'MakeText');
    CopyIndex := FindNodeIndexByKindAndDisplayName(Model,
      'copy-str-owned-runtime', 'S');
    ReleaseIndex := FindNodeIndexByKindAndDisplayName(Model,
      'string-temp-release-runtime', 'MakeText');
    if (OwnedIndex < 0) or (CopyIndex < 0) or (ReleaseIndex < 0) then
      Fail('missing-copy-temp-order-node');
    if OwnedIndex >= CopyIndex then
      Fail('copy-temp-owned-must-precede-copy');
    if CopyIndex >= ReleaseIndex then
      Fail('copy-temp-release-must-follow-copy');
  finally
    Model.Free;
  end;
end;

begin
  AssertDirectLengthTempOwnershipNodes;
  AssertRepeatedLengthOrder;
  AssertConcatLengthTempOwnershipNodes;
  AssertCopyOwnedTempOwnershipNodes;
  WriteLn('hir-string-length-ownership-contract-status=pass');
end.
