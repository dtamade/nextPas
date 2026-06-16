program test_hir_field_dynarray_contract;

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
  LayoutSource =
    'program test;' + LineEnding +
    'type TBase = class' + LineEnding +
    '  Head: Integer;' + LineEnding +
    '  Items: array of Integer;' + LineEnding +
    '  Tail: Integer;' + LineEnding +
    'end;' + LineEnding +
    'type TDerived = class(TBase)' + LineEnding +
    '  More: array of Integer;' + LineEnding +
    '  After: Integer;' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    'end.';

  FieldResizeSource =
    'program test;' + LineEnding +
    'type TWorker = class' + LineEnding +
    '  FieldArr: array of Integer;' + LineEnding +
    '  More: array of Integer;' + LineEnding +
    '  function Score: Integer;' + LineEnding +
    'end;' + LineEnding +
    'function TWorker.Score: Integer;' + LineEnding +
    'begin' + LineEnding +
    '  SetLength(FieldArr, 4);' + LineEnding +
    '  SetLength(Self.More, 2);' + LineEnding +
    '  Result := Length(FieldArr) + Length(Self.More);' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    'end.';

  FieldElemSource =
    'program test;' + LineEnding +
    'type TReader = class' + LineEnding +
    '  FieldArr: array of Integer;' + LineEnding +
    '  function First: Integer;' + LineEnding +
    'end;' + LineEnding +
    'function TReader.First: Integer;' + LineEnding +
    'begin' + LineEnding +
    '  Result := FieldArr[0];' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    'end.';

  FreeSource =
    'program test;' + LineEnding +
    'type TBase = class' + LineEnding +
    '  Head: Integer;' + LineEnding +
    '  Items: array of Integer;' + LineEnding +
    'end;' + LineEnding +
    'type TDerived = class(TBase)' + LineEnding +
    '  More: array of Integer;' + LineEnding +
    'end;' + LineEnding +
    'procedure FreeDerived(D: TDerived);' + LineEnding +
    'begin' + LineEnding +
    '  D.Free;' + LineEnding +
    'end;' + LineEnding +
    'procedure FreeBase(B: TBase);' + LineEnding +
    'begin' + LineEnding +
    '  B.Free;' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
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

  InterfaceDynArrayFieldSource =
    'program test;' + LineEnding +
    'type IStack = interface' + LineEnding +
    '  procedure Push(V: Integer);' + LineEnding +
    'end;' + LineEnding +
    'type TStack = class(TInterfacedObject, IStack)' + LineEnding +
    '  FItems: array of Integer;' + LineEnding +
    '  FTop: Integer;' + LineEnding +
    '  procedure Push(V: Integer);' + LineEnding +
    'end;' + LineEnding +
    'procedure TStack.Push(V: Integer);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'var S: IStack;' + LineEnding +
    'begin' + LineEnding +
    '  S := TStack.Create;' + LineEnding +
    'end.';

procedure Fail(const AMessage: string);
begin
  WriteLn('hir-field-dynarray-contract-failure=', AMessage);
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

procedure RequireSequence(const AText: string; const ANeedles: array of string;
  const ALabel: string);
var
  I: LongInt;
  PosAt: LongInt;
begin
  PosAt := 1;
  for I := Low(ANeedles) to High(ANeedles) do
  begin
    PosAt := FindAfter(ANeedles[I], AText, PosAt);
    if PosAt = 0 then
      Fail(ALabel + ':' + ANeedles[I]);
    Inc(PosAt, Length(ANeedles[I]));
  end;
end;

procedure RequireConst(const AModel: TSemanticModel; const AName: string;
  AExpected: Int64);
var
  Actual: Int64;
begin
  if not AModel.LookupConstValue(AName, Actual) then
    Fail('missing-const:' + AName);
  if Actual <> AExpected then
    Fail('const-mismatch:' + AName + ':' + IntToStr(Actual) +
      ':expected:' + IntToStr(AExpected));
end;

procedure AssertLayoutContract;
var
  Model: TSemanticModel;
begin
  Model := BuildModel(LayoutSource);
  try
    if Model = nil then
      Fail('layout-model-nil');
    RequireConst(Model, 'TBase.Items$arr', 1);
    RequireConst(Model, 'TBase.Items$idx', 2);
    RequireConst(Model, 'TBase.Tail$idx', 4);
    RequireConst(Model, 'TDerived.Items$arr', 1);
    RequireConst(Model, 'TDerived.Items$idx', 2);
    RequireConst(Model, 'TDerived.More$arr', 1);
    RequireConst(Model, 'TDerived.More$idx', 5);
    RequireConst(Model, 'TDerived.After$idx', 7);
  finally
    Model.Free;
  end;
end;

procedure AssertFieldResizeContract;
var
  Model: TSemanticModel;
  Node: TTypedHirNode;
  LlvmText: string;
  ScoreLlvm: string;
begin
  Model := BuildModel(FieldResizeSource);
  try
    if Model = nil then
      Fail('field-resize-model-nil');
    if not FindFirstNodeByKindAndDisplayName(Model,
      'setlength-field-arr-runtime', 'FieldArr', Node) then
      Fail('missing-implicit-self-field-resize-node');
    if not FindFirstNodeByKindAndDisplayName(Model,
      'setlength-field-arr-runtime', 'Self.More', Node) then
      Fail('missing-explicit-self-field-resize-node');
    if FindFirstNodeByKindAndDisplayName(Model,
      'assign-arr-elem-runtime', '__field_setlength__', Node) then
      Fail('legacy-field-setlength-path-must-disappear');

    LlvmText := EmitLlvm(Model);
    ScoreLlvm := ExtractDefinitionSlice(LlvmText, '@TWorker.Score(');
    if ScoreLlvm = '' then
      Fail('missing-score-function');
    RequireSequence(ScoreLlvm, [
      'add i64 1, 0',
      'getelementptr i64, ptr ',
      'add i64 2, 0',
      'getelementptr i64, ptr ',
      'load ptr, ptr ',
      'load i64, ptr ',
      'call ptr @np_dynarray_resize(',
      'store ptr ',
      'store i64 '
    ], 'missing-fieldarr-ptr-len-resize-sequence');
    RequireSequence(ScoreLlvm, [
      'add i64 3, 0',
      'getelementptr i64, ptr ',
      'add i64 4, 0',
      'getelementptr i64, ptr ',
      'load ptr, ptr ',
      'load i64, ptr ',
      'call ptr @np_dynarray_resize(',
      'store ptr ',
      'store i64 '
    ], 'missing-more-ptr-len-resize-sequence');
  finally
    Model.Free;
  end;
end;

procedure AssertFieldArrayPtrSlotContract;
var
  Model: TSemanticModel;
  LlvmText: string;
  FirstLlvm: string;
begin
  Model := BuildModel(FieldElemSource);
  try
    if Model = nil then
      Fail('field-elem-model-nil');
    LlvmText := EmitLlvm(Model);
    FirstLlvm := ExtractDefinitionSlice(LlvmText, '@TReader.First(');
    if FirstLlvm = '' then
      Fail('missing-reader-first-function');
    RequireSequence(FirstLlvm, [
      'add i64 1, 0',
      'getelementptr i64, ptr ',
      'load ptr, ptr ',
      'getelementptr i64, ptr '
    ], 'missing-field-array-ptr-slot-load-sequence');
  finally
    Model.Free;
  end;
end;

procedure AssertObjectFreeCompileTimeClassContract;
var
  Model: TSemanticModel;
  FreeLlvm, DerivedFreeLlvm, BaseFreeLlvm: string;
begin
  Model := BuildModel(FreeSource);
  try
    if Model = nil then
      Fail('free-model-nil');
    FreeLlvm := EmitLlvm(Model);
    DerivedFreeLlvm := ExtractDefinitionSlice(FreeLlvm, '@FreeDerived(');
    BaseFreeLlvm := ExtractDefinitionSlice(FreeLlvm, '@FreeBase(');
    if DerivedFreeLlvm = '' then
      Fail('missing-derived-free-function');
    if BaseFreeLlvm = '' then
      Fail('missing-base-free-function');
    if Pos('call void @np_object_dynarray_cleanup_TDerived(ptr ',
      DerivedFreeLlvm) = 0 then
      Fail('missing-derived-cleanup-helper-call');
    if Pos('call void @np_object_dynarray_cleanup_TBase(ptr ',
      BaseFreeLlvm) = 0 then
      Fail('missing-base-cleanup-helper-call');
    if Pos('@np_object_dynarray_cleanup_TDerived', BaseFreeLlvm) <> 0 then
      Fail('base-free-must-stay-compile-time-class-only');
  finally
    Model.Free;
  end;
end;

procedure AssertStringFieldPathUntouched;
var
  Model: TSemanticModel;
  Node: TTypedHirNode;
  LlvmText: string;
begin
  Model := BuildModel(StringFieldSource);
  try
    if Model = nil then
      Fail('string-field-model-nil');
    if not FindFirstNodeByKind(Model, 'assign-str-field-load-runtime', Node) then
      Fail('missing-string-field-load-node');
    if not FindFirstNodeByKind(Model, 'field-store-str-runtime', Node) then
      Fail('missing-string-field-store-node');
    LlvmText := EmitLlvm(Model);
    if Pos('call {ptr, i64} @np_str_concat(', LlvmText) = 0 then
      Fail('missing-string-field-concat-helper-call');
  finally
    Model.Free;
  end;
end;

procedure AssertInterfaceSlotAfterWideFieldsContract;
var
  Model: TSemanticModel;
  LlvmText: string;
begin
  Model := BuildModel(InterfaceDynArrayFieldSource);
  try
    if Model = nil then
      Fail('interface-dynarray-field-model-nil');
    RequireConst(Model, 'TStack.FItems$arr', 1);
    RequireConst(Model, 'TStack.FItems$idx', 1);
    RequireConst(Model, 'TStack.FTop$idx', 3);
    RequireConst(Model, 'TStack$intf_offset_IStack', 32);
    RequireConst(Model, 'TStack$size', 40);

    LlvmText := EmitLlvm(Model);
    if Pos('@TStack.imt.IStack', LlvmText) = 0 then
      Fail('missing-stack-imt-global');
    RequireSequence(LlvmText, [
      'add i64 4, 0',
      'getelementptr i64, ptr ',
      'store ptr @TStack.imt.IStack'
    ], 'missing-interface-slot-after-wide-field-sequence');
  finally
    Model.Free;
  end;
end;

begin
  AssertLayoutContract;
  AssertFieldResizeContract;
  AssertFieldArrayPtrSlotContract;
  AssertObjectFreeCompileTimeClassContract;
  AssertStringFieldPathUntouched;
  AssertInterfaceSlotAfterWideFieldsContract;
  WriteLn('hir-field-dynarray-contract-status=pass');
end.
