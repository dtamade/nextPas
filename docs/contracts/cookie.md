# nextpas.core.cookie 代码契约

> 模块路径: `core/src/nextpas.core.cookie.*.pas`
> 创建日期: 2026-07-04
> 维护者: AI

---

## 概述

unit nextpas.core.cookie;

---

## 关键类型

```pascal
  type
    TCookieSameSite = nextpas.core.cookie.base.TCookieSameSite;
    TCookie = nextpas.core.cookie.base.TCookie;
    TCookieArray = nextpas.core.cookie.base.TCookieArray;
    TSetCookie = nextpas.core.cookie.base.TSetCookie;
  function ParseCookieHeader(const AHeader: string): TCookieArray;
  function TryParseCookieHeader(const AHeader: string; out ACookies: TCookieArray): Boolean;
  function ParseSetCookieHeader(const AHeader: string): TSetCookie;
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
