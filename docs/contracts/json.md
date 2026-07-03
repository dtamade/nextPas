# nextpas.core.json 代码契约

> 模块路径: `core/src/nextpas.core.json.*.pas`
> 创建日期: 2026-07-04
> 维护者: AI

---

## 概述

JSON 门面。提供解析、序列化、DOM 访问和自定义分配器支持。

---

## 关键接口

```pascal
type
  TJsonNodeKind = (jkObject, jkArray, jkString, jkNumber, jkBool, jkNull);
  TJsonValue = record ... end;
  IJsonDocument = interface
    function Root: TJsonValue;
    function HasError: Boolean;
    function Error: TJsonError;
    function Stringify: string;
    function StringifyPretty(AIndent: Int32 = 2): string;
  end;

function JsonParse(AInput: string): IJsonDocument;
function TryJsonParse(AInput: string; out ADoc: IJsonDocument): Boolean;
function JsonParseWith(AInput: string; AAllocator: TMemAllocator): IJsonDocument;
function JsonStringify(AValue: TJsonValue): string;
```

---

## 错误语义

| 场景 | 行为 |
|------|------|
| 非法 JSON | `HasError=true`，`Error` 描述位置 |
| TryJsonParse 失败 | 返回 false，ADoc 为 nil |

---

## 线程安全

- IJsonDocument 不线程安全
- JsonParse/JsonStringify 为纯函数，可安全并发调用

---

## 内存管理

- IJsonDocument 拥有所有节点生命周期
- JsonParseWith 使用自定义分配器（Arena/Pool）

---

## 依赖关系

- 依赖: base, text, mem
- 被依赖: http, config, tls

---

## 变更记录

| 日期 | 变更 | 原因 |
|------|------|------|
| 2026-07-04 | 初始版本 | 契约建立 |
