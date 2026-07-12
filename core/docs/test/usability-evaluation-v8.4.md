# nextpas.core.test 可用性评估报告 v8.4

**评估日期**: 2026-07-12
**评估范围**: 16 个源文件 / 15,891 LOC / 495 测试
**评估标准**: Rust/Go 工程标准对标

---

## 1. Summary

| 维度 | 得分 | 评级 |
|------|------|------|
| 接口设计 | 8.5/10 | ⭐⭐⭐⭐ |
| API 易用性 | 8.0/10 | ⭐⭐⭐⭐ |
| 调用一致性 | 9.0/10 | ⭐⭐⭐⭐⭐ |
| 错误提示质量 | 8.5/10 | ⭐⭐⭐⭐ |
| 边界条件 | 9.0/10 | ⭐⭐⭐⭐⭐ |
| 测试覆盖 | 8.0/10 | ⭐⭐⭐⭐ |
| 性能 | 7.5/10 | ⭐⭐⭐⭐ |
| 内存安全 | 9.0/10 | ⭐⭐⭐⭐⭐ |
| **综合** | **8.4/10** | **⭐⭐⭐⭐** |

**风险等级**: 🟢 低风险 (生产就绪)
**可用性评级**: A- (优秀，有改进空间)

---

## 2. Findings

### 2.1 接口设计 (8.5/10)

**优势**:
- ✅ 双 API 设计 (Check* 过程式 + IExpectation 流式) 满足不同偏好
- ✅ 工厂函数类型安全 (`ExpectInt`/`ExpectBool`/`ExpectDouble`)
- ✅ IExpectation 链式调用返回 Self，支持 `.Not_.ToEqual('x')`
- ✅ IOutputSink 接口抽象输出目标
- ✅ ITestContext 提供 subtest/cleanup/tempdir 能力

**问题**:
- ⚠️ IExpectation 接口过大 (50+ 方法)，违反接口隔离原则
- ⚠️ `Expect()` 函数仅支持 string，其他类型需 `ExpectInt`/`ExpectBool`
- ⚠️ `ToContain` 有歧义：string 版本是子串匹配，Byte 版本是元素包含

**对标 Rust/Go**:
- Go `testify/assert`: 接口更小 (~30 方法)，但功能也更少
- Rust `assert_eq!`: 宏实现，编译时类型检查，零运行时开销
- 差距: IExpectation 可拆分为 `IStringExpectation`/`INumericExpectation`/`ICollectionExpectation`

### 2.2 API 易用性 (8.0/10)

**优势**:
- ✅ 命名一致：`Check*` / `Expect*` / `To*` 前缀统一
- ✅ 默认参数合理：`AEpsilon = 1e-10`，`ARelEps = 1e-9`
- ✅ `WithMessage` 支持自定义失败消息
- ✅ `ExpectFail` 辅助函数简化异常测试
- ✅ `WithTempDir`/`WithMock` 自动清理资源

**问题**:
- ⚠️ `CheckEqual(Double)` 使用绝对 epsilon，大值场景易误判
- ⚠️ `CheckInRange` 参数顺序 `(Value, Low, High)` 与数学记号 `[Low, High]` 不同
- ⚠️ `ToBeOneOf` 使用 `array of string`，不支持 open array
- ⚠️ 缺少 `CheckApprox`/`ToBeApprox` 别名（Rust 命名习惯）

**对标 Rust/Go**:
- Go `testify`: `assert.InDelta` / `assert.InEpsilon` 更清晰
- Rust `approx`: `assert_abs_diff_eq!` / `assert_relative_eq!`
- 差距: Double 比较命名可更直观

### 2.3 调用一致性 (9.0/10)

**优势**:
- ✅ Check* 和 Expect* 覆盖相同的能力域
- ✅ 所有 Check* 方法都有 `AMessage` 可选参数
- ✅ 所有 Expect* 方法都返回 `IExpectation`（链式）
- ✅ `Not_` 前缀一致用于否定
- ✅ CI 变体 (`ToContainCI`/`CheckContainsCI`) 一致

**问题**:
- ⚠️ `CheckRaises` 参数顺序 `(Class, Proc)` vs `ToRaise(Class, Message)`
- ⚠️ `CheckNoRaise` vs `ToNotRaise` 命名不一致
- ⚠️ `CheckSorted` 仅支持 Int64/String，`ToBeSorted` 也相同（缺少 Double）

### 2.4 错误提示质量 (8.5/10)

**优势**:
- ✅ 字符串差异高亮：显示第一个不同位置 + `^` 指针
- ✅ 数组差异：报告 index + expected/actual 值
- ✅ 类型不匹配：提示正确的工厂函数 (`Use ExpectInt(n)`)
- ✅ NaN/Inf 保护：明确提示 `(NaN)` 或 `(Inf)`
- ✅ 范围检查：显示 `ALow > AHigh` 错误

**问题**:
- ⚠️ 字符串差异仅显示前 40 字符，长字符串截断无提示
- ⚠️ 缺少彩色 diff 输出（Go `go-cmp` 有红/绿高亮）
- ⚠️ `CheckArrayEqual` 仅报告第一个差异，不报告所有差异

**对标 Rust/Go**:
- Rust `pretty_assertions`: 彩色 diff + 上下文
- Go `go-cmp`: 结构化差异路径
- 差距: 缺少多差异报告和彩色输出

### 2.5 边界条件 (9.0/10)

**优势**:
- ✅ NaN 保护：所有 Double 比较都有 NaN guard
- ✅ Infinity 保护：`CheckInf`/`CheckNotInf`/`CheckFinite`
- ✅ 空集合处理：空 needle 匹配一切
- ✅ `ToBeInRange` 验证 `ALow > AHigh`
- ✅ `ToRaise(nil)` 优雅失败
- ✅ `-0.0 = +0.0` IEEE 754 正确处理

**问题**:
- ⚠️ `CheckEqual(Double)` 默认 epsilon 对大值 (1e15+) 太紧
- ⚠️ `ToBeOneOf([])` 空数组行为未文档化
- ⚠️ `ToMatch` 正则错误未捕获（可能抛异常）

### 2.6 测试覆盖 (8.0/10)

**优势**:
- ✅ 15 个测试套件，495+ 测试
- ✅ 失败路径测试覆盖 (ExpectFail)
- ✅ 边界值测试 (NaN, Inf, Int64 Max/Min)
- ✅ 并行测试套件
- ✅ 压力测试 (10K 空测试)

**问题**:
- ⚠️ 缺少性能回归测试 (benchmark CI)
- ⚠️ 缺少内存泄漏自动化检测
- ⚠️ 缺少 API 兼容性测试 (semver)

**对标 Rust/Go**:
- Go: `go test -race` 数据竞争检测
- Rust: `cargo test` 默认并行 + `cargo bench`
- 差距: 缺少竞争检测和性能回归

### 2.7 性能 (7.5/10)

**优势**:
- ✅ 对象池优化 (1.64x 提升)
- ✅ 非原子引用计数 (避免 InterlockedDecrement)
- ✅ Check* API 直接函数调用 (34 ns/iter)

**问题**:
- ⚠️ Expect API 仍有 883 ns/iter (26x vs Check)
- ⚠️ 接口调度开销不可避免
- ⚠️ `CloneSelf` 在 `Not_`/`WithMessage` 时分配新对象

**对标 Rust/Go**:
- Go `testify/assert`: ~200 ns/op (接口调度)
- Rust `assert_eq!`: 0 ns (编译时展开)
- 差距: 接口调度固有开销，Check* API 已接近最优

### 2.8 内存安全 (9.0/10)

**优势**:
- ✅ IExpectation COM 引用计数自动释放
- ✅ `WithTempDir`/`WithMock` 异常安全清理
- ✅ `CleanupTableAllocations` 释放 RTTI 分配
- ✅ `FCleanupDone` guard 防止 double-free
- ✅ heaptrc 验证 0 泄漏

**问题**:
- ⚠️ 对象池 `_Release` 重写可能在多线程下不安全
- ⚠️ `TMock` 手动 Free，调用方可能忘记
- ⚠️ `GExecState` threadvar 在异常时可能泄漏

**对标 Rust/Go**:
- Rust: 编译时所有权检查，零泄漏
- Go: GC 自动回收，但可能延迟
- 差距: 已接近最优，但池的线程安全需验证

---

## 3. Risk 评估

| 风险 | 等级 | 影响 | 缓解措施 |
|------|------|------|----------|
| 对象池线程安全 | 🟡 中 | 并行测试可能崩溃 | 添加 threadvar 或 mutex |
| IExpectation 接口过大 | 🟢 低 | 维护成本高 | 未来拆分接口 |
| Double 精度陷阱 | 🟡 中 | 大值比较误判 | 文档警告 + CheckNearRel |
| 性能回归 | 🟢 低 | CI 无基准 | 添加 benchmark CI |
| API 向后兼容 | 🟢 低 | 版本升级破坏 | semver + 版本号 |

---

## 4. Priority 排序

| 优先级 | 问题 | 影响 | 工作量 |
|--------|------|------|--------|
| P0 | 对象池线程安全 | 并行测试崩溃 | 2h |
| P1 | Double 精度文档 | 用户误用 | 1h |
| P1 | `ToBeOneOf([])` 文档 | 边界行为未定义 | 0.5h |
| P2 | 性能回归 CI | 无自动检测 | 4h |
| P2 | 多差异报告 | 调试效率 | 3h |
| P3 | 接口拆分 | 维护成本 | 8h |
| P3 | 彩色 diff | 调试体验 | 4h |

---

## 5. Next Steps

### 短期 (1-2 天)
1. **P0: 对象池线程安全** — 将 `ThreadPool` 改为 `threadvar`
2. **P1: 文档完善** — Double 精度陷阱、空数组行为

### 中期 (1-2 周)
3. **P2: 性能 CI** — 添加 benchmark 回归检测
4. **P2: 多差异报告** — `CheckArrayEqual` 报告所有差异

### 长期 (1-2 月)
5. **P3: 接口拆分** — `IStringExpectation`/`INumericExpectation`
6. **P3: 彩色 diff** — ANSI 彩色高亮差异

---

## 6. 对标 Rust/Go 总结

| 维度 | nextpas.core.test | Go testify | Rust assert |
|------|-------------------|------------|-------------|
| 类型安全 | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| 性能 | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| 错误消息 | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| 测试覆盖 | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| 内存安全 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| 易用性 | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ |

**结论**: nextpas.core.test 在 Pascal 生态中已达到一流水平，在内存安全和类型安全方面超越 Go testify，接近 Rust 标准。主要差距在性能（接口调度固有开销）和调试体验（彩色 diff）。
