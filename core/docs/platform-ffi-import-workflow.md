# Platform FFI Import Workflow

This workflow is the required route for adding platform API declarations from
FPC source into `nextpas.core.platform`. It exists so API import work can pause
and resume without losing the evidence, owner decisions, or verification state.

FPC source is reference authority, not production dependency. nextPas production
platform units must still declare their own ABI truth and must not `uses` FPC
platform units such as `Linux`, `UnixType`, `BaseUnix`, `PThreads`, `Syscall`,
or `Windows`.

## API import wave

An API import wave is one small, reviewable batch of host ABI declarations. A
wave should usually cover one host plus one domain, such as Linux process ids,
Windows file attributes, Darwin Mach timing, or POSIX file status. Do not mix
unrelated domains just because they live in the same FPC unit.

Each wave must answer these questions before it changes production code:

- Which FPC source family, unit, or include file proves the declaration?
- If FPC does not expose the declaration, which OS SDK or header family supplies
  the missing evidence?
- Which nextPas host base/ffi owner receives the declaration?
- Does the declaration need a unified public contract, or is it only raw host
  ABI surface for future consumers?
- Which evidence class proves the change: Linux runtime, Win64 compile-only,
  simulated host compile-only, source-surface guard, or unified-contract test?

## Phase 1: source evidence

Start with source evidence, not Pascal code. Search the local FPC source tree,
record the source family and symbol names, then update
`docs/platform-ffi-source-evidence-index.md`.

Use source family names in project docs instead of local absolute paths. Local
paths are useful during research, but the durable evidence should look like
`rtl/linux/linux.pp`, `rtl/freebsd/ptypes.inc`, `rtl/darwin/pthread.inc`,
`rtl/win64/windows.pp`, or `packages/winunits-base`.

If FPC lacks a newer API, record the OS SDK/header fallback explicitly. Windows
APIs such as `WaitOnAddress` are a normal example: FPC Windows units are the
first pass, and Windows SDK headers are the tie-breaker for missing kernel32
symbols.

## Phase 2: host base/ffi owner

Choose the host base/ffi owner before writing a declaration.

- Put constants, record layouts, opaque carriers, scalar aliases, syscall
  numbers, error-code values, and capability tokens in
  `nextpas.core.platform.<host>.base`.
- Put `cdecl`, `stdcall`, syscall, libc, pthread, kernel32, mach, and other
  external declarations in `nextpas.core.platform.<host>.ffi`.
- Put genuinely shared POSIX ABI shapes in `nextpas.core.platform.posix.base`.
- Put genuinely shared POSIX external declarations and thin POSIX glue in
  `nextpas.core.platform.posix.ffi`.
- Put pure arithmetic helpers in `nextpas.core.platform.posix.math` or
  `nextpas.core.platform.windows.math`.

`platform.time`, `platform.sync`, and `platform.thread` are unified public
contracts. They consume host base/ffi owners and should not create
`platform.time.ffi`, `platform.sync.ffi`, or `platform.thread.ffi` unless a
future design proves the foreign ABI is independent of every host owner.

## Phase 3: RED gate

Write the red gate before the green import. The first failing test should prove
the missing workflow, evidence, owner, or route token. It should not fail because
of a typo, bad path, or an accidental compile error.

Source-surface gates are the default for raw ABI import waves. They check that:

- Evidence docs name the source family.
- Host `base/ffi` units own the symbol or token.
- Feature-specific ffi files stay absent unless explicitly approved.
- `build/verify_local.sh` requires the new files and emits a final envelope
  token.
- The wave does not add production `uses` clauses for FPC platform units.

Raw OS API declarations are not runtime tests. A raw OS API such as
`clock_gettime`, `pthread_*`, `futex`, `QueryPerformanceCounter`,
`GetSystemTimeAsFileTime`, or `WaitOnAddress` should be guarded by source
evidence, source-surface checks, compile-only gates, and review. Runtime tests
belong to unified nextPas public contracts.

## Phase 4: green import

Only after the red gate fails correctly should production code change. Keep the
green import narrow:

- Add the minimum base constants, record layouts, aliases, and capability tokens.
- Add the minimum ffi declarations and host-owned thin helpers.
- Update `docs/platform-host-ffi-gap-matrix.md` to show the new owned surface or
  to remove a known gap.
- If a unified contract consumes the API, update only that contract's focused
  tests and keep the public semantics explicit.

Prefer several small waves over one large wave. A good wave can be reviewed by
reading the evidence entry, the host owner diff, the source-surface gate, and the
focused verification output in one sitting.

## Phase 5: verification matrix

Use the evidence class honestly.

- Linux runtime proves Linux behavior for the unified public contract.
- Win64 compile-only proves the Windows branch compiles and the declarations are
  syntactically coherent. It is not Windows runtime proof.
- Simulated host compile-only proves branch selection and unit surface coherence
  for Darwin, Android, FreeBSD, and generic Unix. It is not runtime proof.
- Source-surface guards prove documentation, ownership, and route truth.
- Unified-contract tests prove public `platform.time`, `platform.sync`,
  `platform.thread`, or future platform contract behavior.

Every wave should run focused gates first. Before merge, run:

```bash
make -C core test
make -C core examples
make -C core benchmarks
bash build/verify_local.sh
git diff --check
```

## Recovery entry

Every wave must keep `task_plan.md`, `progress.md`, and `findings.md` current.
These files are the recovery entry when a session is interrupted.

At minimum, record:

- Worktree path and branch name.
- Starting `main` commit and any later rebase commit.
- Current phase and the first unchecked task.
- RED output, GREEN output, and full verification output.
- Source evidence findings and unresolved host gaps.
- Whether the wave is not started, in progress, blocked, committed, merged, or
  cleaned up.

To resume a wave, run:

```bash
git status --short --branch
sed -n '1,160p' task_plan.md
sed -n '1,160p' progress.md
sed -n '1,130p' findings.md
```

Then continue from the first unchecked task in the latest platform addendum.

## Commit, merge, and cleanup

Use an isolated worktree for each API import wave. Do not work directly in a
dirty main checkout, and do not touch unrelated work from another branch.

Before committing:

- Review `git diff --stat` and `git diff --check`.
- Confirm ignored build output is not staged.
- Commit a single logical wave with a clear message.

Before merging:

- Refresh main.
- Rebase or merge the wave over latest main.
- Resolve conflicts by keeping the better current architecture, not by blindly
  preferring either side.
- Re-run focused verification after rebase.

After merging:

- Run post-merge focused verification.
- Update `task_plan.md` and `progress.md` with the final commit, merge status,
  and verification evidence.
- Remove the worktree and delete the feature branch.
- Report what changed, verification evidence, retrospective, and the next
  planned wave.
