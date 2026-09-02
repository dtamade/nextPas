# nextpas.core.zip CONTRACT

本文档描述 `nextpas.core.zip` 的公共契约。改动公共 API、错误语义或
生命周期行为时必须同步更新本文件与 `test_zip` / `test_zip_reader` /
`test_zip_fs` / `test_zip_contract` 门。

## 1. 公共 API 面

### 1.1 类型

| 类型 | 说明 |
|------|------|
| `TZipMethod = (zmStore, zmDeflate)` | 已知压缩方法；未知方法码保持 `zmStore`，看 `MethodCode` |
| `TZipEntryInfo` | central directory 条目元数据；尺寸/偏移为 UInt64（Zip64 宽度）；含 `ExternalAttrs` 原值与 `IsSymlink` 判定；加密条目另有 `IsEncrypted` / `AesVersion`（1=AE-1，2=AE-2）/ `AesStrengthCode`，`MethodCode` 为解密后的真实压缩方法 |
| `TZipWriteOptions` | `ForceZip64: Boolean`——无条件产出 Zip64 结构 |
| `TZipAddOptions` | 单条目完整选项：`Method` / `ModTimeUnixSec`（<0 取 DOS 下限）/ `Mode`（unix 模式字，0 取默认）/ `Password`（非空走 WinZip AE-2 加密，INV-14）/ `AesStrength`（1/2/3 = AES-128/192/256，0 取 3）/ `DataDescriptor`（仅 `AddEntryStream` 生效，INV-15） |
| `TZipReadOptions` | `MaxOutputSize: SizeUInt`——单条目解压上限，0 取默认 1 GiB；`MaxTotalOutputSize: UInt64`——跨条目总输出上限，0=不限（INV-17）；`MaxDescriptorBuffer: SizeUInt`——顺序读描述符扫描缓冲上限，0 取 512MiB（INV-16）；`Password`——WinZip AES 解密口令（INV-14） |
| `TZipExtractOptions` | fs 解包选项：`RestoreMode` / `SkipSymlinks` / `MaxOutputSize` / `MaxTotalOutputSize` |
| `IZipBuilder` | 链式构造器：`Add`/`AddDeflate`/`AddWithTime`/`AddDeflateWithTime`/`AddWithOptions`/`AddDirectory`/`AddDirectoryWithTime`/`AddEntryStream`/`Reserve`/`StreamTo`/`Finish`/`FinishTo` 薄委托 `IZipWriter`（三十一—三十二期对称完备） |

### 1.2 工厂函数

| 函数 | 说明 |
|------|------|
| `NewZipWriter` / `NewZipWriterWithOptions` | 写器；顺序追加、一次性 Finish |
| `NewZipReader` / `NewZipReaderWithOptions` | 读器；构造时解析 central directory，非法结构立即 raise |
| `NewZipReaderFrom` / `NewZipReaderFromWithOptions` | 从可定位流打开：经 IReaderAt 定位读按需取数（EOCD/central/条目载荷），不整体载入、不改写调用方流位置；源须同时实现 IStream 与 IReaderAt，否则 ENotSupportedError；多条目流可并发打开 |
| `NewZipSequentialReader` / `NewZipSequentialReaderWithOptions` | 从纯顺序流打开：仅靠 local header + data descriptor 前进，不整载、不要求 seek，与七期描述符写端对偶；源为任意 IReader（HTTP body/管道）；一次仅一流，MaxOutputSize/MaxTotal/MaxDescriptorBuffer 与口令语义与读端一致 |
| `DefaultZipWriteOptions` / `DefaultZipAddOptions` / `DefaultZipReadOptions` / `DefaultZipExtractOptions` | 各选项默认值 |
| `NormalizeZipReadOptions` | 读选项归一（`0→默认`，`MaxOutput/MaxDescriptor` 单源，S81） |
| `TryZipMethodFromCode` | 方法码→`TZipMethod` 归一（`0/8` 映射，`reader/sequential` 单源，S83） |
| `ResolveZipMethodWithAes` | AES 感知的方法分发（`99 → realMethod` + 版本/强度强校验，`reader/sequential` 单源，S85） |
| `GuardTotalOutputAdvance` | 总量溢出安全推进（`ACum+Size>Max → EZipLimitError`，`common` 单源，S90） |
| `ZipPumpReader` | 泵送循环单源（`65KiB分块Read/Write→Close`，`reader` 双形态+`sequential` 三路泵，S91—S92） |
| `ZipWrapEntryReader` | 解压管道单源（`AES解帧→inflate→Verify`，`reader` 双 `OpenEntry`，S93） |
| `ZipPackDirInto` / `ZipPackDir` | 目录递归打包（携带 mtime 与 posix 权限位） |
| `ZipExtractToDirWithOptions` / `ZipExtractToDir` | 解包到目录（非原子，见 §6） |
| `ZipExtractToDirAtomicWithOptions` / `ZipExtractToDirAtomic` | 原子解包到目录：同文件系统 `TempDir`+`Rename` 原子提交，`Exists`拒绝覆盖，异常自动清理（S67） |
| `ZipBuilder` / `ZipBuilderForceZip64` / `NewZipBuilder*` | 链式构造器工厂（委托 `NewZipWriter*`，字节级一致，高级感 API） |
| `ZipUnixModeOf` / `ZipRegularMode` / `ZipDirectoryMode` | unix 模式字助手（zip.base） |

### 1.3 写器方法

| 方法 | 说明 |
|------|------|
| `AddEntry(Name, Data)` | store 条目；时间戳取 DOS 纪元下限（确定性输出） |
| `AddEntryWithTime(Name, Data, UnixSec)` | store 条目，显式时间戳（越界钳制到 DOS 区间） |
| `AddEntryDeflate(Name, Data)` | method=8；载荷经 compress.RawDeflate (RFC 1951) |
| `AddEntryDeflateWithTime(...)` | 同上 + 显式时间戳 |
| `AddDirectory(Name)` / `AddDirectoryWithTime(...)` | 目录条目；名字规范化补尾随 `/`；查找需用规范化名 |
| `AddEntryWithOptions(Name, Data, TZipAddOptions)` | 方法/时间戳/模式字一次给定；模式字声明目录（$4000）时补尾随 `/` 并置 MS-DOS 位 $10 |
| `AddEntryStream(Name, TZipAddOptions): ICompressWriter` | 流式添加：返回推式写入端（`nextpas.core.compress.intf` 家族），增量 CRC32 + 按 Method 压缩；`Close` 定稿条目；默认内存上界为单条目压缩尺寸，`DataDescriptor` 开启后降到常数级（INV-15）；放弃未 Close 的流则条目不落入归档（描述符直写路径改为 Finish fail-closed）；存在未关闭流时 `Finish` raise |
| `StreamOutputTo(IWriter)` | 绑定流式输出端：分块排空已暂存字节，此后逐条目透传（内存上界为单条目压缩尺寸）；仅允许绑定一次，重复绑定 raise；绑定后 `Finish` 拒绝，终结经 `FinishTo(同一 sink)` |
| `FinishTo(IWriter): UInt64` | 终结并把完整归档直写 sink，返回写入总字节数；未绑定时自动绑定。产出与缓冲式 `Finish` 字节级一致；nil sink / 异源 sink / 未关闭条目流 raise |
| `EntryCount` | 已添加条目数 |
| `Reserve(ACapacity)` | 预分配条目容量（几何扩容一次性到位，无重分配；0 空操作，<0 `EArgumentError`，Finish 后 `EInvalidOperationError`） |
| `Finish: TBytes` | 终结并返回完整归档；此后任何添加/再次 Finish raise |

### 1.3.1 链式构造器（Fluent Builder）

`IZipBuilder` 为 `IZipWriter` 的薄链式门面（`nextpas.core.zip.builder`），链式方法 `Add`/`AddDeflate`/`AddWithTime`/`AddDeflateWithTime`/`AddWithOptions`/`AddDirectory`/`AddDirectoryWithTime`/`Reserve`/`StreamTo` 均返回 `Self`；`AddEntryStream` 直通写器流式条目（语义与 `IZipWriter.AddEntryStream` 一致，含 `DataDescriptor` 直写与 fail-closed）；`Finish`/`FinishTo`/`EntryCount` 委托写器语义，`ZipBuilder`/`ZipBuilderForceZip64` 为便捷工厂，字节形态与直接写器全等（`Reserve` 亦链式，额外开销仅 Builder 对象本身 1 alloc）。

### 1.4 读器方法

| 方法 | 说明 |
|------|------|
| `EntryCount` / `Entry(Index)` | 元数据随机访问；越界 raise |
| `Find(Name): Integer` | 按名查找；缺失 -1；重名取首个 |
| `ExtractToBytes(Index)` | 提取并强制 CRC32/尺寸校验；目录条目返回空字节 |
| `ExtractToBytesByName(Name)` | 同上按名；缺失 raise ENotFoundError |
| `OpenEntry(Index) / OpenEntryByName(Name): IDecompressReader` | 流式打开：pull 式增量解压不物化输出；读到 EOF（返回 0）时强制尺寸+CRC32 校验；可同读器多流并发；EOF 前放弃则跳过校验 |
| `CopyEntryTo(Index, IWriter): SizeUInt` | 泵送整条目到任意写端，EOF 处校验，返回输出字节数 |
| `ExtractToBuffer(Index, PByte, SizeUInt): SizeUInt` / `ExtractToBufferByName` | 零拷贝直写 PByte 缓冲（INV-18）：不分配 TBytes，直接解压到 `ADst[0..ABufLen-1]`，返回实解字节数；`ABufLen` 不足/尺寸/CRC/MaxOutput 均 fail-closed；目录条目返回 0 |

### 1.5 顺序读器方法

| 方法 | 说明 |
|------|------|
| `Next(out Info: TZipEntryInfo): Boolean` | 推进到下一条目；True 携带当前条目元数据（描述符条目在 Next 时已通过 descriptor 强校验并回填真实尺寸/CRC），False 表示已到 central/EOCD；截断/签名错 raise EParseError |
| `Current: TZipEntryInfo` / `EntryIndex: Integer` / `AtEnd: Boolean` | 当前条目视图与迭代状态 |
| `Open: IDecompressReader` | 打开当前条目流（拉式，读到 0 为 EOF）；一次仅一流，重复打开或未 Next 时 raise EInvalidOperationError；MaxOutputSize 与口令语义与读端一致 |
| `CopyTo(IWriter): SizeUInt` | 泵送当前条目到任意写端，EOF 处校验，返回输出字节数 |
| `Skip` | 跳过当前条目载荷（不解压，直接丢弃 descriptor/载荷）；未 Next 或已打开流时 raise |

## 2. 不变量

- **[INV-1]** CRC32 永远针对未压缩载荷计算与校验（store 与 deflate 一致）。
- **[INV-2]** 提取时校验 local header 签名、解压尺寸与 CRC32，任一不符即 raise。
- **[INV-3]** 未显式指定时间戳的输出字节级确定（同输入同归档，除 deflate 载荷
  受宿主 zlib 版本影响外）。
- **[INV-4]** 敌意条目名（空名/绝对路径/盘符/反斜杠/`//` 空段/`./` 单点段/`..` 段）在写端拒绝入参、
  在读端提取与落盘前以 EParseError 拒绝（尾随 `/` 的目录终段空除外）。
- **[INV-5]** 遗留 ZipCrypto（flag bit 0 且无有效 0x9901 extra）、未知压缩
  方法、多盘归档 → ENotSupportedError；WinZip AES 条目按 INV-14 放行。
- **[INV-6]** Zip64：尺寸/偏移超 ZIP32 宽度或条目数超 65535 时自动启用；
  ForceZip64 无条件启用。central 布局固定为 [固定字段][名字][extra][注释]。
- **[INV-7]** data descriptor 读端容忍：本地头 flag bit3 置位的流式归档按
  central 权威值提取（本地 crc/尺寸为占位值不影响结果）。写端默认仍不
  产出描述符；`TZipAddOptions.DataDescriptor` 显式开启时按 INV-15 产出。
- **[INV-8]** 提取预分配以 central 声明尺寸为容量提示：`deflate` 对敌意声明
  施加压缩比上界（压缩尺寸×16+64KB），`store` 在 `common.DecompressEntryVerified` 层直比 `UncompressedSize` 与 `MaxOutputSize`（34期 store bomb 已闭环）；两者硬上限均为 `MaxOutputSize`，声明值不参与正确性判定（实际输出仍强制校验）。
- **[INV-9]** 权限还原仅对 unix 归档（外部属性高 16 位模式字非零）生效；
  目录的权限与 mtime 在全部内容落盘后逆序定稿。
- **[INV-10]** 符号链接条目默认跳过；SkipSymlinks=False 为显式 opt-in 保真创建。
- **[INV-11]** 流式契约：写端 `AddEntryStream` 增量计算 CRC32 与压缩输出，
  内存上界为单条目压缩尺寸，`Close` 定稿、析构兜底为放弃（暂存路径条目
  排除；描述符直写路径见 INV-15 fail-closed）；
  读端 `OpenEntry*` 在读到 EOF 时强制尺寸+CRC32 校验，EOF 前放弃跳过校验；
  `MaxOutputSize` 对 `store`/`deflate` 两路径在入口（`common` 层）与流中途均生效（34期 store bomb 入口守卫）。
- **[INV-12]** 归档流式输出契约：`StreamOutputTo` 绑定后逐条目透传（绑定
  前暂存字节先按 ≤256 KiB 分块排空），内存上界为单条目压缩尺寸；
  `FinishTo` 与缓冲式 `Finish` 字节级一致（同一 Emit 序列化路径的结构保证，
  测试以 store/deflate/目录/选项模式字/unicode 名/ForceZip64/条目流全场景
  断言）；sink 短写交付 `EIOError`，sink 抛出的异常原样传播，失败后归档
  不完整，写器应整体弃用。
- **[INV-13]** 可定位流来源契约：`NewZipReaderFrom*` 全程经 IReaderAt 定位
  读按需取数——调用方流位置不被改写，多条目流可并发打开（各自持独立区
  间游标）；源须同时实现 IStream 与 IReaderAt，缺失定位读即 fail-closed；
  MaxOutputSize 对提取与流式两条路径同样生效；EOF 处尺寸+CRC32 强制校验
  与 INV-11 一致。
- **[INV-14]** WinZip AES 加密条目契约：写端仅产出 AE-2（wire 方法 99 +
  0x9901 extra + flag bit0，头部 CRC 置 0，压缩后加密，帧 = salt+口令校验
  值+AES-CTR 密文+10 字节 HMAC-SHA1 认证码；密钥 PBKDF2-HMAC-SHA1 1000 轮
  派生 encKey+authKey+pwVerify；盐取安全随机，同输入不再字节级确定）。
  读端同时接受 AE-1（保留真实 CRC32，走常规 CRC 校验）与 AE-2（头部 CRC
  必须为 0，完整性由认证码保证）；口令校验值与认证码在解密前强校验且
  失败报文统一（不泄露失败点 oracle），常量时间比对；缺口令
  EInvalidOperationError；遗留 ZipCrypto 按 INV-5 拒绝。x86_64 且 CPU 支持
  时 CTR 块加密走 AES-NI（128/256 位密钥），其余走常数时间实现（含 192）。
- **[INV-15]** 描述符直写契约：仅 `AddEntryStream` + `DataDescriptor=True`
  生效。开形态 local header（bit3 + CRC=0 + 尺寸字段/zip64 extra 零占位，
  版本 ≥45，加密再抬到 51）立即落盘，压缩字节经 Emit 路由直通输出管道
  （可选 `TWinZipAesSealer` 增量封框），`Close` 紧贴数据补发描述符
  （签名 `$08074B50` + crc + 尺寸；任一尺寸超 ZIP32 则成对走 64 位）。
  描述符条目期间强制串行化（`AddEntry*` / `AddEntryStream` /
  `StreamOutputTo` 一律 `EInvalidOperationError`）。放弃未 Close 的描述符
  流会在输出中留下孤儿字节，`Finish` / `FinishTo` fail-closed
  （`descriptor entry abandoned`）。central flags 镜像 bit3；AE-2 描述符
  携带真实 CRC，登记进 central 的头部 CRC 仍置 0（INV-14）。默认
  `DataDescriptor=False`，既有缓冲/暂存路径字节级行为不变。
- **[INV-16]** 顺序读契约：`NewZipSequentialReader*` 从任意 `IReader` 顺序
  消费，仅靠 local header + data descriptor 前进，不整载、不要求 seek，
  与 INV-15 对偶。`Next` 在描述符条目上增量扫描定位描述符（有签名
  `16/24` 与无签名 `12/20` 均支持——`LCSize==APos`/`LUSize≤MaxOutput` 预筛 + CRC/尺寸强校验 + 下一条目签名预检，防载荷内假签名导致的 `O(n·m)` 试解压 CPU bomb——35期先验 `IsKnownZipSig` 再试解，42期补无签名兼容，44期 AES 描述符经 `UnsealWinZipAesPayload` 解帧后再 CRC/试解压），并通过 pushback 保证跨条目
  字节级精确；非描述符条目按 local 声明尺寸精确有界。`Open` /
  `CopyTo`/`Skip` 语义与读端一致（Guard/解压/CRC/MaxOutput/口令），
  一次仅一流，重复打开或未 `Next` 时 `EInvalidOperationError`；截断
  结构 `EParseError`（`descriptor not found` 含缓冲上限 `MaxDescriptorBuffer` 默认 512MiB 可配，45期与 `MaxOutput/MaxTotal` 正交），`AES+descriptor` 已打通（44期），`缺口令` 仍 `EInvalidOperationError`。目录判定
  仅认尾随 `/`（无 external attrs），与随机读的 `S_IFDIR` 判定互为已知差
  异，见 §6 Known Limitations。
- **[INV-17]** 总输出守卫：`TZipReadOptions.MaxTotalOutputSize` 为跨条目
  总未压缩尺寸上限（防“100k × 1MiB 小条目绕过单条目上限”型 ZipBomb），
  0=不限。随机读路径（内存/定位流）在解析 central 结束时对
  `Σ UncompressedSize` 做溢出安全求和并 fail-closed（`EIOError`）；
  顺序读路径在 `Next` 归一真实尺寸后增量累计，超限即 `EIOError`；
  单值已超限或累加溢出均拒绝；`TZipExtractOptions` 同步透传该上限。
- **[INV-18]** `PByte` 零拷贝直写（S43）：`IZipReader.ExtractToBuffer*` 与
  `common.DecompressEntryToBuffer` 共享校验内核；store 经 `Move` 直写、
  deflate 经 `RawDeflateDecompressToBuffer` 增量泵送到调用方缓冲，无
  `TBytes` 中间物化；`ADstLen < UncompressedSize`/`MaxOutputSize` 超限/
  尺寸/CRC 均 fail-closed；`ADst=nil` 仅允 `UncompressedSize=0`（目录/空）。
- **[INV-19]** `AES+descriptor` 对偶（S44）：顺序读 `CollectDescriptorPayload` 先集密文再经 `UnsealWinZipAesPayload`（按 `AesStrength` 解帧）校验 `CRC/尺寸/试解压`，`MaxOutput` 对解密后明文尺寸预筛，与 Writer `INV-15` `AES 描述符` 路径对偶；`缺口令` `EInvalidOperationError`，认证失败统一 `EParseError('zip aes: authentication failed')`。

## 3. 错误模型

| 场景 | 异常 |
|------|------|
| 结构损坏（签名错、截断、extra 链畸形、central 越界、坏符号链接目标、AE 强度/厂商非法） | `EParseError('zip: ...')` |
| CRC 不符 / 解压尺寸不符 | `EIOError` |
| 遗留 ZipCrypto / 未知方法 / 多盘归档 / 不支持的 AE 版本 | `ENotSupportedError` |
| WinZip AES 口令校验值或认证码不匹配（统一报文，无失败点 oracle） | `EParseError('zip aes: authentication failed')` |
| 加密条目未配置口令 | `EInvalidOperationError` |
| 条目缺失（按名查找后提取） | `ENotFoundError` |
| 索引越界 | `EIndexOutOfRangeError` |
| Finish 后再写入 / 再 Finish | `EInvalidOperationError` |
| 描述符直写进行中的其他条目级操作 | `EInvalidOperationError('zip writer: descriptor entry stream is active')` |
| 描述符直写流被放弃后 Finish/FinishTo | `EInvalidOperationError('zip writer: descriptor entry abandoned')` |
| 写端条目名不安全 | `EArgumentError` |
| 流式输出端为 nil / 重复绑定 / 异源 FinishTo | `EArgumentError`（nil）/ `EInvalidOperation`（其余） |
| 输出 sink 短写 | `EIOError('zip writer: short write to output sink')` |
| 源流缺失定位读能力 | `ENotSupportedError` |
| 单条目解压超过 MaxOutputSize | `EIOError`（来自 raw inflate 上限语义） |
| 跨条目总输出超过 MaxTotalOutputSize | `EIOError('zip: total uncompressed size exceeds limit')` |
| 顺序读未 Next 或重复打开流 | `EInvalidOperationError` |
| 顺序读 AES 描述符缺口令 | `EInvalidOperationError` |

## 4. 源契约

生产单元（src/nextpas.core.zip*.pas）不得 uses 任何非 `nextpas.*` 单元——
FPC RTL（SysUtils/Classes 等）与第三方库一律经 owner 模块间接使用；该规则由
`test_zip_contract` 门在 CI 中机械执行。门面单元只做 re-export 与 inline
委托，不含控制流逻辑。`nextpas.core.zip.common` 为 reader/sequential 共享校验与解压内核（`GuardEntryReadable/GuardEntryPassword/GuardZipIndex/FindZipEntry/GuardTotalOutputAdvance/GuardTotalOutputSize/DecompressEntryVerified/DecompressEntryToBuffer/IsKnownZipSig/LE*`，39期 `GuardTotalOutputSize` 单点化、43期 `DecompressEntryToBuffer` PByte 零拷贝与 `RawDeflateDecompressToBuffer`、S90 `GuardTotalOutputAdvance` 增量/批量总量守卫单点化），`nextpas.core.zip.reader` 的 `ZipPumpReader` 为三路泵共享内核（S91 2×16 行→1 行、S92 +sequential 三路收口，仅 `65KiB` 栈缓冲+`nil/短写` 校验）、`ZipWrapEntryReader` 流式解压管道单源（S93 双 `OpenEntry AES→inflate→Verify` 2×20 行→1 行）、`ZipFindEocd` EOCD 扫描单源（S94 双 `ParseCentralDirectory` 2×12 行→1 行）、`ZipDecodeEocd` EOCD 字段解析单源（S95 2×8 行→1 行）、`ZipParseCentralEntries` 中央条目循环单源（S96 2×10 行→1 行，含 `GuardTotalOutputSize` 守恒）、`ZipDecodeZip64Locator/ZipDecodeZip64Eocd` Zip64 单源（S97 双 `ParseCentralDirectory` 2×24 行→2×2 行，locator 20B + eocd 56B 字段解析）、`ZipResolvePayloadOffset` 载荷定位单源（S98 双 `LocatePayload 2×9 行→2×1 行，Guard+ParseLocalHeader+payload GuardRange`）、`ZipExtractToBytesViaPayload/ZipExtractToBufferViaPayload/ZipOpenViaPayload` 解压与口令单源（S99 双 `ExtractIndex/ExtractToBuffer/OpenEntry 3×2→3×1，Decompress+GuardPassword+Wrap`）与 `ZipValidateCentralBoundsAndAlloc` 中央边界与分配单源（S101 双 `ParseCentralDirectory 2×6→2×1，central out of bounds+entry count+SetLength`）、`writer TZipEntrySink.PushCompressed FScratch High div2` 溢出守卫（S102 与 `reader.EnsureScratch` 双端同构）、`ZipSliceRead/ZipBytesRead` 有界切片读单源（S103 `reader.TSliceReader/sequential.TSeqSliceReader 2×8→2×1`）与 `NeedRange` 薄包装消除（S104 `NeedRange → GuardCursorRange/GuardRange 6 处直通`），`nextpas.core.zip.extra` 为 Zip64/AES extra 字段共享编解码链（`Decode*/Build*`/`Encode*` 对称——`Build*` 为堆便捷包装，`Encode*` 为栈上零分配（`PByte+SizeUInt` 直写，`aes.EncodeWinZipAesExtraBody` 同为栈上 7 字节零堆），`writer` 逐条目经 64 字节栈缓冲与 `FScratch` 几何预留复用），`nextpas.core.zip.sequential` 去 `Copy` 双重拷贝（41期零拷贝切片与 PushBack 复用）并兼容无签名描述符（42期 12/20/16/24 四形态）与 `AES+descriptor`（44期经 `Unseal` 解帧校验），S92 起 `CopyTo` 直通 `reader.ZipPumpReader`。示例 `zip_roundtrip` 覆盖内存/顺序/fs 三路径与 `MaxOutput/MaxTotal` 守卫全演示（四十期定版）。禁用 C 风格复合赋值运算符与 {$COPERATORS}。

## 5. 测试入口

```bash
make focused FOCUS=core/tests/nextpas.core.zip/test_zip            # 写端结构/确定性/Zip64/选项
make focused FOCUS=core/tests/nextpas.core.zip/test_zip_reader     # 读端解析/防护/属性
make focused FOCUS=core/tests/nextpas.core.zip/test_zip_sequential # 顺序读端（HTTP body/管道）与描述符对偶
make focused FOCUS=core/tests/nextpas.core.zip/test_zip_fuzz       # 模糊/属性护栏：随机载荷/名/模式 seq vs mem 一致性
make focused FOCUS=core/tests/nextpas.core.zip/test_zip_fs         # 目录打包/解包/权限
make focused FOCUS=core/tests/nextpas.core.zip/test_zip_contract   # 本契约 + 无 FPC RTL 依赖审计
make focused FOCUS=core/tests/nextpas.core.zip/test_zip_extra      # extra 编解码对称性证明（Build/Decode 往返 + 恶意 extra）
make focused FOCUS=core/tests/nextpas.core.zip/test_zip_aes        # AES 加密门：AE-1/AE-2、强度1..3、口令校验与认证码、篡改 fail-closed
make focused FOCUS=core/tests/nextpas.core.zip/test_zip_go_parity  # Go archive/zip 双向字节级对等（十九期领头羊双锚点）
make focused FOCUS=core/tests/nextpas.core.zip/test_zip_perf       # 性能回归阈值（二十期 allocs 预算，CountingMemoryManager）
make focused FOCUS=core/tests/nextpas.core.zip/test_zip_stress     # 极限压力（二十一期 70k Zip64/1k混合/Bomb/并发）
make focused FOCUS=core/tests/nextpas.core.zip/test_zip_builder    # 链式构造器（二十三期 Fluent 字节级一致 + fail-closed）
make -C core/benchmarks/nextpas.core.zip/bench_zip regression      # 基准回归（22期 BASELINE + allocs/bytes 硬门，ns +50% 告警）
```

python3 zipfile 作为独立实现交叉验证源（读我们产出的归档、生成参考归档、
force_zip64 归档、unix 属性条目、符号链接条目）；python3 缺失时相关用例显式
失败，不静默跳过。Go `archive/zip` 作为第二锚点：`test_zip_go_parity`
通过 `go_helper.go` 双向（Pascal→Go verify / Go→Pascal gen）验证
store/deflate、unicode、空/目录、20×混合、1MiB 吞吐与 30 随机 fuzz
的字节级对等；`go` 缺失时显式失败。`test_zip_perf` 以 `CountingMemoryManager`
（heaptrc 兼容，统计 GetMem+AllocMem+ReAllocMem）锁定 `200×512B 810→805`
零分配基线与 `1MiB ≤12 allocs` 预算，`Reserve` 必须降低 allocs，回归即红。
`test_zip_stress` 以 70k Zip64/1k 混合双路径/ Bomb 单值与总量/并发提取
验证规模与敌意压力下的 fail-closed。`bench_zip regression` 以
`BASELINE.json` 为基线，`allocs +2` 零容忍、`bytes` 强一致、`ns +50%` 告警
的 CI 硬门（`make baseline` 需人工审查后提交）。

## 6. Known Limitations

- 顺序读目录判定仅认尾随 `/`，随机读另认 `S_IFDIR`/`S_IFLNK`（external attrs 高位）；见 INV-16。
- `extra` 的 `LE*` 已收口至 `nextpas.core.zip.common`，`WriteLE*` 栈直写与 `PByte`/`TBytes` 双形态保留；`Build*` 为堆便捷包装，写端一律走 `Encode*` 零分配路径（`aes.EncodeWinZipAesExtraBody` 同为栈上 7 字节零堆，`BuildWinZipAesExtraBody` 为其堆包装）。
- `ZipExtractToDir*` 默认非原子：已落盘文件不回滚，`LDirs` 逆序定稿在 `try..finally` 尽力 `Chmod/Chtimes`，异常需外层整体清理；原子语义请用 `ZipExtractToDirAtomic*`（S67：同文件系统 `TempDir(LParent,'.zip-atomic-')`+`Rename` 原子提交，`Exists`拒绝覆盖，异常 `RemoveAll` 清理）。`EnsureNoSymlinkInPath` 已为落盘前/后双校验 + 落盘结果 `IsSymlink(LFull)` 校验（S66），残余 TOCTOU 需 `openat(O_NOFOLLOW)` 彻底消除，见 SECURITY §5。
- `MaxDescriptorBuffer`（默认 512MiB）与 `MaxTotalOutputSize` 正交，顺序读 `CollectDescriptorPayload` 先缓冲后 `CheckTotalLimit`，极端小 `MaxTotal` 配大缓冲时内存先分配后 fail-closed（已知取舍，见 INV-16/17）。
