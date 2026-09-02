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
| `TTarReader` | `Next(out H):Boolean` / `TrySlice(out TByteSpan):Boolean` 单一规范零拷贝 `inline` 视图 + `EntryDataSlice(out PByte,Count):Boolean` 薄转发（复用 TrySlice 单源，批量 200×512B 零拷贝 201 allocs，`EntryData` 已移除避免 401 vs 201 翻倍峰值，`SpanClone` 按需单次 Move 经 `bytes.ops` 单源） / `OpenEntryStream:IReader` / `EntryDataOfs:SizeUInt` / `Create(PByte,Count)` 双形态 + `WithOptions` / `ClearGlobalPax` 显式清理全局 g + `AcquireGlobalPaxGuard:IInterface` RAII 自动隔离（弱引用不延长 `Reader/FBuf` 大镜像，`Reader.Destroy` 先 `InvalidateGuards` 避免峰值滞留，稳定性不丢；无 guard 时 g 单次消费自动清理防跨条目/跨镜像污染，guard 作用域内持久至下一 g 覆盖） / 头 7 字段 `NUL` 截断经 `bytes.ops ScanNulFieldTruncations` 单源单次 512B 声明式扫描（实现侧不透明缓存，接口不暴露 `TTarScanCache` 七字段扁平化细节），复用 `Span` 单源 |
| `TTarWriter` | `AddEntry(Hdr,Data)` / `AddFile/AddDir/AddEntryWithOptions/AddEntryFromReader` / `Finish`（两零块，需显式 Finish，`FIOBuf` 于 Finish 即释避免滞留峰值，析构兜底补两零块 best-effort 极简 fail-closed，`IsFinished` 供 builder fail-closed 校验） |

### 1.2 常量与谓词

`C_TAR_BLOCK_SIZE=512`，`C_TAR_MAX_NAME_BYTES=512`，`C_TAR_DEFAULT_MAX_ENTRY=1GiB`。`IsSafeTarEntryName/ValidateTarEntryName`（见 §2 INV-5）。

### 1.3 便捷层

`TarPackDirInto/TarPackDir/TarExtractToDirWithOptions/TarExtractToDir`（`nextpas.core.tar.fs`，目录递归确定性排序，deferred dir 逆序定稿）。

### 1.4 链式构造器

`ITarBuilder`（`nextpas.core.tar.intf` 定义，`nextpas.core.tar.builder` 实现）：`Add/AddWithOptions/AddDirectory/AddDirectoryWithOptions/AddEntry/AddEntryFromReader/Finish` 链式，遵循 `base←intf←实现←门面`；薄门面委托 `TTarWriter` + `CreateArchiveBuilder`（`CreateBytesBuilder` 直写切片 + `CreateArchiveBuilderSink` 联邦单源，经 `archive.fs` 单缝，`IBytesBuilder` 几何扩容、inline `AppendBytes` 零拷贝，复用 `bytes.ops`/`bytes.builder` 单源）+ `TarBuilderCapacityFor` 预扩容按预估总量 4K 对齐避免大归档多次几何扩容（`TarBuilderWithCapacity` 显式预估总量），`Finish` 经 `ToBytes` 单次分配+Move 交付，消除 `CreateBytesStream` + `ArchiveSnapshotStream` 二次 `SetLength+Seek+Read` 大块 `Move`；`AddDirectory/AddDirectoryWithOptions` 复用 `TTarWriter.AddDir/AddDirWithOptions` 单源，`AddDirWithOptions` 内部以 `DefaultTarAddOptions` 判零、`TarDirectoryMode` 换算默认权限，薄门面无重复 `TTarHeader` 手写；`AddEntryFromReader` 流式零拷贝（64K pooled 复用分块 Move 单源 `bytes.ops` via `FIOBuf` 于 Finish 即释——首分配 ≤64K 后 200 文件串行复用、amortized 1 alloc、零 `TBytes` 全量拷贝，委托 `TTarWriter.AddEntryFromReader` 单源，Finish 后至 Free 前无 64K 滞留峰值，避免连续复用多占内存，无 2×阈值缩容/4K 底 thrash，消除 `TarPackDirInto` 重复分配峰值）；门面导出 `TarBuilder`/`TarBuilderWithCapacity`/`TarBuilderCapacityFor` inline 工厂（`NewTarBuilder` 已移除），需显式 `Finish`（未 `Finish` 析构 fail-closed：非 unwind 期抛 `EInvalidOperationError('tar: builder destroyed without Finish (missing two zero blocks, data truncated)')` 硬失败防缺两零块截断静默丢数据，unwind 期 `IsExceptionUnwinding` 抑制次生以保原始异常上下文并经 `log.intf` `ILogger.Warn` 可观测（`NullLogger` 默认零分配 inline 薄转发，无 `System.WriteLn/System.StdErr` 直触，L2 平台抽象克制），`try..finally` 必释 `FWriter`；`TTarWriter.Destroy` 同策略：`IsExceptionUnwinding` 捕获于 `Finish` 前、unwind 期抑制 `EIOError/short-write` 次生（无 StdErr 覆盖），非 unwind 期透传，`FIOBuf` 于 Finish 即释 + 析构 `finally` 双保险、无 linger 峰值，`try..finally` 必释资源），零额外序列化逻辑，bytes 级与 `TTarWriter` 一致。

## 2. 不变量

- **[INV-1]** USTAR 写入：`magic "ustar\0"` @257 + `version "00"` @263 固定，>100 字符名自动 `prefix/name` 分割（最大 `/` 使后缀 ≤100，否则以 `pax` 扩展头 `typeflag 'x'` 承载 `path/linkpath` 记录，长度前缀十进制自洽，读端 `x/g` 与 `GNU L/K` 单点覆盖，消除读写不对称），`linkname>100` 同走 `pax linkpath`，目录补 `/`。
- **[INV-2]** 数值字段八进制为主，超 `octal capacity` 自动 `base-256`（首字节 `$80` + big-endian），读端双路径兼容。
- **[INV-3]** 读写对称：读端支持 `GNU L/K` 长名、`pax x/g` 的 `path/linkpath` 覆盖（per-entry 优于 global，`g` 全局在 `AcquireGlobalPaxGuard` 作用域内持久至下一 `g` 覆盖，无 guard 时单次消费自动清理防跨条目/跨镜像污染，`Next` 对 `H.Name` 自动 `GuardTarNameForRead` 拒绝路径穿越，`ClearGlobalPax` 显式 fail-closed 或 `AcquireGlobalPaxGuard:IInterface` RAII 自动隔离），pax 记录含长度前缀 strict 校验（`archive.pax ArchivePaxParseRecords` 零拷贝 PByte 切片，长度缺空格/非数字/越界/缺换行即抛 `EIOError`，禁静默 `Exit(False)` 回退截断名，fail-closed）；写端>100 且无 `prefix` 切分或 `linkpath>100` 时自动前置 `pax` `x` 扩展头（`path/linkpath` 单条记录，`common.TarAppendPaxRecord` builder 零拷贝最优路径单源 `Reserve+AppendBytes` 直写，`TarFormatPaxRecord` 为 `CreateBytesBuilder+TarAppendPaxRecord+SpanToString` 单次 Move 薄包装单源，`bytes.ops` 单源视图），与读端 `TarParsePaxRecords`/`TarParsePaxKVRecords` 单点互通编解码同源；通用 `TarParsePaxKVRecords`/`ArchivePaxParseRecords` 供归档族复用 `atime/mtime/ctime/size/uid/gid` 等 pax 扩展键零拷贝迭代。
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
| `ITarBuilder` 未 `Finish` 即析构 | `EInvalidOperationError('tar: builder destroyed without Finish (missing two zero blocks, data truncated)')` — 非 unwind 期硬失败（fail-closed 防缺两零块截断静默丢数据），unwind 期 `IsExceptionUnwinding` 抑制次生以保原始异常上下文并经 `log.intf` `ILogger.Warn` 可观测（`NullLogger` 默认，无 `System.WriteLn/System.StdErr` 直触），`try..finally` 必释资源 |
| 单条目/总量超限 | `EIOError('tar: entry size exceeds limit for "%s" (%d > %d)' / 'total ... exceeds limit (%d + %d > %d)')` — 总量分支携带 `ACum/ANext/AMaxTotal` 上下文便于定位 |
| Short write | `EIOError('tar: short write')` |

## 4. 源契约

生产单元（`src/nextpas.core.tar*.pas`）不得 uses 任何非 `nextpas.*` 单元，经 `test_tar_contract` 门机械执行。门面仅 re-export + inline 委托，无控制流。四件套依赖方向 `base←intf←实现←门面` 单建 `nextpas.core.tar.intf` 显式备案例外：`nextpas.core.tar.intf` 额外依赖 L1 `nextpas.core.io.intf(IReader)`（10:13 `uses nextpas.core.io.intf, nextpas.core.tar.base`）偏离 `base←intf` 纯数据依赖，仅为 `ITarBuilder.AddEntryFromReader(const AHdr: TTarHeader; const AReader: IReader)` 流式零拷贝必需——L2→L1 单向合规、复用 `bytes.ops` 单源 `CopyMemory/Move` inline 零拷贝、64K pooled `FIOBuf` 于 `Finish` 即释 + `try..finally` 必释资源不丢、L2 单缝联邦经 `archive.fs`（`CreateArchiveBuilder`/`IArchiveBuilder` 单源），已备案为合规例外（`test_tar_contract` 机械放行 `nextpas.*` 前提下本条例外由 CONTRACT 显式锁定，禁止扩散至其他 intf 依赖）。`nextpas.core.tar.common` 为内部共享内核（`TarPadToBlock`/`GuardTarEntrySize`/`GuardTarTotalSize`/`GuardTarNameForRead` + 校验和单点 `TarComputeChecksumUnsigned`/`TarComputeChecksumSigned`/`TarVerifyBlockChecksum`/`TarHeaderIsZeroOrValid` + 数值单点 `TarParseNumericField`/`TarFormatNumericField` + pax 单点 `TarFormatPaxRecord`（`CreateBytesBuilder+TarAppendPaxRecord+SpanToString` 单次 Move 薄包装，`TarAppendPaxRecord` 为 `Reserve+AppendBytes` 零拷贝最优路径单源，禁 `SetLength+CopyStringToBuffer` 双复制误用）/`TarParsePaxRecords`/`TarParsePaxKVRecords` 编解码同源，零拷贝 PByte 切片、复用 `bytes.ops` 单源视图，`archive.pax ArchivePaxParseRecords` 为通用 pax-kv 严格校验解析供归档族复用，`pax: ...` 畸形即抛 `EIOError` 禁静默回退；薄守卫 `TarPadToBlock`/`TarStoredChecksum`/`TarVerifyBlockChecksum` inline，含 512/变长循环的 `TarComputeChecksum*`/`TarHeaderIsZero*`/`TarParseNumericField`/`TarFormatNumericField`/`TarAppendPaxRecord`/`TarParsePaxRecords`/`TarParsePaxKVRecords`/`ArchivePaxParseRecords` 保持外联以遵 design-conventions 真实循环体禁 inline，避免 I-Cache 复制膨胀），仅供 `tar.reader/writer/fs` 实现内复用，禁止门面（`nextpas.core.tar`）外直接 `uses`；`nextpas.core.archive.pax` 为通用 pax-kv 解析共享内核（同为内部核例外，四件套外，归档族经 `tar.common → archive.pax` 联邦复用）；绕过门面直引视为违契，`test_tar_contract` 覆盖该边界。

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
  └─ OpenEntryStream ──► IReader 持有型
        ├─ FBuf 非空：TTarSliceReader.CreateWithHold(FBuf, Ofs, Size) 持有镜像引用，Reader 释放后仍可读
        └─ 外部 PByte：SpanClone 固化拷贝自包含（FHold 独立），Reader 释放后仍可读
```

- 视图失效：`Reader.Free` 后 `Span.Data` 悬垂，禁止再访；流持有型则安全（`FHold` 自包含）。
- 单源：`SpanClone/CopyMemory/CopyStringToBuffer` 均经 `bytes.ops` 单源 `Move`，`TTarSliceReader.Read` 经 `CopyMemory` 单源零拷贝。
