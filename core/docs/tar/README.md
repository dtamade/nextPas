# nextpas.core.tar

USTAR/PAX tar 容器：读、写、文件系统打包/解包，标准 `tar` 可直接读写。

## Units

| Unit | Role |
|------|------|
| `nextpas.core.tar` | Facade: re-exports 全量公共面（唯一公共入口） |
| `nextpas.core.tar.base` | 种类枚举、头记录、选项、常量 `C_TAR_BLOCK_SIZE=512`、名安全谓词、模式助手 |
| `nextpas.core.tar.intf` | `ITarBuilder` 接口契约（`base←intf←实现←门面`） |
| `nextpas.core.tar.reader` | `TTarReader`：迭代内存镜像，pax/x/g + GNU L/K + base-256 全兼容 |
| `nextpas.core.tar.writer` | `TTarWriter`：以 `IWriter` 为目标的 ustar 写入，prefix 自动分割 + pax `x` 长名回退（>100 无 prefix 切分或 `linkpath>100` 时） + base-256 溢出 + `devmajor/devminor` 设备号（`C_TAR_LAYOUT.DevMajor/DevMinor` 单源），需显式 `Finish`（`Destroy` SafeFail 抑制 `EIOError` 二次逃逸） |
| `nextpas.core.tar.fs` | 目录打包/解包便捷层 |
| `nextpas.core.tar.builder` | `ITarBuilder` 实现：链式薄门面，委托 `TTarWriter`，单一 `TarBuilder` 入口（显式 `Finish` fail-closed，`AddEntryFromReader` 流式零拷贝 64K pooled 复用 via `FIOBuf` 无缩容） |
| `nextpas.core.compress.tar` | 兼容转发（deprecated，委托 `nextpas.core.tar`） |

> 内部实现（不属于公共 API，禁止门面外直引）：`nextpas.core.tar.common` — 共享内核 `TarPadToBlock`/`Guard*`（`EntrySize/TotalSize/NameForRead`）+ 校验和单点 `TarComputeChecksum*`/`TarVerifyBlockChecksum`/`TarHeaderIsZeroOrValid` + 数值单点 `TarParseNumericField`/`TarFormatNumericField` + pax 单点 `TarParsePaxRecords`（零拷贝 PByte 切片、复用 `bytes.ops` 单源；薄守卫 inline，含循环体外联以遵 design-conventions 禁 inline、避 I-Cache 膨胀），仅供 `reader/writer/fs` 实现内复用。

## Supported Features

| Feature | Write | Read | Notes |
|---------|-------|------|-------|
| Regular files | Yes | Yes | `tekRegular`, `Size` 精确 |
| Directories | Yes | Yes | 名字补 `/`，`tekDirectory` |
| Symlink/Hardlink/Devices/FIFO | Yes (emit) | Yes (parse) | 读端全识别，`fs` 默认 `SkipSpecial=True` 跳过 |
| USTAR prefix splitting | Yes | Yes | >100 字符名自动 `prefix/name` 分割，无 prefix 切分时写端以 `pax x` 承载 |
| GNU base-256 numeric | Yes (overflow) | Yes | 超 octal 容量自动 `$80` + big-endian |
| GNU longname `L/K` | — | Yes | 读端 `FPendingLongName/Link` 覆盖 |
| PAX `x/g` `path/linkpath` | Yes (x 回退) | Yes | 写端>100 无切分或 `linkpath>100` 前置 `x` 扩展头（`bytes.ops` 单源 `StringToBytes` 一次 Move），读端 per-entry 优于 global，`g` 全局持久至下一 `g` 覆盖支持多条目继承、恶意污染由 `IsSafeTarEntryName` 拒绝、`ClearGlobalPax` 显式可选 |
| Block alignment | Yes | Yes | 512 对齐 + 两零块收尾 |
| Zero-copy slice/stream | — | Yes | `TrySlice` 单一规范 `TByteSpan` 零拷贝视图 + `EntryDataSlice` 薄转发(`PByte`) + `OpenEntryStream` 持有型 `IReader`（`bytes.ops.CopyMemory` 单源，Reader 释放后仍可读，外部裸指针固化拷贝） |

## API

### Write

```pascal
uses nextpas.core.tar;

var W: TTarWriter; S: IStream;
S := CreateBytesStream;
W := TTarWriter.Create(S as IWriter);
W.AddFile('hello.txt', BytesOfString('hello'), $1A4, 1700000000);
W.AddDir('assets');
W.AddEntry(Hdr, Data); // Hdr.Name/Kind/Mode/UID/GID/MTime/UName/GName/DevMajor/DevMinor
W.Finish; // 两零块，需显式调用，析构 SafeFail 抑制 EIOError 二次逃逸
```

### Read

```pascal
var R: TTarReader; H: TTarHeader; Data: TBytes; P: PByte; C: SizeUInt; RS: IReader; S: TByteSpan;
R := TTarReader.Create(Bytes); // 或 Create(PByte, Count) + WithOptions(bomb 上限)
while R.Next(H) do
begin
  WriteLn(H.Name, ' ', H.Size, ' ', Ord(H.Kind));
  Data := R.EntryData; // 拷贝（SpanClone 单源）
  if R.TrySlice(S) then // 单一规范零拷贝视图（inline，生命周期绑 Reader）
    ; // 按需 SpanClone(S) 单次 Move（bytes.ops 单源）
  if R.EntryDataSlice(P, C) then // 薄转发复用 TrySlice
    RS := R.OpenEntryStream; // 持有型流，Reader 释放后仍可读
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
  .Add('hello.txt', BytesOfString('hello'))
  .AddDirectory('assets')
  .Add('assets/data.bin', BytesOfString('0123456789'))
  .Finish; // 内部 TTarWriter + CreateBytesBuilder 直写切片（inline 零拷贝），Finish 单次 ToBytes，bytes 级与 writer 一致；未 Finish 析构 fail-closed 抛错

// 带选项：携带权限/mtime/uname
var Opts: TTarAddOptions;
Opts := DefaultTarAddOptions; Opts.Mode := $1A4; Opts.MTimeUnix := 1700000000;
TarBuilder.AddWithOptions('hello.txt', Data, Opts)
          .AddDirectoryWithOptions('assets', Opts)
          .AddEntry(Hdr, Data)
          .AddEntryFromReader(Hdr2, Reader) // 流式零拷贝 64K pooled 复用 via FIOBuf 无缩容（首分配≤64K后200文件复用）、无 TBytes 全量拷贝，抽取 WritePaddedPayload 单源
          .Finish; // 显式 Finish 必需，未调即析构抛 EInvalidOperationError
```

## Safety Model

- `IsSafeTarEntryName` 拒绝空名、绝对路径、盘符、`\\`、`//` 空段、`./` 单点段、`..` 段；写端 `ValidateTarEntryName` 即 `EArgumentError`，读端/落盘前 `EParseError`，`TarExtractToDir` 对 `H.Name` 二次 `GuardTarNameForRead`。
- Bomb 守卫：`TTarReadOptions.MaxEntrySize`（默认 1 GiB）单条目、`MaxTotalSize` 跨条目总量，`common.Guard*` 单点 fail-closed；`EntryData`/`EntryDataSlice` 中途生效。
- 落盘前 `EnsureNoSymlinkInPath` 拒绝路径中符号链接段，避免劫持。

## Performance

- **inline/零拷贝/单源**：`reader` 零拷贝切片（`TrySlice` 单一规范 `TByteSpan` 视图 + `EntryDataSlice` 薄转发，`FieldSlice` 单次 `SpanIndexOf` 单源视图；`EntryData` 为 `SpanClone` 单源拷贝，`OpenEntryStream` 持有型 `FHold` 防悬垂，`Next` 对 `H.Name` 自动 `GuardTarNameForRead`，`pax g` 全局持久至下一 `g` 覆盖，`ClearGlobalPax` 显式可选；设备 `DevMajor/DevMinor` 解析/回写完整），`writer` 单块 `Move` 直写（`WriteBlock` 去 inline 避 512 栈 I-Cache 复制膨胀、out-of-line 单拷贝，`WritePaddedPayload` 单源 Bulk+Tail+Pad 抽取 `bytes.ops CopyMemory` inline 零拷贝，`AddEntryFromReader` 64K pooled 复用 `FIOBuf` 无缩容 amortized 1 alloc 零拷贝，`builder` 经 `IBytesBuilder` 直写切片、inline `AppendBytes` 几何扩容、单次 `ToBytes`，`Destroy` SafeFail 抑制二次逃逸），`common.TarHeaderIsZeroOrValid` 单遍 512 融合校验和/零块与 `TarParsePaxRecords` 零拷贝 `PByte` 复用 `bytes.ops` 单源（薄守卫 inline，热循环外联）。
- **量化基线**：`core/benchmarks/nextpas.core.tar/bench_tar` 7 项 `TBenchSuite` 300ms/7样，数值单源于 `BASELINE.json`（`build/bench-tar.json` 人工审查固化），`make -C core/benchmarks/nextpas.core.tar/bench_tar run` 可复现，`TAR_BENCH_FULL=1` 追加 `2000×512B` 档；详见 `CONTRACT.md §6`。
- **回归门限（CONTRACT §6）**：`allocs` 硬预算 `baseline+2`/`bytes` 强一致（CI 红），`ns/op` `1.5×` WARN 与 `MB/s` `0.65×` WARN；Go/Rust 对照同口径 `compare_go`/`compare_rust` 守卫 `Pascal ns/op ≤1.5×` 且 `MB/s ≥0.70×`（`GOMAXPROCS=1` 降噪，连续两机复现升硬门）；`make -C core/benchmarks/nextpas.core.tar/bench_tar regression` 经 `check_regression.py` 比对 `BASELINE.json` 一键门。

Runnable example: `examples/nextpas.core.tar/tar_roundtrip`（writer / builder / pack / extract / reader 全链路，可 `make run`）。
Benchmark: 已落地 `bench_tar`（见上），与 `gzip` 组合待 `compress` 协作。
Roadmap: `CONTRACT.md` S0 已落地，`builder` 流式与基准已交付。
