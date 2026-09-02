# nextpas.core.tar CONTRACT

本文档描述 `nextpas.core.tar` 的公共契约。改动公共 API、错误语义或生命周期时必须同步更新本文件与 `test_tar_*` 门。

## 1. 公共 API 面

### 1.1 类型

| 类型 | 说明 |
|------|------|
| `TTarEntryKind` | 7 种类：`tekRegular/HardLink/Symlink/CharDevice/BlockDevice/Directory/Fifo` |
| `TTarHeader` | `Name/LinkName/Kind/Mode/UID/GID/Size/MTimeUnix/UName/GName/DevMajor/DevMinor`（`DevMajor/DevMinor` 为 ustar `devmajor/devminor@329/337` 8 字节八进制/base-256，设备类型 `tekCharDevice/tekBlockDevice` 生效，其余可为 0） |
| `TTarAddOptions` | `Mode/UID/GID/MTimeUnix/UName/GName`（`DefaultTarAddOptions` 取 0/空） |
| `TTarReadOptions` | `MaxEntrySize` 单条目上限（0 取 `C_TAR_DEFAULT_MAX_ENTRY=1GiB`）、`MaxTotalSize` 跨条目总量（0=不限） |
| `TTarExtractOptions` | `RestoreMode/SkipSpecial/MaxEntrySize/MaxTotalSize` |
| `TTarReader` | `Next(out H):Boolean` / `TrySlice(out TByteSpan):Boolean` 单一规范零拷贝 `inline` 视图 + `EntryDataSlice(out PByte,Count):Boolean` 薄转发（复用 TrySlice 单源，批量 200×512B 零拷贝 201 allocs，`EntryData` 已移除避免 401 vs 201 翻倍峰值，`SpanClone` 按需单次 Move 经 `bytes.ops` 单源） / `OpenEntryStream:IReader` / `EntryDataOfs:SizeUInt` / `Create(PByte,Count)` 双形态 + `WithOptions` / `ClearGlobalPax` 显式清理全局 g + `AcquireGlobalPaxGuard:IInterface` RAII 自动隔离（无 guard 时 g 单次消费自动清理防污染，guard 作用域内持久至下一 g 覆盖） / 头 7 字段 `NUL` 截断经 `bytes.ops ScanNulFieldTruncations` 单源单次 512B 声明式扫描（实现侧不透明缓存，接口不暴露七字段扁平化细节），复用 `Span` 单源 |
| `TTarWriter` | `AddEntry(Hdr,Data)` / `AddFile/AddDir/AddEntryWithOptions/AddEntryFromReader` / `Finish`（两零块，需显式 Finish，`AddEntryFromReader` per-entry 局域缓冲 try..finally 无滞留峰值，析构 best-effort 补两零块永不抛异常仅 `log.intf Warn` 抑制次生，`IsFinished` 供 builder 可观测校验） |

### 1.2 常量与谓词

`C_TAR_BLOCK_SIZE=512`，`C_TAR_MAX_NAME_BYTES=512`，`C_TAR_MAX_LINK_BYTES=4096`，`C_TAR_DEFAULT_MAX_ENTRY=1GiB`。`IsSafeTarEntryName/ValidateTarEntryName`（见 §2 INV-5）。

### 1.3 便捷层

`TarPackDirInto/TarPackDir/TarExtractToDirWithOptions/TarExtractToDir`（`nextpas.core.tar.fs`，目录递归确定性排序，deferred dir 逆序定稿）。

- **PackWalks 单源**：`TarPackDir`/`TarPackDirInto` 共用 `PackWalks` inline 单源，消除 30+ 行重复粘贴；零拷贝分块搬运复用 `ArchiveCollectWalk` 已 Stat 的 `FSize` 零二次 Stat，`bytes.ops` 单源，`try..finally` 不丢句柄；`TarPackDir` 按预估总量经 `TarBuilderCapacityFor` 4K 对齐预扩容（`bytes.ops.AlignUp4K` 单源，`bytes.builder` 几何扩容 inline 零拷贝），大目录 200×512B 仅1次扩容，小目录 64K 覆盖，零额外拷贝（代码层仅保留克制调用，性能故事沉于此）。
- **文件系统单缝**：`tar.fs` 仅 `uses nextpas.core.archive.fs` 单缝联邦，Walk/排序/防劫持/零拷贝落盘均经 `archive.fs` 单源，无自有递归样板；`IsSafeTarLinkTarget`/`ArchiveValidateHardlinkSource` 复用 `bytes.pathvalid`/`archive.fs` 单源 `inline` 薄转发（`ValidateHardlinkSource` 已抽至 `archive.fs` 归档族统一谓词，tar/zip 复用，`tar.fs` 薄委托 `ArchiveValidateHardlinkSource` + `ArchiveHardLinkVerified` fd级闭环，零额外分配）。
- **硬链接 TOCTOU 闭环**：`tekHardLink` 经 `ArchiveValidateHardlinkSource` fail-fast（`archive.fs` 统一谓词 `inline` 复用 `ArchiveExists/IsSymlink/IsRegularFile` 零分配）+ `ArchiveHardLinkVerified` → `FsHardLinkVerified` → `platform_file_link_verified` 单源原子落盘：`O_NOFOLLOW|O_CLOEXEC` 打开源 fd 校验 `ftRegular` 后经 `/proc/self/fd`（Linux）或 `/dev/fd`（Darwin/BSD）fd 链路 `link`，消除 `Validate→HandleSpecial→HardLink` 窗口并发替换源为 symlink 的绕过，归档族单源 via `archive.fs`。

### 1.4 链式构造器

`ITarBuilder`（`nextpas.core.tar.intf` 定义，`nextpas.core.tar.builder` 实现）：`Add/AddWithOptions/AddDirectory/AddDirectoryWithOptions/AddEntry/AddEntryFromReader/Finish` 链式单口直达。

- 遵循 `base←intf←实现←门面`，L2→L1 单向 `nextpas.core.io.intf(IReader)`，零 `QueryInterface` 仪式，一链 `TarBuilder.Add(...).AddEntryFromReader(...).Finish` 直达。
- 薄门面委托 `TTarWriter`，经 `archive.fs` 单缝联邦复用 `bytes.ops`/`bytes.builder` 单源：`CreateArchiveBuilder` 直写切片，`IBytesBuilder` 几何扩容 `inline AppendBytes` 零拷贝；`TarBuilderCapacityFor` 4K 对齐预扩容，`Finish` 经 `ToBytes` 单次 Move，无二次大块 `Move`。
- `AddDirectory*` 复用 `TTarWriter.AddDir*` 单源，无重复 `TTarHeader` 组装。
- 流式零拷贝 `AddEntryFromReader`：复用 `bytes.ops` 单源 `inline` 零拷贝，per-entry 局域缓冲 `try..finally` 无滞留峰值，委托 `TTarWriter` 单源。
- 需显式 `Finish`（两零块）：未 `Finish` 析构永不抛异常，经 `log.intf` `Warn` 可观测（`NullLogger` 默认零分配 inline，无 `System.WriteLn/System.StdErr` 直触，L2 平台抽象克制），`try..finally` 必释 `FWriter`，避免 `IsExceptionUnwinding` 分叉掩盖原始异常；`TTarWriter.Destroy` 同策略：`try..finally` 必释资源，best-effort `Finish` 失败仅 `Warn` 抑制次生。门面 `TarBuilder`/`TarBuilderWithCapacity`/`TarBuilderCapacityFor` 单口 `inline` 工厂，零额外序列化，bytes 级一致。

## 2. 不变量

- **[INV-1]** USTAR 写入：`magic "ustar\0"` @257 + `version "00"` @263 固定，>100 字符名自动 `prefix/name` 分割（最大 `/` 使后缀 ≤100，否则以 `pax` 扩展头 `typeflag 'x'` 承载 `path/linkpath` 记录，长度前缀十进制自洽，读端 `x/g` 与 `GNU L/K` 单点覆盖，消除读写不对称），`linkname>100` 同走 `pax linkpath`，目录补 `/`。
- **[INV-2]** 数值字段八进制为主，超 `octal capacity` 自动 `base-256`（首字节 `$80` + big-endian），读端双路径兼容。
- **[INV-3]** 读写对称：读端支持 `GNU L/K` 长名、`pax x/g` 的 `path/linkpath` 覆盖（per-entry 优于 global，`g` 全局在 `AcquireGlobalPaxGuard` 作用域内持久至下一 `g` 覆盖，无 guard 时单次消费自动清理防污染，`Next` 对 `H.Name` 自动 `GuardTarNameForRead` 拒绝路径穿越，`ClearGlobalPax` 显式或 `AcquireGlobalPaxGuard:IInterface` RAII 自动隔离），pax 记录含长度前缀 strict 校验（`archive.pax ArchivePaxParseRecords` 零拷贝 PByte 切片，长度缺空格/非数字/越界/缺换行即抛 `EIOError`，禁静默 `Exit(False)` 回退截断名，fail-closed）；写端>100 且无 `prefix` 切分或 `linkpath>100` 时自动前置 `pax` `x` 扩展头（`path/linkpath` 单条记录，`common.TarAppendPaxRecord` builder 零拷贝最优路径单源 `Reserve+AppendBytes` 直写，经 `archive.pax ArchivePaxFormatRecord/ArchivePaxAppendRecord` 单源直达，`bytes.ops` 单源视图），与读端 `TarParsePaxRecords`/`TarParsePaxKVRecords` 单点互通编解码同源；通用 `TarParsePaxKVRecords`/`ArchivePaxParseRecords` 供归档族复用 `atime/mtime/ctime/size/uid/gid` 等 pax 扩展键零拷贝迭代。
- **[INV-4]** 校验和双算（unsigned/signed）任一匹配即过，否则 `EIOError: header checksum mismatch`。
- **[INV-5]** 名安全：`IsSafeTarEntryName` 拒绝空名/绝对路径/盘符/反斜杠/`//` 空段/`./` 单点段/`..` 段，尾随 `/` 终段空合法；写端 `Validate` 即 `EArgumentError`，读端/落盘前 `EParseError`，`..` 经 `TarExtractToDir` 二次拒绝。
- **[INV-6]** Bomb 守卫：`MaxEntrySize` 单条目与 `MaxTotalSize` 跨条目总量在 `common.Guard*` 单点，`Next` 仅对正则载荷累计（`GNU L/K` 与 `pax x/g` 扩展元数据不计入 `FCumTotal`，避免含大量长名归档误触总量），`TrySlice`/`OpenEntryStream` 中途同受，超限 `EIOError`。
- **[INV-7]** 零块结束：双零块收尾，单零块后非零即 `truncated stream`；`FEntryDataOfs/Size` 视图单一规范；`TrySlice` 为单一规范零拷贝 `TByteSpan` 视图（`inline` 薄转发，生命周期绑 `Reader`），`EntryDataSlice` 为 `PByte/Count` 薄转发（复用 `TrySlice` 单源，零拷贝，批量 200×512B 仅 201 allocs）；`OpenEntryStream` 为持有型 `IReader`（`Reader` 拥有 `TBytes` 时流持有镜像引用，外部 `PByte` 时流固化拷贝自包含）；设备条目 `DevMajor/DevMinor` 由 `C_TAR_LAYOUT.DevMajor/DevMinor` 单源解析/回写，往返完整；容量预扩容 `TarBuilderCapacityFor` 经 `bytes.ops.AlignUp4K` 4K 对齐单源（div/mul 无掩码截断，32/64 位 SizeUInt 安全）。
- **[INV-8]** 确定性：未显式 mtime 取 `0`，mode 默认 `0644/0755`，同输入同字节（除 pax 长名外）。

## 3. 错误模型

| 场景 | 异常 |
|------|------|
| 结构损坏（截断、八进制非法、校验和不符、不支持 typeflag、负尺寸、长名过长、孤儿块、pax 长度前缀非法/越界/缺换行） | `EIOError('tar: ...'/'pax: ...')` |
| 名不安全（写端） | `EArgumentError('tar entry name ...')` |
| 名不安全（读端/落盘） | `EParseError('tar: refusing unsafe entry name: ...')` |
| 落盘路径含符号链接段 | `EParseError('tar extract: symlink in path: ...')` |
| 目标 writer 为 nil / 已 Finish 后再写入 | `EArgumentError` / `EInvalidOperationError('tar: writer already finished')` |
| `ITarBuilder` 未 `Finish` 即析构 | 经 `log.intf` `ILogger.Warn('tar: builder destroyed without Finish (missing two zero blocks, data truncated)')` 可观测（`NullLogger` 默认零分配 inline，无 `System.WriteLn/System.StdErr` 直触，L2 平台抽象克制），析构永不抛异常以防 `IsExceptionUnwinding` 分叉掩盖原始异常，`try..finally` 必释资源 |
| 单条目/总量超限 | `EIOError('tar: entry size exceeds limit for "%s" (%d > %d)' / 'total ... exceeds limit (%d + %d > %d)')` — 总量分支携带 `ACum/ANext/AMaxTotal` 上下文便于定位 |
| Short write | `EIOError('tar: short write')` |

## 4. 源契约

生产单元（`src/nextpas.core.tar*.pas`）不得 `uses` 非 `nextpas.*`，经 `test_tar_contract` 机械执行。门面仅 `re-export` + `inline` 委托，无控制流。

- 四件套 `base←intf←实现←门面`；`nextpas.core.tar.intf` 单口 `ITarBuilder.AddEntryFromReader(IReader)` 直达，L2→L1 单向、零 `QueryInterface` 仪式，复用 `bytes.ops` 单源 `inline` 零拷贝，per-entry 局域缓冲 `try..finally` 无滞留，经 `archive.fs` 单缝联邦。
- `nextpas.core.tar.common` 为内部共享内核，仅供 `reader/writer/fs` 复用，禁门面外 `uses`：`TarPadToBlock`/`Guard*`、校验和单点、数值单点、pax 单点（`ArchivePaxAppendRecord`/`ArchivePaxFormatRecord` 单源 `Reserve+AppendBytes` 零拷贝，`ArchivePaxParseRecords` 严格校验零拷贝 PByte 复用 `bytes.ops`）；薄守卫 `inline`，含循环体外联以遵 `design-conventions` 避免 I-Cache 膨胀。
- `nextpas.core.archive.pax` 为通用 pax-kv 内部核例外，归档族经 `tar.common → archive.pax` 联邦复用。绕过门面直引视为违契，`test_tar_contract` 覆盖。

## 5. 测试入口

```bash
make focused FOCUS=core/tests/nextpas.core.tar/test_tar_reader
make focused FOCUS=core/tests/nextpas.core.tar/test_tar_writer
make focused FOCUS=core/tests/nextpas.core.tar/test_tar_fs
make focused FOCUS=core/tests/nextpas.core.tar/test_tar_contract
make focused FOCUS=core/tests/nextpas.core.compress/test_compress_tar  # 回归：单源收敛后仍绿（空存根已删除）
make -C core/benchmarks/nextpas.core.tar/bench_tar run              # 基准：产出 build/bench-tar.json（阈值见 §6，数值单源 BASELINE.json）
make -C core/benchmarks/nextpas.core.tar/bench_tar regression       # 回归门：allocs/bytes 硬门 + ns/MB/s 阈值（阈值见 §6）
```

## 6. 性能目标与回归门限

> 数值单源于 `core/benchmarks/nextpas.core.tar/bench_tar/BASELINE.json`（`build/bench-tar.json` 的人工审查固化，`make baseline` 刷新）。CONTRACT 仅定义公式与门限，不复刻绝对数值。

- **口径**：`core/benchmarks/nextpas.core.tar/bench_tar` `TBenchSuite` 承载，`make -C core/benchmarks/nextpas.core.tar/bench_tar run` 可复现；数值见 `BASELINE.json`。
- **阈值**：硬门 `allocs ≤ baseline+2` 且 `bytes/op` 一致且 `status=ok`（CI 红）；软门 `ns/op ≤1.5× baseline`、`MB/s ≥0.65× baseline`（WARN，公式见附录 A）。
- **回归**：`make -C core/benchmarks/nextpas.core.tar/bench_tar regression` 比对 `BASELINE.json` 判定；`make baseline` 需人工审查后提交。

## 附录 A · 阈值公式

> 数值单源于 `BASELINE.json`，本附录仅定义判定公式，不复刻绝对数值。

- **硬门**：`allocs ≤ baseline+2` 且 `bytes/op` 一致且 `status=ok`（超限 CI 红）。
- **软门**：`ns/op >1.5× baseline` WARN；`MB/s <0.65× baseline` WARN。
- **判定**：`make -C core/benchmarks/nextpas.core.tar/bench_tar regression` 比对 `BASELINE.json` 与 `build/bench-tar.json`。

## 附录 B · 零拷贝与持有型生命周期

> 单一规范：`TrySlice` 为零拷贝 `TByteSpan` 视图唯一入口（inline 薄转发，生命周期绑 `TTarReader`）；`EntryDataSlice` 为 `PByte/Count` 薄转发复用 `TrySlice` 单源；已移除 `EntryData` 单次 `SpanClone` 拷贝（曾 200×512B 401 vs 201 allocs 翻倍），批量场景零拷贝 `TrySlice` + 按需 `SpanClone` 单次 Move（`bytes.ops` 单源）。

```
Reader.Create(Bytes|PByte) ── FBuf/FData 持有镜像
  │
  ├─ TrySlice(out Span) ──► TByteSpan{Data=PByte, Len} 零拷贝视图，inline，Reader 释放后失效
  ├─ EntryDataSlice(out PByte, Count) ──► 同上薄转发
  └─ OpenEntryStream ──► IReader 持有型（nextpas.core.io.slice TIOSliceReader/CreateSliceReaderWithHold 单源，tar/zip 统一）
        ├─ FBuf 非空：CreateSliceReaderWithHold(FBuf, Ofs, Size) 持有镜像引用，Reader 释放后仍可读
        └─ 外部 PByte：SpanClone 固化拷贝自包含（FHold 独立），Reader 释放后仍可读
```

- 视图失效：`Reader.Free` 后 `Span.Data` 悬垂，禁止再访；流持有型则安全（`FHold` 自包含）。
- 单源：`SpanClone/CopyMemory/CopyStringToBuffer` 均经 `bytes.ops` 单源 `Move`，`TIOSliceReader.Read`（io.slice）经 `CopyMemory` 单源零拷贝，`FieldSlice` 七字段表驱动（layout 表+ScanLens 数组 loop，无 if-else 链，单次 512B ScanNulFieldTruncations 缓存）。
