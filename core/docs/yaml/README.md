# nextpas.core.yaml

YAML 1.2 parser/serializer with zero-copy value access.

## Architecture

Two-layer API mirroring `nextpas.core.json` and `nextpas.core.toml`:

| Layer | Type | Lifecycle | Use Case |
|-------|------|-----------|----------|
| Bottom | `TYamlDocument` (record) | Manual Init/Done | Hot paths, zero overhead |
| Top | `IYamlDocument` (interface) | Auto-release (COM refcount) | Application code |

Values are accessed via `TYamlValue` — a borrowing view with safe defaults for invalid access.

## Quick Start

```pascal
uses nextpas.core.yaml;

// Parse
var Doc: IYamlDocument;
Doc := YamlParse('server:' + #10 + '  host: localhost' + #10 + '  port: 8080');
WriteLn(Doc.Root.Get('server').Get('port').AsInt); // 8080

// Parse with custom allocator
Doc := YamlParseWith(MyYaml, MyArenaAllocator);

// Pretty-print
WriteLn(Doc.StringifyPretty(2));

// Try parse (no exception on failure)
var DiagnosticDoc: IYamlDocument;
if not TryYamlParse('invalid: yaml: here', DiagnosticDoc) then
  WriteLn(DiagnosticDoc.Error.Message);
```

## Failure and lifetime contract

`TryYamlParse` returns `False` on parse failure and still assigns a diagnostic document.

`TYamlError` exposes `Message`, `Line`, `Col`, and `Offset`.

Keep the owning `IYamlDocument` alive while any `TYamlValue` is still in use.

Diagnostic documents cannot be stringified with `Stringify` or `StringifyPretty`.

## File Structure

```
src/nextpas.core.yaml.types.pas    — TYamlNodeKind, TYamlError, constants
src/nextpas.core.yaml.scanner.pas  — YAML token scanner
src/nextpas.core.yaml.parser.pas   — TYamlDocument (low-level record parser)
src/nextpas.core.yaml.value.pas    — TYamlValue (borrowing view accessor)
src/nextpas.core.yaml.writer.pas   — TYamlWriter (low-level record serializer)
src/nextpas.core.yaml.builder.pas  — TYamlBuilder (high-level interface)
src/nextpas.core.yaml.pas          — IYamlDocument facade + YamlParse/TryYamlParse
```

## YAML 1.2 Feature Coverage

- Scalars: strings, integers, floats, booleans, null
- Block sequences (`-`) and mappings (`key:`)
- Flow collections (`[ ]`, `{ }`)
- Anchors (`&anchor`) and aliases (`*alias`)
- Block scalars: literal (`|`), folded (`>`)
- Comments (`# ...`)
- Directives (`%YAML 1.2`)
- Multi-document support (`---`)

## Performance

- SIMD-accelerated token scanning
- Zero-copy string views for unescaped strings
- Arena allocator support for bulk parsing workloads

## Dependencies

- `nextpas.core.text.view` — TStringView
- `nextpas.core.text.scan` — SIMD byte scanning
- `nextpas.core.text.number` — ParseInt64, ParseDouble
- `nextpas.core.mem.intf` — IAllocator