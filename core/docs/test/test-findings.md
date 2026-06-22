# Test Module Audit Findings

> 最后更新: Round 5 — 全面审查扫描 (2026-06-21)

---

## Round 5 — 全面审查扫描

> 审查时间: 2026-06-21
> 审查范围: 全部 10 个源文件 + 8 个测试套件 + README
> 审查方法: Claude 逐文件全量阅读 + 逻辑推演
> 前序: Round 3+4 的 Codex 修复已全部落地 (68eb06ff6)

**汇总**: 12 findings (1 Medium, 6 Low, 5 Info)
**亮点**: Critical 为零，框架核心已相当稳固。
**修复状态**: R5-01 之前已修复, R5-02~07 已修复 (67be519e2), R5-08~12 Info 级别保留观察。

### 纠正 Round 3/4 已修复项

| 原 ID | 状态 | 说明 |
|--------|------|------|
| M-03 | ✅ 已修复 | `RunParallelWithResult` L739 实际已调用 `CleanupTableAllocations` |
| L-09 | ✅ 不成立 | `ExecuteSubtests` 通过 `RunNested` + 递归调用自身，支持任意深度嵌套 |
| L-14 | ✅ 已修复 | `CheckContains` L197-198 显式处理空 needle：`Exit` 匹配一切，6 个测试覆盖 |

### Medium

| ID | 文件 | 问题 | 建议 |
|----|------|------|------|
| R5-01 | expect.pas L479-492 | **`ToNotRaise` 不处理 `ETestSkipped`**：`Skip()` 在 `ToNotRaise` 被捕获为意外异常而非流控制传播。`ToRaise` (L447) 正确 re-raise `ETestSkipped`，但 `ToNotRaise` 缺少此处理。`ExpectProc(@Skip).ToNotRaise` 会误报失败。 | ✅ 之前已修复 — Round 3 Batch 7 已添加 `on E: ETestSkipped do raise;` |

### Low

| ID | 文件 | 问题 | 建议 |
|----|------|------|------|
| R5-02 | runner.pas L742-744 | `RunParallelWithResult` 对 subtest 条目不写 `LResults[I]`（`ParallelWorkerProc` 直接 Exit），导致结果数组中对应 slot 包含零初始化数据（`tsPassed` + 空消息），掩盖了"subtest 未运行"的事实。 | ✅ 已修复 (67be519e2) — pre-fill loop 中初始化 tsSkipped + 原因消息 |
| R5-03 | test_lifecycle.lpr | 缺少 `{$modeswitch anonymousfunctions}` 和 `{$modeswitch functionreferences}`——其他 7 个测试文件均有。虽然当前代码只用命名过程所以不报错，但风格不一致，未来添加匿名函数时会困惑。 | ✅ 已修复 (67be519e2) — 补齐 modeswitch 声明 |
| R5-04 | README.md L306 | 声称 filter 是 "case-insensitive substring match" 但代码 (`output.pas` L242) 用 `Pos(LPattern, AName)` 即 case-sensitive。文档与实现不符。 | ✅ 已修复 (67be519e2) — 改为 "case-sensitive" |
| R5-05 | README.md L437-458 | 架构图只列出 8 个模块，遗漏 `test.output.tap` (108 行) 和 `test.output.json` (154 行)。行数也有多处过时：`output` 实际 435 行 (文档写 393)、`runner` 实际 933 行 (文档写 834)。 | ✅ 已修复 (67be519e2) — 更新架构图 + 补全 tap/json/discovery/mock + 修正行数 + 补全 Build & Test 循环 |
| R5-06 | check.pas L62-85 | `StringDiff` 用字符位置而非字节位置——对多字节 UTF-8 字符串，`Copy(S, LStart, ...)` 可能截断多字节序列导致乱码输出。 | ✅ 已修复 (67be519e2) — 添加 `Utf8SafeStart` 辅助函数，扫描回退续行字节 |
| R5-07 | output.pas L253-277 | `XmlEscape` 不转义控制字符 (#0-#31)——`JsonEscape` 已处理但 `XmlEscape` 没有。包含 tab/newline 的错误消息会产生畸形 XML。 | ✅ 已修复 (67be519e2) — 控制字符替换为空格（保留 #9/#10/#13） |

### Info

| ID | 文件 | 问题 |
|----|------|------|
| R5-08 | base.pas L83 | `ETestSkipped = class(EAbort)`——任何 `EAbort`（包括用户代码抛出的）都会被框架视为 Skip。这是有意设计但可能导致非预期行为。 |
| R5-09 | runner.parallel.pas | `RunParallelWithResult` 不检查 `GetTestFilter`——并行模式下 filter 不生效，被 filter 排除的测试仍会并行执行。与 serial 模式行为不一致。 |
| R5-10 | discovery.pas | `DiscoverTests` 的 `New(LPStub)` 在 finalization 中有文档化的有意泄漏。对大规模 test suite（数千 published 方法），内存累积可能显著。 |
| R5-11 | runner.pas L700-718 | `RunParallelWithResult` 为每个测试创建一个 OS 线程——无上限。1000+ 测试的 suite 可能触发 OS 线程限制。 |
| R5-12 | test_advanced.lpr L89 | `TestDiscoverDefaultSuiteName` 手动 `LFixture.Free`——如果将来添加 `LSuite.Run`，teardown 会 double-free。与 R4-10 同类。 |

---

## Round 4 — Codex 审查 (68eb06ff6 之后)

> 审查时间: 2026-06-21
> 审查范围: 全部 18 个源文件 + 8 个测试套件
> 审查方法: Codex agent 逐文件扫描 + 运行时验证
> 前序: Round 3 的 7-batch Codex 修复已全部落地 (68eb06ff6)

**汇总**: 14 findings (0 Critical, 5 Medium, 6 Low, 3 Info)

### Medium

| ID | 文件 | 问题 | 建议 |
|----|------|------|------|
| R4-01 | expect.pas | `Not_()` 创建新对象但 `FNegated` 不会自动重置。`Expect('x').Not_.ToEqual('y').ToEqual('x')` 中第二个 `ToEqual` 仍以 `FNegated=True` 运行。 | 文档明确说明 `Not_()` 只影响链中下一个断言，或在 `To*` 后自动重置 `FNegated`。 |
| R4-02 | runner.parallel.pas | `ParallelWorkerProc` 中 skip/subtest 的 `Exit` 路径不写 `R^.Res^`，导致调用方看到未初始化的结果。 | 在所有 `Exit` 路径前确保 `R^.Res^` 被写入（至少写 `Status := tsPassed`）。 |
| R4-03 | runner.parallel.pas | `RunParallelWithResult` 跳过子测试（`subtest` 不支持并行），但不记录跳过原因到结果中。 | 在并行结果中标记子测试为 skipped + 原因说明。 |
| R4-04 | output.tap.pas | TAP 输出不对 YAML 特殊字符转义（`#`, `{`, `[` 等在 YAML block 中有歧义）。 | 为 TAP diagnostics 行添加 YAML-safe 转义。 |
| R4-05 | README.md | 测试数量统计缺少 `test_advanced`(18) 和 `test_lifecycle`(13) 和 `test_output`(23)。 | 更新 README 中的测试套件清单和数量。 |

### Low

| ID | 文件 | 问题 | 建议 |
|----|------|------|------|
| R4-06 | base.pas | `TTestFixure` 拼写错误（应为 `TTestFixture`），是 breaking change。 | 下次 major version 修正，或提供类型别名过渡。 |
| R4-07 | output.pas | `StringDiff` 在前缀相同时显示的 context 行不够有用（只显示相同部分）。 | 改进 diff 算法，优先显示差异行及其上下文。 |
| R4-08 | output.pas | `MatchesGlob` 递归回溯在极端 pattern（如 `*****`）下可能栈溢出。 | 添加递归深度限制或改用迭代算法。 |
| R4-09 | runner.parallel.pas | 并行模式下 `BeforeEach` 闭包如果捕获了共享引用，多线程执行可能有数据竞争。 | 文档说明 `BeforeEach` 闭包在并行模式下的线程安全要求。 |
| R4-10 | test_discovery.pas | discovery 测试中手动 `Free` suite，如果未来 suite 被传入 runner 会 double-free。 | 改用 `try..finally` 或让 runner 接管所有权。 |
| R4-11 | test_lifecycle.pas | `DisposeTableEntries` 手动清理与框架的 `CleanupTableAllocations` 职责重叠。 | 测试中使用框架提供的清理方法，避免手动管理。 |

### Info

| ID | 文件 | 问题 |
|----|------|------|
| R4-12 | expect.pas | `ToNotBeNear` 直接翻转 `FNegated`，与 `Not_()` 模式不一致。 |
| R4-13 | README.md | 架构段落的行数统计已过时。 |
| R4-14 | README.md | README 声称 `Not_()` "auto-resets after each To* call" 但代码并未实现此行为。 |

---

## Round 3 — 50 findings (8047321cb 之前)

> 审查时间: 2026-06-21
> 审查范围: 全部 18 个源文件
> 审查方法: Claude 手动逐文件审查
> 后续: 7-batch Codex 修复已全部落地 (68eb06ff6)

**汇总**: 50 findings (2 Critical, 11 Medium, 22 Low, 15 Info)
**状态**: Critical 全部修复，Medium/Low/Info 部分修复，详见 Codex Fix Plan。
**Round 5 纠正**: M-03 已修复、L-09 不成立、L-14 已修复。

### Critical (全部已修复)

| ID | 文件 | 问题 | 修复状态 |
|----|------|------|----------|
| C-01 | runner.parallel.pas | `TimeoutWorker` use-after-free：`TTimeoutRec` 是栈变量，worker 线程可能在 `ParallelWorkerProc` 返回后仍访问它 | ✅ 已修复 — 改为堆分配 `PTimeoutRec`，join 路径由调用方 Dispose，timeout 路径由 worker self-Dispose |
| C-02 | runner.parallel.pas | `ParallelWorkerProc` 中 `R^.Res^` 写入无同步保护 | ✅ 已修复 — 写入移入 mutex 保护区域 (已降级为 P2 防御性修复，每个 worker 写独立 slot) |

### Medium (部分已修复)

| ID | 文件 | 问题 | 修复状态 |
|----|------|------|----------|
| M-01 | check.pas | `CheckMethodCalled` / `CheckMethodNotCalled` 未验证 `AMethod <> nil` | 未修复 — P2 |
| M-02 | runner.pas | `CleanupTableAllocations` 未处理 `SubTests` 字段 | 未修复 — P2 |
| M-03 | runner.pas | `RunParallelWithResult` 不调用 `CleanupTableAllocations`，TestTable 泄漏 | ✅ 已修复 (R5 纠正) — L739 已有调用 |
| M-04 | discovery.pas | `DiscoverTests` 每次创建新 suite 而非复用，大项目有分配压力 | 未修复 — P3 |
| M-05 | runner.context.pas | `Execute` 内 `LIsSubTest` 变量声明但从未使用 | 未修复 — P2 |
| M-06 | output.pas | `JsonEscape` 不处理控制字符 (#0-#31) | ✅ 已修复 — 添加 `\b`, `\f`, `\r`, `\u00XX` 处理 |
| M-07 | mock.pas | `GetReturnInt` 用 `StrToInt64` 无 try-except，无效输入抛异常 | ✅ 已修复 — 改为 `TryStrToInt64` |
| M-08 | mock.pas | `GetReturnBool` 大小写敏感比较，`'True'` 返回 false | ✅ 已修复 — 改为 `SameText` |
| M-09 | output.tap.pas | TAP 计划行格式 `1..N` 可能在有 skip 时与实际不符 | 未修复 — P3 |
| M-10 | runner.pas | `CleanupTableAllocations` 的 nil-before-Dispose 模式增加复杂度 | Won't fix — 有文档说明原因 |
| M-11 | runner.parallel.pas | `TimeoutWorker` 的 `Sleep(10)` 粒度太细，CPU 浪费 | 未修复 — P3 |

### Low

| ID | 文件 | 问题 | 修复状态 |
|----|------|------|----------|
| L-01 | check.pas | `CheckFalse` 消息写 "expected false" 而非 "expected condition to be false" | 未修复 |
| L-02 | check.pas | `CheckSame` 使用 `Pointer` 比较，跨平台可能有对齐问题 | 未修复 |
| L-03 | expect.pas | `ToBeGreaterThan` 等比较方法无 `ToBeGreaterOrEqual` 等变体 | 未修复 |
| L-04 | expect.pas | `ToMatch` 正则每次调用都重新编译 | 未修复 |
| L-05 | expect.pas | `ToContain` 对字符串的子串检查区分大小写 | 未修复 |
| L-06 | expect.pas | `ToStartWith` / `ToEndWith` 只支持字符串，不支持 `TBytes` | 未修复 |
| L-07 | output.pas | `MatchesGlob` 不支持 `{a,b}` brace expansion | 未修复 |
| L-08 | output.pas | `MakeValidUtf8` 替换策略激进，合法 UTF-8 边缘情况可能误替换 | 未修复 |
| L-09 | runner.context.pas | `RunSubTests` 不支持嵌套子测试（只支持一层） | ✅ 不成立 (R5 纠正) — `RunNested` + 递归已支持 |
| L-10 | runner.parallel.pas | 并行模式下 `AfterEach` 在 worker 线程执行，可能有线程安全问题 | 未修复 |
| L-11 | base.pas | `TTestEntry.Fixture` 字段从未被使用 | 未修复 |
| L-12 | discovery.pas | `TTestFixure` 拼写错误（应为 `TTestFixture`） | 未修复 — breaking change |
| L-13 | check.pas | `CheckNear` 默认 epsilon 1e-6 对 `Single` 类型可能太严格 | 未修复 |
| L-14 | check.pas | `CheckContains` 对空 needle 的行为未定义 | ✅ 已修复 (R5 纠正) — L197-198 显式处理 + 6 测试覆盖 |
| L-15 | expect.pas | `ToBeType` / `NotToBeType` 中 `TTypeInfo` 比较只比较 Kind，不比较 Name | 未修复 |
| L-16 | runner.pas | `RunWithResult` 的 `--filter` 不支持通配符 | 未修复 |
| L-17 | output.pas | ANSI 输出在非 TTY 环境下仍输出颜色码 | 未修复 |
| L-18 | mock.pas | `TMockMethodStub` 的 `WithArgs` 验证只比较第一个参数 | 未修复 |
| L-19 | test_runner.pas | 5 个 `CheckEqual(Int64, Int64)` 可以用 `CheckSame` 测试引用类型 | Won't fix |
| L-20 | test_output.pas | `TestMatchesGlob` 缺少空字符串输入的边界测试 | 未修复 |
| L-21 | test_output.pas | ANSI 测试的 `Pos(#27, ...)` 只检查 ESC 字符存在，不验证完整序列 | 未修复 |
| L-22 | output.json.pas | `FormatJsonTime` 输出 ms 精度但输入是秒，截断可能丢失精度 | 未修复 |

### Info

| ID | 文件 | 问题 |
|----|------|------|
| I-01 | check.pas | `CheckEqual(string, string)` 用 `=` 比较，不显示 diff（需用 `Expect` API） |
| I-02 | expect.pas | `TExpectation` 每次 `To*` 创建新的消息字符串，热路径有分配压力 |
| I-03 | output.pas | `JUnitTime` 只输出秒，Jenkins 等工具可能期望 ms |
| I-04 | runner.pas | `RunWithResult` 的 finally 块中 `RestoreConsoleMode` 可能在非 Windows 上是 no-op |
| I-05 | base.pas | `TTestEntry.Status` 字段是 public，外部可直接修改跳过状态机 |
| I-06 | runner.parallel.pas | 并行 worker 数量硬编码为 `CPUCount`，无用户配置选项 |
| I-07 | test_runner.pas | 测试中用 `Sleep(50)` 等待重试，CI 慢机器上可能不够 |
| I-08 | discovery.pas | `DiscoverTests` 只扫描 published 方法，不支持 class procedure |
| I-09 | check.pas | `CheckIs` / `CheckNotIs` 不支持接口类型检查 |
| I-10 | output.tap.pas | TAP 的 YAML block 只在有 diagnostics 时输出，空消息时省略 |
| I-11 | mock.pas | `TMockMethodStub` 的 `Times` 验证在 `CalledWith` 失败后仍执行 |
| I-12 | test_mock.pas | mock 测试不验证 `FreeAll` 后 stub 内存是否释放 |
| I-13 | runner.pas | `ConsoleModeSaved` 变量在非 Windows 上始终为 False |
| I-14 | runner.context.pas | `GetCurrentTestName` 在非测试执行上下文中返回空字符串 |
| I-15 | output.pas | `JsonEscape` 的 `\u00XX` 格式假设所有平台的 `Ord(C)` 一致 |

---

## Round 2 — 归档

> 见 `findings.md`

## Round 1 — 归档

> 见 `findings.md`
