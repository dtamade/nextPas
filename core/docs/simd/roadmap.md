# nextpas.core.simd 路线图和计划任务

> 最后更新: 2026-07-06

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

### 进行中 (⚠️)

| 目标 | 状态 | 说明 |
|------|------|------|
| G16: RISC-V V 后端 | Phase 1-2 ✅ | Phase 3 需硬件 |
| G17: Dispatch 开销优化 | Phase 1-3 ✅ | Phase 4: 硬件测量 |
| G18: ArrayAdd 加速比 | Phase 1 ✅ | 6x 峰值 @256-1024 |
| G21: NEON AArch64 覆盖度 | 执行中 | 基准测试 |

### 未开始 (❌)

| 目标 | 状态 | 说明 |
|------|------|------|
| Intrinsics FP 真正实现 | ❌ 未开始 | FP 算术是标量回退 |
| 编译期快速路径 | ❌ 未开始 | 分派器开销优化 |
| 静态调度 | ❌ 未开始 | 参考 Highway 双模式 |
| LoongArch LASX Backend | ❌ 未开始 | Intrinsics 已有 stub |
| WebAssembly SIMD | ❌ 未开始 | 需要新后端 |
| POWER VSX | ❌ 未开始 | 需要新后端 |
| MIPS MSA | ❌ 未开始 | 需要新后端 |

## 问题分析

### 问题 1: 分派器开销

**现状**: atomic_load + 函数指针，~15-20 cycles 开销
**原因**: FPC 编译器无法内联函数指针调用
**影响**: 热路径性能下降

### 问题 2: Intrinsics FP 标量回退

**现状**: FP 算术是标量回退，不是真正 SIMD
**原因**: 处理特殊值 (NaN, Inf, -0.0)，确保 IEEE 754 一致性
**影响**: Intrinsics 层未真正实现

### 问题 3: 文件数量庞大

**现状**: 214 个源文件 (84 .pas + 130 .inc)
**原因**: 历史积累，功能细分
**影响**: 维护成本高

### 问题 4: 平台覆盖不全

**现状**: 主要支持 x86/ARM/RISC-V，其他平台未支持
**原因**: 开发资源有限
**影响**: 跨平台兼容性受限

## 路线图

### Phase 1: 优化热路径 (短期, 1-2 周)

**目标**: 减少分派器开销，提供编译期快速路径

**任务**:
1. [ ] 为 AVX2 提供编译期快速路径
   ```pascal
   {$IFDEF HAS_AVX2}
   function VecF32x4Add(const a, b: TVecF32x4): TVecF32x4; inline;
   begin
     Result := AVX2AddF32x4(a, b);  // 直接调用
   end;
   {$ENDIF}
   ```

2. [ ] 为批量操作提供快速路径
   ```pascal
   procedure BatchAddF32x4(const A, B: array of TVecF32x4;
                           var C: array of TVecF32x4);
   begin
     // 一次分派，多次调用
   end;
   ```

3. [ ] 添加编译期后端选择宏
   ```pascal
   {$DEFINE SIMD_BACKEND_AVX2}
   ```

**验证**:
- 基准测试: 分派器开销从 ~15-20 cycles 降到 ~1-2 cycles
- 测试: 全部通过

### Phase 2: 修复 Intrinsics 层 (中期, 2-4 周)

**目标**: Intrinsics FP 算术使用真正 SIMD 指令

**任务**:
1. [ ] 在 Backend Adapters 中直接实现 FP SIMD
   ```pascal
   function SSE2AddF32x4(const a, b: TVecF32x4): TVecF32x4; assembler;
   asm
     movups xmm0, [a]
     movups xmm1, [b]
     addps xmm0, xmm1     // 真正的 SIMD 指令
     movups [Result], xmm0
   end;
   ```

2. [ ] 保留 Intrinsics 层用于特殊值处理
   - Load/Store: 真正 SIMD 汇编
   - Set/Zero: 真正 SIMD 汇编
   - 整数算术: 真正 SIMD 汇编
   - FP 算术: 标量回退 (处理特殊值)

3. [ ] 添加 IEEE 754 测试
   - NaN 传播测试
   - Inf 处理测试
   - -0.0 处理测试

**验证**:
- 基准测试: FP 操作性能提升 4-8x
- 测试: IEEE 754 一致性测试通过

### Phase 3: 简化文件结构 (中期, 2-4 周)

**目标**: 减少文件数量，提高可维护性

**任务**:
1. [ ] 合并相似功能的 .inc 文件
2. [ ] 删除过时的 .inc 文件
3. [ ] 统一命名规范

**验证**:
- 文件数量: 214 → ~100
- 编译时间: 不增加
- 测试: 全部通过

### Phase 4: 扩展平台支持 (长期, 2-3 月)

**目标**: 支持更多平台

**任务**:

#### 4.1 LoongArch LASX (优先级: 高)

- [ ] 实现 LASX Backend Adapter
  ```pascal
  function LASXAddF32x8(const a, b: TVecF32x8): TVecF32x8; assembler;
  asm
    xvld xr0, [a]
    xvld xr1, [b]
    xvadd.s xr0, xr0, xr1
    xvst xr0, [Result]
  end;
  ```
- [ ] 测试验证
- [ ] 性能基准

#### 4.2 WebAssembly SIMD (优先级: 中)

- [ ] 实现 WASM SIMD Backend
  ```pascal
  function WASMAddF32x4(const a, b: TVecF32x4): TVecF32x4;
  begin
    // 使用 WASM SIMD 内建函数
    Result := wasm_f32x4_add(a, b);
  end;
  ```
- [ ] 测试验证
- [ ] 性能基准

#### 4.3 POWER VSX (优先级: 低)

- [ ] 实现 VSX Backend Adapter
- [ ] 测试验证
- [ ] 性能基准

#### 4.4 MIPS MSA (优先级: 低)

- [ ] 实现 MSA Backend Adapter
- [ ] 测试验证
- [ ] 性能基准

**验证**:
- 平台: LoongArch, WebAssembly, POWER, MIPS
- 测试: 全部通过
- 性能: 与标量相比有提升

### Phase 5: 静态调度 (长期, 1-2 月)

**目标**: 参考 Highway 双模式设计，支持编译期确定后端

**任务**:
1. [ ] 设计静态调度 API
   ```pascal
   // 静态调度
   function VecF32x4Add_Static(const a, b: TVecF32x4): TVecF32x4; inline;
   begin
     {$IFDEF HAS_AVX2}
     Result := AVX2AddF32x4(a, b);
     {$ELSEIF HAS_SSE2}
     Result := SSE2AddF32x4(a, b);
     {$ELSE}
     Result := ScalarAddF32x4(a, b);
     {$ENDIF}
   end;
   ```

2. [ ] 实现编译期后端选择
   ```pascal
   {$PUSH}
   {$DEFINE SIMD_BACKEND_AVX2}
   // 使用静态调度
   {$POP}
   ```

3. [ ] 保持动态调度兼容
   - 静态调度和动态调度并存
   - 用户可以选择使用哪种

**验证**:
- 基准测试: 静态调度无分派器开销
- 测试: 全部通过
- 兼容性: 动态调度仍然可用

## 优先级

### P0: 必须完成 (Phase 1)

1. 编译期快速路径
2. 批量操作优化
3. 编译期后端选择宏

### P1: 应该完成 (Phase 2)

1. Intrinsics FP 真正实现
2. IEEE 754 测试
3. 性能基准测试

### P2: 可以完成 (Phase 3)

1. 文件结构简化
2. 命名规范统一
3. 文档更新

### P3: 未来完成 (Phase 4-5)

1. LoongArch LASX Backend
2. WebAssembly SIMD
3. POWER VSX
4. MIPS MSA
5. 静态调度

## 验证标准

### 性能验证

| 操作 | 目标 | 当前 | 差距 |
|------|------|------|------|
| VecF32x4Add | ~1 cycle | ~16-21 cycles | 16-21x |
| MemEqual (16B) | ~1 cycle | ~16-21 cycles | 16-21x |
| Utf8Validate (16B) | ~1 cycle | ~16-21 cycles | 16-21x |
| BatchAddF32x4 (1000) | ~1000 cycles | ~16000-21000 cycles | 16-21x |

### 正确性验证

- 全部测试通过
- IEEE 754 一致性测试
- 边界条件测试

### 兼容性验证

- x86_64: SSE2, AVX2, AVX-512
- AArch64: NEON
- RISC-V: RVV
- LoongArch: LASX
- WebAssembly: SIMD128
- 标量回退: 全平台

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

### Phase 1 成功标准

- 分派器开销: ~15-20 cycles → ~1-2 cycles
- 批量操作: 性能提升 10-20x
- 测试: 全部通过

### Phase 2 成功标准

- FP 操作: 性能提升 4-8x
- IEEE 754: 一致性测试通过
- 测试: 全部通过

### Phase 3 成功标准

- 文件数量: 214 → ~100
- 编译时间: 不增加
- 测试: 全部通过

### Phase 4 成功标准

- 平台: LoongArch, WebAssembly, POWER, MIPS
- 测试: 全部通过
- 性能: 与标量相比有提升

### Phase 5 成功标准

- 静态调度: 无分派器开销
- 兼容性: 动态调度仍然可用
- 测试: 全部通过
