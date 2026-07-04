# nextpas.core.regex 代码契约

> 模块路径: `core/src/nextpas.core.regex.*.pas`
> 创建日期: 2026-07-04
> 维护者: AI

---

## 概述

正则表达式引擎。提供编译、NFA/DFA 匹配、Teddy 加速和替换。

---

## 关键接口

```pascal
type
  TRegexFlags = set of (rfIgnoreCase, rfMultiline, rfDotAll, rfUnicode);
  TMatch = record ... end;
  TGroup = record ... end;
  ERegexError = class(ECore);
  ERegexCompileError = class(ERegexError);

function RegexCompile(APattern: string; AFlags: TRegexFlags = []): PRegexProgram;
function RegexMatch(AProgram: PRegexProgram; AInput: string): Boolean;
function RegexFind(AProgram: PRegexProgram; AInput: string): TMatch;
function RegexFindAll(AProgram: PRegexProgram; AInput: string): TMatchArray;
function RegexReplace(AProgram: PRegexProgram; AInput, AReplacement: string): string;
```

---

## 错误语义

| 场景 | 行为 |
|------|------|
| 非法正则语法 | raise ERegexCompileError |
| 编译失败 | raise ERegexCompileError |

---

## 线程安全

- PRegexProgram 编译后只读，可安全并发匹配
- RegexCompile 不线程安全

---

## 依赖关系

- 依赖: base, text
- 被依赖: config (pattern 验证), text (搜索替换)

---

## 变更记录

| 日期 | 变更 | 原因 |
|------|------|------|
| 2026-07-04 | 初始版本 | 契约建立 |
