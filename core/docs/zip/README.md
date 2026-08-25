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
| Directory entries | Yes | Yes | Name normalized to trailing `/` |
| Zip64 | Yes (automatic / forced) | Yes | Engages when sizes/offsets/count exceed ZIP32 widths; `TZipWriteOptions.ForceZip64` forces it |
| UTF-8 names | Yes (flag bit 11) | Yes | Names are raw byte strings; surfaced as stored |

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
Bytes := W.Finish;
```

`Finish` returns the whole archive; further calls raise.
Unspecified timestamps use the DOS epoch floor so identical input yields
identical bytes (determinism).

### Read

```pascal
var R: IZipReader;
R := NewZipReader(Bytes);
for I := 0 to R.EntryCount - 1 do Info := R.Entry(I);
Data := R.ExtractToBytesByName('dir/file.txt');
```

Extraction verifies local header signature, decompressed size and CRC32.
`NewZipReaderWithOptions` takes a per-entry output cap (`TZipReadOptions.MaxOutputSize`,
default 1 GiB) to bound zip bombs.

### Filesystem

```pascal
Bytes := ZipPackDir('/some/dir');          // recursive, deterministic order
ZipExtractToDir(Bytes, '/out/dir');        // creates parents, restores mtime
```

Packing collects regular files and directories only (symlinks/devices skipped),
sorts each directory level by name, stores relative paths with forward slashes,
and keeps source mtimes. Extraction refuses unsafe names before any write and
restores mtimes at DOS 2-second granularity.

## Safety Model

Entry names from archives are untrusted input. The shared predicate
`IsSafeZipEntryName` rejects empty names, absolute paths, drive prefixes,
backslashes and `..` segments; extraction paths re-check it and raise
`EParseError` before touching the filesystem.

Runnable example: [examples/nextpas.core.zip](../../examples/nextpas.core.zip).
