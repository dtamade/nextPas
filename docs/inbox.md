# nextPas 工作看板

> 这是给快速扫状态用的，不是日志。

## 当前在做什么

- `C5-F` 已完成：`TTypedHirNode.TargetExprId` 成为独立 LHS target/address 通道，`ExprId` 继续只表示 RHS。
- `field-store-runtime` / `record-field-store-runtime` 现在优先通过 `LowerExprAddress(TargetExprId)` 得到 LHS 地址，失败时仍回落旧 operand target。
- sema producer 已覆盖普通 `record.field := rhs`、方法内 `self.field := rhs` 和 `obj.field := rhs` target：
  `record -> shekField -> shekSymbolAddress`，`class/self -> shekField -> shekDeref -> shekSymbolValue`。
- `C5-E` 能力保留：field store / record field store 的 RHS 可以走结构化 `ExprId`，失败时仍回落旧 blob。
- `C5-D` 能力保留：builder 支持 `shekField` 作为 field address，sema producer 支持 `@p^.Field -> shekAddressOf -> shekField -> shekDeref -> shekSymbolValue`。
- `shekDeref` 现在可作为 non-scalar aggregate address base；字段值仍由 `LowerExprValue` 显式 load。
- 旧 blob 仍保留：新增临时 fallback token `field_ref`；C5-C 的 `arr_elem_ref` 继续保底 array element address。
- 最近验证：focused C3/C4/C5 tests `9/9`；`scripts/rebuild-compiler.sh` 输出 `45545 lines compiled`；LLVM smoke `137/137`，全部 exit=42。
- 本批没有迁移 array store、static array 或嵌套 field chain。
- C4 已完成：typed scalar 表达式已经覆盖真实宽度、显式 cast、signed/unsigned opcode、sema-side promotion，以及 legacy alloca store 归一。

## 接下来怎么走

1. `C5-G`：迁移 `array[i] := rhs` 的 LHS target/address，优先动态数组，再决定 static array 的表达方式。
2. `C5-H+`：补齐 static array、嵌套 field chain，继续减少 `$ptr`、`arr_load_ptr` 等 blob 暗号。
3. `C6`：补 allocator 和真实释放。
4. `C7/C8`：多目标、优化、自举探针。

## 重要约束

- 只改 `compiler/`，不碰 `core/` 的并行工作。
- 每轮先给任务清单，再给结果报告。
- 任何编译器改动都必须过完整重编译和 137 个 smoke。
- 结构化表达式和旧 blob 现在是双轨并存，没迁移的 producer 必须能回退。
- `ExprId` 是 RHS value 通道；`TargetExprId` 是 LHS address 通道，不要混用。
- 运行时 helper 如果仍是 legacy i64 ABI，typed 值必须在 builder 侧显式归一，不能靠 emitter 猜。
- 下一步不要继续修字符串暗号局部个案；C5 应先把 address/value 契约建起来。

## 入口文档

- 总路线：[`compiler/docs/compiler-goal-tree.md`](../compiler/docs/compiler-goal-tree.md)
- 当前批次：[`compiler/docs/plans/2026-06-03-c5f-field-store-target.md`](../compiler/docs/plans/2026-06-03-c5f-field-store-target.md)
