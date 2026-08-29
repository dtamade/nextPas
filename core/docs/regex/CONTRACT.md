# nextpas.core.regex 代码契约

**模块路径**：`core/src/nextpas.core.regex*.pas`（8 个源文件）
**层级**：L1（依赖 L0-L1: base, text）
**Owner**：Claude（AI 负责）
**最后更新**：2026-08-30
**版本**：1.1

---

## 1. 接口契约

### 1.1 子模块

| 文件 | 职责 |
|------|------|
| regex.base | TRegexFlags, TMatch, TGroup, ERegexError, ERegexCompileError |
| regex.charclass | 字符类解析 ([a-z], \d, \w 等) |
| regex.parser | 正则表达式 → AST 解析 |
| regex.compiler | AST → Thompson NFA 编译 |
| regex.nfa | Thompson NFA 执行引擎 |
| regex.dfa | DFA 优化引擎 |
| regex.teddy | Teddy SSSE3 多模式匹配优化 |
| regex.pas | 门面 |

### 1.2 核心 API

```pascal
function RegexCompile(const APattern: string; AFlags: TRegexFlags = []): PRegexProgram;
function RegexMatch(AProg: PRegexProgram; const ASubject: string): Boolean;
function RegexFind(AProg: PRegexProgram; const ASubject: string): TMatch;
function RegexFindAll(AProg: PRegexProgram; const ASubject: string): TMatchArray;
function RegexReplace(AProg: PRegexProgram; const ASubject, AReplacement: string): string;
function RegexReplaceFunc(AProg: PRegexProgram; const ASubject: string; AFunc: TReplaceFunc): string;
procedure RegexFree(AProg: PRegexProgram);
```

### 1.3 TRegexFlags

```pascal
TRegexFlags = set of (
  rfIgnoreCase,    // (?i)
  rfMultiline,     // (?m) ^ $ 匹配行首行尾
  rfDotAll,        // (?s) . 匹配换行
  rfUnicode,       // Unicode 模式
  rfLiteral        // 字面量模式（无元字符）
);
```

### 1.4 性能

- Compile 比 Go regexp.Compile 快 5.2x
- Literal alternation 优化 2.35x
- Case-insensitive 优化 4.71x
- Teddy SSSE3 加速多字节匹配

---

## 2. 不变量

- **[INV-1]** PRegexProgram 由 Compile 创建，必须由 RegexFree 释放
- **[INV-2]** Thompson NFA 保证线性时间匹配（无回溯）
- **[INV-3]** Match 返回 TMatch 表示匹配位置，无匹配时 Match.Success = False
- **[INV-4]** FindAll 返回所有非重叠匹配

---

## 3. 错误处理

| 场景 | 异常 |
|------|------|
| 非法正则语法 | ERegexCompileError |
| 编译失败 | ERegexCompileError + 位置信息 |

---

## 4-6. 概要

- **线程安全**: PRegexProgram ✅（编译后只读）; Compile ✅; Match/Find ✅
- **内存**: PRegexProgram 堆分配，必须 RegexFree; Match 结果包含 string 拷贝
- **测试**: 1 个测试目录，22 tests

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-01 | 1.0 | 初始版本 | Claude |
| 2026-08-30 | 1.1 | 冻结感修复：更新最后更新至 2026-08-30 并 bump 版本 | Claude |
