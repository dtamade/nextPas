# nextpas.core.test 高规格可用性评估 — 调研报告

**日期**: 2026-07-05  
**范围**: 25 项发现 (F-01 ~ F-25)  
**工作树**: `.worktrees/test` (branch `test`)

---

## 一、问题分类总览

| 类别 | 发现数 | 严重度 |
|------|--------|--------|
| A. FPC RTL 隔离违规 | 2 (F-01, F-15) | P0 — 违反架构约束 |
| B. JSON 正确性 | 2 (F-09, F-10) | P0 — 数据损坏 |
| C. 计时精度 | 2 (F-11, F-24) | P1 — 测量失准 |
| D. 算法效率 | 3 (F-08, F-13, F-17) | P1-P2 |
| E. 配置一致性 | 1 (F-16) | P1 — 行为不可预期 |
| F. 测试覆盖缺口 | 1 (F-14) | P1 — 质量风险 |
| G. API 清理 | 5 (F-02, F-03, F-04, F-05, F-06) | P2-P3 |
| H. 实现细节 | 7 (F-07, F-12, F-18, F-19, F-20, F-21, F-22, F-23, F-25) | P2-P3 |

---

## 二、逐项调研结果

### A. FPC RTL 隔离违规 (P0)

#### F-01: `Math` 单元导入
- **文件**: `check.pas:137`, `expect.pas:92`
- **问题**: `uses Math` 仅用于 `IsNan(Double)`
- **根因**: 开发时未注意到 `nextpas.core.math.scalar` 已提供等价函数
- **修复**: 替换为 `nextpas.core.math.scalar`（已确认提供 `IsNaN(Double)` 和 `IsNaN(Single)`）
- **风险**: 极低，2 行改动，功能完全等价

#### F-15: 直接 libc `isatty` 调用
- **文件**: `output.pas:148`
- **问题**: `function c_isatty(fd: LongInt): LongInt; cdecl; external 'c'` 绕过平台抽象
- **根因**: 开发时 `nextpas.core.platform.console` 尚未就绪
- **修复**: 替换为 `platform_console_is_terminal(AFd: Int32): Boolean`
- **风险**: 极低，API 签名匹配

### B. JSON 正确性 (P0)

#### F-09: SaveBenchResultsToFile 无字符串转义
- **文件**: `runner.pas:2021-2054`
- **问题**: 手写 JSON 输出，benchmark name 含 `"` 或 `\` 时生成无效 JSON
- **根因**: 早期快速实现，未引入 JSON 库
- **修复**: 使用 `nextpas.core.json.builder.IJsonBuilder`（参考 `bench.report.pas:517-595` 的 ToJSON 实现）
- **风险**: 低，IJsonBuilder 已在 bench 模块验证

#### F-10: LoadBenchResultsFromFile 解析脆弱
- **文件**: `runner.pas:2090-2137`
- **问题**:
  1. 硬编码 200 字符窗口（line 2125），长 benchmark name 被截断
  2. `Pos('"name":', LFull)` 搜索整个文档而非当前窗口（line 2134 逻辑 bug）
  3. 无容错，格式微变即崩溃
- **根因**: 手写解析器，未使用 JSON 库
- **修复**: 使用 `nextpas.core.json.JsonParse` 解析，返回结构化 DOM
- **风险**: 低，JsonParse 已在 config 模块验证

### C. 计时精度 (P1)

#### F-24: Benchmark 使用 GetTickCount64 (毫秒精度)
- **文件**: `runner.pas` 中的 `RunBenchmarks`
- **问题**: `GetTickCount64` 底层是 `platform_monotonic_ns div 1000000`，精度仅 1ms。对亚毫秒级 benchmark（如 64B mem alloc 23ns），自适应校准完全失效
- **根因**: 早期实现使用了 FPC RTL 的 `GetTickCount64`，后端已升级但未同步
- **修复**: 使用 `TInstant.Now`（纳秒精度，底层 `platform_monotonic_ns` → `clock_gettime(CLOCK_MONOTONIC)` / `QueryPerformanceCounter` / `mach_absolute_time`）
- **风险**: 低，`TInstant` 已在 bench 模块广泛使用

#### F-11: RunBenchmarks 不填充 AllocBytes/AllocCount
- **文件**: `runner.pas` 的 `RunBenchmarks`
- **问题**: `TBenchResult.AllocBytes` 和 `AllocCount` 始终为 0，`--benchmem` 无效
- **根因**: 测试框架的 benchmark runner 未集成 `nextpas.core.bench.memtrack.TMemoryTracker`
- **修复**: 在 benchmark 执行前后调用 `TMemoryTracker` 获取分配统计
- **风险**: 中，需确保与 bench 模块的 memtrack 兼容

### D. 算法效率 (P1-P2)

#### F-17: GetTopSlowest O(K×N) 选择排序
- **文件**: `base.pas:332-404`
- **问题**: 对 N 个测试结果做 K 次线性扫描 + 插入排序，复杂度 O(K×N + N²)
- **修复**: 使用 `nextpas.core.collections.algorithms.Sort<T>` (IntroSort+pdqsort) 全排序后取前 K 个，复杂度 O(N log N)
- **风险**: 低，algorithms 模块已验证

#### F-19: ShuffleEntries 使用简单 LCG PRNG
- **文件**: `base.pas:406-468`
- **问题**: LCG 周期短、低位质量差，对测试 shuffle 来说随机性不足
- **修复**: 替换为 `nextpas.core.math.random` 的 PRNG（xoshiro256**）
- **风险**: 极低，仅影响测试执行顺序

#### F-08: PrintBenchComparison O(N×M) 嵌套循环
- **文件**: `runner.pas:2139-2174`
- **问题**: 逐名匹配当前结果与基线，复杂度 O(N×M)
- **修复**: 用 `MakeSwissHashMap<string, Integer>` 建索引，O(1) 查找
- **风险**: 低，但实际影响小（benchmark 数量通常 <100）

#### F-13: RunAllBenchmarks 只比较第一个 suite
- **文件**: `runner.pas:2213`
- **问题**: `PrintBenchComparison(LOutSink, LConfig, AResults[0], LBaseline)` 硬编码 `[0]`
- **根因**: 保存格式不含 suite 信息，加载后为扁平数组
- **修复**: 遍历所有 `AResults[I]`，或在 benchmark name 中加入 suite 前缀（Go 风格 `SuiteName/BenchName`）
- **风险**: 低

### E. 配置一致性 (P1)

#### F-16: ResolveConfig GExplicit 使用不一致
- **文件**: `config.pas:224-255`
- **问题**:
  - 使用 GExplicit 集合: `RepeatAllCount`, `SlowTestCount`, `ShuffleSeed`
  - 仅用零值检查: `FilterPattern`, `TagFilter`, `TimeoutMs`, `AnsiMode`, `OutSink`, `ErrSink`, `RetryCount`, `MaxParallelWorkers`, `RunPattern`
  - 完全未合并: `FailFast`, `ListMode`, `ShortMode`, `ShowProgress`, `MaxFailures`, `JsonOutput`, `VerboseMode`, `RunTimeoutSec`, `BenchEnabled`, `BenchTimeMs`, `BenchMem`, `BenchSaveFile`, `BenchCompareFile`
- **修复**: 统一使用 GExplicit 集合，所有布尔字段加 `SetBoolField`/`GetBoolField`
- **风险**: 中，需确保现有 CLI 解析不受影响

### F. 测试覆盖缺口 (P1)

#### F-14: 13 个特性完全无测试
经交叉比对 `test_runner.lpr`、`test_parallel.lpr`、`test_lifecycle.lpr`、`test_output.lpr`、`test_advanced.lpr`，以下特性 **零测试覆盖**：

| 特性 | 影响 |
|------|------|
| ShouldFail + 异常类匹配 (4 个重载) | 高 — 功能不可信 |
| RepeatAllCount (--count=N) 集成 | 中 |
| FailFast + MaxFailures 组合 | 中 |
| RunTimeoutSec 实际终止 suite | 中 |
| ListMode 实际输出 | 低 |
| BenchSave / BenchCompare | 中 |
| RunPattern (--run) | 中 |
| Test(name,proc,tags) TTestClosure | 低 |
| Test(name,proc,displayName,tags) | 低 |
| WithEachCleanup | 低 |
| ConfigBuilder 多数 With* 方法 | 中 |

### G. API 清理 (P2-P3)

#### F-05: CheckEqualMsg 废弃但仍导出
- **使用量**: 0（全仓库无调用）
- **修复**: 安全移除声明和 re-export

#### F-06: Mock 双 API 表面
- **调研结论**: 两套 API（字符串 + 类型化）**都在积极使用**（测试文件中各 30+ 处调用）
- **判定**: 设计如此，非冗余。类型化 API 提供类型安全匹配，字符串 API 是便捷路径
- **修复**: 不需要移除，可添加文档说明双轨设计意图

#### F-03: InOrder 是空操作
- **文件**: `mock.pas:758-764`
- **问题**: `function TMockVerification.InOrder: IMockVerification; begin Result := Self; end;`
- **修复**: 实现真正的顺序验证（记录调用时间戳，验证时按时间排序比对），或标记为 `TODO` 并在文档中说明
- **风险**: 实现复杂，建议先标记 TODO

#### F-04: TestTable 零使用
- **调研结论**: 全仓库无 `TestTable(` 调用，调用方偏好 `Test()` + 闭包
- **修复**: 保留但添加文档说明推荐用法

#### F-02: With* 方法返回新记录
- **调研结论**: 已有缓解路径（`Set*`/`On*` 就地变异方法）
- **修复**: 文档说明 With* 的不可变语义和 Set*/On* 的可变替代

### H. 实现细节 (P2-P3)

#### F-07: Not_ 创建堆副本
- **调研结论**: 测试 `TestExpectNotStateReset` 明确验证了独立副本语义。`Not_` 返回 `Self` 会破坏 `E.Not_.ToEqual('world'); E.ToEqual('hello');` 链式调用
- **修复**: 不需要改。堆分配在测试框架中不是瓶颈

#### F-12: RunParallelWithResult 不支持 RepeatCount/RetryCount
- **文件**: `runner.pas:1445-1642`
- **修复**: 在并行 worker 中加入 retry 循环和 repeat 循环
- **风险**: 中，需确保线程安全

#### F-18: FLogLines 仅失败时复制
- **文件**: `runner.pas:1238-1240`
- **问题**: 通过的测试日志被丢弃，verbose 模式下无法回溯
- **修复**: verbose 模式下始终复制日志到结果
- **风险**: 极低

#### F-20: 文件 I/O 使用裸 Pascal I/O
- **文件**: `runner.pas` 的 snapshot 读写
- **问题**: 使用 `AssignFile`/`Reset`/`Rewrite` 而非 `nextpas.core.fs`
- **修复**: 替换为 `ReadFileText`/`WriteFileText`
- **风险**: 极低

#### F-21: Output 模块 JSON 手写转义
- **文件**: `output.json.pas` 有独立的 `JsonEscape`
- **修复**: 统一使用 `nextpas.core.json.builder`
- **风险**: 低

#### F-22: Expect() 默认字符串
- **文件**: `test.pas:102`
- **问题**: `Expect(value)` 返回 `IExpectation` 但推断为字符串类型
- **修复**: 添加 `ExpectInt()`、`ExpectBool()` 等显式构造器，或重载 `Expect`
- **风险**: 低

#### F-23: CalledWith 错误消息不含期望/实际值
- **文件**: `mock.pas`
- **修复**: 在断言失败时输出 expected args vs actual args
- **风险**: 极低

#### F-25: VMT 表访问使用硬编码常量
- **文件**: `discovery.pas`
- **问题**: `CEntrySize = SizeOf(Pointer) * 2` 假设 VMT 布局
- **修复**: 使用 FPC 的 `vmtMethodStart` + `vmtMethodWidth` 常量，或添加运行时断言
- **风险**: 中，VMT 布局可能跨 FPC 版本变化

---

## 三、修复策略总结

### P0 — 必须修复（架构违规 + 数据损坏）
1. F-01: `Math` → `nextpas.core.math.scalar` (2 行)
2. F-15: `c_isatty` → `platform_console_is_terminal` (1 行)
3. F-09: SaveBench → `IJsonBuilder` (30 行)
4. F-10: LoadBench → `JsonParse` (50 行)

### P1 — 应该修复（精度 + 一致性 + 覆盖）
5. F-24: `GetTickCount64` → `TInstant.Now` (10 行)
6. F-11: 集成 `TMemoryTracker` (40 行)
7. F-16: 统一 GExplicit 配置合并 (30 行)
8. F-13: 遍历所有 suite 比较 (5 行)
9. F-14: 补充 13 个缺失测试 (300+ 行)

### P2 — 建议修复（效率 + 清理）
10. F-17: GetTopSlowest → IntroSort (10 行)
11. F-19: LCG → xoshiro256** (5 行)
12. F-08: O(N×M) → SwissHashMap (15 行)
13. F-05: 移除 CheckEqualMsg (10 行)
14. F-18: verbose 日志始终复制 (5 行)
15. F-20: 裸 I/O → nextpas.core.fs (10 行)
16. F-23: CalledWith 错误消息增强 (10 行)

### P3 — 可选改进（文档 + 设计说明）
17. F-02/F-03/F-04/F-06/F-07: 文档说明
18. F-12: 并行 RepeatCount/RetryCount (30 行)
19. F-21: JSON 转义统一 (10 行)
20. F-22: Expect 重载 (10 行)
21. F-25: VMT 常量安全化 (5 行)

---

## 四、依赖关系

```
F-01 (Math) ──→ 独立，可立即实施
F-15 (isatty) ──→ 独立，可立即实施
F-09/F-10 (JSON) ──→ 独立，可立即实施
F-24 (计时) ──→ 独立，可立即实施
F-11 (memtrack) ──→ 依赖 F-24（计时基础设施）
F-13 (多 suite) ──→ 依赖 F-09/F-10（JSON 格式含 suite 信息）
F-16 (config) ──→ 独立，可立即实施
F-17/F-19 (算法) ──→ 独立，可立即实施
F-05 (API 清理) ──→ 独立，可立即实施
F-14 (测试) ──→ 依赖所有修复完成后补充
```
