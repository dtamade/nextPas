program test_hir_string_call_argument_ownership_runtime_smoke;

{$mode objfpc}{$H+}

uses
  Classes, Process, SysUtils,
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
  DirectOwnedArgumentSource =
    'program c6h5_direct_string_arg_runtime;' + LineEnding +
    'function MakeText: string;' + LineEnding +
    'var Suffix: string;' + LineEnding +
    'begin' + LineEnding +
    '  Suffix := ''tail'';' + LineEnding +
    '  MakeText := ''head'' + Suffix;' + LineEnding +
    'end;' + LineEnding +
    'procedure Take(P: string);' + LineEnding +
    'begin' + LineEnding +
    '  if Length(P) = 8 then Halt(42);' + LineEnding +
    '  Halt(13);' + LineEnding +
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
    '  Wrap := P + ''!'';' + LineEnding +
    'end;' + LineEnding +
    'var S: string;' + LineEnding +
    'begin' + LineEnding +
    '  S := Wrap(MakeText());' + LineEnding +
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
    '  if Length(A) + Length(B) = 3 then Halt(42);' + LineEnding +
    '  Halt(23);' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    '  Take2(MakeA(), MakeB());' + LineEnding +
    '  Halt(11);' + LineEnding +
    'end.';

  LiteralBorrowedArgumentSource =
    'program c6h5_literal_string_arg_runtime;' + LineEnding +
    'procedure Take(P: string);' + LineEnding +
    'begin' + LineEnding +
    '  if Length(P) = 7 then Halt(42);' + LineEnding +
    '  Halt(19);' + LineEnding +
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

  ConcatLeftOwnedArgumentSource =
    'program c6h9_concat_left_string_arg_runtime;' + LineEnding +
    'function MakeText: string;' + LineEnding +
    'begin' + LineEnding +
    '  MakeText := ''left'';' + LineEnding +
    'end;' + LineEnding +
    'var S: string;' + LineEnding +
    'begin' + LineEnding +
    '  S := MakeText() + ''x'';' + LineEnding +
    '  if Length(S) = 5 then Halt(42);' + LineEnding +
    '  Halt(29);' + LineEnding +
    'end.';

  ConcatRightOwnedArgumentSource =
    'program c6h9_concat_right_string_arg_runtime;' + LineEnding +
    'function MakeText: string;' + LineEnding +
    'begin' + LineEnding +
    '  MakeText := ''right'';' + LineEnding +
    'end;' + LineEnding +
    'var S: string;' + LineEnding +
    'begin' + LineEnding +
    '  S := ''x'' + MakeText();' + LineEnding +
    '  if Length(S) = 6 then Halt(42);' + LineEnding +
    '  Halt(31);' + LineEnding +
    'end.';

  ConcatBothOwnedArgumentSource =
    'program c6h9_concat_both_string_arg_runtime;' + LineEnding +
    'function MakeA: string;' + LineEnding +
    'begin' + LineEnding +
    '  MakeA := ''left'';' + LineEnding +
    'end;' + LineEnding +
    'function MakeB: string;' + LineEnding +
    'begin' + LineEnding +
    '  MakeB := ''right'';' + LineEnding +
    'end;' + LineEnding +
    'var S: string;' + LineEnding +
    'begin' + LineEnding +
    '  S := MakeA() + MakeB();' + LineEnding +
    '  if Length(S) = 9 then Halt(42);' + LineEnding +
    '  Halt(37);' + LineEnding +
    'end.';

  CompareLeftOwnedArgumentSource =
    'program c6h10_compare_left_string_arg_runtime;' + LineEnding +
    'function MakeText: string;' + LineEnding +
    'begin' + LineEnding +
    '  MakeText := ''x'';' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    '  if MakeText() = ''x'' then Halt(42);' + LineEnding +
    '  Halt(39);' + LineEnding +
    'end.';

  CompareRightOwnedArgumentSource =
    'program c6h10_compare_right_string_arg_runtime;' + LineEnding +
    'function MakeText: string;' + LineEnding +
    'begin' + LineEnding +
    '  MakeText := ''x'';' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    '  if ''x'' = MakeText() then Halt(42);' + LineEnding +
    '  Halt(41);' + LineEnding +
    'end.';

  CompareNotEqualOwnedArgumentSource =
    'program c6h10_compare_not_equal_string_arg_runtime;' + LineEnding +
    'function MakeText: string;' + LineEnding +
    'begin' + LineEnding +
    '  MakeText := ''x'';' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    '  if MakeText() <> ''y'' then Halt(42);' + LineEnding +
    '  Halt(43);' + LineEnding +
    'end.';

  CompareRuntimeVarOwnedArgumentSource =
    'program c6h10_compare_runtime_var_string_arg_runtime;' + LineEnding +
    'function MakeText: string;' + LineEnding +
    'begin' + LineEnding +
    '  MakeText := ''x'';' + LineEnding +
    'end;' + LineEnding +
    'var S: string;' + LineEnding +
    'begin' + LineEnding +
    '  S := ''x'';' + LineEnding +
    '  if MakeText() = S then Halt(42);' + LineEnding +
    '  Halt(45);' + LineEnding +
    'end.';

  CompareBothOwnedArgumentSource =
    'program c6h11_compare_both_string_arg_runtime;' + LineEnding +
    'function MakeA: string;' + LineEnding +
    'begin' + LineEnding +
    '  MakeA := ''x'';' + LineEnding +
    'end;' + LineEnding +
    'function MakeB: string;' + LineEnding +
    'begin' + LineEnding +
    '  MakeB := ''x'';' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    '  if MakeA() = MakeB() then Halt(42);' + LineEnding +
    '  Halt(47);' + LineEnding +
    'end.';

  CompareConcatOwnedArgumentSource =
    'program c6h12_compare_concat_string_arg_runtime;' + LineEnding +
    'function MakeText: string;' + LineEnding +
    'begin' + LineEnding +
    '  MakeText := ''x'';' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    '  if MakeText() + ''y'' = ''xy'' then Halt(42);' + LineEnding +
    '  Halt(49);' + LineEnding +
    'end.';

  CompareCompoundOwnedArgumentSource =
    'program c6h13_compare_compound_string_arg_runtime;' + LineEnding +
    'function MakeText: string;' + LineEnding +
    'begin' + LineEnding +
    '  MakeText := ''x'';' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    '  if (MakeText() = ''x'') and True then Halt(42);' + LineEnding +
    '  Halt(51);' + LineEnding +
    'end.';

procedure Fail(const AMessage: string);
begin
  WriteLn('hir-string-call-argument-ownership-runtime-smoke-failure=', AMessage);
  Halt(1);
end;

procedure WriteTextFile(const APath, AText: string);
var
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  try
    Lines.Text := AText;
    Lines.SaveToFile(APath);
  finally
    Lines.Free;
  end;
end;

function ToolPath(const AEnvName, ADefaultValue: string): string;
begin
  Result := GetEnvironmentVariable(AEnvName);
  if Result = '' then
    Result := ADefaultValue;
end;

procedure RunCommand(const ALabel, AExecutable: string;
  const AArgs: array of string; AExpectedExit: LongInt);
var
  Proc: TProcess;
  I: LongInt;
begin
  Proc := TProcess.Create(nil);
  try
    Proc.Executable := AExecutable;
    for I := Low(AArgs) to High(AArgs) do
      Proc.Parameters.Add(AArgs[I]);
    Proc.Options := [poWaitOnExit, poUsePipes];
    Proc.Execute;
    if Proc.ExitStatus <> AExpectedExit then
      Fail(ALabel + '-exit:' + IntToStr(Proc.ExitStatus) +
        '-expected:' + IntToStr(AExpectedExit));
  finally
    Proc.Free;
  end;
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

procedure RequireReverseReleaseOrder(const ALlvmText: string);
var
  MakeAPos, MakeBPos, CallPos, ReleaseBPos, ReleaseAPos: LongInt;
begin
  MakeAPos := Pos(' = call {ptr, i64, ptr, i64} @MakeA(', ALlvmText);
  MakeBPos := Pos(' = call {ptr, i64, ptr, i64} @MakeB(', ALlvmText);
  CallPos := Pos('call i64 @Take2(', ALlvmText);
  if (MakeAPos = 0) or (MakeBPos = 0) or (CallPos = 0) then
    Fail('missing-multi-owned-string-return-runtime');
  if (MakeAPos >= MakeBPos) or (MakeBPos >= CallPos) then
    Fail('owned-string-temp-creation-order-runtime');
  ReleaseBPos := FindAfter(ALlvmText, 'call void @np_string_release(',
    CallPos);
  ReleaseAPos := FindAfter(ALlvmText, 'call void @np_string_release(',
    ReleaseBPos + 1);
  if (ReleaseBPos = 0) or (ReleaseAPos = 0) then
    Fail('missing-multi-owned-string-temp-release-runtime');
  if ReleaseBPos >= ReleaseAPos then
    Fail('owned-string-temp-release-order-runtime');
end;

procedure AssertOwnedArgumentRuntimeContract(const ALlvmText,
  ACalleeName, AProducerName: string);
var
  CalleeCallNeedle: string;
begin
  RequireContains(ALlvmText,
    ' = call {ptr, i64, ptr, i64} @' + AProducerName + '(',
    'missing-owned-string-return-runtime');
  RequireContains(ALlvmText, 'extractvalue {ptr, i64, ptr, i64}',
    'missing-owned-string-return-extract-runtime');
  CalleeCallNeedle := 'call i64 @' + ACalleeName + '(ptr ';
  if Pos(CalleeCallNeedle, ALlvmText) = 0 then
    CalleeCallNeedle := 'call {ptr, i64, ptr, i64} @' + ACalleeName + '(ptr ';
  RequireContains(ALlvmText, CalleeCallNeedle,
    'missing-borrowed-string-argument-runtime');
  RejectContains(ALlvmText, 'call i64 @' + ACalleeName + '(ptr %owner',
    'borrowed-string-argument-must-not-pass-owner-runtime');
  RequireOrder(ALlvmText, CalleeCallNeedle,
    'call void @np_string_release(',
    'string-temp-release-must-follow-enclosing-call-runtime');
end;

procedure AssertLiteralBorrowedRuntimeContract(const ALlvmText: string);
begin
  RequireContains(ALlvmText, '@.str.',
    'missing-literal-borrowed-string-constant-runtime');
  RequireContains(ALlvmText, 'call i64 @Take(ptr ',
    'missing-literal-borrowed-string-argument-runtime');
  RejectContains(ALlvmText, 'call void @np_string_release(',
    'literal-borrowed-argument-must-not-release-runtime');
end;

procedure AssertWriteLnOwnedRuntimeContract(const ALlvmText: string);
var
  ProducerPos, WritePos, ReleasePos: LongInt;
begin
  ProducerPos := Pos(' = call {ptr, i64, ptr, i64} @MakeText(', ALlvmText);
  WritePos := Pos('call void asm sideeffect "movq $$1, %rax; syscall"',
    ALlvmText);
  if (ProducerPos = 0) or (WritePos = 0) then
    Fail('missing-writeln-owned-string-write-runtime');
  ReleasePos := FindAfter(ALlvmText, 'call void @np_string_release(',
    WritePos + 1);
  if ReleasePos = 0 then
    Fail('missing-writeln-owned-string-release-runtime');
  if (ProducerPos >= WritePos) or (WritePos >= ReleasePos) then
    Fail('writeln-owned-string-temp-release-order-runtime');
end;

procedure AssertConcatOwnedRuntimeContract(const ALlvmText: string);
var
  ProducerPos, ConcatPos, ReleasePos: LongInt;
begin
  ProducerPos := Pos(' = call {ptr, i64, ptr, i64} @MakeText(', ALlvmText);
  ConcatPos := Pos(' = call {ptr, i64, ptr, i64} @np_str_concat_owned(',
    ALlvmText);
  if (ProducerPos = 0) or (ConcatPos = 0) then
    Fail('missing-concat-owned-string-runtime');
  ReleasePos := FindAfter(ALlvmText, 'call void @np_string_release(',
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
  MakeAPos := Pos(' = call {ptr, i64, ptr, i64} @MakeA(', ALlvmText);
  MakeBPos := Pos(' = call {ptr, i64, ptr, i64} @MakeB(', ALlvmText);
  ConcatPos := Pos(' = call {ptr, i64, ptr, i64} @np_str_concat_owned(',
    ALlvmText);
  if (MakeAPos = 0) or (MakeBPos = 0) or (ConcatPos = 0) then
    Fail('missing-concat-both-owned-string-runtime');
  ReleaseBPos := FindAfter(ALlvmText, 'call void @np_string_release(',
    ConcatPos + 1);
  ReleaseAPos := FindAfter(ALlvmText, 'call void @np_string_release(',
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
  ProducerPos := Pos(' = call {ptr, i64, ptr, i64} @MakeText(', ALlvmText);
  ComparePos := Pos(' = call i64 @np_str_cmp(', ALlvmText);
  if (ProducerPos = 0) or (ComparePos = 0) then
    Fail('missing-compare-owned-string-runtime');
  ReleasePos := FindAfter(ALlvmText, 'call void @np_string_release(',
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
  MakeAPos := Pos(' = call {ptr, i64, ptr, i64} @MakeA(', ALlvmText);
  MakeBPos := Pos(' = call {ptr, i64, ptr, i64} @MakeB(', ALlvmText);
  ComparePos := Pos(' = call i64 @np_str_cmp(', ALlvmText);
  if (MakeAPos = 0) or (MakeBPos = 0) or (ComparePos = 0) then
    Fail('missing-compare-both-owned-string-runtime');
  ReleaseBPos := FindAfter(ALlvmText, 'call void @np_string_release(',
    ComparePos + 1);
  ReleaseAPos := FindAfter(ALlvmText, 'call void @np_string_release(',
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
  ProducerPos := Pos(' = call {ptr, i64, ptr, i64} @MakeText(', ALlvmText);
  ConcatPos := Pos(' = call {ptr, i64, ptr, i64} @np_str_concat_owned(',
    ALlvmText);
  ComparePos := Pos(' = call i64 @np_str_cmp(', ALlvmText);
  if (ProducerPos = 0) or (ConcatPos = 0) or (ComparePos = 0) then
    Fail('missing-compare-concat-owned-string-runtime');
  ConcatReleasePos := FindAfter(ALlvmText, 'call void @np_string_release(',
    ComparePos + 1);
  SourceReleasePos := FindAfter(ALlvmText, 'call void @np_string_release(',
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
  ProducerPos := Pos(' = call {ptr, i64, ptr, i64} @MakeText(', ALlvmText);
  ComparePos := Pos(' = call i64 @np_str_cmp(', ALlvmText);
  ReleasePos := FindAfter(ALlvmText, 'call void @np_string_release(',
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

procedure RunRuntimeSmoke(const AOutputDir, AStem: string);
var
  LlPath: string;
  AsmPath: string;
  ExePath: string;
begin
  LlPath := IncludeTrailingPathDelimiter(AOutputDir) + AStem + '.ll';
  AsmPath := IncludeTrailingPathDelimiter(AOutputDir) + AStem + '.s';
  ExePath := IncludeTrailingPathDelimiter(AOutputDir) + AStem;

  RunCommand(AStem + '-opt-verify', ToolPath('LLVM_OPT', 'opt'),
    ['-passes=verify', '-disable-output', LlPath], 0);
  RunCommand(AStem + '-llc', ToolPath('LLVM_LLC', 'llc'),
    ['-filetype=asm', '-o', AsmPath, LlPath], 0);
  RunCommand(AStem + '-link', ToolPath('CLANG', 'clang'),
    ['-nostdlib', '-no-pie', '-o', ExePath, AsmPath], 0);
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
  else
    Fail('unknown-assert-kind:' + AAssertKind);

  RunRuntimeSmoke(AOutputDir, AStem);
  WriteLn('hir-string-call-argument-ownership-runtime-smoke-', AStem,
    '-exit=42');
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
  WriteLn('hir-string-call-argument-ownership-runtime-smoke-status=pass');
end.
