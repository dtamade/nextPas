# Config Formats

Unified configuration module supporting multiple data formats with a common flat key/value model.

## Recommended calls

Five-line happy paths + one failure path per format (prefer `Try*` over silent defaults).

### config

```pascal
uses nextpas.core.config;
var C: IConfig; N: Int64;
C := ConfigBuilder.AddJson('{"port":8080}').RequireKeys(['port']).Build;
if not C.TryGetInt('port', N) then Halt(1);  // fail closed
// fail: ConfigBuilder.AddJson('{').TryBuild(C, Err) → False
```

### json

```pascal
uses nextpas.core.json;
var D: IJsonDocument; V: Int64;
D := JsonParse('{"n":1}');
if D.HasError then Halt(1);
if not D.Root.Get('n').TryAsInt(V) then Halt(1);  // Get aliases ObjectGet
// fail: TryJsonParse('{', D) → False + diagnostic document
```

### yaml

```pascal
uses nextpas.core.yaml;
var D: IYamlDocument; S: TStringView;
D := YamlParse('name: demo' + #10);
if D.HasError or (not D.Root.Get('name').TryAsStr(S)) then Halt(1);
// fail: multi-doc / merge-key → HasError (strict subset)
```

### toml

```pascal
uses nextpas.core.toml;
var D: ITomlDocument; B: Boolean;
D := TomlParse('on = true' + #10);
if D.HasError or (not D.Root.Get('on').TryAsBool(B)) then Halt(1);
// fail: TryTomlParse('= bad', D) → False
```

### csv

```pascal
uses nextpas.core.csv;
var R: TCsvReader; F: TStringArray;
R := TCsvReader.Create('a,b' + #10 + '1,2');
if not R.ReadRow(F) then Halt(1);
// fail: after bad row, R.HasError / R.Error (in-band)
```

### ini

```pascal
uses nextpas.core.ini;
var I: TIniFile; E: TIniError;
I := TIniFile.Create;
try
  if not I.TryLoadFromString('[s]' + #10 + 'k=v' + #10, E) then Halt(1);
  // file I/O via nextpas.core.fs (ReadFileText / WriteAtomic), not TextFile
finally I.Free; end;
// fail: Strict:=True + bare line → TryLoad False
```

### xml

```pascal
uses nextpas.core.xml;
var Doc: TXmlDocument;
Doc := XmlParse('<root/>');  // raises EXmlError on hard fail
try
  // use Doc.Root ...
finally Doc.Free; end;
// fail soft: TryXmlParse('<root', Doc) → False, Doc=nil
```

## Error model (when to raise / HasError / Free)

| Format | Success path | Failure primary | Free / lifetime |
|--------|--------------|-----------------|-----------------|
| json/yaml/toml | `I*Document`, check `HasError` | document + `Error` record (usually **no raise**) | COM auto; **views borrow document** |
| xml | class `TXmlDocument` / `IXmlDocument` | **`XmlParse` raises** `EXmlError`; `TryXmlParse*` soft | **caller Free** class; interface refcount |
| csv | `ReadRow` / `ReadAll` | **in-band** `HasError` + `Error` | free reader if class-owned pattern used |
| ini | `Load*` / `TryLoad*` | Try → `TIniError`; LoadFromFile I/O → raise | **caller Free** `TIniFile` |
| config | `Build` / getters | `TryBuild` string err; Required → raise | interface snapshot / Free `TConfig` |

## Common diagnostics and lifetime matrix

| Format | Module | Parser | Diagnostic Doc | Error Type |
|--------|--------|--------|-----------------|------------|
| `json` | `nextpas.core.json` | `JsonParse` | `TryJsonParse` | `TJsonError` |
| `toml` | `nextpas.core.toml` | `TomlParse` | `TryTomlParse` | `TTomlError` |
| `yaml` | `nextpas.core.yaml` | `YamlParse` | `TryYamlParse` | `TYamlError` |
| `xml` | `nextpas.core.xml` | `XmlParse` | `TryXmlParse` | `EXmlError` |
| `csv` | `nextpas.core.csv` | `TCsvReader` | In-band via `HasError` | `TCsvError` |
| `ini` | `nextpas.core.ini` | `LoadFromString` | `TryLoadFromString` (string / `TIniError`) | `TIniError` |

### Diagnostics Fields

- JSON: `TJsonError` exposes `Message`, `Line`, `Column`, and `Offset`
- TOML: `TTomlError` exposes `Line`, `Col`, `Offset`
- YAML: `TYamlError` exposes `Message`, `Line`, `Col`, and `Offset`
- XML: `EXmlError.Pos` carries `ByteOffset`, `Line`, `Column`
- CSV: `TCsvError` exposes `Message`, `Line`, `Column`, and `Offset`
- INI: `TIniError` exposes `Message`, `Line`, `Column`, and `Offset`
- Cross-format aliases: `Col` / `Column` are property aliases on structured error records so callers can use either name.

### Safe scalar access

- JSON / YAML / TOML values expose `TryAsBool`, `TryAsInt`, `TryAsFloat`, `TryAsStr` (typed success flag + out value) alongside the lenient `As*` defaults.
- JSON also has `Get` (alias of `ObjectGet`) and `IsFloat` (alias of `IsReal`).
- Config exposes `TryGetInt` / `TryGetBool` / `TryGetFloat` / `TryGetDurationNs` / `TryGetByteSize` (True only when the key resolves and parses).

### ⚠️ Silent defaults (`As*` / `Get*` with defaults)

Lenient `AsBool` / `AsInt` / `AsFloat` / `AsStr` and config `GetInt(..., Default)` return zeros/false/empty/default **without** signaling a type or missing-key failure.

**Prefer `TryAs*` / `TryGet*` / `*Required` in application code.** Silent defaults are for demos and tolerant merge paths only.

### Bulk `IReader` parse limits

- JSON / YAML / TOML / INI / XML `Parse(IReader)` paths bulk-read via `IoReadAll` then parse.
- Shared cap: `FORMAT_BULK_PARSE_MAX_BYTES` (64 MiB) in `nextpas.core.format.limits`; overflow raises `EArgumentError`.
- CSV true streaming (`TCsvReader` + chunked `IReader`) is **not** subject to this bulk cap.

### TryParse Semantics

- JSON/TOML/YAML: Returns `False` and still assigns a diagnostic document
- XML: `TryXmlParse` returns `False` and keeps `ADoc = nil`
- INI: `TryLoadFromString` returns `False` and populates `Error`
- INI optional `Strict` mode rejects bare non-key lines on try-load

### Lifetime Model

- JSON: Borrowing view; keep the owning document alive while any `TJsonValue` is in use
- TOML: Borrowing view; keep the owning document alive while any `TTomlValue` is in use
- YAML: Borrowing view; keep the owning document alive while any `TYamlValue` is in use
- CSV: `TCsvReader` keeps its input string alive internally, while returned field strings are owned copies
- INI/CSV/XML: Callers own instances and must free them

### Diagnostic Stringification

JSON, TOML, and YAML diagnostic documents are error carriers and cannot be stringified.

### RTL isolation

Format and config production sources do not `uses SysUtils` and do not use language-level `TextFile` / `AssignFile`.

- INI file I/O uses **`ReadFileText` / `WriteAtomic`** (`nextpas.core.fs`).
- Format/config tests must not `uses SysUtils` or `Classes` (use `fs` / `process` / `text.*`).
- Out of scope for this stack (honest): Schema / XPath / YAML multi-doc streams; true streaming JSON only if >64 MiB demand appears.

## Format Surface Gates

Run surface contract tests for each format:

```bash
# Config
`make -C tests/nextpas.core.config/test_config_facade_surface clean test`

# CSV
`make -C tests/nextpas.core.csv/test_csv_facade_surface clean test`

# INI
`make -C tests/nextpas.core.ini/test_ini_facade_surface clean test`

# JSON
`make -C tests/nextpas.core.json/test_json_facade_surface clean test`

# TOML
`make -C tests/nextpas.core.toml/test_toml_facade_surface clean test`

# XML
`make -C tests/nextpas.core.xml/test_xml_facade_surface clean test`

# YAML
`make -C tests/nextpas.core.yaml/test_yaml_facade_surface clean test`
```

One-shot:

```bash
bash core/docs/config-formats/scripts/run-facade-gates.sh
make focused FOCUS=core/tests/nextpas.core.config/test_config_format_contracts
```

## Empty Keys

JSON, YAML, and TOML empty keys stay a config-adapter concern.

## Module Structure

```
src/
  nextpas.core.config*       — Flat config facade (IConfig, TConfig)
  nextpas.core.format.limits — Shared bulk parse limits
  nextpas.core.json*         — JSON parser
  nextpas.core.toml*         — TOML parser
  nextpas.core.yaml*         — YAML parser
  nextpas.core.xml*          — XML tokenizer/reader/writer
  nextpas.core.csv*          — CSV parser
  nextpas.core.ini*          — INI parser (fs-backed file I/O)
```
