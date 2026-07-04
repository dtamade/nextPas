# nextpas.core.event 代码契约

> 模块路径: `core/src/nextpas.core.event.*.pas`
> 创建日期: 2026-07-04
> 维护者: AI

---

## 概述

unit nextpas.core.event;

---

## 关键类型

```pascal
  type
    TSubscriptionID = nextpas.core.event.base.TSubscriptionID;
    TEventPriority = nextpas.core.event.base.TEventPriority;
    TEventData = nextpas.core.event.base.TEventData;
    TEventDataKind = nextpas.core.event.base.TEventDataKind;
    TEventHandler = nextpas.core.event.base.TEventHandler;
    TEventHandlerProc = nextpas.core.event.base.TEventHandlerProc;
    IEventBus = nextpas.core.event.intf.IEventBus;
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
