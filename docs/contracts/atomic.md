# nextpas.core.atomic 代码契约

> 模块路径: `core/src/nextpas.core.atomic.*.pas`
> 创建日期: 2026-07-04
> 维护者: AI

---

## 概述

跨平台原子操作实现，提供 C++ 风格的内存序语义和类型安全的泛型封装。
基于平台原生原子指令，支持 lock-free 并发数据结构。

---

## 模块分层

| 单元 | 职责 |
|------|------|
| `atomic.core` | 内存序定义、底层原子原语（GCC/MSVC builtins 或 Fallback） |
| `atomic.types` | 泛型原子类型封装 |
| `atomic.pas` | 门面聚合 |

---

## 接口签名

### 内存序

```pascal
type
  memory_order_t = (
    moRelaxed,  { 无序 }
    moConsume,  { consume 语义 }
    moAcquire,  { acquire 屏障 }
    moRelease,  { release 屏障 }
    moAcqRel,   { acquire + release }
    moSeqCst    { 顺序一致性（默认） }
  );
```

### 原子整数类型

```pascal
type
  TAtomicInt32 = record
    function Load(AOrder: memory_order_t = moSeqCst): Int32;
    procedure Store(AValue: Int32; AOrder: memory_order_t = moSeqCst);
    function Exchange(AValue: Int32; AOrder: memory_order_t = moSeqCst): Int32;
    function CompareExchangeStrong(var AExpected: Int32; ADesired: Int32;
      ASuccess, AFailure: memory_order_t = moSeqCst): Boolean;
    function CompareExchangeWeak(var AExpected: Int32; ADesired: Int32;
      ASuccess, AFailure: memory_order_t = moSeqCst): Boolean;
    function FetchAdd(AValue: Int32; AOrder: memory_order_t = moSeqCst): Int32;
    function FetchSub(AValue: Int32; AOrder: memory_order_t = moSeqCst): Int32;
    function FetchAnd(AValue: Int32; AOrder: memory_order_t = moSeqCst): Int32;
    function FetchOr(AValue: Int32; AOrder: memory_order_t = moSeqCst): Int32;
    function FetchXor(AValue: Int32; AOrder: memory_order_t = moSeqCst): Int32;
    function IsLockFree: Boolean;
  end;

  TAtomicUInt32 = record;  { 同 TAtomicInt32，操作类型为 UInt32 }
  TAtomicInt64 = record;   { 64 位有符号原子整数 }
  TAtomicUInt64 = record;  { 64 位无符号原子整数 }
  TAtomicBool = record;    { 原子布尔 }
```

### 底层原语（atomic.core）

```pascal
function atomic_load(var AObj: Int32; AOrder: memory_order_t): Int32;
procedure atomic_store(var AObj: Int32; AValue: Int32; AOrder: memory_order_t);
function atomic_exchange(var AObj: Int32; AValue: Int32; AOrder: memory_order_t): Int32;
function atomic_compare_exchange_strong(var AObj: Int32; var AExpected: Int32;
  ADesired: Int32; ASuccess, AFailure: memory_order_t): Boolean;
function atomic_fetch_add(var AObj: Int32; AValue: Int32; AOrder: memory_order_t): Int32;
function atomic_is_lock_free_32: Boolean;
{ ... 64 位变体类似 ... }
```

---

## 前置条件

1. 所有原子变量必须自然对齐（record 保证）
2. CompareExchange: AExpected 按引用传递，失败时更新为当前值
3. 内存序参数必须与操作类型匹配（如 store 不可用 moAcquire）

---

## 后置条件

1. Load: 返回调用时刻的值（受内存序约束）
2. FetchAdd/Sub/And/Or/Xor: 返回操作前的值，原子修改为操作后的值
3. CompareExchangeStrong: 成功时返回 true，AObj 设为 ADesired
4. CompareExchangeWeak: 可能虚假失败（spurious failure），其余同 Strong
5. IsLockFree: 返回该类型是否使用无锁实现

---

## 错误语义

| 场景 | 行为 |
|------|------|
| 非法内存序组合 | 未定义行为（调用方责任） |
| 对齐不满足 | 硬件异常（平台相关） |

---

## 线程安全

- **所有操作完全线程安全**
- 基于硬件原子指令（x86 LOCK 前缀、ARM LDXR/STXR）
- 无锁设计，无互斥等待

---

## 内存管理

- 纯值类型 record，栈分配
- 无动态内存分配
- 无资源管理

---

## 测试覆盖

| 套件 | 路径 | 范围 |
|------|------|------|
| test_atomic_* | `core/tests/nextpas.core.atomic/` | 原子操作、内存序、CAS |

---

## 依赖关系

- 依赖: `nextpas.core.platform.sync`（底层 fence/barrier）
- 被依赖: `nextpas.core.sync`, `nextpas.core.lockfree`, `nextpas.core.collections`

---

## 变更记录

| 日期 | 变更 | 原因 |
|------|------|------|
| 2026-07-04 | 初始版本 | 契约建立 |
