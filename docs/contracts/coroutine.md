# nextpas.core.coroutine 代码契约

> 模块路径: `core/src/nextpas.core.coroutine.*.pas`
> 创建日期: 2026-07-04
> 维护者: AI

---

## 概述

unit nextpas.core.coroutine;

---

## 关键类型

```pascal
  type
    TCoroutineID = nextpas.core.coroutine.base.TCoroutineID;
    TCoroutineState = nextpas.core.coroutine.base.TCoroutineState;
    TYieldKind = nextpas.core.coroutine.base.TYieldKind;
    TCoroStep = nextpas.core.coroutine.base.TCoroStep;
    TCoroStepKind = nextpas.core.coroutine.base.TCoroStepKind;
    TCoroutineProc = nextpas.core.coroutine.base.TCoroutineProc;
    TCoroutineCondition = nextpas.core.coroutine.base.TCoroutineCondition;
```

---

## 线程安全

- 值类型 record 为天然线程安全
- 接口类型按具体实现确定

---

## 依赖关系

- 依赖: base
- 被依赖: 上层模块

---

## 变更记录

| 日期 | 变更 | 原因 |
|------|------|------|
| 2026-07-04 | 初始版本 | 契约建立 |
