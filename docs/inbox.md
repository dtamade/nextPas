# nextPas 工作看板

> 快速扫状态用，不是日志。

## 当前在做什么

- `C5-J` 已完成：字段数组 `self.FItems[i] := rhs` 生成结构化 LHS target：
  `shekArrayElem(SymbolId=0) -> shekField(self.FItems) -> index`。
- `shekArrayElem` 现在有两种合法形态：
  direct array：`SymbolId > 0`，child 0 是 index；
  base-address array：`SymbolId = 0`，child 0 是 array slot address，child 1 是 index。
- `ExprId` 继续只表示 RHS value；`TargetExprId` 表示 LHS address。
- 旧 blob fallback 保留：`__field_arr__`、direct `arr$ptr` 路径仍能回退。
- parser 已保留 class field 的完整 type node，包括逗号字段列表；sema 可为 class array field 记录 element metadata。
- field-array producer 覆盖隐式 `FItems[i]`、显式 `Self.FItems[i]` 和继承 field-array metadata。
- 最近验证：focused C3/C4/C5 tests `focused_failed=0`；`scripts/rebuild-compiler.sh`
  输出 `46248 lines compiled`；LLVM smoke `137/137`，全部 exit=42。

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

## 入口文档

- 总路线：[`compiler/docs/compiler-goal-tree.md`](../compiler/docs/compiler-goal-tree.md)
- 当前批次：[`compiler/docs/plans/2026-06-03-c5j-field-array-target.md`](../compiler/docs/plans/2026-06-03-c5j-field-array-target.md)
