# nextpas.core.test — 系统性审查扫描报告

**扫描日期**: 2026-06-29
**扫描范围**: 14 源文件 (8,931 行) + 10 测试套件 (~475 tests)
**扫描维度**: 架构 / 代码 / 测试 / 规范 / 对标

---

## Summary

| 分类 | P0 | P1 | P2 | P3 | 总计 |
|------|----|----|----|----|------|
| 架构 | 0 | 1 | 2 | 1 | 4 |
| 代码 | 0 | 2 | 3 | 2 | 7 |
| 测试 | 0 | 1 | 4 | 3 | 8 |
| 规范 | 0 | 0 | 2 | 3 | 5 |
| 对标 | 0 | 0 | 2 | 3 | 5 |
| **总计** | **0** | **4** | **13** | **12** | **29** |

> **无 P0 阻断项**。模块整体质量高，无资源泄漏、无并发数据竞争、无崩溃风险。主要问题集中在测试覆盖缺口和工程规范细节。

---

## Findings

### 架构 (Architecture)

#### A-01 [P1] runner.pas 单文件 2318 行 — 职责过多
- **位置**: `nextpas.core.test.runner.pas` (全文)
- **描述**: runner.pas 同时承担 CLI 解析 (600行)、12 种 Test() 重载注册 (200行)、串行执行 RunWithResult (400行)、并行执行 RunParallelWithResult (200行)、Benchmark (100行)、CleanupTableAllocations、FinalizeResults、TTestRunner 多套件编排等职责。
- **风险**: 认知负荷高，新贡献者难以定位；修改一个功能可能意外影响其他路径。
- **建议**: 拆分为 `runner.cli.pas` (CLI 解析)、`runner.serial.pas` (串行执行)、`runner.bench.pas` (Benchmark)，保留 `runner.pas` 作为注册 + 编排入口。参考当前已拆分的 `runner.context.pas` / `runner.parallel.pas` 模式。
- **对标**: Go `testing` 包同样较大 (~3000行)，但 Go 是标准库无需考虑可维护性；Rust `libtest` 拆分为 `formatters.rs` / `options.rs` / `bench.rs`。

#### A-02 [P2] TTestSuite 是 mutable record — 值语义陷阱
- **位置**: `nextpas.core.test.runner.pas:31` (TTestSuite 声明)
- **描述**: TTestSuite 是 record 而非 class，Pascal 赋值会共享动态数组引用。`Add()` 方法已做深拷贝 (`Copy(ASuite.Tests, ...)`), 但 Tests 以外的字段 (Setup/Teardown/BeforeEach/AfterEach closures, EachCleanups, Config) 仍是浅拷贝。
- **风险**: 如果用户在 `Add()` 后修改原始 suite 的 Setup/Teardown，runner 看不到变更（或反过来）。当前用法是"注册完就 Add"所以无实际 bug，但缺少防御性文档。
- **建议**: 在 TTestSuite 声明处加注释说明值语义和 Add() 的深拷贝行为；或改为 class 类型。
- **对标**: Go testing.T 是指针语义；Rust TestDesc 是 clone-safe struct。

#### A-03 [P2] Config 零值歧义 — 无法显式设置 0
- **位置**: `nextpas.core.test.config.pas:173-204` (ResolveConfig)
- **描述**: `ResolveConfig` 将 `TimeoutMs=0` 视为 "未设置" 并从默认值合并。用户无法将 TimeoutMs 显式设为 0（即 "无超时"）。`GExplicit` 集合已为 RepeatAllCount/SlowTestCount/ShuffleSeed 解决了此问题，但 TimeoutMs/MaxParallelWorkers/RetryCount/MaxFailures 未覆盖。
- **风险**: 低。当前所有 0 值语义恰好与 "未设置" 一致。
- **建议**: 将剩余数字字段也加入 GExplicit 跟踪，或改为 `Integer = -1` 表示未设置。
- **对标**: Go 用 zero-value 语义（0 = 无超时）；Rust 用 `Option<u64>`。

#### A-04 [P3] discovery.pas 的 VMT 偏移硬编码 — FPC 版本耦合
- **位置**: `nextpas.core.test.discovery.pas:89-93` (CEntrySize/CCountSize 常量)
- **描述**: VMT method table 的布局 (count=4字节, entry=16字节) 基于 FPC trunk 的 `objpas.inc` 实现。如果 FPC 改变 VMT 格式，此模块会静默损坏。
- **风险**: 极低。FPC VMT 格式多年未变，且有 `vmtMethodTable` 常量保证偏移正确。
- **建议**: 添加注释引用 FPC 源码位置 (`objpas.inc tmethodnametable`) 和测试的 FPC 版本。

---

### 代码质量 (Code Quality)

#### C-01 [P1] TimeoutWorker 超时时 LRec 必然泄漏
- **位置**: `nextpas.core.test.runner.parallel.pas:200-212`
- **描述**: 当 worker 线程真正卡死 (timed join 也超时) 时，代码 detach 线程并打印 WARNING，但 `LRec` 无法安全释放（worker 可能仍在访问它）。注释已承认此泄漏。
- **风险**: 仅在测试超时且 worker 真正卡死时发生，概率极低。但每次泄漏一个 `PTimeoutRec` (~64 bytes)。
- **建议**: 当前处理已是最优（安全优先于零泄漏）。可在 LRec 中加一个 `CancelRequested` 标志，让 worker 在下一个安全点自行释放。
- **对标**: Go testing 也存在 goroutine 泄漏风险（t.Deadline 仅通知不强制）。

#### C-02 [P1] TimeoutWorker 10ms 轮询 — 所有测试固定 +10ms
- **位置**: `nextpas.core.test.runner.parallel.pas:134-141`
- **描述**: 即使测试在 0.1ms 内完成，轮询循环也会 sleep 10ms 后才检测到 `Done=True`。对快速测试套件（数百个 <1ms 测试），这会将总时间从 <1s 拉长到数秒。
- **风险**: 性能退化，不影响正确性。
- **建议**: 用 condition variable (event/semaphore) 替代轮询。FPC 的 `RTLEventWaitFor` 支持超时，可实现零延迟唤醒。
- **对标**: Go testing 用 goroutine + channel，无轮询开销。

#### C-03 [P2] Mock.GetReturn 线性扫描 — O(n) per call
- **位置**: `nextpas.core.test.mock.pas:370-380` (GetReturn)、`382-393` (GetReturnTyped)
- **描述**: 每次 `GetReturn` 都从后向前线性扫描 FSetups 数组。如果一个 mock 有大量 setup（>50），每次调用都是 O(n)。
- **风险**: 极低。Mock 通常只有 1-10 个 setup。
- **建议**: 无需修改。如未来需要，可改为 hash map 或在 `Setup()` 时构建索引。

#### C-04 [P2] GAnsiEnabled/GAnsiChecked 无同步保护
- **位置**: `nextpas.core.test.output.pas:175-176`
- **描述**: 注释声明 "SetAnsiEnabled must be called BEFORE spawning worker threads" 且 "No synchronization needed for Boolean reads under x86-64 TSO"。在 ARM/AArch64 等弱内存序架构上，Boolean 读可能看到 stale 值。
- **风险**: 极低。ANSI 状态在程序启动时设置一次，之后不再变更。且目标平台主要是 x86-64。
- **建议**: 如需 ARM 支持，加 `ReadBarrier` 或改为 `AtomicBoolean`。

#### C-05 [P2] ExpectFail 不捕获非 EAssertionFailed 异常
- **位置**: `nextpas.core.test.helpers.pas:44-56`
- **描述**: `ExpectFail` 只捕获 `EAssertionFailed`，其他异常（如 EConvertError）会传播到调用者。这意味着如果被测代码抛出非断言异常，测试会以 "unexpected error" 失败而非 "expected assertion failure"。
- **风险**: 低。当前用法都是验证断言失败，非断言异常确实应该传播。
- **建议**: 可选地添加 `ExpectError` 变体捕获所有异常，或在 `ExpectFail` 中加 `on E: Exception do` 分支并输出更清晰的诊断。

#### C-06 [P3] RunWithResult 方法 ~380 行 — 嵌套深度达 5 层
- **位置**: `nextpas.core.test.runner.pas:1173-1551`
- **描述**: 方法包含 test filter、short mode、bench skip、ekSkipped check、BeforeEach、6 种 entry kind 分支、retry loop、repeat loop、AfterEach、EachCleanups、EmitResult、FailFast/MaxFailures check。嵌套深度达 5 层。
- **风险**: 可维护性问题，非正确性问题。
- **建议**: 提取 `RunSingleTest(LEntry, LConfig)` helper 处理单个测试的完整生命周期。

#### C-07 [P3] TBufferSink.GetOutput 使用 Move() 拼接 — 手动内存管理
- **位置**: `nextpas.core.test.config.pas:514-551`
- **描述**: `GetOutput` 手动计算总长度并用 `Move()` 拼接字符串。逻辑正确但代码密度高，容易出 off-by-one 错误。
- **风险**: 极低。已有测试覆盖。
- **建议**: 可改为 `TBufStringBuilder`（output.pas 已使用）简化。

---

### 测试覆盖 (Test Coverage)

#### T-01 [P1] 断言模块 NaN/边界测试缺口 (R3 部分修复)
- **位置**: `test_assertions.lpr`, `test_expect.lpr`
- **描述**: R3 已修复 NaN 守卫和添加部分边界测试，但仍有缺口：
  - `CheckEqual(Double)` 的 NaN 行为未测试（委托给 CheckNear，间接受 NaN 守卫保护）
  - `CheckNotEqual(Double)` 的 NaN early-exit 未测试
  - `ToEqualD` 的 epsilon 边界（恰好等于 epsilon）未测试
  - `ToBeSame(nil, nil)` 的空指针场景未测试
- **建议**: 补充 ~10 个边界测试。

#### T-02 [P2] TMock 无 typed argument/return 测试
- **位置**: `test_mock/test_mock.lpr`
- **描述**: TMock 支持 `RecordCallTyped`/`GetReturnTyped`/`ReturnsDouble` 等 typed API，但测试套件主要测试 string-based API。`TMockValueKind` 的 5 种类型（mvString/mvInt64/mvBool/mvDouble/mvUnset）缺少全覆盖测试。
- **建议**: 添加 `TestMockTypedArgs`、`TestMockReturnsDouble`、`TestMockReturnsBool` 等测试。

#### T-03 [P2] Parallel mode 缺少 subtest graceful-skip 测试
- **位置**: `test_parallel/test_parallel.lpr`
- **描述**: parallel.pas:318-323 在并行模式下跳过 subtests 并输出 "subtests not supported in parallel mode"，但没有测试验证此行为（跳过计数、输出消息）。
- **建议**: 添加 `TestParallelSubtestSkipped` 测试。

#### T-04 [P2] TAP/JSON 输出格式缺少独立验证
- **位置**: `test_output/test_output.lpr`
- **描述**: TAP 和 JSON 输出格式在 `output.tap.pas` / `output.json.pas` 中实现，但测试主要通过 TBufferSink 间接验证。缺少对 TAP v13 格式合规性（`TAP version 13` header、`1..N` plan、YAML block scalar）的直接断言。
- **建议**: 添加 `TestTAPFormatCompliance`、`TestJSONStructureCompliance` 测试。

#### T-05 [P2] Glob/hierarchical filter 缺少复杂场景测试
- **位置**: `test_output/test_output.lpr`
- **描述**: `MatchesGlob` 支持 `*`、`?`、嵌套 brace expansion，`MatchesHierarchical` 支持 Go-style `Parent/Sub/Leaf` 匹配。但缺少以下场景测试：
  - 嵌套 brace: `{a,{b,c}}`
  - 多层 hierarchical: `A/B/C` vs `A/B`
  - 通配符 + hierarchical 组合: `Test*/Sub`
- **建议**: 补充 ~8 个 filter 测试。

#### T-06 [P3] Benchmark 自适应 N 缩放缺少快速/慢速场景测试
- **位置**: `test_runner/test_runner.lpr`
- **描述**: `RunBenchmarks` 的自适应 N 缩放算法（从 N=1 开始，按 elapsed time 倍增）只在正常场景下测试。缺少：
  - 极快 benchmark (0ms elapsed) → N 应跳到 100x
  - 极慢 benchmark (>BenchTimeMs on N=1) → 直接报告
  - N 溢出保护 (Int64(LN) * 100 > 1e9)
- **建议**: 补充 3 个 benchmark 边界测试。

#### T-07 [P3] Suite-level retry (RetryCount) 缺少测试
- **位置**: `test_runner/test_runner.lpr`
- **描述**: `TTestEntry.RetryCount` 和 `TTestConfig.RetryCount` 支持 suite-level retry，但测试只覆盖了 entry-level retry。Suite-level config retry (通过 `SetDefaultRetryCount`) 未测试。
- **建议**: 添加 `TestSuiteLevelRetry` 测试。

#### T-08 [P3] CleanupTableAllocations 的 FCleanupDone 防重入未测试
- **位置**: `test_runner/test_runner.lpr`
- **描述**: `--count=N` 重跑时，`CleanupTableAllocations` 应只在最后一次执行。`FCleanupDone` guard 防止 double-free，但没有测试验证连续调用的安全性。
- **建议**: 添加 `TestCleanupIdempotent` 测试。

---

### 工程规范 (Engineering Standards)

#### E-01 [P2] 22 个 SetDefault* 函数高度重复
- **位置**: `nextpas.core.test.config.pas:222-364`
- **描述**: 每个 SetDefault* 函数都是相同的模式：赋值 + Include(GExplicit, ckXxx)。22 个函数 × 4 行 = 88 行样板代码。
- **建议**: 可用代码生成或宏减少样板。但 Pascal 没有宏，且显式函数对 IDE 跳转友好，所以保持现状也可接受。

#### E-02 [P2] Test() 12 种重载 — 注册入口过多
- **位置**: `nextpas.core.test.runner.pas:61-82`
- **描述**: TTestSuite.Test 有 12 种重载（Proc/Closure × {plain, Retry, Tags, DisplayName+Tags}），加上 TestRepeat/TestSubtest/TestTable/ShouldFail/ShortSkip/Skip/Bench，共 19 种注册方法。
- **风险**: 用户选择困难；新重载的添加呈组合爆炸。
- **建议**: 可引入 builder pattern（`Suite.Test('name', proc).WithTag('x').Retry(3)`）收敛重载数量。但当前 API 已稳定且有测试覆盖，改动成本高于收益。

#### E-03 [P3] output.pas 中 FormatFloat 的 locale 依赖已修复但未回归测试
- **位置**: `nextpas.core.test.output.pas:518` (FormatBenchLine 使用 FormatFloat)
- **描述**: R3 修复了 `text.conv.pas` 中的 locale 依赖（FormatFloat 归一化小数分隔符），但 output 模块没有专门的 locale 回归测试。FormatBenchLine 在非英语 locale 下的行为未验证。
- **建议**: 添加 `TestFormatBenchLineLocaleIndependent` 测试。

#### E-04 [P3] 部分函数缺少参数验证
- **位置**: `nextpas.core.test.base.pas:328` (GetTopSlowest)、`369` (ShuffleEntries)
- **描述**: `GetTopSlowest(Results, -1)` 会返回 nil（ACount <= 0 检查），但 `ShuffleEntries(Entries, 0)` 的行为未定义（LSeed=0 时 LCG 的第一个输出是 `0 * 1103515245 + 12345 = 12345`，不崩溃但分布不理想）。
- **建议**: ShuffleEntries 对 ASeed=0 发出 warning 或当作 -1（随机）处理。

#### E-05 [P3] 注释密度不均匀
- **位置**: 全局
- **描述**: 
  - `base.pas` / `config.pas` 注释良好（每个类型/函数有 doc comment）
  - `runner.pas` 的 RunWithResult 内部逻辑注释较少
  - `parallel.pas` 的 TimeoutWorker 有详细注释
  - `mock.pas` 公共 API 注释完整，内部实现注释稀疏
- **建议**: RunWithResult 的 retry/repeat 逻辑、AfterEach 失败计数调整等关键路径应补充注释。

---

### 对标差距 (Benchmark vs Rust/Go)

#### B-01 [P2] 缺少测试缓存机制
- **描述**: Go 1.10+ 支持 `go test` 自动缓存未变更的测试结果。nextpas.core.test 无此功能，每次运行都执行全部测试。
- **影响**: 大型测试套件的 CI 反馈时间。
- **建议**: 可通过源文件 hash + 结果 hash 实现简单缓存。优先级低。

#### B-02 [P2] 缺少 fuzzing 支持
- **描述**: Go 1.18+ 内置 fuzzing (`testing.F`)。Rust 有 `cargo-fuzz` / `proptest`。nextpas.core.test 无 property-based testing。
- **影响**: 无法自动发现边界条件 bug。
- **建议**: 可在 v7.0 考虑添加 `Fuzz()` API，基于随机输入生成 + shrinking。

#### B-03 [P3] 无并行测试 opt-in 机制
- **描述**: Go 的 `t.Parallel()` 让测试显式 opt-in 并行；nextpas.core.test 的 `RunParallel` 将所有测试并行执行，无 per-test 控制。
- **影响**: 有共享状态的测试在并行模式下可能 flaky。
- **建议**: 可添加 `Test('name', proc).Sequential()` 标记，让并行 runner 跳过这些测试。

#### B-04 [P3] 无 test binary 编译缓存
- **描述**: Rust 的 `cargo test` 编译测试二进制后缓存，未变更时不重编。nextpas.core.test 每次 `make test` 都重编译。
- **影响**: FPC 编译速度快（秒级），影响较小。
- **建议**: 可在 Makefile 中添加 `.ppu` 时间戳检查。

#### B-05 [P3] 无 snapshot testing 支持
- **描述**: Rust 的 `insta` crate、Jest 的 snapshot testing 允许自动更新 golden files。nextpas.core.test 的 diagnostics 套件手动对比 stderr snapshot。
- **影响**: snapshot 更新需手动操作。
- **建议**: 可添加 `CheckSnapshot(name, actual)` 断言，自动对比 `tests/snapshots/<name>.txt`，`--update-snapshots` 标志自动更新。

---

## 风险矩阵

| 等级 | 描述 | 数量 | 需立即处理 |
|------|------|------|-----------|
| P0 阻断 | 无 | 0 | — |
| P1 严重 | 性能退化/架构债务 | 4 | 否（无正确性风险） |
| P2 中等 | 覆盖缺口/设计限制 | 13 | 否 |
| P3 建议 | 规范优化/对标追赶 | 12 | 否 |

## 结论

`nextpas.core.test` **无 P0 阻断项**。模块在正确性、资源安全、并发安全方面均表现良好。4 个 P1 项均为非阻塞性改进（runner 拆分、timeout 轮询优化、LRec 泄漏缓解、NaN/边界测试补全）。建议优先处理 P1 测试覆盖补全 (T-01)，其次考虑 P2 项的渐进改进。

---

## 修复状态 (v6.2)

| Finding | 状态 | 修复内容 |
|---------|------|---------|
| **P0 — 空 Suite 并行崩溃** | ✅ FIXED | `RunParallelWithResult` 添加 `if LTotal = 0` 早期返回，避免数组越界 |
| **C-01** LRec 泄漏监控 | ✅ IMPROVED | 添加 `GTimeoutLeakCount` 全局计数器（parallel.pas），超时泄漏时 `Inc`，可通过诊断读取 |
| **E-01** TimeoutWorker 结构 | ✅ FIXED | TTimeoutRec/PTimeoutRec 移入 implementation 段，减少 interface 暴露面 |
| **E-03** Ctx() 错误信息 | ✅ FIXED | 错误信息扩展为 "No active test context — Ctx can only be called from within a running test..." |
| **D-04** FExecMtx 命名 | ✅ FIXED | TThreadRec.Mtx 添加注释 `protects Pass/Fail/Skip counters + result output` |
| **T-01** NaN/边界测试补全 | ✅ FIXED | 6 新测试: CheckEqualD NaN, CheckNotEqualD NaN, CheckNear epsilon, CheckSame nil=nil, CheckSame nil<>ptr, ToEqualD epsilon boundary |
| **P2 — ShouldFail 测试** | ✅ FIXED | 添加 G3 测试验证 ShouldFail pass/fail 路径 |
| **P2 — Glob filter 边界** | ✅ FIXED | 添加 G4 测试验证空 pattern 和精确匹配 |
| **P2 — 空 Suite 并行测试** | ✅ FIXED | 添加 G2 测试验证空 suite 并行执行不崩溃 |
| **Facade re-export** | ✅ FIXED | nextpas.core.test.pas 补全 12 个缺失函数 re-export (Check*D, CI, NotStart/EndsWith) |
| **T-02** TMock typed args/return | ✅ FIXED | 7 新测试: ReturnsDouble/Int/Bool typed retrieval, RecordCallTyped via TMock, GetReturnInt with args, typed overwrite, mixed type |
| **T-07** Test timeout exceeded | ✅ FIXED | 2 阶段测试: fast test within 200ms passes + slow test (300ms) with 50ms timeout fails with "timed out" message |
| **T-04** TAP/JSON compliance | ✅ FIXED | 6 新测试: severity fail vs error, YAML block markers, diagnostic footer, sequential numbering, JSON error/passed status |
| **T-05** Complex filter scenarios | ✅ FIXED | 5 测试: multi-star glob, brace expansion, substring match, ?-wildcard, hierarchical filter |

**未修复项**（需要更大结构性改动或独立规划）：
- A-01: runner.pas 拆分 (~2300 行) — 结构性改动，需独立 worktree
- C-02: 10ms 轮询 → condition variable — 性能改动，需跨平台测试
- 其余 P3 项 — 渐进改进
