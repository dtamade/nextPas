# nextpas.core.test — 全面审查 findings

审查日期: 2026-06-21
分支: feat/core-test-framework
审查范围: 11 个源文件 + 8 个测试套件

## 修复状态

| ID | 状态 | 说明 |
|----|------|------|
| F01 | ✅ 已修 | `ToNotBeNear` 改用 `Not_.ToBeNear` 创建副本 (7401b68f9) |
| F02 | ⏭ 保留 | `ParallelThreadEntry` 可移植性 — 当前 Linux x86-64 唯一目标 |
| F03 | ✅ 已修 | `DisposeTableEntries` 删除，由框架统一负责 (788783854) |
| F04 | ✅ 简化 | 保留双注册机制（设计合理），添加文档 |
| F05 | ⏭ 保留 | `TTestEntry` 空间浪费 — 低优先级优化点 |
| F06 | ✅ TODO | 添加了 TODO 注释标记代码重复 |
| F07 | ✅ 已修 | TAP/JSON 测试覆盖 — 3 TAP + 2 JSON 测试 |
| F08 | ✅ 已修 | Mock 测试覆盖 — 16 测试，Setup/Record/Verify/Returns 全覆盖 |
| F09 | ✅ 已修 | 并行 subtest skip 现计入 LSkip 统计 |
| F10 | ⚠️ 不可行 | FPC 循环前向引用阻止类型化，已添加文档说明 |
| F11 | ✅ 已修 | `MatchesGlob` 重写为迭代式（零 Copy 分配） |
| F12 | ✅ 已修 | `XmlEscape`/`JsonEscape` 预分配避免 O(n²) |
| F13 | ✅ 已修 | `AddLine` 提取到 `output.pas` 接口区供 TAP/JSON 共用 |
| F14 | ⏭ 保留 | `for-in` FPC 3.x — 当前使用 trunk 无影响 |
| F15 | ⏭ 保留 | epsilon 默认值 — 设计偏好 |
| F16 | ✅ 已修 | `CheckGreaterThan`/`CheckLessThan` 已添加到 `check.pas` |
| F17 | ✅ 已修 | 8 个重复过程合并为 1 个共享过程 |
| F18 | ✅ 已修 | `Add` var 参数语义说明精简 |
| F19 | ✅ 已修 | `LAppender.Free` 用 try/finally 保护 |
| F20 | ✅ 已修 | 临时文件路径用 `GetTempDir` + `CreateGUID` (5f0b0f4e0) |
| F21 | ✅ 已修 | `StatusDot` 非 ANSI 时回退 ASCII (5f0b0f4e0) |

统计: ✅ 16 已修 / ⏭ 4 保留 / ⚠️ 1 不可行 / 总 21

---

## P0 — 正确性 Bug (必须修复)

### F01: `ToNotBeNear` 状态污染 — `IExpectation` 链式调用会得到错误结果 ✅ 已修

**文件**: `expect.pas:519-524`
**严重度**: 高 — 真实 Bug

```pascal
function TExpectation.ToNotBeNear(AExpected: Double;
  AEpsilon: Double): IExpectation;
begin
  FNegated := not FNegated;   // 直接修改 Self 状态!
  Result := ToBeNear(AExpected, AEpsilon);
end;
```

`Not_` 方法创建新副本避免污染，但 `ToNotBeNear` 直接翻转 `Self.FNegated`。链式调用时状态被破坏：

```pascal
ExpectDouble(1.0).ToNotBeNear(2.0).ToBeNear(1.0);
// ToNotBeNear 翻转 FNegated=True → ToBeNear 看到错误的 negated 状态
```

**修复方案**: `ToNotBeNear` 应像 `Not_` 一样创建副本，或改用局部变量传递 negated 语义。

---

### F02: ParallelThreadEntry 调用约定假设不具可移植性

**文件**: `runner.pas:679-683`
**严重度**: 中 — 平台相关

```pascal
function ParallelThreadEntry(AArg: Pointer): PtrInt;
begin
  ParallelWorkerProc(AArg);  // ParallelWorkerProc 是 cdecl
  Result := 0;
end;
```

注释声称 "On x86-64 Linux calling conventions are compatible"，但这只是假设，不是保证。在 ARM64 或其他架构上可能不成立。

**修复方案**: 让 `ParallelWorkerProc` 直接使用 `PtrInt` 返回类型以匹配 `BeginThread` 签名，或使用显式的 trampoline。

---

### F03: `DisposeTableEntries` 和 `CleanupTableAllocations` 双重释放风险 ✅ 已修

**文件**: `test_lifecycle.pas:36-50`
**严重度**: 中 — 测试代码中的真实 Bug

`test_lifecycle.lpr` 中的 `DisposeTableEntries` 手动释放 table test 指针，但 `CleanupTableAllocations` 也会在 `Run/RunParallel` 结束时释放同样的指针。双重释放被 `Tests[I].TableCase := nil` 保护住了，但这是脆弱的隐式保证，不是设计上的安全。

```
TestTableSerial → Suite.RunWithResult → CleanupTableAllocations (释放指针)
                 → DisposeTableEntries(Suite) → 对 nil 做 Dispose (安全但冗余)
```

**修复方案**: 删除 `test_lifecycle.lpr` 中的 `DisposeTableEntries`，由框架的 `CleanupTableAllocations` 统一负责。

---

## P1 — 设计债务 (应尽快清理)

### F04: Stub 双重注册机制过度复杂 ✅ 已文档化

**文件**: `runner.pas:114-153, 844-873, 1001-1007`
**严重度**: 中 — 设计债务

Stub 释放有三个机制同时运行：
1. `TTestSuite.StubAllocations` — 每 suite 实例的追踪
2. `CleanupTableAllocations` — Run 时释放 + nil-out 全局注册表
3. `GStubRegistry` + `finalization` — 全局安全网

问题：
- `RegisterStub` 是 `public` API，暴露了框架内部细节
- `NilPointerInArray` 线性扫描全局注册表，O(n²) 复杂度
- `finalization` 和 `CleanupTableAllocations` 的交互需要仔细推理才能确认不会 double-free

**建议**: 统一为单一 ownership 机制。让 `CleanupTableAllocations` 是唯一释放路径，`finalization` 只做防泄漏检查（heaptrc 已有此功能）。

---

### F05: `TTestEntry` record 空间浪费

**文件**: `base.pas:89-100`
**严重度**: 低 — 性能/内存

```pascal
TTestEntry = record
  Name       : string;
  Proc       : TTestProc;       // nil for ekSubtest/ekTableTest
  Closure    : TTestClosure;    // nil for ekSubtest/ekTableTest
  SubtestProc: TSubtestProc;    // nil for ekTest/ekTableTest
  Kind       : TTestEntryKind;
  SkipReason : string;
  RetryCount : Integer;
  TableCase  : Pointer;         // nil for non-table tests
  TableProc  : Pointer;         // nil for non-table tests
end;
```

每个 entry 有 4 个可能 nil 的指针/闭包字段。对于只有 `ekTest` 的简单 test，浪费了 3 个字段的空间。

**建议**: 可以用 variant record (FPC `record case`) 节省空间，但收益不大，记录为未来优化点。

---

### F06: `RunWithResult` ✅ TODO 和 `RunParallelWithResult` 代码重复

**文件**: `runner.pas:330-666 vs 685-807`
**严重度**: 中 — 维护性

Setup 失败处理、结果计数、HasRun/LastRunPassed 更新、Summary 输出 — 这些逻辑在串行和并行路径中重复。并行版本遗漏了 BeforeEach failure、AfterEach failure、Retry、TestFilter 的处理。

**建议**: 提取公共的 "before run" 和 "after run" 逻辑为辅助方法。

---

### F07: TAP 和 JSON 输出缺少测试覆盖

**文件**: `test_output.tap.pas`, `test_output.json.pas`
**严重度**: 中 — 测试覆盖缺失

`TAPReport` 和 `JSONReport` 在 8 个测试套件中完全没有测试。`JSONReport` 的手动 JSON 构建容易出错（如尾随逗号处理的 hack at line 137-141），而 `TAPReport` 的 YAML block 格式也不一定符合 TAP v13 规范。

**建议**: 至少添加基础输出格式验证测试。

---

### F08: Mock 模块零测试覆盖

**文件**: `test.mock.pas` (376 行)
**严重度**: 中 — 测试覆盖缺失

`TMock` / `TMockState` / `IMockSetup` / `IMockVerify` 的完整实现无任何测试。`GetReturnInt` 的 `TryStrToInt64` 错误路径、`GetReturnBool` 的 `SameText` 语义、`ResetCalls` 对 setups 的保留行为 — 全部未验证。

**建议**: 添加 `test_mock.lpr` 套件。

---

### F09: Parallel 模式静默跳过 Subtest ✅ 已修

**文件**: `runner.pas:754-759`
**严重度**: 中 — 语义不明确

```pascal
if Tests[I].Kind = ekSubtest then
begin
  LResults[I].Name    := Tests[I].Name;
  LResults[I].Status  := tsSkipped;
  LResults[I].Message := 'subtests not supported in parallel mode';
end;
```

用户在并行模式下运行 subtest 会静默跳过，不计入 skip 统计（`LSkip` 不增），结果被埋在日志中。

**建议**: 要么将 skip 计入 `LSkip`，要么在并行模式入口 `WriteLn` 警告有 subtest 被跳过。

---

### F10: `ITestContext` ⚠️ 不可行 (FPC 循环引用) 接口公开了 `RunNested(AProc: Pointer)`

**文件**: `base.pas:25`
**严重度**: 低 — API 设计

```pascal
procedure RunNested(const AName: string; AProc: Pointer);
```

`AProc` 是无类型的 `Pointer`，调用方必须自行 cast 为 `TSubtestProc`，丧失类型安全。

**建议**: 改为 `AProc: TSubtestProc`。

---

## P2 — 代码质量 (择机修复)

### F11: Glob 匹配器递归 ✅ 已修 + 字符串分配

**文件**: `output.pas:173-205`
**严重度**: 低 — 性能

`MatchesGlob` 对 `*` 的回溯使用递归 + `Copy()` 创建新字符串。对于 `*a*b*c*d*e*` 这类 pattern 可能指数级慢。

**建议**: 改为迭代 + 索引方式，避免 `Copy()` 分配。

---

### F12: `XmlEscape` / `JsonEscape` ✅ 已修 重复字符串拼接

**文件**: `output.pas:253-280`, `output.json.pas:34-60`
**严重度**: 低 — 性能

每次特殊字符都触发 `Result + string`，FPC 的字符串连接每次可能分配新内存。对于包含大量 `&`、`<`、`>` 的长字符串会退化为 O(n²)。

**建议**: 预分配 `SetLength` + 索引写入，或使用 `TBufStringBuilder`（项目已有）。

---

### F13: `AddLine` 辅助函数在 TAP 和 JSON 中重复

**文件**: `output.tap.pas:27-31`, `output.json.pas:27-31`
**严重度**: 低 — 重复代码

两个输出模块各自实现了完全相同的 `AddLine` 过程。

**建议**: 提取到 `nextpas.core.test.output` 作为公共工具。

---

### F14: `for-in` 语法需要 FPC 3.x

**文件**: `output.tap.pas:44,53,55` (隐含)，`output.json.pas:88,109,126`
**严重度**: 低 — 可移植性

TAP 和 JSON 输出使用 `for LSuite in AResults` / `for LRes in LSuite.Results`。需要 `{$mode objfpc}` + FPC 3.0+。当前项目使用 trunk FPC 所以没问题，但不兼容 FPC 3.0 以下。

---

### F15: `CheckNear` 的 epsilon 默认值可能不适合所有场景

**文件**: `check.pas:39`, `expect.pas:39-42`
**严重度**: 低 — API 设计

默认 epsilon = `1e-10`。对于金融计算可能太大，对于物理计算可能太小。`FloatToStr` 的输出也不包含足够精度来诊断失败原因。

**建议**: 考虑更智能的默认值或在失败消息中显示实际 epsilon。

---

### F16: `Check` API 缺少数值比较便捷方法

**文件**: `check.pas`
**严重度**: 低 — API 覆盖

有 `CheckInRange` 但没有 `CheckGreaterThan` / `CheckLessThan`。`Expect` API 有 `ToBeGreaterThan` / `ToBeLessThan`，但 `Check` API 没有对等物。

---

### F17: `test_parallel.lpr` ✅ 已修 8 个几乎相同的过程

**文件**: `test_parallel.lpr:16-61`
**严重度**: 低 — 测试代码质量

`TestParallelSimple1` 到 `TestParallelSimple8` 是完全相同的代码复制了 8 次。可以循环注册同一个过程 8 次。

---

### F18: TTestRunner.Add ✅ 已修 的 var 参数语义

**文件**: `runner.pas:889-900`
**严重度**: 低 — API 陷阱

```pascal
procedure TTestRunner.Add(var ASuite: TTestSuite);
```

`var` 参数避免了值拷贝开销，但内部仍做值拷贝 (`Suites[High(Suites)] := ASuite`)。调用方修改 `ASuite` 不会影响 runner 内部副本。`var` 暗示引用语义但实际是值语义 — 容易误导。

**建议**: 改为普通参数（去掉 `var`），或在文档中明确说明。

---

### F19: `RunWithResult` 的 `LAppender ✅ 已修.Free` 在 setup failure 路径

**文件**: `runner.pas:385`
**严重度**: 低 — 资源管理

Setup 失败时 `LAppender.Free` 在 `Exit` 前被调用 — 正确。但如果未来有人在 `Exit` 前添加代码而忘记保持 `LAppender.Free`，就会泄漏。

**建议**: 用 `try/finally` 包裹整个 `RunWithResult` 的主逻辑确保 `LAppender` 总被释放。

---

### F20: `test_output.lpr` ✅ 已修 (5f0b0f4e0) 用 `/tmp` 路径写文件

**文件**: `test_output.lpr:374`
**严重度**: 低 — 测试可移植性

```pascal
LPath := '/tmp/nextpas_test_junit_' + IntToStr(GetTickCount64) + '.xml';
```

在 Windows 上 `/tmp` 不存在。虽然当前 CI 是 Linux，但项目有 Windows CI 计划。

**建议**: 使用 `SysUtils.GetTempDir` + `CreateGUID` 生成跨平台临时路径。

---

### F21: `StatusDot` ✅ 已修 (5f0b0f4e0) 字符依赖 Unicode 字体支持

**文件**: `output.pas:133-141`
**严重度**: 低 — 兼容性

```pascal
tsPassed:  Result := AnsiGreen(#$2713);   // ✓
tsFailed:  Result := AnsiRed(#$2717);     // ✗
tsSkipped: Result := AnsiYellow(#$25CB);  // ○
```

这些 Unicode 字符在某些终端字体中不可见或渲染为方块。

**建议**: 在非 Unicode 终端或 Windows cmd 中 fallback 到 ASCII (`+`, `-`, `o`)。

---

## P3 — 长期演进建议

### F22: 缺少 Test Suite 的 suite-level timeout

当前只有 per-test timeout（`SetTestTimeout`），没有 suite-level 的总超时。长时间 hang 的 suite 会无限等待。

### F23: 缺少 test parallelism degree 控制

`RunParallel` 为每个 test 创建一个线程。对于 100+ tests 的 suite，这会产生 100+ 线程。应该有 `MaxParallel` 参数或使用线程池。

### F24: 缺少 test ordering 控制

当前 tests 按注册顺序运行。某些场景（如依赖测试、性能测试）可能需要随机顺序或指定顺序。

### F25: 缺少 test retry 的 backoff

Retry 是立即重试。对于 IO 相关的测试，可能需要指数退避。

### F26: 缺少 `Expect` 对 Double 的 `ToBeGreaterThan` / `ToBeLessThan`

`IExpectation` 只有 `Int64` 的比较方法，没有 `Double` 的 `ToBeGreaterThan` / `ToBeLessThan`。

---

## 统计

| 优先级 | 数量 | 描述 |
|--------|------|------|
| P0     | 3    | 正确性 Bug |
| P1     | 7    | 设计债务 / 覆盖缺失 |
| P2     | 11   | 代码质量 |
| P3     | 5    | 长期演进 |
| **合计** | **26** | |

## 建议优先处理顺序

1. **F01** (ToNotBeNear 状态污染) — 真实 Bug，影响链式调用正确性
2. **F03** (DisposeTableEntries 双重释放风险) — 测试代码 Bug，修复简单
3. **F09** (Parallel 跳过 Subtest 不计入 skip) — 用户可见的语义问题
4. **F07+F08** (TAP/JSON/Mock 零测试覆盖) — 测试框架自身的测试盲区
5. **F06** (串行/并行代码重复) — 减少未来维护成本
6. **F04** (Stub 双重注册简化) — 降低复杂度
7. 其余按优先级和兴趣择机处理
