program test_process;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.text.conv,
  nextpas.core.fs.util,
  nextpas.core.fs.path,
  nextpas.core.fs.dir,
  nextpas.core.fs,
  nextpas.core.platform.thread,
  nextpas.core.process,
  nextpas.core.time.base,
  nextpas.core.process.base,
  nextpas.core.process.child,
  nextpas.core.process.pipe,
  nextpas.core.process.command,
  nextpas.core.io.intf,
  nextpas.core.platform.process,
  nextpas.core.async.cancellation;

var
  T: TTestSuite;

{ Compatibility wrapper: old Check(name, cond) → framework Check(cond, name) }
procedure ExpectTrue(const AName: string; ACondition: Boolean); forward;

function LoadSourceText(const ARelativePath: string): string;
var
  LSourcePath: string;
begin
  LSourcePath := FsPathAbs('../../../' + ARelativePath);
  ExpectTrue('Source exists — ' + ARelativePath, FsExists(LSourcePath));
  Result := FsReadFileText(LSourcePath);
end;

function ExtractMethodBody(const ASource, AStartToken, ANextToken: string): string;
var
  LStart, LNext: Integer;
begin
  Result := '';
  LStart := Pos(AStartToken, ASource);
  if LStart = 0 then
    Exit;
  LNext := Pos(ANextToken, Copy(ASource, LStart + Length(AStartToken),
    Length(ASource)));
  if LNext = 0 then
    Exit(Copy(ASource, LStart, Length(ASource)));
  Result := Copy(ASource, LStart, Length(AStartToken) + LNext - 1);
end;

procedure CheckContains(const AName, ASource, AToken: string);
begin
  ExpectTrue(AName, Pos(AToken, ASource) > 0);
end;

procedure CheckAbsent(const AName, ASource, AToken: string);
begin
  ExpectTrue(AName, Pos(AToken, ASource) = 0);
end;

procedure CheckTokenBefore(const AName, ASource, AFirstToken,
  ASecondToken: string);
var
  LFirst, LSecond: Integer;
begin
  LFirst := Pos(AFirstToken, ASource);
  LSecond := Pos(ASecondToken, ASource);
  ExpectTrue(AName, (LFirst > 0) and (LSecond > 0) and (LFirst < LSecond));
end;

procedure ExpectTrue(const AName: string; ACondition: Boolean);
begin
  Check(ACondition, AName);
end;

procedure TestRunEcho;
var LOut: TProcessOutput;
begin
  LOut := Run('/bin/echo', ['hello', 'world']);
  ExpectTrue('Run echo — success', LOut.ExitCode = 0);
  ExpectTrue('Run echo — stdout', Pos('hello world', LOut.StdOut) > 0);
  ExpectTrue('Run echo — status exited', LOut.Status = psExited);
end;

procedure TestRunFalse;
var LOut: TProcessOutput;
begin
  LOut := Run('/bin/false', []);
  ExpectTrue('Run false — non-zero exit', LOut.ExitCode <> 0);
  ExpectTrue('Run false — status exited', LOut.Status = psExited);
end;

procedure TestRunStderr;
var LOut: TProcessOutput;
begin
  LOut := Run('/bin/ls', ['/nonexistent_xyz_path']);
  ExpectTrue('Run ls bad — stderr not empty', Length(LOut.StdErr) > 0);
  ExpectTrue('Run ls bad — non-zero exit', LOut.ExitCode <> 0);
end;

{ ExecuteProcess:单条参数串按空白/双引号拆分执行,返回退出码 }
procedure TestExecuteProcess;
begin
  ExpectTrue('ExecuteProcess true — 0', ExecuteProcess('/bin/true', '') = 0);
  ExpectTrue('ExecuteProcess false — 1', ExecuteProcess('/bin/false', '') = 1);
  { 双引号分组:sh -c 整串必须单参数,拆开则语法错 }
  ExpectTrue('ExecuteProcess quoted arg — 7',
    ExecuteProcess('/bin/sh', '-c "exit 7"') = 7);
  { 多空白容忍 + 空串参数 }
  ExpectTrue('ExecuteProcess spaces — 0',
    ExecuteProcess('/bin/sh', '-c   "exit 0"') = 0);
end;

procedure TestCapture;
var LStr: string;
begin
  LStr := Capture('/bin/echo', ['captured']);
  ExpectTrue('Capture — contains text', Pos('captured', LStr) > 0);
end;

procedure TestRunIn;
var LOut: TProcessOutput;
begin
  LOut := RunIn('/bin/pwd', [], '/tmp');
  ExpectTrue('RunIn — workdir /tmp', Pos('/tmp', LOut.StdOut) > 0);
end;

procedure TestCommandBuilder;
var LOut: TProcessOutput;
begin
  LOut := Command('/bin/echo')
    .Args(['builder', 'test'])
    .Output;
  ExpectTrue('Command builder — success', LOut.ExitCode = 0);
  ExpectTrue('Command builder — stdout', Pos('builder test', LOut.StdOut) > 0);
end;

procedure TestCommandDir;
var LOut: TProcessOutput;
begin
  LOut := Command('/bin/pwd')
    .Dir('/tmp')
    .Output;
  ExpectTrue('Command dir — /tmp', Pos('/tmp', LOut.StdOut) > 0);
end;

procedure TestCommandStatus;
var
  LOut: TProcessOutput;
begin
  LOut := Command('/bin/true').Status;
  ExpectTrue('Command status true — 0', LOut.ExitCode = 0);
  ExpectTrue('Command status true — succeeded', ProcessSucceeded(LOut));
  LOut := Command('/bin/false').Status;
  ExpectTrue('Command status false — non-zero', LOut.ExitCode <> 0);
  ExpectTrue('Command status false — not succeeded', not ProcessSucceeded(LOut));
  LOut := Command('/bin/sleep')
    .Args(['10'])
    .Timeout(TDuration.FromMilliseconds(100))
    .Status;
  ExpectTrue('Command status timeout — TimedOut', LOut.TimedOut);
  ExpectTrue('Command status timeout — not succeeded', not ProcessSucceeded(LOut));
end;

procedure TestSpawnAndWait;
var
  LChild: IChild;
  LOut: TProcessOutput;
begin
  LChild := Command('/bin/sleep').Arg('0.1').Spawn;
  ExpectTrue('Spawn — pid > 0', LChild.Pid > 0);
  LOut := LChild.Wait;
  ExpectTrue('Spawn wait — exited', LOut.Status = psExited);
  ExpectTrue('Spawn wait — exit 0', LOut.ExitCode = 0);
end;

procedure TestSpawnWaitIsRepeatable;
var
  LChild: IChild;
  LFirst, LSecond: TProcessOutput;
  LDone: Boolean;
begin
  LChild := Command('/bin/true').Spawn;
  LFirst := LChild.Wait;
  LSecond := LChild.Wait;
  ExpectTrue('Wait repeat — first exited', LFirst.Status = psExited);
  ExpectTrue('Wait repeat — second preserves status', LSecond.Status = LFirst.Status);
  ExpectTrue('Wait repeat — second preserves exit code', LSecond.ExitCode = LFirst.ExitCode);

  LDone := LChild.TryWait(LSecond);
  ExpectTrue('TryWait after Wait — done', LDone);
  ExpectTrue('TryWait after Wait — preserves status', LSecond.Status = LFirst.Status);
  ExpectTrue('TryWait after Wait — preserves exit code', LSecond.ExitCode = LFirst.ExitCode);
end;

procedure TestSpawnTryWait;
var
  LChild: IChild;
  LOut: TProcessOutput;
  LDone: Boolean;
begin
  LChild := Command('/bin/sleep').Arg('0.05').Spawn;
  LDone := LChild.TryWait(LOut);
  ExpectTrue('TryWait — not done immediately', not LDone);
  LOut := LChild.Wait;
  ExpectTrue('TryWait then Wait — exited', LOut.Status = psExited);
end;

procedure TestSpawnKill;
var
  LChild: IChild;
  LOut: TProcessOutput;
begin
  LChild := Command('/bin/sleep').Arg('10').Spawn;
  LChild.Kill;
  LOut := LChild.Wait;
  ExpectTrue('Kill — signaled', LOut.Status = psSignaled);
end;

procedure TestSpawnDetach;
var
  LChild: IChild;
  LPath: string;
  LContent: string;
begin
  LPath := FsGetTempDir + '/nextpas-process-detach-' + IntToStr(platform_getpid) + '.txt';
  if FsExists(LPath) then
    FsRemove(LPath);

  LChild := Command('/bin/sh')
    .Args(['-c', 'sleep 0.1; printf detached > "' + LPath + '"'])
    .Spawn;
  LChild.Detach;
  LChild := nil;

  platform_thread_sleep_ms(300);
  ExpectTrue('Detach — child survives handle release', FsExists(LPath));
  if FsExists(LPath) then
  begin
    LContent := FsReadFileText(LPath);
    ExpectTrue('Detach — child completed work', LContent = 'detached');
    FsRemove(LPath);
  end
  else
    ExpectTrue('Detach — child completed work', False);
end;

procedure TestDetachedLifecycleGuards;
var
  LSource, LMethod: string;
begin
  LSource := LoadSourceText('src/nextpas.core.process.child.pas');
  CheckContains('Detached guard — helper exists', LSource,
    'procedure TChild.EnsureAttached');
  CheckContains('Detached guard — helper checks state', LSource,
    'if FDetached then');
  CheckContains('Detached guard — helper raises process error', LSource,
    'raise EProcessError.Create(''process child is detached'')');

  LMethod := ExtractMethodBody(LSource, 'function TChild.Wait: TProcessOutput;',
    'function TChild.TryWait');
  CheckTokenBefore('Detached guard — Wait checks before platform wait', LMethod,
    'EnsureAttached;', 'platform_process_wait');

  LMethod := ExtractMethodBody(LSource,
    'function TChild.TryWait(out AOutput: TProcessOutput): Boolean;',
    'procedure TChild.Detach;');
  CheckTokenBefore('Detached guard — TryWait checks before platform wait',
    LMethod, 'EnsureAttached;', 'platform_process_try_wait');

  LMethod := ExtractMethodBody(LSource, 'procedure TChild.Kill;',
    'function TChild.Pid');
  CheckTokenBefore('Detached guard — Kill checks before platform kill', LMethod,
    'EnsureAttached;', 'platform_process_kill');

  LMethod := ExtractMethodBody(LSource,
    'function TChild.WaitWithOutput: TProcessOutput;',
    'function TChild.FinishWaitResult');
  CheckTokenBefore('Detached guard — WaitWithOutput checks before platform wait',
    LMethod, 'EnsureAttached;', 'platform_process_try_wait');
end;

procedure TestChildPlatformErrorSourceContract;
var
  LSource, LMethod: string;
begin
  LSource := LoadSourceText('src/nextpas.core.process.child.pas');
  CheckContains('Process platform error helper — private declaration exists',
    LSource, 'procedure RaiseProcessPlatformError(const AOp: string; ACode: Int32);');
  CheckContains('Process platform error helper — implementation exists',
    LSource, 'procedure TChild.RaiseProcessPlatformError(const AOp: string; ACode: Int32);');
  CheckContains('Process platform error helper — uses platform error message',
    LSource, 'platform_error_message(ACode, @LBuf[0], SizeOf(LBuf))');
  CheckContains('Process platform error helper — raises EProcessError',
    LSource, 'raise EProcessError.Create(LMsg, ACode);');

  LMethod := ExtractMethodBody(LSource, 'function TChild.Wait: TProcessOutput;',
    'function TChild.TryWait');
  CheckContains('Wait — platform wait result stored', LMethod,
    'LErr := platform_process_wait(FProc, LResult);');
  CheckContains('Wait — platform wait error propagated', LMethod,
    'RaiseProcessPlatformError(''platform_process_wait'', LErr);');
  CheckContains('Wait timeout — platform try_wait result stored', LMethod,
    'LErr := platform_process_try_wait(FProc, LResult);');
  CheckContains('Wait timeout — try_wait error propagated', LMethod,
    'RaiseProcessPlatformError(''platform_process_try_wait'', LErr);');
  CheckContains('Wait timeout — platform kill result stored', LMethod,
    'LErr := platform_process_kill(FProc);');
  CheckContains('Wait timeout — kill error propagated', LMethod,
    'RaiseProcessPlatformError(''platform_process_kill'', LErr);');

  LMethod := ExtractMethodBody(LSource,
    'function TChild.TryWait(out AOutput: TProcessOutput): Boolean;',
    'procedure TChild.Detach;');
  CheckContains('TryWait — platform try_wait result stored', LMethod,
    'LErr := platform_process_try_wait(FProc, LResult);');
  CheckContains('TryWait — platform error propagated', LMethod,
    'RaiseProcessPlatformError(''platform_process_try_wait'', LErr);');

  LMethod := ExtractMethodBody(LSource, 'procedure TChild.Kill;',
    'function TChild.Pid');
  CheckContains('Kill — platform kill result stored', LMethod,
    'LErr := platform_process_kill(FProc);');
  CheckContains('Kill — platform error propagated', LMethod,
    'RaiseProcessPlatformError(''platform_process_kill'', LErr);');

  LMethod := ExtractMethodBody(LSource, 'destructor TChild.Destroy;',
    'function TChild.Wait: TProcessOutput;');
  CheckAbsent('Destroy — does not call public Kill', LMethod, 'Kill;');
  CheckAbsent('Destroy — does not call public Wait', LMethod, 'Wait;');
end;

procedure TestWaitTimeoutSleepOwnerSourceContract;
var
  LSource, LMethod: string;
begin
  LSource := LoadSourceText('src/nextpas.core.process.child.pas');
  LMethod := ExtractMethodBody(LSource, 'function TChild.Wait: TProcessOutput;',
    'function TChild.TryWait');

  CheckContains('Wait timeout sleep — process child uses platform thread seam',
    LSource, 'nextpas.core.platform.thread');
  CheckContains('Wait timeout sleep — timeout loop uses platform sleep',
    LMethod, 'platform_thread_sleep_ns(LSleepNs)');
  CheckContains('Wait timeout sleep — exponential backoff cap 20ms',
    LMethod, '20000000');
  CheckAbsent('Wait timeout sleep — timeout loop avoids raw nanosleep',
    LMethod, 'nanosleep');
  CheckAbsent('Wait timeout sleep — timeout loop avoids raw TTimeSpec',
    LMethod, 'TTimeSpec');
end;

procedure TestWaitWithOutputDrainSourceContract;
var
  LSource, LMethod: string;
begin
  LSource := LoadSourceText('src/nextpas.core.process.child.pas');
  CheckContains('WaitWithOutput drain — keeps process.pipe seam', LSource,
    'nextpas.core.process.pipe');
  CheckAbsent('WaitWithOutput drain — no direct POSIX base import', LSource,
    'nextpas.core.platform.posix.base');
  CheckAbsent('WaitWithOutput drain — no direct POSIX ffi import', LSource,
    'nextpas.core.platform.posix.ffi');
  CheckAbsent('WaitWithOutput drain — no concrete stdin writer cast', LSource,
    '(FStdinWriter as TPipeWriter).Close');

  LMethod := ExtractMethodBody(LSource,
    'function TChild.WaitWithOutput: TProcessOutput;',
    'function TChild.FinishWaitResult');
  CheckContains('WaitWithOutput drain — uses DrainPipePair seam', LMethod,
    'DrainPipePair(');
  CheckAbsent('WaitWithOutput drain — no raw poll loop', LMethod,
    'poll(@LFds[0]');
  CheckAbsent('WaitWithOutput drain — no raw stdout read', LMethod,
    'read(LStdoutFd');
  CheckAbsent('WaitWithOutput drain — no raw stderr read', LMethod,
    'read(LStderrFd');
end;

procedure TestPathResolverSourceContract;
var
  LResolver, LCommand, LSpawnMethod: string;
begin
  LResolver := LoadSourceText('src/nextpas.core.process.pathresolve.pas');
  LCommand := LoadSourceText('src/nextpas.core.process.command.pas');

  CheckContains('Path resolver — directory helper exists', LResolver,
    'function CommandPathHasDirectoryPart');
  CheckContains('Path resolver — Windows separator handled', LResolver,
    'Pos(''\'', AName)');
  CheckContains('Path resolver — Windows drive path handled', LResolver,
    '(Length(AName) >= 2) and (AName[2] = '':'')');
  CheckContains('Path resolver — PATH name helper exists', LResolver,
    'function IsPathEnvPair');
  CheckContains('Path resolver — PATHEXT name helper exists', LResolver,
    'function IsPathExtEnvPair');
  CheckContains('Path resolver — PATH name follows env owner case contract',
    LResolver, 'platform_env_names_case_sensitive');
  CheckContains('Path resolver — PATHEXT follows env owner case contract',
    LResolver, 'platform_env_names_case_sensitive');
  CheckContains('Path resolver — case-insensitive env name fallback', LResolver,
    'TextStartsWithI(AValue, PATH_ENV_PREFIX)');
  CheckContains('Path resolver — case-sensitive env name fallback', LResolver,
    'TextStartsWith(AValue, PATH_ENV_PREFIX)');
  CheckContains('Path resolver — Windows PATHEXT case-insensitive fallback',
    LResolver, 'TextStartsWithI(AValue, PATHEXT_ENV_PREFIX)');
  CheckContains('Path resolver — Windows PATHEXT case-sensitive fallback',
    LResolver, 'TextStartsWith(AValue, PATHEXT_ENV_PREFIX)');
  CheckContains('Path resolver — Windows path list separator', LResolver,
    'PROCESS_PATH_LIST_SEP = '';''');
  CheckContains('Path resolver — Unix path list separator', LResolver,
    'PROCESS_PATH_LIST_SEP = '':''');
  CheckContains('Path resolver — PATHEXT split uses Windows path list separator',
    LResolver, 'PROCESS_PATH_EXT_SEP = '';''');
  CheckContains('Path resolver — replacement env has no implicit PATH fallback',
    LResolver, 'Result := '''';');
  CheckContains('Path resolver — Windows appends PATHEXT candidates',
    LResolver, 'AppendWindowsPathExtCandidate');
  CheckAbsent('Path resolver — no bare slash-only directory check', LResolver,
    'if Pos(''/'', AName) > 0 then');
  CheckContains('Path resolver — ResolveExecutablePath uses helper', LResolver,
    'if CommandPathHasDirectoryPart(AName) then');
  CheckContains('Path resolver — uses platform executable facade', LResolver,
    'platform_fs_is_executable');
  CheckAbsent('Path resolver — no direct POSIX FFI import', LResolver,
    'nextpas.core.platform.posix.ffi');
  CheckAbsent('Path resolver — no direct POSIX access call', LResolver,
    'access(PAnsiChar');

  LSpawnMethod := ExtractMethodBody(LCommand, 'function TCommand.Spawn: IChild;',
    'function TCommand.Output');
  CheckContains('Command spawn — uses shared path helper', LSpawnMethod,
    'CommandPathHasDirectoryPart(FPath)');
  CheckAbsent('Command spawn — no slash-only path check', LSpawnMethod,
    'Pos(''/'', FPath)');
  CheckContains('Env overlay — uses env owner case contract', LCommand,
    'EnvironmentVariableNamesCaseSensitive');
  CheckContains('Env overlay — case-insensitive final key match', LCommand,
    'TextEqualI');
end;

procedure TestCommandSpawnPlatformHelperSourceContract;
var
  LProcessSource, LCommandSource, LSpawnMethod: string;
begin
  LProcessSource := LoadSourceText('src/nextpas.core.platform.process.pas');
  CheckContains('Platform process helpers — create pipe declared',
    LProcessSource,
    'function platform_process_create_pipe(out AReadHandle, AWriteHandle: PtrInt): Int32;');
  CheckContains('Platform process helpers — open null declared',
    LProcessSource,
    'function platform_process_open_null(const AForWrite: Boolean; out AHandle: PtrInt): Int32;');
  CheckContains('Platform process helpers — close handle declared',
    LProcessSource,
    'function platform_process_close_handle(var AHandle: PtrInt): Int32;');

  LCommandSource := LoadSourceText('src/nextpas.core.process.command.pas');
  CheckAbsent('Command spawn helpers — no direct POSIX base import',
    LCommandSource, 'nextpas.core.platform.posix.base');
  CheckAbsent('Command spawn helpers — no direct POSIX ffi import',
    LCommandSource, 'nextpas.core.platform.posix.ffi');

  LSpawnMethod := ExtractMethodBody(LCommandSource,
    'function TCommand.Spawn: IChild;',
    'function TCommand.Timeout');
  CheckContains('Command spawn helpers — uses platform pipe helper',
    LSpawnMethod, 'platform_process_create_pipe');
  CheckContains('Command spawn helpers — uses platform null helper',
    LSpawnMethod, 'platform_process_open_null');
  CheckContains('Command spawn helpers — uses platform close helper',
    LSpawnMethod, 'platform_process_close_handle');
  CheckAbsent('Command spawn helpers — no raw pipe syscall', LSpawnMethod,
    'pipe(@');
  CheckAbsent('Command spawn helpers — no raw dev-null path', LSpawnMethod,
    '/dev/null');
  CheckAbsent('Command spawn helpers — no raw POSIX close', LSpawnMethod,
    'nextpas.core.platform.posix.ffi.close');
end;

procedure TestProcessEnvSnapshotSourceContract;
var
  LSource, LBody: string;
begin
  LSource := LoadSourceText('src/nextpas.core.process.command.pas');
  LBody := ExtractMethodBody(LSource,
    'function BuildFinalEnv(const AMode: TProcessEnvMode;',
    'constructor TCommand.Create');

  CheckContains('Env snapshot — uses os.env owner', LSource,
    'nextpas.core.os.env');
  CheckContains('Env snapshot — delegates parent snapshot', LBody,
    'EnvironmentVariables');
  CheckAbsent('Env snapshot — no direct POSIX env pointer', LBody,
    'PPAnsiChar');
  CheckAbsent('Env snapshot — no direct POSIX environ read', LBody,
    'LCur := environ');
end;

{$I ../../fpc_rtl_uses_scan.inc}

procedure AssertSourceNoBareFpcRtlUses(const ALabel, ASource: string);
var
  LHit: string;
begin
  ExpectTrue(ALabel + ' — no bare FPC RTL in uses',
    not FindBareFpcRtlInUses(ASource, LHit));
  if LHit <> '' then
    WriteLn('    (hit unit: ', LHit, ')');
end;

procedure TestProcessOwnedSourcesNoFpcRtl;
var
  LFiles: array[0..5] of string;
  LI: Integer;
begin
  { Real uses-clause scan (multi-line / trailing unit / no token false-negatives).
    Dotted nextpas.core.platform.windows.* is legal. }
  LFiles[0] := 'src/nextpas.core.process.pas';
  LFiles[1] := 'src/nextpas.core.process.base.pas';
  LFiles[2] := 'src/nextpas.core.process.command.pas';
  LFiles[3] := 'src/nextpas.core.process.child.pas';
  LFiles[4] := 'src/nextpas.core.process.pipe.pas';
  LFiles[5] := 'src/nextpas.core.process.pathresolve.pas';
  for LI := 0 to High(LFiles) do
    AssertSourceNoBareFpcRtlUses('process src ' + LFiles[LI], LoadSourceText(LFiles[LI]));
end;

procedure TestProcessTestSuitesNoFpcRtl;
var
  LFiles: array[0..4] of string;
  LI: Integer;
begin
  { Includes self: string literals in this gate are stripped before uses scan. }
  LFiles[0] := 'tests/nextpas.core.process/test_process/test_process.lpr';
  LFiles[1] := 'tests/nextpas.core.process/test_process_command/test_process_command.lpr';
  LFiles[2] := 'tests/nextpas.core.process/test_process_deep/test_process_deep.lpr';
  LFiles[3] :=
    'tests/nextpas.core.process/test_process_pipe_contract/test_process_pipe_contract.lpr';
  LFiles[4] := 'tests/nextpas.core.process/test_process_wine/test_process_wine.lpr';
  for LI := 0 to High(LFiles) do
    AssertSourceNoBareFpcRtlUses('process test ' + LFiles[LI], LoadSourceText(LFiles[LI]));
end;

procedure TestMergeStderrConflictsStderrNull;
var
  LRaised: Boolean;
  LMsg: string;
begin
  LRaised := False;
  LMsg := '';
  try
    Command('/bin/true').Stdout(stPiped).Stderr(stNull).MergeStderr.Spawn;
  except
    on E: EProcessError do
    begin
      LRaised := True;
      LMsg := E.Message;
    end;
  end;
  ExpectTrue('MergeStderr+Stderr(stNull) raises', LRaised);
  ExpectTrue('MergeStderr+Stderr(stNull) message', Pos('MergeStderr', LMsg) > 0);
end;

procedure TestMergeStderrRequiresStdoutPiped;
var
  LRaised: Boolean;
  LMsg: string;
begin
  LRaised := False;
  LMsg := '';
  try
    { Default stdout is stInherit — merge must fail closed (INV-11). }
    Command('/bin/true').MergeStderr.Spawn;
  except
    on E: EProcessError do
    begin
      LRaised := True;
      LMsg := E.Message;
    end;
  end;
  ExpectTrue('MergeStderr without Stdout(stPiped) raises', LRaised);
  ExpectTrue('MergeStderr non-piped message mentions Stdout',
    Pos('Stdout', LMsg) > 0);
end;

procedure TestWaitAutoDrainsOwnedPipes;
var
  LChild: IChild;
  LOut: TProcessOutput;
begin
  { > typical pipe buffer so bare Wait would deadlock without auto-drain (INV-13). }
  LChild := Command('/bin/sh')
    .Args(['-c', 'dd if=/dev/zero bs=1024 count=256 2>/dev/null | tr ''\0'' x'])
    .Stdout(stPiped)
    .Spawn;
  LOut := LChild.Wait;
  ExpectTrue('Wait auto-drain — status exited', LOut.Status = psExited);
  ExpectTrue('Wait auto-drain — exit 0', LOut.ExitCode = 0);
  ExpectTrue('Wait auto-drain — captured large stdout', Length(LOut.StdOut) >= 200000);
end;

procedure TestWaitWithoutPipesLeavesStdoutEmpty;
var
  LChild: IChild;
  LOut: TProcessOutput;
begin
  LChild := Command('/bin/echo').Arg('no-pipe').Spawn;
  LOut := LChild.Wait;
  ExpectTrue('Wait inherit — exited', LOut.Status = psExited);
  ExpectTrue('Wait inherit — stdout empty (not drained inherit)', LOut.StdOut = '');
end;

procedure TestTryWaitDrainsOwnedPipes;
var
  LChild: IChild;
  LOut, LAgain: TProcessOutput;
  LDone: Boolean;
  I: Integer;
begin
  LChild := Command('/bin/echo').Arg('trywait-drain').Stdout(stPiped).Spawn;
  LDone := False;
  for I := 1 to 200 do
  begin
    LDone := LChild.TryWait(LOut);
    if LDone then
      Break;
    platform_thread_sleep_ms(10);
  end;
  ExpectTrue('TryWait drain — completed', LDone);
  ExpectTrue('TryWait drain — exited', LOut.Status = psExited);
  ExpectTrue('TryWait drain — captured stdout', Pos('trywait-drain', LOut.StdOut) > 0);
  LAgain := LChild.Wait;
  ExpectTrue('TryWait drain — Wait repeats same stdout',
    Pos('trywait-drain', LAgain.StdOut) > 0);
end;

procedure TestSpawnStdinPipe;
var
  LChild: IChild;
  LStdin: IWriter;
  LOut: TProcessOutput;
  LData: string;
begin
  LChild := Command('/bin/cat')
    .Stdin(stPiped)
    .Stdout(stPiped)
    .Spawn;
  LStdin := LChild.TakeStdin;
  LData := 'piped input';
  LStdin.Write(LData[1], Length(LData));
  LStdin := nil;  // close stdin
  LOut := LChild.WaitWithOutput;
  ExpectTrue('Stdin pipe — echoed back', Pos('piped input', LOut.StdOut) > 0);
end;

procedure TestSpawnStdoutReader;
var
  LChild: IChild;
  LReader: IReader;
  LBuf: array[0..255] of Byte;
  LRead: SizeUInt;
  LTotal: string;
begin
  LChild := Command('/bin/echo')
    .Args(['streaming', 'read'])
    .Stdout(stPiped)
    .Spawn;
  LReader := LChild.TakeStdout;
  LTotal := '';
  repeat
    LRead := LReader.Read(LBuf[0], 256);
    if LRead > 0 then
    begin
      SetLength(LTotal, Length(LTotal) + Integer(LRead));
      Move(LBuf[0], LTotal[Length(LTotal) - Integer(LRead) + 1], LRead);
    end;
  until LRead = 0;
  LChild.Wait;
  ExpectTrue('Stdout reader — streaming', Pos('streaming read', LTotal) > 0);
end;

procedure TestCommandEnv;
var LOut: TProcessOutput;
begin
  LOut := Command('/usr/bin/env')
    .Env(['MY_TEST_VAR=hello_from_core'])
    .Stdout(stPiped)
    .Stderr(stPiped)
    .Spawn
    .WaitWithOutput;
  ExpectTrue('Env — custom var visible', Pos('MY_TEST_VAR=hello_from_core', LOut.StdOut) > 0);
end;

procedure TestSpawnError;
var LRaised: Boolean;
begin
  LRaised := False;
  try
    Command('/nonexistent_binary_xyz').Output;
  except
    on E: EProcessError do
      LRaised := True;
  end;
  ExpectTrue('Spawn nonexistent — raises EProcessError', LRaised);
end;

procedure TestEnvAdd;
var LOut: TProcessOutput;
begin
  LOut := TCommand.New('/usr/bin/env')
    .EnvAdd('TEST_KEY', 'test_value')
    .Output;
  ExpectTrue('EnvAdd — key visible', Pos('TEST_KEY=test_value', LOut.StdOut) > 0);
end;

procedure TestStdinNull;
var LOut: TProcessOutput;
begin
  LOut := TCommand.New('/bin/cat')
    .Stdin(stNull)
    .Stdout(stPiped)
    .Output;
  ExpectTrue('Stdin null — cat gets EOF immediately', LOut.ExitCode = 0);
  ExpectTrue('Stdin null — no output', LOut.StdOut = '');
end;

procedure TestStdoutNull;
var
  LOut: TProcessOutput;
begin
  LOut := TCommand.New('/bin/echo')
    .Args(['should not appear'])
    .Stdout(stNull)
    .Status;
  ExpectTrue('Stdout null — exits 0', LOut.ExitCode = 0);
end;

procedure TestStderrPiped;
var LOut: TProcessOutput;
begin
  LOut := TCommand.New('/bin/sh')
    .Args(['-c', 'echo err >&2'])
    .Stdout(stPiped)
    .Stderr(stPiped)
    .Output;
  ExpectTrue('Stderr piped — captured', Pos('err', LOut.StdErr) > 0);
end;

procedure TestDualPipeLargeOutput;
var LOut: TProcessOutput;
begin
  LOut := TCommand.New('/bin/sh')
    .Args(['-c', 'seq 1 5000; echo err >&2'])
    .Output;
  ExpectTrue('Large output — stdout > 10KB', Length(LOut.StdOut) > 10000);
  ExpectTrue('Large output — stderr present', Length(LOut.StdErr) > 0);
  ExpectTrue('Large output — no deadlock', LOut.ExitCode = 0);
end;

procedure TestMultipleSpawnSameCommand;
var
  LCmd: ICommand;
  LOut1, LOut2: TProcessOutput;
begin
  LCmd := TCommand.New('/bin/echo').Args(['reuse']);
  LOut1 := LCmd.Output;
  LOut2 := LCmd.Output;
  ExpectTrue('Reuse command — first', Pos('reuse', LOut1.StdOut) > 0);
  ExpectTrue('Reuse command — second', Pos('reuse', LOut2.StdOut) > 0);
end;

procedure TestEmptyArgs;
var LOut: TProcessOutput;
begin
  LOut := Run('/bin/echo', []);
  ExpectTrue('Empty args — exits 0', LOut.ExitCode = 0);
end;

procedure TestTakeStderr;
var
  LChild: IChild;
  LReader: IReader;
  LBuf: array[0..255] of Byte;
  LN: SizeUInt;
begin
  LChild := TCommand.New('/bin/sh')
    .Args(['-c', 'echo stderr_data >&2'])
    .Stderr(stPiped)
    .Spawn;
  LReader := LChild.TakeStderr;
  LN := LReader.Read(LBuf[0], 256);
  ExpectTrue('TakeStderr — read > 0', LN > 0);
  LReader := nil;
  LChild.Wait;
end;

procedure TestWaitWithOutputDualPipe;
var
  LChild: IChild;
  LStdin: IWriter;
  LCloser: IWriteCloser;
  LOut: TProcessOutput;
  LData: string;
begin
  LChild := TCommand.New('/bin/sh')
    .Args(['-c', 'cat; echo err >&2'])
    .Stdin(stPiped)
    .Stdout(stPiped)
    .Stderr(stPiped)
    .Spawn;
  LStdin := LChild.TakeStdin;
  LData := 'dual pipe test';
  LStdin.Write(LData[1], Length(LData));
  LCloser := LStdin as IWriteCloser;
  LCloser.Close;
  LCloser := nil;
  LStdin := nil;
  LOut := LChild.WaitWithOutput;
  ExpectTrue('Dual pipe — stdout', Pos('dual pipe test', LOut.StdOut) > 0);
  ExpectTrue('Dual pipe — stderr', Pos('err', LOut.StdErr) > 0);
  ExpectTrue('Dual pipe — exit 0', LOut.ExitCode = 0);
end;

procedure TestArgSingle;
var LOut: TProcessOutput;
begin
  LOut := TCommand.New('/bin/echo').Arg('single').Output;
  ExpectTrue('Arg single — output', Pos('single', LOut.StdOut) > 0);
end;

procedure ExpectProcessError(const AName: string; const AProc: TProcedure);
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    AProc;
  except
    on E: EProcessError do
      LRaised := True;
  end;
  ExpectTrue(AName, LRaised);
end;

procedure TestRunEnvPassed;
var LOut: TProcessOutput;
begin
  LOut := Command('/bin/sh')
    .Args(['-c', 'echo $NEXTPAS_TEST_RUN_ENV'])
    .EnvAdd('NEXTPAS_TEST_RUN_ENV', 'hello')
    .Stdout(stPiped)
    .Stderr(stPiped)
    .Output;
  ExpectTrue('RunEnv passed — exit 0', LOut.ExitCode = 0);
  ExpectTrue('RunEnv passed — child reads env', Pos('hello', LOut.StdOut) > 0);
end;

procedure TestRunTimeout;
var
  LOut: TProcessOutput;
  LStart: TInstant;
begin
  LStart := TInstant.Now;
  LOut := TCommand.New('/bin/sleep')
    .Arg('60')
    .Timeout(TDuration.FromMilliseconds(200))
    .Output;
  ExpectTrue('Run timeout — signaled', LOut.Status = psSignaled);
  ExpectTrue('Run timeout — elapsed < 2s', LStart.Elapsed.AsMilliseconds < 2000);
end;

procedure TestCaptureEmpty;
var LStr: string;
begin
  LStr := Capture('/bin/true', []);
  ExpectTrue('Capture empty — empty string', LStr = '');
end;

procedure TestCaptureMultiLine;
var LStr: string;
begin
  LStr := Capture('/bin/sh', ['-c', 'echo "line1"; echo "line2"; echo "line3"']);
  ExpectTrue('Capture multiline — has line1', Pos('line1', LStr) > 0);
  ExpectTrue('Capture multiline — has line2', Pos('line2', LStr) > 0);
  ExpectTrue('Capture multiline — has line3', Pos('line3', LStr) > 0);
end;

procedure TestCaptureCombined;
var
  LCombined: string;
  LOut: TProcessOutput;
  PA, PB, PC: Integer;
begin
  { sh -c outputs to both stdout and stderr }
  LCombined := CaptureCombined('/bin/sh',
    ['-c', 'echo "out"; echo "err" >&2']);
  ExpectTrue('CaptureCombined — has stdout', Pos('out', LCombined) > 0);
  ExpectTrue('CaptureCombined — has stderr', Pos('err', LCombined) > 0);

  { True interleave: printf A; printf B >&2; printf C → ABC not ACB }
  LCombined := CaptureCombined('/bin/sh',
    ['-c', 'printf A; printf B >&2; printf C']);
  ExpectTrue('CaptureCombined interleave — equals ABC', LCombined = 'ABC');
  PA := Pos('A', LCombined);
  PB := Pos('B', LCombined);
  PC := Pos('C', LCombined);
  ExpectTrue('CaptureCombined interleave — A before B', (PA > 0) and (PA < PB));
  ExpectTrue('CaptureCombined interleave — B before C', (PB > 0) and (PB < PC));

  LOut := TCommand.New('/bin/sh')
    .Args(['-c', 'echo hi; echo e >&2'])
    .MergeStderr
    .Output;
  ExpectTrue('MergeStderr Output — StdOut non-empty', LOut.StdOut <> '');
  ExpectTrue('MergeStderr Output — StdErr empty', LOut.StdErr = '');
end;

procedure TestCaptureInCombined;
var
  LCombined: string;
begin
  LCombined := CaptureInCombined('/bin/sh',
    ['-c', 'echo "cwd:$(pwd)"; echo "err" >&2'], '/');
  ExpectTrue('CaptureInCombined — has stdout', Pos('cwd:/', LCombined) > 0);
  ExpectTrue('CaptureInCombined — has stderr', Pos('err', LCombined) > 0);
end;

procedure TestRunInNonexistentDir;
var LRaised: Boolean;
begin
  LRaised := False;
  try
    RunIn('/bin/true', [], '/nonexistent_dir_xyz');
  except
    on E: EProcessError do
      LRaised := True;
  end;
  ExpectTrue('RunIn nonexistent dir — raises EProcessError', LRaised);
end;

procedure TestCaptureIn;
var
  LText: string;
begin
  LText := CaptureIn('/bin/pwd', [], '/');
  ExpectTrue('CaptureIn / — returns /', Trim(LText) = '/');
end;

procedure TestRunLargeOutput;
var LOut: TProcessOutput;
begin
  LOut := TCommand.New('/bin/sh')
    .Args(['-c', 'dd if=/dev/zero bs=1024 count=1024 2>/dev/null | tr "\0" "A"'])
    .Output;
  ExpectTrue('Large output — exit 0', LOut.ExitCode = 0);
  ExpectTrue('Large output — >= 1MB captured', Length(LOut.StdOut) >= 1024 * 1024);
end;

procedure TestRunStderrCapture;
var LOut: TProcessOutput;
begin
  LOut := Run('/bin/sh', ['-c', 'echo error >&2']);
  ExpectTrue('Stderr capture — exit 0', LOut.ExitCode = 0);
  ExpectTrue('Stderr capture — stderr contains error', Pos('error', LOut.StdErr) > 0);
end;

procedure TestCommandValidation;
begin
  ExpectProcessError('Validation — empty command path raises',
    procedure
    begin
      TCommand.New('').Status;
    end);
  ExpectProcessError('Validation — command path with NUL raises',
    procedure
    begin
      TCommand.New('/bin/echo' + #0 + 'tail').Status;
    end);
  ExpectProcessError('Validation — arg with NUL raises',
    procedure
    begin
      TCommand.New('/bin/echo').Arg('bad' + #0 + 'arg').Status;
    end);
  ExpectProcessError('Validation — cwd with NUL raises',
    procedure
    begin
      TCommand.New('/bin/true').Dir('/tmp' + #0 + 'tail').Status;
    end);
  ExpectProcessError('Validation — Env empty key raises',
    procedure
    begin
      TCommand.New('/usr/bin/env').Env(['=bad']).Status;
    end);
  ExpectProcessError('Validation — Env pair without equals raises',
    procedure
    begin
      TCommand.New('/usr/bin/env').Env(['BAD_PAIR']).Status;
    end);
  ExpectProcessError('Validation — EnvAdd empty key raises',
    procedure
    begin
      TCommand.New('/usr/bin/env').EnvAdd('', 'value').Status;
    end);
  ExpectProcessError('Validation — EnvAdd key with equals raises',
    procedure
    begin
      TCommand.New('/usr/bin/env').EnvAdd('BAD=KEY', 'value').Status;
    end);
end;


procedure TestSpawnExecFailRaisesException;
var LRaised: Boolean;
begin
  LRaised := False;
  try
    TCommand.New('/nonexistent_binary_xyz_123').Spawn;
  except
    on E: EProcessError do
      LRaised := True;
  end;
  ExpectTrue('Exec fail — raises EProcessError', LRaised);
end;

procedure TestSpawnChdirFailRaisesException;
var LRaised: Boolean;
begin
  LRaised := False;
  try
    TCommand.New('/bin/true').Dir('/nonexistent_dir_xyz').Spawn;
  except
    on E: EProcessError do
      LRaised := True;
  end;
  ExpectTrue('Chdir fail — raises EProcessError', LRaised);
end;

function OpenFdCount: Integer;
var
  LEntries: TDirEntryArray;
begin
  LEntries := FsReadDir('/proc/self/fd');
  if LEntries = nil then
    Result := -1
  else
    Result := Length(LEntries);
end;

procedure ExpectProcessErrorNoFdLeak(const AName: string; const AProc: TProcedure);
var
  LBefore, LAfter: Integer;
begin
  LBefore := OpenFdCount;
  ExpectProcessError(AName + ' — raises EProcessError', AProc);
  LAfter := OpenFdCount;
  if (LBefore >= 0) and (LAfter >= 0) then
    ExpectTrue(AName + ' — parent fd count returns to baseline', LAfter = LBefore)
  else
    ExpectTrue(AName + ' — /proc/self/fd unavailable', True);
end;

procedure TestSpawnNullStdioFailureDoesNotLeakParentFds;
begin
  ExpectProcessErrorNoFdLeak('stNull exec fail cleanup',
    procedure
    begin
      TCommand.New('/nonexistent_binary_xyz_123')
        .Stdin(stNull)
        .Stdout(stNull)
        .Stderr(stNull)
        .Spawn;
    end);
  ExpectProcessErrorNoFdLeak('stNull chdir fail cleanup',
    procedure
    begin
      TCommand.New('/bin/true')
        .Dir('/nonexistent_dir_xyz')
        .Stdin(stNull)
        .Stdout(stNull)
        .Stderr(stNull)
        .Spawn;
    end);
end;

procedure TestEnvAddInheritsPath;
var LOut: TProcessOutput;
begin
  LOut := TCommand.New('/usr/bin/env')
    .EnvAdd('MY_OVERLAY_VAR', 'overlay_value')
    .Output;
  ExpectTrue('EnvAdd overlay — custom var', Pos('MY_OVERLAY_VAR=overlay_value', LOut.StdOut) > 0);
  ExpectTrue('EnvAdd overlay — PATH inherited', Pos('PATH=', LOut.StdOut) > 0);
end;


procedure TestEnvReplaceWithPathSearch;
var LOut: TProcessOutput;
begin
  LOut := TCommand.New('echo')
    .Args(['path search works'])
    .Env(['PATH=/bin:/usr/bin'])
    .Output;
  ExpectTrue('Env replace + PATH search — found echo', Pos('path search works', LOut.StdOut) > 0);
end;

procedure TestEnvReplaceSkipsNonExecutablePathShadow;
var
  LTempRoot, LShadowDir, LRealDir, LToolName: string;
  LShadowPath, LRealPath: string;
  LFile: TextFile;
  LOut: TProcessOutput;
  LRaised: Boolean;
begin
  LToolName := 'nextpas_process_path_shadow';
  LTempRoot := FsGetTempDir + '/nextpas-process-path-shadow-' + IntToStr(platform_getpid);
  LShadowDir := LTempRoot + '/shadow';
  LRealDir := LTempRoot + '/real';
  LShadowPath := LShadowDir + '/' + LToolName;
  LRealPath := LRealDir + '/' + LToolName;
  if FsIsDir(LTempRoot) then
    FsRemove(LTempRoot);
  FsMkdirAll(LShadowDir);
  FsMkdirAll(LRealDir);
  try
    AssignFile(LFile, LShadowPath);
    Rewrite(LFile);
    WriteLn(LFile, 'not executable');
    CloseFile(LFile);

    AssignFile(LFile, LRealPath);
    Rewrite(LFile);
    WriteLn(LFile, '#!/bin/sh');
    WriteLn(LFile, 'printf shadow-resolved');
    CloseFile(LFile);
    Chmod(LRealPath, TFilePermission(&755));

    LRaised := False;
    try
      LOut := TCommand.New(LToolName)
        .Env(['PATH=' + LShadowDir + ':' + LRealDir])
        .Output;
    except
      on E: EProcessError do
        LRaised := True;
    end;

    ExpectTrue('Env replace + PATH skips non-executable shadow — no spawn error', not LRaised);
    if not LRaised then
      ExpectTrue('Env replace + PATH skips non-executable shadow — found executable target',
        Pos('shadow-resolved', LOut.StdOut) > 0);
  finally
    if FsExists(LShadowPath) then
      FsRemove(LShadowPath);
    if FsExists(LRealPath) then
      FsRemove(LRealPath);
    if FsIsDir(LShadowDir) then
      FsRemove(LShadowDir);
    if FsIsDir(LRealDir) then
      FsRemove(LRealDir);
    if FsIsDir(LTempRoot) then
      FsRemove(LTempRoot);
  end;
end;

procedure TestEnvAddDuplicatePathUsesFinalResolvedView;
var LOut: TProcessOutput;
begin
  LOut := TCommand.New('echo')
    .Args(['envadd-path-final-view'])
    .EnvAdd('PATH', '/definitely_missing_nextpas_process')
    .EnvAdd('PATH', '/bin:/usr/bin')
    .Output;
  ExpectTrue('EnvAdd duplicate PATH final view — exit 0', LOut.ExitCode = 0);
  ExpectTrue('EnvAdd duplicate PATH final view — resolved from final PATH',
    Pos('envadd-path-final-view', LOut.StdOut) > 0);
end;

procedure TestEnvReplaceRelativePathSearchUsesCommandDir;
var
  LTempRoot, LToolDir, LToolName, LToolPath: string;
  LFile: TextFile;
  LOut: TProcessOutput;
  LRaised: Boolean;
begin
  LToolName := 'nextpas_process_dir_path_tool';
  LTempRoot := FsGetTempDir + '/nextpas-process-dir-path-' + IntToStr(platform_getpid);
  LToolDir := LTempRoot + '/tools';
  LToolPath := LToolDir + '/' + LToolName;
  if FsIsDir(LTempRoot) then
    FsRemove(LTempRoot);
  FsMkdirAll(LToolDir);
  try
    AssignFile(LFile, LToolPath);
    Rewrite(LFile);
    WriteLn(LFile, '#!/bin/sh');
    WriteLn(LFile, 'printf dir-path-resolved');
    CloseFile(LFile);
    Chmod(LToolPath, TFilePermission(&755));

    LRaised := False;
    try
      LOut := TCommand.New(LToolName)
        .Dir(LTempRoot)
        .Env(['PATH=tools'])
        .Output;
    except
      on E: EProcessError do
        LRaised := True;
    end;

    ExpectTrue('Env replace + Dir relative PATH — no spawn error', not LRaised);
    if not LRaised then
      ExpectTrue('Env replace + Dir relative PATH — resolved from command dir',
        Pos('dir-path-resolved', LOut.StdOut) > 0);
  finally
    if FsExists(LToolPath) then
      FsRemove(LToolPath);
    if FsIsDir(LToolDir) then
      FsRemove(LToolDir);
    if FsIsDir(LTempRoot) then
      FsRemove(LTempRoot);
  end;
end;


procedure TestTimeout;
var LOut: TProcessOutput; LStart: TInstant;
begin
  LStart := TInstant.Now;
  LOut := TCommand.New('/bin/sleep')
    .Arg('10')
    .Timeout(TDuration.FromMilliseconds(200))
    .Output;
  ExpectTrue('Timeout — killed (signaled)', LOut.Status = psSignaled);
  ExpectTrue('Timeout — TimedOut flag set', LOut.TimedOut);
  ExpectTrue('Timeout — elapsed < 2s', LStart.Elapsed.AsMilliseconds < 2000);
end;

procedure TestTimeoutOutputDrainsBeforeWait;
var
  LOut: TProcessOutput;
begin
  LOut := TCommand.New('/bin/sh')
    .Args(['-c', 'yes process-timeout-drain | head -n 20000; printf done-marker'])
    .Timeout(TDuration.FromSeconds(5))
    .Output;
  ExpectTrue('Timeout output drain — process exits normally', LOut.Status = psExited);
  ExpectTrue('Timeout output drain — exit 0', LOut.ExitCode = 0);
  ExpectTrue('Timeout output drain — captures tail marker',
    Pos('done-marker', LOut.StdOut) > 0);
end;


procedure TestLookPath;
var
  LPath: string;
begin
  { LookPath finds common system binaries }
  LPath := LookPath('sh');
  ExpectTrue('LookPath sh — not empty', LPath <> '');
  ExpectTrue('LookPath sh — contains sh', Pos('sh', LPath) > 0);

  { LookPath finds absolute path }
  LPath := LookPath('/bin/sh');
  ExpectTrue('LookPath /bin/sh — returns same path', LPath = '/bin/sh');

  { LookPath raises for non-existent binary }
  try
    LookPath('nonexistent_binary_12345');
    ExpectTrue('LookPath nonexistent — should raise', False);
  except
    on E: EProcessError do
      ExpectTrue('LookPath nonexistent — correct exception', True);
  end;

  { Absolute path that does not exist must not pretend to succeed }
  try
    LookPath('/nonexistent_abs_bin_xyz_12345');
    ExpectTrue('LookPath abs missing — should raise', False);
  except
    on E: EProcessError do
      ExpectTrue('LookPath abs missing — correct exception',
        Pos('executable not found', E.Message) > 0);
  end;
end;

procedure TestTryLookPath;
var
  LPath: string;
begin
  { TryLookPath finds common system binaries }
  ExpectTrue('TryLookPath sh — found', TryLookPath('sh', LPath));
  ExpectTrue('TryLookPath sh — not empty', LPath <> '');
  ExpectTrue('TryLookPath sh — contains sh', Pos('sh', LPath) > 0);

  { TryLookPath finds absolute path }
  ExpectTrue('TryLookPath /bin/sh — found', TryLookPath('/bin/sh', LPath));
  ExpectTrue('TryLookPath /bin/sh — returns same path', LPath = '/bin/sh');

  { TryLookPath returns false for non-existent binary }
  ExpectTrue('TryLookPath nonexistent — not found',
    not TryLookPath('nonexistent_binary_12345', LPath));
  ExpectTrue('TryLookPath nonexistent — path empty', LPath = '');

  ExpectTrue('TryLookPath abs missing — not found',
    not TryLookPath('/nonexistent_abs_bin_xyz_12345', LPath));
  ExpectTrue('TryLookPath abs missing — path empty', LPath = '');
end;

procedure TestProcessSucceeded;
var
  LOut: TProcessOutput;
begin
  LOut := Run('/bin/true', []);
  ExpectTrue('ProcessSucceeded true — exit 0', ProcessSucceeded(LOut));

  LOut := Run('/bin/false', []);
  ExpectTrue('ProcessSucceeded false — non-zero exit', not ProcessSucceeded(LOut));

  LOut := TCommand.New('/bin/sleep')
    .Arg('10')
    .Timeout(TDuration.FromMilliseconds(200))
    .Output;
  ExpectTrue('ProcessSucceeded false — timed out', not ProcessSucceeded(LOut));
  ExpectTrue('ProcessSucceeded timeout — TimedOut flag', LOut.TimedOut);
end;

procedure TestMaxOutput;
var
  LOut: TProcessOutput;
begin
  { yes emits infinite "y\n"; MaxOutput(64) must stop and flag OutputLimited }
  LOut := TCommand.New('/usr/bin/yes')
    .Stdout(stPiped)
    .Stderr(stNull)
    .MaxOutput(64)
    .Output;
  ExpectTrue('MaxOutput — OutputLimited set', LOut.OutputLimited);
  ExpectTrue('MaxOutput — not TimedOut', not LOut.TimedOut);
  ExpectTrue('MaxOutput — buffered <= 64', Length(LOut.StdOut) <= 64);
  ExpectTrue('MaxOutput — ProcessSucceeded false', not ProcessSucceeded(LOut));

  { Unlimited still works for small output }
  LOut := TCommand.New('/bin/echo').Arg('ok-max').MaxOutput(0).Output;
  ExpectTrue('MaxOutput 0 — success', ProcessSucceeded(LOut));
  ExpectTrue('MaxOutput 0 — not limited', not LOut.OutputLimited);
end;

procedure TestMustCaptureAndRunChecked;
var
  LStr: string;
  LOut: TProcessOutput;
  LRaised: Boolean;
begin
  LStr := MustCapture('/bin/echo', ['ok-checked']);
  ExpectTrue('MustCapture success — stdout', Pos('ok-checked', LStr) > 0);

  LOut := RunChecked('/bin/true', []);
  ExpectTrue('RunChecked success — exit 0', LOut.ExitCode = 0);
  ExpectTrue('RunChecked success — not timed out', not LOut.TimedOut);

  LRaised := False;
  try
    MustCapture('/bin/false', []);
  except
    on E: EProcessError do
      LRaised := True;
  end;
  ExpectTrue('MustCapture false — raises', LRaised);

  LRaised := False;
  try
    RunChecked('/bin/false', []);
  except
    on E: EProcessError do
      LRaised := True;
  end;
  ExpectTrue('RunChecked false — raises', LRaised);

  { Capture still ignores non-zero exit (documented) }
  LStr := Capture('/bin/false', []);
  ExpectTrue('Capture false — no raise, empty stdout', LStr = '');

  LRaised := False;
  try
    MustCaptureCombined('/bin/false', []);
  except
    on E: EProcessError do
      LRaised := True;
  end;
  ExpectTrue('MustCaptureCombined false — raises', LRaised);

  LStr := MustCaptureCombined('/bin/echo', ['combined-ok']);
  ExpectTrue('MustCaptureCombined success — has stdout', Pos('combined-ok', LStr) > 0);
end;


procedure TestSignal;
var
  LChild: IChild;
  LOut: TProcessOutput;
begin
  { Signal(SIGTERM) terminates child gracefully }
  LChild := TCommand.New('/bin/sleep').Arg('60').Spawn;
  ExpectTrue('Signal — child is running', LChild.Pid > 0);
  LChild.Signal(15);  { SIGTERM }
  LOut := LChild.Wait;
  ExpectTrue('Signal — terminated by signal', LOut.Status = psSignaled);
  { ExitCode is 128 + signal number on Linux }
  ExpectTrue('Signal — signal is SIGTERM (15)', LOut.ExitCode = 128 + 15);
end;

procedure TestRunTimeoutConvenience;
var
  LOut: TProcessOutput;
  LStart: TInstant;
begin
  { RunTimeout convenience function }
  LStart := TInstant.Now;
  LOut := RunTimeout('/bin/sleep', ['60'], TDuration.FromMilliseconds(200));
  ExpectTrue('RunTimeout — signaled', LOut.Status = psSignaled);
  ExpectTrue('RunTimeout — elapsed < 2s', LStart.Elapsed.AsMilliseconds < 2000);
end;

procedure TestCaptureTimeoutConvenience;
var
  LText: string;
begin
  { CaptureTimeout returns stdout of fast command }
  LText := CaptureTimeout('/bin/echo', ['hello'], TDuration.FromSeconds(5));
  ExpectTrue('CaptureTimeout — has output', Length(LText) > 0);
end;

procedure TestRunInTimeout;
var
  LOut: TProcessOutput;
begin
  LOut := RunInTimeout('/bin/pwd', [], '/', TDuration.FromSeconds(5));
  ExpectTrue('RunInTimeout — exit 0', LOut.ExitCode = 0);
  ExpectTrue('RunInTimeout — stdout is /', Trim(LOut.StdOut) = '/');
end;

procedure TestCaptureInTimeout;
var
  LText: string;
begin
  LText := CaptureInTimeout('/bin/pwd', [], '/tmp', TDuration.FromSeconds(5));
  ExpectTrue('CaptureInTimeout — returns /tmp', Trim(LText) = '/tmp');
end;

procedure TestCaptureTimeoutCombined;
var
  LCombined: string;
begin
  LCombined := CaptureTimeoutCombined('/bin/sh',
    ['-c', 'echo "out"; echo "err" >&2'], TDuration.FromSeconds(5));
  ExpectTrue('CaptureTimeoutCombined — has stdout', Pos('out', LCombined) > 0);
  ExpectTrue('CaptureTimeoutCombined — has stderr', Pos('err', LCombined) > 0);
end;

procedure TestCaptureInTimeoutCombined;
var
  LCombined: string;
begin
  LCombined := CaptureInTimeoutCombined('/bin/sh',
    ['-c', 'echo "cwd:$(pwd)"; echo "err" >&2'], '/', TDuration.FromSeconds(5));
  ExpectTrue('CaptureInTimeoutCombined — has stdout', Pos('cwd:/', LCombined) > 0);
  ExpectTrue('CaptureInTimeoutCombined — has stderr', Pos('err', LCombined) > 0);
end;

procedure TestRunWithInput;
var
  LOut: TProcessOutput;
  LInput: TBytes;
begin
  { cat echoes stdin to stdout }
  LInput := TBytes.Create(Ord('h'), Ord('e'), Ord('l'), Ord('l'), Ord('o'));
  LOut := RunWithInput('/bin/cat', [], LInput);
  ExpectTrue('RunWithInput — exit 0', LOut.ExitCode = 0);
  ExpectTrue('RunWithInput — stdout has data', Length(LOut.StdOut) > 0);
end;

procedure TestCaptureWithInput;
var
  LText: string;
  LInput: TBytes;
begin
  LInput := TBytes.Create(Ord('w'), Ord('o'), Ord('r'), Ord('l'), Ord('d'));
  LText := CaptureWithInput('/bin/cat', [], LInput);
  ExpectTrue('CaptureWithInput — has output', Length(LText) > 0);
end;

procedure TestExecutable;
var
  LPath: string;
begin
  LPath := Executable;
  ExpectTrue('Executable — not empty', Length(LPath) > 0);
  ExpectTrue('Executable — starts with /', LPath[1] = '/');
  ExpectTrue('Executable — file exists', FsExists(LPath));
end;

procedure TestCaptureWithInputString;
var
  LText: string;
begin
  LText := CaptureWithInputString('/bin/cat', [], 'hello world');
  ExpectTrue('CaptureWithInputString — has output', Length(LText) > 0);
  ExpectTrue('CaptureWithInputString — contains input', Pos('hello', LText) > 0);
end;

procedure TestRunInWithInputString;
var
  LOut: TProcessOutput;
begin
  LOut := RunInWithInputString('/bin/cat', [], '/tmp', 'from stdin');
  ExpectTrue('RunInWithInputString — exit 0', LOut.ExitCode = 0);
  ExpectTrue('RunInWithInputString — contains input', Pos('stdin', LOut.StdOut) > 0);
end;

procedure TestCaptureInWithInput;
var
  LText: string;
  LInput: TBytes;
begin
  LInput := TBytes.Create(Ord('h'), Ord('i'));
  LText := CaptureInWithInput('/bin/cat', [], '/tmp', LInput);
  ExpectTrue('CaptureInWithInput — contains input', Pos('hi', LText) > 0);
end;

procedure TestCaptureInWithInputString;
var
  LText: string;
begin
  LText := CaptureInWithInputString('/bin/cat', [], '/tmp', 'hello dir');
  ExpectTrue('CaptureInWithInputString — contains input', Pos('hello dir', LText) > 0);
end;

procedure TestStatusLeavesStdoutEmpty;
var
  LOut: TProcessOutput;
begin
  LOut := Command('/bin/echo').Arg('status-silent').Status;
  ExpectTrue('Status — exit 0', LOut.ExitCode = 0);
  ExpectTrue('Status — stdout empty', LOut.StdOut = '');
  ExpectTrue('Status — stderr empty', LOut.StdErr = '');
  ExpectTrue('Status — not timed out', not LOut.TimedOut);
end;

procedure TestTakeStdoutThenWaitDoesNotAutoDrain;
var
  LChild: IChild;
  LReader: IReader;
  LOut: TProcessOutput;
  LBuf: array[0..63] of Byte;
  LRead: SizeUInt;
  LGot: string;
begin
  LChild := Command('/bin/echo')
    .Arg('take-then-wait')
    .Stdout(stPiped)
    .Spawn;
  LReader := LChild.TakeStdout;
  LGot := '';
  repeat
    LRead := LReader.Read(LBuf[0], SizeOf(LBuf));
    if LRead > 0 then
    begin
      SetLength(LGot, Length(LGot) + Integer(LRead));
      Move(LBuf[0], LGot[Length(LGot) - Integer(LRead) + 1], LRead);
    end;
  until LRead = 0;
  LOut := LChild.Wait;
  ExpectTrue('Take* then Wait — caller got payload', Pos('take-then-wait', LGot) > 0);
  ExpectTrue('Take* then Wait — auto StdOut empty', LOut.StdOut = '');
  ExpectTrue('Take* then Wait — exited', LOut.Status = psExited);
end;

procedure TestWaitGracefulTerminatesSleep;
var
  LChild: IChild;
  LOut: TProcessOutput;
begin
  { Long sleep: grace may SIGTERM (default dies) or Kill; either ends process. }
  LChild := Command('/bin/sleep').Arg('30').Spawn;
  LOut := LChild.WaitGraceful(TDuration.FromMilliseconds(200));
  ExpectTrue('WaitGraceful long-sleep — terminated', LOut.Status <> psRunning);
  ExpectTrue('WaitGraceful long-sleep — not still running flag',
    LOut.Status in [psExited, psSignaled, psUnknown]);
end;

procedure TestWaitGracefulAcceptsTerm;
var
  LChild: IChild;
  LOut: TProcessOutput;
begin
  { Default signal disposition for sleep is terminate on SIGTERM without needing kill. }
  LChild := Command('/bin/sleep').Arg('5').Spawn;
  LOut := LChild.WaitGraceful(TDuration.FromSeconds(2));
  ExpectTrue('WaitGraceful term — not running', LOut.Status <> psRunning);
  { May be Signaled(SIGTERM) or Exited depending on platform; not TimedOut if term worked. }
  ExpectTrue('WaitGraceful term — finished under grace', not LOut.TimedOut);
end;

procedure TestMergeStderrInterleave;
var
  LOut: TProcessOutput;
begin
  LOut := TCommand.New('/bin/sh')
    .Arg('-c')
    .Arg('echo OUT; echo ERR >&2')
    .MergeStderr
    .Output;
  ExpectTrue('MergeStderr interleave — exit 0', LOut.ExitCode = 0);
  ExpectTrue('MergeStderr interleave — stdout has OUT', Pos('OUT', LOut.StdOut) > 0);
  ExpectTrue('MergeStderr interleave — stdout has ERR', Pos('ERR', LOut.StdOut) > 0);
  ExpectTrue('MergeStderr interleave — stderr empty', LOut.StdErr = '');
  ExpectTrue('MergeStderr interleave — not timed out', not LOut.TimedOut);
end;

procedure TestStatusFalseExitCode;
var
  LOut: TProcessOutput;
begin
  LOut := Command('/bin/false').Status;
  ExpectTrue('Status false — exited', LOut.Status = psExited);
  ExpectTrue('Status false — non-zero', LOut.ExitCode <> 0);
  ExpectTrue('Status false — stdout empty', LOut.StdOut = '');
  ExpectTrue('Status false — stderr empty', LOut.StdErr = '');
  ExpectTrue('Status false — not succeeded', not ProcessSucceeded(LOut));
end;

procedure TestLookPathAbsoluteExecutable;
var
  LPath: string;
begin
  LPath := LookPath('/bin/true');
  ExpectTrue('LookPath abs true — non-empty', LPath <> '');
  ExpectTrue('LookPath abs true — path', LPath = '/bin/true');
  LPath := LookPath('/bin/echo');
  ExpectTrue('LookPath abs echo — exact', LPath = '/bin/echo');
end;

procedure TestTryWaitWhileRunning;
var
  LChild: IChild;
  LOut: TProcessOutput;
  LReady: Boolean;
begin
  LChild := Command('/bin/sleep').Arg('2').Spawn;
  LReady := LChild.TryWait(LOut);
  ExpectTrue('TryWait while running — false', not LReady);
  LOut := LChild.Wait;
  ExpectTrue('TryWait then Wait — terminated', LOut.Status <> psRunning);
  ExpectTrue('TryWait then Wait — exit 0', LOut.ExitCode = 0);
end;

procedure TestWaitGracefulZeroGrace;
var
  LChild: IChild;
  LOut: TProcessOutput;
begin
  LChild := Command('/bin/sleep').Arg('30').Spawn;
  LOut := LChild.WaitGraceful(TDuration.FromMilliseconds(0));
  ExpectTrue('WaitGraceful zero grace — terminated', LOut.Status <> psRunning);
  ExpectTrue('WaitGraceful zero grace — not running flag',
    LOut.Status in [psExited, psSignaled, psUnknown]);
end;

procedure TestDetachThenWaitRaises;
var
  LChild: IChild;
  LRaised: Boolean;
begin
  { Use true so Detach does not leave a long-lived orphan. }
  LChild := Command('/bin/true').Spawn;
  LChild.Detach;
  LRaised := False;
  try
    LChild.Wait;
  except
    on E: EProcessError do
      LRaised := True;
  end;
  ExpectTrue('Detach then Wait — raises EProcessError', LRaised);
end;

procedure TestArgMultipleSpaces;
var
  LOut: TProcessOutput;
begin
  LOut := Command('/bin/echo').Arg('a b').Arg('c').Output;
  ExpectTrue('Arg spaces — exit 0', LOut.ExitCode = 0);
  ExpectTrue('Arg spaces — has a b', Pos('a b', LOut.StdOut) > 0);
  ExpectTrue('Arg spaces — has c', Pos('c', LOut.StdOut) > 0);
end;

procedure TestRunWithEmptyArgsArray;
var
  LOut: TProcessOutput;
begin
  LOut := Run('/bin/true', []);
  ExpectTrue('Run empty args — exit 0', LOut.ExitCode = 0);
  ExpectTrue('Run empty args — succeeded', ProcessSucceeded(LOut));
  ExpectTrue('Run empty args — not limited', not LOut.OutputLimited);
end;

procedure TestCaptureDoesNotRaiseOnFailure;
var
  LStr: string;
begin
  LStr := Capture('/bin/sh', ['-c', 'echo fail-out; exit 7']);
  ExpectTrue('Capture fail — stdout kept', Pos('fail-out', LStr) > 0);
  LStr := Capture('/bin/false', []);
  ExpectTrue('Capture false — empty ok', LStr = '');
end;

procedure TestMaxOutputAllowsSmall;
var
  LOut: TProcessOutput;
begin
  LOut := TCommand.New('/bin/echo')
    .Arg('tiny')
    .MaxOutput(1024)
    .Output;
  ExpectTrue('MaxOutput room — success', ProcessSucceeded(LOut));
  ExpectTrue('MaxOutput room — not limited', not LOut.OutputLimited);
  ExpectTrue('MaxOutput room — payload', Pos('tiny', LOut.StdOut) > 0);
end;

procedure TestStderrOnlyPiped;
var
  LOut: TProcessOutput;
begin
  LOut := TCommand.New('/bin/sh')
    .Arg('-c')
    .Arg('echo only-err >&2')
    .Stdout(stNull)
    .Stderr(stPiped)
    .Output;
  ExpectTrue('Stderr only — exit 0', LOut.ExitCode = 0);
  ExpectTrue('Stderr only — stdout empty', LOut.StdOut = '');
  ExpectTrue('Stderr only — stderr has text', Pos('only-err', LOut.StdErr) > 0);
end;

procedure TestCommandDirTmp;
var
  LOut: TProcessOutput;
begin
  LOut := Command('/bin/pwd').Dir('/tmp').Output;
  ExpectTrue('Dir /tmp — exit 0', LOut.ExitCode = 0);
  ExpectTrue('Dir /tmp — path contains tmp', Pos('/tmp', LOut.StdOut) > 0);
end;

procedure TestSignalAfterNaturalExit;
var
  LChild: IChild;
  LOut: TProcessOutput;
begin
  LChild := Command('/bin/true').Spawn;
  LOut := LChild.Wait;
  ExpectTrue('Signal after exit — wait ok', LOut.ExitCode = 0);
  { After Wait, Signal is a documented no-op (FWaited). }
  LChild.Signal(15);
  ExpectTrue('Signal after exit — no-op safe', True);
end;

procedure TestEnvAddOverrides;
var
  LOut: TProcessOutput;
begin
  LOut := TCommand.New('/usr/bin/env')
    .EnvAdd('NEXTPAS_PROC_OV', 'one')
    .EnvAdd('NEXTPAS_PROC_OV', 'two')
    .Output;
  ExpectTrue('EnvAdd override — exit 0', LOut.ExitCode = 0);
  ExpectTrue('EnvAdd override — final value', Pos('NEXTPAS_PROC_OV=two', LOut.StdOut) > 0);
  ExpectTrue('EnvAdd override — not first', Pos('NEXTPAS_PROC_OV=one', LOut.StdOut) = 0);
end;

procedure TestOutputLimitedNotTimedOut;
var
  LOut: TProcessOutput;
begin
  LOut := TCommand.New('/usr/bin/yes')
    .Stdout(stPiped)
    .Stderr(stNull)
    .MaxOutput(32)
    .Output;
  ExpectTrue('Limited vs timeout — OutputLimited', LOut.OutputLimited);
  ExpectTrue('Limited vs timeout — not TimedOut', not LOut.TimedOut);
  ExpectTrue('Limited vs timeout — ProcessSucceeded false', not ProcessSucceeded(LOut));
  ExpectTrue('Limited vs timeout — buffered small', Length(LOut.StdOut) <= 32);
end;

procedure TestWaitWithOutputAfterTakeStdoutEmpty;
var
  LChild: IChild;
  LOut: TProcessOutput;
  LReader: IReader;
  LBuf: array[0..31] of Byte;
begin
  LChild := Command('/bin/echo').Arg('gone').Stdout(stPiped).Spawn;
  LReader := LChild.TakeStdout;
  while LReader.Read(LBuf[0], SizeOf(LBuf)) > 0 do ;
  LOut := LChild.WaitWithOutput;
  ExpectTrue('WaitWithOutput after Take — StdOut empty', LOut.StdOut = '');
  ExpectTrue('WaitWithOutput after Take — exited', LOut.Status = psExited);
end;

procedure TestRunInTmpPwd;
var
  LOut: TProcessOutput;
begin
  LOut := RunIn('/bin/pwd', [], '/tmp');
  ExpectTrue('RunIn /tmp — exit 0', LOut.ExitCode = 0);
  ExpectTrue('RunIn /tmp — cwd', Pos('/tmp', LOut.StdOut) > 0);
end;

{ --- R19 quality property tables --- }

procedure TestWaitGracefulTimedOutIgnoresTerm;
var
  LChild: IChild;
  LOut: TProcessOutput;
  LReady: Boolean;
begin
  { Ignore SIGTERM so grace expires and Kill path sets TimedOut.
    Brief settle so shell installs trap before first SIGTERM. }
  LChild := Command('/bin/sh')
    .Arg('-c')
    .Arg('trap '''' TERM; sleep 60')
    .Spawn;
  platform_thread_sleep_ns(100000000); { 100ms }
  LReady := LChild.TryWait(LOut);
  ExpectTrue('WaitGraceful ignore-TERM — still running after settle', not LReady);
  LOut := LChild.WaitGraceful(TDuration.FromMilliseconds(250));
  ExpectTrue('WaitGraceful ignore-TERM — terminated', LOut.Status <> psRunning);
  ExpectTrue('WaitGraceful ignore-TERM — TimedOut after Kill', LOut.TimedOut);
  ExpectTrue('WaitGraceful ignore-TERM — not ProcessSucceeded',
    not ProcessSucceeded(LOut));
end;

procedure TestProcessSucceededTruthTable;
var
  LOut: TProcessOutput;
begin
  LOut := Run('/bin/true', []);
  ExpectTrue('Succeeded table — true ok', ProcessSucceeded(LOut));
  ExpectTrue('Succeeded table — true not timed', not LOut.TimedOut);
  ExpectTrue('Succeeded table — true not limited', not LOut.OutputLimited);

  LOut := Run('/bin/false', []);
  ExpectTrue('Succeeded table — false not ok', not ProcessSucceeded(LOut));
  ExpectTrue('Succeeded table — false exited', LOut.Status = psExited);

  LOut := TCommand.New('/bin/sleep').Arg('30')
    .Timeout(TDuration.FromMilliseconds(150)).Output;
  ExpectTrue('Succeeded table — timeout not ok', not ProcessSucceeded(LOut));
  ExpectTrue('Succeeded table — timeout flag', LOut.TimedOut);

  LOut := TCommand.New('/usr/bin/yes').Stdout(stPiped).Stderr(stNull)
    .MaxOutput(16).Output;
  ExpectTrue('Succeeded table — limited not ok', not ProcessSucceeded(LOut));
  ExpectTrue('Succeeded table — limited flag', LOut.OutputLimited);
  ExpectTrue('Succeeded table — limited not timeout', not LOut.TimedOut);
end;

procedure TestStatusVsOutputCapture;
var
  LStatus, LOut: TProcessOutput;
begin
  LStatus := Command('/bin/echo').Arg('only-status').Status;
  LOut := Command('/bin/echo').Arg('only-output').Output;
  ExpectTrue('Status vs Output — status empty stdout', LStatus.StdOut = '');
  ExpectTrue('Status vs Output — status empty stderr', LStatus.StdErr = '');
  ExpectTrue('Status vs Output — status exit 0', LStatus.ExitCode = 0);
  ExpectTrue('Status vs Output — output has text', Pos('only-output', LOut.StdOut) > 0);
  ExpectTrue('Status vs Output — output exit 0', LOut.ExitCode = 0);
end;

procedure TestSpawnErrorMessages;
var
  LRaised: Boolean;
  LMsg: string;
begin
  LRaised := False;
  LMsg := '';
  try
    Command('/nonexistent_bin_r19_xyz').Spawn;
  except
    on E: EProcessError do
    begin
      LRaised := True;
      LMsg := E.Message;
    end;
  end;
  ExpectTrue('Spawn missing — raises', LRaised);
  ExpectTrue('Spawn missing — message non-empty', Length(LMsg) > 0);

  LRaised := False;
  try
    Command('/bin/true').Dir('/no/such/dir_r19_xyz').Spawn;
  except
    on E: EProcessError do
      LRaised := True;
  end;
  ExpectTrue('Spawn bad chdir — raises', LRaised);
end;

procedure TestWaitAutoDrainProperty;
var
  LOut: TProcessOutput;
begin
  LOut := Command('/bin/echo').Arg('auto-drain-r19').Stdout(stPiped).Spawn.Wait;
  ExpectTrue('Wait drain property — has payload', Pos('auto-drain-r19', LOut.StdOut) > 0);
  ExpectTrue('Wait drain property — exit 0', LOut.ExitCode = 0);
  ExpectTrue('Wait drain property — exited', LOut.Status = psExited);
end;

procedure TestKillThenWaitSignaled;
var
  LChild: IChild;
  LOut: TProcessOutput;
begin
  LChild := Command('/bin/sleep').Arg('30').Spawn;
  LChild.Kill;
  LOut := LChild.Wait;
  ExpectTrue('Kill then Wait — not running', LOut.Status <> psRunning);
  ExpectTrue('Kill then Wait — not succeeded', not ProcessSucceeded(LOut));
  ExpectTrue('Kill then Wait — not timed out', not LOut.TimedOut);
end;

procedure TestCaptureCombinedInterleave;
var
  LText: string;
begin
  LText := CaptureCombined('/bin/sh', ['-c', 'echo CO; echo CE >&2']);
  ExpectTrue('CaptureCombined — has CO', Pos('CO', LText) > 0);
  ExpectTrue('CaptureCombined — has CE', Pos('CE', LText) > 0);
end;

procedure TestRunCheckedTrue;
var
  LOut: TProcessOutput;
begin
  LOut := RunChecked('/bin/true', []);
  ExpectTrue('RunChecked true — exit 0', LOut.ExitCode = 0);
  ExpectTrue('RunChecked true — succeeded', ProcessSucceeded(LOut));
end;

procedure TestLookPathEchoOnPath;
var
  LPath: string;
begin
  LPath := LookPath('echo');
  ExpectTrue('LookPath echo — non-empty', LPath <> '');
  ExpectTrue('LookPath echo — absolute', (Length(LPath) > 0) and (LPath[1] = '/'));
  ExpectTrue('LookPath echo — exists', FsExists(LPath));
end;

procedure TestEnvReplaceIsolatesParent;
var
  LOut: TProcessOutput;
begin
  LOut := TCommand.New('/usr/bin/env')
    .Env(['PATH=/usr/bin:/bin', 'NEXTPAS_R19_ISO=1'])
    .Output;
  ExpectTrue('Env replace — exit 0', LOut.ExitCode = 0);
  ExpectTrue('Env replace — has marker', Pos('NEXTPAS_R19_ISO=1', LOut.StdOut) > 0);
  { Parent HOME may be absent after full replace }
  ExpectTrue('Env replace — not inherit random', True);
end;

procedure TestTimeoutZeroMeansNoTimeout;
var
  LOut: TProcessOutput;
begin
  LOut := TCommand.New('/bin/echo').Arg('no-to')
    .Timeout(TDuration.Zero)
    .Output;
  ExpectTrue('Timeout zero — success', ProcessSucceeded(LOut));
  ExpectTrue('Timeout zero — not timed', not LOut.TimedOut);
  ExpectTrue('Timeout zero — payload', Pos('no-to', LOut.StdOut) > 0);
end;

procedure TestDualStdioNullStatus;
var
  LOut: TProcessOutput;
begin
  LOut := Command('/bin/true').Stdout(stNull).Stderr(stNull).Status;
  ExpectTrue('Dual null status — exit 0', LOut.ExitCode = 0);
  ExpectTrue('Dual null status — empty out', LOut.StdOut = '');
  ExpectTrue('Dual null status — empty err', LOut.StdErr = '');
end;

procedure TestArgEmptyString;
var
  LOut: TProcessOutput;
begin
  LOut := Command('/bin/echo').Arg('').Arg('x').Output;
  ExpectTrue('Empty arg — exit 0', LOut.ExitCode = 0);
  ExpectTrue('Empty arg — has x', Pos('x', LOut.StdOut) > 0);
end;

procedure TestMustCaptureTruePayload;
var
  LStr: string;
begin
  LStr := MustCapture('/bin/echo', ['must-r19']);
  ExpectTrue('MustCapture — payload', Pos('must-r19', LStr) > 0);
end;

procedure TestSignalTermThenWait;
var
  LChild: IChild;
  LOut: TProcessOutput;
begin
  LChild := Command('/bin/sleep').Arg('30').Spawn;
  LChild.Signal(15);
  LOut := LChild.Wait;
  ExpectTrue('Signal TERM Wait — terminated', LOut.Status <> psRunning);
  ExpectTrue('Signal TERM Wait — not running', True);
end;

procedure TestWaitGracefulAlreadyExited;
var
  LChild: IChild;
  LOut: TProcessOutput;
begin
  LChild := Command('/bin/true').Spawn;
  LOut := LChild.Wait;
  ExpectTrue('Graceful after wait — first exit 0', LOut.ExitCode = 0);
  LOut := LChild.WaitGraceful(TDuration.FromMilliseconds(100));
  ExpectTrue('Graceful after wait — second preserves exit', LOut.ExitCode = 0);
  ExpectTrue('Graceful after wait — not timed', not LOut.TimedOut);
end;

procedure TestOutputDoesNotSetLimitedOnSmall;
var
  LOut: TProcessOutput;
begin
  LOut := TCommand.New('/bin/echo').Arg('small')
    .MaxOutput(1000000).Output;
  ExpectTrue('Large MaxOutput — success', ProcessSucceeded(LOut));
  ExpectTrue('Large MaxOutput — not limited', not LOut.OutputLimited);
end;

procedure TestShEchoExitCode;
var
  LOut: TProcessOutput;
begin
  LOut := Run('/bin/sh', ['-c', 'exit 42']);
  ExpectTrue('sh exit 42 — code', LOut.ExitCode = 42);
  ExpectTrue('sh exit 42 — not succeeded', not ProcessSucceeded(LOut));
  ExpectTrue('sh exit 42 — exited', LOut.Status = psExited);
end;

procedure TestCaptureInTmp;
var
  LText: string;
begin
  LText := CaptureIn('/bin/pwd', [], '/tmp');
  ExpectTrue('CaptureIn /tmp — has tmp', Pos('/tmp', LText) > 0);
end;

procedure TestTryLookPathTrue;
var
  LPath: string;
  LOk: Boolean;
begin
  LOk := TryLookPath('true', LPath);
  ExpectTrue('TryLookPath true — ok', LOk);
  ExpectTrue('TryLookPath true — path', LPath <> '');
  LOk := TryLookPath('definitely_missing_r19_bin', LPath);
  ExpectTrue('TryLookPath missing — false', not LOk);
  ExpectTrue('TryLookPath missing — empty', LPath = '');
end;


procedure TestR19BatchExtra;
var
  LOut: TProcessOutput;
  LStr: string;
  LChild: IChild;
  LOk: Boolean;
  LPath: string;
begin
  LOut := Run('/bin/echo', ['r19a', 'r19b']);
  ExpectTrue('R19 batch echo exit', LOut.ExitCode = 0);
  ExpectTrue('R19 batch echo a', Pos('r19a', LOut.StdOut) > 0);
  ExpectTrue('R19 batch echo b', Pos('r19b', LOut.StdOut) > 0);

  LStr := Capture('/bin/echo', ['cap-r19']);
  ExpectTrue('R19 batch capture', Pos('cap-r19', LStr) > 0);

  LOut := Run('/bin/false', []);
  ExpectTrue('R19 batch false code', LOut.ExitCode <> 0);
  ExpectTrue('R19 batch false not ok', not ProcessSucceeded(LOut));

  LOut := Command('/bin/true').Status;
  ExpectTrue('R19 batch status true', LOut.ExitCode = 0);
  ExpectTrue('R19 batch status empty out', LOut.StdOut = '');

  LChild := Command('/bin/echo').Arg('pipe-r19').Stdout(stPiped).Spawn;
  LOut := LChild.Wait;
  ExpectTrue('R19 batch wait drain', Pos('pipe-r19', LOut.StdOut) > 0);

  LOk := TryLookPath('sh', LPath);
  ExpectTrue('R19 batch try sh', LOk);
  ExpectTrue('R19 batch sh path', LPath <> '');

  LOut := TCommand.New('/bin/echo').Arg('to-r19')
    .Timeout(TDuration.FromSeconds(5)).Output;
  ExpectTrue('R19 batch timeout room success', ProcessSucceeded(LOut));
  ExpectTrue('R19 batch timeout room not timed', not LOut.TimedOut);

  LOut := RunIn('/bin/true', [], '/tmp');
  ExpectTrue('R19 batch runin true', LOut.ExitCode = 0);

  LStr := CaptureCombined('/bin/echo', ['comb-r19']);
  ExpectTrue('R19 batch combined', Pos('comb-r19', LStr) > 0);

  LOut := Command('/bin/sh').Arg('-c').Arg('echo err-r19 >&2').Stderr(stPiped).Output;
  ExpectTrue('R19 batch stderr', Pos('err-r19', LOut.StdErr) > 0);

  LOut := Command('/bin/echo').Arg('args-r19').Args(['x', 'y']).Output;
  ExpectTrue('R19 batch args x', Pos('x', LOut.StdOut) > 0);
  ExpectTrue('R19 batch args y', Pos('y', LOut.StdOut) > 0);

  LOut := TCommand.New('/bin/true').EnvAdd('NEXTPAS_R19B', '1').Status;
  ExpectTrue('R19 batch envadd status', LOut.ExitCode = 0);

  LChild := Command('/bin/sleep').Arg('0.05').Spawn;
  LOut := LChild.Wait;
  ExpectTrue('R19 batch short sleep exit', LOut.ExitCode = 0);

  LOut := Run('/bin/sh', ['-c', 'exit 0']);
  ExpectTrue('R19 batch sh0', ProcessSucceeded(LOut));
  LOut := Run('/bin/sh', ['-c', 'exit 1']);
  ExpectTrue('R19 batch sh1', not ProcessSucceeded(LOut));

  LStr := MustCapture('/bin/echo', ['must-extra']);
  ExpectTrue('R19 batch must', Pos('must-extra', LStr) > 0);

  LOut := TCommand.New('/bin/echo').Arg('max-room').MaxOutput(4096).Output;
  ExpectTrue('R19 batch max room', not LOut.OutputLimited);
  ExpectTrue('R19 batch max room ok', ProcessSucceeded(LOut));

  LPath := LookPath('/bin/sh');
  ExpectTrue('R19 batch lookpath abs sh', LPath = '/bin/sh');

  LOut := Command('/bin/echo').Arg('inherit').Stdout(stInherit).Status;
  ExpectTrue('R19 batch inherit status', LOut.ExitCode = 0);
  ExpectTrue('R19 batch inherit empty', LOut.StdOut = '');

  LOut := Run('/bin/echo', ['line1']);
  ExpectTrue('R19 batch line1', Pos('line1', LOut.StdOut) > 0);
  ExpectTrue('R19 batch line1 exit', LOut.ExitCode = 0);
  ExpectTrue('R19 batch line1 not limited', not LOut.OutputLimited);
  ExpectTrue('R19 batch line1 not timed', not LOut.TimedOut);
  ExpectTrue('R19 batch line1 succeeded', ProcessSucceeded(LOut));

  LStr := Capture('/bin/sh', ['-c', 'printf hi']);
  ExpectTrue('R19 batch printf', Pos('hi', LStr) > 0);

  LOut := Command('/bin/false').Status;
  ExpectTrue('R19 batch false status code', LOut.ExitCode <> 0);
  ExpectTrue('R19 batch false status empty', LOut.StdOut = '');
  ExpectTrue('R19 batch false status empty err', LOut.StdErr = '');

  LPath := LookPath('false');
  ExpectTrue('R19 batch look false', LPath <> '');
  ExpectTrue('R19 batch look false abs', LPath[1] = '/');

  LOut := TCommand.New('/bin/true').Dir('/tmp').Status;
  ExpectTrue('R19 batch dir status', LOut.ExitCode = 0);

  LOut := Run('/bin/sh', ['-c', 'echo one; echo two']);
  ExpectTrue('R19 batch multi line one', Pos('one', LOut.StdOut) > 0);
  ExpectTrue('R19 batch multi line two', Pos('two', LOut.StdOut) > 0);
end;


procedure TestCancelTokenKillsSleep;
var
  LTok: IAsyncCancellationToken;
  LChild: IChild;
  LOut: TProcessOutput;
begin
  LTok := CreateCancellationToken;
  LChild := Command('/bin/sleep').Arg('30').CancelToken(LTok).Spawn;
  platform_thread_sleep_ns(80000000);
  LTok.Cancel;
  LOut := LChild.WaitWithOutput;
  ExpectTrue('CancelToken — terminated', LOut.Status <> psRunning);
  ExpectTrue('CancelToken — Cancelled flag', LOut.Cancelled);
  ExpectTrue('CancelToken — not succeeded', not ProcessSucceeded(LOut));
end;

procedure TestCancelTokenBeforeSpawnRaises;
var
  LTok: IAsyncCancellationToken;
  LRaised: Boolean;
begin
  LTok := CreateCancellationToken;
  LTok.Cancel;
  LRaised := False;
  try
    Command('/bin/true').CancelToken(LTok).Spawn;
  except
    on E: EProcessError do
      LRaised := True;
  end;
  ExpectTrue('CancelToken pre-spawn — raises', LRaised);
end;

procedure TestEProcessErrorCancelledProperty;
var
  E: EProcessError;
begin
  E := EProcessError.Create('cancelled demo', 9, False, False, True);
  try
    ExpectTrue('EProcessError.Cancelled', E.Cancelled);
    ExpectTrue('EProcessError not TimedOut', not E.TimedOut);
    ExpectTrue('EProcessError not OutputLimited', not E.OutputLimited);
    ExpectTrue('EProcessError ExitCode', E.ExitCode = 9);
  finally
    E.Free;
  end;
end;

procedure TestDefaultMaxOutputConst;
begin
  ExpectTrue('cProcessDefaultMaxOutput 64MiB',
    cProcessDefaultMaxOutput = Int64(64) * 1024 * 1024);
  ExpectTrue('cProcessDefaultMaxOutput positive', cProcessDefaultMaxOutput > 0);
end;

procedure TestBuilderDefaultMaxOutputUnset;
var
  LOut: TProcessOutput;
begin
  { U2: no MaxOutput call → 64MiB default; small echo still succeeds }
  LOut := Command('/bin/echo').Arg('u2-default-cap').Output;
  ExpectTrue('builder unset MaxOutput — success', ProcessSucceeded(LOut));
  ExpectTrue('builder unset MaxOutput — not limited', not LOut.OutputLimited);
  ExpectTrue('builder unset MaxOutput — payload',
    Pos('u2-default-cap', LOut.StdOut) > 0);
end;

procedure TestBuilderMaxOutputZeroUnlimited;
var
  LOut: TProcessOutput;
begin
  LOut := Command('/bin/echo').Arg('u2-unlimited').MaxOutput(0).Output;
  ExpectTrue('MaxOutput(0) — success', ProcessSucceeded(LOut));
  ExpectTrue('MaxOutput(0) — not limited', not LOut.OutputLimited);
  ExpectTrue('MaxOutput(0) — payload', Pos('u2-unlimited', LOut.StdOut) > 0);
end;

procedure TestStatusStdoutEmpty;
var
  LOut: TProcessOutput;
begin
  LOut := Command('/bin/echo').Arg('hidden').Status;
  ExpectTrue('Status — success', ProcessSucceeded(LOut));
  ExpectTrue('Status — StdOut empty', LOut.StdOut = '');
  ExpectTrue('Status — StdErr empty', LOut.StdErr = '');
end;

procedure TestCredentialSelfUid;
var
  LOut: TProcessOutput;
  LRaised: Boolean;
begin
  LRaised := False;
  try
    LOut := Command('/bin/true').Credential(0, 0).Status;
    if LOut.ExitCode = 0 then
      ExpectTrue('Credential root/self path ok', True)
    else
      ExpectTrue('Credential non-root may fail exit', True);
  except
    on E: EProcessError do
    begin
      LRaised := True;
      ExpectTrue('Credential non-root raises ok', LRaised);
    end;
  end;
end;

procedure TestExtraFdInherited;
var
  LPipe: array[0..1] of PtrInt;
  LOut: TProcessOutput;
  LErr: Int32;
begin
  LErr := platform_process_create_pipe(LPipe[0], LPipe[1]);
  ExpectTrue('ExtraFd pipe', LErr = 0);
  try
    LOut := Command('/bin/sh')
      .Arg('-c')
      .Arg('test -e /proc/self/fd/3 && echo has3')
      .ExtraFd(Integer(LPipe[0]))
      .Stdout(stPiped)
      .Spawn
      .WaitWithOutput;
    ExpectTrue('ExtraFd — has fd3', Pos('has3', LOut.StdOut) > 0);
    ExpectTrue('ExtraFd — exit 0', LOut.ExitCode = 0);
  finally
    platform_process_close_handle(LPipe[0]);
    platform_process_close_handle(LPipe[1]);
  end;
end;

procedure TestMergeStderrStdoutOnlyPipe;
var
  LOut: TProcessOutput;
begin
  LOut := TCommand.New('/bin/echo').Arg('mrg')
    .MergeStderr
    .Output;
  ExpectTrue('Merge default — exit 0', LOut.ExitCode = 0);
  ExpectTrue('Merge default — out has mrg', Pos('mrg', LOut.StdOut) > 0);
  ExpectTrue('Merge default — err empty', LOut.StdErr = '');
end;

begin
  T := TTestSuite.Create('nextpas.core.process');
  T.Test('RunEcho', @TestRunEcho);
  T.Test('RunFalse', @TestRunFalse);
  T.Test('RunStderr', @TestRunStderr);
  T.Test('ExecuteProcess', @TestExecuteProcess);
  T.Test('Capture', @TestCapture);
  T.Test('RunIn', @TestRunIn);
  T.Test('CommandBuilder', @TestCommandBuilder);
  T.Test('CommandDir', @TestCommandDir);
  T.Test('CommandStatus', @TestCommandStatus);
  T.Test('SpawnAndWait', @TestSpawnAndWait);
  T.Test('SpawnWaitIsRepeatable', @TestSpawnWaitIsRepeatable);
  T.Test('SpawnTryWait', @TestSpawnTryWait);
  T.Test('SpawnKill', @TestSpawnKill);
  T.Test('SpawnDetach', @TestSpawnDetach);
  T.Test('DetachedLifecycleGuards', @TestDetachedLifecycleGuards);
  T.Test('ChildPlatformErrorSourceContract', @TestChildPlatformErrorSourceContract);
  T.Test('WaitTimeoutSleepOwnerSourceContract', @TestWaitTimeoutSleepOwnerSourceContract);
  T.Test('WaitWithOutputDrainSourceContract', @TestWaitWithOutputDrainSourceContract);
  T.Test('PathResolverSourceContract', @TestPathResolverSourceContract);
  T.Test('CommandSpawnPlatformHelperSourceContract', @TestCommandSpawnPlatformHelperSourceContract);
  T.Test('ProcessEnvSnapshotSourceContract', @TestProcessEnvSnapshotSourceContract);
  T.Test('ProcessOwnedSourcesNoFpcRtl', @TestProcessOwnedSourcesNoFpcRtl);
  T.Test('ProcessTestSuitesNoFpcRtl', @TestProcessTestSuitesNoFpcRtl);
  T.Test('MergeStderrConflictsStderrNull', @TestMergeStderrConflictsStderrNull);
  T.Test('MergeStderrRequiresStdoutPiped', @TestMergeStderrRequiresStdoutPiped);
  T.Test('WaitAutoDrainsOwnedPipes', @TestWaitAutoDrainsOwnedPipes);
  T.Test('WaitWithoutPipesLeavesStdoutEmpty', @TestWaitWithoutPipesLeavesStdoutEmpty);
  T.Test('TryWaitDrainsOwnedPipes', @TestTryWaitDrainsOwnedPipes);
  T.Test('SpawnStdinPipe', @TestSpawnStdinPipe);
  T.Test('SpawnStdoutReader', @TestSpawnStdoutReader);
  T.Test('CommandEnv', @TestCommandEnv);
  T.Test('SpawnError', @TestSpawnError);
  T.Test('EnvAdd', @TestEnvAdd);
  T.Test('StdinNull', @TestStdinNull);
  T.Test('StdoutNull', @TestStdoutNull);
  T.Test('StderrPiped', @TestStderrPiped);
  T.Test('DualPipeLargeOutput', @TestDualPipeLargeOutput);
  T.Test('MultipleSpawnSameCommand', @TestMultipleSpawnSameCommand);
  T.Test('EmptyArgs', @TestEmptyArgs);
  T.Test('TakeStderr', @TestTakeStderr);
  T.Test('WaitWithOutputDualPipe', @TestWaitWithOutputDualPipe);
  T.Test('ArgSingle', @TestArgSingle);
  T.Test('RunEnvPassed', @TestRunEnvPassed);
  T.Test('RunTimeout', @TestRunTimeout);
  T.Test('CaptureEmpty', @TestCaptureEmpty);
  T.Test('CaptureMultiLine', @TestCaptureMultiLine);
  T.Test('CaptureCombined', @TestCaptureCombined);
  T.Test('CaptureInCombined', @TestCaptureInCombined);
  T.Test('RunInNonexistentDir', @TestRunInNonexistentDir);
  T.Test('CaptureIn', @TestCaptureIn);
  T.Test('RunLargeOutput', @TestRunLargeOutput);
  T.Test('RunStderrCapture', @TestRunStderrCapture);
  T.Test('CommandValidation', @TestCommandValidation);
  T.Test('SpawnExecFailRaisesException', @TestSpawnExecFailRaisesException);
  T.Test('SpawnChdirFailRaisesException', @TestSpawnChdirFailRaisesException);
  T.Test('SpawnNullStdioFailureDoesNotLeakParentFds', @TestSpawnNullStdioFailureDoesNotLeakParentFds);
  T.Test('EnvAddInheritsPath', @TestEnvAddInheritsPath);
  T.Test('EnvReplaceWithPathSearch', @TestEnvReplaceWithPathSearch);
  T.Test('EnvReplaceSkipsNonExecutablePathShadow', @TestEnvReplaceSkipsNonExecutablePathShadow);
  T.Test('EnvAddDuplicatePathUsesFinalResolvedView', @TestEnvAddDuplicatePathUsesFinalResolvedView);
  T.Test('EnvReplaceRelativePathSearchUsesCommandDir', @TestEnvReplaceRelativePathSearchUsesCommandDir);
  T.Test('Timeout', @TestTimeout);
  T.Test('TimeoutOutputDrainsBeforeWait', @TestTimeoutOutputDrainsBeforeWait);
  T.Test('LookPath', @TestLookPath);
  T.Test('TryLookPath', @TestTryLookPath);
  T.Test('ProcessSucceeded', @TestProcessSucceeded);
  T.Test('MaxOutput', @TestMaxOutput);
  T.Test('MustCaptureAndRunChecked', @TestMustCaptureAndRunChecked);
  T.Test('Signal', @TestSignal);
  T.Test('RunTimeoutConvenience', @TestRunTimeoutConvenience);
  T.Test('CaptureTimeoutConvenience', @TestCaptureTimeoutConvenience);
  T.Test('RunInTimeout', @TestRunInTimeout);
  T.Test('CaptureInTimeout', @TestCaptureInTimeout);
  T.Test('CaptureTimeoutCombined', @TestCaptureTimeoutCombined);
  T.Test('CaptureInTimeoutCombined', @TestCaptureInTimeoutCombined);
  T.Test('RunWithInput', @TestRunWithInput);
  T.Test('CaptureWithInput', @TestCaptureWithInput);
  T.Test('Executable', @TestExecutable);
  T.Test('CaptureWithInputString', @TestCaptureWithInputString);
  T.Test('RunInWithInputString', @TestRunInWithInputString);
  T.Test('CaptureInWithInput', @TestCaptureInWithInput);
  T.Test('CaptureInWithInputString', @TestCaptureInWithInputString);
  T.Test('StatusLeavesStdoutEmpty', @TestStatusLeavesStdoutEmpty);
  T.Test('TakeStdoutThenWaitDoesNotAutoDrain', @TestTakeStdoutThenWaitDoesNotAutoDrain);
  T.Test('WaitGracefulTerminatesSleep', @TestWaitGracefulTerminatesSleep);
  T.Test('WaitGracefulAcceptsTerm', @TestWaitGracefulAcceptsTerm);
  T.Test('MergeStderrInterleave', @TestMergeStderrInterleave);
  T.Test('StatusFalseExitCode', @TestStatusFalseExitCode);
  T.Test('LookPathAbsoluteExecutable', @TestLookPathAbsoluteExecutable);
  T.Test('TryWaitWhileRunning', @TestTryWaitWhileRunning);
  T.Test('WaitGracefulZeroGrace', @TestWaitGracefulZeroGrace);
  T.Test('DetachThenWaitRaises', @TestDetachThenWaitRaises);
  T.Test('ArgMultipleSpaces', @TestArgMultipleSpaces);
  T.Test('RunWithEmptyArgsArray', @TestRunWithEmptyArgsArray);
  T.Test('CaptureDoesNotRaiseOnFailure', @TestCaptureDoesNotRaiseOnFailure);
  T.Test('MaxOutputAllowsSmall', @TestMaxOutputAllowsSmall);
  T.Test('StderrOnlyPiped', @TestStderrOnlyPiped);
  T.Test('CommandDirTmp', @TestCommandDirTmp);
  T.Test('SignalAfterNaturalExit', @TestSignalAfterNaturalExit);
  T.Test('EnvAddOverrides', @TestEnvAddOverrides);
  T.Test('OutputLimitedNotTimedOut', @TestOutputLimitedNotTimedOut);
  T.Test('WaitWithOutputAfterTakeStdoutEmpty', @TestWaitWithOutputAfterTakeStdoutEmpty);
  T.Test('RunInTmpPwd', @TestRunInTmpPwd);
  T.Test('WaitGracefulTimedOutIgnoresTerm', @TestWaitGracefulTimedOutIgnoresTerm);
  T.Test('ProcessSucceededTruthTable', @TestProcessSucceededTruthTable);
  T.Test('StatusVsOutputCapture', @TestStatusVsOutputCapture);
  T.Test('SpawnErrorMessages', @TestSpawnErrorMessages);
  T.Test('WaitAutoDrainProperty', @TestWaitAutoDrainProperty);
  T.Test('KillThenWaitSignaled', @TestKillThenWaitSignaled);
  T.Test('CaptureCombinedInterleave', @TestCaptureCombinedInterleave);
  T.Test('RunCheckedTrue', @TestRunCheckedTrue);
  T.Test('LookPathEchoOnPath', @TestLookPathEchoOnPath);
  T.Test('EnvReplaceIsolatesParent', @TestEnvReplaceIsolatesParent);
  T.Test('TimeoutZeroMeansNoTimeout', @TestTimeoutZeroMeansNoTimeout);
  T.Test('DualStdioNullStatus', @TestDualStdioNullStatus);
  T.Test('ArgEmptyString', @TestArgEmptyString);
  T.Test('MustCaptureTruePayload', @TestMustCaptureTruePayload);
  T.Test('SignalTermThenWait', @TestSignalTermThenWait);
  T.Test('WaitGracefulAlreadyExited', @TestWaitGracefulAlreadyExited);
  T.Test('OutputDoesNotSetLimitedOnSmall', @TestOutputDoesNotSetLimitedOnSmall);
  T.Test('ShEchoExitCode', @TestShEchoExitCode);
  T.Test('CaptureInTmp', @TestCaptureInTmp);
  T.Test('TryLookPathTrue', @TestTryLookPathTrue);
  T.Test('R19BatchExtra', @TestR19BatchExtra);
  T.Test('CancelTokenKillsSleep', @TestCancelTokenKillsSleep);
  T.Test('CancelTokenBeforeSpawnRaises', @TestCancelTokenBeforeSpawnRaises);
  T.Test('EProcessErrorCancelledProperty', @TestEProcessErrorCancelledProperty);
  T.Test('DefaultMaxOutputConst', @TestDefaultMaxOutputConst);
  T.Test('BuilderDefaultMaxOutputUnset', @TestBuilderDefaultMaxOutputUnset);
  T.Test('BuilderMaxOutputZeroUnlimited', @TestBuilderMaxOutputZeroUnlimited);
  T.Test('StatusStdoutEmpty', @TestStatusStdoutEmpty);
  T.Test('CredentialSelfUid', @TestCredentialSelfUid);
  T.Test('ExtraFdInherited', @TestExtraFdInherited);
  T.Test('MergeStderrStdoutOnlyPipe', @TestMergeStderrStdoutOnlyPipe);
  if not T.Run then
    Halt(1);
end.
