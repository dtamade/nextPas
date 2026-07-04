# nextpas.core.multipart 代码契约

> 模块路径: `core/src/nextpas.core.multipart.*.pas`
> 创建日期: 2026-07-04
> 维护者: AI

---

## 概述

unit nextpas.core.multipart;

---

## 关键类型

```pascal
  type
    TMultipartHeader = nextpas.core.multipart.base.TMultipartHeader;
    TMultipartHeaderArray = nextpas.core.multipart.base.TMultipartHeaderArray;
    TMultipartPart = nextpas.core.multipart.base.TMultipartPart;
    TMultipartPartArray = nextpas.core.multipart.base.TMultipartPartArray;
  function MultipartExtractBoundary(const AContentType: string): string;
  function TryMultipartExtractBoundary(const AContentType: string; out ABoundary: string): Boolean;
  function ParseMultipart(const ABody: TBytes; const ABoundary: string): TMultipartPartArray;
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
