# nextpas.core.bench 代码契约

**模块路径**：`core/src/nextpas.core.bench*.pas`（11 个源文件）
**层级**：L1（依赖 L0: base, text）
**Owner**：Claude（AI 负责）
**最后更新**：2026-07-01
**版本**：1.0

---

## 1. 接口契约

### 1.1 子模块

| 文件 | 职责 |
|------|------|
| bench.base | TBaselineComparison, TBaselineManager, EBenchError 基础类型 |
| bench.intf | IBenchResults, IBenchContext 接口定义 |
| bench.runner | TParallelBenchmark, TBenchThread 基准测试运行器 |
| bench.parallel | TParallelBenchConfig 并行基准配置 |
| bench.stats | 统计计算（均值/中位数/标准差） |
| bench.stats.advanced | 高级统计（百分位/自举） |
| bench.baseline | 基线管理（保存/对比） |
| bench.memtrack | 内存跟踪 |
| bench.report | 报告生成 |
| bench.pas | 门面 re-export |

### 1.2 核心接口

```pascal
IBenchResults = interface
  function Iterations: Int64;
  function NsPerOp: Double;
  function BytesPerOp: Int64;
  function AllocsPerOp: Int64;
end;

IBenchContext = interface
  procedure ResetTimer;
  procedure StartTimer;
  procedure StopTimer;
  procedure ReportAllocs;
  procedure SetBytes(ABytes: Int64);
  function N: Integer;
end;
```

### 1.3 核心类型

```pascal
TParallelBenchConfig = record
  Threads: Integer;
  Duration: TDuration;
  MinIterations: Integer;
end;
```

---

## 2. 不变量

- 自适应 N：运行时间不低于 `Duration`
- 统计计算至少 3 次迭代
- 百分位 P50/P95/P99 有效

---

## 3. 错误处理

- `EBenchInvalidParam` 参数无效
- `EBenchBaselineNotFound` 基线不存在

---

## 4. 线程安全

- TParallelBenchmark 使用工作线程并行执行
- IBenchContext 在各自线程中独立使用

---

## 5. 内存管理

- memtrack 跟踪堆分配，报告 AllocsPerOp
- IBenchResults 通过引用计数自动释放

---

## 6. 测试覆盖

- `test_bench`: Runner/Stats/Baseline/Parallel/Memtrack/Report
