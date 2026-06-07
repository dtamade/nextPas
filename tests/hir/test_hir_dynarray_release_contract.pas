program test_hir_dynarray_release_contract;

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
    'procedure Touch(A: array of Integer);' + LineEnding +
    'var Local: array of Integer;' + LineEnding +
    'begin' + LineEnding +
    '  SetLength(Local, 4);' + LineEnding +
    '  if A[0] = 1 then Exit;' + LineEnding +
    '  Halt(0);' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    'end.';

  BorrowedResizeSource =
    'program test;' + LineEnding +
    'procedure ResizeBorrowed(A: array of Integer);' + LineEnding +
    'begin' + LineEnding +
    '  SetLength(A, 4);' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    'end.';

  FieldSource =
    'program test;' + LineEnding +
    'type TWorker = class' + LineEnding +
    '  FieldArr: array of Integer;' + LineEnding +
    '  procedure Touch;' + LineEnding +
    'end;' + LineEnding +
    'procedure TWorker.Touch;' + LineEnding +
    'begin' + LineEnding +
    '  SetLength(FieldArr, 4);' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    'end.';

  StringSource =
    'program test;' + LineEnding +
    'var A, B, C: string;' + LineEnding +
    'begin' + LineEnding +
    '  B := A;' + LineEnding +
    '  C := A + B;' + LineEnding +
    'end.';

procedure Fail(const AMessage: string);
begin
  WriteLn('hir-dynarray-release-contract-failure=', AMessage);
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
    if not FindFirstNodeByKindAndDisplayName(Model, 'var-decl-arr-runtime',
      'Local', Node) then
      Fail('missing-owned-local-node');
    if not FindFirstNodeByKindAndDisplayName(Model,
      'var-decl-arr-borrowed-runtime', 'A', Node) then
      Fail('missing-borrowed-param-node');
    if FindFirstNodeByKindAndDisplayName(Model, 'dynarray-cleanup-runtime',
      'A', Node) then
      Fail('borrowed-param-must-not-cleanup');
    if not FindFirstNodeByKindAndDisplayName(Model, 'dynarray-cleanup-runtime',
      'Local', Node) then
      Fail('missing-owned-local-cleanup');

    LlvmText := EmitLlvm(Model);
    if Pos('define internal ptr @np_dynarray_resize(', LlvmText) = 0 then
      Fail('missing-dynarray-resize-helper');
    if Pos('define internal void @np_dynarray_release(', LlvmText) = 0 then
      Fail('missing-dynarray-release-helper');
    if Pos('define internal void @np_dynarray_fault(', LlvmText) = 0 then
      Fail('missing-dynarray-fault-helper');
    if Pos('call ptr @np_dynarray_resize(', LlvmText) = 0 then
      Fail('missing-owned-resize-call');
    if Pos('call void @np_dynarray_release(', LlvmText) = 0 then
      Fail('missing-owned-cleanup-release-call');
    if Pos('call ptr @np_alloc(i64 %arralloc.', LlvmText) <> 0 then
      Fail('owned-setlength-still-bare-arr-alloc');
  finally
    Model.Free;
  end;
end;

procedure AssertBorrowedResizeContract;
var
  Model: TSemanticModel;
  Node: TTypedHirNode;
  LlvmText: string;
begin
  Model := BuildModel(BorrowedResizeSource);
  try
    if Model = nil then
      Fail('borrowed-resize-model-nil');
    if FindFirstNodeByKindAndDisplayName(Model, 'setlength-arr-runtime', 'A',
      Node) then
      Fail('borrowed-param-must-not-use-owned-setlength-node');

    LlvmText := EmitLlvm(Model);
    if Pos('call ptr @np_alloc(i64 %arralloc.', LlvmText) <> 0 then
      Fail('borrowed-param-must-not-allocate-on-setlength');
    if Pos('call ptr @np_dynarray_resize(', LlvmText) <> 0 then
      Fail('borrowed-param-must-not-use-owned-resize-call');
  finally
    Model.Free;
  end;
end;

procedure AssertFieldPathPreserved;
var
  Model: TSemanticModel;
  Node: TTypedHirNode;
begin
  Model := BuildModel(FieldSource);
  try
    if Model = nil then
      Fail('field-model-nil');
    if not FindFirstNodeByKindAndDisplayName(Model, 'assign-arr-elem-runtime',
      '__field_setlength__', Node) then
      Fail('missing-field-setlength-path');
  finally
    Model.Free;
  end;
end;

procedure AssertStringPathUntouched;
var
  Model: TSemanticModel;
  Node: TTypedHirNode;
  LlvmText: string;
begin
  Model := BuildModel(StringSource);
  try
    if Model = nil then
      Fail('string-model-nil');
    if not FindFirstNodeByKind(Model, 'assign-str-copy-runtime', Node) then
      Fail('missing-string-copy-node');
    if not FindFirstNodeByKind(Model, 'assign-str-concat-runtime', Node) then
      Fail('missing-string-concat-node');
    LlvmText := EmitLlvm(Model);
    if Pos('call {ptr, i64} @np_str_concat(', LlvmText) = 0 then
      Fail('missing-string-concat-helper-call');
  finally
    Model.Free;
  end;
end;

begin
  AssertOwnedBorrowedContract;
  AssertBorrowedResizeContract;
  AssertFieldPathPreserved;
  AssertStringPathUntouched;
  WriteLn('hir-dynarray-release-contract-status=pass');
end.
