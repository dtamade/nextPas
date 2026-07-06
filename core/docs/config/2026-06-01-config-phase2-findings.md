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

## P1 Section / Array Notes

- `GetSection` is a read-only convenience over the flat key table. It should not
  expose full descendant paths; it returns only the next segment below the
  requested prefix.
- `GetSection('')` is useful and deterministic: it returns root-level direct
  children in stored order.
- `GetSection` uses case-insensitive prefix matching and case-insensitive
  de-duplication, consistent with `FindIndex`, but preserves the spelling of the
  first stored key segment.
- `GetStringArray` reconstructs scalar arrays from direct numeric children only.
  Object arrays remain navigable via `GetSection('servers')` and
  `GetSection('servers.0')` instead of being coerced into strings.
- Sparse numeric arrays are returned compactly in numeric index order; missing
  indices do not inject empty strings.

## P2 Interpolation Notes

- Interpolation is read-time behavior, not load-time mutation. Raw entries stay
  unchanged so `ReplaceFrom`, hot reload, and multi-source load order keep their
  existing shape.
- The resolver copies `FEntries` under a read lock and releases the lock before
  recursive interpolation. This avoids recursive public getter calls while
  holding `IRWLock` and gives each getter call stable snapshot semantics.
- Placeholder resolution order is config key first, then environment variable.
  This preserves explicit config overrides when a config key and an env var have
  the same name.
- Environment fallback uses `nextpas.core.os.env.HasEnv/GetEnv`. `HasEnv` is
  important because an intentionally empty environment value is distinct from a
  missing variable.
- `$${name}` escapes to literal `${name}`.
- Missing placeholders stay unchanged in ordinary value getters, for example
  `${OPTIONAL_SECRET}`. Required getters use stricter validation and raise
  `EConfigError` when the effective value still contains an unresolved
  placeholder.
- Config-key cycles, including self-cycles, raise `EConfigError` because they
  are invalid configuration. The stack check is case-insensitive, matching
  config key lookup.
- Value APIs expose interpolated values: `GetString`, `GetInt`, `GetBool`,
  `GetFloat`, and `GetStringArray`. Structural APIs remain raw/structural:
  `Has`, `GetKeys`, `GetSection`, and `Count`.
- Default strings passed to `GetString` are interpolated against the same
  snapshot, so callers can use defaults such as `http://${host}`.

## P3 Required API Notes

- Required APIs are additive and do not change the existing default-returning
  getter semantics.
- `GetStringRequired` requires the key to exist and its interpolated value to be
  non-empty after trimming whitespace. Empty or whitespace-only strings are
  treated as invalid required values.
- `GetIntRequired`, `GetBoolRequired`, and `GetFloatRequired` all validate the
  interpolated final value. Missing keys, empty values, and invalid typed values
  raise `EConfigError`.
- `Require(keys)` is a bulk presence/value check over `GetStringRequired`; it
  is intentionally structural-light and does not parse typed values.
- Required APIs reject unresolved placeholders. Ordinary `GetString` and typed
  default getters still preserve unresolved placeholders for optional config.
- Error messages include the requested key name but not the raw config value,
  which keeps diagnostics useful without echoing possible secret contents.
