# C5-N 计划：structured direct-call expr lowering

## Goal

不再继续修一个 RHS 分支补一个特判，而是把第一条真正 end-to-end 的结构化 call
expr 收进来：direct free-function call。范围限定在 legacy ABI 仍能直接承接的子集：
`i` / `p` 参数，`i64` / `ptr` 返回。旧 blob fallback 保留，失败时整条 call 仍可回退。

## Checklist

- [x] 确认 dirty 边界：只改 `compiler/sema`、`compiler/ir`、`compiler/tests` 与状态文档，不碰并行 toolchain/targets lane。
- [x] 收口 call expr 合同：`LiteralStr=callee`、`Op=paramKinds`、`Children=args`、
      `TypeId=return type`、`ValueClass=shvcScalar`。
- [x] 在 sema 让 direct free-function call 产出 `shekCall`，并保持 blob 双轨。
- [x] 放开 class/pointer-return helper assignment 的 `ExprId` 挂接。
- [x] 在 builder 增加 `shekCall` lowering，只接受 legacy ABI 兼容子集，不兼容时回落 blob。
- [x] 增加 focused tests，证明 producer 真产出 `shekCall`，builder 真走 structured path。
- [x] 跑 changed tests、完整重编译、137 LLVM smoke。
- [x] 更新目标树、`docs/inbox.md`、计划/进度/发现文档，并准备 path-limited commit。

## Constraints

- 本轮只做 direct free-function call；不进 overload、member call、virtual call、interface call。
- 参数只接受 `i` / `p`；`string`、`record`、`var/out`、array 继续回退旧 blob。
- 返回只 lower legacy ABI 兼容子集；不兼容返回类型继续回退旧 blob。
- `ExprId` 只表示 RHS/value；`TargetExprId` 只表示 LHS/address。
- 编译器改动必须过 `scripts/rebuild-compiler.sh`，确认是 `40000+ lines compiled`。
- 全量 LLVM smoke 仍以 `examples/smoke/llvm_*.pas` 为准，全部 exit code 必须为 `42`。

## Verification

- Changed tests:
  - `compiler/tests/test_hir_builder_expr_fallback` -> `exit=0`
  - `compiler/tests/test_semantic_hir_expr_producer` -> `exit=0`
  - `compiler/tests/test_hir_builder_structured_address` -> `exit=0`
- Full rebuild:
  - `bash scripts/rebuild-compiler.sh` -> `44341 lines compiled`
- LLVM smoke:
  - `smoke_total=137 passed=137 failed=0 build_failed=0 run_failed=0`
