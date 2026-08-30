# nextpas.core.zip 终局路线图 — 领头羊标准

> **愿景**：`nextpas.core.zip` 成为 Pascal AI 时代 ZIP 容器的领头羊实现 — 以 `nextpas.core.bench` 为唯一基准尺，零分配、可复用、强稳定、完全体，跨 Python `zipfile` 与 Go `archive/zip` 双锚点字节级一致，任何标准解压器可读，我们产出的归档可被任何标准解压器还原。

> **原则**：性能（零分配、几何预留、零拷贝）、高级感（Fluent Builder、确定性输出、字节级一致）、复用度（`common`/`extra`/`builder` 单点内核）、稳定性（`MaxOutput`/`MaxTotal` 双守卫、`IsKnownZipSig` 预筛、fail-closed）、完整性（store/deflate/Zip64/AES/描述符四形态/顺序流全覆盖）。标准很高、很严格。

## 1. 现状基线（S0—S42 已落地）

| 阶段 | 交付 |
|------|------|
| S0-S3 | 文档门面与生命周期契约（`np.system.*`） |
| S19 | 领头羊双锚点：Python zipfile + Go archive/zip 字节级对等（store/deflate/unicode/1MiB/20×混合/30 fuzz） |
| S20 | `CountingMemoryManager` allocs 预算门（`200×512B 810→805`、`1MiB ≤12`） |
| S21 | 极限压力：`70k Zip64`/`1k 混合双路径`/`Bomb 单值与总量`/`并发提取` |
| S22 | `BASELINE.json` + `check_regression.py`（allocs+2/bytes 强一致/ns+50% 告警）CI 硬门 |
| S23 | Fluent Builder 字节级一致薄委托（`Add/Deflate/WithTime/Reserve/StreamTo/AddEntryStream`） |
| S31-S33 | Sequential 对偶（`ISequentialZipReader`）与 MaxTotal 守卫、Builder 对称 |
| S34 | `DecompressEntryVerified` 单点 + `fs` 几何预分配（70k 目录 O(n²)→O(n)） |
| S35 | `IsKnownZipSig` 先验再试解防 `O(n·m)` CPU bomb |
| S36 | `EncodeWinZipAesExtraBody` 栈上零堆 + `FScratch` 几何 |
| S37 | `LCumTotal` 去复用 + Store bomb 回归 |
| S38 | `INV-8/11/16` 入约 |
| S39 | `GuardTotalOutputSize` 单点化 |
| S40 | 示例与契约定版：`zip_roundtrip` 补 `MaxOutput/MaxTotal` 三路径（内存/顺序/fs）fail-closed 全演示 |
| S41 | 顺序读零拷贝：`TSeqSliceReader` 去 `Copy` 双重拷贝、`PushBack` 去 `Copy`，`seq-extract-all 2005→1804` |
| S42 | 描述符无签名兼容：`CollectDescriptorPayload` 支持 `12/16/20/24` 四形态，移除 Known Limitation |

**当前门**：12门全绿 `[HEAPTRC] OK`（`test_zip 27`/`test_zip_reader 26`/`test_zip_sequential 20`/`test_zip_fs 7`/`test_zip_contract 5`/`test_zip_extra 6`/`test_zip_builder 9`/`test_zip_fuzz 3`/`test_zip_aes 13`/`test_zip_go_parity 6`/`test_zip_perf 5`/`test_zip_stress 4`）+ `bench regression` 14项 `allocs+2` 硬预算 + `zip_roundtrip` 四守卫实测 PASS + `hygiene`/`diff --check` 通过。

**Truth level**：`source-contract + focused-runtime`（`core/docs/core-module-registry.md`）。下一步冲击 `ci-matrix`。

## 2. 剩余差距（领头羊体检）

| 维度 | 差距 | 影响 |
|------|------|------|
| 性能 | `ExtractToBytes` 仍经 `TBytes` 物化，大 Entry 峰值内存；`DecompressEntryVerified` 无 `PByte` 零拷贝直写 | M-4：大文件吞吐可再降 1 次分配 |
| 稳定性 | 顺序路径 AES 描述符仍 `ENotSupportedError`（Writer 可产 `descriptor+AES`，顺序读不支持） | S-424 小缺口 |
| 稳定性 | `CollectDescriptorPayload` 全缓冲 512MiB 硬门 + 64MiB* MaxOutput 双阈值，超大描述符条目需流式化 | M-3 |
| 完整性 | 顺序目录判定仅 `trailing /`，随机读另认 `S_IFDIR`/`S_IFLNK`；文档化但可进一步收敛 | M-2 已文档化，低优 |
| 复用 | `writer` `Emit*` 与 `common.LE*` 仍有轻度重复，`FScratch` 几何与 `EnsureWalkCapacity` 可统一样式 | 可复用收口 |
| 观测 | `bench_zip` `aes-extract/1MB` 高方差（CV 7-9%），需稳定化 | 性能门噪点 |
| 矩阵 | 仅 linux-x86_64 focused-runtime，缺 windows-x86_64 / darwin / musl 矩阵 | Truth level 升级 |

## 3. 终局路线图 S43—S50（每期独立可 Landing，12门+bench+hygiene 为硬门）

### S43 — 提取零拷贝（M-4 收口）· 性能
- **目标**：`IZipReader.ExtractToBytes` 保留兼容，新增 `ExtractTo` `PByte`/`IWriter` 零拷贝路径与 `CopyEntryTo` 复用，store 直过、`deflate` 经 `RawDeflate` 增量泵送，峰值内存恒定单条目压缩尺寸。
- **改动**：`common.DecompressEntryVerified` 增 `PByte` 重载（`AOut: PByte; AOutLen: SizeUInt`），`reader`/`sequential` 共享；`test_zip_perf` 新增 `1MiB PByte ≤8 allocs` 预算；`bench_zip` 新增 `extract-pbyte/1MB` 与 `copy-to/1MB` 两项（共 16项），基线刷新需人工审查。
- **验收**：`200×512B` allocs 不增，`1MiB` 4项 `≤12→≤8`，`bench regression` 全 OK，`test_zip_reader` 新增 `PByte vs TBytes` 字节一致用例。

### S44 — 顺序 AES 描述符打通 · 稳定性
- **目标**：顺序读支持 `AES+descriptor`（与 Writer `INV-15` 对偶），`CollectDescriptorPayload` 先集密文再经 `UnsealWinZipAesPayload` 校验，`MaxOutput` 预筛对解密后尺寸生效。
- **改动**：`sequential` 去 `ENotSupportedError` 分支，`TryDescriptorAt/NoSigAt` 增 AES 分支（先按 `AesStrength` 解帧再 CRC/试解压）；`test_zip_sequential` 新增 `AES descriptor store/deflate` 往返与 `python` 交叉（Go 不产 AES 描述符，仅 Python 验证）。
- **验收**：`S44` 前 `descriptor AES combo` 仅 `test_zip` 通过，`S44` 后顺序路径同过；`MaxOutput` 对 AES 明文尺寸同样 fail-closed。

### S45 — 描述符流式化与阈值可配（M-3 收口）· 稳定性/性能
- **目标**：`CollectDescriptorPayload` 从全缓冲改为 `IReader` 增量扫描 + `IBytesBuilder` 几何（已部分），阈值改由 `TZipReadOptions.MaxDescriptorBuffer`（默认 512MiB）显式可配，与 `MaxOutput/MaxTotal` 正交；超限 `EParseError('descriptor not found')` 报文不变。
- **改动**：`sequential` 引入 `FMaxDescriptorBuffer`，`512MiB` 硬门改为可配；`test_zip_stress` 新增 `descriptor 400MiB` 压力（仅长度，不实际分配 400MiB，以分块扫描验证）。
- **验收**：`70k Zip64` 不回退，`descriptor 512MiB` 边界用例稳定，`bench` `descriptor-pack/1MB` 不增 allocs。

### S46 — Central 目录流式与大目录常数内存（70k→700k 演进）· 性能
- **目标**：`reader` `ParseCentralDirectory` 对 `700k` 条目保持 `O(n)` 且 `allocs` 线性（当前 70k 已 `O(n)`，700k 仅验证）；`fs.ZipPackDirInto` `SortDirEntries` 迭代快排已就绪，`fs` `EnsureWalkCapacity` 已几何，本期聚焦 `reader` 中央 extra 解析的 `FScratch` 复用。
- **改动**：`reader` 复用 `writer` 同款 `FScratch` 几何（4096→2×），`extra` `Decode*` 保持栈上；`test_zip_stress` 扩展 `700k` 可选（CI 仅 70k，700k 为手工 `make stress-700k`）。
- **验收**：`70k` 1.07s 不回退，`700k` 可选门通过，`pack 200×512B` 815 预算不增。

### S47 — 模糊与双锚点扩容 · 完整性
- **目标**：`test_zip_fuzz` 从 30 fuzz 扩至 100 fuzz（含 `12/16/20/24` 描述符、`store/deflate`、`Zip64`、`AES`、`unicode`），`test_zip_go_parity` 保持 6 门 + 新增 `descriptor no-sig` Go 交叉（`go_helper` 扩展）。
- **改动**：`nextpas.core.test.fuzz` 复用，`go_helper` 增 `no-sig` 生成；`test_zip_perf` 保持阈值门，`test_zip_fuzz` 保持 3 门但迭代数提升。
- **验收**：`100 fuzz` 全过，双锚点一致；`bench` 不增，`hygiene` 通过。

### S48 — 文档与示例 cookbook 定版 · 高级感
- **目标**：`README` 增 `Cookbook`（`MaxOutput/MaxTotal` 防 bomb、`Descriptor` 流式、`PByte` 零拷贝、`Builder` 高级感链式、`StreamOutputTo` 常数内存）与 `Migration`（FPC `System`/`SysUtils`→`nextpas.core` 映射），`CONTRACT` 补 `INV-18`（PByte 零拷贝）与 `INV-19`（AES 描述符对偶）。
- **改动**：纯文档与示例；`zip_roundtrip` 增 `PByte` 与 `AES descriptor` 两小节演示，保持 `all demos ok`。
- **验收**：`test_zip_contract` 契约同步通过，`cargo` 无；文档即真实状态，无过时 `Production Ready`。

### S49 — 热路径微优与方差治理 · 性能
- **目标**：`crc32` `slice-by-8` 已优，`aes-extract` 方差治理（`MinSamples 5→7`、`MaxIterations 20→25`，`SetMinDuration 200ms→300ms`），`bench_zip` `aes-*` CV 降至 `<5%`；`writer` `EmitU*` inline 保持。
- **改动**：仅 `bench` 参数与 `crypto` 常量时间保持；`BASELINE.json` 刷新需人工审查，`check_regression.py` 阈值不变。
- **验收**：`bench regression` 无 `WARN` 噪点（`ns+50%` 内），`allocs` 不增。

### S50 — 安全审计与 Release Candidate · 领头羊封版
- **目标**：`focused-runtime` → `ci-matrix`（`linux-x86_64` + `linux-x86_64-musl` + `windows-x86_64` + `darwin-aarch64` 交叉编译验证，`wine` 可交互如 webview），`cargo vet` 无新增，`make verify` 全绿。
- **改动**：`core/tests/nextpas.core.zip` 12门在 `core/matrix`（如 `scripts/ci-matrix.sh`）复跑；`SECURITY.md` 增 `zip` 威胁模型（`zip-slip`/`bomb`/`CPU bomb`/`AES oracle` 四项）；`CHANGELOG` 1.0 RC，`VERSION` 冻结。
- **验收**：`make verify`（`rebuild-compiler`+`test` 全量）通过，`make hygiene` 通过，`git diff --check` 通过，`Ready` 达 `Landed` 标准。

## 4. 度量与硬门

| 度量 | 基线 | 目标 | 门 |
|------|------|------|----|
| `pack 200×512B` allocs | 810→805 | ≤815 / `Reserve` ≤810 | `test_zip_perf` + `bench regression` |
| `seq-extract-all 200×512B` allocs | 1804 | ≤1806 | 同上 |
| `1MiB` store/deflate | ≤12 | `PByte` 路径 ≤8（S43后） | 同上 |
| `70k Zip64` | 1.07s | ≤1.2s（700k 可选） | `test_zip_stress` |
| 双锚点 | 19期 | 100 fuzz 仍双向一致 | `test_zip_go_parity` + `python` |
| 安全 | INV-17 全覆盖 | `MaxOutput`+`MaxTotal` 入口+流中途双重 | `test_zip_reader` `Bomb`/`StoreBomb`/`TotalLimit` |
| 文档 | CONTRACT 1.34→1.38 | S50 时 `INV-19`、`ROADMAP`、`Cookbook` 同步 | `test_zip_contract` |

## 5. 发布标准（S50 封版即 `Landed`）

- 12门 `make focused` 全绿 `[HEAPTRC] OK`，`bench regression` `allocs+2/bytes` 硬门全 OK，`test_zip_go_parity` 与 `python zipfile` 双向一致仍显式失败于缺失而非静默跳过，`zip_roundtrip` `all demos ok`，`make hygiene` 与 `git diff --check` 通过，`make verify` 全量通过，`ci-matrix` 四靶标复跑通过，`SECURITY.md` 与 `CHANGELOG` 就绪。

## 6. 风险与对策

| 风险 | 对策 |
|------|------|
| `PByte` 重载与现有 `TBytes` 路径分叉导致语义漂移 | 共享 `GuardTotalOutputSize`/`DecompressEntryVerified` 内核，`test` 强制字节一致 |
| 无签名描述符误判（载荷内假结构） | 保留 `IsKnownZipSig` 次头部预检 + `LCSize==APos` + `CRC/试解压` 三重，`O(n·m)` 已在 S35 闭环 |
| 大 central 内存峰值 | `FScratch` 几何 + 单次分配条目数组，`700k` 仅手工门，CI 保持 70k |
| `aes-extract` 方差 | S49 提升样本与时长，`allocs` 为硬门、`ns` 仅告警，不阻塞封版 |

---

*执行纪律*：一期一 Landing，`landing/zip-Sxx` path-limited replay 进 `main`，`codex/core-zip` 及时 rebase；`main` 只总控 Landing，模块开发只在 `.worktrees/core-zip`。每期 `Ready` 含分支/worktree/HEAD/保留与禁止清单/12门+bench+hygiene 证据/merge 建议。

*基准规矩*：所有性能数据以 `nextpas.core.bench` `TBenchSuite` 为唯一口径（`SetMinDuration`/`MinSamples`/`MaxIterations`/`ACtx.SetBytes`/`PrintToConsole`/`ToBenchstat`/`SaveToJSON`），`CountingMemoryManager` 为 allocs 真值，`BASELINE.json` 人工审查后方可更新。

