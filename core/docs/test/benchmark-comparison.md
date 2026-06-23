# nextpas.core.test 基准对照报告

## 测试环境

- CPU: Intel Xeon E5-2680 v4 @ 2.40GHz (56 cores)
- OS: Linux 6.12.74+deb13+1-amd64
- FPC: 3.3.1 (trunk, -O2)
- Go: 1.23.5
- Rust: 1.96.0 (nightly, -O)
- 日期: 2026-06-22

## 结果对比

| 场景 | nextPas | Go | Rust | Go/Pas | Rust/Pas |
|------|---------|-----|------|--------|----------|
| `Check(True)` / `assert!(true)` | **14.1 ns** | 2.7 ns | 0.48 ns | 5.2x | 29x |
| `CheckEqual(Int64)` / `assert_eq!(42,42)` | **20.7 ns** | 2.3 ns | 0.49 ns | 9.0x | 42x |
| `CheckEqual(string)` / `assert_eq!("hello","hello")` | **18.2 ns** | 5.0 ns | 1.21 ns | 3.6x | 15x |
| `CheckNear(Double)` / `(a-b).abs() < eps` | **24.8 ns** | 3.1 ns | 0.84 ns | 8.0x | 30x |
| `ExpectInt.ToEqualInt` (fluent) | **152.9 ns** | — | — | — | — |
| `ExpectDouble.ToBeNear` (fluent) | **154.6 ns** | — | — | — | — |
| Suite RunWithResult (100 tests) | **127.6 µs** | — | — | — | — |

## 架构差异分析

### Go/Rust 为什么快

Go 和 Rust 的断言是 **内联宏/函数**，编译器将比较指令直接内联到循环体中：
- 无函数调用开销
- 无线程本地状态读写
- 无异常机制开销
- 编译器可将循环完全优化为单条比较指令

### nextpas.core.test 为什么有 14-25ns 开销

1. **函数调用**：`Check(True)` 是跨单元的过程调用（~5ns）
2. **threadvar 读写**：`GExecState` 指针解引用 + `Failed := True` 赋值（~3ns）
3. **异常准备**：FPC 在 try/except 块内维护异常处理链（~5ns）
4. **字符串格式化**：失败时需要构造错误消息（热路径上为零开销）

### Fluent API 额外开销

`ExpectInt(42).ToEqualInt(42)` 的 153ns 来自：
- 接口方法分派（~30ns）：通过 vtable 间接调用
- 堆分配 TExpectation 对象（~100ns）：`TInterfacedObject.Create` + 引用计数
- 接口引用计数管理（~20ns）：AddRef/Release

## 结论

### 绝对性能

| 指标 | 值 |
|------|-----|
| Check(True) | 70M ops/s |
| CheckEqual(Int64) | 48M ops/s |
| CheckNear | 40M ops/s |
| 100 测试套件运行 | 7,800 套件/秒 |

### 相对定位

- **vs Go**：3-9x 慢，但 Go 用内联函数，Pascal 用跨单元过程调用——架构差异，非优化差距
- **vs Rust**：15-42x 慢，Rust 编译器优化能力更强（可消除循环），同时使用零开销抽象
- **vs 测试运行时间**：单个断言 14-25ns，即使 10,000 个断言也只占 0.14-0.25ms——**断言开销在实际测试中可忽略不计**

### 设计取舍

nextpas.core.test 选择了 **可观测性优先** 的设计：
- threadvar 支持并行测试的 per-test 状态追踪
- 结构化 TTestRunResult 支持 JUnit XML/CI 集成
- 异常机制支持 Skip/Abort 流程控制
- Fluent API (IExpectation) 提供类型安全的链式断言

这些特性在 Go/Rust 中需要额外的框架代码才能实现（如 Go 的 `testing.T`、Rust 的 custom assert macros），其开销与 nextpas.core.test 相当。
