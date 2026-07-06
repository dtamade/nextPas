# UUID Module Rewrite — nextpas.core.id.uuid

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 重写 `nextpas.core.id.uuid` 为生产级 UUID v4/v7 实现，遵循 RFC 9562，使用密码学安全随机源。

**Architecture:** 引入 `TUuid` record 作为 128-bit 值类型（16 字节数组），提供 v4（随机）和 v7（时间排序+随机）生成、解析、格式化、比较、版本提取。随机源使用 `platform_random_bytes`（Linux getrandom / macOS arc4random / Windows RtlGenRandom）。时间源使用 `platform_realtime_ns`。

**Tech Stack:** FPC ObjFPC mode, nextpas.core.platform.random, nextpas.core.platform.time, nextpas.core.testing

**层级:** L1 (id 模块)

**参考:**
- RFC 9562 (UUIDv4 §5.4, UUIDv7 §5.7)
- 现有 `src/nextpas.core.id.base.pas` — 类型定义
- 现有 `src/nextpas.core.id.uuid.pas` — 当前 44 行实现（将完全重写）
- 现有 `tests/nextpas.core.id/test_id/test_id.lpr` — 已有 5 个 UUID 测试
- `src/nextpas.core.platform.random.pas` — `platform_random_bytes`
- `src/nextpas.core.platform.time.pas` — `platform_realtime_ns`

---

## API 设计

```pascal
{ nextpas.core.id.base.pas — 新增类型 }
type
  TUuid = record
  private
    FBytes: array[0..15] of Byte;
  public
    class function NewV4: TUuid; static;
    class function NewV7: TUuid; static;
    class function Parse(const AStr: string): TUuid; static;
    class function TryParse(const AStr: string; out AUuid: TUuid): Boolean; static;
    class function Nil_: TUuid; static;

    function ToString: string;
    function ToBytes: TBytes;
    function Version: Byte;
    function Variant: Byte;
    function IsNil: Boolean;
    function Equals(const AOther: TUuid): Boolean;
    function CompareTo(const AOther: TUuid): Int32;
    function TimestampMs: UInt64;  // v7 only, 0 for others
  end;

{ nextpas.core.id.uuid.pas — 函数式 API (向后兼容) }
function UuidV4: string;
function UuidV7: string;
function UuidParse(const AStr: string): TUuid;
function UuidIsValid(const AStr: string): Boolean;
```

---

## Task 1: 重写 id.base.pas — 添加 TUuid record 声明

**Files:**
- Modify: `src/nextpas.core.id.base.pas`

**Step 1:** 在 `id.base.pas` 中添加 TUuid record 的 interface 声明（只声明，不实现）。保留现有 TUuidString/TUlidString/TNanoIdString 类型。

**Step 2:** 编译确认无语法错误。

**Step 3:** Commit: `feat(id): TUuid record type declaration in id.base`

---

## Task 2: 重写 id.uuid.pas — 核心实现

**Files:**
- Rewrite: `src/nextpas.core.id.uuid.pas`

**Step 1:** 实现 TUuid 的所有方法：
- `NewV4`: 16 字节 platform_random_bytes + 设置 version=4, variant=RFC
- `NewV7`: 48-bit unix_ts_ms + 12-bit rand_a + version=7 + variant + 62-bit rand_b
- `Parse/TryParse`: 解析 "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" 格式
- `ToString`: 格式化为标准 UUID 字符串
- `ToBytes/Version/Variant/IsNil/Equals/CompareTo/TimestampMs`
- `Nil_`: 返回全零 UUID

**Step 2:** 保留向后兼容的 `UuidV4` 函数（调用 TUuid.NewV4.ToString）。新增 `UuidV7`。

**Step 3:** 编译确认。

**Step 4:** Commit: `feat(id/uuid): complete TUuid implementation — v4 + v7 + parse + format`

---

## Task 3: 更新 id facade

**Files:**
- Modify: `src/nextpas.core.id.pas`

**Step 1:** 在 facade 中 re-export TUuid 类型和新增的 UuidV7/UuidParse/UuidIsValid 函数。

**Step 2:** 编译确认。

**Step 3:** Commit: `feat(id): facade re-export TUuid + UuidV7 + UuidParse + UuidIsValid`

---

## Task 4: 扩展测试 — 全接口覆盖

**Files:**
- Modify: `tests/nextpas.core.id/test_id/test_id.lpr`

**Step 1:** 新增测试用例覆盖所有 API：

UUID v4:
- 长度 36, 格式正确 (已有)
- version nibble = '4' (已有)
- variant nibble ∈ {8,9,a,b} (已有)
- 唯一性 (已有)
- 使用 TUuid.NewV4 record API

UUID v7:
- 长度 36, 格式正确
- version nibble = '7'
- variant nibble ∈ {8,9,a,b}
- 时间排序性：连续生成的 v7 字符串 lexicographic 有序
- TimestampMs 提取正确（和 platform_realtime_ns/1000000 接近）

Parse/Format:
- Parse 已知 UUID 字符串 → 正确 bytes
- Parse nil UUID "00000000-0000-0000-0000-000000000000"
- Parse 无效字符串 → TryParse 返回 False
- Parse 大小写不敏感
- ToString 输出小写

TUuid record:
- IsNil 对 Nil_ 返回 True
- Equals 自反性
- CompareTo 排序正确
- Version/Variant 提取正确

**Step 2:** 运行测试全部通过。

**Step 3:** heaptrc 验证 0 泄漏。

**Step 4:** Commit: `test(id/uuid): full API coverage — v4 + v7 + parse + format + record ops`

---

## Task 5: 文档

**Files:**
- Create: `docs/id/README.md`

**Step 1:** 写模块文档（概述、API 入口、使用示例、RFC 合规说明）。

**Step 2:** Commit: `docs(id): module README — UUID/ULID/NanoID overview and usage`

---

## Task 6: Benchmark（最后一轮）

**Files:**
- Create: `benchmarks/nextpas.core.id/bench_uuid/bench_uuid.lpr`
- Create: `benchmarks/nextpas.core.id/bench_uuid/Makefile`

**Step 1:** 基准测试覆盖：
- UuidV4 生成 ns/op
- UuidV7 生成 ns/op
- UuidParse ns/op
- UuidToString ns/op
- 对照：Go uuid.New(), Rust uuid::Uuid::new_v4()

**Step 2:** Commit: `bench(id/uuid): generation + parse benchmark with Go/Rust reference`

---

## 验收标准

- [ ] TUuid.NewV4 使用 platform_random_bytes（密码学安全）
- [ ] TUuid.NewV7 使用 platform_realtime_ns（毫秒精度时间戳）
- [ ] 所有 API 100% 测试覆盖
- [ ] heaptrc 零泄漏
- [ ] 向后兼容：现有 UuidV4 函数签名不变
- [ ] 遵循 design-conventions.md 规范
