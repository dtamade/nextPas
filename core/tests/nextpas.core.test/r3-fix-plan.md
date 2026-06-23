# R3 Fix Plan — 全量执行

**目标**: 47 项 confirmed findings 全部处理（3 项 refuted 已排除）
**执行顺序**: 按依赖关系和风险分 6 批，每批自包含

---

## 批次 1：P0 运行时 bug 修复（4 项）

### F01: 并行子测试计数修复 [R3-01修正]
- **文件**: `core/src/nextpas.core.test.runner.parallel.pas` line 212
- **修复**: `R^.Pass^ := R^.Pass^ + 1` → `R^.Skip^ := R^.Skip^ + 1`
- **验证**: `test_parallel` 检查 skip 计数正确

### F02: 并行 afterEach LFailMsg [R3-02]
- **文件**: `core/src/nextpas.core.test.runner.parallel.pas` line 314
- **修复**: 在 `LStatus := tsError` 后加 `LFailMsg := 'afterEach failed: ' + E.Message`
- **验证**: `test_parallel` 新增 afterEach fail 检查 LFailMsg

### F03: MemoryBarrier LDummy 初始化 [R3-06]
- **文件**: `core/src/nextpas.core.test.runner.parallel.pas` MemoryBarrier
- **修复**: `var LDummy: LongInt` → `var LDummy: LongInt = 0`
- **验证**: 编译通过，无 warning

### F04: Serial beforeEach skip 泄漏检查 [R3-12]
- **文件**: `core/src/nextpas.core.test.runner.pas` ~line 444
- **修复**: ETestSkipped catch 块 Continue 前加 `ReportLeakIfAny`
- **验证**: `test_runner` 通过

---

## 批次 2：P1 源码修复 + 小改进（5 项）

### F05: TTestFixure 拼写修正 [R3-16]
- **文件**: discovery.pas, runner.pas, test_runner.lpr（全局搜索）
- **修复**: `TTestFixure` → `TTestFixture`，所有引用处同步
- **验证**: 编译通过

### F06: runner.pas 未使用 uses 移动 [R3-14]
- **文件**: `core/src/nextpas.core.test.runner.pas` interface uses
- **修复**: `nextpas.core.test.mock` 和 `nextpas.core.test.context` 移到 implementation uses
- **验证**: 编译通过

### F07: SafeRelease 不吞异常 [R3-28]
- **文件**: `core/src/nextpas.core.test.runner.parallel.pas`
- **修复**: SafeRelease 的 except 块改为 `WriteLn(StdErr, ...)` 或 log
- **验证**: 编译通过

### F08: TTestRunner.Add const 参数 [R3-34]
- **文件**: `core/src/nextpas.core.test.runner.pas`
- **修复**: `var AEntry` → `const AEntry`
- **验证**: 编译通过

### F09: CreatePool 参数使用 [R3-26]
- **文件**: `core/src/nextpas.core.test.runner.pool.pas`
- **修复**: 使用 `AWorkers` 参数控制线程数，而不是忽略它
- **验证**: 编译通过

---

## 批次 3：P1 测试补全（10 项）

### F10: RunAllParallelWithResult 测试 [R3-08]
- **文件**: `test_parallel/test_parallel.lpr`
- **内容**: 直接调用 RunAllParallelWithResult，验证 filter/setup/beforeEach/afterEach

### F11: ITestContext.Fail/Skip 测试 [R3-09]
- **文件**: `test_subtests/test_subtests.lpr`
- **内容**: 捕获 EAssertionFailed/ETestSkipped，验证 Message/Reason 字段

### F12: TAP/JSON Duration 测试 [R3-10]
- **文件**: `test_output/test_output.lpr`
- **内容**: 构造 Duration > 0 的 TTestResult，检查 `# duration_ms:` 和 `"durationMs"`

### F13: TAP 多行 YAML 测试 [R3-11]
- **文件**: `test_output/test_output.lpr`
- **内容**: ErrorMsg 含换行符，检查 TAP `|-` block scalar 格式

### F14: AfterEach 失败路径测试 [R3-13]
- **文件**: `test_subtests/test_subtests.lpr`
- **内容**: AfterEach 里调 Fail()，验证传播到父测试

### F15: 子测试 Duration 测试 [R3-17]
- **文件**: `test_subtests/test_subtests.lpr`
- **内容**: 检查子测试 TTestResult.Duration > 0

### F16: Closure + Retry 测试 [R3-23]
- **文件**: `test_parallel/test_parallel.lpr`
- **内容**: closure + retryCount 组合

### F17: Timeout 真正触发测试 [R3-07/R3-21]
- **文件**: `test_runner/test_runner.lpr`
- **内容**: 极短 timeout + Sleep 触发 watchdog 超时

### F18: GStubRegistry 并发测试 [R3-15]
- **文件**: `test_mock/test_mock.lpr`
- **内容**: 多线程同时创建 TMockHelper（验证线程安全）

### F19: beforeEach skip 泄漏检查测试 [R3-12]
- **文件**: `test_runner/test_runner.lpr`
- **内容**: beforeEach skip 场景下内存泄漏报告验证

---

## 批次 4：P2 Check/Expect 安全修复（7 项）

### F20: CheckRaises nil 保护 [R3-32]
- **文件**: `nextpas.core.test.check.pas`
- **修复**: `EClass = nil` 时 raise 有意义的错误

### F21: CheckInRange 前置条件 [R3-33]
- **文件**: `nextpas.core.test.check.pas`
- **修复**: `AMin <= AMax` 断言

### F22: CheckInRange 类型扩展 [R3-40]
- **文件**: `nextpas.core.test.check.pas`
- **修复**: 文档说明仅支持 Int64，或加 overload

### F23: Not_.ToNotRaise 语义文档 [R3-30]
- **文件**: `nextpas.core.test.expect.pas`
- **修复**: 加强文档说明，或修正语义

### F24: GetReturnInt 非数字行为 [R3-31]
- **文件**: `nextpas.core.test.mock.pas` + `test_mock.lpr`
- **修复**: 明确行为规范并测试

### F25: ExpectDouble 跨类型测试 [R3-42]
- **文件**: `test_expect/test_expect.lpr`
- **内容**: `Expect(1.0).ToEqual(1)` 整数/浮点比较

### F26: ExpectNotStateReset 测试重命名 [R3-43]
- **文件**: `test_expect/test_expect.lpr`
- **修复**: 重命名为 `TestNotToNotRaiseIgnoresNegated`

---

## 批次 5：P2 输出 + 架构改进（12 项）

### F27: test_runner 统一输出风格 [R3-18]
- **文件**: `test_runner/test_runner.lpr`
- **修复**: Halt(1) 改为打印 "ALL PASSED"/"FAILED: N"

### F28: TAP/JSON 测试去重 [R3-19]
- **文件**: `test_output/test_output.lpr`
- **修复**: 合并重复的 multi-suite 测试

### F29: TAP tsError 测试 [R3-20]
- **文件**: `test_output/test_output.lpr`
- **内容**: 新增 tsError 状态的 TAP 输出检查

### F30: StringDiff 边界安全 [R3-22]
- **文件**: `nextpas.core.test.check.pas`
- **修复**: 验证 LPos 访问不越界

### F31: Duration 精度改进 [R3-03]
- **文件**: `core/src/nextpas.core.test.runner.parallel.pas`
- **修复**: beforeEach 失败时设 Duration := 0（与串行路径对齐语义）

### F32: TTestContext public→private [R3-27]
- **文件**: `nextpas.core.test.runner.context.pas`
- **修复**: 字段改 private，加 property 只读访问
- **注意**: 这是大改动，需同步所有使用处

### F33: VMT 可移植性断言 [R3-29]
- **文件**: `nextpas.core.test.mock.pas`
- **修复**: 加编译期断言验证 VMT 布局

### F34: ParseFilterFromArgs 提取 [R3-35]
- **文件**: `nextpas.core.test.runner.pas`
- **修复**: 提取公共 ParseFilterFromArgs 函数

### F35: 子测试失败计数区分 [R3-44]
- **文件**: `nextpas.core.test.runner.context.pas`
- **修复**: 区分 assertion 失败和异常的计数

### F36: MatchesFilter 精度 [R3-39]
- **文件**: `nextpas.core.test.runner.pas`
- **修复**: 支持精确匹配或通配符

### F37: JsonEscape UTF-8 安全 [R3-45]
- **文件**: `output.json.pas`
- **修复**: 逐字符扫描改逐 codepoint

### F38: ANSI facade 缓存优化 [R3-41]
- **文件**: `output.ansi.pas`
- **修复**: Write 直接输出，减少临时 string 分配

---

## 批次 6：P3 长期改进（11 项）

### F39: deprecated 单元清理 [R3-36]
### F40: settings.inc 清理 [R3-37]
### F41: TMock 线程安全文档 [R3-38]
### F42: GRetryCount suite 级 [R3-46]
### F43: GRetryCount 测试污染 [R3-50]
### F44: discovery stub 生命周期 [R3-47]
### F45: TableCase/TableProc 类型 [R3-48]
### F46: Timeout 泛型化 [R3-49]
### F47: COW 风险测试 [R3-25]
### F48: GExecState 文档 [R3-24]
### F49: TTestSuite COW 文档 [R3-25]

---

## 验证策略

每批完成后：
```bash
# 全套件验证
for dir in test_runner test_check test_expect test_mock test_output test_subtests test_parallel test_discovery test_advanced; do
  make -C core/tests/nextpas.core.test/$dir clean test
done
```

完成后更新 test-findings.md 标记状态。
