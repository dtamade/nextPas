# nextpas.core.id — 唯一标识符生成

## 概述

提供多种唯一标识符生成算法，覆盖从数据库主键到分布式追踪的常见场景。

**层级:** L1 (基础设施)

**依赖:** `nextpas.core.platform.random`, `nextpas.core.platform.time`

## 模块结构

```
nextpas.core.id.pas          ← 门面（re-export 所有 API）
nextpas.core.id.base.pas     ← 基础类型定义
nextpas.core.id.uuid.pas     ← UUID v4/v7 实现 + TUuid record
nextpas.core.id.ulid.pas     ← ULID 实现
nextpas.core.id.nanoid.pas   ← NanoID 实现
```

## 快速使用

```pascal
uses nextpas.core.id;

// UUID v4 — 随机，适合通用唯一标识
var LId: string := UuidV4;
// "550e8400-e29b-41d4-a716-446655440000"

// UUID v7 — 时间排序，适合数据库主键（B-tree 友好）
var LId7: string := UuidV7;
// "018f6b1c-4a2e-7xxx-xxxx-xxxxxxxxxxxx"

// ULID — 时间排序 + Crockford Base32，26 字符
var LUlid: string := Ulid;
// "01ARZ3NDEKTSV4RRFFQ69G5FAV"

// NanoID — URL 安全，可自定义长度和字母表
var LNano: string := NanoId;
// "V1StGXR8_Z5jdHi6B-myT"
```

## TUuid Record API

```pascal
uses nextpas.core.id.uuid;

var U: TUuid;

// 生成
U := TUuid.NewV4;           // 随机 UUID
U := TUuid.NewV7;           // 时间排序 UUID
U := TUuid.Nil_;            // 全零 UUID

// 解析
U := TUuid.Parse('550e8400-e29b-41d4-a716-446655440000');
if TUuid.TryParse(SomeStr, U) then ...;

// 格式化
WriteLn(U.ToString);        // 小写标准格式

// 属性
U.Version;                  // 4 或 7
U.Variant;                  // 2 (RFC 4122/9562)
U.IsNil;                    // 是否全零
U.TimestampMs;              // v7 的毫秒时间戳（v4 返回 0）

// 比较
U.Equals(Other);            // 相等判断
U.CompareTo(Other);         // 排序（-1/0/1）
```

## UUID 版本选择指南

| 版本 | 适用场景 | 特点 |
|------|---------|------|
| v4 | 通用唯一标识、API key、token | 完全随机，无时间信息 |
| v7 | 数据库主键、事件 ID、日志追踪 | 时间排序，B-tree 插入友好 |

## RFC 合规

- UUID v4: RFC 9562 §5.4 — 122 bits random + version/variant
- UUID v7: RFC 9562 §5.7 — 48-bit unix_ts_ms + 12-bit rand_a + 62-bit rand_b

## 安全性

所有随机数通过 `platform_random_bytes` 生成：
- Linux: `getrandom(2)` 系统调用
- macOS/FreeBSD: `arc4random_buf`
- Windows: `RtlGenRandom`

不使用 FPC 的 `Random()` 函数（非密码学安全）。
