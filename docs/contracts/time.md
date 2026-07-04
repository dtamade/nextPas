# nextpas.core.time 代码契约

> 模块路径: `core/src/nextpas.core.time.*.pas`
> 创建日期: 2026-07-04
> 维护者: AI

---

## 概述

时间门面。提供 TDuration、TInstant、TDeadline、TDate、TTimeOfDay、
TNaiveDateTime、TStopwatch、TTimer、TTicker、TPeriod。

---

## 关键类型

```pascal
type
  TDuration;          { 时间间隔（纳秒精度） }
  TInstant;           { 单调时间点 }
  TStopwatch;         { 秒表 }
  TDate;              { 日期 }
  TDayOfWeek;         { 星期 }
  TTimeOfDay;         { 时间 }
  TNaiveDateTime;     { 日期+时间（无时区） }
  TDeadline;          { 截止时间 }
  TSleep;             { 睡眠工具 }
  TTimer;             { 定时器 }
  TTicker;            { 周期性定时器 }
  TPeriod;            { 周期 }
```

---

## 线程安全

- TInstant/TDuration 为值类型，天然线程安全
- TStopwatch/TTimer 不线程安全

---

## 依赖关系

- 依赖: base, platform.time
- 被依赖: async, http, net, sync

---

## 变更记录

| 日期 | 变更 | 原因 |
|------|------|------|
| 2026-07-04 | 初始版本 | 契约建立 |
