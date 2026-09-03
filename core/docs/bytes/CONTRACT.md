# nextpas.core.bytes 代码契约

**模块路径**：`core/src/nextpas.core.bytes*.pas`（12 个源文件：base/binary/builder/cursor/stream/pathvalid + ops.capacity/hash/ring/snapshot + ops 门面 + bytes 门面）
**层级**：L1（依赖 L0: base, mem, platform, simd；与 `core/docs/core-module-registry.md` 一致）
**Owner**：Claude（AI 负责）
**最后更新**：2026-09-02
**版本**：1.2（匠心分治：bytes.ops 902→713 行 <800 软阈值，按容量/负载/掩码/快照四职责拆为 capacity/hash/ring/snapshot 子单元，ops 门面 inline 零拷贝转发单源，window 家族复用单源，heaptrc 0，守四件套与 L0-L3）

---

## 1. 接口契约

### 1.1 子模块

| 文件 | 职责 |
|------|------|
| bytes.base | TEndianness/TEndian/TByteOrder 别名、`NATIVE_ENDIAN`、Builder 默认容量 |
| bytes.ops.capacity | 容量增长单源 `0→32→2×`（BytesGrowCapacity/Reserve/EnsureCapacity inline 零拷贝 O(1)，BYTES_BUILDER_MIN_GROW 单源，防 O(n²)） |
| bytes.ops.hash | 哈希阈值/幂二单源（BYTES_HASH_LOAD_DENOM=2, BytesHashNeedsGrow/IsPowerOfTwo/CeilPow2/AlignCapacity inline 零拷贝 O(1)，window.hash/cow 复用单源） |
| bytes.ops.ring | 环形掩码单源（BytesRingMask/Index/Next and掩码 O(1) 避 mod + Managed/Raw Ring 批量 inline 零拷贝，Move 零拷贝，托管释放不丢） |
| bytes.ops.snapshot | 快照截断单源（ArraySetLengthNoRealloc/SwapRemove + ManagedEnsure/Triple + LiveArenaEnsureBatch inline 零拷贝 O(1)，window.live 64槽池化单源 ARENA_POOL_SIZE=BYTES_BUILDER_MIN_GROW 池化通用抽象 via ArenaPoolAcquireSlot/RecycleSlot/Finalize 0→64→2× 单源 Burst64 fast fallback 3CAS+cpu_pause ≤48ns P95 <1µs 阈值收缩8192 inline 零拷贝，SetLength 托管释放不丢） |
| bytes.ops | TByteSpan/TBytes 门面（Span/Bytes 比较/拼接/追加/大小端互转 + 容量/哈希/环形/快照四职责 inline 转发单源，~713行 <800，原 902 行已分治，零拷贝） |
| bytes.binary | 字节序转换与游标编解码（Swap/ToEndian/Read/Write/TryRead/TryWrite） |
| bytes.builder | IBytesBuilder 可变字节缓冲区（allocator 注入、按需增长） |
| bytes.cursor | IByteCursor 边界受查只读游标（顺序/绝对偏移、Try* 变体） |
| bytes.stream | TByteStreamBuf 可增长缓冲流（append/consume/compact） |
| bytes.pathvalid | ValidPath 共享校验（复用 bytes.ops 单源 + text.utf8 单源） |
| bytes.pas | 门面：纯 re-export + inline 转发 |

四件套形态：`base`（类型/常量）→ `ops.capacity/hash/ring/snapshot + ops 门面 + binary/builder/cursor/stream/pathvalid`（实现子模块，ops 四职责已分治 capacity←hash/ring/snapshot 依赖 DAG 守 L0-L3）→ `bytes.pas`（门面聚合）；本模块无独立 `intf/ffi`（按需存在，不机械创建）。

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
| `BytesAppend/BytesAppendByte/BytesAppendUInt* /BytesToString/StringToBytes` | TBytes 追加与字符串互转（AppendByte/UInt* 8 重载 inline 单次 SetLength 直写零拷贝，单次便利；批量/高频 O(n²) 必须走 IBytesBuilder/ConcatMany 单源） |
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

### 1.5 Stream / Cursor / ValidPath

- **TByteStreamBuf**：`EnsureCapacity/ReserveAppend/CommitAppend/Append/Consume/Clear/Compact`；容量保留、尾部零分配、头游标延迟压实；Destroy 经 `FreeMemOf(FAllocator, FPtr, FCap)` 释放。
- **IByteCursor**：`NewByteCursor(TBytes)` 持有 `TBytes` 拷贝保活；`NewByteCursorAt(PByte, Len)` 裸指针由调用方保活；只读无分配（`ReadBytes` 除外）。
- **ValidPath**：`BytesValidPath/BaseValidPath(APath, AAllowRoot)` — Go `io/fs.ValidPath` 语义，复用 `text.utf8.UTF8IsValid` 单源，段扫描零拷贝。

---

## 2. 不变量

- **[INV-1]** Span 为非拥有视图：除 `SpanConcat/Clone/CopySlice/ConcatMany` 返回 `TBytes` 外不分配；零拷贝（`Move` 直拷，不经编码转换）。
- **[INV-2]** IBytesBuilder 按需倍增增长（`capacity ≥ length`，下界 `BYTES_BUILDER_MIN_GROW`，溢出钳制）；`Clear` 保留容量；`Truncate` 仅缩 `FLen`。
- **[INV-3]** `NATIVE_ENDIAN` 编译时确定（当前 `endLittle`）；`ToEndian/FromEndian` 在 native 时直通无翻转。
- **[INV-4]** 越界受查：`SpanCopySlice` 越界 → `EOutOfRange`；IByteCursor 越界 → `EIndexOutOfRangeError`；`Try*` 变体返回 `False` 不抛异常、不推进。
- **[INV-5]** 单源复用：比较/查找经 `bytes.ops`（`MemEqual/MemCompare/MemFindByte/BytesIndexOf` + SIMD）；门面全部 `inline` 转发，不分叉实现。
- **[INV-6]** 资源释放不丢：`TBytesBuilderImpl.Destroy` 与 `TByteStreamBuf.Destroy` 以 sized `FreeMemOf/ReallocMemOf` 经注入 `TMemAllocator/IAllocator` 释放；`Clear/Consume` 不丢块；`try-finally/Free` 语义由调用方持有接口/对象生命周期保证。
- **[INV-7]** L0-L3 分层：bytes 为 L1，仅依赖 L0（`base/mem/platform/simd`）及文档化 `bytes↔text↔encoding` seam（interface/implementation 分区引用，不形成循环）；门面不含逻辑。

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
- 零拷贝：`Move/FillChar` 直操内存；门面与 `Bytes*` 便捷面均为 `inline` 转发，无额外拷贝。

---

## 6. 测试覆盖

| 测试目录 | 说明 |
|----------|------|
| test_bytes | Span/TBytes 操作 + 字节序编解码 + Builder（含 allocator 注入、增长、截断） |
| test_cursor | IByteCursor 顺序/BE/peek/Seek/Try* / 边界守卫 / 裸指针构造 |
| test_stream | TByteStreamBuf append/consume/compact/EnsureCapacity/Clear/ReserveAppend/Grow |
| **合计** | **3 个测试目录** |

门禁：`make -C core/tests/nextpas.core.bytes/test_bytes clean test`；`test_cursor`；`test_stream`（均 `heaptrc 0`）。

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-01 | 1.0 | 初始版本 | Claude |
| 2026-07-26 | 1.1 | 时效刷新：补齐 8 文件门面（cursor/stream/pathvalid）、对齐 IBytesBuilder/Try* 真实签名、收敛 Span/Binary 单源与 inline/零拷贝不变量、资源释放（sized FreeMemOf）与 L1 分层四件套、测试 1→3 目录 | Claude |
| 2026-09-02 | 1.2 | 匠心分治：bytes.ops 902→713 行 <800 软阈值，按容量/负载/掩码/快照四职责拆 capacity/hash/ring/snapshot 子单元（各 <200 行），ops 门面 inline 零拷贝转发单源，window.hash/ring/live 复用单源无重复，heaptrc 0 资源托管不丢，守四件套与 L0-L3 | 窗口 lane |
