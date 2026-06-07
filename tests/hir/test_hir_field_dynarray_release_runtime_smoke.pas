program test_hir_field_dynarray_release_runtime_smoke;

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
  FieldFreeSource =
    'program test;' + LineEnding +
    'type TBase = class' + LineEnding +
    '  Items: array of Integer;' + LineEnding +
    'end;' + LineEnding +
    'type TWorker = class(TBase)' + LineEnding +
    '  More: array of Integer;' + LineEnding +
    '  procedure Touch;' + LineEnding +
    'end;' + LineEnding +
    'var Worker: TWorker;' + LineEnding +
    'procedure TWorker.Touch;' + LineEnding +
    'begin' + LineEnding +
    '  SetLength(Items, 4);' + LineEnding +
    '  SetLength(Self.More, 2);' + LineEnding +
    'end;' + LineEnding +
    'procedure FreeWorker(Obj: TWorker);' + LineEnding +
    'begin' + LineEnding +
    '  Obj.Free;' + LineEnding +
    'end;' + LineEnding +
    'procedure FreeBaseRef(BaseRef: TBase);' + LineEnding +
    'begin' + LineEnding +
    '  BaseRef.Free;' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    '  Worker := TWorker.Create;' + LineEnding +
    '  Worker.Free;' + LineEnding +
    'end.';

procedure Fail(const AMessage: string);
begin
  WriteLn('hir-field-dynarray-release-runtime-smoke-failure=', AMessage);
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

function ExtractRuntimeHelpers(const ALlvmText: string): string;
var
  WorkerCleanup: string;
  BaseCleanup: string;
begin
  WorkerCleanup := ExtractDefinitionSlice(ALlvmText,
    'define internal void @np_object_dynarray_cleanup_TWorker(ptr ');
  if WorkerCleanup = '' then
    Fail('missing-worker-cleanup-helper-slice');
  BaseCleanup := ExtractDefinitionSlice(ALlvmText,
    'define internal void @np_object_dynarray_cleanup_TBase(ptr ');
  if BaseCleanup = '' then
    Fail('missing-base-cleanup-helper-slice');
  Result := WorkerCleanup + LineEnding + LineEnding + BaseCleanup +
    LineEnding + LineEnding + ExtractHelperSuffix(ALlvmText);
end;

function ModuleHeader: string;
begin
  Result :=
    '; ModuleID = ''c6h2-field-dynarray-runtime-smoke''' + LineEnding +
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

function BuildResizeFreeIr(const AHelpers: string): string;
begin
  Result := ModuleHeader +
    'define i64 @TWorker.Destroy(ptr %self) {' + LineEnding +
    'entry:' + LineEnding +
    '  %items.slot = getelementptr i64, ptr %self, i64 1' + LineEnding +
    '  %itemsp = load ptr, ptr %items.slot' + LineEnding +
    '  %items.first = load i64, ptr %itemsp' + LineEnding +
    '  %items.first.ok = icmp eq i64 %items.first, 17' + LineEnding +
    '  br i1 %items.first.ok, label %check.items.tail, label %fail.items.first' + LineEnding +
    'check.items.tail:' + LineEnding +
    '  %items.tailp = getelementptr i64, ptr %itemsp, i64 3' + LineEnding +
    '  %items.tail = load i64, ptr %items.tailp' + LineEnding +
    '  %items.tail.ok = icmp eq i64 %items.tail, 29' + LineEnding +
    '  br i1 %items.tail.ok, label %check.more, label %fail.items.tail' + LineEnding +
    'check.more:' + LineEnding +
    '  %more.slot = getelementptr i64, ptr %self, i64 3' + LineEnding +
    '  %morep = load ptr, ptr %more.slot' + LineEnding +
    '  %more.first = load i64, ptr %morep' + LineEnding +
    '  %more.first.ok = icmp eq i64 %more.first, 41' + LineEnding +
    '  br i1 %more.first.ok, label %check.more.tail, label %fail.more.first' + LineEnding +
    'check.more.tail:' + LineEnding +
    '  %more.tailp = getelementptr i64, ptr %morep, i64 1' + LineEnding +
    '  %more.tail = load i64, ptr %more.tailp' + LineEnding +
    '  %more.tail.ok = icmp eq i64 %more.tail, 43' + LineEnding +
    '  br i1 %more.tail.ok, label %ok, label %fail.more.tail' + LineEnding +
    'ok:' + LineEnding +
    '  ret i64 0' + LineEnding +
    ExitBlock('fail.items.first', 11) +
    ExitBlock('fail.items.tail', 12) +
    ExitBlock('fail.more.first', 13) +
    ExitBlock('fail.more.tail', 14) +
    '}' + LineEnding + LineEnding +
    'define i64 @_start() {' + LineEnding +
    'entry:' + LineEnding +
    '  %obj = call ptr @np_object_alloc(i64 40)' + LineEnding +
    '  %items.4 = call ptr @np_dynarray_resize(ptr null, i64 0, i64 4, i64 8)' + LineEnding +
    '  %items.slot = getelementptr i64, ptr %obj, i64 1' + LineEnding +
    '  store ptr %items.4, ptr %items.slot' + LineEnding +
    '  %items.len = getelementptr i64, ptr %obj, i64 2' + LineEnding +
    '  store i64 4, ptr %items.len' + LineEnding +
    '  store i64 17, ptr %items.4' + LineEnding +
    '  %items.tail4 = getelementptr i64, ptr %items.4, i64 3' + LineEnding +
    '  store i64 29, ptr %items.tail4' + LineEnding +
    '  %items.8 = call ptr @np_dynarray_resize(ptr %items.4, i64 4, i64 8, i64 8)' + LineEnding +
    '  store ptr %items.8, ptr %items.slot' + LineEnding +
    '  store i64 8, ptr %items.len' + LineEnding +
    '  %more.slot = getelementptr i64, ptr %obj, i64 3' + LineEnding +
    '  %more.len = getelementptr i64, ptr %obj, i64 4' + LineEnding +
    '  %more.2 = call ptr @np_dynarray_resize(ptr null, i64 0, i64 2, i64 8)' + LineEnding +
    '  store ptr %more.2, ptr %more.slot' + LineEnding +
    '  store i64 2, ptr %more.len' + LineEnding +
    '  store i64 41, ptr %more.2' + LineEnding +
    '  %more.tail = getelementptr i64, ptr %more.2, i64 1' + LineEnding +
    '  store i64 43, ptr %more.tail' + LineEnding +
    '  %ignored = call i64 @TWorker.Destroy(ptr %obj)' + LineEnding +
    '  call void @np_object_dynarray_cleanup_TWorker(ptr %obj)' + LineEnding +
    '  %items.after = load ptr, ptr %items.slot' + LineEnding +
    '  %items.after.null = icmp eq ptr %items.after, null' + LineEnding +
    '  br i1 %items.after.null, label %check.items.len, label %fail.items.cleanup.ptr' + LineEnding +
    'check.items.len:' + LineEnding +
    '  %items.len.after = load i64, ptr %items.len' + LineEnding +
    '  %items.len.zero = icmp eq i64 %items.len.after, 0' + LineEnding +
    '  br i1 %items.len.zero, label %check.more.ptr, label %fail.items.cleanup.len' + LineEnding +
    'check.more.ptr:' + LineEnding +
    '  %more.after = load ptr, ptr %more.slot' + LineEnding +
    '  %more.after.null = icmp eq ptr %more.after, null' + LineEnding +
    '  br i1 %more.after.null, label %check.more.len, label %fail.more.cleanup.ptr' + LineEnding +
    'check.more.len:' + LineEnding +
    '  %more.len.after = load i64, ptr %more.len' + LineEnding +
    '  %more.len.zero = icmp eq i64 %more.len.after, 0' + LineEnding +
    '  br i1 %more.len.zero, label %release, label %fail.more.cleanup.len' + LineEnding +
    'release:' + LineEnding +
    '  call void @np_object_free_release(ptr %obj)' + LineEnding +
    '  br label %pass' + LineEnding +
    ExitBlock('pass', 42) +
    ExitBlock('fail.items.cleanup.ptr', 21) +
    ExitBlock('fail.items.cleanup.len', 22) +
    ExitBlock('fail.more.cleanup.ptr', 23) +
    ExitBlock('fail.more.cleanup.len', 24) +
    '}' + LineEnding + LineEnding +
    AHelpers;
end;

function BuildZeroFreeIr(const AHelpers: string): string;
begin
  Result := ModuleHeader +
    'define i64 @TWorker.Destroy(ptr %self) {' + LineEnding +
    'entry:' + LineEnding +
    '  ret i64 0' + LineEnding +
    '}' + LineEnding + LineEnding +
    'define i64 @_start() {' + LineEnding +
    'entry:' + LineEnding +
    '  %obj = call ptr @np_object_alloc(i64 40)' + LineEnding +
    '  %ignored = call i64 @TWorker.Destroy(ptr %obj)' + LineEnding +
    '  call void @np_object_dynarray_cleanup_TWorker(ptr %obj)' + LineEnding +
    '  call void @np_object_free_release(ptr %obj)' + LineEnding +
    '  br label %pass' + LineEnding +
    ExitBlock('pass', 42) +
    '}' + LineEnding + LineEnding +
    AHelpers;
end;

procedure AssertGeneratedContracts(const ASourceLlvm, AResizeIr,
  AZeroIr: string);
var
  FreeWorkerLlvm, FreeBaseRefLlvm: string;
  DestroyPos, CleanupPos, ReleasePos: LongInt;
begin
  if Pos('define internal ptr @np_dynarray_resize(', ASourceLlvm) = 0 then
    Fail('missing-dynarray-resize-helper');
  if Pos('define internal void @np_dynarray_release(', ASourceLlvm) = 0 then
    Fail('missing-dynarray-release-helper');
  if Pos('define internal ptr @np_object_alloc(i64 %size)', ASourceLlvm) = 0 then
    Fail('missing-object-alloc-helper');
  if Pos('define internal void @np_object_free_release(ptr %obj)', ASourceLlvm) = 0 then
    Fail('missing-object-free-release-helper');
  if Pos('define internal void @np_object_dynarray_cleanup_TWorker(ptr ',
    ASourceLlvm) = 0 then
    Fail('missing-worker-field-cleanup-helper');
  if Pos('define internal void @np_object_dynarray_cleanup_TBase(ptr ',
    ASourceLlvm) = 0 then
    Fail('missing-base-field-cleanup-helper');

  FreeWorkerLlvm := ExtractDefinitionSlice(ASourceLlvm, '@FreeWorker(');
  if FreeWorkerLlvm = '' then
    Fail('missing-free-worker-function');
  DestroyPos := FindAfter('@TWorker.Destroy', FreeWorkerLlvm, 1);
  CleanupPos := FindAfter('call void @np_object_dynarray_cleanup_TWorker(ptr ',
    FreeWorkerLlvm, DestroyPos);
  ReleasePos := FindAfter('call void @np_object_free_release(ptr ',
    FreeWorkerLlvm, CleanupPos);
  if (DestroyPos = 0) or (CleanupPos = 0) or (ReleasePos = 0) or
    not ((DestroyPos < CleanupPos) and (CleanupPos < ReleasePos)) then
    Fail('free-worker-destroy-cleanup-release-order');

  FreeBaseRefLlvm := ExtractDefinitionSlice(ASourceLlvm, '@FreeBaseRef(');
  if FreeBaseRefLlvm = '' then
    Fail('missing-free-baseref-function');
  if Pos('call void @np_object_dynarray_cleanup_TBase(ptr ',
    FreeBaseRefLlvm) = 0 then
    Fail('missing-baseref-base-cleanup');
  if Pos('@np_object_dynarray_cleanup_TWorker', FreeBaseRefLlvm) <> 0 then
    Fail('baseref-free-must-stay-compile-time-class-only');

  if Pos('call ptr @np_dynarray_resize(ptr null, i64 0, i64 4, i64 8)',
    AResizeIr) = 0 then
    Fail('missing-field-items-initial-resize');
  if Pos('call ptr @np_dynarray_resize(ptr %items.4, i64 4, i64 8, i64 8)',
    AResizeIr) = 0 then
    Fail('missing-field-items-second-resize');
  if Pos('call void @np_object_dynarray_cleanup_TWorker(ptr %obj)',
    AResizeIr) = 0 then
    Fail('missing-resize-runtime-cleanup-call');
  if Pos('call void @np_object_free_release(ptr %obj)', AResizeIr) = 0 then
    Fail('missing-resize-runtime-release-call');
  if Pos('call void @np_object_dynarray_cleanup_TWorker(ptr %obj)',
    AZeroIr) = 0 then
    Fail('missing-zero-runtime-cleanup-call');
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
  SourceLlvm: string;
  Helpers: string;
  ResizeIr: string;
  ZeroIr: string;
begin
  if ParamCount >= 1 then
    OutputDir := ParamStr(1)
  else
    OutputDir := '/tmp/nextpas-c6h2-field-dynarray-runtime-smoke';
  if not ForceDirectories(OutputDir) then
    Fail('create-output-dir:' + OutputDir);

  SourceLlvm := EmitLlvmFromSource(FieldFreeSource);
  Helpers := ExtractRuntimeHelpers(SourceLlvm);
  ResizeIr := BuildResizeFreeIr(Helpers);
  ZeroIr := BuildZeroFreeIr(Helpers);
  AssertGeneratedContracts(SourceLlvm, ResizeIr, ZeroIr);

  WriteTextFile(IncludeTrailingPathDelimiter(OutputDir) +
    'llvm_field_dynarray_source.ll', SourceLlvm);
  WriteTextFile(IncludeTrailingPathDelimiter(OutputDir) +
    'llvm_field_dynarray_resize_free.ll', ResizeIr);
  WriteTextFile(IncludeTrailingPathDelimiter(OutputDir) +
    'llvm_field_dynarray_zero_free.ll', ZeroIr);

  WriteLn('hir-field-dynarray-release-runtime-smoke-output-dir=', OutputDir);
  RunRuntimeSmoke(OutputDir, 'llvm_field_dynarray_resize_free');
  WriteLn('hir-field-dynarray-release-runtime-smoke-resize-free-exit=42');
  RunRuntimeSmoke(OutputDir, 'llvm_field_dynarray_zero_free');
  WriteLn('hir-field-dynarray-release-runtime-smoke-zero-free-exit=42');
  WriteLn('hir-field-dynarray-release-runtime-smoke-status=pass');
end.
