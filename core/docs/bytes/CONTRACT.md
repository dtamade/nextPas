# nextpas.core.bytes 代码契约

**模块路径**：`core/src/nextpas.core.bytes*.pas`（11 个源文件：`bytes.base/pas` + `ops` + `ops.capacity/ops.text/ops.ascii` 3 叶子 + `binary/builder/cursor/stream/pathvalid`）
**层级**：L1（依赖 L0: base, mem, platform, simd；与 `core/docs/core-module-registry.md` 一致）
**Owner**：Claude（AI 负责）
**最后更新**：2026-09-03
**版本**：1.6

---

## 1. 接口契约

### 1.1 子模块

| 文件 | 职责 |
|------|------|
| bytes.base | TEndianness/TEndian/TByteOrder 别名、`NATIVE_ENDIAN`、Builder 默认容量 |
| bytes.ops | TByteSpan/TBytes 单源操作（Equal/Compare/IndexOf/Fill/Reverse/Concat/Clone/CopySlice/ConcatMany/BytesAppendRaw）— 单源 Owner（raw Move/FillChar 仅此，BytesCopy/BytesZero inline 零拷贝，BytesAppendRaw 单点 SetLength+BytesCopy，BytesEnsureCapacity/BytesNextCapacity thin-forward capacity 叶子 0→64→2× 无重复 while）；叶子 `ops.capacity`（几何增长 `BytesGrowCapacityWithMin` 0→64→2×/Webview 0→4→2× 同源 `*2`）、`ops.text`（SpanToString/Var/HTon/FNV 零拷贝）、`ops.ascii`（Xor/Ascii inplace 无 Move）为纯算术/字符串叶子，thin-forward 复用单源，无重复 Move |
| bytes.ops.capacity | 容量增长单源（`BytesGrowCapacityWithMin` 几何 `*2` 均摊 `O(1)`，`BytesGrowCapacity`/`BytesNextCapacity`/`BytesEnsureCapacity` 统一复用，`Webview 0→4→2×` 同源复用）— 不含 Move，not inline loop |
| bytes.ops.text | 字符串/Var/字节序 helpers（SpanToString/FNV/HTonN 等零拷贝 SetString 视图）— 不含 raw Move |
| bytes.ops.ascii | Xor/Ascii 大小写原地（QWord 批异或、ToLower/Upper）— 不含 Move |
| bytes.binary | 字节序转换与游标编解码（Swap/ToEndian/Read/Write/TryRead/TryWrite） |
| bytes.builder | IBytesBuilder 可变字节缓冲区（allocator 注入、按需增长） |
| bytes.cursor | IByteCursor 边界受查只读游标（顺序/绝对偏移、Try* 变体） |
| bytes.stream | TByteStreamBuf 可增长缓冲流（append/consume/compact） |
| bytes.pathvalid | ValidPath 共享校验（复用 bytes.ops 单源 + text.utf8 单源） |
| bytes.pas | 门面：纯 re-export + inline 转发 |

四件套形态：`base` → `ops`（单源 Owner，raw Move 仅此） + `ops.capacity/ops.text/ops.ascii` 3 叶子（纯算术/字符串，无 Move，thin-forward）+ `binary/builder/cursor/stream/pathvalid` → `bytes.pas` 门面；`ops` 981→~760 行（≤800 软指引，叶子各 ~120 行），优雅度合规；无独立 `intf/ffi`（按需存在）。

### 1.2 IBytesBuilder 接口

```pascal
IBytesBuilder = interface
  ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']
  function GetLength: SizeUInt;
  function GetCapacity: SizeUInt;
  function GetData: PByte;
  procedure AppendByte(const AValue: Byte);
  procedure AppendBytes(const AData: PByte; const ACount: SizeUInt);
  procedure AppendSpan(const ASpan: TByteSpan);
  procedure AppendUInt16LE/BE(const AValue: UInt16);
  procedure AppendUInt32LE/BE(const AValue: UInt32);
  procedure AppendUInt64LE/BE(const AValue: UInt64);
  procedure AppendFill(const AValue: Byte; const ACount: SizeUInt);
  function WrittenSpan: TByteSpan;
  function ToBytes: TBytes;
  procedure Clear;
  procedure Reserve(const AAdditional: SizeUInt);
  procedure Truncate(const ANewLen: SizeUInt);
  property Length: SizeUInt read GetLength;
  property Capacity: SizeUInt read GetCapacity;
  property Data: PByte read GetData;
end;
function CreateBytesBuilder(const AInitialCapacity: SizeUInt = BYTES_BUILDER_DEFAULT_CAPACITY): IBytesBuilder;
function CreateBytesBuilderWith(const AAllocator: TMemAllocator; const AInitialCapacity: SizeUInt = BYTES_BUILDER_DEFAULT_CAPACITY): IBytesBuilder;
```

门面 `nextpas.core.bytes` 另 inline 转发 `CreateBytesBuilder/NewByteCursor/TByteStreamBuf` 别名与全部 Span/Binary 便捷面（见 `bytes.pas`）。

### 1.3 Span 操作（单源：bytes.ops）

| 函数 | 说明 |
|------|------|
| `SpanEqual(A, B): Boolean` | 逐字节比较（经 `MemEqual`/SIMD） |
| `SpanEqualIgnoreCase` | 大小写不敏感比较 |
| `SpanCompare(A, B): Integer` | 三路比较（SIMD） |
| `SpanIndexOf(Haystack, Needle: Byte): SizeInt` | 查找字节 |
| `SpanIndexOfSpan(Haystack, Needle): SizeInt` | 查找子序列 |
| `SpanContains(Haystack, Needle): Boolean` | 包含检查（inline） |
| `SpanStartsWith/EndsWith` | 前缀/后缀 |
| `SpanFill(Span, Value)` | 填充 |
| `SpanReverse(Span)` | 反转 |
| `SpanConcat(A, B): TBytes` | 拼接（分配） |
| `SpanCopySlice(Span, Offset, Len): TBytes` | 切片拷贝（越界 `EOutOfRange`） |
| `SpanClone(Span): TBytes` | 克隆 |
| `SpanConcatMany/BysConcatMany` | 多段拼接 |
| `BytesEqual/Compare/IndexOf/Concat/StartsWith/EndsWith` | TBytes 便捷面（inline → Span） |
| `BytesAppend/BytesToString/StringToBytes` | TBytes 追加与字符串互转 |
| `SpanClone/SpanCopySlice` | 仅两处分配；其余 Span 为非拥有视图 |

约定：`bytes.ops` 为 Span/TBytes 比较与切片的唯一实现源；门面与其它实现均 inline 转发，不复制逻辑。

### 1.4 字节序与游标编解码

| 函数 | 说明 |
|------|------|
| `SwapUInt16/SwapUInt32/SwapUInt64` | 字节序翻转 |
| `ToEndian16/32/64 / FromEndian16/32/64` | 条件翻转（`AEndian = NATIVE_ENDIAN` 时零开销） |
| `ReadUInt16/32/64LE/BE(PSrc): UInt*` | 非受查指针读写 |
| `WriteUInt16/32/64LE/BE(PDst, Value)` | 非受查指针写入 |
| `TryReadUInt8/16/32/64LE/BE(var Span, out Value): Boolean` | 受查推进式读（成功收缩 Span） |
| `TryWriteUInt8/16/32/64LE/BE(var Span, Value): Boolean` | 受查推进式写 |

IByteCursor 在此之上提供边界受查的顺序/随机读（`ReadU16LE/BE`、`PeekU16LE`、`ReadBytes/ReadSpan/TryReadBytes`，越界 `EIndexOutOfRangeError`，`TrySeek` 返回 Boolean）。

### 1.5 Stream / Cursor / ValidPath

- **TByteStreamBuf**：`EnsureCapacity/ReserveAppend/CommitAppend/Append/Consume/Clear/Compact`；容量保留、尾部零分配、头游标延迟压实；Destroy 经 `FreeMemOf(FAllocator, FPtr, FCap)` 释放。
- **IByteCursor**：`NewByteCursor(TBytes)` 持有 `TBytes` 拷贝保活；`NewByteCursorAt(PByte, Len)` 裸指针由调用方保活；只读无分配（`ReadBytes` 除外）。
- **ValidPath**：`BytesValidPath/BaseValidPath(APath, AAllowRoot)` — Go `io/fs.ValidPath` 语义，复用 `text.utf8.UTF8IsValid` 单源，段扫描零拷贝。

---

## 2. 不变量

- **[INV-1]** Span 为非拥有视图：除 `SpanConcat/Clone/CopySlice/ConcatMany` 返回 `TBytes` 外不分配；零拷贝（`Move` 直拷，不经编码转换）。
- **[INV-2]** IBytesBuilder 按需倍增增长（`capacity ≥ length`，下界 `BYTES_BUILDER_MIN_GROW`，溢出钳制；单源 `BytesGrowCapacityWithMin` 几何 `0→64→2×` / `Webview` 重用 `0→4→2×` 同源 `*2` 均摊 `O(1)` 零 `O(n²)`，容量 `while` 单源仅 `bytes.ops.capacity` 叶子，`bytes.ops` 内 `BytesEnsureCapacity/BytesNextCapacity` inline thin-forward 复用无重复 `while`/`I-Cache`，门禁 `check_bytes_ops_source_contract.py` 容量单源巡检防漂移）；`Clear` 保留容量；`Truncate` 仅缩 `FLen`。
- **[INV-3]** `NATIVE_ENDIAN` 编译时确定（当前 `endLittle`）；`ToEndian/FromEndian` 在 native 时直通无翻转。
- **[INV-4]** 越界受查：`SpanCopySlice` 越界 → `EOutOfRange`；IByteCursor 越界 → `EIndexOutOfRangeError`；`Try*` 变体返回 `False` 不抛异常、不推进。
- **[INV-5]** 单源复用：比较/查找与 `Move`/`FillChar` 经 `bytes.ops` 单源（`BytesCopy` inline 单 `Move(ASrc^,ADst^,ALen)` 零拷贝 `281` 巡检、`BytesZero` inline `FillChar`，`Span*` inline 零拷贝，`MemEqual`/`MemCompare`/`MemFindByte`/`BytesIndexOf` + SIMD；`red-line 1` 禁索引 `Move`/`SetLength+Move` 批量—`BytesCopy/BytesZero` 单源、`BytesAppendRaw` 单点 `SetLength+BytesCopy` 单源；`red-line 2` 禁循环体—`BytesReplicateCopy/BytesAppendRaw/Grow` 等 `not inline` 防 `I-Cache` 膨胀；`BytesGrowCapacityWithMin` 几何倍增 `BYTES_BUILDER_MIN_GROW=64` 单源于 `bytes.ops.capacity` 叶子（同源 `0→64→2×`/`0→4→2×` `*2`），`WebviewGrowCapacity`/`BytesNextCapacity`/`BytesEnsureCapacity` 均 inline thin-forward 同源复用无重复 while/I-Cache，`BytesAppend` 系列收口至 `BytesAppendRaw` 单点 `SetLength+BytesCopy`（not inline per red-line 1/2，零拷贝单 `BytesCopy`，单次分配，单次 `I-Cache`；高频/循环 `MUST` 走 `IBytesBuilder` 几何 `Grow` 或 `BytesConcatMany`/`SpanConcatMany` 单次分配避免 `O(n²)`，`per-call O(n) → O(n²) if looped` 门禁巡检 `BytesAppend` 循环误用跨模块扫描），`bytes.ops.text/ascii` 叶子无 Move 纯算术/字符串 thin-forward；门面全部 `inline` 薄转发，零重复 `Move`/`SetLength`；`tls.encoding:479` 亦迁移至 `BytesCopy`，`platform.fs` 全量经 `BytesCopy` 单源复用（`platform_fs_read_until_eof` 与路径拼接零拷贝 inline `BytesCopy`，`sized FreeMem` 稳定性不丢））；强制门禁由 `test_bytes_ops_source_contracts/check_bytes_ops_source_contract.py` 全量巡检冻结（`raw Move/FillChar` 仅 `bytes.ops` 允许，`bytes.ops.capacity/text/ascii` 为无 Move 叶子且 `bytes.ops` 内无重复容量 `while`，`L0 platform.fs` 亦经 `bytes.ops.BytesCopy` 单源复用无分散，`BytesCopy inline Move(ASrc^,ADst^,ALen)` `281` 单源、`BytesAppend` `NotInline` + `O(n²)` 循环误用跨模块扫描、`red-line 1/2` 全量防漂移）。
- **[INV-6]** 资源释放不丢：`TBytesBuilderImpl.Destroy` 与 `TByteStreamBuf.Destroy` 以 sized `FreeMemOf/ReallocMemOf` 经注入 `TMemAllocator/IAllocator` 释放；`Clear/Consume` 不丢块；`try-finally/Free` 语义由调用方持有接口/对象生命周期保证；`BytesGrowCapacity`/`WebviewGrowCapacity` 无分配泄漏。
- **[INV-7]** L0-L3 分层：bytes 为 L1，仅依赖 L0（`base/mem/platform/simd`）及文档化 `bytes↔text↔encoding` seam（interface/implementation 分区引用，不形成循环）；门面不含逻辑；`webview.base` 复用 `bytes.ops` 属 `L3→L1` 合法反哺（`capacity` 单源下沉）。

---

## 3. 错误处理

| 场景 | 异常/返回值 |
|------|-------------|
| Slice 越界（Offset+Len > Span.Len） | `EOutOfRange`（`CheckSizeRange`） |
| IByteCursor 越界读/Seek | `EIndexOutOfRangeError`（含 pos/len/size） |
| Try* 游标/编解码余量不足 | `False`（不抛异常，Span 不推进） |
| 分配失败 | 传播自 `TMemAllocator.GetMem/ReallocMemOf`（nil 时调用方按分配器契约处理） |

---

## 4. 线程安全

- Span/Bytes 纯函数与 Binary 编解码：✅ 线程安全（无共享状态）。
- IBytesBuilder / TByteStreamBuf / IByteCursor：❌ 非线程安全，调用方同步；同一实例禁止并发。

---

## 5. 内存管理

- Span 操作：非拥有视图，不分配（Concat/CopySlice/Clone 除外返回独立 `TBytes`）。
- IBytesBuilder：内部块经 `TMemAllocator` 增长，`Grow` 倍增；`ToBytes` 返回拷贝；`WrittenSpan` 为当前写入区的零拷贝视图（随后续 Append 失效）。
- TByteStreamBuf：块经 `IAllocator`；`EnsureCapacity` 幂等；`ReserveAppend` 先压实后倍增；`Consume/Clear` 保留容量；`Destroy` sized free。
- 零拷贝：`Move/FillChar` 单源 `bytes.ops.BytesCopy` inline 单 `Move(ASrc^,ADst^,ALen)` 直操内存（`281` 巡检，`red-line 1` 禁索引 `Move`/`SetLength+Move` 批量）/`BytesZero` inline `FillChar`（`Pointer(Result)^/PByte+Off^` 单次 `Move`，`BytesAppendRaw` 单点 `SetLength+BytesCopy` 单次 `Move` 零额外拷贝，`L0 platform.fs` 亦 `BytesCopy` inline 单源零拷贝 — `platform_fs_read_until_eof` `LNewBuf` 生长与路径 `LTmpDir/APrefix/ASuffix/LDirEntry.Name` 拼接均 `BytesCopy` 单次 `Move`，无分散；`sized FreeMem` 资源释放不丢）；`ops.capacity/text/ascii` 叶子为无 Move 纯算术/字符串，thin-forward 零额外拷贝（capacity 几何 `*2` 均摊 `O(1)` 含 `BytesEnsureCapacity`/`BytesNextCapacity` 单源复用无重复 while，text SetString 零拷贝视图，ascii QWord 批异或）；门面与 `Bytes*` 便捷面均为 `inline` 薄转发，无额外拷贝；性能证据：`inline` 热路径零额外调用（`BytesCopy` inline 单 `Move(ASrc^,ADst^,ALen)` 零额外拷贝 `281`，`BytesZero` inline `FillChar`，`Span*` 热视图 inline 零拷贝），分配/循环路径 `not inline`（`red-line 1` 索引 `Move`/`SetLength` 批量、`red-line 2` 循环+`Move`/`SetLength` 均 `not inline`，`BytesReplicateCopy`/`BytesAppendRaw`/`Grow`/`StringToBytes` 等 `not inline`，`BytesAppendRaw` 单点/`BytesEnsureCapacity` thin-forward 消重复 while/`I-Cache`，门禁 `check_bytes_ops_source_contract.py` 全量巡检冻结 `red-line 1/2` + `BytesCopy inline` + `BytesAppend NotInline O(n²)` 循环误用跨模块扫描 + 容量单源无重复 while，split 后 `bytes.ops` ~760 + leaves 各 ~120，高频循环 `MUST` 走 `IBytesBuilder`/`ConcatMany` 单次分配避免 `O(n²)` `per-call O(n) → O(n²) if looped`）。

---

## 6. 测试覆盖

| 测试目录 | 说明 |
|----------|------|
| test_bytes | Span/TBytes 操作 + 字节序编解码 + Builder（含 allocator 注入、增长、截断） |
| test_cursor | IByteCursor 顺序/BE/peek/Seek/Try* / 边界守卫 / 裸指针构造 |
| test_stream | TByteStreamBuf append/consume/compact/EnsureCapacity/Clear/ReserveAppend/Grow |
| test_bytes_ops_source_contracts | `bytes.ops` 源契约门禁：`red-line 1/2 inline` 冻结（`BytesCopy inline Move(ASrc^,ADst^,ALen) 281` 单源、`BytesAppendRaw` 单点单源 `NotInline`）、`Move/FillChar` 单源与 `WebviewGrowCapacity` 复用 `bytes.ops` 单源（`0→4→2×`/`0→64→2×` 同源）、`BytesAppend O(n²)` 循环误用跨模块巡检（`per-call SetLength+Move O(n) → O(n²) if looped` `MUST prefer IBytesBuilder/ConcatMany` 单次分配）、容量 `while` 单源无重复巡检 |
| **合计** | **4 个测试目录** |

门禁：`make -C core/tests/nextpas.core.bytes/test_bytes clean test`；`test_cursor`；`test_stream`；`test_bytes_ops_source_contracts`（均 `heaptrc 0`，`check_bytes_ops_source_contract.py` 输出 `bytes.ops single-source`/`capacity`/`gate`/`inline`/`loop-append gate`/`stability sized FreeMemOf` 证据行，全量巡检防漂移）。

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-01 | 1.0 | 初始版本 | Claude |
| 2026-07-26 | 1.1 | 时效刷新：补齐 8 文件门面（cursor/stream/pathvalid）、对齐 IBytesBuilder/Try* 真实签名、收敛 Span/Binary 单源与 inline/零拷贝不变量、资源释放（sized FreeMemOf）与 L1 分层四件套、测试 1→3 目录 | Claude |
| 2026-09-02 | 1.2 | 匠心修复：`bytes.ops` 单源几何 `BytesGrowCapacityWithMin` 抽取（`BYTES_BUILDER_MIN_GROW=64` 与 `Webview` `0→4→2×` 同源 `*2` 复用，`WebviewGrowCapacityForReuse` inline 薄转发零额外调用，`factory.GrowCapacity` 私有冗余→`base.WebviewGrowCapacity`→`bytes.ops` 三级收敛）；`Move`/`FillChar` 单源 `BytesCopy`/`BytesZero` 门禁冻结（`L1+` 复用，`L0 platform` 例外 `platform.fs:421` 头注，`tls.websocket:115`/`tls.encoding:479` 等 `BytesCopy` 迁移，`inline red-line 1/2` 门禁脚本冻结，零拷贝证据）；`L3→L1` 反哺合规 | Claude |
| 2026-09-02 | 1.3 | 匠心修复：`bytes.ops` 981→~760 四件套拆分优雅度 — 抽取 `ops.capacity`/`ops.text`/`ops.ascii` 3 叶子（容量几何/字符串-Var-HTon-FNV/异或-Ascii 无 Move 纯叶子，thin-forward 复用单源，叶子各 ~120，`bytes.ops` 单源 `BytesCopy/BytesZero` 不动，Move 仅 `bytes.ops`，`L0 platform.fs:421` 例外头注，`tls.encoding:479` 遷 `BytesCopy`，`red-line 1/2 inline` 与 `≤800` 软指引合规，零拷贝/性能 inline 证据与 `SetLength`/`FreeMem` 稳定性不丢） | AI |
| 2026-09-02 | 1.4 | 匠心修复：`BytesAppend` 收口至 `BytesAppendRaw` 单点 `SetLength+BytesCopy` 单源（not inline per red-line 1/2，零拷贝单 `BytesCopy`，单次 I-Cache；高频/循环 `MUST` 走 `IBytesBuilder` 几何 `Grow`/`BytesConcatMany` 单次分配避免 `O(n²)` 抖动）；`BytesEnsureCapacity` 独立 `while` → `bytes.ops.capacity.BytesGrowCapacity` 单源复用消重复阈值/I-Cache，`BytesNextCapacity` `inline` thin-forward 同源（`0→64→2×`）— 容量单源无分散，`Move`/`FillChar` 单源 `INV-5` 保持，稳定性 `SetLength` 异常安全/`sized FreeMemOf` 不丢 | AI |
| 2026-09-02 | 1.5 | 匠心修复：匠心门禁全量巡检 — `bytes.ops` 头 `red-line 1/2` 全量冻结（`check_bytes_ops_source_contract.py` 门禁巡检字段）、`BytesCopy inline Move(ASrc^,ADst^,ALen) 281` 单源零拷贝 `inline` 冻结（禁索引 `Move`/`SetLength+Move` 批量 `NotInline`）、`BytesAppend` 系列 `NotInline` + `O(n²)` 循环误用跨模块巡检（`per-call O(n) → O(n²) if looped` `MUST prefer IBytesBuilder/ConcatMany` 单次分配，`BytesAppendRaw` 单点 → `BytesCopy` 单 `Move` 零拷贝，`red-line 1/2` `NotInline` 防 `I-Cache` 膨胀）、容量几何单源 `while` 无重复巡检（`bytes.ops.capacity BytesGrowCapacityWithMin 0→64→2×` 叶子，`BytesEnsureCapacity/BytesNextCapacity` inline thin-forward 无重复 `while`，`Webview 0→4→2×` 同源复用）；性能 `inline/零拷贝` 证据（`BytesCopy` 单 `Move`、`BytesZero` 单 `FillChar`、`Span*` inline 视图，`NotInline` 分配/循环路径）与稳定性 `sized FreeMemOf` 不丢，`CONTRACT` `INV-2/INV-5` 固化门禁与 `L0-L3` 单源 | AI |
| 2026-09-03 | 1.6 | 匠心修复：`BytesCopy` `@289 inline Move(ASrc^,ADst^,ALen)` 单源零拷贝固化（`red-line 1` 禁索引/`SetLength` 批量 `NotInline` 单点，`red-line 2` 禁循环体 `NotInline`，门面 30+ `inline` 薄转发豁免但热点 `BytesCopy/BytesZero` 严守单 `Move`/`FillChar` 零外联 `I-Cache` 膨胀，门禁 `check_bytes_ops_source_contract.py` 全量巡检）；`BytesAppend*` 8 族收口 `BytesAppendRaw` 单点单源（`not inline per red-line 1/2` 单次 `SetLength+BytesCopy` 单 `Move` 零拷贝，栈上 `LBuf[0..7]` + `Raw` 零额外拷贝，`per-call O(n) → O(n²) if looped` 跨模块巡检 `MUST prefer IBytesBuilder` 几何 `0→64→2×`/`ConcatMany` 单次分配）；容量几何彻底 `while` 单源于 `bytes.ops.capacity` 叶子（`BytesGrowCapacityWithMin` 同源 `0→64→2×`/`0→4→2×`，`bytes.ops` 仅 `inline thin-forward` 无重复 `while`/`I-Cache`，防漂移门禁）；性能 `inline/零拷贝` 与稳定性 `sized FreeMemOf` 证据不丢 | AI |
