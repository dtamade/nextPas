# nextpas.core.atomic 代码契约

**模块路径**：`core/src/nextpas.core.atomic*.pas`（4 个源文件）
**层级**：L0（依赖 base；与 `core/docs/core-module-registry.md` 一致）
**Owner**：Claude（AI 负责）
**最后更新**：2026-07-17
**版本**：1.3

---

## 1. 接口契约

### 1.1 子模块

| 文件 | 职责 |
|------|------|
| atomic.types | `TAtomicInt32`/`TAtomicUInt32`/`TAtomicInt64`/`TAtomicUInt64`/`TAtomicBool` 等 |
| atomic.core | CAS/Load/Store/FetchAdd/FetchOr 等核心原语（`atomic_*` + `mo_*`） |
| atomic.compat | 兼容层 / 旧 PascalCase 表面 |
| atomic.pas | 门面 re-export |

### 1.2 核心类型

```pascal
TAtomicInt32 = record
  function Load(AOrder: TMemoryOrder = moSeqCst): Int32;
  procedure Store(AValue: Int32; AOrder: TMemoryOrder = moSeqCst);
  function Exchange(AValue: Int32; AOrder: TMemoryOrder = moSeqCst): Int32;
  function CompareExchange(AExpected, ADesired: Int32; AOrder: TMemoryOrder = moSeqCst): Boolean;
  function FetchAdd(AValue: Int32; AOrder: TMemoryOrder = moSeqCst): Int32;
  function FetchSub(AValue: Int32; AOrder: TMemoryOrder = moSeqCst): Int32;
  function FetchOr(AValue: Int32; AOrder: TMemoryOrder = moSeqCst): Int32;
  function FetchAnd(AValue: Int32; AOrder: TMemoryOrder = moSeqCst): Int32;
end;

TAtomicUInt64 = record
  // 同 TAtomicInt32 宽度族，但操作 UInt64
end;

TAtomicBool = record
  function Load(AOrder: TMemoryOrder = moSeqCst): Boolean;
  procedure Store(AValue: Boolean; AOrder: TMemoryOrder = moSeqCst);
  function Exchange(AValue: Boolean; AOrder: TMemoryOrder = moSeqCst): Boolean;
end;
```

### 1.3 内存序（双入口）

两套等价别名并存，语义相同：

```pascal
// C11 风格（atomic.core / 低层 hot path 推荐）
memory_order_t = (mo_relaxed, mo_consume, mo_acquire, mo_release, mo_acq_rel, mo_seq_cst);

// PascalCase 别名（facade / TAtomic* 记录常用）
TMemoryOrder = (moRelaxed, moAcquire, moRelease, moAcqRel, moSeqCst);
// 另有 moConsume 对应 mo_consume
```

**选择规则**：
1. 新低层 / 热路径代码优先 `atomic_*` + `mo_*`（例如 `atomic_load(V, mo_acquire)`）
2. 需要类型安全所有权时用 `TAtomic*` + `moAcquire` 等 PascalCase 别名
3. 不要在同一函数内混用两套命名；模块内保持一种风格

### 1.4 Preferred path vs legacy CAS（R7 + H2-3）

**首选路径（Preferred）** — 新代码 / 触达修改必须走这里：

| 场景 | Preferred API |
|------|----------------|
| 标量 RMW / load-store | `atomic_load` / `atomic_store` / `atomic_fetch_*` + `mo_*` |
| CAS | `atomic_compare_exchange_strong` / `_weak`（Boolean + `var AExpected`） |
| 类型安全存储 | `TAtomicInt32` / `TAtomicUInt64` / `TAtomicBool` / `TAtomicPtr<T>` 等 + PascalCase `moAcquire`… |
| 指针字节偏移 | 主门面 `atomic_fetch_add/sub(var Pointer; PtrInt)` |

**legacy（保留、非首选）** — **不删除任何公开符号**：

| 表面 | 返回/语义 | 偏好 |
|------|-----------|------|
| `AtomicCompareExchange32/64/Ptr` | 返回 **观测值**（调用方用 `= AExpected` 判成功） | **legacy** |
| `AtomicLoad32/64`、`AtomicStore32/64`、`AtomicFetchAdd*`、`AtomicWait*` 等 PascalCase | 与 `atomic_*` 等价包装 | **legacy 兼容** |
| `atomic.compat` pointer bitwise / 算术 overload | 旧调用点 | **legacy**；主门面 **禁止扩大** |

**日程（文档纪律，非删码里程碑）**：

1. **即日起**：新单元、新函数、重构触达点 → `atomic_*` 或 `TAtomic*`。
2. **不强制** 全库机械替换 `AtomicCompareExchange*`（lockfree 内联热路径体量大；正确性优先于重命名）。
3. **禁止** 在 `nextpas.core.atomic` 主门面继续扩大 pointer bitwise / 新的 PascalCase 别名；扩展放 `atomic.compat` 且需评审。
4. 未来若删 legacy，须单独修订本 CONTRACT + roadmap **重大变更**流程（当前 **不做**；H2 D3）。

常见误读：把 `AtomicCompareExchange32(...)` 的返回值当 Boolean。它是 **Int32 观测值**，不是 `True/False`。

**测试 / 审计脚注**：atomic 测试门覆盖 preferred 与 legacy 两面以保兼容；覆盖 **≠** 鼓励新代码用 legacy。
消费者分布与 preferred 占比见 [`../lockfree/consumer-audit.md`](../lockfree/consumer-audit.md) §3.3 / H2-3 脚注。

---

## 2. 不变量

- **[INV-1]** 所有原子操作在硬件级别保证原子性
- **[INV-2]** mo_seq_cst / moSeqCst 提供最强的全序保证
- **[INV-3]** CAS 操作返回 True 时，值已被替换
- **[INV-4]** 原子类型必须自然对齐（SizeOf(Pointer) 边界）
- **[INV-5]** 生产/测试/示例均不直接 `uses` FPC RTL（仅 `nextpas.core.system*` 门面可桥接）；异常经 `nextpas.core.errors`

### 2.1 FPC RTL isolation

`nextpas.core.atomic*` 生产单元与 `core/tests/nextpas.core.atomic/**` 测试不得直接
`uses SysUtils/Classes/Math/Windows/BaseUnix/Unix/TypInfo/StrUtils/DateUtils/SyncObjs/Contnrs`。
与 lockfree 共享 isolation source-contract（见 `core/docs/lockfree/CONTRACT.md` §2.1）。
公开类型名是 **`TAtomicInt32`**（不是 `TAtomicInt`）。

---

## 3. 错误处理

- 核心原子 RMW 无异常；CAS 失败返回 False
- 类型包装层对非法配置可抛 `EArgumentError`（经 errors 门面）

---

## 4. 线程安全

**所有操作本身就是线程安全的。** 这是线程安全的基础原语。

---

## 5. 内存管理

- 原子类型为 record，栈/堆上均可使用
- 不分配堆内存
- 调用方负责确保底层内存生命周期

---

## 6. 测试覆盖

| 测试目录 | 说明 | 规模（约） |
|----------|------|------------|
| test_atomic | Load/Store/CAS/FetchAdd/内存序/wait/notify | **~45** tests |
| **合计** | **1 个测试目录** | |

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-01 | 1.0 | 初始版本 | Claude |
| 2026-07-17 | 1.1 | TAtomicInt32 命名；RTL isolation；~45 tests | Codex |
| 2026-07-17 | 1.2 | §1.4 Legacy CAS 弃用偏好（R7；不删 API） | Codex |
