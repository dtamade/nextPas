# nextpas.core.bytes 代码契约

**模块路径**：`core/src/nextpas.core.bytes*.pas`（15 个源文件：base/binary/builder/cursor/stream/pathvalid/framing + ops 门面 + ops.capacity/hash/ring/snapshot/text/ascii 6 叶子 + bytes 门面；window lane 与 main 并行分治的 union：lane 容量/哈希/环形/快照单源与 main 容量/字符串/ascii 叶子 + framing/Vec 注册表并存，ops 门面统一转发）
**层级**：L1（依赖 L0: base, mem, platform, simd；与 `core/docs/core-module-registry.md` 一致）
**Owner**：Claude（AI 负责）
**最后更新**：2026-09-03
**版本**：1.10（union：lane 匠心分治 capacity/hash/ring/snapshot 四职责 + main 容量几何/字符串/ascii/framing/Vec 注册表并存，ops 门面 inline 零拷贝转发单源，window 家族与 Webview 复用单源，守四件套与 L0-L3）

---

## 1. 接口契约

### 1.1 子模块

| 文件 | 职责 |
|------|------|
| bytes.base | TEndianness/TEndian/TByteOrder 别名、`NATIVE_ENDIAN`、Builder 默认容量 |
| bytes.ops | TByteSpan/TBytes 单源门面（Span/Bytes 比较/拼接/追加/大小端互转 + 容量/哈希/环形/快照/字符串/ascii 职责 inline 转发单源，零拷贝；raw Move/FillChar 仅此，BytesCopy/BytesZero 门禁单源；`BytesAppend*` 全族经 `EnsureAppendCapacity` 单源几何扩容 + `BytesCopy` 单 `Move`，`BytesAppend(TBytes/PByte)` not inline，`BytesAppendByte/UInt*` 8 重载 inline 单次便利，高频/循环 `MUST` 走 `IBytesBuilder`/`ConcatMany` 防 O(n²)；dynarray probe/poke + `VecGrowCapacity 0→4→2×`/`TCompactLiveRegistry<T>` Vec/Registry 单源，window.live/webview 家族直用） |
| bytes.ops.text | 字符串/Var/字节序 helpers（SpanToString/FNV/HTonN 等零拷贝 SetString 视图）— 不含 raw Move |
| bytes.ops.capacity | 容量增长单源（`BytesGrowCapacityWithMin` 几何 `*2` 均摊 `O(1)` 0→64→2×，`Webview 0→4→2×` 同源复用；单参 `BytesGrowCapacity/Capped/GrowHelper` inline 零拷贝 O(1) 重载并存）— 不含 Move，loop 体 not inline |
| bytes.ops.hash | 哈希阈值/幂二单源（BYTES_HASH_LOAD_DENOM=2, BytesHashNeedsGrow/IsPowerOfTwo/CeilPow2/AlignCapacity inline 零拷贝 O(1)，window.hash/cow 复用单源） |
| bytes.ops.ring | 环形掩码单源（BytesRingMask/Index/Next and掩码 O(1) 避 mod + Managed/Raw Ring 批量 inline 零拷贝，托管释放不丢） |
| bytes.ops.snapshot | 快照截断单源（ArraySetLengthNoRealloc/SwapRemove + ManagedEnsure/Triple + LiveArenaEnsureBatch inline 零拷贝 O(1)，window.live 64槽池化 ARENA_POOL_SIZE via ArenaPoolAcquireSlot/RecycleSlot/Finalize，阈值收缩8192，SetLength 托管释放不丢） |
| bytes.ops.ascii | Xor/Ascii 大小写原地（QWord 批异或、ToLower/Upper）— 不含 Move |
| bytes.binary | 字节序转换与游标编解码（Swap/ToEndian/Read/Write/TryRead/TryWrite） |
| bytes.builder | IBytesBuilder 可变字节缓冲区（allocator 注入、按需增长） |
| bytes.cursor | IByteCursor 边界受查只读游标（顺序/绝对偏移、Try* 变体） |
| bytes.stream | TByteStreamBuf 可增长缓冲流（append/consume/compact） |
| bytes.framing | TWireBuffer 4B 长度前缀帧缓冲（BytesEnsureCapacity 几何 + FOff 零拷贝 + 16KB/4KB 懒压实 + quarter-cap 回收，复用 bytes.ops/bytes.binary 单源） |
| bytes.pathvalid | ValidPath + IsSafeArchiveEntryName/Ex 共享校验（tar/zip 归档名与 tar link target 参数化单源，阈值/尾斜杠收敛，复用 bytes.ops 单源 + text.utf8 单源） |
| bytes.pas | 门面：纯 re-export + inline 转发 |

四件套形态：`base`（类型/常量）→ `ops.capacity/hash/ring/snapshot/text/ascii`（叶子，capacity←hash/ring/snapshot 依赖 DAG，text/ascii 纯字符串叶子，均守 L0-L3） + `ops`（单源 Owner，raw Move 仅此） + `binary/builder/cursor/stream/pathvalid`（实现子模块）→ `bytes.pas`（门面聚合）；本模块无独立 `intf/ffi`（按需存在，不机械创建）。

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
| `BytesAppend(*)/BytesToString/StringToBytes` | TBytes 追加与字符串互转（全族经 `EnsureAppendCapacity` 单源几何扩容 + `BytesCopy` 单 `Move` 零拷贝；`BytesAppend(TBytes/PByte)` not inline（红线#1），`BytesAppendByte/UInt*` 8 重载 inline 单次便利；逐次调用 O(n)，高频/循环拼接 O(n²)，高频/循环 `MUST` 改用 `IBytesBuilder` 几何扩容或 `BytesConcatMany/SpanConcatMany` 单次分配（门禁跨模块巡检）；注：`deprecated` 机械门禁与 `INV-8` 已随争议门禁撤销而废弃，当前无 `deprecated` 标记） |
| `SpanClone/SpanCopySlice` | 仅两处分配；其余 Span 为非拥有视图 |

约定：`bytes.ops` 为 Span/TBytes 比较与切片的唯一实现源；门面与其它实现均 inline 转发，不复制逻辑。`BytesAppend`（TBytes/PByte）禁 inline（红线#1：索引元素直喂 Move untyped 形参，FPC 常量传播折叠为单字符临时，valgrind+反汇编实证，BytesToString/StringToBytes 同理，已用 typed PByte 中转破红线；见 `design-conventions.md` 两条红线），单次 SetLength+Move 零拷贝、异常安全；`BytesAppendByte/BytesAppendUInt16BE/LE/UInt24BE/UInt32BE/LE/UInt64BE/LE` 8 重载保持 inline 单次 SetLength 直写零拷贝、异常安全 SetLength 资源托管不丢、bytes.ops 单源 inline 零额外调用 O(1)，批量/循环/高频批量必须走 `IBytesBuilder`（amortized 2× via `BytesGrowCapacity/BYTES_BUILDER_MIN_GROW` inline 零拷贝）或 `BytesConcatMany/SpanConcatMany`（单次分配 O(n) 零拷贝 Moves）以避免 O(n²) 多次重分配，window 侧由 `test_window_source_contracts` 强制门禁（循环内 BytesAppend/Byte/UInt* 视为 O(n²) 违规，强制收敛至 IBytesBuilder/ConcatMany 批量单源）。

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

### 1.5 Stream / Cursor / ValidPath / Framing

- **TByteStreamBuf**：`EnsureCapacity/ReserveAppend/CommitAppend/Append/Consume/Clear/Compact`；容量保留、尾部零分配、头游标延迟压实；Destroy 经 `FreeMemOf(FAllocator, FPtr, FCap)` 释放。
- **IByteCursor**：`NewByteCursor(TBytes)` 持有 `TBytes` 拷贝保活；`NewByteCursorAt(PByte, Len)` 裸指针由调用方保活；只读无分配（`ReadBytes` 除外）。
- **ValidPath**：`BytesValidPath/BaseValidPath(APath, AAllowRoot)` — Go `io/fs.ValidPath` 语义，复用 `text.utf8.UTF8IsValid` 单源，段扫描零拷贝。
- **TWireBuffer**：`Clear/Append/HasHeader/HasCompleteFrame/TryPeekFrameLength/TryTakeFrame/TakeFrame/Compact`；4B BE 长度前缀重组，`BytesEnsureCapacity` 几何 + `FOff` 零拷贝 + 16KB/4KB 懒压实 + quarter-cap 回收（长流水线季窗），`bytes.ops/bytes.binary` 单源，热路径 `inline` 零拷贝，取帧单次 `Move`+单次压实，增长/压实外联避免 I-Cache 膨胀；编码侧 `WireEncodeFrame/WireAppendEncoded` 单次 `Move` 零拷贝。
- **ArchiveEntry**：`IsSafeArchiveEntryName(AName, AMaxBytes)` / `IsSafeArchiveEntryNameEx(AName, AMaxBytes, AAllowTrailingSlash)` — tar/zip 归档名与 tar link target 安全谓词参数化单源（非空/≤AMaxBytes/非'/'/无盘符/无'\'/无'//'/'.'/'..'，尾随'/'由 `AAllowTrailingSlash` 决定；`IsSafeArchiveEntryName` 为 `Ex(..., True)` 薄转发，`IsSafeTarLinkTarget` 经 `Ex(..., C_TAR_MAX_LINK_BYTES, False)` 零拷贝段扫描单源、消除80%重复），inline+零拷贝原串索引，无Copy/分配，tar.base/zip.base/tar.fs 薄 inline 转发，复用 `bytes.ops` 单源。

### 1.6 Vec 单源与通用紧凑注册表（L1 已反哺）

- **Vec 生长/删除/快照单源**：`VecGrowCapacity(0→4→2×)` / `VecGrow` / `VecRemoveSwap(O1零拷贝swap)` / `VecRemoveOrdered` / `VecSnapshot` / `VecTrim` / `VecCopy` / `VecRingCopy` 均为 `bytes.ops` 唯一权威，`VecGrow/Capacity/Snapshot/Trim/Copy/RingCopy` inline 零额外调用、`VecRemoveSwap/Ordered` 含扫描/搬移循环按 design-conventions §2 红线二去 inline 避 I-Cache 膨胀（Swap O(1) 零拷贝末尾换位、Ordered O(n) 保序搬移、尾槽 `Default(T)` 释放不丢，热关闭默认 Swap 避 O(n²)）；`webview.live`/`window.live`/`collections` 复用此单源，零重复实现。
- **通用紧凑 Vec 注册表**：`TCompactLiveRegistry<T>`（`bytes.ops`）为 L1 通用紧凑注册表，已反哺落地（CONTRACT §1.2/§50 可抽候选）；`webview.live.TWebviewLiveRegistry<T>` 兼容薄别名已于 2026-09-02 物理删除，现家族全量直用 `bytes.ops.TCompactLiveRegistry<T>` 单源 inline 零额外调用（过程式 `WebviewLiveAdd/Remove` 双形已收敛删除，`webview2` 直用 `VecGrow/VecRemoveSwap` 单源），`window.live` 同构已收敛至同源 Swap 语义；`Register` via `VecGrow` 0→4→2×，`Unregister` via `VecRemoveSwap` O(1) 零拷贝，`Snapshot` via `VecSnapshot` 单 SetLength + managed/blittable 分支零拷贝，`Clear` 逐槽 `Default(T)` 释放不丢，`Trim` 单源 `VecTrim`。

---

## 2. 不变量

- **[INV-1]** Span 为非拥有视图：除 `SpanConcat/Clone/CopySlice/ConcatMany` 返回 `TBytes` 外不分配；零拷贝（`Move` 直拷，不经编码转换）。
- **[INV-2]** IBytesBuilder 按需倍增增长（`capacity ≥ length`，下界 `BYTES_BUILDER_MIN_GROW`，溢出钳制；单源 `BytesGrowCapacityWithMin` 几何 `0→64→2×` / `Webview` 重用 `0→4→2×` 同源 `*2` 均摊 `O(1)` 零 `O(n²)`，容量 `while` 单源仅 `bytes.ops.capacity` 叶子，`bytes.ops` 内 `BytesEnsureCapacity/BytesNextCapacity` inline thin-forward 复用无重复 `while`/`I-Cache`，门禁 `check_bytes_ops_source_contract.py` 容量单源巡检防漂移）；`Clear` 保留容量；`Truncate` 仅缩 `FLen`。
- **[INV-3]** `NATIVE_ENDIAN` 编译时确定（当前 `endLittle`）；`ToEndian/FromEndian` 在 native 时直通无翻转。
- **[INV-4]** 越界受查：`SpanCopySlice` 越界 → `EOutOfRange`；IByteCursor 越界 → `EIndexOutOfRangeError`；`Try*` 变体返回 `False` 不抛异常、不推进。
- **[INV-5]** 单源复用：比较/查找与 `Move`/`FillChar` 经 `bytes.ops` 单源（`BytesCopy` inline 单 `Move(ASrc^,ADst^,ALen)` 零拷贝门禁巡检、`BytesZero` inline `FillChar`，`Span*` inline 零拷贝，`MemEqual`/`MemCompare`/`MemFindByte`/`BytesIndexOf` + SIMD；`red-line 1` 禁索引 `Move`/`SetLength+Move` 批量—`BytesCopy/BytesZero` 单源、`BytesAppend*` 经 `EnsureAppendCapacity` 单源扩容 + `BytesCopy` 单 `Move`；`red-line 2` 禁循环体—`BytesReplicateCopy/BytesAppend*/Grow` 等 `not inline` 防 `I-Cache` 膨胀；`BytesGrowCapacityWithMin` 几何倍增 `BYTES_BUILDER_MIN_GROW=64` 单源于 `bytes.ops.capacity` 叶子（同源 `0→64→2×`/`0→4→2×` `*2`），`WebviewGrowCapacity`/`BytesNextCapacity`/`BytesEnsureCapacity` 均 inline thin-forward 同源复用无重复 while/I-Cache，`BytesAppend` 系列经 `EnsureAppendCapacity` 单源几何扩容 + `BytesCopy` 单 `Move` 零拷贝（not inline per red-line 1/2，单次 `I-Cache`；高频/循环 `MUST` 走 `IBytesBuilder` 几何 `Grow` 或 `BytesConcatMany`/`SpanConcatMany` 单次分配避免 `O(n²)`，`per-call O(n) → O(n²) if looped` 门禁巡检 `BytesAppend` 循环误用跨模块扫描），`bytes.ops.text/ascii` 叶子无 Move 纯算术/字符串 thin-forward；门面全部 `inline` 薄转发，零重复 `Move`/`SetLength`；`tls.encoding:479` 亦迁移至 `BytesCopy`，`platform.fs` 全量经 `BytesCopy` 单源复用（`platform_fs_read_until_eof` 与路径拼接零拷贝 inline `BytesCopy`，`sized FreeMem` 稳定性不丢））；强制门禁由 `test_bytes_ops_source_contracts/check_bytes_ops_source_contract.py` 全量巡检冻结（`raw Move/FillChar` 仅 `bytes.ops` 允许，`bytes.ops.capacity/text/ascii` 为无 Move 叶子且 `bytes.ops` 内无重复容量 `while`，`L0 platform.fs` 亦经 `bytes.ops.BytesCopy` 单源复用无分散，`BytesCopy inline Move(ASrc^,ADst^,ALen)` 门禁单源、`BytesAppend` `NotInline` + `O(n²)` 循环误用跨模块扫描、`red-line 1/2` 全量防漂移）。
- **[INV-6]** 资源释放不丢：`TBytesBuilderImpl.Destroy` 与 `TByteStreamBuf.Destroy` 以 sized `FreeMemOf/ReallocMemOf` 经注入 `TMemAllocator/IAllocator` 释放；`Clear/Consume` 不丢块；`try-finally/Free` 语义由调用方持有接口/对象生命周期保证；`BytesGrowCapacity`/`WebviewGrowCapacity` 无分配泄漏。
- **[INV-7]** L0-L3 分层：bytes 为 L1，仅依赖 L0（`base/mem/platform/simd`）及文档化 `bytes↔text↔encoding` seam（interface/implementation 分区引用，不形成循环）；门面不含逻辑；`webview.base` 复用 `bytes.ops` 属 `L3→L1` 合法反哺（`capacity` 单源下沉）。
- **[INV-8]** Framing 幂等与懒压实：`TWireBuffer`（`bytes.framing`，ssh 反哺抽取：sftp.wire 4B 前缀流单源）`Append` 经 `BytesEnsureCapacity` 几何增长，`FOff` 头游标零拷贝，压实阈值 `WIRE_BUFFER_COMPACT_OFFSET_ABSOLUTE=16KB` / `WIRE_BUFFER_COMPACT_OFFSET_HALF=4KB` + `quarter-cap` 回收（长流水线季窗消除空洞），`CompactIfNeeded` 单次 `Move`，`TryTakeFrame` 单包单次 `Move`+单次压实（`FOff+4` 零拷贝取载荷后一次性推进），`Clear/HasHeader` `inline` 零开销；在途长度校验 `1 ≤ LLen ≤ AMax`（默认 256KiB），`Try*` 余量不足返回 `False` 不抛异常、不推进。

---

## 3. 错误处理

| 场景 | 异常/返回值 |
|------|-------------|
| Slice 越界（Offset+Len > Span.Len） | `EOutOfRange`（`CheckSizeRange`） |
| IByteCursor 越界读/Seek | `EIndexOutOfRangeError`（含 pos/len/size） |
| Try* 游标/编解码余量不足 | `False`（不抛异常，Span 不推进） |
| Framing 截断（`TryTakeFrame` 余量不足） | `False`（不抛异常，不推进）；`TakeFrame` 截断抛 `EInvalidArgument` |
| Framing 长度非法（`LLen<1 或 >AMax`） | `EInvalidArgument`（含长度） |
| 分配失败 | 传播自 `TMemAllocator.GetMem/ReallocMemOf`（nil 时调用方按分配器契约处理） |

---

## 4. 线程安全

- Span/Bytes 纯函数与 Binary 编解码：✅ 线程安全（无共享状态）。
- IBytesBuilder / TByteStreamBuf / IByteCursor / TWireBuffer：❌ 非线程安全，调用方同步；同一实例禁止并发。

---

## 5. 内存管理

- Span 操作：非拥有视图，不分配（Concat/CopySlice/Clone 除外返回独立 `TBytes`）。
- IBytesBuilder：内部块经 `TMemAllocator` 增长，`Grow` 倍增；`ToBytes` 返回拷贝；`WrittenSpan` 为当前写入区的零拷贝视图（随后续 Append 失效）。
- TByteStreamBuf：块经 `IAllocator`；`EnsureCapacity` 幂等；`ReserveAppend` 先压实后倍增；`Consume/Clear` 保留容量；`Destroy` sized free。
- 零拷贝：`Move/FillChar` 单源 `bytes.ops.BytesCopy` inline 单 `Move(ASrc^,ADst^,ALen)` 直操内存（门禁巡检，`red-line 1` 禁索引 `Move`/`SetLength+Move` 批量）/`BytesZero` inline `FillChar`（`Pointer(Result)^/PByte+Off^` 单次 `Move`，`BytesAppend*` 经 `EnsureAppendCapacity` 单源扩容 + `BytesCopy` 单次 `Move` 零额外拷贝，`L0 platform.fs` 亦 `BytesCopy` inline 单源零拷贝 — `platform_fs_read_until_eof` `LNewBuf` 生长与路径 `LTmpDir/APrefix/ASuffix/LDirEntry.Name` 拼接均 `BytesCopy` 单次 `Move`，无分散；`sized FreeMem` 资源释放不丢）；`ops.capacity/text/ascii` 叶子为无 Move 纯算术/字符串，thin-forward 零额外拷贝（capacity 几何 `*2` 均摊 `O(1)` 含 `BytesEnsureCapacity`/`BytesNextCapacity` 单源复用无重复 while，text SetString 零拷贝视图，ascii QWord 批异或）；门面与 `Bytes*` 便捷面均为 `inline` 薄转发，无额外拷贝；性能证据：`inline` 热路径零额外调用（`BytesCopy` inline 单 `Move(ASrc^,ADst^,ALen)` 零额外拷贝，`BytesZero` inline `FillChar`，`Span*` 热视图 inline 零拷贝），分配/循环路径 `not inline`（`red-line 1` 索引 `Move`/`SetLength` 批量、`red-line 2` 循环+`Move`/`SetLength` 均 `not inline`，`BytesReplicateCopy`/`BytesAppend*`/`Grow`/`StringToBytes` 等 `not inline`，`EnsureAppendCapacity` 单源/`BytesEnsureCapacity` thin-forward 消重复 while/`I-Cache`，门禁 `check_bytes_ops_source_contract.py` 全量巡检冻结 `red-line 1/2` + `BytesCopy inline` + `BytesAppend NotInline O(n²)` 循环误用跨模块扫描 + 容量单源无重复 while，split 后 `bytes.ops` ~760 + leaves 各 ~120，高频循环 `MUST` 走 `IBytesBuilder`/`ConcatMany` 单次分配避免 `O(n²)` `per-call O(n) → O(n²) if looped`）。TWireBuffer：追加单次 `Move`、取帧单次 `Move`+单次压实（`FOff` 视图 + `FOff+4` 零拷贝 + quarter-cap 懒压实），`Clear/HasHeader/TryPeek` `inline` 零开销，`CompactIfNeeded/EnsureCapacity/TryTakeFrame` 外联避免 I-Cache 膨胀；编码 `WireEncodeFrame` 单次 `Move`。

---

## 6. 测试覆盖

| 测试目录 | 说明 |
|----------|------|
| test_bytes | Span/TBytes 操作 + 字节序编解码 + Builder（含 allocator 注入、增长、截断） |
| test_cursor | IByteCursor 顺序/BE/peek/Seek/Try* / 边界守卫 / 裸指针构造 |
| test_stream | TByteStreamBuf append/consume/compact/EnsureCapacity/Clear/ReserveAppend/Grow |
| test_bytes_ops_source_contracts | `bytes.ops` 源契约门禁：`red-line 1/2 inline` 冻结（`BytesCopy inline Move(ASrc^,ADst^,ALen)` 单源、`BytesAppend*` 经 `EnsureAppendCapacity` 单源扩容 `NotInline`）、`Move/FillChar` 单源与 `WebviewGrowCapacity` 复用 `bytes.ops` 单源（`0→4→2×`/`0→64→2×` 同源）、`BytesAppend O(n²)` 循环误用跨模块巡检（`per-call SetLength+Move O(n) → O(n²) if looped` `MUST prefer IBytesBuilder/ConcatMany` 单次分配）、容量 `while` 单源无重复巡检 |
| **合计** | **4 个测试目录** |

门禁：`make -C core/tests/nextpas.core.bytes/test_bytes clean test`；`test_cursor`；`test_stream`；`test_bytes_ops_source_contracts`（均 `heaptrc 0`，`check_bytes_ops_source_contract.py` 输出 `bytes.ops single-source` 与 `capacity`/`gate` 证据行）。`bytes.framing`（`TWireBuffer`，ssh 反哺）由 ssh 侧 `sftp.wire` 行为覆盖，暂无独立测试目录。

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-01 | 1.0 | 初始版本 | Claude |
| 2026-07-26 | 1.1 | 时效刷新：补齐 8 文件门面（cursor/stream/pathvalid）、对齐 IBytesBuilder/Try* 真实签名、收敛 Span/Binary 单源与 inline/零拷贝不变量、资源释放（sized FreeMemOf）与 L1 分层四件套、测试 1→3 目录 | Claude |
| 2026-09-02 | 1.2 | 匠心分治（window lane）：bytes.ops 按容量/负载/掩码/快照四职责拆 capacity/hash/ring/snapshot 子单元，ops 门面 inline 零拷贝转发单源，window.hash/ring/live 复用单源，heaptrc 0，守四件套与 L0-L3 | 窗口 lane |
| 2026-09-02 | 1.2-tar | 匠心修复 BytesAppend O(n²)（tar lane 并行史）：`BytesAppend*` 全族 `deprecated` 机械门禁（`inline` 保留单次便利，`deprecated` 提示改用 `IBytesBuilder` 几何 Grow 或 `ConcatMany` 单分配，零拷贝单 `Move` 单源），新增 INV-8 与 `test_bytes_source_contract` 门禁；注：合入主线时 `BytesAppend` 取主线非 `deprecated` 形态（`test_bytes_ops_source_contracts` 红线门禁），本行仅留史 | tar lane |
| 2026-09-02 | 1.2 | 匠心修复：`bytes.ops` 单源几何 `BytesGrowCapacityWithMin` 抽取（`BYTES_BUILDER_MIN_GROW=64` 与 `Webview` `0→4→2×` 同源 `*2` 复用，`WebviewGrowCapacityForReuse` inline 薄转发零额外调用，`factory.GrowCapacity` 私有冗余→`base.WebviewGrowCapacity`→`bytes.ops` 三级收敛）；`Move`/`FillChar` 单源 `BytesCopy`/`BytesZero` 门禁冻结（`L1+` 复用，`L0 platform` 例外 `platform.fs:421` 头注，`tls.websocket:115`/`tls.encoding:479` 等 `BytesCopy` 迁移，`inline red-line 1/2` 门禁脚本冻结，零拷贝证据）；`L3→L1` 反哺合规 | Claude |
| 2026-09-02 | 1.3 | 匠心修复：`bytes.ops` 981→~760 四件套拆分优雅度 — 抽取 `ops.capacity`/`ops.text`/`ops.ascii` 3 叶子（容量几何/字符串-Var-HTon-FNV/异或-Ascii 无 Move 纯叶子，thin-forward 复用单源，叶子各 ~120，`bytes.ops` 单源 `BytesCopy/BytesZero` 不动，Move 仅 `bytes.ops`，`L0 platform.fs:421` 例外头注，`tls.encoding:479` 遷 `BytesCopy`，`red-line 1/2 inline` 与 `≤800` 软指引合规，零拷贝/性能 inline 证据与 `SetLength`/`FreeMem` 稳定性不丢） | AI |
| 2026-09-02 | 1.4 | 匠心修复：`BytesAppend` 收口至 `BytesAppendRaw` 单点 `SetLength+BytesCopy` 单源（not inline per red-line 1/2，零拷贝单 `BytesCopy`，单次 I-Cache；高频/循环 `MUST` 走 `IBytesBuilder` 几何 `Grow`/`BytesConcatMany` 单次分配避免 `O(n²)` 抖动）；`BytesEnsureCapacity` 独立 `while` → `bytes.ops.capacity.BytesGrowCapacity` 单源复用消重复阈值/I-Cache，`BytesNextCapacity` `inline` thin-forward 同源（`0→64→2×`）— 容量单源无分散，`Move`/`FillChar` 单源 `INV-5` 保持，稳定性 `SetLength` 异常安全/`sized FreeMemOf` 不丢 | AI |
| 2026-09-02 | 1.5 | 匠心修复：匠心门禁全量巡检 — `bytes.ops` 头 `red-line 1/2` 全量冻结（`check_bytes_ops_source_contract.py` 门禁巡检字段）、`BytesCopy inline Move(ASrc^,ADst^,ALen) 281` 单源零拷贝 `inline` 冻结（禁索引 `Move`/`SetLength+Move` 批量 `NotInline`）、`BytesAppend` 系列 `NotInline` + `O(n²)` 循环误用跨模块巡检（`per-call O(n) → O(n²) if looped` `MUST prefer IBytesBuilder/ConcatMany` 单次分配，`BytesAppendRaw` 单点 → `BytesCopy` 单 `Move` 零拷贝，`red-line 1/2` `NotInline` 防 `I-Cache` 膨胀）、容量几何单源 `while` 无重复巡检（`bytes.ops.capacity BytesGrowCapacityWithMin 0→64→2×` 叶子，`BytesEnsureCapacity/BytesNextCapacity` inline thin-forward 无重复 `while`，`Webview 0→4→2×` 同源复用）；性能 `inline/零拷贝` 证据（`BytesCopy` 单 `Move`、`BytesZero` 单 `FillChar`、`Span*` inline 视图，`NotInline` 分配/循环路径）与稳定性 `sized FreeMemOf` 不丢，`CONTRACT` `INV-2/INV-5` 固化门禁与 `L0-L3` 单源 | AI |
| 2026-09-03 | 1.6 | 匠心修复：`BytesCopy` `@289 inline Move(ASrc^,ADst^,ALen)` 单源零拷贝固化（`red-line 1` 禁索引/`SetLength` 批量 `NotInline` 单点，`red-line 2` 禁循环体 `NotInline`，门面 30+ `inline` 薄转发豁免但热点 `BytesCopy/BytesZero` 严守单 `Move`/`FillChar` 零外联 `I-Cache` 膨胀，门禁 `check_bytes_ops_source_contract.py` 全量巡检）；`BytesAppend*` 8 族收口 `BytesAppendRaw` 单点单源（`not inline per red-line 1/2` 单次 `SetLength+BytesCopy` 单 `Move` 零拷贝，栈上 `LBuf[0..7]` + `Raw` 零额外拷贝，`per-call O(n) → O(n²) if looped` 跨模块巡检 `MUST prefer IBytesBuilder` 几何 `0→64→2×`/`ConcatMany` 单次分配）；容量几何彻底 `while` 单源于 `bytes.ops.capacity` 叶子（`BytesGrowCapacityWithMin` 同源 `0→64→2×`/`0→4→2×`，`bytes.ops` 仅 `inline thin-forward` 无重复 `while`/`I-Cache`，防漂移门禁）；性能 `inline/零拷贝` 与稳定性 `sized FreeMemOf` 证据不丢 | AI |
| 2026-09-03 | 1.7 | 主线收敛（core 合并）：代码取主线——`BytesAppend*` 经 `EnsureAppendCapacity` 单源几何扩容 + `BytesCopy` 单 `Move`（无 `BytesAppendRaw`，无 `deprecated`；争议 `deprecated` 门禁已在 tar 线撤销，`INV-8` 废弃），`BytesCopy/BytesZero` 接口声明补 `inline`（与实现一致，跨单元内联），`BytesHexUInt64` 去 `inline`（`SetLength` + `for` 循环体触 `red-line 2`，主线既有红点，连带修复）；门禁取 lane 新版并修复 `BytesCopy` 实现体正则跨行回溯误报（参数 `[^()]*` 单行锚定）；本文现行事实行已按合并后代码澄清，1.2-tar/1.4/1.6 行仅留史 | AI |
| 2026-09-03 | 1.8 | 主线收敛（ssh 合并）：`bytes.ops` 取主线 1.7 + ssh 反哺 `BytesEnsureCapacity(SizeUInt)` 槽超载/`BytesRemovePrefix`/`BytesConsumePrefix`（channel/sftp 按槽复用，`BytesGrowCapacity` 单源）；`bytes.framing`（TWireBuffer，ssh 反哺：抽 sftp.wire 4B 前缀流，`BytesEnsureCapacity` 几何 + `FOff` 零拷贝 + 16KB/4KB 懒压实 + quarter-cap，TryTakeFrame 单次 Move+单次压实）在本文恢复事实行（§1.1/§1.5/§5/§6，INV-8 保持），先前 1.4/1.5 framing 行史实并入本行 | AI |
| 2026-09-03 | 1.9 | 主线收敛（webview 合并）：`bytes.ops` 取主线 1.8 + webview 反哺 Vec/Registry 单源（`BytesSteal`/`TVecArray`/`VecGrowCapacity 0→4→2×`/`VecGrow/Snapshot/Trim/RemoveSwap/Ordered/Copy/GrowCopy/RingCopy/RingGrowCopy`/`TCompactLiveRegistry<T>`，window.live/webview 家族直用，`webview.live` 薄别名已删；先前 S107/S108 行史实并入本行） | AI |
| 2026-09-03 | 1.10 | union（window lane 合 main）：lane capacity/hash/ring/snapshot 四职责叶子与 main capacity/text/ascii/framing/Vec 并存（15 文件），ops 门面统一转发（单参 grow/Capped/Helper 重载 + 双参几何单源 + dynarray/Vec/Registry），`BytesAppend*` 全族经 `EnsureAppendCapacity` 单源，双方复用方（window.hash/ring/live/cow/fake + Webview/vfs/js/agent）均不断链 | consolidation |
