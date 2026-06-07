program test_hir_dynarray_release_runtime_smoke;

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
  ResizeSource =
    'program dynarray_resize;' + LineEnding +
    'var A: array of Integer; I: Integer;' + LineEnding +
    'begin' + LineEnding +
    '  SetLength(A, 4);' + LineEnding +
    '  A[0] := 17;' + LineEnding +
    '  A[3] := 29;' + LineEnding +
    '  SetLength(A, 8);' + LineEnding +
    '  I := A[0] + A[3];' + LineEnding +
    '  Halt(I - 4);' + LineEnding +
    'end.';

  ExitSource =
    'program dynarray_exit;' + LineEnding +
    'procedure Work;' + LineEnding +
    'var A: array of Integer;' + LineEnding +
    'begin' + LineEnding +
    '  SetLength(A, 4);' + LineEnding +
    '  Exit;' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    '  Work;' + LineEnding +
    '  Halt(42);' + LineEnding +
    'end.';

procedure Fail(const AMessage: string);
begin
  WriteLn('hir-dynarray-release-runtime-smoke-failure=', AMessage);
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
    Fail('missing-allocator-helper-slice');
  Result := Copy(ALlvmText, HelperStart, MaxInt);
end;

function ModuleHeader: string;
begin
  Result :=
    '; ModuleID = ''c6h1-dynarray-runtime-smoke''' + LineEnding +
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

function BuildDirectResizeIr(const AHelpers: string): string;
begin
  Result := ModuleHeader +
    'define i64 @_start() {' + LineEnding +
    'entry:' + LineEnding +
    '  %p0 = call ptr @np_dynarray_resize(ptr null, i64 0, i64 4, i64 8)' + LineEnding +
    '  %slot0 = getelementptr i64, ptr %p0, i64 0' + LineEnding +
    '  %slot3 = getelementptr i64, ptr %p0, i64 3' + LineEnding +
    '  store i64 17, ptr %slot0' + LineEnding +
    '  store i64 29, ptr %slot3' + LineEnding +
    '  %p1 = call ptr @np_dynarray_resize(ptr %p0, i64 4, i64 8, i64 8)' + LineEnding +
    '  %head = load i64, ptr %p1' + LineEnding +
    '  %tailp = getelementptr i64, ptr %p1, i64 3' + LineEnding +
    '  %tail = load i64, ptr %tailp' + LineEnding +
    '  %head.ok = icmp eq i64 %head, 17' + LineEnding +
    '  br i1 %head.ok, label %check.tail, label %fail' + LineEnding +
    'check.tail:' + LineEnding +
    '  %tail.ok = icmp eq i64 %tail, 29' + LineEnding +
    '  br i1 %tail.ok, label %release, label %fail' + LineEnding +
    'release:' + LineEnding +
    '  call void @np_dynarray_release(ptr %p1, i64 8, i64 8)' + LineEnding +
    '  br label %pass' + LineEnding +
    ExitBlock('pass', 42) +
    ExitBlock('fail', 13) +
    '}' + LineEnding + LineEnding +
    AHelpers;
end;

procedure AssertGeneratedContracts(const ADirectIr, AResizeLlvm,
  AExitLlvm: string);
var
  ExitReleasePos: LongInt;
  ExitRetPos: LongInt;
  ExitHaltPos: LongInt;
begin
  if Pos('define internal ptr @np_dynarray_resize(', AResizeLlvm) = 0 then
    Fail('missing-dynarray-resize-helper');
  if Pos('define internal void @np_dynarray_release(', AResizeLlvm) = 0 then
    Fail('missing-dynarray-release-helper');
  if Pos('define internal void @np_dynarray_fault(', AResizeLlvm) = 0 then
    Fail('missing-dynarray-fault-helper');
  if Pos('call ptr @np_dynarray_resize(', AResizeLlvm) = 0 then
    Fail('missing-generated-resize-call');
  if Pos('call void @np_dynarray_release(', AExitLlvm) = 0 then
    Fail('missing-generated-exit-release-call');
  if Pos('call ptr @np_alloc(i64 %arralloc.', AResizeLlvm) <> 0 then
    Fail('generated-resize-still-bare-arr-alloc');
  if Pos('call ptr @np_dynarray_resize(ptr null, i64 0, i64 4, i64 8)', ADirectIr) = 0 then
    Fail('missing-direct-helper-resize-call');
  if Pos('call void @np_dynarray_release(ptr %p1, i64 8, i64 8)', ADirectIr) = 0 then
    Fail('missing-direct-helper-release-call');

  ExitReleasePos := Pos('call void @np_dynarray_release(', AExitLlvm);
  ExitRetPos := FindAfter('ret i64 ', AExitLlvm, ExitReleasePos);
  ExitHaltPos := FindAfter(
    'call void asm sideeffect "movq $$60, %rax; syscall"',
    AExitLlvm, ExitReleasePos);
  if (ExitReleasePos > 0) and (ExitRetPos > 0) and
    (ExitReleasePos > ExitRetPos) then
    Fail('exit-cleanup-after-return');
  if (ExitReleasePos > 0) and (ExitHaltPos > 0) and
    (ExitReleasePos > ExitHaltPos) then
    Fail('exit-cleanup-after-halt');
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
  ResizeLlvm: string;
  ExitLlvm: string;
  DirectIr: string;
  Helpers: string;
begin
  if ParamCount >= 1 then
    OutputDir := ParamStr(1)
  else
    OutputDir := '/tmp/nextpas-c6h1-dynarray-runtime-smoke';
  if not ForceDirectories(OutputDir) then
    Fail('create-output-dir:' + OutputDir);

  ResizeLlvm := EmitLlvmFromSource(ResizeSource);
  ExitLlvm := EmitLlvmFromSource(ExitSource);
  Helpers := ExtractHelperSuffix(ResizeLlvm);
  DirectIr := BuildDirectResizeIr(Helpers);
  AssertGeneratedContracts(DirectIr, ResizeLlvm, ExitLlvm);

  WriteTextFile(IncludeTrailingPathDelimiter(OutputDir) +
    'llvm_dynarray_direct_helper.ll', DirectIr);
  WriteTextFile(IncludeTrailingPathDelimiter(OutputDir) +
    'llvm_dynarray_resize.ll', ResizeLlvm);
  WriteTextFile(IncludeTrailingPathDelimiter(OutputDir) +
    'llvm_dynarray_exit.ll', ExitLlvm);

  WriteLn('hir-dynarray-release-runtime-smoke-output-dir=', OutputDir);
  RunRuntimeSmoke(OutputDir, 'llvm_dynarray_direct_helper');
  WriteLn('hir-dynarray-release-runtime-smoke-direct-exit=42');
  RunRuntimeSmoke(OutputDir, 'llvm_dynarray_resize');
  WriteLn('hir-dynarray-release-runtime-smoke-resize-exit=42');
  RunRuntimeSmoke(OutputDir, 'llvm_dynarray_exit');
  WriteLn('hir-dynarray-release-runtime-smoke-exit-cleanup=42');
  WriteLn('hir-dynarray-release-runtime-smoke-status=pass');
end.
