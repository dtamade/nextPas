# Dispatch Table Modularization Design

## 当前状态

当前 `TSimdDispatchTable` 是一个单一的 record，包含 95+ 个批量操作和 100+ 个向量操作。所有操作混合在一起，难以维护和扩展。

## 设计目标

1. **模块化**: 将 dispatch table 拆分为逻辑子记录
2. **可维护性**: 每个子记录专注于一类操作
3. **可扩展性**: 新增操作只需修改对应的子记录
4. **向后兼容**: 保持现有公共 API 不变
5. **零开销**: 子记录组合不增加运行时开销

## 模块化方案

### 子记录定义

```pascal
// 1. 核心向量操作
TSimdCoreVectorOps = record
  // F32x4
  AddF32x4: function(const a, b: TVecF32x4): TVecF32x4;
  SubF32x4: function(const a, b: TVecF32x4): TVecF32x4;
  MulF32x4: function(const a, b: TVecF32x4): TVecF32x4;
  DivF32x4: function(const a, b: TVecF32x4): TVecF32x4;
  // ... 其他 F32x4 操作
  
  // F64x2
  AddF64x2: function(const a, b: TVecF64x2): TVecF64x2;
  SubF64x2: function(const a, b: TVecF64x2): TVecF64x2;
  // ... 其他 F64x2 操作
  
  // I32x4, I64x2, U64x2, F64x4, I32x8, F32x8, F32x16, F64x8, etc.
end;

// 2. 内存操作
TSimdMemoryOps = record
  MemEqual: function(a, b: Pointer; len: SizeUInt): LongBool;
  MemFindByte: function(p: Pointer; len: SizeUInt; value: Byte): PtrInt;
  MemDiffRange: function(a, b: Pointer; len: SizeUInt; out firstDiff, lastDiff: SizeUInt): Boolean;
  MemCopy: procedure(src, dst: Pointer; len: SizeUInt);
  MemSet: procedure(dst: Pointer; len: SizeUInt; value: Byte);
  MemReverse: procedure(p: Pointer; len: SizeUInt);
  // ... 其他内存操作
end;

// 3. F32 批量操作
TSimdBatchF32Ops = record
  ArrayAddF32: procedure(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
  ArraySubF32: procedure(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
  ArrayMulF32: procedure(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
  ArrayDivF32: procedure(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
  // ... 其他 F32 批量操作
end;

// 4. F64 批量操作
TSimdBatchF64Ops = record
  ArrayAddF64: procedure(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
  ArraySubF64: procedure(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
  ArrayMulF64: procedure(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
  ArrayDivF64: procedure(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
  // ... 其他 F64 批量操作
end;

// 5. F64 超越函数
TSimdTranscendentalF64Ops = record
  ArraySinF64: procedure(aSrc, aDst: PDouble; aCount: SizeUInt);
  ArrayCosF64: procedure(aSrc, aDst: PDouble; aCount: SizeUInt);
  ArrayExpF64: procedure(aSrc, aDst: PDouble; aCount: SizeUInt);
  ArrayLogF64: procedure(aSrc, aDst: PDouble; aCount: SizeUInt);
  // ... 其他 F64 超越函数
end;

// 6. F32 超越函数
TSimdTranscendentalF32Ops = record
  ArrayExpF32: procedure(aSrc, aDst: PSingle; aCount: SizeUInt);
  ArrayLogF32: procedure(aSrc, aDst: PSingle; aCount: SizeUInt);
  ArrayPowF32: procedure(aSrc, aDst: PSingle; aCount: SizeUInt; aExponent: Single);
  // ... 其他 F32 超越函数
end;

// 7. 整数批量操作
TSimdBatchIntegerOps = record
  // I32
  ArrayAddI32: procedure(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt);
  ArraySubI32: procedure(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt);
  ArrayMulI16: procedure(aSrc1, aSrc2, aDst: PInt16; aCount: SizeUInt);
  // ... 其他整数操作
  
  // I8, U8, I16, U16, I64, U64, U32
end;

// 8. 工具操作
TSimdUtilityOps = record
  // 聚合操作
  ReduceSumF32: function(aSrc: PSingle; aCount: SizeUInt): Single;
  ReduceDotF32: function(aSrc1, aSrc2: PSingle; aCount: SizeUInt): Single;
  ReduceMinF32: function(aSrc: PSingle; aCount: SizeUInt): Single;
  ReduceMaxF32: function(aSrc: PSingle; aCount: SizeUInt): Single;
  // ... 其他聚合操作
  
  // 类型转换
  ConvertF32ToI32: procedure(aSrc: PSingle; aDst: PInt32; aCount: SizeUInt);
  ConvertI32ToF32: procedure(aSrc: PInt32; aDst: PSingle; aCount: SizeUInt);
  // ... 其他类型转换
end;

// 9. Mask 操作
TSimdMaskOps = record
  // TMask2
  Mask2All: function(mask: TMask2): Boolean;
  Mask2Any: function(mask: TMask2): Boolean;
  Mask2None: function(mask: TMask2): Boolean;
  Mask2PopCount: function(mask: TMask2): Integer;
  Mask2FirstSet: function(mask: TMask2): Integer;
  
  // TMask4, TMask8, TMask16
end;
```

### 主 Dispatch Table 组合

```pascal
TSimdDispatchTable = record
  // Backend 信息
  Backend: TSimdBackend;
  BackendInfo: TSimdBackendInfo;
  
  // 组合子记录
  CoreVectors: TSimdCoreVectorOps;
  Memory: TSimdMemoryOps;
  BatchF32: TSimdBatchF32Ops;
  BatchF64: TSimdBatchF64Ops;
  TranscendentalF64: TSimdTranscendentalF64Ops;
  TranscendentalF32: TSimdTranscendentalF32Ops;
  BatchInteger: TSimdBatchIntegerOps;
  Utility: TSimdUtilityOps;
  Mask: TSimdMaskOps;
end;
```

## 公共 API 访问模式

### 当前模式
```pascal
function VecF32x4Add(const a, b: TVecF32x4): TVecF32x4; inline;
begin
  Result := GetSimdFacadeDispatchFastPath^.AddF32x4(a, b);
end;
```

### 新模式
```pascal
function VecF32x4Add(const a, b: TVecF32x4): TVecF32x4; inline;
begin
  Result := GetSimdFacadeDispatchFastPath^.CoreVectors.AddF32x4(a, b);
end;
```

## 实现步骤

### Phase 1: 定义子记录类型
1. 创建 `nextpas.core.simd.dispatch.types.inc`
2. 定义所有子记录类型
3. 更新主 dispatch table 使用子记录

### Phase 2: 更新 Backend 实现
1. 更新 SSE2 backend 使用子记录
2. 更新 AVX2 backend 使用子记录
3. 更新 AVX512 backend 使用子记录
4. 更新 Scalar backend 使用子记录
5. 更新其他 backend (NEON, RVV, etc.)

### Phase 3: 更新公共 API
1. 更新所有 facade 函数使用新的访问模式
2. 确保所有测试通过
3. 更新文档

### Phase 4: 清理和优化
1. 移除旧的 dispatch table 定义
2. 优化子记录访问路径
3. 更新基准测试

## 风险评估

### 低风险
- 子记录组合是编译时特性，无运行时开销
- 公共 API 保持不变，只是访问路径改变
- 可以逐步迁移，不需要一次性完成

### 中风险
- 需要更新所有 backend 实现
- 需要确保所有测试通过
- 需要更新文档和示例

### 缓解措施
- 分阶段实施，每阶段验证
- 保持向后兼容的过渡期
- 完整的测试覆盖

## 验证标准

1. 所有现有测试通过 (1730 tests)
2. 性能无回退
3. 代码可读性提升
4. 新增操作更容易添加
5. 文档完整更新
