# nextPas 工作看板

> 快速扫状态用，不是日志。

## 当前在做什么

- `C5-K` 已完成：`arr[i].A.B := rhs` 与 `Self.FItems[i].A.B := rhs`
  现在都能生成递归结构化 target，形态为
  `shekField -> shekField -> shekArrayElem`。
- sema 新增共享 `BuildTargetAddressExpr`，把 direct array、field-array、
  record/class base 和 nested dot chain 收到一条 address 构造线上。
- array-backed field store 的旧 blob fallback 还在，但 index 会展平成
  `index * elem_slots + field_offset`，不是只会认一层 `arr[i].Field`。
- builder 的 `shekField` 现在允许“聚合中间字段只作为地址存在”：
  address lowering 放行，value load 仍要求 concrete scalar type。
- `C5-K0` 的 constructor argument classification 修复仍保持有效：
  `TRect.Create(P.GetX, P.GetY)` 继续按 `ptr, i64, i64` 发 LLVM call。
- `ExprId` 继续只表示 RHS value；`TargetExprId` 表示 LHS address。
- 旧 blob fallback 保留：`__field_arr__`、direct `arr$ptr` 路径仍能回退。
- 最近验证：focused compiler tests `focused_failed=0`；`scripts/rebuild-compiler.sh`
  输出 `46508 lines compiled`；LLVM smoke `137/137`，全部 exit=42。

## 接下来怎么走

1. `C5-L`：array/field-array value load，尤其 `x := arr[i].A.B`、
   `Result := FItems[i]` 这类 value-side 迁移，继续减少 `arr_load` / `arrload` 暗号。
2. `C5-M`：class/object RHS 特殊分支和剩余 array/field store producer 收口。
3. 把 address/value contract 从“store 先硬起来”推进到“load/store 对称”。
4. `C6`：allocator 和真实释放。
5. `C7/C8`：多目标、优化、自举探针。

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
