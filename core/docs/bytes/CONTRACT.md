# nextpas.core.bytes 代码契约

**模块路径**：`core/src/nextpas.core.bytes*.pas`（7 个源文件）
**层级**：L1（依赖 L0: base, simd impl-only）
**Owner**：Claude（AI 负责）
**最后更新**：2026-08-31
**版本**：1.2

---

## 1. 接口契约

### 1.1 子模块

| 文件 | 职责 |
|------|------|
| bytes.base | TEndianness 枚举 (endLittle/endBig), NATIVE_ENDIAN 常量, 容量常量 |
| bytes.ops | TByteSpan/TBytes 零拷贝操作 (Equal/Compare/IndexOf/Fill/Reverse/Concat/Clone/CopySlice) + Unsigned  helpers + Append |
| bytes.binary | 字节序转换 (Swap16/32/64, ToEndian/FromEndian, Read/Write LE/BE, TryRead/TryWrite) |
| bytes.builder | IBytesBuilder 可变字节缓冲区 |
| bytes.cursor | IByteCursor 边界受查只读游标 |
| bytes.stream | TByteStreamBuf 可增长缓冲流 |
| bytes.pas | 门面 (re-export base/ops/binary/builder/cursor/stream) |

### 1.2 IBytesBuilder 接口

```pascal
IBytesBuilder = interface['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']
  function GetLength: SizeUInt;
  function GetCapacity: SizeUInt;
  function GetData: PByte;
  procedure AppendByte(const AValue: Byte);
  procedure AppendBytes(const AData: PByte; const ACount: SizeUInt);
  procedure AppendSpan(const ASpan: TByteSpan);
  procedure AppendUInt16LE(const AValue: UInt16);
  procedure AppendUInt16BE(const AValue: UInt16);
  procedure AppendUInt32LE(const AValue: UInt32);
  procedure AppendUInt32BE(const AValue: UInt32);
  procedure AppendUInt64LE(const AValue: UInt64);
  procedure AppendUInt64BE(const AValue: UInt64);
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
```

### 1.3 IByteCursor 接口

```pascal
IByteCursor = interface['{4B8D2C57-9E31-4A6F-B7D5-08C3A1E62F94}']
  function Length: SizeUInt;
  function Position: SizeUInt;
  function Remaining: SizeUInt;
  procedure Seek(APos: SizeUInt);
  function TrySeek(APos: SizeUInt): Boolean;
  function ReadU16LE: UInt16; function ReadU32LE: UInt32; function ReadU64LE: UInt64;
  function ReadU16BE: UInt16; function ReadU32BE: UInt32; function ReadU64BE: UInt64;
  function PeekU16LE(AAt: SizeUInt): UInt16; function PeekU32LE(AAt: SizeUInt): UInt32; function PeekU64LE(AAt: SizeUInt): UInt64;
  function ReadBytes(ACount: SizeUInt): TBytes;
  function TryReadBytes(ACount: SizeUInt; out AOut: TBytes): Boolean;
  function ReadSpan(ACount: SizeUInt): PByte;
end;
```

### 1.4 TByteStreamBuf

```pascal
TByteStreamBuf = class
  constructor Create(const AAllocator: IAllocator; const AInitialCapacity: SizeUInt = 0);
  function Capacity: SizeUInt; function Length: SizeUInt; function Data: PByte;
  function Available: SizeUInt; function TailSpace: SizeUInt;
  procedure EnsureCapacity(const ANewCapacity: SizeUInt);
  function ReserveAppend(const AAdditional: SizeUInt): PByte;
  procedure CommitAppend(const ACount: SizeUInt);
  procedure Append(const AData: PByte; const ACount: SizeUInt);
  procedure AppendByte(const AValue: Byte);
  function Consume(const ACount: SizeUInt): SizeUInt;
  procedure Clear; procedure Compact;
end;
```

### 1.5 Span 操作

| 函数 | 说明 |
|------|------|
| `SpanEqual(A, B): Boolean` | 逐字节比较 |
| `SpanCompare(A, B): Integer` | 三路比较 |
| `SpanIndexOf(Haystack, Needle): SizeInt` | 查找字节 |
| `SpanIndexOfSpan(Haystack, Needle): SizeInt` | 查找子序列 (simd 加速) |
| `SpanContains(Haystack, Needle): Boolean` | 包含检查 |
| `SpanStartsWith/EndsWith` | 前缀/后缀 |
| `SpanFill(Span, Value)` | 填充 |
| `SpanReverse(Span)` | 反转 |
| `SpanConcat(A, B): TBytes` | 拼接 |
| `SpanConcatMany(Parts: array of TByteSpan): TBytes` | 多段拼接 |
| `SpanCopySlice(Span, Offset, Len): TBytes` | 切片拷贝 |
| `SpanClone(Span): TBytes` | 克隆 |
| `BytesEqual(A, B): Boolean` | 字节数组比较 |
| `BytesCompare(A, B): Integer` | 字节数组三路比较 |
| `BytesIndexOf(Data, Needle): SizeInt` | 字节数组查找 |
| `BytesConcat(A, B): TBytes` | 字节数组拼接 |
| `BytesConcatMany(Parts: array of TBytes): TBytes` | 字节数组多段拼接 |
| `BytesAppend(var Dest; Src)` / `BytesAppendByte` 等 | 追加辅助 |
| `BytesStartsWith/EndsWith` | 字节数组前缀/后缀 |
| `StripLeadingZero/View/Span` | 无符号前导零剥离 (零分配视图) |
| `CompareUnsigned/Span` | 无符号大端比较 |
| `IsZeroBytes/BytesIsZero/IsAllZero` | 全零检查 |
| `BytesToString/StringToBytes` | 字节↔字符串 |

### 1.6 字节序转换

| 函数 | 说明 |
|------|------|
| `Swap16/Swap32/Swap64` | 字节序翻转 |
| `ToEndian16/32/64 / FromEndian16/32/64` | 主机↔指定端 |
| `ReadUInt16/32/64LE/BE(PByte): UInt` | 裸指针读 |
| `WriteUInt16/32/64LE/BE(PByte, Value)` | 裸指针写 |
| `TryReadUInt8/16/32/64LE/BE(var Span; out Value): Boolean` | 推进式读 |
| `TryWriteUInt8/16/32/64LE/BE(var Span; Value): Boolean` | 推进式写 |

---

## 2. 不变量

- **[INV-1]** Span 操作中 nil + 非零长度触发 EArgumentNil
- **[INV-2]** IBytesBuilder 内部 buffer 按需增长（capacity ≥ length），Reserve/EnsureCapacity 幂等
- **[INV-3]** NATIVE_ENDIAN 在编译时确定
- **[INV-4]** IByteCursor 所有越界 Read/Peek 抛 EIndexOutOfRangeError，Try* 返回 False 不推进
- **[INV-5]** TByteStreamBuf Consume 不搬移，仅 Compact/增长时压实；TailSpace = Cap - (Off+Len)

---

## 3. 错误处理

| 场景 | 异常 |
|------|------|
| nil + 非零长度 | EArgumentNil (base) |
| Slice/Span 越界 | EOutOfRange (base) |
| Cursor 越界 | EIndexOutOfRangeError |
| Builder/Stream 容量溢出 | EOutOfMemory (allocator) |

---

## 4. 线程安全

- Span/Bytes ops：✅ 纯函数
- IBytesBuilder / IByteCursor / TByteStreamBuf：❌ 调用方同步

---

## 5. 内存管理

- Span 操作：非拥有视图，不分配内存（Concat/CopySlice/Clone 返回 TBytes 除外）
- IBytesBuilder：内部 buffer 经 TMemAllocator 动态增长，ToBytes 返回拷贝
- IByteCursor：不拥有缓冲区；TBytes 构造时持有引用，PByte 构造由调用方保证生命周期
- TByteStreamBuf：内部块经 IAllocator，Clear 保留容量，Grow 倍增

---

## 6. 测试覆盖

| 测试目录 | 说明 |
|----------|------|
| test_bytes | Span 操作 + 字节序 + Builder + Unsigned helpers |
| test_cursor | IByteCursor 边界/Seek/Read/Peek/Try* |
| test_stream | TByteStreamBuf Append/Reserve/Consume/Compact |
| **合计** | **3 个测试目录** |

**门禁**：`scripts/bytes-contract-check.sh` — C1 契约结构 / C2 源文件完备性(7) / C3 核心类型(IBytesBuilder/IByteCursor/TByteStreamBuf) / C4 门面+测试

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-01 | 1.0 | 初始版本 | Claude |
| 2026-08-30 | 1.1 | 冻结感修复：更新至 2026-08-30 并 bump 版本 | Claude |
| 2026-08-31 | 1.2 | 同步 3 门禁：补齐 IBytesBuilder/IByteCursor/TByteStreamBuf 契约、7 文件与 3 测试目录、simd 标注 | Claude |
