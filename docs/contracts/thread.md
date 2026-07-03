# nextpas.core.thread 代码契约

> 模块路径: `core/src/nextpas.core.thread.*.pas`
> 创建日期: 2026-07-04
> 维护者: AI

---

## 概述

线程抽象层。提供线程创建、Future/Promise 和线程池。

---

## 关键类型

```pascal
type
  TThreadTask = reference to procedure;

  TFutureState = (
    fsPending, fsCompleted, fsFailed, fsCancelled
  );
```

---

## 线程安全

- Future/线程池接口完全线程安全
- 线程任务在独立线程执行

---

## 依赖关系

- 依赖: base, platform.thread, sync
- 被依赖: async, http, collections.concurrent

---

## 变更记录

| 日期 | 变更 | 原因 |
|------|------|------|
| 2026-07-04 | 初始版本 | 契约建立 |
