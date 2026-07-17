# nextpas.core.atomic 代码契约

**模块路径**：`core/src/nextpas.core.atomic*.pas`（4 个源文件）
**层级**：L0（依赖 base；与 `core/docs/core-module-registry.md` 一致）
**Owner**：Claude（AI 负责）
**最后更新**：2026-07-17
**版本**：1.1

---

## 1. 接口契约

### 1.1 子模块

| 文件 | 职责 |
|------|------|
| atomic.types | TAtomicInt, TAtomicUInt64, TAtomicBool 类型 |
| atomic.core | CAS/Load/Store/FetchAdd/FetchOr 等核心原语 |
| atomic.compat | C++ std::memory_order 兼容 API |
| atomic.pas | 门面 |

### 1.2 核心类型

```pascal
TAtomicInt = record
  function Load(AOrder: TMemoryOrder = moSeqCst): Integer;
  procedure Store(AValue: Integer; AOrder: TMemoryOrder = moSeqCst);
  function Exchange(AValue: Integer; AOrder: TMemoryOrder = moSeqCst): Integer;
  function CompareExchange(AExpected, ADesired: Integer; AOrder: TMemoryOrder = moSeqCst): Boolean;
  function FetchAdd(AValue: Integer; AOrder: TMemoryOrder = moSeqCst): Integer;
  function FetchSub(AValue: Integer; AOrder: TMemoryOrder = moSeqCst): Integer;
  function FetchOr(AValue: Integer; AOrder: TMemoryOrder = moSeqCst): Integer;
  function FetchAnd(AValue: Integer; AOrder: TMemoryOrder = moSeqCst): Integer;
end;

TAtomicUInt64 = record
  // 同 TAtomicInt，但操作 UInt64
end;

TAtomicBool = record
  function Load(AOrder: TMemoryOrder = moSeqCst): Boolean;
  procedure Store(AValue: Boolean; AOrder: TMemoryOrder = moSeqCst);
  function Exchange(AValue: Boolean; AOrder: TMemoryOrder = moSeqCst): Boolean;
end;
```

### 1.3 内存序

```pascal
TMemoryOrder = (
  moRelaxed,  // 无序
  moAcquire,  // 读屏障
  moRelease,  // 写屏障
  moAcqRel,   // 读写屏障
  moSeqCst    // 全序（默认）
);
```

---

## 2. 不变量

- **[INV-1]** 所有原子操作在硬件级别保证原子性
- **[INV-2]** moSeqCst 提供最强的全序保证
- **[INV-3]** CAS 操作返回 True 时，值已被替换
- **[INV-4]** 原子类型必须自然对齐（SizeOf(Pointer) 边界）

---

## 3. 错误处理

- 无异常。所有操作直接操作内存。
- CAS 失败返回 False，不抛异常。

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

| 测试目录 | 说明 |
|----------|------|
| test_atomic | Load/Store/CAS/FetchAdd 多线程测试 |
| **合计** | **1 个测试目录** |

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-01 | 1.0 | 初始版本 | Claude |
