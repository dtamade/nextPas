# nextPas/core 反哺计划 — 从 fafafa.game 下沉通用模块

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 将 fafafa.game 中实战验证的通用模块反哺到 nextPas/core 框架，遵循 nextPas 设计规范。

**Architecture:** 每个模块按 nextPas 四件套范式重写（base → intf → 实现 → 门面），使用 dotted namespace 命名，2 空格缩进，独立 .lpr 测试项目。

**Tech Stack:** Free Pascal 3.3.1, nextPas/core 框架规范

---

## 修正后的反哺清单

经过检查，nextPas/core 已有：priorityqueue、arena、pool、object_pool、thread.pool。

**真正缺失且需要反哺的**：

| # | 模块 | 目标 | 来源 | 复杂度 |
|---|------|------|------|--------|
| 1 | `nextpas.core.coroutine` | 无栈协程（状态表驱动） | fafafa Coroutine.pas (481行) | M |
| 2 | `nextpas.core.event` | 事件总线 pub/sub + 追踪 | fafafa EventBus.pas (937行) | L |
| 3 | `nextpas.core.reflect` | 运行时反射 + visitor | fafafa TypeRegistry.pas (532行) | L |

---

## Task 1: nextpas.core.coroutine — 无栈协程

### 文件结构

```
src/nextpas.core.coroutine.base.pas     ← 类型：TCoroutineID, TCoroutineState, TYieldKind
src/nextpas.core.coroutine.intf.pas     ← 接口：ICoroutineManager
src/nextpas.core.coroutine.pas          ← 实现 + 门面
tests/nextpas.core.coroutine/test_coroutine/test_coroutine.lpr
```

### 设计要点

- 状态表驱动：每个协程是一个步骤序列（action → wait → action → ...）
- 零分配热路径：预分配固定数组，无动态内存
- 支持：WaitSeconds、WaitFrames、WaitUntil、WaitCoroutine
- 接口化：ICoroutineManager 允许多实现
- 层级：L1（基础设施，依赖 L0 的 base/time）

### API 设计

```pascal
ICoroutineManager = interface
  function Start(AProc: TCoroutineProc; AUserData: Pointer = nil): TCoroutineID;
  function StartSequence(const ASteps: array of TCoroStep): TCoroutineID;
  procedure Stop(AID: TCoroutineID);
  procedure StopAll;
  procedure YieldFrames(AID: TCoroutineID; AFrames: Integer);
  procedure YieldSeconds(AID: TCoroutineID; ASeconds: Single);
  procedure YieldUntil(AID: TCoroutineID; ACondition: TCoroutineCondition);
  procedure Update(ADeltaTime: Single);
  function GetState(AID: TCoroutineID): TCoroutineState;
  function GetActiveCount: Integer;
end;
```

### 测试覆盖

- TestStartAndFinish
- TestYieldFrames
- TestYieldSeconds
- TestYieldUntil
- TestSequence
- TestStopSingle
- TestStopAll
- TestMaxCoroutines
- TestWaitCoroutine
- TestTag

---

## Task 2: nextpas.core.event — 事件总线

### 文件结构

```
src/nextpas.core.event.base.pas         ← 类型：TEventID, TSubscriptionID
src/nextpas.core.event.intf.pas         ← 接口：IEventBus, ISubscription
src/nextpas.core.event.pas              ← 实现 + 门面
tests/nextpas.core.event/test_event/test_event.lpr
```

### 层级：L3（框架层，设计规范已规划此位置）

---

## Task 3: nextpas.core.reflect — 运行时反射

### 文件结构

```
src/nextpas.core.reflect.base.pas       ← 类型：TFieldKind, TFieldDef, TTypeDef
src/nextpas.core.reflect.intf.pas       ← 接口：ITypeVisitor, ITypeRegistry
src/nextpas.core.reflect.visitor.pas    ← visitor 实现
src/nextpas.core.reflect.pas            ← 门面
tests/nextpas.core.reflect/test_reflect/test_reflect.lpr
```

### 层级：L1（基础设施）

---

## 执行顺序

1. **coroutine**（最独立，无外部依赖，M 复杂度）
2. **reflect**（被 event 可能依赖，先做）
3. **event**（可能用 reflect 做类型化事件）

每个模块完成后：编译 → 测试 → 提交 → 复盘
