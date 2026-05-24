# nextPas Continuous Developer Tooling Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** After Batch 29, continue without stopping by landing the next real developer-tooling control surfaces: `doctor`, richer read-only environment evidence, minimal semantic `query`, and package workflow skeletons.

**Architecture:** Keep `tools/stage0/nextpas.pas` as a thin command surface. Put reusable truth in compiler/toolchain/workspace-owned units, freeze every public behavior first in `build/verify_local.sh`, then update docs and tracking before each commit. Do not reopen completed toolchain transcript, direct-link C library, `nextpas test`, or `env status` work unless verification proves drift.

**Tech Stack:** FreePascal, Pascal units under `compiler/` and `tools/stage0/`, shell verification via `bash build/verify_local.sh`, existing line-based projection plus `command-envelope=<json>`.

---

## Continuous Execution Rules

- Work straight through the tasks in order. Do not pause after a green gate; review, commit, then start the next task.
- Use TDD at the promotion-gate level: add or tighten `build/verify_local.sh` checks first, run once to see the expected failure, implement the smallest code path, rerun verification.
- Before every commit, write a short review conclusion in the session: what changed, what was verified, and remaining risk.
- Commit after every task using only files touched for that task.
- Stop only for hard blockers: missing host tools that cannot be installed inside the workspace, destructive user-data risk, or a contradiction between architecture docs and current implementation that cannot be resolved by reading local files.
- Keep Linux x86_64, FreePascal `stage0`, no new Pascal syntax, and `ABI compatibility is deferred`.
- If Rust commands appear later, use release strategy by default; this plan currently does not require Rust commands.

## Task 1: `doctor` Minimal Read-only Health Surface

**Files:**
- Modify: `build/verify_local.sh`
- Modify: `tools/stage0/nextpas.pas`
- Modify: `tools/stage0/README.md`
- Modify: `docs/architecture/stage0-driver-specification.md`
- Modify: `docs/architecture/developer-tooling-specification.md`
- Modify: `docs/plans/2026-03-24-nextpas-master-roadmap-plan.md`
- Modify: `task_plan.md`
- Modify: `findings.md`
- Modify: `progress.md`

**Step 1: Write failing verification gate**

Add two gates to `build/verify_local.sh` after the existing `env status` checks:

- `nextpas doctor --target linux-x86_64 --workspace "$REPO_ROOT"`
- bare `nextpas doctor`

Expected line/envelope fields for the success path:

- `command=doctor`
- `selector=doctor`
- `target=linux-x86_64`
- `status=success`
- `result=success`
- `environment-readiness=incomplete|ready`
- `runtime-sdk-status=missing|ready`
- `runtime-libc-present=false|true`
- `doctor-check-count=<non-zero>`
- `doctor-finding-count=<count>`
- `doctor-status=warning|healthy`
- `command-envelope=.*"command":"doctor"`
- `command-envelope=.*"doctorStatus":"warning|healthy"`

Expected invalid argument path:

- `command=doctor`
- `selector=doctor`
- `status=failure`
- `failure-kind=invalid-arguments`
- `command-envelope=.*"command":"doctor"`

**Step 2: Run focused verification**

Run:

```bash
bash build/verify_local.sh
```

Expected: FAIL at the new `doctor` gate because `doctor` is not implemented.

**Step 3: Implement minimal parser and projection**

In `tools/stage0/nextpas.pas`:

- Add `doctor` to top-level command dispatch.
- Support only `nextpas doctor --target linux-x86_64 [--toolchain-binding <id>] [--workspace <root>]`.
- Reuse the same target/binding/distribution/runtime resolution path currently used by `env status`.
- Do not mutate environment state.
- Keep `doctor` semantically separate from `env status`: `env status` states facts; `doctor` explains health.

Minimum findings:

- Runtime SDK missing if `runtime-libc-present=false`.
- Toolchain binding config missing or invalid if target/binding loading fails.
- Workspace root invalid if `--workspace` points to a non-directory.

Output model:

- Keep command success if inspection completed, even when findings exist.
- Use `doctor-status=warning` when finding count is non-zero.
- Use `doctor-status=healthy` when finding count is zero.
- Put structured summary into `command-envelope.result`.

**Step 4: Update docs and tracking**

Update docs to state:

- `doctor` is now the first read-only health inspection surface.
- `doctor` does not replace `build`, `test`, `env status`, or future `env sync`.
- Current findings are intentionally minimal and runtime/toolchain/workspace focused.

**Step 5: Verify**

Run:

```bash
bash build/verify_local.sh
```

Expected: PASS with new `stage0DoctorCheck=pass`, `stage0DoctorInvalidArgumentsCheck=pass`, and `verify-local=pass`.

**Step 6: Review and commit**

Review conclusion format:

```text
Review: doctor is read-only, uses existing target/binding/runtime truth, and verification covers success plus invalid arguments. Remaining risk: finding taxonomy is intentionally minimal.
```

Commit:

```bash
git add build/verify_local.sh tools/stage0/nextpas.pas tools/stage0/README.md docs/architecture/stage0-driver-specification.md docs/architecture/developer-tooling-specification.md docs/plans/2026-03-24-nextpas-master-roadmap-plan.md task_plan.md findings.md progress.md
git commit -m "feat: add minimal doctor health surface"
```

## Task 2: Doctor Result Contract Hardening

**Files:**
- Modify: `build/verify_local.sh`
- Modify: `tools/stage0/nextpas.pas`
- Modify: `docs/architecture/diagnostics-specification.md`
- Modify: `docs/architecture/developer-tooling-specification.md`
- Modify: `task_plan.md`
- Modify: `findings.md`
- Modify: `progress.md`

**Step 1: Write failing verification gate**

Add focused checks that freeze individual doctor findings, not just aggregate counts:

- Missing runtime libc produces a finding with:
  - `doctor-finding-code=doctor.runtime-sdk-missing`
  - `doctor-finding-severity=warning`
  - envelope `doctorFindings[*].code`
- Valid workspace root produces:
  - `doctor-workspace-status=ready`
- Existing binding config produces:
  - `doctor-toolchain-binding-status=ready`

**Step 2: Run focused verification**

Run:

```bash
bash build/verify_local.sh
```

Expected: FAIL because detailed finding fields are absent.

**Step 3: Implement structured doctor findings**

In `tools/stage0/nextpas.pas`:

- Introduce a small `TDoctorFinding` record or equivalent local structure if no shared unit exists yet.
- Keep fields stable: `code`, `severity`, `subject`, `summary`, `suggestedAction`.
- Add line projection for representative first finding.
- Add envelope array `doctorFindings`.

Do not create a second diagnostics sink yet unless the code already has a clean shared owner available. This task is about result contract hardening, not full diagnostics unification.

**Step 4: Verify**

Run:

```bash
bash build/verify_local.sh
```

Expected: PASS.

**Step 5: Review and commit**

Commit:

```bash
git add build/verify_local.sh tools/stage0/nextpas.pas docs/architecture/diagnostics-specification.md docs/architecture/developer-tooling-specification.md task_plan.md findings.md progress.md
git commit -m "test: harden doctor finding contract"
```

## Task 3: Richer `env status` Readiness Evidence

**Files:**
- Modify: `build/verify_local.sh`
- Modify: `tools/stage0/nextpas.pas`
- Modify: `tools/stage0/README.md`
- Modify: `docs/architecture/developer-tooling-specification.md`
- Modify: `task_plan.md`
- Modify: `findings.md`
- Modify: `progress.md`

**Step 1: Write failing verification gate**

Extend `env status` checks to expose enough evidence for `doctor` and future `env sync`:

- `environment-status=ready|incomplete`
- `runtime-sdk-status=ready|missing`
- `toolchain-binding-status=ready`
- `distribution-status=ready|incomplete`
- envelope fields:
  - `environmentStatus`
  - `runtimeSdkStatus`
  - `toolchainBindingStatus`
  - `distributionStatus`

**Step 2: Run focused verification**

Run:

```bash
bash build/verify_local.sh
```

Expected: FAIL on the new fields.

**Step 3: Implement minimal readiness fields**

In `tools/stage0/nextpas.pas`:

- Reuse existing `env status` target/binding/runtime discovery.
- Do not change exit behavior: incomplete environment remains command success.
- Ensure `doctor` and `env status` use the same derived readiness vocabulary.

**Step 4: Verify**

Run:

```bash
bash build/verify_local.sh
```

Expected: PASS.

**Step 5: Review and commit**

Commit:

```bash
git add build/verify_local.sh tools/stage0/nextpas.pas tools/stage0/README.md docs/architecture/developer-tooling-specification.md task_plan.md findings.md progress.md
git commit -m "feat: expose richer env readiness evidence"
```

## Task 4: Minimal `query` Command Shape

**Files:**
- Modify: `build/verify_local.sh`
- Modify: `tools/stage0/nextpas.pas`
- Modify: `docs/architecture/language-service-specification.md`
- Modify: `docs/architecture/developer-tooling-specification.md`
- Modify: `tools/stage0/README.md`
- Modify: `task_plan.md`
- Modify: `findings.md`
- Modify: `progress.md`

**Step 1: Write failing verification gate**

Add a minimal read-only semantic query gate:

```bash
nextpas query symbols examples/smoke/hello_with_units.pas --target linux-x86_64 --workspace "$REPO_ROOT"
```

Expected fields:

- `command=query`
- `selector=symbols`
- `query-kind=symbols`
- `query-status=success`
- `analysis-source=compilation-session`
- `query-result-count=<non-zero>`
- `command-envelope=.*"command":"query"`
- `command-envelope=.*"queryKind":"symbols"`

Invalid argument gate:

```bash
nextpas query
```

Expected: `failure-kind=invalid-arguments`.

**Step 2: Run focused verification**

Run:

```bash
bash build/verify_local.sh
```

Expected: FAIL because `query` is unsupported.

**Step 3: Implement thin query path**

In `tools/stage0/nextpas.pas`:

- Support only `query symbols <source> --target linux-x86_64 [--workspace <root>]`.
- Reuse the existing build/session analysis path through semantic analysis, but do not execute backend/toolchain.
- Project existing semantic model counts as query results.
- Keep this honest: call it `analysis-source=compilation-session`, not language service.

**Step 4: Verify**

Run:

```bash
bash build/verify_local.sh
```

Expected: PASS.

**Step 5: Review and commit**

Commit:

```bash
git add build/verify_local.sh tools/stage0/nextpas.pas docs/architecture/language-service-specification.md docs/architecture/developer-tooling-specification.md tools/stage0/README.md task_plan.md findings.md progress.md
git commit -m "feat: add minimal query symbols surface"
```

## Task 5: Package Workflow Truth Objects

**Files:**
- Create: `compiler/frontend/np_package_workflow.pas`
- Modify: `tests/toolchain/toolchain_contract_smoke.pas`
- Modify: `build/verify_local.sh`
- Modify: `docs/architecture/package-workflow-specification.md`
- Modify: `docs/architecture/workspace-file-format-specification.md`
- Modify: `task_plan.md`
- Modify: `findings.md`
- Modify: `progress.md`

**Step 1: Write failing contract smoke**

In `tests/toolchain/toolchain_contract_smoke.pas`, add a package workflow probe that imports `np_package_workflow` and prints:

- `package-workflow-manifest-status=ready`
- `package-workflow-lock-status=ready|missing`
- `package-install-plan-status=ready|blocked|missing`
- `package-install-plan-blocker-code` / `package-install-plan-blocker-message`
- `package-workflow-source-root-count=<count>`

Add `build/verify_local.sh` gates for those fields.

**Step 2: Run focused verification**

Run:

```bash
bash build/verify_local.sh
```

Expected: FAIL because `np_package_workflow.pas` does not exist.

**Step 3: Implement minimal unit**

Create `compiler/frontend/np_package_workflow.pas` with:

- `TPackageManifestTruth`
- `TPackageLockTruth`
- `TPackageInstallPlanTruth`
- helper that consumes existing `TPackageManifestInfo` from `np_package_manifest.pas`

Keep it non-executing:

- no registry
- no fetch
- no install
- no dependency solver

**Step 4: Wire test compilation flags**

If needed, update `build/verify_local.sh` FPC flags for the contract smoke so `compiler/frontend` still resolves the new unit.

**Step 5: Verify**

Run:

```bash
bash build/verify_local.sh
```

Expected: PASS.

**Step 6: Review and commit**

Commit:

```bash
git add compiler/frontend/np_package_workflow.pas tests/toolchain/toolchain_contract_smoke.pas build/verify_local.sh docs/architecture/package-workflow-specification.md docs/architecture/workspace-file-format-specification.md task_plan.md findings.md progress.md
git commit -m "feat: add package workflow truth skeleton"
```

## Task 6: Minimal `pkg inspect` Read-only Surface

**Files:**
- Modify: `build/verify_local.sh`
- Modify: `tools/stage0/nextpas.pas`
- Modify: `compiler/frontend/np_package_workflow.pas`
- Modify: `tools/stage0/README.md`
- Modify: `docs/architecture/package-workflow-specification.md`
- Modify: `docs/architecture/developer-tooling-specification.md`
- Modify: `task_plan.md`
- Modify: `findings.md`
- Modify: `progress.md`

**Step 1: Write failing verification gate**

Add a read-only package inspection gate:

```bash
nextpas pkg inspect --workspace "$REPO_ROOT/tests/fixtures/package_manifest_source_root" --target linux-x86_64
```

Expected fields:

- `command=pkg`
- `selector=inspect`
- `package-workflow-status=ready`
- `package-manifest-status=ready`
- `package-source-root-count=<non-zero>`
- `package-source-roots=<json-array>`
- `package-install-plan-status=ready|blocked|missing`
- `package-install-plan-blocker-code` / `package-install-plan-blocker-message`
- `command-envelope=.*"command":"pkg"`
- `command-envelope=.*"selector":"inspect"`

Invalid argument gate:

```bash
nextpas pkg
```

Expected: `failure-kind=invalid-arguments`.

**Step 2: Run focused verification**

Run:

```bash
bash build/verify_local.sh
```

Expected: FAIL because `pkg` is unsupported.

**Step 3: Implement thin inspect path**

In `tools/stage0/nextpas.pas`:

- Support only `pkg inspect --workspace <root> --target linux-x86_64`.
- Reuse `ResolveWorkspaceModel(...)`.
- Consume `np_package_workflow.pas`.
- Do not fetch, install, resolve external dependencies, or write lock files.

**Step 4: Verify**

Run:

```bash
bash build/verify_local.sh
```

Expected: PASS.

**Step 5: Review and commit**

Commit:

```bash
git add build/verify_local.sh tools/stage0/nextpas.pas compiler/frontend/np_package_workflow.pas tools/stage0/README.md docs/architecture/package-workflow-specification.md docs/architecture/developer-tooling-specification.md task_plan.md findings.md progress.md
git commit -m "feat: add read-only pkg inspect surface"
```

## Task 7: Final Roadmap Sync and Full Verification

**Files:**
- Modify: `README.md`
- Modify: `docs/plans/2026-03-24-nextpas-master-roadmap-plan.md`
- Modify: `docs/architecture/master-roadmap.md`
- Modify: `docs/architecture/compiler-roadmap.md`
- Modify: `task_plan.md`
- Modify: `findings.md`
- Modify: `progress.md`

**Step 1: Audit current status claims**

Search:

```bash
rg -n "doctor|query|pkg inspect|env status|Batch 29|Batch 30|Batch 31|Batch 32|Batch 33" README.md docs task_plan.md findings.md progress.md
```

Update only stale claims. Do not rewrite completed phase1 history.

**Step 2: Run full verification**

Run:

```bash
bash build/verify_local.sh
```

Expected: PASS with all new checks and `verify-local=pass`.

**Step 3: Review and commit**

Review conclusion format:

```text
Review: roadmap and tracking now match the implemented post-Batch-29 developer tooling surfaces. Full verify-local passes. Remaining risk: language service and full package resolution are still intentionally deferred.
```

Commit:

```bash
git add README.md docs/plans/2026-03-24-nextpas-master-roadmap-plan.md docs/architecture/master-roadmap.md docs/architecture/compiler-roadmap.md task_plan.md findings.md progress.md
git commit -m "docs: sync continuous developer tooling roadmap"
```

## Final Completion Gate

Run:

```bash
git status --short
bash build/verify_local.sh
```

Expected:

- Only unrelated pre-existing untracked files may remain.
- `verify-local=pass`
- No task in this plan left partially implemented.

Final response must include:

- Commits created.
- Verification command and result.
- Any remaining intentional deferrals: full language service, `env bootstrap/use/sync`, full package resolution/install, GUI, IDE.
