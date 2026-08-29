# nextpas.core.bytes 代码契约

**模块路径**：`core/src/nextpas.core.bytes*.pas`（7 个源文件）
**层级**：L1（依赖 L0: base）
**Owner**：Claude（AI 负责）
**最后更新**：2026-07-01
**版本**：1.0

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
| test_bytes | Span 操作 + 字节序 + Builder |
| **合计** | **1 个测试目录** |

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-01 | 1.0 | 初始版本 | Claude |
