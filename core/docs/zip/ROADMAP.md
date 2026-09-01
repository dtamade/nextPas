# nextpas.core.zip 终局路线图 — 领头羊标准（1.0.0 Final）

> **愿景**：`nextpas.core.zip` 成为 Pascal AI 时代 ZIP 容器的领头羊实现 — 以 `nextpas.core.bench` 为唯一基准尺，零分配、可复用、强稳定、完全体，跨 Python `zipfile` 与 Go `archive/zip` 双锚点字节级一致，任何标准解压器可读，我们产出的归档可被任何标准解压器还原。

> **原则**：性能（零分配、几何预留、零拷贝）、高级感（Fluent Builder、确定性输出、字节级一致）、复用度（`common`/`extra`/`builder` 单点内核）、稳定性（`MaxOutput`/`MaxTotal` 双守卫、`IsKnownZipSig` 预筛、fail-closed）、完整性（store/deflate/Zip64/AES/描述符四形态/顺序流全覆盖）。标准很高、很严格。

## 1. 现状基线（S0—S50 已落地，1.0.0 Final）

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
| S40 | 示例与契约定版：`zip_roundtrip` 补 `MaxOutput/MaxTotal` 三路径 fail-closed 全演示 |
| S41 | 顺序读零拷贝：`TSeqSliceReader` 去 `Copy` 双重拷贝、`PushBack` 去 `Copy`，`seq-extract-all 2005→1804` |
| S42 | 描述符无签名兼容：`CollectDescriptorPayload` 支持 `12/16/20/24` 四形态 |
| S43 | 提取零拷贝：`ExtractToBuffer` PByte 直写 `RawDeflateDecompressToBuffer`，`bench 16项` |
| S44 | 顺序 AES 描述符打通：`AES+descriptor` 先集密文再 `Unseal` |
| S45 | 描述符阈值可配：`MaxDescriptorBuffer` 默认 512MiB 可配 |
| S46 | 中央目录零分配：`ReadSpan+DecodeCentralExtraBuf` 直通，`open/parse-CD 4004→2004 allocs` |
| S47 | 模糊与双锚点扩容：`450组fuzz` + `Go 7门` 含 `12/16/20/24` 与 `no-sig` |
| S48 | Cookbook 定版：`README` 6式与 `Migration`，`zip_roundtrip` 增 `PByte/AES-desc` |
| S49 | 方差治理：`300ms/7/25` 使 `aes-*` CV `<5%` 无 WARN |
| S50 | 安全审计与 RC：`SECURITY.md` 五模型，`1.0.0-rc.1` 冻结 |
| S51 | 单源与纯化收敛（1.0.1 巡检）：`IsSafe inline + common DOS 委托 base 去 time.date`、`compress 5 one-shot 纯 Pas 兜底` |
| S52 | 注册表完整性：`module-registry` 增 `zip/zlib` L2 条目，12门+双锚点+bench 单源收敛 |
| S53 | 常量化收敛：`C_DOS_MIN/MAX_UNIX` 常量去 `TDate` 构造，`DosMinUnixSec` inline 常量返回 |
| S54 | 验证平台期：三门全绿 `27/32/30` 验证，无新增债务，完美 plateau 证据 |
| S55 | 对称补齐：`DosMaxUnixSec` 对称暴露，`base/common` 双 `inline` 单源 |
| S56 | 回归修复：`C_DOS_MIN/MAX` 常量化还原 + `DosDateTimeFromUnix` 零构造 |
| S57 | 尾隙收敛：`UnixFromDosDateTime` 去 `Create` 验证，`FromUnixDays` 单源回退 |
| S58 | 委托对称：`zip.common` 时间委托四子 `inline` 零成本 |
| S59 | 984合流验证：三门全绿再验证 + 113/r9 基线对齐 |
| S60 | 文档一致性收敛（1.0.1 巡检）：`SECURITY 4→5` 同步、`CONTRACT §6` 增非原子/TOCTOU 已知局限、`registry zip` 补 `crypto/hash` 依赖 |

**Truth level**：`ci-matrix`（`1.0.0 Final`，`VERSION 1.0.0`）。

## 2. 剩余差距（1.0.0 后巡检项）

| 维度 | 差距 | 状态 |
|------|------|------|
| 性能 | `700k Zip64` 定时预检（CI 仅 70k，700k 手工 `make stress-700k`） | 巡检 |
| 稳定性 | `顺序目录判定` 仅 `trailing /` vs `S_IFDIR` 已文档化 | 接受 |
| 观测 | `bench` 已 `300ms/7/25` 治理，`CV <5%` | 完成 |

## 3. 终局路线图 S43—S50（已全部 Landed，1.0.0 归档）

### S43 — 提取零拷贝（M-4 收口）· 性能 — 已落地
- `ExtractToBuffer` PByte 直写，无 `TBytes` 物化；`bench 16项` 基准刷新

### S44 — 顺序 AES 描述符打通 · 稳定性 — 已落地
- `AES+descriptor` 对偶，`MaxOutput` 对明文预筛

### S45 — 描述符流式化与阈值可配（M-3 收口）· 已落地
- `MaxDescriptorBuffer` 512MiB 可配，与 `MaxTotal` 正交

### S46 — Central 目录流式与大目录常数内存 · 性能 — 已落地
- `ReadSpan` 零分配，`open/parse-CD` 减半

### S47 — 模糊与双锚点扩容 · 完整性 — 已落地
- `450组` + `no-sig` 双向对等

### S48 — 文档与示例 cookbook 定版 · 高级感 — 已落地
- `Cookbook 6式` + `Migration`，`zip_roundtrip` 双小节

### S49 — 热路径微优与方差治理 · 性能 — 已落地
- `300ms/7/25`，`CV <5%`

### S50 — 安全审计与 Release Candidate · 已落地
- `SECURITY.md` 五模型，`1.0.0-rc.1` → `1.0.0 Final`

### S51 — 单源与纯化收敛（1.0.1 巡检）· 模块化/性能/复用度 — 已落地
- `zip.base IsSafe inline` 热路径可内联；`zip.common DOS 28行去重委托 base 单源`，移除 `time.date`；`compress.deflate 5 one-shot 纯 Pas 兜底（zbAuto）`，无 `libz.so` 可移植

### S52 — 注册表完整性（1.0.1 巡检）· 完整性 — 已落地
- `module-registry` 增 `zip/zlib` L2 条目，12门+双锚点+bench 完整性闭环

### S53 — 常量化收敛（1.0.1 巡检）· 性能 — 已落地
- `C_DOS_MIN/MAX_UNIX` 常量（315532800/4354819199）去 `TDate.Create` 构造，`DosDateTimeFromUnix` 钳制零分配，`DosMinUnixSec` inline 常量返回

### S54 — 验证平台期（1.0.1 巡检）· 稳定性 — 已落地
- 三门全绿 `27/32/30` 验证，无新增债务，完美 plateau 证据化

### S55 — 对称补齐（1.0.1 巡检）· 模块化/完整性 — 已落地
- `DosMaxUnixSec` 对称暴露，`base/common` 双 `inline` 单源，`C_DOS_MAX_UNIX` 常量复用，边界契约对称闭环

### S56 — 回归修复与常量化再收敛（1.0.1 巡检）· 性能/模块化 — 已落地
- 主线合入导致 `C_DOS_MIN/MAX_UNIX` 常量化回退，`DosDateTimeFromUnix` 重回 `TDate.Create` 构造；本期在隔离 worktree 中零 TDate 构造还原，`DosMin/MaxUnixSec` 双 `inline` 常量返回，`common` 委托 `inline` 对称，三门全绿回归

### S57 — 尾隙零验证收敛（1.0.1 巡检）· 性能/稳定性 — 已落地
- `UnixFromDosDateTime` 失效回退 `TDate.Create` 去验证，改 `FromUnixDays(C_DOS_MIN_UNIX div 86400)` 单源零构造，与 `DosDateTimeFromUnix` 常量化对偶，`base` 全链路零 `Create`，三门全绿

### S58 — 委托对称零成本（1.0.1 巡检）· 性能/模块化 — 已落地
- `zip.common` 时间委托四子 `DosDateTime/UnixFromDos/DosMin/DosMax` 全 `inline` 零成本，与 `base` 常量化对偶，`common` 委托链路对称闭环，三门全绿

### S59 — 984合流验证平台期（1.0.1 巡检）· 稳定性/完整性 — 已落地
- `984e2df` 113/r9 合流后基线对齐验证：`zip` `27/32/30` 三门全绿 + `math` 轸断再修复，`ROADMAP` `S58` 回补，完美 plateau 证据化

## 4. 度量与硬门（1.0.0 冻结）

| 度量 | 基线 | 门 |
|------|------|----|
| `pack 200×512B` allocs | 810 | ≤815 / `Reserve` ≤810 |
| `seq-extract-all 200×512B` allocs | 1804 | ≤1806 |
| `1MiB` store/deflate `PByte` | 7 | ≤8 |
| `open/parse-CD` allocs | 2004 | ≤2006 |
| `70k Zip64` | 1.07s | ≤1.2s（700k 可选） |
| 双锚点 | 7门 + `450 fuzz` | 全过 |
| 安全 | `INV-16/17/18/19` | `Bomb/CPU/AES` 全覆盖 |
| 文档 | `CONTRACT 1.38` + `SECURITY` | 同步 |

## 5. 发布标准（1.0.0 Final）

- 12门 `HEAPTRC OK`，`bench regression` 全 OK，`test_zip_go_parity` 与 `python` 双向一致，`zip_roundtrip all demos ok`，`hygiene/diff --check` 通过，`ci-matrix` 复跑通过，`SECURITY/CHANGELOG/VERSION` 就绪 — 已全部满足。

## 6. 风险与对策（归档）

| 风险 | 对策 | 状态 |
|------|------|------|
| `PByte` 语义漂移 | 共享内核 + 字节一致测试 | 已闭环 |
| 无签名误判 | `IsKnownSig` + 三重校验 | 已闭环 |
| 大 central 峰值 | `FScratch` 几何 + 单次数组 | 已闭环 |
| `aes-extract` 方差 | `300ms/7/25` | 已闭环 |

---

*执行纪律*：一期一 Landing，`landing/zip-Sxx` path-limited replay 进 `main`，`codex/core-zip` 及时 rebase；每期 `Ready` 含分支/worktree/HEAD/保留与禁止清单/12门+bench+hygiene 证据。

*基准规矩*：所有性能数据以 `nextpas.core.bench` `TBenchSuite` 为唯一口径，`CountingMemoryManager` 为真值，`BASELINE.json` 人工审查后方可更新。

*当前状态*：`1.0.0 Final @ 7c19495d0`，`VERSION 1.0.0`，后续为 `1.0.1+` 巡检。
