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

`ITarBuilder`（`nextpas.core.tar.intf` 定义，`nextpas.core.tar.builder` 实现）：`Add/AddWithOptions/AddDirectory/AddDirectoryWithOptions/AddEntry/Finish` 链式，遵循 `base←intf←实现←门面`；薄门面委托 `TTarWriter` + `CreateBytesStream`，`Finish` 快照 `ArchiveSnapshotStream` 并校验 short read；门面导出单一 `TarBuilder` inline 工厂（`NewTarBuilder` 已移除），需显式 `Finish`（析构经 `TTarWriter` 兜底补两零块 best-effort），零额外序列化逻辑，bytes 级与 `TTarWriter` 一致。

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

生产单元（`src/nextpas.core.tar*.pas`）不得 uses 任何非 `nextpas.*` 单元，经 `test_tar_contract` 门机械执行。门面仅 re-export + inline 委托，无控制流。`nextpas.core.tar.common` 为内部共享内核（`TarPadToBlock`/`GuardTarEntrySize`/`GuardTarTotalSize`/`GuardTarNameForRead` + 校验和单点 `TarComputeChecksumUnsigned`/`TarComputeChecksumSigned`/`TarVerifyBlockChecksum`/`TarHeaderIsZeroOrValid` + 数值单点 `TarParseNumericField`/`TarFormatNumericField` + pax 单点 `TarParsePaxRecords`，均 inline 零拷贝 PByte 切片、复用 `bytes.ops` 单源视图），仅供 `tar.reader/writer/fs` 实现内复用，禁止门面（`nextpas.core.tar`）外直接 `uses`；绕过门面直引视为违契，`test_tar_contract` 覆盖该边界。

## 5. 测试入口

```bash
make focused FOCUS=core/tests/nextpas.core.tar/test_tar_reader
make focused FOCUS=core/tests/nextpas.core.tar/test_tar_writer
make focused FOCUS=core/tests/nextpas.core.tar/test_tar_fs
make focused FOCUS=core/tests/nextpas.core.tar/test_tar_contract
make focused FOCUS=core/tests/nextpas.core.compress/test_compress_tar  # 回归：经 deprecated 转发仍绿
```
