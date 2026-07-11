# SIMD 模块实施计划

> 最后更新: 2026-07-11 (Phase 10 内存操作优化)

## 当前状态: Phase 1-10 全部完成 + 深化扩展

### 已完成阶段

| 阶段 | 目标 | 状态 | 验证结果 |
|------|------|------|----------|
| Phase 1: 编译期快速路径 | 静态分派宏 (SIMD_STATIC_*) | ✅ 完成 | 消除运行时分派开销 |
| Phase 2: FP 快速路径 + IEEE 754 | SSE2/AVX2 真实 SIMD 指令 | ✅ 完成 | IEEE 754 合规 |
| Phase 3: 文件合并 + 命名规范化 | 214→88 文件 | ✅ 完成 | 文件数减少 59% |
| Phase 4: 平台扩展 | LoongArch/PPC64 QEMU 验证 | ✅ 完成 | QEMU 验证通过 |
| Phase 5: Highway 静态调度 | SIMD_STATIC_BACKEND 支持 | ✅ 完成 | 双模式工作 |
| Phase 6: 类型覆盖扩展 | 全类型运算符 | ✅ 完成 | F32/F64/I8-I64/U8-U64 |
| Phase 7: 批量操作深度优化 | SSE2/AVX2/AVX512 循环展开 | ✅ 完成 | 1645 tests 通过 |
| Phase 8: 基准测试修正 | SIMD vs Scalar 对比框架 | ✅ 完成 | GetNanoTime 高精度计时 |
| Phase 9: 宽向量优化 | AVX-512 批量操作 | ✅ 完成 | 4x zmm 展开 |
| Phase 10: 内存操作优化 | SimdMemCopy/Fill/Compare | ✅ 完成 | 集成到 mem.utils + 大数组预取优化 |

### 深化扩展 (2026-07-06)

| 扩展 | 目标 | 状态 | 验证结果 |
|------|------|------|----------|
| SSE2 GEMM 微内核 | 4×4 F32 + 2×2 F64 | ✅ 完成 | 运行时分派 AVX2/SSE2 |
| 信号处理扩展 | Kaiser 窗 + 滤波器 + 信号生成 | ✅ 完成 | 1696 tests 通过 |
| TODO 清理 | 源码 TODO 清零 | ✅ 完成 | 0 TODO 残留 |

### 进行中

| 目标 | 状态 | 说明 |
|------|------|------|
| G16: RISC-V V 后端 | Phase 1-2 ✅ | Phase 3 需硬件 |
| G17: Dispatch 开销优化 | Phase 1-3 ✅ | Phase 4: 硬件测量 |
| G18: ArrayAdd 加速比 | Phase 1 ✅ | 2.24x @16KB (实测) |
| G21: NEON AArch64 覆盖度 | ✅ 100% | 558 槽位全覆盖 |

### 延迟项 (🔒 等待 nextpas 编译器)

| 目标 | 状态 | 说明 |
|------|------|------|
| LoongArch LASX Backend | 🔒 STUB | FPC 无 LASX 内联汇编 |
| WebAssembly SIMD | 🔒 STUB | FPC WASM32 无 SIMD128 |
| POWER VSX | 🔒 STUB | 需 nextpas 后端 |
| MIPS MSA | 🔒 STUB | FPC mips64el InternalError |

---

## 实际性能数据

| 操作 | 目标 | 当前 | 差距 | 说明 |
|------|------|------|------|------|
| ArrayAddF32 (16KB) | 6x+ | 2.24x | 2.7x | 标量基准被 FPC 自动向量化 |
| ArrayMulF32 (16KB) | 4x+ | 2.23x | 1.8x | 同上 |
| MemEqual (4KB) | 4x+ | 2.32x | 1.7x | 同上 |
| MemCopy (4KB) | 3x+ | 待测 | - | 需要基准测试 |

**注**: 性能差距主要因为 FPC `-O2` 自动向量化标量基准，导致 SIMD 看起来比标量慢。实际 SIMD 并不慢，是标量已经很快。

---

## Phase 11: 编译器集成 (未来)

**目标**: nextpas 编译器 SIMD 内建支持

**阻塞条件**: nextpas 编译器实现 SIMD 类型和运算符

**任务**:
1. SIMD 类型内建支持
   - TVecF32x4 作为编译器内建类型
   - 直接生成 SIMD 指令

2. SIMD 运算符重载
   - `+`, `-`, `*`, `/` 直接映射到 SIMD 指令
   - 无函数调用开销

3. 自动向量化
   - 编译器自动将循环向量化
   - 利用 SIMD 指令

**验证**:
- 编译器: SIMD 类型和运算符工作
- 性能: 无函数调用开销

---

## 延迟项启用步骤

1. nextpas 编译器实现目标后端
2. 移除 `{$IFDEF CPU...}` 中的 STUB 标记
3. 实现 SIMD intrinsics（参考 LASX stub 模式）
4. QEMU 或真机验证
5. 更新本文档状态
