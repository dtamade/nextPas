# nextpas.core.contracts 代码契约

> 模块路径: `core/src/nextpas.core.contracts.pas`
> 创建日期: 2026-07-04
> 维护者: AI

---

## 概述

条件编译契约断言。当 `NEXTPAS_CORE_CONTRACTS` 定义时，断言生效并抛异常；
未定义时，断言被编译器优化为空操作（零开销）。

---

## 接口签名

```pascal
procedure ContractsRequire(ACondition: Boolean; const AMessage: string);
{ 前置条件断言。ACondition=false 时 raise EInvalidArgument。
  未定义 NEXTPAS_CORE_CONTRACTS 时为空操作。 }

procedure ContractsRequireAssigned(ACondition: Boolean; const AName: string);
{ 非空断言。ACondition=false 时 raise EArgumentNil(AName + ' is nil')。
  未定义 NEXTPAS_CORE_CONTRACTS 时为空操作。 }
```

---

## 前置条件

1. `ContractsRequire`: ACondition 为调用方需要保证的前置条件
2. `ContractsRequireAssigned`: ACondition 通常为 `Assigned(Ptr)` 的结果

---

## 后置条件

1. 契约启用时: ACondition=false 抛异常，true 无操作
2. 契约禁用时: 无操作（inline 展开为空）

---

## 错误语义

| 场景 | 行为 |
|------|------|
| `ContractsRequire(false, msg)` | raise EInvalidArgument(msg) |
| `ContractsRequireAssigned(false, name)` | raise EArgumentNil(name + ' is nil') |
| 契约禁用 | 无操作 |

---

## 线程安全

- 纯函数，无线程安全问题
- 可安全并发调用

---

## 内存管理

- 无动态内存分配
- 异常对象由 FPC 异常机制管理

---

## 依赖关系

- 依赖: `nextpas.core.base`（仅契约启用时）
- 被依赖: 需要契约保护的模块

---

## 变更记录

| 日期 | 变更 | 原因 |
|------|------|------|
| 2026-07-04 | 初始版本 | 契约建立 |
