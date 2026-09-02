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
| S61 | 错误归一（1.0.1 巡检）：未知压缩方法 parse 阶段即 `ENotSupportedError`，消除回落 `zmStore` 指纹混淆 |
| S62 | 复用与性能微抛光（1.0.1 巡检）：`extra.WriteLE*` PByte 单源、`base.IsSafe` 去 `inline` 减膨胀、`README` 性能段拆表留白 |
| S63 | 验证平台期（1.0.1 巡检）：12 门 `27/27/22/7/6/9/5/13/7/5/4` 全绿 + `extra 6` 补位，`HEAPTRC OK` + `hygiene` 完美 plateau 再证据 |
| S64 | 复用收敛 II（1.0.1 巡检）：`sequential.TryDescriptor` 双探针抽 `VerifyParsedValues` 单点，`common.GuardCursorRange/GuardRange` 收口 `reader.NeedRange*` 三重截断守卫 |
| S65 | 性能攻坚（1.0.1 巡检）：`checksum.crc32` slice-by-8（8 表并行，`1MiB` 校验 5× 提升，`123456789` 向量与全 fuzz 对照一致） |

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

### S60 — 文档一致性收敛（1.0.1 巡检）· 完整性 — 已落地
- `SECURITY 4→5` 同步、`CONTRACT §6` 增非原子/TOCTOU 与阈值正交局限、`registry zip` 补 `crypto/hash` 依赖，`test_zip_contract` 全绿

### S61 — 错误归一（1.0.1 巡检）· 稳定性 — 已落地
- 未知压缩方法在 `ParseCentralEntry`/`ParseCurrentLocal` 即 `ENotSupportedError`，消除回落 `zmStore` 后的 `EIOError` 指纹混淆

### S62 — 复用与性能微抛光（1.0.1 巡检）· 复用度/性能/高级感 — 已落地
- `extra.WriteLE*` PByte 单源收敛（`TBytes` 版薄委托 `WriteLE*Buf`）；`base.IsSafeZipEntryName` 去 `inline` 减长循环膨胀；`README` 性能段拆为覆盖/实现要点/门禁/历代收敛四段留白

### S63 — 验证平台期（1.0.1 巡检）· 完整性/稳定性 — 已落地
- 12 门全绿再验证：`test_zip 27` / `reader 27` / `sequential 22` / `fs 7` / `contract 6` / `extra 6` / `builder 9` / `fuzz 5` / `aes 13` / `go_parity 7` / `perf 5` / `stress 4`，`HEAPTRC OK` + `hygiene` 通过，完美 plateau 证据化

### S64 — 复用收敛 II（1.0.1 巡检）· 复用度/模块化 — 已落地
- `sequential.TryDescriptorAt/TryNoSigAt` 双探针 90% 重复抽 `VerifyParsedValues` 单点；`common.GuardCursorRange/GuardRange` 收口 `reader.NeedRangeIn/impl/source` 三重截断守卫，`reader/sequential` 共享校验语义

### S65 — 性能攻坚（1.0.1 巡检）· 性能 — 已落地
- `checksum.crc32` slice-by-8：8 表并行（`T[0..7]` 由 `T0` 递推 ` (C shr 8) xor T0[C & FF]`），`Crc32Update` 每 8 字节一次 8 路查表，余量回退单字节；`123456789 → CBF43926` 与 450 组 fuzz 及非对齐 50 字节对照全一致，`zip` `27/27/22` 与 `fuzz 5` 全绿

### S66 — TOCTOU 双重校验（1.0.1 巡检）· 稳定性 — 已落地
- `zip.fs` `TOCTOU` 加固：`ADestDir` 入口与 `MkdirAll` 后双 `EnsureNoSymlinkInPath`，每条目父目录 `MkdirAll` 后二次校验，落盘后对父路径与 `LFull` `IsSymlink` 非穿透校验，`MkdirAll` 目录落地后校验，`Symlink` 后校验，收口 `ZipExtractToDirWithOptions` 窗口

### S67 — 原子落盘（1.0.1 巡检）· 完整性/稳定性 — 已落地
- `zip.fs` `ZipExtractToDirAtomic*`：同文件系统 `TempDir(LParent,'.zip-atomic-')` + `ZipExtractToDirWithOptions` + `Rename` 原子提交，`ADestDir` 已存在则 `EArgumentError` 拒绝覆盖，异常时 `RemoveAll` 自动清理临时目录，`EnsureNoSymlinkInPath(LParent)` 前后双校验，`bomb/hostile` 触发时无残留，12 门全绿 `HEAPTRC OK`

### S68 — 文档一致性收敛（1.0.1 巡检）· 完整性 — 已落地
- `CONTRACT` §1/§6 同步 `Atomic*` API 与非原子/TOCTOU 已知局限（S66 双校验/S67 原子已提供），`README` 文件系统段补 `Atomic` 用法与双校验说明，`SECURITY` §5 同步双校验+原子防线与验证项，`ROADMAP` 文档门同步

### S69 — 原子硬化与官门固化（1.0.1 巡检）· 稳定性/完整性 — 已落地
- `zip.fs` `Atomic` 增 `Rename EXDEV` 回退：`Rename` 失败且 `!Exists(dest)` 时 `CopyTree(LTemp,dest)`+`RemoveAll(LTemp)`，`CopyTree` 异常则 `RemoveAll(dest)` 清理；`test_zip_fs` 10 门（新增 `Atomic roundtrip/refuses/bomb`），`HEAPTRC OK`

### S70 — 性能收敛（1.0.1 巡检）· 性能 — 已落地
- `zip.fs` `LDirs` 几何预留：`EnsureDeferredCapacity` 16 起步倍增，`LDirsCount` 分离容量与计数，`O(n²)` 逐条 `SetLength` 消除，70k 目录场景与 `Walk` 同构，`finally` 以 `LDirsCount` 逆序定稿

### S71 — 示例与文档完整性（1.0.1 巡检）· 完整性/高级感 — 已落地
- `README` Cookbook 补第 7 式原子落盘（`Atomic/WithOptions/EXDEV`），`zip_roundtrip` 增原子 `ok/refuse/bomb clean` 三演示 `all demos ok`，`ROADMAP` 文档门同步

### S72 — 复用收敛（1.0.1 巡检）· 复用度 — 已落地
- `zip.fs` 容量几何单点化：`CalcGrowCapacity(ACap,AMin)` 单源，双 `Ensure*Capacity` 薄委托 `CalcGrow`，消除 `Walk/LDirs` 双生 `while Result<AMin do Result*=2` 循环

### S73 — 稳定性纵深（1.0.1 巡检）· 稳定性 — 已落地
- `zip.fs` 原子落盘后二次校验：`Rename/CopyTree` 成功后 `IsSymlink(LDestTrim)` 非穿透 + `EnsureNoSymlinkInPath(LDestTrim)`，收口 `Rename→IsSymlink` 竞态窗口

### S74 — 完整性收口（1.0.1 巡检）· 完整性/稳定性 — 已落地
- `test_zip_fs` 10→12 门：新增 `Atomic permission restore` 与 `Atomic symlink policy`，原子路径 `RestoreMode/SkipSymlinks/MaxTotal` 透传与非原子对等，`HEAPTRC OK`

### S75 — 复用收敛（1.0.1 巡检）· 复用度/模块化 — 已落地
- `zip.fs` 父目录解析单点化：`ParentDirOf(APath)` 单源，`ZipExtractToDirWithOptions` 与 `Atomic` 双路径复用，消除 `LSep while` 重复，`LSep` 局部变量归零

### S76 — 版本封版（1.0.1 巡检）· 完整性 — 已落地
- `VERSION 1.0.0→1.0.1`，`CHANGELOG 1.0.1` 12 期巡检收敛（S64—S75）+ 封版，`ROADMAP` 当前状态同步 `1.0.1` 与 `12 门 10→12`

### S77 — 文档完整性（1.0.1 巡检）· 完整性/高级感 — 已落地
- `README` 路标行同步 `S0—S76 1.0.1` 与 `zip_roundtrip 7 式`，`ROADMAP` 状态行收口

### S78 — 稳定性收口（1.0.1 巡检）· 稳定性/复用度 — 已落地
- `zip.fs` `ParentDirOf` 根路径校正：`"/a"→"/"`（`LSep=1→'/'`），`"/"→"/"`，`LParent=''` 时 `MkdirAll` 免空操作，`Atomic` 同文件系统保证更精确

### S79 — 性能收敛（1.0.1 巡检）· 性能 — 已落地
- `zip.fs` `EnsureNoSymlinkInPath` 零分配重构：`SetLength(LPrefix, Len)` 预分配复用 + `Move`，单次堆分配替代每段 `Copy`，70k× 多段路径 `O(n)` 预检

### S80 — 最佳实践合入（1.0.1 巡检）· 完整性/复用度 — 已落地
- `path-limited replay` 落地 `landing/zip-1.0.1 → main 626cadf7e`：21 枚（P0—S79）重放至 `cebfb8cdc/8a5c029a1` 最新基线，保护 `core/src/nextpas.core.json` 未提交脏区，`rebase` 并发演进，`12 门 27/27/22/12 全绿 HEAPTRC OK` + `hygiene pass`，`zip/landing` 双 `current` 收口

### S81 — 六维打磨（1.0.1 巡检）· 性能/复用度/完整性 — 已落地
- `S81.1` CRC 基线固化：`BASELINE.json` 2026-09-02 刷新，`slice-by-8` 5× 提升已纳入 `read/1MB`；`S81.2` 复用收口：`base.NormalizeZipReadOptions` 单源，`reader/sequential` 去重 `if LMax=0`；`S81.3` `ROADMAP` S80 落地记录

### S82 — 治理收口（1.0.1 巡检）· 模块化/性能 — 已落地
- `bench` 可编译性：`core/src/nextpas.core.bench.baseline.pas` 补 `nextpas.core.json.value` 显式依赖，适配 `TJsonValueHelper.IsReal/IsInt/AsFloat` 新门面，`bench_zip` 16 项 `300ms/7/25` 全编译通过，`BASELINE.json` 2026-09-02T05:34:39 实跑刷新（`pack 810`/`reserve 805`/`read 10` 稳定）

### S83 — 文档与复用收口（1.0.1 巡检）· 完整性/复用度 — 已落地
- `CHANGELOG 1.0.1` 补 `S80—S82` 18 期收敛与 `Normalize`/`bench` 亮点；`CONTRACT` §1.2 增 `NormalizeZipReadOptions`；`README` 路标 `S0—S82` 同步；`base.TryZipMethodFromCode` 单源化 `reader/sequential` 的 `zmStore/zmDeflate` 映射，消除 `if LMethodCode=0/8` 重复

### S84 — 文档一致性与零堆栈验证（1.0.1 巡检）· 完整性/性能/复用度 — 已落地
- `CONTRACT` §1.2 补 `TryZipMethodFromCode`（S83 滞后 `Normalize/TryMethod` 双单源入约）；`README` 历代收敛补 `S81 Normalize / S83 TryMethod`、路标 `S0—S82 → S0—S83` 同步，`Normalize/TryMethod` 双单源闭环
- `writer` AES extra 零堆栈路径确认：`extra.EncodeWinZipAesExtraBody` 栈上 7 字节直写对偶 `Build*` 堆 wrapper，写端 `TWinZipAesSealer + Encode*` 走 `FScratch 64B` 几何复用零分配，`grep EncodeWinZip|BuildWinZip 7 hits / writer 6 hits` 验证
- `ROADMAP` S84 入档与 `CHANGELOG` S83—S84 亮点同步，12 门 + `bench 16 项` + `hygiene` 全绿回归

### S85 — AES 方法分发单源（1.0.1 巡检）· 复用度/模块化/稳定性 — 已落地
- `aes.ResolveZipMethodWithAes` 单源化 `reader.ParseCentralEntry` / `sequential.ParseCurrentLocal` 的 AES 校验与方法改写重复（`99 → realMethod` + 版本 1/2 + 强度 1..3 强校验 + `TryMethod`），2×25 行 → 2×1 行调用，`EParseError/ENotSupportedError` 语义守恒
- `aes` 接口层显式依赖 `zip.base`（`base ← aes` 有向无环），`reader/sequential` 薄委托单源，12 门 + `bench_zip` 可编译回归

### S86 — Local Header 走查单源（1.0.1 巡检）· 复用度/模块化 — 已落地
- `common.ParseLocalHeader` 单源化 `TZipReaderImpl.LocatePayload` / `TZipSourceReader.LocatePayload` 的本地头走查重复（签名+`version/flags/method/time/date/crc/size/nameLen/extraLen` 10 读 + 载荷偏移 `LLho+30+NameLen+ExtraLen`），2×12 行 → 2×1 行，`EParseError('bad local header signature')` 与 `NeedRange` 语义守恒
- `common` 为 `reader` 双读器共享校验内核（`GuardEntryReadable/GuardCursorRange/ParseLocalHeader`），冷路径零分配，12 门 + `bench_zip 221746` 可编译回归

### S87 — 缺口令守卫单源（1.0.1 巡检）· 复用度/稳定性 — 已落地
- `common.GuardEntryPassword` 单源化 `reader` 双 `OpenEntry` + `sequential` 的 `CollectDescriptorPayload/MakeDecompressedReader` 缺口令守卫重复（`IsEncrypted ∧ Password=∅ → EInvalidOperationError('zip: entry is encrypted, no password configured: '+Name)`），4×3 行 → 4×1 行，错误消息与 fail-closed 时序守恒
- `common` 为 `reader/sequential` 共享校验内核（`GuardEntryReadable/GuardEntryPassword/GuardTotalOutputSize/ParseLocalHeader`），冷路径零分配，12 门 + `bench_zip 221744` 可编译回归

### S88 — 越界守卫单源与平台期（1.0.1 巡检）· 复用度/稳定性 — 已落地
- `common.GuardZipIndex` 单源化 `TZipReaderImpl.CheckIndex` / `TZipSourceReader.CheckIndex` 越界守卫重复（`0 ≤ Index < Count → EIndexOutOfRangeError('zip: entry index out of range: '+Int)`），2×4 行 → 2×1 行 `inline`，`EIndexOutOfRangeError` 语义守恒
- `common` 为 `reader` 双形态共享校验内核（`GuardEntryReadable/GuardEntryPassword/GuardZipIndex/GuardTotalOutputSize/ParseLocalHeader`），冷路径 `inline` 零成本，12 门 + `bench_zip 221747` 可编译回归，`S85—S88` 四单源平台期证据化

### S89 — Find 单源与平台期（1.0.1 巡检）· 复用度/模块化 — 已落地
- `common.FindZipEntry` 单源化 `TZipReaderImpl.Find` / `TZipSourceReader.Find` 线性查找重复（`Name = AName → 首命中 Index / -1`），2×6 行 → 2×1 行 `inline`，首命中语义守恒，`common` 为 `reader` 双形态共享查找内核，12 门 + `bench_zip 221757` 可编译回归，`S85—S89` 五单源平台期

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
| 文档 | `CONTRACT 1.39` + `SECURITY` | 同步 |

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

*当前状态*：`1.0.1 @ 1.0.1`（S64—S89 收敛），`VERSION 1.0.1`，`12 门` `10→12`（原子选项透传），`zip_roundtrip 7 式` `all demos ok`，`main 0dfb25e` 已落地，`bench 16 项` 可编译，`Normalize/TryMethod/ResolveWithAes/ParseLocalHeader/GuardPassword/GuardIndex/FindEntry` 七单源 + AES 零堆栈。
