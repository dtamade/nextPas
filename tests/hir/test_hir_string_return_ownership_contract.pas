program test_hir_string_return_ownership_contract;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.compiler.syntax.ast_facade,
  nextpas.compiler.diagnostics.sink,
  nextpas.compiler.syntax.green_tree,
  np_hir_builder,
  np_hir_llvm_emitter,
  nextpas.compiler.syntax.lexer,
  nextpas.compiler.sema.analyzer,
  nextpas.compiler.sema.semantic_model,
  nextpas.compiler.frontend.unit_graph;

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

  // H17: class field owned string store (now supported)
  ClassFieldOwnedReturnConsumerSource =
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

  // H17: Self class field owned string store (now supported)
  SelfFieldOwnedReturnConsumerSource =
    'program test;' + LineEnding +
    'type TStringBox = class' + LineEnding +
    '  Text: string;' + LineEnding +
    '  procedure StoreSelf;' + LineEnding +
    'end;' + LineEnding +
    'function MakeText: string;' + LineEnding +
    'begin' + LineEnding +
    '  MakeText := ''self'';' + LineEnding +
    'end;' + LineEnding +
    'procedure TStringBox.StoreSelf;' + LineEnding +
    'begin' + LineEnding +
    '  Self.Text := MakeText();' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    'end.';

  OverwriteFieldOwnedReturnConsumerSource =
    'program test;' + LineEnding +
    'type TStringBox = class' + LineEnding +
    '  Text: string;' + LineEnding +
    'end;' + LineEnding +
    'function MakeTextA: string;' + LineEnding +
    'begin' + LineEnding +
    '  MakeTextA := ''first'';' + LineEnding +
    'end;' + LineEnding +
    'function MakeTextB: string;' + LineEnding +
    'begin' + LineEnding +
    '  MakeTextB := ''second'';' + LineEnding +
    'end;' + LineEnding +
    'var Box: TStringBox;' + LineEnding +
    'begin' + LineEnding +
    '  Box := TStringBox.Create;' + LineEnding +
    '  Box.Text := MakeTextA();' + LineEnding +
    '  Box.Text := MakeTextB();' + LineEnding +
    '  Box.Free;' + LineEnding +
    'end.';

  LayoutAfterStringFieldSource =
    'program test;' + LineEnding +
    'type ITextHolder = interface' + LineEnding +
    '  procedure Touch;' + LineEnding +
    'end;' + LineEnding +
    'type TStringLayoutBox = class(TInterfacedObject, ITextHolder)' + LineEnding +
    '  Text: string;' + LineEnding +
    '  Count: Integer;' + LineEnding +
    '  procedure Touch;' + LineEnding +
    'end;' + LineEnding +
    'procedure TStringLayoutBox.Touch;' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'var Holder: ITextHolder;' + LineEnding +
    'begin' + LineEnding +
    '  Holder := TStringLayoutBox.Create;' + LineEnding +
    'end.';

  ObjectFreeStringCleanupSource =
    'program test;' + LineEnding +
    'type TStringPair = class' + LineEnding +
    '  Text: string;' + LineEnding +
    '  Note: string;' + LineEnding +
    '  Count: Integer;' + LineEnding +
    'end;' + LineEnding +
    'procedure FreeBox(Box: TStringPair);' + LineEnding +
    'begin' + LineEnding +
    '  Box.Free;' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    'end.';

  // H17: record field owned string store (still fail-closed)
  RecordFieldOwnedReturnConsumerSource =
    'program test;' + LineEnding +
    'type TDataRec = record' + LineEnding +
    '  Name: string;' + LineEnding +
    'end;' + LineEnding +
    'function MakeText: string;' + LineEnding +
    'begin' + LineEnding +
    '  MakeText := ''record'';' + LineEnding +
    'end;' + LineEnding +
    'var Rec: TDataRec;' + LineEnding +
    'begin' + LineEnding +
    '  Rec.Name := MakeText();' + LineEnding +
    'end.';

  // H17: array element owned string store (still fail-closed)
  ArrayElementOwnedReturnConsumerSource =
    'program test;' + LineEnding +
    'var Arr: array of string;' + LineEnding +
    'function MakeText: string;' + LineEnding +
    'begin' + LineEnding +
    '  MakeText := ''array'';' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    '  SetLength(Arr, 3);' + LineEnding +
    '  Arr[0] := MakeText();' + LineEnding +
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
  StartPos, EndPos, Depth: LongInt;
begin
  Result := '';
  StartPos := Pos(ACallNeedle, ALine);
  if StartPos = 0 then
    Exit;
  Inc(StartPos, Length(ACallNeedle));
  EndPos := StartPos;
  Depth := 1;
  while (EndPos <= Length(ALine)) and (Depth > 0) do
  begin
    if ALine[EndPos] = '(' then
      Inc(Depth)
    else if ALine[EndPos] = ')' then
      Dec(Depth);
    if Depth > 0 then
      Inc(EndPos);
  end;
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

function CountSubstring(const AText, ANeedle: string): LongInt;
var
  SearchPos, MatchPos: LongInt;
begin
  Result := 0;
  SearchPos := 1;
  while SearchPos <= Length(AText) do
  begin
    MatchPos := FindAfter(ANeedle, AText, SearchPos);
    if MatchPos = 0 then
      Exit;
    Inc(Result);
    SearchPos := MatchPos + Length(ANeedle);
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
    if not FindFirstNodeByKind(Model, 'ret-tstring-runtime', Node) then
      Fail('missing-tstring-return-node');
    if not FindFirstNodeByKindAndDisplayName(Model,
      'var-decl-tstring-runtime', 'MakeText', Node) then
      Fail('missing-owned-function-name-result-slot');
    if not FindFirstNodeByKindAndDisplayName(Model,
      'assign-tstring-concat-runtime', 'MakeText', Node) then
      Fail('missing-owned-concat-to-result-node');

    LlvmText := EmitLlvm(Model);
    { sret ABI: string-returning function takes sret ptr as first arg }
    RequireContains(LlvmText, 'define void @MakeText(ptr sret(%TString)',
      'missing-sret-maketext-definition');
    { Concat via np_tstring_concat (not legacy np_str_concat_owned) }
    RequireContains(LlvmText, 'call void @np_tstring_concat(',
      'missing-tstring-concat-call');
    { sret return is void, not struct-valued }
    RequireContains(LlvmText, 'ret void',
      'missing-sret-ret-void');
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
      'tstring-from-int-runtime', 'MakeText', Node) then
      Fail('missing-owned-int-to-str-result-node');
    LlvmText := EmitLlvm(Model);
    { IntToStr now uses np_tstring_from_int (sret model) }
    RequireContains(LlvmText,
      'call void @np_tstring_from_int(',
      'missing-tstring-from-int-call');
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
      'assign-tstring-literal-runtime', 'LiteralText', Node) then
      Fail('missing-literal-return-assignment-node');
    if not FindFirstNodeByKindAndDisplayName(Model, 'tstring-copy-runtime',
      'SliceText', Node) then
      Fail('missing-copy-alias-return-node');
    LlvmText := EmitLlvm(Model);
    { sret model: literal and copy returns use sret, no sidecars }
    RequireContains(LlvmText, 'define void @LiteralText(ptr sret(%TString)',
      'literal-text-must-use-sret');
    RequireContains(LlvmText, 'define void @SliceText(ptr sret(%TString)',
      'slice-text-must-use-sret');
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
      'assign-tstring-call-runtime', 'S', Node) then
      Fail('missing-owned-call-assignment-node');
    LlvmText := EmitLlvm(Model);
    { sret model: caller passes result pointer with sret annotation }
    RequireContains(LlvmText, 'call void @MakeText(ptr sret(%TString) @g_S$ts',
      'caller-must-pass-sret-ptr-to-maketext');
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
    { sret model: move-to-result via tstring_ret_move intrinsic (no HIR node) }
    if not FindFirstNodeByKind(Model, 'ret-tstring-runtime', Node) then
      Fail('missing-ret-tstring-for-move-to-result');
    LlvmText := EmitLlvm(Model);
    { sret model: move to result via np_tstring_assign, no sidecar }
    RequireContains(LlvmText, 'call void @np_tstring_assign(ptr %',
      'missing-tstring-assign-for-move-to-result');
  finally
    Model.Free;
  end;

  Model := BuildModel(ChainedReturnSource);
  try
    if Model = nil then
      Fail('chained-return-model-nil');
    if not FindFirstNodeByKindAndDisplayName(Model,
      'assign-tstring-call-runtime', 'OuterText', Node) then
      Fail('missing-owned-call-into-result-slot');
    LlvmText := EmitLlvm(Model);
    { sret model: chained return passes sret pointer with annotation }
    RequireContains(LlvmText, 'call void @InnerText(ptr sret(%TString) %',
      'inner-sret-call-must-feed-outer-result');
    RequireContains(LlvmText, 'define void @OuterText(ptr sret(%TString)',
      'outer-return-must-use-sret');
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
      'var-decl-tstring-runtime', 'P', Node) then
      Fail('string-param-must-remain-borrowed');
    LlvmText := EmitLlvm(Model);
    EchoCallLine := FindLineContaining(LlvmText, '@Echo(');
    if EchoCallLine = '' then
      Fail('missing-echo-call-line');
    EchoArgs := ExtractCallArguments(EchoCallLine, '@Echo(');
    if EchoArgs = '' then
      Fail('missing-echo-call-args');
    { sret model: Echo returns string so has sret(TString) ptr + data ptr + len.
      The string param P is passed as (ptr, i64) after the sret ptr.
      Verify no owner/alloc_size sidecars in the borrowed param position. }
    if Pos('ptr sret(%TString) ', EchoArgs) <> 1 then
      Fail('string-param-call-must-start-with-sret-ptr');
    if Pos(', ptr ', EchoArgs) = 0 then
      Fail('string-param-call-must-keep-visible-ptr-arg');
    if Pos(', i64 ', EchoArgs) = 0 then
      Fail('string-param-call-must-keep-visible-len-arg');
    { sret + data + len = 2 commas max; reject 3+ commas (owner sidecars) }
    if CountChar(EchoArgs, ',') > 2 then
      Fail('string-param-call-must-not-pass-owner-sidecars');
  finally
    Model.Free;
  end;

  Model := BuildModel(FieldBoundarySource);
  try
    if Model = nil then
      Fail('field-boundary-model-nil');
    if not FindFirstNodeByKind(Model, 'field-store-tstring-runtime', Node) then
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
    { sret model: all string returns use sret; verify Greeting uses it }
    RequireContains(LlvmText, 'define void @Greeting(ptr sret(%TString)',
      'legacy-greeting-must-use-sret');
  finally
    Model.Free;
  end;
end;

procedure AssertDeferredOwnedReturnConsumersPassOpen;
begin
  { sret model: C6-H4 owned-string-return-deferred-consumer is no longer
    emitted. The sret calling convention manages temporary lifetimes
    implicitly — the caller allocates the result slot and the callee
    writes into it. Deferred consumer patterns (WriteLn, Halt, etc.)
    are safe because the owned temporary is the caller's sret slot. }
  if AnalyzeSourceHasError(MixedOwnedAndLegacyConsumerSource,
    'sema.c6h4-owned-string-return-deferred-consumer') then
    Fail('mixed-owned-string-return-consumer-must-pass-in-sret-model');
  if AnalyzeSourceHasError(OverloadedStringReturnSource,
    'sema.c6h4-owned-string-return-deferred-consumer') then
    Fail('overloaded-owned-string-return-must-pass-in-sret-model');
  if AnalyzeSourceHasError(RecordFieldOwnedReturnConsumerSource,
    'sema.c6h4-owned-string-return-deferred-consumer') then
    Fail('record-field-owned-string-return-must-pass-in-sret-model');
  if AnalyzeSourceHasError(ArrayElementOwnedReturnConsumerSource,
    'sema.c6h4-owned-string-return-deferred-consumer') then
    Fail('array-element-owned-string-return-must-pass-in-sret-model');
end;

procedure AssertClassFieldOwnedStoreContract;
var
  Model: TSemanticModel;
  Node: TTypedHirNode;
  LlvmText: string;
  StartSlice, CleanupSlice: string;
  SecondCallPos, OverwriteReleasePos, CleanupCallPos: LongInt;
begin
  // H17: class field owned string store should now pass sema
  Model := BuildModel(ClassFieldOwnedReturnConsumerSource);
  try
    if Model = nil then
      Fail('class-field-owned-store-model-nil');
    if not SameText(Model.Status, 'ready') then
      Fail('class-field-owned-store-must-pass-sema');
    if not FindFirstNodeByKind(Model, 'field-store-tstring-runtime', Node) then
      Fail('missing-class-field-owned-store-node');
    LlvmText := EmitLlvm(Model);
    if LlvmText = '' then
      Fail('class-field-owned-store-llvm-empty');
    { sret model: field store uses np_tstring_field_assign }
    RequireContains(LlvmText, 'call void @np_tstring_field_assign(',
      'class-field-owned-store-must-use-tstring-field-assign');
  finally
    Model.Free;
  end;

  Model := BuildModel(SelfFieldOwnedReturnConsumerSource);
  try
    if Model = nil then
      Fail('self-field-owned-store-model-nil');
    if not SameText(Model.Status, 'ready') then
      Fail('self-field-owned-store-must-pass-sema');
    if not FindFirstNodeByKind(Model, 'field-store-tstring-runtime', Node) then
      Fail('missing-self-field-owned-store-node');
    LlvmText := EmitLlvm(Model);
    if LlvmText = '' then
      Fail('self-field-owned-store-llvm-empty');
    { sret model: self field store uses np_tstring_field_assign }
    RequireContains(LlvmText, 'call void @np_tstring_field_assign(',
      'self-field-owned-store-must-use-tstring-field-assign');
  finally
    Model.Free;
  end;

  Model := BuildModel(OverwriteFieldOwnedReturnConsumerSource);
  try
    if Model = nil then
      Fail('overwrite-field-owned-store-model-nil');
    if not SameText(Model.Status, 'ready') then
      Fail('overwrite-field-owned-store-must-pass-sema');
    LlvmText := EmitLlvm(Model);
    StartSlice := ExtractDefinitionSlice(LlvmText, 'define i64 @_start() {');
    if StartSlice = '' then
      Fail('missing-overwrite-start-function');
    SecondCallPos := FindAfter(
      'call void @MakeTextB(ptr sret(%TString) ', StartSlice, 1);
    if SecondCallPos = 0 then
      Fail('missing-second-owned-string-return-call');
    { sret model: field overwrite uses np_tstring_field_assign which
      handles release internally. Verify field_assign after second call. }
    OverwriteReleasePos := FindAfter('call void @np_tstring_field_assign(',
      StartSlice, SecondCallPos);
    if OverwriteReleasePos = 0 then
      Fail('missing-field-assign-after-second-call');
    CleanupCallPos := FindAfter(
      'call void @np_object_string_cleanup_TStringBox(ptr ',
      StartSlice, OverwriteReleasePos);
    if CleanupCallPos = 0 then
      Fail('missing-object-free-cleanup-after-overwrite');
    if OverwriteReleasePos >= CleanupCallPos then
      Fail('field-assign-must-precede-object-free-cleanup');

    CleanupSlice := ExtractDefinitionSlice(LlvmText,
      'define internal void @np_object_string_cleanup_TStringBox(ptr %');
    if CleanupSlice = '' then
      Fail('missing-overwrite-cleanup-helper');
    { sret model: cleanup helper releases each string field via np_string_release }
    if CountSubstring(CleanupSlice, 'call void @np_string_release(') < 1 then
      Fail('cleanup-helper-must-release-string-fields');
  finally
    Model.Free;
  end;
end;

procedure AssertStringFieldLayoutMetadataContract;
var
  Model: TSemanticModel;
begin
  Model := BuildModel(LayoutAfterStringFieldSource);
  try
    if Model = nil then
      Fail('layout-after-string-field-model-nil');
    RequireConst(Model, 'TStringLayoutBox.Text$idx', 1);
    RequireConst(Model, 'TStringLayoutBox.Count$idx', 5);
    RequireConst(Model, 'TStringLayoutBox$intf_offset_ITextHolder', 48);
    RequireConst(Model, 'TStringLayoutBox$size', 56);
  finally
    Model.Free;
  end;
end;

procedure AssertObjectFreeStringCleanupContract;
var
  Model: TSemanticModel;
  LlvmText, HelperSlice, FreeSlice: string;
  CleanupCallPos, ReleaseCallPos: LongInt;
  FirstReleasePos, FirstZeroStartPos, SecondReleasePos, SecondZeroStartPos: LongInt;
  FirstZeroSlice, SecondZeroSlice: string;
begin
  Model := BuildModel(ObjectFreeStringCleanupSource);
  try
    if Model = nil then
      Fail('object-free-string-cleanup-model-nil');
    LlvmText := EmitLlvm(Model);
    HelperSlice := ExtractDefinitionSlice(LlvmText,
      'define internal void @np_object_string_cleanup_TStringPair(ptr %');
    if HelperSlice = '' then
      Fail('missing-object-free-string-cleanup-helper');
    if CountSubstring(HelperSlice, 'call void @np_string_release(') <> 2 then
      Fail('string-cleanup-helper-must-release-each-string-field-owner');
    FirstReleasePos := FindAfter('call void @np_string_release(',
      HelperSlice, 1);
    FirstZeroStartPos := FindAfter('inttoptr i64 0 to ptr',
      HelperSlice, FirstReleasePos);
    SecondReleasePos := FindAfter('call void @np_string_release(',
      HelperSlice, FirstZeroStartPos);
    SecondZeroStartPos := FindAfter('inttoptr i64 0 to ptr',
      HelperSlice, SecondReleasePos);
    if (FirstReleasePos = 0) or (FirstZeroStartPos = 0) or
      (SecondReleasePos = 0) or (SecondZeroStartPos = 0) then
      Fail('string-cleanup-helper-must-zero-slots-after-each-release');
    FirstZeroSlice := Copy(HelperSlice, FirstZeroStartPos,
      SecondReleasePos - FirstZeroStartPos);
    SecondZeroSlice := Copy(HelperSlice, SecondZeroStartPos, MaxInt);
    if (CountSubstring(FirstZeroSlice, 'store ptr ') < 2) or
      (CountSubstring(FirstZeroSlice, 'store i64 ') < 2) then
      Fail('first-string-field-must-clear-all-four-slots');
    if (CountSubstring(SecondZeroSlice, 'store ptr ') < 2) or
      (CountSubstring(SecondZeroSlice, 'store i64 ') < 2) then
      Fail('second-string-field-must-clear-all-four-slots');
    RequireContains(HelperSlice, 'add i64 7, 0',
      'missing-note-owner-slot-walk');
    RequireContains(HelperSlice, 'add i64 3, 0',
      'missing-text-owner-slot-walk');

    FreeSlice := ExtractDefinitionSlice(LlvmText, 'define i64 @FreeBox(');
    if FreeSlice = '' then
      Fail('missing-freebox-function');
    CleanupCallPos := FindAfter(
      'call void @np_object_string_cleanup_TStringPair(ptr ',
      FreeSlice, 1);
    if CleanupCallPos = 0 then
      Fail('missing-freebox-string-cleanup-call');
    ReleaseCallPos := FindAfter('call void @np_object_free_release(ptr ',
      FreeSlice, CleanupCallPos);
    if ReleaseCallPos = 0 then
      Fail('missing-freebox-heap-release-call');
    if CleanupCallPos >= ReleaseCallPos then
      Fail('string-cleanup-must-precede-heap-release');
  finally
    Model.Free;
  end;
end;

begin
  AssertDirectOwnedReturnContract;
  AssertIntToStrAndLiteralAliasReturnContract;
  AssertCallerConsumesOwnedDescriptor;
  AssertMoveAndChainedReturnContract;
  AssertDeferredBoundariesPreserved;
  AssertDeferredOwnedReturnConsumersPassOpen;
  AssertClassFieldOwnedStoreContract; // H17: new test
  AssertStringFieldLayoutMetadataContract;
  AssertObjectFreeStringCleanupContract;
  WriteLn('hir-string-return-ownership-contract-status=pass');
end.
