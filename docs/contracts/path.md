# nextpas.core.path 代码契约

> 模块路径: `core/src/nextpas.core.path.*.pas`
> 创建日期: 2026-07-04
> 维护者: AI

---

## 概述

unit nextpas.core.path;

---

## 关键类型

```pascal
  function PathJoin(const ABase, AChild: string): string;
  function PathJoin3(const A, B, C: string): string;
  function PathDir(const APath: string): string;
  function PathBase(const APath: string): string;
  procedure PathSplit(const APath: string; out ADir, ABase: string);
  function PathExt(const APath: string): string;
  function PathChangeExt(const APath, ANewExt: string): string;
  function PathIsAbsolute(const APath: string): Boolean;
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
