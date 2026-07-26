# math-simd Maintenance Posture

> Last updated: 2026-07-26
> Lane: `codex/math-simd` @ `.worktrees/math-simd`
> Mode: **A — maintenance only** (green gates, doc truth, debt inventory)
> Goal pointer: [`GOAL_QUEUE.md`](GOAL_QUEUE.md) (`CURRENT=IDLE`)
> Latest residual cut: **audit findings F-001…F-020 package (2026-07-26)**; prior:
> Latest residual cut: **D-RTL-1/2/3 closed** (TWorkerThread BeginThread + test migration)

This file is the maintenance authority for residual debt and re-verify evidence.
It does **not** invent feature milestones. Feature work needs a new Goal Card.

## Posture

| Rule | Meaning |
|------|---------|
| Default | Stay `CURRENT=IDLE`; re-verify; keep docs honest |
| Do not auto-start | Wave 4 walls (RVV hardware, compiler SIMD, new ISA, M9, macOS) |
| Do not expand | NEON full Batch tables, value-type SIMD, private simd imports from math |
| Touch code only for | Red gates, doc/contract lies, hygiene, or an approved Goal Card |

## Re-verify baseline (2026-07-26)

Host: Linux x86_64 worktree after `git merge --ff-only main` → `e9d92ab5b`.

| Gate | Result |
|------|--------|
| `make hygiene` | pass |
| `make -C core/tests/nextpas.core.math clean test` | exit 0 |
| `MATH_API_SURFACE` | **scanned=71 findings=0** |
| Math Pascal suites (16) | **313** passed / 0 failed; heaptrc **0 unfreed** on each suite |
| `make focused FOCUS=core/tests/nextpas.core.simd` | **1762** passed / 0 failed |
| `git status` after re-verify | clean tree before doc edits |

Notes:

- simd README baseline **1762** matches this run.
- roadmap §1.4 historically said **1750** (B9 closeout); updated to current focused count.
- `neon-optin-focused` not re-run in this maintenance pass (x86 host; last recorded 1762 at C5e-ext).

## Ownership reminder

Authoritative edit-where map: [`GOAL_QUEUE.md`](GOAL_QUEUE.md) §「math↔simd linkage (Q2)」.

```text
consumer → math (apps) | simd (kernel/expert)
math.batch* → public nextpas.core.simd only
simd ↛ math
```

## Debt inventory

### Live residuals (in-lane visible, not blocking landing)

| ID | Item | Where | Severity | Unblock |
|----|------|-------|----------|---------|
| D-RTL-1 | ~~Tests `Classes` + `TThread`~~ | concurrent / direct / cpuinfo.lazy | **closed 2026-07-26** | Migrated to `TWorkerThread`; base uses **BeginThread** (FPC TLS/heap init) + Destroy joins |
| D-RTL-2 | ~~dispatchapi `Classes` + `TStringList`~~ | `dispatchapi.testcase.pas` | **closed 2026-07-26** | Local `TSourceLines` + `nextpas.core.fs` ReadFile*; focused **1762**/0 |
| D-RTL-3 | ~~`Math.Power` + TextFormat `%g` crash~~ | `transcendental_f32.pas` | **closed 2026-07-26** | math `Power`; Format specs `%f`; standalone **PASS 1050**/0 |
| D-DOC-1 | Historical pass counts in archive sections | GOAL_QUEUE card EVIDENCE, plan.md history | low | Keep history; only §current baseline must match latest re-verify |
| D-SIZE-1 | simd surface very large (~247 files under `nextpas.core.simd*`, ~137k LOC pas+inc) | `core/src/` | maintainability | Prefer `tools/simdgen` + contracts over hand-copy tables |
| D-CPU-1 | Registry: simd **CPUInfo debt** | `core/docs/core-module-registry.md`; `simd.cpuinfo.*` | governance | Audit L0 boundary / host unit ownership; no silent OS unit creep |
| D-AUDIT-1 | **audit gate systemically dead**: `make audit` fail-fast at simdgen masked 13/21 failing steps; main byte-identical red (discovered during M3.2, 2026-07-26) | `core/tests/nextpas.core.simd/check_*.py`, `tools/simdgen` | **high** | GOAL_QUEUE **M3.4** W1–W5 (path orphans → baselines → simdgen sync → key_slot/cpuinfo truth → no-fail-fast audit) |

### Explicitly blocked (Wave 4 / external)

| ID | Item | BLOCKED_UNTIL |
|----|------|----------------|
| W-MAC | macOS trig host link/runtime proof | macOS runner / CI host |
| W-M9 | `fafafa.game` cutover to final math names | product auth + cross-lane plan |
| W-RVV | RVV Memory/Batch real leaves (S24b) | RISC-V hardware or approved QEMU evidence path |
| W-S26 | Compiler built-in SIMD | compiler lane |
| W-S27 | LASX / WASM / VSX / MSA backends | FPC/toolchain + validation |
| W-VAL | Value-type methods → SIMD | profiled evidence + public contract design |

### Closed (do not reopen without evidence)

- Math M0–M8 available hosts; public Batch F32/F64; `vec.batch` Double minimal parity
- NEON Memory 15/15; BatchF32 representative 23 leaves; Wave C F64/transcendental samples
- RVV Memory/Batch intentionally scalar (S24a contracts)
- S25a/b performance methodology + vsTrue SLA re-baseline
- Q1/Q2 pointer + linkage; usability equal-length Batch policy

## dispatchapi split size report (M3.2, 2026-07-26)

`nextpas.core.simd.dispatchapi.testcase.pas` 24012 → 7 units; published-method conservation 253 = 253; focused 1764/0 unchanged; suites 61 → 65.

| Unit | Lines | Suite (registered class) | Published |
|------|-------|--------------------------|-----------|
| `dispatchapi.testcase.pas` (original) | **7159** ⚠ >5k | `TTestCase_DispatchAPI` (narrowed: NEON/RISCVV/NonX86_/X86-grouped-wiring/Phase19 script-coupled only) | 71 |
| `dispatchapi.support.pas` | 353 | — (shared helpers/types/hook globals, uses-LAST for shadowing parity) | 0 |
| `dispatchapi.controlplane.testcase.pas` | 3995 | `TTestCase_DispatchAPIControlPlane` + `TTestCase_RISCVFallbackDispatchContract` | 59+2 |
| `dispatchapi.parity.testcase.pas` | 3084 | `TTestCase_DispatchAPIParity` | 29 |
| `dispatchapi.batchparity.testcase.pas` | 1819 | `TTestCase_DispatchAPIBatchParity` | 23 |
| `dispatchapi.capabilities.testcase.pas` | 2336 | `TTestCase_DispatchAPICapabilities` + masked-contract classes | 37+3 |
| `dispatchapi.nonx86.testcase.pas` | **5742** ⚠ >5k | `TTestCase_NonX86BackendParity` (cohesive single class, kept whole) | 29 |

Size exceptions (documented, accepted): original keeps script-coupled methods (immutable gate scripts pin qualified names + same-file helper); nonx86 is one cohesive class.
Old→new suite mapping: methods formerly under `TTestCase_DispatchAPI` now run under the 4 new suites above; `--suite=TTestCase_DispatchAPI` filters now cover **only** the 71 script-coupled methods.

## Recommended maintenance order (when touching code)

1. Re-verify gates if tree moved or main advanced
2. Fix red tests / hygiene / contract lies only
3. Doc number alignment (this file + README/roadmap current sections)
4. Optional small residual cuts that stay **inside** math-simd tests (e.g. D-RTL-2/3)
5. Cross-lane residuals (D-RTL-1, W-*) → report **Needs Review**, do not solo

## Verification commands (copy/paste)

```bash
git status --short --branch
make hygiene
make -C core/tests/nextpas.core.math clean test
make focused FOCUS=core/tests/nextpas.core.simd
# optional ARM:
# make -C core/tests/nextpas.core.simd neon-optin-focused
git diff --check
```

## Related docs

- [`GOAL_QUEUE.md`](GOAL_QUEUE.md) — executable CURRENT
- [`../math/README.md`](../math/README.md) / [`../math/CONTRACT.md`](../math/CONTRACT.md)
- [`../simd/README.md`](../simd/README.md) / [`../simd/roadmap.md`](../simd/roadmap.md) / [`../simd/plan.md`](../simd/plan.md)
