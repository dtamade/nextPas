# SIMD 模块深化计划 v2

> 创建: 2026-07-06  
> 状态: **ARCHIVED（已完成）** — 勿当主线；现行路线见 [roadmap.md](roadmap.md)  
> 目标: 性能验证 + GEMM 扩展 + 信号处理 + 代码质量

## Work Package A: 性能基准验证

### A1. 运行 bench 模块验证 SIMD 性能 ✅
- 所有 1696 测试通过
- SSE2/AVX2 微内核运行时分派工作正常

### A2. 对比标量 vs SIMD 加速比 ✅
- `{$VECTORIZE OFF}` 已在标量实现中生效
- 性能数据记录在 plan.md

## Work Package B: GEMM 矩阵乘法扩展

### B1. SSE2 GEMM 微内核 (4×4 F32) ✅
- 实现 `GemmMicro4x4F32_SSE2` 和 `GemmMicro4x4F32_SSE2_Zero`
- 4×4 分块，SSE2 128-bit 寄存器
- 集成到 `GemmBlockedF32_SSE2`

### B2. SSE2 GEMM 微内核 (2×2 F64) ✅
- 实现 `GemmMicro2x2F64_SSE2` 和 `GemmMicro2x2F64_SSE2_Zero`
- 2×2 分块，SSE2 128-bit 寄存器
- 集成到 `GemmBlockedF64_SSE2`

### B3. AVX2 GEMM 微内核 (8×8 F32) - 已有
- 现有 6×16 AVX2+FMA 微内核已足够
- 无需额外实现

### B4. GEMM 测试补充 ✅
- 测试 SSE2 微内核 (Test_SSE2_GEMM_Microkernel)
- 运行时分派验证通过

## Work Package C: 信号处理扩展

### C1. 窗函数 ✅
- Kaiser 窗 (KaiserWindowF32)

### C2. 更多滤波器 ✅
- 高通滤波器 (HighPassFilterF32)
- 带通滤波器 (BandPassFilterF32)
- 带阻滤波器 (BandStopFilterF32)

### C3. 信号生成 ✅
- 正弦波生成 (GenerateSineF32)
- 余弦波生成 (GenerateCosineF32)

## Work Package D: 代码质量审查

### D1. 内存安全审查 ✅
- 所有 SimdAlloc 都有对应的 SimdFree
- 无内存泄漏

### D2. 数值精度审查 ✅
- FFT 滤波器使用完整复数 FFT
- Kaiser 窗使用 Bessel 函数近似

### D3. 代码一致性审查 ✅
- 所有新增代码遵循项目风格
- 文档已更新
