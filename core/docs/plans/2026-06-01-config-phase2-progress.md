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
