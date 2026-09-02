# nextpas.core.tar

USTAR/PAX tar 容器：读、写、文件系统打包/解包，标准 `tar` 可直接读写。

## Units

| Unit | Role |
|------|------|
| `nextpas.core.tar` | Facade: re-exports 全量公共面（唯一公共入口） |
| `nextpas.core.tar.base` | 种类枚举、头记录、选项、常量 `C_TAR_BLOCK_SIZE=512`、名安全谓词、模式助手 |
| `nextpas.core.tar.intf` | `ITarBuilder` 接口契约（`base←intf←实现←门面` 单口 `AddEntryFromReader` 直达，L2→L1 `io.intf(IReader)`，零 QueryInterface 仪式） |
| `nextpas.core.tar.reader` | `TTarReader`：迭代内存镜像，pax/x/g + GNU L/K + base-256 全兼容 |
| `nextpas.core.tar.writer` | `TTarWriter`：以 `IWriter` 为目标的 ustar 写入，prefix 自动分割 + pax `x` 长名回退（>100 无 prefix 切分或 `linkpath>100` 时） + base-256 溢出 + `devmajor/devminor` 设备号（`C_TAR_LAYOUT.DevMajor/DevMinor` 单源），需显式 `Finish`（`Destroy` best-effort `Finish` 永不抛异常仅 `log.intf Warn` 抑制次生，`try..finally` 必释资源，`AddEntryFromReader` per-entry 局域缓冲 `try..finally` 无滞留） |
| `nextpas.core.tar.fs` | 目录打包/解包便捷层 |
| `nextpas.core.tar.builder` | `ITarBuilder` 实现：链式薄门面，委托 `TTarWriter`，单口 `TarBuilder` 入口（显式 `Finish`（两零块）：未 `Finish` 析构永不抛异常仅 `log.intf` `ILogger.Warn` 可观测（`NullLogger` 零分配 inline，无 `StdErr` 直触，L2 平台抽象克制），`try..finally` 必释资源，避免 `IsExceptionUnwinding` 分叉掩盖原始异常；`ITarBuilder.AddEntryFromReader` 流式零拷贝 per-entry 局域缓冲 `try..finally` 无滞留，`bytes.ops` 单源 inline `Move`，零 QueryInterface 分发） |
| `nextpas.core.compress.tar` | 已删除（空存根已移除，单源收敛完成；新增请直接 uses `nextpas.core.tar`） |

> 内部实现（不属于公共 API，禁止门面外直引）：`nextpas.core.tar.common` — 共享内核 `TarPadToBlock`/`Guard*`（`EntrySize/TotalSize/NameForRead`）+ 校验和单点 `TarComputeChecksum*`/`TarVerifyBlockChecksum`/`TarHeaderIsZeroOrValid` + 数值单点 `TarParseNumericField`/`TarFormatNumericField` + pax 单点 `TarAppendPaxRecord`（`archive.pax ArchivePaxAppendRecord` 单源 `Reserve+AppendBytes` 零拷贝最优路径，字符串形态经 `ArchivePaxFormatRecord` 单源 `CreateBytesBuilder+SpanToString` 单次 Move）/`TarParsePaxRecords`/`TarParsePaxKVRecords`（零拷贝 PByte 切片、复用 `bytes.ops` 单源，`archive.pax ArchivePaxParseRecords` 通用 pax-kv 严格校验供归档族复用，畸形抛 `EIOError`；薄守卫 inline，含循环体外联以遵 design-conventions 禁 inline、避 I-Cache 膨胀），仅供 `reader/writer/fs` 实现内复用；`nextpas.core.archive.pax` 为通用 pax-kv 解析共享内核（内部核例外，归档族 `tar.common → archive.pax` 联邦复用，零拷贝迭代 `atime/mtime/size` 等扩展键）。

## Supported Features

| Feature | Write | Read | Notes |
|---------|-------|------|-------|
| Regular files | Yes | Yes | `tekRegular`, `Size` 精确 |
| Directories | Yes | Yes | 名字补 `/`，`tekDirectory` |
| Symlink/Hardlink/Devices/FIFO | Yes (emit) | Yes (parse) | 读端全识别，`fs` 默认 `SkipSpecial=True` 跳过 |
| USTAR prefix splitting | Yes | Yes | >100 字符名自动 `prefix/name` 分割，无 prefix 切分时写端以 `pax x` 承载 |
| GNU base-256 numeric | Yes (overflow) | Yes | 超 octal 容量自动 `$80` + big-endian |
| GNU longname `L/K` | — | Yes | 读端 `FPendingLongName/Link` 覆盖 |
| PAX `x/g` `path/linkpath` | Yes (x 回退) | Yes | 写端>100 无切分或 `linkpath>100` 前置 `x` 扩展头（`TarAppendPaxRecord` builder 零拷贝 `Reserve+AppendBytes` 最优路径单源，经 `archive.pax ArchivePaxFormatRecord` 单源 `SpanToString` 单次 Move），读端 per-entry 优于 global，`g` 在 `AcquireGlobalPaxGuard` 作用域内持久至下一 `g` 覆盖、无 guard 时单次消费自动清理防跨条目/跨镜像污染、恶意由 `IsSafeTarEntryName` 自动 Guard 丢弃、`ClearGlobalPax` 显式或 `AcquireGlobalPaxGuard` RAII 自动隔离；通用 `TarParsePaxKVRecords`/`ArchivePaxParseRecords` 零拷贝迭代 `atime/mtime/size` 等扩展键，长度前缀缺空格/非数字/越界/缺换行即抛 `EIOError` 禁回退截断名 |
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
var R: TTarReader; H: TTarHeader; P: PByte; C: SizeUInt; RS: IReader; S: TByteSpan;
R := TTarReader.Create(Bytes); // 或 Create(PByte, Count) + WithOptions(bomb 上限)
while R.Next(H) do
begin
  WriteLn(H.Name, ' ', H.Size, ' ', Ord(H.Kind));
  if R.TrySlice(S) then // 单一规范零拷贝视图（inline，生命周期绑 Reader），批量 201 vs 401 allocs
    ; // 按需 SpanClone(S) 单次 Move（bytes.ops 单源），已移除 EntryData 避免峰值翻倍
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
  .Finish; // 内部 TTarWriter + CreateBytesBuilder 直写切片（inline 零拷贝），Finish 单次 ToBytes，bytes 级与 writer 一致；未 Finish 析构永不抛异常仅 ILogger.Warn 可观测（NullLogger 零分配 inline，无 StdErr 直触），try..finally 必释资源，避免 IsExceptionUnwinding 分叉掩盖原始异常

// 带选项：携带权限/mtime/uname
var Opts: TTarAddOptions;
Opts := DefaultTarAddOptions; Opts.Mode := $1A4; Opts.MTimeUnix := 1700000000;
TarBuilder.AddWithOptions('hello.txt', Data, Opts)
          .AddDirectoryWithOptions('assets', Opts)
          .AddEntry(Hdr, Data)
          .Finish;
 // 流式零拷贝（单口 ITarBuilder 直达，零 QueryInterface 仪式）：
 // TarBuilder.Add('a', Data).AddEntryFromReader(Hdr2, Reader).Finish
 // per-entry 局域缓冲 via TarIOBufCapacityFor (AlignUp4K), bytes.ops 单源 inline Move
```

## Lifecycle 零拷贝视图 vs 持有型流

- `TrySlice`/`EntryDataSlice`：零拷贝 `TByteSpan`/`PByte` 视图，`inline` 单一规范，生命周期绑 `Reader`（`Reader.Free` 后视图悬垂），批量 200×512B 仅 201 allocs。
- 已移除 `EntryData`：原 `SpanClone` 单次拷贝致 401 vs 201 allocs 翻倍，改按需 `SpanClone(TrySlice)` 单次 Move（`bytes.ops` 单源）。
- `OpenEntryStream`：持有型 `IReader`（`nextpas.core.io.slice TIOSliceReader/CreateSliceReaderWithHold` 单源，tar/zip 统一），`FBuf` 时持有镜像引用，外部 `PByte` 时 `SpanClone` 固化拷贝自包含，`Reader` 释放后仍可读（`bytes.ops.CopyMemory` 单源）。

```
Reader ── TrySlice ──► 零拷贝视图（绑 Reader）
       └─ OpenEntryStream ──► 持有型流（自包含，Reader 释放后仍可读）
```

详见 `CONTRACT.md 附录 B` 单一规范与生命周期图解。

## Safety Model

- `IsSafeTarEntryName` 拒绝空名、绝对路径、盘符、`\\`、`//` 空段、`./` 单点段、`..` 段；写端 `ValidateTarEntryName` 即 `EArgumentError`，读端/落盘前 `EParseError`，`TarExtractToDir` 对 `H.Name` 二次 `GuardTarNameForRead`。
- Bomb 守卫：`TTarReadOptions.MaxEntrySize`（默认 1 GiB）单条目、`MaxTotalSize` 跨条目总量，`common.Guard*` 单点 fail-closed；`TrySlice`/`EntryDataSlice` 中途生效。
- 落盘前 `EnsureNoSymlinkInPath` 拒绝路径中符号链接段，避免劫持。

## Performance

- **inline/零拷贝/单源**：`reader` 零拷贝切片（`TrySlice` 单一规范 `TByteSpan` 视图 + `EntryDataSlice` 薄转发，`FieldSlice` 表驱动七字段（layout 表+ScanLens 数组 loop，无 if-else 链）+不透明缓存单次 `ScanNulFieldTruncations` 单源（`bytes.ops`）单遍 512B、接口不暴露七字段扁平化，`OpenEntryStream` 经 `io.slice TIOSliceReader` 持有型单源（`CreateSliceReaderWithHold`，tar/zip 统一，`bytes.ops.CopyMemory` inline 零拷贝，`FHold` 防悬垂），`Next` 对 `H.Name` 自动 `GuardTarNameForRead`，`pax g` 在 guard 作用域内持久至下一 `g` 覆盖、无 guard 单次消费自动清理防污染、`ClearGlobalPax` 显式可选；设备 `DevMajor/DevMinor` 解析/回写完整），`writer` 单块 `Move` 直写（`WriteBlock` 去 inline 避 512 栈 I-Cache 复制膨胀、out-of-line 单拷贝，`WritePaddedPayload` 单源 Bulk+Tail+Pad 抽取 `bytes.ops CopyMemory` inline 零拷贝，`AddEntryFromReader` per-entry 局域缓冲 `try..finally` 无滞留 via `TarIOBufCapacityFor` (AlignUp4K 单源 inline 零拷贝)，`builder` 经 `IBytesBuilder` 直写切片、inline `AppendBytes` 几何扩容、单次 `ToBytes`，`Destroy` 永不抛异常仅 `log.intf` `ILogger.Warn` 抑制次生（`NullLogger` 零分配 inline，无 `System.WriteLn/StdErr` 直触），`try..finally` 必释资源，避免 `IsExceptionUnwinding` 分叉掩盖原始异常），`common.TarHeaderIsZeroOrValid` 单遍 512 融合校验和/零块与 `TarAppendPaxRecord` builder 零拷贝最优路径（经 `archive.pax ArchivePaxFormatRecord` 单源 `SpanToString` 单次 Move）及 `ArchivePaxParseRecords` 通用 pax-kv 严格校验零拷贝 `PByte` 复用 `bytes.ops` 单源（畸形 `pax: ...` 即抛 `EIOError` 禁回退，`TarParsePaxKVRecords` 供归档族复用；薄守卫 inline，热循环外联）。
- **量化基线**：`core/benchmarks/nextpas.core.tar/bench_tar` 7 项 `TBenchSuite` 300ms/7样，数值单源于 `BASELINE.json`（`build/bench-tar.json` 人工审查固化），`make -C core/benchmarks/nextpas.core.tar/bench_tar run` 可复现，`TAR_BENCH_FULL=1` 追加 `2000×512B` 档；详见 `CONTRACT.md §6`。
- **回归门限（CONTRACT §6）**：`allocs` 硬预算 `baseline+2`/`bytes` 强一致（CI 红），`ns/op` `1.5×` WARN 与 `MB/s` `0.65×` WARN；Go/Rust 对照同口径 `compare_go`/`compare_rust` 守卫 `Pascal ns/op ≤1.5×` 且 `MB/s ≥0.70×`（`GOMAXPROCS=1` 降噪，连续两机复现升硬门）；`make -C core/benchmarks/nextpas.core.tar/bench_tar regression` 经 `check_regression.py` 比对 `BASELINE.json` 一键门。

Runnable example: `examples/nextpas.core.tar/tar_roundtrip`（writer / builder / pack / extract / reader 全链路，可 `make run`）。
Benchmark: 已落地 `bench_tar`（见上），与 `gzip` 组合待 `compress` 协作。
Roadmap: `CONTRACT.md` S0 已落地，`builder` 流式与基准已交付。
