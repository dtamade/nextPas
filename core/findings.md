# Findings: parser TryParse API compliance

## Requirements
- Read `docs/api-conventions.md` first.
- Add `TryJsonParse`, `TryYamlParse`, `TryTomlParse`, and `TryXmlParse`.
- Preserve existing parse APIs exactly.
- For JSON/YAML/TOML, return parsed document through the `out` parameter even when `HasError` is true.
- For XML, catch `EXmlError`, free any assigned class document, and return `False`.
- Add success/failure tests for each parser facade.
- Verify tests and memory leak behavior.

## Research Findings
- `docs/api-conventions.md` requires parser modules to keep existing `Parse` APIs and add `TryXxx` as a supplemental branch-friendly form.
- JSON facade already exports `JsonParse` and `JsonParseWith`; `IJsonDocument` exposes `HasError` and `Error`.
- YAML facade already exports `YamlParse` overloads; `IYamlDocument` exposes `HasError` and `Error`.
- TOML facade already exports `TomlParse` and `TomlParseWith`; `ITomlDocument` exposes `HasError` and `Error`.
- XML facade exports `XmlParse(const AInput: string): TXmlDocument` and re-exports `EXmlError`; document ownership is manual because `TXmlDocument` is a class.
- Best-fit existing test files are:
  - `tests/nextpas.core.json/test_json_facade/test_json_facade.lpr`
  - `tests/nextpas.core.yaml/test_yaml_facade/test_yaml_facade.lpr`
  - `tests/nextpas.core.toml/test_toml_facade/test_toml_facade.lpr`
  - `tests/nextpas.core.xml/test_xml/test_xml.lpr`
- These facade tests already have dedicated `Makefile`s using `-gh -gl`, so they are the most direct place to add API-surface verification and leak checks.

## Issues Encountered
| Issue | Resolution |
|---|---|
| `/home/dtamade/.codex/memories/MEMORY.md` is missing in this environment | Continued with system-provided memory summary and live repo inspection |
