# nextpas.core.io 代码契约

> 模块路径: `core/src/nextpas.core.io.*.pas`
> 创建日期: 2026-07-04
> 维护者: AI

---

## 概述

I/O 抽象层。提供流接口、内存映射文件、I/O polling 和文件描述符包装。

---

## 关键类型

```pascal
type
  TSeekOrigin = (soBeginning, soCurrent, soEnd);
const
  IO_EOF = -1;
```

---

## 线程安全

- 流接口不线程安全（需外部同步）
- I/O poller 线程安全

---

## 依赖关系

- 依赖: base, bytes, platform.io, fs
- 被依赖: http, net, crypto

---

## 变更记录

| 日期 | 变更 | 原因 |
|------|------|------|
| 2026-07-04 | 初始版本 | 契约建立 |
