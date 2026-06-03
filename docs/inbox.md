# nextPas 工作看板

> 快速扫状态用，不是日志。

## 当前在做什么

- `C5-O` 已完成：ordinary non-virtual member call expr slice 已落地。
  `obj.Method(...)`、`Self.Method(...)`、zero-arg `obj.Method` 现在都能生成
  结构化 `shekCall`，不再只靠 member-call blob 文本回放。
- 这条 member-call 合同继续复用 `C5-N` 的克制设计：
  `LiteralStr=callee`、`Op=legacy ABI paramKinds`、`Children=args`、
  `TypeId=return type`、`ValueClass=shvcScalar`。
- class receiver 的结构化形态已经固定：
  `shekDeref(shvcAddress) -> shekSymbolValue(Pointer)`。
  这为后续 address/value 合同继续扩到 virtual/interface call 留了统一入口。
- dual-track 仍然保留：builder 继续只 lower legacy ABI 兼容子集；
  同时旧 blob 对显式 `Self.Method` / `Self.FieldLikeRead` 的兼容缺口已补齐，
  structured lowering 失败时仍可完整回退。
- 最近验证：focused
  `test_semantic_hir_expr_producer`、`test_hir_builder_structured_address` 全绿；
  `scripts/rebuild-compiler.sh` 输出 `44591 lines compiled`；
  LLVM smoke `137/137`，全部 exit=42。

## 接下来怎么走

1. 进入 `shekVirtualCall` / `shekInterfaceCall`，把 `vcall` / `ivcall`
   从 blob-only 迁到结构化路径。
2. 收口 `WalkHaltCalls` 里剩余 constructor-like / raw object-dot /
   pointer-return helper call 特殊分支，减少 call producer 分叉。
3. 评估 call contract 是否需要把 receiver 从 legacy `Op` 前导 `p`
   抽成更显式的 kind；这一步先设计，后落地。
4. `C6`：allocator 和真实释放；`C7/C8`：多目标、优化、自举探针。

## 重要约束

- 只改当前 compiler 主线需要的文件；不碰并行 `toolchain/targets/stage0/verify` lane。
- 每轮先给任务清单，再给结果报告。
- 编译器改动必须过 focused tests、完整 rebuild、137 LLVM smoke。
- 结构化表达式和旧 blob 双轨并存；没迁移的 producer 必须能回退。
- 运行时 helper 如果仍是 legacy i64 ABI，typed 值必须在 builder 侧显式归一。
- 旧 blob 的 pointer 暗号只能按最终表达式结果解释，不能用 receiver/中间行推断参数类型。

## 入口文档

- 总路线：[`compiler/docs/compiler-goal-tree.md`](../compiler/docs/compiler-goal-tree.md)
- 当前批次：[`compiler/docs/plans/2026-06-03-c5n-structured-direct-call-lowering.md`](../compiler/docs/plans/2026-06-03-c5n-structured-direct-call-lowering.md)
