# nextpas.core.zip

ZIP archive container: read, write, filesystem pack/extract.

## Units

| Unit | Role |
|------|------|
| `nextpas.core.zip` | Facade: re-exports the full public surface |
| `nextpas.core.zip.base` | Method enum, entry metadata record, signature/limit constants, entry-name safety predicate, unix/DOS time conversion |
| `nextpas.core.zip.common` | Shared kernel：`GuardEntryReadable` / `DecompressEntryVerified` / LE* / `IsKnownZipSig` — reader 与 sequential 单点复用 |
| `nextpas.core.zip.extra` | Shared extra codec：`Decode*` / `Build*` / `Encode*`（栈上零分配 `PByte` 直写，无堆分配）— Zip64/AES extra 链编解码单点，消除 writer/reader 重复 |
| `nextpas.core.zip.writer` | `IZipWriter` implementation |
| `nextpas.core.zip.reader` | `IZipReader` implementation |
| `nextpas.core.zip.sequential` | `ISequentialZipReader` — pure sequential (pipe/HTTP body) reader |
| `nextpas.core.zip.aes` | WinZip AE-2 seal/unseal, streaming sealer/reader, AES-CTR |
| `nextpas.core.zip.fs` | Directory pack/extract convenience layer |

## Supported Features

| Feature | Write | Read | Notes |
|---------|-------|------|-------|
| Store entries (method 0) | Yes | Yes | |
| Deflate entries (method 8) | Yes | Yes | RFC 1951 via `compress.RawDeflate*`; CRC32 always over uncompressed payload |
| Directory entries | Yes | Yes | Name normalized to trailing `/`; MS-DOS dir attribute bit `$10` set in external attrs |
| Zip64 | Yes (automatic / forced) | Yes | Engages when sizes/offsets/count exceed ZIP32 widths; `TZipWriteOptions.ForceZip64` forces it |
| UTF-8 names | Yes (flag bit 11) | Yes | Names are raw byte strings; surfaced as stored |
| Unix mode words | Yes (`TZipAddOptions.Mode`) | Yes | `TZipEntryInfo.ExternalAttrs` / `.IsSymlink`; helpers `ZipUnixModeOf` / `ZipRegularMode` / `ZipDirectoryMode` |
| Data descriptors | Yes (`TZipAddOptions.DataDescriptor` on `AddEntryStream`) | Tolerated on read | Local bit3 + zero-size placeholder; descriptor after payload; central remains authoritative |
| Streaming entries (`IStream` family) | Yes (`AddEntryStream` → `ICompressWriter`) | Yes (`OpenEntry*` → `IDecompressReader`, `CopyEntryTo`) | Incremental CRC32+deflate on write; pull-style decode with EOF size+CRC32 verification on read |
| WinZip AES encryption (AE-2) | Yes (`TZipAddOptions.Password`) | Yes (AE-1 and AE-2, `TZipReadOptions.Password`) | Method 99 + `0x9901` extra; PBKDF2-HMAC-SHA1 keys, AES-CTR, HMAC-SHA1-80 auth code; legacy ZipCrypto refused |

Not supported by design: legacy ZipCrypto encryption (flag bit 0 without a
valid `0x9901` extra raises `ENotSupportedError`), multi-disk archives.

## API

### Write

```pascal
uses nextpas.core.zip;

var W: IZipWriter;
W := NewZipWriter;
W.AddEntry('a.txt', Data);                       // store
W.AddEntryDeflate('b.bin', Data);                // method 8
W.AddEntryWithTime('c.txt', Data, UnixSec);      // explicit mtime
W.AddDirectory('assets');                        // stored as 'assets/'

var Opts: TZipAddOptions;
Opts := DefaultZipAddOptions;
Opts.Method := zmDeflate;                        // per-entry method
Opts.ModTimeUnixSec := UnixSec;                  // < 0 = DOS floor
Opts.Mode := ZipRegularMode(&640);               // S_IFREG|0640 unix mode word
W.AddEntryWithOptions('d.cfg', Data, Opts);      // dir modes normalize trailing '/'
W.Reserve(2000);                                 // preallocate 2k entries, avoids geometric realloc
Bytes := W.Finish;
```

`Finish` returns the whole archive; further calls raise. `Reserve` is a pure
hint — byte-identical output, fail-closed on negative or post-Finish.
Unspecified timestamps use the DOS epoch floor so identical input yields
identical bytes (determinism). A non-zero `Mode` whose format bits declare a
directory (`$4000`) makes the entry a directory and appends the trailing slash
(same semantics as Go's archive/zip).

### Streaming write

```pascal
var S: ICompressWriter;
Opts := DefaultZipAddOptions;
Opts.Method := zmDeflate;
S := W.AddEntryStream('big.bin', Opts);
while HasChunk do
  S.Write(Chunk[0], Length(Chunk));   // incremental CRC32 + raw deflate
S.Close;                              // finalizes the entry
```

The payload never has to be materialized; memory is bounded by one entry's
compressed output. Set `Opts.DataDescriptor := True` to drop that bound to a
constant: the local header (flag bit 3, zero size placeholders, zip64 extra)
is emitted immediately, compressed bytes go straight to the output pipe, and
`Close` appends the data descriptor. Only one descriptor entry may be open at
a time; abandoning it without `Close` leaves orphan bytes, so `Finish` fails
closed. Streams integrate with the house `IStream` family
(`nextpas.core.io.intf`): an `AddEntryStream` sink is an `ICompressWriter`,
so any compressor/reader adapter can be chained on top. Multiple staged
(non-descriptor) streams may be open at once; each lands in its own `Close`
order. Abandoning a staged stream excludes its entry from the archive.
`Finish` raises while any stream is still open.

### Streaming output

```pascal
var Sink: IWriter;   // e.g. an HTTP response body, file stream, pipe...
W := NewZipWriter;
W.StreamOutputTo(Sink);              // entries stream through as they land
W.AddEntryDeflate('big.bin', Data);
W.AddDirectory('assets');
N := W.FinishTo(Sink);               // finalize: central dir + EOCD, N = bytes
```

Binding routes every emitted byte straight to the sink, so memory stays
bounded by one entry's compressed payload regardless of archive size. Bytes
staged before binding are drained in 256 KiB chunks first. `FinishTo` on a
never-bound writer is equivalent to bind-then-finalize. Piped and buffered
modes produce byte-identical archives (same serialization path); a short
write raises `EIOError`, sink failures propagate as-is, and a failed terminal
leaves the archive incomplete — discard the writer.

### Reading from a seekable source

```pascal
var Src: IStream;   // e.g. fs.Open('big.zip', [fmRead]) — needs IReaderAt
R := NewZipReaderFrom(Src);
for I := 0 to R.EntryCount - 1 do Info := R.Entry(I);
Data := R.ExtractToBytesByName('dir/file.txt');
```

The archive is never materialized: EOCD, central directory and entry payloads
are fetched with positioned reads (`IReaderAt`), so the caller's stream
position is untouched and several entry streams can be open concurrently —
each keeps its own span cursor. Sources that lack positioned reads are
rejected at construction (`ENotSupportedError`, fail-closed). Extraction,
`OpenEntry*` streaming and `MaxOutputSize` semantics are identical to the
in-memory reader.

### Reading from a sequential source

```pascal
var Src: IReader;   // e.g. HTTP response body, pipe, non-seekable stream
var Seq: ISequentialZipReader;
var Info: TZipEntryInfo;
var S: IDecompressReader;
Seq := NewZipSequentialReader(Src);
while Seq.Next(Info) do
begin
  WriteLn(Info.Name, ' ', Info.UncompressedSize);
  S := Seq.Open;                      // pull-style incremental decode, EOF verified
  repeat
    N := S.Read(Buf[0], SizeOf(Buf));
    if N = 0 then Break;
    Consume(Buf, N);
  until False;
  S.Close;
end;
```

The archive is never materialized: `Next` advances solely from `local header + data descriptor`
without seeking or whole-archive buffering, forming the read-side dual of
`TZipAddOptions.DataDescriptor` streaming writes. Non-descriptor entries are
bounded by declared sizes; descriptor entries are located by incremental
scanning (signature `$08074B50` + CRC/size strong validation + next-signature
pre-check) with pushback for byte-exact boundaries. `Open`/`CopyTo`/`Skip`
share the same `Guard`/`MaxOutputSize`/password semantics as the random-access
reader; only one entry stream may be open at a time.

### AES encryption (WinZip AE-2)

```pascal
var W: IZipWriter; O: TZipAddOptions; RO: TZipReadOptions;
W := NewZipWriter;
O := DefaultZipAddOptions;
O.Method := zmDeflate;
O.Password := StrBytes('hunter2');
O.AesStrength := 3;              // 1/2/3 = AES-128/192/256, 0 -> 256
W.AddEntryWithOptions('secret.txt', Data, O);
Archive := W.Finish;

RO := DefaultZipReadOptions;
RO.Password := StrBytes('hunter2');
R := NewZipReaderWithOptions(Archive, RO);
Data2 := R.ExtractToBytesByName('secret.txt');
```

Writing always produces AE-2: wire method `99` with the real compression method
in a `0x9901` extra field, general-purpose flag bit 0 set, header CRC32 forced
to zero (integrity rests entirely on the authentication code). Payloads are
compressed first, then framed as salt + password-verification value +
AES-CTR ciphertext + 10-byte truncated HMAC-SHA1; keys come from
PBKDF2-HMAC-SHA1 (1000 iterations). Salt is drawn from secure randomness, so
encrypted output is intentionally not byte-reproducible.

Reading accepts both AE-1 and AE-2. AE-1 entries keep their real CRC32 and go
through normal CRC verification; AE-2 entries must carry CRC32 = 0 and rely on
the authentication code. Password-verification and authentication-code checks
run before decryption with one uniform failure message
(`EParseError('zip aes: authentication failed')`) — wrong password and tampered
bytes are indistinguishable by design. Opening an encrypted entry without a
configured password raises `EInvalidOperationError`. Legacy ZipCrypto archives
remain rejected. On x86_64 with AES-NI available the CTR block function uses
hardware acceleration for 128/256-bit keys; everything else falls back to the
constant-time implementation (including AES-192).

### Read

```pascal
var R: IZipReader;
R := NewZipReader(Bytes);
for I := 0 to R.EntryCount - 1 do Info := R.Entry(I);
Data := R.ExtractToBytesByName('dir/file.txt');
```

Extraction verifies local header signature, decompressed size and CRC32.
Entries expose `ExternalAttrs` (raw central value) and `IsSymlink`
(unix mode word `S_IFLNK` detection). Deflate output is pre-allocated from the
declared size with a compression-ratio bound against hostile declarations.
`NewZipReaderWithOptions` takes a per-entry output cap
(`TZipReadOptions.MaxOutputSize`, default 1 GiB) to bound zip bombs,
and an optional cross-entry total cap `MaxTotalOutputSize` (0=unlimited)
to defeat the "100k × 1 MiB" bypass (INV-17); `TZipExtractOptions`
forwards the same total.

### Streaming read

```pascal
var S: IDecompressReader;
S := R.OpenEntryByName('big.bin');            // or OpenEntry(Index)
repeat
  N := S.Read(Buf[0], SizeOf(Buf));           // pull-style incremental decode
  if N = 0 then Break;
  Consume(Buf, N);
until False;
S.Close;

N := R.CopyEntryTo(R.Find('log.txt'), AnyIWriter);  // pump whole entry, verified at EOF
```

Streams decode incrementally without materializing the output; several can be
open concurrently on the same reader. Reading to EOF (a `Read` returning 0)
forces decompressed-size and CRC32 verification; abandoning a stream before
EOF skips verification by design. `MaxOutputSize` applies mid-stream: an
over-limit entry raises `EIOError` during decode instead of after allocation.

### Filesystem

```pascal
Bytes := ZipPackDir('/some/dir');          // recursive, deterministic order

var XOpts: TZipExtractOptions;
XOpts := DefaultZipExtractOptions;         // RestoreMode=True, SkipSymlinks=True
XOpts.RestoreMode := False;
ZipExtractToDirWithOptions(Bytes, '/out/dir', XOpts);

ZipExtractToDir(Bytes, '/out/dir');        // defaults: restore perms+mtime
```

Packing collects regular files and directories only (symlinks/devices skipped),
sorts each directory level by name, stores relative paths with forward slashes,
and keeps source mtimes plus posix permission bits as unix mode words.
Extraction refuses unsafe names before any write, restores file mtimes at DOS
2-second granularity, and — for unix archives only — restores posix permissions.
Directory permissions and mtimes are applied after all content is written
(child writes would otherwise refresh directory mtimes and tightened modes
could block later files). Symlink entries are skipped by default;
`SkipSymlinks=False` creates real symlinks from entry payloads (opt-in fidelity).

## Safety Model

Entry names from archives are untrusted input. The shared predicate
`IsSafeZipEntryName` rejects empty names, absolute paths, drive prefixes,
backslashes and `..` segments; extraction paths re-check it and raise
`EParseError` before touching the filesystem. Declared entry sizes never
allocate beyond the configured output cap.

## Performance

`core/benchmarks/nextpas.core.zip/bench_zip` 以 `nextpas.core.bench` `TBenchSuite` 规矩承载（`SetMinDuration 200ms`/`MinSamples 5`/`MaxIterations 20`，`ACtx.SetBytes` 换算吞吐，`PrintToConsole`+`ToBenchstat`+`SaveToJSON` 归档），覆盖 `200×512B` 小容器与 `1MiB` 吞吐两面（含 `pack-reserve`/`stream-out`/`descriptor`/`staged`/`seq-*`/`aes-*` 13 项），`2000×512B` 全量 parity 预检 + Go `archive/zip` 对比在 `compare_go/` 与 `test_zip_go_parity` 双向对等门（十九期领头羊双锚点：Python zipfile + Go archive/zip，各自独立验证 store/deflate、unicode、1MiB、20×混合、30 fuzz 的字节级一致）。Reader 解析用 `nextpas.core.bytes.cursor` 边界检查 + 单次分配条目数组；CRC32 为 `nextpas.core.checksum.crc32` slice-by-8；`nextpas.core.zip.extra` 逐条目经 64 字节栈缓冲 `Encode*` 零分配（`pack 200×512B` `810→805 allocs`），`Reserve` 预分配消除 2k+ 几何重分配；`test_zip_perf` 以 `CountingMemoryManager`（heaptrc 兼容）锁定 `200×512B ≤815 / Reserve ≤810 / 1MiB ≤12 allocs` 预算，回归即红（二十期阈值门）；`test_zip_stress` 以 `70k Zip64`（1.07s）/`1k 混合双路径`/`Bomb 单值与总量`/`并发提取` 验证极限压力下的规模与 fail-closed（二十一期）。

Sequential read reuses the same `DecompressEntryVerified` kernel via
`nextpas.core.zip.common`（reader/sequential 单点复用，fail-closed 语义一致），
`2000×512B` 顺序提取 `322k entries/s / 157 MB/s`（内存读 `373k/182 MB/s`），
`1MB` 单条目顺序 `398 MB/s`（内存读 `568 MB/s`），管道扫描开销约 15% 可预期；`bench_zip` 的 `BenchSequential` 为锚点。

Runnable example: [examples/nextpas.core.zip](../../examples/nextpas.core.zip).
