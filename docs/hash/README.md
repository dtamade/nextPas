# nextpas.core.hash — Hash Module

Pure Pascal cryptographic hash functions with SIMD acceleration.

## Quick Start

```pascal
uses nextpas.core.hash;

// One-shot hash
var D: TSHA256Digest;
D := SHA256Of(Data[0], Length(Data));
WriteLn(DigestToHex(D, SizeOf(D)));

// Streaming (incremental)
var H: IHasher;
H := NewSHA256;
H.Write(Chunk1[0], Length(Chunk1));
H.Write(Chunk2[0], Length(Chunk2));
WriteLn(DigestToHex(H.SumBytes[0], 32));

// Clone for TLS transcript forking
var H2: IHasher;
H2 := H.Clone;
H2.Write(MoreData[0], Length(MoreData));
// H and H2 now have different states
```

## API Reference

### Facade: `uses nextpas.core.hash`

| Function | Description |
|----------|-------------|
| `NewMD5: IHasher` | Create MD5 streaming hasher |
| `NewSHA1: IHasher` | Create SHA-1 streaming hasher |
| `NewSHA256: IHasher` | Create SHA-256 streaming hasher |
| `NewSHA384: IHasher` | Create SHA-384 streaming hasher |
| `NewSHA512: IHasher` | Create SHA-512 streaming hasher |
| `NewHasher(AAlgo): IHasher` | Create hasher by algorithm enum |
| `SHA256Of(ABuf, ALen): TSHA256Digest` | One-shot SHA-256 |
| `SHA384Of(ABuf, ALen): TSHA384Digest` | One-shot SHA-384 |
| `SHA512Of(ABuf, ALen): TSHA512Digest` | One-shot SHA-512 |
| `SHA1Of(ABuf, ALen): TSHA1Digest` | One-shot SHA-1 |
| `MD5Of(ABuf, ALen): TMD5Digest` | One-shot MD5 |
| `DigestToHex(ABuf, ALen): string` | Convert digest to hex string |

### IHasher Interface

```pascal
IHasher = interface(IWriter)
  function Write(const ABuf; ACount: SizeUInt): SizeUInt;
  procedure Sum(out ADst; const ASize: SizeUInt);
  function SumBytes: TBytes;
  procedure Reset;
  function DigestSize: SizeUInt;
  function BlockSize: SizeUInt;
  function Clone: IHasher;
end;
```

### Constants (from `nextpas.core.hash.base`)

| Constant | Value |
|----------|-------|
| `SHA256_DIGEST_SIZE` | 32 |
| `SHA384_DIGEST_SIZE` | 48 |
| `SHA512_DIGEST_SIZE` | 64 |
| `SHA1_DIGEST_SIZE` | 20 |
| `MD5_DIGEST_SIZE` | 16 |

## Performance (x86_64)

| Algorithm | Throughput (8KB) | Acceleration |
|-----------|-----------------|--------------|
| SHA-256 | 254 MB/s | AVX2 dual-block |
| SHA-512 | ~200 MB/s | Scalar |
| MD5 | ~400 MB/s | Scalar |

## Platform Support

- x86_64: SHA-NI > AVX2 > SSSE3 > scalar (auto-detected at runtime)
- ARM64: Pure Pascal scalar
- All platforms: identical API, identical results
