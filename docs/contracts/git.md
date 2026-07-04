# nextpas.core.git 代码契约

> 模块路径: `core/src/nextpas.core.git.*.pas`
> 创建日期: 2026-07-04
> 维护者: AI

---

## 概述

unit nextpas.core.git;

---

## 关键类型

```pascal
  type
    TGitBranchKind = nextpas.core.git.base.TGitBranchKind;
    TGitPullFastForwardResult = nextpas.core.git.base.TGitPullFastForwardResult;
    TGitStatusFlag = nextpas.core.git.base.TGitStatusFlag;
    TGitStatusFlags = nextpas.core.git.base.TGitStatusFlags;
    TGitStatusEntry = nextpas.core.git.base.TGitStatusEntry;
    TGitStatusEntryArray = nextpas.core.git.base.TGitStatusEntryArray;
    TGitStatusFilter = nextpas.core.git.base.TGitStatusFilter;
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
