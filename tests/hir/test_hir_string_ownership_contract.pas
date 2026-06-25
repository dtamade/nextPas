program test_hir_string_ownership_contract;

{$mode objfpc}{$H+}

uses
  SysUtils,
  np_ast_facade,
  np_diagnostics_sink,
  np_green_tree,
  np_hir_builder,
  np_hir_llvm_emitter,
  np_lexer,
  np_semantic_analyzer,
  np_semantic_model,
  np_unit_graph;

const
  OwnedBorrowedSource =
    'program test;' + LineEnding +
    'procedure Touch(P: string);' + LineEnding +
    'var S: string;' + LineEnding +
    'begin' + LineEnding +
    '  S := ''left'' + P;' + LineEnding +
    '  if Length(P) = 0 then Exit;' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    'end.';

  AliasSource =
    'program test;' + LineEnding +
    'var A, B, C: string;' + LineEnding +
    'begin' + LineEnding +
    '  A := ''abcdef'';' + LineEnding +
    '  B := A;' + LineEnding +
    '  C := Copy(A, 2, 3);' + LineEnding +
    'end.';

  IntToStrSource =
    'program test;' + LineEnding +
    'var S: string;' + LineEnding +
    'begin' + LineEnding +
    '  S := IntToStr(42);' + LineEnding +
    'end.';

  ReturnSource =
    'program test;' + LineEnding +
    'function MakeText: string;' + LineEnding +
    'begin' + LineEnding +
    '  MakeText := ''owned elsewhere'';' + LineEnding +
    'end;' + LineEnding +
    'var S: string;' + LineEnding +
    'begin' + LineEnding +
    '  S := MakeText;' + LineEnding +
    'end.';

  StringFieldSource =
    'program test;' + LineEnding +
    'type TStringBox = class' + LineEnding +
    '  Text: string;' + LineEnding +
    '  Other: string;' + LineEnding +
    '  procedure Touch;' + LineEnding +
    'end;' + LineEnding +
    'procedure TStringBox.Touch;' + LineEnding +
    'begin' + LineEnding +
    '  Other := Text;' + LineEnding +
    '  Text := Text + Other;' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    'end.';

  ObjectFreeSource =
    'program test;' + LineEnding +
    'type TStringBox = class' + LineEnding +
    '  Text: string;' + LineEnding +
    'end;' + LineEnding +
    'procedure Kill(Box: TStringBox);' + LineEnding +
    'begin' + LineEnding +
    '  Box.Free;' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    'end.';

procedure Fail(const AMessage: string);
begin
  WriteLn('hir-string-ownership-contract-failure=', AMessage);
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

function EmitLlvm(const AModel: TSemanticModel): string;
var
  Builder: THIRBuilder;
  Emitter: THIRLlvmEmitter;
begin
  Builder := nil;
  Emitter := nil;
  try
    Builder := THIRBuilder.Create(AModel);
    Builder.Build;
    Emitter := THIRLlvmEmitter.Create(Builder.Module);
    Emitter.EmitModule;
    Result := Emitter.AsText;
  finally
    Emitter.Free;
    Builder.Free;
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

procedure AssertOwnedBorrowedContract;
var
  Model: TSemanticModel;
  Node: TTypedHirNode;
  LlvmText: string;
begin
  Model := BuildModel(OwnedBorrowedSource);
  try
    if Model = nil then
      Fail('owned-borrowed-model-nil');
    { TString 24B: 参数和局部变量都是 var-decl-tstring-runtime }
    if not FindFirstNodeByKindAndDisplayName(Model,
      'var-decl-tstring-runtime', 'P', Node) then
      Fail('missing-borrowed-param-node');
    if not FindFirstNodeByKindAndDisplayName(Model,
      'var-decl-tstring-runtime', 'S', Node) then
      Fail('missing-owned-local-node');
    if FindFirstNodeByKindAndDisplayName(Model, 'tstring-cleanup-runtime',
      'P', Node) then
      Fail('borrowed-param-must-not-cleanup');
    if not FindFirstNodeByKindAndDisplayName(Model, 'tstring-cleanup-runtime',
      'S', Node) then
      Fail('missing-owned-string-cleanup');
    if not FindFirstNodeByKindAndDisplayName(Model,
      'assign-tstring-concat-runtime', 'S', Node) then
      Fail('missing-owned-concat-node');

    LlvmText := EmitLlvm(Model);
    if Pos('call void @np_tstring_fini(ptr ', LlvmText) = 0 then
      Fail('missing-tstring-fini-call');
    if Pos('call void @np_tstring_concat(ptr ', LlvmText) = 0 then
      Fail('missing-tstring-concat-call');
  finally
    Model.Free;
  end;
end;

procedure AssertAliasNoOwnerContract;
var
  Model: TSemanticModel;
  Node: TTypedHirNode;
  LlvmText: string;
begin
  Model := BuildModel(AliasSource);
  try
    if Model = nil then
      Fail('alias-model-nil');
    if not FindFirstNodeByKind(Model, 'assign-tstring-literal-runtime', Node) and
      not FindFirstNodeByKind(Model, 'assign-tstring-copy-runtime', Node) then
      Fail('missing-shallow-copy-node');
    if not FindFirstNodeByKind(Model, 'tstring-copy-runtime', Node) then
      Fail('missing-copy-alias-node');
    LlvmText := EmitLlvm(Model);
    if Pos('call void @np_tstring_fini(ptr ', LlvmText) = 0 then
      Fail('missing-tstring-fini-call');
    if Pos('call void @np_tstring_assign(ptr ', LlvmText) = 0 then
      Fail('missing-tstring-assign-call');
  finally
    Model.Free;
  end;
end;

procedure AssertIntToStrOwnershipContract;
var
  Model: TSemanticModel;
  Node: TTypedHirNode;
  LlvmText: string;
begin
  Model := BuildModel(IntToStrSource);
  try
    if Model = nil then
      Fail('int-to-str-model-nil');
    if not FindFirstNodeByKindAndDisplayName(Model,
      'tstring-from-int-runtime', 'S', Node) then
      Fail('missing-owned-int-to-str-node');
    LlvmText := EmitLlvm(Model);
    if Pos('call void @np_tstring_from_int(ptr ', LlvmText) = 0 then
      Fail('missing-tstring-from-int-helper-call');
  finally
    Model.Free;
  end;
end;

procedure AssertReturnOwnershipCoveredByC6H4;
var
  Model: TSemanticModel;
  Node: TTypedHirNode;
begin
  Model := BuildModel(ReturnSource);
  try
    if Model = nil then
      Fail('return-model-nil');
    if (not FindFirstNodeByKind(Model, 'ret-tstring-runtime', Node)) and
      (not FindFirstNodeByKind(Model, 'ret-tstring-runtime', Node)) then
      Fail('missing-string-return-node');
    if (not FindFirstNodeByKindAndDisplayName(Model,
      'assign-tstring-call-runtime', 'S', Node)) and
      (not FindFirstNodeByKindAndDisplayName(Model,
      'assign-tstring-copy-runtime', 'S', Node)) then
      Fail('missing-return-call-assignment-node');
    if FindFirstNodeByKindAndDisplayName(Model,
      'assign-tstring-concat-runtime', 'S', Node) then
      Fail('return-assignment-must-not-be-owned-concat');
  finally
    Model.Free;
  end;
end;

procedure AssertFieldAndObjectFreeBoundaries;
var
  FieldModel: TSemanticModel;
  FreeModel: TSemanticModel;
  Node: TTypedHirNode;
  LlvmText: string;
begin
  FieldModel := BuildModel(StringFieldSource);
  try
    if FieldModel = nil then
      Fail('string-field-model-nil');
    if not FindFirstNodeByKind(FieldModel, 'field-store-tstring-runtime', Node) then
      Fail('missing-field-store-tstring-node');
    if not FindFirstNodeByKind(FieldModel, 'assign-tstring-field-load-runtime', Node) then
      Fail('missing-field-load-tstring-node');
    if not FindFirstNodeByKind(FieldModel, 'assign-tstring-concat-runtime', Node) then
      Fail('missing-string-field-concat-node');
  finally
    FieldModel.Free;
  end;

  FreeModel := BuildModel(ObjectFreeSource);
  try
    if FreeModel = nil then
      Fail('object-free-model-nil');
    LlvmText := EmitLlvm(FreeModel);
    { Phase 3: np_object_free_release 已移至 libnprt.a runtime 模块 }
    if Pos('declare void @np_object_free_release(ptr %obj)', LlvmText) = 0 then
      Fail('missing-object-free-release-helper-decl');
    if Pos('define internal void @np_object_string_cleanup_TStringBox(ptr %', LlvmText) = 0 then
      Fail('missing-object-string-cleanup-helper');
    if Pos('call void @np_object_string_cleanup_TStringBox(ptr %', LlvmText) = 0 then
      Fail('missing-object-free-string-cleanup-call');
  finally
    FreeModel.Free;
  end;
end;

begin
  AssertOwnedBorrowedContract;
  AssertAliasNoOwnerContract;
  AssertIntToStrOwnershipContract;
  AssertReturnOwnershipCoveredByC6H4;
  AssertFieldAndObjectFreeBoundaries;
  WriteLn('hir-string-ownership-contract-status=pass');
end.
