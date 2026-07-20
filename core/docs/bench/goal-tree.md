# nextpas.core.bench — 目标树

## 当前状态

**阶段**: 生产就绪 (Production Ready) + 结果 API 收敛冻结
**最后更新**: 2026-07-19 (Round 62 分组对比 + 审计收敛)

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

B17  Phase 5: 统计能力深化 (2026-07-06)                      ✅
  B17.1  单样本 K-S 检验 (Kolmogorov-Smirnov)              ✅
  B17.2  两样本 K-S 检验                                    ✅
  B17.3  Xoroshiro128+ PRNG 升级                            ✅
  B17.4  BCa Bootstrap (偏差修正加速)                       ✅
  B17.5  Bootstrap 假设检验                                 ✅
  B17.6  正态-正态共轭贝叶斯估计                            ✅
  B17.7  贝叶斯可信区间                                     ✅
  B17.8  先验融合 (历史数据作为先验)                        ✅

B18  线程安全执行器 (2026-07-06)                             ✅
  B18.1  TBenchRun 原子结果收集 (AtomicFetchAdd32)           ✅
  B18.2  AllocBenchResult/FreeBenchResult 堆分配              ✅
  B18.3  并发 RunAll (platform_thread_create/join)            ✅
  B18.4  test_bench_run 13 tests (heaptrc 0 leaks)           ✅

B19  缓冲区池 (2026-07-07)                                   ✅
  B19.1  TBenchResultPool 预分配缓冲区                        ✅
  B19.2  原子索引无锁借用 (AtomicFetchAdd32)                  ✅
  B19.3  池满回退到直接分配                                    ✅
  B19.4  test_bench_resultpool 7 tests (0 leaks)              ❌ removed (dead code cleanup)

B20  跨语言性能对照 (2026-07-08)                              ✅
  B20.1  Go 基准测试 (Fibonacci/Sort/String/Memory/Map)       ✅
  B20.2  Rust 基准测试 (Cargo项目, rand依赖)                  ✅
  B20.3  C 基准测试 (clock_gettime高精度)                     ✅
  B20.4  Pascal 基准测试 (GetTickCount64→fpgettimeofday)      ✅
  B20.5  run_all.sh 自动化脚本 + 对比表格                     ✅
  B20.6  COMPARISON.md 性能对比报告                           ✅

B21  自适应预热 (2026-07-08)                                  ✅
  B21.1  TBenchConfig 新增 AdaptiveWarmup/CVThreshold/MaxIters ✅
  B21.2  WarmupEntry 自适应逻辑 (CV<阈值自动停止)             ✅
  B21.3  TBenchSuite.SetAdaptiveWarmup 配置方法               ✅
  B21.4  TBenchRunner.SetAdaptiveWarmup 配置方法              ✅
  B21.5  test_bench_adaptive_warmup 4 tests (0 leaks)         ✅

B22  异常值感知报告 (2026-07-08)                              ✅
  B22.1  TBenchStats/TBenchResult 新增 FilteredMean/StdDev/Median/Count ✅
  B22.2  ComputeStats 自动计算排除异常值后的统计              ✅
  B22.3  PrintToConsole 异常值行显示 (Filtered: ...)          ✅

B23  进度回调 (2026-07-08)                                    ✅
  B23.1  TBenchProgressCallback 类型定义                      ✅
  B23.2  TBenchConfig.OnProgress 字段                         ✅
  B23.3  TBenchSuite.SetOnProgress 配置方法                   ✅
  B23.4  RunAll 调用回调 (platform_monotonic_ns 计时)         ✅

B24  结果聚合 / 过滤 / 排序 API (Round 40–56)                   ✅
  B24.1  GetFastest/Slowest/TopN + Stable/Unstable            ✅
  B24.2  GetTotal* 聚合 + GetSummaryStats                     ✅
  B24.3  FilterBy* / SortBy* / 自定义指标 API                 ✅
  B24.4  ToCSV + Matrix 文件导出                              ✅

B25  分组分析 (Round 57–62)                                    ✅
  B25.1  GetGroups / GetGroupStats / FilterByStdDevRange      ✅
  B25.2  ToJSON/Markdown/HTML_Grouped + SaveTo*_Grouped       ✅
  B25.3  CompareGroups + GetGroupRegressionReport             ✅
  B25.4  分组匹配统一 ExtractGroupName / CollectGroupResults  ✅

B26  审计收敛 / API 冻结 (2026-07-19)                           ✅
  B26.1  停止默认向 IBenchResults 堆叠公共便捷 API            ✅
  B26.2  文档同步 README / API / ARCHITECTURE / goal-tree     ✅

B27  integration 软拆 (2026-07-19)                               ✅
  B27.1  test_bench_results_api 承载结果 API 测试 (~58)         ✅
  B27.2  test_bench_integration 保留生命周期/并行 (~66)         ✅

B28  符号消歧 / 子集扩 track / 文档 CI (2026-07-19)              ✅
  B28.1  runner/pas/xlang/baseline 限定 GlobMatch/LowerCase/…  ✅
  B28.2  SCORECARD 子集 + shortstr/recops/inttohex             ✅
  B28.3  README/CONTRACT/FINAL/ci-gate 口径对齐                  ✅

B29  消费侧文档 + 子集再扩 (2026-07-20)                          ✅
  B29.1  consumer-guide.md                                     ✅
  B29.2  scorecard + bitfield/packed/nativeset                 ✅

B30  可复现子集 + 消费抽检 (2026-07-20)                          ✅
  B30.1  run-scorecard-subset.sh + scorecard-tracks.txt        ✅
  B30.2  consumer-checklist.md (hash/vec/json)                 ✅
  B30.3  archive/README 权威 vs 历史索引                       ✅

B31  仓库入口 + 消费扩面 (2026-07-20)                            ✅
  B31.1  make bench-module-test / bench-scorecard-smoke        ✅
  B31.2  --summary TSV；checklist ≥8 模块                      ✅

B32–B40  消费侧 C3 落地与扩面 (2026-07-20)                       ✅
  B32    text/json/async API 对齐                                ✅
  B33    C2 Domain/Op 命名                                       ✅
  B34    checklist +yaml/log；scorecard binsearch/lookup         ✅
  B35–B39  C3 扩面（yaml/log/regex/number/io/csv/xml/atomic/bytes/sync） ✅
  B40    lockfree matched+micro 双 suite C3                      ✅
  水位   consumer-checklist **19** 模块 C1–C5 全绿               ✅

B41  维护收口 + EBR 设计备忘 (2026-07-20)                        ✅
  B41.1  README/goal-tree 水位对齐                               ✅
  B41.2  ebr-benchrun-design-note.md（不实现）                   ✅
```

## 测试套件分布

> **最后更新**: 2026-07-19

| 套件 | 测试数 | heaptrc | 说明 |
|------|--------|---------|------|
| test_bench_stats | 45 | ✅ 零泄漏 | 基础统计 + GeometricMean + OLS |
| test_bench_stats_advanced | 43 | ✅ 零泄漏 | 高级统计 + 异常值分级 + NaN/Inf |
| test_bench_mannwhitney | 10 | ✅ 零泄漏 | Mann-Whitney U 检验 |
| test_bench_runner | 16 | ✅ 零泄漏 | 执行器 + StopTimer + 统计完整性 |
| test_bench_integration | 66 | ✅ 零泄漏 | 套件生命周期 / 并行 / 超时 / 基线 |
| test_bench_results_api | 58 | ✅ 零泄漏 | 结果聚合/过滤/分组/矩阵 API |
| test_bench_report | 33 | ✅ 零泄漏 | 报告生成 + 空结果 + 边界值 |
| test_bench_xlang | 40 | ✅ 零泄漏 | 跨语言解析 + Unicode + 溢出保护 |
| test_bench_baseline | 22 | ✅ 零泄漏 | 基线管理 + 字段验证 |
| test_bench_memtrack | 16 | ✅ 零泄漏 | 内存追踪 + 全局跟踪器 |
| test_bench_parallel | 11 | ✅ 零泄漏 | 并行基准 |
| test_bench_parallel_heaptrc | 5 | ✅ 0 leaks | 并行 heaptrc |
| test_bench_parallel_memtrack_heaptrc | 5 | ✅ 0 leaks | 并行+memtrack |
| test_bench_invalid_parameters_heaptrc | 18 | ✅ 0 leaks | 参数校验 + 异常类型 |
| test_bench_matrix | 15 | ✅ 0 leaks | 多基线矩阵 + 图表 + JSON |
| test_bench_ks | 12 | ✅ 0 leaks | K-S 检验 |
| test_bench_phase_b | 13 | ✅ 0 leaks | BCa Bootstrap + 假设检验 |
| test_bench_phase_c | 13 | ✅ 0 leaks | 贝叶斯估计 + 可信区间 |
| test_bench_run | 13 | ✅ 0 leaks | TBenchRun 线程安全执行器 |
| test_bench_self_bench | 17 | ✅ 0 leaks | 框架自举路径 |
| test_bench_regression | 29 | ✅ 0 leaks | ToSummary + 自定义指标回归 |
| test_bench_adaptive_warmup | 4 | ✅ 0 leaks | 自适应预热 (CV 阈值) |
| **合计** | **~504** | **22/22 通过** | |

### 跨语言基准对照 (benchmarks/)

| 语言 | 基准测试 | 说明 |
|------|----------|------|
| Go | benchmarks/go/main.go | Fibonacci/Sort/StringConcat/MapOps/MemoryAlloc |
| Rust | benchmarks/rust/main.rs + Cargo.toml | 同上 + rand 依赖 |
| C | benchmarks/c/main.c | 同上 + clock_gettime 高精度 |
| Pascal | benchmarks/pascal/bench_cross_language.lpr | 同上 + GetTickCount64 |
| 自动化 | benchmarks/run_all.sh | 编译运行 + 对比表格 |
| 报告 | benchmarks/COMPARISON.md | 性能对比分析 |

## 已解决的技术债务

- [x] SortDoubleArray NaN 安全（IEEE 754 bit pattern 检测 + 分区）
- [x] TAdvancedStats.Variance/Skewness/Kurtosis NaN/Inf guard
- [x] GetData 返回 Copy 语义（原来返回引用，泄漏）
- [x] 17 处 TAdvancedStats 内联 Create 泄漏
- [x] 全部 12 套件迁移到 nextpas.core.test 框架
- [x] 8 个 Makefile 添加 `-gh` heaptrc 标志

## 未来候选

- [x] Go/Rust/C 跨语言性能对照数据 — **部分完成**：轻量子集 + `run-scorecard-subset.sh`（11 track；全量 SCORECARD 仍推迟）
- [x] 消费侧 checklist C3 扩面 — **已完成**：19 模块（见 [consumer-checklist.md](consumer-checklist.md)）
- [ ] `BenchRun` 新执行器（EBR 感知）— **推迟**；备忘见 [ebr-benchrun-design-note.md](ebr-benchrun-design-note.md)；需独立 lane + 总控授权
- [ ] `TInt64Array` 类型别名（base 模块导出）— 归 base
- [ ] `BENCH_DEFAULT_PARALLEL_THREADS` 常量 — 低优先级
- [ ] 全量 `bench/SCORECARD.md` 60+ track 刷新 — 明确推迟
