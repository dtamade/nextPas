# nextpas.core.validation 代码契约

> 模块路径: `core/src/nextpas.core.validation.pas`
> 创建日期: 2026-07-04
> 维护者: AI

---

## 概述

数据验证模块。fluent builder API，收集所有错误而非首个即停。
零 SysUtils 依赖。

---

## 关键接口

```pascal
type
  TValidationError = record
    Field: string;
    Message: string;
  end;
  TValidationErrors = array of TValidationError;

  TValidator = record
    class function Create(AField: string): TValidator; static;
    function Required(AValue: string): TValidator;
    function MinLen(AValue: string; AMin: Integer): TValidator;
    function MaxLen(AValue: string; AMax: Integer): TValidator;
    function MinInt(AValue: Int64; AMin: Int64): TValidator;
    function MaxInt(AValue: Int64; AMax: Int64): TValidator;
    function Pattern(AValue: string; APattern: string): TValidator;
    function Custom(ACondition: Boolean; AMessage: string): TValidator;
    function Errors: TValidationErrors;
    function IsValid: Boolean;
  end;
```

---

## 后置条件

1. `IsValid`: 所有验证通过时返回 true
2. `Errors`: 返回收集的全部错误

---

## 线程安全

- TValidator 为值类型 record，天然线程安全

---

## 依赖关系

- 依赖: 无（零外部依赖）
- 被依赖: http (请求验证), config

---

## 变更记录

| 日期 | 变更 | 原因 |
|------|------|------|
| 2026-07-04 | 初始版本 | 契约建立 |
