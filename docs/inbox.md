# nextPas 工作看板

> 快速扫状态用，不是日志。

## 当前在做什么

- `C5-K0` 已完成：修复 `test_obj_compose` 的 constructor argument classification
  红点，`TRect.Create(P.GetX, P.GetY)` 现在按 `ptr, i64, i64` 发 LLVM call。
- 根因在 builder 的 `ProcessClassNew`：旧逻辑用参数 blob 的 receiver/内部行判断 pointer，
  nested method-call 的 `var P` 会污染最终参数类型。
- 新逻辑改为复用 `ParseIntBlobTyped` 的最终 `TypeId`：constructor argument
  不再自行重猜类型，而是直接沿用 blob lowering 的 typed result。
- `test_nested_method` 对照保持正常：`A.AddTo(B.Get)` 仍发 `ptr, i64`。
- `C5-J` 字段数组结构化 target 仍是当前 address/value 主线最近完成的功能切片：
  `shekArrayElem(SymbolId=0) -> shekField(self.FItems) -> index`。
- `ExprId` 继续只表示 RHS value；`TargetExprId` 表示 LHS address。
- 旧 blob fallback 保留：`__field_arr__`、direct `arr$ptr` 路径仍能回退。
- 最近验证：focused compiler tests `focused_failed=0`；`scripts/rebuild-compiler.sh`
  输出 `46258 lines compiled`；LLVM smoke `137/137`，全部 exit=42。

## 接下来怎么走

1. `C5-K`：更深 field chain，例如 `arr[i].A.B := rhs`，继续统一 nested address contract。
2. `C5-L`：field-array value load / `Result := FItems[i]` 结构化迁移，减少 `arr_load` / `arrload` 暗号。
3. `C5-M`：class/object RHS 特殊分支和剩余 array/field store producer 收口。
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
- 当前批次：[`compiler/docs/plans/2026-06-03-c5k0-constructor-arg-classification.md`](../compiler/docs/plans/2026-06-03-c5k0-constructor-arg-classification.md)
