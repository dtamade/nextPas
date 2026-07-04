# nextpas.core.id 代码契约

> 模块路径: `core/src/nextpas.core.id.*.pas`
> 创建日期: 2026-07-04
> 维护者: AI

---

## 概述

唯一标识门面。提供 UUID v4/v7、ULID、Snowflake、NanoID、KSUID、XID。

---

## 关键类型

```pascal
type
  TUuid;                { UUID (128-bit) }
  TUuidV7Generator;     { UUID v7 单调生成器 }
  TSnowflakeId;         { Snowflake (64-bit) }
  TSnowflakeGenerator;  { Snowflake 生成器 }
  TKsuid;               { KSUID (160-bit) }
  TXid;                 { XID (96-bit) }
const
  UUID_LENGTH = 36;
  ULID_LENGTH = 26;
  NANOID_DEFAULT_LENGTH = 21;
  SNOWFLAKE_EPOCH_TWITTER = 1288834974657;
  SNOWFLAKE_EPOCH_DISCORD = 1420070400000;
```

---

## 线程安全

- 生成器不线程安全（需外部同步或 per-thread 实例）
- ID 值类型为 record，天然线程安全

---

## 依赖关系

- 依赖: base, platform.random, time
- 被依赖: 数据库主键、分布式 ID、日志关联

---

## 变更记录

| 日期 | 变更 | 原因 |
|------|------|------|
| 2026-07-04 | 初始版本 | 契约建立 |
