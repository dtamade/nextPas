# Tar 模块实施计划 — nextpas.core.tar

> 独立 L2 归档模块，从 `nextpas.core.compress.tar` 寄生抽离，对标 `zip` 成熟度，六维打磨：模块化 / 性能 / 高级感 / 复用度 / 稳定性 / 完整性。

## 1. 背景与目标

- 现状：唯一 tar 实现寄生在 `compress.tar`（642 行，`TTarReader/TTarWriter/TTarHeader`），门面 `nextpas.core.compress` re-export，测试仅 `test_compress_tar` 单 gate，无 `fs`、`common`、`base`、`contract`、`benchmark`。
- 目标：晋升为独立 L2 模块 `nextpas.core.tar`，层级 `L2`（依赖 `L0-L1` 仅 `base/io/bytes/text/checksum`），提供 `reader/writer/fs` 三段式 API + 流式零拷贝 + 防 bomb 上限 + pax/GNU 全兼容，对齐 `zip` 的 12-gate 标杆。

## 2. 模块归属与层级

| 项 | 决策 |
| --- | --- |
| 层级 | `L2`，`allowed: L0-L1, platform/fs`（`fs` 仅 `tar.fs` 打包 seam），与 `zip/respack` 同层 |
| Facade | `nextpas.core.tar` |
| Units | `base / common / reader / writer / fs / tar.pas(mirror)` |
| 注册 | `core/docs/module-registry.md` 新增行，`core/docs/core-module-registry.md` 同步 |
| 兼容 | `nextpas.core.compress.tar` 保留为 deprecated 薄转发（re-export tar），单测仍绿 |

## 3. 四件套切分

```
nextpas.core.tar.base.pas    ← TTarEntryKind/TTarHeader/TTarAddOptions/TTarReadOptions/常量/C_TAR_BLOCK_SIZE/IsSafeTarEntryName
nextpas.core.tar.common.pas  ← Guard/Decompress 语义单点、LE/八进制/base-256 助手、PadToBlock、校验和
nextpas.core.tar.reader.pas  ← TTarReader（PBytes 零拷贝视图，Next/EntryData/EntryDataSlice/EntryStream）
nextpas.core.tar.writer.pas  ← TTarWriter（IWriter 目标，AddEntry/AddFile/AddDir/Finish，ustar prefix + pax 长名回退 + base-256）
nextpas.core.tar.fs.pas      ← TarPackDirInto / TarPackDir / TarExtractToDirWithOptions（复用 zip.fs 模式：排序、安全谓词、deferred dir 定稿）
nextpas.core.tar.pas         ← 门面 re-export + inline 转发
```

依赖方向：`base ← common ← reader/writer/fs ← tar`。`common` 仅依赖 `base + exception + bytes`。`reader/writer` 依赖 `common + io.intf`。`fs` 额外依赖 `nextpas.core.fs`。

## 4. 公共 API 设计（对齐 zip 手感）

```pascal
// base
TTarEntryKind = (tekRegular, tekHardLink, tekSymlink, tekCharDevice, tekBlockDevice, tekDirectory, tekFifo)
TTarHeader = record Name/LinkName/Kind/Mode/UID/GID/Size/MTimeUnix/UName/GName end
TTarAddOptions = record Mode/MTimeUnix/UID/GID/UName/GName end
TTarReadOptions = record MaxEntrySize/MaxTotalSize end
TTarExtractOptions = record RestoreMode/SkipSpecial/MaxEntrySize/MaxTotalSize end
C_TAR_BLOCK_SIZE = 512; C_TAR_DEFAULT_MAX_ENTRY = 1 GiB; C_TAR_DEFAULT_MAX_TOTAL = 0 (unlimited)
IsSafeTarEntryName / ValidateTarEntryName

// reader
TTarReader = class
  constructor Create(const AData: TBytes); overload;
  constructor Create(AData: PByte; ACount: SizeUInt); overload;
  function Next(out AHeader: TTarHeader): Boolean;
  function EntryData: TBytes;                 // 拷贝
  function EntryDataSlice(out AData: PByte; out ACount: SizeUInt): Boolean; // 零拷贝视图
  function EntryDataOfs: SizeUInt;
  function OpenEntryStream: IReader;          // 零拷贝切片流（PBytes 直视）
end;

// writer
TTarWriter = class
  constructor Create(const ADst: IWriter);
  procedure AddEntry(const AHdr: TTarHeader; const AData: TBytes);
  procedure AddFile(const AName: string; const AData: TBytes; AMode=...; AMTime=0);
  procedure AddDir(const AName: string; AMode=...; AMTime=0);
  procedure AddEntryWithOptions(const AName: string; const AData: TBytes; const AOpts: TTarAddOptions);
  procedure Finish; destructor Destroy; override;
end;

// fs
procedure TarPackDirInto(const ADir: string; const AWriter: TTarWriter);
function TarPackDir(const ADir: string): TBytes;
procedure TarExtractToDirWithOptions(const AData: TBytes; const ADestDir: string; const AOpts: TTarExtractOptions);
procedure TarExtractToDir(const AData: TBytes; const ADestDir: string);
```

流式：reader 提供 `EntryDataSlice` + `OpenEntryStream`（复用 `bytes.stream` 的零拷贝切片），writer 仍以 `IWriter` 目标保持常数内存（条目级缓冲，`Finish` 两零块）。

## 5. 关键语义（INV）

- INV-1: `ustar` 写入：`magic "ustar\0"`/`version "00"` 固定，`prefix` 自动分割（最大 `/` 使后缀 ≤100，否则 `EIOError: entry name too long for ustar`），目录补 `/`。
- INV-2: 数值字段八进制为主，超 `octal capacity` 自动 `base-256`（首字节 `$80` + big-endian），读端双路径兼容。
- INV-3: 读端支持 `GNU L/K` 长名、`pax x/g` 的 `path/linkpath` 覆盖（per-entry 优于 global），`pax` 记录长度前缀校验。
- INV-4: 校验和双算（unsigned/signed）任一匹配即过，否则 `EIOError: header checksum mismatch`。
- INV-5: `IsSafeTarEntryName` 拒绝空名/绝对路径/盘符/反斜杠/`//` 空段/`./` 单点段/`..` 段，但允许 pax 覆盖后的真实名；写端 `Validate` 即 `EArgumentError`，读端/落盘前 `EParseError`，`..` 经 `TarExtractToDir` 二次拒绝对称。
- INV-6: `MaxEntrySize`（单条目）与 `MaxTotalSize`（跨条目总量，防 100k×1MiB）单点守卫在 `common.GuardTarEntrySize`，`EntryData`/`OpenEntryStream` 中途生效。
- INV-7: 零块结束：单零块后须跟全零或 EOF，否则 `truncated stream`；`FEntryDataOfs/Size` 视图与 `EntryData` 拷贝一致。
- INV-8: 确定性：未显式 mtime 取 `0`，mode 默认 `0644/0755`，同输入同字节（除 pax 长名外）。

## 6. 性能与复用

- 复用 `base.utils.CompareBytesOrdered/CompareMem/TryMulSizeUInt`（零拷贝比较）、`bytes.ops`、`checksum.crc32`（若需）。
- `EntryDataSlice`/`OpenEntryStream` 零拷贝（`PByte + Move` 仅在 `EntryData` 拷贝路径），`CollectLevel` 排序缓存 `Key` 指针，`EnsureWalkCapacity` 几何扩容。
- `common` 单点 `PadToBlock/NumericField/StringField`，消除 reader/writer 重复。

## 7. 测试与门禁

| Gate | 覆盖 |
| --- | --- |
| `test_tar_reader` | system tar 互操作、pax/gnu/base-256、损坏校验和、空档/截断 |
| `test_tar_writer` | ustar prefix 分割、mode/mtime/uid、block 对齐、writer vs system tar 提取 |
| `test_tar_fs` | 目录打包/解包、排序确定性、权限/mtime 还原、symlink 拒绝、zip-slip |
| `test_tar_contract` | 无 FPC RTL 依赖、禁 C 运算符、门面纯度、文档/registry 存在性 |
| `test_tar_fuzz` | 随机载荷/名/边界 fuzz，mem vs slice 一致性 |
| `test_tar_perf` | CountingMemoryManager alloc 预算 |
| `test_compress_tar` | 保留回归（经 deprecated 转发仍绿） |

Gate 指令：`make focused FOCUS=core/tests/nextpas.core.tar/test_tar_reader` 等。Benchmark 以 `nextpas.core.bench` 另起 `bench_tar`（非首版阻塞）。

## 8. 实施顺序

1. `tar.base` + `tar.common` → 2. `tar.reader`/`writer`（抽离 compress.tar，补 slice/stream + guard）→ 3. `tar.fs` + 门面 `tar.pas` → 4. `compress.tar` 薄转发 → 5. `docs/tar/{README,CONTRACT}` + registry → 6. tests 6 gates → 7. hygiene + focused 全绿。

## 9. 风险

- `compress.tar` 存量测试依赖 `TTarWriter.Create((S as IWriter))` 的 cast，抽离后需保持签名兼容。
- `pax` 全局 `g` 的作用域（本读端已实现 global 兜底），需与 GNU tar 行为对齐并加回归。
