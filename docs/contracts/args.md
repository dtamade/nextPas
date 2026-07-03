# nextpas.core.args 代码契约

> 模块路径: `core/src/nextpas.core.args.*.pas`
> 创建日期: 2026-07-04
> 维护者: AI

---

## 概述

生产级 CLI 参数解析器，双层架构：TArgParser（单命令）+ TArgApp（子命令路由）。
支持长/短选项、位置参数、类型验证、choices 约束和自动 help/version。

---

## 关键接口

```pascal
type
  TArgKind = (akString, akInt, akBool, akStringList);
  EArgParseError = class(ECore);
  EArgHelp = class(ECore);      { --help 触发 }
  EArgVersion = class(ECore);   { --version 触发 }

  TArgOption = record
    Name: string;
    Short: AnsiChar;
    Help: string;
    Kind: TArgKind;
    Required: Boolean;
    DefaultStr: string;
    DefaultInt: Int64;
    Choices: TStringArray;
    ValueStr: string;
    ValueInt: Int64;
    ValueBool: Boolean;
    ValueList: TStringArray;
    Present: Boolean;
  end;

  TArgParser = class
    function AddOption(AName: string; AShort: AnsiChar = #0;
      AKind: TArgKind = akString; ARequired: Boolean = False;
      ADefault: string = ''; AHelp: string = ''): TArgParser;
    function AddPositional(AName: string; ARequired: Boolean = True): TArgParser;
    procedure Parse(AArgs: array of string);
    function GetString(AName: string): string;
    function GetInt(AName: string): Int64;
    function GetBool(AName: string): Boolean;
    function IsPresent(AName: string): Boolean;
  end;
```

---

## 错误语义

| 场景 | 行为 |
|------|------|
| 缺少必需选项 | raise EArgParseError |
| 值不在 Choices 中 | raise EArgParseError |
| --help | raise EArgHelp（由调用方捕获） |
| --version | raise EArgVersion |

---

## 线程安全

- TArgParser 不线程安全（配置+解析生命周期）

---

## 依赖关系

- 依赖: base, text.number
- 被依赖: CLI 工具入口

---

## 变更记录

| 日期 | 变更 | 原因 |
|------|------|------|
| 2026-07-04 | 初始版本 | 契约建立 |
