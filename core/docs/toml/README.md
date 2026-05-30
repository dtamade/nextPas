# nextpas.core.toml

TOML v1.0 parser/serializer for the nextPas core framework.

## Architecture

Two-layer API mirroring `nextpas.core.json`:

| Layer | Type | Lifecycle | Use Case |
|-------|------|-----------|----------|
| Bottom | `TTomlDocument` / `TTomlWriter` (record) | Manual Init/Done | Hot paths, zero overhead |
| Top | `ITomlDocument` / `ITomlBuilder` (interface) | Auto-release (COM refcount) | Application code |

Values are accessed via `TTomlValue` — a 12-byte borrowing view (doc pointer + node index) with safe defaults for invalid access.

## Quick Start

```pascal
uses nextpas.core.toml, nextpas.core.toml.value, nextpas.core.toml.base;

// Parse
var Doc: ITomlDocument;
Doc := TomlParse('[server]' + #10 + 'host = "localhost"' + #10 + 'port = 8080');
WriteLn(Doc.Root.Get('server').Get('port').AsInt); // 8080

// Parse with custom allocator
Doc := TomlParseWith(MyToml, MyArenaAllocator);

// Pretty-print
WriteLn(Doc.StringifyPretty(2));

// Iterate
for LItem in TomlEnumerate(Doc.Root.Get('items')) do
  WriteLn(LItem.AsStr.ToString);

// Access node key during iteration
for LItem in TomlEnumerate(Doc.Root) do
  WriteLn(LItem.Key.ToString, ' = ', LItem.AsInt);

// Build
var B: ITomlBuilder;
B := TomlBuilder;
B.BeginTable('package');
B.Key('name'); B.Str('my-app');
B.Key('version'); B.Str('1.0.0');
WriteLn(B.ToString);
```

## File Structure

```
src/nextpas.core.toml.base.pas      — TTomlNodeKind, TTomlNode, TTomlDateTime, constants
src/nextpas.core.toml.parser.pas    — TTomlDocument (low-level record parser)
src/nextpas.core.toml.value.pas     — TTomlValue (borrowing view accessor)
src/nextpas.core.toml.writer.pas    — TTomlWriter (low-level record serializer)
src/nextpas.core.toml.builder.pas   — ITomlBuilder (high-level interface)
src/nextpas.core.toml.pas           — ITomlDocument facade + TomlParse/Stringify
```

## TOML v1.0 Feature Coverage

- Basic/literal/multi-line strings with TOML-specific escape (`\uXXXX`, `\UXXXXXXXX`, `\xNN`, `\e`)
- Integers: decimal, hex (`0x`), octal (`0o`), binary (`0b`), underscore separators
- Floats: decimal, exponent, `inf`, `nan`
- Booleans: `true`, `false`
- DateTime: offset (`Z`, `+HH:MM`), local datetime, local date, local time
- Arrays with trailing comma support
- Inline tables (sealed — cannot be extended externally)
- Standard tables `[table]` with dotted keys
- Array tables `[[array]]`
- Comments `# ...`
- Strict validation: duplicate keys, leading zeros, underscore placement, datetime ranges

## Performance

Benchmarked on x86_64, FPC 3.3.1, -O2:

| Scenario | ns/op | Throughput | vs Rust `toml` | vs Go `BurntSushi/toml` |
|----------|-------|-----------|----------------|------------------------|
| Small (216B, 10 keys) | 2,500 | 86 MB/s | 6x faster | 24x faster |
| Medium (1.6KB, 50 keys) | 15,000 | 106 MB/s | 8x faster | 30x faster |
| Large (12KB, 700 keys) | 209,000 | 59 MB/s | 8x faster | 27x faster |
| Long string (10KB) | 10,000 | 1,026 MB/s | — | — |

Key optimizations:
- FNV-1a key hash for O(1) pre-filter in FindChild
- SIMD string scanning (ScanFindByte2 for `"` and `\`)
- SIMD comment skipping (ScanFindByte for `\n`)
- O(1) child append via LastChild pointer
- Zero-copy strings (borrow input buffer when no escapes)

## Testing

232 tests across 9 suites:

| Suite | Tests | Coverage |
|-------|-------|----------|
| test_toml_base | 17 | Type layout, datetime constructors, flags encoding |
| test_toml_parser | 32 | All value types, tables, arrays, error detection |
| test_toml_value | 22 | All accessor methods, for..in, FindByPath, Key, AsString |
| test_toml_writer | 21 | All serialization methods, pretty-print, nested, path quoting |
| test_toml_facade | 12 | High-level API, builder all types, allocator |
| test_toml_compliance | 84 | TOML v1.0/v1.1 + toml-test + Codex review regressions |
| test_toml_robustness | 23 | Deep nesting, long strings, hash index, malicious input |
| test_toml_fuzz | 5 | 1700 random/binary/semi-valid inputs |
| test_toml_roundtrip | 16 | Parse → Stringify → Parse → deep compare |

All suites verified with heaptrc: 0 unfreed memory blocks.

## Dependencies

- `nextpas.core.text.view` — TStringView (zero-copy string slice)
- `nextpas.core.text.scan` — SIMD byte scanning
- `nextpas.core.text.number` — ParseInt64, ParseDouble
- `nextpas.core.text.utf8` — UTF8Encode
- `nextpas.core.text.escape` — TUnescapeError type
- `nextpas.core.mem.intf` — IAllocator
- `nextpas.core.mem.default` — DefaultAllocator (facade only)
