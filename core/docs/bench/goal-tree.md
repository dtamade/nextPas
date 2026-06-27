# nextpas.core.bench — 目标树

## 当前状态

**阶段**: 生产就绪 (Production Ready)
**最后更新**: 2026-06-26

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
  B9.1  12 测试套件 / 221 框架级测试                 ✅
  B9.2  nextpas.core.test 框架迁移                  ✅
  B9.3  heaptrc 零泄漏验证 (12/12 套件全部启用 -gh)  ✅
  B9.4  API 覆盖补全 (GetData/Count/GetResults)     ✅

B10  文档 ✅
  B10.1  README.md (API 概览/快速开始)              ✅
  B10.2  goal-tree.md (目标树)                      ✅

B11  跨语言基准对照                                    ⏳
  B11.1  Go benchmark 对照数据                       ⏳
  B11.2  Rust criterion 对照数据                     ⏳
  B11.3  C 高精度计时对照                             ⏳
```

## 测试套件分布

| 套件 | 测试数 | heaptrc | 说明 |
|------|--------|---------|------|
| test_bench_stats | 24 | ✅ 零泄漏 | 基础统计 |
| test_bench_stats_advanced | 25 | ✅ 零泄漏 | 高级统计 + NaN/Inf |
| test_bench_runner | 12 | ✅ 零泄漏 | 执行器 |
| test_bench_integration | 43 | ✅ 零泄漏 | 集成测试 |
| test_bench_report | 28 | ✅ 零泄漏 | 报告生成 |
| test_bench_xlang | 32 | ✅ 零泄漏 | 跨语言解析 |
| test_bench_baseline | 22 | ✅ 零泄漏 | 基线管理 |
| test_bench_memtrack | 16 | ✅ 零泄漏 | 内存追踪 |
| test_bench_parallel | 11 | ✅ 零泄漏 | 并行基准 |
| test_bench_parallel_heaptrc | 1 | ✅ 0 leaks | 并行 heaptrc |
| test_bench_parallel_memtrack_heaptrc | 2 | ✅ 0 leaks | 并行+memtrack |
| test_bench_invalid_parameters_heaptrc | 5 | ✅ 0 leaks | 参数校验 |
| **合计** | **221** | **8/8 通过** | |

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
