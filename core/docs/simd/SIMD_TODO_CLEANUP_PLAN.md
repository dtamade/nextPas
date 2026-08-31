# math-simd 完善计划

> 创建: 2026-08-31
> 状态: **ARCHIVED** — 源码 TODO 清零目标已完成；勿当主线；现行路线见 [roadmap.md](roadmap.md)

## 总览

4 个工作包，13 个任务项：

| 工作包 | 任务数 | 预估改动 |
|--------|--------|----------|
| A. 源码 TODO 清理 | 5 | 5 文件 |
| B. 测试 TODO 清理 | 2 | 1 文件 |
| C. 文档同步 | 3 | 3 文件 |
| D. 性能优化 | 3 | 2-3 文件 |

---

## A. 源码 TODO 清理 (5 个)

### A1-A4. 后端注册 STUB → {$NOTE}

**文件:**
- `core/src/nextpas.core.simd.wasm.pas:224`
- `core/src/nextpas.core.simd.loongarch.pas:225`
- `core/src/nextpas.core.simd.power.pas:227`
- `core/src/nextpas.core.simd.mips.pas:224`

**操作:**
1. 将 `// TODO: Register XXX backend with dispatch system` 替换为 `{$NOTE SIMD-XXX: backend registration deferred — blocked on FPC compiler support}`
2. 在代码中已有的 `{$IFDEF}` 块中添加 `{$NOTE}`，让 FPC 编译时给出提示
3. 不删除任何代码，仅标记状态

**阻塞原因:**
- WASM: FPC WASM32 无 SIMD128 内联支持
- LASX: FPC LoongArch 内联汇编不支持 LASX
- VSX: FPC PPC64 内联汇编不支持 VSX
- MSA: FPC mips64el InternalError

### A5. GEMM NEON 微内核实现

**文件:** `core/src/nextpas.core.simd.linalg.gemm.neon.pas`

**操作:**
1. 实现 `GemmMicro4x8F32_NEON_Zero`: 4×8 F32 矩阵乘法微内核
   - 使用 `vfmaq_f32` (FMA) 指令
   - 4 行 × 8 列 = 32 个 float = 8 个 NEON 寄存器
   - C = A × B + C，按列主序
2. 实现辅助函数: PackA/PackB 矩阵打包
3. 添加正确性测试

**算法:**
```
for k = 0 to K-1:
  for i = 0 to 3:
    a_vec = vdupq_n_f32(A[i*K+k])  // 广播 A[i,k]
    for j = 0 to 7 step 4:
      C[i*8+j:i*8+j+3] += a_vec * B[k*8+j:k*8+j+3]
```

---

## B. 测试 TODO 清理 (2 个)

### B1. SSE4.2 字符串搜索测试

**文件:** `core/tests/nextpas.core.simd/nextpas.core.simd.testcase.pas`

**操作:**
1. 取消注释 published 声明 (line 142-143): `procedure Test_SSE42_StringSearchHelpers;`
2. 取消注释测试体 (line 2188-2217)
3. 迁移断言: `AssertEquals(msg, exp, act)` → `CheckEqual(exp, act, msg)`
4. 函数已存在于 `nextpas.core.simd.sse42.pas`: `FindFirstOf_SSE42`, `FindFirstNotOf_SSE42`

### B2. SSE4.2 CRC32C 测试

**文件:** `core/tests/nextpas.core.simd/nextpas.core.simd.testcase.pas`

**操作:**
1. 取消注释 published 声明 (line 145-146): `procedure Test_SSE42_CRC32C_Contracts;`
2. 取消注释测试体 (line 2219-2249)
3. 迁移断言: `AssertEquals(msg, exp, act)` → `CheckEqual(exp, act, msg)`
4. 函数已存在: `CRC32C_Buffer`, `CRC32C_16`, `CRC32C_32`, `CRC32C_64`

---

## C. 文档同步 (3 个)

### C1. roadmap.md 去重

**文件:** `core/docs/simd/roadmap.md`

**操作:** 删除 line 55-81 重复的"已完成"区块 (与 line 33-51 完全相同)

### C2. plan.md 进度同步

**文件:** `core/docs/simd/plan.md`

**操作:**
1. 更新进度追踪表: Phase 1-10 标记 ✅ 完成
2. Phase 11 标记为 🔒 未来 (阻塞于 nextpas 编译器)
3. 同步实际性能数据到成功标准
4. 更新最后更新日期

### C3. plan.md 性能数据更新

**操作:** 在 plan.md 中添加实际基准测试结果:
- ArrayAddF32: 2.24x (目标 6x)
- ArrayMulF32: 2.23x (目标 4x)
- MemEqual: 2.32x (目标 4x)

---

## D. 性能优化 (3 个)

### D1. 公平基准测试方法

**问题:** FPC `-O2` 自动向量化标量基准，SIMD 加速比被低估。

**方案:**
1. 在标量基准函数上添加 `{$OPTIMIZATION NOVECTORIZE}` 编译指令
2. 或使用 `{$PUSH}` / `{$POP}` 包裹标量函数
3. 确保标量基准是真正的标量循环，不被 FPC 自动向量化

**文件:** `core/src/nextpas.core.simd.arrays.typed.pas` 中的标量回退路径

### D2. ArrayAddF32 深度优化

**当前:** SSE2 4x 展开, AVX2 8x 展开
**目标:** 6x 加速比

**优化策略:**
1. AVX2: 增加到 16x 展开 (512 elements/iter)
2. 非对齐数据: 先对齐到 32B 边界，再批量处理
3. 预取距离调优: 从 4096 elements 降到 2048
4. 非临时存储: 降低阈值从 4096 到 2048 elements

### D3. MemEqual SIMD 早期退出

**当前:** 2.32x (4KB)
**目标:** 4x

**优化策略:**
1. SIMD 比较 + `vptestnmd` (AVX2) 检测零差异
2. 早期退出: 发现不匹配立即返回 false
3. 64B 批量比较 (AVX2 2x ymm)
4. 尾部处理: 标量逐字节比较

---

## 执行顺序

```
A1-A4 (后端 {$NOTE})  ← 最简单，先做
  ↓
B1-B2 (测试取消注释)  ← 依赖 A 无，可并行
  ↓
C1-C3 (文档同步)      ← 依赖 A/B 完成后更新数据
  ↓
D1 (公平基准)         ← 核心：修正基准方法
  ↓
D2 (ArrayAdd 优化)    ← 依赖 D1
  ↓
D3 (MemEqual 优化)    ← 依赖 D1
  ↓
A5 (GEMM NEON)        ← 最复杂，最后做
```

## 验证

每个工作包完成后运行:
```bash
make -C core/tests/nextpas.core.simd clean test
```

全部完成后运行:
```bash
make test
make hygiene
```
