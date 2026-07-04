# nextpas.core.xml 代码契约

> 模块路径: `core/src/nextpas.core.xml.*.pas`
> 创建日期: 2026-07-04
> 维护者: AI

---

## 概述

XML 模块 Facade。统一导出 reader/writer/dom 所有公共类型和函数。
提供 IXmlDocument 接口以匹配 JSON/TOML/YAML 的 I*Document 一致性。

---

## 关键接口

```pascal
type
  IXmlDocument = interface
    function Root: TXmlNode;
    function HasError: Boolean;
    function Error: TXmlError;
    function Stringify: string;
  end;
  TXmlNode = record ... end;

function XmlParse(AInput: string): IXmlDocument;
function TryXmlParse(AInput: string; out ADoc: IXmlDocument): Boolean;
function XmlStringify(ADoc: IXmlDocument): string;
```

---

## 错误语义

| 场景 | 行为 |
|------|------|
| 非法 XML | HasError=true |
| TryXmlParse 失败 | 返回 false |

---

## 线程安全

- IXmlDocument 不线程安全
- XmlParse 为纯函数，可安全并发调用

---

## 依赖关系

- 依赖: text, mem
- 被依赖: 配置解析, 数据交换

---

## 变更记录

| 日期 | 变更 | 原因 |
|------|------|------|
| 2026-07-04 | 初始版本 | 契约建立 |
