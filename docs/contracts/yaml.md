# nextpas.core.yaml 代码契约

> 模块路径: `core/src/nextpas.core.yaml.*.pas`
> 创建日期: 2026-07-04
> 维护者: AI

---

## 概述

YAML 门面。提供解析、序列化、DOM 访问。

---

## 关键接口

```pascal
type
  IYamlDocument = interface
    function Root: TYamlNode;
    function HasError: Boolean;
    function Error: TYamlError;
    function Stringify: string;
  end;
  TYamlNode = record ... end;

function YamlParse(AInput: string): IYamlDocument;
function TryYamlParse(AInput: string; out ADoc: IYamlDocument): Boolean;
function YamlStringify(ADoc: IYamlDocument): string;
```

---

## 错误语义

| 场景 | 行为 |
|------|------|
| 非法 YAML | HasError=true |
| TryYamlParse 失败 | 返回 false |

---

## 线程安全

- IYamlDocument 不线程安全
- YamlParse 为纯函数，可安全并发调用

---

## 依赖关系

- 依赖: text, mem
- 被依赖: config (YAML 格式)

---

## 变更记录

| 日期 | 变更 | 原因 |
|------|------|------|
| 2026-07-04 | 初始版本 | 契约建立 |
