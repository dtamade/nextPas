# nextpas.core.test — 测试框架实施方案

## 目标

为 nextPas 框架提供一个先进的单元测试框架 `nextpas.core.test`，双套 API（过程式 Check* + 链式 IExpectation），支持完整并行执行。

## 模块定位

- **层级**: L1（只依赖 L0 + 同层 L1）
- **路径**: `core/src/nextpas.core.test.pas`
- **与 testing 关系**: 全新模块，不替换现有 `nextpas.core.testing`

## 依赖

| 依赖 | 层级 | 用途 |
|------|------|------|
| `nextpas.core.errors` | L0 | EAssertionFailed 异常 |
| `nextpas.core.atomic` | L0 | TAtomicInt32 无锁计数器 |
| `nextpas.core.text.conv` | L1 | IntToStr, BoolToStr |
| `nextpas.core.sync` | L1 | IMutex 线程安全结果收集 |
| `nextpas.core.thread` | L1 | IThreadPool 并行执行 |
| `SysUtils` | 临时 | Now, Format 等（自举阶段） |

## 文件结构

```
core/src/nextpas.core.test.pas                    ← 框架主体（单文件，~1200 行）
core/tests/nextpas.core.test/
  test_assertions/test_assertions.lpr + Makefile   ← 断言 API 测试
  test_runner/test_runner.lpr + Makefile           ← Runner 功能测试
  test_parallel/test_parallel.lpr + Makefile       ← 并行执行测试
  test_expect/test_expect.lpr + Makefile           ← IExpectation 链式 API 测试
  test_subtests/test_subtests.lpr + Makefile       ← 子测试测试
core/docs/test/README.md                           ← 模块文档
```

## API 设计

### 1. 核心类型

```pascal
TTestProc       = procedure;
TTestContextProc = procedure(const Ctx: ITestContext);
TSetupProc      = procedure;
TTeardownProc   = procedure;
TTestHook       = reference to procedure;
```

### 2. Suite 记录 (TTestSuite)

```pascal
var S: TTestSuite;
S := TTestSuite.Create('MyModule');
S.SetSetup(procedure begin ... end);
S.SetTeardown(procedure begin ... end);
S.OnBeforeEach(procedure begin ... end);
S.OnAfterEach(procedure begin ... end);
S.Test('name', @Proc);                    // 过程式
S.Test('name', procedure(const C: ITestContext) begin ... end);  // 链式
S.Run;                                    // 串行执行
S.RunParallel(0);                         // 并行执行（0=自动检测 CPU 数）
S.Summary;                                // 打印汇总
```

### 3. Check* 过程式 API

```pascal
Check(ACondition);
CheckEqual(Expected, Actual);             // string/Int64/Boolean/Pointer 重载
CheckNotEqual(Expected, Actual);
CheckTrue/CheckFalse(ACondition);
CheckNil/CheckNotNil(APtr);
CheckContains(Haystack, Needle);
CheckStartsWith(Prefix, Str);
CheckEndsWith(Suffix, Str);
CheckSame(AExpected, AActual);            // 指针/引用同一性
CheckInRange(AValue, AMin, AMax);
CheckLength(AExpected, AActual);
CheckRaises(AExcClass, AProc);
CheckNoRaise(AProc);
Fail(AMessage);
Skip(AMessage);
```

### 4. IExpectation 链式 API

```pascal
Expect(42).ToEqual(42);
Expect('hello').ToContain('ell');
Expect(True).ToBeTrue;
Expect(Ptr).ToBeNil;
Expect(42).Not.ToEqual(0);
Expect(10).ToBeInRange(1, 100);
Expect(procedure begin end).Not.ToRaise;
```

**实现方式**: COM 接口 `IExpectation`，引用计数自动管理。`Not` 修改内部状态并返回 Self。

```pascal
IExpectation = interface
  function Not_: IExpectation;  // 避免 FPC 关键字冲突
  function ToEqual(const AExpected: string): IExpectation; overload;
  function ToEqual(const AExpected: Int64): IExpectation; overload;
  function ToEqual(const AExpected: Boolean): IExpectation; overload;
  function ToBeTrue: IExpectation;
  function ToBeFalse: IExpectation;
  function ToBeNil: IExpectation;
  function ToBeNotNil: IExpectation;
  function ToContain(const ANeedle: string): IExpectation;
  function ToStartWith(const APrefix: string): IExpectation;
  function ToEndWith(const ASuffix: string): IExpectation;
  function ToBeGreaterThan(const AValue: Int64): IExpectation;
  function ToBeLessThan(const AValue: Int64): IExpectation;
  function ToBeInRange(const AMin, AMax: Int64): IExpectation;
  function ToHaveLength(const AExpected: Integer): IExpectation;
  function ToRaise(AExcClass: ExceptClass): IExpectation;
end;

function Expect(const AValue: string): IExpectation; overload;
function Expect(const AValue: Int64): IExpectation; overload;
function Expect(const AValue: Boolean): IExpectation; overload;
function Expect(APtr: Pointer): IExpectation; overload;
function Expect(AProc: TTestProc): IExpectation; overload;
```

### 5. 子测试（Go 风格 t.Run）

```pascal
S.Test('Math', procedure(const Ctx: ITestContext) begin
  Ctx.Run('Addition', procedure begin CheckEqual(3, 1+2) end);
  Ctx.Run('Multiply', procedure begin CheckEqual(6, 2*3) end);
end);
// 输出: Math/Addition PASS, Math/Multiply PASS
```

### 6. 并行执行

```pascal
S.RunParallel(0);  // 0 = CPU 核心数
```

- 使用 `IThreadPool` 执行测试
- `TAtomicInt32` 无锁计数器统计 pass/fail/skip
- `IMutex` 保护测试结果收集和输出
- 每个测试独立运行，互不干扰
- Setup/Teardown 在各自线程中安全执行

### 7. Runner

```pascal
var R: TTestRunner;
R := TTestRunner.Create;
R.Add(S1);
R.Add(S2);
R.RunAll;         // 串行运行所有 Suite
R.RunAllParallel(4);  // 并行运行
R.Summary;
R.AllPassed: Boolean;
```

### 8. 过滤

```pascal
S.Run('--filter=TestAdd');           // 精确匹配或子串匹配
R.RunAll('--filter=MyModule');       // 过滤 Suite
// 支持命令行参数自动读取
```

### 9. 输出格式

```
=== MyModule === (8 tests, 2 threads)
  PASS  TestAddition        (0.02ms)
  PASS  TestMultiply        (0.01ms)
  FAIL  TestDivision        (0.05ms)
         expected 3, got 2
         at test_math.lpr:42
  SKIP  TestFloat (pending)

--- Summary ---
  Total:  8
  Passed: 6
  Failed: 1
  Skipped: 1
  Time:   12.34ms
```

- ANSI 彩色输出（PASS=绿色, FAIL=红色, SKIP=黄色）
- 自动检测终端，非终端禁用颜色
- 失败时显示位置信息

### 10. 内存泄漏检测

```pascal
S.Test('no leak', @MyTest);
// 自动检测 HeapTrace，测试后报告泄漏
```

## 实施阶段

### Phase 1: 基础骨架（~400 行）
- [ ] ETestFailure, ETestSkipped 异常类
- [ ] TTestEntry, TSuiteEntry 记录
- [ ] TTestSuite 核心（Create, Test, SetSetup/Teardown, Run, Summary）
- [ ] 基础 ANSI 颜色输出
- [ ] 基础过滤

### Phase 2: Check* API（~200 行）
- [ ] Check, CheckEqual (4 重载), CheckNotEqual
- [ ] CheckTrue, CheckFalse, CheckNil, CheckNotNil
- [ ] CheckContains, CheckStartsWith, CheckEndsWith
- [ ] CheckSame, CheckInRange, CheckLength
- [ ] CheckRaises, CheckNoRaise
- [ ] Fail, Skip

### Phase 3: IExpectation API（~300 行）
- [ ] TExpectation 类 + IExpectation 接口
- [ ] Expect 5 重载（string, Int64, Boolean, Pointer, TTestProc）
- [ ] Not_ 切换
- [ ] 所有 To* 方法实现
- [ ] 自定义失败消息支持

### Phase 4: 并行 + Runner（~200 行）
- [ ] TTestRunner 记录
- [ ] RunParallel（IThreadPool + TAtomicInt32 + IMutex）
- [ ] 命令行过滤参数解析
- [ ] 子测试 (Ctx.Run) 支持
- [ ] HeapTrace 泄漏检测

### Phase 5: 测试 + 文档（~800 行测试代码）
- [ ] test_assertions — Check* API 全覆盖
- [ ] test_expect — IExpectation API 全覆盖
- [ ] test_runner — Runner 功能测试
- [ ] test_parallel — 并行正确性测试
- [ ] test_subtests — 子测试功能测试
- [ ] docs/test/README.md 文档

## 验收标准

1. 所有 5 个测试项目 100% 通过
2. 0 内存泄漏（HeapTrace 验证）
3. 并行测试结果与串行一致
4. ANSI 输出在终端/非终端都正确
5. `make focused FOCUS=core/tests/nextpas.core.test/*` 全绿
