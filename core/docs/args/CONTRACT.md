# nextpas.core.args 代码契约

**模块路径**：`core/src/nextpas.core.args*.pas`（2 个源文件）
**层级**：L1（依赖 L0: base, text）
**Owner**：Claude（AI 负责）
**最后更新**：2026-08-30
**版本**：1.1

---

## 1. 接口契约

### 1.1 子模块

| 文件 | 职责 |
|------|------|
| args.base | TArgKind, EArgParseError, EArgHelp, EArgVersion, TArgPositionalSpec |
| args.pas | TArgParser (单命令) + TArgApp (子命令路由) |

### 1.2 两层架构

```pascal
// 层 1: 单命令解析器
TArgParser = class
  procedure AddOption(const AOption: TArgOption);
  procedure AddPositional(const ASpec: TArgPositionalSpec);
  function Parse(const AArgs: TStringArray): Boolean;
  function GetString(const AName: string): string;
  function GetInt(const AName: string): Int64;
  function GetBool(const AName: string): Boolean;
  function GetRemaining: TStringArray;
  procedure ShowHelp;
end;

// 层 2: 子命令路由器
TArgApp = class
  procedure SetName(const AName: string);
  procedure SetVersion(const AVersion: string);
  procedure AddCommand(const AName: string; AParser: TArgParser; AHandler: TProc);
  procedure Run(const AArgs: TStringArray);
end;
```

### 1.3 选项类型

```pascal
TArgKind = (akString, akInt, akBool, akCount);
TArgOption = record
  Name: string;
  Short: AnsiChar;       // 如 'v'
  Help: string;
  Kind: TArgKind;
  Required: Boolean;
  DefaultStr: string;
  DefaultInt: Int64;
end;
```

---

## 2. 不变量

- **[INV-1]** `--help` 触发 EArgHelp（调用方捕获后显示帮助）
- **[INV-2]** `--version` 触发 EArgVersion
- **[INV-3]** Required 选项缺失时 Parse 返回 False
- **[INV-4]** 子命令路由按第一个非 `--` 参数匹配

---

## 3. 错误处理

| 场景 | 异常 |
|------|------|
| `--help` / `-h` | EArgHelp |
| `--version` | EArgVersion |
| 非法参数 | EArgParseError + 描述 |
| Required 缺失 | Parse 返回 False |

---

## 4-6. 概要

- **线程安全**: TArgParser/TArgApp ❌（单次解析使用）
- **内存**: TArgParser 拥有选项列表; Run 完成后 TArgApp 释放
- **测试**: 1 个测试目录，56 tests

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-01 | 1.0 | 初始版本 | Claude |
| 2026-08-30 | 1.1 | 冻结感修复：更新最后更新至 2026-08-30 并 bump 版本 | Claude |
