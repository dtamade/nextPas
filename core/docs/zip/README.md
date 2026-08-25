# nextpas.core.zip

ZIP archive container: read, write, filesystem pack/extract.

## Units

| Unit | Role |
|------|------|
| `nextpas.core.zip` | Facade: re-exports the full public surface |
| `nextpas.core.zip.base` | Method enum, entry metadata record, signature/limit constants, entry-name safety predicate, unix/DOS time conversion |
| `nextpas.core.zip.writer` | `IZipWriter` implementation |
| `nextpas.core.zip.reader` | `IZipReader` implementation |
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
| Data descriptors | Not written | Tolerated on read | Streaming-writer archives (local flag bit 3) extract using central-directory sizes |

Not supported by design: encryption (flag bit 0 raises), multi-disk archives,
data descriptors on write (sizes are known up front), streaming entry API.

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
Bytes := W.Finish;
```

`Finish` returns the whole archive; further calls raise.
Unspecified timestamps use the DOS epoch floor so identical input yields
identical bytes (determinism). A non-zero `Mode` whose format bits declare a
directory (`$4000`) makes the entry a directory and appends the trailing slash
(same semantics as Go's archive/zip).

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
(`TZipReadOptions.MaxOutputSize`, default 1 GiB) to bound zip bombs.

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

`core/benchmarks/nextpas.core.zip/bench_zip` measures pack/parse/extract over
2000 small deflate entries plus a 1 MiB single-entry roundtrip, with a Go
`archive/zip` comparison under the same workload (including CRC verification)
in `compare_go/`. Reader parsing uses the boundary-checked
`nextpas.core.bytes.cursor` primitive with single-allocation entry arrays;
CRC32 is slice-by-8 in `nextpas.core.checksum.crc32`.

Runnable example: [examples/nextpas.core.zip](../../examples/nextpas.core.zip).
