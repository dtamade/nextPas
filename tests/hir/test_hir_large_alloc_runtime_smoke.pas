program test_hir_large_alloc_runtime_smoke;

{$mode objfpc}{$H+}

uses
  Classes, SysUtils, Process, np_semantic_model, np_hir_builder,
  np_hir_llvm_emitter;

const
  LargeThreshold = 65536;
  LargeObjectPayloadSize = 70001;
  LargeDirectMappedLen = 69632;
  LargeObjectMappedLen = 73728;
  LargeMagic = '131388245100000016';

procedure Fail(const AMessage: string);
begin
  WriteLn('hir-large-alloc-runtime-smoke-failure=', AMessage);
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

function BuildAllocatorHelpers: string;
var
  SemaModel: TSemanticModel;
  Builder: THIRBuilder;
  Emitter: THIRLlvmEmitter;
  LlvmText: string;
  HelperStart: LongInt;
begin
  SemaModel := TSemanticModel.Create;
  Builder := nil;
  Emitter := nil;
  try
    SemaModel.AddTypedHirNode(
      'class-new-runtime',
      IntToStr(LargeObjectPayloadSize),
      0,
      0,
      'Worker' + #9 + 'TLarge.Create'
    );
    SemaModel.AddTypedHirNode(
      'object-free-runtime',
      'np.system.object_free',
      0,
      0,
      'var Worker' + #10 +
      'destroy TLarge.Destroy' + #10 +
      'heap-release true' + #10
    );
    SemaModel.AddTypedHirNode(
      'call-runtime',
      'TLarge.Destroy',
      0,
      0,
      'TLarge.Destroy' + #9 + 'var Worker' + #10
    );

    Builder := THIRBuilder.Create(SemaModel);
    Builder.Build;

    Emitter := THIRLlvmEmitter.Create(Builder.Module);
    Emitter.EmitModule;
    LlvmText := Emitter.AsText;

    HelperStart := Pos('@__heap_cur = internal global ptr null', LlvmText);
    if HelperStart = 0 then
      Fail('missing-allocator-helper-ir');

    Result := Copy(LlvmText, HelperStart, MaxInt);
  finally
    Emitter.Free;
    Builder.Free;
    SemaModel.Free;
  end;
end;

function ModuleHeader: string;
begin
  Result :=
    '; ModuleID = ''c6g-large-allocator-runtime-smoke''' + LineEnding +
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

function BuildDirectLargeIr(const AHelpers: string): string;
begin
  Result := ModuleHeader +
    'define i64 @_start() {' + LineEnding +
    'entry:' + LineEnding +
    '  %payload = call ptr @np_alloc(i64 ' + IntToStr(LargeThreshold) + ')' + LineEnding +
    '  store i8 17, ptr %payload' + LineEnding +
    '  %lastp = getelementptr i8, ptr %payload, i64 65535' + LineEnding +
    '  store i8 29, ptr %lastp' + LineEnding +
    '  %first = load i8, ptr %payload' + LineEnding +
    '  %first.ok = icmp eq i8 %first, 17' + LineEnding +
    '  br i1 %first.ok, label %check.last, label %fail.first' + LineEnding +
    'check.last:' + LineEnding +
    '  %last = load i8, ptr %lastp' + LineEnding +
    '  %last.ok = icmp eq i8 %last, 29' + LineEnding +
    '  br i1 %last.ok, label %check.offset, label %fail.last' + LineEnding +
    'check.offset:' + LineEnding +
    '  %payload.int = ptrtoint ptr %payload to i64' + LineEnding +
    '  %payload.off = and i64 %payload.int, 4095' + LineEnding +
    '  %payload.off.ok = icmp eq i64 %payload.off, 16' + LineEnding +
    '  br i1 %payload.off.ok, label %check.magic, label %fail.offset' + LineEnding +
    'check.magic:' + LineEnding +
    '  %base = getelementptr i8, ptr %payload, i64 -16' + LineEnding +
    '  %magic = load i64, ptr %base' + LineEnding +
    '  %magic.ok = icmp eq i64 %magic, ' + LargeMagic + LineEnding +
    '  br i1 %magic.ok, label %check.len, label %fail.magic' + LineEnding +
    'check.len:' + LineEnding +
    '  %lenp = getelementptr i8, ptr %base, i64 8' + LineEnding +
    '  %mapped.len = load i64, ptr %lenp' + LineEnding +
    '  %mapped.len.ok = icmp eq i64 %mapped.len, ' + IntToStr(LargeDirectMappedLen) + LineEnding +
    '  br i1 %mapped.len.ok, label %release, label %fail.len' + LineEnding +
    'release:' + LineEnding +
    '  call void @np_free(ptr %payload, i64 ' + IntToStr(LargeThreshold) + ')' + LineEnding +
    '  br label %pass' + LineEnding +
    ExitBlock('pass', 42) +
    ExitBlock('fail.first', 11) +
    ExitBlock('fail.last', 12) +
    ExitBlock('fail.offset', 13) +
    ExitBlock('fail.magic', 14) +
    ExitBlock('fail.len', 15) +
    '}' + LineEnding + LineEnding +
    AHelpers;
end;

function BuildObjectLargeIr(const AHelpers: string): string;
begin
  Result := ModuleHeader +
    'define i64 @TLarge.Destroy(ptr %self) {' + LineEnding +
    'entry:' + LineEnding +
    '  store i8 1, ptr %self' + LineEnding +
    '  %tailp = getelementptr i8, ptr %self, i64 70000' + LineEnding +
    '  store i8 2, ptr %tailp' + LineEnding +
    '  ret i64 0' + LineEnding +
    '}' + LineEnding + LineEnding +
    'define i64 @_start() {' + LineEnding +
    'entry:' + LineEnding +
    '  %obj = call ptr @np_object_alloc(i64 ' + IntToStr(LargeObjectPayloadSize) + ')' + LineEnding +
    '  %raw = getelementptr i8, ptr %obj, i64 -24' + LineEnding +
    '  %size = load i64, ptr %raw' + LineEnding +
    '  %size.ok = icmp eq i64 %size, ' + IntToStr(LargeObjectPayloadSize) + LineEnding +
    '  br i1 %size.ok, label %check.magic, label %fail.header.size' + LineEnding +
    'check.magic:' + LineEnding +
    '  %magicp = getelementptr i8, ptr %raw, i64 8' + LineEnding +
    '  %magic = load i64, ptr %magicp' + LineEnding +
    '  %magic.ok = icmp eq i64 %magic, 1313882451' + LineEnding +
    '  br i1 %magic.ok, label %check.raw.offset, label %fail.header.magic' + LineEnding +
    'check.raw.offset:' + LineEnding +
    '  %raw.int = ptrtoint ptr %raw to i64' + LineEnding +
    '  %raw.off = and i64 %raw.int, 4095' + LineEnding +
    '  %raw.off.ok = icmp eq i64 %raw.off, 16' + LineEnding +
    '  br i1 %raw.off.ok, label %check.obj.offset, label %fail.raw.offset' + LineEnding +
    'check.obj.offset:' + LineEnding +
    '  %obj.int = ptrtoint ptr %obj to i64' + LineEnding +
    '  %obj.off = and i64 %obj.int, 4095' + LineEnding +
    '  %obj.off.ok = icmp eq i64 %obj.off, 40' + LineEnding +
    '  br i1 %obj.off.ok, label %check.large.len, label %fail.obj.offset' + LineEnding +
    'check.large.len:' + LineEnding +
    '  %base = getelementptr i8, ptr %raw, i64 -16' + LineEnding +
    '  %large.lenp = getelementptr i8, ptr %base, i64 8' + LineEnding +
    '  %large.len = load i64, ptr %large.lenp' + LineEnding +
    '  %large.len.ok = icmp eq i64 %large.len, ' + IntToStr(LargeObjectMappedLen) + LineEnding +
    '  br i1 %large.len.ok, label %destroy, label %fail.large.len' + LineEnding +
    'destroy:' + LineEnding +
    '  %ignored = call i64 @TLarge.Destroy(ptr %obj)' + LineEnding +
    '  %first = load i8, ptr %obj' + LineEnding +
    '  %first.ok = icmp eq i8 %first, 1' + LineEnding +
    '  br i1 %first.ok, label %check.tail, label %fail.destroy.first' + LineEnding +
    'check.tail:' + LineEnding +
    '  %tailp = getelementptr i8, ptr %obj, i64 70000' + LineEnding +
    '  %tail = load i8, ptr %tailp' + LineEnding +
    '  %tail.ok = icmp eq i8 %tail, 2' + LineEnding +
    '  br i1 %tail.ok, label %release, label %fail.destroy.tail' + LineEnding +
    'release:' + LineEnding +
    '  call void @np_object_free_release(ptr %obj)' + LineEnding +
    '  br label %pass' + LineEnding +
    ExitBlock('pass', 42) +
    ExitBlock('fail.header.size', 21) +
    ExitBlock('fail.header.magic', 22) +
    ExitBlock('fail.raw.offset', 23) +
    ExitBlock('fail.obj.offset', 24) +
    ExitBlock('fail.large.len', 25) +
    ExitBlock('fail.destroy.first', 26) +
    ExitBlock('fail.destroy.tail', 27) +
    '}' + LineEnding + LineEnding +
    AHelpers;
end;

procedure AssertGeneratedContracts(const ADirectIr, AObjectIr: string);
begin
  if FindAfter('call ptr @np_alloc(i64 65536)', ADirectIr, 1) = 0 then
    Fail('missing-direct-large-alloc-call');
  if FindAfter('store i8 17, ptr %payload', ADirectIr, 1) = 0 then
    Fail('missing-direct-first-byte-write');
  if FindAfter('store i8 29, ptr %lastp', ADirectIr, 1) = 0 then
    Fail('missing-direct-last-byte-write');
  if FindAfter('call void @np_free(ptr %payload, i64 65536)', ADirectIr, 1) = 0 then
    Fail('missing-direct-free-request-size');
  if FindAfter('call ptr @np_object_alloc(i64 70001)', AObjectIr, 1) = 0 then
    Fail('missing-large-object-alloc-call');
  if FindAfter('%raw = getelementptr i8, ptr %obj, i64 -24', AObjectIr, 1) = 0 then
    Fail('missing-large-object-raw-header-base');
  if FindAfter('call void @np_object_free_release(ptr %obj)', AObjectIr, 1) = 0 then
    Fail('missing-large-object-release-call');
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
  Helpers: string;
  DirectIr: string;
  ObjectIr: string;
begin
  if ParamCount >= 1 then
    OutputDir := ParamStr(1)
  else
    OutputDir := '/tmp/nextpas-c6g-large-alloc-runtime-smoke';
  if not ForceDirectories(OutputDir) then
    Fail('create-output-dir:' + OutputDir);

  Helpers := BuildAllocatorHelpers;
  DirectIr := BuildDirectLargeIr(Helpers);
  ObjectIr := BuildObjectLargeIr(Helpers);
  AssertGeneratedContracts(DirectIr, ObjectIr);

  WriteTextFile(IncludeTrailingPathDelimiter(OutputDir) +
    'llvm_large_direct_alloc_payload.ll', DirectIr);
  WriteTextFile(IncludeTrailingPathDelimiter(OutputDir) +
    'llvm_large_object_free.ll', ObjectIr);

  WriteLn('hir-large-alloc-runtime-smoke-output-dir=', OutputDir);
  WriteLn('hir-large-alloc-runtime-smoke-direct-ir=llvm_large_direct_alloc_payload.ll');
  WriteLn('hir-large-alloc-runtime-smoke-object-ir=llvm_large_object_free.ll');
  RunRuntimeSmoke(OutputDir, 'llvm_large_direct_alloc_payload');
  WriteLn('hir-large-alloc-runtime-smoke-direct-exit=42');
  RunRuntimeSmoke(OutputDir, 'llvm_large_object_free');
  WriteLn('hir-large-alloc-runtime-smoke-object-exit=42');
  WriteLn('hir-large-alloc-runtime-smoke-status=pass');
end.
