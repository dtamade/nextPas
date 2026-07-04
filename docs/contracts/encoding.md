# nextpas.core.encoding 代码契约

> 模块路径: `core/src/nextpas.core.encoding.*.pas`
> 创建日期: 2026-07-04
> 维护者: AI

---

## 概述

编解码门面。提供 Base64、Hex、URL 编码和 Varint 变长整数编码。

---

## 关键接口

```pascal
function Base64Encode(AData: TBytes): string;
function Base64Decode(AEncoded: string): TBytes;
function Base64UrlEncode(AData: TBytes): string;
function Base64UrlDecode(AEncoded: string): TBytes;
function HexEncode(AData: TBytes; ACase: THexCase = hcLower): string;
function HexDecode(AHex: string): TBytes;
function VarintEncode(AValue: UInt64): TBytes;
function VarintDecode(AData: TBytes; out ABytesRead: Integer): UInt64;
function UrlEncode(AValue: string): string;
function UrlDecode(AEncoded: string): string;
```

---

## 错误语义

| 场景 | 行为 |
|------|------|
| Base64Decode 非法字符 | raise EConvertError |
| HexDecode 非法字符 | raise EConvertError |
| VarintDecode 数据不足 | ABytesRead = 0 |

---

## 线程安全

- 所有函数为纯函数，可安全并发调用

---

## 依赖关系

- 依赖: base
- 被依赖: crypto, http, json

---

## 变更记录

| 日期 | 变更 | 原因 |
|------|------|------|
| 2026-07-04 | 初始版本 | 契约建立 |
