# Process Module Final Polish — execvpe + Windows

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Complete the process module to full Go/Rust parity: PATH search with custom env + Windows L2 support.

**Architecture:** Two independent tasks. Task 1 adds parent-side PATH resolution (like Go's LookPath) so execve with custom env still finds binaries. Task 2 adds Windows conditional compilation to pipe.pas and child.pas.

**Tech Stack:** Object Pascal, nextpas.core platform layer, POSIX/Win32 API

---

### Task 1: execvpe — PATH search with custom env

**Files:**
- Create: `core/src/nextpas.core.process.pathresolve.pas`
- Modify: `core/src/nextpas.core.process.command.pas` (Spawn method)
- Test: `core/tests/nextpas.core.process/test_process/test_process.lpr`

**Problem:** When `Env([...])` or `EnvAdd(...)` is used, Spawn passes envp to `execve` (not `execvp`). `execve` requires an absolute path — it doesn't search PATH. So `Command('fpc').Env([...]).Spawn` fails with ENOENT even if `fpc` is in PATH.

**Solution (Go's approach):** Before fork, resolve the executable path by searching PATH from the provided env. This is what Go's `exec.LookPath` does.

**Step 1: Create pathresolve.pas**

```pascal
unit nextpas.core.process.pathresolve;
{$I nextpas.core.settings.inc}
interface
uses nextpas.core.text.base;

function ResolveExecutablePath(const AName: string;
  const AEnv: TStringArray): string;

implementation
uses
  nextpas.core.fs,
  nextpas.core.text.compare;

function ExtractPathFromEnv(const AEnv: TStringArray): string;
var I, P: Integer;
begin
  Result := '/usr/local/bin:/usr/bin:/bin';
  if AEnv = nil then Exit;
  for I := 0 to High(AEnv) do
  begin
    if TextStartsWith(AEnv[I], 'PATH=') then
    begin
      Result := Copy(AEnv[I], 6, Length(AEnv[I]) - 5);
      Exit;
    end;
  end;
end;

function ResolveExecutablePath(const AName: string;
  const AEnv: TStringArray): string;
var
  LPath, LDir: string;
  LStart, LColon: Integer;
  LCandidate: string;
begin
  if Pos('/', AName) > 0 then
    Exit(AName);

  LPath := ExtractPathFromEnv(AEnv);
  LStart := 1;
  while LStart <= Length(LPath) do
  begin
    LColon := LStart;
    while (LColon <= Length(LPath)) and (LPath[LColon] <> ':') do
      Inc(LColon);
    LDir := Copy(LPath, LStart, LColon - LStart);
    if LDir = '' then LDir := '.';
    LCandidate := LDir + '/' + AName;
    if Exists(LCandidate) then
      Exit(LCandidate);
    LStart := LColon + 1;
  end;
  Result := AName;
end;

end.
```

**Step 2: Modify command.pas Spawn**

In Spawn, before building LArgv, resolve the path:

```pascal
{ Resolve path if using custom env and path has no '/' }
if (FEnvMode <> pemInherit) and (Pos('/', FPath) = 0) then
begin
  LFinalEnv := BuildFinalEnv(FEnvMode, FEnvPairs);
  LResolvedPath := ResolveExecutablePath(FPath, LFinalEnv);
end
else
  LResolvedPath := FPath;
```

Then use `LResolvedPath` instead of `FPath` for LArgv[0] and the spawn call.

**Step 3: Add test**

```pascal
procedure TestEnvReplaceWithPathSearch;
var LOut: TProcessOutput;
begin
  LOut := TCommand.New('echo')
    .Args(['path search works'])
    .Env(['PATH=/bin:/usr/bin'])
    .Output;
  Check('Env replace + PATH search', Pos('path search works', LOut.StdOut) > 0);
end;
```

**Step 4: Run tests**

Expected: 45 tests pass, 0 leaks.

---

### Task 2: Windows L2 conditional compilation

**Files:**
- Modify: `core/src/nextpas.core.process.pipe.pas`
- Modify: `core/src/nextpas.core.process.child.pas`
- Modify: `core/src/nextpas.core.process.command.pas`

**Step 1: pipe.pas — add Windows branch**

```pascal
implementation
uses
  {$IFDEF NEXTPAS_UNIX}
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi;
  {$ENDIF}
  {$IFDEF NEXTPAS_WINDOWS}
  nextpas.core.platform.windows.ffi;
  {$ENDIF}

function TPipeReader.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
var LRead: {$IFDEF NEXTPAS_UNIX}ssize_t{$ELSE}DWORD{$ENDIF};
begin
  if FClosed then Exit(0);
  {$IFDEF NEXTPAS_UNIX}
  LRead := nextpas.core.platform.posix.ffi.read(FFd, @ABuf, ACount);
  if LRead <= 0 then Exit(0);
  Result := SizeUInt(LRead);
  {$ENDIF}
  {$IFDEF NEXTPAS_WINDOWS}
  LRead := 0;
  if not ReadFile(HANDLE(FFd), @ABuf, DWORD(ACount), @LRead, nil) then Exit(0);
  Result := SizeUInt(LRead);
  {$ENDIF}
end;
```

**Step 2: child.pas — Windows WaitWithOutput**

Replace poll-based concurrent read with Windows equivalent:
- Use `WaitForMultipleObjects` on pipe handles
- Or simpler: use threads (one per pipe) since Windows doesn't have poll for pipes

For initial implementation, use sequential read (acceptable for Windows where pipe buffers are larger):

```pascal
{$IFDEF NEXTPAS_WINDOWS}
{ Windows: sequential read (no poll equivalent for anonymous pipes) }
Result.StdOut := ReadAll(FStdoutReader);
Result.StdErr := ReadAll(FStderrReader);
{$ENDIF}
```

**Step 3: command.pas — Windows /dev/null → NUL**

```pascal
{$IFDEF NEXTPAS_UNIX}
LDevNull := nextpas.core.platform.posix.ffi.open(PAnsiChar('/dev/null'), 0, 0);
{$ENDIF}
{$IFDEF NEXTPAS_WINDOWS}
LDevNull := CreateFileA('NUL', ...);
{$ENDIF}
```

**Step 4: Verify Windows compile**

Use `-dNEXTPAS_FORCE_HOST_WINDOWS -Cn` for compile-only verification.

---

## Execution Order

1. Task 1 first (affects correctness, can test on Linux)
2. Task 2 second (Windows, compile-only verification)

## Success Criteria

- 45+ tests pass on Linux
- 0 memory leaks
- `Command('echo').Env(['PATH=/bin']).Output` works (PATH search)
- Windows compile passes with `-Cn`
