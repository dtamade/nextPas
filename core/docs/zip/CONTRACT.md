# nextpas.core.zip CONTRACT

本文档描述 `nextpas.core.zip` 的公共契约。改动公共 API、错误语义或
生命周期行为时必须同步更新本文件与 `test_zip` / `test_zip_reader` /
`test_zip_fs` / `test_zip_contract` 门。

## 1. 公共 API 面

### 1.1 类型

| 类型 | 说明 |
|------|------|
| `TZipMethod = (zmStore, zmDeflate)` | 已知压缩方法；未知方法码保持 `zmStore`，看 `MethodCode` |
| `TZipEntryInfo` | central directory 条目元数据；尺寸/偏移为 UInt64（Zip64 宽度）；含 `ExternalAttrs` 原值与 `IsSymlink` 判定 |
| `TZipWriteOptions` | `ForceZip64: Boolean`——无条件产出 Zip64 结构 |
| `TZipAddOptions` | 单条目完整选项：`Method` / `ModTimeUnixSec`（<0 取 DOS 下限）/ `Mode`（unix 模式字，0 取默认） |
| `TZipReadOptions` | `MaxOutputSize: SizeUInt`——单条目解压上限，0 取默认 1 GiB |
| `TZipExtractOptions` | fs 解包选项：`RestoreMode` / `SkipSymlinks` / `MaxOutputSize` |

### 1.2 工厂函数

| 函数 | 说明 |
|------|------|
| `NewZipWriter` / `NewZipWriterWithOptions` | 写器；顺序追加、一次性 Finish |
| `NewZipReader` / `NewZipReaderWithOptions` | 读器；构造时解析 central directory，非法结构立即 raise |
| `DefaultZipWriteOptions` / `DefaultZipAddOptions` / `DefaultZipReadOptions` / `DefaultZipExtractOptions` | 各选项默认值 |
| `ZipPackDirInto` / `ZipPackDir` | 目录递归打包（携带 mtime 与 posix 权限位） |
| `ZipExtractToDirWithOptions` / `ZipExtractToDir` | 解包到目录 |
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
| `EntryCount` | 已添加条目数 |
| `Finish: TBytes` | 终结并返回完整归档；此后任何添加/再次 Finish raise |

### 1.4 读器方法

| 方法 | 说明 |
|------|------|
| `EntryCount` / `Entry(Index)` | 元数据随机访问；越界 raise |
| `Find(Name): Integer` | 按名查找；缺失 -1；重名取首个 |
| `ExtractToBytes(Index)` | 提取并强制 CRC32/尺寸校验；目录条目返回空字节 |
| `ExtractToBytesByName(Name)` | 同上按名；缺失 raise ENotFoundError |

## 2. 不变量

- **[INV-1]** CRC32 永远针对未压缩载荷计算与校验（store 与 deflate 一致）。
- **[INV-2]** 提取时校验 local header 签名、解压尺寸与 CRC32，任一不符即 raise。
- **[INV-3]** 未显式指定时间戳的输出字节级确定（同输入同归档，除 deflate 载荷
  受宿主 zlib 版本影响外）。
- **[INV-4]** 敌意条目名（空名/绝对路径/盘符/反斜杠/`..` 段）在写端拒绝入参、
  在读端提取与落盘前以 EParseError 拒绝。
- **[INV-5]** 加密条目（flag bit 0）、未知压缩方法、多盘归档 → ENotSupportedError。
- **[INV-6]** Zip64：尺寸/偏移超 ZIP32 宽度或条目数超 65535 时自动启用；
  ForceZip64 无条件启用。central 布局固定为 [固定字段][名字][extra][注释]。
- **[INV-7]** data descriptor 容忍：本地头 flag bit3 置位的流式归档按 central
  权威值提取（本地 crc/尺寸为占位值不影响结果）；写端永不产出描述符。
- **[INV-8]** deflate 提取预分配以 central 声明尺寸为容量提示，但对敌意声明
  施加压缩比上界（压缩尺寸×16+64KB），硬上限仍是 MaxOutputSize；声明值不参与
  正确性判定（实际输出仍强制校验）。
- **[INV-9]** 权限还原仅对 unix 归档（外部属性高 16 位模式字非零）生效；
  目录的权限与 mtime 在全部内容落盘后逆序定稿。
- **[INV-10]** 符号链接条目默认跳过；SkipSymlinks=False 为显式 opt-in 保真创建。

## 3. 错误模型

| 场景 | 异常 |
|------|------|
| 结构损坏（签名错、截断、extra 链畸形、central 越界、坏符号链接目标） | `EParseError('zip: ...')` |
| CRC 不符 / 解压尺寸不符 | `EIOError` |
| 加密条目 / 未知方法 / 多盘归档 | `ENotSupportedError` |
| 条目缺失（按名查找后提取） | `ENotFoundError` |
| 索引越界 | `EIndexOutOfRangeError` |
| Finish 后再写入 / 再 Finish | `EInvalidOperationError` |
| 写端条目名不安全 | `EArgumentError` |
| 单条目解压超过 MaxOutputSize | `EIOError`（来自 raw inflate 上限语义） |

## 4. 源契约

生产单元（src/nextpas.core.zip*.pas）不得 uses 任何非 `nextpas.*` 单元——
FPC RTL（SysUtils/Classes 等）与第三方库一律经 owner 模块间接使用；该规则由
`test_zip_contract` 门在 CI 中机械执行。门面单元只做 re-export 与 inline
委托，不含控制流逻辑。禁用 C 风格复合赋值运算符与 {$COPERATORS}。

## 5. 测试入口

```bash
make focused FOCUS=core/tests/nextpas.core.zip/test_zip           # 写端结构/确定性/Zip64/选项
make focused FOCUS=core/tests/nextpas.core.zip/test_zip_reader    # 读端解析/防护/属性
make focused FOCUS=core/tests/nextpas.core.zip/test_zip_fs        # 目录打包/解包/权限
make focused FOCUS=core/tests/nextpas.core.zip/test_zip_contract  # 本契约 + 无 FPC RTL 依赖审计
```

python3 zipfile 作为独立实现交叉验证源（读我们产出的归档、生成参考归档、
force_zip64 归档、unix 属性条目、符号链接条目）；python3 缺失时相关用例显式
失败，不静默跳过。
