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

var
  OutputDir: string;
  LlvmText: string;
  LlPath: string;
begin
  if ParamCount >= 1 then
    OutputDir := ParamStr(1)
  else
    OutputDir := '/tmp/nextpas-c6h4-string-return-ownership-runtime-smoke';
  if not ForceDirectories(OutputDir) then
    Fail('create-output-dir:' + OutputDir);

  LlvmText := EmitLlvmFromSource(DirectConcatReturnSource);
  LlPath := IncludeTrailingPathDelimiter(OutputDir) +
    'llvm_string_return_owned_direct.ll';
  WriteTextFile(LlPath, LlvmText);

  AssertDirectOwnedReturnRuntimeContract(LlvmText);
  RunRuntimeSmoke(OutputDir, 'llvm_string_return_owned_direct');
  WriteLn('hir-string-return-ownership-runtime-smoke-direct-exit=42');
  WriteLn('hir-string-return-ownership-runtime-smoke-status=pass');
end.
