# SIMD 批量操作优化设计

## 概述

为 nextpas.core.math.batch 的 17 个批量标量函数添加 SIMD 优化，并扩展批量操作功能。

## 设计目标

1. **SIMD 优化**: 为所有批量标量函数添加 SIMD 优化实现
2. **新增操作**: 添加 BatchSinCosF32 等新批量操作
3. **性能基准**: 使用 bench 模块对比 SIMD 和标量性能

## 架构设计

### SIMD 优化策略

采用混合方式，针对不同函数类型使用不同优化策略：

| 函数类型 | 优化策略 | SIMD 指令 |
|----------|----------|-----------|
| 三角函数 (Sin, Cos, Tan) | SIMD 多项式近似 | VecF32x4 并行计算 |
| 指数/对数 (Exp, Ln, Log2) | SIMD 加速软件实现 | 查找表 + 多项式近似 |
| 基础运算 (Sqrt, Abs, Neg) | 硬件指令 | sqrtss, 位操作 |
| 取整函数 (Ceil, Floor, Round, Trunc) | SSE4.1 或软件实现 | roundps |

### 文件结构

```
core/src/nextpas.core.math.batch.simd.pas      ← SIMD 优化实现
core/src/nextpas.core.math.batch.pas            ← 修改为使用 SIMD 实现
core/src/nextpas.core.math.vec.batch.simd.pas   ← 已有，继续完善
```

### BatchSinCosF32 设计

采用独立函数设计，保持 API 一致性：

```pascal
function BatchSinCosF32(const AInput: array of Single;
                        var ASinOutput, ACosOutput: array of Single): SizeInt;
```

**优点**:
- 符合现有 API 风格（var 参数返回结果）
- 使用简单直观
- 内部可优化（共享范围缩减步骤）

## 性能基准测试

### 测试结构

使用 `nextpas.core.bench` 模块创建基准测试：

- 测试文件: `bench_batch_scalar_simd.lpr`
- 测试所有 17 个批量标量函数 + BatchSinCosF32
- 对比 SIMD 版本和标量版本

### 测试规模

| 规模 | 元素数量 | 用途 |
|------|----------|------|
| 小数组 | 64 | 测试函数调用开销 |
| 中数组 | 1024 | 典型使用场景 |
| 大数组 | 16384 | 测试吞吐量 |

### 测试指标

- **吞吐量**: 每秒处理元素数 (elements/sec)
- **延迟**: 单次操作时间 (ns)
- **加速比**: SIMD/标量性能比

### 结果输出

- 生成性能对比表
- 标记显著加速 (>1.5x) 和轻微加速 (<1.5x)
- 保存到 `docs/math/bench-results.md`

## 实现计划

### 阶段 1: SIMD 基础实现
1. 创建 `nextpas.core.math.batch.simd.pas`
2. 实现 Sqrt、Abs、Neg 的 SIMD 版本（最简单）
3. 实现三角函数的 SIMD 近似

### 阶段 2: 高级函数实现
1. 实现 Exp、Ln、Log2 的 SIMD 版本
2. 实现取整函数的 SIMD 版本
3. 实现 BatchSinCosF32

### 阶段 3: 集成与测试
1. 修改 `nextpas.core.math.batch.pas` 使用 SIMD 实现
2. 创建性能基准测试
3. 运行测试并优化

### 阶段 4: 文档与提交
1. 更新 API 文档
2. 生成性能报告
3. 提交代码

## 风险与缓解

1. **平台兼容性**: 不同 CPU 支持不同 SIMD 指令
   - 缓解: 使用运行时检测，回退到标量实现

2. **精度问题**: SIMD 近似可能有精度损失
   - 缓解: 测试精度，确保在可接受范围内

3. **性能回归**: 某些情况下 SIMD 可能更慢
   - 缓解: 使用基准测试验证，必要时禁用 SIMD

## 成功标准

1. 所有批量标量函数都有 SIMD 优化版本
2. BatchSinCosF32 功能正常
3. 性能基准测试完成，SIMD 版本在大多数情况下有加速
4. 所有测试通过，无内存泄漏