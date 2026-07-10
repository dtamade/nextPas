# SIMD 全面深度优化计划

> 创建日期: 2026-07-09
> 状态: 规划中

## 概述

让整个 SIMD 模块"变牛逼"，覆盖四个方向：
1. 批量操作性能深度优化
2. 数学函数向量化
3. SIMD 字符串操作增强
4. 编译期快速路径

## 问题分析

### 问题 1: 批量操作性能不足

| 操作 | 当前 | 目标 | 差距 |
|------|------|------|------|
| ArrayAddF32 | 2.24x | 6x+ | 2.7x |
| ArrayMulF32 | 2.23x | 4x+ | 1.8x |
| MemEqual | 2.32x | 4x+ | 1.7x |

**原因分析**：
1. SSE2 循环展开只有 4x（16 elements/iter），不够激进
2. SSE2 缺少预取优化（只有 AVX2/AVX-512 有）
3. SSE2 缺少非临时存储（movntps）优化
4. 缺少软件流水线（software pipelining）

### 问题 2: 数学函数标量回退

当前状态：
- Exp/Log: 标量回退（逐元素调用 Math.Exp/Log）
- Sin/Cos: 标量回退（逐元素调用 Math.Sin/Cos）
- Tan: 已优化（Sin/Cos 除法）
- Sqrt: 真正 SIMD（sqrtps）

### 问题 3: 整数批量操作缺失

缺失的操作：
- I8/U8: Add, Sub, And, Or, Xor, Min, Max
- U16: Add, Sub, And, Or, Xor, Min, Max
- U32: Add, Sub, And, Or, Xor, Min, Max
- U64/I64: Add, Sub, And, Or, Xor
- ReduceMaxF32/ReduceMaxF64

### 问题 4: Dispatch 开销

当前状态：
- 每次 SIMD 调用都通过函数指针
- GetDispatchTable 需要 atomic_load
- FPC 无法内联函数指针

## 优化计划

### Phase 1: 批量操作深度优化（P0）

**目标**: ArrayAddF32 6x+, ArrayMulF32 4x+

**任务**:
1. SSE2 8x 循环展开（32 elements/iter）
2. SSE2 预取优化（prefetchnta）
3. SSE2 非临时存储（movntps）用于大数据
4. 软件流水线（software pipelining）
5. 对齐检测 + 快速路径

**预计提升**: ArrayAddF32 4x→6x+, ArrayMulF32 3x→4x+

### Phase 2: 数学函数向量化（P1）

**目标**: Exp/Log/Sin/Cos 真正 SIMD 实现

**任务**:
1. SSE2ArrayExpF32: 多项式近似（Range Reduction + Minimax）
2. SSE2ArrayLogF32: 多项式近似（Range Reduction + Minimax）
3. SSE2ArraySinF32: 多项式近似（Range Reduction + Minimax）
4. SSE2ArrayCosF32: 多项式近似（Range Reduction + Minimax）
5. AVX2 版本同步实现

**预计提升**: Exp/Log 4x+, Sin/Cos 3x+

### Phase 3: 整数批量操作补全（P1）

**目标**: 完整的整数批量操作覆盖

**任务**:
1. I8/U8: Add, Sub, And, Or, Xor, Min, Max
2. U16: Add, Sub, And, Or, Xor, Min, Max
3. U32: Add, Sub, And, Or, Xor, Min, Max
4. U64/I64: Add, Sub, And, Or, Xor
5. ReduceMaxF32/ReduceMaxF64

**预计提升**: 整数操作覆盖度 100%

### Phase 4: 字符串操作增强（P1）

**目标**: MemEqual 4x+, 字符串搜索优化

**任务**:
1. MemEqual: 4KB+ 块优化（AVX2 32B 对齐快速路径）
2. MemFindByte: SSE2/AVX2 快速路径
3. BytesIndexOf: SSE4.2 PCMPISTRI 优化
4. Utf8Validate: AVX2 批量验证
5. ToLowerAscii/ToUpperAscii: AVX2 批量转换

**预计提升**: MemEqual 4x+, BytesIndexOf 3x+

### Phase 5: 编译期快速路径（P2）

**目标**: 消除 dispatch 开销

**任务**:
1. SIMD_STATIC_* 宏优化
2. 内联函数指针（如果 FPC 支持）
3. 编译期常量折叠
4. 模板特化（如果 FPC 支持）

**预计提升**: 单向量操作 1.5x+

## 实施策略

### 工作方式

- 在 `.worktrees/simd-optimize` worktree 中进行
- 每个 Phase 独立验证
- 小步提交，每步验证

### 验证标准

1. 正确性: 所有现有测试通过
2. 性能: 达到目标加速比
3. 兼容性: SSE2/AVX2/AVX-512 全部工作
4. 回归: 无性能回归

### 风险

1. FPC 汇编器限制: 某些指令可能无法使用
2. IEEE 754 一致性: 多项式近似可能有精度问题
3. 平台兼容性: 不同 CPU 行为不同

## 详细设计

### Phase 1: SSE2 8x 循环展开

```asm
; SSE2 ArrayAddF32 8x 展开 (32 elements/iter)
@loop32:
  movups xmm0, [rax]
  addps xmm0, [rdx]
  movups [rcx], xmm0
  movups xmm1, [rax + 16]
  addps xmm1, [rdx + 16]
  movups [rcx + 16], xmm1
  movups xmm2, [rax + 32]
  addps xmm2, [rdx + 32]
  movups [rcx + 32], xmm2
  movups xmm3, [rax + 48]
  addps xmm3, [rdx + 48]
  movups [rcx + 48], xmm3
  movups xmm4, [rax + 64]
  addps xmm4, [rdx + 64]
  movups [rcx + 64], xmm4
  movups xmm5, [rax + 80]
  addps xmm5, [rdx + 80]
  movups [rcx + 80], xmm5
  movups xmm6, [rax + 96]
  addps xmm6, [rdx + 96]
  movups [rcx + 96], xmm6
  movups xmm7, [rax + 112]
  addps xmm7, [rdx + 112]
  movups [rcx + 112], xmm7
  add rax, 128
  add rdx, 128
  add rcx, 128
  sub r8, 32
  cmp r8, 32
  jae @loop32
```

### Phase 2: SSE2 预取优化

```asm
; 预取下一批数据
prefetchnta [rax + 256]
prefetchnta [rdx + 256]
```

### Phase 3: SSE2 非临时存储

```asm
; 非临时存储（用于大数据）
movntps [rcx], xmm0
movntps [rcx + 16], xmm1
; ...
sfence  ; 确保写入完成
```

## 时间估算

| Phase | 工作量 | 预计时间 |
|-------|--------|----------|
| Phase 1 | 大 | 2-3 天 |
| Phase 2 | 大 | 2-3 天 |
| Phase 3 | 中 | 1-2 天 |
| Phase 4 | 中 | 1-2 天 |
| Phase 5 | 小 | 0.5-1 天 |
| **总计** | | **7-11 天** |

## 成功标准

1. ArrayAddF32: 6x+ 加速比 ✅
2. ArrayMulF32: 4x+ 加速比 ✅
3. MemEqual: 4x+ 加速比 ✅
4. 数学函数: 真正 SIMD 实现 ✅
5. 整数操作: 100% 覆盖 ✅
6. 所有测试通过 ✅
