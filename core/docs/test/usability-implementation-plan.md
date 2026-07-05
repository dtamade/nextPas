# nextpas.core.test 可用性修复 — 实施规划

**日期**: 2026-07-05  
**工作树**: `.worktrees/test` (branch `test`)  
**基准**: main @ 8e3a50c0

---

## 里程碑总览

| 阶段 | 内容 | 发现数 | 预估行数 | 依赖 |
|------|------|--------|----------|------|
| M1 | FPC RTL 隔离 + 平台抽象 | 2 | ~5 | 无 |
| M2 | JSON 正确性重写 | 2 | ~100 | 无 |
| M3 | 计时精度 + 内存追踪 | 2 | ~60 | M2 (JSON 格式) |
| M4 | 配置一致性 | 1 | ~40 | 无 |
| M5 | 算法效率优化 | 4 | ~50 | 无 |
| M6 | API 清理 + 实现细节 | 8 | ~80 | 无 |
| M7 | 测试覆盖补充 | 1 | ~350 | M1-M6 全部 |

**总计**: 25 项发现，~685 行改动/新增

---

## M1: FPC RTL 隔离 + 平台抽象 (P0, 预估 10 分钟)

### F-01: `Math` → `nextpas.core.math.scalar`
- `check.pas:137`: `uses Math` → `uses nextpas.core.math.scalar`
- `expect.pas:92`: `uses Math` → `uses nextpas.core.math.scalar`
- 验证: `make -C core/tests/nextpas.core.test clean test`

### F-15: `c_isatty` → `platform_console_is_terminal`
- `output.pas:148`: 删除 `c_isatty` 声明
- `output.pas` uses 增加: `nextpas.core.platform.console`
- 调用处替换: `c_isatty(1) <> 0` → `platform_console_is_terminal(1)`
- 验证: `make -C core/tests/nextpas.core.test clean test`

---

## M2: JSON 正确性重写 (P0, 预估 45 分钟)

### F-09: SaveBenchResultsToFile → IJsonBuilder
- 引入 `nextpas.core.json.builder`
- 重写 `SaveBenchResultsToFile` (runner.pas:2021-2054)
- 生成格式: `{"version":1,"benchmarks":[{"suite":"...","name":"...","n":...,"nsPerOp":...,"allocBytes":...,"allocCount":...}]}`
- 加入 suite name 字段（为 F-13 铺路）

### F-10: LoadBenchResultsFromFile → JsonParse
- 引入 `nextpas.core.json`
- 重写 `LoadBenchResultsFromFile` (runner.pas:2090-2137)
- 解析 JSON DOM，提取结构化数据
- 返回含 suite 信息的结果（为 F-13 铺路）

- 验证: `make -C core/tests/nextpas.core.test clean test`

---

## M3: 计时精度 + 内存追踪 (P1, 预估 30 分钟)

### F-24: GetTickCount64 → TInstant.Now
- 引入 `nextpas.core.time.base` (TInstant, TDuration)
- 替换所有 `GetTickCount64` 为 `TInstant.Now`
- 差值计算: `LFinish - LStart` → `LStart.Elapsed(LFinish)` 或 `TDuration.FromNanoseconds(...)`
- 确保 `FormatDuration` 处理纳秒精度

### F-11: 集成 TMemoryTracker
- 引入 `nextpas.core.bench.memtrack`
- 在 `RunBenchmarks` 的每次迭代前后调用 tracker
- 填充 `TBenchResult.AllocBytes` 和 `AllocCount`

- 验证: `make -C core/tests/nextpas.core.test clean test`

---

## M4: 配置一致性 (P1, 预估 20 分钟)

### F-16: 统一 GExplicit 配置合并
- 为所有布尔字段添加 GExplicit 标记
- `ResolveConfig` 中统一使用 `LExplicit.Contains(...)` 检查
- 涉及字段: `FailFast`, `ListMode`, `ShortMode`, `ShowProgress`, `MaxFailures`, `JsonOutput`, `VerboseMode`, `RunTimeoutSec`, `BenchEnabled`, `BenchTimeMs`, `BenchMem`, `BenchSaveFile`, `BenchCompareFile`

- 验证: `make -C core/tests/nextpas.core.test clean test`

---

## M5: 算法效率优化 (P2, 预估 20 分钟)

### F-17: GetTopSlowest → IntroSort
- 引入 `nextpas.core.collections.algorithms`
- 全排序后取前 K 个，替代 O(K×N) 选择

### F-19: ShuffleEntries → xoshiro256**
- 引入 `nextpas.core.math.random`
- 替换 LCG PRNG

### F-08: PrintBenchComparison → SwissHashMap
- 引入 `nextpas.core.collections` (MakeSwissHashMap)
- 基线结果建 name→index 哈希索引

### F-13: RunAllBenchmarks 遍历所有 suite
- 遍历 `AResults[I]` 而非仅 `AResults[0]`
- 依赖 M2 的 suite name 字段做匹配

- 验证: `make -C core/tests/nextpas.core.test clean test`

---

## M6: API 清理 + 实现细节 (P2-P3, 预估 30 分钟)

### API 清理
- **F-05**: 移除 `CheckEqualMsg` 声明和 re-export (check.pas + facade)
- **F-06**: 不移除，添加文档注释说明双轨设计
- **F-03**: InOrder 添加 `{$TODO}` 标记和文档注释
- **F-04**: TestTable 添加文档注释说明推荐用法
- **F-02**: With* 方法添加文档注释说明不可变语义

### 实现细节
- **F-18**: verbose 模式下始终复制 FLogLines 到结果
- **F-20**: snapshot 读写替换为 `ReadFileText`/`WriteFileText`
- **F-23**: CalledWith 断言失败消息输出 expected vs actual
- **F-07**: 不改，添加文档注释说明独立副本语义
- **F-12**: 并行 worker 添加 retry/repeat 支持
- **F-21**: output.json.pas 统一使用 IJsonBuilder
- **F-22**: 添加 `ExpectInt()`, `ExpectBool()` 重载
- **F-25**: VMT 常量使用 `vmtMethodStart` + 运行时断言

- 验证: `make -C core/tests/nextpas.core.test clean test`

---

## M7: 测试覆盖补充 (P1, 预估 60 分钟)

在 `test_runner.lpr` 中补充以下测试：

1. ShouldFail + 异常类匹配（4 个重载各 1 个测试）
2. RepeatAllCount 集成（suite 跑 N 次）
3. FailFast + MaxFailures 组合
4. RunTimeoutSec 实际终止
5. ListMode 输出验证
6. BenchSave / BenchCompare
7. RunPattern (--run)
8. Test(name,proc,tags) TTestClosure
9. Test(name,proc,displayName,tags)
10. WithEachCleanup
11. ConfigBuilder 全覆盖

- 验证: `make -C core/tests/nextpas.core.test clean test`

---

## 执行顺序

```
M1 ──→ M2 ──→ M3 ──→ M4 ──→ M5 ──→ M6 ──→ M7
 │      │      │      │      │      │      │
 └──────┴──────┴──────┴──────┴──────┴──────┘ 每阶段验证后 git commit
```

M1-M2 为 P0 必须先做。M3 依赖 M2 的 JSON 格式。M4-M6 可并行但串行更安全。M7 最后做。

---

## 验证策略

每个里程碑完成后：
1. `make -C core/tests/nextpas.core.test clean test` — 全量测试
2. `git diff --check` — 无 trailing whitespace
3. `git add -A && git commit` — 有意义的 commit message
4. 最终: `make hygiene` — 无构建产物散落
