program test_hir_string_return_ownership_contract;

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
  DirectConcatReturnSource =
    'program test;' + LineEnding +
    'function MakeText: string;' + LineEnding +
    'var Suffix: string;' + LineEnding +
    'begin' + LineEnding +
    '  Suffix := ''tail'';' + LineEnding +
    '  MakeText := ''head'' + Suffix;' + LineEnding +
    'end;' + LineEnding +
    'var S: string;' + LineEnding +
    'begin' + LineEnding +
    '  S := MakeText;' + LineEnding +
    'end.';

  IntToStrReturnSource =
    'program test;' + LineEnding +
    'function MakeText: string;' + LineEnding +
    'begin' + LineEnding +
    '  MakeText := IntToStr(42);' + LineEnding +
    'end;' + LineEnding +
    'var S: string;' + LineEnding +
    'begin' + LineEnding +
    '  S := MakeText;' + LineEnding +
    'end.';

  LiteralAndCopyReturnSource =
    'program test;' + LineEnding +
    'function LiteralText: string;' + LineEnding +
    'begin' + LineEnding +
    '  LiteralText := ''static'';' + LineEnding +
    'end;' + LineEnding +
    'function SliceText(P: string): string;' + LineEnding +
    'begin' + LineEnding +
    '  SliceText := Copy(P, 2, 3);' + LineEnding +
    'end;' + LineEnding +
    'var S: string;' + LineEnding +
    'begin' + LineEnding +
    '  S := LiteralText;' + LineEnding +
    '  S := SliceText(S);' + LineEnding +
    'end.';

  LocalMoveReturnSource =
    'program test;' + LineEnding +
    'function MakeText: string;' + LineEnding +
    'var Tmp, Suffix: string;' + LineEnding +
    'begin' + LineEnding +
    '  Suffix := ''tail'';' + LineEnding +
    '  Tmp := ''head'' + Suffix;' + LineEnding +
    '  MakeText := Tmp;' + LineEnding +
    'end;' + LineEnding +
    'var S: string;' + LineEnding +
    'begin' + LineEnding +
    '  S := MakeText;' + LineEnding +
    'end.';

  ChainedReturnSource =
    'program test;' + LineEnding +
    'function InnerText: string;' + LineEnding +
    'begin' + LineEnding +
    '  InnerText := IntToStr(42);' + LineEnding +
    'end;' + LineEnding +
    'function OuterText: string;' + LineEnding +
    'begin' + LineEnding +
    '  OuterText := InnerText;' + LineEnding +
    'end;' + LineEnding +
    'var S: string;' + LineEnding +
    'begin' + LineEnding +
    '  S := OuterText;' + LineEnding +
    'end.';

  BorrowedParamBoundarySource =
    'program test;' + LineEnding +
    'function Echo(P: string): string;' + LineEnding +
    'begin' + LineEnding +
    '  Echo := P;' + LineEnding +
    'end;' + LineEnding +
    'var S: string;' + LineEnding +
    'begin' + LineEnding +
    '  S := Echo(S);' + LineEnding +
    'end.';

  FieldBoundarySource =
    'program test;' + LineEnding +
    'type TStringBox = class' + LineEnding +
    '  Text: string;' + LineEnding +
    'end;' + LineEnding +
    'procedure Store(Box: TStringBox);' + LineEnding +
    'begin' + LineEnding +
    '  Box.Text := Box.Text;' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    'end.';

  LegacyOnlyReturnConsumerSource =
    'program test;' + LineEnding +
    'function Greeting: string;' + LineEnding +
    'begin' + LineEnding +
    '  Greeting := ''Hello World'';' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    '  WriteLn(Greeting);' + LineEnding +
    '  Halt(Length(Greeting) + 31);' + LineEnding +
    'end.';

  MixedOwnedAndLegacyConsumerSource =
    'program test;' + LineEnding +
    'function Greeting: string;' + LineEnding +
    'begin' + LineEnding +
    '  Greeting := ''Hello World'';' + LineEnding +
    'end;' + LineEnding +
    'var S: string;' + LineEnding +
    'begin' + LineEnding +
    '  S := Greeting;' + LineEnding +
    '  WriteLn(Greeting);' + LineEnding +
    '  Halt(Length(Greeting) + 31);' + LineEnding +
    'end.';

  OverloadedStringReturnSource =
    'program test;' + LineEnding +
    'function MakeText: string;' + LineEnding +
    'begin' + LineEnding +
    '  MakeText := ''default'';' + LineEnding +
    'end;' + LineEnding +
    'function MakeText(Value: Integer): string;' + LineEnding +
    'begin' + LineEnding +
    '  MakeText := IntToStr(Value);' + LineEnding +
    'end;' + LineEnding +
    'var S: string;' + LineEnding +
    'begin' + LineEnding +
    '  S := MakeText(42);' + LineEnding +
    'end.';

  FieldOwnedReturnConsumerSource =
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

  LengthOwnedReturnConsumerSource =
    'program test;' + LineEnding +
    'function MakeText: string;' + LineEnding +
    'begin' + LineEnding +
    '  MakeText := ''length'';' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    '  Halt(Length(MakeText()));' + LineEnding +
    'end.';

  CopyOwnedReturnConsumerSource =
    'program test;' + LineEnding +
    'function MakeText: string;' + LineEnding +
    'begin' + LineEnding +
    '  MakeText := ''copy'';' + LineEnding +
    'end;' + LineEnding +
    'var S: string;' + LineEnding +
    'begin' + LineEnding +
    '  S := Copy(MakeText(), 1, 2);' + LineEnding +
    'end.';

  ArgumentOwnedReturnConsumerSource =
    'program test;' + LineEnding +
    'function MakeText: string;' + LineEnding +
    'begin' + LineEnding +
    '  MakeText := ''arg'';' + LineEnding +
    'end;' + LineEnding +
    'procedure Take(P: string);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    '  Take(MakeText());' + LineEnding +
    'end.';

  NestedArgumentOwnedReturnConsumerSource =
    'program test;' + LineEnding +
    'function MakeText: string;' + LineEnding +
    'begin' + LineEnding +
    '  MakeText := ''inner'';' + LineEnding +
    'end;' + LineEnding +
    'function Wrap(P: string): string;' + LineEnding +
    'begin' + LineEnding +
    '  Wrap := P;' + LineEnding +
    'end;' + LineEnding +
    'var S: string;' + LineEnding +
    'begin' + LineEnding +
    '  S := Wrap(MakeText());' + LineEnding +
    'end.';

procedure Fail(const AMessage: string);
begin
  WriteLn('hir-string-return-ownership-contract-failure=', AMessage);
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

function AnalyzeSourceHasError(const ASource, ACode: string): Boolean;
var
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  Tree: TGreenTree;
  Ast: TAstFacade;
  Graph: TUnitGraph;
  Analyzer: TSemanticAnalyzer;
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
    Result := Diagnostics.HasErrors and SameText(Diagnostics.LastDiagnosticCode, ACode);
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

procedure RequireContains(const AText, ANeedle, AMessage: string);
begin
  if Pos(ANeedle, AText) = 0 then
    Fail(AMessage);
end;

procedure RejectContains(const AText, ANeedle, AMessage: string);
begin
  if Pos(ANeedle, AText) <> 0 then
    Fail(AMessage);
end;

procedure RequireOrder(const AText, AFirstNeedle, ASecondNeedle,
  AMessage: string);
var
  FirstPos, SecondPos: LongInt;
begin
  FirstPos := Pos(AFirstNeedle, AText);
  SecondPos := Pos(ASecondNeedle, AText);
  if (FirstPos = 0) or (SecondPos = 0) or (FirstPos >= SecondPos) then
    Fail(AMessage);
end;

function FindLineContaining(const AText, ANeedle: string): string;
var
  NeedlePos, LineStart, LineEnd: LongInt;
begin
  Result := '';
  NeedlePos := Pos(ANeedle, AText);
  if NeedlePos = 0 then
    Exit;
  LineStart := NeedlePos;
  while (LineStart > 1) and (AText[LineStart - 1] <> #10) do
    Dec(LineStart);
  LineEnd := NeedlePos;
  while (LineEnd <= Length(AText)) and (AText[LineEnd] <> #10) do
    Inc(LineEnd);
  Result := Copy(AText, LineStart, LineEnd - LineStart);
end;

function ExtractCallArguments(const ALine, ACallNeedle: string): string;
var
  StartPos, EndPos: LongInt;
begin
  Result := '';
  StartPos := Pos(ACallNeedle, ALine);
  if StartPos = 0 then
    Exit;
  Inc(StartPos, Length(ACallNeedle));
  EndPos := StartPos;
  while (EndPos <= Length(ALine)) and (ALine[EndPos] <> ')') do
    Inc(EndPos);
  if EndPos > Length(ALine) then
    Exit;
  Result := Copy(ALine, StartPos, EndPos - StartPos);
end;

function CountChar(const AText: string; AChar: Char): LongInt;
var
  I: LongInt;
begin
  Result := 0;
  for I := 1 to Length(AText) do
    if AText[I] = AChar then
      Inc(Result);
end;

procedure AssertDirectOwnedReturnContract;
var
  Model: TSemanticModel;
  Node: TTypedHirNode;
  LlvmText: string;
begin
  Model := BuildModel(DirectConcatReturnSource);
  try
    if Model = nil then
      Fail('direct-return-model-nil');
    if not FindFirstNodeByKind(Model, 'ret-str-owned-runtime', Node) then
      Fail('missing-owned-string-return-node');
    if FindFirstNodeByKind(Model, 'ret-str-runtime', Node) then
      Fail('legacy-string-return-node-must-be-replaced');
    if not FindFirstNodeByKindAndDisplayName(Model,
      'var-decl-str-owned-runtime', 'MakeText', Node) then
      Fail('missing-owned-function-name-result-slot');
    if not FindFirstNodeByKindAndDisplayName(Model,
      'assign-str-owned-concat-runtime', 'MakeText', Node) then
      Fail('missing-owned-concat-to-result-node');

    LlvmText := EmitLlvm(Model);
    RequireContains(LlvmText, 'define {ptr, i64, ptr, i64} @MakeText(',
      'missing-owned-direct-return-llvm-abi');
    RejectContains(LlvmText, 'define {ptr, i64} @MakeText(',
      'legacy-visible-string-return-abi-must-not-remain');
    RequireContains(LlvmText, 'MakeText$owner',
      'missing-result-owner-sidecar');
    RequireContains(LlvmText, 'MakeText$alloc_size',
      'missing-result-alloc-size-sidecar');
    RequireContains(LlvmText,
      'call {ptr, i64, ptr, i64} @np_str_concat_owned(',
      'missing-owned-concat-helper-for-result');
    RequireContains(LlvmText, 'ret {ptr, i64, ptr, i64}',
      'missing-owned-return-ret');
  finally
    Model.Free;
  end;
end;

procedure AssertIntToStrAndLiteralAliasReturnContract;
var
  Model: TSemanticModel;
  Node: TTypedHirNode;
  LlvmText: string;
begin
  Model := BuildModel(IntToStrReturnSource);
  try
    if Model = nil then
      Fail('int-to-str-return-model-nil');
    if not FindFirstNodeByKindAndDisplayName(Model,
      'int-to-str-owned-runtime', 'MakeText', Node) then
      Fail('missing-owned-int-to-str-result-node');
    LlvmText := EmitLlvm(Model);
    RequireContains(LlvmText,
      'call {ptr, i64, ptr, i64} @np_int_to_str_owned(',
      'missing-owned-int-to-str-helper-for-result');
    RejectContains(LlvmText, 'call void @np_free(ptr %digits.',
      'int-to-str-return-must-not-free-visible-interior-pointer');
  finally
    Model.Free;
  end;

  Model := BuildModel(LiteralAndCopyReturnSource);
  try
    if Model = nil then
      Fail('literal-copy-return-model-nil');
    if not FindFirstNodeByKindAndDisplayName(Model,
      'assign-str-literal-runtime', 'LiteralText', Node) then
      Fail('missing-literal-return-assignment-node');
    if not FindFirstNodeByKindAndDisplayName(Model, 'copy-str-runtime',
      'SliceText', Node) then
      Fail('missing-copy-alias-return-node');
    LlvmText := EmitLlvm(Model);
    RequireContains(LlvmText, 'ptr null',
      'literal-or-copy-return-must-carry-null-owner');
    RequireContains(LlvmText, 'i64 0',
      'literal-or-copy-return-must-carry-zero-alloc-size');
  finally
    Model.Free;
  end;
end;

procedure AssertCallerConsumesOwnedDescriptor;
var
  Model: TSemanticModel;
  Node: TTypedHirNode;
  LlvmText: string;
begin
  Model := BuildModel(DirectConcatReturnSource);
  try
    if Model = nil then
      Fail('caller-consume-model-nil');
    if not FindFirstNodeByKindAndDisplayName(Model,
      'assign-str-owned-call-runtime', 'S', Node) then
      Fail('missing-owned-call-assignment-node');
    LlvmText := EmitLlvm(Model);
    RequireContains(LlvmText, ' = call {ptr, i64, ptr, i64} @MakeText(',
      'caller-must-call-owned-string-return-abi');
    RequireContains(LlvmText, 'extractvalue {ptr, i64, ptr, i64}',
      'caller-must-extract-owned-return-descriptor');
    RequireContains(LlvmText, 'S$owner',
      'caller-must-store-returned-owner');
    RequireContains(LlvmText, 'S$alloc_size',
      'caller-must-store-returned-alloc-size');
    RequireOrder(LlvmText, 'extractvalue {ptr, i64, ptr, i64}',
      'call void @np_string_release(',
      'caller-must-materialize-return-before-releasing-old-owner');
  finally
    Model.Free;
  end;
end;

procedure AssertMoveAndChainedReturnContract;
var
  Model: TSemanticModel;
  Node: TTypedHirNode;
  LlvmText: string;
begin
  Model := BuildModel(LocalMoveReturnSource);
  try
    if Model = nil then
      Fail('local-move-return-model-nil');
    if not FindFirstNodeByKindAndDisplayName(Model,
      'assign-str-move-to-result-runtime', 'MakeText', Node) then
      Fail('missing-owned-local-move-to-result-node');
    LlvmText := EmitLlvm(Model);
    RequireContains(LlvmText, 'Tmp$owner',
      'missing-local-owner-sidecar-for-move');
    RequireContains(LlvmText, 'store ptr null',
      'move-to-result-must-clear-source-owner');
  finally
    Model.Free;
  end;

  Model := BuildModel(ChainedReturnSource);
  try
    if Model = nil then
      Fail('chained-return-model-nil');
    if not FindFirstNodeByKindAndDisplayName(Model,
      'assign-str-owned-call-runtime', 'OuterText', Node) then
      Fail('missing-owned-call-into-result-slot');
    LlvmText := EmitLlvm(Model);
    RequireContains(LlvmText, ' = call {ptr, i64, ptr, i64} @InnerText(',
      'inner-return-descriptor-must-feed-outer-result');
    RequireContains(LlvmText, 'define {ptr, i64, ptr, i64} @OuterText(',
      'outer-return-must-preserve-owned-descriptor');
  finally
    Model.Free;
  end;
end;

procedure RequireAnalyzeError(const ASource, ACode, AMessage: string);
begin
  if not AnalyzeSourceHasError(ASource, ACode) then
    Fail(AMessage);
end;

procedure AssertDeferredBoundariesPreserved;
var
  Model: TSemanticModel;
  Node: TTypedHirNode;
  LlvmText, EchoCallLine, EchoArgs: string;
begin
  Model := BuildModel(BorrowedParamBoundarySource);
  try
    if Model = nil then
      Fail('borrowed-param-boundary-model-nil');
    if not FindFirstNodeByKindAndDisplayName(Model,
      'var-decl-str-borrowed-runtime', 'P', Node) then
      Fail('string-param-must-remain-borrowed');
    LlvmText := EmitLlvm(Model);
    EchoCallLine := FindLineContaining(LlvmText, '@Echo(');
    if EchoCallLine = '' then
      Fail('missing-echo-call-line');
    EchoArgs := ExtractCallArguments(EchoCallLine, '@Echo(');
    if EchoArgs = '' then
      Fail('missing-echo-call-args');
    if Pos('ptr ', EchoArgs) <> 1 then
      Fail('string-param-call-must-keep-visible-ptr-arg');
    if Pos(', i64 ', EchoArgs) = 0 then
      Fail('string-param-call-must-keep-visible-len-arg');
    if CountChar(EchoArgs, ',') <> 1 then
      Fail('string-param-call-must-not-pass-owner-sidecars');
  finally
    Model.Free;
  end;

  Model := BuildModel(FieldBoundarySource);
  try
    if Model = nil then
      Fail('field-boundary-model-nil');
    if not FindFirstNodeByKind(Model, 'field-store-str-runtime', Node) then
      Fail('string-field-store-node-must-remain-visible');
    LlvmText := EmitLlvm(Model);
    RejectContains(LlvmText, '$owner',
      'string-fields-must-not-gain-owner-sidecars-in-c6h4');
    RejectContains(LlvmText, '@np_object_string_cleanup',
      'object-string-cleanup-must-remain-deferred');
    RejectContains(LlvmText, '@np_object_free_release',
      'object-free-release-must-remain-field-agnostic-for-strings');
  finally
    Model.Free;
  end;

  Model := BuildModel(LegacyOnlyReturnConsumerSource);
  try
    if Model = nil then
      Fail('legacy-only-return-consumer-model-nil');
    LlvmText := EmitLlvm(Model);
    RequireContains(LlvmText, 'define {ptr, i64} @Greeting(',
      'legacy-only-consumer-must-keep-visible-string-return');
    RequireContains(LlvmText, 'call {ptr, i64} @Greeting(',
      'legacy-only-consumer-must-call-visible-string-return');
    RejectContains(LlvmText, 'define {ptr, i64, ptr, i64} @Greeting(',
      'legacy-only-consumer-must-not-use-owned-string-return');
    RejectContains(LlvmText, 'call {ptr, i64, ptr, i64} @Greeting(',
      'legacy-only-consumer-must-not-call-owned-string-return');
  finally
    Model.Free;
  end;
end;

procedure AssertDeferredOwnedReturnConsumersFailClosed;
const
  DeferredCode = 'sema.c6h4-owned-string-return-deferred-consumer';
begin
  RequireAnalyzeError(MixedOwnedAndLegacyConsumerSource, DeferredCode,
    'mixed-owned-string-return-consumer-must-fail-closed');
  RequireAnalyzeError(OverloadedStringReturnSource, DeferredCode,
    'overloaded-owned-string-return-must-fail-closed');
  RequireAnalyzeError(FieldOwnedReturnConsumerSource, DeferredCode,
    'field-owned-string-return-consumer-must-fail-closed');
  RequireAnalyzeError(LengthOwnedReturnConsumerSource, DeferredCode,
    'length-owned-string-return-consumer-must-fail-closed');
  RequireAnalyzeError(CopyOwnedReturnConsumerSource, DeferredCode,
    'copy-owned-string-return-consumer-must-fail-closed');
end;

begin
  AssertDirectOwnedReturnContract;
  AssertIntToStrAndLiteralAliasReturnContract;
  AssertCallerConsumesOwnedDescriptor;
  AssertMoveAndChainedReturnContract;
  AssertDeferredBoundariesPreserved;
  AssertDeferredOwnedReturnConsumersFailClosed;
  WriteLn('hir-string-return-ownership-contract-status=pass');
end.
