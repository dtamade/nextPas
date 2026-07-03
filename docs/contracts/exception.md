# nextpas.core.exception 代码契约

> 模块路径: `core/src/nextpas.core.exception.pas`
> 创建日期: 2026-07-04
> 维护者: AI

---

## 概述

框架异常根模块。定义 `ENextPasError` 基类、`TErrorCategory` 分类枚举和完整异常层次。
是 `nextpas.core.base` 和 `nextpas.core.errors` 的底层依赖。

---

## 接口签名

### 基础类型

```pascal
type
  Exception = SysUtils.Exception;      { FPC 模式下重导出 }
  ExceptClass = SysUtils.ExceptClass;
  EConvertError = SysUtils.EConvertError;
  EAssertionFailed = SysUtils.EAssertionFailed;
```

### 错误分类

```pascal
type
  TErrorCategory = (
    ecNone, ecInvalidArgument, ecNullReference, ecInvalidOperation,
    ecNotImplemented, ecNotSupported, ecTimeout, ecCancelled,
    ecInterrupted, ecWouldBlock, ecPermission, ecNotFound,
    ecAlreadyExists, ecResourceExhausted, ecIO, ecNetwork,
    ecParse, ecInternal
  );
```

### 框架根异常

```pascal
type
  ENextPasError = class(Exception)
    constructor Create(AMessage: string);
    constructor Create(AMessage: string; ACategory: TErrorCategory);
    constructor CreateFmt(AMessage: string; AArgs: array of const);
    constructor Create(AMessage: string; AInner: Exception; AOwnsInner = True);
    destructor Destroy; override;
    property Category: TErrorCategory;
    property Inner: Exception;
  end;
```

### 特化异常类

| 类 | DefaultCategory | 用途 |
|----|-----------------|------|
| EArgumentError | ecInvalidArgument | 非法参数 |
| ENullReferenceError | ecNullReference | 空引用 |
| EInvalidOperationError | ecInvalidOperation | 非法操作 |
| ENotImplementedError | ecNotImplemented | 未实现 |
| ENotSupportedError | ecNotSupported | 不支持 |
| ETimeoutError | ecTimeout | 超时 |
| ECancelledError | ecCancelled | 已取消 |
| EInterruptedError | ecInterrupted | 被中断 |
| EWouldBlockError | ecWouldBlock | 会阻塞 |
| EPermissionError | ecPermission | 权限不足 |
| ENotFoundError | ecNotFound | 未找到 |
| EAlreadyExistsError | ecAlreadyExists | 已存在 |
| EResourceExhaustedError | ecResourceExhausted | 资源耗尽 |
| EIOError | ecIO | I/O 错误 |
| ENetworkError | ecNetwork | 网络错误 |
| EParseError | ecParse | 解析错误 |
| EIndexOutOfRangeError | ecInvalidArgument | 索引越界 |
| EOutOfMemoryError | (default) | OOM |

---

## 前置条件

1. 所有 Create 构造函数: AMessage 通常应为有意义的描述
2. Create with AInner: AInner 可以为 nil（此时忽略 AOwnsInner）

---

## 后置条件

1. `ENextPasError.Category`: 未指定时返回子类的 `DefaultCategory`
2. `ENextPasError.Inner`: 返回内嵌异常，可为 nil
3. `ENextPasError.Destroy`: 如果 `AOwnsInner=True`，释放 Inner 异常

---

## 错误语义

本模块定义错误语义本身，不产生额外错误。

---

## 线程安全

- 异常对象本身不线程安全（与 FPC Exception 行为一致）
- 异常创建和抛出由 FPC 运行时保证 per-thread 安全

---

## 内存管理

- `AOwnsInner=True` 时，ENextPasError 拥有 Inner 的生命周期
- 析构时自动释放 Inner（如果拥有）
- 异常对象由 FPC 异常机制管理

---

## 依赖关系

- 依赖: FPC `SysUtils`（FPC 模式）或 `System`（nextPas 自举模式）
- 被依赖: `nextpas.core.base`, `nextpas.core.errors`, 几乎所有框架模块

---

## 变更记录

| 日期 | 变更 | 原因 |
|------|------|------|
| 2026-07-04 | 初始版本 | 契约建立 |
