program test_hir_string_length_ownership_runtime_smoke;

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
  DirectLengthOwnedTempSource =
    'program c6h6_string_length_runtime;' + LineEnding +
    'function MakeText: string;' + LineEnding +
    'begin' + LineEnding +
    '  MakeText := IntToStr(42) + ''tail'';' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    '  Halt(Length(MakeText()) + 36);' + LineEnding +
    'end.';

  LiteralLengthSource =
    'program c6h6_literal_length_runtime;' + LineEnding +
    'begin' + LineEnding +
    '  Halt(Length(''literal'') + 35);' + LineEnding +
    'end.';

  CopyOwnedTempSource =
    'program c6h8_string_copy_owned_runtime;' + LineEnding +
    'function MakeText: string;' + LineEnding +
    'begin' + LineEnding +
    '  MakeText := IntToStr(42) + ''tail'';' + LineEnding +
    'end;' + LineEnding +
    'var S: string;' + LineEnding +
    'begin' + LineEnding +
    '  S := Copy(MakeText(), 2, 2);' + LineEnding +
    '  if S = ''2t'' then' + LineEnding +
    '    Halt(42)' + LineEnding +
    '  else' + LineEnding +
    '    Halt(7);' + LineEnding +
    'end.';

procedure Fail(const AMessage: string);
begin
  WriteLn('hir-string-length-ownership-runtime-smoke-failure=', AMessage);
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

function BuildModel(const ASource, ARedPrefix: string): TSemanticModel;
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
      Fail(ARedPrefix + ':' + Diagnostics.LastDiagnosticCode);
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

function EmitLlvmFromSource(const ASource, ARedPrefix: string): string;
var
  Model: TSemanticModel;
  Builder: THIRBuilder;
  Emitter: THIRLlvmEmitter;
begin
  Model := BuildModel(ASource, ARedPrefix);
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

procedure AssertOwnedLengthRuntimeContract(const ALlvmText: string);
begin
  RequireContains(ALlvmText,
    ' = call {ptr, i64, ptr, i64} @MakeText(',
    'missing-owned-string-length-producer-runtime');
  RequireContains(ALlvmText, 'extractvalue {ptr, i64, ptr, i64}',
    'missing-owned-string-length-descriptor-extract-runtime');
  RequireContains(ALlvmText, 'call void @np_string_release(',
    'missing-owned-string-length-release-runtime');
  RequireOrder(ALlvmText, 'extractvalue {ptr, i64, ptr, i64}',
    'call void @np_string_release(',
    'length-temp-release-must-follow-length-runtime');
end;

procedure AssertLiteralLengthRuntimeContract(const ALlvmText: string);
begin
  RequireContains(ALlvmText, '@.str.',
    'missing-literal-length-string-constant-runtime');
  RejectContains(ALlvmText, 'call void @np_string_release(',
    'literal-length-must-not-release-runtime');
end;

procedure AssertCopyOwnedRuntimeContract(const ALlvmText: string);
begin
  RequireContains(ALlvmText,
    ' = call {ptr, i64, ptr, i64} @MakeText(',
    'missing-owned-string-copy-producer-runtime');
  RequireContains(ALlvmText,
    ' = call {ptr, i64, ptr, i64} @np_str_copy_owned(',
    'missing-owned-string-copy-helper-runtime');
  RequireContains(ALlvmText, 'call void @np_string_release(',
    'missing-owned-string-copy-release-runtime');
  RequireOrder(ALlvmText,
    ' = call {ptr, i64, ptr, i64} @np_str_copy_owned(',
    'call void @np_string_release(',
    'copy-temp-release-must-follow-owned-copy-runtime');
end;

procedure EmitAssertAndRun(const AOutputDir, AStem, ASource,
  AAssertKind: string);
var
  LlvmText: string;
  LlPath: string;
begin
  LlvmText := EmitLlvmFromSource(ASource,
    'missing-owned-string-length-runtime');
  LlPath := IncludeTrailingPathDelimiter(AOutputDir) + AStem + '.ll';
  WriteTextFile(LlPath, LlvmText);

  if AAssertKind = 'owned-length' then
    AssertOwnedLengthRuntimeContract(LlvmText)
  else if AAssertKind = 'literal-length' then
    AssertLiteralLengthRuntimeContract(LlvmText)
  else if AAssertKind = 'owned-copy' then
    AssertCopyOwnedRuntimeContract(LlvmText)
  else
    Fail('unknown-assert-kind:' + AAssertKind);

  RunRuntimeSmoke(AOutputDir, AStem);
  WriteLn('hir-string-length-ownership-runtime-smoke-', AStem,
    '-exit=42');
end;

var
  OutputDir: string;
begin
  if ParamCount >= 1 then
    OutputDir := ParamStr(1)
  else
    OutputDir := '/tmp/nextpas-c6h6-string-length-runtime-smoke';
  if not ForceDirectories(OutputDir) then
    Fail('create-output-dir:' + OutputDir);

  EmitAssertAndRun(OutputDir, 'llvm_string_length_owned_direct',
    DirectLengthOwnedTempSource, 'owned-length');
  EmitAssertAndRun(OutputDir, 'llvm_string_length_literal',
    LiteralLengthSource, 'literal-length');
  EmitAssertAndRun(OutputDir, 'llvm_string_copy_owned_direct',
    CopyOwnedTempSource, 'owned-copy');
  WriteLn('hir-string-length-ownership-runtime-smoke-status=pass');
end.
