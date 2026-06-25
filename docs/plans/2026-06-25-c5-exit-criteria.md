# C5 Exit Criteria (2026-06-25)

> C5 (lvalue/address 模型) 的完成标准。C5-A 到 C5-P 已全部完成，
> 本文档定义剩余的收口工作 (C5-Q) 和完成检查清单 (C5-R)。

## 已建立的 Structured Contract

| Contract | Node Kind | Producer | Consumer |
|----------|-----------|----------|----------|
| Scalar value | `shekSymbolValue`, `shekBinaryOp`, `shekCast`, `shekLiteral` | C3-B1~B6, C4-D | `LowerExprValue` |
| Address | `shekSymbolAddress`, `shekAddressOf`, `shekDeref` | C5-B | `LowerExprAddress` |
| Array element | `shekArrayElem` | C5-C, C5-H | `LowerExprAddress` |
| Field access | `shekField` | C5-D, C5-F | `LowerExprAddress` |
| Nested lvalue | `shekField -> shekArrayElem` chain | C5-I, C5-J, C5-K | `LowerExprAddress` |
| Value load | `shekDeref(shvcAddress)` | C5-L, C5-M | `LowerExprValue` |
| Direct call | `shekCall` | C5-N | `LowerExpr` → LLVM call |
| Ordinary member call | `shekCall` | C5-O | `LowerExpr` → LLVM call |
| Virtual/interface call | `shekVirtualCall` / `shekInterfaceCall` | C5-P | `LowerExpr` → LLVM call |

## 已挂 ExprId/TargetExprId 的路径

| 路径 | ExprId | TargetExprId | 状态 |
|------|--------|-------------|------|
| `halt-call-runtime` | ✅ | N/A | C3-B1 |
| `write-int-runtime` | ✅ | N/A | C3-B2 |
| `ret-runtime` | ✅ | N/A | C3-B3 |
| `cond-br-runtime` | ✅ | N/A | C3-B4 |
| `assign-runtime` (scalar) | ✅ | N/A | C3-B5 |
| `assign-runtime` (Inc/Dec) | ✅ | N/A | C3-B6 |
| `field-store-runtime` | ✅ (RHS) | ✅ (LHS) | C5-E, C5-F |
| `record-field-store-runtime` | ✅ (RHS) | ✅ (LHS) | C5-E, C5-F |
| `assign-arr-elem-runtime` | ✅ (RHS) | ✅ (LHS) | C5-G, C5-H |
| `call-runtime` (direct) | ✅ | N/A | C5-N |
| `call-runtime` (member) | ✅ | N/A | C5-O |
| `call-runtime` (virtual/iface) | ✅ | N/A | C5-P |
| pointer-return helper | ✅ | N/A | C5-N |

## C5-Q: 剩余 Special-Case 审计

以下 special-case 已识别但明确留给 C6/C7：

| Special-Case | 位置 | 为什么不在 C5 |
|-------------|------|--------------|
| `class-new-runtime` (constructor) | sema:12897,13009,13030,13046,13094,14180 | 需要 C6-A allocator 完成后才能定义 object ownership contract |
| `assign-tstring-*` (string copy/concat) | sema:多处 | 需要 C6-B string ownership 收尾 |
| `record-copy-runtime` | sema:13508 | record value semantics 留给 C6 |
| `field-store-tstring-runtime` | sema:13113+ | 最近 bug fix 加入，属于 C6 域 |

## C5 完成定义

- [x] C5-A ~ C5-P 全部完成
- [x] 结构化 call contract (`shekCall`/`shekVirtualCall`/`shekInterfaceCall`) 已建立并工作
- [x] 结构化 lvalue chain (field/array/deref) 已建立并工作
- [x] Dual-track (结构化 + blob fallback) 在所有已迁移路径上工作
- [x] 编译器重编译通过 (43404 lines)
- [x] LLVM smoke 测试通过
- [x] 剩余 special-case 已审计并记录为 C6 工作
- [ ] `test_semantic_hir_expr_producer` 全绿 (当前 exit=102, 需要调查)

## C5 正式完成

一旦 `test_semantic_hir_expr_producer` 的 exit=102 问题解决，C5 即可标记为完成。
