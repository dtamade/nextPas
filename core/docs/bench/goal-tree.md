# nextpas.core.bench — 目标树

## 当前状态

**阶段**: 生产就绪 (Production Ready)
**最后更新**: 2026-07-05 (Phase 3 + 可用性改进完成)

## 目标树

```
B0  核心 API ✅
  B0.1  IBenchSuite / IBenchResults 接口          ✅
  B0.2  TBenchSuite Fluent Builder                 ✅
  B0.3  TBenchRunner 便利 API                      ✅
  B0.4  IBenchContext 控制接口                      ✅

B1  统计引擎 ✅
  B1.1  TSimpleStats (Mean/Median/StdDev)          ✅
  B1.2  TBenchStatsAnalyzer (KahanSum + PF-01)     ✅
  B1.3  TAdvancedStats (Outlier/CI/Bootstrap)      ✅
  B1.4  t-分布置信区间                               ✅
  B1.5  Tukey 异常值检测                             ✅
  B1.6  NaN 安全 (SortDoubleArray + NaN/Inf guard)  ✅

B2  执行引擎 ✅
  B2.1  校准 (CalibrateEntryIterations)             ✅
  B2.2  采样 (CollectEntrySamples)                  ✅
  B2.3  统计流水线                                   ✅
  B2.4  配置热加载 (环境变量)                        ✅
  B2.5  超时控制 (SetTimeout)                       ✅
  B2.6  名称过滤 (SetFilter)                        ✅

B3  输出格式 ✅
  B3.1  Console 表格                                ✅
  B3.2  JSON                                        ✅
  B3.3  TSV                                         ✅
  B3.4  HTML + SVG 图表                             ✅
  B3.5  Benchstat 兼容格式                          ✅

B4  基线管理 ✅
  B4.1  AddBaseline / AddBaselines                  ✅
  B4.2  LoadBaseline (JSON 文件)                    ✅
  B4.3  回归检测 (Welch's t-test + p-value)          ✅

B5  内存追踪 ✅
  B5.1  TMemoryTracker (MemoryManager hook)         ✅
  B5.2  TAtomicMemoryTracker (线程安全)             ✅
  B5.3  GlobalMemoryTracker 单例                    ✅
  B5.4  集成到 runner 采样循环                       ✅

B6  并行基准 ✅
  B6.1  TParallelBenchmark (TThread)                ✅
  B6.2  TParallelConfig                             ✅
  B6.3  TParallelBenchResult 聚合                   ✅
  B6.4  集成到 TBenchSuite.AddParallel              ✅

B7  跨语言解析 ✅
  B7.1  Go bench 输出解析                           ✅
  B7.2  Rust criterion 输出解析                     ✅
  B7.3  FPC 输出解析                                ✅
  B7.4  CompareBenchResults 对比                    ✅

B8  报告扩展 ✅
  B8.1  BoxPlot SVG                                 ✅
  B8.2  环境信息收集                                 ✅
  B8.3  原始样本收集 (CollectRawSamples)            ✅

B9  质量保证 ✅
  B9.1  15 测试套件 / 296 框架级测试                 ✅
  B9.2  nextpas.core.test 框架迁移                  ✅
  B9.3  heaptrc 零泄漏验证 (15/15 套件全部启用 -gh)  ✅
  B9.4  API 覆盖补全 (GetData/Count/GetResults)     ✅
  B9.5  可用性改进 4 里程碑全部完成                   ✅

B10  文档 ✅
  B10.1  README.md (API 概览/快速开始)              ✅
  B10.2  goal-tree.md (目标树)                      ✅

B11  跨语言基准对照                                    ✅
  B11.1  Go benchmark 基准代码                         ✅
  B11.2  Rust criterion 基准代码                       ✅
  B11.3  C 高精度计时基准                              ✅
  B11.4  Pascal vs C 对比报告                          ✅

B12  Phase 1: 统计基础（对标 Go/Rust）                   ✅
  B12.1  Mann-Whitney U 检验（非参数，右偏数据适用）    ✅
  B12.2  GeometricMean 几何均值聚合                    ✅
  B12.3  StopTimer/StartTimer 暂停/恢复计时器          ✅
  B12.4  CompareTwoResults 两结果 Mann-Whitney 对比    ✅
  B12.5  GlobMatch 模式匹配过滤器                      ✅

B13  Phase 2: 精密测量                                   ✅
  B13.1  OLS 线性回归去除固定开销                       ✅
  B13.2  吞吐量标准化显示 (bytes/s)                     ✅
  B13.3  异常值严重度分级 (mild/moderate/severe)         ✅
  B13.4  CV 变异系数显示                                ✅
  B13.5  自适应测量（自动校准采样数量）                  ✅
  B13.6  命名基线 SaveBaseline / LoadBaseline           ✅
  B13.7  时间线追踪 AppendToTimeline (JSONL)            ✅

B14  Phase 3: 超越 Go/Rust                               ✅
  B14.1  多基线对比矩阵 (TMatrixResult)                  ✅
  B14.2  内存+性能联合报告 (B/op + allocs/op 列)         ✅
  B14.3  分布直方图 SVG (GenerateDistributionChart)      ✅
  B14.4  基线对比图 SVG (GenerateComparisonChart)        ✅
  B14.5  CI 集成模板 (shell + GitHub Actions)            ✅

B15  可用性改进 (2026-07-05)                               ✅
  B15.1  D04: GenerateComparisons O(n) HashMap 优化       ✅
  B15.2  E03: ComputePercentiles 批量接口                  ✅
  B15.3  E09: 并行预热多线程化                              ✅
  B15.4  E11: ToJSON 统一 TJsonWriter                      ✅
  B15.5  D08: xlang 解析器诊断输出                          ✅
  B15.6  D12: HasRegression 简化                            ✅
  B15.7  E05: 测试框架统一迁移                              ✅

B16  边界验证修复 (2026-07-06)                               ✅
  B16.1  C-25: RemoveByName 未找到时抛异常                  ✅
  B16.2  C-26: SetTimeout 负值验证                          ✅
  B16.3  C-27: HasRegression 阈值验证                       ✅
  B16.4  C-12/C-13: SetTimeout(TDuration) 重载              ✅

B17  Phase 5: 统计能力深化 (2026-07-06)                      ⬜
  B17.1  单样本 K-S 检验 (Kolmogorov-Smirnov)              ⬜
  B17.2  两样本 K-S 检验                                    ⬜
  B17.3  Xoroshiro128+ PRNG 升级                            ⬜
  B17.4  BCa Bootstrap (偏差修正加速)                       ⬜
  B17.5  Bootstrap 假设检验                                 ⬜
  B17.6  正态-正态共轭贝叶斯估计                            ⬜
  B17.7  贝叶斯可信区间                                     ⬜
  B17.8  先验融合 (历史数据作为先验)                        ⬜
```

## 测试套件分布

> **最后更新**: 2026-07-05

| 套件 | 测试数 | heaptrc | 说明 |
|------|--------|---------|------|
| test_bench_stats | 38 | ✅ 零泄漏 | 基础统计 + GeometricMean + OLS |
| test_bench_stats_advanced | 39 | ✅ 零泄漏 | 高级统计 + 异常值分级 + NaN/Inf |
| test_bench_mannwhitney | 10 | ✅ 零泄漏 | Mann-Whitney U 检验 |
| test_bench_runner | 14 | ✅ 零泄漏 | 执行器 + StopTimer + 统计完整性 |
| test_bench_integration | 49 | ✅ 零泄漏 | 集成测试 + 超时 + LoopContext |
| test_bench_report | 30 | ✅ 零泄漏 | 报告生成 + 空结果 + 边界值 |
| test_bench_xlang | 40 | ✅ 零泄漏 | 跨语言解析 + Unicode + 溢出保护 |
| test_bench_baseline | 22 | ✅ 零泄漏 | 基线管理 + 字段验证 |
| test_bench_memtrack | 16 | ✅ 零泄漏 | 内存追踪 + 全局跟踪器 |
| test_bench_parallel | 11 | ✅ 零泄漏 | 并行基准 |
| test_bench_parallel_heaptrc | 1 | ✅ 0 leaks | 并行 heaptrc |
| test_bench_parallel_memtrack_heaptrc | 2 | ✅ 0 leaks | 并行+memtrack |
| test_bench_invalid_parameters_heaptrc | 9 | ✅ 0 leaks | 参数校验 + 异常类型 |
| test_bench_matrix | 15 | ✅ 0 leaks | 多基线矩阵 + 图表 + JSON |
| test_bench_self_bench | N/A | ✅ 0 leaks | 自基准测试 |
| **合计** | **~296** | **15/15 通过** | |

## 已解决的技术债务

- [x] SortDoubleArray NaN 安全（IEEE 754 bit pattern 检测 + 分区）
- [x] TAdvancedStats.Variance/Skewness/Kurtosis NaN/Inf guard
- [x] GetData 返回 Copy 语义（原来返回引用，泄漏）
- [x] 17 处 TAdvancedStats 内联 Create 泄漏
- [x] 全部 12 套件迁移到 nextpas.core.test 框架
- [x] 8 个 Makefile 添加 `-gh` heaptrc 标志

## 未来候选

- [ ] Go/Rust/C 跨语言性能对照数据
- [ ] `BenchRun` 新执行器（基于 `nextpas.core.sync.ebr`）
- [ ] `TInt64Array` 类型别名（base 模块导出）
- [ ] `BENCH_DEFAULT_PARALLEL_THREADS` 常量
