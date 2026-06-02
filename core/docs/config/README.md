# nextpas.core.config

`nextpas.core.config` is the L3 configuration module. It stores configuration as
a flat, case-insensitive dot-path key/value table, similar to .NET
`IConfiguration`.

## Load configuration sources

Use `TConfig` to load one or more sources. Later sources overwrite earlier
values for the same key.

```pascal
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromIni('[server]' + #10 + 'host=127.0.0.1' + #10);
    LCfg.LoadFromJson('{"server":{"port":8080},"tags":["api","prod"]}');
    LCfg.LoadFromEnv('APP_');
  finally
    LCfg.Free;
  end;
end;
```

Supported loaders:

- `LoadFromIni`
- `LoadFromJson`
- `LoadFromYaml`
- `LoadFromToml`
- `LoadFromEnv`

JSON, YAML, and TOML loaders flatten nested data:

```json
{
  "server": { "host": "localhost", "port": 8080 },
  "tags": ["api", "prod"],
  "servers": [{ "host": "a" }, { "host": "b" }]
}
```

This becomes:

```text
server.host = localhost
server.port = 8080
tags.0 = api
tags.1 = prod
servers.0.host = a
servers.1.host = b
```

Literal keys that contain dots and nested keys can collide after flattening. The
later loaded value wins.

## Handle load errors

`LoadFromJson`, `LoadFromYaml`, and `LoadFromToml` raise `EConfigError` when the
underlying parser reports invalid input. The message includes parser details and
position context. JSON reports line, column, and byte offset; YAML and TOML
report line and column.

Use `TryLoadJson`, `TryLoadYaml`, or `TryLoadToml` when the caller needs an
explicit success/failure branch:

```pascal
if not LCfg.TryLoadJson(AInput, LError) then
  WriteLn(LError);
```

The longer `TryLoadFromJson`, `TryLoadFromYaml`, and `TryLoadFromToml` names are
kept for compatibility.

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

Typed getters parse the effective string value. If the key is missing or parsing
fails, they return the supplied default.

Use required getters when a value must exist and be valid:

- `GetStringRequired`
- `GetIntRequired`
- `GetBoolRequired`
- `GetFloatRequired`
- `Require`

Required APIs raise `EConfigError` for missing values, empty or whitespace-only
values, unresolved placeholders, and invalid typed values. Error messages name
the requested key but do not echo the raw value.

## Read sections and arrays

`GetSection(APrefix)` returns direct child segments below a prefix. It does not
return full descendant paths.

```pascal
LCfg.GetSection('server');   // host, port, tls
LCfg.GetSection('servers');  // 0, 1
LCfg.GetSection('');         // root-level children
```

`GetStringArray(AKey)` reconstructs scalar arrays from direct numeric children.
It sorts numeric indexes, skips sparse holes, and ignores object-array
descendants.

```pascal
LCfg.GetStringArray('tags');    // tags.0, tags.1, ...
LCfg.GetStringArray('servers'); // empty when only servers.0.host exists
```

Object arrays remain navigable through sections such as `GetSection('servers')`
and `GetSection('servers.0')`.

## Use placeholders

Value-returning APIs resolve placeholders lazily at read time:

```text
service.url = https://${server.host}:${server.port}
```

Resolution order:

1. Config key, using the same case-insensitive lookup as normal getters.
2. Environment variable through `nextpas.core.os.env`.
3. Preserve the original placeholder when unresolved.

Use `$${name}` to return a literal `${name}`.

Interpolation cycles are invalid configuration and raise `EConfigError`.
Structural APIs (`Has`, `GetKeys`, `GetSection`, and `Count`) stay raw and
reflect the flat key table.
