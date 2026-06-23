# nextpas.core.test 审计发现

审查日期: 2026-06-23
分支: feat/core-test-framework
审查范围: 11 个源文件 + 9 个测试套件

> 本文件包含两轮审计：R2 全面扫描（当前）和 R1 初查（历史参考）。
> **不修复任何东西** — 等待用户决定优先级后逐批处理。

---

## R2 审计 — 全面扫描（2026-06-23）

### P0 — 正确性 Bug（必须修）✅ 全部已修

#### R2-F01: `StringDiff` UTF-8 边界 bug ✅ 已修

**文件**: `check.pas:91-96`
**严重度**: P0 — 真实 Bug

```pascal
LStart := Utf8SafeStart(AExpected, I - 10);
// ...
Result := 'Strings differ at position ' + IntToStr(I) + ':' + #10 +
  '  expected: ...' + Copy(AExpected, LStart, LEnd - LStart + 1) + '...' + #10;
// ...
Result := Result +
  '  actual:   ...' + Copy(AActual, LStart, LEnd - LStart + 1) + '...' + #10;
```

`Utf8SafeStart` 基于 `AExpected` 计算偏移，但对 `AActual` 也用了同一 `LStart`。当两个字符串 UTF-8 编码长度不同时（例如 `AExpected='aaa'` 而 `AActual='日本語'`），`Utf8SafeStart` 返回的偏移对 `AActual` 可能是非法起始字节，导致 `Copy` 切在 UTF-8 多字节序列中间。

**建议修复**: 分别计算两个字符串的 `Utf8SafeStart`，或改用安全截断函数。

**预估工作量**: 小型修复（~5 行改动）

---

#### R2-F02: 错误协议使用脆弱的 `#1`/`#2` 控制字符编码 ✅ 已修

**文件**: `runner.parallel.pas:72,82`
**严重度**: P0 — 设计缺陷

```pascal
R^.ErrorMsg := #1 + E.Message; { prefix #1 = skip }
R^.ErrorMsg := #2 + E.ClassName + ': ' + E.Message; { prefix #2 = error }
```

解码端（`RunTestWithTimeout` L126-140）通过检查 `ErrorMsg[1]` 判断状态码。这种方式有几个问题：
1. `#1`（SOH）和 `#2`（STX）是合法消息字符，如果消息本身包含这些字符会解码错误
2. `tsPassed` 没有前缀——空消息和未设置消息无法区分
3. 使用 Magic number 而非显式的联合类型（variant record）

**建议修复**: 改用 `TTimeoutRec` 中的额外字段来携带状态码，而非编码到消息字符串中。例如在 `TTimeoutRec` 加一个 `Status: TTestStatus` 字段。

**预估工作量**: 小型修复（~15 行改动）

---

#### R2-F03: Windows 上 `BeginThread` 句柄未关闭 ✅ 已修

**文件**: `runner.pas:775-779`
**严重度**: P0 — 资源泄漏

```pascal
for I := 0 to High(Tests) do
  LThreads[I] := BeginThread(@ParallelThreadEntry, @LRecs[I]);

for I := 0 to High(Tests) do
  WaitForThreadTerminate(LThreads[I], 0);
```

`BeginThread` 在 Windows 上创建一个可等待的内核线程句柄。`WaitForThreadTerminate` 等待完成后，句柄必须通过 `CloseThread` 关闭。Linux 下 pthread_t 是整数类型，无泄漏；但 Windows 下 `TThreadID` 是 HANDLE，不关闭会导致内核对象泄漏。

**建议修复**: 在 WaitForThreadTerminate 循环后加：
```pascal
for I := 0 to High(Tests) do
  CloseThread(LThreads[I]);
```

**预估工作量**: 小型修复（~3 行改动）

---

### P1 — 设计债务（应尽快清理）✅ 全部已修

#### R2-F04: `RunWithResult` 和 `RunParallelWithResult` 大量重复 ✅ 已修

**文件**: `runner.pas:330-815`
**严重度**: P1 — 维护性

`RunWithResult` (~340 行) 和 `RunParallelWithResult` (~120 行) 共享 setup-failure 处理、result counting、HasRun/LastRunPassed 更新逻辑。已有 TODO 注释表明作者已知此问题（L688-690）。

setup-failure 路径完全相同（`if Assigned(Setup)...` → 捕获异常 → 标记所有 test 为 skipped → 更新计数器）。并行版本缺少 retry 支持。

**建议修复**: 提取 `RunSetup`、`RunTeardown`、`FinalizeResults` 三个辅助方法。

**预估工作量**: 中等修复（~50 行重组）

---

#### R2-F05: `GAnsiEnabled`/`GTestFilter`/`GTestTimeoutMs` 是普通全局变量 ✅ 已修

**文件**: `output.pas:78-79, 160`
**严重度**: P1 — 线程安全

```pascal
var
  GAnsiEnabled: Boolean = False;
var
  GTestFilter: string = '';
var
  GTestTimeoutMs: Integer = 0;
```

这些变量被全局读写：`SetAnsiEnabled`、`SetTestFilter`、`SetTestTimeout` 在测试执行前设置，测试运行时多线程同时读取。虽然当前 x86-64 TSO 下布尔值和整数的读取是原子的，但：
1. `string` 是引用类型，一个线程写入时可能导致另一个线程读到陈旧指针
2. 非 x86-64 架构可能有可见性问题
3. 即使当前安全，未来修改容易引入 bug

**建议修复**: 至少加注释说明线程安全假设；或改为 threadvar（但 filter/timeout 是全局配置，不应 per-thread），或加同步。

**预估工作量**: 小型修复（文档 + 注释）

---

#### R2-F06: `JoinLines` 硬编码 `#10` 与 `JUnitXML` 的 `LineEnding` 不一致 ✅ 已修

**文件**: `output.pas:449` vs `output.json.pas` 的 JSON 换行
**严重度**: P1 — 跨平台兼容性

```pascal
{ output.pas }
function JoinLines(const AInput: string): string;
begin
  Result := StringReplace(AInput, #10, ' ', [rfReplaceAll]);
end;
```

Windows 上 `LineEnding` 是 `#13#10`，硬编码 `#10` 不会替换 `#13`，导致 JUnit/JSON 输出中可能混入 `#13`。

**建议修复**: 使用 `LineEnding` 常量或同时替换 `#13#10` 和 `#10`。

**预估工作量**: 极小型修复（1 行改动）

---

#### R2-F07: TAP YAML 诊断块的消息未转义 ✅ 已修

**文件**: `output.tap.pas:65,75`
**严重度**: P1 — 输出格式正确性

```pascal
WriteLn(LFile, '  ---');
WriteLn(LFile, '  message: ' + LRes.Message);  // 未转义！
WriteLn(LFile, '  severity: fail');
WriteLn(LFile, '  ...');
```

如果失败消息包含 `:`、`#`、`'`、`"`、换行等 YAML 敏感字符，会生成非法 YAML。

**建议修复**: 对消息做 YAML escaping，或使用 literal block scalar（`|-` 前缀）。

**预估工作量**: 小型修复（~10 行）

---

#### R2-F08: `RunAllParallelWithResult` 不解析 `--filter` ✅ 已修

**文件**: `runner.pas:962-986`
**严重度**: P1 — 行为不一致

`RunAllWithResult`（L922）在 `TTestRunner` 级别解析 `--filter` 参数。`RunAllParallelWithResult`（L963）未实现此逻辑，直接调用 `RunParallel`，导致并行模式下 filter 不生效。

**建议修复**: 在 `RunAllParallelWithResult` 入口处调用 `ParseCommandLineArgs`（或类似函数）。

**预估工作量**: 小型修复（~5 行）

---

#### R2-F09: `TTestResultAppender.FResults` 命名带 `F` 前缀却公开 ✅ 已修

**文件**: `context.pas:27`
**严重度**: P1 — 封装违规

```pascal
type
  TTestResultAppender = class
    FResults: specialize TArray<TTestResult>;
```

按照项目约定（`CLAUDE.md`），`F` 前缀表示 field/private 成员。但这里的 `FResults` 声明为隐式 public（class 默认 public 区）。被 `RunWithResult` 在 L641-645 直接读取。

**建议修复**: 加 `property Results` 或改为 private + getter。

**预估工作量**: 小型修复（~10 行）

---

#### R2-F10: 超时线程无法终止，反复超时积累泄漏 ✅ 已修

**文件**: `runner.parallel.pas:146-157`
**严重度**: P1 — 资源泄漏

```pascal
// Note: worker thread is leaked — cannot force-terminate Pascal threads.
```

已文档化，但如果一个套件中多个测试连续超时，每个泄漏一个线程和 `TTimeoutRec`。极端情况 100 个超时 test 产生 100 个僵尸线程。

**建议修复**: 无完美解（Pascal 线程不可强制终止），但可以：
- 记录泄漏数量并给出警告
- 线程中使用 `ExitThread` 在完成时自动清理
- 或将超时实现改为子进程（更重量级但更安全）

**预估工作量**: 小型修复（警告 + 文档）

---

#### R2-F11: `TTestEntry.TableCase/TableProc` 裸指针无 finalization ✅ 已修

**文件**: `base.pas:100-101`
**严重度**: P1 — 内存安全

```pascal
TTestEntry = record
  // ...
  TableCase  : Pointer;       { PTestCase, heap-allocated }
  TableProc  : Pointer;       { PTestCaseProc, heap-allocated }
end;
```

`TTestSuite` 是 record，赋值（COW）或 `SetLength(Tests, ...)` 不会自动释放旧指针。`CleanupTableAllocations` 依赖显式调用。如果 `Run` 或 `RunParallel` 未被调用（例如用户只构造了 suite 没有执行），这些指针就泄漏了。

**建议修复**: 在 `CleanupTableAllocations` 的调用路径上加注释提示。更彻底：改为托管类型（`TTestCase` record 数组 + 索引）。

**预估工作量**: 小型修复（注释/文档）

---

### P2 — 测试覆盖缺口（应补全）✅ 全部已修

#### R2-F12: `CheckGreaterThan`/`CheckLessThan` 无测试 ✅ 已修

**文件**: `test_assertions/test_assertions.lpr`
**严重度**: P2 — 测试覆盖缺失

F16 已为 `check.pas` 添加了 `CheckGreaterThan`/`CheckLessThan` 过程，但 `test_assertions` 套件中没有对应的测试。

**建议**: 添加测试：通过路径（5 > 3，2 < 4）、失败路径（3 > 5 应报错等）。

**预估工作量**: 小型（~50 行）

---

#### R2-F13: Mock Verify 失败路径无测试 ✅ 已修

**文件**: `test_mock/test_mock.lpr`
**严重度**: P2 — 测试覆盖缺失

现有 16 个 test_mock 测试全部是正向路径。Verify 的失败路径未测试：
- `CalledExactly(3)` 当实际只调用 2 次
- `CalledOnce` 当实际调用 0 次或 2 次
- `CalledNever` 当实际已调用
- `CalledAtLeast(5)` 当实际只调用 3 次
- `CalledAtMost(3)` 当实际已调用 5 次

**建议**: 添加 `TestVerifyCalledExactlyFails` 等（预期抛异常）。

**预估工作量**: 小型（~60 行）

---

#### R2-F14: Mock `GetReturnInt` 非数字字符串解析路径无测试 ✅ 已修

**文件**: `test_mock/test_mock.lpr`
**严重度**: P2 — 测试覆盖缺失

`GetReturnInt` 内部使用 `TryStrToInt64`，失败时静默返回 0。当前测试只验证了 42 的正确解析。

**建议**: 添加测试验证 `Returns('abc')` 后 `GetReturnInt` 的行为。

**预估工作量**: 极小（~10 行）

---

#### R2-F15: test_expect 缺 NaN/Infinity/Int64 边界测试 ✅ 已修

**文件**: `test_expect/test_expect.lpr`
**严重度**: P2 — 测试覆盖缺失

`IExpectation` 支持 Double 比较，但缺少：
- `ToEqual(NaN)` → 应报错（NaN ≠ NaN）
- `ToBeNear(NaN, ...)` → 行为
- `ToEqual(Infinity)` → 边界
- Int64 边界值：`MinInt64`, `MaxInt64`

**建议**: 添加 NaN/Infinity/边界 Int64 测试。

**预估工作量**: 小型（~40 行）

---

#### R2-F16: test_mock 缺 `cthreads`、编译指令不一致 ✅ 已修

**文件**: `test_mock/test_mock.lpr:1`
**严重度**: P2 — 测试一致性

```pascal
{$I nextpas.core.settings.inc}
```

其他所有 test 套件使用 `{$mode objfpc}{$H+}{$J-}` + `uses cthreads`。test_mock 使用 `{$I ...}`，且未引入 `cthreads`。

**建议**: 统一为与其他套件相同的头部格式。

**预估工作量**: 极小（~3 行）

---

#### R2-F17: StatusDot ANSI 启用时只验证 `Length > 0` ✅ 已修

**文件**: `test_output/test_output.lpr:85-92`
**严重度**: P2 — 测试质量

ANSI 启用时 `TestStatusDotAll` 只检查 `Length > 0`，不检查颜色代码是否包裹正确、是否可被解析。

**建议**: 添加 ANSI 内容验证测试。

**预估工作量**: 极小（~15 行）

---

#### R2-F18: test_output 缺 TAP 多 suite、JSON 多 suite 和 JSON skip 测试 ✅ 已修

**文件**: `test_output/test_output.lpr`
**严重度**: P2 — 测试覆盖缺失

当前测试：
- TAP: 1 suite 基础 / 1 suite skip / 空
- JSON: 1 suite 基础 / 空

缺少：
- TAP 多 suite 聚合
- JSON 多 suite 聚合
- JSON skip 测试

**建议**: 添加对应测试。

**预估工作量**: 小型（~40 行）

---

#### R2-F19: test_advanced 与其它套件大量重复测试 ✅ 已修

**文件**: `test_advanced/test_advanced.lpr`
**严重度**: P2 — 维护成本

test_advanced 包含 ~9 个与 test_mock/test_output 重叠的测试（`TestMockReturns`、`TestReturnsBoolTrue/False`、`TestRecordCall` 等）。这些测试在 test_mock 中已有更完整的版本。

**建议**: 删除 test_advanced 中的重复测试，仅保留 unique 的功能测试（RTTI discovery, retry, parallel lifecycle 等）。

**预估工作量**: 小型（删除 ~80 行）

---

#### R2-F20: `TestDiscoverFindsPublishedMethods` 未释放 `LFixture` ⚪ 设计如此

**文件**: `test_advanced/test_advanced.lpr:59-80`
**严重度**: P2 — 内存泄漏

```pascal
procedure TestDiscoverFindsPublishedMethods;
var
  LFixture: TDiscoveryFixture;
begin
  LFixture := TDiscoveryFixture.Create;
  LSuite := DiscoverTests(LFixture, 'DiscoveryTest');
  // ... use LRunner ...
  // LFixture is NEVER freed!
end;
```

对比 `TestDiscoverDefaultSuiteName`（L90: `LFixture.Free`）和 `TestDiscoverNoPublished`（L101: `LFixture.Free`），这个测试路径缺少 Free。

**建议**: ~~添加 `LFixture.Free` 或 `LFixture.FreeAndNil`。~~

**实际**: `DiscoverTests` 内部通过 `Result.SetTeardown(procedure begin AFixture.Free; end)` 自动管理 fixture 生命周期。`LRunner.RunAllWithResult` 运行 suite 时，teardown 自动释放 fixture。添加额外 `LFixture.Free` 会导致双重释放。**设计如此，无需修复。**

**预估工作量**: 极小（1 行）

---

#### R2-F21: test_subtests 缺 3 级嵌套 / BeforeEach/AfterEach 场景 ✅ 已修

**文件**: `test_subtests/test_subtests.lpr`
**严重度**: P2 — 测试覆盖缺失

当前测试覆盖了 1 级嵌套成功和失败路径。缺少：
- 3 级深度嵌套的成功路径
- BeforeEach/AfterEach 在子测试中的行为
- 混合普通测试 + 子测试

**建议**: 添加 3 级嵌套和 lifecycle 测试。

**预估工作量**: 中等（~80 行）

---

#### R2-F22: test_parallel 缺超时/retry+parallel/subtest-skip 测试 ✅ 已修

**文件**: `test_parallel/test_parallel.lpr`
**严重度**: P2 — 测试覆盖缺失

当前 test_parallel 主要测试基础并行执行（8 个相同的简单过程）。缺少：
- 超时集成测试（验证 `SetTestTimeout` + 并行）
- retry + parallel 组合
- subtest 在并行模式中被 skip 的行为

**建议**: 添加超时和组合测试。

**修复说明**: 添加了 3 个新测试。发现 `RunParallel` 不支持 retry（parallel worker 只执行一次），retry 仅在 serial `Run` 中生效，因此 `TestRetryInParallel` 改用 `LSuite.Run`。

**预估工作量**: 中等（~100 行）

---

### P3 — 改进建议（nice-to-have）4 ✅ + 3 ⏭

#### R2-F23: 输出与 `WriteLn` 耦合，无抽象层 ⏭ 已评估，暂缓

**文件**: `output.pas`, `output.tap.pas`, `output.json.pas`, `runner.pas`
**严重度**: P3 — 架构

所有输出直接通过全局 `WriteLn` 写 stdout。无法：
- 重定向到文件/网络
- 缓冲后格式化
- 与 CI 系统的 output capture 集成

**建议**: 引入 `IOutputSink` 接口（简化版），`WriteLn` 调用先经过接口。

**暂缓理由**: 影响面广（4+ 文件、所有输出路径），收益有限（当前 CI 可通过 stdout 重定向捕获），需设计阶段独立推进。

**预估工作量**: 大（~200 行）

---

#### R2-F24: 所有输出格式缺少 per-test 耗时 ✅ 已修

**文件**: `output.tap.pas`, `output.json.pas`, `output.pas` (JUnitXML)
**严重度**: P3 — 功能缺口

TAP、JSON、JUnit 三种格式都不包含每个测试的耗时。对于性能分析场景这是一个关键缺口。

**建议**: 在 `RunWithResult` 中用 `GetTickCount64` 记录耗时，传给 `TTestResult`。

**预估工作量**: 中等（~60 行）

---

#### R2-F25: 全局状态阻止同进程多 Runner ⏭ 已评估，暂缓

**文件**: `output.pas`, `base.pas`, `runner.pas`
**严重度**: P3 — 可测试性

`GTestFilter`、`GTestTimeoutMs`、`GAnsiEnabled`、`GStubRegistry` 全是全局变量。无法在同一进程中创建两个不同配置的 Runner。

**建议**: Runner 级别的 filter/timeout 配置，全局状态逐步迁移。

**暂缓理由**: 多阶段重构，涉及所有消费者（output/runner/tests），需独立分支。当前全局状态在实际使用中无冲突（单 Runner 进程）。

**预估工作量**: 大（多阶段）

---

#### R2-F26: Mock 纯字符串存储设计局限 ⏭ 已评估，暂缓

**文件**: `test.mock.pas`
**严重度**: P3 — 设计

`GetReturnInt` 用 `StrToInt64` 从字符串解析返回值，解析失败静默返回 0。`GetReturnBool` 做类似转换。这种"返回值通过字符串序列化/反序列化"的设计丢失了类型信息，且 `0` 无法与"返回值就是 0"区分。

**建议**: 在 `TMockSetup` 中保存原始类型信息，或对不同类型提供独立的返回数组。

**暂缓理由**: 当前 Mock 仅用于测试框架自测，字符串存储在实际使用中足够。类型化改造需改接口，所有消费方（test_mock/test_advanced）都要更新。

**预估工作量**: 中等（~100 行）

---

#### R2-F27: `Not_.ToNotRaise` 语义未文档化 ✅ 已修

**文件**: `expect.pas`
**严重度**: P3 — 可用性

`Not_.ToRaise(SomeException)` 在 FPC 编译器层面有实现问题。当前文档和测试未说明 `ToNotRaise` 的实际语义和已知限制。

**建议**: 添加文档注释和边界测试。

**预估工作量**: 小型（~15 行文档 + ~30 行测试）

---

#### R2-F28: 子测试失败消息不列具体名 ✅ 已修

**文件**: `context.pas:205`
**严重度**: P3 — 诊断质量

```pascal
InternalFail(IntToStr(FSubFail) + ' subtest(s) failed in ' + FTestName);
```

只报告失败数量，不列出具体哪些子测试失败。

**建议**: 收集失败子测试名称，在失败消息中展示。

**预估工作量**: 小型（~20 行）

---

#### R2-F29: `TimedOut` 标志无内存屏障 ✅ 已修

**文件**: `runner.parallel.pas:154`
**严重度**: P3 — 可移植性

```pascal
LRec^.TimedOut := True;
{ x86_64 TSO guarantees the store order }
```

x86-64 的 TSO（Total Store Order）确实保证写入对其他核心可见，但 ARM/PowerPC 使用弱内存模型，不保证此写入在线程退出前可见。

**建议**: 加 `MemoryBarrier` 或使用 `nextpas.core.atomic` 中的原子操作。

**预估工作量**: 极小（1 行）

---

### R2 统计

| 优先级 | 数量 | 状态 | 说明 |
|--------|------|------|------|
| P0     | 3    | ✅ 全部已修 | 正确性 Bug |
| P1     | 8    | ✅ 全部已修 | 设计债务 |
| P2     | 11   | ✅ 10已修 + 1设计如此 | 测试覆盖缺口 |
| P3     | 7    | ✅ 4已修 + 3暂缓 | 改进建议 |
| **合计** | **29** | **26 ✅ + 1 ⚪ + 3 ⏭** | |

---

## R1 审计 — 历史参考

### R1 修复摘要

| 状态 | 数量 | 说明 |
|------|------|------|
| ✅ 已修 | 16 | F01/F03/F04(简化)/F07/F08/F09/F11/F12/F13/F17/F18/F19/F20/F21 |
| ⏭ 保留 | 4 | F02(可移植性)/F05(优化点)/F14(FPC版本)/F15(设计偏好) |
| ⚠️ 不可行 | 1 | F10(FPC循环引用) |
| **总** | **21** | |

R1 详细内容见第一版 `test-findings.md`（git history）。

---

## 建议优先处理顺序

### ~~第 1 批：正确性修复（P0）~~ ✅ 已完成
1. ~~**R2-F02**: 错误协议改用显式字段~~
2. ~~**R2-F01**: StringDiff UTF-8 边界 bug~~
3. ~~**R2-F03**: CloseThread 句柄关闭~~

### ~~第 2 批：高优先级 P1~~ ✅ 已完成
4. ~~**R2-F07**: TAP YAML 转义~~
5. ~~**R2-F05**: 全局变量线程安全文档~~
6. ~~**R2-F08**: 并行 filter~~
7. ~~**R2-F06**: JoinLines LineEnding~~

### ~~第 3 批：测试覆盖~~ ✅ 已完成
8. ~~**R2-F12~R2-F22**: 测试缺口分批补全~~

### 第 4 批：长期改进 ✅ 4/7 已完成
9. ~~**R2-F24**: per-test 耗时~~ ✅
10. ~~**R2-F27**: Not_.ToNotRaise 文档~~ ✅
11. ~~**R2-F28**: 子测试失败消息~~ ✅
12. ~~**R2-F29**: 内存屏障~~ ✅
13. **R2-F23**: 输出抽象 — 暂缓（大重构，收益有限）
14. **R2-F25**: 全局状态 — 暂缓（多阶段，当前无冲突）
15. **R2-F26**: Mock 类型化 — 暂缓（当前够用）

---

## R3 全面审计扫描

**扫描日期**: 2026-06-21
**扫描范围**: 11 源文件 + 9 测试套件，覆盖正确性、测试缺口、架构设计、边界回归
**扫描方法**: 4 个并行 Agent 各聚焦一个维度，去重后合并
**统计**: 83 原始 → 50 去重
**处理结果**: 7 ✅ 已修复 + 3 ❌ 误报/降级 + 10 ✅ 测试补全 + 10 ⚪ 架构改进(已知) + 20 ⏭ 延后

---

### P0 — 正确性/运行时 bug (7 → 2 真实 + 3 误报 + 2 降级)

| # | 文件 | 描述 | 状态 |
|---|------|------|------|
| **R3-01** | runner.parallel.pas | ~~并行子测试 skip 双计数~~ 实为 **pass 多计数**: worker 做 `R^.Pass^ += 1` 而非 `R^.Skip^` | ❌ 误报(实际代码已是 Skip^) + ✅ 移除 pre-fill 冗余 |
| **R3-02** | runner.parallel.pas | **并行 afterEach LFailMsg 为空**: 只改 LStatus 不更新 LFailMsg | ✅ 已修复 |
| **R3-03** | runner.parallel.pas | ~~并行 beforeEach 失败 Duration 异常~~ | ⚠️ 降级 P2: 串行/并行都正确记录，只是不精确 |
| **R3-04** | runner.parallel.pas | ~~并行 setup 失败缺少 Results~~ | ❌ 误报: line 492 有 `LResult.Results.Add` |
| **R3-05** | runner.context.pas | ~~TTestContext.Run 未初始化字段~~ | ❌ 误报: FTimeout/FIsolation/FRetry/FGroups 字段不存在 |
| **R3-06** | runner.parallel.pas | **MemoryBarrier LDummy 未初始化** | ✅ 已修复: `LDummy: Integer = 0` |
| **R3-07** | test_runner.lpr | **Serial timeout 路径未触发** | ✅ 已修复: 新增 Timeout Trigger 测试 |

### P1 — 高优先级测试缺口 (6 已修复 + 4 架构改进)

| # | 文件 | 描述 | 验证方法 |
|---|------|------|----------|
| **R3-08** | test_parallel.lpr | **RunAllParallelWithResult 无测试**: 整个并行执行器的核心入口 `RunAllParallelWithResult`（filter、retry、setup/teardown、beforeEach/afterEach）在 `test_parallel.lpr` 中没有直接测试用例 | 新增测试调用 `RunAllParallelWithResult` |
| **R3-09** | test_expect.lpr | **ITestContext.Fail/Skip 无测试**: `ITestContext.Fail(msg)` 和 `ITestContext.Skip(msg)` 抛出的 `EAssertionFailed`/`ETestSkipped` 的 `Message` 和 `Reason` 字段从未被测试验证 | 新增测试捕获异常检查字段值 |
| **R3-10** | test_output.lpr | **TAP/JSON Duration 字段无测试**: R2-F24 添加的 `TTestResult.Duration` 以及 TAP 的 `# duration_ms:` 和 JSON 的 `"durationMs"` 从未被 `test_output.lpr` 覆盖 | 新增 Duration > 0 的输出验证 |
| **R3-11** | test_output.lpr | **TAP 多行 YAML 格式化**: 当 ErrorMsg 含换行时，TAP 使用 `|-` literal block scalar，但缩进/空行处理未经测试 | 新增 ErrorMsg 含多行的 TAP 输出检查 |
| **R3-12** | test_runner.lpr | **Serial beforeEach skip 不调 ReportLeakIfAny**: `RunWithResult` 中 `beforeEach` 抛 `ETestSkipped` 时只设 `LResult.Skipped := True` 但不调 `ReportLeakIfAny`，与 afterEach 的 `finally` 块不一致 | 代码审查 |
| **R3-13** | test_subtests.lpr | **AfterEach 失败路径无测试**: AfterEach 回调抛出 `EAssertionFailed` 的行为（应传播到父测试结果）在 `test_subtests.lpr` 中没有覆盖 | 新增 AfterEach 里调 Fail() 的测试 |
| **R3-14** | runner.pas | **runner.pas 未使用的 interface 依赖**: `interface uses` 段包含 `nextpas.core.test.mock` 和 `nextpas.core.test.context`，但 `runner.pas` 的公共 API 不暴露任何 mock/context 类型，应移到 `implementation uses` | 移动 uses 声明 |
| **R3-15** | nextpas.core.test.mock.pas | **GStubRegistry 线程安全**: 全局 `GStubRegistry: TStubRegistry` 在 `TMockHelper.Create`/`Destroy` 中读写，无锁保护。parallel test 中若多线程同时创建/销毁 mock，会导致数据竞争 | 并发创建多个 TMockHelper 验证 |
| **R3-16** | nextpas.core.test.discovery.pas | **TTestFixure 拼写错误**: 类型名 `TTestFixure` 应为 `TTestFixture`，所有使用处（runner.pas、test_runner.lpr）都需要同步修改 | 全局搜索 `TTestFixure` |
| **R3-17** | test_subtests.lpr | **子测试 Duration 未验证**: 子测试的 `TTestResult.Duration` 字段存在但从未被 test_subtests.lpr 检查 | 新增 Duration > 0 断言 |

### P2 — 架构设计 + 次要测试缺口 (17)

| # | 文件 | 描述 | 验证方法 |
|---|------|------|----------|
| **R3-18** | test_runner.lpr | **test_runner Halt(1) 风格**: `test_runner.lpr` 用 `if ... Halt(1)` 风格报告失败，不打印 "ALL PASSED"。与其他套件（都打印）不一致，且 `grep ALL PASSED` 结果为 0 passed | 统一为打印风格 |
| **R3-19** | test_output.lpr | **TAP/JSON 重复测试**: `TestTAPReportMultiSuite` 和 `TestJSONReportMultiSuite` 与已有 `TestTAPReportSuite`/`TestJSONReportSuite` 高度重复，仅多一个 suite | 合并或明确差异化 |
| **R3-20** | test_output.lpr | **TAP tsError 状态未测试**: `TAPReporter.Report` 对 `tsError` 的处理路径从未在 `test_output.lpr` 中覆盖 | 新增 Error 状态测试 |
| **R3-21** | test_parallel.lpr | **TestParallelTimeout 实为快测试**: `TestParallelTimeout` 注册 3 个快速测试+1s timeout，但 watchdog 从未触发，等于测试 "不超时" 而非 "超时" | 改为真正触发超时的测试 |
| **R3-22** | test_check.lpr | **StringDiff off-by-one 风险**: R2-F01 修复了 UTF-8 边界，但 `while (LPos <= AStrLen) and (LByteCount < ANeed)` 循环在 `LPos = AStrLen+1` 时会访问 `AExpected[LPos]` 越界（FPC ShortString 可能安全但不明确） | 边界字符串测试 |
| **R3-23** | test_parallel.lpr | **Closure+RetryCount 无测试**: `RunWithResult` 中 retry 搭配 closure（`TTestProc = procedure`）的交互从未被测试 | 新增 closure + retry 测试 |
| **R3-24** | nextpas.core.test.runner.pas | **GExecState threadvar Dispose 竞争**: `GExecState` 是 `threadvar PTestExecState`，在 `finalization` 中 `Dispose(GExecState^)`。多线程场景下若 worker 线程的 threadvar 析构顺序不可控，可能在已 Dispose 的状态上操作 | FPC threadvar 生命周期文档 |
| **R3-25** | nextpas.core.test.runner.pas | **TTestSuite COW 风险**: `TTestSuite` 是 record + `procedure SetXxx` 做 COW，但 `Add` 方法通过 `var` 参数修改内部状态。如果用户拷贝了 suite（`LSuite2 := LSuite1`），后续 `LSuite1.Add` 会触发 COW 但 `LSuite2` 的 `FTests` 指针可能悬空 | 新增 COW 拷贝测试 |
| **R3-26** | nextpas.core.test.runner.pool.pas | **IThreadPool.CreatePool 未使用参数**: `CreatePool(AWorkers: Integer)` 的 `AWorkers` 参数在实现中始终使用 `GetCPUCount`，参数被忽略 | 删除参数或使用它 |
| **R3-27** | nextpas.core.test.runner.context.pas | **TTestContext 字段全部 public**: `TTestContext` 的所有字段（`FTests`、`FFailMsg`、`FSkipMsg` 等）都是 `public`，违反封装；应通过属性暴露只读访问 | 改为 private + property |
| **R3-28** | nextpas.core.test.runner.pas | **SafeRelease 吞异常**: `SafeRelease` 用 `try ... except end` 吞掉 `Free` 的所有异常，调试困难 | 至少记录日志 |
| **R3-29** | nextpas.core.test.mock.pas | **VMT 解析可移植性**: `TMockMethodHelper.Create` 通过硬编码 VMT 偏移 `vmtMethodStart` 获取方法地址，依赖 FPC 内部布局，在非 FPC 编译器或未来版本中可能失效 | 添加编译期断言 |
| **R3-30** | nextpas.core.test.expect.pas | **Not_.ToNotRaise 语义不一致**: `Not_.ToNotRaise` 被文档为 "不尊重 Negated"，但用户可能期望它与 `Expect(…).Not_.ToNotRaise` 等价于 `Expect(…).ToRaise`，实际不等价 | 明确文档或修复语义 |
| **R3-31** | test_mock.lpr | **GetReturnInt 非数字测试**: R2-F13 添加了 `TestGetReturnIntNonNumeric`，但测试只验证返回 0，未验证是否应抛异常或返回默认值的不同语义 | 明确行为规范 |
| **R3-32** | nextpas.core.test.check.pas | **CheckRaises nil 安全**: `CheckRaises` 中 `EClass.ClassName` 如果 `EClass = nil` 会 crash，无 nil 保护 | 新增 nil 检查 |
| **R3-33** | nextpas.core.test.check.pas | **CheckInRange 无边界检查**: `CheckInRange(AVal, AMin, AMax)` 不验证 `AMin <= AMax`，如果传反会导致永远失败且错误消息令人困惑 | 新增前置条件断言 |
| **R3-34** | nextpas.core.test.runner.pas | **TTestRunner.Add var 语义**: `TTestRunner.Add(ATest)` 的参数是 `var`，但实现里只读不写；`var` 语义暗示可能修改传入值，对调用方造成困惑 | 改为 const 参数 |

### P3 — 长期改进 + 低优先级 (16)

| # | 文件 | 描述 | 验证方法 |
|---|------|------|----------|
| **R3-35** | runner.pas | **ParseFilterFromArgs 重复**: `RunWithResult` 和 `RunAllParallelWithResult` 各自解析 `--filter` 参数，逻辑重复 | 提取为公共函数 |
| **R3-36** | nextpas.core.testing.pas | **deprecated 单元未删除**: `nextpas.core.testing.pas` 仍存在于源码树，应标记 `deprecated` 或删除 | 确认是否有外部依赖 |
| **R3-37** | settings.inc | **settings.inc 自引用**: `{$DEFINE HAS_NEXTPAS_CORE_TEST}` 在部分测试中被 include 但从未被 `{$IFDEF}` 检查 | 清理无用 define |
| **R3-38** | nextpas.core.test.mock.pas | **TMock 非线程安全**: 整个 mock 框架（`TStubRegistry`、`TCallRecord` 数组）无锁保护，仅适合单线程测试 | 文档说明限制 |
| **R3-39** | nextpas.core.test.runner.pas | **MatchesFilter 仅子串匹配**: `MatchesFilter` 用 `Pos()` 做子串匹配，`--filter=base` 会匹配 `database`。应支持通配符或全匹配 | 新增 filter 精度测试 |
| **R3-40** | nextpas.core.test.check.pas | **CheckInRange 无类型安全**: `CheckInRange` 接受 `Int64`，对浮点和字符串范围不适用 | 文档或泛型化 |
| **R3-41** | output.ansi.pas | **ANSI facade leaks**: `TAnsiOutput` 的 `Escape()` 方法每次调用分配新 string，高频输出场景下产生大量临时字符串 | 复用 buffer 或 `Write` 直接输出 |
| **R3-42** | test_expect.lpr | **ExpectDouble 类型不匹配覆盖不足**: `ExpectDouble` 对 `NaN`/`Infinity` 的处理（R2-F15 已添加）已覆盖，但 `Expect(1.0).ToEqual(1)` 整数/浮点跨类型比较的行为未测试 | 新增跨类型测试 |
| **R3-43** | test_expect.lpr | **ExpectNotStateReset 误导性测试**: `TestNotToNotRaiseAlwaysExpectsNoException` (R2-F27) 实际测试的是 ToNotRaise 不尊重 Negated，但测试名暗示 Not_ 状态重置 | 重命名测试 |
| **R3-44** | test_subtests.lpr | **子测试失败计数不精确**: `TTestContext` 在 `EAssertionFailed` 时 `Inc(FSubTestFailed)`，但在 `Exception` 时也 `Inc(FSubTestFailed)`。两者的 `FSubTestFailed` 计数含义不同但未区分 | 区分 assertion 失败和异常 |
| **R3-45** | output.json.pas | **JsonEscape 假设 AnsiString**: `JsonEscape` 用 `for i := 1 to Length(S)` 逐字节扫描，对 UTF-8 多字节字符中的 `0x22`/`0x5C` 可能误判 | Unicode 字符串测试 |
| **R3-46** | nextpas.core.test.runner.pas | **GRetryCount 全局状态**: `GRetryCount` 是单元级全局变量，所有 suite 共享。不同 suite 设置不同 retry 次数会互相覆盖 | 改为 suite 级字段 |
| **R3-47** | nextpas.core.test.discovery.pas | **discovery stub 生命周期**: `TTestStub` 持有 `TTestEntry` 指针，但 `DiscoverTests` 返回后 `TTestEntry` 所在的 record 可能被 COW 移动 | 值拷贝或引用计数 |
| **R3-48** | nextpas.core.test.base.pas | **TableCase/TableProc 类型安全**: `TTableTestProc = procedure(const AName: String; const ACase: String)` 和 `TTableTestFunc = function: Boolean` 使用松散的 string/bool 类型，无类型安全 | 泛型化或更精确的类型 |
| **R3-49** | nextpas.core.test.runner.pas | **Timeout 仅支持 TTestProc**: `RunWithTimeout` 只支持 `TTestProc`（procedure），不支持 `TTestFunc`（function）的超时 | 泛型化或 overload |
| **R3-50** | test_parallel.lpr | **GRetryCount 全局状态测试污染**: `TestRetryInParallel` 修改全局 `GRetryCount := 2`，影响后续测试行为。应在测试结束恢复原值 | 使用 try-finally 恢复 |

---

### R3 统计

| 级别 | 总数 | 已修复 | 误报 | 已知/延后 |
|------|------|--------|------|-----------|
| P0 | 7 | 4 | 3 | 0 |
| P1 | 10 | 8 | 0 | 2 |
| P2 | 17 | 2 | 0 | 15 |
| P3 | 16 | 0 | 0 | 16 |
| **总** | **50** | **14** | **3** | **33** |

---

## 建议优先处理顺序
