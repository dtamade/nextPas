# Process/FS/Path/Env Phase 2 Execution Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Finish the Phase 2 backlog for `process/fs/path/env` by landing the blocking `FsWalk` rewrite, environment/path/file follow-ups, and the remaining test coverage without regressing the focused gates already restored in Phase 1.

**Architecture:** Phase 2 should keep the same owner boundaries established in Phase 1: `fs.dir` delegates traversal mechanics to `platform.fs`, text/env behavior stays owned by `nextpas.core.os.env`, and performance changes must stay behind existing public APIs. The only cross-module work in this phase is controlled owner convergence: high-level `fs` and `process` code should stop duplicating platform behavior instead of adding new side paths.

**Tech Stack:** FPC Pascal, `nextpas.core` facade/base owner model, `platform_*` host seams, root `make focused FOCUS=...` verification, UTF-8 `AnsiString` under `{$H+}`.

---

## Scope and current truth

Phase 1 already landed the following commits on this lane:

- `11a0b7739` — P0 compile blockers
- `e88a3f0e5` — process correctness fixes
- `466fe8ee6` — fs safety fixes
- `11dbec603` — text/path/owner polish

This plan covers the remaining Phase 2 backlog described on 2026-06-15, with two important reality checks from the current tree:

1. `FsWalk` still uses the local recursive `DoWalk` implementation in [`core/src/nextpas.core.fs.dir.pas`](/home/dtamade/projects/nextPas/.worktrees/core-process-fs-path-env/core/src/nextpas.core.fs.dir.pas), even though [`platform_fs_walk`](/home/dtamade/projects/nextPas/.worktrees/core-process-fs-path-env/core/src/nextpas.core.platform.fs.pas) already implements non-recursive traversal and has its own focused gate.
2. The three `platform_process_spawn_*` variants are dead for production code, but **not dead for tests**: `test_platform_process` and `test_platform_error` still call `platform_process_spawn_piped(...)`. Phase 2 cannot simply delete them without first migrating those tests or explicitly keeping a narrow test seam.

## File map

**Primary production files**

- Modify: [`core/src/nextpas.core.fs.dir.pas`](/home/dtamade/projects/nextPas/.worktrees/core-process-fs-path-env/core/src/nextpas.core.fs.dir.pas)
- Modify: [`core/src/nextpas.core.platform.fs.pas`](/home/dtamade/projects/nextPas/.worktrees/core-process-fs-path-env/core/src/nextpas.core.platform.fs.pas)
- Modify: [`core/src/nextpas.core.fs.util.pas`](/home/dtamade/projects/nextPas/.worktrees/core-process-fs-path-env/core/src/nextpas.core.fs.util.pas)
- Modify: [`core/src/nextpas.core.fs.pas`](/home/dtamade/projects/nextPas/.worktrees/core-process-fs-path-env/core/src/nextpas.core.fs.pas)
- Modify: [`core/src/nextpas.core.os.env.pas`](/home/dtamade/projects/nextPas/.worktrees/core-process-fs-path-env/core/src/nextpas.core.os.env.pas)
- Modify: [`core/src/nextpas.core.process.pathresolve.pas`](/home/dtamade/projects/nextPas/.worktrees/core-process-fs-path-env/core/src/nextpas.core.process.pathresolve.pas)
- Modify: [`core/src/nextpas.core.path.pas`](/home/dtamade/projects/nextPas/.worktrees/core-process-fs-path-env/core/src/nextpas.core.path.pas)
- Modify: [`core/src/nextpas.core.fs.path.pas`](/home/dtamade/projects/nextPas/.worktrees/core-process-fs-path-env/core/src/nextpas.core.fs.path.pas)
- Modify or trim: [`core/src/nextpas.core.platform.process.pas`](/home/dtamade/projects/nextPas/.worktrees/core-process-fs-path-env/core/src/nextpas.core.platform.process.pas)

**Primary focused tests**

- Modify: [`core/tests/nextpas.core.fs/test_fs/test_fs.lpr`](/home/dtamade/projects/nextPas/.worktrees/core-process-fs-path-env/core/tests/nextpas.core.fs/test_fs/test_fs.lpr)
- Modify: [`core/tests/nextpas.core.fs/test_fs_text/test_fs_text.lpr`](/home/dtamade/projects/nextPas/.worktrees/core-process-fs-path-env/core/tests/nextpas.core.fs/test_fs_text/test_fs_text.lpr)
- Modify: [`core/tests/nextpas.core.os.env/test_os_env/test_os_env.lpr`](/home/dtamade/projects/nextPas/.worktrees/core-process-fs-path-env/core/tests/nextpas.core.os.env/test_os_env/test_os_env.lpr)
- Possibly modify: [`core/tests/nextpas.core.platform.process/test_platform_process/test_platform_process.lpr`](/home/dtamade/projects/nextPas/.worktrees/core-process-fs-path-env/core/tests/nextpas.core.platform.process/test_platform_process/test_platform_process.lpr)
- Possibly modify: [`core/tests/nextpas.core.platform.error/test_platform_error/test_platform_error.lpr`](/home/dtamade/projects/nextPas/.worktrees/core-process-fs-path-env/core/tests/nextpas.core.platform.error/test_platform_error/test_platform_error.lpr)
- Reuse: [`core/tests/nextpas.core.platform.fs/test_platform_fs_walk/test_platform_fs_walk.lpr`](/home/dtamade/projects/nextPas/.worktrees/core-process-fs-path-env/core/tests/nextpas.core.platform.fs/test_platform_fs_walk/test_platform_fs_walk.lpr)
- Reuse: [`core/tests/nextpas.core.platform.fs/test_platform_fs/test_platform_fs.lpr`](/home/dtamade/projects/nextPas/.worktrees/core-process-fs-path-env/core/tests/nextpas.core.platform.fs/test_platform_fs/test_platform_fs.lpr)
- Reuse: [`core/tests/nextpas.core.path/test_path/test_path.lpr`](/home/dtamade/projects/nextPas/.worktrees/core-process-fs-path-env/core/tests/nextpas.core.path/test_path/test_path.lpr)

## Sequencing summary

Run Phase 2 in this order:

1. `FsWalk` rewrite and traversal tests
2. `spawn_*` cleanup decision and migration
3. `ExpandEnv`
4. `ReadFile` allocation convergence
5. `CopyFile` buffer policy
6. buffer-size constant consolidation
7. path facade unification
8. `WriteFileLines` newline policy

That order keeps the only hard blocker (`FsWalk`) first, resolves the misleading dead-code item before deleting interfaces that tests still need, and postpones the higher-risk public-surface cleanup (`path` facade merge) until the functional work is already stable.

## Dependency graph

- Task 1 (`FsWalk` rewrite) blocks Task 2 (`FsWalk` behavior tests), because the tests must assert the new callback semantics and depth truth.
- Task 3 (`spawn_*` cleanup) depends on reading platform-process tests first. It is a design decision task, not a blind delete.
- Task 4 (`ExpandEnv`) is independent from fs work and can run after Task 2.
- Task 5 (`ReadFile` allocation convergence) should precede Task 6 (`CopyFile` buffer policy), because both touch `platform.fs` and `fs.util` and should land in separate commits.
- Task 7 (magic-number consolidation) should come after Tasks 1, 5, and 6 so it can fold in any new constants instead of creating churn twice.
- Task 8 (path facade unification) depends on the previous verification being green, because it is the broadest surface change in the phase.
- Task 9 (`WriteFileLines` newline policy) should land after Task 8 if the path work changes the `fs` facade tests anyway; otherwise it can be split before Task 8 as a low-risk independent slice.

---

## Task 1: Rewrite `FsWalk` to delegate to `platform_fs_walk`

**Why this is first**

The current `FsWalk` still duplicates traversal, carries a local `MAX_WALK_DEPTH = 256`, and bypasses the already-tested `platform_fs_walk` owner. This is the only remaining P0 item that is both real and already implemented one layer below.

**Files**

- Modify: [`core/src/nextpas.core.fs.dir.pas`](/home/dtamade/projects/nextPas/.worktrees/core-process-fs-path-env/core/src/nextpas.core.fs.dir.pas)
- Reuse truth from: [`core/src/nextpas.core.platform.fs.pas`](/home/dtamade/projects/nextPas/.worktrees/core-process-fs-path-env/core/src/nextpas.core.platform.fs.pas)
- Extend tests in: [`core/tests/nextpas.core.fs/test_fs/test_fs.lpr`](/home/dtamade/projects/nextPas/.worktrees/core-process-fs-path-env/core/tests/nextpas.core.fs/test_fs/test_fs.lpr)

### Task 1A: Add a small callback bridge record in `fs.dir`

- [ ] **Step 1: Define bridge state next to `FsWalk`**

```pascal
type
  PFsWalkBridge = ^TFsWalkBridge;
  TFsWalkBridge = record
    Callback: TWalkFunc;
    StopRequested: Boolean;
    RootPath: string;
  end;
```

Why: `platform_fs_walk` passes `Pointer` user data and path slices; `FsWalk` must translate that back to `TWalkFunc` without reintroducing recursive Pascal traversal.

- [ ] **Step 2: Add helpers to convert `TPlatformWalkEntry` into `TFileInfo`**

```pascal
function BuildWalkInfo(const AEntry: TPlatformWalkEntry): TFileInfo;
var
  LPath: string;
begin
  if AEntry.PathLen > 0 then
    SetString(LPath, AEntry.Path, AEntry.PathLen)
  else
    LPath := '';

  Result := Default(TFileInfo);
  Result.Name := LPath;
  Result.IsDir := AEntry.FileType = nextpas.core.platform.files.base.ftDirectory;
  Result.IsSymlink := AEntry.FileType = nextpas.core.platform.files.base.ftSymlink;
  case AEntry.FileType of
    nextpas.core.platform.files.base.ftRegular: Result.FileType := ftRegular;
    nextpas.core.platform.files.base.ftDirectory: Result.FileType := ftDirectory;
    nextpas.core.platform.files.base.ftSymlink: Result.FileType := ftSymlink;
    nextpas.core.platform.files.base.ftCharDevice: Result.FileType := ftCharDevice;
    nextpas.core.platform.files.base.ftBlockDevice: Result.FileType := ftBlockDevice;
    nextpas.core.platform.files.base.ftFifo: Result.FileType := ftFifo;
    nextpas.core.platform.files.base.ftSocket: Result.FileType := ftSocket;
  else
    Result.FileType := ftUnknown;
  end;
end;
```

Why: keep the conversion single-purpose and avoid rebuilding the old recursive logic.

### Task 1B: Replace recursive `DoWalk` with a `platform_fs_walk` callback bridge

- [ ] **Step 3: Implement the bridge callback**

```pascal
function FsWalkPlatformCallback(const AEntry: TPlatformWalkEntry;
  AUserData: Pointer): TPlatformWalkAction;
var
  LBridge: PFsWalkBridge;
  LInfo: TFileInfo;
  LPath: string;
  LErr: Exception;
  LKeepGoing: Boolean;
begin
  LBridge := PFsWalkBridge(AUserData);
  SetString(LPath, AEntry.Path, AEntry.PathLen);

  if AEntry.ErrorCode <> 0 then
  begin
    LInfo := Default(TFileInfo);
    LInfo.Name := LPath;
    LErr := EIOError.Create('walk failed (' + IntToStr(AEntry.ErrorCode) + '): ' + LPath);
    try
      LKeepGoing := LBridge^.Callback(LPath, LInfo, LErr);
    finally
      LErr.Free;
    end;
    if not LKeepGoing then
      Exit(pwaStop);
    if AEntry.FileType = nextpas.core.platform.files.base.ftDirectory then
      Exit(pwaSkipSubtree);
    Exit(pwaContinue);
  end;

  LInfo := BuildWalkInfo(AEntry);
  if not LBridge^.Callback(LPath, LInfo, nil) then
    Exit(pwaStop);
  Result := pwaContinue;
end;
```

Notes:
- Error delivery should stay callback-based, matching current `TWalkFunc` semantics.
- Returning `pwaSkipSubtree` on directory-open/stat failure preserves the current “report error, don’t recurse deeper” behavior.

- [ ] **Step 4: Rewrite `FsWalk` itself**

```pascal
procedure FsWalk(const ARoot: string; const AFunc: TWalkFunc);
var
  LBridge: TFsWalkBridge;
  LResult: Int32;
begin
  LBridge.Callback := AFunc;
  LBridge.StopRequested := False;
  LBridge.RootPath := ARoot;

  LResult := platform_fs_walk(PAnsiChar(ARoot), @FsWalkPlatformCallback,
    @LBridge, False);
  if (LResult <> PLATFORM_WALK_COMPLETED) and
     (LResult <> PLATFORM_WALK_STOPPED) then
    RaiseFsError(LResult, 'walk', ARoot);
end;
```

Notes:
- `PLATFORM_WALK_COMPLETED` and `PLATFORM_WALK_STOPPED` are control outcomes, not fs errors.
- `PLATFORM_WALK_BADARGS` should still map to a typed exception, so let `RaiseFsError` or a precondition guard handle empty root if desired.

### Task 1C: Remove the old recursive truth and source-contract it

- [ ] **Step 5: Delete these old elements from `fs.dir`**

Remove:
- local `MAX_WALK_DEPTH = 256`
- nested `DoWalk`
- direct `FsOpenDir` recursion inside `FsWalk`

- [ ] **Step 6: Add or update source-contract assertions in `test_fs`**

Add checks like:

```pascal
CheckContains(LBody, 'platform_fs_walk(PAnsiChar(ARoot), @FsWalkPlatformCallback,',
  'FsWalk delegates traversal to platform_fs_walk');
CheckAbsent(LBody, 'procedure DoWalk(',
  'FsWalk no longer embeds recursive Pascal traversal');
CheckAbsent(LBody, 'MAX_WALK_DEPTH = 256',
  'FsWalk depth truth comes from platform walk owner');
```

### Task 1 verification

- [ ] **Step 7: Run the narrow platform walk gate first**

Run:
```bash
make focused FOCUS=core/tests/nextpas.core.platform.fs/test_platform_fs_walk
```

Expected: PASS. This verifies the lower-level traversal owner before checking the facade.

- [ ] **Step 8: Run the fs facade gate**

Run:
```bash
make focused FOCUS=core/tests/nextpas.core.fs/test_fs
```

Expected: PASS with new `FsWalk` source-contract and behavior coverage.

- [ ] **Step 9: Commit**

```bash
git add core/src/nextpas.core.fs.dir.pas core/tests/nextpas.core.fs/test_fs/test_fs.lpr
git commit -m "refactor: delegate fs walk to platform walker"
```

**Estimate:** 0.5 day

**Risk:** Medium. The main risk is changing error callback shape around root errors and directory-open failures. Keep the first implementation conservative: preserve callback-driven errors, do not add symlink-following or new filtering behavior in this slice.

---

## Task 2: Add full `FsWalk` success-path tests

**Why this is separate**

Current `test_fs` only covers the error callback path. The real regression risk after Task 1 is traversal order/coverage, directory/file type mapping, max-depth truth, and symlink behavior.

**Files**

- Modify: [`core/tests/nextpas.core.fs/test_fs/test_fs.lpr`](/home/dtamade/projects/nextPas/.worktrees/core-process-fs-path-env/core/tests/nextpas.core.fs/test_fs/test_fs.lpr)

### Task 2A: Add a capture callback for success traversal

- [ ] **Step 1: Add capture state**

```pascal
var
  GWalkVisited: TStringArray;
  GWalkFileTypes: array of TFileType;
  GWalkDepthSeen: Int32;

function HasVisitedPath(const APath: string): Boolean;
var
  I: SizeInt;
begin
  for I := 0 to High(GWalkVisited) do
    if GWalkVisited[I] = APath then
      Exit(True);
  Result := False;
end;

function WalkCaptureCallback(const APath: string; const AInfo: TFileInfo;
  const AErr: Exception): Boolean;
var
  LIndex: SizeInt;
begin
  Check(AErr = nil, 'success walk callback should not receive error');
  LIndex := Length(GWalkVisited);
  SetLength(GWalkVisited, LIndex + 1);
  SetLength(GWalkFileTypes, LIndex + 1);
  GWalkVisited[LIndex] := APath;
  GWalkFileTypes[LIndex] := AInfo.FileType;
  if AInfo.IsDir and (APath <> '') then
    Inc(GWalkDepthSeen);
  Result := True;
end;
```

### Task 2B: Add normal traversal coverage

- [ ] **Step 2: Add a tree traversal test**

```pascal
procedure TestWalkVisitsFilesAndDirectories;
var
  LRoot: string;
begin
  LRoot := GTmpDir + '/walk-tree';
  FsMkdirAll(LRoot + '/a/b');
  FsWriteFile(LRoot + '/root.txt', TBytes.Create(1));
  FsWriteFile(LRoot + '/a/child.txt', TBytes.Create(2));
  FsWriteFile(LRoot + '/a/b/deep.txt', TBytes.Create(3));

  GWalkVisited := nil;
  GWalkFileTypes := nil;
  FsWalk(LRoot, @WalkCaptureCallback);

  Check(Length(GWalkVisited) >= 6, 'walk visits root + dirs + files');
  Check(GWalkVisited[0] = LRoot, 'walk visits root first');
end;
```

- [ ] **Step 3: Assert file/dir classification explicitly**

Example assertions:

```pascal
Check(FsLstat(LRoot).FileType = ftDirectory, 'fixture root is directory');
Check(HasVisitedPath(LRoot + '/root.txt'), 'root file visited');
Check(HasVisitedPath(LRoot + '/a'), 'child directory visited');
Check(HasVisitedPath(LRoot + '/a/b/deep.txt'), 'deep file visited');
```

### Task 2C: Add depth and symlink coverage

- [ ] **Step 4: Add a max-depth contract test by delegating truth to platform owner**

Do not hard-code 256 in the facade test body. Instead, build a tree deeper than 260 and verify:
- traversal stops before the deepest leaf
- the facade does not locally define its own max depth anymore

Example source contract:

```pascal
CheckAbsent(LBody, 'MAX_WALK_DEPTH = 256',
  'fs facade no longer owns max walk depth');
```

- [ ] **Step 5: Add symlink no-follow coverage on Unix**

```pascal
procedure TestWalkDoesNotDescendSymlinkDirectory;
var
  LRoot, LTarget, LLink: string;
begin
  LRoot := GTmpDir + '/walk-link-root';
  LTarget := LRoot + '/target';
  LLink := LRoot + '/link-target';
  FsMkdirAll(LTarget);
  FsWriteFile(LTarget + '/inside.txt', TBytes.Create(1));
  FsSymlink(LTarget, LLink);

  GWalkVisited := nil;
  FsWalk(LRoot, @WalkCaptureCallback);

  Check(HasVisitedPath(LLink), 'symlink entry visited');
  Check(not HasVisitedPath(LLink + '/inside.txt'),
    'symlink target subtree not descended');
end;
```

### Task 2 verification

- [ ] **Step 6: Run the fs gate**

Run:
```bash
make focused FOCUS=core/tests/nextpas.core.fs/test_fs
```

Expected: PASS with both error-path and success-path traversal checks.

- [ ] **Step 7: Commit**

```bash
git add core/tests/nextpas.core.fs/test_fs/test_fs.lpr
git commit -m "test: cover fs walk success traversal"
```

**Estimate:** 0.5 day

**Risk:** Low to medium. The only subtlety is keeping the tests platform-neutral enough outside Unix symlink-specific branches.

---

## Task 3: Resolve the `platform_process_spawn_*` cleanup item correctly

**Current truth**

The user backlog says `platform_process_spawn_piped`, `platform_process_spawn_cwd`, and `platform_process_spawn_piped_cwd` are dead code. In production code that is mostly true: `TCommand.Spawn` uses `platform_process_spawn_fds`. But the current tree still has test references in:

- [`core/tests/nextpas.core.platform.process/test_platform_process/test_platform_process.lpr`](/home/dtamade/projects/nextPas/.worktrees/core-process-fs-path-env/core/tests/nextpas.core.platform.process/test_platform_process/test_platform_process.lpr)
- [`core/tests/nextpas.core.platform.error/test_platform_error/test_platform_error.lpr`](/home/dtamade/projects/nextPas/.worktrees/core-process-fs-path-env/core/tests/nextpas.core.platform.error/test_platform_error/test_platform_error.lpr)

So this task is: migrate or narrow the seam, then delete only what is truly dead.

**Recommended approach**

Keep `platform_process_spawn_fds` as the single production spawn primitive. Migrate tests away from the three convenience wrappers. Only then delete the wrappers from the platform surface.

**Files**

- Modify: [`core/src/nextpas.core.platform.process.pas`](/home/dtamade/projects/nextPas/.worktrees/core-process-fs-path-env/core/src/nextpas.core.platform.process.pas)
- Modify: [`core/tests/nextpas.core.platform.process/test_platform_process/test_platform_process.lpr`](/home/dtamade/projects/nextPas/.worktrees/core-process-fs-path-env/core/tests/nextpas.core.platform.process/test_platform_process/test_platform_process.lpr)
- Modify: [`core/tests/nextpas.core.platform.error/test_platform_error/test_platform_error.lpr`](/home/dtamade/projects/nextPas/.worktrees/core-process-fs-path-env/core/tests/nextpas.core.platform.error/test_platform_error/test_platform_error.lpr)

### Task 3A: Migrate tests to explicit pipe helpers + `spawn_fds`

- [ ] **Step 1: Add a test-owned helper in `test_platform_process`**

```pascal
function SpawnPipedForTest(const APath: PAnsiChar; AArgv: PPAnsiChar;
  out AProc: TPlatformProcess; out APipes: TPlatformProcessPipes): Int32;
var
  LStdinRead, LStdoutWrite, LStderrWrite: PtrInt;
  LFailStage: TPlatformProcessSpawnStage;
begin
  FillChar(APipes, SizeOf(APipes), $FF);
  LStdinRead := -1;
  LStdoutWrite := -1;
  LStderrWrite := -1;

  Result := platform_process_create_pipe(LStdinRead, APipes.StdinWrite);
  if Result <> 0 then
    Exit;
  Result := platform_process_create_pipe(APipes.StdoutRead, LStdoutWrite);
  if Result <> 0 then
  begin
    platform_process_close_handle(LStdinRead);
    platform_process_close_handle(APipes.StdinWrite);
    Exit;
  end;
  Result := platform_process_create_pipe(APipes.StderrRead, LStderrWrite);
  if Result <> 0 then
  begin
    platform_process_close_handle(LStdinRead);
    platform_process_close_handle(APipes.StdinWrite);
    platform_process_close_handle(APipes.StdoutRead);
    platform_process_close_handle(LStdoutWrite);
    Exit;
  end;
  Result := platform_process_spawn_fds(APath, AArgv, nil, nil,
    LStdinRead, LStdoutWrite, LStderrWrite, AProc, LFailStage);
  platform_process_close_handle(LStdinRead);
  platform_process_close_handle(LStdoutWrite);
  platform_process_close_handle(LStderrWrite);
  if Result <> 0 then
  begin
    platform_process_close_handle(APipes.StdinWrite);
    platform_process_close_handle(APipes.StdoutRead);
    platform_process_close_handle(APipes.StderrRead);
  end;
end;
```

This keeps the convenience local to the test owner while still exercising the real supported spawn primitive.

- [ ] **Step 2: Replace each `platform_process_spawn_piped(...)` call in tests**

Target patterns:

```pascal
Check(platform_process_spawn_piped('/bin/echo', @LArgv[0], nil, P, Pipes) = 0,
  'spawn piped');
```

Replace with test-owned helper invocations.

- [ ] **Step 3: Add one explicit cwd test on `spawn_fds` before deleting `spawn_cwd` wrappers**

```pascal
procedure TestSpawnFdsCwd;
var
  P: TPlatformProcess;
  Pipes: TPlatformProcessPipes;
  R: TPlatformProcessResult;
  LArgv: array[0..2] of PAnsiChar;
  LBuf: array[0..255] of AnsiChar;
  LRead: PtrInt;
begin
  LArgv[0] := '/bin/pwd';
  LArgv[1] := nil;
  LArgv[2] := nil;
  Check(SpawnPipedForTest('/bin/pwd', @LArgv[0], P, Pipes) = 0, 'spawn pwd');
  nextpas.core.platform.posix.ffi.close(Pipes.StdinWrite);
  FillChar(LBuf, SizeOf(LBuf), 0);
  LRead := nextpas.core.platform.posix.ffi.read(Pipes.StdoutRead, @LBuf[0], SizeOf(LBuf));
  Check(LRead > 0, 'pwd returned output');
  nextpas.core.platform.posix.ffi.close(Pipes.StdoutRead);
  nextpas.core.platform.posix.ffi.close(Pipes.StderrRead);
  platform_process_wait(P, R);
  Check(R.ExitCode = 0, 'pwd exits 0');
end;
```

For the real test, wire `SpawnPipedForTest` through a second helper that accepts `ACwd` and forwards it to `platform_process_spawn_fds(..., ACwd, ...)`.

### Task 3B: Delete only the truly dead wrappers

- [ ] **Step 4: Remove the three wrapper declarations and implementations**

Delete from `platform.process` only after the tests above are migrated:
- `platform_process_spawn_piped`
- `platform_process_spawn_cwd`
- `platform_process_spawn_piped_cwd`

Keep:
- `platform_process_spawn`
- `platform_process_spawn_fds`
- `platform_process_run`
- helper functions for pipe/null/close

### Task 3 verification

- [ ] **Step 5: Run focused gates**

Run:
```bash
make focused FOCUS=core/tests/nextpas.core.platform.process/test_platform_process
make focused FOCUS=core/tests/nextpas.core.platform.error/test_platform_error
make focused FOCUS=core/tests/nextpas.core.process/test_process
```

Expected: PASS. Platform tests should still verify the behavior, but now through the single supported spawn seam.

- [ ] **Step 6: Commit**

```bash
git add core/src/nextpas.core.platform.process.pas \
  core/tests/nextpas.core.platform.process/test_platform_process/test_platform_process.lpr \
  core/tests/nextpas.core.platform.error/test_platform_error/test_platform_error.lpr
git commit -m "refactor: drop unused process spawn wrappers"
```

**Estimate:** 0.5 to 1 day

**Risk:** Medium. The risk is test churn around low-level FD ownership. Keep the migration mechanical and verify every close path.

---

## Task 4: Add `ExpandEnv` to `nextpas.core.os.env`

**Why now**

This is the next clean P1 item and is logically isolated. It also has a ready owner: `nextpas.core.os.env` already owns validation, lookup, and case-sensitivity policy.

**Recommended behavior**

Support `${VAR}` expansion only in Phase 2. Do not expand `%VAR%` or `$VAR` in this slice unless the user extends scope. Preserve unknown variables as empty strings unless a stronger contract is desired and documented.

**Files**

- Modify: [`core/src/nextpas.core.os.env.pas`](/home/dtamade/projects/nextPas/.worktrees/core-process-fs-path-env/core/src/nextpas.core.os.env.pas)
- Modify: [`core/tests/nextpas.core.os.env/test_os_env/test_os_env.lpr`](/home/dtamade/projects/nextPas/.worktrees/core-process-fs-path-env/core/tests/nextpas.core.os.env/test_os_env/test_os_env.lpr)

### Task 4A: Add the public API and parser

- [ ] **Step 1: Add the public function declaration**

```pascal
function ExpandEnv(const AValue: string): string;
```

Place it next to `GetEnv`/`HasEnv` in the interface.

- [ ] **Step 2: Implement a single-pass `${...}` parser**

```pascal
function ExpandEnv(const AValue: string): string;
var
  I, LStart: Integer;
  LName: string;
begin
  Result := '';
  I := 1;
  while I <= Length(AValue) do
  begin
    if (AValue[I] = '$') and (I < Length(AValue)) and (AValue[I + 1] = '{') then
    begin
      LStart := I + 2;
      I := LStart;
      while (I <= Length(AValue)) and (AValue[I] <> '}') do
        Inc(I);
      if I > Length(AValue) then
        raise EArgumentError.Create('unterminated ${...} in environment expansion');
      LName := Copy(AValue, LStart, I - LStart);
      ValidateEnvName(LName);
      Result := Result + GetEnvironmentVariable(LName);
      Inc(I);
      Continue;
    end;
    Result := Result + AValue[I];
    Inc(I);
  end;
end;
```

If repeated string concatenation is too noisy for long inputs, move to a `TStringBuilder`-style local buffer only if the codebase already has one. Otherwise keep the first version simple and correct.

### Task 4B: Add focused env tests

- [ ] **Step 3: Add round-trip expansion tests**

```pascal
procedure Test_ExpandEnv_Basic;
begin
  SetEnv('NEXTPAS_TEST_EXPAND', 'hello');
  CheckEqual('say hello', ExpandEnv('say ${NEXTPAS_TEST_EXPAND}'),
    'ExpandEnv expands ${VAR}');
  UnsetEnv('NEXTPAS_TEST_EXPAND');
end;
```

- [ ] **Step 4: Add edge tests**

Cover:
- missing variable becomes empty string
- adjacent variables: `${A}${B}`
- no markers returns original string
- invalid syntax raises
- invalid env name inside `${...}` raises

Example:

```pascal
procedure Test_ExpandEnv_Unterminated;
var
  LGot: Boolean;
begin
  LGot := False;
  try
    ExpandEnv('bad ${NEXTPAS_TEST_EXPAND');
  except
    on E: EArgumentError do
      LGot := True;
  end;
  Check(LGot, 'unterminated placeholder rejected');
end;
```

### Task 4 verification

- [ ] **Step 5: Run focused gate**

Run:
```bash
make focused FOCUS=core/tests/nextpas.core.os.env/test_os_env
```

Expected: PASS with new expansion tests.

- [ ] **Step 6: Commit**

```bash
git add core/src/nextpas.core.os.env.pas core/tests/nextpas.core.os.env/test_os_env/test_os_env.lpr
git commit -m "feat: add env placeholder expansion"
```

**Estimate:** 0.5 day

**Risk:** Low. The only design risk is missing or overreaching syntax. Keep Phase 2 scoped to `${VAR}`.

---

## Task 5: Remove the double allocation in `ReadFile`

**Current truth**

`platform_fs_read_file` allocates with `GetMem`, then `FsReadFile` allocates a `TBytes` result and copies the whole buffer before freeing the platform allocation. That is correct but wasteful.

**Recommended direction**

Do not try to alias a `TBytes` directly onto `GetMem` memory. Under FPC managed arrays, that creates ownership and lifetime hazards. Instead, introduce an alternate owner path that reads directly into a caller-owned `TBytes` buffer.

**Files**

- Modify: [`core/src/nextpas.core.platform.fs.pas`](/home/dtamade/projects/nextPas/.worktrees/core-process-fs-path-env/core/src/nextpas.core.platform.fs.pas)
- Modify: [`core/src/nextpas.core.fs.util.pas`](/home/dtamade/projects/nextPas/.worktrees/core-process-fs-path-env/core/src/nextpas.core.fs.util.pas)
- Extend: [`core/tests/nextpas.core.platform.fs/test_platform_fs/test_platform_fs.lpr`](/home/dtamade/projects/nextPas/.worktrees/core-process-fs-path-env/core/tests/nextpas.core.platform.fs/test_platform_fs/test_platform_fs.lpr)
- Extend if needed: [`core/tests/nextpas.core.fs/test_fs/test_fs.lpr`](/home/dtamade/projects/nextPas/.worktrees/core-process-fs-path-env/core/tests/nextpas.core.fs/test_fs/test_fs.lpr)

### Task 5A: Add a direct-read API instead of trying to transfer ownership

- [ ] **Step 1: Add a new platform helper**

```pascal
function platform_fs_read_file_into(const APath: PAnsiChar;
  AData: Pointer; ALen: PtrUInt): Int32;
```

Implementation pattern:
- stat size first
- caller allocates exact `TBytes`
- open and read exactly `ALen`
- no `GetMem` ownership transfer

- [ ] **Step 2: Rewrite `FsReadFile` to use the new helper**

```pascal
function FsReadFile(const APath: string): TBytes;
var
  LSize: Int64;
  LResult: Int32;
begin
  LResult := platform_fs_file_size(PAnsiChar(APath), LSize);
  if LResult <> 0 then
    RaiseFsError(LResult, 'read file size', APath);
  SetLength(Result, LSize);
  if LSize = 0 then
    Exit;
  LResult := platform_fs_read_file_into(PAnsiChar(APath), @Result[0], PtrUInt(LSize));
  if LResult <> 0 then
    RaiseFsError(LResult, 'read file', APath);
end;
```

This keeps ownership entirely in Pascal-managed memory and drops the extra copy.

### Task 5B: Preserve the existing raw-buffer helper only if still needed

- [ ] **Step 3: Audit `platform_fs_read_file` call sites**

If `FsReadFile` is the only caller, remove `platform_fs_read_file` and `platform_fs_free_buf` entirely.

If another module still uses raw ownership transfer, keep the old helper but mark it as the minority path, not the facade default.

### Task 5 verification

- [ ] **Step 4: Run focused gates**

Run:
```bash
make focused FOCUS=core/tests/nextpas.core.platform.fs/test_platform_fs
make focused FOCUS=core/tests/nextpas.core.fs/test_fs
make focused FOCUS=core/tests/nextpas.core.fs/test_fs_text
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add core/src/nextpas.core.platform.fs.pas core/src/nextpas.core.fs.util.pas \
  core/tests/nextpas.core.platform.fs/test_platform_fs/test_platform_fs.lpr
git commit -m "perf: read files directly into managed buffers"
```

**Estimate:** 0.5 day

**Risk:** Medium. The subtle risk is TOCTOU between stat and read if the file shrinks. Decide and document one contract:
- either treat short read as an error
- or re-stat / shrink the result buffer after read

For Phase 2, keeping short read as a typed I/O error is the safest choice.

---

## Task 6: Improve `platform_fs_copy_file` buffer policy

**Current truth**

`platform_fs_copy_file` currently uses a fixed `array[0..8191] of Byte`. That is simple but small for larger files. Since `FsCopyFile` now delegates to the platform owner, this is the right level to tune.

**Files**

- Modify: [`core/src/nextpas.core.platform.fs.pas`](/home/dtamade/projects/nextPas/.worktrees/core-process-fs-path-env/core/src/nextpas.core.platform.fs.pas)
- Extend source-contracts in: [`core/tests/nextpas.core.platform.fs/test_platform_fs/test_platform_fs.lpr`](/home/dtamade/projects/nextPas/.worktrees/core-process-fs-path-env/core/tests/nextpas.core.platform.fs/test_platform_fs/test_platform_fs.lpr)

### Task 6A: Move the copy buffer size to a named constant

- [ ] **Step 1: Add a local constant first**

```pascal
const
  PLATFORM_FS_COPY_BUFFER_SIZE = 65536;
```

Then replace:

```pascal
LBuf: array[0..8191] of Byte;
```

with:

```pascal
LBuf: array[0..PLATFORM_FS_COPY_BUFFER_SIZE - 1] of Byte;
```

### Task 6B: Only add dynamic sizing if measurement or host constraints justify it

- [ ] **Step 2: Keep Phase 2 conservative**

Recommended Phase 2 implementation: use a larger fixed constant, not a dynamic heap buffer. It is simpler, stays on-stack, and already removes the worst small-buffer issue.

Only choose dynamic sizing if you also add:
- an upper bound constant
- an explicit reason tied to host behavior
- regression tests that keep it deterministic

### Task 6 verification

- [ ] **Step 3: Run focused gates**

Run:
```bash
make focused FOCUS=core/tests/nextpas.core.platform.fs/test_platform_fs
make focused FOCUS=core/tests/nextpas.core.fs/test_fs
```

Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add core/src/nextpas.core.platform.fs.pas core/tests/nextpas.core.platform.fs/test_platform_fs/test_platform_fs.lpr
git commit -m "perf: raise platform copy buffer size"
```

**Estimate:** 0.25 day

**Risk:** Low.

---

## Task 7: Consolidate scattered buffer-size magic numbers

**Current truth**

This lane owns several hard-coded sizes already visible in the touched modules: `1024`, `4096`, `65536`, `8192`, path buffer sizes, cwd buffers, readlink growth caps, and pipe drain sizes.

**Recommendation**

Do not attempt a repo-wide cleanup in this phase. Limit the consolidation to numbers owned by the modules touched here. Add named constants in the nearest stable owner. If a constant is shared by unrelated modules, move only then to `nextpas.core.base`.

**Files**

- Modify: [`core/src/nextpas.core.base.pas`](/home/dtamade/projects/nextPas/.worktrees/core-process-fs-path-env/core/src/nextpas.core.base.pas) only if a constant is truly shared
- Otherwise modify local owners:
  - [`core/src/nextpas.core.platform.fs.pas`](/home/dtamade/projects/nextPas/.worktrees/core-process-fs-path-env/core/src/nextpas.core.platform.fs.pas)
  - [`core/src/nextpas.core.fs.util.pas`](/home/dtamade/projects/nextPas/.worktrees/core-process-fs-path-env/core/src/nextpas.core.fs.util.pas)
  - [`core/src/nextpas.core.path.pas`](/home/dtamade/projects/nextPas/.worktrees/core-process-fs-path-env/core/src/nextpas.core.path.pas)
  - [`core/src/nextpas.core.fs.path.pas`](/home/dtamade/projects/nextPas/.worktrees/core-process-fs-path-env/core/src/nextpas.core.fs.path.pas)
  - [`core/src/nextpas.core.process.pipe.pas`](/home/dtamade/projects/nextPas/.worktrees/core-process-fs-path-env/core/src/nextpas.core.process.pipe.pas)

### Task 7A: Define ownership rules before moving constants

- [ ] **Step 1: Classify each number before editing**

Suggested buckets:
- path scratch buffer sizes stay with path owners
- fs readlink/getcwd growth limits stay with `fs.util`
- pipe drain chunk stays with `process.pipe`
- generic byte-count constants move to `core.base` only if at least two unrelated owners use the same concept

### Task 7B: Replace inline literals with named constants

- [ ] **Step 2: Rename only touched-module literals**

Examples:

```pascal
const
  FS_READLINK_STACK_BUF_SIZE = 1024;
  FS_READLINK_MAX_BUF_SIZE = 65536;
  FS_GETCWD_STACK_BUF_SIZE = 1024;
  FS_GETCWD_MAX_BUF_SIZE = 65536;
```

Avoid fake deduplication such as one `GLOBAL_BUFFER_SIZE` for unrelated semantics.

### Task 7 verification

- [ ] **Step 3: Run narrow gates**

Run:
```bash
make focused FOCUS=core/tests/nextpas.core.fs/test_fs
make focused FOCUS=core/tests/nextpas.core.path/test_path
make focused FOCUS=core/tests/nextpas.core.process/test_process_pipe_contract
```

Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add core/src/nextpas.core.base.pas core/src/nextpas.core.fs.util.pas \
  core/src/nextpas.core.path.pas core/src/nextpas.core.fs.path.pas \
  core/src/nextpas.core.process.pipe.pas
git commit -m "refactor: name local buffer size constants"
```

**Estimate:** 0.5 day

**Risk:** Low if kept local. High if expanded into repo-wide “cleanup”; do not do that in Phase 2.

---

## Task 8: Unify `nextpas.core.path` and `nextpas.core.fs.path`

**Current truth**

Both modules wrap `platform.path` with overlapping logic and separate local buffer strategies. This is a real duplication issue, but it is also the broadest public-surface change in the phase.

**Recommendation**

Unify by choosing **one implementation owner** and turning the other into a thin facade adapter in Phase 2. Do not delete both APIs or force all call sites to rewrite in this slice.

The safer choice is:
- keep `nextpas.core.fs.path` as the `fs`-facing owner used by `nextpas.core.fs`
- make `nextpas.core.path` a compatibility facade over that implementation

Why: `nextpas.core.fs` already re-exports `fs.path` names, and `fs.dir` / `fs.util` already depend there.

**Files**

- Modify: [`core/src/nextpas.core.path.pas`](/home/dtamade/projects/nextPas/.worktrees/core-process-fs-path-env/core/src/nextpas.core.path.pas)
- Possibly simplify: [`core/src/nextpas.core.fs.path.pas`](/home/dtamade/projects/nextPas/.worktrees/core-process-fs-path-env/core/src/nextpas.core.fs.path.pas)
- Reuse tests in:
  - [`core/tests/nextpas.core.path/test_path/test_path.lpr`](/home/dtamade/projects/nextPas/.worktrees/core-process-fs-path-env/core/tests/nextpas.core.path/test_path/test_path.lpr)
  - [`core/tests/nextpas.core.fs/test_fs/test_fs.lpr`](/home/dtamade/projects/nextPas/.worktrees/core-process-fs-path-env/core/tests/nextpas.core.fs/test_fs/test_fs.lpr)

### Task 8A: Choose `fs.path` as the implementation owner

- [ ] **Step 1: Rewrite `nextpas.core.path` functions to forward**

Example:

```pascal
uses
  nextpas.core.fs.path;

function PathDir(const APath: string): string;
begin
  Result := FsPathDir(APath);
end;

function PathNormalize(const APath: string): string;
begin
  Result := FsPathClean(APath);
end;
```

Map the compatibility names explicitly:
- `PathNormalize -> FsPathClean`
- `PathIsAbsolute -> FsPathIsAbs`
- `PathWithoutExt -> FsPathWithoutExt`
- `PathRelative -> FsPathRelative`

- [ ] **Step 2: Keep public behavior stable**

Do not remove these compatibility APIs in Phase 2:
- `ExtractFilePath`
- `ExtractFileName`
- `ExtractFileExt`
- `ChangeFileExt`

They should simply delegate through the unified implementation path.

### Task 8B: Add source-contract coverage for the new owner

- [ ] **Step 3: Extend `test_path` source contracts**

Add assertions like:

```pascal
CheckContains(LSource, 'uses' + LineEnding + '  nextpas.core.fs.path;',
  'core.path now delegates to fs.path owner');
CheckAbsent(LSource, 'BUF_SIZE = 4096',
  'core.path no longer owns a duplicate buffer strategy');
```

### Task 8 verification

- [ ] **Step 4: Run focused gates**

Run:
```bash
make focused FOCUS=core/tests/nextpas.core.path/test_path
make focused FOCUS=core/tests/nextpas.core.fs/test_fs
make focused FOCUS=core/tests/nextpas.core.fs/test_fs_facade
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add core/src/nextpas.core.path.pas core/tests/nextpas.core.path/test_path/test_path.lpr
git commit -m "refactor: unify path facade over fs.path"
```

**Estimate:** 0.5 to 1 day

**Risk:** Medium to high. This touches a public compatibility unit. Keep the change as pure delegation and avoid renaming public functions in Phase 2.

---

## Task 9: Make `WriteFileLines` newline policy explicit and cross-platform

**Current truth**

`WriteFileLines` appends `#10` unconditionally in [`core/src/nextpas.core.fs.pas`](/home/dtamade/projects/nextPas/.worktrees/core-process-fs-path-env/core/src/nextpas.core.fs.pas). `ReadFileLines` already accepts CRLF and LF, so writes are the only missing half.

**Recommendation**

Introduce a small local line-ending helper and make the behavior explicit:
- Unix: `#10`
- Windows: `#13#10`

Do not change `AppendFileLine` separately if it already routes through text APIs; update it if needed to share the same helper.

**Files**

- Modify: [`core/src/nextpas.core.fs.pas`](/home/dtamade/projects/nextPas/.worktrees/core-process-fs-path-env/core/src/nextpas.core.fs.pas)
- Modify: [`core/tests/nextpas.core.fs/test_fs_text/test_fs_text.lpr`](/home/dtamade/projects/nextPas/.worktrees/core-process-fs-path-env/core/tests/nextpas.core.fs/test_fs_text/test_fs_text.lpr)

### Task 9A: Add a line-ending helper and reuse it

- [ ] **Step 1: Add helper**

```pascal
function NativeLineEndingBytes: TBytes;
begin
{$IFDEF NEXTPAS_WINDOWS}
  Result := TBytes.Create(13, 10);
{$ELSE}
  Result := TBytes.Create(10);
{$ENDIF}
end;
```

Then use it in `WriteFileLines` instead of hard-coded `10`.

A more allocation-friendly variant is better in real code:

```pascal
function NativeLineEndingText: string;
begin
{$IFDEF NEXTPAS_WINDOWS}
  Result := #13#10;
{$ELSE}
  Result := #10;
{$ENDIF}
end;
```

Then build bytes through the existing UTF-8 helper.

### Task 9B: Add focused tests

- [ ] **Step 2: Add newline-specific assertions**

Example:

```pascal
procedure TestWriteFileLinesUsesNativeLineEnding;
var
  LPath, LRaw: string;
begin
  LPath := TmpPath + '.txt';
  WriteFileLines(LPath, TStringArray.Create('a', 'b'));
  LRaw := ReadFileText(LPath);
{$IFDEF NEXTPAS_WINDOWS}
  Check(Pos(#13#10, LRaw) > 0, 'CRLF written on Windows');
{$ELSE}
  Check(Pos(#10, LRaw) > 0, 'LF written on Unix');
  Check(Pos(#13#10, LRaw) = 0, 'Unix does not force CRLF');
{$ENDIF}
end;
```

Use `ReadFile` instead of `ReadFileText` if you want to inspect exact bytes without normalization concerns.

### Task 9 verification

- [ ] **Step 3: Run focused gate**

Run:
```bash
make focused FOCUS=core/tests/nextpas.core.fs/test_fs_text
```

Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add core/src/nextpas.core.fs.pas core/tests/nextpas.core.fs/test_fs_text/test_fs_text.lpr
git commit -m "fix: use native line endings for file line writes"
```

**Estimate:** 0.25 day

**Risk:** Low.

---

## Recommended verification schedule

Run these after each slice, not only at the end:

```bash
make focused FOCUS=core/tests/nextpas.core.platform.fs/test_platform_fs_walk
make focused FOCUS=core/tests/nextpas.core.fs/test_fs
make focused FOCUS=core/tests/nextpas.core.os.env/test_os_env
make focused FOCUS=core/tests/nextpas.core.platform.process/test_platform_process
make focused FOCUS=core/tests/nextpas.core.platform.error/test_platform_error
make focused FOCUS=core/tests/nextpas.core.process/test_process
make focused FOCUS=core/tests/nextpas.core.process/test_process_pipe_contract
make focused FOCUS=core/tests/nextpas.core.fs/test_fs_text
make focused FOCUS=core/tests/nextpas.core.path/test_path
make focused FOCUS=core/tests/nextpas.core.fs/test_fs_facade
make focused FOCUS=core/tests/nextpas.core.platform.fs/test_platform_fs
```

End-of-phase hygiene:

```bash
git diff --check
make hygiene
```

## Estimated effort

- Task 1 `FsWalk` rewrite: 0.5 day
- Task 2 `FsWalk` tests: 0.5 day
- Task 3 `spawn_*` cleanup and test migration: 0.5 to 1 day
- Task 4 `ExpandEnv`: 0.5 day
- Task 5 `ReadFile` allocation convergence: 0.5 day
- Task 6 `CopyFile` buffer policy: 0.25 day
- Task 7 magic-number consolidation: 0.5 day
- Task 8 path facade unification: 0.5 to 1 day
- Task 9 native line endings: 0.25 day

**Total:** about 4 to 5 working days as small, reviewable commits.

## Risk summary

- **Highest risk:** Task 8 path facade unification, because it changes a public compatibility surface.
- **Moderate risk:** Task 1 `FsWalk` rewrite and Task 5 `ReadFile` allocation convergence, because both touch correctness-sensitive owner boundaries.
- **Moderate risk:** Task 3 process spawn cleanup, because low-level tests currently depend on the wrappers marked as dead.
- **Low risk:** Task 4 `ExpandEnv`, Task 6 copy buffer tuning, Task 7 local constant naming, Task 9 line ending fix.

## Merge guidance

Keep Phase 2 as a sequence of small commits. Do not batch Tasks 1 through 9 into one landing slice. The clean review boundaries are:

1. `FsWalk` rewrite
2. `FsWalk` test completion
3. process wrapper cleanup
4. env expansion
5. file-read allocation convergence
6. copy buffer + local constants
7. path facade unification
8. newline policy

That keeps every commit reversible and matches the lane rules in `AGENTS.md`.
