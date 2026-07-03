# nextpas.core.errors 代码契约

> 模块路径: `core/src/nextpas.core.errors.pas`
> 创建日期: 2026-07-04
> 维护者: AI

---

## 概述

公共异常分类门面(facade)。从 `nextpas.core.exception` 重新导出所有异常类型、
错误分类常量和辅助函数，使消费者无需直接依赖 `nextpas.core.exception` 或 FPC `SysUtils`。

---

## 接口签名

### 重新导出的类型

| 类型 | 来源 | 用途 |
|------|------|------|
| `Exception` | nextpas.core.exception | 基础异常类 |
| `ExceptClass` | nextpas.core.exception | 异常元类 |
| `EConvertError` | nextpas.core.exception | 类型转换错误 |
| `EAssertionFailed` | nextpas.core.exception | 断言失败 |
| `TErrorCategory` | nextpas.core.exception | 错误分类枚举 |
| `ENextPasError` | nextpas.core.exception | 框架基础异常 |

### 框架异常类型

| 异常类 | TErrorCategory | 语义 |
|--------|----------------|------|
| `EArgumentError` | ecInvalidArgument | 非法参数 |
| `ENullReferenceError` | ecNullReference | 空引用 |
| `EInvalidOperationError` | ecInvalidOperation | 非法操作 |
| `ENotImplementedError` | ecNotImplemented | 未实现 |
| `ENotSupportedError` | ecNotSupported | 不支持 |
| `ETimeoutError` | ecTimeout | 超时 |
| `ECancelledError` | ecCancelled | 已取消 |
| `EInterruptedError` | ecInterrupted | 被中断 |
| `EWouldBlockError` | ecWouldBlock | 会阻塞 |
| `EPermissionError` | ecPermission | 权限不足 |
| `ENotFoundError` | ecNotFound | 未找到 |
| `EAlreadyExistsError` | ecAlreadyExists | 已存在 |
| `EResourceExhaustedError` | ecResourceExhausted | 资源耗尽 |
| `EIOError` | ecIO | I/O 错误 |
| `ENetworkError` | ecNetwork | 网络错误 |
| `EParseError` | ecParse | 解析错误 |
| `EIndexOutOfRangeError` | ecInvalidArgument | 索引越界 |
| `EOutOfMemoryError` | ecInternal | OOM (异常类) |
| `EOutOfMemory` | ecInternal | OOM (别名) |

### 错误分类常量

```pascal
const
  ecNone, ecInvalidArgument, ecNullReference, ecInvalidOperation,
  ecNotImplemented, ecNotSupported, ecTimeout, ecCancelled,
  ecInterrupted, ecWouldBlock, ecPermission, ecNotFound,
  ecAlreadyExists, ecResourceExhausted, ecIO, ecNetwork,
  ecParse, ecInternal: TErrorCategory;
```

### 辅助函数

```pascal
function ErrorCategoryToString(ACategory: TErrorCategory): string;
```

---

## 错误语义

本模块为纯 re-export 门面，无自有错误语义。所有行为由 `nextpas.core.exception` 定义。

---

## 线程安全

- 纯类型和常量重导出，无线程安全问题
- `ErrorCategoryToString` 为纯函数，可安全并发调用

---

## 内存管理

- 无动态内存分配
- 异常对象的内存管理由 FPC 异常机制处理

---

## 依赖关系

- 依赖: `nextpas.core.exception`
- 被依赖: 框架高层模块（消费者应通过本模块访问异常类型）

---

## 设计决策

本模块存在意义：让消费者通过 `uses nextpas.core.errors` 获取完整异常体系，
而不需要知道 `nextpas.core.exception` 的存在。这保持了模块依赖图的简洁。

---

## 变更记录

| 日期 | 变更 | 原因 |
|------|------|------|
| 2026-07-04 | 初始版本 | 契约建立 |
