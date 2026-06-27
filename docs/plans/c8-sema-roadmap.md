# C8 Sema 修复路线图

> Codex 制定 2026-06-27

## 根因分析

437 个 sema 错误不是 9 类独立 bug，而是 **4 条根因链**：

1. **类型宇宙不完整** — `SeedBuiltinTypes` 缺 `PInt32`、`RawByteString`、更多 pointer alias
2. **`gnkFunctionCall` 三义混合** — 类型转换、intrinsic、普通调用走同一条路径
3. **无统一 designator resolver** — 字段赋值/record 设计器掉到错误路径
4. **表达式类型+重载打分太粗** — `InferExpressionType` 对 dot/array/deref 返回 0

## 修复顺序

| Phase | 目标 | 预期降错 |
|-------|------|----------|
| 1 | 类型入口 + cast/intrinsic 分流 | ~220-280 |
| 2 | designator/lvalue 统一 | ~80-110 |
| 3 | 表达式类型 + overload scoring | ~25-40 |
| 4 | imported unit / resolver 尾巴 | ~10-20 |
| 5 | corpus-driven 收尾 | → 可自举范围 |

## Phase 1 详细计划

1. **扩 builtin/public type 表** — `SeedBuiltinTypes` 补齐 ShortInt/SmallInt/Int32/UInt32/UInt64/PByte/PWord/PInt32/PInt16/PChar/PAnsiChar/RawByteString
2. **imported facade alias 接入类型图** — 泛化 `SeedCachedTypeGaps`，让 TMemoryStream/TStringList/Format 等进入 model
3. **call-shape 分类** — `gnkFunctionCall` 前置分流：type symbol → cast, SizeOf/High/Low/Length → intrinsic, 其余 → callable
4. **扩 `InferExpressionType`** — 认识 cast 结果、intrinsic 结果、alias unwrap
5. **加 focused regression** — `Byte(I)`、`PInt32(@Buf)^`、`RawByteString(S)`、`SizeOf(T)+16`、`TVarData(V).VType`

## 涉及文件

- `compiler/sema/np_semantic_analyzer.pas` (主要)
- `compiler/sema/np_semantic_model.pas` (少量)
- `compiler/frontend/np_unit_resolver.pas` (Phase 4)
- `compiler/frontend/np_unit_graph.pas` (Phase 4)
