program test_hir_string_ownership_runtime_smoke;

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
  OwnedConcatSource =
    'program string_concat_owned;' + LineEnding +
    'var A, B: string;' + LineEnding +
    'begin' + LineEnding +
    '  B := ''-tail'';' + LineEnding +
    '  A := ''head'' + B;' + LineEnding +
    '  A := ''again'' + B;' + LineEnding +
    '  Halt(42);' + LineEnding +
    'end.';

  IntToStrSource =
    'program string_int_to_str_owned;' + LineEnding +
    'var S: string;' + LineEnding +
    'begin' + LineEnding +
    '  S := IntToStr(42);' + LineEnding +
    '  Halt(42);' + LineEnding +
    'end.';

procedure Fail(const AMessage: string);
begin
  WriteLn('hir-string-ownership-runtime-smoke-failure=', AMessage);
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

function ExtractHelperSuffix(const ALlvmText: string): string;
var
  HelperStart: LongInt;
begin
  HelperStart := Pos('@__heap_cur = internal global ptr null', ALlvmText);
  if HelperStart = 0 then
    Fail('missing-runtime-helper-slice');
  Result := Copy(ALlvmText, HelperStart, MaxInt);
end;

function ModuleHeader: string;
begin
  Result :=
    '; ModuleID = ''c6h3-string-ownership-runtime-smoke''' + LineEnding +
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

function DirectOwnedHelperIr(const AHelpers: string): string;
begin
  Result := ModuleHeader +
    '@left = private constant [4 x i8] c"left"' + LineEnding +
    '@right = private constant [5 x i8] c"right"' + LineEnding +
    '@big = private constant [65536 x i8] zeroinitializer' + LineEnding +
    LineEnding +
    'define i64 @_start() {' + LineEnding +
    'entry:' + LineEnding +
    '  %cat = call {ptr, i64, ptr, i64} @np_str_concat_owned(ptr @left, i64 4, ptr @right, i64 5)' + LineEnding +
    '  %cat.ptr = extractvalue {ptr, i64, ptr, i64} %cat, 0' + LineEnding +
    '  %cat.len = extractvalue {ptr, i64, ptr, i64} %cat, 1' + LineEnding +
    '  %cat.owner = extractvalue {ptr, i64, ptr, i64} %cat, 2' + LineEnding +
    '  %cat.alloc = extractvalue {ptr, i64, ptr, i64} %cat, 3' + LineEnding +
    '  %cat.len.ok = icmp eq i64 %cat.len, 9' + LineEnding +
    '  br i1 %cat.len.ok, label %cat.first, label %fail' + LineEnding +
    'cat.first:' + LineEnding +
    '  %first = load i8, ptr %cat.ptr' + LineEnding +
    '  %first.ok = icmp eq i8 %first, 108' + LineEnding +
    '  br i1 %first.ok, label %cat.last, label %fail' + LineEnding +
    'cat.last:' + LineEnding +
    '  %lastp = getelementptr i8, ptr %cat.ptr, i64 8' + LineEnding +
    '  %last = load i8, ptr %lastp' + LineEnding +
    '  %last.ok = icmp eq i8 %last, 116' + LineEnding +
    '  br i1 %last.ok, label %release.cat, label %fail' + LineEnding +
    'release.cat:' + LineEnding +
    '  call void @np_string_release(ptr %cat.owner, i64 %cat.alloc)' + LineEnding +
    '  br label %int.to.str' + LineEnding +
    'int.to.str:' + LineEnding +
    '  %its = call {ptr, i64, ptr, i64} @np_int_to_str_owned(i64 42)' + LineEnding +
    '  %its.ptr = extractvalue {ptr, i64, ptr, i64} %its, 0' + LineEnding +
    '  %its.len = extractvalue {ptr, i64, ptr, i64} %its, 1' + LineEnding +
    '  %its.owner = extractvalue {ptr, i64, ptr, i64} %its, 2' + LineEnding +
    '  %its.alloc = extractvalue {ptr, i64, ptr, i64} %its, 3' + LineEnding +
    '  %its.len.ok = icmp eq i64 %its.len, 2' + LineEnding +
    '  br i1 %its.len.ok, label %its.first, label %fail' + LineEnding +
    'its.first:' + LineEnding +
    '  %d0 = load i8, ptr %its.ptr' + LineEnding +
    '  %d0.ok = icmp eq i8 %d0, 52' + LineEnding +
    '  br i1 %d0.ok, label %its.second, label %fail' + LineEnding +
    'its.second:' + LineEnding +
    '  %d1p = getelementptr i8, ptr %its.ptr, i64 1' + LineEnding +
    '  %d1 = load i8, ptr %d1p' + LineEnding +
    '  %d1.ok = icmp eq i8 %d1, 50' + LineEnding +
    '  br i1 %d1.ok, label %its.owner.check, label %fail' + LineEnding +
    'its.owner.check:' + LineEnding +
    '  %same.visible.owner = icmp eq ptr %its.ptr, %its.owner' + LineEnding +
    '  br i1 %same.visible.owner, label %fail, label %release.its' + LineEnding +
    'release.its:' + LineEnding +
    '  call void @np_string_release(ptr %its.owner, i64 %its.alloc)' + LineEnding +
    '  br label %large' + LineEnding +
    'large:' + LineEnding +
    '  %large.cat = call {ptr, i64, ptr, i64} @np_str_concat_owned(ptr @big, i64 65536, ptr @right, i64 5)' + LineEnding +
    '  %large.ptr = extractvalue {ptr, i64, ptr, i64} %large.cat, 0' + LineEnding +
    '  %large.len = extractvalue {ptr, i64, ptr, i64} %large.cat, 1' + LineEnding +
    '  %large.owner = extractvalue {ptr, i64, ptr, i64} %large.cat, 2' + LineEnding +
    '  %large.alloc = extractvalue {ptr, i64, ptr, i64} %large.cat, 3' + LineEnding +
    '  %large.len.ok = icmp eq i64 %large.len, 65541' + LineEnding +
    '  br i1 %large.len.ok, label %large.last, label %fail' + LineEnding +
    'large.last:' + LineEnding +
    '  %large.lastp = getelementptr i8, ptr %large.ptr, i64 65540' + LineEnding +
    '  %large.last.byte = load i8, ptr %large.lastp' + LineEnding +
    '  %large.last.ok = icmp eq i8 %large.last.byte, 116' + LineEnding +
    '  br i1 %large.last.ok, label %release.large, label %fail' + LineEnding +
    'release.large:' + LineEnding +
    '  call void @np_string_release(ptr %large.owner, i64 %large.alloc)' + LineEnding +
    '  call void @np_string_release(ptr null, i64 0)' + LineEnding +
    '  br label %pass' + LineEnding +
    ExitBlock('pass', 42) +
    ExitBlock('fail', 13) +
    '}' + LineEnding + LineEnding +
    AHelpers;
end;

procedure AssertGeneratedContracts(const AConcatLlvm, AIntToStrLlvm,
  ADirectIr: string);
var
  ReleasePos, HaltPos: LongInt;
begin
  if Pos('call {ptr, i64, ptr, i64} @np_str_concat_owned(',
    AConcatLlvm) = 0 then
    Fail('missing-generated-owned-concat-call');
  if Pos('call {ptr, i64, ptr, i64} @np_int_to_str_owned(',
    AIntToStrLlvm) = 0 then
    Fail('missing-generated-owned-int-to-str-call');
  if Pos('call void @np_string_release(', AConcatLlvm) = 0 then
    Fail('missing-generated-string-release-call');
  if Pos('define internal void @np_string_release(', AConcatLlvm) = 0 then
    Fail('missing-string-release-helper');
  if Pos('define internal void @np_string_fault(', AConcatLlvm) = 0 then
    Fail('missing-string-fault-helper');
  if Pos('call void @np_free(ptr %concat.', AConcatLlvm) <> 0 then
    Fail('generated-string-path-must-not-free-visible-concat-ptr');
  if Pos('call {ptr, i64, ptr, i64} @np_str_concat_owned(ptr @big, i64 65536',
    ADirectIr) = 0 then
    Fail('missing-direct-large-owned-concat-call');
  if Pos('call void @np_string_release(ptr null, i64 0)', ADirectIr) = 0 then
    Fail('missing-direct-null-release-call');

  ReleasePos := Pos('call void @np_string_release(', AConcatLlvm);
  HaltPos := FindAfter('movq $$60, %rax; syscall', AConcatLlvm, ReleasePos);
  if (ReleasePos = 0) or (HaltPos = 0) or (ReleasePos > HaltPos) then
    Fail('generated-cleanup-must-precede-halt');
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

var
  OutputDir: string;
  ConcatLlvm: string;
  IntToStrLlvm: string;
  DirectIr: string;
  Helpers: string;
begin
  if ParamCount >= 1 then
    OutputDir := ParamStr(1)
  else
    OutputDir := '/tmp/nextpas-c6h3-string-ownership-runtime-smoke';
  if not ForceDirectories(OutputDir) then
    Fail('create-output-dir:' + OutputDir);

  ConcatLlvm := EmitLlvmFromSource(OwnedConcatSource);
  IntToStrLlvm := EmitLlvmFromSource(IntToStrSource);
  Helpers := ExtractHelperSuffix(ConcatLlvm);
  DirectIr := DirectOwnedHelperIr(Helpers);

  WriteTextFile(IncludeTrailingPathDelimiter(OutputDir) +
    'llvm_string_owned_concat.ll', ConcatLlvm);
  WriteTextFile(IncludeTrailingPathDelimiter(OutputDir) +
    'llvm_string_int_to_str.ll', IntToStrLlvm);
  WriteTextFile(IncludeTrailingPathDelimiter(OutputDir) +
    'llvm_string_owned_helpers_direct.ll', DirectIr);

  AssertGeneratedContracts(ConcatLlvm, IntToStrLlvm, DirectIr);

  WriteLn('hir-string-ownership-runtime-smoke-output-dir=', OutputDir);
  RunRuntimeSmoke(OutputDir, 'llvm_string_owned_concat');
  WriteLn('hir-string-ownership-runtime-smoke-owned-concat-exit=42');
  RunRuntimeSmoke(OutputDir, 'llvm_string_int_to_str');
  WriteLn('hir-string-ownership-runtime-smoke-int-to-str-exit=42');
  RunRuntimeSmoke(OutputDir, 'llvm_string_owned_helpers_direct');
  WriteLn('hir-string-ownership-runtime-smoke-direct-owned-helpers-exit=42');
  WriteLn('hir-string-ownership-runtime-smoke-status=pass');
end.
