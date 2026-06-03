# C5-M 计划：object-backed field-array value loads

## Goal

在 C5-L 已经收口 `FItems[i]` / `Self.FItems[i].A.B` value-side 之后，把对象接收者版本补齐：
`Other.FItems[i]`、`Other.FItems[i].A.B`，并同时覆盖 local assign 与 `Result` assign。
这轮继续保持 builder 不动，只在 sema 统一 object-backed field-array 识别，
让 structured `ExprId` 与 legacy blob fallback 双轨都成立。

## Checklist

- [x] 确认 dirty 边界：只改 `compiler/sema`、`compiler/tests`、状态文档，不碰并行 toolchain/targets lane。
- [x] 重读目标树、设计规范、`docs/inbox.md`、根计划文件和上一轮 C5-L 证据。
- [x] 写 RED：`Result := Other.FItems[i]`，确认失败不是 builder，而是 producer 没发 `assign-runtime`（`exit=83`）。
- [x] 补 coverage：direct/nested + local/result 四条 object-backed field-array value load producer 用例。
- [x] 在 sema 引入通用 class-field-array 识别，扩到 object receiver，同时保留 self/current-class wrapper。
- [x] 让 `BuildClassFieldArrayElementTargetExpr`、`ResolveArrayAccessElementTypeId`、
  `EncodeRuntimeIntExprFold` 共享同一 object-backed 识别结果。
- [x] 跑 changed tests、完整重编译、137 LLVM smoke。
- [x] 更新目标树、`docs/inbox.md`、计划/进度/发现文档，并准备 path-limited commit。

## Constraints

- `ExprId` 只表示 RHS/value；`TargetExprId` 只表示 LHS/address。
- 结构化表达式和旧 blob fallback 必须双轨并存；不能靠“只要 structured 成功就行”偷过。
- 这轮不进入 constructor-like RHS、pointer-return helper、raw `assign-runtime` 其他 class/object 分支。
- 编译器改动必须过 `scripts/rebuild-compiler.sh`，确认是 `40000+ lines compiled`。
- 全量 LLVM smoke 仍以 `examples/smoke/llvm_*.pas` 为准，全部 exit code 必须为 `42`。

## Verification

- Changed tests:
  - `compiler/tests/test_semantic_hir_expr_producer` -> `exit=0`
  - `compiler/tests/test_hir_builder_structured_address` -> `exit=0`
- Full rebuild:
  - `bash scripts/rebuild-compiler.sh` -> `44145 lines compiled`
- LLVM smoke:
  - `smoke_total=137 passed=137 failed=0 build_failed=0 run_failed=0`
