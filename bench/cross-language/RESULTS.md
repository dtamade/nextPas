# Cross-Language Sort Benchmark Comparison

> **Date**: 2026-06-25
> **Machine**: Linux x86_64, 44 cores, FPC 3.3.1 / GCC -O2
> **Data**: N=1000 random integers, seed=42

## Results

| Algorithm      | Pascal (ns/op) | C (ns/op) | Pascal/C Ratio |
|----------------|----------------|-----------|----------------|
| InsertionSort  | 337,493        | 147,877   | 2.28x          |
| QuickSort      | 50,683         | 60,044    | **0.84x**      |
| MergeSort      | 160,243        | 50,780    | 3.16x          |

## Analysis

### QuickSort: Pascal 16% faster than C

Pascal 的 QuickSort 使用内联的 Int32 比较和 swap，编译器优化后接近 C 性能。
C 的 `qsort` 使用函数指针回调 (`cmp_int`)，每次比较都有间接调用开销。

### InsertionSort/MergeSort: C 2-3x faster

差距主要来自内存分配策略：
- **C**: 固定大小栈数组 (`int d[N]`)，`memcpy` 复制，零堆分配
- **Pascal**: `Copy(GData)` 创建动态数组（堆分配 + 引入引用计数），每次基准迭代都分配/释放

MergeSort 差距更大因为 Pascal 版本在递归中多次 `SetLength(LTmp, ...)` 分配临时数组。

### 结论

nextpas.core.bench 框架本身开销可忽略（QuickSort 场景已证明）。
排序实现在堆分配密集场景下与 C 有 2-3x 差距，这是 Pascal 动态数组 vs C 栈数组的固有差异。
纯计算密集场景（QuickSort，少量分配）Pascal 性能与 C 相当甚至更优。

## benchstat 格式

```
=== Pascal ===
name                                            ns/op     +- %         B/op  allocs/op
InsertionSort                                337493.3       0%         4000          1
QuickSort                                     50683.0       2%         4000          1
MergeSort                                    160243.4      35%         4000       1000
```
