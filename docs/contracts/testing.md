# nextpas.core.testing 代码契约

> 模块路径: `core/src/nextpas.core.testing.pas`
> 创建日期: 2026-07-04
> 维护者: AI

---

## 概述

**已废弃** — 请使用 `nextpas.core.test`。
保留为向后兼容，Check/CheckEqual/Fail 委托到 `nextpas.core.test.check`。

---

## 关键类型

```pascal
type
  TTestProc = procedure;
  TTestClosure = reference to procedure;
  TSuiteRunner = record
    class function Create(ASuiteName: string): TSuiteRunner; static;
    procedure Run(AName: string; AProc: TTestProc);
    procedure Summary;
    function AllPassed: Boolean;
  end;
```

---

## 依赖关系

- 依赖: system, errors, text.conv, test.check
- 被依赖: 旧测试代码（应迁移到 test）

---

## 变更记录

| 日期 | 变更 | 原因 |
|------|------|------|
| 2026-07-04 | 初始版本 | 契约建立 |
