program test_process;

{$I nextpas.core.settings.inc}

uses
  SysUtils, Classes,
  nextpas.core.process,
  nextpas.core.time.base,
  nextpas.core.process.base,
  nextpas.core.process.child,
  nextpas.core.process.pipe,
  nextpas.core.process.command,
  nextpas.core.io.intf,
  nextpas.core.platform.posix.ffi;

var
  LPassed, LFailed: Integer;

procedure Check(const AName: string; ACondition: Boolean);
begin
  if ACondition then
  begin
    WriteLn('  PASS: ', AName);
    Inc(LPassed);
  end
  else
  begin
    WriteLn('  FAIL: ', AName);
    Inc(LFailed);
  end;
end;

procedure TestRunEcho;
var LOut: TProcessOutput;
begin
  LOut := Run('/bin/echo', ['hello', 'world']);
  Check('Run echo — success', LOut.ExitCode = 0);
  Check('Run echo — stdout', Pos('hello world', LOut.StdOut) > 0);
  Check('Run echo — status exited', LOut.Status = psExited);
end;

procedure TestRunFalse;
var LOut: TProcessOutput;
begin
  LOut := Run('/bin/false', []);
  Check('Run false — non-zero exit', LOut.ExitCode <> 0);
  Check('Run false — status exited', LOut.Status = psExited);
end;

procedure TestRunStderr;
var LOut: TProcessOutput;
begin
  LOut := Run('/bin/ls', ['/nonexistent_xyz_path']);
  Check('Run ls bad — stderr not empty', Length(LOut.StdErr) > 0);
  Check('Run ls bad — non-zero exit', LOut.ExitCode <> 0);
end;

procedure TestCapture;
var LStr: string;
begin
  LStr := Capture('/bin/echo', ['captured']);
  Check('Capture — contains text', Pos('captured', LStr) > 0);
end;

procedure TestRunIn;
var LOut: TProcessOutput;
begin
  LOut := RunIn('/bin/pwd', [], '/tmp');
  Check('RunIn — workdir /tmp', Pos('/tmp', LOut.StdOut) > 0);
end;

procedure TestCommandBuilder;
var LOut: TProcessOutput;
begin
  LOut := Command('/bin/echo')
    .Args(['builder', 'test'])
    .Output;
  Check('Command builder — success', LOut.ExitCode = 0);
  Check('Command builder — stdout', Pos('builder test', LOut.StdOut) > 0);
end;

procedure TestCommandDir;
var LOut: TProcessOutput;
begin
  LOut := Command('/bin/pwd')
    .Dir('/tmp')
    .Output;
  Check('Command dir — /tmp', Pos('/tmp', LOut.StdOut) > 0);
end;

procedure TestCommandStatus;
var LCode: Integer;
begin
  LCode := Command('/bin/true').Status;
  Check('Command status true — 0', LCode = 0);
  LCode := Command('/bin/false').Status;
  Check('Command status false — non-zero', LCode <> 0);
end;

procedure TestSpawnAndWait;
var
  LChild: IChild;
  LOut: TProcessOutput;
begin
  LChild := Command('/bin/sleep').Arg('0.1').Spawn;
  Check('Spawn — pid > 0', LChild.Pid > 0);
  LOut := LChild.Wait;
  Check('Spawn wait — exited', LOut.Status = psExited);
  Check('Spawn wait — exit 0', LOut.ExitCode = 0);
end;

procedure TestSpawnTryWait;
var
  LChild: IChild;
  LOut: TProcessOutput;
  LDone: Boolean;
begin
  LChild := Command('/bin/sleep').Arg('0.05').Spawn;
  LDone := LChild.TryWait(LOut);
  Check('TryWait — not done immediately', not LDone);
  LOut := LChild.Wait;
  Check('TryWait then Wait — exited', LOut.Status = psExited);
end;

procedure TestSpawnKill;
var
  LChild: IChild;
  LOut: TProcessOutput;
begin
  LChild := Command('/bin/sleep').Arg('10').Spawn;
  LChild.Kill;
  LOut := LChild.Wait;
  Check('Kill — signaled', LOut.Status = psSignaled);
end;

procedure TestSpawnDetach;
var
  LChild: IChild;
  LPath: string;
  LOut: TStringList;
begin
  LPath := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'nextpas-process-detach-' + IntToStr(GetProcessID) + '.txt';
  if FileExists(LPath) then
    DeleteFile(LPath);

  LChild := Command('/bin/sh')
    .Args(['-c', 'sleep 0.1; printf detached > "' + LPath + '"'])
    .Spawn;
  LChild.Detach;
  LChild := nil;

  Sleep(300);
  Check('Detach — child survives handle release', FileExists(LPath));
  if FileExists(LPath) then
  begin
    LOut := TStringList.Create;
    try
      LOut.LoadFromFile(LPath);
      Check('Detach — child completed work',
        (LOut.Count = 1) and (LOut[0] = 'detached'));
    finally
      LOut.Free;
      DeleteFile(LPath);
    end;
  end
  else
    Check('Detach — child completed work', False);
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
  Check('Stdin pipe — echoed back', Pos('piped input', LOut.StdOut) > 0);
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
  Check('Stdout reader — streaming', Pos('streaming read', LTotal) > 0);
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
  Check('Env — custom var visible', Pos('MY_TEST_VAR=hello_from_core', LOut.StdOut) > 0);
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
  Check('Spawn nonexistent — raises EProcessError', LRaised);
end;

procedure TestEnvAdd;
var LOut: TProcessOutput;
begin
  LOut := TCommand.New('/usr/bin/env')
    .EnvAdd('TEST_KEY', 'test_value')
    .Output;
  Check('EnvAdd — key visible', Pos('TEST_KEY=test_value', LOut.StdOut) > 0);
end;

procedure TestStdinNull;
var LOut: TProcessOutput;
begin
  LOut := TCommand.New('/bin/cat')
    .Stdin(stNull)
    .Stdout(stPiped)
    .Output;
  Check('Stdin null — cat gets EOF immediately', LOut.ExitCode = 0);
  Check('Stdin null — no output', LOut.StdOut = '');
end;

procedure TestStdoutNull;
var LCode: Integer;
begin
  LCode := TCommand.New('/bin/echo')
    .Args(['should not appear'])
    .Stdout(stNull)
    .Status;
  Check('Stdout null — exits 0', LCode = 0);
end;

procedure TestStderrPiped;
var LOut: TProcessOutput;
begin
  LOut := TCommand.New('/bin/sh')
    .Args(['-c', 'echo err >&2'])
    .Stdout(stPiped)
    .Stderr(stPiped)
    .Output;
  Check('Stderr piped — captured', Pos('err', LOut.StdErr) > 0);
end;

procedure TestDualPipeLargeOutput;
var LOut: TProcessOutput;
begin
  LOut := TCommand.New('/bin/sh')
    .Args(['-c', 'seq 1 5000; echo err >&2'])
    .Output;
  Check('Large output — stdout > 10KB', Length(LOut.StdOut) > 10000);
  Check('Large output — stderr present', Length(LOut.StdErr) > 0);
  Check('Large output — no deadlock', LOut.ExitCode = 0);
end;

procedure TestMultipleSpawnSameCommand;
var
  LCmd: ICommand;
  LOut1, LOut2: TProcessOutput;
begin
  LCmd := TCommand.New('/bin/echo').Args(['reuse']);
  LOut1 := LCmd.Output;
  LOut2 := LCmd.Output;
  Check('Reuse command — first', Pos('reuse', LOut1.StdOut) > 0);
  Check('Reuse command — second', Pos('reuse', LOut2.StdOut) > 0);
end;

procedure TestEmptyArgs;
var LOut: TProcessOutput;
begin
  LOut := Run('/bin/echo', []);
  Check('Empty args — exits 0', LOut.ExitCode = 0);
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
  Check('TakeStderr — read > 0', LN > 0);
  LReader := nil;
  LChild.Wait;
end;

procedure TestWaitWithOutputDualPipe;
var
  LChild: IChild;
  LStdin: IWriter;
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
  (LStdin as TPipeWriter).Close;
  LStdin := nil;
  LOut := LChild.WaitWithOutput;
  Check('Dual pipe — stdout', Pos('dual pipe test', LOut.StdOut) > 0);
  Check('Dual pipe — stderr', Pos('err', LOut.StdErr) > 0);
  Check('Dual pipe — exit 0', LOut.ExitCode = 0);
end;

procedure TestArgSingle;
var LOut: TProcessOutput;
begin
  LOut := TCommand.New('/bin/echo').Arg('single').Output;
  Check('Arg single — output', Pos('single', LOut.StdOut) > 0);
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
  Check(AName, LRaised);
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
  Check('Exec fail — raises EProcessError', LRaised);
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
  Check('Chdir fail — raises EProcessError', LRaised);
end;

function OpenFdCount: Integer;
var
  LSearch: TSearchRec;
begin
  Result := 0;
  if FindFirst('/proc/self/fd/*', faAnyFile, LSearch) = 0 then
  begin
    repeat
      if (LSearch.Name <> '.') and (LSearch.Name <> '..') then
        Inc(Result);
    until FindNext(LSearch) <> 0;
    FindClose(LSearch);
  end
  else
    Result := -1;
end;

procedure ExpectProcessErrorNoFdLeak(const AName: string; const AProc: TProcedure);
var
  LBefore: Integer;
  LAfter: Integer;
begin
  LBefore := OpenFdCount;
  ExpectProcessError(AName + ' — raises EProcessError', AProc);
  LAfter := OpenFdCount;
  if (LBefore >= 0) and (LAfter >= 0) then
    Check(AName + ' — parent fd count returns to baseline', LAfter = LBefore)
  else
    Check(AName + ' — /proc/self/fd unavailable', True);
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
  Check('EnvAdd overlay — custom var', Pos('MY_OVERLAY_VAR=overlay_value', LOut.StdOut) > 0);
  Check('EnvAdd overlay — PATH inherited', Pos('PATH=', LOut.StdOut) > 0);
end;


procedure TestEnvReplaceWithPathSearch;
var LOut: TProcessOutput;
begin
  LOut := TCommand.New('echo')
    .Args(['path search works'])
    .Env(['PATH=/bin:/usr/bin'])
    .Output;
  Check('Env replace + PATH search — found echo', Pos('path search works', LOut.StdOut) > 0);
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
  LTempRoot := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'nextpas-process-path-shadow-' + IntToStr(GetProcessID);
  LShadowDir := IncludeTrailingPathDelimiter(LTempRoot) + 'shadow';
  LRealDir := IncludeTrailingPathDelimiter(LTempRoot) + 'real';
  LShadowPath := IncludeTrailingPathDelimiter(LShadowDir) + LToolName;
  LRealPath := IncludeTrailingPathDelimiter(LRealDir) + LToolName;
  if DirectoryExists(LTempRoot) then
    RemoveDir(LTempRoot);
  ForceDirectories(LShadowDir);
  ForceDirectories(LRealDir);
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
    nextpas.core.platform.posix.ffi.chmod(PAnsiChar(LRealPath), &755);

    LRaised := False;
    try
      LOut := TCommand.New(LToolName)
        .Env(['PATH=' + LShadowDir + ':' + LRealDir])
        .Output;
    except
      on E: EProcessError do
        LRaised := True;
    end;

    Check('Env replace + PATH skips non-executable shadow — no spawn error', not LRaised);
    if not LRaised then
      Check('Env replace + PATH skips non-executable shadow — found executable target',
        Pos('shadow-resolved', LOut.StdOut) > 0);
  finally
    if FileExists(LShadowPath) then
      DeleteFile(LShadowPath);
    if FileExists(LRealPath) then
      DeleteFile(LRealPath);
    if DirectoryExists(LShadowDir) then
      RemoveDir(LShadowDir);
    if DirectoryExists(LRealDir) then
      RemoveDir(LRealDir);
    if DirectoryExists(LTempRoot) then
      RemoveDir(LTempRoot);
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
  Check('EnvAdd duplicate PATH final view — exit 0', LOut.ExitCode = 0);
  Check('EnvAdd duplicate PATH final view — resolved from final PATH',
    Pos('envadd-path-final-view', LOut.StdOut) > 0);
end;


procedure TestTimeout;
var LOut: TProcessOutput; LStart: TInstant;
begin
  LStart := TInstant.Now;
  LOut := TCommand.New('/bin/sleep')
    .Arg('10')
    .Timeout(TDuration.FromMilliseconds(200))
    .Output;
  Check('Timeout — killed (signaled)', LOut.Status = psSignaled);
  Check('Timeout — elapsed < 2s', LStart.Elapsed.AsMilliseconds < 2000);
end;


begin
  LPassed := 0;
  LFailed := 0;

  WriteLn('--- nextpas.core.process full test suite ---');
  WriteLn('');

  TestRunEcho;
  TestRunFalse;
  TestRunStderr;
  TestCapture;
  TestRunIn;
  TestCommandBuilder;
  TestCommandDir;
  TestCommandStatus;
  TestSpawnAndWait;
  TestSpawnTryWait;
  TestSpawnKill;
  TestSpawnDetach;
  TestSpawnStdinPipe;
  TestSpawnStdoutReader;
  TestCommandEnv;
  TestSpawnError;
  TestSpawnExecFailRaisesException;
  TestSpawnChdirFailRaisesException;
  TestSpawnNullStdioFailureDoesNotLeakParentFds;
  TestEnvAddInheritsPath;
  TestEnvReplaceWithPathSearch;
  TestEnvReplaceSkipsNonExecutablePathShadow;
  TestEnvAddDuplicatePathUsesFinalResolvedView;
  TestTimeout;
  TestEnvAdd;
  TestStdinNull;
  TestStdoutNull;
  TestStderrPiped;
  TestDualPipeLargeOutput;
  TestMultipleSpawnSameCommand;
  TestEmptyArgs;
  TestTakeStderr;
  TestWaitWithOutputDualPipe;
  TestArgSingle;
  TestCommandValidation;

  WriteLn('');
  WriteLn('--- ', LPassed, ' passed, ', LFailed, ' failed ---');
  if LFailed > 0 then
    Halt(1);
end.
