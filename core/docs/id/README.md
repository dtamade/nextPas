# nextpas.core.id — 唯一标识符生成

## 概述

提供 8 种唯一标识符生成算法，覆盖从数据库主键到分布式追踪的所有常见场景。

**层级:** L1 (基础设施)

**依赖:** `nextpas.core.platform.random`, `nextpas.core.platform.time`

## 算法选择指南

| 算法 | 大小 | 编码长度 | 时间排序 | 适用场景 |
|------|------|---------|---------|---------|
| UUID v4 | 128-bit | 36 char | ❌ | 通用唯一标识、API key |
| UUID v7 | 128-bit | 36 char | ✅ | 数据库主键（B-tree 友好） |
| UUID v7 Mono | 128-bit | 36 char | ✅ 严格 | 高并发数据库主键 |
| Snowflake | 64-bit | 数字 | ✅ | 分布式系统、消息队列 |
| KSUID | 160-bit | 27 char | ✅ | 事件 ID、日志追踪 |
| XID | 96-bit | 20 char | ✅ | 紧凑 ID、URL 短链 |
| ULID | 128-bit | 26 char | ✅ | Crockford Base32 场景 |
| NanoID | 可变 | 21 char | ❌ | URL 安全、可定制 |

## 快速使用

```pascal
uses nextpas.core.id;

// UUID v4 — 随机
WriteLn(UuidV4);  // "550e8400-e29b-41d4-a716-446655440000"

// UUID v7 — 时间排序
WriteLn(UuidV7);  // "018f6b1c-4a2e-7xxx-xxxx-xxxxxxxxxxxx"

// UUID v7 Monotonic — 同毫秒严格单调（数据库主键推荐）
WriteLn(UuidV7Monotonic);

// Snowflake — 64-bit 分布式 ID
var Gen: TSnowflakeGenerator;
Gen.Init(1);  // worker ID = 1
WriteLn(Gen.Next);  // 7654321098765432

// KSUID — 160-bit 时间排序，27 字符
WriteLn(KsuidNew);  // "2ES9xtepqYKlhydDAVDdCo7YIWQ"

// XID — 96-bit 极紧凑，20 字符
WriteLn(XidNew);  // "d8dhmif3qmogn6l383j0"

// ULID — 128-bit Crockford Base32
WriteLn(Ulid);  // "01ARZ3NDEKTSV4RRFFQ69G5FAV"

// NanoID — URL 安全，可定制
WriteLn(NanoId);  // "V1StGXR8_Z5jdHi6B-myT"
WriteLn(NanoIdCustom('abc', 10));  // "bcaabcbacb"
```

## TUuid Record API

```pascal
uses nextpas.core.id.uuid;

var U: TUuid;

// 生成
U := TUuid.NewV4;
U := TUuid.NewV7;
U := TUuid.NewV7At(1700000000000);  // 指定时间戳
U := TUuid.Nil_;

// 解析（大小写不敏感）
U := TUuid.Parse('550e8400-e29b-41d4-a716-446655440000');
if TUuid.TryParse(SomeStr, U) then ...;
if UuidIsValid(SomeStr) then ...;

// 格式化
WriteLn(U.ToString);        // 小写标准格式
WriteLn(U.ToStringNoDash);  // 32 字符无横线

// 属性
U.Version;      // 4 或 7
U.Variant;      // 2 (RFC 4122/9562)
U.IsNil;        // 是否全零
U.TimestampMs;  // v7 的毫秒时间戳（v4 返回 0）
U.Hash;         // UInt32 哈希值

// 运算符
if A = B then ...;
if A < B then ...;
```

## UUID v7 Monotonic

同毫秒内严格单调递增，适合高并发数据库主键：

```pascal
uses nextpas.core.id.v7.monotonic;

// 全局生成器（单线程）
var Id: string := UuidV7Monotonic;

// 自定义生成器
var Gen: TUuidV7Generator;
Gen.Init;
var A := Gen.Next;  // 保证 A < B < C ...
var B := Gen.Next;
Assert(A < B);
```

## Snowflake

64-bit 分布式 ID，Twitter/Discord 标准：

```pascal
uses nextpas.core.id.snowflake;

var Gen: TSnowflakeGenerator;
Gen.Init(42, SNOWFLAKE_EPOCH_TWITTER);  // worker=42, Twitter epoch

var Id: TSnowflakeId := Gen.Next;

// 解构
var Ts: Int64; Worker, Seq: UInt16;
TSnowflakeGenerator.Extract(Id, SNOWFLAKE_EPOCH_TWITTER, Ts, Worker, Seq);
// Ts = Unix 毫秒时间戳, Worker = 42, Seq = 序列号
```

## KSUID

160-bit K-Sortable UID，Segment 标准：

```pascal
uses nextpas.core.id.ksuid;

var K: TKsuid := TKsuid.New;
WriteLn(K.ToString);       // 27 字符 Base62
WriteLn(K.TimestampUnix);  // Unix 秒时间戳

// 解析
var K2: TKsuid := TKsuid.Parse('2ES9xtepqYKlhydDAVDdCo7YIWQ');

// 排序
Assert(TKsuid.NewAt(100) < TKsuid.NewAt(200));
```

## XID

96-bit 极紧凑 ID，MongoDB ObjectId 改进版：

```pascal
uses nextpas.core.id.xid;

var X: TXid := TXid.New;
WriteLn(X.ToString);    // 20 字符 Base32-hex
WriteLn(X.Timestamp);   // Unix 秒时间戳

// 自动递增，无需配置
var A := TXid.New;
var B := TXid.New;
Assert(A < B);  // 保证顺序
```

## 性能

| 操作 | nextpas | Go | 倍率 |
|------|---------|-----|------|
| UUID v4 | 62 ns | 150 ns | 2.4x faster |
| UUID v7 | 76 ns | 160 ns | 2.1x faster |
| Snowflake | ~20 ns | ~50 ns | ~2.5x faster |
| KSUID | ~80 ns | ~200 ns | ~2.5x faster |
| XID | ~30 ns | ~60 ns | ~2x faster |

## 安全性

所有随机数通过 `platform_random_bytes` 生成（4KB 缓冲）：
- Linux: `getrandom(2)` 系统调用
- macOS/FreeBSD: `arc4random_buf`
- Windows: `RtlGenRandom`

不使用 FPC 的 `Random()` 函数。

## RFC 合规

- UUID v4: RFC 9562 §5.4
- UUID v7: RFC 9562 §5.7
- ULID: ulid/spec
- KSUID: segment/ksuid
- XID: rs/xid
- Snowflake: Twitter Snowflake spec
