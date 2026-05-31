# nextpas.core.compress

Compression and decompression for Deflate, Gzip, and LZ4 formats.

## Supported Formats

| Format  | Compress | Decompress | Streaming | Notes |
|---------|----------|------------|-----------|-------|
| Deflate | Yes      | Yes        | Yes       | Raw deflate (RFC 1951) |
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

### Streaming (IWriter/IReader)

```pascal
var W: ICompressWriter;
W := GzipWriter(DstStream, clBestSpeed);
W.Write(Buf, Len);
W.Flush;

var R: IDecompressReader;
R := DeflateReader(SrcStream);
BytesRead := R.Read(Buf, BufSize);
```

### Compression Levels

`TCompressionLevel`: `clNone`, `clBestSpeed`, `clDefault`, `clBestCompression`

### LZ4 Utilities

- `Lz4CompressBound(InputSize)` — max compressed size for buffer allocation

## Performance

- Deflate/Gzip: pure Pascal zlib implementation via `nextpas.core.compress.zlib.ffi`
- LZ4: pure Pascal by default; define `NEXTPAS_USE_LZ4_NATIVE` for native liblz4 FFI
- Streaming interface avoids full-buffer copies for large data

## Dependencies

- `nextpas.core.io.intf` (IReader/IWriter)
- `nextpas.core.base` (TBytes)
