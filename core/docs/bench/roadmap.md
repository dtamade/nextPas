# Bench 模块竞争路线图

> **目标**: 对标 Go testing.B / benchstat 和 Rust criterion，达到并超越它们的统计严谨性和报告质量。
>
> **原则**: 不做表面功夫。每个 gap 有明确的技术理由和测试覆盖要求。

---

## 当前优势（已超越 Go/Rust 的领域）

| 能力 | nextpas | Go | Rust criterion |
|------|---------|-----|----------------|
| Kahan 求和（浮点精度） | ✅ 内建 | ❌ 普通 sum | ❌ 普通 sum |
| Shapiro-Wilk 正态性检验 | ✅ 内建 | ❌ | ❌（需外部 crate） |
| 内存追踪集成 | ✅ memtrack suite | ❌ 需外部工具 | ❌ |
| 并行基准 | ✅ parallel suite | ❌ 需外部工具 | ❌ |
| 跨语言对比框架 | ✅ xlang suite | ❌ | ❌ |
| Welch's t-test | ✅ 已集成 | ✅ benchstat | ❌（用 Mann-Whitney） |
| 多异常值检测方法 | ✅ Tukey/ZScore/ModifiedZScore | ❌ 仅 IQR | ❌ 仅 IQR |
| HTML 报告 | ✅ 内建 | ❌ 需第三方 | ✅ 内建 |

---

## Gap 分析与优先级

### P0 — 统计可信度（不做就没人信你的数据）

| ID | Gap | 理由 | 对标 |
|----|-----|------|------|
| P0-1 | Mann-Whitney U 检验 | 基准数据右偏，t-test 假设正态分布不成立。Go benchstat v2 和 Rust criterion 都用非参数检验 | Go benchstat v2, Rust criterion |
| P0-2 | 几何均值聚合 | 多 benchmark 的 ratio 聚合必须用几何均值（算术均值有偏）。CI 管线 gating 依赖这个 | Go benchstat |
| P0-3 | 正则过滤 / 层级名称 | `bench -run Quick` 按名称选择子集，CI 只跑相关 benchmark | Go `-run`, Rust `--filter` |
| P0-4 | StopTimer/StartTimer | 跳过 setup/teardown 时间，保证测量精度 | Go `b.StopTimer()`/`b.StartTimer()` |

### P1 — 功能对齐（达到 criterion 级别）

| ID | Gap | 理由 | 对标 |
|----|-----|------|------|
| P1-1 | 线性回归去除固定开销 | OLS 回归分离每次迭代的固定开销和可变开销，报告 R²。这才是真正的精密测量 | Rust criterion OLS |
| P1-2 | 吞吐量报告 bytes/s | 已有 BytesPerOp，但需标准化显示为 bytes/s 或 elements/s | Go `SetBytes`, Rust `Throughput` |
| P1-3 | 异常值严重度分级 | mild(1.5-3x IQR), moderate(3-10x), severe(>10x)。不只是检测，要分类 | Rust criterion |
| P1-4 | CV 显示 | 变异系数（StdDev/Mean），快速判断数据稳定性 | Rust criterion |
| P1-5 | 基线时间线追踪 | 保存历史基线，可回溯对比任意两次运行 | Rust criterion baselines |
| P1-6 | 命名基线工作流 | save/compare/list 三步操作，CI 可集成 | Rust `--save-baseline`/`--baseline` |
| P1-7 | 自适应测量 | 预热阶段自动校准采样数量，而非固定 MinSamples | Rust criterion warm-up |

### P2 — 超越（做 Go/Rust 做不到的）

| ID | Gap | 理由 | 对标 |
|----|-----|------|------|
| P2-1 | 多基线对比矩阵 | 一次运行对比 N 个基线（不只是 A vs B） | 无（超越） |
| P2-2 | 内存 + 性能联合报告 | 同时展示 ns/op 和 allocs/op + bytes/op | Go testing 有但不美观 |
| P2-3 | HTML 报告交互图表 | 趋势图、分布图、对比图 | criterion HTML |
| P2-4 | CI 集成模板 | GitHub Actions / GitLab CI 模板，回归检测 | benchstat CI |

---

## 实施阶段

### Phase 1: 统计基础（P0）

**目标**: 消除统计可信度 gap，让数据经得起审查。

#### 1.1 Mann-Whitney U 检验 (P0-1)
- 在 `nextpas.core.bench.stats` 中实现 `ComputeMannWhitneyU(A, B: TDoubleArray): Double`
- 计算 U 统计量 + 正态近似 p-value（大样本 n>20 用正态近似）
- 更新 `IBenchStatsAnalyzer` 接口
- `GenerateComparisons` 默认使用 Mann-Whitney U 而非 t-test
- **测试**: 10+ 测试用例，包括已知分布、边界条件、与 R/Python 交叉验证
- **交付**: MannWhitney 测试套件 + 更新 test_bench_integration

#### 1.2 几何均值聚合 (P0-2)
- 实现 `ComputeGeometricMean(Ratios: TDoubleArray): Double`
- 在 `GenerateComparisons` 中计算聚合几何均值
- 报告中增加 "aggregate" 行
- **测试**: 5+ 测试用例，验证与 benchstat 输出一致
- **交付**: 更新 test_bench_stats + test_bench_report

#### 1.3 StopTimer/StartTimer (P0-4)
- `TBenchRunner` 增加 `StopTimer`/`StartTimer` 方法
- 实现: StopTimer 记录当前时间点，StartTimer 将暂停期间的耗时从累计中扣除
- `TBenchContext` 暴露给 benchmark 函数
- **测试**: 8+ 测试用例，验证暂停时间不计入
- **交付**: 更新 test_bench_runner

#### 1.4 正则过滤 (P0-3)
- `TBenchSuite.Run(AClientFilter: string)` 或 `TBenchRunner.SetFilter(Pattern: string)`
- 简单 glob 匹配（`*` 通配符）或基础正则
- **测试**: 6+ 测试用例
- **交付**: 更新 test_bench_runner 或 test_bench_integration

### Phase 2: 精密测量（P1 前半）

**目标**: 达到 Rust criterion 级别的测量精度。

#### 2.1 线性回归去除开销 (P1-1)
- 实现 `TOLSRegression` record: slope, intercept, R²
- 在 `TBenchRunner` 中支持多迭代次数运行（N=1,2,4,8,...）
- OLS 回归: time = α + β×N，报告 β（每次迭代时间）和 R²（拟合度）
- **测试**: 10+ 测试用例，包括已知线性关系、R² 验证
- **交付**: 新增 `nextpas.core.bench.regression.pas` 或扩展现有 stats

#### 2.2 吞吐量报告 (P1-2)
- `TBenchResult` 增加 `BytesPerSec: Double` 和 `ElementsPerSec: Double`
- 报告中自动显示 "123.4 MB/s" 或 "45.6M elem/s"
- **测试**: 4+ 测试用例
- **交付**: 更新 test_bench_report

#### 2.3 异常值严重度分级 (P1-3)
- `TOutlierSeverity = (osMild, osModerate, osSevere)`
- `ClassifyOutlier(Value, Q1, Q3, IQR): TOutlierSeverity`
- 报告中标注异常值级别
- **测试**: 6+ 测试用例
- **交付**: 更新 test_bench_stats_advanced

#### 2.4 CV 显示 (P1-4)
- `CV = StdDev / Mean`，以百分比显示
- 报告中在 StdDev 旁边显示 CV%
- 阈值: <5% 优秀，5-15% 一般，>15% 警告
- **测试**: 3+ 测试用例
- **交付**: 更新 test_bench_report

### Phase 3: 工作流集成（P1 后半）

**目标**: CI 管线可用，基线管理成熟。

#### 3.1 命名基线 (P1-6)
- `TBenchResults.SaveBaseline(Name: string)`
- `TBenchSuite.CompareWithBaseline(Name: string)`
- 存储格式: JSON 或 benchstat 兼容文本
- **测试**: 8+ 测试用例
- **交付**: 更新 test_bench_baseline

#### 3.2 基线时间线 (P1-5)
- `.nextpas/bench/<suite>/<name>.jsonl` 追加式存储
- `TBenchSuite.ShowTimeline(Name, LastN)` 查询历史
- **测试**: 6+ 测试用例
- **交付**: 更新 test_bench_baseline

#### 3.3 自适应测量 (P1-7)
- 预热阶段: 运行 100ms 估算单次耗时
- 根据单次耗时自动决定采样数（目标: 总时间 ~1s，至少 30 样本）
- `TBenchRunner` 的 `Calibrate` 方法替代固定 `SetMinSamples`
- **测试**: 5+ 测试用例，验证自动校准结果合理
- **交付**: 更新 test_bench_runner

### Phase 4: 超越（P2）

**目标**: 做 Go/Rust 做不到的事。

#### 4.1 多基线对比矩阵 (P2-1)
- `CompareWithBaselines(Names: array of string)`
- 输出 N 列对比表格
- **测试**: 4+ 测试用例

#### 4.2 内存 + 性能联合报告 (P2-2)
- HTML 报告中同时展示 ns/op, allocs/op, bytes/op 趋势
- **测试**: 3+ 测试用例

#### 4.3 HTML 交互图表 (P2-3)
- 内嵌 SVG 或 JS 图表
- 分布直方图、趋势折线、对比柱状图
- **测试**: 视觉回归测试

#### 4.4 CI 集成模板 (P2-4)
- `bench compare --threshold=5% --fail-on-regression`
- GitHub Actions YAML 模板
- **测试**: 集成测试

---

## 每个 Phase 的验收标准

| Phase | 测试数量（最低） | 文档更新 | 回归检查 |
|-------|----------------|----------|----------|
| Phase 1 | +30 tests | README, goal-tree | 全部 12 套件 0 回归 |
| Phase 2 | +25 tests | README, goal-tree | 全部 12 套件 0 回归 |
| Phase 3 | +20 tests | README, goal-tree | 全部 12 套件 0 回归 |
| Phase 4 | +10 tests | README, goal-tree | 全部 12 套件 0 回归 |

---

## 与 Go/Rust 的对标矩阵

完成所有 Phase 后:

| 能力 | nextpas | Go benchstat | Rust criterion |
|------|---------|-------------|----------------|
| Mann-Whitney U | ✅ Phase 1 | ✅ | ✅ |
| 几何均值聚合 | ✅ Phase 1 | ✅ | ❌ |
| Welch's t-test | ✅ 已有 | ❌ | ❌ |
| StopTimer/StartTimer | ✅ Phase 1 | ✅ | N/A |
| 正则过滤 | ✅ Phase 1 | ✅ | ✅ |
| OLS 线性回归 | ✅ Phase 2 | ❌ | ✅ |
| 吞吐量报告 | ✅ Phase 2 | ✅ | ✅ |
| 异常值分级 | ✅ Phase 2 | ❌ | 部分 |
| CV 显示 | ✅ Phase 2 | ❌ | ✅ |
| 命名基线 | ✅ Phase 3 | ✅ | ✅ |
| 自适应测量 | ✅ Phase 3 | ❌ | ✅ |
| Kahan 求和 | ✅ 已有 | ❌ | ❌ |
| Shapiro-Wilk | ✅ 已有 | ❌ | ❌ |
| 内存追踪 | ✅ 已有 | ❌ | ❌ |
| 并行基准 | ✅ 已有 | ❌ | ❌ |
| 多基线矩阵 | ✅ Phase 4 | ❌ | ❌ |
| HTML 图表 | ✅ Phase 4 | ❌ | ✅ |
| CI 模板 | ✅ Phase 4 | 部分 | 部分 |

**结论**: 完成 Phase 1-3 后，nextpas.bench 在统计方法和工作流上全面对齐 Go/Rust。Phase 4 完成后，在多基线、内存追踪、数值精度上超越两者。

---

## 实施纪律

1. **每个 Gap 一个 commit**，message 格式: `feat(bench): <gap-id> <简述>`
2. **测试先行**: 先写测试（红），再实现（绿），再打磨（重构）
3. **不跳步**: Phase N 全部完成才进入 Phase N+1
4. **每个 Phase 结束**: 更新 goal-tree.md + README.md + 本文件状态
5. **heaptrc 全绿**: 新增的测试套件必须启用 `-gh`
