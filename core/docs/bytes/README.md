# nextpas.core.bytes

`nextpas.core.bytes` 是 `nextpas.core` 的 L1 字节容器模块。提供 `TBytes`/`TByteSpan` 之上的
只读视图操作、可变构建器、字节序编解码、边界受查游标与可增长流缓冲，为 `text`/`encoding`/`crypto`/`net`/`compress` 等高层模块提供字节原语。

- 层级：L1，只依赖 L0（`base`、`platform.base`、`mem`、`simd` 的标量/向量原语）。
- 门面：`nextpas.core.bytes`（纯 re-export + inline forward，不承载逻辑）。
- 依赖规则：门面聚合子模块；`bytes`/`text`/`encoding` 按 `design-conventions.md` §3 特例以 `interface`/`implementation` 分区引用（`encoding` interface → `bytes`/`text`，`bytes`/`text` implementation → `encoding`）。
- 文档真源：稳定契约见 [CONTRACT.md](CONTRACT.md)；设计规范见 `core/docs/design-conventions.md` §12.5。

## 源文件布局

```
core/src/nextpas.core.bytes.pas          ← 门面
core/src/nextpas.core.bytes.base.pas     ← TEndianness / NATIVE_ENDIAN / Builder 常量
core/src/nextpas.core.bytes.ops.pas      ← TByteSpan / TBytes 视图操作
core/src/nextpas.core.bytes.binary.pas   ← Swap / ToEndian / Read*LE/BE / TryRead/TryWrite
core/src/nextpas.core.bytes.builder.pas  ← IBytesBuilder 可变缓冲
core/src/nextpas.core.bytes.cursor.pas   ← IByteCursor 只读游标
core/src/nextpas.core.bytes.stream.pas   ← TByteStreamBuf 可增长流缓冲
core/src/nextpas.core.bytes.framing.pas  ← TWireBuffer 4B 帧缓冲（SFTP/QUIC/Redis 共用）
```

## API 入口

日常应优先 `uses nextpas.core.bytes`。需要接口/实现细节或按需裁剪依赖时再直引子模块。

| 子模块 | 职责 | 关键 API |
|--------|------|----------|
| `nextpas.core.bytes.base` | 字节序枚举与 Builder 常量 | `TEndianness`/`TByteOrder`/`TEndian`、`endLittle`/`endBig`/`NATIVE_ENDIAN`、`BYTES_BUILDER_DEFAULT_CAPACITY` |
| `nextpas.core.bytes.ops` | Span/TBytes 纯函数视图操作 | `SpanEqual`/`SpanCompare`/`SpanIndexOf`/`SpanIndexOfSpan`/`SpanContains`/`SpanStartsWith`/`SpanEndsWith`/`SpanFill`/`SpanReverse`/`SpanConcat`/`SpanCopySlice`/`SpanClone`/`SpanConcatMany`、`BytesEqual`/`BytesCompare`/`BytesIndexOf`/`BytesConcat`/`BytesConcatMany`/`BytesAppend`/`BytesAppendByte`/`BytesAppendUInt16BE`/`BytesAppendUInt24BE`/`BytesAppendUInt32BE`/`BytesReserve`/`BytesEnsureCapacity`/`BytesStartsWith`/`BytesEndsWith`/`StripLeadingZero*`/`CompareUnsigned*`/`UnsignedEqual*`/`IsZeroBytes`/`BytesIsZero`/`IsAllZero`/`BytesToString`/`StringToBytes` |
| `nextpas.core.bytes.binary` | 字节序翻转与指针级编解码 | `SwapUInt16/32/64`、`ToEndian16/32/64`/`FromEndian16/32/64`、`ReadUInt16/32/64LE/BE`/`WriteUInt16/32/64LE/BE`、`TryReadUInt8/16/32/64LE/BE`/`TryWriteUInt8/16/32/64LE/BE`（推进式 `TByteSpan` 游标） |
| `nextpas.core.bytes.builder` | 可变字节缓冲（接口，自动引用计数） | `IBytesBuilder`（`AppendByte`/`AppendBytes`/`AppendSpan`/`AppendUInt16/32/64LE/BE`/`AppendFill`/`WrittenSpan`/`ToBytes`/`Clear`/`Reserve`/`Truncate`/`Length`/`Capacity`/`Data`）、`CreateBytesBuilder`/`CreateBytesBuilderWith` |
| `nextpas.core.bytes.cursor` | 边界受查只读游标（ZIP/PNG/WASM 等容器解析原语） | `IByteCursor`（`Length`/`Position`/`Remaining`/`Seek`/`TrySeek`/`ReadU16/32/64LE/BE`/`PeekU16/32/64LE`/`ReadBytes`/`TryReadBytes`/`ReadSpan`）、`NewByteCursor`/`NewByteCursorAt` |
| `nextpas.core.bytes.stream` | 追加/消费/压实一体流缓冲（TLS/代理缓冲复用） | `TByteStreamBuf`（`EnsureCapacity`/`ReserveAppend`+`CommitAppend`/`Append`/`AppendByte`/`Consume`/`Clear`/`Compact`/`Data`/`Available`/`TailSpace`） |
| `nextpas.core.bytes.framing` | 4B 长度前缀帧缓冲（SFTP/QUIC/Redis 共用） | `TWireBuffer`（`Clear`/`Append`/`HasHeader`/`HasCompleteFrame`/`TryPeekFrameLength`/`TryTakeFrame`/`TakeFrame`/`Compact`/`BufferedLen`/`Capacity`/`BufferedData`）、`WireEncodeFrame`/`WireAppendEncoded`（常量 `WIRE_BUFFER_COMPACT_OFFSET_ABSOLUTE=16KB`/`WIRE_BUFFER_COMPACT_OFFSET_HALF=4KB`/`WIRE_BUFFER_DEFAULT_MAX=256KiB`，`BytesEnsureCapacity` 几何 + `FOff` 零拷贝 + quarter-cap 懒压实，取帧单次 Move+单次压实 `inline`） |

门面 `nextpas.core.bytes` 重导出以上常用符号：`TEndianness`/`IBytesBuilder`/`IByteCursor`/`TByteStreamBuf`/`TWireBuffer`、`CreateBytesBuilder`、`NewByteCursor`/`NewByteCursorAt`、全部 `Span*`/`Bytes*`（含 `BytesAppend*`/`BytesReserve`/`BytesEnsureCapacity`/`BytesConcatMany`/`SpanConcatMany`/`CompareUnsignedSpan`/`UnsignedEqualSpan`/`BytesToString` 等）、`SwapUInt*`/`ToEndian*`/`Read*`/`Write*`/`TryRead*`/`TryWrite*` 与 `WireEncodeFrame`/`WireAppendEncoded`/`WIRE_BUFFER_*`（`bytes.ops`/`bytes.binary`/`bytes.framing` 单源 inline 转发，零拷贝）。

## 示例

### Span 视图操作

```pascal
uses
  nextpas.core.base,
  nextpas.core.bytes;

var
  A, B: TBytes;
  S: TByteSpan;
begin
  A := TBytes.Create(1, 2, 3);
  B := TBytes.Create(1, 2, 3);
  Assert(BytesEqual(A, B));
  Assert(SpanStartsWith(TByteSpan.FromBytes(A), TByteSpan.FromBytes(TBytes.Create(1, 2))));

  S := TByteSpan.Create(@A[0], Length(A));
  SpanFill(S, $FF);
  SpanReverse(S);
  S := TByteSpan.FromBytes(A);
  Assert(SpanIndexOf(S, $FF) >= 0);
end;
```

### IBytesBuilder 可变拼接

```pascal
uses
  nextpas.core.bytes;

var
  Builder: IBytesBuilder;
  Data: TBytes;
begin
  Builder := CreateBytesBuilder;
  Builder.AppendByte($01);
  Builder.AppendUInt32LE($02030405);
  Builder.AppendSpan(TByteSpan.FromBytes(TBytes.Create($AA, $BB)));
  Builder.AppendFill($00, 4);
  Data := Builder.ToBytes;
  Builder.Clear;
  Builder.Reserve(1024);
end;
```

### 字节序与推进式编解码

```pascal
uses
  nextpas.core.bytes;

var
  Buf: array[0..7] of Byte;
  Span: TByteSpan;
  V32: UInt32;
  V64: UInt64;
begin
  WriteUInt32LE(@Buf[0], $12345678);
  V32 := ReadUInt32LE(@Buf[0]);

  V64 := $0102030405060708;
  V64 := ToEndian64(V64, endBig);
  V64 := FromEndian64(V64, endBig);

  Span := TByteSpan.Create(@Buf[0], Length(Buf));
  if TryReadUInt32LE(Span, V32) then
    TryWriteUInt64BE(Span, V64);
end;
```

### IByteCursor 解析容器

```pascal
uses
  nextpas.core.bytes;

var
  Cursor: IByteCursor;
  Data: TBytes;
  Magic: UInt32;
  Payload: TBytes;
begin
  Data := TBytes.Create($50, $4B, $03, $04, $00, $00);
  Cursor := NewByteCursor(Data);
  Magic := Cursor.ReadU32LE;
  Payload := Cursor.ReadBytes(2);
  Cursor.Seek(0);
  if not Cursor.TrySeek(100) then
    Payload := Cursor.ReadBytes(Cursor.Remaining);
end;
```

### TByteStreamBuf 流缓冲

```pascal
uses
  nextpas.core.mem,
  nextpas.core.bytes.stream;

var
  Buf: TByteStreamBuf;
  P: PByte;
begin
  Buf := TByteStreamBuf.Create(DefaultAllocator, 4096);
  try
    Buf.Append(nil, 0);
    P := Buf.ReserveAppend(4);
    P[0] := $01; P[1] := $02; P[2] := $03; P[3] := $04;
    Buf.CommitAppend(4);
    Buf.Consume(2);
    Buf.Compact;
    Buf.Clear;
  finally
    Buf.Free;
  end;
end;
```

## 测试

```bash
make -C core/tests/nextpas.core.bytes clean test
```

覆盖见 [CONTRACT.md](CONTRACT.md) §6：Span 操作、字节序、Builder、Cursor、StreamBuf、WireBuffer。

### TWireBuffer 帧缓冲

```pascal
uses
  nextpas.core.bytes;

var
  Wire: TWireBuffer;
  Frame: TBytes;
  Encoded: TBytes;
begin
  Wire.Clear;
  Wire.Append(WireEncodeFrame(TBytes.Create(1,2,3)));
  Wire.Append(TBytes.Create(0,0,0,2, $AA,$BB)); // 分片/粘包
  if Wire.HasCompleteFrame then
    Frame := Wire.TakeFrame; // 零拷贝 Take + 懒压实
  Encoded := WireEncodeFrame(Frame);
end;
```
