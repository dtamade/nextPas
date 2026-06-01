# Config Phase 2 Progress

## 2026-06-01 Batch 1: P0 Error Semantics

- Worktree:
  `/home/dtamade/.config/superpowers/worktrees/nextPas/config-phase2-20260601`
- Branch: `codex/config-phase2-main-20260601`
- Base: current `main@ca309fb7`

### Completed

- Read design conventions and prior loader DOM plan.
- Inspected `src/nextpas.core.config.pas`.
- Inspected `test_config` and `test_config_nested`.
- Confirmed current `main` has newer config API consistency commits than the
  initial prompt described.
- Switched to an isolated branch from current `main`.
- Added config-specific planning files under `docs/plans/`.
- Baseline before behavior changes:
  - `make -C tests/nextpas.core.config/test_config clean test`:
    `38 total, 38 passed, 0 failed`, heaptrc `0 unfreed memory blocks`.
  - `make -C tests/nextpas.core.config/test_config_nested clean test`:
    `20 total, 20 passed, 0 failed`, heaptrc `0 unfreed memory blocks`.
- Found and corrected an editing-path mistake: initial `apply_patch` wrote to
  the shared checkout; owned config changes were moved to the isolated worktree.

### Next

### Completed After Resume

- Added public `EConfigError = class(EParseError)`.
- Changed `LoadFromJson`, `LoadFromYaml`, and `LoadFromToml` to raise
  `EConfigError` with parser diagnostics instead of silently exiting.
- Added short `TryLoadJson`, `TryLoadYaml`, and `TryLoadToml` aliases while
  preserving existing `TryLoadFromXxx` APIs.
- Added focused tests for:
  - short Try-load success and failure paths;
  - failed Try-load preserving existing entries;
  - malformed JSON/YAML/TOML `LoadFromXxx` raising `EConfigError`;
  - watcher bad JSON reload propagating `EConfigError` while preserving the
    old config.
- Corrected the invalid YAML fixture from `: : : bad` to `{a: *missing}` after
  reproducing that the former parses successfully in the current YAML module.
- Verification:
  - `make -C core/tests/nextpas.core.config/test_config test`:
    `41 total, 41 passed, 0 failed`, heaptrc `0 unfreed memory blocks`.
  - `make -C core/tests/nextpas.core.config/test_config_nested test`:
    `20 total, 20 passed, 0 failed`, heaptrc `0 unfreed memory blocks`.
  - `git diff --check`: exit 0.

### Next

- Commit P0 error semantics.
- Start P1: `GetStringArray` and `GetSection` with test-first coverage.

## 2026-06-02 Batch 2: P1 Section and String Array Accessors

### Completed

- Verified worktree state before editing:
  - branch `codex/config-phase2-main-20260601`
  - head `a0442c0a`
  - no uncommitted changes
  - latest config file commit was the P0 commit
- Added RED tests for:
  - `GetSection('')` root direct children;
  - `GetSection(prefix)` direct children;
  - array index sections such as `servers`, `servers.0`;
  - missing and case-insensitive section lookup;
  - `GetStringArray` basic scalar arrays;
  - sparse numeric ordering (`0`, `2`, `10`);
  - object-array descendants being ignored by `GetStringArray`;
  - top-level array reconstruction with `GetStringArray('')`.
- Verified RED failure before implementation:
  `test_config_nested.lpr` failed to compile with missing `GetSection` and
  `GetStringArray` members.
- Implemented:
  - public `TConfig.GetSection`;
  - public `TConfig.GetStringArray`;
  - private helper routines for direct-child extraction, case-insensitive
    de-duplication, numeric index parsing, and small insertion-sort of array
    elements.
- Verification:
  - `make -C core/tests/nextpas.core.config/test_config clean test`:
    `41 total, 41 passed, 0 failed`, heaptrc `0 unfreed memory blocks`.
  - `make -C core/tests/nextpas.core.config/test_config_nested clean test`:
    `28 total, 28 passed, 0 failed`, heaptrc `0 unfreed memory blocks`.
  - `git diff --check`: exit 0.

### Next

- Commit P1 accessors.
- Start P2: `${VAR}` interpolation policy and tests.

## 2026-06-02 Batch 3: P2 Placeholder Interpolation

### Completed So Far

- Verified worktree state before editing:
  - branch `codex/config-phase2-main-20260601`
  - head `aa720d64`
  - no uncommitted changes
  - latest config file commit was the P1 commit
- Re-read `core/docs/design-conventions.md` and the config DOM loader plan.
- Added RED tests for:
  - config key placeholders such as `${server.host}`;
  - environment variable fallback;
  - config key precedence over same-named env var;
  - interpolation inside default strings passed to `GetString`;
  - `$${...}` escaping;
  - unresolved placeholders being preserved;
  - typed getter parsing after interpolation;
  - `GetStringArray` item interpolation;
  - cross-key and self-cycle `EConfigError`.
- Verified RED failure before implementation:
  - `make -C core/tests/nextpas.core.config/test_config test`:
    `48 total, 41 passed, 7 failed`, with failures showing raw placeholders;
    heaptrc `0 unfreed memory blocks`.
- Implemented:
  - read-time interpolation over a copied `TConfigEntry` snapshot;
  - config-key-first, env-second placeholder resolution;
  - `$${...}` escape handling;
  - unresolved placeholder preservation;
  - case-insensitive cycle detection raising `EConfigError`;
  - interpolation for `GetString`, typed getters, defaults, and
    `GetStringArray` values.
- During GREEN, fixed two narrow issues:
  - qualified env lookup as `nextpas.core.os.env.HasEnv/GetEnv`;
  - removed literal brace examples from a Pascal `{ ... }` comment to avoid FPC
    nested-comment warnings.
- Focused GREEN verification:
  - `make -C core/tests/nextpas.core.config/test_config test`:
    `49 total, 49 passed, 0 failed`, heaptrc `0 unfreed memory blocks`.
  - `make -C core/tests/nextpas.core.config/test_config_nested test`:
    `28 total, 28 passed, 0 failed`, heaptrc `0 unfreed memory blocks`.
- Final clean verification:
  - `make -C core/tests/nextpas.core.config/test_config clean test`:
    `49 total, 49 passed, 0 failed`, heaptrc `0 unfreed memory blocks`.
  - `make -C core/tests/nextpas.core.config/test_config_nested clean test`:
    `28 total, 28 passed, 0 failed`, heaptrc `0 unfreed memory blocks`.
  - `git diff --check`: exit 0.
- External `/codex`-style review was requested via a read-only sub-agent for
  interpolation boundaries, locks, and coverage; it timed out after two waits
  without findings. Local review found no lock reentry or loader/watcher
  mutation risk.

### Next

- Commit P2 interpolation.
- Start P3 required-value APIs.
