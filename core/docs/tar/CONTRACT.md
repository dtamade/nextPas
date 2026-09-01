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
| `TTarWriter` | `AddEntry(Hdr,Data)` / `AddFile/AddDir/AddEntryWithOptions` / `Finish`（两零块，需显式 Finish，析构兜底补两零块 best-effort） |

### 1.2 常量与谓词

`C_TAR_BLOCK_SIZE=512`，`C_TAR_MAX_NAME_BYTES=512`，`C_TAR_DEFAULT_MAX_ENTRY=1GiB`。`IsSafeTarEntryName/ValidateTarEntryName`（见 §2 INV-5）。

### 1.3 便捷层

`TarPackDirInto/TarPackDir/TarExtractToDirWithOptions/TarExtractToDir`（`nextpas.core.tar.fs`，目录递归确定性排序，deferred dir 逆序定稿）。

### 1.4 链式构造器

`ITarBuilder`（`nextpas.core.tar.intf` 定义，`nextpas.core.tar.builder` 实现）：`Add/AddWithOptions/AddDirectory/AddDirectoryWithOptions/AddEntry/Finish` 链式，遵循 `base←intf←实现←门面`；薄门面委托 `TTarWriter` + `CreateBytesBuilder` 直写切片（`IBytesBuilder` 几何扩容、inline `AppendBytes` 零拷贝，复用 `bytes.ops`/`bytes.builder` 单源），`Finish` 经 `ToBytes` 单次分配+Move 交付，消除 `CreateBytesStream` + `ArchiveSnapshotStream` 二次 `SetLength+Seek+Read` 大块 `Move`；`AddDirectory/AddDirectoryWithOptions` 复用 `TTarWriter.AddDir/AddDirWithOptions` 单源，`AddDirWithOptions` 内部以 `DefaultTarAddOptions` 判零、`TarDirectoryMode` 换算默认权限，薄门面无重复 `TTarHeader` 手写；门面导出单一 `TarBuilder` inline 工厂（`NewTarBuilder` 已移除），需显式 `Finish`（析构经 `TTarWriter` 兜底补两零块 best-effort），零额外序列化逻辑，bytes 级与 `TTarWriter` 一致。

## 2. 不变量

- **[INV-1]** USTAR 写入：`magic "ustar\0"` @257 + `version "00"` @263 固定，>100 字符名自动 `prefix/name` 分割（最大 `/` 使后缀 ≤100，否则以 `pax` 扩展头 `typeflag 'x'` 承载 `path/linkpath` 记录，长度前缀十进制自洽，读端 `x/g` 与 `GNU L/K` 单点覆盖，消除读写不对称），`linkname>100` 同走 `pax linkpath`，目录补 `/`。
- **[INV-2]** 数值字段八进制为主，超 `octal capacity` 自动 `base-256`（首字节 `$80` + big-endian），读端双路径兼容。
- **[INV-3]** 读写对称：读端支持 `GNU L/K` 长名、`pax x/g` 的 `path/linkpath` 覆盖（per-entry 优于 global），pax 记录含长度前缀校验；写端>100 且无 `prefix` 切分或 `linkpath>100` 时自动前置 `pax` `x` 扩展头（`path/linkpath` 单条记录，`bytes.ops` 单源 `StringToBytes` 一次 Move），与读端单点互通。
- **[INV-4]** 校验和双算（unsigned/signed）任一匹配即过，否则 `EIOError: header checksum mismatch`。
- **[INV-5]** 名安全：`IsSafeTarEntryName` 拒绝空名/绝对路径/盘符/反斜杠/`//` 空段/`./` 单点段/`..` 段，尾随 `/` 终段空合法；写端 `Validate` 即 `EArgumentError`，读端/落盘前 `EParseError`，`..` 经 `TarExtractToDir` 二次拒绝。
- **[INV-6]** Bomb 守卫：`MaxEntrySize` 单条目与 `MaxTotalSize` 跨条目总量在 `common.Guard*` 单点，`Next` 归一真实尺寸后累计，`EntryData`/`OpenEntryStream` 中途同受，超限 `EIOError`。
- **[INV-7]** 零块结束：单零块后须跟全零或 EOF，否则 `truncated stream`；`FEntryDataOfs/Size` 视图与 `EntryData` 拷贝一致；零拷贝 `EntryDataSlice/OpenEntryStream` 不拥有镜像。
- **[INV-8]** 确定性：未显式 mtime 取 `0`，mode 默认 `0644/0755`，同输入同字节（除 pax 长名外）。

## 3. 错误模型

| 场景 | 异常 |
|------|------|
| 结构损坏（截断、八进制非法、校验和不符、不支持 typeflag、负尺寸、长名过长、孤儿块） | `EIOError('tar: ...')` |
| 名不安全（写端） | `EArgumentError('tar entry name ...')` |
| 名不安全（读端/落盘） | `EParseError('tar: refusing unsafe entry name: ...')` |
| 落盘路径含符号链接段 | `EParseError('tar extract: symlink in path: ...')` |
| 目标 writer 为 nil / 已 Finish 后再写入 | `EArgumentError` / `EInvalidOperationError('tar: writer already finished')` |
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
make -C core/benchmarks/nextpas.core.tar/bench_tar run              # 基准：产出 build/bench-tar.json（见 §6）
make -C core/benchmarks/nextpas.core.tar/bench_tar regression       # 回归门：allocs/bytes 硬门 + ns/MB/s 阈值（见 §6.4）
```

## 6. 性能目标与回归门限

> 基准口径：`core/benchmarks/nextpas.core.tar/bench_tar` 以 `nextpas.core.bench` `TBenchSuite` 规矩承载（`SetMinDuration 300ms`/`MinSamples 7`/`MaxIterations 25`/`Warmup 1`，`ACtx.SetBytes` 换算吞吐，`PrintToConsole`+`ToBenchstat`+`SaveToJSON` 双路归档 `build/bench-tar.json` 与 `../../../build/bench-tar.json`，`-O3 -Xs` 计时保真）。覆盖小容器 `200×512B` 与 `1MiB` 吞吐两面共 7 项（`tar/pack`/`builder-pack`/`open/parse`/`extract-all`/`extract-slice`/`write/1MB`/`read/1MB`），`TAR_BENCH_FULL=1` 追加 `2000×512B` 档。`make -C core/benchmarks/nextpas.core.tar/bench_tar run` 可复现。

### 6.1 基线快照（2026-09-02, Linux x86_64 44c, FPC 3.3.1 `-O3 -Xs`）

`build/bench-tar.json` 七项中值（7/7 ok, 25 iters）：

| benchmark | ns/op | MB/s | allocs/op | bytes/op | 备注 |
|-----------|-------|------|-----------|----------|------|
| `tar/pack/200x512B` | 526 µs (526383 ns, p50 514µs p95 604µs) | 194.5 MB/s | 410 | 102400 | `TTarWriter` 直写 `IWriter` + `Move` 单块 |
| `tar/builder-pack/200x512B` | 537 µs (537175 ns, p50 534µs) | 190.6 MB/s | 411 | 102400 | `ITarBuilder` 薄门面委托 `TTarWriter`，`BuilderSink.Write` inline `AppendBytes` 零拷贝，`Finish` 单次 `ToBytes` |
| `tar/open/parse` | 236 µs (235750 ns, p50 222µs) | — | 201 | 5536 | 纯解析，不含解压；`TarHeaderIsZeroOrValid` 单遍 512 融合校验和/零块 |
| `tar/extract-all/200x512B` | 321 µs (320922 ns) | 319 MB/s | 401 | 102400 | `EntryData` 拷贝路径 |
| `tar/extract-slice/200x512B` | 236 µs (236523 ns, p50 223µs) | 432.9 MB/s | 201 | 102400 | `EntryDataSlice` 零拷贝视图，无 `Copy` |
| `tar/write/1MB` | 2.37 ms (2372762 ns, p50 2.378ms) | 441.9 MB/s | 5 | 1048576 | 单条目 1MiB |
| `tar/read/1MB` | 1.59 ms (1592930 ns, p50 1.585ms) | 658.3 MB/s | 3 | 1048576 | 零拷贝切片流 |

`bench_tar` 以 `TBenchSuite` 校准 300ms/7 样，CV 受 `MinSamples`/`MaxIterations` 治理，`TAR_BENCH_FULL=1` 追加 2000×512B 档用于规模回归（不入默认门限）。

### 6.2 量化目标（ns/op 与 MB/s）

| benchmark | 目标 p50 | 硬门限 ns/op (≤1.5×基线) | 软告警 ns/op (>1.5×) | MB/s 底线 (≥0.65×基线) |
|-----------|----------|-------------------------|---------------------|----------------------|
| `tar/pack/200x512B` | ≤560 µs | ≤800 µs | WARN | ≥126 MB/s |
| `tar/builder-pack/200x512B` | ≤570 µs | ≤810 µs | WARN | ≥124 MB/s |
| `tar/open/parse` | ≤250 µs | ≤354 µs | WARN | — |
| `tar/extract-all/200x512B` | ≤340 µs | ≤482 µs | WARN | ≥207 MB/s |
| `tar/extract-slice/200x512B` | ≤250 µs | ≤355 µs | WARN | ≥281 MB/s |
| `tar/write/1MB` | ≤2.5 ms | ≤3.56 ms | WARN | ≥287 MB/s |
| `tar/read/1MB` | ≤1.70 ms | ≤2.39 ms | WARN | ≥428 MB/s |

- **allocs 硬预算（零容忍 +2 抖动，CI 红）**：`pack ≤412`/`builder ≤413`/`open ≤203`/`extract-all ≤403`/`extract-slice ≤203`/`write ≤7`/`read ≤5`；`bytes/op` 强一致（偏差即红），`status=ok` 必达。
- **ns/op**：`+50%` 为软告警（CI 不红，方差高时以 allocs 硬门为准）；`+50%` 以上持续回归视为硬门待人工复核。
- 基线固化于 `core/benchmarks/nextpas.core.tar/bench_tar/BASELINE.json`（由 `make baseline` 人工审查后提交），`check_regression.py` 对比 `BASELINE.json` 与当前 `build/bench-tar.json` 执行上述三项（allocs/bytes/ns）判定。

### 6.3 Go / Rust 对照守卫

| 对标 | 实现 | 口径 | 守卫 |
|------|------|------|------|
| Go `archive/tar` | `core/benchmarks/nextpas.core.tar/bench_tar/compare_go` (`go test -bench=. -benchtime=1x`，同 `FILE_COUNT/FILE_SIZE` 与 `BIG_SIZE` 参数) | `ns/op` + `MB/s`（`SetBytes` 同口径，含 `pack/open/extract-all/extract-slice/write/read` 六项） | **Pascal ns/op ≤ 1.5× Go** 且 **Pascal MB/s ≥ 0.70× Go**；任一超限即回归待查（同机 `-O3` vs `go test -bench`，`GOMAXPROCS=1` 降噪） |
| Rust `tar` crate | `core/benchmarks/nextpas.core.tar/bench_tar/compare_rust` (`cargo bench`，同参) | `ns/op` + `MB/s`（`criterion` 单次调用，不含内循环放大） | **Pascal ns/op ≤ 1.5× Rust** 且 **Pascal MB/s ≥ 0.70× Rust**；同 Go 门限，阈值与 `bench` 框架 `ToBenchstat` 归一 |

- 对照套件与 Pascal 共享 `GenerateData`（`GFiles[2000×512B]` 伪随机 `mod 251` + `GBlob[1MiB]`），`entryName` 统一 `f/XXXX.bin`，避免数据分布偏差。
- Go/Rust 亦以 `benchstat` 汇出，人机对照以 `ns/op` 为主、`MB/s` 为辅，`allocs` 不跨语言对比。
- 门限说明：tar 为纯 store（无压缩），Go/Rust 同为 `store` 形态，Pascal 因 `bytes.ops` 单源 `Move` + 零拷贝切片具备竞争力；`1.5×/0.70×` 兼顾机器方差与实现差异，`allocs` 硬门仍为首判据。

### 6.4 回归门限与 CI 硬门

```bash
make -C core/benchmarks/nextpas.core.tar/bench_tar build   # -O3 -Xs 计时保真
make -C core/benchmarks/nextpas.core.tar/bench_tar run      # 产出 build/bench-tar.json
python3 core/benchmarks/nextpas.core.tar/bench_tar/check_regression.py  # 对比 BASELINE.json
```

- **硬门**：`allocs > baseline+2` 或 `bytes/op` 不等或 `status!=ok` → 非零退出，CI 红。
- **软门**：`ns/op > baseline*1.5` → WARN（不红），`MB/s < baseline*0.65` → WARN；持续 WARN 需人工 `benchstat` 复核。
- **Go/Rust 门**：同机复跑 `compare_go`/`compare_rust` 后以 `benchstat` 对比，`Pascal/Go` 与 `Pascal/Rust` 比值超 `1.5×` ns 或 `0.70×` MB/s 即 WARN，连续两机复现升硬门。
- `make baseline` 将当前 `build/bench-tar.json` 固化为 `BASELINE.json`，需人工审查 p50/p95/outliers 后提交。

### 6.5 实现证据（性能 · 复用度 · 稳定性）

- **inline/零拷贝**：`common.TarPadToBlock`/`TarStoredChecksum`/`TarVerifyBlockChecksum`/`TarWriteUStarMagic` inline 薄守卫；`builder.TBuilderSink.Write` inline `AppendBytes` 零拷贝（`IBytesBuilder` 几何扩容、4K 初始、`MEM_PAGE_SIZE` 对齐，`bytes.builder` 单源）；`reader.EntryDataSlice`/`OpenEntryStream` 零拷贝 `PByte` 视图（不拥有镜像，`FEntryDataOfs/Size` 视图与 `EntryData` 拷贝一致，INV-7）；`writer` 单块 `Move` 直写 `IWriter`，`builder.Finish` 单次 `ToBytes` 分配+Move，消除 `CreateBytesStream` + `ArchiveSnapshotStream` 二次 `SetLength+Seek+Read` 大块 `Move`。
- **单源复用（bytes.ops）**：`common.TarPutHeaderString`/`TarPutHeaderSlice`/`TarParsePaxRecords`/`TarWriteUStarMagic` 零拷贝 `PByte` 切片复用 `bytes.ops` `StringToBytes`/`SpanToString`/`TByteSpan` 单源一次 `Move`；`TarPackDirInto` 同层排序 + 几何扩容与 `deferred dir` 逆序定稿复用 `collections` 排序单源；`AddDirectoryWithOptions` 薄门面复用 `writer.AddDirWithOptions` 单源 `DefaultTarAddOptions`/`TarDirectoryMode`，无重复 `TTarHeader` 手写。
- **循环体外联（design-conventions 真实循环体禁 inline）**：`TarComputeChecksumUnsigned/Signed`/`TarHeaderIsZeroBlock`/`TarHeaderIsZeroOrValid`（单遍 512 融合校验和/零块）/`TarParseNumericField`/`TarFormatNumericField`/`TarParsePaxRecords` 含 512/变长循环体保持外联，避免 I-Cache 复制膨胀；薄守卫 inline，热循环外联。
- **稳定性**：`TTarWriter.Finish` 显式两零块，析构兜底 `best-effort` 补零块；`TTarBuilder.Destroy` 经 `FWriter.Free` 兜底，`FBuilder/FSink` 为接口自动释放，不丢资源；`TTarReader` 拥有镜像 `TBytes`，`EntryDataSlice` 视图生命周期绑定 `Reader`，`GuardTarEntrySize/GuardTarTotalSize` 单点 fail-closed，`Short write` 抛 `EIOError`。
