# Config Phase 2 Findings

## Current Reality

- Current branch is based on `main` commit `ca309fb7`, not the older `0779002b`
  described in the initial prompt.
- `src/nextpas.core.config.pas` already includes DOM recursive flattening for
  JSON/YAML/TOML and existing `TryLoadFromIni/Json/Yaml/Toml` methods.
- `LoadFromJson/Yaml/Toml` still silently `Exit` on parser errors.
- Existing `TryLoadFromJson/Yaml/Toml` return `False` and fill `AError`, but
  the user-requested short names `TryLoadJson/Yaml/Toml` do not exist yet.
- Existing nested tests still include `Malformed.NoCorruption`, which encodes
  the old silent `LoadFromXxx` behavior and must be replaced with the v2 error
  contract.

## Architecture Notes

- `config` is an L3 framework module and already follows the single-unit shape
  for this cohesive implementation. This batch should not split the file.
- `EConfigError` belongs in the config public interface because callers need to
  catch it without importing lower parser units.
- Under the project error model, `EConfigError` should inherit from
  `EParseError` rather than raw `ENextPasError`.
- Parser error formatting helpers already include location information:
  JSON offset, YAML line/column, TOML line/column.

## Compatibility Notes

- Changing `LoadFromXxx` from silent failure to exceptions is intentional v2
  behavior.
- `TryLoadFromXxx` preserves branch-friendly compatibility.
- `TConfigWatcher` currently reloads into a temporary `TConfig` and calls
  `ReplaceFrom` only after the loader returns. With exceptions, bad reloads
  preserve the old config automatically.
- YAML parser behavior is permissive for `: : : bad`; it does not set
  `HasError`. For config error-contract tests, `{a: *missing}` is the reliable
  invalid YAML fixture because existing YAML tests verify undefined aliases are
  parser errors.
