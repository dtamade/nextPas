# Config Formats

Unified configuration module supporting multiple data formats with a common flat key/value model.

## Common diagnostics and lifetime matrix

| Format | Module | Parser | Diagnostic Doc | Error Type |
|--------|--------|--------|-----------------|------------|
| `json` | `nextpas.core.json` | `JsonParse` | `TryJsonParse` | `TJsonError` |
| `toml` | `nextpas.core.toml` | `TomlParse` | `TryTomlParse` | `TTomlError` |
| `yaml` | `nextpas.core.yaml` | `YamlParse` | `TryYamlParse` | `TYamlError` |
| `xml` | `nextpas.core.xml` | `XmlParse` | `TryXmlParse` | `EXmlError` |
| `csv` | `nextpas.core.csv` | `TCsvReader` | In-band via `HasError` | `TCsvError` |
| `ini` | `nextpas.core.ini` | `LoadFromString` | `TryLoadFromString` | `TIniError` |

### Diagnostics Fields

- JSON: `TJsonError` exposes `Message`, `Line`, `Column`, and `Offset`
- TOML: `TTomlError` exposes `Line`, `Col`, `Offset`
- YAML: `TYamlError` exposes `Message`, `Line`, `Col`, and `Offset`
- XML: `EXmlError.Pos` carries `ByteOffset`, `Line`, `Column`
- CSV: `TCsvError` exposes `Message`, `Line`, `Column`, and `Offset`
- INI: `TIniError` exposes `Message`, `Line`, `Column`, and `Offset`

### TryParse Semantics

- JSON/TOML/YAML: Returns `False` and still assigns a diagnostic document
- XML: `TryXmlParse` returns `False` and keeps `ADoc = nil`
- INI: `TryLoadFromString` returns `False` and populates `Error`

### Lifetime Model

- JSON: Borrowing view; keep the owning document alive while any `TJsonValue` is in use
- TOML: Borrowing view; keep the owning document alive while any `TTomlValue` is in use
- YAML: Borrowing view; keep the owning document alive while any `TYamlValue` is in use
- CSV: `TCsvReader` keeps its input string alive internally, while returned field strings are owned copies
- INI/CSV/XML: Callers own instances and must free them

### Diagnostic Stringification

JSON, TOML, and YAML diagnostic documents are error carriers and cannot be stringified.

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

## Empty Keys

JSON, YAML, and TOML empty keys stay a config-adapter concern.

## Module Structure

```
src/
  nextpas.core.config/     — Flat config facade (IConfig, TConfig)
  nextpas.core.json/       — JSON parser
  nextpas.core.toml/       — TOML parser
  nextpas.core.yaml/       — YAML parser
  nextpas.core.xml/       — XML tokenizer/reader/writer
  nextpas.core.csv/        — CSV parser
  nextpas.core.ini/        — INI parser
```