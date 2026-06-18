program toolchain_contract_smoke;

{$mode objfpc}{$H+}
{$UNITPATH ../../compiler/backend}
{$UNITPATH ../../compiler/diagnostics}
{$UNITPATH ../../compiler/frontend}
{$UNITPATH ../../compiler/ir}
{$UNITPATH ../../compiler/sema}
{$UNITPATH ../../compiler/syntax}
{$UNITPATH ../../compiler/toolchain}
{$UNITPATH ../../compiler/targets}
{$UNITPATH ../../rtl/core/base}
{$UNITPATH ../../rtl/core/text}
{$UNITPATH ../../core/src}
{$UNITPATH ../../tools/stage0}

uses
  Classes, SysUtils, BaseUnix, target_config, np_backend_plan,
  np_diagnostics_sink, np_package_manifest, np_package_workflow,
  np_source_database, np_target_facts, np_toolchain_plan, np_unit_resolver,
  np_workspace_model, np_toolchain_runner;

function BuildFactsFromConfig(const AConfig: TTargetConfig): TTargetFactsView;
begin
  Result := BuildTargetFactsView(
    AConfig.TargetId,
    AConfig.ConfigPath,
    AConfig.HostId,
    AConfig.HostOS,
    AConfig.HostCPU,
    AConfig.CompilerExecutable,
    AConfig.UnitsDir,
    AConfig.ObjectFormat,
    AConfig.AssemblerFlavor,
    AConfig.LinkerFlavor,
    AConfig.RuntimeLayoutKey,
    AConfig.CSymbolPrefix,
    AConfig.CLibraryNaming,
    AConfig.LlvmTriple,
    AConfig.LlvmDataLayout,
    AConfig.ToolchainBindingId,
    AConfig.HostCompilerProfileId,
    AConfig.BackendFamily,
    AConfig.AssemblerProfileId,
    AConfig.LinkerProfileId,
    AConfig.ArchiverProfileId,
    AConfig.ResourceToolProfileId,
    AConfig.SysrootMode,
    AConfig.RuntimeSdkId,
    AConfig.AllowHostFallback,
    AConfig.ToolRootKind,
    AConfig.RuntimeRootKind,
    AConfig.ResponseFilePolicy,
    AConfig.LinkScriptPolicy,
    AConfig.LlvmEnabled,
    AConfig.LlvmExecutableSetId
  );
end;

procedure PrintNativePlan(const ATargetFacts: TTargetFactsView);
var
  Plan: TToolchainPlan;
  Planner: TToolchainPlanner;
begin
  Planner := TToolchainPlanner.Create(nil, ATargetFacts, 'examples/smoke/hello.pas');
  try
    Planner.PlanNativeAssembleLink(
      'examples/smoke/hello.s',
      'examples/smoke/hello.o',
      'examples/smoke/hello'
    );
    Plan := Planner.DetachPlan;
  finally
    Planner.Free;
  end;

  try
    Plan.AddLogicalLibraryRequest('c', 'shared', 'strong');
    WriteLn('native-plan-status=', Plan.Status);
    WriteLn('native-plan-family=', Plan.PlanFamily);
    WriteLn('native-tool-invocation-count=', Plan.ToolInvocationCount);
    WriteLn(
      'native-logical-library-request-count=',
      Plan.LogicalLibraryRequestCount
    );
    WriteLn('native-tool-profile-root=', Plan.ToolProfileRoot);
    WriteLn(
      'native-tool-invocation-plan=',
      Plan.ToolInvocationPlanJson('plan-native-assemble-link', '')
    );
    WriteLn('native-logical-link-request=', Plan.LogicalLinkRequestJson);
    WriteLn('native-llvm-executable-set=', Plan.LlvmExecutableSetJson);
  finally
    Plan.Free;
  end;
end;

procedure PrintResourcePlan(const ATargetFacts: TTargetFactsView);
var
  ResourceFacts: TTargetFactsView;
  Plan: TToolchainPlan;
  Planner: TToolchainPlanner;
begin
  ResourceFacts := ATargetFacts;
  ResourceFacts.ResourceToolProfileId := 'windres+fpcres-coff';

  Planner := TToolchainPlanner.Create(nil, ResourceFacts, 'examples/resources/app.rc');
  try
    Planner.PlanResourceCompile(
      'examples/resources/app.rc',
      'examples/resources/app.res',
      'examples/resources/app.res.o'
    );
    Plan := Planner.DetachPlan;
  finally
    Planner.Free;
  end;

  try
    WriteLn('resource-plan-status=', Plan.Status);
    WriteLn('resource-plan-family=', Plan.PlanFamily);
    WriteLn('resource-tool-invocation-count=', Plan.ToolInvocationCount);
    WriteLn(
      'resource-tool-invocation-plan=',
      Plan.ToolInvocationPlanJson('plan-resource-compile', '')
    );
  finally
    Plan.Free;
  end;
end;

procedure PrintArchivePlan(const ATargetFacts: TTargetFactsView);
var
  ArchiveMembers: array[0..1] of string;
  Plan: TToolchainPlan;
  Planner: TToolchainPlanner;
begin
  ArchiveMembers[0] := 'examples/lib/foo.o';
  ArchiveMembers[1] := 'examples/lib/bar.o';

  Planner := TToolchainPlanner.Create(nil, ATargetFacts, 'examples/lib/libdemo.a');
  try
    Planner.PlanArchiveBuild('examples/lib/libdemo.a', ArchiveMembers);
    Plan := Planner.DetachPlan;
  finally
    Planner.Free;
  end;

  try
    WriteLn('archive-plan-status=', Plan.Status);
    WriteLn('archive-plan-family=', Plan.PlanFamily);
    WriteLn('archive-tool-invocation-count=', Plan.ToolInvocationCount);
    WriteLn(
      'archive-tool-invocation-plan=',
      Plan.ToolInvocationPlanJson('plan-archive-build', '')
    );
  finally
    Plan.Free;
  end;
end;

procedure PrintLlvmEnabledPlan(const ATargetFacts: TTargetFactsView);
var
  LlvmFacts: TTargetFactsView;
  Plan: TToolchainPlan;
  Planner: TToolchainPlanner;
begin
  LlvmFacts := ATargetFacts;
  LlvmFacts.LlvmEnabled := True;

  Planner := TToolchainPlanner.Create(nil, LlvmFacts, 'examples/smoke/hello.pas');
  try
    Planner.PlanNativeAssembleLink(
      'examples/smoke/hello.s',
      'examples/smoke/hello.o',
      'examples/smoke/hello'
    );
    Plan := Planner.DetachPlan;
  finally
    Planner.Free;
  end;

  try
    WriteLn('llvm-enabled-plan-status=', Plan.Status);
    WriteLn('llvm-enabled-toolchain-status=', Plan.LlvmToolchainStatus);
    WriteLn('llvm-enabled-set-id=', Plan.LlvmExecutableSetId);
    WriteLn('llvm-enabled-set=', Plan.LlvmExecutableSetJson);
  finally
    Plan.Free;
  end;
end;

procedure PrintLlvmMissingPlan(const ATargetFacts: TTargetFactsView);
var
  BrokenFacts: TTargetFactsView;
  Plan: TToolchainPlan;
  Planner: TToolchainPlanner;
begin
  BrokenFacts := ATargetFacts;
  BrokenFacts.LlvmEnabled := True;
  BrokenFacts.LlvmExecutableSetId := 'missing-llvm-set';

  Planner := TToolchainPlanner.Create(nil, BrokenFacts, 'examples/smoke/hello.pas');
  try
    Planner.PlanNativeAssembleLink(
      'examples/smoke/hello.s',
      'examples/smoke/hello.o',
      'examples/smoke/hello'
    );
    Plan := Planner.DetachPlan;
  finally
    Planner.Free;
  end;

  try
    WriteLn('llvm-missing-plan-status=', Plan.Status);
    WriteLn('llvm-missing-toolchain-status=', Plan.LlvmToolchainStatus);
    WriteLn('llvm-missing-failure-code=', Plan.FailureCode);
  finally
    Plan.Free;
  end;
end;

procedure WriteTextFile(const APath: string; const AText: string);
var
  Stream: TFileStream;
begin
  Stream := TFileStream.Create(APath, fmCreate);
  try
    if Length(AText) > 0 then
      Stream.WriteBuffer(AText[1], Length(AText));
  finally
    Stream.Free;
  end;
end;

function ReadTextFile(const APath: string): string;
var
  Stream: TFileStream;
begin
  Stream := TFileStream.Create(APath, fmOpenRead or fmShareDenyNone);
  try
    SetLength(Result, Stream.Size);
    if Stream.Size > 0 then
      Stream.ReadBuffer(Result[1], Stream.Size);
  finally
    Stream.Free;
  end;
end;

procedure DeleteFileIfExists(const APath: string);
begin
  if FileExists(APath) then
    DeleteFile(APath);
end;

procedure RemoveDirIfEmpty(const APath: string);
begin
  if DirectoryExists(APath) then
    RmDir(APath);
end;

function NormalizeWhitespace(const Value: string): string;
begin
  Result := StringReplace(Value, #13, ' ', [rfReplaceAll]);
  Result := StringReplace(Result, #10, ' ', [rfReplaceAll]);
  Result := StringReplace(Result, #9, ' ', [rfReplaceAll]);
  while Pos('  ', Result) > 0 do
    Result := StringReplace(Result, '  ', ' ', [rfReplaceAll]);
  Result := Trim(Result);
end;

function ResolveRepoRoot(const ATargetFacts: TTargetFactsView): string;
var
  RepoRoot: string;
begin
  RepoRoot := GetEnvironmentVariable('NEXTPAS_REPO_ROOT');
  if RepoRoot <> '' then
    Exit(ExpandFileName(RepoRoot));

  Result := ExpandFileName(
    IncludeTrailingPathDelimiter(ExtractFileDir(ATargetFacts.ConfigPath)) + '..' +
    DirectorySeparator + '..'
  );
end;

function RuntimeLibRootPath(const ATargetFacts: TTargetFactsView): string;
begin
  Result := ExpandFileName(
    IncludeTrailingPathDelimiter(ResolveRepoRoot(ATargetFacts)) + 'lib' +
    DirectorySeparator + 'nextpas' + DirectorySeparator + 'runtime' +
    DirectorySeparator + ATargetFacts.RuntimeSdkId
  );
end;

function RuntimeLibcPath(const ATargetFacts: TTargetFactsView): string;
begin
  Result := IncludeTrailingPathDelimiter(RuntimeLibRootPath(ATargetFacts)) + 'libc.so';
end;

procedure EnsureRuntimeLibcFixture(const ATargetFacts: TTargetFactsView);
begin
  ForceDirectories(RuntimeLibRootPath(ATargetFacts));
  WriteTextFile(
    RuntimeLibcPath(ATargetFacts),
    '/* fake runtime libc fixture for direct-link contract */' + LineEnding
  );
end;

procedure RemoveRuntimeLibcFixture(const ATargetFacts: TTargetFactsView);
var
  RuntimeRoot: string;
begin
  RuntimeRoot := RuntimeLibRootPath(ATargetFacts);
  DeleteFileIfExists(RuntimeLibcPath(ATargetFacts));
  RemoveDirIfEmpty(RuntimeRoot);
  RemoveDirIfEmpty(ExtractFileDir(RuntimeRoot));
  RemoveDirIfEmpty(ExtractFileDir(ExtractFileDir(RuntimeRoot)));
  RemoveDirIfEmpty(ExtractFileDir(ExtractFileDir(ExtractFileDir(RuntimeRoot))));
end;

function JsonEscape(const Value: string): string;
var
  Index: SizeInt;
begin
  Result := '';
  for Index := 1 to Length(Value) do
    case Value[Index] of
      '\':
        Result := Result + '\\';
      '"':
        Result := Result + '\"';
      #10:
        Result := Result + '\n';
      #13:
        Result := Result + '\r';
      #9:
        Result := Result + '\t';
    else
      Result := Result + Value[Index];
    end;
end;

function JsonString(const Value: string): string;
begin
  Result := '"' + JsonEscape(Value) + '"';
end;

procedure AppendJsonField(
  var AFields: string;
  const AName: string;
  const AValue: string
);
begin
  if AFields <> '' then
    AFields := AFields + ',';
  AFields := AFields + JsonString(AName) + ':' + AValue;
end;

function BuildExecutedSidecarJson(
  const AValues: TToolchainExecutedSidecarArray
): string;
var
  EntryFields: string;
  Index: SizeInt;
begin
  Result := '';
  for Index := 0 to High(AValues) do
  begin
    if Result <> '' then
      Result := Result + ',';
    EntryFields := '';
    AppendJsonField(EntryFields, 'kind', JsonString(AValues[Index].Kind));
    AppendJsonField(EntryFields, 'path', JsonString(AValues[Index].Path));
    AppendJsonField(EntryFields, 'ownerStepId', JsonString(AValues[Index].OwnerStepId));
    AppendJsonField(
      EntryFields,
      'materializationTiming',
      JsonString(AValues[Index].MaterializationTiming)
    );
    AppendJsonField(
      EntryFields,
      'cleanupPolicy',
      JsonString(AValues[Index].CleanupPolicy)
    );
    if AValues[Index].Materialized then
      AppendJsonField(EntryFields, 'materialized', 'true')
    else
      AppendJsonField(EntryFields, 'materialized', 'false');
    AppendJsonField(
      EntryFields,
      'cleanupStatus',
      JsonString(AValues[Index].CleanupStatus)
    );
    Result := Result + '{' + EntryFields + '}';
  end;
  Result := '[' + Result + ']';
end;

function BuildRunTranscriptJson(const ARunResult: TToolchainRunResult): string;
var
  StepFields: string;
  StepIndex: LongInt;
begin
  Result := '';
  for StepIndex := 0 to ARunResult.StepCount - 1 do
  begin
    if Result <> '' then
      Result := Result + ',';
    StepFields := '';
    AppendJsonField(StepFields, 'stepId', JsonString(ARunResult.StepAt(StepIndex).StepId));
    AppendJsonField(StepFields, 'status', JsonString(ARunResult.StepAt(StepIndex).Status));
    AppendJsonField(
      StepFields,
      'logicalExecutable',
      JsonString(ARunResult.StepAt(StepIndex).LogicalExecutable)
    );
    if ARunResult.StepAt(StepIndex).ResolvedPath <> '' then
      AppendJsonField(
        StepFields,
        'resolvedPath',
        JsonString(ARunResult.StepAt(StepIndex).ResolvedPath)
      );
    AppendJsonField(
      StepFields,
      'sidecars',
      BuildExecutedSidecarJson(ARunResult.StepAt(StepIndex).Sidecars)
    );
    if ARunResult.StepAt(StepIndex).HasExitCode then
      AppendJsonField(
        StepFields,
        'exitCode',
        IntToStr(ARunResult.StepAt(StepIndex).ExitCode)
      );
    Result := Result + '{' + StepFields + '}';
  end;
  Result := '[' + Result + ']';
end;

procedure WriteExecutableScript(const APath: string; const AText: string);
begin
  WriteTextFile(APath, AText);
  if fpChmod(APath, &755) <> 0 then
    raise Exception.Create('failed to chmod script: ' + APath);
end;

procedure PrintLlvmExecutionContract(const ATargetFacts: TTargetFactsView);
var
  ArtifactDir: string;
  BackendPlan: TBackendPlan;
  BitcodePath: string;
  FakeBinDir: string;
  IrPath: string;
  LinkScriptPath: string;
  LlvmFacts: TTargetFactsView;
  LlcScriptPath: string;
  LinkArgvCapturePath: string;
  ObjectPath: string;
  OptScriptPath: string;
  OutputPath: string;
  Plan: TToolchainPlan;
  Planner: TToolchainPlanner;
  RunResult: TToolchainRunResult;
  RunnerRoot: string;
  SearchPath: string;
begin
  RunnerRoot := ExpandFileName(
    IncludeTrailingPathDelimiter(ExtractFileDir(ParamStr(0))) +
    'toolchain-llvm-runner-fixture'
  );
  FakeBinDir := IncludeTrailingPathDelimiter(RunnerRoot) + 'bin';
  ArtifactDir := IncludeTrailingPathDelimiter(RunnerRoot) + 'artifacts';
  ForceDirectories(FakeBinDir);
  ForceDirectories(ArtifactDir);

  OptScriptPath := IncludeTrailingPathDelimiter(FakeBinDir) + 'opt';
  LlcScriptPath := IncludeTrailingPathDelimiter(FakeBinDir) + 'llc';
  LinkScriptPath := IncludeTrailingPathDelimiter(FakeBinDir) + 'ld.lld';
  LinkArgvCapturePath := IncludeTrailingPathDelimiter(ArtifactDir) + 'llvm-link-argv.txt';

  WriteExecutableScript(
    OptScriptPath,
    '#!/bin/sh' + LineEnding +
    'out=""' + LineEnding +
    'while [ "$#" -gt 0 ]; do' + LineEnding +
    '  if [ "$1" = "-o" ]; then' + LineEnding +
    '    out="$2"' + LineEnding +
    '    shift 2' + LineEnding +
    '    continue' + LineEnding +
    '  fi' + LineEnding +
    '  shift' + LineEnding +
    'done' + LineEnding +
    'printf "fake-bitcode\n" > "$out"' + LineEnding
  );
  WriteExecutableScript(
    LlcScriptPath,
    '#!/bin/sh' + LineEnding +
    'out=""' + LineEnding +
    'while [ "$#" -gt 0 ]; do' + LineEnding +
    '  if [ "$1" = "-o" ]; then' + LineEnding +
    '    out="$2"' + LineEnding +
    '    shift 2' + LineEnding +
    '    continue' + LineEnding +
    '  fi' + LineEnding +
    '  shift' + LineEnding +
    'done' + LineEnding +
    'printf "fake-object\n" > "$out"' + LineEnding
  );
  WriteExecutableScript(
    LinkScriptPath,
    '#!/bin/sh' + LineEnding +
    'out=""' + LineEnding +
    'printf "%s\n" "$@" > "' + LinkArgvCapturePath + '"' + LineEnding +
    'while [ "$#" -gt 0 ]; do' + LineEnding +
    '  if [ "$1" = "-o" ]; then' + LineEnding +
    '    out="$2"' + LineEnding +
    '    shift 2' + LineEnding +
    '    continue' + LineEnding +
    '  fi' + LineEnding +
    '  shift' + LineEnding +
    'done' + LineEnding +
    'printf "fake-linked\n" > "$out"' + LineEnding
  );

  LlvmFacts := ATargetFacts;
  LlvmFacts.ToolchainBindingId := 'linux-x86_64-to-linux-x86_64-llvm';
  LlvmFacts.BackendFamily := 'llvm';
  LlvmFacts.LinkerProfileId := 'lld-elf';
  LlvmFacts.LlvmEnabled := True;
  LlvmFacts.LlvmExecutableSetId := 'llvm-stable';

  BackendPlan := TBackendPlan.Create;
  BackendPlan.SetRootName('hello');
  BackendPlan.SetTargetMetadata(LlvmFacts);
  BackendPlan.SetOutputKind('executable');
  BackendPlan.AddArtifact('llvm-ir',
    IncludeTrailingPathDelimiter(ArtifactDir) + 'hello.ll');
  BackendPlan.AddArtifact('llvm-bitcode',
    IncludeTrailingPathDelimiter(ArtifactDir) + 'hello.bc');
  BackendPlan.AddArtifact('object-file',
    IncludeTrailingPathDelimiter(ArtifactDir) + 'hello.o');
  BackendPlan.AddArtifact('executable',
    IncludeTrailingPathDelimiter(ArtifactDir) + 'hello');
  BackendPlan.SetPrimaryArtifact('executable',
    IncludeTrailingPathDelimiter(ArtifactDir) + 'hello');
  BackendPlan.MarkReady;

  try
    EnsureRuntimeLibcFixture(LlvmFacts);
    WriteLn('llvm-exec-backend-plan-status=', BackendPlan.Status);
    WriteLn('llvm-exec-backend-artifact-count=', BackendPlan.ArtifactCount);
    WriteLn('llvm-exec-backend-artifacts=', BackendPlan.ArtifactsJson);
    BackendPlan.AddLogicalLibraryRequest('c', 'shared', 'strong');

    Planner := TToolchainPlanner.Create(
      BackendPlan,
      LlvmFacts,
      'examples/smoke/hello.pas'
    );
    try
      Planner.PlanFromBackend;
      Plan := Planner.DetachPlan;
    finally
      Planner.Free;
    end;

    try
      WriteLn('llvm-exec-plan-status=', Plan.Status);
      WriteLn('llvm-exec-plan-family=', Plan.PlanFamily);
      WriteLn('llvm-exec-toolchain-status=', Plan.LlvmToolchainStatus);
      WriteLn('llvm-exec-tool-invocation-count=', Plan.ToolInvocationCount);
      WriteLn(
        'llvm-exec-tool-invocation-plan=',
        Plan.ToolInvocationPlanJson('plan-llvm-ir-opt-llc-link', '')
      );

      SearchPath := FakeBinDir;
      RunResult := ExecuteToolchainPlan(Plan, SearchPath);
      try
        WriteLn('llvm-exec-run-status=', RunResult.Status);
        WriteLn('llvm-exec-run-step-count=', RunResult.StepCount);
        WriteLn('llvm-exec-run-transcript=', BuildRunTranscriptJson(RunResult));
      finally
        RunResult.Free;
      end;
    finally
      Plan.Free;
    end;

    IrPath := BackendPlan.ArtifactPathByKind('llvm-ir');
    BitcodePath := BackendPlan.ArtifactPathByKind('llvm-bitcode');
    ObjectPath := BackendPlan.ArtifactPathByKind('object-file');
    OutputPath := BackendPlan.ArtifactPathByKind('executable');
    if FileExists(IrPath) then
      WriteLn('llvm-exec-ir-exists=true')
    else
      WriteLn('llvm-exec-ir-exists=false');
    if FileExists(BitcodePath) then
      WriteLn('llvm-exec-bitcode-exists=true')
    else
      WriteLn('llvm-exec-bitcode-exists=false');
    if FileExists(ObjectPath) then
      WriteLn('llvm-exec-object-exists=true')
    else
      WriteLn('llvm-exec-object-exists=false');
    if FileExists(OutputPath) then
      WriteLn('llvm-exec-output-exists=true')
    else
      WriteLn('llvm-exec-output-exists=false');
    if Pos(
      '-L' + RuntimeLibRootPath(LlvmFacts),
      NormalizeWhitespace(ReadTextFile(LinkArgvCapturePath))
    ) > 0 then
      WriteLn('llvm-exec-link-contains-runtime-root=true')
    else
      WriteLn('llvm-exec-link-contains-runtime-root=false');
    if Pos('-lc', NormalizeWhitespace(ReadTextFile(LinkArgvCapturePath))) > 0 then
      WriteLn('llvm-exec-link-contains-libc=true')
    else
      WriteLn('llvm-exec-link-contains-libc=false');
  finally
    DeleteFileIfExists(LinkArgvCapturePath);
    RemoveRuntimeLibcFixture(LlvmFacts);
    BackendPlan.Free;
  end;
end;

procedure PrintNativeExecutionContract(const ATargetFacts: TTargetFactsView);
var
  ArtifactDir: string;
  AssembleScriptPath: string;
  AssemblyPath: string;
  BackendPlan: TBackendPlan;
  CaptureResponsePath: string;
  FakeBinDir: string;
  LinkArgvCapturePath: string;
  LinkScriptPath: string;
  ObjectPath: string;
  OutputPath: string;
  Plan: TToolchainPlan;
  Planner: TToolchainPlanner;
  ResponsePath: string;
  RunResult: TToolchainRunResult;
  RunnerRoot: string;
  SearchPath: string;
begin
  RunnerRoot := ExpandFileName(
    IncludeTrailingPathDelimiter(ExtractFileDir(ParamStr(0))) +
    'toolchain-runner-fixture'
  );
  FakeBinDir := IncludeTrailingPathDelimiter(RunnerRoot) + 'bin';
  ArtifactDir := IncludeTrailingPathDelimiter(RunnerRoot) + 'artifacts';
  ForceDirectories(FakeBinDir);
  ForceDirectories(ArtifactDir);

  AssemblyPath := IncludeTrailingPathDelimiter(ArtifactDir) + 'hello.s';
  ObjectPath := IncludeTrailingPathDelimiter(ArtifactDir) + 'hello.o';
  OutputPath := IncludeTrailingPathDelimiter(ArtifactDir) + 'hello';
  ResponsePath := OutputPath + '.rsp';
  CaptureResponsePath := IncludeTrailingPathDelimiter(ArtifactDir) +
    'captured-response.txt';
  LinkArgvCapturePath := IncludeTrailingPathDelimiter(ArtifactDir) +
    'captured-link-argv.txt';
  AssembleScriptPath := IncludeTrailingPathDelimiter(FakeBinDir) + 'as';
  LinkScriptPath := IncludeTrailingPathDelimiter(FakeBinDir) + 'ld';

  WriteTextFile(AssemblyPath, '; fake assembly input' + LineEnding);
  WriteExecutableScript(
    AssembleScriptPath,
    '#!/usr/bin/env sh' + LineEnding +
    'out=""' + LineEnding +
    'while [ "$#" -gt 0 ]; do' + LineEnding +
    '  if [ "$1" = "-o" ]; then' + LineEnding +
    '    out="$2"' + LineEnding +
    '    shift 2' + LineEnding +
    '    continue' + LineEnding +
    '  fi' + LineEnding +
    '  shift' + LineEnding +
    'done' + LineEnding +
    'printf "fake-object\n" > "$out"' + LineEnding
  );
  WriteExecutableScript(
    LinkScriptPath,
    '#!/usr/bin/env sh' + LineEnding +
    'out=""' + LineEnding +
    'rsp=""' + LineEnding +
    'printf "%s\n" "$@" > "' + LinkArgvCapturePath + '"' + LineEnding +
    'while [ "$#" -gt 0 ]; do' + LineEnding +
    '  if [ "$1" = "-o" ]; then' + LineEnding +
    '    out="$2"' + LineEnding +
    '    shift 2' + LineEnding +
    '    continue' + LineEnding +
    '  fi' + LineEnding +
    '  case "$1" in' + LineEnding +
    '    @*) rsp="${1#@}" ;;' + LineEnding +
    '  esac' + LineEnding +
    '  shift' + LineEnding +
    'done' + LineEnding +
    'cp "$rsp" "' + CaptureResponsePath + '"' + LineEnding +
    'printf "fake-linked\n" > "$out"' + LineEnding
  );
  WriteExecutableScript(LinkScriptPath + '.bfd', ReadTextFile(LinkScriptPath));

  BackendPlan := TBackendPlan.Create;
  try
    EnsureRuntimeLibcFixture(ATargetFacts);
    BackendPlan.AddLogicalLibraryRequest('c', 'shared', 'strong');
    Planner := TToolchainPlanner.Create(BackendPlan, ATargetFacts, AssemblyPath);
    try
      Planner.PlanNativeAssembleLink(
        AssemblyPath,
        ObjectPath,
        OutputPath
      );
      Plan := Planner.DetachPlan;
    finally
      Planner.Free;
    end;
  finally
    BackendPlan.Free;
  end;

  SearchPath := FakeBinDir + PathSeparator + GetEnvironmentVariable('PATH');
  RunResult := ExecuteToolchainPlan(Plan, SearchPath);
  try
    WriteLn('native-run-status=', RunResult.Status);
    WriteLn('native-run-step-count=', RunResult.StepCount);
    if (RunResult.StepCount > 0) and
      (RunResult.StepAt(0).Status = 'success') then
      WriteLn('native-run-assemble-step-status=success')
    else
      WriteLn('native-run-assemble-step-status=failure');
    if (RunResult.StepCount > 1) and
      (RunResult.StepAt(1).Status = 'success') then
      WriteLn('native-run-link-step-status=success')
    else
      WriteLn('native-run-link-step-status=failure');
    if FileExists(ObjectPath) then
      WriteLn('native-run-object-exists=true')
    else
      WriteLn('native-run-object-exists=false');
    if FileExists(OutputPath) then
      WriteLn('native-run-output-exists=true')
    else
      WriteLn('native-run-output-exists=false');
    if FileExists(ResponsePath) then
      WriteLn('native-run-response-sidecar-cleaned=false')
    else
      WriteLn('native-run-response-sidecar-cleaned=true');
    if FileExists(CaptureResponsePath) then
      WriteLn('native-run-response-captured=true')
    else
      WriteLn('native-run-response-captured=false');
    if FileExists(CaptureResponsePath) and
      (Pos(
        ExpandFileName(ObjectPath),
        NormalizeWhitespace(ReadTextFile(CaptureResponsePath))
      ) > 0) then
      WriteLn('native-run-response-contains-object=true')
    else
      WriteLn('native-run-response-contains-object=false');
    if FileExists(LinkArgvCapturePath) and
      (Pos(
        '-L' + RuntimeLibRootPath(ATargetFacts),
        NormalizeWhitespace(ReadTextFile(LinkArgvCapturePath))
      ) > 0) then
      WriteLn('native-run-link-contains-runtime-root=true')
    else
      WriteLn('native-run-link-contains-runtime-root=false');
    if FileExists(LinkArgvCapturePath) and
      (Pos('-lc', NormalizeWhitespace(ReadTextFile(LinkArgvCapturePath))) > 0) then
      WriteLn('native-run-link-contains-libc=true')
    else
      WriteLn('native-run-link-contains-libc=false');
    WriteLn('native-run-transcript=', BuildRunTranscriptJson(RunResult));
  finally
    RunResult.Free;
    Plan.Free;
    DeleteFileIfExists(CaptureResponsePath);
    DeleteFileIfExists(LinkArgvCapturePath);
    RemoveRuntimeLibcFixture(ATargetFacts);
  end;
end;

procedure PrintBootstrapExecutionContract(const ATargetFacts: TTargetFactsView);
var
  AdditionalAssemblyBaseNames: TStringArray;
  ArtifactDir: string;
  AssembleScriptPath: string;
  AssemblyPath: string;
  BackendPlan: TBackendPlan;
  BootstrapFacts: TTargetFactsView;
  CaptureResponsePath: string;
  EmitScriptPath: string;
  EmptyRoots: TStringArray;
  FakeBinDir: string;
  LinkArgvCapturePath: string;
  LinkScriptPath: string;
  MainBaseName: string;
  MissingAdditionalAssemblyPath: string;
  ObjectPath: string;
  OutputPath: string;
  Plan: TToolchainPlan;
  Planner: TToolchainPlanner;
  RunResult: TToolchainRunResult;
  RunnerRoot: string;
  SearchPath: string;
  SourcePath: string;
begin
  RunnerRoot := ExpandFileName(
    IncludeTrailingPathDelimiter(ExtractFileDir(ParamStr(0))) +
    'toolchain-bootstrap-runner-fixture'
  );
  FakeBinDir := IncludeTrailingPathDelimiter(RunnerRoot) + 'bin';
  ArtifactDir := IncludeTrailingPathDelimiter(RunnerRoot) + 'artifacts';
  ForceDirectories(FakeBinDir);
  ForceDirectories(ArtifactDir);

  MainBaseName := 'bootstrap_main';
  SourcePath := IncludeTrailingPathDelimiter(ArtifactDir) + MainBaseName + '.pas';
  AssemblyPath := IncludeTrailingPathDelimiter(ArtifactDir) + MainBaseName + '.s';
  MissingAdditionalAssemblyPath := IncludeTrailingPathDelimiter(ArtifactDir) +
    'bootstrap_extra.s';
  ObjectPath := IncludeTrailingPathDelimiter(ArtifactDir) + MainBaseName + '.o';
  OutputPath := IncludeTrailingPathDelimiter(ArtifactDir) + MainBaseName;
  CaptureResponsePath := IncludeTrailingPathDelimiter(ArtifactDir) +
    'captured-bootstrap-link-argv.txt';
  LinkArgvCapturePath := CaptureResponsePath;
  EmitScriptPath := IncludeTrailingPathDelimiter(FakeBinDir) + 'fake-fpc';
  AssembleScriptPath := IncludeTrailingPathDelimiter(FakeBinDir) + 'as';
  LinkScriptPath := IncludeTrailingPathDelimiter(FakeBinDir) + 'ld';

  DeleteFileIfExists(MissingAdditionalAssemblyPath);
  WriteTextFile(SourcePath, 'program bootstrap_main; begin end.' + LineEnding);
  WriteExecutableScript(
    EmitScriptPath,
    '#!/usr/bin/env sh' + LineEnding +
    'src=""' + LineEnding +
    'outdir=""' + LineEnding +
    'while [ "$#" -gt 0 ]; do' + LineEnding +
    '  case "$1" in' + LineEnding +
    '    -FE*) outdir="${1#-FE}" ;;' + LineEnding +
    '    *.pas) src="$1" ;;' + LineEnding +
    '  esac' + LineEnding +
    '  shift' + LineEnding +
    'done' + LineEnding +
    'base=$(basename "$src" .pas)' + LineEnding +
    'printf "; fake bootstrap asm\n" > "$outdir/$base.s"' + LineEnding +
    'printf "ENTRY(_start)\nSECTIONS {}\n" > "$outdir/$base_link.res"' + LineEnding
  );
  WriteExecutableScript(
    AssembleScriptPath,
    '#!/usr/bin/env sh' + LineEnding +
    'out=""' + LineEnding +
    'infile=""' + LineEnding +
    'while [ "$#" -gt 0 ]; do' + LineEnding +
    '  if [ "$1" = "-o" ]; then' + LineEnding +
    '    out="$2"' + LineEnding +
    '    shift 2' + LineEnding +
    '    continue' + LineEnding +
    '  fi' + LineEnding +
    '  infile="$1"' + LineEnding +
    '  shift' + LineEnding +
    'done' + LineEnding +
    'if [ ! -f "$infile" ]; then' + LineEnding +
    '  exit 9' + LineEnding +
    'fi' + LineEnding +
    'printf "fake-object\n" > "$out"' + LineEnding
  );
  WriteExecutableScript(
    LinkScriptPath,
    '#!/usr/bin/env sh' + LineEnding +
    'out=""' + LineEnding +
    'printf "%s\n" "$@" > "' + LinkArgvCapturePath + '"' + LineEnding +
    'while [ "$#" -gt 0 ]; do' + LineEnding +
    '  if [ "$1" = "-o" ]; then' + LineEnding +
    '    out="$2"' + LineEnding +
    '    shift 2' + LineEnding +
    '    continue' + LineEnding +
    '  fi' + LineEnding +
    '  shift' + LineEnding +
    'done' + LineEnding +
    'printf "fake-linked\n" > "$out"' + LineEnding
  );
  WriteExecutableScript(LinkScriptPath + '.bfd', ReadTextFile(LinkScriptPath));

  BootstrapFacts := ATargetFacts;
  BootstrapFacts.CompilerExecutable := EmitScriptPath;
  SetLength(EmptyRoots, 0);
  SetLength(AdditionalAssemblyBaseNames, 1);
  AdditionalAssemblyBaseNames[0] := MissingAdditionalAssemblyPath;

  BackendPlan := TBackendPlan.Create;
  try
    BackendPlan.SetRootName(MainBaseName);
    BackendPlan.SetTargetMetadata(BootstrapFacts);
    BackendPlan.SetOutputKind('executable');
    BackendPlan.AddArtifact('assembly-text', AssemblyPath);
    BackendPlan.AddArtifact('object-file', ObjectPath);
    BackendPlan.AddArtifact('executable', OutputPath);
    BackendPlan.SetPrimaryArtifact('executable', OutputPath);
    BackendPlan.AddLogicalLibraryRequest('c', 'shared', 'strong');
    BackendPlan.MarkReady;

    EnsureRuntimeLibcFixture(BootstrapFacts);
    Planner := TToolchainPlanner.Create(
      BackendPlan,
      BootstrapFacts,
      SourcePath,
      RunnerRoot,
      EmptyRoots,
      EmptyRoots,
      AdditionalAssemblyBaseNames
    );
    try
      Planner.PlanFromBackend;
      Plan := Planner.DetachPlan;
    finally
      Planner.Free;
    end;

    try
      WriteLn('bootstrap-plan-status=', Plan.Status);
      WriteLn('bootstrap-plan-family=', Plan.PlanFamily);
      WriteLn('bootstrap-tool-invocation-count=', Plan.ToolInvocationCount);
      WriteLn(
        'bootstrap-tool-invocation-plan=',
        Plan.ToolInvocationPlanJson('plan-bootstrap-native-assemble-link', '')
      );

      SearchPath := FakeBinDir + PathSeparator + GetEnvironmentVariable('PATH');
      RunResult := ExecuteToolchainPlan(Plan, SearchPath);
      try
        WriteLn('bootstrap-run-status=', RunResult.Status);
        WriteLn('bootstrap-run-step-count=', RunResult.StepCount);
        if (RunResult.StepCount > 0) and
          (RunResult.StepAt(0).Status = 'success') then
          WriteLn('bootstrap-run-emit-step-status=success')
        else
          WriteLn('bootstrap-run-emit-step-status=failure');
        if (RunResult.StepCount > 1) and
          (RunResult.StepAt(1).Status = 'success') then
          WriteLn('bootstrap-run-main-assemble-step-status=success')
        else
          WriteLn('bootstrap-run-main-assemble-step-status=failure');
        if (RunResult.StepCount > 2) and
          (RunResult.StepAt(2).Status = 'success') then
          WriteLn('bootstrap-run-extra-assemble-step-status=success')
        else
          WriteLn('bootstrap-run-extra-assemble-step-status=failure');
        if (RunResult.StepCount > 3) and
          (RunResult.StepAt(3).Status = 'success') then
          WriteLn('bootstrap-run-link-step-status=success')
        else
          WriteLn('bootstrap-run-link-step-status=failure');
        if (RunResult.StepCount > 2) and
          SameText(RunResult.StepAt(2).StepId, 'native-assemble-bootstrap_extra') and
          (RunResult.StepAt(2).Status = 'success') and
          (not RunResult.StepAt(2).HasExitCode) and
          (RunResult.StepAt(2).ResolvedPath = '') then
          WriteLn('bootstrap-run-missing-assembly-skip=true')
        else
          WriteLn('bootstrap-run-missing-assembly-skip=false');
        WriteLn(
          'bootstrap-run-missing-assembly-step-id=',
          RunResult.StepAt(2).StepId
        );
        WriteLn(
          'bootstrap-run-missing-assembly-has-exit-code=',
          BoolToStr(RunResult.StepAt(2).HasExitCode, True)
        );
        WriteLn(
          'bootstrap-run-missing-assembly-resolved-path=',
          RunResult.StepAt(2).ResolvedPath
        );
        if FileExists(OutputPath) then
          WriteLn('bootstrap-run-output-exists=true')
        else
          WriteLn('bootstrap-run-output-exists=false');
        if FileExists(LinkArgvCapturePath) and
          (Pos('-lc', NormalizeWhitespace(ReadTextFile(LinkArgvCapturePath))) > 0) then
          WriteLn('bootstrap-run-link-contains-libc=true')
        else
          WriteLn('bootstrap-run-link-contains-libc=false');
        WriteLn('bootstrap-run-transcript=', BuildRunTranscriptJson(RunResult));
      finally
        RunResult.Free;
      end;
    finally
      Plan.Free;
    end;
  finally
    BackendPlan.Free;
    DeleteFileIfExists(LinkArgvCapturePath);
    RemoveRuntimeLibcFixture(BootstrapFacts);
  end;
end;

procedure PrintDirectLinkMissingLibcContract(const ATargetFacts: TTargetFactsView);
var
  AssemblyPath: string;
  BackendPlan: TBackendPlan;
  ObjectPath: string;
  OutputPath: string;
  Plan: TToolchainPlan;
  Planner: TToolchainPlanner;
  RunnerRoot: string;
begin
  RunnerRoot := ExpandFileName(
    IncludeTrailingPathDelimiter(ExtractFileDir(ParamStr(0))) +
    'toolchain-runner-fixture'
  );
  AssemblyPath := IncludeTrailingPathDelimiter(
    IncludeTrailingPathDelimiter(RunnerRoot) + 'artifacts'
  ) + 'hello.s';
  ObjectPath := IncludeTrailingPathDelimiter(
    IncludeTrailingPathDelimiter(RunnerRoot) + 'artifacts'
  ) + 'hello.o';
  OutputPath := IncludeTrailingPathDelimiter(
    IncludeTrailingPathDelimiter(RunnerRoot) + 'artifacts'
  ) + 'hello-missing-libc';

  RemoveRuntimeLibcFixture(ATargetFacts);
  BackendPlan := TBackendPlan.Create;
  try
    BackendPlan.AddLogicalLibraryRequest('c', 'shared', 'strong');
    Planner := TToolchainPlanner.Create(BackendPlan, ATargetFacts, AssemblyPath);
    try
      Planner.PlanNativeAssembleLink(
        AssemblyPath,
        ObjectPath,
        OutputPath
      );
      Plan := Planner.DetachPlan;
    finally
      Planner.Free;
    end;

    try
      WriteLn('direct-link-missing-libc-plan-status=', Plan.Status);
      WriteLn('direct-link-missing-libc-failure-code=', Plan.FailureCode);
      WriteLn('direct-link-missing-libc-failure-message=', Plan.FailureMessage);
    finally
      Plan.Free;
    end;
  finally
    BackendPlan.Free;
  end;
end;

procedure PrintDiagnosticsContract;
var
  WarningAsErrorSink: TDiagnosticsSink;
  WarningSink: TDiagnosticsSink;
begin
  WarningSink := TDiagnosticsSink.CreateDefault;
  try
    WarningSink.EmitWarning(
      'driver.synthetic-warning',
      'driver',
      0,
      0,
      'synthetic warning'
    );
    WriteLn('diagnostics-error-count=', WarningSink.ErrorCount);
    WriteLn('diagnostics-warning-count=', WarningSink.WarningCount);
    WriteLn('diagnostics-warning-summary=', WarningSink.Summary);
    WriteLn('diagnostics-warning-json=', WarningSink.DiagnosticsJson);
  finally
    WarningSink.Free;
  end;

  WarningAsErrorSink := TDiagnosticsSink.CreateDefault;
  try
    WarningAsErrorSink.SetWarningAsError(True);
    WarningAsErrorSink.EmitWarning(
      'driver.synthetic-warning',
      'driver',
      0,
      0,
      'synthetic warning promoted'
    );
    WriteLn(
      'diagnostics-warning-as-error-count=',
      WarningAsErrorSink.WarningCount
    );
    WriteLn(
      'diagnostics-warning-as-error-error-count=',
      WarningAsErrorSink.ErrorCount
    );
    if WarningAsErrorSink.HasErrors then
      WriteLn('diagnostics-warning-as-error-has-errors=true')
    else
      WriteLn('diagnostics-warning-as-error-has-errors=false');
    WriteLn(
      'diagnostics-warning-as-error-json=',
      WarningAsErrorSink.DiagnosticsJson
    );
  finally
    WarningAsErrorSink.Free;
  end;
end;

procedure PrintResolverIndexContract(const ATargetFacts: TTargetFactsView);
var
  Diagnostics: TDiagnosticsSink;
  ExplicitUnitRoots: TStringArray;
  FirstScanCount: LongInt;
  ProjectRootInfos: TProjectUnitRootInfoArray;
  Resolver: TUnitResolver;
  RootFileId: TSourceFileId;
  SourceDatabase: TSourceDatabase;
begin
  SourceDatabase := TSourceDatabase.Create;
  Diagnostics := TDiagnosticsSink.CreateDefault;
  SetLength(ProjectRootInfos, 0);
  SetLength(ExplicitUnitRoots, 0);
  try
    RootFileId := SourceDatabase.RegisterRootSource(
      'examples/smoke/hello_with_units.pas'
    );
    Resolver := TUnitResolver.Create(
      SourceDatabase,
      ATargetFacts,
      Diagnostics,
      RootFileId,
      ProjectRootInfos,
      ExplicitUnitRoots
    );
    try
      WriteLn(
        'resolver-search-index-status-before=',
        Resolver.SearchIndexStatus
      );
      WriteLn(
        'resolver-indexed-root-count-before=',
        Resolver.IndexedRootCount
      );
      WriteLn(
        'resolver-candidate-count=',
        Resolver.CandidateCountFor('Stage0Greeter')
      );
      FirstScanCount := Resolver.SearchIndexScanCount;
      WriteLn('resolver-search-index-scan-count=', FirstScanCount);
      WriteLn(
        'resolver-candidate-count-repeat=',
        Resolver.CandidateCountFor('Stage0Greeter')
      );
      WriteLn(
        'resolver-search-index-status-after=',
        Resolver.SearchIndexStatus
      );
      WriteLn(
        'resolver-indexed-root-count-after=',
        Resolver.IndexedRootCount
      );
      WriteLn(
        'resolver-search-index-scan-count-after-repeat=',
        Resolver.SearchIndexScanCount
      );
    finally
      Resolver.Free;
    end;
  finally
    Diagnostics.Free;
    SourceDatabase.Free;
  end;
end;

procedure PrintWorkspaceModelContract(const ATargetFacts: TTargetFactsView);
var
  ExplicitWorkspaceModel: TWorkspaceModel;
  MemberWorkspaceModel: TWorkspaceModel;
  PackageWorkspaceModel: TWorkspaceModel;
begin
  ExplicitWorkspaceModel := ResolveWorkspaceModel(
    ExpandFileName('examples/smoke/hello.pas'),
    ExpandFileName('.'),
    ATargetFacts.TargetId,
    ''
  );
  try
    WriteLn(
      'workspace-model-explicit-root=',
      ExplicitWorkspaceModel.WorkspaceRootPath
    );
    WriteLn(
      'workspace-model-explicit-discovery-kind=',
      ExplicitWorkspaceModel.DiscoveryKind
    );
    WriteLn(
      'workspace-model-explicit-descriptor-path=',
      ExplicitWorkspaceModel.WorkspaceDescriptorPath
    );
    WriteLn(
      'workspace-model-explicit-package-manifest-path=',
      ExplicitWorkspaceModel.PackageManifestPath
    );
    WriteLn(
      'workspace-model-explicit-package-ref-count=',
      ExplicitWorkspaceModel.PackageRefCount
    );
    WriteLn(
      'workspace-model-explicit-source-root-count=',
      ExplicitWorkspaceModel.SourceRootInfoCount
    );
    WriteLn(
      'workspace-model-explicit-artifact-root=',
      ExplicitWorkspaceModel.ArtifactRootPath
    );
    WriteLn(
      'workspace-model-explicit-output-dir=',
      ExplicitWorkspaceModel.OutputDirPath
    );
    WriteLn(
      'workspace-model-explicit-host-cache-root=',
      ExplicitWorkspaceModel.HostCompilerCacheRootPath
    );
  finally
    ExplicitWorkspaceModel.Free;
  end;

  PackageWorkspaceModel := ResolveWorkspaceModel(
    ExpandFileName(
      'tests/fixtures/package_manifest_source_root/app/package_manifest_source_root_smoke.pas'
    ),
    '',
    ATargetFacts.TargetId,
    ''
  );
  try
    WriteLn(
      'workspace-model-package-root=',
      PackageWorkspaceModel.WorkspaceRootPath
    );
    WriteLn(
      'workspace-model-package-discovery-kind=',
      PackageWorkspaceModel.DiscoveryKind
    );
    WriteLn(
      'workspace-model-package-package-manifest-path=',
      PackageWorkspaceModel.PackageManifestPath
    );
    WriteLn(
      'workspace-model-package-package-ref-count=',
      PackageWorkspaceModel.PackageRefCount
    );
    WriteLn(
      'workspace-model-package-source-root-count=',
      PackageWorkspaceModel.SourceRootInfoCount
    );
    WriteLn(
      'workspace-model-package-artifact-root=',
      PackageWorkspaceModel.ArtifactRootPath
    );
    WriteLn(
      'workspace-model-package-output-dir=',
      PackageWorkspaceModel.OutputDirPath
    );
  finally
    PackageWorkspaceModel.Free;
  end;

  MemberWorkspaceModel := ResolveWorkspaceModel(
    ExpandFileName(
      'tests/fixtures/workspace_member_source_root/app/app/workspace_member_source_root_smoke.pas'
    ),
    '',
    ATargetFacts.TargetId,
    ''
  );
  try
    WriteLn(
      'workspace-model-member-root=',
      MemberWorkspaceModel.WorkspaceRootPath
    );
    WriteLn(
      'workspace-model-member-discovery-kind=',
      MemberWorkspaceModel.DiscoveryKind
    );
    WriteLn(
      'workspace-model-member-descriptor-path=',
      MemberWorkspaceModel.WorkspaceDescriptorPath
    );
    WriteLn(
      'workspace-model-member-package-manifest-path=',
      MemberWorkspaceModel.PackageManifestPath
    );
    WriteLn(
      'workspace-model-member-package-ref-count=',
      MemberWorkspaceModel.PackageRefCount
    );
    WriteLn(
      'workspace-model-member-source-root-count=',
      MemberWorkspaceModel.SourceRootInfoCount
    );
    WriteLn(
      'workspace-model-member-artifact-root=',
      MemberWorkspaceModel.ArtifactRootPath
    );
    WriteLn(
      'workspace-model-member-output-dir=',
      MemberWorkspaceModel.OutputDirPath
    );
    WriteLn(
      'workspace-model-member-host-cache-root=',
      MemberWorkspaceModel.HostCompilerCacheRootPath
    );
  finally
    MemberWorkspaceModel.Free;
  end;
end;

procedure PrintPackageWorkflowContract;
var
  ManifestInfo: TPackageManifestInfo;
  WorkflowTruth: TPackageWorkflowTruth;
begin
  ManifestInfo := LoadPackageManifestInfo(
    ExpandFileName('tests/fixtures/package_manifest_source_root/nextpas.package.toml')
  );
  WorkflowTruth := BuildPackageWorkflowTruth(
    ManifestInfo,
    ExpandFileName('tests/fixtures/package_manifest_source_root')
  );
  WriteLn(
    'package-workflow-manifest-status=',
    WorkflowTruth.ManifestTruth.Status
  );
  WriteLn(
    'package-workflow-lock-status=',
    WorkflowTruth.LockTruth.Status
  );
  WriteLn(
    'package-install-plan-status=',
    WorkflowTruth.InstallPlanTruth.Status
  );
  WriteLn(
    'package-workflow-source-root-count=',
    WorkflowTruth.PackageSourceRootCount
  );
end;

var
  BaseFacts: TTargetFactsView;
  Config: TTargetConfig;
begin
  Config := LoadTargetConfig('linux-x86_64', ParamStr(0));
  BaseFacts := BuildFactsFromConfig(Config);
  PrintNativePlan(BaseFacts);
  PrintResourcePlan(BaseFacts);
  PrintArchivePlan(BaseFacts);
  PrintLlvmEnabledPlan(BaseFacts);
  PrintLlvmMissingPlan(BaseFacts);
  PrintLlvmExecutionContract(BaseFacts);
  PrintNativeExecutionContract(BaseFacts);
  PrintBootstrapExecutionContract(BaseFacts);
  PrintDirectLinkMissingLibcContract(BaseFacts);
  PrintDiagnosticsContract;
  PrintResolverIndexContract(BaseFacts);
  PrintWorkspaceModelContract(BaseFacts);
  PrintPackageWorkflowContract;
end.
