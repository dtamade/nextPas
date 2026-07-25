# 统计能力深化调研报告

> **日期**: 2026-07-06
> **范围**: Bootstrap 改进、K-S 检验、贝叶斯估计
> **当前状态**: 320 tests, 0 leaks, Phase 1-3 完成

---

## 1. Bootstrap 置信区间改进

### 当前实现

- **位置**: `core/src/nextpas.core.bench.stats.advanced.pas:548-624`
- **算法**: 百分位数 Bootstrap (percentile bootstrap)
- **PRNG**: PCG-LCG (简化版，周期 2^64)
- **迭代次数**: 默认 10,000 次

### 问题分析

| 问题 | 影响 | 严重度 |
|------|------|--------|
| PRNG 质量不足 | LCG 低位周期短，bootstrap 重采样可能有偏差 | P2 |
| 仅支持百分位数法 | 不支持 BCa (偏差修正加速) 方法 | P2 |
| 无 bootstrap 假设检验 | 无法直接用 bootstrap 检验两组数据差异 | P3 |

### 改进方案

#### 1.1 PRNG 升级 (P2)

**目标**: 替换 PCG-LCG 为 Xoroshiro128+ 算法

**理由**:
- Xoroshiro128+ 周期 2^128，统计质量更好
- 速度与 LCG 相当（~1 ns/iter）
- 已被 Rust rand crate 采用

**实现**:
```pascal
TXoroshiro128Plus = record
  S0, S1: UInt64;
  procedure Init(ASeed: UInt64);
  function Next: UInt64;
end;
```

**测试**: 5+ 测试用例，验证分布均匀性

#### 1.2 BCa Bootstrap (P2)

**目标**: 实现 Bias-Corrected and Accelerated bootstrap

**理由**:
- 百分位数法在小样本或偏态分布时有偏差
- BCa 方法通过偏差修正和加速因子提高精度
- 是统计学界推荐的标准方法

**算法**:
```
1. 计算偏差修正因子 z0 = Φ^(-1)(#(θ* < θ) / B)
2. 计算加速因子 a = Σ(θ_(.) - θ_(i))^3 / (6 * (Σ(θ_(.) - θ_(i))^2)^(3/2))
3. 调整百分位数: α1 = Φ(z0 + (z0 + zα)/(1 - a(z0 + zα)))
                 α2 = Φ(z0 + (z0 + z(1-α))/(1 - a(z0 + z(1-α))))
```

**测试**: 8+ 测试用例，与 R boot package 交叉验证

#### 1.3 Bootstrap 假设检验 (P3)

**目标**: 支持 bootstrap 重采样检验两组数据差异

**方法**:
1. 合并两组数据
2. 随机重采样分配到两组
3. 计算重采样下的统计量差异
4. 与实际差异比较，得到 p-value

**测试**: 6+ 测试用例

---

## 2. Kolmogorov-Smirnov 检验

### 当前状态

未实现。当前仅有 Shapiro-Wilk 启发式（基于偏度/峰度）。

### 应用场景

| 场景 | 说明 |
|------|------|
| 正态性检验 | 比 Shapiro-Wilk 更通用，适用于任何分布 |
| 两样本检验 | 比较两个基准结果的分布是否相同 |
| 分布拟合 | 验证数据是否符合特定分布（指数、均匀等） |

### 实现方案

#### 2.1 单样本 K-S 检验 (P1)

**目标**: 检验数据是否来自特定分布

**算法**:
```
1. 计算经验分布函数 Fn(x) = (# of Xi ≤ x) / n
2. 计算 K-S 统计量 D = max|Fn(x) - F0(x)|
3. 使用 Kolmogorov 分布计算 p-value
```

**支持的分布**:
- 正态分布 N(μ, σ²)
- 指数分布 Exp(λ)
- 均匀分布 U(a, b)

**测试**: 10+ 测试用例，包括已知分布、边界条件

#### 2.2 两样本 K-S 检验 (P1)

**目标**: 检验两个样本是否来自同一分布

**算法**:
```
1. 计算两个经验分布函数 F1n(x) 和 F2m(x)
2. 计算 K-S 统计量 D = max|F1n(x) - F2m(x)|
3. 使用渐近分布计算 p-value
```

**应用场景**:
- 比较优化前后的基准分布
- 检测分布变化（regression 不仅看均值，还要看分布）

**测试**: 8+ 测试用例

#### 2.3 接口设计

```pascal
// 在 IBenchStatsAnalyzer 中添加
function KolmogorovSmirnovTest(const A, B: TDoubleArray): TKSTestResult;
function KolmogorovSmirnovNormalTest(const A: TDoubleArray; AMean, AStdDev: Double): TKSTestResult;

TKSTestResult = record
  Statistic: Double;    // K-S 统计量 D
  PValue: Double;       // p-value
  IsSignificant: Boolean; // 在 α=0.05 水平下是否显著
end;
```

---

## 3. 贝叶斯估计

### 当前状态

未实现。当前所有推断都是频率学派方法（置信区间、假设检验）。

### 应用场景

| 场景 | 说明 |
|------|------|
| 后验分布估计 | 给定数据，估计参数的后验分布 |
| 可信区间 | 比置信区间更直观（"有 95% 概率参数在此区间"） |
| 先验知识融合 | 结合历史基准数据改进估计 |

### 实现方案

#### 3.1 正态-正态共轭模型 (P2)

**目标**: 实现正态分布均值的贝叶斯估计

**模型**:
- 先验: μ ~ N(μ0, σ0²)
- 似然: x_i ~ N(μ, σ²)（σ 已知或估计）
- 后验: μ|x ~ N(μ_n, σ_n²)

**公式**:
```
σ_n² = 1 / (1/σ0² + n/σ²)
μ_n = σ_n² * (μ0/σ0² + n*x̄/σ²)
```

**测试**: 8+ 测试用例，验证后验均值和方差

#### 3.2 可信区间 (P2)

**目标**: 计算贝叶斯可信区间

**方法**:
- 解析法（正态共轭模型）
- 数值法（MCMC 采样，未来扩展）

**接口**:
```pascal
function BayesianCredibleInterval(const AData: TDoubleArray;
  APriorMean, APriorStdDev: Double; ALevel: Double = 0.95): TConfidenceInterval;
```

**测试**: 6+ 测试用例

#### 3.3 先验融合 (P3)

**目标**: 使用历史基准数据作为先验

**方法**:
1. 从基线文件加载历史数据
2. 计算历史均值和方差作为先验
3. 结合当前数据计算后验

**应用场景**:
- CI 管线中，使用上次通过的基准作为先验
- 逐步积累先验知识，提高估计精度

**测试**: 5+ 测试用例

---

## 实施计划

### Phase A: K-S 检验 (最高优先级)

**理由**: 最实用，填补分布检验空白

| 任务 | 时间 | 测试 |
|------|------|------|
| A1: 单样本 K-S 检验 | 2h | 10 tests |
| A2: 两样本 K-S 检验 | 2h | 8 tests |
| A3: 接口集成 | 1h | 3 tests |
| **合计** | **5h** | **21 tests** |

### Phase B: Bootstrap 改进

**理由**: 提升统计可信度

| 任务 | 时间 | 测试 |
|------|------|------|
| B1: Xoroshiro128+ PRNG | 1h | 5 tests |
| B2: BCa Bootstrap | 3h | 8 tests |
| B3: Bootstrap 假设检验 | 2h | 6 tests |
| **合计** | **6h** | **19 tests** |

### Phase C: 贝叶斯估计

**理由**: 新能力，差异化竞争优势

| 任务 | 时间 | 测试 |
|------|------|------|
| C1: 正态-正态共轭模型 | 2h | 8 tests |
| C2: 可信区间 | 1h | 6 tests |
| C3: 先验融合 | 2h | 5 tests |
| **合计** | **5h** | **19 tests** |

### 总计

- **时间**: 16 小时
- **测试**: 59 新测试
- **最终**: 320 + 59 = 379 tests

---

## 与 Go/Rust 对标

| 能力 | nextpas (完成后) | Go benchstat | Rust criterion |
|------|-----------------|-------------|----------------|
| K-S 检验 | ✅ Phase A | ❌ | ❌ |
| BCa Bootstrap | ✅ Phase B | ❌ | ❌ |
| Bootstrap 假设检验 | ✅ Phase B | ❌ | ❌ |
| 贝叶斯估计 | ✅ Phase C | ❌ | ❌ |
| 可信区间 | ✅ Phase C | ❌ | ❌ |

**结论**: 完成后，nextpas.bench 在统计方法上将显著超越 Go 和 Rust。

---

## 风险评估

| 风险 | 可能性 | 影响 | 缓解措施 |
|------|--------|------|----------|
| K-S 检验 p-value 计算精度 | 中 | 高 | 与 R/Python 交叉验证 |
| BCa 加速因子数值稳定性 | 低 | 中 | 小样本时回退到百分位数法 |
| 贝叶斯先验选择主观性 | 低 | 低 | 提供默认无信息先验 |
| 测试覆盖不足 | 低 | 中 | 每个功能 8+ 测试用例 |

---

## 下一步

1. 确认实施计划
2. 从 Phase A (K-S 检验) 开始
3. 测试先行，逐步实现
