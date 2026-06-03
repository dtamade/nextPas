# nextPas 工作看板

> 快速扫状态用，不是日志。

## 当前在做什么

- `C5-M` 已完成：object-backed field-array value load 已收口。
  现在 `y := Other.FItems[i]`、`Result := Other.FItems[i]`、
  `y := Other.FItems[i].A.B`、`Result := Other.FItems[i].A.B`
  都能挂上结构化 `ExprId`，同时保留旧 `arr_load` fallback。
- 这轮依旧没有改 builder 主合同，修的是 sema 的 self-only 识别边界：
  旧实现只认 implicit/self field-array，导致 object receiver 版本既没有 blob，
  也没有 structured address-backed value expr。
- sema 现在用共享 `TryClassFieldArrayAccess` 统一识别
  implicit self / explicit self / object variable receiver；
  `BuildClassFieldArrayElementTargetExpr`、`ResolveArrayAccessElementTypeId`、
  `EncodeRuntimeIntExprFold` 都复用这条识别结果。
- `C5-K` 的递归 target 与 `C5-K0` 的 constructor arg classification 修复都保持有效。
- `ExprId` 继续只表示 RHS value；`TargetExprId` 表示 LHS address。
- 旧 blob fallback 保留：`__field_arr__`、direct `arr$ptr`、field-array value load
  路径都还能回退。
- 最近验证：changed tests 绿；`scripts/rebuild-compiler.sh`
  输出 `44145 lines compiled`；LLVM smoke `137/137`，全部 exit=42。

## 接下来怎么走

1. 继续 `WalkHaltCalls` 里剩余 class/object RHS 特殊分支：
   constructor-like RHS、raw object-dot RHS、pointer-return helper assignment。
2. 把 address/value contract 从“主要路径可用”推进到“剩余 raw assign 分支也复用 attach helper”。
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
- 当前批次：[`compiler/docs/plans/2026-06-03-c5m-object-field-array-value-loads.md`](../compiler/docs/plans/2026-06-03-c5m-object-field-array-value-loads.md)
