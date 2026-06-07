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

function FindAfter(const ANeedle, AText: string; AStart: LongInt): LongInt;
var
  Offset: LongInt;
begin
  if AStart < 1 then
    AStart := 1;
  Offset := Pos(ANeedle, Copy(AText, AStart, MaxInt));
  if Offset = 0 then
    Exit(0);
  Result := AStart + Offset - 1;
end;

function ExtractDefinitionSlice(const AText, AHeaderNeedle: string): string;
var
  StartPos, EndPos: LongInt;
begin
  Result := '';
  StartPos := Pos(AHeaderNeedle, AText);
  if StartPos = 0 then
    Exit;
  EndPos := FindAfter(LineEnding + '}', AText, StartPos);
  if EndPos = 0 then
    Exit;
  Result := Copy(AText, StartPos, EndPos - StartPos + Length(LineEnding + '}'));
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
    if not FindFirstNodeByKindAndDisplayName(Model,
      'var-decl-str-borrowed-runtime', 'P', Node) then
      Fail('missing-borrowed-param-node');
    if not FindFirstNodeByKindAndDisplayName(Model,
      'var-decl-str-owned-runtime', 'S', Node) then
      Fail('missing-owned-local-node');
    if FindFirstNodeByKindAndDisplayName(Model, 'string-cleanup-runtime',
      'P', Node) then
      Fail('borrowed-param-must-not-cleanup');
    if not FindFirstNodeByKindAndDisplayName(Model, 'string-cleanup-runtime',
      'S', Node) then
      Fail('missing-owned-string-cleanup');
    if not FindFirstNodeByKindAndDisplayName(Model,
      'assign-str-owned-concat-runtime', 'S', Node) then
      Fail('missing-owned-concat-node');

    LlvmText := EmitLlvm(Model);
    if Pos('S$owner', LlvmText) = 0 then
      Fail('missing-owned-sidecar-owner');
    if Pos('S$alloc_size', LlvmText) = 0 then
      Fail('missing-owned-sidecar-alloc-size');
    if Pos('call void @np_string_release(', LlvmText) = 0 then
      Fail('missing-string-release-call');
    if Pos('call {ptr, i64, ptr, i64} @np_str_concat_owned(', LlvmText) = 0 then
      Fail('missing-owned-concat-helper-call');
    if Pos('define internal void @np_string_release(', LlvmText) = 0 then
      Fail('missing-string-release-helper');
    if Pos('define internal void @np_string_fault(', LlvmText) = 0 then
      Fail('missing-string-fault-helper');
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
    if not FindFirstNodeByKind(Model, 'assign-str-copy-runtime', Node) then
      Fail('missing-shallow-copy-node');
    if not FindFirstNodeByKind(Model, 'copy-str-runtime', Node) then
      Fail('missing-copy-alias-node');
    LlvmText := EmitLlvm(Model);
    if Pos('A$owner', LlvmText) = 0 then
      Fail('missing-global-owner-sidecar');
    if Pos('store ptr null, ptr ', LlvmText) = 0 then
      Fail('missing-alias-owner-clear');
    if Pos('call void @np_free(ptr %concat.', LlvmText) <> 0 then
      Fail('string-path-must-not-free-visible-concat-ptr');
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
      'int-to-str-owned-runtime', 'S', Node) then
      Fail('missing-owned-int-to-str-node');
    LlvmText := EmitLlvm(Model);
    if Pos('call {ptr, i64, ptr, i64} @np_int_to_str_owned(', LlvmText) = 0 then
      Fail('missing-owned-int-to-str-helper-call');
    if Pos('call void @np_free(ptr %digits.', LlvmText) <> 0 then
      Fail('int-to-str-must-not-free-visible-interior-pointer');
  finally
    Model.Free;
  end;
end;

procedure AssertReturnOwnershipDeferred;
var
  Model: TSemanticModel;
  Node: TTypedHirNode;
  LlvmText: string;
begin
  Model := BuildModel(ReturnSource);
  try
    if Model = nil then
      Fail('return-model-nil');
    if not FindFirstNodeByKind(Model, 'ret-str-runtime', Node) then
      Fail('missing-string-return-node');
    if not FindFirstNodeByKindAndDisplayName(Model,
      'assign-str-call-runtime', 'S', Node) then
      Fail('missing-return-call-assignment-node');
    if FindFirstNodeByKindAndDisplayName(Model,
      'assign-str-owned-concat-runtime', 'S', Node) then
      Fail('return-assignment-must-not-be-owned-concat');
    LlvmText := EmitLlvm(Model);
    if Pos('@np_str_return_owned', LlvmText) <> 0 then
      Fail('return-ownership-must-remain-deferred');
  finally
    Model.Free;
  end;
end;

procedure AssertFieldAndObjectFreeBoundaries;
var
  FieldModel: TSemanticModel;
  FreeModel: TSemanticModel;
  Node: TTypedHirNode;
  LlvmText, ReleaseSlice: string;
begin
  FieldModel := BuildModel(StringFieldSource);
  try
    if FieldModel = nil then
      Fail('string-field-model-nil');
    if not FindFirstNodeByKind(FieldModel, 'assign-str-field-load-runtime',
      Node) then
      Fail('missing-string-field-load-node');
    if not FindFirstNodeByKind(FieldModel, 'field-store-str-runtime', Node) then
      Fail('missing-string-field-store-node');
    LlvmText := EmitLlvm(FieldModel);
    if Pos('call {ptr, i64} @np_str_concat(', LlvmText) = 0 then
      Fail('string-field-concat-must-stay-visible-abi');
    if Pos('@np_object_string_cleanup_', LlvmText) <> 0 then
      Fail('string-field-cleanup-must-remain-deferred');
  finally
    FieldModel.Free;
  end;

  FreeModel := BuildModel(ObjectFreeSource);
  try
    if FreeModel = nil then
      Fail('object-free-model-nil');
    LlvmText := EmitLlvm(FreeModel);
    ReleaseSlice := ExtractDefinitionSlice(LlvmText,
      'define internal void @np_object_free_release(ptr %obj)');
    if ReleaseSlice = '' then
      Fail('missing-object-free-release-helper');
    if Pos('np_object_string_cleanup', ReleaseSlice) <> 0 then
      Fail('object-free-release-must-stay-field-agnostic');
  finally
    FreeModel.Free;
  end;
end;

begin
  AssertOwnedBorrowedContract;
  AssertAliasNoOwnerContract;
  AssertIntToStrOwnershipContract;
  AssertReturnOwnershipDeferred;
  AssertFieldAndObjectFreeBoundaries;
  WriteLn('hir-string-ownership-contract-status=pass');
end.
