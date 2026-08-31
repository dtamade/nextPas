# nextpas.core.id 代码契约

**模块路径**：`core/src/nextpas.core.id*.pas`（10 个源文件）
**层级**：L1（依赖 L0: base, bytes）
**Owner**：Claude（AI 负责）
**最后更新**：2026-08-31
**版本**：1.2

---

## 1. 接口契约

### 1.1 子模块

| 文件 | 职责 |
|------|------|
| id.base | TKsuid, TXid, TSnowflakeGenerator, TUuidV7Generator, TUuid 记录类型 |
| id.ksuid | KSUID 生成（时间戳+随机） |
| id.xid | XID 生成 |
| id.snowflake | Snowflake ID 生成 |
| id.uuid | UUID v7 生成 |
| id.v7.monotonic | UUID v7 单调递增变体 |
| id.nanoid | NanoID 生成 |
| id.ulid | ULID 生成 |
| id.rng | 随机数工具 |
| id.pas | 门面 re-export |

### 1.2 核心类型

```pascal
TKsuid = record
  Timestamp: UInt64;
  Payload: array[0..15] of Byte;
end;

TXid = record
  Bytes: array[0..11] of Byte;
end;

TSnowflakeGenerator = record
  MachineId: UInt16;
  Sequence: UInt16;
end;

TUuid = record
  Bytes: array[0..15] of Byte;
end;
```

### 1.3 核心函数

```pascal
function KsuidGenerate: TKsuid;
function KsuidToString(const AId: TKsuid): string;
function KsuidParse(const AStr: string): TKsuid;

function XidGenerate: TXid;
function XidToString(const AId: TXid): string;

function SnowflakeNext(var AGen: TSnowflakeGenerator): Int64;
function SnowflakeTimestamp(AId: Int64): Int64;

function UuidV7Generate: TUuid;
function UuidToString(const AId: TUuid): string;
```

---

## 2. 不变量

- KSUID 单调递增（同毫秒内）
- XID 全局唯一（机器+进程+时间+随机）
- Snowflake 63 位：41 位时间戳 + 10 位机器 + 12 位序列
- UUID v7 单调递增（同毫秒内）

---

## 3. 错误处理

- 解析失败抛 `EIdError`
- 生成不抛异常

---

## 4. 线程安全

- KSUID/XID/UUID 生成使用原子操作，线程安全
- Snowflake 生成器需外部同步

---

## 5. 内存管理

- 所有 ID 类型是值类型，无堆分配

---

## 6. 测试覆盖

- `test_id`: KSUID/XID/Snowflake/UUID/ULID/NanoID 生成+解析+唯一性
