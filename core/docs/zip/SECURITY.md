# nextpas.core.zip SECURITY — 威胁模型与 Fail-Closed

本文档描述 `nextpas.core.zip` 的五项核心威胁模型与对应 fail-closed 语义，构成 `1.0 RC` 安全基线。所有边界输入均视为敌意，任何违反即 `EParseError/EIOError/ENotSupported` 显式失败，不静默。

## 1. Zip-Slip（路径穿越）

- **威胁**：归档内 `../`、`//`、`/absolute`、`\`、`C:` 等敌意条目名导致解包写入沙箱外。
- **防线**：`IsSafeZipEntryName` 在写端入参即拒、读端 `GuardEntryReadable` 与 `fs.ZipExtractToDir*` 落盘前二次校验，尾随 `/` 目录除外（INV-4）。`MaxOutput*` 不参与路径校验，路径与尺寸正交。
- **验证**：`test_zip_reader:Unsafe name refused`、`test_zip_fs:unsafe`、`test_zip_contract:No FPC RTL`。

## 2. Zip-Bomb（解压炸弹）

- **威胁**：单条目声明 `UncompressedSize` 巨大或 `100k × 1MiB` 小条目绕过单条目上限，内存/磁盘耗尽。
- **防线**：`TZipReadOptions.MaxOutputSize` 单条目入口+流中途双重拦截（`store` 在 `DecompressEntryVerified` 直比，`deflate` 在 `RawDeflate` 泵送中途 `FCap` 校验，INV-8/11）；`MaxTotalOutputSize` 跨条目增量累计（随机读 `GuardTotalOutputSize` 解析结束溢出安全求和，顺序读 `Next` 归一后累计，fs 透传，INV-17），任一超限 `EIOError('zip: ... exceeds limit')`，`bytes` 声明不参与正确性判定，仅作预分配提示（压缩比上界 `压缩尺寸×16+64KB`）。
- **阈值**：默认 `MaxOutput 1 GiB`、`MaxTotal 0=不限`，调用方按容器显式收紧（Cookbook 1）。
- **验证**：`test_zip_reader:Bomb guard/Store bomb/Total limit`、`test_zip_sequential:MaxOutput/Total`、`test_zip_perf:200×512B ≤815 allocs`、`zip_roundtrip` 三路径 guard 演示。

## 3. CPU Bomb（`O(n·m)` 试解压）

- **威胁**：描述符载荷内假结构（`LCSize==APos` 假阳性）触发每字节试解压，`O(n·m)` 耗尽 CPU。
- **防线**：`CollectDescriptorPayload` 三重：`LCSize==APos` 预筛 + `CRC/试解压` 强校验 + `IsKnownZipSig` 下一条目签名预检（35期先验再试解），`12/16/20/24` 四形态均覆盖（42期），`AES+descriptor` 先 `Unseal` 再校验（44期），`MaxDescriptorBuffer` 默认 512MiB 可配且与 `MaxOutput/MaxTotal` 正交（45期）。
- **验证**：`test_zip_sequential:Descriptor four morphs`、`test_zip_fuzz:descriptor 150组`、`test_zip_go_parity:no-sig`、`bench seq-read` 方差门。

## 4. AES Oracle（口令/认证码侧信道）

- **威胁**：通过区分 `口令校验值失败` 与 `认证码失败` 的报文/时延，构成口令猜测 oracle。
- **防线**：WinZip AE-2 统一报文 `EParseError('zip aes: authentication failed')`，`PBKDF2 1000轮` 派生 `encKey/authKey/pwVerify`，`pwVerify` 与 `HMAC-SHA1-80` 常量时间比对，失败不泄露分支（INV-14）；`AE-1` 保留真实 CRC 走常规校验，`AE-2` 头部 CRC 强制 0 依赖认证码；`缺口令` `EInvalidOperationError` 早拒，避免异常穿越持接口帧；`x86_64 AES-NI` 硬件加速与常时序回退。
- **验证**：`test_zip_aes:13`（AE-1/2、强度1..3、tamper 统一报文、缺口令）、`test_zip_fuzz:AES 100组`、`bench aes-*`。

## 5. Symlink Traversal（符号链接穿越）

- **威胁**：归档内符号链接条目目标为 `/absolute`、`C:`、`..`、`//` 或含反斜杠，配合 `ZipExtractToDir*` 的 `MkdirAll` 逐段跟随已存在的目录符号链接，可使后续文件落盘至沙箱外（zip-slip bypass）。
- **防线**：`MkdirAll`（`platform_fs_mkdir_p`）逐段 `lstat` 不跟随：每段前缀若为 `ftSymlink` 即 `ENOTDIR` 失败，不穿透；`ZipExtractToDirWithOptions` 在 `ADestDir` 与每个 `LParent` 落盘前 `EnsureNoSymlinkInPath` 二次校验（`IsSymlink` 不跟随）；`SkipSymlinks=False` 的符号链接创建前 `IsSafeSymlinkTarget` 拒绝绝对路径/盘符/反斜杠/空段/`..`/超长4096（INV-4 段规则复用，零分配扫描）。目录符号链接与目标穿越双重闭合。
- **非原子语义**：解包非原子，已落盘文件不回滚；`try..finally` 保证异常时已收集的 `LDirs` 仍逆序定稿（`Chmod`/`Chtimes` 尽力，异常吞掉），需外层整体清理或改用 `ZipExtractToDirWithOptions` 的临时目录+rename 原子变体（待提供，见 `ZipExtractToDir` 双重载：`SizeUInt` 便捷与 `TZipExtractOptions` 完整语义）。
- **验证**：`test_zip_fs:Symlink policy + hostlie + IsSafeSymlinkTarget`（新增 `IsSafeSymlinkTarget` 单元与路径 symlink 注入用例）、`platform_fs:mkdir_p symlink`。

## 6. 报告与处置

- 发现新的 zip 威胁向量，请在 `core/docs/zip/CONTRACT.md` 增 `INV-*` 并同步 `test_zip_contract` 门与本文件，禁止静默放宽上限。
- 所有安全边界变更需 `12门+bench regression+hygiene` 全绿且 `BASELINE` 人工审查后方可 `make baseline` 刷新。
