# nextpas.core.tar CONTRACT

本文档描述 `nextpas.core.tar` 的公共契约。改动公共 API、错误语义或生命周期时必须同步更新本文件与 `test_tar_*` 门。

## 1. 公共 API 面

### 1.1 类型

| 类型 | 说明 |
|------|------|
| `TTarEntryKind` | 7 种类：`tekRegular/HardLink/Symlink/CharDevice/BlockDevice/Directory/Fifo` |
| `TTarHeader` | `Name/LinkName/Kind/Mode/UID/GID/Size/MTimeUnix/UName/GName/DevMajor/DevMinor` |
| `TTarAddOptions` | `Mode/UID/GID/MTimeUnix/UName/GName`（`DefaultTarAddOptions` 取 0/空） |
| `TTarReadOptions` | `MaxEntrySize` 单条目上限（0 取 `C_TAR_DEFAULT_MAX_ENTRY=1GiB`）、`MaxTotalSize` 跨条目总量（0=不限） |
| `TTarExtractOptions` | `RestoreMode/SkipSpecial/MaxEntrySize/MaxTotalSize` |
| `TTarReader` | `Create(PByte,Count)` / `WithOptions` 双形态；`Next(out H):Boolean` 迭代；`TrySlice(out TByteSpan):Boolean` 零拷贝视图（单一规范，生命周期绑 Reader）/ `EntryDataSlice` 薄转发；`OpenEntryStream:IReader` 零拷贝流（FBuf 时持有型、外部 PByte 时直视，inline/零拷贝，生命周期绑 Reader/外部 PByte，按需 SpanClone）；`EntryDataOfs:SizeUInt`；`ClearGlobalPax` / `AcquireGlobalPaxGuard:IInterface` RAII 隔离 |
| `TTarWriter` | `AddEntry(Hdr,Data)` / `AddFile/AddDir/AddEntryWithOptions/AddEntryFromReader` / `Finish`（两零块，需显式 Finish） |

### 1.2 常量与谓词

`C_TAR_BLOCK_SIZE=512`，`C_TAR_MAX_NAME_BYTES=512`，`C_TAR_MAX_LINK_BYTES=4096`，`C_TAR_DEFAULT_MAX_ENTRY=1GiB`。`IsSafeTarEntryName/ValidateTarEntryName`（见 §2 INV-5）。

### 1.3 便捷层

`TarPackDirInto/TarPackDir/TarExtractToDirWithOptions/TarExtractToDir`（`nextpas.core.tar.fs`，目录递归确定性排序，deferred dir 逆序定稿）。

- 单源联邦：`tar.fs` 仅 `uses nextpas.core.archive.fs`，Walk/排序/防劫持/零拷贝落盘经 `archive.fs` 单源；`PackWalks` 外联单源（真实循环+文件IO分发遵设计公约红线2禁inline避I-Cache膨胀，零拷贝语义不变）；`bytes.ops` 单源，`try..finally` 不丢句柄。
- 硬链接 TOCTOU 闭环：`tekHardLink` 经 `archive.fs` 统一谓词 `ArchiveValidateHardlinkSource` + `ArchiveHardLinkVerified` fd 级原子落盘（`O_NOFOLLOW|O_CLOEXEC`）。

### 1.4 链式构造器

`ITarBuilder`（`nextpas.core.tar.intf` 定义，`nextpas.core.tar.builder` 实现）：`Add/AddWithOptions/AddDirectory/AddDirectoryWithOptions/AddEntry/AddEntryFromReader/Finish` 链式单口直达。

- `base←intf←实现←门面`，L2→L1 单向 `nextpas.core.io.intf(IReader)`；薄门面委托 `TTarWriter`，复用 `bytes.ops`/`bytes.builder` 单源；需显式 `Finish`（两零块），析构 `try..finally` 必释资源、永不抛异常仅 `log.intf Warn` 可观测。

## 2. 不变量

- **[INV-1]** USTAR 写入：`magic "ustar\0"` @257 + `version "00"` @263 固定；>100 字符名自动 `prefix/name` 分割，否则以 `pax x` 扩展头承载。
- **[INV-2]** 数值字段八进制为主，超限自动 `base-256`（`$80` + big-endian），读端双路径兼容。
- **[INV-3]** 读写对称：读端支持 `GNU L/K` 与 `pax x/g` 的 `path/linkpath` 覆盖（per-entry 优于 global，`g` 需 guard 持久否则单次消费自动清理并 `ILogger.Warn`；`g` 恶意路堨经 `IsSafeTarEntryName` 过滤置空同步 `Warn` 可观测，防静默篡改），pax 记录严格校验、畸形抛 `EIOError`。
- **[INV-4]** 校验和双算（unsigned/signed）任一匹配即过，否则 `EIOError: header checksum mismatch`。
- **[INV-5]** 名安全：`IsSafeTarEntryName` 拒绝空名/绝对路径/盘符/反斜杠/`//`/`./`/`..`；写端 `EArgumentError`，读端/落盘前 `EParseError`，落盘二次拒绝；落盘前拒绝路径含符号链接段。
- **[INV-6]** Bomb 守卫：`MaxEntrySize` 单条目与 `MaxTotalSize` 总量在 `common.Guard*` 单点 fail-closed，`TrySlice`/`OpenEntryStream` 中途同受；`pax x/g` 与 `GNU L/K` 扩展载荷计入总量（防 100k×超大 pax DoS，`GuardTarTotalSize` 单源）。
- **[INV-7]** 帧与视图：双零块收尾、单零块后非零即 `truncated stream`；`TrySlice` 为零拷贝 `TByteSpan` 单一规范（`inline`、生命周期绑 `Reader`），`EntryDataSlice` 薄转发同源；`OpenEntryStream` 为零拷贝 `IReader`（`FBuf` 时 `CreateSliceReaderWithHold` 零拷贝持有镜像、`Reader` 释放后仍可读；外部 `PByte` 时 `CreateSliceReader` 零拷贝直视、生命周期绑外部 PByte/Reader，零分配 inline，按需 `TrySlice+SpanClone` 自包含防高频 allocs 次 GC），`bytes.ops` 单源 `CopyMemory`（`SpanClone` 仅按需路径）。确定性：未显式 mtime 取 `0`，同输入同字节（除 pax 长名外）。

## 3. 错误模型

| 场景 | 异常 |
|------|------|
| 结构损坏（截断、八进制非法、校验和不符、不支持 typeflag、负尺寸、长名过长、孤儿块、pax 畸形） | `EIOError('tar: ...'/'pax: ...')` |
| 名不安全（写端） | `EArgumentError('tar entry name ...')` |
| 名不安全（读端/落盘） | `EParseError('tar: refusing unsafe entry name: ...')` |
| 落盘路径含符号链接段 | `EParseError('tar extract: symlink in path: ...')` |
| 目标 writer 为 nil / 已 Finish 后再写入 | `EArgumentError` / `EInvalidOperationError('tar: writer already finished')` |
| `ITarBuilder` 未 `Finish` 即析构 | `log.intf ILogger.Warn` 可观测，析构永不抛异常，`try..finally` 必释资源 |
| 单条目/总量超限 | `EIOError`（总量分支携带 `ACum/ANext/AMaxTotal` 上下文） |
| Short write | `EIOError('tar: short write')` |

## 4. 源契约

生产单元（`src/nextpas.core.tar*.pas`）不得 `uses` 非 `nextpas.*`，经 `test_tar_contract` 机械执行。门面仅 `re-export` + `inline` 委托，无控制流。

- 四件套 `base←intf←实现←门面`（`base` 零依赖同模块文件，守纯度；阈值常量与 `TarCapacityAlign4K/Builder/IOBuf` 单源于 `nextpas.core.tar.base` 经 `bytes.ops.AlignUp4K` 位掩码零除法 `inline` 零拷贝，阈值分叉固化于 `base` 常量）；`nextpas.core.tar.common` 为内部共享内核（类型级隔离：门面零 re-export，仅 `reader/writer/fs` 受信实现 `implementation uses` 可见，辅以本契约机械门禁双重收敛）仅供 `reader/writer/fs` 复用，`nextpas.core.tar.capacity` 为容量与对齐专用内核（`TarCapacityAlign4K` 经 `bytes.ops.AlignUp4K` 位掩码零除法 `inline` 零拷贝单源、`TarBuilderCapacityFor` floor 4K+两零块 4K 对齐（修复 64K 对 512B 128倍过度预分配）、`TarIOBufCapacityFor` 4K~1M clamp 单源，阈值分叉固化于 `base` 常量（`capacity` 无常量薄别名，函数经 `capacity→base` 薄转发 `inline` 零拷贝单源，无双路径），门面零 re-export，仅 `builder/writer/fs` 受信实现 `implementation uses` 可见，`base` 不直引 `capacity` 守纯度）仅供 `builder/writer/fs` 容量预估与对齐单源复用，`nextpas.core.archive.pax` 为归档族通用 pax-kv 内核；绕过门面直引视为违契。

## 5. 测试入口

```bash
make focused FOCUS=core/tests/nextpas.core.tar/test_tar_reader
make focused FOCUS=core/tests/nextpas.core.tar/test_tar_writer
make focused FOCUS=core/tests/nextpas.core.tar/test_tar_fs
make focused FOCUS=core/tests/nextpas.core.tar/test_tar_contract
make focused FOCUS=core/tests/nextpas.core.compress/test_compress_tar
make -C core/benchmarks/nextpas.core.tar/bench_tar run
make -C core/benchmarks/nextpas.core.tar/bench_tar regression
```

## 6. 性能目标与回归门限

数值单源于 `core/benchmarks/nextpas.core.tar/bench_tar/BASELINE.json`（`build/bench-tar.json` 人工审查固化，`make baseline` 刷新）。

- 口径：`bench_tar` `TBenchSuite` 承载，`make -C core/benchmarks/nextpas.core.tar/bench_tar run` 可复现（`GOMAXPROCS=1` 降噪，`SetMinDuration 300ms/MinSamples 7/Warmup 1`，`ACtx.SetBytes` 换算吞吐，双路归档 `build/bench-tar.json`）。
- 门限（CI 硬红）：`allocs` 硬预算 `baseline+2` / `bytes` 强一致（`!=` 即红）与 `ns/op ≤1.50×` / `MB/s ≥0.65×` 均为硬门（`status=ok` 强一致，任一超限 `check_regression.py` 非零退出，CI 红）；`make -C core/benchmarks/nextpas.core.tar/bench_tar regression` 比对 `BASELINE.json` 判定。
- 对照（CI 硬红，若对照产物存在；缺失时 warn 非硬红闭环）：Go `archive/tar` (`core/benchmarks/nextpas.core.tar/bench_tar/compare_go/main.go`, `go.mod` 已落地，`GOMAXPROCS=1` 降噪) / Rust `tar` (`compare_rust/Cargo.toml` + `main.rs` `tar="0.4"` 已落地) 同口径守卫 `Pascal ns/op ≤1.50×` 且 `MB/s ≥0.70×`（连续双机复现升硬门）；`make -C core/benchmarks/nextpas.core.tar/bench_tar run-compare` 生成对照 JSON（`build/bench-tar-compare-*.json`），`check_regression.py --with-compare` 比对判定，缺失时 warn 非硬红闭环；零拷贝 `TrySlice` inline 视图与 `bytes.ops CopyMemory/SpanClone` 单源（FBuf 持有型/外部 PByte 直视，按需 `SpanClone`，`try..finally` 必释）证据见 `reader.pas:TrySlice inline` 与 `common.pas:CopyMemory` 单源。
- 实现：零拷贝视图 `TrySlice` 单一规范 `inline` + `EntryDataSlice` 薄转发，`OpenEntryStream` 零拷贝（FBuf 持有型、外部 PByte 直视，`inline` 零分配，按需 `SpanClone`）；`bytes.ops` 单源 `CopyMemory`（`SpanClone` 仅按需）+ `bytes.ops.AlignUp4K` 容量对齐单源（`base` 单源常量与 `TarCapacityAlign4K` 经 `bytes.ops.AlignUp4K` 位掩码零除法 `inline` 零拷贝，`capacity` 仅函数薄转发 `builder/writer/fs` 单源无常量双路径，`base` 零依赖同模块）、`bytes.builder` 几何扩容；含循环体外联以遵 `design-conventions`（薄转发 `inline`、循环体/回退外联避 I-Cache 膨胀）。
- 确定性：`archive.fs` 确定性排序 + `deferred dir` 逆序定稿 + 未显式 `mtime=0` 同输入同字节（除 pax 长名外），跨机复现高级感。
