# nextpas.core.bytes 代码契约

**模块路径**：`core/src/nextpas.core.bytes*.pas`（7 个源文件）
**层级**：L1（依赖 L0: base）
**Owner**：Claude（AI 负责）
**最后更新**：2026-08-31
**版本**：1.1

---

## 1. 接口契约

### 1.1 子模块

| 文件 | 职责 |
|------|------|
| bytes.base | TEndianness 枚举 (endLittle/endBig), NATIVE_ENDIAN 常量 |
| bytes.ops | TByteSpan 操作 (Equal/Compare/IndexOf/Fill/Reverse/Concat) |
| bytes.binary | 字节序转换 (Swap16/Swap32/Swap64, HostToLE/LEToHost 等) |
| bytes.builder | IBytesBuilder 可变字节缓冲区 |
| bytes.cursor | IByteCursor 边界受查只读游标 |
| bytes.stream | TByteStreamBuf 可增长缓冲流 |
| bytes.pas | 门面 |

### 1.2 IBytesBuilder 接口（与 `bytes.builder.pas` 实现一致）

```pascal
IBytesBuilder = interface
  ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']
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

function CreateBytesBuilder(const AInitialCapacity: SizeUInt = BYTES_BUILDER_DEFAULT_CAPACITY): IBytesBuilder;
function CreateBytesBuilderWith(const AAllocator: TMemAllocator; const AInitialCapacity: SizeUInt = BYTES_BUILDER_DEFAULT_CAPACITY): IBytesBuilder;
```

门面 `MakeBytesBuilder` / `CreateBytesBuilder` 为 thin inline 转发；`IByteCursor` 与 `TByteStreamBuf` 见 1.5/1.6（cursor/stream 独立单元，合计 7 文件）。

### 1.3 Span 操作

| 函数 | 说明 |
|------|------|
| `SpanEqual(A, B): Boolean` | 逐字节比较 |
| `SpanCompare(A, B): Integer` | 三路比较 |
| `SpanIndexOf(Haystack, Needle): SizeInt` | 查找字节 |
| `SpanIndexOfSpan(Haystack, Needle): SizeInt` | 查找子序列 |
| `SpanContains(Haystack, Needle): Boolean` | 包含检查 |
| `SpanStartsWith/EndsWith` | 前缀/后缀 |
| `SpanFill(Span, Value)` | 填充 |
| `SpanReverse(Span)` | 反转 |
| `SpanConcat(A, B): TBytes` | 拼接 |
| `SpanCopySlice(Span, Offset, Len): TBytes` | 切片拷贝 |
| `SpanClone(Span): TBytes` | 克隆 |
| `BytesEqual(A, B): Boolean` | 字节数组比较 |
| `BytesCompare(A, B): Integer` | 字节数组三路比较 |
| `BytesIndexOf(Data, Needle): SizeInt` | 字节数组查找 |
| `BytesConcat(A, B): TBytes` | 字节数组拼接 |
| `BytesStartsWith(Data, Prefix): Boolean` | 字节数组前缀检查 |
| `BytesEndsWith(Data, Suffix): Boolean` | 字节数组后缀检查 |

### 1.4 字节序转换

| 函数 | 说明 |
|------|------|
| `Swap16/Swap32/Swap64` | 字节序翻转 |
| `HostToLE16/LEToHost16` 等 | 主机↔小端 |
| `HostToBE16/BEToHost16` 等 | 主机↔大端 |
| `ReadLE16/WriteLE16` 等 | 从缓冲区读写 |

---

## 2. 不变量

- **[INV-1]** Span 操作中 nil + 非零长度触发 EArgumentNil
- **[INV-2]** IBytesBuilder 内部 buffer 按需增长（capacity ≥ length）
- **[INV-3]** NATIVE_ENDIAN 在编译时确定

---

## 3. 错误处理

| 场景 | 异常 |
|------|------|
| nil + 非零长度 | EArgumentNil (base) |
| Slice 越界 | EOutOfRange (base) |

---

## 4. 线程安全

- Span 操作：✅ 纯函数
- IBytesBuilder：❌ 调用方同步

---

## 5. 内存管理

- Span 操作：非拥有视图，不分配内存（Concat/CopySlice 返回 TBytes 除外）
- IBytesBuilder：内部 buffer 动态增长，调用方通过 ToBytes 获取拷贝

---

## 6. 测试覆盖

| 测试目录 | 说明 |
|----------|------|
| test_bytes | Span 操作 + 字节序 + Builder（`bytes.ops`/`binary`/`builder` 基础） |
| test_cursor | `IByteCursor` 边界受查只读游标（Seek/TrySeek/ReadU*LE/BE/Peek/ReadBytes/TryReadBytes/ReadSpan） |
| test_stream | `TByteStreamBuf` 可增长缓冲流（Append/Consume/Compact/ReserveAppend/EnsureCapacity/TailSpace） |
| **合计** | **3 个测试目录** |

> 7 文件门面：`bytes.base` / `ops` / `binary` / `builder` / `cursor` / `stream` / `bytes.pas`；`cursor` 与 `stream` 为独立实现单元，契约与源码一致。

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-01 | 1.0 | 初始版本 | Claude |
| 2026-08-30 | 1.1 | 冻结感修复：更新最后更新至 2026-08-30 并 bump 版本 | Claude |
| 2026-08-31 | 1.1 | 时效修复：补 cursor/stream 7 文件、IBytesBuilder 与实现一致、测试 3 目录（test_bytes/test_cursor/test_stream） | Claude |
