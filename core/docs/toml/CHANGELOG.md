# nextpas.core.toml Changelog

## 2026-05-30 — v1.1 Extensions + Hash Index

### New Features
- TOML v1.1 escape support: `\xNN` (hex byte), `\e` (ESC 0x1B)
- TTomlValue.FindByPath('a.b.c') — dot-separated deep lookup
- TTomlValue.AsString — convenience method returning Pascal string
- TTomlValue.Key — access node key during iteration
- ITomlDocument.StringifyPretty(AIndent) — multi-line array formatting
- TomlParseWith(TStringView, IAllocator) — view-based parse with custom allocator
- TTomlValueEnumerator + TomlEnumerate() — for..in iteration
- TTomlWriter.InitPretty() — configurable indentation

### Performance
- Hash table index for large tables (>256 keys): O(1) lookup
- 10000 keys: 1010ms → 4.5ms (223x speedup)
- Standard benchmarks unchanged (no overhead for small tables)

### Correctness
- Reject leading zeros in floats (03.14)
- Reject duplicate keys in inline tables
- Reject +0xff (sign with base prefix)
- Reject capital Inf/NaN
- Reject \a, \0 escapes
- Reject datetime without seconds, without leading zeros, without T separator

### Testing
- 226 tests across 9 suites
- toml-test official suite coverage expanded
- Hash index correctness tests (500 keys + dup detection)

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
