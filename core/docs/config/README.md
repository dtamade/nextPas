# nextpas.core.config

`nextpas.core.config` is the L3 configuration module. It stores configuration as
a flat, case-insensitive dot-path key/value table, similar to .NET
`IConfiguration`.

## Pick the right entry point

Use `ConfigBuilder` when a module wants a read-only `IConfig` snapshot and a
clear source pipeline:

```pascal
var
  LCfg: IConfig;
begin
  LCfg := ConfigBuilder
    .AddDefault('server.host', '127.0.0.1')
    .AddFile('app.toml', cfToml)
    .AddEnv('APP_')
    .RequireKeys(['server.host', 'server.port'])
    .Build;
end;
```

Use `ConfigLoad` when you just need to load one file into `IConfig`:

```pascal
var
  LCfg: IConfig;
begin
  LCfg := ConfigLoad('app.json', cfJson);
end;
```

Use `TConfig` when you need a mutable instance, direct `LoadFromXxx` calls,
`ReplaceFrom`, or `TConfigWatcher` from `nextpas.core.config.watcher`.

## Build config snapshots

`ConfigBuilder` records a source plan, then replays it into a fresh `TConfig`
each time you call `Build`, `BuildConfig`, or `TryBuild`.

Available builder steps:

- `AddDefault`
- `AddIni`
- `AddJson`
- `AddYaml`
- `AddToml`
- `AddEnv`
- `AddFile`
- `RequireKeys`

Builder priority rules:

1. Defaults are always lowest priority, even if `AddDefault` appears later in
   the chain.
2. Explicit sources are applied in the order they were added.
3. Later sources override earlier sources for the same key.
4. Environment variables are just another source. They are only highest
   priority when you add them last.

This means:

```pascal
LCfg := ConfigBuilder
  .AddDefault('server.host', '127.0.0.1')
  .AddFile('app.toml', cfToml)
  .AddFile('local.toml', cfToml)
  .AddEnv('APP_')
  .Build;
```

loads defaults first, then `app.toml`, then `local.toml`, then `APP_` overrides.

### Choose the right build method

- `Build` returns an owned read-only `IConfig`.
- `BuildConfig` returns a mutable `TConfig`. The caller owns it and must
  `Free` it.
- `TryBuild` returns `False` and an error string for config-domain failures such
  as parse errors, file load errors, interpolation errors, or missing required
  keys.

Builder instances are reusable. Each build call returns an independent config
instance.

## Use config during app startup

Most applications only need one of three patterns.

See the [runnable startup demo](../../examples/nextpas.core.config/config_startup_patterns/config_startup_patterns.lpr)
and its [Makefile](../../examples/nextpas.core.config/config_startup_patterns/Makefile).
It exercises `Build`, `ConfigLoad`, `TryBuild`, and `BuildConfig` with the
same public API shown below.

For export/save flows, see the [runnable export demo](../../examples/nextpas.core.config/config_export_patterns/config_export_patterns.lpr)
and its [Makefile](../../examples/nextpas.core.config/config_export_patterns/Makefile).
It exercises `ToIni` / `ToJson` / `ToYaml` / `ToToml`, all four `SaveTo...`
helpers, reload through `ConfigLoad`, and the current representability guards
for lossy values.

For in-memory mutation flows, see the [runnable mutation demo](../../examples/nextpas.core.config/config_mutation_patterns/config_mutation_patterns.lpr)
and its [Makefile](../../examples/nextpas.core.config/config_mutation_patterns/Makefile).
It exercises `SetString` / `SetInt` / `SetBool` / `SetFloat` /
`SetStringArray`, `DeleteKey`, `DeleteSection`, `ReplaceFrom`, and `Clear`.

### Pass a read-only snapshot into modules

Use `Build` when a module should depend on `IConfig` and not on mutable config
implementation details:

```pascal
procedure StartHttpServer(const AConfig: IConfig);
begin
  WriteLn(AConfig.GetStringRequired('server.host'));
  WriteLn(AConfig.GetIntRequired('server.port'));
end;

var
  LCfg: IConfig;
begin
  LCfg := ConfigBuilder
    .AddFile('app.toml', cfToml)
    .AddEnv('APP_')
    .RequireKeys(['server.host', 'server.port'])
    .Build;
  StartHttpServer(LCfg);
end;
```

This keeps startup wiring in one place while downstream modules consume a small
read-only contract.

### Catch config failures at the process boundary

Use `TryBuild` when the process boundary wants an explicit success/failure
branch instead of exception flow:

```pascal
var
  LCfg: IConfig;
  LError: string;
begin
  if not ConfigBuilder
    .AddFile('app.toml', cfToml)
    .AddEnv('APP_')
    .RequireKeys(['server.host', 'server.port'])
    .TryBuild(LCfg, LError) then
  begin
    WriteLn(LError);
    Halt(1);
  end;

  StartHttpServer(LCfg);
end;
```

This is usually the cleanest place to convert `EConfigError` into process exit
behavior.

### Keep one mutable live config for reloads

Use `BuildConfig` when an application needs a mutable `TConfig` instance that
stays alive for `TConfigWatcher` or manual updates. Add
`nextpas.core.config.watcher` to the `uses` clause when you use the watcher:

```pascal
var
  Live: TConfig;
  Watcher: TConfigWatcher;
begin
  Live := ConfigBuilder
    .AddFile('app.toml', cfToml)
    .AddEnv('APP_')
    .BuildConfig;
  try
    Watcher := TConfigWatcher.Create(Live, 'app.toml', cfToml);
    try
      { polling loop calls Watcher.CheckReload }
    finally
      Watcher.Free;
    end;
  finally
    Live.Free;
  end;
end;
```

`TConfigWatcher` reloads into the same `TConfig` instance and updates it
through `ReplaceFrom`, so callers that share that instance keep reading the live
config object.

## Load mutable configs directly

Use `TConfig` when the caller needs a mutable config object:

```pascal
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromFile('app.toml', cfToml);
    LCfg.LoadFromIni('[server]' + #10 + 'host=127.0.0.1' + #10);
    LCfg.LoadFromJson('{"server":{"port":8080},"tags":["api","prod"]}');
    LCfg.LoadFromEnv('APP_');
  finally
    LCfg.Free;
  end;
end;
```

Supported direct loaders:

- `LoadFromFile`
- `LoadFromIni`
- `LoadFromJson`
- `LoadFromYaml`
- `LoadFromToml`
- `LoadFromEnv`

## Mutate config in memory

`TConfig` now supports direct in-memory mutation when the application needs to
build or adjust config values programmatically:

- `SetString`
- `SetInt`
- `SetBool`
- `SetFloat`
- `SetStringArray`
- `DeleteKey`
- `DeleteSection`
- `Clear`

Example:

```pascal
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.SetString('server.host', '127.0.0.1');
    LCfg.SetInt('server.port', 8080);
    LCfg.SetString('service.url', 'http://${server.host}:${server.port}');
    LCfg.SetStringArray('tags', ['api', 'prod']);

    LCfg.DeleteKey('tags.1');
    LCfg.DeleteSection('legacy');
  finally
    LCfg.Free;
  end;
end;
```

See the [runnable mutation demo](../../examples/nextpas.core.config/config_mutation_patterns/config_mutation_patterns.lpr)
for a complete write/update/reset flow with output markers that are also
checked by `test_config_examples`.

Mutation stays aligned with the existing flat dot-path storage model:

- `SetString` stores the raw string value. `GetRawString` returns that raw
  value, while `GetString` still applies normal interpolation.
- `SetStringArray('tags', ...)` writes `tags.0`, `tags.1`, and so on.
- `DeleteKey` removes one exact key.
- `DeleteSection` removes one exact prefix root plus all `prefix.*`
  descendants.
- `Clear` resets the full config snapshot.

## Export config as INI, JSON, YAML, or TOML

Both `IConfig` snapshots and mutable `TConfig` instances can now export their
current config table through:

- `ToJson`
- `ToIni`
- `ToYaml`
- `ToToml`

Mutable `TConfig` instances also add:

- `SaveToIni`
- `SaveToJson`
- `SaveToYaml`
- `SaveToToml`

Example:

```pascal
var
  Live: TConfig;
  Snapshot: IConfig;
begin
  Live := TConfig.Create;
  try
    Live.SetString('server.host', '127.0.0.1');
    Live.SetInt('server.port', 8080);
    WriteLn(Live.ToIni);
    WriteLn(Live.ToJson);
    WriteLn(Live.ToYaml);
    WriteLn(Live.ToToml);
    Live.SaveToIni('app.snapshot.ini');
    Live.SaveToJson('app.snapshot.json');
    Live.SaveToYaml('app.snapshot.yaml');
    Live.SaveToToml('app.snapshot.toml');
  finally
    Live.Free;
  end;

  Snapshot := ConfigBuilder
    .AddDefault('app.name', 'nextpas')
    .AddJson('{"app":{"port":8080}}')
    .Build;
  WriteLn(Snapshot.ToIni);
  WriteLn(Snapshot.ToJson);
  WriteLn(Snapshot.ToYaml);
  WriteLn(Snapshot.ToToml);
end;
```

Export semantics stay faithful to the config module's flat storage model:

- leaf values are exported as canonical strings, because the flat config store
  keeps canonical string values rather than original source scalar types
- INI uses a hybrid mapping:
  - common nested keys use the deepest safe `section + leaf key` split
  - split failures fall back to one global dotted key line
  - scalar/subtree coexistence such as `db` plus `db.host` is preserved as a
    global key plus a named section
  - values with leading whitespace or line breaks raise `EConfigError`, because
    the current INI parser would trim or split them lossily
- JSON and YAML rebuild a nested export view:
  - dense zero-based numeric children like `tags.0`, `tags.1` export as JSON
    arrays or YAML sequences
  - sparse or mixed numeric children export as JSON objects or YAML mappings so
    keys round-trip without reindexing
  - scalar/subtree conflicts such as `db` plus `db.host` raise `EConfigError`
    instead of silently dropping data
  - empty path segments such as `.hidden`, `name.`, or `a..b` raise
    `EConfigError`, because hierarchical JSON/YAML export cannot round-trip
    those flat keys without changing their shape
- TOML intentionally does **not** rebuild tables or dotted-key structure.
  Instead it writes one TOML entry per stored config key:
  - `server.host` becomes `"server.host" = "127.0.0.1"`
  - `tags.0` becomes `"tags.0" = "api"`
  - top-level numeric keys like `0`, `1` remain literal numeric keys
- TOML uses literal keys because the config store is flat and TOML table/dotted
  key syntax cannot losslessly preserve scalar/subtree coexistence such as `db`
  together with `db.host`
- raw placeholder strings like `${host}` stay raw on export; reload still keeps
  `GetRawString` and typed getters working
- YAML export quotes empty strings and ambiguous/special scalars so the emitted
  YAML reparses to the same stored canonical values

`ConfigLoad(APath, AFormat)` is a convenience wrapper for:

```pascal
ConfigBuilder.AddFile(APath, AFormat).Build
```

It fits small tools, tests, or one-file startup paths that do not need multiple
sources or watcher integration.

## Handle load errors

`LoadFromJson`, `LoadFromYaml`, and `LoadFromToml` raise `EConfigError` when the
underlying parser reports invalid input. The message includes parser details and
position context. JSON reports line, column, and byte offset. YAML and TOML
report line and column.

Use `TryLoadFromFile`, `TryLoadJson`, `TryLoadYaml`, or `TryLoadToml` when the
caller needs an explicit success/failure branch:

```pascal
if not LCfg.TryLoadFromFile('app.toml', cfToml, LError) then
  WriteLn(LError);

if not LCfg.TryLoadJson(AInput, LError) then
  WriteLn(LError);
```

The longer `TryLoadFromJson`, `TryLoadFromYaml`, and `TryLoadFromToml` names are
kept for compatibility.

`LoadFromFile` and `TryLoadFromFile` use the same format dispatch as
`ConfigBuilder.AddFile` and `ConfigLoad`, but load into an existing mutable
`TConfig` instance.

`AddFile` and `ConfigLoad` wrap file-path context around the underlying error,
so missing files and malformed file content report which config file failed.

Failed loads do not mutate the existing config table. `TConfigWatcher` reloads
into a temporary `TConfig` and calls `ReplaceFrom` only after parsing succeeds,
so a bad JSON/YAML/TOML reload preserves the old values while propagating
`EConfigError`.

## Read values

Default-returning getters are branch-friendly and never raise for missing keys
or invalid typed values:

- `GetString`
- `GetInt`
- `GetBool`
- `GetFloat`

Use required getters when a value must exist and be valid:

- `GetStringRequired`
- `GetIntRequired`
- `GetBoolRequired`
- `GetFloatRequired`
- `Require`

Required APIs raise `EConfigError` for missing values, empty or whitespace-only
values, unresolved placeholders, and invalid typed values. Error messages name
the requested key but do not echo the raw value.

### Read raw stored values

Use raw getters when the caller needs the stored text without interpolation:

- `GetRawString`
- `GetRawStringArray`

Raw getters return stored `${...}` placeholders unchanged. Raw defaults are also
returned unchanged. There is no raw-required API in the current public surface.

## Read sections and arrays

`GetSection(APrefix)` returns direct child segments below a prefix. It does not
return full descendant paths.

```pascal
LCfg.GetSection('server');   // host, port, tls
LCfg.GetSection('servers');  // 0, 1
LCfg.GetSection('');         // root-level children
```

`GetStringArray(AKey)` reconstructs scalar arrays from direct numeric children.
Array index segments must be canonical decimal indexes: `0`, or a non-zero digit
followed by digits. Segments such as `01` remain normal section children. The
reader sorts numeric indexes, skips sparse holes, and ignores object-array
descendants.

```pascal
LCfg.GetStringArray('tags');    // tags.0, tags.1, ...
LCfg.GetStringArray('servers'); // empty when only servers.0.host exists
```

`GetRawStringArray(AKey)` follows the same array reconstruction rules, but
returns raw stored values without interpolation.

Object arrays remain navigable through sections such as `GetSection('servers')`
and `GetSection('servers.0')`.

## Use placeholders

Value-returning getters resolve placeholders lazily at read time:

```text
service.url = https://${server.host}:${server.port}
```

Resolution order:

1. Config key, using the same case-insensitive lookup as normal getters.
2. Environment variable through `nextpas.core.os.env`.
3. Preserve the original placeholder when unresolved.

Use `$${name}` to return a literal `${name}`.

Interpolation cycles are invalid configuration and raise `EConfigError`.
Structural APIs such as `Has`, `GetKeys`, `GetSection`, and `Count` stay raw and
reflect the flat key table.
