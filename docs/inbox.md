# nextPas 工作看板

> 快速扫状态用，不是日志。

## 当前在做什么

- `C5-N` 已完成：first structured direct-call expr slice 已落地。
  direct free-function call 现在可以生成 `shekCall`，不再只能靠 blob 文本回放。
- 这条 call expr 合同很克制：
  `LiteralStr=callee`、`Op=legacy ABI paramKinds`、`Children=args`、
  `TypeId=return type`、`ValueClass=shvcScalar`。
- builder 现在能真正 lower `shekCall`，但只接受 legacy ABI 兼容子集：
  `i` / `p` 参数，`i64` / `ptr` 返回。超出这条边界时整条 call 继续回退旧 blob。
- sema 里 direct pointer/class-return helper assignment 也开始挂 `ExprId`，
  不再只留下旧 `assign-runtime` blob。
- `ExprId` 继续只表示 RHS value；`TargetExprId` 表示 LHS address。
- 最近验证：changed tests 绿；`scripts/rebuild-compiler.sh`
  输出 `44341 lines compiled`；LLVM smoke `137/137`，全部 exit=42。

## 接下来怎么走

1. 把同样的结构化 call 合同推进到 member call：
   ordinary `obj.Method(...)` / `self.Method(...)`，优先收口最常见 non-virtual 直调。
2. 再进入真正的 `shekVirtualCall` / `shekInterfaceCall` lowering，把 vcall/ivcall
   从 blob-only 迁到结构化路径。
3. 最后再回头清 `WalkHaltCalls` 里剩余 constructor-like / raw object-dot 特殊分支，
   让 call producer 不再散落多套入口。
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
