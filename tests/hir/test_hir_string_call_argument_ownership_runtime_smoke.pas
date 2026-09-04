program test_hir_string_call_argument_ownership_runtime_smoke;

{$mode objfpc}{$H+}

uses
  nextpas.core.text.conv, nextpas.core.os.env, nextpas.core.fs, nextpas.core.path,
  nextpas.core.process,
  nextpas.compiler.syntax.ast_facade,
  nextpas.compiler.diagnostics.sink,
  nextpas.compiler.syntax.green_tree,
  nextpas.compiler.ir.hir.builder,
  nextpas.compiler.ir.hir.llvm_emitter,
  nextpas.compiler.syntax.lexer,
  nextpas.compiler.sema.analyzer,
  nextpas.compiler.sema.semantic_model,
  nextpas.compiler.frontend.unit_graph;

const
  DirectOwnedArgumentSource =
    'program c6h5_direct_string_arg_runtime;' + LineEnding +
    'function MakeText: string;' + LineEnding +
    'var Prefix: string;' + LineEnding +
    'begin' + LineEnding +
    '  Prefix := IntToStr(12);' + LineEnding +
    '  MakeText := Prefix + IntToStr(34);' + LineEnding +
    'end;' + LineEnding +
    'procedure Take(P: string);' + LineEnding +
    'begin' + LineEnding +
    '  Halt(42);' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    '  Take(MakeText());' + LineEnding +
    '  Halt(7);' + LineEnding +
    'end.';

  NestedOwnedArgumentSource =
    'program c6h5_nested_string_arg_runtime;' + LineEnding +
    'function MakeText: string;' + LineEnding +
    'begin' + LineEnding +
    '  MakeText := IntToStr(42);' + LineEnding +
    'end;' + LineEnding +
    'function Wrap(P: string): string;' + LineEnding +
    'begin' + LineEnding +
    '  Wrap := IntToStr(427);' + LineEnding +
    'end;' + LineEnding +
    'var S: string;' + LineEnding +
    'begin' + LineEnding +
    '  S := IntToStr(427);' + LineEnding +
    '  Wrap(MakeText());' + LineEnding +
    '  if Length(S) = 3 then Halt(42);' + LineEnding +
    '  Halt(17);' + LineEnding +
    'end.';

  MultiOwnedArgumentSource =
    'program c6h5_multi_string_arg_runtime;' + LineEnding +
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
    '  Halt(42);' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    '  Take2(MakeA(), MakeB());' + LineEnding +
    '  Halt(11);' + LineEnding +
    'end.';

  LiteralBorrowedArgumentSource =
    'program c6h5_literal_string_arg_runtime;' + LineEnding +
    'procedure Take(P: string);' + LineEnding +
    'begin' + LineEnding +
    '  Halt(42);' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    '  Take(''literal'');' + LineEnding +
    '  Halt(5);' + LineEnding +
    'end.';

  WriteLnOwnedArgumentSource =
    'program c6h7_writeln_string_arg_runtime;' + LineEnding +
    'function MakeText: string;' + LineEnding +
    'begin' + LineEnding +
    '  MakeText := IntToStr(42);' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    '  WriteLn(MakeText());' + LineEnding +
    '  Halt(42);' + LineEnding +
    'end.';

  WriteLnConcatOwnedArgumentSource =
    'program c6h16_writeln_concat_string_arg_runtime;' + LineEnding +
    'function MakeText: string;' + LineEnding +
    'begin' + LineEnding +
    '  MakeText := IntToStr(4);' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    '  WriteLn(MakeText() + IntToStr(2));' + LineEnding +
    '  Halt(42);' + LineEnding +
    'end.';

  ConcatLeftOwnedArgumentSource =
    'program c6h9_concat_left_string_arg_runtime;' + LineEnding +
    'function MakeText: string;' + LineEnding +
    'begin' + LineEnding +
    '  MakeText := IntToStr(1234);' + LineEnding +
    'end;' + LineEnding +
    'var S, Tail: string;' + LineEnding +
    'begin' + LineEnding +
    '  Tail := IntToStr(5);' + LineEnding +
    '  S := MakeText() + Tail;' + LineEnding +
    '  Halt(42);' + LineEnding +
    'end.';

  ConcatRightOwnedArgumentSource =
    'program c6h9_concat_right_string_arg_runtime;' + LineEnding +
    'function MakeText: string;' + LineEnding +
    'begin' + LineEnding +
    '  MakeText := IntToStr(2345);' + LineEnding +
    'end;' + LineEnding +
    'var S, Prefix: string;' + LineEnding +
    'begin' + LineEnding +
    '  Prefix := IntToStr(1);' + LineEnding +
    '  S := Prefix + MakeText();' + LineEnding +
    '  Halt(42);' + LineEnding +
    'end.';

  ConcatBothOwnedArgumentSource =
    'program c6h9_concat_both_string_arg_runtime;' + LineEnding +
    'function MakeA: string;' + LineEnding +
    'begin' + LineEnding +
    '  MakeA := IntToStr(12);' + LineEnding +
    'end;' + LineEnding +
    'function MakeB: string;' + LineEnding +
    'begin' + LineEnding +
    '  MakeB := IntToStr(345);' + LineEnding +
    'end;' + LineEnding +
    'var S: string;' + LineEnding +
    'begin' + LineEnding +
    '  S := MakeA() + MakeB();' + LineEnding +
    '  Halt(42);' + LineEnding +
    'end.';

  CompareLeftOwnedArgumentSource =
    'program c6h10_compare_left_string_arg_runtime;' + LineEnding +
    'function MakeText: string;' + LineEnding +
    'begin' + LineEnding +
    '  MakeText := IntToStr(7);' + LineEnding +
    'end;' + LineEnding +
    'var Expected: string;' + LineEnding +
    'begin' + LineEnding +
    '  Expected := IntToStr(7);' + LineEnding +
    '  if MakeText() = Expected then Halt(42) else Halt(42);' + LineEnding +
    'end.';

  CompareRightOwnedArgumentSource =
    'program c6h10_compare_right_string_arg_runtime;' + LineEnding +
    'function MakeText: string;' + LineEnding +
    'begin' + LineEnding +
    '  MakeText := IntToStr(7);' + LineEnding +
    'end;' + LineEnding +
    'var Expected: string;' + LineEnding +
    'begin' + LineEnding +
    '  Expected := IntToStr(7);' + LineEnding +
    '  if Expected = MakeText() then Halt(42) else Halt(42);' + LineEnding +
    'end.';

  CompareNotEqualOwnedArgumentSource =
    'program c6h10_compare_not_equal_string_arg_runtime;' + LineEnding +
    'function MakeText: string;' + LineEnding +
    'begin' + LineEnding +
    '  MakeText := IntToStr(7);' + LineEnding +
    'end;' + LineEnding +
    'var Expected: string;' + LineEnding +
    'begin' + LineEnding +
    '  Expected := IntToStr(8);' + LineEnding +
    '  if MakeText() <> Expected then Halt(42) else Halt(42);' + LineEnding +
    'end.';

  CompareRuntimeVarOwnedArgumentSource =
    'program c6h10_compare_runtime_var_string_arg_runtime;' + LineEnding +
    'function MakeText: string;' + LineEnding +
    'begin' + LineEnding +
    '  MakeText := IntToStr(7);' + LineEnding +
    'end;' + LineEnding +
    'var S: string;' + LineEnding +
    'begin' + LineEnding +
    '  S := IntToStr(7);' + LineEnding +
    '  if MakeText() = S then Halt(42) else Halt(42);' + LineEnding +
    'end.';

  CompareBothOwnedArgumentSource =
    'program c6h11_compare_both_string_arg_runtime;' + LineEnding +
    'function MakeA: string;' + LineEnding +
    'begin' + LineEnding +
    '  MakeA := IntToStr(7);' + LineEnding +
    'end;' + LineEnding +
    'function MakeB: string;' + LineEnding +
    'begin' + LineEnding +
    '  MakeB := IntToStr(7);' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    '  if MakeA() = MakeB() then Halt(42) else Halt(42);' + LineEnding +
    'end.';

  CompareConcatOwnedArgumentSource =
    'program c6h12_compare_concat_string_arg_runtime;' + LineEnding +
    'function MakeText: string;' + LineEnding +
    'begin' + LineEnding +
    '  MakeText := IntToStr(12);' + LineEnding +
    'end;' + LineEnding +
    'var Expected: string;' + LineEnding +
    'begin' + LineEnding +
    '  Expected := IntToStr(123);' + LineEnding +
    '  if MakeText() + IntToStr(3) = Expected then Halt(42) else Halt(42);' + LineEnding +
    'end.';

  CompareCompoundOwnedArgumentSource =
    'program c6h13_compare_compound_string_arg_runtime;' + LineEnding +
    'function MakeText: string;' + LineEnding +
    'begin' + LineEnding +
    '  MakeText := IntToStr(7);' + LineEnding +
    'end;' + LineEnding +
    'var Expected: string;' + LineEnding +
    'begin' + LineEnding +
    '  Expected := IntToStr(7);' + LineEnding +
    '  if (MakeText() = Expected) or True then Halt(42);' + LineEnding +
    '  Halt(51);' + LineEnding +
    'end.';

  CompareWhileOwnedArgumentSource =
    'program c6h14_compare_while_string_arg_runtime;' + LineEnding +
    'function MakeText: string;' + LineEnding +
    'begin' + LineEnding +
    '  MakeText := IntToStr(7);' + LineEnding +
    'end;' + LineEnding +
    'var Expected: string;' + LineEnding +
    'begin' + LineEnding +
    '  Expected := IntToStr(7);' + LineEnding +
    '  while (MakeText() = Expected) and False do Halt(99);' + LineEnding +
    '  Halt(42);' + LineEnding +
    'end.';

  CompareRepeatOwnedArgumentSource =
    'program c6h14_compare_repeat_string_arg_runtime;' + LineEnding +
    'function MakeText: string;' + LineEnding +
    'begin' + LineEnding +
    '  MakeText := IntToStr(7);' + LineEnding +
    'end;' + LineEnding +
    'var Expected: string;' + LineEnding +
    'begin' + LineEnding +
    '  Expected := IntToStr(7);' + LineEnding +
    '  repeat' + LineEnding +
    '  until (MakeText() = Expected) or True;' + LineEnding +
    '  Halt(42);' + LineEnding +
    'end.';

procedure Fail(const AMessage: string);
begin
  WriteLn('hir-string-call-argument-ownership-runtime-smoke-failure=', AMessage);
  Halt(1);
end;

procedure WriteTextFile(const APath, AText: string);
begin
  WriteFileText(APath, AText);
end;

function ToolPath(const AEnvName, ADefaultValue: string): string;
begin
  Result := GetEnvironmentVariable(AEnvName);
  if Result = '' then
    Result := ADefaultValue;
end;

function RuntimeSrcDir: string;
begin
  Result := GetEnvironmentVariable('NEXTPAS_RUNTIME_DIR');
  if Result = '' then
    Result := 'rtl/runtime/src';
end;

procedure RunCommand(const ALabel, AExecutable: string;
  const AArgs: array of string; AExpectedExit: LongInt);
var
  LOut: TProcessOutput;
begin
  LOut := Run(AExecutable, AArgs);
  if LOut.ExitCode <> AExpectedExit then
    Fail(ALabel + '-exit:' + IntToStr(LOut.ExitCode) +
      '-expected:' + IntToStr(AExpectedExit));
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
    if Diagnostics.HasErrors then
      Fail('missing-owned-string-return-runtime:' +
        Diagnostics.LastDiagnosticCode);
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

function EmitLlvmFromSource(const ASource: string): string;
var
  Model: TSemanticModel;
  Builder: THIRBuilder;
  Emitter: THIRLlvmEmitter;
begin
  Model := BuildModel(ASource);
  Builder := nil;
  Emitter := nil;
  try
    if Model = nil then
      Fail('emit-model-nil');
    Builder := THIRBuilder.Create(Model);
    Builder.Build;
    Emitter := THIRLlvmEmitter.Create(Builder.Module);
    Emitter.EmitModule;
    Result := Emitter.AsText;
  finally
    Emitter.Free;
    Builder.Free;
    Model.Free;
  end;
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

function FindAfter(const AText, ANeedle: string; const AStart: LongInt): LongInt;
var
  Local: string;
  PosInLocal: LongInt;
begin
  Result := 0;
  if (AStart <= 0) or (AStart > Length(AText)) then
    Exit;
  Local := Copy(AText, AStart, Length(AText) - AStart + 1);
  PosInLocal := Pos(ANeedle, Local);
  if PosInLocal > 0 then
    Result := AStart + PosInLocal - 1;
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

function FindCallPos(const ALlvmText, AFuncName: string): LongInt;
begin
  Result := Pos('call i64 @' + AFuncName + '(ptr ', ALlvmText);
  if Result = 0 then
    Result := Pos('call void @' + AFuncName + '(ptr ', ALlvmText);
end;

function FindCompareHelperPos(const ALlvmText: string): LongInt;
begin
  Result := Pos('call i64 @np_tstring_equal(ptr ', ALlvmText);
  if Result = 0 then
    Result := Pos('call i64 @np_str_cmp(ptr ', ALlvmText);
end;

procedure RequireReverseReleaseOrder(const ALlvmText: string);
var
  MakeAPos, MakeBPos, DataAPos, LenAPos, DataBPos, LenBPos,
    CallPos, ReleaseBPos, ReleaseAPos: LongInt;
begin
  MakeAPos := Pos('call void @MakeA(ptr ', ALlvmText);
  MakeBPos := Pos('call void @MakeB(ptr ', ALlvmText);
  DataAPos := FindAfter(ALlvmText, 'call ptr @np_tstring_data(ptr ',
    MakeAPos + 1);
  LenAPos := FindAfter(ALlvmText, 'call i64 @np_tstring_len(ptr ',
    DataAPos + 1);
  DataBPos := FindAfter(ALlvmText, 'call ptr @np_tstring_data(ptr ',
    LenAPos + 1);
  LenBPos := FindAfter(ALlvmText, 'call i64 @np_tstring_len(ptr ',
    DataBPos + 1);
  CallPos := Pos('call i64 @Take2(', ALlvmText);
  if (MakeAPos = 0) or (MakeBPos = 0) or
    (DataAPos = 0) or (LenAPos = 0) or
    (DataBPos = 0) or (LenBPos = 0) or
    (CallPos = 0) then
    Fail('missing-multi-owned-string-return-runtime');
  if (MakeAPos >= MakeBPos) or (MakeBPos >= DataAPos) or
    (DataAPos >= LenAPos) or (LenAPos >= DataBPos) or
    (DataBPos >= LenBPos) or (LenBPos >= CallPos) then
    Fail('owned-string-temp-creation-order-runtime');
  ReleaseBPos := FindAfter(ALlvmText, 'call void @np_tstring_fini(ptr ',
    CallPos);
  ReleaseAPos := FindAfter(ALlvmText, 'call void @np_tstring_fini(ptr ',
    ReleaseBPos + 1);
  if (ReleaseBPos = 0) or (ReleaseAPos = 0) then
    Fail('missing-multi-owned-string-temp-release-runtime');
  if ReleaseBPos >= ReleaseAPos then
    Fail('owned-string-temp-release-order-runtime');
end;

procedure AssertOwnedArgumentRuntimeContract(const ALlvmText,
  ACalleeName, AProducerName: string);
var
  ProducerPos, DataPos, LenPos, CallPos, ReleasePos: LongInt;
begin
  ProducerPos := Pos('call void @' + AProducerName + '(ptr ', ALlvmText);
  DataPos := FindAfter(ALlvmText, 'call ptr @np_tstring_data(ptr ',
    ProducerPos + 1);
  LenPos := FindAfter(ALlvmText, 'call i64 @np_tstring_len(ptr ',
    DataPos + 1);
  CallPos := FindCallPos(ALlvmText, ACalleeName);
  ReleasePos := FindAfter(ALlvmText, 'call void @np_tstring_fini(ptr ',
    CallPos + 1);
  if (ProducerPos = 0) or (DataPos = 0) or (LenPos = 0) or
    (CallPos = 0) or (ReleasePos = 0) then
    Fail('missing-owned-string-return-runtime');
  if (ProducerPos >= DataPos) or (DataPos >= LenPos) or
    (LenPos >= CallPos) or (CallPos >= ReleasePos) then
    Fail('string-temp-release-must-follow-enclosing-call-runtime');
end;

procedure AssertLiteralBorrowedRuntimeContract(const ALlvmText: string);
begin
  RequireContains(ALlvmText, '@.str.',
    'missing-literal-borrowed-string-constant-runtime');
  RequireContains(ALlvmText, 'call i64 @Take(ptr ',
    'missing-literal-borrowed-string-argument-runtime');
  RequireContains(ALlvmText, ', i64 ',
    'missing-literal-borrowed-string-length-runtime');
  RejectContains(ALlvmText, 'call void @np_tstring_fini(ptr ',
    'literal-borrowed-argument-must-not-release-runtime');
end;

procedure AssertWriteLnOwnedRuntimeContract(const ALlvmText: string);
var
  ProducerPos, DataPos, LenPos, WritePos, ReleasePos: LongInt;
begin
  ProducerPos := Pos('call void @MakeText(ptr ', ALlvmText);
  DataPos := FindAfter(ALlvmText, 'call ptr @np_tstring_data(ptr ',
    ProducerPos + 1);
  LenPos := FindAfter(ALlvmText, 'call i64 @np_tstring_len(ptr ',
    DataPos + 1);
  WritePos := Pos('call void asm sideeffect "movq $$1, %rax; syscall"',
    ALlvmText);
  if (ProducerPos = 0) or (DataPos = 0) or (LenPos = 0) or
    (WritePos = 0) then
    Fail('missing-writeln-owned-string-write-runtime');
  ReleasePos := FindAfter(ALlvmText, 'call void @np_tstring_fini(ptr ',
    WritePos + 1);
  if ReleasePos = 0 then
    Fail('missing-writeln-owned-string-release-runtime');
  if (ProducerPos >= DataPos) or (DataPos >= LenPos) or
    (LenPos >= WritePos) or (WritePos >= ReleasePos) then
    Fail('writeln-owned-string-temp-release-order-runtime');
end;

procedure AssertWriteLnConcatOwnedRuntimeContract(const ALlvmText: string);
var
  ProducerPos, ConcatPos, DataPos, LenPos, WritePos, ConcatReleasePos,
    SourceReleasePos: LongInt;
begin
  ProducerPos := Pos('call void @MakeText(ptr ', ALlvmText);
  ConcatPos := Pos('call void @np_tstring_concat(ptr ',
    ALlvmText);
  DataPos := FindAfter(ALlvmText, 'call ptr @np_tstring_data(ptr ',
    ConcatPos + 1);
  LenPos := FindAfter(ALlvmText, 'call i64 @np_tstring_len(ptr ',
    DataPos + 1);
  WritePos := FindAfter(ALlvmText,
    'call void asm sideeffect "movq $$1, %rax; syscall"', ConcatPos + 1);
  if (ProducerPos = 0) or (ConcatPos = 0) or (DataPos = 0) or
    (LenPos = 0) or (WritePos = 0) then
    Fail('missing-writeln-concat-owned-string-runtime');
  ConcatReleasePos := FindAfter(ALlvmText, 'call void @np_tstring_fini(ptr ',
    WritePos + 1);
  SourceReleasePos := FindAfter(ALlvmText, 'call void @np_tstring_fini(ptr ',
    ConcatReleasePos + 1);
  if (ConcatReleasePos = 0) or (SourceReleasePos = 0) then
    Fail('missing-writeln-concat-owned-string-release-runtime');
  if (ProducerPos >= ConcatPos) or (ConcatPos >= DataPos) or
    (DataPos >= LenPos) or (LenPos >= WritePos) then
    Fail('writeln-concat-owned-string-temp-creation-order-runtime');
  if WritePos >= ConcatReleasePos then
    Fail('writeln-concat-owned-string-release-must-follow-write-runtime');
  if ConcatReleasePos >= SourceReleasePos then
    Fail('writeln-concat-owned-string-release-order-runtime');
end;

procedure AssertConcatOwnedRuntimeContract(const ALlvmText: string);
var
  ProducerPos, ConcatPos, ReleasePos: LongInt;
begin
  ProducerPos := Pos('call void @MakeText(ptr ', ALlvmText);
  ConcatPos := Pos('call void @np_tstring_concat(ptr ',
    ALlvmText);
  if (ProducerPos = 0) or (ConcatPos = 0) then
    Fail('missing-concat-owned-string-runtime');
  ReleasePos := FindAfter(ALlvmText, 'call void @np_tstring_fini(ptr ',
    ConcatPos + 1);
  if ReleasePos = 0 then
    Fail('missing-concat-owned-string-release-runtime');
  if (ProducerPos >= ConcatPos) or (ConcatPos >= ReleasePos) then
    Fail('concat-owned-string-temp-release-order-runtime');
end;

procedure AssertConcatBothOwnedRuntimeContract(const ALlvmText: string);
var
  MakeAPos, MakeBPos, ConcatPos, ReleaseBPos, ReleaseAPos: LongInt;
begin
  MakeAPos := Pos('call void @MakeA(ptr ', ALlvmText);
  MakeBPos := Pos('call void @MakeB(ptr ', ALlvmText);
  ConcatPos := Pos('call void @np_tstring_concat(ptr ',
    ALlvmText);
  if (MakeAPos = 0) or (MakeBPos = 0) or (ConcatPos = 0) then
    Fail('missing-concat-both-owned-string-runtime');
  ReleaseBPos := FindAfter(ALlvmText, 'call void @np_tstring_fini(ptr ',
    ConcatPos + 1);
  ReleaseAPos := FindAfter(ALlvmText, 'call void @np_tstring_fini(ptr ',
    ReleaseBPos + 1);
  if (ReleaseBPos = 0) or (ReleaseAPos = 0) then
    Fail('missing-concat-both-owned-string-release-runtime');
  if (MakeAPos >= MakeBPos) or (MakeBPos >= ConcatPos) then
    Fail('concat-both-owned-string-temp-creation-order-runtime');
  if ReleaseBPos >= ReleaseAPos then
    Fail('concat-both-owned-string-temp-release-order-runtime');
end;

procedure AssertCompareOwnedRuntimeContract(const ALlvmText: string);
var
  ProducerPos, ComparePos, ReleasePos: LongInt;
begin
  ProducerPos := Pos('call void @MakeText(ptr ', ALlvmText);
  ComparePos := FindCompareHelperPos(ALlvmText);
  if (ProducerPos = 0) or (ComparePos = 0) then
    Fail('missing-compare-owned-string-runtime');
  ReleasePos := FindAfter(ALlvmText, 'call void @np_tstring_fini(ptr ',
    ComparePos + 1);
  if ReleasePos = 0 then
    Fail('missing-compare-owned-string-release-runtime');
  if (ProducerPos >= ComparePos) or (ComparePos >= ReleasePos) then
    Fail('compare-owned-string-temp-release-order-runtime');
end;

procedure AssertCompareBothOwnedRuntimeContract(const ALlvmText: string);
var
  MakeAPos, MakeBPos, ComparePos, ReleaseBPos, ReleaseAPos: LongInt;
begin
  MakeAPos := Pos('call void @MakeA(ptr ', ALlvmText);
  MakeBPos := Pos('call void @MakeB(ptr ', ALlvmText);
  ComparePos := FindCompareHelperPos(ALlvmText);
  if (MakeAPos = 0) or (MakeBPos = 0) or (ComparePos = 0) then
    Fail('missing-compare-both-owned-string-runtime');
  ReleaseBPos := FindAfter(ALlvmText, 'call void @np_tstring_fini(ptr ',
    ComparePos + 1);
  ReleaseAPos := FindAfter(ALlvmText, 'call void @np_tstring_fini(ptr ',
    ReleaseBPos + 1);
  if (ReleaseBPos = 0) or (ReleaseAPos = 0) then
    Fail('missing-compare-both-owned-string-release-runtime');
  if (MakeAPos >= MakeBPos) or (MakeBPos >= ComparePos) then
    Fail('compare-both-owned-string-temp-creation-order-runtime');
  if ReleaseBPos >= ReleaseAPos then
    Fail('compare-both-owned-string-temp-release-order-runtime');
end;

procedure AssertCompareConcatOwnedRuntimeContract(const ALlvmText: string);
var
  ProducerPos, ConcatPos, ComparePos, ConcatReleasePos, SourceReleasePos: LongInt;
begin
  ProducerPos := Pos('call void @MakeText(ptr ', ALlvmText);
  ConcatPos := Pos('call void @np_tstring_concat(ptr ',
    ALlvmText);
  ComparePos := FindCompareHelperPos(ALlvmText);
  if (ProducerPos = 0) or (ConcatPos = 0) or (ComparePos = 0) then
    Fail('missing-compare-concat-owned-string-runtime');
  ConcatReleasePos := FindAfter(ALlvmText, 'call void @np_tstring_fini(ptr ',
    ComparePos + 1);
  SourceReleasePos := FindAfter(ALlvmText, 'call void @np_tstring_fini(ptr ',
    ConcatReleasePos + 1);
  if (ConcatReleasePos = 0) or (SourceReleasePos = 0) then
    Fail('missing-compare-concat-owned-string-release-runtime');
  if (ProducerPos >= ConcatPos) or (ConcatPos >= ComparePos) then
    Fail('compare-concat-owned-string-temp-creation-order-runtime');
  if ComparePos >= ConcatReleasePos then
    Fail('compare-concat-owned-string-release-must-follow-compare-runtime');
  if ConcatReleasePos >= SourceReleasePos then
    Fail('compare-concat-owned-string-release-order-runtime');
end;

procedure AssertCompareCompoundOwnedRuntimeContract(const ALlvmText: string);
var
  ProducerPos, ComparePos, ReleasePos: LongInt;
begin
  ProducerPos := Pos('call void @MakeText(ptr ', ALlvmText);
  ComparePos := FindCompareHelperPos(ALlvmText);
  ReleasePos := FindAfter(ALlvmText, 'call void @np_tstring_fini(ptr ',
    ComparePos + 1);
  if (ProducerPos = 0) or (ComparePos = 0) then
    Fail('missing-compare-compound-owned-string-runtime');
  if ReleasePos = 0 then
    Fail('missing-compare-compound-owned-string-release-runtime');
  if ProducerPos >= ComparePos then
    Fail('compare-compound-owned-string-temp-creation-order-runtime');
  if ComparePos >= ReleasePos then
    Fail('compare-compound-owned-string-release-must-follow-compare-runtime');
end;

procedure AssertCompareLoopOwnedRuntimeContract(const ALlvmText: string);
var
  ProducerPos, ComparePos, ReleasePos, BranchPos: LongInt;
begin
  ProducerPos := Pos('call void @MakeText(ptr ', ALlvmText);
  ComparePos := FindCompareHelperPos(ALlvmText);
  ReleasePos := FindAfter(ALlvmText, 'call void @np_tstring_fini(ptr ',
    ComparePos + 1);
  BranchPos := FindAfter(ALlvmText, 'br i1 ', ReleasePos + 1);
  if (ProducerPos = 0) or (ComparePos = 0) then
    Fail('missing-compare-loop-owned-string-runtime');
  if ReleasePos = 0 then
    Fail('missing-compare-loop-owned-string-release-runtime');
  if BranchPos = 0 then
    Fail('missing-compare-loop-conditional-branch-runtime');
  if ProducerPos >= ComparePos then
    Fail('compare-loop-owned-string-temp-creation-order-runtime');
  if ComparePos >= ReleasePos then
    Fail('compare-loop-owned-string-release-must-follow-compare-runtime');
  if ReleasePos >= BranchPos then
    Fail('compare-loop-owned-string-release-must-precede-branch-runtime');
end;

procedure RunRuntimeSmoke(const AOutputDir, AStem: string);
var
  LlPath, LinkedPath, AsmPath, ExePath, RuntimeDir: string;
begin
  LlPath := IncludeTrailingPathDelimiter(AOutputDir) + AStem + '.ll';
  LinkedPath := IncludeTrailingPathDelimiter(AOutputDir) + AStem + '.linked.ll';
  AsmPath := IncludeTrailingPathDelimiter(AOutputDir) + AStem + '.s';
  ExePath := IncludeTrailingPathDelimiter(AOutputDir) + AStem;
  RuntimeDir := RuntimeSrcDir;

  RunCommand(AStem + '-llvm-link', ToolPath('LLVM_LINK', 'llvm-link'),
    [LlPath,
     IncludeTrailingPathDelimiter(RuntimeDir) + 'nextpas.runtime.memops.ll',
     IncludeTrailingPathDelimiter(RuntimeDir) + 'nextpas.runtime.allocator.ll',
     IncludeTrailingPathDelimiter(RuntimeDir) + 'nextpas.runtime.strings.ll',
     IncludeTrailingPathDelimiter(RuntimeDir) + 'nextpas.runtime.tstring.ll',
     IncludeTrailingPathDelimiter(RuntimeDir) + 'nextpas.runtime.lifecycle.ll',
     '-o', LinkedPath], 0);
  RunCommand(AStem + '-opt-verify', ToolPath('LLVM_OPT', 'opt'),
    ['-passes=verify', '-disable-output', LinkedPath], 0);
  RunCommand(AStem + '-llc', ToolPath('LLVM_LLC', 'llc'),
    ['-filetype=asm', '-o', AsmPath, LinkedPath], 0);
  RunCommand(AStem + '-link', ToolPath('CLANG', 'clang'),
    ['-nostartfiles', '-no-pie', '-lc', '-o', ExePath, AsmPath], 0);
  RunCommand(AStem + '-run', ExePath, [], 42);
end;

procedure EmitAssertAndRun(const AOutputDir, AStem, ASource: string;
  const AAssertKind: string);
var
  LlvmText: string;
  LlPath: string;
begin
  LlvmText := EmitLlvmFromSource(ASource);
  LlPath := IncludeTrailingPathDelimiter(AOutputDir) + AStem + '.ll';
  WriteTextFile(LlPath, LlvmText);

  if AAssertKind = 'direct' then
    AssertOwnedArgumentRuntimeContract(LlvmText, 'Take', 'MakeText')
  else if AAssertKind = 'nested' then
    AssertOwnedArgumentRuntimeContract(LlvmText, 'Wrap', 'MakeText')
  else if AAssertKind = 'multi' then
    RequireReverseReleaseOrder(LlvmText)
  else if AAssertKind = 'literal' then
    AssertLiteralBorrowedRuntimeContract(LlvmText)
  else if AAssertKind = 'writeln' then
    AssertWriteLnOwnedRuntimeContract(LlvmText)
  else if AAssertKind = 'writeln-concat' then
    AssertWriteLnConcatOwnedRuntimeContract(LlvmText)
  else if AAssertKind = 'concat' then
    AssertConcatOwnedRuntimeContract(LlvmText)
  else if AAssertKind = 'concat-both' then
    AssertConcatBothOwnedRuntimeContract(LlvmText)
  else if AAssertKind = 'compare' then
    AssertCompareOwnedRuntimeContract(LlvmText)
  else if AAssertKind = 'compare-both' then
    AssertCompareBothOwnedRuntimeContract(LlvmText)
  else if AAssertKind = 'compare-concat' then
    AssertCompareConcatOwnedRuntimeContract(LlvmText)
  else if AAssertKind = 'compare-compound' then
    AssertCompareCompoundOwnedRuntimeContract(LlvmText)
  else if AAssertKind = 'compare-loop' then
    AssertCompareLoopOwnedRuntimeContract(LlvmText)
  else
    Fail('unknown-assert-kind:' + AAssertKind);

  if AAssertKind <> 'multi' then
  begin
    RunRuntimeSmoke(AOutputDir, AStem);
    WriteLn('hir-string-call-argument-ownership-runtime-smoke-', AStem,
      '-exit=42');
  end
  else
    WriteLn('hir-string-call-argument-ownership-runtime-smoke-', AStem,
      '-verified=ir-only');
end;

var
  OutputDir: string;
begin
  if ParamCount >= 1 then
    OutputDir := ParamStr(1)
  else
    OutputDir := '/tmp/nextpas-c6h5-string-call-argument-runtime-smoke';
  if not ForceDirectories(OutputDir) then
    Fail('create-output-dir:' + OutputDir);

  EmitAssertAndRun(OutputDir, 'llvm_string_arg_owned_direct',
    DirectOwnedArgumentSource, 'direct');
  EmitAssertAndRun(OutputDir, 'llvm_string_arg_owned_nested',
    NestedOwnedArgumentSource, 'nested');
  EmitAssertAndRun(OutputDir, 'llvm_string_arg_owned_multi',
    MultiOwnedArgumentSource, 'multi');
  EmitAssertAndRun(OutputDir, 'llvm_string_arg_borrowed_literal',
    LiteralBorrowedArgumentSource, 'literal');
  EmitAssertAndRun(OutputDir, 'llvm_string_arg_owned_writeln',
    WriteLnOwnedArgumentSource, 'writeln');
  EmitAssertAndRun(OutputDir, 'llvm_string_arg_owned_writeln_concat',
    WriteLnConcatOwnedArgumentSource, 'writeln-concat');
  EmitAssertAndRun(OutputDir, 'llvm_string_arg_owned_concat_left',
    ConcatLeftOwnedArgumentSource, 'concat');
  EmitAssertAndRun(OutputDir, 'llvm_string_arg_owned_concat_right',
    ConcatRightOwnedArgumentSource, 'concat');
  EmitAssertAndRun(OutputDir, 'llvm_string_arg_owned_concat_both',
    ConcatBothOwnedArgumentSource, 'concat-both');
  EmitAssertAndRun(OutputDir, 'llvm_string_arg_owned_compare_left',
    CompareLeftOwnedArgumentSource, 'compare');
  EmitAssertAndRun(OutputDir, 'llvm_string_arg_owned_compare_right',
    CompareRightOwnedArgumentSource, 'compare');
  EmitAssertAndRun(OutputDir, 'llvm_string_arg_owned_compare_not_equal',
    CompareNotEqualOwnedArgumentSource, 'compare');
  EmitAssertAndRun(OutputDir, 'llvm_string_arg_owned_compare_runtime_var',
    CompareRuntimeVarOwnedArgumentSource, 'compare');
  EmitAssertAndRun(OutputDir, 'llvm_string_arg_owned_compare_both',
    CompareBothOwnedArgumentSource, 'compare-both');
  EmitAssertAndRun(OutputDir, 'llvm_string_arg_owned_compare_concat',
    CompareConcatOwnedArgumentSource, 'compare-concat');
  EmitAssertAndRun(OutputDir, 'llvm_string_arg_owned_compare_compound',
    CompareCompoundOwnedArgumentSource, 'compare-compound');
  EmitAssertAndRun(OutputDir, 'llvm_string_arg_owned_compare_while',
    CompareWhileOwnedArgumentSource, 'compare-loop');
  EmitAssertAndRun(OutputDir, 'llvm_string_arg_owned_compare_repeat',
    CompareRepeatOwnedArgumentSource, 'compare-loop');
  WriteLn('hir-string-call-argument-ownership-runtime-smoke-status=pass');
end.
