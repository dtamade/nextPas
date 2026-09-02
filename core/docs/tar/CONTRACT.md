# nextpas.core.tar CONTRACT

本文档描述 `nextpas.core.tar` 的公共契约。改动公共 API、错误语义或生命周期时必须同步更新本文件与 `test_tar_*` 门。

## 1. 公共 API 面

### 1.1 类型

| 类型 | 说明 |
|------|------|
| `TTarEntryKind` | 7 种类：`tekRegular/HardLink/Symlink/CharDevice/BlockDevice/Directory/Fifo` |
| `TTarHeader` | `Name/LinkName/Kind/Mode/UID/GID/Size/MTimeUnix/UName/GName` |
| `TTarAddOptions` | `Mode/UID/GID/MTimeUnix/UName/GName`（`DefaultTarAddOptions` 取 0/空） |
| `TTarReadOptions` | `MaxEntrySize` 单条目上限（0 取 `C_TAR_DEFAULT_MAX_ENTRY=1GiB`）、`MaxTotalSize` 跨条目总量（0=不限） |
| `TTarExtractOptions` | `RestoreMode/SkipSpecial/MaxEntrySize/MaxTotalSize` |
| `TTarReader` | `Next(out H):Boolean` / `EntryData:TBytes` / `EntryDataSlice(out PByte,Count):Boolean` / `OpenEntryStream:IReader` / `EntryDataOfs:SizeUInt` / `Create(PByte,Count)` 双形态 + `WithOptions` |
| `TTarWriter` | `AddEntry(Hdr,Data)` / `AddFile/AddDir/AddEntryWithOptions/AddEntryFromReader` / `Finish`（两零块，需显式 Finish，析构兜底补两零块 best-effort，`IsFinished` 供 builder fail-closed 校验） |

### 1.2 常量与谓词

`C_TAR_BLOCK_SIZE=512`，`C_TAR_MAX_NAME_BYTES=512`，`C_TAR_DEFAULT_MAX_ENTRY=1GiB`。`IsSafeTarEntryName/ValidateTarEntryName`（见 §2 INV-5）。

### 1.3 便捷层

`TarPackDirInto/TarPackDir/TarExtractToDirWithOptions/TarExtractToDir`（`nextpas.core.tar.fs`，目录递归确定性排序，deferred dir 逆序定稿）。

### 1.4 链式构造器

`ITarBuilder`（`nextpas.core.tar.intf` 定义，`nextpas.core.tar.builder` 实现）：`Add/AddWithOptions/AddDirectory/AddDirectoryWithOptions/AddEntry/AddEntryFromReader/Finish` 链式，遵循 `base←intf←实现←门面`；薄门面委托 `TTarWriter` + `CreateBytesBuilder` 直写切片（`IBytesBuilder` 几何扩容、inline `AppendBytes` 零拷贝，复用 `bytes.ops`/`bytes.builder` 单源），`Finish` 经 `ToBytes` 单次分配+Move 交付，消除 `CreateBytesStream` + `ArchiveSnapshotStream` 二次 `SetLength+Seek+Read` 大块 `Move`；`AddDirectory/AddDirectoryWithOptions` 复用 `TTarWriter.AddDir/AddDirWithOptions` 单源，`AddDirWithOptions` 内部以 `DefaultTarAddOptions` 判零、`TarDirectoryMode` 换算默认权限，薄门面无重复 `TTarHeader` 手写；`AddEntryFromReader` 流式零拷贝（64K pooled 复用缓冲分块 Move 单源 `bytes.ops`，委托 `TTarWriter.AddEntryFromReader` 单源，无 `TBytes` 全量拷贝）；门面导出单一 `TarBuilder` inline 工厂（`NewTarBuilder` 已移除），需显式 `Finish`（未 `Finish` 析构 fail-closed 抛 `EInvalidOperationError('tar: builder destroyed without Finish')`，而非静默补零块，避免链式丢数据无感知；`TTarWriter` 析构仍 best-effort 兜底），零额外序列化逻辑，bytes 级与 `TTarWriter` 一致。

## 2. 不变量

- **[INV-1]** USTAR 写入：`magic "ustar\0"` @257 + `version "00"` @263 固定，>100 字符名自动 `prefix/name` 分割（最大 `/` 使后缀 ≤100，否则以 `pax` 扩展头 `typeflag 'x'` 承载 `path/linkpath` 记录，长度前缀十进制自洽，读端 `x/g` 与 `GNU L/K` 单点覆盖，消除读写不对称），`linkname>100` 同走 `pax linkpath`，目录补 `/`。
- **[INV-2]** 数值字段八进制为主，超 `octal capacity` 自动 `base-256`（首字节 `$80` + big-endian），读端双路径兼容。
- **[INV-3]** 读写对称：读端支持 `GNU L/K` 长名、`pax x/g` 的 `path/linkpath` 覆盖（per-entry 优于 global），pax 记录含长度前缀校验；写端>100 且无 `prefix` 切分或 `linkpath>100` 时自动前置 `pax` `x` 扩展头（`path/linkpath` 单条记录，`bytes.ops` 单源 `StringToBytes` 一次 Move），与读端单点互通。
- **[INV-4]** 校验和双算（unsigned/signed）任一匹配即过，否则 `EIOError: header checksum mismatch`。
- **[INV-5]** 名安全：`IsSafeTarEntryName` 拒绝空名/绝对路径/盘符/反斜杠/`//` 空段/`./` 单点段/`..` 段，尾随 `/` 终段空合法；写端 `Validate` 即 `EArgumentError`，读端/落盘前 `EParseError`，`..` 经 `TarExtractToDir` 二次拒绝。
- **[INV-6]** Bomb 守卫：`MaxEntrySize` 单条目与 `MaxTotalSize` 跨条目总量在 `common.Guard*` 单点，`Next` 归一真实尺寸后累计，`EntryData`/`OpenEntryStream` 中途同受，超限 `EIOError`。
- **[INV-7]** 零块结束：单零块后须跟全零或 EOF，否则 `truncated stream`；`FEntryDataOfs/Size` 视图与 `EntryData` 拷贝一致；`EntryDataSlice` 为零拷贝借用视图（生命周期默认绑定 `Reader`），`OpenEntryStream` 为持有型 `IReader`（`Reader` 拥有 `TBytes` 时流持有镜像引用，外部 `PByte` 时流固化拷贝自包含，`Reader` 释放后仍可读）；`EntryData` 为拷贝分流（峰值 2× 切片，`bytes.ops SpanClone` 单源），热路径优先 `EntryDataSlice/OpenEntryStream`（`extract-all 320µs` vs `extract-slice 236µs`）。
- **[INV-8]** 确定性：未显式 mtime 取 `0`，mode 默认 `0644/0755`，同输入同字节（除 pax 长名外）。

## 3. 错误模型

| 场景 | 异常 |
|------|------|
| 结构损坏（截断、八进制非法、校验和不符、不支持 typeflag、负尺寸、长名过长、孤儿块） | `EIOError('tar: ...')` |
| 名不安全（写端） | `EArgumentError('tar entry name ...')` |
| 名不安全（读端/落盘） | `EParseError('tar: refusing unsafe entry name: ...')` |
| 落盘路径含符号链接段 | `EParseError('tar extract: symlink in path: ...')` |
| 目标 writer 为 nil / 已 Finish 后再写入 | `EArgumentError` / `EInvalidOperationError('tar: writer already finished')` |
| `ITarBuilder` 未 `Finish` 即析构 | `EInvalidOperationError('tar: builder destroyed without Finish (missing two zero blocks, data truncated)')` — fail-closed 避免静默丢数据 |
| 单条目/总量超限 | `EIOError('tar: entry size exceeds limit for "%s" (%d > %d)' / 'total ... exceeds limit (%d + %d > %d)')` — 总量分支携带 `ACum/ANext/AMaxTotal` 上下文便于定位 |
| Short write | `EIOError('tar: short write')` |

## 4. 源契约

生产单元（`src/nextpas.core.tar*.pas`）不得 uses 任何非 `nextpas.*` 单元，经 `test_tar_contract` 门机械执行。门面仅 re-export + inline 委托，无控制流。`nextpas.core.tar.common` 为内部共享内核（`TarPadToBlock`/`GuardTarEntrySize`/`GuardTarTotalSize`/`GuardTarNameForRead` + 校验和单点 `TarComputeChecksumUnsigned`/`TarComputeChecksumSigned`/`TarVerifyBlockChecksum`/`TarHeaderIsZeroOrValid` + 数值单点 `TarParseNumericField`/`TarFormatNumericField` + pax 单点 `TarParsePaxRecords`，零拷贝 PByte 切片、复用 `bytes.ops` 单源视图；薄守卫 `TarPadToBlock`/`TarStoredChecksum`/`TarVerifyBlockChecksum` inline，含 512/变长循环的 `TarComputeChecksum*`/`TarHeaderIsZero*`/`TarParseNumericField`/`TarFormatNumericField`/`TarParsePaxRecords` 保持外联以遵 design-conventions 真实循环体禁 inline，避免 I-Cache 复制膨胀），仅供 `tar.reader/writer/fs` 实现内复用，禁止门面（`nextpas.core.tar`）外直接 `uses`；绕过门面直引视为违契，`test_tar_contract` 覆盖该边界。

## 5. 测试入口

```bash
make focused FOCUS=core/tests/nextpas.core.tar/test_tar_reader
make focused FOCUS=core/tests/nextpas.core.tar/test_tar_writer
make focused FOCUS=core/tests/nextpas.core.tar/test_tar_fs
make focused FOCUS=core/tests/nextpas.core.tar/test_tar_contract
make focused FOCUS=core/tests/nextpas.core.compress/test_compress_tar  # 回归：经 deprecated 转发仍绿
make -C core/benchmarks/nextpas.core.tar/bench_tar run              # 基准：产出 build/bench-tar.json（阈值见 §6，数值单源 BASELINE.json）
make -C core/benchmarks/nextpas.core.tar/bench_tar regression       # 回归门：allocs/bytes 硬门 + ns/MB/s 阈值（阈值见 §6）
```

## 6. 性能目标与回归门限

> 数值单源于 `core/benchmarks/nextpas.core.tar/bench_tar/BASELINE.json`（`build/bench-tar.json` 的人工审查固化，`make baseline` 刷新）。CONTRACT 仅定义口径与阈值公式，不复刻绝对数值，遵上层极简收敛原则。

口径：`core/benchmarks/nextpas.core.tar/bench_tar` 以 `nextpas.core.bench` `TBenchSuite` 规矩承载（`SetMinDuration 300ms`/`MinSamples 7`/`MaxIterations 25`/`Warmup 1`，`ACtx.SetBytes` 换算吞吐，`SaveToJSON` 双路归档 `build/bench-tar.json`，`-O3 -Xs` 计时保真）。覆盖小容器 `200×512B` 与 `1MiB` 吞吐两面 7 项（`pack/builder-pack/open/parse/extract-all/extract-slice/write/read`），`TAR_BENCH_FULL=1` 追加 `2000×512B` 档；`make -C core/benchmarks/nextpas.core.tar/bench_tar run` 可复现。

阈值：`allocs` 硬预算 `baseline+2` 且 `bytes/op` 强一致、`status=ok` 必达（超限 CI 红）；`ns/op` 软告警 `>1.5× baseline`（持续回归待人工 `benchstat` 复核，方差高时以 `allocs` 为准）；`MB/s` 底线 `≥0.65× baseline`（WARN）。Go `archive/tar` / Rust `tar` 对照同口径 `compare_go`/`compare_rust`（共享 `GenerateData` 伪随机 `mod 251`，`GOMAXPROCS=1` 降噪，`benchstat` 对比），守卫 `Pascal ns/op ≤1.5×` 且 `MB/s ≥0.70×`（连续两机复现升硬门）。

回归：`make -C core/benchmarks/nextpas.core.tar/bench_tar regression` 经 `check_regression.py` 比对 `BASELINE.json` 与当前 `build/bench-tar.json` 执行 `allocs/bytes/status` 硬门与 `ns/MB/s` 软门判定（支持显式两参比对）；`make baseline` 需人工审查 p50/p95/outliers 后提交。

实现证据（性能·复用度·稳定性）：`common.TarPadToBlock`/`TarStoredChecksum`/`TarVerifyBlockChecksum` inline 薄守卫，`builder.TBuilderSink.Write` inline `AppendBytes` 零拷贝（`IBytesBuilder` 几何扩容、4K 初始，`bytes.builder` 单源），`reader.EntryDataSlice`/`OpenEntryStream` 零拷贝 `PByte` 视图（不拥有镜像，`FEntryDataOfs/Size` 与 `EntryData` 一致 INV-7，`TTarSliceReader.FHold:TBytes` 持有防悬垂，`bytes.ops.CopyMemory` 单源 `Move`），`writer` 单块 `Move` 直写、`builder.Finish` 单次 `ToBytes`（消除二次大块 `Move`）；`common.TarPutHeaderString`/`TarParsePaxRecords` 等零拷贝 `PByte` 复用 `bytes.ops` 单源一次 `Move`，`TarPackDirInto` 排序+`deferred dir` 复用 `collections` 单源，`AddDirectoryWithOptions` 复用 `writer.AddDirWithOptions` 单源；`TarComputeChecksum*`/`TarHeaderIsZeroOrValid`/`TarParseNumericField` 等含 512/变长循环体保持外联（遵 `design-conventions` 真实循环体禁 inline，防 I-Cache 膨胀）；`TTarWriter.Finish` 显式两零块+析构兜底 `best-effort`（`IsFinished` 供 builder 校验），`TTarBuilder.Destroy` fail-closed（未 `Finish` 抛 `EInvalidOperationError` 而非静默补零块，`FWriter.Free` 兜底+接口自动释放不丢资源，`FFinished` 单源），`GuardTarEntrySize/GuardTarTotalSize` 单点 fail-closed，`Short write` 抛 `EIOError`，`AddEntryFromReader` 流式 64K pooled 缓冲单源 `bytes.ops`。
