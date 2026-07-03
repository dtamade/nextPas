# nextpas.core.bytes 代码契约

> 模块路径: `core/src/nextpas.core.bytes.*.pas`
> 创建日期: 2026-07-04
> 维护者: AI

---

## 概述

字节容器门面。提供 TByteSpan 操作、字节序转换和 IBytesBuilder 流式构建。

---

## 关键接口

```pascal
function CreateBytesBuilder(AInitialCapacity = 4096): IBytesBuilder;
function SpanEqual(A, B: TByteSpan): Boolean;
function SpanCompare(A, B: TByteSpan): Integer;
function SpanIndexOf(AHaystack: TByteSpan; ANeedle: Byte): SizeInt;
function SpanContains(AHaystack: TByteSpan; ANeedle: Byte): Boolean;
function SpanStartsWith(AData, APrefix: TByteSpan): Boolean;
function SpanEndsWith(AData, ASuffix: TByteSpan): Boolean;
procedure SpanFill(ASpan: TByteSpan; AValue: Byte);
procedure SpanReverse(ASpan: TByteSpan);
function SpanConcat(A, B: TByteSpan): TBytes;
```

---

## 错误语义

| 场景 | 行为 |
|------|------|
| Span 操作 nil Data + Len > 0 | raise EArgumentNil |

---

## 线程安全

- IBytesBuilder 不线程安全
- Span 操作为纯函数，可安全并发调用

---

## 依赖关系

- 依赖: base
- 被依赖: io, crypto, net

---

## 变更记录

| 日期 | 变更 | 原因 |
|------|------|------|
| 2026-07-04 | 初始版本 | 契约建立 |
