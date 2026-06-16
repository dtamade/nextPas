# nextpas.core.compress

Compression and decompression for Deflate, Gzip, and LZ4 formats.

## Supported Formats

| Format  | Compress | Decompress | Streaming | Notes |
|---------|----------|------------|-----------|-------|
| Deflate | Yes      | Yes        | Yes       | zlib-wrapped Deflate stream (RFC 1950) |
| Gzip    | Yes      | Yes        | Yes       | Gzip wrapper (RFC 1952) |
| LZ4     | Yes      | Yes        | No        | Block format, optional native FFI |

## API

### One-Shot (TBytes)

```pascal
uses nextpas.core.compress;

var Compressed, Original: TBytes;
Compressed := DeflateCompress(Data, clDefault);
Original := DeflateDecompress(Compressed);

Compressed := GzipCompress(Data);
Original := GzipDecompress(Compressed);

Compressed := Lz4Compress(Data);
Original := Lz4Decompress(Compressed, OriginalSize);
```

Runnable example: [compress_roundtrip.lpr](../../examples/nextpas.core.compress/compress_roundtrip/compress_roundtrip.lpr)
and its [Makefile](../../examples/nextpas.core.compress/compress_roundtrip/Makefile). The runnable example covers one-shot and bounded facade helpers; streaming snippets are contract-tested by the audit gate, not by the example.

### Streaming (IWriter/IReader)

```pascal
var W: ICompressWriter;
W := GzipWriter(DstStream, clFastest);
W.Write(Buf, Len);
W.Flush;

var R: IDecompressReader;
R := DeflateReaderWithMaxOutputSize(SrcStream, MaxOutputSize);
BytesRead := R.Read(Buf, BufSize);

R := GzipReaderWithMaxOutputSize(SrcStream, MaxOutputSize);
BytesRead := R.Read(Buf, BufSize);

R := DeflateReader(SrcStream);
BytesRead := R.Read(Buf, BufSize);
```

Writer `Close` finalizes the compressed stream and writes any required trailer.
Writer `Flush` publishes a readable prefix and keeps the writer open for later `Write` calls.
Writer `Close` is idempotent.
Writes after writer `Close` raise stable write-after-close errors.
Flush after successful writer `Close` raises stable flush-after-close errors.
Reader `Close` is release-only. Read to EOF to validate trailing bytes, CRC, and size.
Reader `Close` is idempotent.
Reads after reader `Close` return 0.
Streaming factories reject nil readers and writers with stable argument errors.

### Compression Levels

`TCompressionLevel`: `clNone`, `clFastest`, `clDefault`, `clBest`

### Bounded Deflate/Gzip Decompression

`DeflateDecompress` keeps the module default one-shot output cap. If a caller needs a tighter cap for untrusted input, use the root facade bounded helpers:

```pascal
uses nextpas.core.compress;

Original := DeflateDecompressWithMaxOutputSize(Compressed, MaxOutputSize);
```

```pascal
uses nextpas.core.compress;

Original := GzipDecompressWithMaxOutputSize(Compressed, MaxOutputSize);
```

The bounded helper raises if the decoded output would exceed `MaxOutputSize`. Output-limit errors are `deflate: decompressed size exceeds limit` and `gzip: decompressed size exceeds limit`. Streaming readers also expose `DeflateReaderWithMaxOutputSize` and `GzipReaderWithMaxOutputSize` for cumulative output caps.

Deflate error model: one-shot and streaming decode classify malformed input as
`deflate: invalid zlib header`, `deflate: truncated stream`,
`deflate: preset dictionary not supported`, `deflate: trailing bytes after stream`,
and `deflate: corrupt stream`.

Gzip error model: header failures are `gzip: header too short`, `gzip: invalid magic`, `gzip: unsupported method`, and `gzip: invalid flags`. Optional-header truncation uses `gzip: truncated FEXTRA`, `gzip: truncated FNAME`, `gzip: truncated FCOMMENT`, and `gzip: truncated header`. Oversized FNAME/FCOMMENT fields use `gzip: header field exceeds limit`, and header CRC failures use `gzip: header CRC mismatch`. Payload and trailer failures use `gzip: truncated stream`, `gzip: truncated trailer`, `gzip: trailing bytes after trailer`, and `gzip: corrupt stream`. Integrity failures use `gzip: CRC32 mismatch` and `gzip: size mismatch`.

Concatenated gzip members use the same header, payload, trailer, and integrity error model as the first member. Bytes after a trailer that do not begin a complete gzip member remain `gzip: trailing bytes after trailer`; bytes that begin with gzip magic but truncate the fixed header are `gzip: header too short`.

### LZ4 Utilities

- `Lz4CompressBound(InputSize)` — max compressed size for buffer allocation
- For untrusted LZ4 input, use `Lz4DecompressWithMaxOutputSize` from the root facade:
  `uses nextpas.core.compress;`
  `Original := Lz4DecompressWithMaxOutputSize(Compressed, OriginalSize, MaxOutputSize);`
- `Lz4Decompress(nil, 0)` returns empty `TBytes`; non-empty input with original size `0` raises.
- LZ4 APIs handle raw LZ4 block payloads; `.lz4` frame headers are rejected as unsupported.

LZ4 error model: The stable `lz4:` error model is the default pure-Pascal surface. Malformed raw-block branches use stable `EIOError` messages: `lz4: truncated literal length`, `lz4: literal overflow`, `lz4: literal length overflow`, `lz4: truncated offset`, `lz4: zero offset`, `lz4: offset before start`, `lz4: truncated match length`, `lz4: match length overflow`, `lz4: output overflow`, and `lz4: decompressed size mismatch`. Block-structure failures use `lz4: final literal tail missing` or `lz4: final match too close to end`. Metadata and declared-size failures use `lz4: input size exceeds limit`, `lz4: invalid original size`, `lz4: original size exceeds limit`, `lz4: compressed input size exceeds limit`, `lz4: decompressed size exceeds limit`, `lz4: empty input with nonzero original size`, and `lz4: non-empty input with zero original size`. The optional native LZ4 FFI surface is not error-message parity with the pure path; native decode failures can use `lz4 native: decompress failed` and `lz4 native: size mismatch`.

## Performance

- Deflate/Gzip: FPC paszlib by default; `nextpas.core.compress.zlib.ffi` documents the optional native zlib switch
- LZ4: pure Pascal by default; define `NEXTPAS_USE_LZ4_NATIVE` for native liblz4 FFI
- `make -C core/tests/nextpas.core.compress/test_compress_audit zlib-native-compile` only proves the native zlib branch compiles; the default audit gate does not provide native zlib runtime/link proof.
- Run `make -C core/tests/nextpas.core.compress/test_compress_audit zlib-native-runtime` on hosts with system `libz.so` for native zlib runtime/link proof.
- Native LZ4 audit is compile-only by default; run `make -C core/tests/nextpas.core.compress/test_compress_audit native-runtime` only on hosts with system liblz4 for runtime/link proof.
- `nextpas.core.compress.lz4.ffi` is ABI-only for liblz4 declarations; `nextpas.core.compress.lz4.native` owns wrapper, fallback, and error-policy code.
- Native LZ4 runtime proof requires the development link name `liblz4.so`, not only a runtime `liblz4.so.1` shared object.
- When `pkg-config liblz4` is available, `native-runtime` uses that libdir for FPC linking and runtime shared-library lookup.
- Streaming interface avoids full-buffer copies for large data
- Audit gate compiles the benchmark only; run `make -C core/tests/nextpas.core.compress/test_compress_audit benchmark-run` for throughput evidence.
- The Pascal benchmark is one-shot throughput only; it does not measure streaming reader or writer throughput.
- The Go comparator source covers Deflate and Gzip only.
- Default audit uses `go test ./...` as a compile-check; run `make -C core/tests/nextpas.core.compress/test_compress_audit go-comparator-run` for Go throughput evidence.
- LZ4 throughput is covered by the Pascal benchmark only.

## Gate Matrix

| Gate | Role | Coverage |
|------|------|----------|
| `audit-gate` | Default landing gate | `test` alias: runtime audit, basic/deep module tests, native compile-only branches, benchmark/Go compile checks, example run, heaptrc, docs contract |
| `native-runtime`, `zlib-native-runtime` | Optional runtime/link proof | Host-provided liblz4/libz plus heaptrc; keep optional unless the landing host owns those libraries |
| `benchmark-run`, `go-comparator-run` | Optional throughput evidence | Not part of default landing proof |
| `heaptrc`, `docs-contract-run` | Focused evidence | Zero-leak audit proof and docs/source contract proof |

## Dependencies

- `nextpas.core.io.intf` (IReader/IWriter)
- `nextpas.core.base` (TBytes)
