# Config Phase 2 Task Plan

## Goal

Move `nextpas.core.config` toward the v2 contract without disrupting the
existing IRWLock, watcher, `ReplaceFrom`, DOM flattening, or struct mapping
work already merged.

## Batch 1

Priority: P0 error semantics.

- [x] Read `docs/design-conventions.md`.
- [x] Inspect current config implementation and tests.
- [x] Confirm no same-file concurrent config changes with
  `git log --all --oneline -5 -- src/nextpas.core.config.pas`.
- [x] Work in an isolated worktree/branch instead of the dirty shared `main`
  checkout.
- [x] Run current config baseline tests.
- [x] Add RED tests for `EConfigError` and short `TryLoadJson/Yaml/Toml`
  variants.
- [x] Implement the minimum code to pass those tests.
- [x] Run focused tests with heaptrc and check for zero leaks.
- [x] Commit the batch with a clear message.

## Batch 2

Priority: P1 section and string-array accessors.

- [x] Confirm isolated worktree is clean and no newer same-file config commits
  exist.
- [x] Add RED tests for `GetSection` and `GetStringArray`.
- [x] Implement the minimum code to pass those tests.
- [x] Run focused tests with heaptrc and check for zero leaks.
- [x] Commit the batch with a clear message.

## Design Decisions

| Topic | Decision | Reason |
| --- | --- | --- |
| Exception type | Add `EConfigError = class(EParseError)` in `nextpas.core.config` | Config parse/load failures are domain-specific parse failures while preserving framework error categories. |
| Load behavior | `LoadFromJson/Yaml/Toml` raises `EConfigError` on parser errors | Matches design convention: default APIs throw; `TryXxx` is the branch-friendly variant. |
| Try aliases | Keep existing `TryLoadFromJson/Yaml/Toml`; add `TryLoadJson/Yaml/Toml` aliases | Existing API already exists after API consistency work; short aliases satisfy the Phase 2 spelling without breaking callers. |
| Failed load mutation | Failed loads must not modify existing entries | Existing `TryLoadFromXxx` already parses before flattening; `LoadFromXxx` should preserve this property. |
| Watcher behavior | `TConfigWatcher.DoReload` may propagate `EConfigError`; `ReplaceFrom` only happens after successful parse | This preserves old config on bad reload and lets application boundaries decide whether to catch. |
| Section semantics | `GetSection('')` returns root-level direct children; `GetSection(prefix)` returns direct child segments only, de-duplicated case-insensitively while preserving first-seen spelling | Matches flattened dot-path model and keeps API useful for object and array traversal. |
| String array semantics | `GetStringArray(prefix)` reads direct numeric children (`prefix.0`, `prefix.1`, ...), sorts by numeric index, skips sparse holes, and ignores object-array descendants such as `servers.0.host` | Reconstructs scalar arrays from the .NET-style flattened storage without inventing object-array serialization. |

## Later Batches

- P2: `${VAR}` interpolation with a precise unresolved-placeholder policy.
- P3: required-value APIs such as `GetIntRequired` and `Require`.
- Final round: documentation refresh and benchmark comparison after interfaces
  are complete and stable.

## Verification Gates

- `make -C tests/nextpas.core.config/test_config clean test`
- `make -C tests/nextpas.core.config/test_config_nested clean test`
- heaptrc output must report zero unfreed memory blocks for changed config
  tests.
- `git diff --check`

## Errors Encountered

| Error | Resolution |
| --- | --- |
| Shared `main` checkout has unrelated platform/pty dirty files | Use the existing isolated config worktree and a fresh branch from current `main`. |
| Existing root/core planning files belong to another HTTP task | Use config-specific files under `docs/plans/` and leave HTTP planning files untouched. |
| Initial `apply_patch` call landed in the shared checkout | Move owned config changes to the isolated worktree and remove the accidental shared-checkout edits. |
| YAML invalid fixture `: : : bad` parsed successfully | Use `{a: *missing}`, an existing YAML-suite-proven invalid fixture that sets `HasError`. |
