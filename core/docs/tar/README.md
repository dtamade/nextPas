# nextpas.core.tar

USTAR/PAX tar 容器：读、写、文件系统打包/解包，标准 `tar` 可直接读写。

## Units

| Unit | Role |
|------|------|
| `nextpas.core.tar` | Facade: re-exports 全量公共面 |
| `nextpas.core.tar.base` | 种类枚举、头记录、选项、常量 `C_TAR_BLOCK_SIZE=512`、名安全谓词、模式助手 |
| `nextpas.core.tar.common` | 共享内核：`TarPadToBlock`/`GuardTarEntrySize`/`GuardTarTotalSize`/`GuardTarNameForRead` |
| `nextpas.core.tar.reader` | `TTarReader`：迭代内存镜像，pax/x/g + GNU L/K + base-256 全兼容 |
| `nextpas.core.tar.writer` | `TTarWriter`：以 `IWriter` 为目标的 ustar 写入，prefix 自动分割 + base-256 溢出 |
| `nextpas.core.tar.fs` | 目录打包/解包便捷层 |
| `nextpas.core.tar.builder` | `ITarBuilder`：链式薄门面，委托 `TTarWriter`，`TarBuilder/NewTarBuilder` 入口 |
| `nextpas.core.compress.tar` | 兼容转发（deprecated，委托 `nextpas.core.tar`） |

## Supported Features

| Feature | Write | Read | Notes |
|---------|-------|------|-------|
| Regular files | Yes | Yes | `tekRegular`, `Size` 精确 |
| Directories | Yes | Yes | 名字补 `/`，`tekDirectory` |
| Symlink/Hardlink/Devices/FIFO | Yes (emit) | Yes (parse) | 读端全识别，`fs` 默认 `SkipSpecial=True` 跳过 |
| USTAR prefix splitting | Yes | Yes | >100 字符名自动 `prefix/name` 分割，失败 `EIOError` |
| GNU base-256 numeric | Yes (overflow) | Yes | 超 octal 容量自动 `$80` + big-endian |
| GNU longname `L/K` | — | Yes | `FPendingLongName/Link` 覆盖 |
| PAX `x/g` `path/linkpath` | — | Yes | per-entry 优于 global |
| Block alignment | Yes | Yes | 512 对齐 + 两零块收尾 |
| Zero-copy slice/stream | — | Yes | `EntryDataSlice` + `OpenEntryStream` |

## API

### Write

```pascal
uses nextpas.core.tar;

var W: TTarWriter; S: IStream;
S := CreateBytesStream;
W := TTarWriter.Create(S as IWriter);
W.AddFile('hello.txt', BytesOfString('hello'), $1A4, 1700000000);
W.AddDir('assets');
W.AddEntry(Hdr, Data); // Hdr.Name/Kind/Mode/UID/GID/MTime/UName/GName
W.Finish; // 两零块，析构自动补
```

### Read

```pascal
var R: TTarReader; H: TTarHeader; Data: TBytes; P: PByte; C: SizeUInt; RS: IReader;
R := TTarReader.Create(Bytes); // 或 Create(PByte, Count) + WithOptions(bomb 上限)
while R.Next(H) do
begin
  WriteLn(H.Name, ' ', H.Size, ' ', Ord(H.Kind));
  Data := R.EntryData; // 拷贝
  if R.EntryDataSlice(P, C) then // 零拷贝视图
    RS := R.OpenEntryStream; // 拉式流
end;
```

### Filesystem

```pascal
Bytes := TarPackDir('/src'); // 递归确定性排序，携带 mtime/权限位
TarExtractToDir(Bytes, '/out'); // 拒绝 IsSafeTarEntryName 失败、EnsureNoSymlinkInPath 二次防护
var O: TTarExtractOptions;
O := DefaultTarExtractOptions; O.RestoreMode:=True; O.SkipSpecial:=False;
TarPackDirInto('/src', Writer);
TarExtractToDirWithOptions(Bytes, '/out', O);
```

### Builder (fluent)

```pascal
uses nextpas.core.tar;

var Arc: TBytes;
Arc := TarBuilder
  .Add('hello.txt', BytesOfString('hello'), DefaultTarAddOptions)
  .AddDirectory('assets')
  .Add('assets/data.bin', BytesOfString('0123456789'))
  .Finish; // 内部 TTarWriter + CreateBytesStream，Finish 后 bytes 级与 writer 一致

// 带选项：携带权限/mtime/uname
var Opts: TTarAddOptions;
Opts := DefaultTarAddOptions; Opts.Mode := $1A4; Opts.MTimeUnix := 1700000000;
TarBuilder.AddWithOptions('hello.txt', Data, Opts)
          .AddDirectoryWithOptions('assets', Opts)
          .AddEntry(Hdr, Data).Finish;

NewTarBuilder; // 别名，等价 TarBuilder
```

## Safety Model

- `IsSafeTarEntryName` 拒绝空名、绝对路径、盘符、`\\`、`//` 空段、`./` 单点段、`..` 段；写端 `ValidateTarEntryName` 即 `EArgumentError`，读端/落盘前 `EParseError`，`TarExtractToDir` 对 `H.Name` 二次 `GuardTarNameForRead`。
- Bomb 守卫：`TTarReadOptions.MaxEntrySize`（默认 1 GiB）单条目、`MaxTotalSize` 跨条目总量，`common.Guard*` 单点 fail-closed；`EntryData`/`EntryDataSlice` 中途生效。
- 落盘前 `EnsureNoSymlinkInPath` 拒绝路径中符号链接段，避免劫持。

## Performance

- reader 零拷贝切片与外部 `PByte` 视图（无 `Copy`），writer 单块 `Move` 直写，`TarPackDirInto` 同层排序 + 几何扩容与 `deferred dir` 逆序定稿。
- `bench_tar` 另起 `nextpas.core.bench` 基准（非首版阻塞）。

Runnable example: `examples/nextpas.core.tar/tar_roundtrip`（writer / builder / pack / extract / reader 全链路，可 `make run`）。
Benchmark: `bench_tar` 另起 `nextpas.core.bench`（非首版阻塞）；与 `gzip` 组合演示待 `compress` 协作。
Roadmap: `CONTRACT.md` S0 已落地，`builder` 流式已交付。
