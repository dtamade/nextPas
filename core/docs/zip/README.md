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
| `nextpas.core.zip.builder` | `IZipBuilder` — fluent chaining facade over `IZipWriter` (`ZipBuilder`/`Reserve`/`StreamTo`/`AddEntryStream`) |
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

Fluent builder — same bytes, higher-level shape:

```pascal
Bytes := ZipBuilder()
  .Reserve(2000)
  .Add('a.txt', Data)
  .AddDeflate('b.bin', Data)
  .AddWithTime('c.txt', Data, UnixSec)
  .AddDeflateWithTime('d.bin', Data, UnixSec)
  .AddWithOptions('e.cfg', Data, Opts)
  .AddDirectory('assets')
  .AddDirectoryWithTime('logs', UnixSec)
  .Finish;

Bytes := ZipBuilderForceZip64().Add('large.bin', Data).Finish;  // forced Zip64
var B: IZipBuilder;
B := ZipBuilder();
Cw := TCollectWriter.Create;
N := B.StreamTo(Cw).Add('a.txt', Data).FinishTo(Cw); // piped, byte-identical
// streaming entry via builder straight to writer kernel (INV-15)
var B2: IZipBuilder; var S: ICompressWriter;
B2 := ZipBuilder();
S := B2.AddEntryStream('big.bin', DefaultZipAddOptions);
S.Write(Data[0], Length(Data)); S.Close;
Bytes := B2.Finish; // same descriptor semantics
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
ZipExtractToDirAtomic(Bytes, '/out/dir');  // atomic: sibling TempDir+Rename, refuse if exists, auto cleanup (S67)
```

Packing collects regular files and directories only (symlinks/devices skipped),
sorts each directory level by name, stores relative paths with forward slashes,
and keeps source mtimes plus posix permission bits as unix mode words.
Extraction refuses unsafe names before any write, restores file mtimes at DOS
2-second granularity, and — for unix archives only — restores posix permissions.
Directory permissions and mtimes are applied after all content is written
(child writes would otherwise refresh directory mtimes and tightened modes
could block later files). `EnsureNoSymlinkInPath` is double-checked before/after `MkdirAll/WriteFile` plus `IsSymlink(LFull)` post-write (S66). Symlink entries are skipped by default;
`SkipSymlinks=False` creates real symlinks from entry payloads (opt-in fidelity).
`ZipExtractToDirAtomic*` wraps the same kernel in a sibling `TempDir`+`Rename` atomic commit (S67).

## Safety Model

Entry names from archives are untrusted input. The shared predicate
`IsSafeZipEntryName` rejects empty names, absolute paths, drive prefixes,
backslashes, `//` empty segments, `./` single-dot segments and `..` segments; extraction paths re-check it and raise
`EParseError` before touching the filesystem. Declared entry sizes never
allocate beyond the configured output cap — `store` 与 `deflate` 同受 `MaxOutputSize` 单条与 `MaxTotalOutputSize` 总量守卫（`common.DecompressEntryVerified` 单点，34期 store bomb 已闭环）；`SkipSymlinks=False` 显式 opt-in 下 symlink 目标不做二次 `IsSafe` 校验（`S_IFLNK` 语义允许 `../`），调用方需自行沙箱。

## Performance

`core/benchmarks/nextpas.core.zip/bench_zip` 以 `nextpas.core.bench` `TBenchSuite` 为唯一口径（`SetMinDuration 300ms` / `MinSamples 7` / `MaxIterations 25`，49 期后 `aes-*` CV `<5%`；`ACtx.SetBytes` 换算吞吐，`PrintToConsole` + `ToBenchstat` + `SaveToJSON` 归档）。

**覆盖**：`200×512B` 小容器（轻量化；`2000×512B` 全量 parity 另作预检）与 `1MiB` 吞吐两面，16 项（`pack` / `reserve` / `builder-pack` / `stream-out` / `descriptor` / `staged` / `seq-*` / `aes-*` / `pbyte` / `copy-to`）；Go 对比在 `compare_go/` 与 `test_zip_go_parity` 双向对等门（S19 领头羊双锚点：Python `zipfile` + Go `archive/zip`，47 期扩至 7 门含无签名）。

**实现要点**
- Reader：`bytes.cursor` 边界检查 + 单次分配条目数组（S46 `ReadSpan+DecodeCentralExtraBuf` 零分配，`open/parse-CD 4004→2004 allocs`）
- 校验：`checksum.crc32` slice-by-8；`zip.extra` 逐条目 64 字节栈缓冲 `Encode*` 零分配（`pack 200×512B 810→805 allocs`）
- 预分配：`Reserve` 消除 2k+ 几何重分配；`StreamOutputTo` 后 `DrainStaged` 指针分块直写零拷贝排空
- 防护：S34 `store` bomb `MaxOutput` 单点守卫 + `fs` 几何预分配（70k `O(n²)→O(n)`）；S35 顺序读 `IsKnownZipSig` 先验再试解防 `O(n·m)` CPU bomb

**门禁**
- `test_zip_perf` 以 `CountingMemoryManager` 锁定 `200×512B ≤815 / Reserve ≤810 / 1MiB ≤12 allocs`，回归即红（S20）；`test_zip_stress` 以 `70k Zip64 1.07s` / `1k 混合双路径` / `Bomb` / `并发` 验证极限（S21）
- `BASELINE.json` + `check_regression.py` 以 `allocs +2` 硬预算、`bytes` 强一致、`ns +50%` 告警构成 `make regression` 硬门（`make baseline` 需人工审查，S22）

**历代收敛**：S36 栈上 AES + `FScratch` 几何；S37 `LCumTotal` 去复用；S38 `INV-8/11/16` 入约；S39 `GuardTotalOutputSize` 单点化；S40 `zip_roundtrip` 三路径 `MaxOutput/MaxTotal` 演示；S41 顺序零拷贝；S42 无签名四形态；S43 PByte 直写；S44 AES 描述符对偶；S45 阈值可配；S46 中央零分配；S81 `Normalize` 单源；S83 `TryMethod` 单源；S85 `ResolveWithAes` 单源；S86 `ParseLocalHeader` 单源；S87 `GuardPassword` 单源；S88 `GuardIndex` 单源；详见 `ROADMAP` 与 `CHANGELOG`。

Sequential read reuses the same `DecompressEntryVerified` kernel via
`nextpas.core.zip.common`（reader/sequential 单点复用，fail-closed 语义一致），
`200×512B` 顺序提取约 `300k entries/s` 量级（内存读略高约 15%），`1MB` 单条目
顺序约 `300-400 MB/s`（视机器与 `benchstat` 方差），管道扫描开销可预期；`bench_zip`
的 `BenchSequential` 为锚点（方差高时回归以 `allocs` 硬门为准，`ns` 仅告警）。

## Cookbook

### 1. 防 bomb 双上限（MaxOutput / MaxTotal）

```pascal
var RO: TZipReadOptions;
RO := DefaultZipReadOptions;
RO.MaxOutputSize := 64*1024*1024;        // 单条目 64 MiB 上限，超限 EIOError
RO.MaxTotalOutputSize := 256*1024*1024;  // 100k×1MiB 绕过上限，超限 EIOError
R := NewZipReaderWithOptions(Bytes, RO); // 入口守卫
S := R.OpenEntry(0);                     // 流中途同受守卫
// 顺序与 fs 落盘同语义：NewZipSequentialReaderWithOptions / ZipExtractToDirWithOptions
```

`store` 与 `deflate` 在 `common.DecompressEntryVerified` 单点受检，声明尺寸不参与正确性判定，仅作预分配提示（INV-8），超限 `EIOError` fail-closed（见 `zip_roundtrip` 三路径演示）。

### 2. 描述符流式（常数内存）

```pascal
var S: ICompressWriter; var Opt: TZipAddOptions;
Opt := DefaultZipAddOptions; Opt.Method := zmDeflate; Opt.DataDescriptor := True;
S := W.AddEntryStream('big.bin', Opt); // local 头立即落盘，压缩字节直通输出管道
S.Write(Chunk[0], ChunkLen); S.Close; // 紧贴数据补描述符 12/16/20/24 四形态
// 读端：NewZipSequentialReader 从管道增量扫描，不整档
// MaxDescriptorBuffer 默认 512MiB 可配，与 MaxOutput 正交（INV-16）
```

写端内存上界为单条目压缩尺寸直写时降至常数；读端 `CollectDescriptorPayload` 先验 `IsKnownZipSig` 再试解，防 `O(n·m)` CPU bomb。

### 3. PByte 零拷贝直写（INV-18）

```pascal
var Buf: array[0..1048575] of Byte; var N: SizeUInt;
N := R.ExtractToBufferByName('big.bin', @Buf[0], SizeOf(Buf)); // 无 TBytes 物化
// store 经 Move 直写，deflate 经 RawDeflateDecompressToBuffer 泵送
// 缓冲不足 / 尺寸/CRC/MaxOutput 超限均 fail-closed，目录返回 0
// 共用 DecompressEntryToBuffer 内核，与 ExtractToBytes 字节一致
```

`1MiB` 预算 `≤8 allocs`，`bench 16项` 已锁 `extract-pbyte/1MB 7 allocs` / `copy-to 9 allocs`。

### 4. Builder 高级感链式

```pascal
Bytes := ZipBuilder().Reserve(2000)
  .Add('a.txt', Data).AddDeflate('b.bin', Data)
  .AddWithTime('c.txt', Data, 1700000000)
  .AddDirectory('logs').Finish; // 与 IZipWriter 字节级一致，薄委托仅 1 alloc
// StreamTo / AddEntryStream 同链式，语义与写端一致
```

`Reserve` 几何预分配一次性到位，`StreamTo` 后 `FinishTo` 直写管道，确定性输出。

### 5. StreamOutputTo 常数内存落盘

```pascal
var Sink: IWriter; // 文件/HTTP body
W := NewZipWriter; W.StreamOutputTo(Sink);
ZipPackDirInto('/src', W); // 已暂存分块排空，此后逐条目透传
N := W.FinishTo(Sink); // 内存恒为单条目压缩尺寸，字节级一致
```

绑定后 `Finish` 拒绝，短写 `EIOError`，失败弃用写器。

### 6. AES 口令生命周期

```pascal
var O: TZipAddOptions; var RO: TZipReadOptions;
O.Password := StrBytes('hunter2'); O.AesStrength := 3; // 1=128,2=192,3=256
W.AddEntryWithOptions('secret.txt', Data, O); // 产出 AE-2，头 CRC 置 0，盐随机，输出非确定
RO.Password := StrBytes('hunter2'); R := NewZipReaderWithOptions(Arc, RO);
Data2 := R.ExtractToBytesByName('secret.txt'); // 缺口令 EInvalidOperation，认证失败 EParseError('zip aes: authentication failed')
```

AES 描述符对偶（INV-19）：顺序读先集密文再 `UnsealWinZipAesPayload` 解帧校验，`MaxOutput` 对明文预筛。

### 7. 原子落盘（S67）

```pascal
ZipExtractToDirAtomic(Bytes, '/out/dir'); // atomic: sibling TempDir+Rename, refuse if exists, auto cleanup
var Opts: TZipExtractOptions; Opts := DefaultZipExtractOptions; Opts.MaxTotalOutputSize := 9;
ZipExtractToDirAtomicWithOptions(Bytes, '/out/dir', Opts); // 透传总量/口令等，与 WithOptions 同语义
// Exist 已存在 → EArgumentError；Rename EXDEV → CopyTree 回退，Copy 异常则清理半残留，无残留
```

非原子 `ZipExtractToDir*` 仍在 `try..finally` 逆序定稿目录；原子变体在同文件系统 `TempDir(LParent,'.zip-atomic-')` 内完成全部落盘与 `EnsureNoSymlinkInPath` 双校验后一次性 `Rename`，失败无落地（见 `SECURITY §5` 与 `CONTRACT §6`）。

## Migration（FPC System/SysUtils → nextpas.core）

| FPC 写法 | nextpas.core 写法 | 说明 |
|----------|-------------------|------|
| `SysUtils.Format` / `IntToStr` | `nextpas.core.text.conv` | 文本转换单点 |
| `TBytes = array of Byte` / `SizeInt` | `nextpas.core.base` | 基础类型别名 |
| `TStream` / `TMemoryStream` | `IStream` / `IReader` / `IWriter` / `CreateBytesStreamFrom` | 流接口化，零拷贝切片 |
| `CRC32` 手写 | `nextpas.core.checksum.crc32` | slice-by-8 |
| `TFileStream.Create` | `nextpas.core.fs.Open/Create` + `nextpas.core.io` | 文件与流分离 |
| `Exception` | `nextpas.core.exception` 分类（`EParseError`/`EIOError`/`ENotSupported` 等） | 错误语义显式 |

`core/src` 禁 `uses` 非 `nextpas.*`，FPC 单元经 `units/<target>/` stub 桥接，逐步以 `nextpas.core.*` 类型替代遗留类型，stub 自然废弃。

Runnable example: [examples/nextpas.core.zip](../../examples/nextpas.core.zip) (`zip_roundtrip` 7 式 `all demos ok`).

Roadmap: [ROADMAP.md](./ROADMAP.md) — S0—S88 已落地，1.0.1 巡检（`VERSION 1.0.1`，`SECURITY.md` 五模型，12门+16项全绿，`test_zip_fs` 12 项，`bench 16项` 可编译，`Normalize/TryMethod/ResolveWithAes/ParseLocalHeader/GuardPassword/GuardIndex` 六单源）。
