# Dispatch Table Modularization - Implementation Plan

## 目标

将 `TSimdDispatchTable` 拆分为逻辑子记录，提升代码可维护性和可扩展性。

## 实施阶段

### Phase 1: 定义子记录类型 (1-2 小时)

**任务**:
1. 创建 `core/src/nextpas.core.simd.dispatch.types.inc`
2. 定义所有子记录类型
3. 更新主 dispatch table 使用子记录

**文件修改**:
- `core/src/nextpas.core.simd.dispatch.types.inc` (新建)
- `core/src/nextpas.core.simd.dispatch.table.inc` (修改)
- `core/src/nextpas.core.simd.dispatch.pas` (修改)

**验证**:
- 编译通过
- 所有测试通过

### Phase 2: 更新 Scalar Backend (1-2 小时)

**任务**:
1. 更新 `nextpas.core.simd.scalar.pas` 使用子记录
2. 更新所有 scalar 实现文件
3. 验证 scalar backend 正常工作

**文件修改**:
- `core/src/nextpas.core.simd.scalar.pas`
- `core/src/nextpas.core.simd.scalar.*.inc`

**验证**:
- Scalar backend 测试通过
- 静态调度测试通过

### Phase 3: 更新 SSE2 Backend (2-3 小时)

**任务**:
1. 更新 `nextpas.core.simd.sse2.pas` 使用子记录
2. 更新所有 SSE2 实现文件
3. 验证 SSE2 backend 正常工作

**文件修改**:
- `core/src/nextpas.core.simd.sse2.pas`
- `core/src/nextpas.core.simd.sse2.register.inc`
- `core/src/nextpas.core.simd.sse2.batch.inc`

**验证**:
- SSE2 backend 测试通过
- 性能无回退

### Phase 4: 更新 AVX2 Backend (2-3 小时)

**任务**:
1. 更新 `nextpas.core.simd.avx2.pas` 使用子记录
2. 更新所有 AVX2 实现文件
3. 验证 AVX2 backend 正常工作

**文件修改**:
- `core/src/nextpas.core.simd.avx2.pas`
- `core/src/nextpas.core.simd.avx2.register.inc`
- `core/src/nextpas.core.simd.avx2.batch.inc`

**验证**:
- AVX2 backend 测试通过
- 性能无回退

### Phase 5: 更新 AVX512 Backend (2-3 小时)

**任务**:
1. 更新 `nextpas.core.simd.avx512.pas` 使用子记录
2. 更新所有 AVX512 实现文件
3. 验证 AVX512 backend 正常工作

**文件修改**:
- `core/src/nextpas.core.simd.avx512.pas`
- `core/src/nextpas.core.simd.avx512.register.inc`
- `core/src/nextpas.core.simd.avx512.batch.inc`

**验证**:
- AVX512 backend 测试通过
- 性能无回退

### Phase 6: 更新其他 Backend (2-3 小时)

**任务**:
1. 更新 NEON backend
2. 更新 RVV backend
3. 更新其他 backend (LoongArch, PPC64, etc.)

**文件修改**:
- `core/src/nextpas.core.simd.neon.pas`
- `core/src/nextpas.core.simd.riscvv.pas`
- 其他 backend 文件

**验证**:
- 所有 backend 测试通过
- 跨平台兼容性验证

### Phase 7: 更新公共 API (1-2 小时)

**任务**:
1. 更新所有 facade 函数使用新的访问模式
2. 确保所有测试通过
3. 更新文档

**文件修改**:
- `core/src/nextpas.core.simd.pas`
- `core/src/nextpas.core.simd.impl.static.inc`
- `core/src/nextpas.core.simd.impl.core.inc`

**验证**:
- 所有测试通过 (1730 tests)
- 公共 API 保持不变
- 文档完整更新

### Phase 8: 清理和优化 (1 小时)

**任务**:
1. 移除旧的 dispatch table 定义
2. 优化子记录访问路径
3. 更新基准测试
4. 更新 roadmap

**文件修改**:
- 清理临时文件
- 更新 `core/docs/simd/roadmap.md`

**验证**:
- 所有测试通过
- 性能无回退
- 文档完整

## 总时间估计

- Phase 1-2: 2-4 小时
- Phase 3-4: 4-6 小时
- Phase 5-6: 4-6 小时
- Phase 7-8: 2-3 小时
- **总计**: 12-19 小时

## 风险缓解

1. **分阶段验证**: 每个 phase 完成后验证测试通过
2. **向后兼容**: 公共 API 保持不变
3. **性能监控**: 每个 phase 后运行基准测试
4. **回滚计划**: 如果发现问题，可以回滚到上一个 phase

## 成功标准

1. 所有测试通过 (1730 tests)
2. 性能无回退
3. 代码可读性提升
4. 新增操作更容易添加
5. 文档完整更新
