# nextpas.core.test — Round 3 全面审查 Findings

> 审查日期: 2026-06-21 (Round 3)
> 审查范围: 12 源文件 (3744行) + 8 测试程序 (3733行) + README.md + design-conventions.md
> 前置状态: Round 1 (33 findings 全处置) + Round 2 (26 findings 全处置)
> 本轮发现: 50 个 findings (2 Critical, 11 Medium, 22+ Low, 15 info/design)

## 统计

| 级别 | 代码 | 测试 | 文档/API | 合计 |
|------|------|------|----------|------|
| Critical | 2 | 0 | 0 | **2** |
| Medium | 9 | 0 | 2 | **11** |
| Low | 12 | 3 | 7 | **22** |
| Info/Design | 3 | 0 | 12 | **15** |
| **合计** | **26** | **3** | **21** | **50** |

---

## Critical (must-fix)

### C-01 — TimeoutWorker 访问栈局部变量 (use-after-free)

- **位置**: `nextpas.core.test.runner.parallel.pas` L60-148
- **问题**: `RunTestWithTimeout` 声明 `LRec: TTimeoutRec` 为栈局部变量，将 `@LRec` 传给 `TimeoutWorker` 线程。超时后函数返回，栈帧销毁，但 worker 线程仍在运行并写入 `LRec.Done` / `LRec.ErrorMsg`。
- **影响**: **Use-after-free** — worker 线程写入已销毁的栈内存，导致未定义行为。在优化编译下可能导致崩溃或数据损坏。
- **复现路径**: 任何超时测试用例 — worker 仍在运行时 caller 栈帧已弹出。
- **建议修复**: 将 `LRec` 改为堆分配 (`New/Dispose`)，超时路径在 worker 完成后 dispose；或使用 threadvar；或引入 join-with-timeout 机制。
- **优先级**: **立即修** — 这是内存安全问题。

---

### C-02 — ParallelWorkerProc R^.Res^ 写入在 mutex 外部 (data race)

- **位置**: `nextpas.core.test.runner.parallel.pas` L303-314
- **问题**: mutex 在 L299 已释放 (`R^.Mtx.Release`)，但 L303-314 在 mutex 外部写入 `R^.Res^` (`Name`, `Status`, `Message`)。
- **影响**: 若多个 worker 同时写入各自的 `Res^`，且 `Res` 指向的内存区域由同一数组分配，写入相邻元素可能在 ARM 等弱内存模型平台上产生 data race。在 x86_64 上通常无问题（store 顺序保证），但不符合 C++11 内存模型语义。
- **对比**: `Pass^`/`Fail^`/`Skip^` 的写入在 mutex 内部 (L265-298)，是正确的。
- **建议修复**: 将 `R^.Res^` 写入移入 mutex 保护区域，或确认 `Res` 各自指向独立分配的内存并添加注释+编译器屏障。
- **优先级**: **立即修** — 并行正确性问题。

---

## Medium (should-fix)

### M-01 — PMethodStub 堆内存泄漏 (discovery)

- **位置**: `nextpas.core.test.discovery.pas` L137
- **代码**: `New(LPStub)` 分配但 suite 运行结束后无 `Dispose(LPStub)`。
- **影响**: 每个 discovered published method 泄漏一个 `TMethodStub` (16 bytes)。在 `test_advanced` 的 discovery 测试中报告 4 leaks。
- **建议修复**: 在 `MakeMethodClosure` 中捕获的 closure 结束时 Dispose，或在 suite teardown 中遍历并释放所有 stubs。
- **测试验证**: `test_advanced` 的 discovery 测试已报告 4 个 PMethodStub 泄漏。

---

### M-02 — 超时后 worker 线程泄漏 (thread leak)

- **位置**: `nextpas.core.test.runner.parallel.pas` L141-147
- **代码**: 注释明确说明 "worker thread is leaked — cannot force-terminate Pascal threads"。
- **影响**: 每个超时测试泄漏一个 OS 线程。线程持有对已销毁栈变量的指针 (C-01)，可能在后续导致 crash。
- **建议修复**: 与 C-01 一并修复 — 堆分配 LRec + 引入 graceful shutdown 标志。

---

### M-03 — TestTable PTestCase/PTestCaseProc 堆内存泄漏

- **位置**: `nextpas.core.test.runner.pas` L215-217
- **代码**: `New(LPCase)` + `New(LPProc)` 分配，但从未 `Dispose`。
- **影响**: 每个 table test case 泄漏 `SizeOf(TTestCase) + SizeOf(TTestCaseProc)` bytes。
- **建议修复**: 在 suite teardown 或 runner cleanup 中释放，或改用内联存储避免堆分配。

---

### M-04 — ReportLeakIfAny 使用绝对值而非增量检测

- **位置**: `nextpas.core.test.output.pas` (ReportLeakIfAny)
- **代码**: `GetFPCHeapStatus.CurrHeapUsed > 0` — 绝对值检查。
- **影响**: 框架自身在测试期间的分配（如测试名称字符串）可能导致误报。如果测试前 heap 就非零（正常情况），每个测试都会报告泄漏。
- **建议修复**: 在 `SetTestContext` 中记录 `BeforeHeapUsed`，`ReportLeakIfAny` 中检查差值 `CurrHeapUsed - BeforeHeapUsed > 0`。
- **当前状态**: 实际上因为 FPC heap 在测试开始前通常为 0，误报率不高，但逻辑上不严谨。

---

### M-05 — Filter 排除的测试被计为 skipped

- **位置**: `nextpas.core.test.runner.pas` (RunWithResult filter path)
- **问题**: 被 `TEST_FILTER` 排除的测试计入 `LastSkip`，导致 skip 计数膨胀。
- **影响**: 用户无法区分"有意跳过"和"被过滤排除"。
- **建议修复**: 新增 `TTestStatus.tsFiltered` 或在 filter 排除时不计入 skip。

---

### M-06 — GTestFilter / GAnsiEnabled 普通全局变量 (非 threadvar)

- **位置**: `nextpas.core.test.output.pas` L77, L148
- **代码**: `GAnsiEnabled: Boolean = False;` 和 `GTestFilter: string = '';` — 普通 `var`。
- **影响**: 并行测试模式下，若多个 suite 在不同线程同时设置 filter/ansi，存在 data race。
- **当前状态**: 实际使用中 filter/ansi 通常在 initialization 段设置，race 窗口极小。但语义上应为 `threadvar` 或加 mutex。
- **建议修复**: 改为 `threadvar`（但 threadvar 不支持初始化值），或在 initialization 段一次性设置后不再修改（添加注释声明不可变）。

---

### M-07 — Discovery fixture double-free 风险

- **位置**: `nextpas.core.test.discovery.pas` L145-148
- **代码**: `Result.SetTeardown(procedure begin AFixture.Free; end);`
- **影响**: 若调用方在 `DiscoverTests` 返回后再次 `AFixture.Free`（例如在原始作用域的 finally 块中），会 double-free。
- **建议修复**: 文档明确说明 fixture 所有权转移给 suite；或 `DiscoverTests` 内部 `AFixture := nil` 防止外部再 free（需 var 参数）。

---

### M-08 — Mock header 注释过度承诺

- **位置**: `nextpas.core.test.mock.pas` L2-8
- **代码**: "Mock any interface, record calls, configure return values, verify expectations" + `TMock.Create<IFoo>` 泛型语法。
- **实际**: TMock 是手动字符串调用记录器，无接口代理生成、无泛型 `Create<T>` 语法、无方法签名检查。
- **影响**: 用户按文档使用会发现功能不符。
- **建议修复**: 修正 header 注释，明确标注"手动 mock helper"而非"interface proxy"。

---

### M-09 — Discovery stub use-after-free 风险

- **位置**: `nextpas.core.test.discovery.pas` L137-141 + L145-148
- **问题**: `LPStub^.Instance := AFixture` 引用 fixture 对象。Suite teardown 调用 `AFixture.Free` 后，LPStub 持有悬挂指针。若 closure 被延迟调用（如 parallel queue），会 use-after-free。
- **当前状态**: 在串行模式下，teardown 在所有测试完成后运行，closure 不会再被调用。但在 parallel 模式下，若有 worker 尚未执行完毕就触发 teardown，存在风险。
- **建议修复**: 在 teardown 中将 `LPStub^.Instance := nil`，closure 中检查 `Instance <> nil` 再调用。

---

### M-10 — Retry 不支持 Subtest

- **位置**: `nextpas.core.test.runner.pas` — 无 `TestSubtest(..., ARetryCount)` 重载
- **问题**: 子测试无法设置重试次数。
- **影响**: 功能缺失，子测试中的 flaky 测试无法自动重试。
- **建议修复**: 添加 `TestSubtest` retry 重载，或在子测试级别支持 retry。

---

### M-11 — RunParallelWithResult 无测试覆盖

- **位置**: `nextpas.core.test.runner.pas` L74-75 (接口声明)
- **问题**: Round 2 添加了 `RunParallelWithResult` 接口，但 `test_parallel.lpr` 中无对应测试。
- **影响**: 接口存在但行为未验证。
- **建议修复**: 添加 `TestParallelWithResult` 测试用例。

---

## Low (nice-to-have)

### L-01 — TTestFixure 类名拼写错误

- **位置**: `nextpas.core.test.discovery.pas` L32, L35
- **代码**: `TTestFixure` (缺少 'x') — 应为 `TTestFixture`。
- **影响**: API 不符合英语拼写。已作为公共接口暴露。
- **建议**: 重命名为 `TTestFixture` + `TTestFixtureClass`。Breaking change，需同步更新 facade 和所有使用者。

---

### L-02 — JsonEscape 缺少控制字符转义

- **位置**: `nextpas.core.test.output.json.pas`
- **代码**: 只转义 `"` `\` `#10` `#13` `#9`，缺少 `#8`(backspace) `#12`(form-feed) `#0`(null) 及其他 U+0000-U+001F 控制字符。
- **影响**: 极端情况下 JSON 输出可能无效。
- **建议**: 补充 `\b` `\f` `\u00XX` 兜底转义。

---

### L-03 — TAP 输出无转义处理

- **位置**: `nextpas.core.test.output.tap.pas`
- **问题**: TAP 诊断行 (YAML block) 未转义 `#` 开头的行或特殊字符。
- **影响**: 测试名或失败消息若以 `#` 开头，TAP 解析器可能误判为注释。
- **建议**: 对诊断内容进行 minimal escaping。

---

### L-04 — Parallel 模式不支持 retry

- **位置**: `nextpas.core.test.runner.parallel.pas` ParallelWorkerProc
- **问题**: 并行 worker 直接执行一次，忽略 `LEntry.RetryCount`。
- **影响**: 并行模式下 retry 配置静默无效。
- **建议**: 在 `ParallelWorkerProc` 中添加 retry 循环。

---

### L-05 — Parallel 模式不支持 timeout

- **位置**: `nextpas.core.test.runner.parallel.pas` ParallelWorkerProc
- **问题**: 并行 worker 不调用 `RunTestWithTimeout`，直接执行 `R^.Entry.Proc`。
- **影响**: 并行模式下超时配置静默无效。
- **建议**: 在 `ParallelWorkerProc` 中集成 `RunTestWithTimeout`。

---

### L-06 — Parallel 模式静默跳过 subtests

- **位置**: `nextpas.core.test.runner.parallel.pas` L169-179
- **问题**: 子测试被计为 skip 并打印 "subtests not supported in parallel mode"，但无 suite 级汇总警告。
- **建议**: 在 `RunParallel` 结束时若 subtest skip > 0，输出汇总警告。

---

### L-07 — Not_.ToRaise 语义可能令人困惑

- **位置**: `nextpas.core.test.expect.pas` L440-477
- **代码**: `Not_.ToRaise(EConvertError)` — 只匹配 EConvertError，其他异常被 re-raise。
- **当前行为**: 逻辑正确，但用户可能期望"Not_.ToRaise(EConvertError) = 不抛出任何异常"。
- **实际语义**: "不抛出 EConvertError，但其他异常传播"。
- **建议**: 文档明确说明两种语义的区别。

---

### L-08 — Expectation 继承链中未使用 interface delegation

- **位置**: `nextpas.core.test.expect.pas` — 6 个类各自实现全部 IExpectation 方法
- **问题**: TExpectation 基类 + TNumberExpectation/TStringExpectation/TCollectionExpectation 每个都实现了完整的 IExpectation。不相关的方法（如 TNumberExpectation.ToContain）调用时直接报错。
- **建议**: 考虑拆分为精化接口 (INumberExpectation, IStringExpectation) 以获得编译期类型安全。Breaking change，低优先级。

---

### L-09 — 超时实现使用 polling (10ms sleep loop)

- **位置**: `nextpas.core.test.runner.parallel.pas` L106-111
- **代码**: `while (LElapsed < ATimeoutMs) and (not LRec.Done) do begin platform_thread_sleep_ns(10*1000*1000); Inc(LElapsed, 10); end;`
- **影响**: 10ms 粒度，CPU 开销微小但延迟可感知。100ms 超时的测试可能在 90-100ms 之间触发。
- **建议**: 低优先级。可改用 condition variable 实现精确等待。

---

### L-10 — Mock 方法名用字符串匹配 (非类型安全)

- **位置**: `nextpas.core.test.mock.pas` 全局
- **问题**: 所有方法名都是 `string`，拼写错误在编译期无法检测。
- **影响**: `Mock.Setup('Fooo').Returns('bar')` 静默配置一个永远不会被调用的方法。
- **建议**: 这是 FPC 无 interface proxy 的限制，接受现状。可在 Verify 中检测"配置了但从未调用"作为额外检查。

---

### L-11 — PTimeoutRec / PThreadRec 公开导出

- **位置**: `nextpas.core.test.runner.parallel.pas` 接口段
- **问题**: `PTimeoutRec`, `TTimeoutRec`, `PThreadRec`, `TThreadRec` 是实现细节，不应在公共接口中暴露。
- **建议**: 移至 implementation 段或标记为 `{internal}`。

---

### L-12 — Discovery VMT 扫描可能遗漏继承方法

- **位置**: `nextpas.core.test.discovery.pas` L116
- **代码**: `AFixture.ClassType + vmtMethodTable` — 只访问当前类的 VMT。
- **当前状态**: FPC VMT 已合并父类 published 方法，但若有 {$M-} 父类再 {$M+} 子类的场景，行为未验证。
- **建议**: 添加测试验证多层继承场景。

---

### L-13 — test_advanced 4 个 PMethodStub 泄漏

- **位置**: `test_advanced.lpr` — RTTI discovery 测试
- **问题**: 测试运行后报告 4 个堆泄漏（来自 M-01）。
- **状态**: 与 M-01 同源。修复 M-01 后此处自动解决。

---

### L-14 — test_parallel 未覆盖 RunParallelWithResult

- **位置**: `test_parallel.lpr`
- **问题**: 只测 `RunParallel` / `RunAllParallel`，未测 `RunParallelWithResult` / `RunAllParallelWithResult`。
- **建议**: 添加结果收集测试。

---

### L-15 — test_runner 变量名重用影响可读性

- **位置**: `test_runner.lpr` — `LResultSuite` 被多次赋值用于不同测试
- **建议**: 使用独立变量名或添加分隔注释。

---

### L-16 — 子测试结果可能双重计入

- **位置**: `nextpas.core.test.runner.context.pas` L195-201 + `nextpas.core.test.runner.pas` (RunWithResult)
- **问题**: `ExecuteSubtests` 通过 `FOnResult` 回调向 runner 报告子测试结果，同时子测试的 pass/fail 计数通过 `InternalFail` 向上传播。若 runner 既收集 Results 数组又计数，可能双重计入。
- **当前状态**: 需验证 runner 是否在 `FOnResult` 回调中正确去重。

---

### L-17 — CheckLength 与 CheckEqual 参数顺序不一致

- **位置**: `nextpas.core.test.check.pas`
- **代码**: `CheckEqual(expected, actual)` vs `CheckLength(actual, expected)` — 顺序相反。
- **状态**: 已有文档注释。Breaking change 不值得改。
- **建议**: 不改，保持现状。

---

### L-18 — parallel 模式 BeforeEach/AfterEach 线程安全由用户负责

- **位置**: `nextpas.core.test.runner.parallel.pas` L194-217, L247-263
- **状态**: 设计如此 — 所有线程共享同一个 BeforeEach/AfterEach proc，无框架级保护。
- **建议**: README 中更强调这一点。

---

### L-19 — GExecState threadvar finalization 只释放主线程

- **位置**: `nextpas.core.test.runner.pas` — finalization 段
- **问题**: `Dispose(GExecState)` 只释放主线程的 GExecState。并行 worker 在 `ParallelWorkerProc` 结束时自行释放 (L316-320)，但若 worker 异常退出可能泄漏。
- **建议**: 添加注释明确说明 threadvar finalization 行为。

---

### L-20 — 子测试 AfterEach LPass 计数可能下溢

- **位置**: `nextpas.core.test.runner.pas` — RunWithResult AfterEach 失败路径
- **问题**: AfterEach 失败时 `if LPass > 0 then Dec(LPass)`，但子测试模式下 `LPass` 可能未被 Inc（由 `FSubPass` 计数），Dec 减的是前一个普通测试的 pass 数。
- **建议**: 添加 `if LEntry.Kind <> ekSubtest then` 条件守护。

---

### L-21 — Mock GetReturnInt 非数字字符串时抛异常

- **位置**: `nextpas.core.test.mock.pas` L353
- **代码**: `Result := StrToInt64(LVal)` — 若 `Returns` 配置了非数字字符串，`GetReturnInt` 会抛 `EConvertError`。
- **建议**: 改为 `TryStrToInt64` 或在 ReturnsInt 中存储原始 Int64 值。

---

### L-22 — GetReturnBool 只认 'true' 字符串

- **位置**: `nextpas.core.test.mock.pas` L358
- **代码**: `Result := FState.GetReturn(AMethodName) = 'true'` — 大小写敏感，不认 'True'、'1'、'yes'。
- **建议**: 改为 `SameText(LVal, 'true')` 或存储原始 Boolean。

---

## Info / Design Notes (通常不修)

### I-01 — 无 Float/Double 专用断言

- **现状**: `CheckEqual` 有 `Double` 重载（带 epsilon），`ExpectFloat`/`ExpectNear` 已存在。
- **结论**: 已足够，无需额外 API。

---

### I-02 — ETestSkipped = class(EAbort) 的 GUI 环境行为

- **现状**: EAbort 在 GUI 应用中可能触发 debugger break。设计如此，文档已说明。

---

### I-03 — InitAnsi 非线程安全

- **位置**: `nextpas.core.test.output.pas` InitAnsi
- **现状**: benign race — 结果确定性（同值赋值），initialization 段已先执行。不改。

---

### I-04 — TTestRunner.AllPassed 空 suite 行为

- **现状**: `HasRun` 字段已存在。空 suite 的 `AllPassed` 返回 `HasRun and (LastFail = 0)`。设计正确。

---

### I-05 — APool 参数未使用

- **位置**: `nextpas.core.test.runner.pas` L72-73
- **现状**: 注释说明 "Reserved for future thread pool integration"。设计如此。

---

### I-06 — test_assertions 的 Halt(1) 模式

- **现状**: catch 块可能遗漏非 EAssertionFailed 异常。已在 Round 2 R2-F16 标记并修复。

---

### I-07 — test_subtests GSubTestsRun 计数精度

- **现状**: `if GSubTestsRun < 10` 只检查下限。可改为精确值检查，但非关键。

---

### I-08 — README 测试计数过时

- **现状**: 文档说 test_expect 有 45 测试，实际有 60+。建议更新数字。

---

### I-09 — README 行数 "~1870" 近似值

- **现状**: `~` 前缀已表示近似。可接受。

---

### I-10 — Thread.sleep 精度依赖平台

- **现状**: `platform_thread_sleep_ns` 精度取决于 OS scheduler。Linux 下通常 ~1ms，Windows ~15ms。设计如此。

---

### I-11 — TTestEntry.TableCase/TableProc 用无类型指针

- **现状**: `Pointer` 类型，使用时需 `PTestCase()`/`PTestCaseProc()` 强制转换。FPC 泛型记录的限制。

---

### I-12 — 无 async/await 测试支持

- **现状**: 测试是同步执行的。FPC 无原生 async/await。设计如此。

---

### I-13 — 无 test coverage 集成

- **现状**: FPC 有 `-Cov` 选项但未集成到 test 框架。可作为未来功能。

---

### I-14 — TTestSuite 是 record (COW 语义)

- **现状**: 设计如此。COW 意味着 `var S2 := S1` 后修改 S2 不影响 S1。但 `Tests` 数组是引用语义，修改 S2.Tests 会影响 S1.Tests。
- **注意**: 已知设计点，非 bug。

---

### I-15 — Mock 的 IMockSetup/IMockVerify GUID

- **现状**: 硬编码 GUID。若未来版本修改接口，GUID 不变会导致旧代码链接到新接口。
- **建议**: 接口变更时更新 GUID。

---

## 已核实无问题

| Finding | 核实结果 |
|---------|---------|
| ToNotRaise FNegated 重置 | 正确 — L479-493 无 FNegated 使用，ToRaise L452 处理 FNegated |
| RunWithResult retry 循环 | 正确 — L470-518 retry 逻辑完整 |
| ParallelWorkerProc BeforeEach 失败后行为 | 正确 — `if LStatus = tsPassed` 跳过测试，AfterEach best-effort 运行 |
| Discovery VMT 格式 | 正确 — 与 FPC objpas.inc 定义一致 |
| Closure capture by-value | 正确 — MakeMethodClosure 工厂函数确保 AStub 按值捕获 |

---

## 修复优先级建议

| 优先级 | Findings | 说明 |
|--------|----------|------|
| **P0 立即修** | C-01, C-02 | 内存安全 + data race |
| **P1 本轮修** | M-01, M-02, M-03 | 泄漏（与 C-01 关联） |
| **P1 本轮修** | M-04, M-05 | 逻辑正确性 |
| **P2 可选修** | M-06, M-07, M-08, M-09, M-10, M-11 | 代码健壮 + 文档准确 |
| **P3 按需修** | L-01 ~ L-22 | 低影响或 breaking change |
| **不修** | I-01 ~ I-15 | 设计如此或无实际影响 |

### 建议修复批次

| Batch | Findings | 说明 |
|-------|----------|------|
| **Batch 1** | C-01, C-02, M-02 | 安全修复：timeout 堆分配 + parallel mutex |
| **Batch 2** | M-01, M-03 | 泄漏修复：discovery stubs + TestTable cases |
| **Batch 3** | M-04, M-05, M-06, M-08 | 逻辑 + 文档修正 |
| **Batch 4** | M-07, M-09, M-10, M-11 | 健壮性 + 测试覆盖 |
| **Batch 5** | L-01, L-04, L-05 | 功能对齐 (breaking) |
| **按需** | 其余 L-* | 用户反馈触发时修 |

---

## 架构建议 (非 findings，供讨论)

### A-1 — 测试发现扩展：扫描指定目录

当前 `DiscoverTests` 只接受单个 fixture 实例。可考虑：
- `DiscoverAllTests(ASearchPath: string): TTestSuite` — 扫描目录中所有 `*_test.pas` 单元
- 需要编译期单元注册机制（如 initialization 段注册），FPC 无动态加载

### A-2 — Mock 升级路线

若需要真正的 interface mock：
- **Phase 1** (当前): 手动字符串记录器 ✓
- **Phase 2**: 编译期代码生成器 (类似 Mockito for Java)
- **Phase 3**: 运行时 interface proxy (需要 TRttiMethod.Invoke 或 JIT)

FPC 的 RTTI 能力有限，Phase 2 需要修改编译器或使用 metaprogramming tool。

### A-3 — 并行模式架构改进

当前并行模式用 `platform_thread_create` 直接创建线程（注释说明 APool 未使用）。建议：
- 集成 `IThreadPool` 以控制并发度
- 支持 per-test timeout 和 retry
- 支持 subtest（通过 thread-safe 结果收集器）

---

**本轮合计**: 2 Critical / 11 Medium / 22 Low / 15 Info / 5 核实无问题
