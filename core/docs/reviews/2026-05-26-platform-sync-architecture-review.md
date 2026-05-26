# platform.sync Architecture Review

Date: 2026-05-26

Scope: `nextpas.core.platform.sync` as the L0 native synchronization substrate for
the L1 `sync` module.

## Review stance

`platform.sync` is not just a helper unit. It is the contract boundary between
nextPas core and operating-system concurrency primitives. If this layer is vague,
every higher-level abstraction will inherit the ambiguity.

The goal is to make nextPas one of the best Free Pascal framework foundations.
For this module, that means:

- correctness before convenience;
- explicit platform contracts before broad API growth;
- small unsafe/native boundaries with strong tests around them;
- fast paths that are measurable, not merely clever;
- portable semantics that do not pretend different kernels behave the same.

## Current evidence

The current Linux path has improved since the first `platform.sync` commit:

- `platform_rwlock_trywrlock` now calls `pthread_rwlock_trywrlock`.
- `pthread_cond_timedwait` now uses a monotonic condvar clock on Linux.
- `test_platform_sync_sizes` checks native pthread object sizes against the
  opaque buffers.
- `make test` currently reaches and passes `platform.sync` and L1 `sync` tests.

Fresh verification from this review:

- `fpc -Cn ... test_platform_sync.lpr` on Linux: pass.
- `fpc -Cn ... test_platform_sync_sizes.lpr` on Linux: pass.
- `fpc -Twin64 -Cn ... test_platform_sync.lpr`: fail with 18 missing Windows
  synchronization identifiers.
- `make test`: fails later in `nextpas.core.text`, with 19/21 passing and two
  unrelated text failures. The `platform.sync` and `sync` tests pass before that.

## Findings

### P0: Windows support is currently non-compilable

The Windows branch directly calls `InitializeSRWLock`, `AcquireSRWLockExclusive`,
`SleepConditionVariableSRW`, `WaitOnAddress`, and related APIs through the FPC
`Windows` unit. Current FPC 3.3.1 does not declare these symbols in this setup,
so Win64 syntax/semantic compilation fails before linking.

This is a hard blocker for the stated target platform set. It should be fixed by
adding a narrow Windows synchronization FFI boundary, not by scattering ad hoc
external declarations through the implementation body.

Recommended direction:

- Add a dedicated Windows FFI unit or include for the missing `synchapi`
  declarations.
- Keep declarations separate from policy and wrapper logic.
- Add a Win64 `-Cn` compile gate for `platform.sync` before claiming Windows
  support.

### P0: RWLock unlock cannot stay mode-free on Windows

The current API exposes one `platform_rwlock_unlock` function. That maps cleanly
to `pthread_rwlock_unlock`, but it does not map cleanly to Windows `SRWLOCK`.
Windows requires `ReleaseSRWLockShared` for read locks and
`ReleaseSRWLockExclusive` for write locks.

The current Windows code always releases exclusive mode, so any read-lock path
would be wrong once the branch compiles.

Recommended direction:

- Replace the low-level API with explicit release functions:
  `platform_rwlock_rdunlock` and `platform_rwlock_wrunlock`.
- On Unix, both functions may delegate to `pthread_rwlock_unlock`.
- Update L1 `TRWLock.ReleaseRead` and `TRWLock.ReleaseWrite` to call the matching
  platform function.
- Add tests that hold a read lock and verify write acquisition fails, then hold a
  write lock and verify read acquisition fails.

### P1: The `UNIX` branch is really Linux-specific

The implementation uses `Linux`, `Syscall`, raw futex, and
`pthread_condattr_setclock`. That is Linux-oriented code guarded by `UNIX`.
macOS and BSD should not be implicitly routed through this branch.

Recommended direction:

- Split the implementation by actual target: Linux, Windows, and explicit
  unsupported fallback.
- Do not use `UNIX` as a synonym for Linux when futex or Linux units are involved.
- Add a compile gate or explicit unsupported diagnostic for macOS until that path
  has its own primitive strategy.

### P1: Opaque records check size, but not alignment

The records store native primitives in `Byte` arrays. The size tests are useful,
but size is only half the ABI contract. `pthread_mutex_t`, `pthread_rwlock_t`,
`pthread_cond_t`, `SRWLOCK`, and address-wait words all have alignment
requirements.

Recommended direction:

- Make opaque storage explicitly pointer- or QWord-aligned.
- Add alignment checks next to the size checks.
- Test embedded and array cases, not only standalone local variables.
- Treat this as a prerequisite before building more primitives on top of the
  platform layer.

### P1: Mutex kind semantics are not portable yet

The public constants expose `NORMAL`, `ERRORCHECK`, and `RECURSIVE`. Unix maps
them through numeric pthread kind values. Windows currently ignores the kind and
uses `SRWLOCK` exclusively.

That means `TMutex` can document error-check behavior while Windows silently
provides different behavior.

Recommended direction:

- Decide whether the platform mutex contract really includes error-check and
  recursive modes.
- If yes, implement or emulate the same semantics per platform.
- If no, simplify the low-level contract to one normal mutex and move debugging
  checks into a higher-level optional wrapper.
- Avoid magic pthread kind numbers unless they are guarded by target-specific
  definitions.

### P1: Error-code semantics need one policy

Unix returns errno-style codes. Windows returns a mix of hard-coded errno-like
values and raw `GetLastError` values. L1 wrappers currently convert many failures
into generic exceptions, which hides useful diagnosis.

Recommended direction:

- Choose one public low-level policy: normalized errno-like codes, or native
  platform codes plus helper translation.
- Define names for the small set higher layers need: busy, timeout, would block,
  invalid, interrupted, unsupported.
- Assert exact timeout / busy / mismatch codes in tests instead of only checking
  non-zero.

### P2: Timeout semantics are inconsistent

`platform_wait_address32` treats negative timeout as infinite. Windows timed
condvar wait does the same. Unix timed condvar wait currently computes an
absolute time using the negative value rather than taking the infinite wait path.
Windows also truncates nanoseconds to milliseconds, so sub-millisecond positive
timeouts become zero.

Recommended direction:

- Specify timeout semantics once: negative means infinite, zero means poll,
  positive means bounded wait.
- On Windows, round positive nanoseconds up to at least one millisecond.
- On Unix condvars, dispatch negative values to `pthread_cond_wait`.
- Add contract tests for negative, zero, sub-millisecond, and normal timeout
  values.

### P2: Official verification has not caught up with the module

`make test` covers `platform.sync`, but the top-level repository verification
still explicitly tracks the older core time gate. For a foundational native
boundary, the official verification path should include at least focused Linux
checks and Windows compile checks.

Recommended direction:

- Add focused `platform.sync` Linux compile/run checks to the top-level local
  verification script.
- Add a Win64 `-Cn` compile check once the Windows FFI declarations exist.
- Report these checks explicitly in the final verification envelope.

## Proposed architecture

Keep `nextpas.core.platform.sync` as the public L0 contract, but make the native
surface narrower and more explicit.

Recommended file shape:

- `nextpas.core.platform.sync.pas`: public types, constants, and forwarding API.
- `nextpas.core.platform.sync.linux.inc`: Linux pthread/futex implementation.
- `nextpas.core.platform.sync.windows.inc`: Windows implementation policy.
- `nextpas.core.platform.sync.windows.ffi.pas`: Windows external declarations.
- `tests/nextpas.core.platform.sync/*`: contract tests that verify behavior, not
  only successful calls.

The public contract should describe:

- object lifetime: init, use, destroy;
- ownership: caller owns records and must not copy initialized records;
- alignment: records are safe as fields and array elements;
- error code policy;
- timeout policy;
- memory ordering boundary for address wait and wake.

## Evolution route

### Phase 0: Freeze the contract

Write the contract before changing more implementation code. Decide the RWLock
unlock shape, mutex kind scope, timeout policy, error code policy, and whether
`platform.sync` is public through `nextpas.core.platform` or a lower-level module
used directly by L1 `sync`.

Exit criteria:

- Contract decisions are documented.
- Existing Linux behavior is mapped to those decisions.
- Windows and macOS unsupported areas are explicit.

### Phase 1: Harden Linux

Fix alignment, replace magic pthread kind numbers with target-defined constants,
normalize timeout handling, and add exact-code tests for busy, timeout, and value
mismatch.

Exit criteria:

- Linux `platform.sync` contract tests pass.
- L1 `sync` tests pass.
- Alignment tests cover standalone, embedded, and array storage.

### Phase 2: Make Windows compile and match the contract

Add the missing Windows FFI surface, split RWLock release by mode, and resolve
mutex kind semantics honestly.

Exit criteria:

- Win64 `-Cn` compile gate passes.
- Windows branch no longer contains unreachable or semantically false code.
- Any unsupported mode returns a documented unsupported code.

### Phase 3: Decide macOS and BSD strategy

Do not let the Linux branch stand in for all Unix targets. Either implement a
macOS/BSD path with pthread primitives and no futex, or mark it explicitly
unsupported for this stage.

Exit criteria:

- Non-Linux Unix targets do not accidentally compile against Linux-only units.
- The roadmap names the first target that will receive non-Linux Unix support.

### Phase 4: Promote to official verification

Move `platform.sync` from "covered by `make test`" to an explicit first-class
verification target.

Exit criteria:

- Top-level verification reports `core-platform-sync=pass` or an equivalent
  focused status.
- Win64 compile-only status is reported separately.
- Failures point to the exact platform contract that broke.

## Suggested next work packet

Do not start by adding more synchronization primitives. Start with the contract
and the two hard blockers.

Recommended next packet:

1. Add the written `platform.sync` contract section.
2. Split RWLock release into read/write release functions.
3. Update L1 `TRWLock` to use the new release functions.
4. Add Linux regression tests for read-held/write-held acquisition conflicts.
5. Add Windows FFI declarations and a Win64 `-Cn` compile check.
6. Re-run Linux `make test` and Win64 compile-only verification.
7. Commit this as one traceable hardening batch.

## Review checkpoint

The direction is good: L0 platform primitives feeding L1 ergonomic wrappers is
the right architecture for a serious Free Pascal framework. The current risk is
not that the module is too ambitious. The risk is that the low-level contract is
still softer than the abstractions already being built on top of it.

The next move should be contract hardening, not API expansion.
