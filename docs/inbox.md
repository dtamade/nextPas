# nextPas 工作看板

> 快速扫状态用，不是日志。

## 当前在做什么

- `C5-P` 已完成：structured dispatched call 已接通，`shekVirtualCall` /
  `shekInterfaceCall` 现在能 end-to-end lower，不再只靠 `vcall` / `ivcall`
  blob 文本回放。
- 这轮顺手修掉了一个真实回归：method body 里的非调用表达式会被 implicit-self
  bare-call 误判吞掉，典型症状是 `Result := Sum div Count;` 被结构化成只剩
  `Sum`。现在 implicit-self call 只接受真正的 bare call 形状
  （identifier / functioncall / procedurecallstatement）。
- call contract 继续保持克制：
  `LiteralStr=callee`、`LiteralInt=slot(仅 dispatched)`、
  `Op=legacy ABI paramKinds`、`Children=args`、`TypeId=return type`、
  `ValueClass=shvcScalar`。
- class receiver 的结构化形态继续固定为
  `shekDeref(shvcAddress) -> shekSymbolValue(Pointer)`；ordinary / virtual /
  interface call 都开始复用这套 address/value 合同。
- dual-track 仍然保留：builder 只 lower legacy ABI 兼容子集；不支持时继续整条回退
  旧 blob，不偷改行为。
- 最近验证：focused
  `test_semantic_hir_expr_producer`、`test_hir_builder_expr_fallback`、
  `test_hir_builder_structured_address`、`test_hir_builder_structured_expr` 全绿；
  `scripts/rebuild-compiler.sh` 输出 `45139 lines compiled`；
  `llvm_full_oop` exit=42；LLVM smoke `137/137`，全部 exit=42。

## 接下来怎么走

1. 收口 `WalkHaltCalls` 里剩余 constructor-like / raw object-dot /
   pointer-return helper call 特殊分支，减少 call producer 分叉。
2. 设计下一步 call/address 合同：是否把 receiver 从 `Op` 前导 `p`
   进一步显式化，避免 call kind 和参数 ABI 暗耦合。
3. 开始补 call surface 的剩余复杂面：overload、var-param、record/string return、
   property-like read/write。
4. `C6`：allocator 和真实释放；`C7/C8`：多目标、优化、自举探针。

## 重要约束

- 只改当前 compiler 主线需要的文件；不碰并行 `toolchain/targets/stage0/verify` lane。
- 每轮先给任务清单，再给结果报告。
- 编译器改动必须过 focused tests、完整 rebuild、137 LLVM smoke。
- 结构化表达式和旧 blob 双轨并存；没迁移的 producer 必须能回退。
- 运行时 helper 如果仍是 legacy i64 ABI，typed 值必须在 builder 侧显式归一。
- 旧 blob 的 pointer 暗号只能按最终表达式结果解释，不能用 receiver/中间行推断参数类型。
- implicit-self call 识别必须只接受真实 call shape，不能再吞 `binary/unary/compare`
  这类普通表达式。

## 入口文档

- 总路线：[`compiler/docs/compiler-goal-tree.md`](../compiler/docs/compiler-goal-tree.md)
- 当前批次：[`compiler/docs/plans/2026-06-03-c5n-structured-direct-call-lowering.md`](../compiler/docs/plans/2026-06-03-c5n-structured-direct-call-lowering.md)
