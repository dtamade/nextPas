# nextpas.core.bytes 代码契约

**模块路径**：`core/src/nextpas.core.bytes*.pas`（7 个源文件）
**层级**：L1（依赖 L0: base）
**Owner**：Claude（AI 负责）
**最后更新**：2026-08-31
**版本**：1.3

---

## 1. 接口契约

### 1.1 子模块

| 文件 | 职责 |
|------|------|
| bytes.base | TEndianness 枚举 (endLittle/endBig), NATIVE_ENDIAN 常量 |
| bytes.ops | TByteSpan/TBytes 操作 (Equal/Compare/IndexOf/Fill/Reverse/Concat/ConcatMany/BytesAppend* /Reserve/StripLeadingZero/CompareUnsigned/IsZero/BytesToString 等，crypto/tls 单源) |
| bytes.binary | 字节序转换 (Swap16/Swap32/Swap64, ToEndian/FromEndian, Read/Write LE/BE, TryRead/TryWrite) |
| bytes.builder | IBytesBuilder 可变字节缓冲区 |
| bytes.cursor | IByteCursor 边界受查只读游标 |
| bytes.stream | TByteStreamBuf 可增长缓冲流 |
| bytes.pas | 门面 |

### 1.2 IBytesBuilder 接口

```pascal
IBytesBuilder = interface
  function Append(const AData; ASize: SizeUInt): IBytesBuilder;
  function AppendByte(AByte: Byte): IBytesBuilder;
  function AppendBytes(const ABytes: TBytes): IBytesBuilder;
  function AppendSpan(const ASpan: TByteSpan): IBytesBuilder;
  procedure Clear;
  function ToBytes: TBytes;
  function ToSpan: TByteSpan;
  function Length: SizeUInt;
  function Capacity: SizeUInt;
end;
```

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
| `SpanConcatMany([...]): TBytes` | 批拼接（单次分配 + Move 零拷贝） |
| `SpanCopySlice(Span, Offset, Len): TBytes` | 切片拷贝 |
| `SpanClone(Span): TBytes` | 克隆 |
| `BytesEqual(A, B): Boolean` | 字节数组比较 |
| `BytesCompare(A, B): Integer` | 字节数组三路比较 |
| `BytesIndexOf(Data, Needle): SizeInt` | 字节数组查找 |
| `BytesConcat(A, B): TBytes` | 字节数组拼接 |
| `BytesConcatMany([...]): TBytes` | 批拼接（单次分配 + Move 零拷贝） |
| `BytesAppend(var Dest, Src)` / `BytesAppend(var Dest, P, Len)` | 追加（cap-map 分摊 O(1)，inline） |
| `BytesAppendByte(var Dest, V)` | 追加单字节（同上） |
| `BytesAppendUInt16/24/32BE(var Dest, V)` | 追加 BE 编码（同上，零拷贝写） |
| `BytesReserve(var Dest, Add)` / `BytesEnsureCapacity(var Dest, Req)` | 预留/确容（按 2 倍增长，inline） |
| `BytesStartsWith(Data, Prefix): Boolean` | 字节数组前缀检查 |
| `BytesEndsWith(Data, Suffix): Boolean` | 字节数组后缀检查 |
| `StripLeadingZero*` / `CompareUnsigned*` / `UnsignedEqual*` | 无符号大端比较（单源经 StripLeadingZeroView/Span） |
| `IsZeroBytes` / `BytesIsZero` / `IsAllZero` | 全零判定（单源） |
| `BytesToString` / `BytesToUTF8` / `StringToBytes` | 字节↔字符串（Move 零拷贝） |

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
| test_bytes | Span 操作 + 字节序 + Builder |
| test_cursor | IByteCursor 边界受查只读游标 |
| test_stream | TByteStreamBuf 可增长缓冲流 |
| **合计** | **3 个测试目录** |

---

## 7. 门面单源

- `nextpas.core.bytes` 为纯 re-export 门面，所有 `Span*`/`Bytes*`/`BytesAppend*` 均为 `inline` 转发至 `nextpas.core.bytes.ops` 单源，`Swap*`/`ToEndian*`/`Read*`/`Write*`/`TryRead*`/`TryWrite*` 转发至 `nextpas.core.bytes.binary` 单源，禁止重复实现；`BytesAppend*`/`BytesReserve` 共享 `bytes.ops` cap-map 分摊 O(1)，`SpanConcatMany`/`BytesConcatMany` 单次分配 + `Move` 零拷贝，避免 O(n²) `BytesAppend` 循环。

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-01 | 1.0 | 初始版本 | Claude |
| 2026-08-30 | 1.1 | 冻结感修复：更新最后更新至 2026-08-30 并 bump 版本 | Claude |
| 2026-08-31 | 1.2 | 时效刷新：批量校正至 2026-08-31，统一 AL1 口径 | core-docs |
| 2026-08-31 | 1.3 | 补齐门面高频单源：BytesAppend*/Reserve/ConcatMany/CompareUnsignedSpan 等经 bytes.ops inline 转发 | bytes-facade |
