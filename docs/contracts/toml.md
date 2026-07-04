# nextpas.core.toml 代码契约

> 模块路径: `core/src/nextpas.core.toml.*.pas`
> 创建日期: 2026-07-04
> 维护者: AI

---

## 概述

TOML 门面。提供解析、序列化、DOM 访问和构建器。支持 TOML 1.0 规范。

---

## 关键接口

```pascal
type
  TTomlNodeKind = (tnkString, tnkInt, tnkFloat, tnkBool, tnkDateTime,
    tnkArray, tnkTable, tnkInlineTable);
  TTomlValue = record ... end;
  ITomlDocument = interface
    function Root: TTomlValue;
    function HasError: Boolean;
    function Error: TTomlError;
    function Stringify: string;
    function StringifyPretty(AIndent: Int32): string;
  end;
  ITomlBuilder = interface ... end;

function TomlParse(AInput: string): ITomlDocument;
function TryTomlParse(AInput: string; out ADoc: ITomlDocument): Boolean;
function TomlParseWith(AInput: string; AAllocator: TMemAllocator): ITomlDocument;
function TomlBuilder: ITomlBuilder;
function TomlDateTime(AYear, AMonth, ADay, AHour, AMinute, ASecond: Byte;
  ANanosecond: UInt32): TTomlDateTime;
```

---

## 错误语义

| 场景 | 行为 |
|------|------|
| 非法 TOML | HasError=true, Error 描述位置 |
| TryTomlParse 失败 | 返回 false |

---

## 线程安全

- ITomlDocument 不线程安全
- TomlParse 为纯函数，可安全并发调用

---

## 依赖关系

- 依赖: text, mem
- 被依赖: config (TOML 格式)

---

## 变更记录

| 日期 | 变更 | 原因 |
|------|------|------|
| 2026-07-04 | 初始版本 | 契约建立 |
