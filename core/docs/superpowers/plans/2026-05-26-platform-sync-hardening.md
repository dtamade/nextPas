# platform.sync Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Harden `nextpas.core.platform.sync` into a precise, portable L0 contract for the L1 `sync` module.

**Architecture:** Keep `nextpas.core.platform.sync` as the public contract, but split platform-specific implementation and FFI details away from the shared API. Fix the RWLock API so Unix and Windows can both implement it honestly, then add focused Linux and Win64 compile gates.

**Tech Stack:** Free Pascal 3.3.1, ObjFPC mode, pthread/futex on Linux, Windows SRWLOCK/CONDITION_VARIABLE/WaitOnAddress via explicit FFI declarations.

---

## File Structure

- Modify: `src/nextpas.core.platform.sync.pas`
  - Public low-level synchronization contract.
  - Add explicit read/write RWLock release functions.
  - Use aligned opaque records.
  - Dispatch Linux and Windows implementations with target-accurate guards.
- Create: `src/nextpas.core.platform.sync.windows.ffi.pas`
  - Narrow external declarations for Windows synchronization APIs missing from FPC's `Windows` unit.
- Modify: `src/nextpas.core.sync.rwlock.pas`
  - Call `platform_rwlock_rdunlock` and `platform_rwlock_wrunlock`.
- Modify: `tests/nextpas.core.platform.sync/test_platform_sync/test_platform_sync.lpr`
  - Add behavior tests for read-held/write-held conflicts and exact timeout/busy categories.
- Modify: `tests/nextpas.core.platform.sync/test_platform_sync_sizes/test_platform_sync_sizes.lpr`
  - Add alignment tests for standalone, embedded, and array storage.
- Modify: `../build/verify_local.sh`
  - Add focused Linux `platform.sync` verification and Win64 compile-only verification once the Windows FFI compiles.

## Task 1: Split RWLock Release by Mode

**Files:**
- Modify: `src/nextpas.core.platform.sync.pas`
- Modify: `src/nextpas.core.sync.rwlock.pas`
- Test: `tests/nextpas.core.platform.sync/test_platform_sync/test_platform_sync.lpr`

- [ ] **Step 1: Add failing platform RWLock tests**

Add these tests to `tests/nextpas.core.platform.sync/test_platform_sync/test_platform_sync.lpr`:

```pascal
procedure TestRwLockWriteBlockedByReader;
var
  LRwLock: TPlatformRwLock;
  LRet: Int32;
begin
  CheckEqual(Int64(0), Int64(platform_rwlock_init(LRwLock)), 'init');
  CheckEqual(Int64(0), Int64(platform_rwlock_rdlock(LRwLock)), 'rdlock');

  LRet := platform_rwlock_trywrlock(LRwLock);
  Check(LRet <> 0, 'trywrlock should fail while read lock is held');

  CheckEqual(Int64(0), Int64(platform_rwlock_rdunlock(LRwLock)), 'rdunlock');
  CheckEqual(Int64(0), Int64(platform_rwlock_destroy(LRwLock)), 'destroy');
end;

procedure TestRwLockReadBlockedByWriter;
var
  LRwLock: TPlatformRwLock;
  LRet: Int32;
begin
  CheckEqual(Int64(0), Int64(platform_rwlock_init(LRwLock)), 'init');
  CheckEqual(Int64(0), Int64(platform_rwlock_wrlock(LRwLock)), 'wrlock');

  LRet := platform_rwlock_tryrdlock(LRwLock);
  Check(LRet <> 0, 'tryrdlock should fail while write lock is held');

  CheckEqual(Int64(0), Int64(platform_rwlock_wrunlock(LRwLock)), 'wrunlock');
  CheckEqual(Int64(0), Int64(platform_rwlock_destroy(LRwLock)), 'destroy');
end;
```

Register both tests in the program body.

- [ ] **Step 2: Run the test to verify it fails to compile**

Run:

```bash
fpc -MObjFPC -Sh -O2 -gl -FUbuild/review-linux -FEbuild/review-linux -Fusrc -Fisrc tests/nextpas.core.platform.sync/test_platform_sync/test_platform_sync.lpr
```

Expected: FAIL because `platform_rwlock_rdunlock` and `platform_rwlock_wrunlock` are not defined yet.

- [ ] **Step 3: Change the platform API**

In `src/nextpas.core.platform.sync.pas`, replace:

```pascal
function platform_rwlock_unlock(var ARwLock: TPlatformRwLock): Int32;
```

with:

```pascal
function platform_rwlock_rdunlock(var ARwLock: TPlatformRwLock): Int32;
function platform_rwlock_wrunlock(var ARwLock: TPlatformRwLock): Int32;
```

For Linux, implement both as:

```pascal
function platform_rwlock_rdunlock(var ARwLock: TPlatformRwLock): Int32;
begin
  Result := pthread_rwlock_unlock(@ARwLock.FOpaque[0]);
end;

function platform_rwlock_wrunlock(var ARwLock: TPlatformRwLock): Int32;
begin
  Result := pthread_rwlock_unlock(@ARwLock.FOpaque[0]);
end;
```

For Windows, implement them as:

```pascal
function platform_rwlock_rdunlock(var ARwLock: TPlatformRwLock): Int32;
begin
  ReleaseSRWLockShared(@ARwLock.FOpaque[0]);
  Result := 0;
end;

function platform_rwlock_wrunlock(var ARwLock: TPlatformRwLock): Int32;
begin
  ReleaseSRWLockExclusive(@ARwLock.FOpaque[0]);
  Result := 0;
end;
```

Update the unsupported fallback functions to return `-1` for both new functions.

- [ ] **Step 4: Update L1 RWLock wrapper**

In `src/nextpas.core.sync.rwlock.pas`, change:

```pascal
procedure TRWLock.ReleaseRead;
begin
  platform_rwlock_unlock(FHandle);
end;

procedure TRWLock.ReleaseWrite;
begin
  platform_rwlock_unlock(FHandle);
end;
```

to:

```pascal
procedure TRWLock.ReleaseRead;
begin
  platform_rwlock_rdunlock(FHandle);
end;

procedure TRWLock.ReleaseWrite;
begin
  platform_rwlock_wrunlock(FHandle);
end;
```

- [ ] **Step 5: Run Linux tests**

Run:

```bash
make test
```

Expected for this task: `platform.sync` and `sync` tests pass. If unrelated modules fail, record the exact unrelated failure and run focused checks:

```bash
fpc -MObjFPC -Sh -O2 -gl -FUbuild/review-linux -FEbuild/review-linux -Fusrc -Fisrc tests/nextpas.core.platform.sync/test_platform_sync/test_platform_sync.lpr
build/review-linux/test_platform_sync
```

- [ ] **Step 6: Commit**

```bash
git add core/src/nextpas.core.platform.sync.pas core/src/nextpas.core.sync.rwlock.pas core/tests/nextpas.core.platform.sync/test_platform_sync/test_platform_sync.lpr
git commit -m "fix(core): split platform rwlock release modes"
```

## Task 2: Add Windows Synchronization FFI

**Files:**
- Create: `src/nextpas.core.platform.sync.windows.ffi.pas`
- Modify: `src/nextpas.core.platform.sync.pas`

- [ ] **Step 1: Create the Windows FFI unit**

Create `src/nextpas.core.platform.sync.windows.ffi.pas`:

```pascal
unit nextpas.core.platform.sync.windows.ffi;

{$I nextpas.core.settings.inc}

interface

uses
  Windows;

procedure InitializeSRWLock(SRWLock: Pointer); stdcall; external 'kernel32' name 'InitializeSRWLock';
procedure AcquireSRWLockExclusive(SRWLock: Pointer); stdcall; external 'kernel32' name 'AcquireSRWLockExclusive';
function TryAcquireSRWLockExclusive(SRWLock: Pointer): LongBool; stdcall; external 'kernel32' name 'TryAcquireSRWLockExclusive';
procedure ReleaseSRWLockExclusive(SRWLock: Pointer); stdcall; external 'kernel32' name 'ReleaseSRWLockExclusive';
procedure AcquireSRWLockShared(SRWLock: Pointer); stdcall; external 'kernel32' name 'AcquireSRWLockShared';
function TryAcquireSRWLockShared(SRWLock: Pointer): LongBool; stdcall; external 'kernel32' name 'TryAcquireSRWLockShared';
procedure ReleaseSRWLockShared(SRWLock: Pointer); stdcall; external 'kernel32' name 'ReleaseSRWLockShared';

procedure InitializeConditionVariable(ConditionVariable: Pointer); stdcall; external 'kernel32' name 'InitializeConditionVariable';
function SleepConditionVariableSRW(ConditionVariable: Pointer; SRWLock: Pointer; dwMilliseconds: DWORD; Flags: ULONG): LongBool; stdcall; external 'kernel32' name 'SleepConditionVariableSRW';
procedure WakeConditionVariable(ConditionVariable: Pointer); stdcall; external 'kernel32' name 'WakeConditionVariable';
procedure WakeAllConditionVariable(ConditionVariable: Pointer); stdcall; external 'kernel32' name 'WakeAllConditionVariable';

function WaitOnAddress(Address: Pointer; CompareAddress: Pointer; AddressSize: PtrUInt; dwMilliseconds: DWORD): LongBool; stdcall; external 'kernel32' name 'WaitOnAddress';
procedure WakeByAddressSingle(Address: Pointer); stdcall; external 'kernel32' name 'WakeByAddressSingle';
procedure WakeByAddressAll(Address: Pointer); stdcall; external 'kernel32' name 'WakeByAddressAll';

implementation

end.
```

- [ ] **Step 2: Use the FFI unit from the Windows branch**

In `src/nextpas.core.platform.sync.pas`, change the Windows `uses` block to:

```pascal
{$IFDEF WINDOWS}
uses
  Windows,
  nextpas.core.platform.sync.windows.ffi;
{$ENDIF}
```

- [ ] **Step 3: Run Win64 compile-only verification**

Run:

```bash
mkdir -p build/review-win64
fpc -Twin64 -Cn -MObjFPC -Sh -O2 -gl -FUbuild/review-win64 -FEbuild/review-win64 -Fusrc -Fisrc tests/nextpas.core.platform.sync/test_platform_sync/test_platform_sync.lpr
```

Expected: PASS compile-only. If FPC reports calling convention or type mismatch, fix the FFI declarations in the same task.

- [ ] **Step 4: Commit**

```bash
git add core/src/nextpas.core.platform.sync.pas core/src/nextpas.core.platform.sync.windows.ffi.pas
git commit -m "fix(core): add windows sync ffi declarations"
```

## Task 3: Make Opaque Storage Explicitly Aligned

**Files:**
- Modify: `src/nextpas.core.platform.sync.pas`
- Modify: `tests/nextpas.core.platform.sync/test_platform_sync_sizes/test_platform_sync_sizes.lpr`

- [ ] **Step 1: Add failing alignment tests**

Add these types and checks to `test_platform_sync_sizes.lpr`:

```pascal
type
  TEmbeddedMutex = record
    Prefix: Byte;
    Mutex: TPlatformMutex;
  end;

  TEmbeddedRwLock = record
    Prefix: Byte;
    RwLock: TPlatformRwLock;
  end;

  TEmbeddedCondVar = record
    Prefix: Byte;
    CondVar: TPlatformCondVar;
  end;

procedure CheckPointerAligned(const AName: string; APtr: Pointer);
begin
  Check((PtrUInt(APtr) mod SizeOf(Pointer)) = 0, AName + ' must be pointer-aligned');
end;

procedure TestOpaqueAlignment;
var
  LMutexes: array[0..1] of TPlatformMutex;
  LRwLocks: array[0..1] of TPlatformRwLock;
  LCondVars: array[0..1] of TPlatformCondVar;
  LEmbeddedMutex: TEmbeddedMutex;
  LEmbeddedRwLock: TEmbeddedRwLock;
  LEmbeddedCondVar: TEmbeddedCondVar;
begin
  CheckPointerAligned('mutex array element', @LMutexes[1]);
  CheckPointerAligned('rwlock array element', @LRwLocks[1]);
  CheckPointerAligned('condvar array element', @LCondVars[1]);
  CheckPointerAligned('embedded mutex', @LEmbeddedMutex.Mutex);
  CheckPointerAligned('embedded rwlock', @LEmbeddedRwLock.RwLock);
  CheckPointerAligned('embedded condvar', @LEmbeddedCondVar.CondVar);
end;
```

Register `TestOpaqueAlignment`.

- [ ] **Step 2: Run the size/alignment test**

Run:

```bash
fpc -MObjFPC -Sh -O2 -gl -FUbuild/review-linux -FEbuild/review-linux -Fusrc -Fisrc tests/nextpas.core.platform.sync/test_platform_sync_sizes/test_platform_sync_sizes.lpr
build/review-linux/test_platform_sync_sizes
```

Expected before implementation: FAIL if embedded fields are not pointer-aligned.

- [ ] **Step 3: Change opaque record layout**

In `src/nextpas.core.platform.sync.pas`, change the records to variant records:

```pascal
TPlatformMutex = record
  case Integer of
    0: (FAlign: UInt64);
    1: (FOpaque: array[0..PLATFORM_MUTEX_SIZE - 1] of Byte);
end;

TPlatformRwLock = record
  case Integer of
    0: (FAlign: UInt64);
    1: (FOpaque: array[0..PLATFORM_RWLOCK_SIZE - 1] of Byte);
end;

TPlatformCondVar = record
  case Integer of
    0: (FAlign: UInt64);
    1: (FOpaque: array[0..PLATFORM_CONDVAR_SIZE - 1] of Byte);
end;
```

- [ ] **Step 4: Re-run tests**

Run:

```bash
make test
```

Expected: core tests pass, or only unrelated pre-existing failures remain.

- [ ] **Step 5: Commit**

```bash
git add core/src/nextpas.core.platform.sync.pas core/tests/nextpas.core.platform.sync/test_platform_sync_sizes/test_platform_sync_sizes.lpr
git commit -m "fix(core): align platform sync opaque storage"
```

## Task 4: Normalize Timeout and Error Contracts

**Files:**
- Modify: `src/nextpas.core.platform.sync.pas`
- Modify: `tests/nextpas.core.platform.sync/test_platform_sync/test_platform_sync.lpr`

- [ ] **Step 1: Add public error constants**

Add constants near the existing platform constants:

```pascal
PLATFORM_ERR_BUSY        = 16;
PLATFORM_ERR_TIMEOUT     = 110;
PLATFORM_ERR_AGAIN       = 11;
PLATFORM_ERR_INVALID     = 22;
PLATFORM_ERR_UNSUPPORTED = 95;
```

- [ ] **Step 2: Add exact-code tests for address wait**

Update `TestAddressWait` to assert exact categories:

```pascal
LRet := platform_wait_address32(@LValue, 99, 1000000);
CheckEqual(Int64(PLATFORM_ERR_AGAIN), Int64(LRet), 'value mismatch should be EAGAIN');

LRet := platform_wait_address32(@LValue, 42, 1000000);
CheckEqual(Int64(PLATFORM_ERR_TIMEOUT), Int64(LRet), 'matching value should timeout without wake');
```

- [ ] **Step 3: Implement consistent timeout handling**

In Unix `platform_condvar_timedwait`, add:

```pascal
if ATimeoutNs < 0 then
begin
  Result := pthread_cond_wait(@ACondVar.FOpaque[0], @AMutex.FOpaque[0]);
  Exit;
end;
```

In Windows timeout conversion, use a helper that rounds positive nanoseconds up:

```pascal
function platform_timeout_ns_to_ms(const ATimeoutNs: Int64): DWORD;
begin
  if ATimeoutNs < 0 then
    Exit(INFINITE);
  if ATimeoutNs = 0 then
    Exit(0);
  Result := DWORD((ATimeoutNs + 999999) div 1000000);
end;
```

Use this helper in Windows condvar and address-wait paths.

- [ ] **Step 4: Run focused tests**

Run:

```bash
fpc -MObjFPC -Sh -O2 -gl -FUbuild/review-linux -FEbuild/review-linux -Fusrc -Fisrc tests/nextpas.core.platform.sync/test_platform_sync/test_platform_sync.lpr
build/review-linux/test_platform_sync
```

Expected: all `platform.sync` behavior tests pass.

- [ ] **Step 5: Commit**

```bash
git add core/src/nextpas.core.platform.sync.pas core/tests/nextpas.core.platform.sync/test_platform_sync/test_platform_sync.lpr
git commit -m "fix(core): normalize platform sync timeout errors"
```

## Task 5: Promote platform.sync to Official Verification

**Files:**
- Modify: `../build/verify_local.sh`

- [ ] **Step 1: Add required paths**

Add required paths for:

```text
core/src/nextpas.core.platform.sync.pas
core/tests/nextpas.core.platform.sync/test_platform_sync/test_platform_sync.lpr
core/tests/nextpas.core.platform.sync/test_platform_sync_sizes/test_platform_sync_sizes.lpr
```

- [ ] **Step 2: Add focused Linux checks**

Add commands equivalent to:

```bash
fpc -Fi"$REPO_ROOT/core/src" -Fu"$REPO_ROOT/core/src" -FE"$CORE_PLATFORM_SYNC_BUILD_DIR" -FU"$CORE_PLATFORM_SYNC_BUILD_DIR" "$REPO_ROOT/core/tests/nextpas.core.platform.sync/test_platform_sync/test_platform_sync.lpr"
"$CORE_PLATFORM_SYNC_BUILD_DIR/test_platform_sync"
fpc -Fi"$REPO_ROOT/core/src" -Fu"$REPO_ROOT/core/src" -FE"$CORE_PLATFORM_SYNC_SIZE_BUILD_DIR" -FU"$CORE_PLATFORM_SYNC_SIZE_BUILD_DIR" "$REPO_ROOT/core/tests/nextpas.core.platform.sync/test_platform_sync_sizes/test_platform_sync_sizes.lpr"
"$CORE_PLATFORM_SYNC_SIZE_BUILD_DIR/test_platform_sync_sizes"
```

- [ ] **Step 3: Add Win64 compile-only check**

Add a guarded check that runs when the cross target is available:

```bash
fpc -Twin64 -Cn -Fi"$REPO_ROOT/core/src" -Fu"$REPO_ROOT/core/src" -FE"$CORE_PLATFORM_SYNC_WIN64_BUILD_DIR" -FU"$CORE_PLATFORM_SYNC_WIN64_BUILD_DIR" "$REPO_ROOT/core/tests/nextpas.core.platform.sync/test_platform_sync/test_platform_sync.lpr"
```

- [ ] **Step 4: Run top-level verification**

Run from repository root:

```bash
bash build/verify_local.sh
```

Expected: final envelope reports the new `platform.sync` focused checks.

- [ ] **Step 5: Commit**

```bash
git add build/verify_local.sh
git commit -m "test(core): verify platform sync in local gate"
```

## Self-Review

Spec coverage:

- Windows compile blocker: Task 2.
- RWLock release contract: Task 1.
- Alignment: Task 3.
- Timeout and error semantics: Task 4.
- Official verification: Task 5.

Placeholder scan:

- No task contains "TBD" or "implement later".
- Code-changing steps include concrete snippets and commands.

Type consistency:

- The plan consistently uses `platform_rwlock_rdunlock` and
  `platform_rwlock_wrunlock`.
- The L1 wrapper calls match the new L0 API names.
