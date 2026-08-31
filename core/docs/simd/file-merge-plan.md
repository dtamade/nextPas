# SIMD 模块文件合并计划

> 最后更新: 2026-08-31
> 状态: **ARCHIVED（Phase 3 已完成）** — 勿当主线；现行路线见 [roadmap.md](roadmap.md)

## 当前状态

- .pas 文件: 83 个
- .inc 文件: 134 个
- 总计: 217 个文件

## 合并策略

### 1. SSE 变体合并 (5 → 1)

**当前文件**:
- `nextpas.core.simd.sse2.pas` (139KB)
- `nextpas.core.simd.sse2.i386.pas` (16KB)
- `nextpas.core.simd.sse3.pas` (9.5KB)
- `nextpas.core.simd.sse41.pas` (16KB)
- `nextpas.core.simd.sse42.pas` (12KB)

**合并方案**:
- 保留 `nextpas.core.simd.sse2.pas` 作为主文件
- 将 sse3/sse41/sse42 的函数合并到 sse2.pas
- 将 sse2.i386.pas 的函数合并到 sse2.pas
- 使用条件编译 `{$IFDEF CPUX86}` 处理 i386 特定代码

**预计减少**: 4 个文件

### 2. AVX 变体合并 (2 → 1)

**当前文件**:
- `nextpas.core.simd.avx2.pas` (74KB)
- `nextpas.core.simd.avx512.pas` (3.5KB)

**合并方案**:
- 保留 `nextpas.core.simd.avx2.pas` 作为主文件
- 将 avx512.pas 的函数合并到 avx2.pas
- 使用条件编译 `{$IFDEF SIMD_HAS_AVX512}` 处理 AVX-512 特定代码

**预计减少**: 1 个文件

### 3. CPUInfo 文件合并 (7 → 3)

**当前文件**:
- `nextpas.core.simd.cpuinfo.pas` (23KB)
- `nextpas.core.simd.cpuinfo.arm.pas` (33KB)
- `nextpas.core.simd.cpuinfo.base.pas` (8.7KB)
- `nextpas.core.simd.cpuinfo.darwin.pas` (1.4KB)
- `nextpas.core.simd.cpuinfo.diagnostic.pas` (14KB)
- `nextpas.core.simd.cpuinfo.lazy.pas` (28KB)
- `nextpas.core.simd.cpuinfo.loongarch.pas` (6.1KB)
- `nextpas.core.simd.cpuinfo.riscv.pas` (41KB)
- `nextpas.core.simd.cpuinfo.unix.pas` (3.4KB)

**合并方案**:
- 保留 `nextpas.core.simd.cpuinfo.pas` 作为主文件
- 将 cpuinfo.base.pas 合并到 cpuinfo.pas
- 将 cpuinfo.arm.pas 合并到 cpuinfo.pas
- 将 cpuinfo.riscv.pas 合并到 cpuinfo.pas
- 将 cpuinfo.loongarch.pas 合并到 cpuinfo.pas
- 将 cpuinfo.darwin.pas 合并到 cpuinfo.pas
- 将 cpuinfo.unix.pas 合并到 cpuinfo.pas
- 将 cpuinfo.lazy.pas 合并到 cpuinfo.pas
- 将 cpuinfo.diagnostic.pas 合并到 cpuinfo.pas

**预计减少**: 8 个文件

### 4. Dispatch 文件合并 (5 → 2)

**当前文件**:
- `nextpas.core.simd.dispatch.pas` (主文件)
- `nextpas.core.simd.dispatch.baseline.inc` (基线实现)
- `nextpas.core.simd.dispatch.hooks.intf.inc` (钩子接口)
- `nextpas.core.simd.dispatch.table.inc` (表定义)

**合并方案**:
- 保留 `nextpas.core.simd.dispatch.pas` 作为主文件
- 将 dispatch.baseline.inc 合并到 dispatch.pas
- 将 dispatch.hooks.intf.inc 合并到 dispatch.pas
- 将 dispatch.table.inc 合并到 dispatch.pas

**预计减少**: 3 个文件

### 5. Intrinsics 文件合并 (18 → 6)

**当前文件**:
- `nextpas.core.simd.intrinsics.aes.pas`
- `nextpas.core.simd.intrinsics.avx.pas`
- `nextpas.core.simd.intrinsics.avx2.pas`
- `nextpas.core.simd.intrinsics.avx512.pas`
- `nextpas.core.simd.intrinsics.base.pas`
- `nextpas.core.simd.intrinsics.fma3.pas`
- `nextpas.core.simd.intrinsics.lasx.pas`
- `nextpas.core.simd.intrinsics.mmx.pas`
- `nextpas.core.simd.intrinsics.neon.pas`
- `nextpas.core.simd.intrinsics.rvv.pas`
- `nextpas.core.simd.intrinsics.sha.pas`
- `nextpas.core.simd.intrinsics.sse.pas`
- `nextpas.core.simd.intrinsics.sse3.pas`
- `nextpas.core.simd.intrinsics.sse41.pas`
- `nextpas.core.simd.intrinsics.sse42.pas`
- `nextpas.core.simd.intrinsics.sve.pas`
- `nextpas.core.simd.intrinsics.sve.base.pas`
- `nextpas.core.simd.intrinsics.sve2.pas`
- `nextpas.core.simd.intrinsics.sse2.pas`

**合并方案**:
- x86 合并: sse2 + sse3 + sse41 + sse42 + avx + avx2 + avx512 + fma3 + aes + sha + mmx → `intrinsics.x86.pas`
- ARM 合并: neon + sve + sve2 + sve.base → `intrinsics.arm.pas`
- RISC-V: rvv → `intrinsics.riscv.pas`
- LoongArch: lasx → `intrinsics.loongarch.pas`
- 保留 `intrinsics.base.pas` 作为基础类型

**预计减少**: 13 个文件

### 6. 其他文件合并

**可合并文件**:
- `nextpas.core.simd.arrays.pas` + `nextpas.core.simd.arrays.typed.pas` → `nextpas.core.simd.arrays.pas`
- `nextpas.core.simd.pipeline.pas` + `nextpas.core.simd.pipeline.f64.pas` → `nextpas.core.simd.pipeline.pas`
- `nextpas.core.simd.vec.pas` + `nextpas.core.simd.vec16.pas` + `nextpas.core.simd.vec32.pas` + `nextpas.core.simd.vec64.pas` → `nextpas.core.simd.vec.pas`

**预计减少**: 5 个文件

## 总计减少

| 类别 | 当前 | 合并后 | 减少 |
|------|------|--------|------|
| SSE 变体 | 5 | 1 | 4 |
| AVX 变体 | 2 | 1 | 1 |
| CPUInfo | 9 | 3 | 6 |
| Dispatch | 5 | 2 | 3 |
| Intrinsics | 18 | 6 | 12 |
| 其他 | 44 | 39 | 5 |
| **总计** | **83** | **52** | **31** |

## 实施步骤

### Step 1: SSE 变体合并 (Week 1)
- [ ] 分析 sse3/sse41/sse42 函数依赖
- [ ] 合并 sse3 函数到 sse2.pas
- [ ] 合并 sse41 函数到 sse2.pas
- [ ] 合并 sse42 函数到 sse2.pas
- [ ] 合并 sse2.i386.pas 到 sse2.pas
- [ ] 测试验证

### Step 2: AVX 变体合并 (Week 1)
- [ ] 分析 avx512 函数依赖
- [ ] 合并 avx512 函数到 avx2.pas
- [ ] 测试验证

### Step 3: CPUInfo 合并 (Week 2)
- [ ] 分析 cpuinfo 文件依赖
- [ ] 合并 cpuinfo.base.pas
- [ ] 合并 cpuinfo.arm.pas
- [ ] 合并 cpuinfo.riscv.pas
- [ ] 合并 cpuinfo.loongarch.pas
- [ ] 合并 cpuinfo.darwin.pas
- [ ] 合并 cpuinfo.unix.pas
- [ ] 合并 cpuinfo.lazy.pas
- [ ] 合并 cpuinfo.diagnostic.pas
- [ ] 测试验证

### Step 4: Dispatch 合并 (Week 2)
- [ ] 分析 dispatch 文件依赖
- [ ] 合并 dispatch.baseline.inc
- [ ] 合并 dispatch.hooks.intf.inc
- [ ] 合并 dispatch.table.inc
- [ ] 测试验证

### Step 5: Intrinsics 合并 (Week 3)
- [ ] 分析 intrinsics 文件依赖
- [ ] 合并 x86 intrinsics
- [ ] 合并 ARM intrinsics
- [ ] 保留 RISC-V intrinsics
- [ ] 保留 LoongArch intrinsics
- [ ] 测试验证

### Step 6: 其他文件合并 (Week 3)
- [ ] 合并 arrays 文件
- [ ] 合并 pipeline 文件
- [ ] 合并 vec 文件
- [ ] 测试验证

## 风险评估

| 风险 | 影响 | 概率 | 缓解措施 |
|------|------|------|----------|
| 编译错误 | 高 | 中 | 逐步合并，每步测试 |
| 性能回归 | 中 | 低 | 基准测试验证 |
| 依赖冲突 | 中 | 低 | 分析依赖关系 |
| 测试失败 | 高 | 中 | 完整测试套件 |

## 验证标准

- [ ] 所有测试通过
- [ ] 性能无回归
- [ ] 文件数量减少 ≥ 30%
- [ ] 编译无错误
- [ ] 文档更新完整
