# Regex Phase 4: API 完善 + Benchmark 对照

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 补全 TRegex 高层 API 缺口（Iterator、SubexpNames、Longest），加强测试覆盖至 150+ cases，并完成 FPC/Go/Rust 三方基准对照报告。

**Architecture:** 在现有 TRegex record 上扩展 3 个新方法 + 1 个新类型（TRegexIter），不改动底层 NFA/DFA 引擎。Benchmark 复用现有 bench_regex 框架，补充 Replace/Split/FindAll 场景。

**Tech Stack:** FPC ObjFPC, nextpas.core.bench, Go regexp, Rust regex crate

---

## Phase A: API 补全（3 tasks）

### Task 1: TRegexIter — 零分配迭代器

**动机：** `FindAll` 一次性分配整个 TMatchArray，对于大文本（日志解析）内存压力大。Iterator 模式逐个返回 match，恒定内存。

**Files:**
- Modify: `src/nextpas.core.regex.pas` (添加 TRegexIter + FindIter 方法)
- Modify: `src/nextpas.core.regex.base.pas` (添加 TRegexIter 类型)
- Test: `tests/nextpas.core.regex/test_regex_basic/test_regex_basic.lpr`

**Step 1: 在 base.pas 添加 TRegexIter 类型**

```pascal
TRegexIter = record
private
  FProgram: PRegexProgram;
  FInput: string;
  FPos: SizeUInt;
  FDone: Boolean;
public
  function Next(out AMatch: TMatch): Boolean;
end;
```

**Step 2: 在 regex.pas 添加 FindIter 方法**

```pascal
// TRegex 中添加：
function FindIter(const AInput: string): TRegexIter;

// 实现：
function TRegex.FindIter(const AInput: string): TRegexIter;
begin
  Result.FProgram := @FProgram;
  Result.FInput := AInput;
  Result.FPos := 0;
  Result.FDone := False;
end;

function TRegexIter.Next(out AMatch: TMatch): Boolean;
begin
  if FDone then Exit(False);
  AMatch := NfaFindAt(FProgram^, FInput, Length(FInput), FPos);
  if not AMatch.Found then
  begin
    FDone := True;
    Exit(False);
  end;
  // Advance past match (avoid infinite loop on zero-length match)
  if AMatch.Len = 0 then
    FPos := AMatch.Start + 1
  else
    FPos := AMatch.Start + AMatch.Len;
  if FPos > SizeUInt(Length(FInput)) then
    FDone := True;
  Result := True;
end;
```

**Step 3: 写测试**

```pascal
procedure TestFindIter;
var
  R: TRegex;
  LIter: TRegexIter;
  LMatch: TMatch;
  LCount: Int32;
begin
  R := TRegex.Compile('\d+');
  LIter := R.FindIter('abc 123 def 456 ghi 789');
  LCount := 0;
  while LIter.Next(LMatch) do
  begin
    Inc(LCount);
    case LCount of
      1: Check(LMatch.Value('abc 123 def 456 ghi 789') = '123', 'iter 1');
      2: Check(LMatch.Value('abc 123 def 456 ghi 789') = '456', 'iter 2');
      3: Check(LMatch.Value('abc 123 def 456 ghi 789') = '789', 'iter 3');
    end;
  end;
  CheckEqual(Int64(3), Int64(LCount), 'iter count');
end;
```

**Step 4: 编译运行测试**

```bash
make -C tests/nextpas.core.regex/test_regex_basic clean test
```

**Step 5: Commit**

```bash
git add src/nextpas.core.regex.base.pas src/nextpas.core.regex.pas tests/nextpas.core.regex/test_regex_basic/test_regex_basic.lpr
git commit -m "feat(regex): TRegexIter — zero-alloc match iterator"
```

---

### Task 2: SubexpNames + CaptureNames

**动机：** 用户需要知道正则中有哪些命名组，用于动态模板展开。

**Files:**
- Modify: `src/nextpas.core.regex.pas`
- Test: `tests/nextpas.core.regex/test_regex_basic/test_regex_basic.lpr`

**Step 1: 添加 SubexpNames 方法**

```pascal
// TRegex 中添加：
function SubexpNames: TStringArray;

// 实现：
function TRegex.SubexpNames: TStringArray;
var
  LI: SizeInt;
begin
  SetLength(Result, Length(FProgram.GroupNames));
  for LI := 0 to High(FProgram.GroupNames) do
    Result[LI] := FProgram.GroupNames[LI].Name;
end;
```

**Step 2: 写测试**

```pascal
procedure TestSubexpNames;
var
  R: TRegex;
  LNames: TStringArray;
begin
  R := TRegex.Compile('(?P<year>\d{4})-(?P<month>\d{2})-(?P<day>\d{2})');
  LNames := R.SubexpNames;
  CheckEqual(Int64(3), Int64(Length(LNames)), 'name count');
  Check(LNames[0] = 'year', 'name 0');
  Check(LNames[1] = 'month', 'name 1');
  Check(LNames[2] = 'day', 'name 2');
end;
```

**Step 3: 编译运行测试**

**Step 4: Commit**

```bash
git commit -m "feat(regex): SubexpNames — list all named capture groups"
```

---

### Task 3: Longest 模式（贪婪最长匹配）

**动机：** 默认 leftmost-first 语义，某些场景需要 leftmost-longest（如 tokenizer）。

**Files:**
- Modify: `src/nextpas.core.regex.base.pas` (添加 rfLongest flag)
- Modify: `src/nextpas.core.regex.nfa.pas` (NFA 匹配时不 early-exit)
- Modify: `src/nextpas.core.regex.pas`
- Test: `tests/nextpas.core.regex/test_regex_basic/test_regex_basic.lpr`

**Step 1: 添加 rfLongest flag**

```pascal
TRegexFlags = set of (
  rfCaseInsensitive,
  rfMultiLine,
  rfDotAll,
  rfLongest    // ← 新增
);
```

**Step 2: 在 NFA 匹配中支持 longest**

在 `NfaIsMatch` / `NfaFind` 中，当 `rfLongest in Flags` 时，找到第一个 match 后继续搜索更长的 match，直到无法扩展。

**Step 3: 添加 TRegex.Longest 方法**

```pascal
function Longest: TRegex;
// 返回一个设置了 rfLongest 的副本
```

**Step 4: 写测试**

```pascal
procedure TestLongest;
var R: TRegex; M: TMatch;
begin
  R := TRegex.Compile('a|ab|abc');
  M := R.Find('abc');
  Check(M.Value('abc') = 'a', 'default leftmost-first');

  R := TRegex.Compile('a|ab|abc', [rfLongest]);
  M := R.Find('abc');
  Check(M.Value('abc') = 'abc', 'longest match');
end;
```

**Step 5: Commit**

```bash
git commit -m "feat(regex): rfLongest flag — leftmost-longest matching"
```

---

## Phase B: 测试覆盖加强（1 task）

### Task 4: 扩展测试至 150+ cases

**目标：** 覆盖所有 API 的边界条件、Unicode、大输入、错误路径。

**Files:**
- Modify: `tests/nextpas.core.regex/test_regex_basic/test_regex_basic.lpr`

**新增测试场景：**

1. **Iterator 边界：** 空输入、零长度匹配（`a*`）、overlapping
2. **Replace 边界：** 空替换、$0 引用、不存在的组引用
3. **Split 边界：** 分隔符在开头/结尾、连续分隔符、limit=0/1
4. **Unicode：** 中文匹配、emoji、多字节边界
5. **大输入：** 1MB 文本中 FindAll
6. **错误路径：** 无效 pattern、嵌套过深、量词溢出
7. **Longest 模式：** 各种 alternation 场景
8. **性能回归：** 确认无 catastrophic backtracking

**Step 1: 写 40+ 新测试**

**Step 2: 运行确认全绿**

**Step 3: Commit**

```bash
git commit -m "test(regex): expand coverage to 150+ cases — iterator, unicode, edge cases"
```

---

## Phase C: Benchmark 对照（2 tasks）

### Task 5: 补全 nextpas benchmark 场景

**Files:**
- Modify: `benchmarks/nextpas.core.regex/bench_regex/bench_regex.lpr`

**新增场景：**
- `BenchReplaceAll` — 全局替换
- `BenchSplit` — 分割
- `BenchFindAll` — 全部匹配
- `BenchFindIter` — 迭代器（对比 FindAll）
- `BenchCaseInsensitive` — 大小写不敏感
- `BenchLargeInput` — 100KB 输入

**Step 1: 添加新 benchmark procedures**

**Step 2: 运行并记录结果**

```bash
make -C benchmarks/nextpas.core.regex/bench_regex run
```

**Step 3: Commit**

---

### Task 6: Go/Rust 对照 + 报告

**Files:**
- Modify: `benchmarks/nextpas.core.regex/bench_regex/compare_go/main.go`
- Modify: `benchmarks/nextpas.core.regex/bench_regex/compare_rust/src/main.rs`
- Create: `benchmarks/nextpas.core.regex/bench_regex/RESULTS.md`

**Step 1: 在 Go/Rust 中添加对应的新场景**

**Step 2: 运行三方 benchmark**

```bash
cd benchmarks/nextpas.core.regex/bench_regex
make run                          # nextpas
cd compare_go && go run main.go   # Go
cd compare_rust && cargo run --release  # Rust
```

**Step 3: 生成对照报告 RESULTS.md**

```markdown
# Regex Benchmark Results (2026-05-31)

| Scenario | nextpas (ns/op) | Go (ns/op) | Rust (ns/op) | vs Go | vs Rust |
|----------|----------------|------------|--------------|-------|---------|
| Literal IsMatch | ... | ... | ... | ...x | ...x |
| Digit Find | ... | ... | ... | ...x | ...x |
| ...
```

**Step 4: Commit**

```bash
git commit -m "bench(regex): complete Go/Rust comparison — RESULTS.md"
```

---

## 验收标准

1. ✅ TRegexIter 零分配迭代，测试通过
2. ✅ SubexpNames 返回所有命名组
3. ✅ rfLongest 支持最长匹配
4. ✅ 测试覆盖 ≥ 150 cases，0 泄漏
5. ✅ Benchmark 包含 10+ 场景
6. ✅ Go/Rust 对照报告生成
7. ✅ 所有 API 100% 测试覆盖

## 执行顺序

```
Task 1 (Iterator) → Task 2 (SubexpNames) → Task 3 (Longest)
    → Task 4 (测试加强) → Task 5 (Benchmark) → Task 6 (对照报告)
```

预计工作量：每个 Task 15-30 分钟，总计 2-3 小时。
