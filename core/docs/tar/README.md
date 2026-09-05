# nextpas.core.tar

USTAR/PAX tar 容器：读、写、文件系统打包/解包，标准 `tar` 可直接读写。

## Units

| Unit | Role |
|------|------|
| `nextpas.core.tar` | Facade: re-exports 全量公共面（唯一公共入口） |
| `nextpas.core.tar.base` | 种类枚举、头记录、选项、常量 `C_TAR_BLOCK_SIZE=512`、名安全谓词、模式助手、容量与对齐单源（`TarCapacityAlign4K/Builder/IOBuf` 经 `bytes.ops.AlignUp4K` 位掩码零除法 `inline` 零拷贝，阈值固化于 `base` 常量，`base` 零依赖同模块文件守四件套纯度） |
| `nextpas.core.tar.capacity` | 容量与对齐专用内核（`TarCapacityAlign4K` 经 `bytes.ops.AlignUp4K` 位掩码零除法 `inline` 零拷贝单源、`TarBuilderCapacityFor` floor 4K+两零块 4K 对齐（修复 64K 对 512B 128倍过度预分配）、`TarIOBufCapacityFor` 4K~1M clamp 单源，阈值分叉固化于 `base` 常量（无常量薄别名，函数经 `capacity→base` 薄转发 `inline` 零拷贝单源，无双路径），门面零 re-export，仅 `builder/writer/fs` 受信 `implementation uses` 可见，`base` 已纯化） |
| `nextpas.core.tar.log` | 日志文案单源（`C_TAR_WARN_GLOBAL_PAX_*` / `C_TAR_WARN_WRITER/BUILDER_DESTROYED_WITHOUT_FINISH` 5 常量，Warn 文案不驻留 `base` 类型层，行为层 `reader/writer/builder` 经 `tar.log` 单源复用，门面零 re-export，仅行为层受信 `implementation uses` 可见，`base` 零依赖 `tar.log` 守纯度） |
| `nextpas.core.tar.intf` | `ITarBuilder` 接口契约（`base←intf←实现←门面` 单口 `AddEntryFromReader` 直达，L2→L1 `io.intf(IReader)`，零 QueryInterface 仪式） |
| `nextpas.core.tar.reader` | `TTarReader`：迭代内存镜像，pax/x/g + GNU L/K + base-256 全兼容 |
| `nextpas.core.tar.writer` | `TTarWriter`：以 `IWriter` 为目标的 ustar 写入，prefix 自动分割 + pax `x` 长名回退（>100 无 prefix 切分或 `linkpath>100` 时） + base-256 溢出 + `devmajor/devminor` 设备号（`C_TAR_LAYOUT.DevMajor/DevMinor` 单源），需显式 `Finish`（两零块，析构仅 `log.intf Warn` 不补写、永不抛异常，`try..finally` 必释资源，`AddEntryFromReader` per-entry 局域缓冲 `try..finally` 无滞留，经 `capacity.TarIOBufCapacityFor` 单源） |
| `nextpas.core.tar.fs` | 目录打包/解包便捷层（预估经 `capacity.TarBuilderCapacityFor` 4K 对齐单源） |
| `nextpas.core.tar.builder` | `ITarBuilder` 实现：链式薄门面，委托 `TTarWriter`，单口 `TarBuilder` 入口（显式 `Finish`（两零块）：未 `Finish` 析构永不抛异常仅 `log.intf` `ILogger.Warn` 可观测（`NullLogger` 零分配 inline，无 `StdErr` 直触，L2 平台抽象克制），`try..finally` 必释资源，避免 `IsExceptionUnwinding` 分叉掩盖原始异常；`ITarBuilder.AddEntryFromReader` 流式零拷贝 per-entry 局域缓冲 `try..finally` 无滞留，经 `capacity` 单源 inline 零拷贝，零 QueryInterface 分发） |
| `nextpas.core.compress.tar` | 已删除（空存根已移除，单源收敛完成；新增请直接 uses `nextpas.core.tar`） |

> 内部实现（不属于公共 API，类型级隔离·门面零 re-export，仅受信实现 `implementation uses` 可见，辅以 CONTRACT 机械门禁双重收敛）：`nextpas.core.tar.common` — 共享内核 `TarPadToBlock`/`Guard*`（`EntrySize/TotalSize/NameForRead`）+ 校验和单点 `TarComputeChecksum*`/`TarVerifyBlockChecksum`/`TarHeaderIsZeroOrValid` + 数值单点 `TarParseNumericField`/`TarFormatNumericField` + pax 单点 `TarAppendPaxRecord`（`archive.pax ArchivePaxAppendRecord` 单源 `Reserve+AppendBytes` 零拷贝最优路径，字符串形态经 `ArchivePaxFormatRecord` 单源 `CreateBytesBuilder+SpanToString` 单次 Move）/`TarParsePaxRecords`/`TarParsePaxKVRecords`（零拷贝 PByte 切片、复用 `bytes.ops` 单源，`archive.pax ArchivePaxParseRecords` 通用 pax-kv 严格校验供归档族复用，畸形抛 `EIOError`；薄守卫 inline，含循环体外联以遵 design-conventions 禁 inline、避 I-Cache 膨胀，`bytes.ops AlignUp/BytesSumAndCountHighBitExclude/IsZeroBytes` 单源，`TrySlice` 零拷贝视图生命周期绑 Reader），仅供 `reader/writer/fs` 实现内复用；`nextpas.core.tar.capacity` — 容量与对齐专用内核（`TarCapacityAlign4K` 经 `bytes.ops.AlignUp4K` 位掩码零除法 `inline` 零拷贝、`TarBuilderCapacityFor` floor 4K+两零块 4K 对齐、`TarIOBufCapacityFor` 4K~1M clamp 单源，阈值分叉保留域语义，门面零 re-export，仅 `builder/writer/fs` 受信 `implementation uses` 可见，`base` 已纯化零依赖同模块，无常量薄别名，函数经 `capacity→base` 薄转发 `inline` 零拷贝单源）；`nextpas.core.tar.log` — 日志文案单源（`C_TAR_WARN_GLOBAL_PAX_*` / `C_TAR_WARN_WRITER/BUILDER_DESTROYED_WITHOUT_FINISH` 5 常量，行为层 Warn 不侵入 `base` 类型层，`reader/writer/builder` 经 `tar.log` 单源复用，门面零 re-export，仅行为层受信 `implementation uses` 可见，`base` 零依赖 `tar.log` 守纯度）；`nextpas.core.archive.pax` 为通用 pax-kv 解析共享内核（类型级隔离·联邦复用，归档族 `tar.common → archive.pax` 零拷贝迭代 `atime/mtime/size` 等扩展键）。

## Supported Features

| Feature | Write | Read | Notes |
|---------|-------|------|-------|
| Regular files | Yes | Yes | `tekRegular`, `Size` 精确 |
| Directories | Yes | Yes | 名字补 `/`，`tekDirectory` |
| Symlink/Hardlink/Devices/FIFO | Yes (emit) | Yes (parse) | 读端全识别，`fs` 默认 `SkipSpecial=True` 跳过 |
| USTAR prefix splitting | Yes | Yes | >100 字符名自动 `prefix/name` 分割，无 prefix 切分时写端以 `pax x` 承载 |
| GNU base-256 numeric | Yes (overflow) | Yes | 超 octal 容量自动 `$80` + big-endian |
| GNU longname `L/K` | — | Yes | 读端 `FPendingLongName/Link` 覆盖 |
| PAX `x/g` `path/linkpath` | Yes (x 回退) | Yes | 写端>100 无切分或 `linkpath>100` 前置 `x` 扩展头（`TarAppendPaxRecord` builder 零拷贝 `Reserve+AppendBytes` 最优路径单源，经 `archive.pax ArchivePaxFormatRecord` 单源 `SpanToString` 单次 Move），读端 per-entry 优于 global，`g` 在 `AcquireGlobalPaxGuard` 作用域内持久至下一 `g` 覆盖、无 guard 时单次消费自动清理并 `ILogger.Warn`、恶意由 `IsSafeTarEntryName` 自动过滤置空并同步 `Warn`（与自动清理 `Warn` 对齐防静默篡改）、`ClearGlobalPax` 显式或 `AcquireGlobalPaxGuard` RAII 自动隔离；通用 `TarParsePaxKVRecords`/`ArchivePaxParseRecords` 零拷贝迭代 `atime/mtime/size` 等扩展键，长度前缀缺空格/非数字/越界/缺换行即抛 `EIOError` 禁回退截断名 |
| PAX 类型化键 `size/mtime/uid/gid/uname/gname` | —（ustar/base-256 已承载） | Yes（覆盖） | 与 path 同规则（x 优先/g 同持久语义），`mtime` 小数截断，越界即 `EIOError`；未知键保序透传 `TTarHeader.PaxRecords` |
| GNU sparse（old 0.0/0.1 + pax 1.0） | Yes（显式 pax 1.0） | Yes（重建） | 写端默认 dense，`AddSparseFile`/`AddEntryWithOptions(Sparse)`/`AddSparse` 显式写出 pax 1.0（`GNU.sparse.*` + `./GNUSparseFile.0/` 占位名 + 首块 map 文本，段按 512 补齐）；空数据/占位名超长/无收益回退 dense；读端 `S`（386 区 map + 扩展链）/ 1.0 重建，重建前 stored/realsize 双计 bomb，未分配先守卫；见 CONTRACT INV-8 |
| Block alignment | Yes | Yes | 512 对齐 + 两零块收尾 |
| Zero-copy slice/stream | — | Yes | `TrySlice` 单一规范 `TByteSpan` 零拷贝视图 + `EntryDataSlice` 薄转发(`PByte`) + `OpenEntryStream`（`FBuf` 时 `CreateSliceReaderWithHold` 零拷贝持有型、`Reader` 释放后仍可读；外部 `PByte` 时 `CreateSliceReader` 零拷贝直视、生命周期绑外部 PByte/Reader，零分配 inline，按需 `TrySlice+SpanClone` 自包含） |

## API

### Write

```pascal
uses nextpas.core.tar;

var W: TTarWriter; S: IStream;
S := CreateBytesStream;
W := TTarWriter.Create(S as IWriter);
W.AddFile('hello.txt', BytesOfString('hello'), $1A4, 1700000000);
W.AddDir('assets');
W.AddSparseFile('sparse.bin', Data); // 显式 pax 1.0 稀疏写出（默认 dense；回退规则见 CONTRACT INV-8）
W.AddEntry(Hdr, Data); // Hdr.Name/Kind/Mode/UID/GID/MTime/UName/GName/DevMajor/DevMinor
W.Finish; // 两零块，需显式调用，析构仅 Warn 不补写、永不抛异常
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
    RS := R.OpenEntryStream; // FBuf 时零拷贝持有型流（Reader 释放后仍可读）；外部 PByte 时零拷贝直视（生命周期绑外部 PByte/Reader，零分配 inline，按需 SpanClone 自包含）
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
          .AddSparse('sparse.bin', Data)
          .Finish;
 // 流式零拷贝（单口 ITarBuilder 直达，零 QueryInterface 仪式）：
 // TarBuilder.Add('a', Data).AddEntryFromReader(Hdr2, Reader).Finish
 // per-entry 局域缓冲 via TarIOBufCapacityFor (AlignUp4K), bytes.ops 单源 inline Move
```

## Lifecycle 零拷贝视图 vs 持有型流

- `TrySlice`/`EntryDataSlice`：零拷贝 `TByteSpan`/`PByte` 视图，`inline` 单一规范，生命周期绑 `Reader`（`Reader.Free` 后视图悬垂），批量 200×512B 仅 201 allocs；`FieldSlice` 偏移直接索引 `case` 跳表（替代 7 次线性分支）+ `CacheHeader` 批量 `FScanLens:=C_TAR_SCAN_LENS` 单记录拷贝（替代 7 次重复存储）。
- 已移除 `EntryData`：原 `SpanClone` 单次拷贝致 401 vs 201 allocs 翻倍，改按需 `SpanClone(TrySlice)` 单次 Move（`bytes.ops` 单源）。
- `OpenEntryStream`：`FBuf` 非空时 `CreateSliceReaderWithHold` 零拷贝持有型（`FHold` 防悬垂、`Reader` 释放后仍可读，`bytes.ops.CopyMemory` 单源 `inline`）；外部 `PByte` 时 `CreateSliceReader` 零拷贝直视（生命周期绑外部 PByte/Reader，零分配 inline，按需 `TrySlice+SpanClone` 自包含，`bytes.ops` 单源，防高频 allocs 次 GC）。

```
Reader ── TrySlice ──► 零拷贝视图（绑 Reader）
       └─ OpenEntryStream ──► FBuf: 零拷贝持有型流（自包含，Reader 释放后仍可读）| PByte: 零拷贝直视（绑外部 PByte/Reader，零分配 inline，按需 SpanClone 自包含）
```

详见 `CONTRACT.md §2 INV-7` 单一规范与生命周期。

## Safety Model

- `IsSafeTarEntryName` 拒绝空名、绝对路径、盘符、`\\`、`//` 空段、`./` 单点段、`..` 段；写端 `ValidateTarEntryName` 即 `EArgumentError`，读端/落盘前 `EParseError`，`TarExtractToDir` 对 `H.Name` 二次 `GuardTarNameForRead`。
- Bomb 守卫：`TTarReadOptions.MaxEntrySize`（默认 1 GiB）单条目、`MaxTotalSize` 跨条目总量（含 `pax x/g` 与 `GNU L/K` 扩展载荷计入总量防 DoS，`common.Guard*` 单源），`TrySlice`/`EntryDataSlice` 中途生效；`g` 恶意路堨经 `IsSafe` 过滤同步 `ILogger.Warn` 可观测（与单次自动清理 `Warn` 对齐）。
- 落盘前 `EnsureNoSymlinkInPath` 拒绝路径中符号链接段，避免劫持。

## Performance

设计以 `inline` 零拷贝与 `bytes.ops` 单源为纲，阈值收敛于 `base`，容量经 `capacity` 单源透出。

### 读路径 · 零拷贝视图

- `TrySlice` 单一规范 `TByteSpan` 零拷贝 `inline`，生命周期绑 `Reader`；`EntryDataSlice` 薄转发复用单源。
- `FieldSlice` 偏移 `case` 跳表替代 7 分支；`CacheHeader` 批量 `FScanLens[0..6]` 单记录拷贝，`ScanNulFieldTruncations` 单次 512B。
- `OpenEntryStream` 经 `io.slice TIOSliceReader` 单源：`FBuf` 时 `CreateSliceReaderWithHold` 持有型（`Reader` 释放后仍可读）；`PByte` 时 `CreateSliceReader` 直视，零分配 `inline`，按需 `TrySlice+SpanClone` 自包含，`bytes.ops.CopyMemory` 单源。
- `Next` 对 `H.Name` 自动 `GuardTarNameForRead`；设备 `DevMajor/DevMinor` 解析/回写完整。

### 写路径 · 单块直写

- `WriteBlock` 去 `inline` 避 512 栈 I-Cache 膨胀，out-of-line 单拷贝；`WritePaddedPayload` 单源 Bulk+Tail+Pad，`bytes.ops` 单源。
- `AddEntryFromReader` per-entry 局域缓冲 `try..finally` 无滞留，经 `capacity.TarIOBufCapacityFor` AlignUp4K 单源 `inline`。
- `builder` 经 `IBytesBuilder` 直写切片，`inline AppendBytes` 几何扩容，单次 `ToBytes`，与 writer 字节级一致。

### 容量与对齐 · 单源阈值

- 4K 对齐经 `bytes.ops.AlignUp4K` 位掩码零除法 `inline` 零拷贝，无除法，阈值固化于 `base`。
- `TarBuilderCapacityFor` floor 4K + 两零块 4K 对齐；`TarIOBufCapacityFor` 4K~1M clamp 单源。
- 函数经 `capacity→base` 薄转发 `inline`，无常量双路径；`base` 纯度零依赖同模块，仅 `builder/writer/fs` 受信 `implementation uses` 可见。

### 校验与 pax · 单遍融合

- `TarHeaderIsZeroOrValid` 单遍 512 融合校验和/零块；`TarAppendPaxRecord` builder 零拷贝 `Reserve+AppendBytes`，经 `archive.pax ArchivePaxFormatRecord` 单源 `SpanToString` 单次 Move。
- `ArchivePaxParseRecords` / `TarParsePaxKVRecords` 零拷贝 `PByte`，复用 `bytes.ops` 单源，畸形即抛 `EIOError`；薄守卫 `inline`，热循环外联。
- `pax g` 在 guard 作用域内持久至下一 `g` 覆盖，无 guard 单次消费自动清理并 `Warn`，恶意 `IsSafe` 过滤同步 `Warn`，`ClearGlobalPax` 显式或 RAII。

### 稳定性 · 资源释放

- `Finish` 显式两零块；未 `Finish` 析构永不抛异常，仅 `log.intf ILogger.Warn`（`NullLogger` 零分配 `inline`），`try..finally` 必释资源。
- 避免 `IsExceptionUnwinding` 分叉掩盖原始异常；无 `System.WriteLn/StdErr` 直触。

### 证据

- `reader.pas:TrySlice/EntryDataSlice/OpenEntryStream inline`；`base.pas:TarCapacityAlign4K/Builder/IOBuf inline via AlignUp4K`；`bytes.ops CopyMemory/SpanToString` 单源。

### 量化基线

- `core/benchmarks/nextpas.core.tar/bench_tar` 7 项 `TBenchSuite`，300ms/7 样。
- 数值单源于 `BASELINE.json`（`build/bench-tar.json` 人工审查固化），`make -C core/benchmarks/nextpas.core.tar/bench_tar run` 可复现。
- `TAR_BENCH_FULL=1` 追加 `2000×512B` 档；详见 `CONTRACT.md §6`。

### 回归门限（CONTRACT §6）

- `allocs` 硬预算 `baseline+2` / `bytes` 强一致（CI 硬红）；`ns/op ≤1.50×` / `MB/s ≥0.65×` 硬门，`check_regression.py` 非零退出。
- Go/Rust 对照 `compare_go`/`compare_rust` 同口径 `ns/op ≤1.50×` 且 `MB/s ≥0.70×` 硬门（CI 硬红，缺失即硬红）。
- `make -C core/benchmarks/nextpas.core.tar/bench_tar regression` 一键比对 `BASELINE.json`；`run-compare` 生成对照 JSON，`--with-compare` 比对判定。
- 确定性：`archive.fs` 确定性排序 + `deferred dir` 逆序 + `mtime=0` 同输入同字节，跨机复现。

Runnable example: `examples/nextpas.core.tar/tar_roundtrip`（writer / builder / pack / extract / reader 全链路，可 `make run`）。
Benchmark: 已落地 `bench_tar`（见上），与 `gzip` 组合待 `compress` 协作。
Roadmap: `CONTRACT.md` S0 已落地，`builder` 流式与基准已交付。
