# nextpas.core.toml Changelog

## 2026-05-30 — Initial Release

### Features
- Full TOML v1.0 parser/serializer
- Two-layer API: TTomlDocument/TTomlWriter (record) + ITomlDocument/ITomlBuilder (interface)
- TTomlValue borrowing view with chained Get(), type-safe accessors
- TTomlValueEnumerator + TomlEnumerate() for `for..in` iteration
- TTomlWriter.InitPretty() for multi-line array formatting
- ITomlDocument.StringifyPretty(AIndent) convenience method
- TomlParseWith(input, allocator) for custom allocator injection
- TTomlValue.Key / AsString convenience accessors

### TOML v1.0 Compliance
- All value types: string, int, float, bool, datetime, array, table
- Multi-line basic/literal strings with line continuation
- TOML-specific escape: \uXXXX, \UXXXXXXXX (rejects \/, \x)
- Integers: dec/hex/oct/bin with underscore separators
- Floats: dec, exponent, inf, nan (rejects leading zeros, capital Inf/NaN)
- DateTime: offset/local datetime, local date, local time (validates ranges)
- Inline tables (sealed — cannot be extended externally)
- Standard tables with dotted keys (whitespace around dots allowed)
- Array tables [[key]]
- Duplicate key detection (standard tables + inline tables)
- Duplicate explicit table detection
- Nesting depth limit (128)

### Performance
- 6-8x faster than Rust `toml` crate
- 24-30x faster than Go `BurntSushi/toml`
- FNV-1a key hash for O(1) pre-filter in FindChild
- SIMD string scanning (ScanFindByte2)
- SIMD comment skipping (ScanFindByte)
- O(1) child append via LastChild pointer
- Zero-copy strings (borrow input buffer when no escapes)
- Arena allocator benchmark: allocation is not the bottleneck

### Testing
- 217 tests across 9 suites
- heaptrc verified: 0 unfreed memory blocks
- 1700 fuzz inputs (random/binary/semi-valid) — no crashes
- 16 roundtrip tests (parse → stringify → parse → deep compare)
- toml-test official suite coverage: integer, string, float, table, inline-table, datetime, key

### Known Limitations
- No `\x` hex escape (TOML v1.1 feature, not v1.0)
- No `for..in` directly on TTomlValue (use TomlEnumerate wrapper)
