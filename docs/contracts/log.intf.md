# nextpas.core.log.intf 代码契约

> 模块路径: `core/src/nextpas.core.log.intf.pas`
> 创建日期: 2026-07-04
> 维护者: AI

---

## 概述

日志接口定义。提供 `ILogger` 最小契约和 `TNullLogger` 安全默认实现。
零外部依赖，仅定义接口，不涉及具体日志输出。

---

## 接口签名

### 日志级别

```pascal
type
  TLogLevel = (
    llTrace,  { 最细粒度调试信息 }
    llDebug,  { 开发诊断信息 }
    llInfo,   { 正常运行关键事件 }
    llWarn,   { 可恢复异常 }
    llError,  { 需关注但不致命 }
    llFatal   { 进程无法继续 }
  );
```

### ILogger 接口

```pascal
type
  ILogger = interface
    procedure Log(ALevel: TLogLevel; AMessage: string);
    procedure Trace(AMessage: string);
    procedure Debug(AMessage: string);
    procedure Info(AMessage: string);
    procedure Warn(AMessage: string);
    procedure Error(AMessage: string);
    procedure Fatal(AMessage: string);
  end;
```

### TNullLogger

```pascal
type
  TNullLogger = class(TInterfacedObject, ILogger)
    { 所有方法为空操作 }
  end;

function NullLogger: ILogger;
```

---

## 后置条件

1. `NullLogger`: 永远返回同一单例
2. `TNullLogger`: 所有 Log 方法为空操作，无副作用
3. `ILogger` 实现: 线程安全（由实现保证）

---

## 线程安全

- `ILogger` 契约要求实现保证线程安全
- `TNullLogger` 天然线程安全（无状态）
- `NullLogger` 单例初始化非线程安全（首次调用时初始化）

---

## 内存管理

- `ILogger` 为接口类型，引用计数自动管理
- `TNullLogger` 为 TInterfacedObject 子类
- `NullLogger` 单例持有全局引用

---

## 依赖关系

- 依赖: 无
- 被依赖: 所有需要日志的模块

---

## 变更记录

| 日期 | 变更 | 原因 |
|------|------|------|
| 2026-07-04 | 初始版本 | 契约建立 |
