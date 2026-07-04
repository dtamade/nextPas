# nextpas.core.async 代码契约

> 模块路径: `core/src/nextpas.core.async.*.pas`
> 创建日期: 2026-07-04
> 维护者: AI

---

## 概述

异步框架门面。提供事件循环、定时器堆、异步任务和 I/O 完成通知。

---

## 关键类型

```pascal
type
  TAsyncCallback = reference to procedure;
  TAsyncTimerHandle = UInt64;
  TTimerHeap;           { 定时器最小堆 }
  TAsyncLoop;           { 事件循环 }
  TAsyncTask;           { 异步任务 }
  TIoCompletion;        { I/O 完成回调 }

  TAsyncTaskStatus = (
    atsIdle, atsPending, atsCompleted,
    atsFailed, atsTimedOut, atsCancelled
  );
```

---

## 线程安全

- TAsyncLoop 设计为单线程事件循环
- TAsyncTask 状态转换由事件循环保证

---

## 依赖关系

- 依赖: base, time, thread, io.poller, platform.io
- 被依赖: net, http, websocket

---

## 变更记录

| 日期 | 变更 | 原因 |
|------|------|------|
| 2026-07-04 | 初始版本 | 契约建立 |
