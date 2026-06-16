program test_hir_string_return_ownership_runtime_smoke;

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
  DirectConcatReturnSource =
    'program c6h4_string_return_runtime;' + LineEnding +
    'function MakeText: string;' + LineEnding +
    'var Suffix: string;' + LineEnding +
    'begin' + LineEnding +
    '  Suffix := ''-tail'';' + LineEnding +
    '  MakeText := ''head'' + Suffix;' + LineEnding +
    'end;' + LineEnding +
    'var S: string;' + LineEnding +
    'begin' + LineEnding +
    '  S := MakeText;' + LineEnding +
    '  if Length(S) = 9 then Halt(42);' + LineEnding +
    '  Halt(13);' + LineEnding +
    'end.';

  OverwriteAndFreeSource =
    'program c6h17_string_field_runtime;' + LineEnding +
    'type TStringPair = class' + LineEnding +
    '  Text: string;' + LineEnding +
    '  Note: string;' + LineEnding +
    '  Count: Integer;' + LineEnding +
    'end;' + LineEnding +
    'function MakeTextA: string;' + LineEnding +
    'begin' + LineEnding +
    '  MakeTextA := IntToStr(42);' + LineEnding +
    'end;' + LineEnding +
    'function MakeTextB: string;' + LineEnding +
    'var Suffix: string;' + LineEnding +
    'begin' + LineEnding +
    '  Suffix := ''!'';' + LineEnding +
    '  MakeTextB := ''note'' + Suffix;' + LineEnding +
    'end;' + LineEnding +
    'function MakeTextC: string;' + LineEnding +
    'begin' + LineEnding +
    '  MakeTextC := IntToStr(777);' + LineEnding +
    'end;' + LineEnding +
    'var Box: TStringPair;' + LineEnding +
    'begin' + LineEnding +
    '  Box := TStringPair.Create;' + LineEnding +
    '  Box.Text := MakeTextA();' + LineEnding +
    '  Box.Note := MakeTextB();' + LineEnding +
    '  Box.Text := MakeTextC();' + LineEnding +
    '  Box.Free;' + LineEnding +
    '  Halt(42);' + LineEnding +
    'end.';

procedure Fail(const AMessage: string);
begin
  WriteLn('hir-string-return-ownership-runtime-smoke-failure=', AMessage);
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
    Proc.Options := [poWaitOnExit];
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

function ExtractHelperSuffix(const ALlvmText: string): string;
var
  HelperStart: LongInt;
begin
  HelperStart := Pos('@__heap_cur = internal global ptr null', ALlvmText);
  if HelperStart = 0 then
    Fail('missing-runtime-helper-slice');
  Result := Copy(ALlvmText, HelperStart, MaxInt);
end;

function ModuleHeader(const AModuleName: string): string;
begin
  Result :=
    '; ModuleID = ''' + AModuleName + '''' + LineEnding +
    'target triple = "x86_64-unknown-linux-gnu"' + LineEnding +
    'target datalayout = "e-p:64:64:64-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:64:64"' +
    LineEnding + LineEnding;
end;

function ExitBlock(const ALabel: string; ACode: LongInt): string;
begin
  Result :=
    ALabel + ':' + LineEnding +
    '  call void asm sideeffect "movq $$60, %rax; syscall", "{rdi},~{rax},~{rcx},~{r11}"(i64 ' +
    IntToStr(ACode) + ')' + LineEnding +
    '  unreachable' + LineEnding;
end;

function BuildDirectObjectCleanupIr(const ACleanupHelper, AHelpers: string): string;
begin
  Result := ModuleHeader('c6h17-object-string-cleanup-runtime-smoke') +
    'define i64 @_start() {' + LineEnding +
    'entry:' + LineEnding +
    '  %obj = call ptr @np_object_alloc(i64 80)' + LineEnding +
    '  %text = call {ptr, i64, ptr, i64} @np_int_to_str_owned(i64 42)' + LineEnding +
    '  %text.ptr = extractvalue {ptr, i64, ptr, i64} %text, 0' + LineEnding +
    '  %text.len = extractvalue {ptr, i64, ptr, i64} %text, 1' + LineEnding +
    '  %text.owner = extractvalue {ptr, i64, ptr, i64} %text, 2' + LineEnding +
    '  %text.alloc = extractvalue {ptr, i64, ptr, i64} %text, 3' + LineEnding +
    '  %text.ptr.slot = getelementptr i64, ptr %obj, i64 1' + LineEnding +
    '  %text.len.slot = getelementptr i64, ptr %obj, i64 2' + LineEnding +
    '  %text.owner.slot = getelementptr i64, ptr %obj, i64 3' + LineEnding +
    '  %text.alloc.slot = getelementptr i64, ptr %obj, i64 4' + LineEnding +
    '  store ptr %text.ptr, ptr %text.ptr.slot' + LineEnding +
    '  store i64 %text.len, ptr %text.len.slot' + LineEnding +
    '  store ptr %text.owner, ptr %text.owner.slot' + LineEnding +
    '  store i64 %text.alloc, ptr %text.alloc.slot' + LineEnding +
    '  %note = call {ptr, i64, ptr, i64} @np_int_to_str_owned(i64 777)' + LineEnding +
    '  %note.ptr = extractvalue {ptr, i64, ptr, i64} %note, 0' + LineEnding +
    '  %note.len = extractvalue {ptr, i64, ptr, i64} %note, 1' + LineEnding +
    '  %note.owner = extractvalue {ptr, i64, ptr, i64} %note, 2' + LineEnding +
    '  %note.alloc = extractvalue {ptr, i64, ptr, i64} %note, 3' + LineEnding +
    '  %note.ptr.slot = getelementptr i64, ptr %obj, i64 5' + LineEnding +
    '  %note.len.slot = getelementptr i64, ptr %obj, i64 6' + LineEnding +
    '  %note.owner.slot = getelementptr i64, ptr %obj, i64 7' + LineEnding +
    '  %note.alloc.slot = getelementptr i64, ptr %obj, i64 8' + LineEnding +
    '  store ptr %note.ptr, ptr %note.ptr.slot' + LineEnding +
    '  store i64 %note.len, ptr %note.len.slot' + LineEnding +
    '  store ptr %note.owner, ptr %note.owner.slot' + LineEnding +
    '  store i64 %note.alloc, ptr %note.alloc.slot' + LineEnding +
    '  call void @np_object_string_cleanup_TStringPair(ptr %obj)' + LineEnding +
    '  %text.ptr.after = load ptr, ptr %text.ptr.slot' + LineEnding +
    '  %text.ptr.null = icmp eq ptr %text.ptr.after, null' + LineEnding +
    '  br i1 %text.ptr.null, label %check.text.len, label %fail.text.ptr' + LineEnding +
    'check.text.len:' + LineEnding +
    '  %text.len.after = load i64, ptr %text.len.slot' + LineEnding +
    '  %text.len.zero = icmp eq i64 %text.len.after, 0' + LineEnding +
    '  br i1 %text.len.zero, label %check.text.owner, label %fail.text.len' + LineEnding +
    'check.text.owner:' + LineEnding +
    '  %text.owner.after = load ptr, ptr %text.owner.slot' + LineEnding +
    '  %text.owner.null = icmp eq ptr %text.owner.after, null' + LineEnding +
    '  br i1 %text.owner.null, label %check.text.alloc, label %fail.text.owner' + LineEnding +
    'check.text.alloc:' + LineEnding +
    '  %text.alloc.after = load i64, ptr %text.alloc.slot' + LineEnding +
    '  %text.alloc.zero = icmp eq i64 %text.alloc.after, 0' + LineEnding +
    '  br i1 %text.alloc.zero, label %check.note.ptr, label %fail.text.alloc' + LineEnding +
    'check.note.ptr:' + LineEnding +
    '  %note.ptr.after = load ptr, ptr %note.ptr.slot' + LineEnding +
    '  %note.ptr.null = icmp eq ptr %note.ptr.after, null' + LineEnding +
    '  br i1 %note.ptr.null, label %check.note.len, label %fail.note.ptr' + LineEnding +
    'check.note.len:' + LineEnding +
    '  %note.len.after = load i64, ptr %note.len.slot' + LineEnding +
    '  %note.len.zero = icmp eq i64 %note.len.after, 0' + LineEnding +
    '  br i1 %note.len.zero, label %check.note.owner, label %fail.note.len' + LineEnding +
    'check.note.owner:' + LineEnding +
    '  %note.owner.after = load ptr, ptr %note.owner.slot' + LineEnding +
    '  %note.owner.null = icmp eq ptr %note.owner.after, null' + LineEnding +
    '  br i1 %note.owner.null, label %check.note.alloc, label %fail.note.owner' + LineEnding +
    'check.note.alloc:' + LineEnding +
    '  %note.alloc.after = load i64, ptr %note.alloc.slot' + LineEnding +
    '  %note.alloc.zero = icmp eq i64 %note.alloc.after, 0' + LineEnding +
    '  br i1 %note.alloc.zero, label %release, label %fail.note.alloc' + LineEnding +
    'release:' + LineEnding +
    '  call void @np_object_free_release(ptr %obj)' + LineEnding +
    '  br label %pass' + LineEnding +
    ExitBlock('pass', 42) +
    ExitBlock('fail.text.ptr', 21) +
    ExitBlock('fail.text.len', 22) +
    ExitBlock('fail.text.owner', 23) +
    ExitBlock('fail.text.alloc', 24) +
    ExitBlock('fail.note.ptr', 25) +
    ExitBlock('fail.note.len', 26) +
    ExitBlock('fail.note.owner', 27) +
    ExitBlock('fail.note.alloc', 28) +
    '}' + LineEnding + LineEnding +
    ACleanupHelper + LineEnding + LineEnding +
    AHelpers;
end;

function RuntimeMethodStubs: string;
begin
  Result :=
    'define i64 @TObject.Create(ptr %self) {' + LineEnding +
    'entry:' + LineEnding +
    '  ret i64 0' + LineEnding +
    '}' + LineEnding + LineEnding +
    'define i64 @TStringPair.Destroy(ptr %self) {' + LineEnding +
    'entry:' + LineEnding +
    '  ret i64 0' + LineEnding +
    '}' + LineEnding + LineEnding;
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

procedure AssertDirectOwnedReturnRuntimeContract(const ALlvmText: string);
begin
  RequireContains(ALlvmText, 'define {ptr, i64, ptr, i64} @MakeText(',
    'missing-owned-string-return-runtime');
  RejectContains(ALlvmText, 'define {ptr, i64} @MakeText(',
    'legacy-visible-string-return-runtime-must-not-remain');
  RequireContains(ALlvmText, ' = call {ptr, i64, ptr, i64} @MakeText(',
    'missing-owned-string-return-call-runtime');
  RequireContains(ALlvmText, 'extractvalue {ptr, i64, ptr, i64}',
    'missing-owned-string-return-extract-runtime');
  RequireContains(ALlvmText, 'MakeText$owner',
    'missing-owned-string-result-owner-runtime');
  RequireContains(ALlvmText, 'MakeText$alloc_size',
    'missing-owned-string-result-alloc-size-runtime');
  RequireContains(ALlvmText, 'S$owner',
    'missing-owned-string-destination-owner-runtime');
  RequireContains(ALlvmText, 'call void @np_string_release(',
    'return-owned-string-release-missing');
  RejectContains(ALlvmText, '@np_object_string_cleanup',
    'string-field-cleanup-must-remain-deferred');
end;

procedure AssertOverwriteAndFreeRuntimeContract(const ALlvmText: string);
var
  StartSlice, CleanupSlice: string;
  SecondCallPos, ReleasePos, CleanupCallPos, FreeReleasePos: LongInt;
begin
  RequireContains(ALlvmText,
    'define internal void @np_object_string_cleanup_TStringPair(ptr %',
    'missing-string-pair-cleanup-helper');
  StartSlice := ExtractDefinitionSlice(ALlvmText, 'define i64 @_start() {');
  if StartSlice = '' then
    Fail('missing-overwrite-start-slice');
  SecondCallPos := FindAfter(' = call {ptr, i64, ptr, i64} @MakeTextC(',
    StartSlice, 1);
  if SecondCallPos = 0 then
    Fail('missing-overwrite-third-maketext-call');
  ReleasePos := FindAfter('call void @np_string_release(', StartSlice,
    SecondCallPos);
  if ReleasePos = 0 then
    Fail('missing-overwrite-old-owner-release');
  CleanupCallPos := FindAfter('call void @np_object_string_cleanup_TStringPair(ptr ',
    StartSlice, ReleasePos);
  if CleanupCallPos = 0 then
    Fail('missing-overwrite-cleanup-call');
  FreeReleasePos := FindAfter('call void @np_object_free_release(ptr ',
    StartSlice, CleanupCallPos);
  if FreeReleasePos = 0 then
    Fail('missing-overwrite-heap-release-call');
  if not ((SecondCallPos < ReleasePos) and (ReleasePos < CleanupCallPos) and
    (CleanupCallPos < FreeReleasePos)) then
    Fail('overwrite-release-cleanup-order');

  CleanupSlice := ExtractDefinitionSlice(ALlvmText,
    'define internal void @np_object_string_cleanup_TStringPair(ptr %');
  if CleanupSlice = '' then
    Fail('missing-string-pair-cleanup-slice');
  if CountSubstring(CleanupSlice, 'call void @np_string_release(') <> 2 then
    Fail('cleanup-helper-must-release-both-string-field-owners');
  RequireContains(CleanupSlice, 'add i64 7, 0',
    'missing-note-owner-slot-cleanup');
  RequireContains(CleanupSlice, 'add i64 3, 0',
    'missing-text-owner-slot-cleanup');
end;

var
  OutputDir: string;
  LlvmText: string;
  LlPath: string;
  OverwriteLlvmText: string;
  OverwriteRuntimeLlvmText: string;
  OverwriteLlPath: string;
  DirectCleanupIr: string;
  DirectCleanupPath: string;
  RuntimeHelpers: string;
  CleanupHelper: string;
begin
  if ParamCount >= 1 then
    OutputDir := ParamStr(1)
  else
    OutputDir := '/tmp/nextpas-c6h17-string-return-ownership-runtime-smoke';
  if not ForceDirectories(OutputDir) then
    Fail('create-output-dir:' + OutputDir);

  LlvmText := EmitLlvmFromSource(DirectConcatReturnSource);
  LlPath := IncludeTrailingPathDelimiter(OutputDir) +
    'llvm_string_return_owned_direct.ll';
  WriteTextFile(LlPath, LlvmText);

  AssertDirectOwnedReturnRuntimeContract(LlvmText);
  RunRuntimeSmoke(OutputDir, 'llvm_string_return_owned_direct');
  WriteLn('hir-string-return-ownership-runtime-smoke-direct-exit=42');

  OverwriteLlvmText := EmitLlvmFromSource(OverwriteAndFreeSource);
  OverwriteRuntimeLlvmText := OverwriteLlvmText + RuntimeMethodStubs;
  OverwriteLlPath := IncludeTrailingPathDelimiter(OutputDir) +
    'llvm_string_field_owned_overwrite.ll';
  WriteTextFile(OverwriteLlPath, OverwriteRuntimeLlvmText);
  AssertOverwriteAndFreeRuntimeContract(OverwriteLlvmText);
  RunRuntimeSmoke(OutputDir, 'llvm_string_field_owned_overwrite');
  WriteLn('hir-string-return-ownership-runtime-smoke-overwrite-free-exit=42');

  RuntimeHelpers := ExtractHelperSuffix(OverwriteLlvmText);
  CleanupHelper := ExtractDefinitionSlice(OverwriteLlvmText,
    'define internal void @np_object_string_cleanup_TStringPair(ptr %');
  if CleanupHelper = '' then
    Fail('missing-direct-runtime-cleanup-helper-source');
  DirectCleanupIr := BuildDirectObjectCleanupIr(CleanupHelper, RuntimeHelpers);
  DirectCleanupPath := IncludeTrailingPathDelimiter(OutputDir) +
    'llvm_string_field_cleanup_direct.ll';
  WriteTextFile(DirectCleanupPath, DirectCleanupIr);
  RunRuntimeSmoke(OutputDir, 'llvm_string_field_cleanup_direct');
  WriteLn('hir-string-return-ownership-runtime-smoke-direct-cleanup-exit=42');

  WriteLn('hir-string-return-ownership-runtime-smoke-status=pass');
end.
