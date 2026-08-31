# nextpas.core.encoding

L1 codec helpers for Base32, Base64, hex, URL percent-encoding, and protobuf-style varints.
Depends only on L0 (`base`). API surface is pure functions over `TBytes` / `string`.

## Formats

| Codec | Encode | Decode | Notes |
|-------|--------|--------|-------|
| Base32 | `Base32Encode` | `Base32Decode` | RFC 4648 alphabet `A-Z2-7`, padded to 8-char blocks |
| Base64 | `Base64Encode` | `Base64Decode` | RFC 4648 standard alphabet, with padding |
| Base64URL | `Base64UrlEncode` | `Base64UrlDecode` | URL-safe alphabet; **Base64UrlEncode omits padding** |
| Hex | `HexEncode` | `HexDecode` | Optional upper/lower case on encode |
| URL | `UrlEncode` | `UrlDecode` | Percent-encoding; form-style `+` |
| Varint | `VarintEncode` / `SignedVarintEncode` | `VarintDecode` / `SignedVarintDecode` | ZigZag for signed |

## Behavioral contracts

- **RFC 4648** Base32/Base64 alphabets.
- **Base32Encode always pads**; **Base32Decode accepts padded or unpadded** input, and
  rejects non-zero pad bits, out-of-alphabet characters (including lowercase), and
  malformed padding per RFC 4648 §3.5.
- **Base64UrlEncode omits padding**; decode accepts the unpadded form.
- **UrlDecode validates UTF-8** after percent/`+` expansion; invalid sequences raise.
- Application/x-www-form-urlencoded style: **+ decodes to space**.
- **HexDecode rejects odd length** (`Hex string must have even length`).
- **VarintDecode rejects non-canonical** encodings (overlong forms).

## Quick start

```pascal
uses nextpas.core.encoding;

var Enc: string; Raw: TBytes;
Enc := Base64Encode(Raw);
Raw := Base64Decode(Enc);
Enc := Base32Encode(Raw);
Raw := Base32Decode(Enc);
Enc := HexEncode(Raw);
Raw := HexDecode(Enc);
Enc := UrlEncode('a b');
// UrlDecode: + decodes to space; result must be valid UTF-8
```

## Benchmark

Local microbench (not CI gate):

```bash
make -C benchmarks/nextpas.core.encoding/bench_encoding clean run
```

Environment knobs from `nextpas.core.bench`:

- `NEXTPAS_BENCH_FILTER` — run a subset of cases
- `NEXTPAS_BENCH_MAX_ITERS` — cap iteration budget

Comparators under `bench_encoding/compare_go` and `compare_rust`.
**Rust comparator is encode-only naive** (hand-rolled, no crate); treat cross-language
ratios as **not a durable ranking**. See `benchmarks/.../bench_encoding/RESULTS.md`.

## Source layout

```
src/nextpas.core.encoding.pas          facade
src/nextpas.core.encoding.base.pas     enums
src/nextpas.core.encoding.base32.pas
src/nextpas.core.encoding.base64.pas
src/nextpas.core.encoding.hex.pas
src/nextpas.core.encoding.url.pas
src/nextpas.core.encoding.varint.pas
```

## Tests

```bash
make -C tests/nextpas.core.encoding/test_encoding clean test
make -C tests/nextpas.core.encoding/test_encoding_docs_truth clean test
```
