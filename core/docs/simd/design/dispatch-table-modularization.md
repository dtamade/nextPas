# Dispatch Table Modularization Design

## 当前状态

**Phase 19 已完成（Phase 1–6，2026-07-17）。**

`TSimdDispatchTable` 已拆为嵌套子记录，生产路径：

| 字段 | 类型 | 规模 | 说明 |
|------|------|------|------|
| `Backend` / `BackendInfo` | 元数据 | — | 后端身份与能力位 |
| `CoreVectors` | `TSimdCoreVectorOps` | 533 | 全宽向量槽；字段名完整保留（`AddF32x4`…） |
| `Memory` | `TSimdMemoryOps` | 15 | 原 `Mem*`/`SumBytes`/…；`MemSet`→`Fill` 等映射见 Phase 4 |
| `Mask` | `TSimdMaskOps` | 20 | `Mask2/4/8/16*` |
| `BatchF32` | `TSimdBatchF32Ops` | 48 | F32 批量与 F32 超越/归约 |
| `BatchF64` | `TSimdBatchF64Ops` | 48 | F64 批量与 F64 超越/归约 |
| `BatchInteger` | `TSimdBatchIntegerOps` | 52 型 / baseline 11 fill | 整数批量；未 fill 槽靠 clone 链 |

**未落地（刻意不做）**：
- 按 lane 缩短名的 `TSimdVecF32x4Ops.Add` 风格（Phase 6 已删除实验草稿）
- 独立 `TranscendentalF32/F64` / `Utility` 子记录（超越与归约留在 `BatchF32`/`BatchF64`）
- 未使用的 `dispatch.table.new.inc` 草稿（Phase 6 删除）

**Public ABI**：`TNextPasSimdPublicApi` 与 facade 签名仍 flat。

## 设计目标

1. **模块化**: 将 dispatch table 拆分为逻辑子记录
2. **可维护性**: 每个子记录专注于一类操作
3. **可扩展性**: 新增操作只需修改对应的子记录
4. **向后兼容**: 保持现有公共 API 不变
5. **零开销**: 子记录组合不增加运行时开销

## 模块化方案

### 子记录定义（落地形态）

```pascal
// 1. 核心向量操作（字段名完整，不缩短）
TSimdCoreVectorOps = record
  // F32x4
  AddF32x4: function(const a, b: TVecF32x4): TVecF32x4;
  SubF32x4: function(const a, b: TVecF32x4): TVecF32x4;
  MulF32x4: function(const a, b: TVecF32x4): TVecF32x4;
  DivF32x4: function(const a, b: TVecF32x4): TVecF32x4;
  // ... 其他 F32x4 / F64x2 / I32x4 / wide / sat 等共 533 槽
end;

// 2. 内存操作（嵌表字段短名；facade 仍 Mem*）
TSimdMemoryOps = record
  Equal: function(a, b: Pointer; len: SizeUInt): LongBool;
  FindByte: function(p: Pointer; len: SizeUInt; value: Byte): PtrInt;
  DiffRange: function(a, b: Pointer; len: SizeUInt; out firstDiff, lastDiff: SizeUInt): Boolean;
  Copy: procedure(src, dst: Pointer; len: SizeUInt);
  Fill: procedure(dst: Pointer; len: SizeUInt; value: Byte);
  Reverse: procedure(p: Pointer; len: SizeUInt);
  // ... SumBytes / Utf8Validate / BitsetPopCount 等
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

// 5. 整数批量操作
TSimdBatchIntegerOps = record
  ArrayAddI32: procedure(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt);
  // ... 其余整数/转换槽（见 types.inc）
end;

// 6. Mask 操作
TSimdMaskOps = record
  Mask2All: function(mask: TMask2): Boolean;
  // ... Mask2/4/8/16 *
end;
```

> 说明：早期设计稿中的 `Transcendental*` / `Utility` 独立子记录**未落地**；对应槽位已并入 `BatchF32` / `BatchF64`。

### 主 Dispatch Table 组合（落地）

```pascal
TSimdDispatchTable = record
  Backend: TSimdBackend;
  BackendInfo: TSimdBackendInfo;
  CoreVectors: TSimdCoreVectorOps;
  Memory: TSimdMemoryOps;
  Mask: TSimdMaskOps;
  BatchF32: TSimdBatchF32Ops;
  BatchF64: TSimdBatchF64Ops;
  BatchInteger: TSimdBatchIntegerOps;
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

### Phase 1: 定义子记录类型 — ✅
1. `nextpas.core.simd.dispatch.types.inc` 已定义 `TSimdBatchF32Ops` / `TSimdBatchF64Ops` 等子记录
2. accessor 层与 F32/F64 对等契约已落地

### Phase 2: 嵌进主表 + Backend register — ✅ (2026-07-17)
1. `TSimdDispatchTable` 中 flat `Array*F32` / `Array*F64` / `Reduce*F32` / `Reduce*F64` 槽位迁入 `BatchF32` / `BatchF64`
2. Scalar baseline、SSE2/AVX2/AVX512 register fill 改为 `dispatchTable.BatchF32.*` / `BatchF64.*`
3. facade (`nextpas.core.simd.pas`)、accessors、pipeline、arrays、algorithms、相关 tests/benches 同步迁路径
4. 公共 `Array*F32` / `Array*F64` API 签名不变；仅内部访问路径变化
5. 附带修复：`SSE2`/`AVX2` `ArrayLinearReLUF64` 语义对齐 `max(0, scale*x+bias)`；api-coverage Round/Rsqrt/Smoothstep 期望与 `System.Round` / 浮点契约对齐

### Phase 3: BatchInteger 嵌表 — ✅ (2026-07-17)
1. `TSimdDispatchTable` 中 flat 整数批量槽迁入 `BatchInteger: TSimdBatchIntegerOps`（类型 52 字段）
2. Scalar baseline、SSE2/AVX2/AVX512 register fill 改为 `dispatchTable.BatchInteger.*`
3. facade 公开 `Array*I*` / 转换 / 位运算入口、accessor、相关 benches 同步迁路径
4. 公共 `ArrayAddI32` 等 API 签名不变；仅内部访问路径变化
5. **非目标**：不补齐 baseline 历史未实现的 41/52 scalar 槽（与 HEAD fill 面一致；依赖 clone 链继承）

### Phase 4: Memory + Mask 嵌表 — ✅ (2026-07-17)
1. `TSimdDispatchTable` 中 flat Memory/Mask 槽迁入 `Memory: TSimdMemoryOps`（15 字段）与 `Mask: TSimdMaskOps`（20 字段）
2. 命名映射：`MemEqual`→`Memory.Equal`，`MemFindByte`→`Memory.FindByte`，`MemDiffRange`→`Memory.DiffRange`，`MemCopy`→`Memory.Copy`，`MemSet`→`Memory.Fill`，`MemReverse`→`Memory.Reverse`；其余聚合/字符串/bitset 槽同名迁入 `Memory.*`；`Mask*` 迁入 `Mask.Mask*`
3. Scalar baseline、SSE2/SSE4.2/AVX2/AVX512/NEON/RVV register fill 改为 `dispatchTable.Memory.*` / `dispatchTable.Mask.*`
4. facade 公开 `Mem*`/`Mask*` API、accessor、dataplane、adapter map、text.utf8、相关 tests/benches 同步迁路径
5. **保持不变**：`TNextPasSimdPublicApi` / V2 Public ABI 字段名仍 flat（`MemEqual`/`MemSet`/`SumBytes`…）；对外 facade 签名不变

### Phase 5: CoreVectors 嵌表 — ✅ (2026-07-17)
1. 定义 `TSimdCoreVectorOps`（533 字段，字段名保持完整：`AddF32x4` / `SelectF32x16` / sat / AndNot…，不缩短为 `Add`）
2. `TSimdDispatchTable` 中原 flat 向量槽全部迁入 `CoreVectors: TSimdCoreVectorOps`
3. Scalar baseline、SSE2/SSE3/SSE4.1/SSE4.2/AVX2/AVX512/NEON/RVV register fill 改为 `dispatchTable.CoreVectors.*`
4. facade / accessors / dataplane / adapter map / algorithms / arrays / ops / impl.* / tests / benches 同步迁路径
5. source-contract `Pos('dispatchtable.corevectors.*')` 对齐（Fma/Select 宽向量等）
6. **保持不变**：对外 facade 签名与 Public ABI 字段名仍 flat；仅内部 dispatch 访问路径变化

### Phase 6: 清理和优化 — ✅ (2026-07-17)
1. **死草稿清理**：删除未接入的 `dispatch.table.new.inc`；删除未使用的 short-name 实验类型 `TSimdVecF32x4Ops` / `TSimdVecF64x2Ops` / `TSimdVecI32x4Ops`
2. **路径残留契约**：`Test_Phase19_DispatchTable_NestedOnly_NoDeadDraftArtifacts` 断言 table/types 仅嵌套组、register/baseline 禁止 flat 槽赋值
3. **NEON / RVV 对齐审计（路径级）**：
   - NEON / RVV 与 x86 使用**同一嵌套组名**（`table.CoreVectors.*` / `Memory.*` / `Mask.*`…），均 `FillBaseDispatchTable` 播种后按需 override
   - **槽级覆盖差距是刻意的**（非路径错位）：靠 baseline 继承，不在本 phase 补全 native 实现
     - NEON：有 `CoreVectors`（~332）+ 部分 `Memory`（9/15）；**无** Batch*/Mask override（继承 scalar）
     - RVV：有 `CoreVectors`（~412）+ 完整 `Mask`（20）；**无** Memory/Batch* override
     - x86 SSE2/AVX2：Batch/Memory/Mask 覆盖最全，供 clone 链（如 AVX2←SSE2）复用
4. 文档与 roadmap 记为 Phase 19 完成

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
