# SIMD Array* 函数补全计划

## 目标

为 batch.simd.pas 提供完整的 Array* 函数支持，消除标量回退，实现最优性能。

## 当前状态

### 已有 Array* F32 函数 (27个)
- 基础算术: Add, Sub, Mul, Div, Min, Max, Abs, Neg, Sqrt, Rcp, Rsqrt, RcpRefine, RsqrtRefine
- 标量操作: AddScalar, MulScalar, Clamp, Fma, Axpy
- 超越函数: Exp, Log, Pow, Sin, Cos
- 融合操作: Linear, AbsDiff, ReLU, Norm, LinearReLU
- 类型转换: F32toI32, I32toF32

### 缺失 Array* F32 函数 (9个)
1. **ArrayTanF32** - 正切函数
2. **ArraySinCosF32** - 同时计算正弦和余弦
3. **ArrayLog2F32** - 以2为底的对数
4. **ArrayLog10F32** - 以10为底的对数
5. **ArrayCeilF32** - 向上取整
6. **ArrayFloorF32** - 向下取整
7. **ArrayRoundF32** - 四舍五入
8. **ArrayTruncF32** - 截断取整
9. **ArrayLerpF32** - 线性插值

## 实现计划

### Phase 1: Dispatch Table 扩展
**文件**: `nextpas.core.simd.dispatch.table.inc`
- 添加9个新函数指针到 TSimdDispatchTable

### Phase 2: 标量基线实现
**文件**: `nextpas.core.simd.dispatch.baseline.inc`
- 添加9个 ScalarArray* 函数实现

### Phase 3: SSE2 后端实现
**文件**: `nextpas.core.simd.sse2.batch.inc`
- 实现9个 SSE2Array* 函数
- 使用 SSE2 内联汇编优化

### Phase 4: AVX2 后端实现
**文件**: `nextpas.core.simd.avx2.batch.inc`
- 实现9个 AVX2Array* 函数
- 使用 AVX2 内联汇编优化

### Phase 5: Facade 声明和实现
**文件**: `nextpas.core.simd.pas`
- 添加9个 Array* 函数声明
- 添加9个 Array* 函数实现

### Phase 6: 后端注册
**文件**: `nextpas.core.simd.sse2.register.inc`, `nextpas.core.simd.avx2.register.inc`
- 注册新函数到 dispatch table

### Phase 7: batch.simd.pas 更新
**文件**: `nextpas.core.math.batch.simd.pas`
- 使用新 Array* 函数替代标量回退

### Phase 8: 测试和基准测试
- 更新测试用例
- 运行性能基准测试
- 验证正确性

## 技术细节

### ArrayTanF32 实现策略
```
tan(x) = sin(x) / cos(x)
```
- 使用 ArraySinF32 和 ArrayCosF32
- 然后使用 ArrayDivF32

### ArraySinCosF32 实现策略
- 同时计算 sin 和 cos
- 共享角度归一化计算
- 减少内存访问

### ArrayLog2F32/ArrayLog10F32 实现策略
```
log2(x) = ln(x) / ln(2)
log10(x) = ln(x) / ln(10)
```
- 使用 ArrayLogF32
- 然后使用 ArrayMulScalarF32

### ArrayCeil/Floor/Round/Trunc 实现策略
- 使用 SIMD 向量指令
- SSE2: cvtps2dq, cvtdq2ps
- AVX2: vcvtps2dq, vcvtdq2ps

### ArrayLerpF32 实现策略
```
lerp(a, b, t) = a + t * (b - a)
```
- 使用 ArraySubF32 计算 diff
- 使用 ArrayFmaF32 计算结果

## 预期性能提升

| 操作 | 当前 | 预期 | 提升 |
|------|------|------|------|
| Tan | 1.0x | 40x+ | 40x |
| SinCos | 1.0x | 40x+ | 40x |
| Log2 | 1.0x | 40x+ | 40x |
| Log10 | 1.0x | 40x+ | 40x |
| Ceil | 1.0x | 4x+ | 4x |
| Floor | 1.0x | 4x+ | 4x |
| Round | 1.0x | 4x+ | 4x |
| Trunc | 1.0x | 4x+ | 4x |
| Lerp | 1.0x | 4x+ | 4x |

## 实现顺序

1. Phase 1-2: Dispatch Table + 标量基线
2. Phase 3-4: SSE2/AVX2 后端
3. Phase 5-6: Facade + 注册
4. Phase 7-8: batch.simd.pas + 测试

## 风险和注意事项

1. **FPC RTL 隔离**: 不使用 Math 单元，使用 nextpas.core.math.trig
2. **精度要求**: 使用 Cody-Waite 算法减少舍入误差
3. **性能目标**: Array* 函数应比标量快 4-40 倍
4. **测试覆盖**: 每个新函数需要边界值测试
