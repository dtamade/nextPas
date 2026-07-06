# nextpas.core.simd 路线图和计划任务

> 最后更新: 2026-07-06 (Phase 7-11 规划)

## 当前状态

### 平台支持矩阵

| 平台 | 架构 | 指令集 | Backend | Intrinsics | 状态 |
|------|------|--------|---------|------------|------|
| x86/x86_64 | x86 | SSE | ✅ | ✅ | 稳定 |
| x86/x86_64 | x86 | SSE2 | ✅ | ✅ | 稳定 |
| x86/x86_64 | x86 | SSE3 | ✅ | ✅ | 稳定 |
| x86/x86_64 | x86 | SSSE3 | ✅ | ✅ | 稳定 |
| x86/x86_64 | x86 | SSE4.1 | ✅ | ✅ | 稳定 |
| x86/x86_64 | x86 | SSE4.2 | ✅ | ✅ | 稳定 |
| x86/x86_64 | x86 | AVX | ✅ | ✅ | 稳定 |
| x86/x86_64 | x86 | AVX2 | ✅ | ✅ | 稳定 |
| x86/x86_64 | x86 | AVX-512 | ✅ | ✅ | 稳定 |
| x86/x86_64 | x86 | FMA3 | ✅ | ✅ | 稳定 |
| x86/x86_64 | x86 | AES-NI | ✅ | ✅ | 稳定 |
| x86/x86_64 | x86 | SHA | ✅ | ✅ | 稳定 |
| x86/x86_64 | x86 | MMX | ✅ | ✅ | 稳定 |
| ARM/AArch64 | ARM | NEON | ✅ | ✅ | 稳定 (需 opt-in) |
| ARM/AArch64 | ARM | SVE | ❌ | ✅ | 实验性 |
| ARM/AArch64 | ARM | SVE2 | ❌ | ✅ | 实验性 |
| RISC-V | RISC-V | RVV | ✅ | ✅ | 实验性 |
| LoongArch | LoongArch | LASX | ❌ | ✅ | 实验性/stub |
| WebAssembly | WASM | SIMD128 | ❌ | ❌ | 未支持 |
| POWER | POWER | VSX | ❌ | ❌ | 未支持 |
| MIPS | MIPS | MSA | ❌ | ❌ | 未支持 |

### 已完成 (✅)

| 目标 | 状态 | 说明 |
|------|------|------|
| G1: 核心运算完备性 | ✅ 100% | F32/F64/Integer batch 操作 |
| G2: 神经网络推理层 | ✅ 100% | 47 个函数 |
| G3: 质量保障 | ✅ 100% | 审计/测试/内存 |
| G4: 文档与可发现性 | ✅ 100% | 文档体系 |
| G5: 性能验证与基准 | ✅ 100% | 基准测试 |
| G6: 文本/内存 SIMD 加速 | ✅ 100% | MemEqual, Utf8Validate |
| G7: GEMM 微内核 | ✅ 100% | 矩阵乘法 |
| G8: FFT SIMD 化 | ✅ 100% | 信号处理 |
| G9: RTL 依赖清零 | ✅ 100% | 无 FPC RTL 依赖 |
| G10: 高级计算 | ✅ 100% | parallel/quant/NEON |
| G11: SIMD 深化 | ✅ 100% | INT8 dot/RealFft |
| G12: 算法层 | ✅ 100% | Winograd/Attention/Strassen |
| G13: SIMD contract qualification | ✅ 100% | 合规路线图 |
| G14: 维护可持续性 | ✅ 100% | 维护体系 |
| G15: 代码组织瘦身 | ✅ 100% | 可维护性 |
| G19: SysUtils 残留清理 | ✅ 100% | 77→0 |
| G20: Gather/Scatter 正式化 | ✅ 100% | 正式 API |

### 已完成 (✅) — 2026-07-06 更新

| 目标 | 状态 | 说明 |
|------|------|------|
| G1: 核心运算完备性 | ✅ 100% | F32/F64/Integer batch 操作 |
| G2: 神经网络推理层 | ✅ 100% | 47 个函数 |
| G3: 质量保障 | ✅ 100% | 审计/测试/内存 |
| G4: 文档与可发现性 | ✅ 100% | 文档体系 |
| G5: 性能验证与基准 | ✅ 100% | 基准测试 |
| G6: 文本/内存 SIMD 加速 | ✅ 100% | MemEqual, Utf8Validate |
| G7: GEMM 微内核 | ✅ 100% | 矩阵乘法 |
| G8: FFT SIMD 化 | ✅ 100% | 信号处理 |
| G9: RTL 依赖清零 | ✅ 100% | 无 FPC RTL 依赖 |
| G10: 高级计算 | ✅ 100% | parallel/quant/NEON |
| G11: SIMD 深化 | ✅ 100% | INT8 dot/RealFft |
| G12: 算法层 | ✅ 100% | Winograd/Attention/Strassen |
| G13: SIMD contract qualification | ✅ 100% | 合规路线图 |
| G14: 维护可持续性 | ✅ 100% | 维护体系 |
| G15: 代码组织瘦身 | ✅ 100% | 可维护性 |
| G19: SysUtils 残留清理 | ✅ 100% | 77→0 |
| G20: Gather/Scatter 正式化 | ✅ 100% | 正式 API |
| Phase 1: 编译期快速路径 | ✅ 100% | 静态分派宏 (SIMD_STATIC_*) |
| Phase 2: FP 快速路径 + IEEE 754 | ✅ 100% | SSE2/AVX2 真实 SIMD 指令 |
| Phase 3: 文件合并 + 命名规范化 | ✅ 100% | 214→88 文件 |
| Phase 4: 平台扩展 | ✅ 100% | LoongArch/PPC64 QEMU 验证 |
| Phase 5: Highway 静态调度 | ✅ 100% | SIMD_STATIC_BACKEND 支持 |
| Phase 6: 类型覆盖扩展 | ✅ 100% | 全类型运算符 |

### 进行中 (⚠️)

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

### 下一步工作 (Phase 7+)

| 目标 | 优先级 | 说明 |
|------|--------|------|
| 批量操作深度优化 | P0 | ArrayAdd/Mul/Div 循环展开 + 预取 |
| SIMD vs 标量基准修正 | P0 | FPC 自动向量化导致基准不公平 |
| 宽向量(512-bit)批处理 | P1 | AVX-512 批量操作优化 |
| 内存操作优化 | P1 | MemCopy/MemSet 非对齐快速路径 |
| 编译器集成 | P2 | nextpas 编译器 SIMD 内建支持 |

## 问题分析

### 问题 1: 基准测试不公平 (已发现)

**现状**: 标量基准被 FPC 自动向量化，导致 SIMD 看起来比标量慢
**原因**: FPC `-O2`/`-O3` 会将 `for i := 0 to 3 do Result.f[i] := a.f[i] + b.f[i]` 编译为 SSE2 指令
**影响**: 单向量操作基准 0.64x (实际 SIMD 并不慢，是标量已经很快)
**解决**: 需要修正基准测试方法

### 问题 2: 批量操作优化空间

**现状**: ArrayAddF32 2.24x 加速比 (16KB)
**原因**: 循环展开、预取、对齐优化不足
**影响**: 批量操作性能可进一步提升
**解决**: 深度优化批量操作循环

### 问题 3: 平台覆盖受限

**现状**: x86/ARM/RISC-V 已支持，LoongArch/PPC64 已验证，MIPS/WASM 延迟
**原因**: FPC 后端限制，需等待 nextpas 编译器
**影响**: 跨平台兼容性受限
**解决**: 等待 nextpas 编译器实现对应后端

## 路线图

### Phase 7: 批量操作深度优化 (P0, 1-2 周)

**目标**: 优化批量操作性能，充分发挥 SIMD 优势

**任务**:
1. [ ] ArrayAddF32 循环展开优化
   - 当前: 简单循环
   - 目标: 4x/8x 展开 + 预取
   - 预期: 3-4x 加速比 → 6-8x

2. [ ] ArrayMulF32/ArrayDivF32 优化
   - 当前: 2.24x/2.23x
   - 目标: 4x+ 加速比

3. [ ] 内存对齐优化
   - 检测对齐状态，使用 aligned load/store
   - 非对齐数据使用 movups

4. [ ] 预取策略
   - 软件预取下一批数据
   - 减少 cache miss

**验证**:
- 基准测试: ArrayAddF32 6x+ 加速比
- 测试: 全部通过

### Phase 8: 基准测试修正 (P0, 1 周)

**目标**: 修正基准测试方法，公平比较 SIMD vs 标量

**任务**:
1. [ ] 禁用 FPC 自动向量化
   - 使用 `{$OPTIMIZATION OFF}` 或 volatile 变量
   - 确保标量基准是真正的标量

2. [ ] 添加 SIMD vs 手写标量基准
   - 比较 SIMD vs 手写标量循环
   - 测量真实加速比

3. [ ] 添加吞吐量基准
   - 测量 ops/sec 而不是单次操作延迟
   - 批量操作吞吐量

**验证**:
- 基准测试: SIMD vs 真实标量 4x+ 加速比
- 文档: 更新性能数据

### Phase 9: 宽向量优化 (P1, 2 周)

**目标**: 优化 512-bit 批量操作

**任务**:
1. [ ] AVX-512 批量操作
   - ArrayAddF32x16 (512-bit)
   - ArrayMulF32x16

2. [ ] 256-bit 批量操作优化
   - ArrayAddF32x8 (AVX2)
   - 利用 256-bit 寄存器

3. [ ] 向量宽度自动选择
   - 运行时检测最优宽度
   - 动态选择 128/256/512-bit

**验证**:
- 基准测试: 512-bit 2x+ 快于 256-bit
- 测试: 全部通过

### Phase 10: 内存操作优化 (P1, 2 周)

**目标**: 优化 MemCopy/MemSet 等内存操作

**任务**:
1. [ ] MemCopy 对齐优化
   - 检测源/目标对齐
   - 使用 aligned load/store

2. [ ] MemSet 向量化
   - 使用 SIMD memset
   - 16/32/64 字节批量设置

3. [ ] MemEqual 优化
   - 短字符串快速路径
   - 长字符串 SIMD 比较

**验证**:
- 基准测试: MemCopy 2x+ 加速比
- 测试: 全部通过

**发现 (2026-07-06)**:
- FPC 内置 Move/FillChar/CompareByte 已高度优化
- SIMD 包装增加 ~40% 开销 (函数调用 + 分派)
- 结论: 内存操作应直接使用 FPC 内置函数，SIMD 包装无价值

### Phase 11: 编译器集成 (P2, 长期)

**目标**: nextpas 编译器 SIMD 内建支持

**任务**:
1. [ ] SIMD 类型内建支持
   - TVecF32x4 作为编译器内建类型
   - 直接生成 SIMD 指令

2. [ ] SIMD 运算符重载
   - `+`, `-`, `*`, `/` 直接映射到 SIMD 指令
   - 无函数调用开销

3. [ ] 自动向量化
   - 编译器自动将循环向量化
   - 利用 SIMD 指令

**验证**:
- 编译器: SIMD 类型和运算符工作
- 性能: 无函数调用开销

## 优先级

### P0: 必须完成 (Phase 7-8)

1. 批量操作深度优化 (ArrayAdd 6x+)
2. 基准测试修正 (公平比较)
3. 循环展开 + 预取优化

### P1: 应该完成 (Phase 9-10)

1. 宽向量(512-bit)批处理优化
2. 内存操作优化 (MemCopy/MemSet)
3. 向量宽度自动选择

### P2: 未来完成 (Phase 11)

1. nextpas 编译器 SIMD 内建支持
2. SIMD 类型和运算符
3. 自动向量化

## 验证标准

### 性能验证

| 操作 | 目标 | 当前 | 差距 |
|------|------|------|------|
| ArrayAddF32 (16KB) | 6x+ | 2.24x | 2.7x |
| ArrayMulF32 (16KB) | 4x+ | 2.23x | 1.8x |
| MemEqual (4KB) | 4x+ | 2.32x | 1.7x |
| MemCopy (4KB) | 3x+ | 待测 | - |

### 正确性验证

- 全部测试通过 (1542 tests)
- IEEE 754 一致性测试
- 边界条件测试

### 兼容性验证

- x86_64: SSE2, AVX2, AVX-512 ✅
- AArch64: NEON ✅ (opt-in)
- RISC-V: RVV ✅ (experimental)
- LoongArch: QEMU 验证 ✅
- PPC64: QEMU 验证 ✅
- 标量回退: 全平台 ✅

## 风险评估

### 高风险

1. **FPC 编译器限制**: 无法内联函数指针，Phase 1 可能无法达到目标
2. **IEEE 754 一致性**: 不同 CPU 行为不同，Phase 2 可能有兼容性问题

### 中风险

1. **文件简化**: 可能破坏现有代码
2. **静态调度**: 可能增加维护成本

### 低风险

1. **平台扩展**: 可以逐步推进
2. **性能优化**: 可以增量改进

## 成功标准

### Phase 7 成功标准

- ArrayAddF32: 6x+ 加速比
- ArrayMulF32: 4x+ 加速比
- 循环展开: 4x/8x 展开
- 测试: 全部通过

### Phase 8 成功标准

- 基准测试: SIMD vs 真实标量 4x+ 加速比
- 文档: 更新性能数据
- 测试: 全部通过

### Phase 9 成功标准

- 512-bit: 2x+ 快于 256-bit
- 向量宽度: 自动选择
- 测试: 全部通过

### Phase 10 成功标准

- MemCopy: 3x+ 加速比
- MemSet: 4x+ 加速比
- 测试: 全部通过

### Phase 11 成功标准

- 编译器: SIMD 类型和运算符工作
- 性能: 无函数调用开销
- 兼容性: 与现有代码兼容
