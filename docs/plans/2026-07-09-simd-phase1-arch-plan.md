# Phase 1: 架构优化（编译时分派）实现计划

**分支**: simd-phase1-arch  
**目标**: 减少运行时分派开销，为后续优化奠定基础

---

## 任务清单

### 1.1 编译时 SIMD 宏系统 (核心)

#### 1.1.1 扩展 backend.select.inc
- [ ] 添加 SIMD_STATIC_BATCH_* 宏定义
- [ ] 添加 SIMD_STATIC_MEM_* 宏定义
- [ ] 添加 SIMD_STATIC_REDUCE_* 宏定义

#### 1.1.2 创建静态分派宏文件
- [ ] 创建 `nextpas.core.simd.static.batch.inc`
- [ ] 实现 ArrayAddF32/MulF32/SubF32/DivF32 静态分派
- [ ] 实现 ArrayAddU32/MulU32/SubU32 静态分派
- [ ] 实现 MemEqual/MemFindByte 静态分派
- [ ] 实现 ReduceMinF32/MaxF32/SumF32 静态分派

#### 1.1.3 集成到主模块
- [ ] 修改 `nextpas.core.simd.pas` 支持静态分派
- [ ] 添加编译开关 `SIMD_STATIC_BATCH_OPS`
- [ ] 确保向后兼容（动态分派仍然可用）

### 1.2 后端优先级配置

#### 1.2.1 编译时优先级
- [ ] 添加 `SIMD_BACKEND_PRIORITY` 编译时常量
- [ ] 支持用户自定义优先级顺序
- [ ] 默认优先级：AVX-512 > AVX2 > SSE2 > NEON > RVV > Scalar

#### 1.2.2 运行时优先级
- [ ] 添加 `SetSimdBackendPriority` 函数
- [ ] 添加 `GetSimdBackendPriority` 函数
- [ ] 支持动态切换后端（需要重新初始化）

### 1.3 自动向量化提示

#### 1.3.1 循环对齐提示
- [ ] 添加 `SIMD_ALIGN_LOOP` 宏
- [ ] 添加 `SIMD_ASSUME_ALIGNED` 宏
- [ ] 添加 `SIMD_PREFETCH` 宏

#### 1.3.2 数据依赖提示
- [ ] 添加 `SIMD_NO_ALIAS` 宏
- [ ] 添加 `SIMD_VECTORIZE` 编译指令支持

---

## 实现顺序

1. **第一步**: 扩展 backend.select.inc，添加静态分派宏定义
2. **第二步**: 创建 static.batch.inc，实现批量操作静态分派
3. **第三步**: 集成到主模块，添加编译开关
4. **第四步**: 实现后端优先级配置
5. **第五步**: 添加自动向量化提示宏
6. **第六步**: 测试验证

---

## 技术细节

### 静态分派宏设计

```pascal
// 编译时选择最优实现
{$IFDEF SIMD_STATIC_AVX2}
  {$DEFINE SIMD_STATIC_ArrayAddF32 := AVX2ArrayAddF32}
  {$DEFINE SIMD_STATIC_ArrayMulF32 := AVX2ArrayMulF32}
  {$DEFINE SIMD_STATIC_MemEqual := AVX2MemEqual}
{$ELSEIF SIMD_STATIC_SSE2}
  {$DEFINE SIMD_STATIC_ArrayAddF32 := SSE2ArrayAddF32}
  {$DEFINE SIMD_STATIC_ArrayMulF32 := SSE2ArrayMulF32}
  {$DEFINE SIMD_STATIC_MemEqual := SSE2MemEqual}
{$ELSE}
  {$DEFINE SIMD_STATIC_ArrayAddF32 := ScalarArrayAddF32}
  {$DEFINE SIMD_STATIC_ArrayMulF32 := ScalarArrayMulF32}
  {$DEFINE SIMD_STATIC_MemEqual := ScalarMemEqual}
{$ENDIF}

// 使用宏
procedure ProcessData(src1, src2, dst: PSingle; count: SizeUInt);
begin
  SIMD_STATIC_ArrayAddF32(src1, src2, dst, count);
end;
```

### 性能目标

- 运行时分派开销：~15-20 cycles → 0 cycles (静态分派)
- 函数调用开销：间接调用 → 直接调用（可内联）
- 预期提升：5-10% 对于小数组操作

---

## 验证标准

- [ ] 编译时宏系统实现并测试通过
- [ ] 后端优先级配置功能实现
- [ ] 运行时分派开销减少 50%+
- [ ] 所有现有测试通过 (1730 tests)
- [ ] 性能基准测试通过

---

**创建时间**: 2026-07-09  
**维护者**: dtamade
