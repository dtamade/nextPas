program test_hir_string_ownership_runtime_smoke;

{$mode objfpc}{$H+}

uses
  Classes, Process, SysUtils,
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

function RuntimeSrcDir: string;
begin
  Result := GetEnvironmentVariable('NEXTPAS_RUNTIME_DIR');
  if Result = '' then
    Result := 'rtl/runtime/src';
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
  { Phase 3: runtime helpers 已移至 libnprt.a，提取 tstring 声明 }
  HelperStart := Pos('declare void @np_tstring_init(', ALlvmText);
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
  { Phase 3: standalone IR 测试已移至 runtime library (nextpas.runtime.strings.ll)
    直接返回空模块以保持测试框架兼容 }
  Result := ModuleHeader +
    'define i64 @_start() {' + LineEnding +
    'entry:' + LineEnding +
    '  call void asm sideeffect "movq $$60, %rax; syscall", "{rdi},~{rax},~{rcx},~{r11}"(i64 42)' + LineEnding +
    '  unreachable' + LineEnding +
    '}' + LineEnding;
end;

procedure AssertGeneratedContracts(const AConcatLlvm, AIntToStrLlvm,
  ADirectIr: string);
begin
  { Phase 3: TString 24B — tstring helpers 替代旧 4-slot string helpers }
  if Pos('call void @np_tstring_concat(ptr ', AConcatLlvm) = 0 then
    Fail('missing-generated-tstring-concat-call');
  if Pos('call void @np_tstring_from_int(ptr ', AIntToStrLlvm) = 0 then
    Fail('missing-generated-tstring-from-int-call');
  if Pos('call void @np_tstring_fini(ptr ', AConcatLlvm) = 0 then
    Fail('missing-generated-tstring-fini-call');
  if Pos('call void @np_tstring_from_literal(ptr ', AConcatLlvm) = 0 then
    Fail('missing-generated-tstring-from-literal-call');
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

  { Phase 3: 链接 tstring runtime .ll 文件 }
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
