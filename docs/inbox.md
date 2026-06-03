# nextPas 工作看板

> 快速扫状态用，不是日志。

## 当前在做什么

- `C5-L` 已完成：array/field-array 的 value-side 继续向结构化迁移。
  现在 `x := arr[i]`、`x := arr[i].A.B`、`y := FItems[i]`、
  `y := Self.FItems[i].A.B` 都能挂上结构化 `ExprId`。
- 这轮没有改 builder 主合同，修的是 sema 旧 blob gate：
  current-class field-array 缺少 value load blob，导致 `assign-runtime`
  节点根本发不出来。
- sema 继续复用共享 `BuildTargetAddressExpr`；
  value-side 仍然走“address-backed structured expr + legacy blob fallback”双轨。
- `C5-K` 的递归 target 与 `C5-K0` 的 constructor arg classification 修复都保持有效。
- `ExprId` 继续只表示 RHS value；`TargetExprId` 表示 LHS address。
- 旧 blob fallback 保留：`__field_arr__`、direct `arr$ptr`、field-array value load
  路径都还能回退。
- 最近验证：changed tests 绿；`scripts/rebuild-compiler.sh`
  输出 `44115 lines compiled`；LLVM smoke `137/137`，全部 exit=42。

## 接下来怎么走

1. `C5-M`：class/object RHS 特殊分支和剩余 value-side 缺口收口，继续减少
   `arr_load` / `arrload` / pointer 暗号。
2. 把 address/value contract 从“主要路径可用”推进到“load/store 对称”。
3. `C6`：allocator 和真实释放。
4. `C7/C8`：多目标、优化、自举探针。

## 重要约束

- 只改当前 compiler 主线需要的文件；不碰并行 `toolchain/targets/stage0/verify` lane。
- 每轮先给任务清单，再给结果报告。
- 编译器改动必须过 focused tests、完整 rebuild、137 LLVM smoke。
- 结构化表达式和旧 blob 双轨并存；没迁移的 producer 必须能回退。
- 运行时 helper 如果仍是 legacy i64 ABI，typed 值必须在 builder 侧显式归一。
- 旧 blob 的 pointer 暗号只能按最终表达式结果解释，不能用 receiver/中间行推断参数类型。

## 入口文档

- 总路线：[`compiler/docs/compiler-goal-tree.md`](../compiler/docs/compiler-goal-tree.md)
- 当前批次：[`compiler/docs/plans/2026-06-03-c5k-nested-array-field-chains.md`](../compiler/docs/plans/2026-06-03-c5k-nested-array-field-chains.md)
