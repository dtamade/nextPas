# nextpas.core.system 代码契约

> 模块路径: `core/src/nextpas.core.system.pas`
> 创建日期: 2026-07-04
> 维护者: AI

---

## 概述

系统模块根门面。从 `base`、`exception`、`errors` 重新导出所有基础类型和异常，
为消费者提供"只需 uses nextpas.core.system"的单入口体验。

---

## 接口签名

### 重导出的常量

```pascal
const
  NEXTPAS_SYSTEM_NAME = 'nextpas.core.system';
  MAX_SIZE_INT, MAX_SIZE_UINT, MIN_SIZE_INT,
  SIZE_PTR, SIZE_8, SIZE_16, SIZE_32, SIZE_64;
```

### 重导出的类型

| 来源 | 类型 |
|------|------|
| base | SizeInt, SizeUInt, PtrInt, PtrUInt, NativeInt, NativeUInt |
| base | TBytes, TByteSpan, THashCode |
| exception | Exception, ExceptClass, EConvertError, EAssertionFailed, EAbort |
| exception | TErrorCategory, ENextPasError |
| base | ECore, EInvariantViolation, EArgumentNil, EInvalidArgument, ... |
| errors | EArgumentError, ENullReferenceError, ETimeoutError, ... |

### 子模块门面

| 单元 | 职责 |
|------|------|
| `system.classes` | **live 10-type shim**：`TSeekOrigin`, `TStream`, `THandleStream`, `TMemoryStream`, `TFileStream`, `TList`, `TInterfaceList`, `TStringList`, `TDuplicates`, `TThread` + `fmCreate`/`fmOpen*`/`fmShare*`（窄门面，非 `TComponent`/`TPersistent`） |
| `system.sysutils` | **live 40+ 函数** S4 兼容薄门面：`Format`/`SameText`/`IntToStr`/`Trim` + `StrToInt`/`StrToInt64`/`FloatToStr`/`FileExists`/`ExtractFile*`/`Now`/`Sleep`/`SysErrorMessage` 等 **仅 re-export/委托**；文本 owner `nextpas.core.text.conv`，`path`/`fs`/`platform` 分担；Exception 别名 owner `nextpas.core.exception` |
| `system.typinfo` | PTypeInfo/TTypeKind/InitializeArray/FinalizeArray/CopyArray |
| `system.memmanager` | 内存管理器接口 |
| `system.contracts` | 契约断言（条件编译） |

---

## 错误语义

本模块为纯 re-export 门面，无自有错误语义。

---

## 线程安全

- 纯类型重导出，无线程安全问题

---

## 依赖关系

- 依赖: `nextpas.core.base`, `nextpas.core.exception`, `nextpas.core.errors`
- 被依赖: 编译器自举目标（system 模块是 FPC System 的替代）

---

## 设计决策

system 模块存在意义：为编译器自举提供 FPC System 的替代入口。
消费者通过 `uses nextpas.core.system` 获取完整基础类型体系，
编译器将 `uses System` 映射到本模块。

---

## 变更记录

| 日期 | 变更 | 原因 |
|------|------|------|
| 2026-07-04 | 初始版本 | 契约建立 |
